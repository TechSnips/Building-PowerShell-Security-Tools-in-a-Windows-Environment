#region Add Error Checking
# Error Reference
# https://docs.microsoft.com/en-us/windows/deployment/update/windows-update-error-reference
Try {
    $updateSession  = New-Object -ComObject 'Microsoft.Update.Session'
    $updateSearcher = $updateSession.CreateUpdateSearcher()

    If ($updates = ($updateSearcher.Search($Query))) {
        $updates.Updates | Select-Object Title, LastDeploymentChangeTime
    }
} Catch [System.Runtime.InteropServices.COMException] {
    Switch ($_.Exception.Message) {
        { $_ -Match '0x80244022' } {
            Throw "The service is temporarily overloaded"
        }
        Default {
            Throw "Unknown Error $($_.Exception.Message)"
        }
    }
} Catch {
    Throw $_.Exception.Message
}
#endregion

#region Error Checking for Remote Computer Availability
$computerName = 'DC'

$scriptBlock = {
    $updateSession = New-Object -ComObject 'Microsoft.Update.Session'
    $updateSearcher = $updateSession.CreateUpdateSearcher()

    If ($updates = ($updateSearcher.Search($Null))) {
        If ($PassThru) {
            $updates.Updates
        } Else {
            $updates.Updates | Select-Object Title, LastDeploymentChangeTime
        }
    }
}

If ($ComputerName -And (Test-Connection $ComputerName -Quiet) ) {
    Invoke-Command -ComputerName $ComputerName -ScriptBlock $scriptBlock |
        Select-Object PSRemoteComputer, Title, LastDeploymentChangeTime
} Else {
    Throw "Remote computer, $computerName, is not available"
}
#endregion

#region Running as a Job
$scriptBlock = {
    $updateSession = New-Object -ComObject 'Microsoft.Update.Session'
    $updateSearcher = $updateSession.CreateUpdateSearcher()

    If ($updates = ($updateSearcher.Search($Null))) {
        $updates.Updates
    }
}

$Params = @{
    "ComputerName" = 'DC'
    "ScriptBlock"  = $scriptBlock
    "AsJob"        = $true
    "JobName"      = "$ComputerName - Windows Update Query"
}

Invoke-Command @Params

$Result = Get-Job | Where-Object Name -Match "Windows Update Query" | Select -Last 1 | Wait-Job | Receive-Job

$Result
#endregion

#region Parallel Computers
Get-Job | Remove-Job

$Computers = @(
    'DC'
    'CLIENT2'
    'WSUS'
    'CLIENT3'
)

$Jobs = @()
$Results = @()

$scriptBlock = {
    $updateSession = New-Object -ComObject 'Microsoft.Update.Session'
    $updateSearcher = $updateSession.CreateUpdateSearcher()

    If ($updates = ($updateSearcher.Search($Null))) {
        $updates.Updates
    }
}

$Computers | Foreach-Object {
    # Not all computers are ICMP ping enabled, but do support PSRemote which is what we need
    Try {
        Test-WSMan -ComputerName $_ -ErrorAction Stop | Out-Null
    } Catch {
        Return
    }

    $Name = "$($_) - Windows Update Query"

    $Params = @{
        "ComputerName" = $_
        "ScriptBlock"  = $scriptBlock
        "AsJob"        = $true
        "JobName"      = $Name
    }

    Try {
        Invoke-Command @Params
    } Catch {
        Throw $_.Exception.Message
    }

    $Jobs += Get-Job -Name $Name
}

$Jobs | Wait-Job | Receive-Job | Foreach-Object { $Results += $_ }

$Results | Select-Object PSComputerName, Title | Format-Table -AutoSize
#endregion

#region HTML Report
Get-Job | Remove-Job

$Computers = @(
    'DC'
    'CLIENT2'
    'WSUS'
    'CLIENT3'
)

$Jobs    = @()
$Results = @()
$Path    = "$($Env:USERPROFILE)\Desktop\report.html"

$scriptBlock = {
    $allUpdates     = @()
    $updateSession  = New-Object -ComObject 'Microsoft.Update.Session'
    $updateSearcher = $updateSession.CreateUpdateSearcher()

    If ($updates = ($updateSearcher.Search($Null))) {
        $allUpdates += $updates.Updates
    }

    If ($updates = ($updateSearcher.Search('IsInstalled=1'))) {
        $allUpdates += $updates.Updates
    }

    $allUpdates
}

$Computers | Foreach-Object {
    # Not all computers are ICMP ping enabled, but do support PSRemote which is what we need
    Try {
        Test-WSMan -ComputerName $_ -ErrorAction Stop | Out-Null
    }
    Catch {
        Return
    }

    $Name = "$($_) - Windows Update Query"

    $Params = @{
        "ComputerName" = $_
        "ScriptBlock"  = $scriptBlock
        "AsJob"        = $true
        "JobName"      = $Name
    }

    Try {
        Invoke-Command @Params
    }
    Catch {
        Throw $_.Exception.Message
    }

    $Jobs += Get-Job -Name $Name
}

$Jobs | Wait-Job | Receive-Job | Foreach-Object { $Results += $_ }

If ($Results) {
    $Results | Where-Object IsInstalled -EQ $False | ForEach-Object {
        $Updates += [PSCustomObject]@{
            "Title"  = $_.Title
            "Date"   = $_.LastDeploymentChangeTime
            "Status" = "Not Installed"
        }
    }

    $Results | Where-Object IsInstalled -EQ $True | ForEach-Object {
        $Updates += [PSCustomObject]@{
            "Title"  = $_.Title
            "Date"   = $_.LastDeploymentChangeTime
            "Status" = "Installed"
        }
    }
}

$header = @"
<!doctype html>
<html lang='en'>
<head>
    <style type='text/css'>.updates{empty-cells:show;border:1px solid #cbcbcb;border-collapse:collapse;border-spacing:0}.updates thead{background-color:#e0e0e0;color:#000;text-align:left;vertical-align:bottom}.updates td,.updates th{padding:.5em 1em;border-width:0 0 1px;border-bottom:1px solid #cbcbcb;margin:0}.updates td:first-child,.updates th:first-child{border-left-width:0}.updates th{border-width:0 0 1px;border-bottom:1px solid #cbcbcb}.updates .installed{background-color:#a5d6a7;color:#030}.updates .notinstalled{background-color:#ef9a9a;color:#7f0000}</style>
</head>
<body>
    <table class='updates'>
        <thead>
            <tr>
                <th>System</th>
                <th>Status</th>
                <th>Title</th>
                <th>Release</th>
            </tr>
        </thead>
        <tbody>
"@

$body = ""
$results | ForEach-Object {
    If ( $_.Status -EQ 'Installed' ) {
        $class = 'installed'
    } Else {
        $class = 'notinstalled'
    }
    $body += "`t`t`t<tr class='$class'><td>Local</td><td>$($_.Status)</td><td>$($_.Title)</td><td>$($_.Date)</td></tr>`r`n"
}

$footer = @"
        </tbody>
    </table>
</body>
</html>
"@

$html = $header + $body + $footer

$html | Out-File -Path $Path -Force
#endregion