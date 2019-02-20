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