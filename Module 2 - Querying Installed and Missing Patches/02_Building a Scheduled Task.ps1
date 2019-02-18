#region Creating a scheduled task function
function New-RecurringScheduledTask {
	[OutputType([void])]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ComputerName,

		[Parameter(Mandatory)]
		[string]$Name,

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
		param($taskName, $command, $interval, $time, $taskUser)

		## Create the PowerShell script which the scheduled task will execute
		$scheduledTaskScriptFolder = 'C:\ScheduledTaskScripts'
		if (-not (Test-Path -Path $scheduledTaskScriptFolder -PathType Container)) {
			$null = New-Item -Path $scheduledTaskScriptFolder -ItemType Directory
		}
		$scriptPath = "$scheduledTaskScriptFolder\$taskName.ps1"
		Set-Content -Path $scriptPath -Value $command

		## Create the scheduled task
		schtasks /create /SC $interval /ST $time /TN $taskName /TR "powershell.exe -NonInteractive -NoProfile -File `"$scriptPath`"" /F /RU $taskUser /RL HIGHEST
	}

	$icmParams = @{
		ComputerName = $ComputerName
		ScriptBlock  = $createStartSb
		ArgumentList = $Name, $Scriptblock.ToString(), $Interval, $Time
	}
	if ($PSBoundParameters.ContainsKey('Credential')) {
		$icmParams.ArgumentList += $RunAsCredential.UserName	
	} else {
		$icmParams.ArgumentList += 'SYSTEM'
	}
	Invoke-Command @icmParams
	
}
#endregion