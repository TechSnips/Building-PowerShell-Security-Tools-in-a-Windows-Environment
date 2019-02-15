<#
	Scenario:
		- Find all missing updates
		- Download missing updates
		- Install the updates
		- Create Install-WindowsUpdate function
#>

#region Download updates
$updateSession    = New-Object -ComObject 'Microsoft.Update.Session'
$updateSearcher   = $updateSession.CreateUpdateSearcher()

# Create the update collection object to add our updates to
$updatesToInstall = New-Object -ComObject 'Microsoft.Update.UpdateColl'

If ($updates = ($updateSearcher.Search($null))) {
	# Show existing updates before filtering
	$updates.updates | Select-Object 'Title', 'IsDownloaded'

	# Filter out just the updates that we want and add them to our collection
	$updates.updates |
		Where-Object Title -Match "Adobe Flash Player" |
		Foreach-Object { $updatesToInstall.Add($_) | Out-Null }

	# Create the download object, assign our updates to download and initiate the download
	$downloader         = $updateSession.CreateUpdateDownloader()
	$downloader.Updates = $updatesToInstall
	$downloadResult     = $downloader.Download()

	# Show the updates to verify that they've been downloaded
	$updates = $updateSearcher.Search($null)

	$updates.updates | Select-Object 'Title', 'IsDownloaded'
}
#endregion

#region Install One Downloaded Updates
$updatesToInstall = New-Object -ComObject 'Microsoft.Update.UpdateColl'

$updates.updates |
	Where-Object IsDownloaded -EQ $true |
	Foreach-Object { $updatesToInstall.Add($_) | Out-Null }

# Create the installation object, assign our updates to download and initiate the download
$installer         = New-Object -ComObject 'Microsoft.Update.Installer'
$installer.Updates = $updatesToInstall
$installResult     = $installer.Install()

$installResult
#endregion

#region Download All Updates
$updateSession  = New-Object -ComObject 'Microsoft.Update.Session'
$updateSearcher = $updateSession.CreateUpdateSearcher()

If ($updates = ($updateSearcher.Search($null))) {
	$updates.updates | Select-Object 'Title', 'IsDownloaded'

	$downloader         = $updateSession.CreateUpdateDownloader()
	$downloader.Updates = $updates.updates
	$downloadResult     = $downloader.Download()

	$updates = $updateSearcher.Search($null)

	$updates.updates | Select-Object 'Title', 'IsDownloaded'
}
#endregion

#region Download & Install Updates
$updateSession  = New-Object -ComObject 'Microsoft.Update.Session'
$updateSearcher = $updateSession.CreateUpdateSearcher()

If ($updates = ($updateSearcher.Search($null))) {
	$downloader         = $updateSession.CreateUpdateDownloader()
	$downloader.Updates = $updates.updates
	$downloadResult     = $downloader.Download()

	If ($downloadResult.ResultCode -ne 2) {
		Exit $downloadResult.ResultCode;
	}

	$installer         = New-Object -ComObject 'Microsoft.Update.Installer'
	$installer.Updates = $updates
	$installResult     = $installer.Install()

	If ($installResult.RebootRequired) {
		Write-Warning "Reboot Required"
	} Else {
		$installResult.ResultCode
	}
}
#endregion

#region Defer Execution of Install
# Remove all existing scheduled jobs
$ComputerName = 'localhost'
$DelayMinutes = 1

$scriptBlock = {
	$updateSession    = New-Object -ComObject 'Microsoft.Update.Session'
	$updateSearcher   = $updateSession.CreateUpdateSearcher()
	$updatesToInstall = $updateSearcher.Search($null).Updates

	$Downloader         = $updateSession.CreateUpdateDownloader()
	$Downloader.Updates = $updatesToInstall
	$Downloader.Download()

	$Installer         = New-Object -ComObject 'Microsoft.Update.Installer'
	$Installer.Updates = $updatesToInstall
	$InstallerResult   = $Installer.Install()
}

# Using the scheduled task ability create an elevated scheduled task to run our scriptblock in the future
$Params = @{
	"ScriptBlock"        = $scriptBlock
	"Name"               = "$ComputerName - Windows Update Install"
	"Trigger"            = (New-JobTrigger -At (Get-Date).AddMinutes($DelayMinutes) -Once)
	"ScheduledJobOption" = (New-ScheduledJobOption -RunElevated)
}

Register-ScheduledJob @Params
#endregion

#region Remotely Install Updates
$Computers = @(
	'CLIENT'
	'CLIENT2'
)

$scriptBlock = {
	$updateSession    = New-Object -ComObject 'Microsoft.Update.Session'
	$updateSearcher   = $updateSession.CreateUpdateSearcher()
	$updatesToInstall = New-Object -ComObject 'Microsoft.Update.UpdateColl'

	If ($updates = ($updateSearcher.Search($Null))) {
		$updates.updates |
			Where-Object Title -Match "Adobe Flash Player" |
			Foreach-Object { $updatesToInstall.Add($_) | Out-Null }

		$downloader         = $updateSession.CreateUpdateDownloader()
		$downloader.Updates = $updatesToInstall
		$downloadResult     = $downloader.Download()

		$installer          = New-Object -ComObject 'Microsoft.Update.Installer'
		$installer.Updates  = $updatesToInstall
		$installResult      = $installer.Install()
	}
}

$Computers | Foreach-Object {
	# Not all computers are ICMP ping enabled, but do support PSRemote which is what we need
	Try {
		Test-WSMan -ComputerName $_ -ErrorAction Stop | Out-Null
	} Catch {
		Return
	}

	$Name = "$($_) - Windows Update Download and Install"

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
}
#endregion

#region Remotely Schedule Install for Updates
$Computers = @(
	'CLIENT'
	'CLIENT2'
)

$scriptBlock = {
	$scriptBlock = {
		$updateSession    = New-Object -ComObject 'Microsoft.Update.Session'
		$updateSearcher   = $updateSession.CreateUpdateSearcher()
		$updatesToInstall = $updateSearcher.Search($null).Updates

		$Downloader         = $updateSession.CreateUpdateDownloader()
		$Downloader.Updates = $updatesToInstall
		$Downloader.Download()

		$Installer         = New-Object -ComObject 'Microsoft.Update.Installer'
		$Installer.Updates = $updatesToInstall
		$InstallerResult   = $Installer.Install()
	}

	$Params = @{
		"ScriptBlock"        = $scriptBlock
		"Name"               = "localhost - Windows Update Install"
		"Trigger"            = (New-JobTrigger -At (Get-Date).AddMinutes($DelayMinutes) -Once)
		"ScheduledJobOption" = (New-ScheduledJobOption -RunElevated)
	}

	Register-ScheduledJob @Params
}

$Computers | Foreach-Object {
	# Not all computers are ICMP ping enabled, but do support PSRemote which is what we need
	Try {
		Test-WSMan -ComputerName $_ -ErrorAction Stop | Out-Null
	} Catch {
		Return
	}

	$Name = "$($_) - Windows Update Download and Install Scheduled"

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
}
#endregion

#region Remove Windows Update
Import-Module DISM
$Package = Get-WindowsPackage -Online -PackageName 'Package_for_KB4487038~31bf3856ad364e35~amd64~~10.0.1.0'

Remove-WindowsPackage -PackageName $Package.PackageName -Online
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
	[OutputType([System.Management.Automation.PSObject])]
	[CmdletBinding()]

	Param (
		$Updates,

		[Parameter(ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[Alias("Name")]
		[String]$ComputerName,

		[Switch]$PassThru
	)

	Process {
		Try {
			$scriptBlock = {
				Param (
					$PassThru
				)

				Write-Verbose "PassThru is '$PassThru'"

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

					If ($installResult.RebootRequired) {
						Write-Warning "Reboot Required"
					} Else {
						$installResult.ResultCode
					}
				}
			}

			If ($ComputerName) {
				Invoke-Command -ComputerName $ComputerName -ScriptBlock $scriptBlock -ArgumentList $PassThru |
					Select-Object PSRemoteComputer, Title, LastDeploymentChangeTime
			} Else {
				& $scriptBlock $PassThru
			}
		} Catch {
			Throw $_.Exception.Message
		}
	}
}
#endregion