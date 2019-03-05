# DSInternals Module Method

#region Install DSInternals
Install-Module DSInternals -Force
Import-Module DSInternals
#endregion

#region DSInternals - Report on Weak Passwords
# DSInternals Module Method

$Passwords = "$($ENV:USERProfile)\Desktop\passwords.txt"

$Params = @{
	"All"           = $True
	"Server"        = 'DC'
	"NamingContext" = 'dc=techsnips,dc=local'
}

Get-ADReplAccount @Params | Test-PasswordQuality -WeakPasswordsFile $Passwords -IncludeDisabledAccounts
#endregion

#region Find PASSWD_NOTREQD Accounts

## More information: https://blogs.technet.microsoft.com/pfesweplat/2012/12/10/do-you-allow-blank-passwords-in-your-domain/

## Set a test user to not require a password
Set-ADAccountControl 'jjones' -PasswordNotRequired $true

## Contruct an LDAP filter to return users with the appropriate UAC flag and run Get-AdUser

$Domain = 'dc=techsnips,dc=local'

$Params = @{
	"Properties" = @('name', 'distinguishedname', 'useraccountcontrol', 'objectClass')
	"LDAPFilter" = '(&(userAccountControl:1.2.840.113556.1.4.803:=32)(!(IsCriticalSystemObject=TRUE)))'
	"SearchBase" = $Domain
}

Get-ADUser @Params | Select-Object SamAccountName, Name, UserAccountControl, DistinguishedName

## Remediate the problem
$Users | Foreach-Object { Set-ADAccountControl $_.samAccountName -PasswordNotRequired $false }

## Check again
Get-ADUser @Params | Select-Object SamAccountName, Name, UserAccountControl, DistinguishedName
#endregion

#region Test Password Strength Function
# Testing Password Strength in a Function
# http://www.checkyourlogs.net/?p=38333
Function Test-DomainPassword {
	Param (
		[Parameter(Mandatory)]
		[String]$Password,

		[Parameter(Mandatory, ValueFromPipeline)]
		[Microsoft.ActiveDirectory.Management.ADUser]$UserAccount,

		[Parameter(Mandatory)]
		[Microsoft.ActiveDirectory.Management.ADEntity]$PasswordPolicy
	)

	Process {
		$output = @{
			'Result'        = $true
			'FailureReason' = $null
		}
		if ($Password.Length -LT $PasswordPolicy.MinPasswordLength) {
			$output.FailureReason = "Password under minimum password length: $($PasswordPolicy.MinPasswordLength)"
			$output.Result = $false
		} elseif (($UserAccount.SamAccountName) -And ($Password -match $UserAccount.SamAccountName)) {
			$output.FailureReason = "Password matches SamAccountName"
			$output.Result = $false
		} elseif ($Password -in $UserAccount.samAccountName) {
			$output.FailureReason = 'Password in samAccountName'
			$output.Result = $false
		} elseif ($PasswordPolicy.ComplexityEnabled -eq $true) {
			if (-not ($Password -cmatch "[A-Z\p{Lu}\s]" -And ($Password -cmatch "[a-z\p{Ll}\s]") -And ($Password -match "[\d]") -And ($Password -match "[^\w]"))) {
				$output.FailureReason = 'Password does not meet complexity requirements.'
				$output.Result = $false
			}
		}
		[pscustomobject]$output
	}
}

## Example usage
$pwPolicy = Get-ADDefaultDomainPasswordPolicy -ErrorAction 'SilentlyContinue'
Get-AdUser -Filter '*' | ForEach-Object {
	$userAccount = $_
	$passwords | ForEach-Object {
		$userAccount | Test-DomainPassword -PasswordPolicy $pwPolicy -Password $_
	}
}
#endregion