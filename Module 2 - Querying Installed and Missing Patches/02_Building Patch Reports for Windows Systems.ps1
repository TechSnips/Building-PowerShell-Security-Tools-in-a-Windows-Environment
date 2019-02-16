# Quickly allow filtering of the available updates by using the Out-GridView cmdlet
Import-Csv -Path 'C:\computers.txt' | Get-WindowsUpdate | Out-GridView

# Export the Results of Windows Update to a CSV File
Import-Csv -Path 'C:\computers.txt' | Get-WindowsUpdate | Export-CSV -Path '.\WindowsUpdate.csv' -NoTypeInformation -Force

Import-Csv -Path '.\WindowsUpdate.csv'

Function Out-WindowsUpdateReport {
	<#
	.SYNOPSIS
		This function will output all piped in updates, remote or local, to an HTML page saved on disk.
	.DESCRIPTION
		Output the results of gathering Windows Updates to an HTML file on disk.
	.EXAMPLE
		PS> Get-WindowsUpdate | Out-WindowsUpdateReport
	.PARAMETER FilePath
		Location to output the report.
	.PARAMETER UpdateResult
		Updates to export.
	#>
	[OutputType('void')]
	[CmdletBinding()]
	Param(
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[String]$FilePath = '.\WindowsUpdates.html',

		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[PSCustomObject]$UpdateResult
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
                <th>KB ID</th>
				<th>IsDownloaded</th>
				<th>IsInstalled</th>
				<th>RebootRequired</th>
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

	Process {
		If ($UpdateResult.IsInstalled) {
			$class = 'installed'
		} Else {
			$class = 'notinstalled'
		}

		$body += "`t`t`t<tr class='$class'><td>$($UpdateResult.ComputerName)</td><td>$($UpdateResult.'KB ID')</td><td>$($UpdateResult.IsDownloaded)</td><td>$($UpdateResult.IsInstalled)</td><td>$($UpdateResult.RebootRequired)</td></tr>`r`n"
	}
	End {
		$html = $header + $body + $footer
		$html | Out-File -FilePath $FilePath -Force
	}
}

# Save the Results as an HTML Page
Get-WindowsUpdate | Out-WindowsUpdateReport

## Check the results of the report
Invoke-Item '.\WindowsUpdates.html'

# Save the Results as an HTML Page from a list of computers
Import-Csv -Path 'C:\computers.txt' | Get-WindowsUpdate | Out-WindowsUpdateReport

## Check the results of the report
Invoke-Item '.\WindowsUpdates.html'