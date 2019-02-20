# DSInternals Module Method

#region Install DSInternals
Install-Module DSInternals -Force
Import-Module DSInternals
#endregion

#region DSInternals - Report on Weak Passwords
# DSInternals Module Method
$NTLMPasswordHashes = "$($Env:USERPROFILE)\Desktop\passwords.txt" | ConvertTo-NTHashDictionary

$Params = @{
    "All"           = $True
    "Server"        = 'DC'
    "NamingContext" = 'dc=techsnips,dc=local'
}

Get-ADReplAccount @Params | Test-PasswordQuality -WeakPasswordHashesFile $NTLMPasswordHashes -IncludeDisabledAccounts
#endregion

# Normal AD Method
[Void][System.Reflection.Assembly]::LoadWithPartialName('System.DirectoryServices.AccountManagement')

$Searcher = [ADSISearcher]''

$Searcher.Filter   = '(&(objectclass=user) (objectcategory=person))'
$Searcher.PageSize = 500

$Searcher.FindAll() | ForEach-Object
-Begin {
    $DS        = New-Object System.DirectoryServices.AccountManagement.PrincipalContext('domain')
    $Passwords = Get-Content -Path "$($Env:USERPROFILE)\Desktop\passwords.txt"
}
-Process {
    $Account = $_

    $Passwords | ForEach-Object {
        $Password = $_

        If ($DS.ValidateCredentials($Account.properties.samaccountname, $Password)) {
            [PSCustomObject]@{
                'SamAccountName' = $Account.properties.samaccountname
                'LDAPPath'       = $Account.path
                'WeakPassword'   = $True
            }

            Return
        }
    }
}

#region Find PASSWD_NOTREQD Acconts
$Domain = 'dc=techsnips,dc=local'

# Save pwnotreq users to txt
$Params = @{
    "Properties" = @('name', 'distinguishedname', 'useraccountcontrol', 'objectClass')
    "LDAPFilter" = '(&(userAccountControl:1.2.840.113556.1.4.803:=32)(!(IsCriticalSystemObject=TRUE)))'
    "SearchBase" = $Domain
}

$Users = Get-ADUser @Params | Select-Object SamAccountName, Name, UserAccountControl, DistinguishedName
$Users | Out-GridView

$Users | Foreach-Object { Set-ADAccountControl $_.Name -PasswordNotRequired $False }
#endregion

#region Test Password Strength Function
# Testing Password Strength in a Function
# http://www.checkyourlogs.net/?p=38333
Function Test-DomainPassword {
    Param (
        [Parameter(Mandatory)]
        [String]$Password,

        [Parameter(Mandatory)]
        [String]$Account,

        [Microsoft.ActiveDirectory.Management.ADEntity]$PasswordPolicy = (Get-ADDefaultDomainPasswordPolicy -ErrorAction SilentlyContinue)
    )

    Process {
        $Account = Get-ADUser $Account

        If ($Account) {
            If ($Password.Length -LT $PasswordPolicy.MinPasswordLength) {
                Write-Warning "Password under minimum password length: $($PasswordPolicy.MinPasswordLength)"
                Return $False
            }

            If (($Account.SamAccountName) -And ($Password -match $Account.SamAccountName)) {
                Write-Warning "Password matches SamAccountName"
                Return $False
            }

            If ($Account.DisplayName) {
                $tokens = ($Account.DisplayName).Split(",.-,_ #`t")

                Foreach ($token In $tokens) {
                    If (($token) -And ($Password -Match "$token")) {
                        Write-Warning "Username is contained within Password"
                        Return $False
                    }
                }
            }

            If ($PasswordPolicy.ComplexityEnabled -eq $true) {
                If (
                    ($Password -cmatch "[A-Z\p{Lu}\s]") `
                    -And ($Password -cmatch "[a-z\p{Ll}\s]") `
                    -And ($Password -match "[\d]") `
                    -And ($Password -match "[^\w]")
                ) {
                    Return $True
                }
            } Else {
                Return $False
            }
        }
    }
}
#endregion