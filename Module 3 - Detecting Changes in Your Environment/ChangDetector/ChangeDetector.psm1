#requires -Module ActiveDirectory

## This is where the scheduled tasks will be created on
$script:monitorServer = 'DC'

function New-LocalGroupMembershipMonitor {
	<#
		.SYNOPSIS
			This function creates a PowerShell script to query the group membership of a local group and creates a
			scheduled task on a server defined via a module-scoped variable.
	
		.EXAMPLE
			PS> $schedule = Get-MonitorSchedule -Interval Daily -Time '12:00'
			PS> $params = @{
			>>>		GroupName = 'Administrators'
			>>>		ComputerName = 'SRV1'
			>>>		Action = {Send-MailMessage -To "User01 <user01@example.com>" -From "User02 <user02@example.com>" -Subject "Test mail"}
			>>>		Schedule = $schedule
			PS> }
			PS> New-LocalGroupMembershipMonitor @params

			This example creates a PowerShell script with code to send an email to user01@example.com and a scheduled task
			called "SRV1_Local_Group_Administrators_Monitor" on the module-scoped server name. The scheduled task runs
			every day at 12PM and sends an email if the Administrators group members changes.

		.PARAMETER GroupName
			 A mandatory string parameter representing the local group to monitor for membership changes.

		.PARAMETER ComputerName
			 A mandatory string parameter representing the computer the local group is on.
		.PARAMETER Action
			 A mandatory scriptblock parameter representing the code to create the PowerShell script with.
		.PARAMETER Schedule
			 A mandatory pscustomobject parameter representing the interval, time and/or day of week parameters
			 to create the scheduled task with.
		.PARAMETER Name
			 An optional string parameter representing the name of the scheduled task to create. If no value
			 is specified, it will create a scheduled task with name "$ComputerName_Local_Group_$GroupName_Monitor".
	
	#>
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
		[pscustomobject]$Schedule,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Name = ("$ComputerName Local Group $GroupName Monitor" -replace ' ', '_')
	)

	$ErrorActionPreference = 'Stop'

	$monitor = @'
## The CSV file that will hold the past states
$monitorStateFilePath = 'C:\LocalGroupMembers.csv'

## Get the latest previously stored list of members
$previousMembers = $null
$previousMembers = Import-Csv -Path $monitorStateFilePath | Sort-Object -Property {[datetime]$_.Time} -Descending | Select-Object -First 1 | Select-Object -ExpandProperty Members

## Split the string to create a member array to compare with output of Get-AdGroupMember
$previousMembers = $previousMembers -split ','

## Get the current members
$scriptBlock = {
	Get-LocalGroupMembership -Group '|GroupName|' -ErrorAction Ignore
}
$currentMembers = Invoke-Command -ComputerName |ComputerName| -Scriptblock $scriptBlock

## Store the member list for next time
$now = Get-Date -UFormat '%m-%d-%y %H:%M'
[pscustomobject]@{
	'Time'    = $now
	'Members' = $currentMembers -join ','
} | Export-Csv -Path $monitorStateFilePath -NoTypeInformation -Append

## Compare and report
if (Compare-Object -ReferenceObject $previousMembers -DifferenceObject $currentMembers) {
	|Action|
}
'@
	$monitor = $monitor -replace '\|Action\|', $Action.ToString() -replace '\|GroupName\|', $GroupName -replace '\|ComputerName\|'
	$monitor = [scriptblock]::Create($monitor)

	$params = @{
		Name         = $Name
		Scriptblock  = $monitor
		Interval     = $Schedule.Interval
		Time         = $Schedule.Time
		ComputerName = $script:monitorServer
	}
	if ($Schedule.DayOfWeek) {
		$params.DayOfWeek = $Schedule.DayOfWeek
	}
	New-RecurringScheduledTask @params
}

function New-AdGroupMembershipMonitor {
	<#
		.SYNOPSIS
			This function creates a PowerShell script to query the group membership of an Active Directory group and creates a
			scheduled task on a server defined via a module-scoped variable.
	
		.EXAMPLE
			PS> $schedule = Get-MonitorSchedule -Interval Daily -Time '12:00'
			PS> $params = @{
			>>>		GroupName = 'Domain Admins'
			>>>		Action = {Send-MailMessage -To "User01 <user01@example.com>" -From "User02 <user02@example.com>" -Subject "Test mail"}
			>>>		Schedule = $schedule
			PS> }
			PS> New-AdGroupMembershipMonitor @params

			This example creates a PowerShell script with code to send an email to user01@example.com and a scheduled task
			called "AD_Group_Domain_Admins_Monitor" on the module-scoped server name. The scheduled task runs
			every day at 12PM and sends an email if the Domain Admins group members changes.

		.PARAMETER GroupName
			 A mandatory string parameter representing the AD group to monitor for membership changes.
		.PARAMETER Action
			 A mandatory scriptblock parameter representing the code to create the PowerShell script with.
		.PARAMETER Schedule
			 A mandatory pscustomobject parameter representing the interval, time and/or day of week parameters
			 to create the scheduled task with.
		.PARAMETER Name
			 An optional string parameter representing the name of the scheduled task to create. If no value
			 is specified, it will create a scheduled task with name "AD_Group_$GroupName_Monitor".
	
	#>
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
		[pscustomobject]$Schedule,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Name = ("AD Group $GroupName Monitor" -replace ' ', '_')
	)

	$ErrorActionPreference = 'Stop'

	$monitor = @'
## The CSV file that will hold the past states
$monitorStateFilePath = 'C:\ADGroupMembers.csv'

## Get the latest previously stored list of members
$previousMembers = $null
$previousMembers = Import-Csv -Path $monitorStateFilePath | Sort-Object -Property {[datetime]$_.Time} -Descending | Select-Object -First 1 | Select-Object -ExpandProperty Members

## Split the string to create a member array to compare with output of Get-AdGroupMember
$previousMembers = $previousMembers -split ','

## Get the current members
$currentMembers = Get-AdGroupMember -Identity '|GroupName|' | Select-Object -ExpandProperty name

## Store the member list for next time
$now = Get-Date -UFormat '%m-%d-%y %H:%M'
[pscustomobject]@{
	'Time'    = $now
	'Members' = $currentMembers -join ','
} | Export-Csv -Path $monitorStateFilePath -NoTypeInformation -Append

## Compare and report
if (Compare-Object -ReferenceObject $previousMembers -DifferenceObject $currentMembers) {
	|Action|
}
'@
	$monitor = $monitor -replace '\|Action\|', $Action.ToString() -replace '\|GroupName\|', $GroupName
	$monitor = [scriptblock]::Create($monitor)

	$params = @{
		Name         = $Name
		Scriptblock  = $monitor
		Interval     = $Schedule.Interval
		Time         = $Schedule.Time
		ComputerName = $script:monitorServer
	}
	if ($Schedule.DayOfWeek) {
		$params.DayOfWeek = $Schedule.DayOfWeek
	}
	New-RecurringScheduledTask @params
	
}

function New-AdUserLoginMonitor {
	<#
		.SYNOPSIS
			This function creates a PowerShell script to query last logon time of an Active Directory user and creates a
			scheduled task on a server defined via a module-scoped variable.
	
		.EXAMPLE
			PS> $schedule = Get-MonitorSchedule -Interval Daily -Time '12:00'
			PS> $params = @{
			>>>		UserName = 'priv_user'
			>>>		Action = {Send-MailMessage -To "User01 <user01@example.com>" -From "User02 <user02@example.com>" -Subject "Test mail"}
			>>>		Schedule = $schedule
			PS> }
			PS>New-AdUserLoginMonitor @params

			This example creates a PowerShell script with code to send an email to user01@example.com and a scheduled task
			called "AD_User_priv_user_Login_Monitor" on the module-scoped server name. The scheduled task runs
			every day at 12PM and sends an email if the priv_user user has logged in since the last run.

		.PARAMETER UserName
			 A mandatory string parameter representing the AD user to monitor login for.
		.PARAMETER Action
			 A mandatory scriptblock parameter representing the code to create the PowerShell script with.
		.PARAMETER Schedule
			 A mandatory pscustomobject parameter representing the interval, time and/or day of week parameters
			 to create the scheduled task with.
		.PARAMETER Name
			 An optional string parameter representing the name of the scheduled task to create. If no value
			 is specified, it will create a scheduled task with name "AD_User_$UserName_Login_Monitor".
	
	#>
	[OutputType('pscustomobject')]
	[CmdletBinding(SupportsShouldProcess)]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$UserName,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[scriptblock]$Action,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[pscustomobject]$Schedule,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Name = ("AD User $UserName Login Monitor" -replace ' ', '_')	
	)

	$ErrorActionPreference = 'Stop'

	$monitor = @'
## The CSV file that will hold the past states
$monitorStateFilePath = 'C:\ADUser.csv'

## Get the latest previously stored list of members
$previousLoginTime = $null
$previousLoginTime = Import-Csv -Path $monitorStateFilePath | Sort-Object -Property {[datetime]$_.CaptureTime} -Descending | Select-Object -First 1 | Select-Object -ExpandProperty LastLogin

## Get the user's last login
$dcs = Get-ADDomainController | Select-Object -ExpandProperty HostName

## Have to query all DCs since this LastLogon isn't replicated
$dates = @()
foreach ($dc in $dcs) {
	$dates += Get-ADUser -Filter "samAccountName -eq '|UserName|'" -Properties LastLogonDate | Select-Object -ExpandProperty LastLogonDate
}

## Find the latest one
$lastLoginTime = $dates | Sort-Object -Descending -First 1

## Store the last login time for next time
$now = Get-Date -UFormat '%m-%d-%y %H:%M'
[pscustomobject]@{
	'CaptureTime'    = $now
	'LastLoginTime'  = $lastLoginTime
} | Export-Csv -Path $monitorStateFilePath -NoTypeInformation -Append

## Compare and report
if ($previousLoginTime -ne $lastLoginTime) {
	|Action|
}
'@
	$monitor = $monitor -replace '\|Action\|', $Action.ToString() -replace '\|UserName\|', $UserName
	$monitor = [scriptblock]::Create($monitor)

	$params = @{
		Name         = $Name
		Scriptblock  = $monitor
		Interval     = $Schedule.Interval
		Time         = $Schedule.Time
		ComputerName = $script:monitorServer
	}
	if ($Schedule.DayOfWeek) {
		$params.DayOfWeek = $Schedule.DayOfWeek
	}
	New-RecurringScheduledTask @params
}

function New-FileMonitor {
	<#
	.SYNOPSIS
		This function creates a file monitor (permanent WMI event consumer)
	.PARAMETER Name
    	The name of the file monitor.  This will be the name of both the WMI event filter
		and the event consumer.
	.PARAMETER MonitorInterval
		The number of seconds between checks
	.PARAMETER FolderPath
		The complete path of the folder you'd like to monitor
	.PARAMETER ScriptFilePath
		The Powershell script that will execute if a file is detected in the folder
	.PARAMETER VbsScriptFilePath
		When the monitor is triggered it's impossible to execute a Powershell script directly.  A VBS script must be executed instead.
		This function will create the VBS automatically but it must be placed somewhere.  This is the file path to where the VBS
		script will be created.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[string]$Name,

		[Parameter(Mandatory)]
		[string]$MonitorInterval,

		[Parameter(Mandatory)]
		[string]$FolderPath,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('Modification', 'Creation')]
		[string]$EventType,

		[Parameter(Mandatory)]
		[ValidateScript({ Test-Path -Path $_ -PathType 'Leaf' })]
		[ValidatePattern('.*\.ps1')]
		[string]$ScriptFilePath,

		[ValidatePattern('.*\.vbs')]
		[string]$VbsScriptFilePath = "$($env:TEMP)\FileMonitor.vbs"
	)
	process {
		try {
			## Create the event query to monitor only the folder we want.  Also, set the monitor interval
			## to something like 10 seconds to check the folder every 10 seconds.
			$WmiEventFilterQuery = @'
SELECT * FROM __Instance{0}Event WITHIN {1}
WHERE targetInstance ISA 'CIM_DirectoryContainsFile'
and TargetInstance.GroupComponent = 'Win32_Directory.Name="{2}"'
'@ -f $EventType, $MonitorInterval, ($FolderPath -replace '\\+$').Replace('\', '\\')
			
			## Subscribe to the WMI event using the WMI filter query created above
			$WmiFilterParams = @{
				'Class'     = '__EventFilter'
				'Namespace' = 'root\subscription'
				'Arguments' = @{ Name = $Name; EventNameSpace = 'root\cimv2'; QueryLanguage = 'WQL'; Query = $WmiEventFilterQuery }
			}
			Write-Verbose -Message "Creating WMI event filter using query '$WmiEventFilterQuery'"
			$WmiEventFilterPath = Set-WmiInstance @WmiFilterParams
			
			## Create the VBS script that will then call the Powershell script.  A VBscript is needed since
			## WMI events cannot auto-trigger another PowerShell script.
			$VbsScript = "
				Set objShell = CreateObject(`"Wscript.shell`")`r`n
				objShell.run(`"powershell.exe -NonInteractive -NoProfile -WindowStyle Hidden -executionpolicy bypass -file `"`"$ScriptFilePath`"`"`")
			"
			Set-Content -Path $VbsScriptFilePath -Value $VbsScript
			
			## Create the WMI event consumer which will actually consume the event
			$WmiConsumerParams = @{
				'Class'     = 'ActiveScriptEventConsumer'
				'Namespace' = 'root\subscription'
				'Arguments' = @{ Name = $Name; ScriptFileName = $VbsScriptFilePath; ScriptingEngine = 'VBScript' }
			}
			Write-Verbose -Message "Creating WMI consumer using script file name $VbsScriptFilePath"
			$WmiConsumer = Set-WmiInstance @WmiConsumerParams
			
			$WmiFilterConsumerParams = @{
				'Class'     = '__FilterToConsumerBinding'
				'Namespace' = 'root\subscription'
				'Arguments' = @{ Filter = $WmiEventFilterPath; Consumer = $WmiConsumer }
			}
			Write-Verbose -Message "Creating WMI filter consumer using filter $WmiEventFilterPath"
			Set-WmiInstance @WmiFilterConsumerParams | Out-Null
		} catch {
			Write-Error $_.Exception.Message	
		}
	}
}

function Get-MonitorSchedule {
	<#
		.SYNOPSIS
			This is a helper function to easily pass parameters to create a scheduled task for the main functions.
	
		.EXAMPLE
			PS> Get-MonitorSchedule -Interval Daily -Time '12:00'

				Interval Time  DayOfWeek
				-------- ----  ---------
				Daily    12:00

		.PARAMETER Interval
			 A mandatory string parameter representing the time interval to run a scheduled task. This parameter is limited
			 to either Daily or Weekly.
		.PARAMETER Time
			 A mandatory string parameter representing the time to run a scheduled task at.
		.PARAMETER DayOfWeek
			 A optional string parameter representing the day of the week to run a weekly scheduled task at.
			 Options are 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'.
	
	#>
	[OutputType('pscustomobject')]
	[CmdletBinding()]
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
	<#
		.SYNOPSIS
			This function creates a scheduled task on a remote server that executes a PowerShell script
	
		.EXAMPLE
			PS> New-RecurringScheduledTask -ComputerName SRV1 -ScheduledTaskName 'Foo' -Scriptblock { Write-Host 'foo' } -Interval 'Daily' -Time '12:00'

		.PARAMETER ComputerName
			 A mandatory string parameter representing the remote computer to create the scheduled task on.
		.PARAMETER ScheduledTaskName
			 A mandatory string parameter representing the name of the scheduled task to create.
		.PARAMETER Scriptblock
			 A mandatory scriptblock parameter representing the PowerShell code which will be used to create a PowerShell
			 script on $ComputerName.
		.PARAMETER Interval
			 A mandatory string parameter representing the time interval to run a scheduled task. This parameter is limited
			 to either Daily or Weekly.
		.PARAMETER Time
			 A mandatory string parameter representing the time to run a scheduled task at.
		.PARAMETER DayOfWeek
			 An optional string parameter representing the day of the week to run a weekly scheduled task at.
			 Options are 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'.
		.PARAMETER RunAsCredential
			 An optional pscredential parameter representing the user to run the scheduled task under. If this
			 parameter is not used, the scheduled task will run under SYSTEM.
	
	#>
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