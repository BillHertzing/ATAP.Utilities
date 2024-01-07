

# [Encrypt & Decrypt Data with PowerShell](https://medium.com/@sumindaniro/encrypt-decrypt-data-with-powershell-4a1316a0834b) by Suminda Niroshan
# [Using SecureString in PowerShell (With SecureKey)](https://brainseed.wordpress.com/2016/03/29/using-securestring-in-powershell-with-securekey/)
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

Unlock-UsersSecretVault -Name $name -KeySecureStringFilepath $KeySecureStringFilePath -PasswordSecureStringFilePath OR -Dictionary Thumbprint,encryptedpassword

List-DataEncryptionCertificates

List-CodeSigningCertificates
List-KeySecureStringFiles
List-MasterPasswordSecureStringFiles

