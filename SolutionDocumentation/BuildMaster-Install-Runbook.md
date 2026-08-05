# BuildMaster Install and Configuration Runbook

> **Task 13.62 security cutover:** Legacy ProGet raw-key, sensitive-variable, and environment instructions below are superseded. BuildMaster passes `ProGet.BuildMaster.API.Key.<service-host>` only as a SecretName; administration uses `ProGet.Admin.API.Key.<service-host>`, never as fallback.

> **SEC-T1 / Task 13.62:** The ProGet API key must never appear in
> BuildMaster arguments, variables, environments, or transcripts. Active plans
> pass only `ProGet.BuildMaster.API.Key.<service-host>` as `-ProGetApiKeySecretName`; the leaf
> resolves it through `Get-SecretATAP` immediately before authentication.

> **SC-0288 / Task 13.66 host-suffix convention:** `<service-host>` is derived from the
> `ServicePlacementMap` setting, never typed as a literal. BuildTooling functions do this
> themselves and fail closed when placement is unknown. See
> [SecretName-HostSuffix-Convention.md](SecretName-HostSuffix-Convention.md).

**Status:** Current installation runbook. The Sprint 0007 discovery ledger in
`Runbook-BuildMasterConfiguration.md` is historical/non-executable; current values are
resolved from the service-placement host, repository root, and active branch at run time.

**Scope:** Install BuildMaster Free on the approved placement host, create the ATAP BuildMaster
applications, configure the immutable-build pipelines, and define the
PowerShell automation plan for repeatable setup.

**Source of truth:** The immutable build strategy is defined by the
SolutionDocumentation documents, especially:

- [Immutable-Build-Strategy.md](Immutable-Build-Strategy.md)
- [BuildMaster-Pipeline-Topology.md](BuildMaster-Pipeline-Topology.md)
- [Release-Bundle-Pipeline.md](Release-Bundle-Pipeline.md)
- [ProGet-Install-Runbook.md](ProGet-Install-Runbook.md)

Do not reintroduce the old build-per-tier pattern. The Experimental stage
builds and publishes the artifact once; later stages promote those same bytes
through ProGet and run tests against the promoted artifact.

---

## Parity journal requirement

Before a step in this runbook changes BuildMaster, its service account, its host
configuration, or its SQL backing state on `utat022` or `utat01`, append a
secret-safe declaration with `Add-ParityChangeEntry` on the host being changed.
Include the category, item, old/new state, peer host, and a peer action; do not
include any secret value. After the peer applies its corresponding action,
acknowledge it from that peer with `Confirm-ParityChangeApplied`.

---

## 1. What changed in this runbook

This document combines the reliable parts of the original installation runbook
with the later discoveries captured in `Runbook-BuildMasterConfiguration.md`.

| Source                                | Keep                                                                                                                                                                | Replace                                                                                     |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| `BuildMaster-Install-Runbook.md`      | Inedo Hub install steps, SQL/service verification, admin API key bootstrap, service-account notes, first-build troubleshooting.                                     | UI-only pipeline/script setup, stale application catalog, direct script paste instructions. |
| `Runbook-BuildMasterConfiguration.md` | Three-application target, shared global pipeline names, application variables, Git credential/raft discovery, ProGet poller shape, UI paths observed on 2026-05-14. | Its status as an executable runbook. It is now historical/deprecated.                       |
| `ProGet-Install-Runbook.md`           | ProGet URL/port, API-key constraints, current feed architecture.                                                                                                    | Feed-name drift must be resolved before the PowerShell pipeline is used. See section 10.    |

---

## 2. API automation findings

BuildMaster has enough API surface to automate most of the L1 work, but not all
of it should be generated from scratch on the first pass.

| Question                                            | Answer                                                                                                                                                                                                                       | Automation stance                                                                                                                                                                 |
| --------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Can applications be created via API?                | Yes. The Application Management API exposes `POST /api/applications/create`, `clone`, `update`, `purge`, and `list`. ApplicationInfo includes a `raft` property.                                                             | Implemented with `New-BuildMasterApplication`; removal/deactivation is implemented with `Remove-BuildMasterApplication`. Omit `-Raft` so BuildMaster uses the default raft.       |
| Can application variables be created via API?       | Yes. Variables Management supports entity variables at `/api/variables/application/{app}` and scoped variable objects. | Implemented with idempotent `Set-BuildMasterApplicationVariables`; store only `ProGetApiKeySecretName`, never the resolved value. |
| Can builds and build variables be created via API?  | Yes. `POST /api/releases/builds/create` creates builds and accepts variables as body keys prefixed with `$`.                                                                                                                 | Extend `Start-BuildMasterPipeline` to accept `-Variables @{ '$ModuleName' = ... }`.                                                                                               |
| Can releases be created via API?                    | Yes. The Release & Build Deployment API and Native API both support release creation/update with a pipeline name.                                                                                                            | Existing `New-BuildMasterRelease` is the right base function.                                                                                                                     |
| Can deployment scripts be created via API?          | Yes. Scripts are raft items; the Native API exposes `Rafts_CreateOrUpdateRaftItem` for database rafts.                                                                                                                       | Implemented with `New-BuildMasterScript` and `Remove-BuildMasterScript`, using default raft `Raft_Id = 1`.                                                                        |
| Can pipelines be created via API?                   | Partially. In BuildMaster 6.2+, pipelines are stored in rafts and no longer have a native pipeline ID. Public docs describe UI creation and raft storage, not a stable high-level pipeline CRUD endpoint.                    | Bootstrap one known-good global pipeline in the UI, then capture the default-raft item before automating updates. Avoid reverse-engineering pipeline JSON blindly.                |
| Can scripts be assigned to pipeline stages via API? | Partially. The stage-to-script mapping lives inside the pipeline raft item. There is no high-level documented "assign script to stage" REST endpoint in the public docs.                                                     | Manage this through a source-controlled pipeline raft file after the local schema is captured; otherwise use the UI for the first pipeline pass.                                  |
| Can resource monitors be created via API?           | Yes, through Native API methods such as `ResourceMonitors_CreateOrUpdateResourceMonitor`, but the configuration payload is extension-specific.                                                                               | Capture a UI-created monitor payload first, then automate from a manifest.                                                                                                        |

**Practical conclusion:** Automate applications, application variables,
default-raft script upload/removal, releases, builds, and build-scope
variables now. Treat global pipelines and stage-to-script wiring as UI-first
configuration until a known-good local default-raft pipeline item has been
captured and can be safely replayed by PowerShell.

---

## 3. Target BuildMaster state

| Field                    | Value                                                                                |
| ------------------------ | ------------------------------------------------------------------------------------ |
| Host                     | `utat022`                                                                            |
| BuildMaster URL          | `http://localhost:50017`                                                             |
| SQL Server               | `localhost\PRODUCTION`                                                               |
| BuildMaster database     | `BuildMaster`                                                                        |
| Windows service          | `INEDOBMSVC`                                                                         |
| Service account          | `NetworkService` until a dedicated service account is required                       |
| Admin API key secret     | `BuildMaster.Admin.API.Key.<service-host>` (Bitwarden Secrets Manager; read via `Get-SecretATAP`)   |
| ProGet URL               | `http://localhost:50000`                                                             |
| ProGet identity used by plans | Non-secret variable `ProGetApiKeySecretName` = `ProGet.BuildMaster.API.Key.<service-host>` |

### Target applications

| BuildMaster Application      | Pipeline / plan                        | Purpose                                                                                                    |
| ---------------------------- | -------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| `ATAP.Utilities-CSharp`      | `global::CSharpPackage-5Stage`         | Build and promote ATAP.Utilities C# NuGet packages.                                                        |
| `ATAP.Utilities-PowerShell`  | `global::PowerShellModule-5Stage`      | Build and promote all ATAP.Utilities PowerShell modules through one parameterized application.             |
| `AceCommander-ReleaseBundle` | `global::ReleaseBundle-6Stage`         | Build and promote the AceCommander Release Bundle. The Distribution stage remains deferred in Sprint 0007. |
| `ATAPUtilitiesDatabase`      | `global::DatabaseChangePackage-5Stage` | Build and promote ATAP.Utilities database change packages. See §15 for application variables.              |
| `AceCommanderDatabase`       | `global::DatabaseChangePackage-5Stage` | Build and promote AceCommander database change packages. See §15 for application variables.                |

`AceCommander-CSharp` may be added later if AceCommander library packages need
their own C# package application. It is not required for the Stream L target.

---

## 4. BuildMaster installation

### 4.1 Install via Inedo Hub

1. Open **Inedo Hub**.
2. Find **BuildMaster** and select **Install**.
3. Version: latest available for this host. Sprint 0007 used BuildMaster
   `2025.9`.
4. Database server: `localhost\PRODUCTION`.
5. Database name: `BuildMaster`.
6. User account: `NetworkService`.
7. Install and wait for the `INEDOBMSVC` service to start.

### 4.2 Verify service and database

```powershell
Get-Service |
  Where-Object { $_.DisplayName -like '*BuildMaster*' } |
  Select-Object Name, DisplayName, Status

sqlcmd -S 'localhost\PRODUCTION' -E -Q "SELECT name FROM sys.databases WHERE name = 'BuildMaster'"
```

Expected:

- `INEDOBMSVC` is `Running`.
- The SQL query returns `BuildMaster`.
- `http://localhost:50017` opens the BuildMaster UI.

On first login, use `Admin/Admin` only long enough to change the admin
password.

### 4.3 Service-account bootstrap (git `safe.directory` and machine-wide NBGV)

Two service-account prerequisites must be in place before the first
BuildMaster build is triggered. Both are owned by
[NewComputerSetup.md](NewComputerSetup.md) — this runbook only points at the
canonical sections so a divergent copy cannot drift here:

- **Git `safe.directory` for `SvcBuildMaster`** — see
  [NewComputerSetup.md § 9.4](NewComputerSetup.md). Without this, NBGV
  height computation and `Get-BuildContext` fail with `fatal: detected
dubious ownership in repository`. Must be run **as `SvcBuildMaster`**, not
  as the interactive developer login.
- **Machine-wide NBGV install** — see
  [NewComputerSetup.md § 4.4](NewComputerSetup.md). A per-user
  `dotnet tool install --global nbgv` is invisible to `SvcBuildMaster`;
  install to `C:\ProgramData\dotnet\tools` and confirm the machine
  PowerShell profile prepends that path. Failure mode:
  `The 'nbgv' CLI was not found on PATH` during the Experimental stage.

Confirm both are in place before continuing:

```powershell
# As SvcBuildMaster
git config --global --get-all safe.directory   # must include C:/Dropbox/whertzing/GitHub
pwsh -NoProfile -Command "Get-Command nbgv"    # must resolve from machine PATH
```

### 4.4 Create the BuildMaster admin API key

In the UI:

1. Open **Administration -> API Keys & Access Logs**.
2. Create an API key for automation.
3. Enable at least:
   - Native API
   - Application Management
   - Variables Management
   - Release & Build Deployment
   - Infrastructure Management
   - CI Badge, if badge checks are used
4. Store the generated key in Bitwarden Secrets Manager under the secret name
   `BuildMaster.Admin.API.Key.<service-host>`.
5. Code and runbooks read it through `Get-SecretATAP`:

```powershell
$BuildMasterApiKey = Get-SecretATAP -SecretName $BuildMasterAdminSecretName
```

Keep the API key out of runbooks, screenshots, logs, and Git history.

---

## 5. Operator session setup

Use this PowerShell shape for every API-backed step.

```powershell
$serviceHost = [Net.Dns]::GetHostName().ToLowerInvariant()
$BuildMasterAdminSecretName = "BuildMaster.Admin.API.Key.$serviceHost"
$ProGetApiKeySecretName = "ProGet.BuildMaster.API.Key.$serviceHost"
$ProGetAdminSecretName = "ProGet.Admin.API.Key.$serviceHost"
$BuildMasterBaseUrl = 'http://localhost:50017'
$BuildMasterApiKey = Get-SecretATAP -SecretName $BuildMasterAdminSecretName
$RepositoryRoot = git rev-parse --show-toplevel
$ActiveBranch = git -C $RepositoryRoot branch --show-current
Import-Module (Join-Path $RepositoryRoot 'src\ATAP.Utilities.BuildTooling.PowerShell\ATAP.Utilities.BuildTooling.PowerShell.psd1') -Force
```

The module exports these BuildMaster functions used by this runbook:

- `New-BuildMasterRelease`
- `Start-BuildMasterPipeline`
- `Approve-BuildMasterStage`
- `Sync-BuildMasterPlans`
- `Set-BuildMasterStableVariables`
- `Set-BuildMasterSprintVariables`
- `Clear-BuildMasterSprintVariables`
- `New-BuildMasterApplication`
- `Set-BuildMasterApplicationVariables`
- `New-BuildMasterScript`
- `Remove-BuildMasterScript`
- `Remove-BuildMasterApplicationVariable`
- `Remove-BuildMasterApplication`

The new BuildMaster configuration API functions live under
`src/ATAP.Utilities.BuildTooling.PowerShell\public`. Use the UI fallback steps
only for environments, global pipeline creation, and stage-to-script assignment
until those raft schemas are captured from a working BuildMaster instance.

---

## 6. Create environments

BuildMaster pipelines use the canonical five tier names:

```powershell
$BuildMasterEnvironments = @(
  'Experimental',
  'Development',
  'Integration',
  'QA',
  'Production'
)

# Planned:
# $BuildMasterEnvironments | ForEach-Object {
#   New-BuildMasterEnvironment -Name $_ -BuildMasterBaseUrl $BuildMasterBaseUrl
# }
```

UI fallback:

1. Open **Administration -> Environments**.
2. Create missing environments in this order:
   `Experimental`, `Development`, `Integration`, `QA`, `Production`.
3. Do not create a `Distribution` environment for Sprint 0007.

---

## 7. Create or update applications

### 7.1 Automation

```powershell
$Applications = @(
  @{
    Name = 'ATAP.Utilities-CSharp'
    Description = 'ATAP.Utilities C# NuGet package pipeline.'
    ReleaseUsage = 'Required'
  },
  @{
    Name = 'ATAP.Utilities-PowerShell'
    Description = 'Single parameterized pipeline for all ATAP.Utilities PowerShell modules.'
    ReleaseUsage = 'Required'
  },
  @{
    Name = 'AceCommander-ReleaseBundle'
    Description = 'AceCommander release bundle pipeline.'
    ReleaseUsage = 'Required'
  }
)

$Applications | ForEach-Object {
  New-BuildMasterApplication @_ `
    -BuildMasterBaseUrl $BuildMasterBaseUrl `
    -BuildMasterAdminApiKeySecretName $BuildMasterAdminSecretName
}
```

Do not pass `-Raft` during Sprint 0007 setup. The function serializes `raft`
as `null`, which tells BuildMaster to store application configuration in the
default raft.

API implementation target:

- `POST /api/applications/list` or the Application Management list endpoint to
  detect existing apps.
- `POST /api/applications/create` to create missing apps.
- `POST /api/applications/update` to set fields such as description,
  release usage, display flags, artifact usage, and raft.
- `POST /api/applications/purge` through `Remove-BuildMasterApplication` only
  when deliberately removing a failed or abandoned application setup.

### 7.2 UI fallback

For each application:

1. Open **Applications -> Create Application**.
2. Create a blank application with the exact name from section 3.
3. Set Release Usage to `Required`.
4. Leave history intact if an application already exists; update it rather
   than purging it.
5. If the UI offers an initial pipeline or script wizard, skip generated
   content unless it is needed as a temporary template. Durable content comes
   from the Git/database raft path below.

---

## 8. Set application variables

### 8.1 Variable API rule

Prefer a merge-preserving function that reads existing variables, overlays the
desired values, and writes only the intended changes. Avoid a blind "set all
variables" call unless the function first merges with the current object,
because the API's set-all endpoint deletes variables not included in the body.

For sensitive values, use either:

- the scoped variable endpoint with `{ "name", "value", "application",
"sensitive": true }`, or
- the Native API `Variables_CreateOrUpdateVariable` with
  `Sensitive_Indicator = Y`.

The simple single-variable endpoint can update an existing sensitive variable
without clearing the flag, but cannot mark a newly created variable sensitive.

### 8.2 `ATAP.Utilities-CSharp`

Application-scope variables:

| Variable       | Value                                               | Sensitive | Notes                                           |
| -------------- | --------------------------------------------------- | --------- | ----------------------------------------------- |
| `Branch`       | `<active-sprint-branch>`                        | No        | Default only; repository monitors supply it.    |
| `SourcePath`   | `C:\BuildMaster\work\ATAP.Utilities\$ReleaseNumber` | No        | Durable BuildMaster work path.                  |
| `ProGetUrl`    | `http://localhost:50000`                            | No        | Host-specific ProGet URL.                       |
| `ProGetApiKeySecretName` | `ProGet.BuildMaster.API.Key.<service-host>`             | No        | Non-secret name; leaf resolution only.          |

Build-scope variables supplied by the concrete C# Repository Monitor:

| Variable          | StronglyTypedId pilot value                                                    | Notes                                                                                        |
| ----------------- | ------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------- |
| `$ApplicationName` | `ATAP.Utilities`                                                              | Passed to `Get-BuildContext`.                                                                |
| `$MetaPackageName` | `ATAP.Utilities.StronglyTypedId`                                              | Roll-up package ID.                                                                          |
| `$PackageName`     | `ATAP.Utilities.StronglyTypedId`                                              | Package ID promoted through ProGet.                                                          |
| `$ProjectPath`     | `src/ATAP.Utilities.StronglyTypedId/ATAP.Utilities.StronglyTypedId.csproj`    | Passed to `Get-BuildContext -ProjectPath` so NBGV reads the project-adjacent `version.json`. |
| `$SolutionPath`    | `ATAP.Utilities.Production.slnf`                                              | Used by promoted-package tests after Experimental.                                           |
| `$Configuration`   | `Release`                                                                     | MSBuild configuration.                                                                       |

### 8.3 `ATAP.Utilities-PowerShell`

Application-scope variables:

| Variable          | Value                                               | Sensitive | Notes                                           |
| ----------------- | --------------------------------------------------- | --------- | ----------------------------------------------- |
| `ApplicationName` | `ATAP.Utilities-PowerShell`                         | No        | BuildMaster application identity.               |
| `Branch`          | `<active-sprint-branch>`                        | No        | Update each sprint or supply by monitor/poller. |
| `SourcePath`      | `C:\BuildMaster\work\ATAP.Utilities\$ReleaseNumber` | No        | Durable BuildMaster work path.                  |
| `ProGetApiKeySecretName` | `ProGet.BuildMaster.API.Key.<service-host>`             | No        | Non-secret name; leaf resolution only.          |

Build-scope variables supplied when creating a build:

| Variable          | Example                                  | Notes                                                                                                                                           |
| ----------------- | ---------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `$ModuleName`     | `ATAP.Utilities.BuildTooling.PowerShell` | Module folder under `src\`.                                                                                                                     |
| `$PackageName`    | `ATAP.Utilities.BuildTooling.PowerShell` | Usually equals `ModuleName`.                                                                                                                    |
| `$PackageVersion` | `0.1.0-Sprint.42`                        | Exact version detected in ProGet.                                                                                                               |
| `$Tier`           | `Experimental`                           | Current BuildMaster stage context. The plan computes `$CeilingTier` from the module's `version.json`; do not configure `$CeilingTier` manually. |

### 8.4 `AceCommander-ReleaseBundle`

| Variable                                          | Value                                                 | Sensitive | Notes                                                                                                                           |
| ------------------------------------------------- | ----------------------------------------------------- | --------- | ------------------------------------------------------------------------------------------------------------------------------- |
| `ApplicationName`                                 | `AceCommander-ReleaseBundle`                          | No        | BuildMaster application identity.                                                                                               |
| `ProductName`                                     | `AceCommander`                                        | No        | Passed to `Get-BuildContext`.                                                                                                   |
| `ReleaseTag`                                      | Empty until release cut                               | No        | Example: `v1.4.0`.                                                                                                              |
| `Branch`                                          | Current release or sprint branch                      | No        | Fallback when `ReleaseTag` is empty.                                                                                            |
| `SourcePath`                                      | `C:\BuildMaster\work\AceCommander\$ReleaseNumber`     | No        | Durable product work path; also passed as `Get-BuildContext -ProjectPath` because the bundle uses the repo-root `version.json`. |
| `ProGetUrl`                                       | `http://localhost:50000`                              | No        | Host-specific ProGet URL.                                                                                                       |
| `ProGetApiKeySecretName`                          | `ProGet.BuildMaster.API.Key.<service-host>`                          | No        | Non-secret name; leaf resolution only.                                                                                          |
| `ReleaseBundleExperimentalFeedName`               | `releasebundle-experimental`                          | No        | Universal Package feed.                                                                                                         |
| `ReleaseBundleDevelopmentFeedName`                | `releasebundle-development`                           | No        | Universal Package feed.                                                                                                         |
| `ReleaseBundleIntegrationFeedName`                | `releasebundle-integration`                           | No        | Universal Package feed.                                                                                                         |
| `ReleaseBundleQAFeedName`                         | `releasebundle-qa`                                    | No        | Universal Package feed.                                                                                                         |
| `ReleaseBundleProductionFeedName`                 | `releasebundle-production`                            | No        | Universal Package feed.                                                                                                         |
| `PreviousProductionBackupPath`                    | Approved `.bak` path                                  | No        | Required for Integration Flyway rehearsal.                                                                                      |
| `IntegrationDatabaseDBConnectionStringSecretName` | `dbConnectionString-AceCommander-utat022-Integration` | No        | Used by `Invoke-FlywayRehearsal`.                                                                                               |

### 8.5 Automation call

```powershell
Set-BuildMasterApplicationVariables `
  -ApplicationName 'ATAP.Utilities-CSharp' `
  -Variables @{
    Branch = $ActiveBranch
    SourcePath = 'C:\BuildMaster\work\ATAP.Utilities\$ReleaseNumber'
    ProGetUrl = 'http://localhost:50000'
    ProGetApiKeySecretName = $ProGetApiKeySecretName
  } `
  -BuildMasterBaseUrl $BuildMasterBaseUrl `
  -BuildMasterAdminApiKeySecretName $BuildMasterAdminSecretName
```

Use the same function for the PowerShell and Release Bundle application
variable tables above. The function checks existing simple values and skips
unchanged entries; sensitive/evaluated values are written through the scoped
variable API so the metadata is preserved.

UI fallback:

1. Open **Application -> Settings -> Variables**.
2. Add each variable without a leading `$`.
3. Set `ProGetApiKeySecretName` to `ProGet.BuildMaster.API.Key.<service-host>`; this is a
   non-secret name and must not be marked sensitive.
4. Confirm no ProGet key value exists in Application Variables.

### 8.6 Safe operator path for the ProGet SecretName

Set only the canonical non-secret name:

```powershell
Set-BuildMasterApplicationVariables `
  -ApplicationName 'ATAP.Utilities-CSharp' `
  -Variables @{ ProGetApiKeySecretName = $ProGetApiKeySecretName } `
  -BuildMasterAdminApiKeySecretName $BuildMasterAdminSecretName
```

The runner passes this SecretName to the appropriate BuildTooling cmdlet. That
cmdlet resolves it with `Get-SecretATAP` only immediately before authentication.
Never place a resolved ProGet value in BuildMaster variables.

---

## 9. Configure default raft scripts and pipelines

### 9.1 Default raft rule

Sprint 0007 BuildMaster bootstrap uses the default database raft for all
BuildMaster-owned storage. Do not create or depend on the Git raft while this
runbook is stabilizing. Keep the authored source files in Git, then publish
copies into BuildMaster's default raft with API calls.

The implemented script functions target Native API raft item storage with
`Raft_Id = 1`.

### 9.1.1 Raft strategy decision (V4-A08 — authoritative)

**Chosen path: default database raft (`Raft_Id = 1`).**

- Decision (Sprint 0007): use the default database raft for all `.otter`
  upload via `New-BuildMasterScript` and `Sync-BuildMasterPlans`.
- This matches `BuildMasterDefaultRaftId = 1` in `$global:settings` and the
  `-RaftId 1` defaults in `New-BuildMasterScript`, `Remove-BuildMasterScript`,
  and `Sync-BuildMasterPlans`.

**Rationale:**

- BuildMaster's Git raft has no Path/subfolder field; it reads `Plans/`,
  `Monitors/`, and `Scripts/` from the **repo root** only.
- Files were relocated to the repo root on 2026-05-14 to satisfy that
  convention, but this breaks CI isolation between sprint branches and makes
  file layout confusing for contributors.
- The default database raft keeps BuildMaster-managed plan state inside
  BuildMaster, where it is version-tracked by the BuildMaster audit log.
  Source-of-truth edits remain in Git; API push (`Sync-BuildMasterPlans`)
  propagates them.
- Database-raft uploads are idempotent and scriptable; no UI raft
  configuration is required per sprint.

**Git raft — deferred (historical reference only):**

> The Git raft setup steps documented in
> `Runbook-BuildMasterConfiguration.md` §2.9 are **deferred** for Sprint 0007
> and should be treated as historical reference. Do not create or depend on
> the Git raft until either:
>
> - BuildMaster adds a Path/subfolder field to the Git raft dialog, **or**
> - A future sprint decision explicitly adopts the Git raft path and updates
>   this section.
>
> At that time, revert this section to choose the Git raft and mark the
> database raft path historical.

### 9.2 Upload deployment scripts

Canonical authored files:

| File                                                                              | Role                                                                     |
| --------------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| `src/ATAP.Utilities.BuildTooling.BuildMaster/Plans/CSharpPackage-5Stage.otter`    | C# package immutable deployment script.                                  |
| `src/ATAP.Utilities.BuildTooling.BuildMaster/Plans/PowerShellModule-5Stage.otter` | PowerShell module immutable deployment script.                           |
| `src/ATAP.Utilities.BuildTooling.BuildMaster/Plans/ReleaseBundle-6Stage.otter`    | Release bundle immutable deployment script; Distribution block deferred. |
| `src/ATAP.Utilities.BuildTooling.BuildMaster/Scripts/Resolve-FeedName.ps1`        | Supporting script.                                                       |

Upload the three stage scripts into the default raft:

```powershell
$PlansRoot = Join-Path $RepositoryRoot 'src\ATAP.Utilities.BuildTooling.BuildMaster\Plans'

Get-ChildItem -LiteralPath $PlansRoot -Filter '*.otter' | ForEach-Object {
  New-BuildMasterScript `
    -ScriptName $_.Name `
    -Path $_.FullName `
    -BuildMasterBaseUrl $BuildMasterBaseUrl `
    -BuildMasterAdminApiKeySecretName $BuildMasterAdminSecretName
}
```

The function is idempotent. If a script raft item already exists, it is
updated in place; otherwise it is created. To remove a failed or obsolete
script:

```powershell
Remove-BuildMasterScript `
  -ScriptName 'Old-Experimental-Script.otter' `
  -BuildMasterBaseUrl $BuildMasterBaseUrl `
  -BuildMasterAdminApiKeySecretName $BuildMasterAdminSecretName `
  -Confirm:$false
```

Do not paste a `stage X { ... }` plan into a BuildMaster Plan text editor as
ordinary OtterScript. The stage grammar belongs to pipeline/plan context and
was previously rejected by the UI parser. Load through the default raft path.

UI verification:

1. Open the BuildMaster UI.
2. Browse the default raft-backed scripts/plans area.
3. Confirm `CSharpPackage-5Stage.otter`, `PowerShellModule-5Stage.otter`, and
   `ReleaseBundle-6Stage.otter` are visible.
4. Do not edit the script text in the UI unless recording an emergency local
   workaround; make durable edits in Git and rerun `New-BuildMasterScript`.

### 9.3 Create global pipelines in the UI

The desired global pipelines are:

| Pipeline                          | Stages                                                 | Script/plan                                                           |
| --------------------------------- | ------------------------------------------------------ | --------------------------------------------------------------------- |
| `global::CSharpPackage-5Stage`    | Experimental, Development, Integration, QA, Production | `CSharpPackage-5Stage.otter`                                          |
| `global::PowerShellModule-5Stage` | Experimental, Development, Integration, QA, Production | `PowerShellModule-5Stage.otter`                                       |
| `global::ReleaseBundle-6Stage`    | Experimental, Development, Integration, QA, Production | `ReleaseBundle-6Stage.otter`; do not wire Distribution in Sprint 0007 |

Pipeline creation and stage-to-script assignment remain UI steps for this
iteration because the public API documentation does not expose a stable
high-level pipeline CRUD endpoint or a direct "assign this script to this
stage" endpoint.

UI bootstrap:

1. Open **Application -> Settings -> Pipelines**.
2. Select **Global (Shared)**.
3. Create each global pipeline if missing.
4. Add stages in canonical order.
5. Assign each stage to the matching uploaded default-raft script.
6. Configure automatic/manual promotion gates to match the immutable-build
   strategy and local approval policy.
7. Save the pipeline and create a test release that references it.
8. After a pipeline works, capture the default-raft pipeline item from
   BuildMaster before attempting API automation for pipeline replay.

Future automation target after capture:

```powershell
# Planned after a known-good default-raft pipeline item exists:
# Sync-BuildMasterPipeline `
#   -PipelineFile '.\CapturedBuildMasterRaft\Pipelines\CSharpPackage-5Stage.json' `
#   -BuildMasterBaseUrl $BuildMasterBaseUrl `
#   -BuildMasterAdminApiKeySecretName $BuildMasterAdminSecretName
```

---

## 10. ProGet feed and key drift to resolve before first pipeline run

The immutable strategy documents use these PowerShell feed names:

- `powershellget-experimental`
- `powershellget-development`
- `powershellget-integration`
- `powershellget-qa`
- `powershellget-stable`

The ProGet install runbook records that the current `utat022` feeds may still
use the older `PowershellGallery-*` names. Resolve this before enabling
`ATAP.Utilities-PowerShell`:

1. Either rename/create ProGet feeds to match `powershellget-*`, or update the
   PowerShell module BuildMaster plan and variables to the actual feed names.
2. Keep one canonical naming set in `ProGet-Install-Runbook.md`,
   `BuildMaster-Pipeline-Topology.md`, and the `.otter` files.
3. Verify the ProGet key used by BuildMaster can push to Experimental and
   promote between tier feeds. On ProGet Free, this may be the admin key until
   least-privilege keys are available.

---

## 11. Create releases and builds

### 11.1 Placeholder releases

Each application should have a placeholder or current sprint release bound to
the correct global pipeline.

```powershell
New-BuildMasterRelease `
  -Application 'ATAP.Utilities-CSharp' `
  -ReleaseNumber 'Placeholder' `
  -PipelineName 'global::CSharpPackage-5Stage' `
  -BuildMasterBaseUrl $BuildMasterBaseUrl

New-BuildMasterRelease `
  -Application 'ATAP.Utilities-PowerShell' `
  -ReleaseNumber '0.0.0' `
  -PipelineName 'global::PowerShellModule-5Stage' `
  -BuildMasterBaseUrl $BuildMasterBaseUrl
```

Use the UI if BuildMaster requires the global pipeline selection through the
Create Release dialog. Record any exact label differences here.

### 11.2 ProGet poller build creation

The ProGet poller should create builds only for new Experimental feed package
tuples. It must not trigger new builds from Development, Integration, QA, or
Production promotions.

Planned C# trigger:

```powershell
Start-BuildMasterPipeline `
  -Application 'ATAP.Utilities-CSharp' `
  -ReleaseNumber '0.1.0-Sprint.42' `
  -Pipeline 'global::CSharpPackage-5Stage' `
  -Reason 'ProGet polling detected ATAP.Utilities 0.1.0-Sprint.42 in nuget-experimental' `
  -BuildMasterBaseUrl $BuildMasterBaseUrl
```

Planned PowerShell trigger after `Start-BuildMasterPipeline` gains
`-Variables`:

```powershell
Start-BuildMasterPipeline `
  -Application 'ATAP.Utilities-PowerShell' `
  -ReleaseNumber '0.1.0-Sprint.42' `
  -Pipeline 'global::PowerShellModule-5Stage' `
  -Variables @{
    '$ModuleName' = 'ATAP.Utilities.BuildTooling.PowerShell'
    '$PackageName' = 'ATAP.Utilities.BuildTooling.PowerShell'
    '$PackageVersion' = '0.1.0-Sprint.42'
    '$Tier' = 'Experimental'
  } `
  -Reason 'ProGet polling detected module package' `
  -BuildMasterBaseUrl $BuildMasterBaseUrl
```

---

## 12. PowerShell automation plan

Implemented functions live in
`src/ATAP.Utilities.BuildTooling.PowerShell\public`, with Pester tests that
mock `Invoke-RestMethod` and verify URI, method, body, idempotency, and default
raft behavior.

| Function                                | API surface                                                 | Status                         | Notes                                                                                                             |
| --------------------------------------- | ----------------------------------------------------------- | ------------------------------ | ----------------------------------------------------------------------------------------------------------------- |
| `New-BuildMasterApplication`            | Application Management `list`, `create`, `update`           | Implemented                    | Fully parameterized ApplicationInfo wrapper. Omit `-Raft` for default raft.                                       |
| `Set-BuildMasterApplicationVariables`   | Variables Management entity and scoped endpoints            | Implemented                    | Accepts a hashtable; simple values are idempotent; sensitive/evaluate values use scoped variable objects.         |
| `New-BuildMasterScript`                 | Native `Rafts_GetRaftItems`, `Rafts_CreateOrUpdateRaftItem` | Implemented                    | Accepts `-ScriptContent` or `-Path`; uses default raft `Raft_Id = 1`.                                             |
| `Remove-BuildMasterScript`              | Native `Rafts_GetRaftItems`, `Rafts_DeleteRaftItem`         | Implemented                    | Removes default-raft script items by name and optional application scope.                                         |
| `Remove-BuildMasterApplicationVariable` | Variables Management entity delete                          | Implemented                    | Deletes one or more application variables; missing variables are no-ops.                                          |
| `Remove-BuildMasterApplication`         | Application Management `list`, `update`, `purge`            | Implemented                    | Purges by default; `-DeactivateOnly` preserves history.                                                           |
| `Sync-BuildMasterPlans`                 | Native raft item upload                                     | Implemented                    | Existing bulk upload fallback for `.otter` plan files. Prefer `New-BuildMasterScript` for explicit runbook steps. |
| `New-BuildMasterRelease`                | Release API                                                 | Implemented                    | Validate pipeline-name handling with `global::` names.                                                            |
| `Start-BuildMasterPipeline`             | Build create API                                            | Implemented, needs extension   | Add `-Variables` hashtable for build-scope variables.                                                             |
| `Approve-BuildMasterStage`              | Manual approval API                                         | Implemented                    | Keep for manual-gate automation.                                                                                  |
| `New-BuildMasterEnvironment`            | Infrastructure Management or Native API                     | Planned                        | Idempotently create tier environments after endpoint shape is verified.                                           |
| `Sync-BuildMasterPipeline`              | Default-raft pipeline item replay                           | Planned after pipeline capture | Do not invent schema; consume captured/exported pipeline files from a working local pipeline.                     |
| `Set-BuildMasterResourceMonitor`        | Native `ResourceMonitors_CreateOrUpdateResourceMonitor`     | Planned after UI capture       | Requires extension-specific configuration payload.                                                                |
| `Test-BuildMasterConfiguration`         | Read-only API checks                                        | Planned                        | Assert apps, variables, pipelines, releases, environments, and raft references.                                   |
| `Start-ProGetBuildMasterPoller`         | ProGet API + BuildMaster API                                | Planned                        | Poll Experimental feeds, maintain durable state, call release/build functions.                                    |

Next implementation order:

1. Extend `Start-BuildMasterPipeline` with a `-Variables` hashtable for
   build-scope variables.
2. Add read-only `Test-BuildMasterConfiguration`.
3. Capture a working default-raft pipeline item from the UI-created pipeline.
4. Implement `Sync-BuildMasterPipeline` against the captured payload.
5. Capture and automate resource monitors.
6. Implement the ProGet poller.

---

## 13. Verification checklist

- [ ] BuildMaster service `INEDOBMSVC` is running.
- [ ] BuildMaster UI is reachable at `http://localhost:50017`.
- [ ] The `BuildMaster.Admin.API.Key.<service-host>` secret resolves via `Get-SecretATAP`.
- [ ] Environments exist: Experimental, Development, Integration, QA, Production.
- [ ] Applications exist: `ATAP.Utilities-CSharp`,
      `ATAP.Utilities-PowerShell`, `AceCommander-ReleaseBundle`.
- [ ] Each application has the variables listed in section 8.
- [ ] `ProGetApiKeySecretName` is exactly `ProGet.BuildMaster.API.Key.<service-host>` and no
      resolved ProGet value exists in the UI.
- [ ] Global pipelines exist and use the canonical stage order.
- [ ] No Distribution stage is wired for the Release Bundle in Sprint 0007.
- [ ] Plans/scripts are visible in the default raft.
- [ ] PowerShell feed names are reconciled between ProGet, docs, and `.otter`
      files.
- [ ] Placeholder/current releases are bound to the global pipelines.
- [ ] A dry-run or test package can create a BuildMaster build through the API.
- [ ] Database applications exist: `ATAPUtilitiesDatabase`, `AceCommanderDatabase`.
- [ ] Each database application has the variables listed in section 15.
- [ ] `DatabaseChangePackage-5Stage.otter` plan is visible in the default raft.
- [ ] Five canonical `database-*` ProGet feeds exist (see §15 and
      `ProGet-Install-Runbook.md`).
- [ ] `ProGet.BuildMaster.API.Key.<service-host>` resolves for the BuildMaster service account
      through `Get-SecretATAP`; no ProGet API-key environment variable exists.

---

## 14. Troubleshooting

### API returns 403

Check that the key is registered in BuildMaster and has the specific API
permission required by the endpoint. Native API calls require Native API
access in addition to feature-specific permissions.

### Variable is visible after creation

The single-variable endpoint cannot mark a new variable sensitive. Recreate or
update it through a scoped variable object or Native API call with the sensitive
indicator set.

### Pipeline does not appear in release creation

Confirm whether the pipeline is application-scoped or global. Global pipelines
appear under a separate **Global (Shared)** area and are referenced as
`global::<PipelineName>`.

### Script does not appear after upload

Confirm the script was uploaded with `New-BuildMasterScript` and that the UI is
browsing the default raft, not a Git raft or an application-specific raft. The
runbook's API path uses Native API default raft id `1`.

### C# compiler cannot read `.editorconfig`

If BuildMaster runs as `NetworkService`, grant read access to the source tree
or move builds to a BuildMaster-owned work path:

```powershell
icacls "C:\Dropbox\whertzing\GitHub\ATAP.Utilities" /grant "NETWORK SERVICE:(OI)(CI)R" /T
icacls "C:\Dropbox\whertzing\GitHub\AceCommander" /grant "NETWORK SERVICE:(OI)(CI)R" /T
```

---

## 15. External API references

- [BuildMaster API Endpoints & Methods](https://docs.inedo.com/docs/buildmaster/reference/api)
- [BuildMaster Application Management API](https://docs.inedo.com/docs/buildmaster/reference/api/buildmaster-appmanagement-api)
- [Create Application endpoint](https://docs.inedo.com/docs/buildmaster/reference/api/buildmaster-appmanagement-api/buildmaster-appmanagement-create)
- [Variables Management API](https://docs.inedo.com/docs/buildmaster/reference/api/variables)
- [Release & Build Deployment API](https://docs.inedo.com/docs/buildmaster/reference/api/release-and-build)
- [Create Build endpoint](https://docs.inedo.com/docs/buildmaster/reference/api/release-and-build/buildmaster-buildrelease-builds-create)
- [BuildMaster pipelines](https://docs.inedo.com/docs/buildmaster/deployment-continuous-delivery/buildmaster-pipelines)
- [Rafts & Git Storage](https://docs.inedo.com/docs/otter/scripting-in-otter/otter-rafts-and-git-storage)
- [BuildMaster Native API reference](https://buildmaster.inedo.com/reference/api)

---

## 16. Repository Monitor Setup (Manual Gate) — V4-A06

Source-controlled monitor definitions live in:

- `src/ATAP.Utilities.BuildTooling.BuildMaster/Monitors/PowerShellModule-RepositoryMonitors.otter`
- `src/ATAP.Utilities.BuildTooling.BuildMaster/Monitors/CSharpPackage-RepositoryMonitors.otter`

`CSharpPackage-RepositoryMonitors.otter` defines the two pilot monitors for
`ATAP.Utilities.StronglyTypedId`: one for the `main` branch (poll every 10
minutes) and one for sprint branches matching `*-Sprint-*-work-items` (poll
every 2 minutes). Both use
`PathFilter: src/ATAP.Utilities.StronglyTypedId/**` and pass `Branch`,
`ApplicationName`, `MetaPackageName`, `PackageName`, `ProjectPath`,
`SolutionPath`, and `Configuration` as build variables because
`ATAP.Utilities-CSharp` is a shared application. The runner derives the ceiling
from the package's `version.json`, not from the branch filter.

`PowerShellModule-RepositoryMonitors.otter` defines the two pilot monitors for
`ATAP.Utilities.BuildTooling.PowerShell`. These are scoped to
`PathFilter: src/ATAP.Utilities.BuildTooling.PowerShell/**` and must pass
`Branch`, `ModuleName`, and `PackageName` as build variables because
`ATAP.Utilities-PowerShell` is a single shared application for every module.
To onboard another PowerShell module, copy the two monitor entries and change
the monitor names, `PathFilter`, `ModuleName`, and `PackageName`.

The local comparison path is `Start-LocalPowerShellModuleBuildMasterPoller`.
It is intentionally a pilot, not a replacement for BuildMaster's native GitHub
monitor. It compares the current local repository `HEAD` against a state file
and calls `Start-BuildMasterPackagePipeline` when committed files under
`src/ATAP.Utilities.BuildTooling.PowerShell/` changed:

```powershell
Start-LocalPowerShellModuleBuildMasterPoller `
  -RepoRoot $RepositoryRoot `
  -UsePreviousCommitWhenStateMissing `
  -BuildMasterBaseUrl 'http://localhost:8622' `
  -BuildMasterAdminApiKeySecretName $BuildMasterAdminSecretName
```

By default it stores state at
`_generated/buildmaster/local-poller/ATAP.Utilities.BuildTooling.PowerShell.json`.
Run it manually or from Task Scheduler to compare local committed-HEAD polling
against the BuildMaster-native GitHub monitor.

### Prerequisites

The `BUILDMASTER_GH_WEBHOOK_SECRET` environment variable must be populated by
`LoginScript.ps1` before BuildMaster starts. Create a Bitwarden secure note named
`BUILDMASTER_GH_WEBHOOK_SECRET` and add it to the login script.

### Verify monitor readiness

Use `Assert-BuildMasterReady` for the supported non-secret readiness checks and
verify repository monitors in the BuildMaster UI. The Native API does not expose
a stable monitor-listing endpoint, so this runbook intentionally provides no
direct authenticated REST example. Any future automation must accept
`BuildMaster.Admin.API.Key.<service-host>` as a SecretName and resolve it only inside the
authenticated leaf.

### Create monitors via BuildMaster UI (if not already present)

1. Open **`http://localhost:50017`**.
2. Navigate to **Applications → ATAP.Utilities-PowerShell → Settings → Repository Monitors**.
3. Click **Add Monitor**. For each of the two entries in `PowerShellModule-RepositoryMonitors.otter`,
   fill in: Organization = `BillHertzing`, Repository = `ATAP.Utilities`, BranchFilter, PathFilter,
   PollInterval, PipelineName = `PowerShellModule-5Stage`, WebhookSecret env var name,
   and BuildVariables (`Branch`, `ModuleName`, `PackageName`) exactly as shown.
4. Repeat for **Applications → ATAP.Utilities-CSharp** using `CSharpPackage-RepositoryMonitors.otter`
   with PipelineName = `CSharpPackage-5Stage` and the C# BuildVariables exactly as shown.

### Trigger test

Push a commit touching `src/ATAP.Utilities.BuildTooling.PowerShell/**` to the
sprint branch `<active-sprint-branch>` and confirm the
`ATAP.Utilities-PowerShell` build starts with `ModuleName` and `PackageName`
set to `ATAP.Utilities.BuildTooling.PowerShell`. For C#, push a commit touching
`src/ATAP.Utilities.StronglyTypedId/**` and confirm the `ATAP.Utilities-CSharp`
build starts with `MetaPackageName`, `PackageName`, `ProjectPath`,
`SolutionPath`, and `Configuration` set to the StronglyTypedId pilot values.
Record the build IDs in the evidence file:
`_generated/audit/v4-current-state/V4-A06-buildmaster-monitors-evidence-20260523.md`

### API automation note

The BuildMaster Native API exposes `ResourceMonitors_CreateOrUpdateResourceMonitor`
but the configuration payload is extension-specific. Capture a UI-created monitor
JSON payload first, then automate future monitor provisioning from that manifest.
This is tracked as a follow-up in V4-A06 (trigger proof pending interactive session).

---

## Database package applications

This section documents the BuildMaster configuration required for the
`DatabaseChangePackage-5Stage` pipeline (see
`src/ATAP.Utilities.BuildTooling.BuildMaster/Plans/DatabaseChangePackage-5Stage.otter`).
Owned by V4-E09 / DBA2-T04.

### Application naming convention

Each database-bearing product gets a dedicated BuildMaster application whose
name is the product name with the `Database` suffix:

| Product         | BuildMaster application name |
| --------------- | ---------------------------- |
| `ATAPUtilities` | `ATAPUtilitiesDatabase`      |
| `AceCommander`  | `AceCommanderDatabase`       |

This keeps the database pipeline separate from the C# (`ATAP.Utilities-CSharp`)
and PowerShell-module (`ATAP.Utilities-PowerShell`) applications so each can
have its own ceiling and per-stage approvals.

### Required Application Variables

Set the following Application Variables on each `*Database` application before
the pipeline can run. Set them through **Applications → `<App>Database` →
Settings → Variables**:

| Variable name         | Type   | Purpose                                                                                                                                                   | Example value                     |
| --------------------- | ------ | --------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------- |
| `ApplicationName`     | string | BuildMaster application identifier echoed into run-context JSON.                                                                                          | `ATAPUtilitiesDatabase`           |
| `DatabaseApplication` | string | Source-tree application name used to locate `Database/<DatabaseApplication>/`. **Must not be empty.**                                                     | `ATAPUtilities`                   |
| `DatabaseStream`      | string | Optional database stream sub-folder. Empty selects single-stream; non-empty resolves the package id to `<DatabaseApplication>.<DatabaseStream>.Database`. | `` (empty)                        |
| `ExcludedMigrationFileNames` | string | Optional semicolon-delimited exact SQL file names excluded from this immutable release unit. Directory paths and duplicate names are rejected; exclusions are recorded in the build context. | `V00.02.000120__Add_ContentSummary_Rule_Kind.sql` |
| `Branch`              | string | Source branch supplied by the repository monitor.                                                                                                         | `main`                            |
| `SourcePath`          | string | Absolute path to the BuildMaster working directory for the active sprint or stable branch.                                                                | `C:\\BuildMaster\\ATAP.Utilities` |
| `ProGetBaseUrl`       | string | ProGet base URL hosting the canonical five `database-*` feeds.                                                                                            | `http://localhost:50000`          |

The plan passes every one of these to the runner as a `-NAME "$VAR"`
argument. No secret values appear in Application Variables or in `Arguments:`
blocks.

Use `ExcludedMigrationFileNames` only for an explicitly approved release
boundary. An exclusion is package-specific and must not become a permanent way
to hide a migration. The package manifest, target version, and archive contents
must be inspected after build to prove that each deferred file is absent.

### Required ProGet SecretName on the BuildMaster service account

The runner accepts `-ProGetApiKeySecretName` with canonical value
`ProGet.BuildMaster.API.Key.<service-host>`. The authenticated leaf calls `Get-SecretATAP` and
fails closed if that exact name cannot resolve. It never reads a ProGet API-key
environment variable and never falls back to `ProGet.Admin.API.Key.<service-host>`.

### Required ProGet feeds

The pipeline writes only to the canonical five database feeds. All five must
exist in ProGet before the plan can run, and they are permanent (not per-
sprint). The feed naming convention and per-tier purpose is documented in
[`Database-Package-Artifact-And-Feed-Decision.md`](Database-Package-Artifact-And-Feed-Decision.md):

| Tier                | Feed name               | Pipeline stage that writes here                           |
| ------------------- | ----------------------- | --------------------------------------------------------- |
| Experimental        | `database-experimental` | `Experimental` (publish from `New-DatabaseChangePackage`) |
| Development         | `database-development`  | `Development` (promote from `database-experimental`)      |
| Integration         | `database-integration`  | `Integration` (promote from `database-development`)       |
| QA                  | `database-qa`           | `QA` (promote from `database-integration`)                |
| Production / Stable | `database-stable`       | `Production` (promote from `database-qa`)                 |

The procedure for creating these feeds (one-time, per ProGet host) is in
[`ProGet-Install-Runbook.md`](ProGet-Install-Runbook.md) under
**Database content feeds** (V4-E02). Do not duplicate that procedure here.

### Pipeline assignment

The OtterScript plan
`src/ATAP.Utilities.BuildTooling.BuildMaster/Plans/DatabaseChangePackage-5Stage.otter`
is assigned as the per-stage deployment step for the
`DatabaseChangePackage-5Stage` pipeline. Each of the five stages — `Experimental`,
`Development`, `Integration`, `QA`, `Production` — runs the same plan; the
runner branches internally on `$PipelineStageName` (passed as `-Stage`).

### Secrets and audit notes

- Do **not** add any database connection string, SQL credential, or ProGet
  API key value to this document.
- Do **not** add `$Decrypt(...)` calls to `DatabaseChangePackage-5Stage.otter`;
  the static contract test
  `Plans/tests/DatabasePackage-5Stage.Tests.ps1` enforces this.
- Database connection strings used by Flyway during rehearsal stages are
  resolved by name from Bitwarden at runtime via `Get-SecretATAP`. The
  Bitwarden item naming convention for permanent and ephemeral database
  instances is documented in `.claude/Rules/Bitwarden.md`.

### Evidence

The provisioning evidence for the `*Database` applications is written to
`_generated/audit/v4-e/V4-E09-buildmaster-database-variables-<date>.md` in
the active sprint worktree. The evidence file records whether each
application has been created in BuildMaster yet and, if not, the exact
commands or UI steps that will create it.
