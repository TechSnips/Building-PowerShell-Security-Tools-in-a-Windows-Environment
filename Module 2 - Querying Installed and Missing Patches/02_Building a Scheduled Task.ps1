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
		param($taskName, $command, $interval, $time, $taskUser)

		schtasks /create /SC $interval /ST $time /TN "$taskName" /TR "powershell.exe -NonInteractive -NoProfile -EncodedCommand $command" /F /RU $taskUser /RL HIGHEST
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
#endregion