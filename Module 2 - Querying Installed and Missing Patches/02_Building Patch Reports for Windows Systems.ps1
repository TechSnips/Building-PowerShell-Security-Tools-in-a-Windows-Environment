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
$Computers = @(
    'DC'
    'CLIENT2'
)

$Jobs    = @()
$Results = @()

$scriptBlock = {
    $updateSession = New-Object -ComObject 'Microsoft.Update.Session'
    $updateSearcher = $updateSession.CreateUpdateSearcher()

    If ($updates = ($updateSearcher.Search($Null))) {
        $updates.Updates
    }
}

$Computers | Foreach-Object {
    If (Test-Connection -ComputerName $_ -Quiet) {
        $Name = "$ComputerName - Windows Update Query"

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
}

$Jobs | Wait-Job -Any | Receive-Job | Foreach-Object { $Results += $_ }
#endregion

#region HTML Report
$updateSession  = New-Object -ComObject 'Microsoft.Update.Session'
$updateSearcher = $updateSession.CreateUpdateSearcher()

$results = @()
$Path    = "$($Env:USERPROFILE)\Desktop\report.html"

If ($updates = ($updateSearcher.Search($null))) {
    $updates.Updates | ForEach-Object {
        $results += [PSCustomObject]@{
            "Title"  = $_.Title
            "Date"   = $_.LastDeploymentChangeTime
            "Status" = "Not Installed"
        }
    }
}

If ($updates2 = ($updateSearcher.Search('IsInstalled=1'))) {
    $updates2.Updates | ForEach-Object {
        $results += [PSCustomObject]@{
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