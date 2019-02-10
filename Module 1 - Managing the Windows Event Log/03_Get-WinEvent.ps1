#region List Logs
Get-WinEvent -ListLog *
Get-EventLog -List
Get-WinEvent -ListLog Security | Format-List -Property *
#endregion

#region Comparing with Get-EventLog

## Remote
Measure-Command {
	$null = Get-EventLog -LogName Application -ComputerName 'DC'
}

Measure-Command {
	$null = Get-WinEvent -LogName Application -ComputerName 'DC'
}

## Local

Measure-Command {
	$null = Get-EventLog -LogName Application
}

Measure-Command {
	$null = Get-WinEvent -LogName Application
}
#endregion

#region List Providers
Get-WinEvent -ListProvider * | Select-Object -Property Name
(Get-WinEvent -ListProvider Microsoft-Windows-GroupPolicy).Events | Format-Table ID, Description -AutoSize
#endregion

#region Returned Object Types
(Get-WinEvent -LogName Application)[0].GetType()
(Get-EventLog -LogName Application)[0].GetType()
#endregion

#region Get Events
Get-WinEvent -LogName Security -MaxEvents 50

Get-WinEvent -LogName Security -MaxEvents 50 |
	Select-Object TimeCreated, ProviderName, Id, Message |
	Format-Table -AutoSize

## Using Get-WinEvent to query offline event logs
$logFile = Get-CimInstance -Class Win32_NTEventlogFile -Filter "LogFileName = 'System'"
$cimMethodParams = @{
	MethodName = 'BackupEventLog'
	Arguments  = @{ 'ArchiveFileName' = 'C:\ApplicationEventLog.evtx' }
}
$logFile | Invoke-CimMethod @cimMethodParams

Get-WinEvent -Path 'C:\ApplicationEventLog.evtx'
#endregion