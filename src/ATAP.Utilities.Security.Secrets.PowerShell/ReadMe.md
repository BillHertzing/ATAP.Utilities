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
| `ATAP.Utilities.Security.PKI.PowerShell` | Certificate / PKI functions. | Extracted, Sprint 0014 Stream E |

Only the **Bitwarden** functions moved in this iteration. The five non-Bitwarden secret-vault
functions (`Get-UsersSecretVaultInfo`, `Open-UsersSecretVault`, `Unlock-UsersSecretVault`,
`Install-SecretStoreVault`, `Test-SecretVault`) and the `SecretVaultConfigurations\` asset remain
in the umbrella and move later (plan Task 5.6).

## Exported commands

| Function | Aliases | Notes |
| --- | --- | --- |
| `Get-CredentialFile` | — | Imports an existing absolute-path DPAPI credential file and verifies it is a `PSCredential`. |
| `Get-BitWardenCredential` | — | Loads/creates encrypted BitWarden login + unlock credentials. Supports `-WhatIf` (Task 12.55.c) |
| `Invoke-RotateSecretsATAP` | — | **New.** Rotates the two machine-account access tokens. See below |
| `List-BitwardenSecrets` | — | Non-approved verb; rename deferred (Task 12.55.a) |
| `Load-BitwardenBackup` | — | Non-approved verb; rename deferred. **Was unexported in the umbrella manifest — now exported.** |
| `New-BitwardenBackup` | — | |
| `Set-CredentialFile` | — | Prompts for and writes an absolute-path DPAPI credential file. `-Force` is required to create its directory or replace a file; supports `-WhatIf`. |
| `Set-BitWardenSecret` | `New-BWSecret`, `Add-BitWardenLogin` | |
| `Sync-BitWardenDedicatedSecrets` | `Sync-DedicatedSecrets` | Calls `Test-SecretVault` from `Microsoft.PowerShell.SecretManagement` |

`Invoke-RotateSecretsATAP` is re-exported by the umbrella with the rest of the Secrets compatibility
surface. Existing consumers do not require it, but umbrella-only imports now receive one coherent
Secrets child surface in both source and packaged modules.

`Get-CredentialFile` and `Set-CredentialFile` were moved from the machine profile in Sprint 0014
Task 14.62. The profile deliberately does not import this module at startup; PowerShell autoloads
the child only when a caller invokes one of the functions. Both accept only absolute paths. The
set function requires `-Force` before creating a credential directory or replacing an existing
file, and `-WhatIf` neither prompts nor writes.

## `Invoke-RotateSecretsATAP`

Rotates exactly two secrets — the Bitwarden machine-account access tokens
`CommonCIForBitwardenReadOnly` and `CommonCIForBitwardenReadWrite` — on the current host, for the
current Windows identity. DPAPI token files are host- and user-bound, so it must be run once per
host, once per identity.

It **generates nothing.** The operator regenerates each token by hand in the Bitwarden UI, then
pastes each value into a separate prompt that names the machine account it belongs to.

```powershell
# Safe from any shell: enumerates what would rotate, prompts for nothing, writes nothing.
Invoke-RotateSecretsATAP -WhatIf

# Live. Requires a real interactive terminal.
Invoke-RotateSecretsATAP
```

> ⛔ **The live path is human-only.** It reads pasted values with `Read-Host`, so it cannot run from
> an agent shell, a scheduled task, CI, or any `-NonInteractive` session. Such a session is rejected
> before the first write with one terminating error — it never half-rotates and never falls through
> to an empty token.

Each paste is confirmed by character length plus a 12-character SHA-256 prefix, and the written file
is read back and re-fingerprinted before the next token is prompted for. That is what catches a
swapped or truncated paste, which would otherwise authenticate on first touch and only surface later
as a confusing permissions error. No token value is ever echoed, logged, or thrown.

`ReadOnly` rotates first and `ReadWrite` last, because the function authenticates with the
`ReadWrite` token it is rotating.

The binding design decisions (D1–D8) are recorded in
[`Documentation/Invoke-RotateSecretsATAP.DesignDecisions.md`](Documentation/Invoke-RotateSecretsATAP.DesignDecisions.md).
Live rotation on `utat01` and `utat022` is Sprint 0012 Task 12.56.

## Dependencies

`RequiredModules`:

| Module | Constraint | Why |
| --- | --- | --- |
| `PSFramework` | any | Logging |
| `Microsoft.PowerShell.SecretManagement` | any | `Sync-BitWardenDedicatedSecrets` calls its `Test-SecretVault` |
| `ATAP.Utilities.BuildTooling.Secrets.PowerShell` | **≥ 0.1.0** | `Invoke-RotateSecretsATAP` calls its `Get-BWSAccessToken` / `Initialize-BWSAccessToken` contracts with `-TokenPurpose` |

The Secrets-child constraint is a **minimum**, not an exact version, so a later compatible child satisfies
it. It is pinned rather than resolved at call time because an older child would bind-fail at
*rotation* time — the worst possible moment to discover it — instead of at import time. A contract
test asserts both the pin and that the resolved version really does expose `-TokenPurpose`.

There is **no** edge on `ATAP.Utilities.Security.PKI.PowerShell` — design decision D1.

`Get-PVal` / `Get-ParameterValueFromNeoConfigurationRoot` (from `ATAP.Utilities.PowerShell`) is
resolved through the standard in-function helper-load block, not a manifest dependency.

> **Future direction.** The secrets/Bitwarden functions that currently live in
> `ATAP.Utilities.BuildTooling.Secrets.PowerShell` — `Get-SecretATAP`,
> `Get-SecretATAPBitwardenSecretsManager`, `Get-BitWardenSecret`, `Get-BWSAccessToken`,
> `Initialize-BWSAccessToken`, `Initialize-BWSCredentialDirectory`, and the
> `*-SprintBitwardenSecrets` helpers — now live in the dedicated BuildTooling Secrets child. The
> Security child consumes the two BWS token contracts by module dependency, without source-path
> dot-sourcing, because `Get-SecretATAP` remains a global contract named in agent instructions.

## Secrets handling

Reference every secret by its `SecretName`; resolve values with `Get-SecretATAP`. Never write
connection strings, API keys, or credentials into source. Never log a secret value.

## Testing

```powershell
pwsh -Command "Invoke-Pester -Path './tests/Unit' -Output Minimal"
```

All Bitwarden CLI (`bw`/`bws`), vault, and `Read-Host` calls are mocked. Tests never touch a real
vault, never prompt, and never write a DPAPI file, so the suite runs non-interactively in CI.
