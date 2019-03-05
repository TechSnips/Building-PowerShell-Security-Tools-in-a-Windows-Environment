function New-AdGroupMembershipMonitor {
	[OutputType('pscustomobject')]
	[CmdletBinding()]
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
		[ValidateSet('Daily', 'Weekly')]
		[string]$Interval,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Time,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Name = ("AD Group $GroupName Monitor" -replace ' ', '_')
	)

	$ErrorActionPreference = 'Stop'
	
	## Create a big string with template placeholders that will eventually be the PowerShell script
	## that the scheduled task will execute. We're using |<Placeholder>| strings here to insert
	## code when the function runs.
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
if (-not (Compare-Object -ReferenceObject $previousMembers -DifferenceObject $currentMembers)) {
	|Action|
}
'@

	## Replace the "Action template" code (code that will run when a group membership changes) with
	## the code in $Action and replace the group name with $GroupName
	$monitor = $monitor -replace '\|Action\|', $Action.ToString() -replace '\|GroupName\|', $GroupName
	
	## Create a new scriptblock from the finished code snippet
	$monitor = [scriptblock]::Create($monitor)

	## Pass all of the parameters provided via the function to our custom scheduled task function to
	## quickly create the scheduled task
	$params = @{
		Name         = $Name
		Scriptblock  = $monitor
		Interval     = $Interval
		Time         = $Time
		ComputerName = $ComputerName ## This will be a module-scoped variable in our mini-project
	}
	if ($Schedule.DayOfWeek) {
		$params.DayOfWeek = $Schedule.DayOfWeek
	}
	New-PsScheduledTask @params
	
}

function New-LocalGroupMembershipMonitor {
	[OutputType('pscustomobject')]
	[CmdletBinding()]
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
	New-PsScheduledTask @params
}

function New-AdUserLoginActivityMonitor {
	[OutputType('pscustomobject')]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$UserName,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ComputerName,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[scriptblock]$Action,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('Daily', 'Weekly')]
		[string]$Interval,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Time,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Name = ("AD User $UserName Monitor" -replace ' ', '_')
	)

	$ErrorActionPreference = 'Stop'
	
	## Create a big string with template placeholders that will eventually be the PowerShell script
	## that the scheduled task will execute. We're using |<Placeholder>| strings here to insert
	## code when the function runs.
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
$lastLoginTime = $dates | Sort-Object -Descending | Select-Object -First 1

## Store the last login time for next time
$now = Get-Date -UFormat '%m-%d-%y %H:%M'
$lastLogin = Get-Date $lastLoginTime -UFormat '%m-%d-%y %H:%M'
[pscustomobject]@{
	'CaptureTime'    = $now
	'LastLoginTime'  = $lastLoginTime
} | Export-Csv -Path $monitorStateFilePath -NoTypeInformation -Append

## Compare and report
if ($previousLoginTime -ne $lastLoginTime) {
	|Action|
}
'@

	## Replace the "Action template" code with
	## the code in $Action and replace the group name with $UserName
	$monitor = $monitor -replace '\|Action\|', $Action.ToString() -replace '\|UserName\|', $UserName
	
	## Create a new scriptblock from the finished code snippet
	$monitor = [scriptblock]::Create($monitor)

	## Pass all of the parameters provided via the function to our custom scheduled task function to
	## quickly create the scheduled task
	$params = @{
		Name         = $Name
		Scriptblock  = $monitor
		Interval     = $Interval
		Time         = $Time
		ComputerName = $ComputerName ## This will be a module-scoped variable in our mini-project
	}
	New-PsScheduledTask @params	
}

function New-PsScheduledTask {
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
		[ValidateSet('Daily', 'Weekly', 'Once')] ## This can be other intervals but we're limiting to just these for now
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
		schtasks /create /SC $interval /ST $time /TN `"$taskName`" /TR "powershell.exe -NonInteractive -NoProfile -File `"$scriptPath`"" /F /RU $taskUser /RL HIGHEST
		
	}

	$icmParams = @{
		ComputerName = $ComputerName
		ScriptBlock  = $createStartSb
		ArgumentList = $Name, $Scriptblock.ToString(), $Interval, $Time
	}
	if ($PSBoundParameters.ContainsKey('RunAsCredential')) {
		$icmParams.ArgumentList += $RunAsCredential.UserName	
	} else {
		$icmParams.ArgumentList += 'SYSTEM'
	}
	
	Invoke-Command @icmParams
	
}

function New-FileMonitor {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[string]$FolderPath,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('Changed', 'Created')]
		[string]$EventType,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[switch]$IncludeSubdirectories,

		[Parameter(Mandatory)]
		[ValidateScript({ Test-Path -Path $_ -PathType 'Leaf' })]
		[ValidatePattern('.*\.ps1')]
		[string]$ScriptFilePath
	)
	process {
		try {
			$watcher = New-Object System.IO.FileSystemWatcher
			$watcher.Path = $FolderPath
			$watcher.EnableRaisingEvents = $true
			if ($IncludeSubdirectories.IsPresent) {
				$watcher.IncludeSubdirectories = $true
			}

			## Read the script contents
			$scriptContents = Get-Content -Path $ScriptFilePath -Raw

			## Convert script to scriptblock to pass as Action parameter
			$action = [scriptblock]::Create($scriptContents)

			## Register the event
			$null = Register-ObjectEvent -InputObject $watcher -EventName $EventType -Action $action
		} catch {
			Write-Error $_.Exception.Message	
		}
	}
}