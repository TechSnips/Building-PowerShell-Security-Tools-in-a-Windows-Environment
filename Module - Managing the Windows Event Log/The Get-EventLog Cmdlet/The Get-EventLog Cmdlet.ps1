## Get a list of all of the available event logs on our local system
## Notice no "Applications and Services" event logs
Get-EventLog -List
eventvwr.msc

## List events in a particular event log
Get-EventLog -LogName Security

## Find events in all event logs at once
Get-EventLog -List | ForEach-Object { Get-EventLog -LogName $_.Log }

## Formatting rules do not return the actual properties
Get-EventLog -LogName Security | Select-Object -Property * -First 1

## Object type is System.Diagnostics.EventLogEntry
Get-EventLog -LogName Security | Get-Member


<# We can do remote computers just as easily but ensure you've got a few prereqs set
	- remote registry service
	- firewall port (Set-NetFirewallRule -Name 'RemoteEventLogSvc-In-TCP' -Enabled True)
		Get-NetFirewallRule | where DisplayName -like  '* Event Log*' | Enable-NetFirewallRule

		The three rules that get enabled are:

		Remote Event Log Management (RPC)
		Remote Event Log Management (NP-In)
		Remote Event Log Management (RPC-EPMAP)
#>

Get-EventLog -LogName Security -ComputerName DC

## Enumerating machines in parallell with jobs

