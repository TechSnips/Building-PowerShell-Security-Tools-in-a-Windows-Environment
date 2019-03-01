<#
	Scenario:
		- See what's possible using the knowledge of managing Windows updates with PowerShell
#>

## Our PSWinUpdate module is on our system
Get-Module PSWinUpdate -List

## Find needed updates on a single computer
Get-WindowsUpdate -ComputerName DC -Verbose

## Install needed updates on many computers at once
Install-WindowsUpdate -ComputerName 'DC', 'WSUS' -ForceReboot -AsJob -Verbose

## Review the PSWinUpdate module - built using parallel installation of patches using
## background jobs