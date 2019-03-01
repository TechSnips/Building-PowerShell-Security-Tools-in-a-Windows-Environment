<#
	Scenario: 
		- Taking local group changes, functionizing and applying that logic to AD groups
		- Create a "template" string of code that will be the PowerShell the scheduled task executes
		- Replace all of the template variables at run-time
		- Create a remote scheduled task with the created code snippet
#>

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
if (Compare-Object -ReferenceObject $previousMembers -DifferenceObject $currentMembers) {
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

## Example usage
## Action code can be anything.

## Ensure the text file that will store monitor states is gone
Remove-Item -Path '\\DC\c$\ADGroupMembers.csv'

$action = {
	$now = Get-Date -UFormat '%m-%d-%y %H:%M'
	[pscustomobject]@{
		'Time'    = $now
		'Members' = 'Membership changed!'
	} | Export-Csv -Path 'C:\DomainAdminGroupChanges.csv' -NoTypeInformation -Append
}

$params = @{
	GroupName = 'Domain Admins'
	Action    = $action
	Interval  = 'Daily'
	Time      = '12:00'
}
New-AdGroupMembershipMonitor @params

## Start the scheduled task manually to invoke the monitor
Invoke-Command -ComputerName DC -ScriptBlock {Start-ScheduledTask -TaskName 'AD_Group_Domain_Admins_Monitor' }

## Add an object to Domain Admins
dsa.msc

## Check the monitor states and notifications text files
Import-Csv -Path '\\DC\c$\ADGroupMembers.csv'
Import-Csv -Path '\\DC\c$\DomainAdminGroupChanges.csv'