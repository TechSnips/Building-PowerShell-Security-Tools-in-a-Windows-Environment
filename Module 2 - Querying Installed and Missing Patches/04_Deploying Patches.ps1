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

#region Install updates remotely but denied

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

		$scheduledTaskName = 'WindowsUpdateInstall'

	}
	process {
		try {
			@($ComputerName).foreach({
					Write-Verbose -Message "Starting Windows update on [$($_)]"
					## Create the scriptblock. This is only done in case the function
					## needs to be executed via a background job. Otherwise, we wouldn't need to wrap
					## this code in a scriptblock.
					$installProcess = {
						param($ComputerName, $TaskName, $ForceReboot)

						$ErrorActionPreference = 'Stop'
						try {
							## Create a PSSession to reuse
							$sessParams = @{ ComputerName = $ComputerName }
							$session = New-PSSession @sessParams
							
							## Create the scriptblock to pass to the remote computer
							$scriptBlock = {
								$updateSession = New-Object -ComObject 'Microsoft.Update.Session';
								$objSearcher = $updateSession.CreateUpdateSearcher()
								## Check for missing updates. Are updates needed?
								$u = $objSearcher.Search('IsInstalled=0')
								if ($u.updates) {
									Add-Content -Path 'C:\foo.txt' -Value ($u.updates -eq $null)
									$updates = $u.updates
									
									## Download the updates
									$downloader = $updateSession.CreateUpdateDownloader()
									$downloader.Updates = $updates
									$downloadResult = $downloader.Download()
									## Check the download result and quit if it wasn't successful (2)
									if ($downloadResult.ResultCode -ne 2) {
										exit $downloadResult.ResultCode
									}
									
									## Install all of the updates we just downloaded
									$installer = New-Object -ComObject Microsoft.Update.Installer
									$installer.Updates = $updates
									$installResult = $installer.Install()
									## Exit with specific error codes
									if ($installResult.RebootRequired) {
										exit 7
									} else {
										$installResult.ResultCode
									}
								} else {
									exit 6
								}
							}
							
							Write-Verbose -Message 'Creating scheduled task...'
							$params = @{
								ComputerName = $ComputerName
								Name         = $TaskName
								ScriptBlock  = $scriptBlock
								Interval     = 'Once'
								Time         = '23:00' ## doesn't matter
							}
							New-PsScheduledTask @params

							Write-Verbose -Message "Starting scheduled task [$($TaskName)]..."
							$icmParams = @{
								Session      = $session
								ScriptBlock  = { Start-ScheduledTask -TaskName $args[0] }
								ArgumentList = $TaskName
							}
							Invoke-Command @icmParams

							## This could take awhile depending on the number of updates
							Wait-ScheduledTask -Name $scheduledTaskName -ComputerName $ComputerName -Timeout 2400
							
							## Parse the result in another function for modularity
							$installResult = Get-WindowsUpdateInstallResult -Session $session -ScheduledTaskName $scheduledTaskName

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
						} catch {
							Write-Error -Message $_.Exception.Message
						} finally {
							## Remove the scheduled task because we just needed it to run our
							## updates as SYSTEM
							Remove-ScheduledTask -ComputerName $ComputerName -Name $scheduledTaskName
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
			throw $_.Exception.Message
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
}
function Get-WindowsUpdateInstallResult {
	[OutputType([string])]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[System.Management.Automation.Runspaces.PSSession]$Session,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ScheduledTaskName
	)

	$sb = { 
		if ($result = schtasks /query /TN "\$($args[0])" /FO CSV /v | ConvertFrom-Csv) {
			$result.'Last Result'
		}
	}
	$resultCode = Invoke-Command -Session $Session -ScriptBlock $sb -ArgumentList $ScheduledTaskName
	switch -exact ($resultCode) {
		0   {
			'NotStarted'
		}
		1   {
			'InProgress'
		}
		2   {
			'Installed'
		}
		3   {
			'InstalledWithErrors'
		}
		4   {
			'Failed'
		}
		5   {
			'Aborted'
		}
		6   {
			'NoUpdatesNeeded'
		}
		7   {
			'RebootRequired'
		}
		default {
			"Unknown result code [$($_)]"
		}
	}
}
function Remove-ScheduledTask {
	<#
		.SYNOPSIS
			This function looks for a scheduled task on a remote system and, once found, removes it.
	
		.EXAMPLE
			PS> Remove-ScheduledTask -ComputerName FOO -Name Task1
		
		.PARAMETER ComputerName
			 A mandatory string parameter representing a FQDN of a remote computer.

		.PARAMETER Name
			 A mandatory string parameter representing the name of the scheduled task. Scheduled tasks can be retrieved
			 by using the Get-ScheduledTask cmdlet.
	#>
	[OutputType([void])]
	[CmdletBinding(SupportsShouldProcess)]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ComputerName,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Name
	)
	process {
		try {
			$icmParams = @{ 'ComputerName' = $ComputerName }
			$icmParams.ArgumentList = $Name
			$icmParams.ErrorAction = 'Ignore'
			
			$sb = { 
				$taskName = "\$($args[0])"
				if (schtasks /query /TN $taskName) {
					schtasks /delete /TN $taskName /F
				}
			}

			if ($PSCmdlet.ShouldProcess("Remove scheduled task [$($Name)] from [$($ComputerName)]", '----------------------')) {
				Invoke-Command @icmParams -ScriptBlock $sb	
			}
		} catch {
			throw $_.Exception.Message
		}
	}
}
function Wait-ScheduledTask {
	<#
		.SYNOPSIS
			This function looks for a scheduled task on a remote system and, once found, checks to see if it's running.
			If so, it will wait until the task has completed and return control.
	
		.EXAMPLE
			PS> Wait-ScheduledTask -ComputerName FOO -Name Task1 -Timeout 120
		
		.PARAMETER ComputerName
			 A mandatory string parameter representing a FQDN of a remote computer.

		.PARAMETER Name
			 A mandatory string parameter representing the name of the scheduled task. Scheduled tasks can be retrieved
			 by using the Get-ScheduledTask cmdlet.

		.PARAMETER Timeout
			 A optional integer parameter representing how long to wait for the scheduled task to complete. By default,
			 it will wait 60 seconds.

		.PARAMETER Credential
			 Specifies a user account that has permission to perform this action. The default is the current user.
			 
			 Type a user name, such as 'User01' or 'Domain01\User01', or enter a variable that contains a PSCredential
			 object, such as one generated by the Get-Credential cmdlet. When you type a user name, you will be prompted for a password.
	
	#>
	[OutputType([void])]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ComputerName,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[int]$Timeout = 300 ## seconds
	)
	process {
		try {
			$session = New-PSSession -ComputerName $ComputerName

			$scriptBlock = {
				$taskName = "\$($args[0])"
				$VerbosePreference = 'Continue'
				$timer = [Diagnostics.Stopwatch]::StartNew()
				while (((schtasks /query /TN $taskName /FO CSV /v | ConvertFrom-Csv).Status -ne 'Ready') -and ($timer.Elapsed.TotalSeconds -lt $args[1])) {
					Write-Verbose -Message "Waiting on scheduled task [$taskName]..."
					Start-Sleep -Seconds 3
				}
				$timer.Stop()
				Write-Verbose -Message "We waited [$($timer.Elapsed.TotalSeconds)] seconds on the task [$taskName]"
			}

			Invoke-Command -Session $session -ScriptBlock $scriptBlock -ArgumentList $Name, $Timeout
		} catch {
			throw $_.Exception.Message
		} finally {
			if (Test-Path Variable:\session) {
				$session | Remove-PSSession
			}
		}
	}
}

Install-WindowsUpdate -ComputerName DC -Verbose
#endregion