# Create User Accounts for Testing

$Users = @{
    "Joe"      = 'x96JHQmG'
    "Robert"   = 'password'
    "Wilma"    = 'bf2oZFKv'
    "Derrick"  = 'H4JuN9oL'
    "Lynn"     = 'internet'
    "Connie"   = 'ncexe424'
    "Terrence" = 'PrcH6aur'
    "Edna"     = 'banana'
    "Ramona"   = 'k7n7wp8B'
    "Eduardo"  = 'shadow'
}

$Users.GetEnumerator() | ForEach-Object {
    $Params = @{
        "Name"            = $_.Key
        "SamAccountName"  = $_.Key
        "DisplayName"     = $_.Key
        "AccountPassword" = $_.Value
        "Enabled"         = $True
    }

    New-ADUser @Params
}

# Find Users with PASSWD_NOTREQD flag
# Modify Attribute Editor -> userAccountControl = 544 (Enabled, password not required) or 546 (Disabled, password not required)
Get-ADUser 'Joe'  | Set-ADAccountControl -PasswordNotRequired $True
Get-ADUser 'Lynn' | Set-ADAccountControl -PasswordNotRequired $True
Get-ADUser 'Edna' | Set-ADAccountControl -PasswordNotRequired $True