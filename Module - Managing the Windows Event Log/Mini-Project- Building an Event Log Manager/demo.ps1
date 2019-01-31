function Set-MyEventLog { 
	[CmdletBinding(DefaultParameterSetName = 'None')] 
	param 
	( 
		[Parameter(Mandatory)] 
		[string[]]$Name, 
		[Parameter(Mandatory, ParameterSetName = 'Enable')] 
		[switch]$Enable, 
		[Parameter(Mandatory, ParameterSetName = 'Disable')] 
		[switch]$Disable 
	) 
	process { 
		foreach ($evLogName in $Name) { 
			try { 
				if (-not (Test-MyEventLog -Name $evLogName)) { 
					throw "The event log [$($evLogName)] does not exist" 
				} 
				if ($PSBoundParameters.ContainsKey('Enable')) { 
					if ((Get-WinEvent -ListLog $evlogName).IsEnabled) { 
						Write-Verbose -Message "The event log [$($evLogName)] is already enabled" 
					} else { 
						$log = New-Object System.Diagnostics.Eventing.Reader.EventLogConfiguration $evLogName 
						$log.IsEnabled = $true 
						$log.SaveChanges() 
						if (-not (Get-WinEvent -ListLog $evlogName).IsEnabled) { 
							Write-Error -Message "Failed to enable the event log [$($evLogName)]" 
						} else { 
							Write-Verbose -Message "Successfully enabled the event log [$($evLogName)]" 
						} 
					} 
				} elseif ($PSBoundParameters.ContainsKey('Disable')) { 
					if (-not (Get-WinEvent -ListLog $evlogName).IsEnabled) { 
						Write-Verbose -Message "The event log [$($evLogName)] is already disabled" 
					} else { 
						$log = New-Object System.Diagnostics.Eventing.Reader.EventLogConfiguration $evLogName 
						$log.IsEnabled = $false 
						$log.SaveChanges() 
						if ((Get-WinEvent -ListLog $evlogName).IsEnabled) { 
							Write-Error -Message "Failed to disable the event log [$($evLogName)]" 
						} else { 
							Write-Verbose -Message "Successfully disabled the event log [$($evLogName)]" 
						} 
					} 
				} 
			} catch [System.Exception] { 
				Write-Error -Message "$($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)" 
			} 
		} 
	} 
} 
 
function Disable-EventLog { 
	[CmdletBinding()] 
	param ( 
		[Parameter(Mandatory)] 
		[string[]]$Name 
	) 
	begin { 
		Set-StrictMode -Version Latest 
		$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop 
	} 
	process { 
		try { 
			Set-MyEventLog -Name $Name -Disable 
		} catch { 
			Write-Error -Message "$($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)" 
		} 
	} 
} 
 
function Enable-EventLog { 
	[CmdletBinding()] 
	param ( 
		[Parameter(Mandatory)] 
		[string[]]$Name 
	) 
	begin { 
		Set-StrictMode -Version Latest 
		$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop 
	} 
	process { 
		try { 
			Set-MyEventLog -Name $Name -Enable 
		} catch { 
			Write-Error -Message "$($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)" 
		} 
	} 
} 
 
function Save-EventLog { 
	[CmdletBinding()] 
	param ( 
		[Parameter(Mandatory)] 
		[string]$Name, 
		[Parameter(Mandatory)] 
		[ValidateScript({ Test-Path -Path ($_ | Split-Path -Parent) -PathType Container })] 
		[ValidatePattern('.*\.evtx$')] 
		[ValidateNotNullOrEmpty()] 
		[string]$FilePath, 
		[Parameter()] 
		[switch]$Force 
	) 
	begin { 
		Set-StrictMode -Version Latest 
		$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop 
	} 
	process { 
		try { 
			if (Test-Path -Path $filePath -PathType Leaf) { 
				if (-not $Force.IsPresent) { 
					throw "The file [$($filePath)] already exists and -Force was not used" 
				} else { 
					Remove-Item -Path $filePath 
				} 
			} 
			$log = Get-WmiObject -Class 'Win32_nteventlogfile' -Filter "logfilename = '$Name'" 
			$Result = ($log | Invoke-WmiMethod -Name BackupEventlog -ArgumentList $FilePath).ReturnValue 
			if ($Result -ne 0) { 
				throw "The [$($Name)] event log backup failed with exit code [$($Result)]" 
			} else { 
				Write-Verbose -Message "The [$($Name)] event log was successfully backed up"     
			} 
		} catch { 
			Write-Error -Message $_.Exception.Message 
		} 
	} 
}


$ComputerName = 'COMPUTER_NAME', 'COMPUTER_NAME2'

## Specify the timeframe you'd like to search between
$StartTimestamp = [datetime]'1-1-2014 00:00:00'
$EndTimeStamp = [datetime]'1-5-2014 06:00:00'

## Specify in a comma-delimited format which event logs to skip (if any)
$SkipEventLog = 'Microsoft-Windows-TaskScheduler/Operational'

## The output file path of the text file that contains all matching events
$OutputFilePath = 'C:\eventlogs.txt'

## Create the Where filter ahead of time to only get events within the timeframe
$filter = {($_.TimeCreated -ge $StartTimestamp) -and ($_.TimeCreated -le $EndTimeStamp)}

foreach ($c in $ComputerName) {
	## Only get events from included event logs
	if ($SkipEventLog) {
		$op_logs = Get-WinEvent -ListLog * -ComputerName $c | Where {$_.RecordCount -and !($SkipEventLog -contains $_.LogName)}
	} else {
		$op_logs = Get-WinEvent -ListLog * -ComputerName $c | Where {$_.RecordCount}
	}

	## Process each event log and write each event to a text file
	$i = 0
	foreach ($op_log in $op_logs) {
		Write-Progress -Activity "Processing event logs" -status "Processing $($op_log.LogName) event log" -percentComplete ($i / $op_logs.count*100)
		Get-WinEvent $op_log.LogName -ComputerName $c | Where $filter |
			Select @{n='Time'; e={$_.TimeCreated}},
		@{n='Source'; e={$_.ProviderName}},
		@{n='EventId'; e={$_.Id}},
		@{n='Message'; e={$_.Message}},
		@{n='EventLog'; e={$_.LogName}} | Out-File -FilePath $OutputFilePath -Append -Force
		$i++
	}
}