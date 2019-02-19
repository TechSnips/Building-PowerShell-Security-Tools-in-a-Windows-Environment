<#
	Scenario:
		- See what's possible using the knowledge of managing Windows updates with PowerShell
#>

## Import a pre-created custom module
Import-Module '.\PSWinUpdate\PSWinUpdate.psm1'

## Find needed updates on a single computer
Get-WindowsUpdate -ComputerName DC -Verbose

## Install needed updates on many computers at once
Install-WindowsUpdate -ComputerName 'DC', 'WSUS' -ForceReboot -Verbose

## Review the PSWinUpdate module - built using parallel installation of patches using
## background jobs