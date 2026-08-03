# ATAP.Utilities.Security.PKI.PowerShell

Certificate authority, certificate lifecycle, distinguished-name, and protected key-file
functions for ATAP. This is an independently versioned child of the Security module family.

## Safety boundary

Importing this module defines functions and changes nothing. Every private-key, certificate
issuance, certificate-store, and protected-file mutation supports `-WhatIf` and requires a
separately authorized live operation. Private keys, passphrases, PFX passwords, and secret values
must never enter Git, command output, logs, or evidence.

Keep active PKI files beneath `C:\Dropbox\Security\PKI`, with independent `ATAP Foundation` and
`ATAP Consulting` subtrees. CA private keys must remain encrypted at rest with restrictive ACLs;
materialize passphrase files only for the bounded operation that consumes them. Host and
code-signing private keys import into the Windows certificate store as non-exportable. Resolve PFX
passwords by `SecretName` at the installation boundary.

## Public surface

The child owns the eighteen commands formerly exported by `ATAP.Utilities.Security.Powershell`
plus `Install-TrustedPublisherCertificate` for non-interactive publisher trust:

- Distinguished names and paths: `New-DistinguishedNameHash`,
  `Get-DistinguishedNameQualifiedFilePath`.
- Key material: `New-RandomEncryptionKeyToFile`, `New-RandomPassPhraseToFile`,
  `New-EncryptedPasswordFile`, `New-EncryptedPrivateKey`, `Update-KeySecurestringFile`,
  `Update-MasterPasswordSecureStringFile`.
- Requests and issuance: `New-CertificateRequest`, `New-SSLCertificateRequest`,
  `New-DataEncryptionCertificateRequest`, `New-CACertificate`, `New-SignedCertificate`.
- Installation and discovery: `Install-CACertificate`, `Install-SSLCertificate`,
  `Install-CodeSigningCertificate`, `Install-DataEncryptionCertificate`,
  `Install-TrustedPublisherCertificate`, `List-CodeSigningCertificates`.

The umbrella imports this child and re-exports all nineteen names, so existing consumers remain
compatible. `List-CodeSigningCertificates` retains its nonstandard verb because the earlier
architecture decision deferred consumer-facing verb renames.

## Certificate profiles

`CertificateRequestConfigurations/AUdefault.cnf` defines separate CA, Server Authentication,
Code Signing, and Microsoft Document Encryption profiles. Certificate subjects require an explicit
organization, allowing either `ATAP Foundation` or `ATAP Consulting` without hard-coded publisher
identity. TLS requests require SANs and reject a request when `DNS:<CommonName>` is absent. TLS
clients must connect with a SAN identity and must not use chain, common-name, or revocation bypass
switches.

## Operations

Follow [Documentation/PKIForNewOrg.md](Documentation/PKIForNewOrg.md) for CA creation, host and
code-signing issuance, trust-first HTTPS rollout, backup/restore, renewal, revocation, and rollback.
The runbook includes commands as operator-reviewed examples; it is not self-running automation.

## Testing

```powershell
Invoke-Pester -Path './tests/Unit' -Output Minimal
```

Tests use synthetic values and mocks. They do not create a CA, issue a certificate, contact a
vault, change a certificate store, or modify a live endpoint.

## Functional area

Secrets & Security. Start with `SolutionDocumentation/Security-PowerShell-Module-Architecture.md`.
