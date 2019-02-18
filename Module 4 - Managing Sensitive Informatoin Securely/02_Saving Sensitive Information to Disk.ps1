# API Keys
# Private Cert Keys
# Import/Export-CLIXml
# Secure Strings, Creating and Decrypting

# https://docs.microsoft.com/en-us/powershell/module/pkiclient/new-selfsignedcertificate?view=win10-ps
Import-Module PKIClient

New-SelfSignedCertificate -DnsName "www.fabrikam.com", "www.contoso.com" -CertStoreLocation "cert:\LocalMachine\My"
PS C:\> Set-Location -Path "cert:\LocalMachine\My"
PS Cert:\LocalMachine\My> $OldCert = (Get-ChildItem -Path E42DBC3B3F2771990A9B3E35D0C3C422779DACD7)
PS Cert:\LocalMachine\My> New-SelfSignedCertificate -CloneCert $OldCert

PS C:\>New-SelfSignedCertificate -Type Custom -Subject "E=patti.fuller@contoso.com,CN=Patti Fuller" -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.4", "2.5.29.17={text}email=patti.fuller@contoso.com&upn=pattifuller@contoso.com") -KeyUsage DataEncipherment -KeyAlgorithm RSA -KeyLength 2048 -SmimeCapabilities -CertStoreLocation "Cert:\CurrentUser\My"

PS C:\>New-SelfSignedCertificate -Type Custom -Subject "CN=Patti Fuller,OU=UserAccounts,DC=corp,DC=contoso,DC=com" -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.2", "2.5.29.17={text}upn=pattifuller@contoso.com") -KeyUsage DigitalSignature -KeyAlgorithm RSA -KeyLength 2048 -CertStoreLocation "Cert:\CurrentUser\My"

PS C:\>New-SelfSignedCertificate -Type Custom -Subject "CN=Patti Fuller,OU=UserAccounts,DC=corp,DC=contoso,DC=com" -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.2", "2.5.29.17={text}upn=pattifuller@contoso.com") -KeyUsage DigitalSignature -KeyAlgorithm ECDSA_nistP256 -CurveExport CurveName -CertStoreLocation "Cert:\CurrentUser\My"
