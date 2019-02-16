<#
	Scenario:
		- Find all missing updates
		- Download missing updates
		- Install the updates
		- Create Install-WindowsUpdate function
#>

#region Download updates

## Let's first check for any missing updates
Get-WindowsUpdate

$updateSession    = New-Object -ComObject 'Microsoft.Update.Session'
$updateSearcher   = $updateSession.CreateUpdateSearcher()

# Create the update collection object to add our updates to
$updatesToDownload = New-Object -ComObject 'Microsoft.Update.UpdateColl'

If ($updates = ($updateSearcher.Search($null))) {
	# Show existing updates before filtering
	$updates.updates | Select-Object 'Title', 'IsDownloaded'

	# Filter out just the updates that we want and add them to our collection
	$updates.updates | Foreach-Object { $updatesToDownload.Add($_) | Out-Null }

	# Create the download object, assign our updates to download and initiate the download
	$downloader         = $updateSession.CreateUpdateDownloader()
	$downloader.Updates = $updatesToDownload
	$downloadResult     = $downloader.Download()

	# Show the updates to verify that they've been downloaded
	$updates = $updateSearcher.Search($null)

	$updates.updates | Select-Object 'Title', 'IsDownloaded'
}
#endregion

#region Install the updates locally
$updatesToInstall = New-Object -ComObject 'Microsoft.Update.UpdateColl'

$updates.updates |
	Where-Object IsDownloaded -EQ $true |
	Foreach-Object { $updatesToInstall.Add($_) | Out-Null }

# Create the installation object, assign our updates to download and initiate the download
$installer         = New-Object -ComObject 'Microsoft.Update.Installer'
$installer.Updates = $updatesToInstall
$installResult     = $installer.Install()

$installResult

## Check for missing updates again
Get-WindowsUpdate

#endregion

#region Install updates remotely

$ComputerName = 'DC'

$scriptBlock = {
	$updateSession    = New-Object -ComObject 'Microsoft.Update.Session'
	$updateSearcher   = $updateSession.CreateUpdateSearcher()
	$updatesToInstall = $updateSearcher.Search($null).Updates

	$Downloader         = $updateSession.CreateUpdateDownloader()
	$Downloader.Updates = $updatesToInstall
	$Downloader.Download()

	$Installer         = New-Object -ComObject 'Microsoft.Update.Installer'
	$Installer.Updates = $updatesToInstall
	$Installer.Install()
}

Invoke-Command -ComputerName $ComputerName -ScriptBlock $scriptBlock

#endregion

Function Install-WindowsUpdate {
	<#
	.SYNOPSIS
		Install available updates for Windows.
	.DESCRIPTION
		Utilizing the built-in Windows COM objects to interact with the Windows Update service install available updates for Windows.
    .EXAMPLE
        PS> Get-WindowsUpdate

	.PARAMETER Updates
		Return installed updates.
	.PARAMETER ComputerName
		The remote system to retrieve updates from, also aliased as 'Name'.
	.PARAMETER PassThru
		Pass the unfiltered update objects to the pipeline.
	#>
	[OutputType([pscustomobject])]
	[CmdletBinding()]

	Param (
		$Updates,

		[Parameter(ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[Alias("Name")]
		[String]$ComputerName,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[switch]$Restart,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[switch]$AsJob
	)

	process {
		$scriptBlock = {
			$updateSession = New-Object -ComObject 'Microsoft.Update.Session'
			$updateSearcher = $updateSession.CreateUpdateSearcher()

			If ($updates = ($updateSearcher.Search($null))) {
				$downloader         = $updateSession.CreateUpdateDownloader()
				$downloader.Updates = $updates.updates
				$downloadResult     = $downloader.Download()

				If ($downloadResult.ResultCode -ne 2) {
					Exit $downloadResult.ResultCode;
				}

				$installer         = New-Object -ComObject 'Microsoft.Update.Installer'
				$installer.Updates = $updates.updates
				$installResult     = $installer.Install()

				If ($installResult.RebootRequired -and $Restart.IsPresent) {
					Restart-Computer -Force
				} Else {
					Write-Warning "Reboot Required"
					$installResult.ResultCode
				}
			}
		}
			
		$invokeCommandSplat = @{
			ScriptBlock = $scriptBlock
		}

		if ($PSBoundParameters.ContainsKey('ComputerName')) {
			$invokeCommandSplat.ComputerName = $ComputerName
		}
		try {
			Invoke-Command @invokeCommandSplat
		} catch {
			throw $_.Exception.Message
		}
	}
}

Get-WindowsUpdate | Install-WindowsUpdate
#endregion

#region Removing Windows Update

function Remove-WindowsUpdate {
	[OutputType('void')]
	[CmdletBinding(SupportsShouldProcess)]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[object[]]$Update,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$ComputerName,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[switch]$Restart
	)

	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		$scriptBlock = {
			param($Update, $Restart)
			foreach ($patch in $Update) {
				foreach ($kbId in $patch.KBArticleIds) {
					if ($package = (Get-WindowsPackage -Online).where({ $_.PackageName -match "^Package_for_KB$kbId"})) {
						$result = Remove-WindowsPackage -PackageName $Package.PackageName -Online -NoRestart
						if ($result.RestartNeeded -and $Restart.IsPresent) {
							Restart-Computer -Force
						} else {
							Write-Warning -Message "Restart needed to remove update."
						}
					} else {
						Write-Warning -Message "The package for KB id [$($kbId)] was not found."
					}
				}
			}
		}
		$params = @{
			ScriptBlock  = $scriptBlock
			ArgumentList = $Update
		}
		if ($PSBoundParameters.ContainsKey('ComputerName')) {
			$params.ComputerName = $ComputerName
		}
		if ($PSCmdlet.ShouldProcess($ComputerName, 'Install updates')) {
			Invoke-Command @params
		}
	}
}

$installedUpdates = Get-WindowsUpdate -Installed $true
$installedUpdates[1]

Remove-WindowsUpdate -Update $installedUpdates[1] -Restart
#endregion