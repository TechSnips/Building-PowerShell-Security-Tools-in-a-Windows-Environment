function Out-WindowsUpdateReport {
	[OutputType('void')]
	[CmdletBinding()]
	param
	(
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$FilePath = '.\WindowsUpdates.html',
        
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[pscustomobject]$UpdateResult
	)

	begin {
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
    
		$footer = @"
        </tbody>
    </table>
</body>
</html>
"@
	}

	process {
		if ($UpdateResult.PSComputerName) {
			$computerName = $UpdateResult.PSComputerName
		} else {
			$computerName = 'Local'
		}
		If ($UpdateResult.IsInstalled) {
			$class = 'installed'
		} Else {
			$class = 'notinstalled'
		}
		$body += "`t`t`t<tr class='$class'><td>$($computerName)</td><td>$($UpdateResult.Title)</td><td>$($UpdateResult.Description)</td><td>$($UpdateResult.IsInstalled)</td></tr>`r`n"
	}
	end {
		$html = $header + $body + $footer
		$html | Out-File -FilePath $FilePath -Force
	}	
}

Get-WindowsUpdate | Out-WindowsUpdateReport
Import-Csv -Path C:\computers.txt | Get-WindowsUpdate | Out-WindowsUpdateReport