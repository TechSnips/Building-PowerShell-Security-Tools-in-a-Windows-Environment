## Taking local group changes, functionizing and applying that logic to AD groups





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