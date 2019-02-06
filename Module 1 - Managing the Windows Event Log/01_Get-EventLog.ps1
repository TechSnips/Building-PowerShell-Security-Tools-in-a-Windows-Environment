#region Get-EventLog
Get-EventLog -List
Get-EventLog -LogName Application
#endregion

#region Properties Available
Get-EventLog -LogName Application | Select-Object -Property * -First 1
#endregion

#region Remote Computers Logs
Get-EventLog -LogName Application -ComputerName 'DC'
#endregion

#region Speed Test
$time = Measure-Command {
	$results = Get-EventLog -LogName Application -Newest 10000
}

$time.TotalSeconds

$time = Measure-Command {
	$results = Get-EventLog -LogName Application -ComputerName DC -Newest 10000
}

$time.TotalSeconds
#endregion