@{
	RootModule        = 'PasswordManagement.psm1'
	ModuleVersion     = '0.1'
	GUID              = '4c449a9c-9904-4521-ac4b-007d9d1a709d'
	Author            = 'Adam Bertram'
	CompanyName       = 'Adam the Automator, LLC'
	Copyright         = '(c) 2019 Adam the Automator, LLC. All rights reserved.'
	Description       = 'A PowerShell module to securely manage secrets.'
	PowerShellVersion = '5.0'
	FunctionsToExport = @(
		'New-DocumentProtectionCertificate'
		'Get-DocumentProtectionCertificate'
		'New-AESKey'
		'Protect-Item'
		'Unprotect-Item'
	)
	PrivateData       = @{
		PSData = @{
			Tags = @('Passwords', 'Encryption')
		}
	}
}