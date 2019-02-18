# Setup Variables
$CertINFPath = Join-Path -Path $env:TEMP -ChildPath 'DocumentEncryption.inf'
$CertCERPath = Join-Path -Path $env:TEMP -ChildPath 'DocumentEncryption.inf'

# Create the Certificate INF File
{[Version]
Signature = "$Windows NT$"

[Strings]
szOID_ENHANCED_KEY_USAGE = "2.5.29.37"
szOID_DOCUMENT_ENCRYPTION = "1.3.6.1.4.1.311.80.1"

[NewRequest]
Subject = "cn=powershellcms@SUNPHOENIX"
MachineKeySet = false
KeyLength = 2048
KeySpec = AT_KEYEXCHANGE
HashAlgorithm = Sha1
Exportable = true
RequestType = Cert
KeyUsage = "CERT_KEY_ENCIPHERMENT_KEY_USAGE | CERT_DATA_ENCIPHERMENT_KEY_USAGE"
ValidityPeriod = "Years"
ValidityPeriodUnits = "1000"
FriendlyName = "PowerShellCMS"

[Extensions]
%szOID_ENHANCED_KEY_USAGE% = "{text}%szOID_DOCUMENT_ENCRYPTION%"
} | Out-File -FilePath $CertINFPath -Force

# Import Certificate
certreq.exe -new $CertINFPath $CertCERPath

# Cleanup Temporary Files
@($CertINFPath, $CertCERPath) | Remove-Item -ErrorAction SilentlyContinue

# Create Document Encryption Certificate same as above but via built-in CMDLets
$CertParams = @{
    'Subject'           = 'PSDocumentProtection'
    'CertStoreLocation' = 'Cert:\CurrentUser\My'
    'KeyUsage'          = @('KeyEncipherment', 'DataEncipherment')
    'Type'              = 'DocumentEncryptionCert'
    'KeySpec'           = 'KeyExchange'
    'KeyExportPolicy'   = 'Exportable'
    'KeyLength'         = 2048
    'KeyAlgorithm'      = 'RSA'
    'NotAfter'          = (Get-Date).AddYears(1000)
}

New-SelfSignedCertificate @CertParams

# Protect Our Content Using our New Certificate
$Protected = 'Text to Encrypt' | Protect-CmsMessage -To "*PSDocumentProtection*"

# Show that the content is encrypted
$Protected

# Get information about the protected certificate
$Protected | Get-CMSMessage

# Read out the content
$Protected | Unprotect-CmsMessage

# https://github.com/pshamus/PSKeystore
# Not supporting core
# Install-Module -Name Configuration -RequiredVersion 1.3.0 -Force
# Install-Module -Name PSKeyStore

New-KeystoreAccessGroup -Name 'foo' -CertificateThumbprint 92B8E1A4169853B165F1B0E8F647075A678175F3

using a certificate with Document Encryption extended key usage attribute

Get-KeystoreAccessGroup
Get-KeystoreAccessGroup -Name 'bar' | Set-KeystoreDefaultAccessGroup

New-KeystoreStore -Name 'foo' -Path 'C:\keystore'

Get-KeystoreStore

Initialize-Keystore
#The Self store is fixed to $Env:USERPROFILE\Documents\Keystore


New-KeystoreItem -Name mysecret -SecretValue (Read-Host -AsSecureString)
New-KeystoreItem -Name 'mycred' -Credential (Get-Credential)

(Get-KeystoreItem -Name mysecret).GetSecretValueText()