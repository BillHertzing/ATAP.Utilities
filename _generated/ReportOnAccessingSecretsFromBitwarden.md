# Report On Accessing Secrets From Bitwarden

Date: 2026-06-23

Task: Sprint 0010 Task 10.7, "Get to the bottom of the `bws` auth path"

## Direct Answer

ATAP.Utilities already supports both Bitwarden command-line products in the
PowerShell BuildTooling layer:

- `bw` is the Bitwarden Password Manager CLI. It should be opt-in and limited to
  personal, per-user secrets owned by the interactive user. It requires an
  unlocked Password Manager vault and `BW_SESSION`.
- `bws` is the Bitwarden Secrets Manager CLI. It should be the default for CI,
  BuildMaster, service accounts, and any interactive developer who needs access
  to CI/runtime/project secrets. It authenticates with a Secrets Manager access
  token, not `BW_SESSION`.

The important correction is that `bws` does not use `BW_SESSION`. If an
interactive user needs programmatic access to personal Password Manager secrets,
that is `bw` plus `BW_SESSION`. If that same user needs CI/project secrets, issue
that user a scoped BWS access token and store it in the same DPAPI-protected
access-token pattern used by service accounts.

Task 10.7's core finding is confirmed: an absent `BWS_ACCESS_TOKEN` environment
variable is not evidence that `bws` auth is broken. On this workstation, the
current user has no process-scope or user-scope `BWS_ACCESS_TOKEN`, but the
DPAPI-protected BWS access-token file loads successfully and authenticates the
`bws` CLI.

## Intended Access Model

| Secret class | Bitwarden product | CLI | Runtime credential | ATAP path |
| --- | --- | --- | --- | --- |
| Personal user-owned secrets | Password Manager | `bw` | `BW_SESSION` from interactive login/unlock | `Get-SecretATAP -SecretStoreType 'Bitwarden'` |
| CI/runtime/project secrets | Secrets Manager | `bws` | `BWS_ACCESS_TOKEN` or DPAPI token file | `Get-SecretATAP` default, or explicit `-SecretStoreType 'BitwardenSecretsManager'` |
| BuildMaster admin key | Secrets Manager | `bws` | DPAPI token file works when env var is absent | BuildMaster helpers force `BitwardenSecretsManager` |
| Database connection strings, including Sprint Dev/Exp | Secrets Manager | `bws` | `BWS_ACCESS_TOKEN` or DPAPI token file | DB readers should fetch `DBConnectionString*` / `dbConnectionString-*` secrets through `BitwardenSecretsManager` |

## Current PowerShell Implementation

`src/ATAP.Utilities.BuildTooling.PowerShell/public/Get-SecretATAP.ps1` is the
vendor-neutral front door. Its provider resolution order is:

1. Explicit `-SecretStoreType`.
2. `$global:settings['SecretStoreType']` or the configured config-root-key value.
3. Default `BitwardenSecretsManager`.

That default is important. All accounts default to `bws`; the old developer
account heuristic that silently routed humans through `bw` is gone.

`src/ATAP.Utilities.BuildTooling.PowerShell/public/Get-SecretATAPBitwardenSecretsManager.ps1`
is the BWS provider. Its token resolution order is:

1. Process-scope `$env:BWS_ACCESS_TOKEN`.
2. `Get-BWSAccessToken`, which reads the DPAPI-protected token file for the
   current Windows identity.

`src/ATAP.Utilities.BuildTooling.PowerShell/public/Get-BWSAccessToken.ps1` reads:

```text
C:\ProgramData\ATAP\BitwardenCredentials\<SamAccountName>\<COMPUTERNAME>_<SamAccountName>_BWS_AccessToken.xml
```

The file stores a `PSCredential` whose username is `BWS_ACCESS_TOKEN` and whose
password is the Secrets Manager access token. DPAPI binds the file to the owning
Windows account on the same host.

`src/ATAP.Utilities.BuildTooling.PowerShell/public/Initialize-BWSAccessToken.ps1`
is the write side of that credential. It must run as the account that will later
read the token.

`src/ATAP.Utilities.BuildTooling.PowerShell/public/Initialize-BWSCredentialDirectory.ps1`
creates and hardens the token directory with explicit access for the owning
account, `SYSTEM`, and local `Administrators`.

`src/ATAP.Utilities.BuildTooling.PowerShell/public/Get-SecretATAPBitwarden.ps1`
is the Password Manager provider. It is explicitly personal-vault-only:

- It reads `BW_SESSION` from process scope, then user scope.
- It verifies the vault is unlocked with `bw status`.
- It retrieves the item with `bw get item`.
- It refuses CI/infrastructure-looking names before invoking `bw`, including
  `dbConnectionString-*`, API keys, ProGet/BuildMaster names, webhook names, and
  service-account names.

## Live Evidence From This Workstation

I ran a non-disclosing probe on 2026-06-23. It printed booleans and paths only,
not secret values.

```text
Identity: UTAT022\whertzing
Process BWS_ACCESS_TOKEN present: false
User BWS_ACCESS_TOKEN present: false
Process BW_SESSION present: false
User BW_SESSION present: false
bws path: C:\Program Files\Bitwarden\bws\bws.exe
bw path: C:\ProgramData\chocolatey\bin\bw.exe
DPAPI token loaded: true
DPAPI credential username: BWS_ACCESS_TOKEN
DPAPI token path: C:\ProgramData\ATAP\BitwardenCredentials\whertzing\utat022_whertzing_BWS_AccessToken.xml
bws project list: succeeded
bws secret list: succeeded
Visible BWS secret count: 36
BuildMaster.Admin.API.Key resolved through Get-SecretATAP + BitwardenSecretsManager: true
```

This proves the Sprint 0010 observation: the environment variable can be absent
while `bws` still works through the DPAPI-stored token.

For database connection strings, the target model is stricter than the current
fallback behavior: Dev and Exp connection strings should be present in Bitwarden
Secrets Manager and fetched through `bws`. The live probe did not print or inspect
secret payloads, and the initial `dbConnectionString-*` check should not be treated
as evidence that Dev/Exp secrets belong outside Secrets Manager. At most, it shows
that the current code/query path can still fall back to deterministic derivation:

```text
Descriptor: dbConnectionString-ATAPUtilities-localhost-Dev-whertzing
Classification: derivable
Connection string present from deterministic descriptor: true
New-SprintBitwardenSecrets Sprint 0010 result: 12 derived, 0 created, 0 errors
```

That fallback should now be called cleanup debt. The correct statement is:
BuildMaster admin-key reads are proven through BWS, and database connection
strings, including experimental and development connection strings, should also
be retrieved from Bitwarden Secrets Manager through the `bws` provider.

## BuildMaster Path

The BuildMaster-facing PowerShell functions consistently force the BWS provider
when resolving `BuildMaster.Admin.API.Key`:

- `Set-BuildMasterSprintVariables.ps1`
- `Set-BuildMasterStableVariables.ps1`
- `Set-BuildMasterApplicationVariables.ps1`
- `Set-BuildMasterPipelineStageDeploymentStep.ps1`
- `Start-BuildMasterPipeline.ps1`
- `Start-BuildMasterDeployment.ps1`
- `Sync-BuildMasterPlans.ps1`
- `Assert-BuildMasterReady.ps1`
- `Test-SprintInfrastructureHealth.ps1`

These functions pass `-SecretStoreType 'BitwardenSecretsManager'`, so they do
not depend on `BW_SESSION`.

## Current C# Implementation

The C# secrets package has a provider enum value for both:

- `BitwardenPasswordManager`
- `BitwardenSecretsManager`

But the concrete C# shim at
`src/ATAP.Utilities.Secrets/Shim/Bitwarden/BitwardenSecretsShim.cs` is still a
Password Manager `bw` shim only. It:

- Uses provider name `Bitwarden`.
- Requires `BW_SESSION`.
- Calls `bw list items --search <name> --session <session>`.
- Does not implement the BWS access-token or DPAPI-token-file path.

Therefore, PowerShell BuildTooling supports both `bw` and `bws` today, but the
C# plugin layer does not yet have a first-class `bws` shim.

There is also a process-drain risk in the C# shim: it redirects both stdout and
stderr, but only drains stdout before `WaitForExitAsync`. Under repository rule
R-34, stdout and stderr should both be drained before waiting, otherwise a large
stderr payload can deadlock the process.

## Documentation State

The strongest current docs are:

- `SolutionDocumentation/NewComputerSetup.md` section 9.4.10: explains `bws`
  access-token provisioning for service accounts and interactive users.
- `SolutionDocumentation/NewOrganizationSetup.md`: explains Password Manager vs
  Secrets Manager roles.
- `src/ATAP.Utilities.BuildTooling.PowerShell/ReadMe.md`: documents SC-0175,
  BWS defaulting, but still describes the deterministic connection-string fallback
  too favorably.
- `src/ATAP.Utilities.BuildTooling.PowerShell/INDEX.md`: documents the
  CI/infra secrets policy.

Remaining inconsistencies to clean up:

- Some older text still frames interactive users as `bw` only. It should say
  interactive users use `bw` for personal PM secrets and can also use `bws` with
  a scoped BWS token for CI/project secrets.
- `Database/Powershell/public/Rebuild-All.ps1` still requires `BW_SESSION`
  before calling `Get-SecretATAP`, even though `Get-SecretATAP` now defaults to
  BWS. That gate can produce a false failure in agent or CI contexts.
- The Task 9.22 deterministic Dev/Exp connection-string fallback is now
  misaligned with the intended security model. There should be multiple
  `DBConnectionString` / `dbConnectionString-*` entries in Bitwarden Secrets
  Manager, including Experimental and Development entries, and readers should
  retrieve them through `bws` instead of deriving them.
- The generated agent instructions still contain older wording that says to use
  `Get-BitWardenSecret` for Bitwarden access. The current code path is
  `Get-SecretATAP`, with BWS as the default.
- `src/ATAP.Utilities.Secrets/Shim/Bitwarden/ReadMe.md` accurately describes the
  C# shim as `bw`-based, but should explicitly label it Password Manager-only
  and point CI/runtime consumers to the future BWS shim.

## Conclusions

Task 10.7 can be closed for the BWS-auth investigation:

1. `bws` is installed machine-wide and resolves from `C:\Program Files`.
2. The process and user `BWS_ACCESS_TOKEN` variables are absent.
3. `Get-BWSAccessToken` successfully loads the DPAPI token for `UTAT022\whertzing`.
4. `bws project list` and `bws secret list` authenticate successfully through
   that token.
5. `BuildMaster.Admin.API.Key` resolves through `Get-SecretATAP` using
   `BitwardenSecretsManager`.
6. Sprint Dev/Exp connection-string derivation still exists in code, but should
   be treated as cleanup debt. Database connection strings should be Secrets
   Manager entries retrieved through `bws`.

## Recommended Follow-Up Work

1. Update stale docs and generated agent instructions to use this wording:
   `bw` + `BW_SESSION` for personal Password Manager secrets only; `bws` +
   access token/DPAPI file for CI/runtime/project secrets.
2. Open and execute a cleanup task: make database connection strings BWS-only.
   Remove deterministic Dev/Exp derivation as a normal read path, ensure the
   expected `DBConnectionString` / `dbConnectionString-*` secrets exist in
   Bitwarden Secrets Manager for Experimental and Development, and update code
   plus documentation so DB connection strings are always fetched through
   `Get-SecretATAP` / `BitwardenSecretsManager`.
3. Remove the stale `BW_SESSION` precondition from
   `Database/Powershell/public/Rebuild-All.ps1` and route connection strings
   through `Resolve-DatabaseSqlConnection` or explicit
   `BitwardenSecretsManager` handling.
4. Add a C# `BitwardenSecretsManager` shim that uses `bws`, supports process
   `BWS_ACCESS_TOKEN`, supports the DPAPI token-file reader, and never references
   `BW_SESSION`.
5. Fix the C# Password Manager shim process handling so both stdout and stderr
   are drained before `WaitForExitAsync`.
6. Add focused tests that prove:
   - `Get-SecretATAP` defaults to BWS when no store is configured.
   - CI/infra names never reach the `bw` provider.
   - BWS succeeds through the DPAPI token path when `BWS_ACCESS_TOKEN` is absent.
   - Database connection strings are read from BWS, including Dev and Exp names.
   - C# `bw` and future `bws` shims have separate option types and separate auth
     contracts.

## External References

- [Bitwarden Secrets Manager CLI](https://bitwarden.com/help/secrets-manager-cli/)
- [Bitwarden Password Manager CLI](https://bitwarden.com/help/cli/)
- [Bitwarden Secrets Manager access tokens](https://bitwarden.com/help/access-tokens/)
