# INDEX — ATAP.Utilities.Security.Secrets.PowerShell

module: ATAP.Utilities.Security.Secrets.PowerShell
functional-area: Secrets & Security
family-parent: ATAP.Utilities.Security.Powershell
sibling: ATAP.Utilities.Security.PKI.PowerShell (extracted Sprint 0014 Stream E)

## Public functions

| Function | Summary |
| --- | --- |
| `Get-BitWardenCredential` | Retrieves or creates encrypted BitWarden login and unlock credentials for the current user + computer. |
| `Invoke-RotateSecretsATAP` | Rotates the two Bitwarden machine-account access tokens on this host for this identity, from values the operator pastes into labeled prompts. Interactive-only live path; `-WhatIf` runs anywhere. |
| `List-BitwardenSecrets` | Lists secrets held in the Bitwarden vault. |
| `Load-BitwardenBackup` | Restores a Bitwarden vault from an encrypted backup. |
| `New-BitwardenBackup` | Creates an encrypted backup of the Bitwarden vault. |
| `Set-BitWardenSecret` | Creates or updates a Bitwarden vault item. |
| `Sync-BitWardenDedicatedSecrets` | Syncs dedicated secrets into the registered SecretManagement vault. |

## Aliases

| Alias | Target |
| --- | --- |
| `New-BWSecret` | `Set-BitWardenSecret` |
| `Add-BitWardenLogin` | `Set-BitWardenSecret` |
| `Sync-DedicatedSecrets` | `Sync-BitWardenDedicatedSecrets` |

## Private functions

Not exported. Each exists to keep a secret value out of a place it must never reach.

| Function | Summary |
| --- | --- |
| `Get-SecureStringFingerprint` | Length + short SHA-256 prefix of a `SecureString`, so a paste can be confirmed without echoing it. |
| `Test-BWSAccessTokenFormat` | Shape check for a `0.<uuid>.<secret>` bws access token; catches a stale clipboard or a pasted secret *name*. |
| `Test-RotationSessionIsInteractive` | Whether this session can service a `Read-Host` prompt. Fails closed, so the live rotation path can never run in an agent shell or CI. |

## Documentation

| File | Purpose |
| --- | --- |
| `Documentation/Invoke-RotateSecretsATAP.DesignDecisions.md` | Binding design record D1–D8 for the rotation cmdlet (Sprint 0012 Tasks 12.55.a4, 12.55.c). |

## Tests

`tests/Unit/` — Pester 5. All `bw`/`bws`/vault calls and `Read-Host` are mocked; no test ever
rotates a real secret, prompts, or writes a DPAPI file.

| File | Covers |
| --- | --- |
| `SecretsChild.Contract.Tests.ps1` | Module contract: exports, manifest hygiene, no top-level code, logging standards. |
| `Invoke-RotateSecretsATAP.Tests.ps1` | Rotation-set closure, `-WhatIf` writes nothing, non-interactive live path fails terminating, mis-paste guards, read-back verification, no token value in any message. |
