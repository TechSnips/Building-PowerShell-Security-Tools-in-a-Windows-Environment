#region HTML Report
$Computers = @(
	'DC'
	'CLIENT2'
	'WSUS'
	'CLIENT3'
)

$Jobs    = @()
$Results = @()
$Path    = "$($Env:USERPROFILE)\Desktop\report.html"



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


#endregion

function Out-WindowsUpdateReport {
	[OutputType('void')]
	[CmdletBinding()]
	param
	(
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$FilePath = '.\WindowsUpdates.html',
        
		[Parameter(ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[pscustomobject[]]$UpdateResults
	)

	$ErrorActionPreference = 'Stop'

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
                <th>Computer</th>
                <th>Title</th>
                <th>Description</th>
                <th>IsInstalled</th>
            </tr>
        </thead>
        <tbody>
"@

	$body = ""
	$UpdateResults | ForEach-Object {
		if ($_.PSComputerName) {
			$computerName = $_.PSComputerName
		} else {
			$computerName = 'Local'
		}
		If ($_.IsInstalled) {
			$class = 'installed'
		} Else {
			$class = 'notinstalled'
		}
		$body += "`t`t`t<tr class='$class'><td>$($computerName)</td><td>$($_.Title)</td><td>$($_.Description)</td><td>$($_.IsInstalled)</td></tr>`r`n"
	}

	$footer = @"
        </tbody>
    </table>
</body>
</html>
"@

	$html = $header + $body + $footer

	$html | Out-File -FilePath $FilePath -Force
}