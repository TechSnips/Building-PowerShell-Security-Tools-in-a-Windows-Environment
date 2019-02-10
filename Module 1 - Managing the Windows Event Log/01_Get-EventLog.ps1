#region Get-EventLog
Get-EventLog -List
Get-EventLog -LogName Application
#endregion

#region Properties Available
Get-EventLog -LogName Application | Select-Object -Property * -First 1
#endregion

#region Remote Logs

#region Verify PSRemoting, Remote Registry Management & Remote Event Log Management is Enabled
Set-Service -Name 'RemoteRegistry' -StartupType 'Automatic' -PassThru | Start-Service
Enable-PSRemoting -Force
Set-NetFirewallRule -DisplayName 'Remote Event Log Management (NP-In)' -Enabled False
Set-NetFirewallRule -DisplayName 'Remote Event Log Management (RPC)' -Enabled False
Set-NetFirewallRule -DisplayName 'Remote Event Log Management (RPC-EPMAP)' -Enabled False
#endregion

#region Test PSRemoting
$computerName = 'DC'

Test-WSMan -ComputerName $computerName
Invoke-Command -ScriptBlock { $env:COMPUTERNAME } -ComputerName $computerName
Get-Service 'RemoteRegistry' -ComputerName $computerName
#endregion

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