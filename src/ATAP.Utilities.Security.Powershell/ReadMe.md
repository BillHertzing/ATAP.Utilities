# ATAP.Utilities.Security.Powershell

## Overview

Powershell scripts for managing an organization's computer systems' security

> **Module family (Sprint 0012, Task 12.55.b).** This module is now the **umbrella** of the
> `ATAP.Utilities.Security.*` family and runs in **re-export mode**.
>
> | Module | Contents | Status |
> | --- | --- | --- |
> | `ATAP.Utilities.Security.Powershell` | This module. Residual functions + re-exports the Secrets and PKI children. | Umbrella |
> | `ATAP.Utilities.Security.Secrets.PowerShell` | The six Bitwarden functions + 3 aliases. | Pilot child, extracted |
> | `ATAP.Utilities.Security.PKI.PowerShell` | Eighteen certificate, PKI, DN, and protected key-file functions. | Extracted, Sprint 0014 Stream E |
>
> `Get-BitWardenCredential`, `List-BitwardenSecrets`, `Load-BitwardenBackup`,
> `New-BitwardenBackup`, `Set-BitWardenSecret`, and `Sync-BitWardenDedicatedSecrets` **moved** to
> the Secrets child. The umbrella imports the child and re-exports them, so
> `Import-Module ATAP.Utilities.Security.Powershell` still resolves all of them and the command
> surface is unchanged (28 functions, verified before/after).
>
> Three non-function scripts were moved **out of `public/`** because the `.psm1` dot-sources every
> `public/*.ps1` at import and these executed at import time:
>
> | Was | Now | Why |
> | --- | --- | --- |
> | `public/SecretVaultTesting.ps1` | `Documentation/SecretVaultTesting.ps1.txt` | Prompted for a password, echoed it in plaintext, and ran `Get-SecretVault \| Unregister-SecretVault` on import. |
> | `public/Test-SecretVault.ps1` | `Documentation/Test-SecretVault.ps1.txt` | Declared no function; dot-sourced three absolute **stable-worktree** paths, including itself. |
> | `public/PKIForNewOrg.ps1` | `Documentation/PKIForNewOrg.ps1.txt` | Declared no function; executed top-level code at import, writing to the user root certificate store. |
>
> All three were phantom entries in `FunctionsToExport` (listed, never defined) and have been
> removed from it. `Test-SecretVault` at runtime resolves to the
> `Microsoft.PowerShell.SecretManagement` cmdlet, which is what `Sync-BitWardenDedicatedSecrets`
> actually calls. `PKIForNewOrg.ps1.txt` is preserved verbatim as the input to the
> PKI child `Documentation/PKIForNewOrg.md` runbook conversion (completed in Sprint 0014 Stream E).

> **Status (Sprint 9, Task 9.15):** This module is an early-stage prototype and is **not yet
> releasable**. A read-only shortcomings assessment + revise/complete plan is at
> [_generated/Security/Task-9.15-SecurityPowershell-GapAssessment.md](../../_generated/Security/Task-9.15-SecurityPowershell-GapAssessment.md).
> The `PKIForNewOrg.ps1` import-time hazard called out by that assessment was resolved in
> Sprint 0012 Task 12.55.c (moved to `Documentation/PKIForNewOrg.ps1.txt`), but the exported
> The PKI implementation now lives in `ATAP.Utilities.Security.PKI.PowerShell`; import remains
> mutation-free, and live certificate-store or CA operations remain separately authorized.
>
> **Git SSL status (Sprint 9, Task 9.16):** Remote Git over HTTPS is restored for
> this workstation by setting user/global `http.sslBackend=schannel`, overriding
> the system Git for Windows `openssl` backend that could not validate the remote
> chain through Git's bundled CA bundle. The org-root PEM bundle path remains
> deferred to Task 9.17 after the module is import-safe.

### Public Administration Functions

- Install-VaultsInfrastructure - TBD: for bootstrap hosts. Setup the necessary infrastructure. Can ansible do it? Yes, after preamble and before securing the communications channel
- Install-ModulesPerComputer (list of modules and list of computers, PSSession to computer -runas 'adminUserid', install list of modules with AllUsers scope) (SecretManagement and three vault extensions)
- New-CACertificateRequest (Production Public-facing computers get a Response from a Commercial 3rd-party. Development, Testing, and Internal computer systems get a Response from an organization's CA server (or shard of a server cluster) internal to the organization)
- Install-CACertificate - installs the organization's root CA and subordinate CA's trust paths (or shard of trust paths)

- New-SSLCertificateRequest - Creates a request for an certificate to be used to identify the computer, often for HTTPS protocol.
- Install-SSLCertificate - Installs an SSL certificate to the host's CertificateStore. must be provided with a SSL certificate signed by a trusted CA.

- New-CodeSigningCertificateRequest - Creates a request for an certificate to be used sign code to detect tampering
- Install-CodeSigningCertificate - Installs code signing certificate to the host's CertificateStore. must be provided with a code signing certificate signed by a trusted CA.

- New-DataEncryptionCertificateRequest (in behalf of a specific User on a specific Computer, so must accept 1 user and list of machines, 1 machine and list of users, or hash of computerXusers -value = $Subject
- Install-DataEncryptionCertificate (in behalf of a specific User on a specific Computer, so must accept 1 user and list of machines, 1 machine and list of users, or hash of computerXusers

- New-KeySecureStringFile -path $KeySecureStringFilepath -KeySize 16,24,32
- Update-KeySecurestringFile -path $KeySecureStringFilepath -KeySize 16,24,32

- New-MasterPasswordSecureStringFile -Path $PasswordSecureStringFilePath
- Update-MasterPasswordSecureStringFile -Path $PasswordSecureStringFilePath

- Add-UsersSecretStoreVault (on behalf of a specific User on a specific Computer, so must accept 1 user and list of machines, 1 machine and list of users, or hash of computerXusers -value = $Subject and - $KeySecureStringFilePath $PasswordSecureStringFilePath). Uses Register-SecretVault, for any of the three vault types, parameter sets

### Public User Functions

- Unlock-UsersSecretVault -Name $name -KeySecureStringFilepath $KeySecureStringFilePath -PasswordSecureStringFilePath OR -Dictionary Thumbprint,encryptedpassword

- List-DataEncryptionCertificates

- List-CodeSigningCertificates
- List-KeySecureStringFiles
- List-MasterPasswordSecureStringFiles

## Attributions

- [Encrypt & Decrypt Data with PowerShell](https://medium.com/@sumindaniro/encrypt-decrypt-data-with-powershell-4a1316a0834b) by Suminda Niroshan
- [Using SecureString in PowerShell (With SecureKey)](https://brainseed.wordpress.com/2016/03/29/using-securestring-in-powershell-with-securekey/)
- [How to encrypt credentials & secure passwords with PowerShell pt 2](https://www.pdq.com/blog/secure-password-with-powershell-encrypting-credentials-part-2/) Kris Powell
## 5-Tier Module Flow

Use the module-level getting started guide for the lifecycle workflow:

- [Documentation/GettingStarted.md](Documentation/GettingStarted.md)

## Functional area

Secrets & Security - START HERE: SolutionDocumentation\Security Shift-Left.md (link-up added 2026-07-07, Sprint 0012 Task 12.46.f)
