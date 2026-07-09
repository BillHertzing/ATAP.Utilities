# INDEX — ATAP.Utilities.Security.Secrets.PowerShell

module: ATAP.Utilities.Security.Secrets.PowerShell
functional-area: Secrets & Security
family-parent: ATAP.Utilities.Security.Powershell
sibling: ATAP.Utilities.Security.PKI.PowerShell (not yet extracted)

## Public functions

| Function | Summary |
| --- | --- |
| `Get-BitWardenCredential` | Retrieves or creates encrypted BitWarden login and unlock credentials for the current user + computer. |
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

None.

## Documentation

| File | Purpose |
| --- | --- |
| `Documentation/Invoke-RotateSecretsATAP.DesignDecisions.md` | Design record for the forthcoming rotation cmdlet (Sprint 0012 Task 12.55.a4). |

## Tests

`tests/Unit/` — smoke/contract Pester 5 tests. All `bw` and vault calls mocked.
