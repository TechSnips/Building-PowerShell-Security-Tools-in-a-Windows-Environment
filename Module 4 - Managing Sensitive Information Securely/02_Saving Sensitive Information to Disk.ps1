# API Keys
# Private Cert Keys
# Import/Export-CLIXml
# Secure Strings, Creating and Decrypting

#region Create Certificate
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
    Subject = "cn=powershellcms@COMPUTER"
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
#endregion

#region Protect Message Using CMS
# Protect Our Content Using our New Certificate
$Protected = 'Text to Encrypt' | Protect-CmsMessage -To "*PSDocumentProtection*"

# Show that the content is encrypted
$Protected

# Get information about the protected certificate
$Protected | Get-CMSMessage

# Read out the content
$Protected | Unprotect-CmsMessage
#endregion

#region Import/Export CLIXML
# Encrypt Data
$Path = "$($Env:USERPROFILE)\Desktop\Credential.xml"
Get-Credential | Export-Clixml -Path $Path

# Show Encrypted Values
Get-Content -Path $Path

# Get Credentials
$Credential = Import-CliXml -Path $Path

$Credential.GetNetworkCredential().Password
#endregion

#region Create Secure Strings
$Path = "$($Env:USERPROFILE)\Desktop\SecureString.txt"

# Save Secure String to a File
'MyAPIKey' | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString | Set-Content -Path $Path

# Show Value is Encrypted
Get-Content -Path $Path

# Retrieve Saved Secure String and Save to a Variable
$SecureString = Get-Content -Path $Path | ConvertTo-SecureString

[Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR((($SecureString))))
#endregion

#region Using AES Key
$AESKeyPath = "$($Env:USERPROFILE)\Desktop\aes.key"
$PassPath   = "$($Env:USERPROFILE)\Desktop\password.txt"

# Use RNGCryptoServiceProvider instead of Get-Random (better random number generator)
# AES is a subset of Rijndael
# AES comes in 3 block sizes of 128, 192 and 256
# AES superseded DES
# Generally let the default encryption do the work for you, setting a fixed Salt (hashing) or IV (encrypting) means every other key you encrypt will be decrypable if one is broken. It's best to let each be unique so that it's more secure.
$Key = [System.Byte[]]::New(32)
[Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($Key)
$Key | Out-File $AESKeyPath

# Get the Password and encrypt with the AES Key
(Get-Credential).Password | ConvertFrom-SecureString -Key (Get-Content $AESKeyPath) | Set-Content -Path $PassPath
Get-Content -Path $PassPath | ConvertTo-SecureString -Key (Get-Content -Path $AESKeyPath)

# Retrieve Password
$SecurePassword = Get-Content $PassPath | ConvertTo-SecureString -Key (Get-Content -Path $AESKeyPath)
$BSTR           = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
$PlainPassword  = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
$PlainPassword
#endregion