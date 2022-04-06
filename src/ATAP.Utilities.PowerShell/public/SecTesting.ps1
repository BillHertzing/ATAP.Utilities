
# Admin portion for every user
#ToDo move file location to Dropbox vault and invoke Dropbox voodoo to make it accessable in this function/session
$KeyFilePath = "C:/dropbox/whertzing/encryption.key"
$EncryptedPasswordFilePath = "C:/dropbox/whertzing/secret.encrypted"
{
$EncryptionKeyBytes = New-Object Byte[] 32
[Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($EncryptionKeyBytes)
#ToDo: Convert to a securestring before writing to the file
$EncryptionKeyBytes | Out-File $KeyFilePath
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




