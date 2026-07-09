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
| `Get-BitWardenCredential` | — | Loads/creates encrypted BitWarden login + unlock credentials. Supports `-WhatIf` (Task 12.55.c) |
| `Invoke-RotateSecretsATAP` | — | **New.** Rotates the two machine-account access tokens. See below |
| `List-BitwardenSecrets` | — | Non-approved verb; rename deferred (Task 12.55.a) |
| `Load-BitwardenBackup` | — | Non-approved verb; rename deferred. **Was unexported in the umbrella manifest — now exported.** |
| `New-BitwardenBackup` | — | |
| `Set-BitWardenSecret` | `New-BWSecret`, `Add-BitWardenLogin` | |
| `Sync-BitWardenDedicatedSecrets` | `Sync-DedicatedSecrets` | Calls `Test-SecretVault` from `Microsoft.PowerShell.SecretManagement` |

`Invoke-RotateSecretsATAP` is **not** re-exported by the umbrella. It is a new function, not a moved
name, so no existing consumer expects to find it there.

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
| `ATAP.Utilities.BuildTooling.PowerShell` | **≥ 0.1.29** | `Invoke-RotateSecretsATAP` calls `Get-BWSAccessToken` / `Initialize-BWSAccessToken` with `-TokenPurpose`, which first ships in 0.1.29 |

The BuildTooling constraint is a **minimum**, not an exact version, so a later BuildTooling satisfies
it. It is pinned rather than resolved at call time because an older BuildTooling would bind-fail at
*rotation* time — the worst possible moment to discover it — instead of at import time. A contract
test asserts both the pin and that the resolved version really does expose `-TokenPurpose`.

There is **no** edge on `ATAP.Utilities.Security.PKI.PowerShell` — design decision D1.

`Get-PVal` / `Get-ParameterValueFromNeoConfigurationRoot` (from `ATAP.Utilities.PowerShell`) is
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
pwsh -Command "Invoke-Pester -Path './tests/Unit' -Output Minimal"
```

All Bitwarden CLI (`bw`/`bws`), vault, and `Read-Host` calls are mocked. Tests never touch a real
vault, never prompt, and never write a DPAPI file, so the suite runs non-interactively in CI.
