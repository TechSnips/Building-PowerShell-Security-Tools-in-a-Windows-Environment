## I've collected all of the functions we've built in this module into a single script
ise '.\06_Module_Functions.ps1'

## I've wrapped some of the code we've been working with into other functions
## New-FileMonitor and New-LocalGroupMembershipMonitor

## Let's create a proper PowerShell module with these functions
<#
	1. Move all functions into PSM1 file.
	2. "Generalize" as many common variables as possible and share them across the module (scheduled task server).
	3. Create comment-based help
	4. Move the PowerShell to a place where PowerShell see it.
	5. Create a monitor using a module function.
#>

$schedule = Get-MonitorSchedule -Interval Daily -Time '12:00'
New-AdGroupMembershipMonitor -GroupName 'Domain Admins' -Action { Send-Email ..... } -Schedule $schedule