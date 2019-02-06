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