# Functions
# 1) New-DocumentProtectionCertificate
# 2) Get-DocumentProtectionCertificate
# 3) Protect-Item
# 4) Unprotect-Item

#region New-DocumentProtectionCertficate
Function New-DocumentProtectionCertficate {
	[OutputType([System.Security.Cryptography.X509Certificates.X509Certificate2])]
    [CmdletBinding()]

    Param (
        [Parameter()]
        $CertStoreLocation = 'Cert:\CurrentUser\My',

        [Parameter()]
        $Subject = "PSDocumentProtection",

        [Parameter()]
        $Years = (Get-Date).AddYears(1000),

        [Parameter()]
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
                $Content | Protect-CmsMessage -To ($Thumbprint -Replace '(..(?!$))','$1 ') -OutFile $Path

                Break
            }
            "DPAPI" {
                $Content | ConvertTo-SecureString -AsPlainText -Force | Export-CliXML -Path $Path

                Break
            }
            "AES" {
                If (-Not (Test-Path $KeyPath) -And -Not $Force) {
                    $Key = [System.Byte[]]::New(32)
                    [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($Key)
                    $Key | Out-File $KeyPath
                }

                $Content | ConvertFrom-SecureString -Key (Get-Content $KeyPath) | Set-Content -Path $Path

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
                $Content | Protect-CmsMessage -To ($Thumbprint -Replace '(..(?!$))', '$1 ') -OutFile $Path

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