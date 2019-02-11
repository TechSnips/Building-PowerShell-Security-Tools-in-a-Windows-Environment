#region Function
function Export-EventByTimeFrame {
	<#
	.SYNOPSIS
		This script searches a Windows computer for all event specified start and end time.
	.DESCRIPTION
		This script enumerates all event logs within a specified timeframe.
	.EXAMPLE
		PS> .\Export-EventFromTimeframe -StartTime '01-29-2014 13:25:00' -EndTime '01-29-2014 13:28:00' -ComputerName COMPUTERNAME

		This example finds all event log entries between StartTime and EndTime.
	.PARAMETER StartTime
		The earliest date/time you'd like to begin searching for events.
	.PARAMETER EndTime
		The latest date/time you'd like to begin searching for events.
	.PARAMETER Computername
		The name of the remote (or local) computer you'd like to search on.
	.PARAMETER OutputFolderPath
		The path of the folder that will contain the CSV files by computername.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[datetime]$StartTime,
		
		[Parameter(Mandatory)]
		[datetime]$EndTime,
		
		[Parameter()]
		[string[]]$ComputerName = 'localhost',
		
		[Parameter()]
		[string]$OutputFolderPath = '.'
	)
	
	@($ComputerName).foreach({
			$computer = $_
			## Find all of the event logs that contain at least 1 event
			$params = @{ 'ComputerName' = $computer; 'ListLog' = '*' }
			$logNames = (Get-WinEvent @params | Where-Object { $_.RecordCount }).LogName
			Write-Verbose "Found $(@($logNames).Count) event logs to look through."
			$filterTable = @{
				'StartTime' = $StartTime
				'EndTime'   = $EndTime
				'LogName'   = $logNames
			}
			
			## Find all of the events in all of the event logs that are between the start and ending timestamps
			$params = @{
				'ComputerName'    = $computer
				'FilterHashTable' = $filterTable
				'ErrorAction'     = 'Ignore' 
			}
			$events = Get-WinEvent @params
			Write-Verbose "Found $(@($events).Count) total events."

			## Write the events to a CSV file called <ComputerName>.csv
			$csvFilePath = Join-Path -Path $OutputFolderPath -ChildPath "$computer.csv"
			
			$properties = 'ContainerLog', 'TimeCreated', 'ProviderName', 'Id', 'Message'
			## Use the tab delimiter because the Message value will probably have a comma in in
			$events | Sort-Object Time | Select-Object -Property $properties | Export-Csv -Path $csvFilePath -Append -NoTypeInformation -Delimiter "`t"
		})
}

#endregion

$params = @{
	ComputerName     = 'DC', 'WSUS'
	StartTime        = $startTime
	EndTime          = $endTime
	OutputFolderPath = 'C:\EventLogExports'
}
Export-EventByTimeframe @params

#region Look at the output file
Get-ChildItem -Path 'C:\EventLogExports'
Import-Csv -Path 'C:\EventLogExports\DC.csv' -Delimiter "`t" | Select-Object -First 10
#endregion