#region Revert PSRemoting Changes, Remote Registry Changes & Remote Event Log Management (Necessary for Get-WinEvent)
Disable-PSRemoting -Force
Remove-Item -Path 'WSMan:\Localhost\listener\listener*' -Recurse | Out-Null
Stop-Service WinRM | Set-Service 'WinRM' -StartupType 'Disabled'
Set-NetFirewallRule -DisplayName 'Windows Remote Management (HTTP-In)' -Enabled False
Set-Service -Name 'RemoteRegistry' -StartupType 'Disabled' -PassThru | Stop-Service -Force
Set-NetFirewallRule -DisplayName 'Remote Event Log Management (NP-In)' -Enabled False
Set-NetFirewallRule -DisplayName 'Remote Event Log Management (RPC)' -Enabled False
Set-NetFirewallRule -DisplayName 'Remote Event Log Management (RPC-EPMAP)' -Enabled False
#endregion