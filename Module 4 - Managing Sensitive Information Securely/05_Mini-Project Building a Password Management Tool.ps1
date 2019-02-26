# Functions
# 1) New-DocumentProtectionCertificate
# 2) Get-DocumentProtectionCertificate
# 3) New-AESKey
# 4) Protect-Item
# 5) Unprotect-Item

#region New-DocumentProtectionCertficate
Function New-DocumentProtectionCertificate {
	[OutputType([System.Security.Cryptography.X509Certificates.X509Certificate2])]
    [CmdletBinding()]

    Param (
        [Parameter()]
        $CertStoreLocation = 'Cert:\CurrentUser\My',

        [Parameter()]
        $Subject = "PSDocumentProtection",

        [Parameter()]
        [DateTime]$Years = (Get-Date).AddYears(1000),

        [Parameter()]
        [ValidateSet("1028","2048","4096")]
        $KeyLength = 2048,

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
            'KeyLength'         = 2048
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
Function Get-DocumentProtectionCertficate {
    [OutputType([System.Security.Cryptography.X509Certificates.X509Certificate2])]
    [CmdletBinding()]

    Param (
        [Parameter()]
        $CertLocation = 'Cert:\CurrentUser\My',

        [Parameter()]
        $Subject = "CN=PSDocumentProtection",

        [Parameter()]
        $Thumbprint
    )

    Process {
        If ($Thumbprint) {
            $WhereCondition = { $_.Thumbprint -EQ $Thumbprint }
        } Else  {
            $WhereCondition = { $_.Subject -EQ $Subject }
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
	[OutputType([System.Management.Automation.PSObject])]
    [CmdletBinding()]

    Param (
        [Parameter(Mandatory, ValueFromPipeline)]
        $Path
    )

    Process {
        $Key = [System.Byte[]]::New(32)
        [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($Key)
        $Key | Out-File $Path
    }
}
#endregion

#region Protect-Item
Function Protect-Item {
	[OutputType([System.Management.Automation.PSObject])]
    [CmdletBinding()]

    Param (
        [Parameter(Mandatory, ValueFromPipeline)]
        $Content,

        [Parameter(Mandatory)]
        $Path,

        [Parameter()]
        [ValidateSet("CMS","DPAPI","AES")]
        $Method = "DPAPI",

        [Parameter()]
        $Thumbprint,

        [Parameter()]
        $KeyPath,

        [Switch]$Force
    )

    Process {
        Switch ($Method) {
            "CMS" {
                If ((Get-Location).Drive -EQ "Cert") {
                    Write-Error "Cannot Encrypt Using a Thumbprint when Location is in Cert Provider"
                }

                $Content | Protect-CmsMessage -To $Thumbprint -OutFile $Path

                Break
            }
            "DPAPI" {
                $Content | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString | Set-Content -Path $Path

                Break
            }
            "AES" {
                $Content | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString -Key (Get-Content $KeyPath) | Set-Content -Path $Path

                Break
            }
        }
    }
}
#endregion

#region Unprotect-Item
Function Unprotect-Item {
    [OutputType([System.Management.Automation.PSObject])]
    [CmdletBinding()]

    Param (
        [Parameter(Mandatory)]
        $Path,

        [Parameter()]
        [ValidateSet("CMS","DPAPI","AES")]
        $Method = "DPAPI",

        $Thumbprint,

        $KeyPath
    )

    Process {
        Switch ($Method) {
            "CMS" {
                If ((Get-Location).Drive -EQ "Cert") {
                    Write-Error "Cannot Decrypt Using a Thumbprint when Location is in Cert Provider"
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

Get-DocumentProtectionCertficate | Select-Object Subject, Thumbprint

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