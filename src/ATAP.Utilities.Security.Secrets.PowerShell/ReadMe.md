# ATAP.Utilities.Security.Secrets.PowerShell

Bitwarden and secrets-vault functions for ATAP.

## Functional area

**Secrets & Security.** See the "Secrets & Security" START-HERE document in
`SolutionDocumentation/`.

This module is the **pilot child** of the `ATAP.Utilities.Security.*` module family. It was
extracted from the monolith `ATAP.Utilities.Security.Powershell` under Sprint 0012 Task 12.55.b,
following `_Planning/InformationForTheFuture/PlanPowerShellSecurityReorganization.md`.

## Family layout

| Module | Contents | Status |
| --- | --- | --- |
| `ATAP.Utilities.Security.Powershell` | Umbrella. Residual functions + **re-exports this child** for backward compatibility. | Existing |
| `ATAP.Utilities.Security.Secrets.PowerShell` | **This module.** Bitwarden functions today. | Pilot, partial |
| `ATAP.Utilities.Security.PKI.PowerShell` | Certificate / PKI functions. | Not yet extracted (plan Task 5.7) |

Only the **Bitwarden** functions moved in this iteration. The five non-Bitwarden secret-vault
functions (`Get-UsersSecretVaultInfo`, `Open-UsersSecretVault`, `Unlock-UsersSecretVault`,
`Install-SecretStoreVault`, `Test-SecretVault`) and the `SecretVaultConfigurations\` asset remain
in the umbrella and move later (plan Task 5.6).

## Exported commands

| Function | Aliases | Notes |
| --- | --- | --- |
| `Get-BitWardenCredential` | — | Loads/creates encrypted BitWarden login + unlock credentials |
| `List-BitwardenSecrets` | — | Non-approved verb; rename deferred (Task 12.55.a) |
| `Load-BitwardenBackup` | — | Non-approved verb; rename deferred. **Was unexported in the umbrella manifest — now exported.** |
| `New-BitwardenBackup` | — | |
| `Set-BitWardenSecret` | `New-BWSecret`, `Add-BitWardenLogin` | |
| `Sync-BitWardenDedicatedSecrets` | `Sync-DedicatedSecrets` | Calls `Test-SecretVault` from `Microsoft.PowerShell.SecretManagement` |

## Dependencies

`RequiredModules`: `PSFramework`, `Microsoft.PowerShell.SecretManagement`.

`Get-PVal` / `Get-ParameterValueFromNeoConfigurationRoot` (from `ATAP.Utilities.PowerShell`) are
resolved through the standard in-function helper-load block, not a manifest dependency.

> **Future direction.** The secrets/Bitwarden functions that currently live in
> `ATAP.Utilities.BuildTooling.PowerShell` — `Get-SecretATAP`,
> `Get-SecretATAPBitwardenSecretsManager`, `Get-BitWardenSecret`, `Get-BWSAccessToken`,
> `Initialize-BWSAccessToken`, `Initialize-BWSCredentialDirectory`, and the
> `*-SprintBitwardenSecrets` helpers — will eventually move **into this module**. That migration
> is its own iteration with its own consumer map, because `Get-SecretATAP` is a global-contract
> function named in agent instructions (`Bitwarden.md`).

## Secrets handling

Reference every secret by its `SecretName`; resolve values with `Get-SecretATAP`. Never write
connection strings, API keys, or credentials into source. Never log a secret value.

## Testing

```powershell
pwsh -Command "Invoke-Pester -Path './tests/Unit' -Output Detailed"
```

All Bitwarden CLI (`bw`) and vault calls are mocked. Tests never touch a real vault.
