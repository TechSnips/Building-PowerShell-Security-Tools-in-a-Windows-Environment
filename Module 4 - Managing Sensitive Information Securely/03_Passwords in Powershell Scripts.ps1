# Pull in creds from PSDefaultParameters
# Read-Host as Secure Value
# Reading encrypted file as credential
# Old way is using ConvertTo-SecureString with AES256, that way you can share the key between users
# New way is creating a cert, stored in both user stores and using Protect-CMSMessage and UnProtect-CMSMessage
# Registry


New-Item –Path "HKCU:" –Name CustomCredentials
New-ItemProperty -Path "HKCU:\CustomCredentials" -Name "Cred1" -Value "Password" -PropertyType "String"
