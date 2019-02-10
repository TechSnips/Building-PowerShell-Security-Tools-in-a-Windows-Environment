#region Querying events on a remote computer by timeframe
$remoteComputer = 'DC'
$startTime = (Get-Date).AddDays(-1)
$endTime = Get-Date
$logNames = (Get-WinEvent -ListLog * -ComputerName $remoteComputer).LogName

$filter = @{ 
	'LogName'   = 'Security'
	'StartTime' = $startTime
	'EndTime'   = $endTime
}
Get-WinEvent -ComputerName $remoteComputer -FilterHashtable $filter
#endregion

#region Function
function Get-EventsByTimeframe {
	param(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string[]]$ComputerName,
        
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[datetime]$StartTime,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[datetime]$EndTime,
        
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string[]]$EventLog,
        
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$OutputFilePath = "$($Env:USERPROFILE)\Desktop\EventLogs.csv"
	)
    
	foreach ($computer in $ComputerName) {
		if (-not $EventLog) {
			Write-Verbose -Message "Enumerating all event logs on [$($computer)]..."
			$logNames = (Get-WinEvent -ListLog * -ComputerName $computer).LogName
			Write-Verbose -Message "Found [$(@($logNames).Count)] event logs on remote computer."
		} else {
			$logNames = $EventLog
		}

		foreach ($log in $logNames) {
			$filter = @{'LogName' = $log}
			if ($StartTime) {
				$filter.StartTime = $StartTimestamp
			}
			if ($EndTime) {
				$filter.EndTime = $EndTimestamp
			}
			$properties = 'TimeCreated', 'ProviderName', 'Id', 'Message', 'LogName'
			Get-WinEvent -ComputerName $computer -FilterHashtable $filter | Tee-Object -FilePath $OutputFilePath
		}
	}
}
#endregion

#region Look at the output file
Import-Csv -Path "$($Env:USERPROFILE)\Desktop\EventLogs.csv"
#endregion