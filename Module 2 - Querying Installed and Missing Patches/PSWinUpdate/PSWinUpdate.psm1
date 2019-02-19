Set-StrictMode -Version Latest


function Stop-Timer {
	[OutputType([System.Diagnostics.Stopwatch])]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[System.Diagnostics.Stopwatch]$Timer
	)
	process {
		try {
			$Timer.Stop()
		} catch {
			$PSCmdlet.ThrowTerminatingError($_)
		}
	}
}

#region function Get-WindowsUpdate
function Get-WindowsUpdate {
	<#
		.SYNOPSIS
			This function retrieves a list of Microsoft updates based on a number of different criteria for a remote
			computer. It will retrieve these updates over a PowerShell remoting session. It uses the update source set
			at the time of query. If it's set to WSUS, it will only return updates that are advertised to the computer
			by WSUS.
	
		.EXAMPLE
			PS> Get-WindowsUpdate -ComputerName FOO

		.PARAMETER ComputerName
			 A mandatory string parameter representing the FQDN of a computer. This is only mandatory is Session is
			 not used.

		.PARAMETER Session
			 A mandatory PSSession parameter representing a PowerShell remoting session created with New-PSSession. This
			 is only mandatory if ComputerName is not used.
		
		.PARAMETER Installed
			 A optional boolean parameter set to either $true or $false depending on if you'd like to filter the resulting
			 updates on this criteria.

		.PARAMETER Hidden
			 A optional boolean parameter set to either $true or $false depending on if you'd like to filter the resulting
			 updates on this criteria.

		.PARAMETER Assigned
			A optional boolean parameter set to either $true or $false depending on if you'd like to filter the resulting
			updates on this criteria.

		.PARAMETER RebootRequired
			A optional boolean parameter set to either $true or $false depending on if you'd like to filter the resulting
			updates on this criteria.
	#>
	[OutputType([System.Management.Automation.PSObject])]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ParameterSetName = 'ByComputerName')]
		[ValidateNotNullOrEmpty()]
		[string]$ComputerName,

		[Parameter(Mandatory, ParameterSetName = 'BySession')]
		[ValidateNotNullOrEmpty()]
		[System.Management.Automation.Runspaces.PSSession]$Session,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('True', 'False')]
		[string]$Installed = 'False',

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('True', 'False')]
		[string]$Hidden,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('True', 'False')]
		[string]$Assigned,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('True', 'False')]
		[string]$RebootRequired
	)
	begin {
		$ErrorActionPreference = 'Stop'
		if (-not $Session) {
			$Session = New-PSSession @sessParams
		}
	}
	process {
		try {
			$criteriaParams = @{}

			## Had to set these to string values because if they're boolean they will have a $false value even if
			## they aren't set.  I needed to check for a $null value.ided
			@('Installed', 'Hidden', 'Assigned', 'RebootRequired').where({ (Get-Variable -Name $_).Value }).foreach({
					$criteriaParams[$_] = if ((Get-Variable -Name $_).Value -eq 'True') {
						$true 
					} else {
						$false 
					}
				})
			$query = NewUpdateCriteriaQuery @criteriaParams
			Write-Verbose -Message "Using the update criteria query: [$($Query)]..."
			SearchWindowsUpdate -Session $Session -Query $query
		} catch {
			throw $_.Exception.Message
		} finally {
			## Only clean up the session if it was generated from within this function. This is because updates
			## are stored in a variable to be used again by other functions, if necessary.
			if (($PSCmdlet.ParameterSetName -eq 'ByComputerName') -and (Test-Path Variable:\session)) {
				$session | Remove-PSSession
			}
		}
	}
}
#endregion function Get-WindowsUpdate

#region function Install-WindowsUpdate
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
						param($ComputerName, $TaskName, $Credential, $ForceReboot)

						$ErrorActionPreference = 'Stop'
						try {
							if (-not (Get-WindowsUpdate -ComputerName $ComputerName)) {
								Write-Verbose -Message 'No updates needed to install. Skipping computer...'
							} else {
								$sessParams = @{ ComputerName = $ComputerName }
                        
								$session = New-PSSession @sessParams

								$scriptBlock = {
									$updateSession = New-Object -ComObject 'Microsoft.Update.Session';
									$objSearcher = $updateSession.CreateUpdateSearcher();
									if ($updates = ($objSearcher.Search('IsInstalled=0'))) {
										$updates = $updates.Updates;

										$downloader = $updateSession.CreateUpdateDownloader();
										$downloader.Updates = $updates;
										$downloadResult = $downloader.Download();
										if ($downloadResult.ResultCode -ne 2) {
											exit $downloadResult.ResultCode;
										}

										$installer = New-Object -ComObject Microsoft.Update.Installer;
										$installer.Updates = $updates;
										$installResult = $installer.Install();
										if ($installResult.RebootRequired) {
											exit 7;
										} else {
											$installResult.ResultCode
										}
									} else {
										exit 6;
									}
								}
                        
								$taskParams = @{
									Session     = $session
									Name        = $TaskName
									Scriptblock = $scriptBlock
								}
								if ($Credential) {
									$taskParams.Credential = $args[2]	
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
							Name                 = "$_ - Windows Update Install"
							ArgumentList         = $blockArgs
							InitializationScript = { Import-Module -Name 'PSWinUpdate' }
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
#endregion function Install-WindowsUpdate

function Get-WindowsUpdateInstallResult {
	[OutputType([string])]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[System.Management.Automation.Runspaces.PSSession]$Session,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$ScheduledTaskName = 'Windows Update Install'
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

function NewUpdateCriteriaQuery {
	[OutputType([string])]
	[CmdletBinding()]
	param
	(
		[Parameter()]
		[bool]$Installed,

		[Parameter()]
		[bool]$Hidden,

		[Parameter()]
		[bool]$Assigned,

		[Parameter()]
		[bool]$RebootRequired
	)

	$conversion = @{
		Installed      = 'IsInstalled'
		Hidden         = 'IsHidden'
		Assigned       = 'IsAssigned'
		RebootRequired = 'RebootRequired'
	}

	$queryElements = @()
	$PSBoundParameters.GetEnumerator().where({ $_.Key -in $conversion.Keys }).foreach({
			$queryElements += '{0}={1}' -f $conversion[$_.Key], [int]$_.Value
		})
	$queryElements -join ' and '
}

function SearchWindowsUpdate {
	[OutputType()]
	[CmdletBinding()]
	param
	(
		[Parameter()]
		[string]$Query,

		[Parameter()]
		[System.Management.Automation.Runspaces.PSSession]$Session
	)

	$scriptBlock = {
		$objSession = New-Object -ComObject 'Microsoft.Update.Session'
		$objSearcher = $objSession.CreateUpdateSearcher()
		if ($updates = ($objSearcher.Search($args[0]))) {
			$updates = $updates.Updates
			## Save the updates needed to the file system for other functions to pick them up to download/install later.
			$updates | Export-CliXml -Path "$env:TEMP\Updates.xml"
			$updates
		}
		
	}
	Invoke-Command -Session $Session -ScriptBlock $scriptBlock -ArgumentList $Query
}

function New-WindowsUpdateScheduledTask {
	[OutputType([void])]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[System.Management.Automation.Runspaces.PSSession]$Session,

		[Parameter(Mandatory)]
		[string]$Name,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[scriptblock]$Scriptblock,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[pscredential]$RunAsCredential
	)

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
	if ($PSBoundParameters.ContainsKey('RunAsCredential')) {
		$icmParams.ArgumentList += $RunAsCredential.UserName	
	} else {
		$icmParams.ArgumentList += 'SYSTEM'
	}
	Write-Verbose -Message "Running code via powershell.exe: [$($command)]"
	Invoke-Command @icmParams
	
}

#region function Wait-WindowsUpdate
function Wait-WindowsUpdate {
	<#
		.SYNOPSIS
			This function looks for any currently running background jobs that were created by Install-WindowsUpdate
			and continually waits for all of them to finish before returning control to the console.
	
		.EXAMPLE
			PS> Wait-WindowsUpdate
		
		.PARAMETER Timeout
			 An optional integer parameter representing the amount of seconds to wait for the job to finish.
	
	#>
	[OutputType([void])]
	[CmdletBinding()]
	param
	(
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[int]$Timeout = 300
	)
	process {
		try {
			if ($updateJobs = (Get-Job -Name '*Windows Update Install*').where({ $_.State -eq 'Running'})) {
				$timer = Start-Timer
				while ((Microsoft.PowerShell.Core\Get-Job -Id $updateJobs.Id | Where-Object { $_.State -eq 'Running' }) -and ($timer.Elapsed.TotalSeconds -lt $Timeout)) {
					Write-Verbose -Message "Waiting for all Windows Update install background jobs to complete..."
					Start-Sleep -Seconds 3
				}
				Stop-Timer -Timer $timer
			}
		} catch {
			throw $_.Exception.Message
		}
	}
}
#endregion function Wait-WindowsUpdate