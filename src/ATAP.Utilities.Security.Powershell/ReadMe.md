# ATAP.Utilities.Security.Powershell

## Overview

Powershell scripts for managing an orgaization's computer systems' security


### Public Administration Functions

- Install-VaultsInfrastructure - TBD: for bootstrap hosts. Setup the necessaary infrasructure. Can ansible do it? Yes, after preamble and before securing the communications channel
- Install-ModulesPerComputer (list of modules and list of computers, PSSession to computer -runas 'adminUserid', install list of modules with AllUsers scope) (SecretManagement and three vault extensions)
- New-CACertificateRequest (Production Public-facing computers get a Response from a Commercial 3rd-party. Development, Testing, and Internal computer systems get a Response from an organization's CA server (or shard of a server cluster) internal to the organization)
- Install-CACertificate  - installs the organization's root CA and subordinate CA's trust paths (or shard of trust paths)

- New-SSLCertificateRequest - Creates a request for an certificate to be used to identify the computer, often for HTTPS protocol.
- Install-SSLCertificate - Installs an SSL certificate to the host's CertificateStore. must be provided with a SSL certificate signed by a trusted CA.

- New-CodeSigningCertificateRequest - Creates a request for an certificate to be used sign code to detect tampering
- Install-CodeSigningCertificate - Installs code signing certificate to the host's CertificateStore. must be provided with a code signiing certificate signed by a trusted CA.

- New-DataEncryptionCertificateRequest (in behalf of a specific User on a specific Computer, so must accept 1 user and list of machines, 1 machine and list of users, or hash of computerXusers -value = $Subject
- Install-DataEncryptionCertificate (in behalf of a specific User on a specific Computer, so must accept 1 user and list of machines, 1 machine and list of users, or hash of computerXusers

- New-KeySecureStringFile -path $KeySecureStringFilepath -KeySize 16,24,32
- Update-KeySecurestringFile -path $KeySecureStringFilepath -KeySize 16,24,32

- New-MasterPasswordSecureStringFile -Path $PasswordSecureStringFilePath
- Update-MasterPasswordSecureStringFile -Path $PasswordSecureStringFilePath

- Add-UsersSecretStoreVault (on behalf of a specific User on a specific Computer, so must accept 1 user and list of machines, 1 machine and list of users, or hash of computerXusers -value = $Subject and - $KeySecureStringFilePath $PasswordSecureStringFilePath).  Uses Register-SecretVault, for any of the three vault types, parameter sets

### Public User Functions

- Unlock-UsersSecretVault -Name $name -KeySecureStringFilepath $KeySecureStringFilePath -PasswordSecureStringFilePath OR -Dictionary Thumbprint,encryptedpassword

- List-DataEncryptionCertificates

- List-CodeSigningCertificates
- List-KeySecureStringFiles
- List-MasterPasswordSecureStringFiles

## Attributions

* [Encrypt & Decrypt Data with PowerShell](https://medium.com/@sumindaniro/encrypt-decrypt-data-with-powershell-4a1316a0834b) by Suminda Niroshan
* [Using SecureString in PowerShell (With SecureKey)](https://brainseed.wordpress.com/2016/03/29/using-securestring-in-powershell-with-securekey/)
* [How to encrypt credentials & secure passwords with PowerShell pt 2](https://www.pdq.com/blog/secure-password-with-powershell-encrypting-credentials-part-2/) Kris Powell

