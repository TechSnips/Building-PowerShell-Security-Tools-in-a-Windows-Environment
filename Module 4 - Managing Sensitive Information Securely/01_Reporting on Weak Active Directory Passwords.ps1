# placeholder

# DSInternals Module Method
Import-Module DSInternals

$DictFile = "C:\pass\passlist.txt"
$DC = "DomainController"
$Domain = "DC=domain,DC=local"
$Dict = Get-Content $DictFile | ConvertTo-NTHashDictionary

Get-ADReplAccount -All -Server $DC -NamingContext $Domain | Test-PasswordQuality -WeakPasswordHashes $Dict -ShowPlainTextPasswords -IncludeDisabledAccounts

# Normal AD Method
[void][system.reflection.assembly]::LoadWithPartialName('System.DirectoryServices.AccountManagement')
$Searcher = [adsisearcher]''
$Searcher.Filter = '(&(objectclass=user) (objectcategory=person))'
$Searcher.PageSize = 500
$Searcher.FindAll() | ForEach-Object -Begin {
    $DS = New-Object System.DirectoryServices.AccountManagement.PrincipalContext('domain')
} -Process {
    if ($DS.ValidateCredentials($_.properties.samaccountname, 'password')) {
        New-Object -TypeName PSCustomObject -Property @{
            samaccountname = -join $_.properties.samaccountname
            ldappath       = $_.path
            weakpassword   = $true
        }
    }
}

# Find Users with PASSWD_NOTREQD flag
# Modify Attribute Editor -> userAccountControl = 544 (Enabled, password not required) or 546 (Disabled, password not required)

# Create admin folder
New-Item -Path c:\admin -ItemType directory -force
# Get domain dn
$domainDN = get-addomain | select -ExpandProperty DistinguishedName
# Save pwnotreq users to txt
Get-ADUser -Properties Name, distinguishedname, useraccountcontrol, objectClass -LDAPFilter "(&(userAccountControl:1.2.840.113556.1.4.803:=32)(!(IsCriticalSystemObject=TRUE)))" -SearchBase "$domainDN" | select SamAccountName, Name, useraccountcontrol, distinguishedname >C:\admin\PwNotReq.txt
# Output pwnotreq users in grid view
Get-ADUser -Properties Name, distinguishedname, useraccountcontrol, objectClass -LDAPFilter "(&(userAccountControl:1.2.840.113556.1.4.803:=32)(!(IsCriticalSystemObject=TRUE)))" -SearchBase "$domainDN" | select SamAccountName, Name, useraccountcontrol, distinguishedname | Out-GridView

# To Fix
Set-ADAccountControl $user -PasswordNotRequired $false

# Testing Password Strength in a Function
# http://www.checkyourlogs.net/?p=38333
Function Test-PasswordForDomain {
    Param (
        [Parameter(Mandatory=$true)][string]$Password,
        [Parameter(Mandatory=$false)][string]$AccountSamAccountName = "",
        [Parameter(Mandatory=$false)][string]$AccountDisplayName,
        [Microsoft.ActiveDirectory.Management.ADEntity]$PasswordPolicy = (Get-ADDefaultDomainPasswordPolicy -ErrorAction SilentlyContinue)
    )
<#
    Rest of the code in the blog goes here
#>
    return $false
}

    return $false
}

If ($Password.Length -lt $PasswordPolicy.MinPasswordLength) {
    return $false
}

if (($AccountSamAccountName) -and ($Password -match "$AccountSamAccountName")) {
    return $false
}

if ($AccountDisplayName) {
    $tokens = $AccountDisplayName.Split(",.-,_ #`t")
    foreach ($token in $tokens) {
        if (($token) -and ($Password -match "$token")) {
            return $false
        }
    }
}

    if ($PasswordPolicy.ComplexityEnabled -eq $true) {
        If (
                 ($Password -cmatch "[A-Z\p{Lu}\s]") `
            -and ($Password -cmatch "[a-z\p{Ll}\s]") `
            -and ($Password -match "[\d]") `
            -and ($Password -match "[^\w]")
        ) {
            return $true
        }
    } else {
        return $false
    }