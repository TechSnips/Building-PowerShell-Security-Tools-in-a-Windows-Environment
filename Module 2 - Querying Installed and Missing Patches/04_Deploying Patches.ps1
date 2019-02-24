<#
	Scenario:
		- Find all missing updates
		- Download missing updates
		- Install the updates
		- Create Install-WindowsUpdate function
#>

#region Download updates

## Let's first check for any missing updates. We have one that's not downloaded and installed
Get-WindowsUpdate

$updateSession    = New-Object -ComObject 'Microsoft.Update.Session'
$updateSearcher   = $updateSession.CreateUpdateSearcher()

# Create the update collection object to add our updates to
$updatesToDownload = New-Object -ComObject 'Microsoft.Update.UpdateColl'

$updates = $updateSearcher.Search($null)

# Filter out just the updates that we want and add them to our collection
$updates.updates | Foreach-Object { $updatesToDownload.Add($_) | Out-Null }

# Create the download object, assign our updates to download and initiate the download
$downloader         = $updateSession.CreateUpdateDownloader()
$downloader.Updates = $updatesToDownload
$downloadResult     = $downloader.Download()

# Show the updates to verify that they've been downloaded
Get-WindowsUpdate

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
Get-WindowsUpdate -ComputerName $ComputerName

$scriptBlock = {
	$updateSession = New-Object -ComObject 'Microsoft.Update.Session';
	$objSearcher = $updateSession.CreateUpdateSearcher()
	$updates = $objSearcher.Search('IsInstalled=0')
	$updates = $updates.Updates

	$downloader = $updateSession.CreateUpdateDownloader()
	### Other code to download and install updates here ###
}

## Attempt this the "usual" way even if we're an admin on the remote computer, we'll get Access Denied
Invoke-Command -ComputerName $ComputerName -ScriptBlock $scriptBlock

#region Creating a scheduled task running as SYSTEM to get around getting denied
$taskParams = @{
	Session     = $session
	Name        = $TaskName
	Scriptblock = $scriptBlock
}
Write-Verbose -Message 'Creating scheduled task...'

$createStartSb = {
	$taskName = $args[0]
	$taskArgs = $args[1] -replace '"', '\"'
	$taskUser = $args[2]

	$tempScript = "$env:TEMP\WUUpdateScript.ps1"
	Set-Content -Path $tempScript -Value $taskArgs

	schtasks /create /SC ONSTART /TN $taskName /TR "powershell.exe -NonInteractive -NoProfile -File $tempScript" /F /RU $taskUser /RL HIGHEST
}

$command = $Scriptblock.ToString()

$icmParams = @{
	Session      = $Session
	ScriptBlock  = $createStartSb
	ArgumentList = $Name, $command
}
if ($PSBoundParameters.ContainsKey('Credential')) {
	$icmParams.ArgumentList += $Credential.UserName	
} else {
	$icmParams.ArgumentList += 'SYSTEM'
}
Write-Verbose -Message "Running code via powershell.exe: [$($command)]"
Invoke-Command @icmParams
#endregion


#endregion

function Install-WindowsUpdate {
	<#
		.SYNOPSIS
			This function retrieves all updates that are targeted at a remote computer, download and installs any that it
			finds. Depending on how the remote computer's update source is set, it will either read WSUS or Microsoft Update
			for a compliancy report.

			Once found, it will download each update, install them and then read output to detect if a reboot is required
			or not.
	
		.EXAMPLE
			PS> Install-WindowsUpdate -ComputerName FOO.domain.local

		.EXAMPLE
			PS> Install-WindowsUpdate -ComputerName FOO.domain.local,FOO2.domain.local			
		
		.EXAMPLE
			PS> Install-WindowsUpdate -ComputerName FOO.domain.local,FOO2.domain.local -ForceReboot

		.PARAMETER ComputerName
			 A mandatory string parameter representing one or more computer FQDNs.

		.PARAMETER Credential
			 A optional pscredential parameter representing an alternate credential to connect to the remote computer.
		
		.PARAMETER ForceReboot
			 An optional switch parameter to set if any updates on any computer targeted needs a reboot following update
			 install. By default, computers are NOT rebooted automatically. Use this switch to force a reboot.
		
		.PARAMETER AsJob
			 A optional switch parameter to set when activity needs to be sent to a background job. By default, this function 
			 waits for each computer to finish. However, if this parameter is used, it will start the process on each
			 computer and immediately return a background job object to then monitor yourself with Get-Job.
	#>
	[OutputType([void])]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string[]]$ComputerName,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[switch]$ForceReboot,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[switch]$AsJob
	)
	begin {
		$ErrorActionPreference = 'Stop'

		$scheduledTaskName = 'Windows Update Install'

	}
	process {
		try {
			@($ComputerName).foreach({
					Write-Verbose -Message "Starting Windows update on [$($_)]"
					$installProcess = {
						param($ComputerName, $TaskName, $ForceReboot)

						$ErrorActionPreference = 'Stop'
						try {
							if (-not (Get-WindowsUpdate -ComputerName $ComputerName)) {
								Write-Verbose -Message 'No updates needed to install. Skipping computer...'
							} else {
								$sessParams = @{ ComputerName = $ComputerName }    
								$session = New-PSSession @sessParams

								$scriptBlock = {
									$updateSession = New-Object -ComObject 'Microsoft.Update.Session';
									$objSearcher = $updateSession.CreateUpdateSearcher()
									if ($updates = ($objSearcher.Search('IsInstalled=0'))) {
										$updates = $updates.Updates

										$downloader = $updateSession.CreateUpdateDownloader()
										$downloader.Updates = $updates
										$downloadResult = $downloader.Download()
										if ($downloadResult.ResultCode -ne 2) {
											exit $downloadResult.ResultCode
										}

										$installer = New-Object -ComObject Microsoft.Update.Installer
										$installer.Updates = $updates
										$installResult = $installer.Install()
										if ($installResult.RebootRequired) {
											exit 7
										} else {
											$installResult.ResultCode
										}
									} else {
										exit 6
									}
								}
                        
								$taskParams = @{
									Session     = $session
									Name        = $TaskName
									Scriptblock = $scriptBlock
								}
								Write-Verbose -Message 'Creating scheduled task...'
								New-WindowsUpdateScheduledTask @taskParams

								Write-Verbose -Message "Starting scheduled task [$($TaskName)]..."

								$icmParams = @{
									Session      = $session
									ScriptBlock  = { schtasks /run /TN "\$($args[0])" /I }
									ArgumentList = $TaskName
								}
								Invoke-Command @icmParams

								## This could take awhile depending on the number of updates
								Wait-ScheduledTask -Name $TaskName -ComputerName $ComputerName -Timeout 2400

								$installResult = Get-WindowsUpdateInstallResult -Session $session

								if ($installResult -eq 'NoUpdatesNeeded') {
									Write-Verbose -Message "No updates to install"
								} elseif ($installResult -eq 'RebootRequired') {
									if ($ForceReboot) {
										Restart-Computer -ComputerName $ComputerName -Force -Wait;
									} else {
										Write-Warning "Reboot required but -ForceReboot was not used."
									}
								} else {
									throw "Updates failed. Reason: [$($installResult)]"
								}
							}
						} catch {
							Write-Error -Message $_.Exception.Message
						} finally {
							Remove-ScheduledTask -ComputerName $ComputerName -Name $TaskName
						}
					}

					$blockArgs = $_, $scheduledTaskName, $Credential, $ForceReboot.IsPresent
					if ($AsJob.IsPresent) {
						$jobParams = @{
							ScriptBlock          = $installProcess
							Name                 = "$_ - EO Windows Update Install"
							ArgumentList         = $blockArgs
							InitializationScript = { Import-Module -Name 'GHI.Library.WindowsUpdate' }
						}
						Start-Job @jobParams
					} else {
						Invoke-Command -ScriptBlock $installProcess -ArgumentList $blockArgs
					}
				})
		} catch {
			Write-Log -Source $MyInvocation.MyCommand -EventId 1003 -EntryType Error -ErrorRecord $_
		} finally {
			if (-not $AsJob.IsPresent) {
				# Remove any sessions created. This is done when processes aren't invoked under a PS job
				Write-Verbose -Message 'Finding any lingering PS sessions on computers...'
				@(Get-PSSession -ComputerName $ComputerName).foreach({
						Write-Verbose -Message "Removing PS session from [$($_)]..."
						Remove-PSSession -Session $_
					})
			}
		}
	}
	end {
		Write-Log -Source $MyInvocation.MyCommand -Message ('{0}: Exiting' -f $MyInvocation.MyCommand)
		$ErrorActionPreference = 'Continue'
	}
}

Install-WindowsUpdate -ComputerName DC
#endregion

#region Removing Windows Update

function Remove-WindowsUpdate {
	[OutputType('void')]
	[CmdletBinding(SupportsShouldProcess)]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
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
						Write-Warning -Message "The package for KB ID [$($kbId)] was not found."
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
$installedUpdates | Remove-WindowsUpdate -Restart
#endregion