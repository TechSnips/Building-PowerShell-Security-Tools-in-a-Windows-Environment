#region Examples
$AESPath = "$($Env:USERPROFILE)\Desktop\AES.key"
New-AESKey -Path $AESPath

$Certificate = New-DocumentProtectionCertificate -PassThru

Get-DocumentProtectionCertificate | Select-Object Subject, Thumbprint

$DPAPIPassPath = "$($Env:USERPROFILE)\Desktop\DPAPI.txt"
$CMSPassPath   = "$($Env:USERPROFILE)\Desktop\CMS.txt"
$AESPassPath   = "$($Env:USERPROFILE)\Desktop\AES.txt"

"MyPasswordDPAPI" | Protect-Item -Path $DPAPIPassPath
Unprotect-Item -Path $DPAPIPassPath

"MyPasswordCMS" | Protect-Item -Path $CMSPassPath -Method CMS -Thumbprint $Certificate.Thumbprint
Unprotect-Item -Path $CMSPassPath -Thumbprint $Certificate.Thumbprint -Method CMS

"MyPasswordAES" | Protect-Item -Path $AESPassPath -Method AES -KeyPath $AESPath
Unprotect-Item -Path $AESPassPath -KeyPath $AESPath -Method AES
#endregion