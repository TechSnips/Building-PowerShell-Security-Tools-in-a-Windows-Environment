# Functions
# 1) New-DocumentProtectionCertificate
# 2) Get-DocumentProtectionCertificate
# 3) New-AESKey
# 4) Protect-Item
# 5) Unprotect-Item

#region New-DocumentProtectionCertficate
Function New-DocumentProtectionCertificate {
    <#
		.SYNOPSIS
            To use the CMS cmdlets (Cryptographic Message Syntax), you need a certificate of the type data encipherment. This is because CMS uses public key cryptography.

		.EXAMPLE
			PS> $Certificate = New-DocumentProtectionCertificate -PassThru

        .PARAMETER CertStoreLocation
            Be default this stores in the Cert:\CurrentUser\My location. This path is defined via the Cert provider.
        .PARAMETER Subject
            The subject (common name) of the certificate, by default "PSDocumentProtection".
        .PARAMETER Years
            Number of years the certificate is valid for, by default the current date plus 1000 years.
        .PARAMETER KeyLength
            The key length of the certificate, default is 2048, but allowable range is 1028, 2048 and 4096.
        .PARAMETER PassThru
            Whether or not to pass the resulting certificate details along the pipeline.
	#>
	[OutputType([System.Security.Cryptography.X509Certificates.X509Certificate2])]
    [CmdletBinding()]

    Param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        $CertStoreLocation = 'Cert:\CurrentUser\My',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        $Subject = "PSDocumentProtection",

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [DateTime]$Years = (Get-Date).AddYears(1000),

        [Parameter()]
        [ValidateSet(1028,2048,4096)]
        [Int]$KeyLength = 2048,

        [Switch]$PassThru
    )

    Process {
        $CertParams = @{
            'Subject'           = $Subject
            'CertStoreLocation' = $CertStoreLocation
            'KeyUsage'          = @('KeyEncipherment', 'DataEncipherment')
            'Type'              = 'DocumentEncryptionCert'
            'KeySpec'           = 'KeyExchange'
            'KeyExportPolicy'   = 'Exportable'
            'KeyLength'         = $KeyLength
            'KeyAlgorithm'      = 'RSA'
            'NotAfter'          = $Years
            'ErrorAction'       = 'Stop'
        }

        Try {
            $Result = New-SelfSignedCertificate @CertParams
        } Catch {
            $Error[0]
        }

        If ($PassThru) {
            $Result
        }
    }
}
#endregion

#region Get-DocumentProtectionCertficate
Function Get-DocumentProtectionCertificate {
    <#
		.SYNOPSIS
            Retrieve all document protection certificates in the given cert location limited by thumbprint or subject name.
		.EXAMPLE
			PS> Get-DocumentProtectionCertificate

                PSPath                   : Microsoft.PowerShell.Security\Certificate::CurrentUser\My\A606B289BCA2678456D2C15DD87BDF1655BA1BA1
                PSParentPath             : Microsoft.PowerShell.Security\Certificate::CurrentUser\My
                PSChildName              : A606B289BCA2678456D2C15DD87BDF1655BA1BA1
                PSDrive                  : Cert
                PSProvider               : Microsoft.PowerShell.Security\Certificate
                PSIsContainer            : False
                EnhancedKeyUsageList     : {Document Encryption (1.3.6.1.4.1.311.80.1)}
                DnsNameList              : {PSDocumentProtection}
                SendAsTrustedIssuer      : False
                EnrollmentPolicyEndPoint : Microsoft.CertificateServices.Commands.EnrollmentEndPointProperty
                EnrollmentServerEndPoint : Microsoft.CertificateServices.Commands.EnrollmentEndPointProperty
                PolicyId                 :
                Archived                 : False
                Extensions               : {System.Security.Cryptography.Oid, System.Security.Cryptography.Oid, System.Security.Cryptography.Oid}
                FriendlyName             :
                ...
        .PARAMETER CertLocation
            Be default this stores in the Cert:\CurrentUser\My location. This path is defined via the Cert provider.
        .PARAMETER Subject
            The subject (common name) of the certificate, by default "PSDocumentProtection".
        .PARAMETER Thumbprint
            The thumbprint of the certificate to retrieve.
	#>
    [OutputType([System.Security.Cryptography.X509Certificates.X509Certificate2])]
    [CmdletBinding()]

    Param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        $CertLocation = 'Cert:\CurrentUser\My',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        $Subject = "CN=PSDocumentProtection",

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        $Thumbprint
    )

    Process {
        If ($Thumbprint) {
            $WhereCondition = { $_.Thumbprint -EQ $Thumbprint -And $_.EnhancedKeyUsageList -Match "Document Encryption" }
        } Else  {
            $WhereCondition = { $_.Subject -EQ $Subject -And $_.EnhancedKeyUsageList -Match "Document Encryption" }
        }

        Try {
            Get-ChildItem -Path $CertLocation -ErrorAction 'Stop' | Where-Object $WhereCondition | Select-Object *
        } Catch {
            $Error[0]
        }
    }
}
#endregion

#region New-AESKey
Function New-AESKey {
    <#
		.SYNOPSIS
            To use exported secure strings data but in a portable way you need to create an AES key.
		.EXAMPLE
			PS> New-AESKey

        .PARAMETER Path
            Path where to output the AES key.
	#>
	[OutputType([System.Management.Automation.PSObject])]
    [CmdletBinding()]

    Param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        $Path
    )

    Process {
        $Key = [System.Byte[]]::New(32)
        [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($Key)

        Try {
            $Key | Out-File $Path -ErrorAction 'Stop'
        } Catch {
            $Error[0]
        }
    }
}
#endregion

#region Protect-Item
Function Protect-Item {
    <#
		.SYNOPSIS
            Protect string content on disk via one of three methods, DPAPI (per user, per machine), CMS (public key), AES (shared AES key).
		.EXAMPLE
			PS> "MyPassword" | Protect-Item -Path 'C:\encryptedfile.txt'

        .PARAMETER Content
            String content to encrypt on disk.
        .PARAMETER Path
            Location and filename where to save the encrypted file.
        .PARAMETER Method
            Which encryption method to use, defaults to DPAPI, but one of three types, DPAPI, CMS or AES.
        .PARAMETER Thumbprint
            If using CMS, supply the Thumbprint of the certificate to encrypt the contents with.
        .PARAMETER KeyPath
            If using AES, supply the location of the AES key to encrypt the contents.
	#>
	[OutputType([System.Management.Automation.PSObject])]
    [CmdletBinding()]

    Param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [String]$Content,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        $Path,

        [Parameter()]
        [ValidateSet("CMS","DPAPI","AES")]
        $Method = "DPAPI",

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        $Thumbprint,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        $KeyPath
    )

    Process {
        Switch ($Method) {
            "CMS" {
                If ((Get-Location).Drive -EQ "Cert") {
                    Write-Error "Cannot Encrypt Using a Thumbprint when Location is in Cert Provider"

                    Break
                }

                If (-Not $Thumbprint) {
                    Write-Error "Need to supply a thumbprint to encrypt file using CMS."

                    Break
                }

                $Content | Protect-CmsMessage -To $Thumbprint -OutFile $Path

                Break
            }
            "DPAPI" {
                $Content | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString | Set-Content -Path $Path

                Break
            }
            "AES" {
                If (-Not $KeyPath) {
                    Write-Error "Need to supply an AES key to encrypt file using AES."

                    Break
                }

                $Content | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString -Key (Get-Content $KeyPath) | Set-Content -Path $Path

                Break
            }
        }
    }
}
#endregion

#region Unprotect-Item
Function Unprotect-Item {
    <#
		.SYNOPSIS
            Decrypt previously encrypted data using one of three methods, CMS, AES or DPAPI.
		.EXAMPLE
			PS> Unprotect-Item -Path 'C:\encryptedfile.txt'

        .PARAMETER Path
            The file path to the encrypted content.
        .PARAMETER Method
            The method to use in decryption, defaults to DPAPI, but one of three CMS, DPAPI or AES.
        .PARAMETER Thumbprint
            If using CMS, supply the Thumbprint of the certificate to decrypt the contents with.
        .PARAMETER KeyPath
            If using AES, supply the location of the AES key to decrypt the contents.
	#>
    [OutputType([System.Management.Automation.PSObject])]
    [CmdletBinding()]

    Param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        $Path,

        [Parameter()]
        [ValidateSet("CMS","DPAPI","AES")]
        $Method = "DPAPI",

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        $Thumbprint,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        $KeyPath
    )

    Process {
        Switch ($Method) {
            "CMS" {
                If ((Get-Location).Drive -EQ "Cert") {
                    Write-Error "Cannot Decrypt Using a Thumbprint when Location is in Cert Provider"
                }

                If (-Not $Thumbprint) {
                    Write-Error "Need to supply a thumbprint to encrypt file using CMS."

                    Break
                }

                Get-Content -Path $Path | Unprotect-CmsMessage -To $Thumbprint

                Break
            }
            "DPAPI" {
                $SecureString = Get-Content -Path $Path | ConvertTo-SecureString

                [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR((($SecureString))))

                Break
            }
            "AES" {
                If (-Not $KeyPath -And -Not (Test-Path $KeyPath)) {
                    Write-Error "Need to supply an AES key to encrypt file using AES."

                    Break
                }

                $SecurePassword = Get-Content $Path | ConvertTo-SecureString -Key (Get-Content -Path $KeyPath)
                $BSTR           = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
                $PlainContent   = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

                $PlainContent

                Break
            }
        }
    }
}
#endregion

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