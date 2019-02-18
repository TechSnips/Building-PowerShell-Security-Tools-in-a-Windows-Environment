@{
	RootModule        = 'ChangeDetector.psm1'
	ModuleVersion     = '0.1'
	GUID              = '07568efd-c905-417a-b38f-564b347db7f3'
	Author            = 'Adam Bertram'
	CompanyName       = 'Adam the Automator, LLC'
	Copyright         = '(c) 2019 Adam the Automator, LLC. All rights reserved.'
	Description       = 'A PowerShell module to easily create various monitors in a Windows environment.'
	PowerShellVersion = '5.0'
	FunctionsToExport = @(
		'New-LocalGroupMembershipMonitor'
		'New-AdGroupMembershipMonitor'
		'New-AdUserLoginMonitor'
		'New-FileMonitor'
		'Get-MonitorSchedule'
	)
	PrivateData       = @{
		PSData = @{
			Tags = @('ActiveDirectory', 'WMIEvents')
		}
	}
}