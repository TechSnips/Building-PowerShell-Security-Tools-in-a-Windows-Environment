<#
	Scenario:
		- Create a PowerShell script
		- Create a scheduled task on a remote computer to execute PowerShell script
		- Execute scheduled task
#>

#region Creating a local scheduled task to kick off a PowerShell script
$scriptPath = 'C:\CreateFile.ps1'
$testFilePath = 'C:\testing123.txt'
Add-Content -Path $scriptPath -Value "Add-Content -Path $testFilePath -Value 'created via PowerShell'"
Get-Content -Path $scriptPath

## What happens when the script is launched via calling PowerShell from cmd
powershell.exe -NonInteractive -NoProfile -File "$scriptPath"

## Creates the test file
Get-Content -Path $testFilePath

## Remove the test file to create it via the scheduled task
Remove-Item -Path $testFilePath

## Create a scheduled task to launch a script every day

## The test file doesn't exist
Test-Path -Path $testFilePath

$interval = 'Daily'
$time = '12:00'
$taskName = 'Testing 123'
$taskUser = 'SYSTEM'

schtasks /create /SC $interval /ST $time /TN $taskName /TR "powershell.exe -NonInteractive -NoProfile -File `"$scriptPath`"" /F /RU $taskUser /RL HIGHEST

## Check out the task created and run it
control schedtasks

## The test file is back because the scheduled task launched the PowerShell script
Get-Content -Path $testFilePath

#endregion

#region Creating a remote scheduled task to kick off a PowerShell script

## We must wrap all of the code to run on the remote server in a scriptblock
$createStartSb = {

	$interval = 'Daily'
	$time = '12:00'
	$taskName = 'Testing 123'
	$taskUser = 'SYSTEM'

	## Create the PowerShell script which the scheduled task will execute
	$scheduledTaskScriptFolder = 'C:\ScheduledTaskScripts'
	if (-not (Test-Path -Path $scheduledTaskScriptFolder -PathType Container)) {
		$null = New-Item -Path $scheduledTaskScriptFolder -ItemType Directory
	}
	$scriptPath = "$scheduledTaskScriptFolder\CreateScript.ps1"
	Set-Content -Path $scriptPath -Value "Add-Content -Path 'C:\testing123.txt' -Value 'created via PowerShell'"

	## Create the scheduled task
	schtasks /create /SC $interval /ST $time /TN $taskName /TR "powershell.exe -NonInteractive -NoProfile -File `"$scriptPath`"" /F /RU $taskUser /RL HIGHEST
}

## Execute the code in the scriptblock on the remote computer
$scheduledTaskServer = 'DC'
$icmParams = @{
	ComputerName = $scheduledTaskServer
	ScriptBlock  = $createStartSb
}
Invoke-Command @icmParams

## Check out the task created and run it
control schedtasks

## The test file is back because the scheduled task launched the PowerShell script
Get-Content -Path "\\DC\c$\testing123.txt"

#endregion




#region Creating a scheduled task function

## This is where we "parameterize" creating a scheduled task on a remote computer by allowing dynamic
## input like scheduled task name, the contents of the PowerShell script, interval, time, etc. We pass
## in all of this information at run-time.

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
		[ValidateSet('Daily', 'Weekly')] ## This can be other intervals but we're limiting to just these for now
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