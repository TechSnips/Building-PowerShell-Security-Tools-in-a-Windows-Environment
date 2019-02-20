# Pull in creds from PSDefaultParameters
# Read-Host as Secure Value
# Reading encrypted file as credential
# Old way is using ConvertTo-SecureString with AES256, that way you can share the key between users
# New way is creating a cert, stored in both user stores and using Protect-CMSMessage and UnProtect-CMSMessage


$Key = New-Object Byte[] 32
[Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($Key)
$Key | out-file C:\passwords\aes.key

(get-credential).Password | ConvertFrom-SecureString -key (get-content C:\passwords\aes.key) | set-content "C:\Passwords\password.txt"

$password = Get-Content C:\Passwords\password.txt | ConvertTo-SecureString -Key (Get-Content C:\Passwords\aes.key)
$credential = New-Object System.Management.Automation.PsCredential("Luke", $password)

#http://code.avalon-zone.be/cmdlet-aes256-file-encrypt-file-decrypt/
Function Export-EncryptedFile {
    param(
        [string]$InFilePath,
        [string]$OutFilePath,
        [string]$Password
    )
    begin {
        Function Get-SHA256Hash {
            param(
                [string]$inputString
            )
            process {
                [System.Security.Cryptography.SHA256]$SHA256 = [System.Security.Cryptography.SHA256]::Create()
                return $SHA256.ComputeHash([System.Text.ASCIIEncoding]::UTF8.GetBytes($inputString))
            }
        }
    }
    process {
        [System.Security.Cryptography.AesCryptoServiceProvider]$Aes = [System.Security.Cryptography.AesCryptoServiceProvider]::new()
        $Aes.BlockSize = 128
        $Aes.KeySize = 256
        $Aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
        $Aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
        $Aes.GenerateIV()
        [byte[]]$IV = $Aes.IV
        [byte[]]$Key = Get-SHA256Hash -inputString $Password
        [System.IO.FileStream]$FileStreamOut = [System.IO.FileStream]::new($OutFilePath, [System.IO.FileMode]::Create)
        [System.Security.Cryptography.ICryptoTransform]$ICryptoTransform = $Aes.CreateEncryptor($Key, $IV)
        [System.Security.Cryptography.CryptoStream]$CryptoStream = [System.Security.Cryptography.CryptoStream]::new($FileStreamOut, $ICryptoTransform, [System.Security.Cryptography.CryptoStreamMode]::Write)
        [System.IO.FileStream]$FileStreamIn = [System.IO.FileStream]::new($InFilePath, [System.IO.FileMode]::Open)

        $FileStreamOut.Write($IV, 0, $IV.Count)
        $DataAvailable = $true
        [int]$Data

        While ($DataAvailable) {
            $Data = $FileStreamIn.ReadByte()
            if ($Data -ne -1) {
                $CryptoStream.WriteByte([byte]$Data)
            }
            else {
                $DataAvailable = $false
            }
        }

        $FileStreamIn.Dispose()
        $CryptoStream.Dispose()
        $FileStreamOut.Dispose()

    }
}

Export-EncryptedFile -InFilePath "C:\Temp\data.txt" -OutFilePath "C:\Temp\data_cry.txt" -Password "Password"

Function Import-EncryptedFile {
    param(
        [string]$InFilePath,
        [string]$OutFilePath,
        [string]$Password
    )
    begin {
        Function Get-SHA256Hash {
            param(
                [string]$inputString
            )
            process {
                [System.Security.Cryptography.SHA256]$SHA256 = [System.Security.Cryptography.SHA256]::Create()
                return $SHA256.ComputeHash([System.Text.ASCIIEncoding]::UTF8.GetBytes($inputString))
            }
        }
    }
    process {

        [System.IO.FileStream]$FileStreamIn = [System.IO.FileStream]::new($InFilePath, [System.IO.FileMode]::Open)
        [byte[]]$IV = New-Object byte[] 16
        $FileStreamIn.Read($IV, 0, $IV.Length)

        [System.Security.Cryptography.AesCryptoServiceProvider]$Aes = [System.Security.Cryptography.AesCryptoServiceProvider]::new()
        $Aes.BlockSize = 128
        $Aes.KeySize = 256
        $Aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
        $Aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
        [byte[]]$Key = Get-SHA256Hash -inputString $Password


        [System.IO.FileStream]$FileStreamOut = [System.IO.FileStream]::new($OutFilePath, [System.IO.FileMode]::Create)
        [System.Security.Cryptography.ICryptoTransform]$ICryptoTransform = $Aes.CreateDecryptor($Key, $IV)
        [System.Security.Cryptography.CryptoStream]$CryptoStream = [System.Security.Cryptography.CryptoStream]::new($FileStreamIn, $ICryptoTransform, [System.Security.Cryptography.CryptoStreamMode]::Read)

        $DataAvailable = $true
        [int]$Data

        While ($DataAvailable) {

            $Data = $CryptoStream.ReadByte()
            if ($Data -ne -1) {
                $FileStreamOut.WriteByte([byte]$Data)
            }
            else {
                $DataAvailable = $false
            }
        }

        $FileStreamIn.Dispose()
        $CryptoStream.Dispose()
        $FileStreamOut.Dispose()

    }
}

Import-EncryptedFile -InFilePath "C:\Temp\data_cry.txt" -OutFilePath "C:\Temp\data_dec.txt" -Password "Password"