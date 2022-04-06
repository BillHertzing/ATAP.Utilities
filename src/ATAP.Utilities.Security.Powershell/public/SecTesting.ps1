
# Admin portion for every user
#ToDo move file location to Dropbox vault and invoke Dropbox voodoo to make it accessable in this function/session
$KeyFilePath = "C:/dropbox/whertzing/encryption.key"
$EncryptedPasswordFilePath = "C:/dropbox/whertzing/secret.encrypted"
{
$EncryptionKeyBytes = New-Object Byte[] 32
[Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($EncryptionKeyBytes)
#ToDo: Convert to a securestring before writing to the file
$EncryptionKeyBytes |list-C Out-File $KeyFilePath
}

# pass in initial password, when batchd/pipelined for a list of users
$PasswordSecureStringInput = Read-Host -AsSecureString

{
# ToDo import KeyFilePath contents as a secure key
$EncryptionKeyData = Get-Content $KeyFilePath
# ToDo change -key to -securekey
$PasswordSecureStringInput | ConvertFrom-SecureString -Key $EncryptionKeyData | Out-File -FilePath $EncryptedPasswordFilePath
}

# Use this function to get the PasswordSecureStringFromPersistence
$EncryptionKeyData = Get-Content $KeyFilePath
$PasswordSecureStringFromPersistence = Get-Content $EncryptedPasswordFilePath | ConvertTo-SecureString -Key $EncryptionKeyData
$PlainTextPasswordFromPersistence = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($PasswordSecureStringFromPersistence))

# Register Vault


$PasswordSecureStringFromPersistence2 = Get-Content $EncryptedPasswordFilePath | ConvertTo-SecureString -Key $EncryptionKeyData
$PlainTextPasswordFromPersistence2 = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($PasswordSecureStringFromPersistence))

if ($PlainTextPasswordFromPersistence  -eq $PlainTextPasswordFromPersistence2) {"They ARE Equal"}

# [Encrypt & Decrypt Data with PowerShell](https://medium.com/@sumindaniro/encrypt-decrypt-data-with-powershell-4a1316a0834b) by Suminda Niroshan
#[Using SecureString in PowerShell (With SecureKey)](https://brainseed.wordpress.com/2016/03/29/using-securestring-in-powershell-with-securekey/)
# [How to encrypt credentials & secure passwords with PowerShell pt 2](https://www.pdq.com/blog/secure-password-with-powershell-encrypting-credentials-part-2/) Kris Powell


Security Module
Public Admin Functions
Install-ModulesPerComputer (list of modules and list of computers, PSSession to computer -runas 'adminUserid', install list of modules with AllUsers scope) (SecretManagement and three vault extensions)
New-CACertificateRequest (Production Public-facing computers get a Response from a Commercial 3rd-party, Development, Testing, and Internal computer systems Response from a CA server (or backup) internal to the organization)
Install-CACertificate

New-SSLCertificateRequest
Install-SSLCertificate

New-CodeSigningCertificateRequest
Install-CodeSigningCertificate

New-DataEncryptionCertificateRequest (in behalf of a specific User on a specific Computer, so must accept 1 user and list of machines, 1 machine and list of users, or hash of computerXusers -value = $Subject
Install-DataEncryptionCertificate (in behalf of a specific User on a specific Computer, so must accept 1 user and list of machines, 1 machine and list of users, or hash of computerXusers

New-KeySecureStringFile -path $KeySecureStringFilepath -KeySize 16,24,32
Update-KeySecurestringFile -path $KeySecureStringFilepath -KeySize 16,24,32

New-MasterPasswordSecureStringFile -Path $PasswordSecureStringFilePath
Update-MasterPasswordSecureStringFile -Path $PasswordSecureStringFilePath

Add-UsersSecretStoreVault (in behalf of a specific User on a specific Computer, so must accept 1 user and list of machines, 1 machine and list of users, or hash of computerXusers -value = $Subject and - $KeySecureStringFilePath $PasswordSecureStringFilePath
 Uses Register-SecretVault, for any of the three vault types, paramter sets

Public User Functions

Unlock-UsersSecretStore -Name $name -KeySecureStringFilepath $KeySecureStringFilePath -PasswordSecureStringFilePath OR -Dictionary Thumbprint,encryptedpassword

List-DataEncryptionCertificates

List-CodeSigningCertificates
List-KeySecureStringFiles
List-MasterPasswordSecureStringFiles

