## This is where the scheduled tasks will be created on
$script:monitorServer = 'DC'

function New-LocalGroupMembershipMonitor {
	[OutputType('pscustomobject')]
	[CmdletBinding(SupportsShouldProcess)]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$GroupName,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ComputerName,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[scriptblock]$Action,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[pscustomobject]$Schedule
	)

	$ErrorActionPreference = 'Stop'

	$scriptBlock = {
		param($ComputerName, $GroupName)
		Get-LocalGroupMembership -ComputerName $ComputerName -Group $GroupName -ErrorAction Ignore

	}


	
}

function New-AdGroupMembershipMonitor {
	[OutputType('pscustomobject')]
	[CmdletBinding(SupportsShouldProcess)]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$GroupName,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[scriptblock]$Action,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[pscustomobject]$ScheduledTask
	)

	$ErrorActionPreference = 'Stop'

	
}

function New-AdUserMonitor {
	[OutputType('pscustomobject')]
	[CmdletBinding(SupportsShouldProcess)]
	param
	(
		
	)

	$ErrorActionPreference = 'Stop'

	
}

function New-FileMonitor {
	[OutputType('pscustomobject')]
	[CmdletBinding(SupportsShouldProcess)]
	param
	(
		
	)

	$ErrorActionPreference = 'Stop'

	
}

function Get-Monitor {
	[OutputType('pscustomobject')]
	[CmdletBinding()]
	param
	(
		
	)

	$ErrorActionPreference = 'Stop'

	
}

function Get-MonitorSchedule {
	[OutputType('pscustomobject')]
	[CmdletBinding(SupportsShouldProcess)]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('Daily', 'Weekly')]
		[string]$Interval,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Time,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday')]
		[string]$DayOfWeek
	)

	$ErrorActionPreference = 'Stop'

	[pscustomobject]@{
		Interval  = $Interval
		Time      = $Time
		DayOfWeek = $DayOfWeek
	}
	
}

function New-RecurringScheduledTask {
	[OutputType([void])]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ComputerName,

		[Parameter(Mandatory)]
		[string]$ScheduledTaskName,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[scriptblock]$Scriptblock,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('Daily', 'Weekly')] ## This can be other intervals
		[string]$Interval,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Time,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday')]
		[string]$DayOfWeek,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[pscredential]$RunAsCredential
	)

	$createStartSb = {
		$taskName = $args[0]
		$command = $args[1] -replace '"', '\"'
		$taskUser = $args[2]
		$interval = $args[3]
		$time = $args[4]

		schtasks /create /SC $interval /ST $time /TN $taskName /TR "powershell.exe -NonInteractive -NoProfile -EncodedCommand $encodedCommand" /F /RU $taskUser /RL HIGHEST
	}

	$command = $Scriptblock.ToString()
	$codeBytes = [System.Text.Encoding]::Unicode.GetBytes($command)
	$encodedCommand = [Convert]::ToBase64String($codeBytes)

	$icmParams = @{
		ComputerName = $ComputerName
		ScriptBlock  = $createStartSb
		ArgumentList = $ScheduledTaskName, $encodedCommand, $Interval, $Time
	}
	if ($PSBoundParameters.ContainsKey('Credential')) {
		$icmParams.ArgumentList += $RunAsCredential.UserName	
	} else {
		$icmParams.ArgumentList += 'SYSTEM'
	}
	Write-Verbose -Message "Running code via powershell.exe: [$($command)]"
	Invoke-Command @icmParams
	
}