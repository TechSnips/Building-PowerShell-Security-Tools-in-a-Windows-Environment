#region Install PSKeyStore
# https://github.com/pshamus/PSKeystore
# Not supporting core
Install-Module -Name Configuration -RequiredVersion 1.3.0 -Force -Scope CurrentUser

$URI  = 'https://github.com/pshamus/PSKeystore/archive/master.zip'
$File = "$env:PROGRAMFILES\WindowsPowerShell\Modules\PSKeyStore.zip"
Invoke-WebRequest -Uri $URI -OutFile $File

Expand-Archive -Path $File -DestinationPath "$env:PROGRAMFILES\WindowsPowerShell\Modules"

Move-Item -Path "$env:PROGRAMFILES\WindowsPowerShell\Modules\PSKeystore-master\PSKeyStore" -Destination "$env:PROGRAMFILES\WindowsPowerShell\Modules"

$RemoveFiles = @(
	'PSKeystore-master'
	'PSKeySTore.zip'
)

$RemoveFiles | Foreach-Object { Remove-Item "$env:PROGRAMFILES\WindowsPowerShell\Modules\$($_)" -Confirm:$False -Force -Recurse }

Import-Module PSKeyStore
#endregion

#region Setup PSKeyStore

## Find the cert we created in this module
$Certificate = Get-ChildItem -Path 'Cert:\CurrentUser\My' | Where-Object Subject -EQ 'CN=PSDocumentProtection' | Select-Object -Last 1

New-KeystoreAccessGroup -Name 'Secrets' -CertificateThumbprint $Certificate.Thumbprint

Get-KeystoreAccessGroup
Get-KeystoreAccessGroup -Name 'Secrets' | Set-KeystoreDefaultAccessGroup

New-Item -Path "$($Env:USERPROFILE)\Desktop\Secrets" -ItemType Directory
New-KeystoreStore -Name 'Secrets' -Path "$($Env:USERPROFILE)\Desktop\Secrets"
Get-KeystoreStore -Name 'Secrets' | Set-KeystoreDefaultStore

## Secrets are stored as KSI files
Get-ChildItem -Path "$($Env:USERPROFILE)\Desktop\Secrets"

#endregion

#region
New-KeystoreItem -Name 'TestSecret' -SecretValue (ConvertTo-SecureString "TestValue" -AsPlainText -Force)

(Get-KeystoreItem -Name 'TestSecret').GetSecretValueText()
#endregion