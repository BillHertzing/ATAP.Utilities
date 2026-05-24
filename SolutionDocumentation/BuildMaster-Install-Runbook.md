# BuildMaster Install and Configuration Runbook

**Status:** Sprint 0007 runbook. Replaces
`Runbook-BuildMasterConfiguration.md`.

**Scope:** Install BuildMaster Free on `utat022`, create the ATAP BuildMaster
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
| Can application variables be created via API?       | Yes. Variables Management supports entity variables at `/api/variables/application/{app}` and scoped variable objects. Single-variable set cannot create the sensitive flag; bulk/scoped/native calls can carry sensitivity. | Implemented with idempotent `Set-BuildMasterApplicationVariables`; removal is implemented with `Remove-BuildMasterApplicationVariable`. Use sensitive support for `ProGetApiKey`. |
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
| Admin API key env var    | `BUILDMASTER_ADMIN_API_KEY`                                                          |
| ProGet URL               | `http://localhost:50000`                                                             |
| ProGet key used by plans | BuildMaster variable `ProGetApiKey`, sourced from the approved ProGet API key secret |

### Target applications

| BuildMaster Application      | Pipeline / plan                   | Purpose                                                                                                    |
| ---------------------------- | --------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| `ATAP.Utilities-CSharp`      | `global::CSharpPackage-5Stage`    | Build and promote ATAP.Utilities C# NuGet packages.                                                        |
| `ATAP.Utilities-PowerShell`  | `global::PowerShellModule-5Stage` | Build and promote all ATAP.Utilities PowerShell modules through one parameterized application.             |
| `AceCommander-ReleaseBundle` | `global::ReleaseBundle-6Stage`    | Build and promote the AceCommander Release Bundle. The Distribution stage remains deferred in Sprint 0007. |

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

- **Git `safe.directory` for `SvcBuildmaster`** — see
  [NewComputerSetup.md § 9.4](NewComputerSetup.md). Without this, NBGV
  height computation and `Get-BuildContext` fail with `fatal: detected
dubious ownership in repository`. Must be run **as `SvcBuildmaster`**, not
  as the interactive developer login.
- **Machine-wide NBGV install** — see
  [NewComputerSetup.md § 4.4](NewComputerSetup.md). A per-user
  `dotnet tool install --global nbgv` is invisible to `SvcBuildmaster`;
  install to `C:\ProgramData\dotnet\tools` and confirm the machine
  PowerShell profile prepends that path. Failure mode:
  `The 'nbgv' CLI was not found on PATH` during the Experimental stage.

Confirm both are in place before continuing:

```powershell
# As SvcBuildmaster
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
4. Store the generated key in Bitwarden.
5. Ensure the login profile loads it into:

```powershell
$env:BUILDMASTER_ADMIN_API_KEY
```

Keep the API key out of runbooks, screenshots, logs, and Git history.

---

## 5. Operator session setup

Use this PowerShell shape for every API-backed step.

```powershell
$BuildMasterBaseUrl = 'http://localhost:50017'
$BuildMasterApiKey = $env:BUILDMASTER_ADMIN_API_KEY

Import-Module 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-100-Sprint-0007-work-items\src\ATAP.Utilities.BuildTooling.PowerShell\ATAP.Utilities.BuildTooling.PowerShell.psd1' -Force
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
    -ApiKey $BuildMasterApiKey
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

| Variable          | Value                                               | Sensitive | Notes                                                                                        |
| ----------------- | --------------------------------------------------- | --------- | -------------------------------------------------------------------------------------------- |
| `ApplicationName` | `ATAP.Utilities`                                    | No        | Passed to `Get-BuildContext`.                                                                |
| `Branch`          | `100-Sprint-0007-work-items`                        | No        | Update each sprint or supply by monitor/poller.                                              |
| `SourcePath`      | `C:\BuildMaster\work\ATAP.Utilities\$ReleaseNumber` | No        | Durable BuildMaster work path.                                                               |
| `Configuration`   | `Release`                                           | No        | MSBuild configuration.                                                                       |
| `MetaPackageName` | `ATAP.Utilities`                                    | No        | Roll-up package ID.                                                                          |
| `SolutionPath`    | `ATAP.Utilities.sln`                                | No        | Required by `CSharpPackage-5Stage.otter`.                                                    |
| `ProjectPath`     | Project directory or `.csproj` path                 | No        | Passed to `Get-BuildContext -ProjectPath` so NBGV reads the project-adjacent `version.json`. |
| `ProGetApiKey`    | From approved ProGet secret                         | Yes       | Never paste into this document.                                                              |

### 8.3 `ATAP.Utilities-PowerShell`

Application-scope variables:

| Variable          | Value                                               | Sensitive | Notes                                           |
| ----------------- | --------------------------------------------------- | --------- | ----------------------------------------------- |
| `ApplicationName` | `ATAP.Utilities-PowerShell`                         | No        | BuildMaster application identity.               |
| `Branch`          | `100-Sprint-0007-work-items`                        | No        | Update each sprint or supply by monitor/poller. |
| `SourcePath`      | `C:\BuildMaster\work\ATAP.Utilities\$ReleaseNumber` | No        | Durable BuildMaster work path.                  |
| `ProGetApiKey`    | From approved ProGet secret                         | Yes       | Never paste into this document.                 |

Build-scope variables supplied when creating a build:

| Variable          | Example                                  | Notes                                                                                                                                           |
| ----------------- | ---------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `$ModuleName`     | `ATAP.Utilities.BuildTooling.PowerShell` | Module folder under `src\`.                                                                                                                     |
| `$PackageName`    | `ATAP.Utilities.BuildTooling.PowerShell` | Usually equals `ModuleName`.                                                                                                                    |
| `$PackageVersion` | `0.1.0-Sprint.42`                        | Exact version detected in ProGet.                                                                                                               |
| `$Tier`           | `Experimental`                           | Current BuildMaster stage context. The plan computes `$CeilingTier` from the module's `version.json`; do not configure `$CeilingTier` manually. |

### 8.4 `AceCommander-ReleaseBundle`

| Variable                                 | Value                                                 | Sensitive | Notes                                                                                                                           |
| ---------------------------------------- | ----------------------------------------------------- | --------- | ------------------------------------------------------------------------------------------------------------------------------- |
| `ApplicationName`                        | `AceCommander-ReleaseBundle`                          | No        | BuildMaster application identity.                                                                                               |
| `ProductName`                            | `AceCommander`                                        | No        | Passed to `Get-BuildContext`.                                                                                                   |
| `ReleaseTag`                             | Empty until release cut                               | No        | Example: `v1.4.0`.                                                                                                              |
| `Branch`                                 | Current release or sprint branch                      | No        | Fallback when `ReleaseTag` is empty.                                                                                            |
| `SourcePath`                             | `C:\BuildMaster\work\AceCommander\$ReleaseNumber`     | No        | Durable product work path; also passed as `Get-BuildContext -ProjectPath` because the bundle uses the repo-root `version.json`. |
| `ProGetUrl`                              | `http://localhost:50000`                              | No        | Host-specific ProGet URL.                                                                                                       |
| `ProGetApiKey`                           | From approved ProGet secret                           | Yes       | Never paste into this document.                                                                                                 |
| `ReleaseBundleExperimentalFeedName`      | `releasebundle-experimental`                          | No        | Universal Package feed.                                                                                                         |
| `ReleaseBundleDevelopmentFeedName`       | `releasebundle-development`                           | No        | Universal Package feed.                                                                                                         |
| `ReleaseBundleIntegrationFeedName`       | `releasebundle-integration`                           | No        | Universal Package feed.                                                                                                         |
| `ReleaseBundleQAFeedName`                | `releasebundle-qa`                                    | No        | Universal Package feed.                                                                                                         |
| `ReleaseBundleProductionFeedName`        | `releasebundle-production`                            | No        | Universal Package feed.                                                                                                         |
| `PreviousProductionBackupPath`           | Approved `.bak` path                                  | No        | Required for Integration Flyway rehearsal.                                                                                      |
| `IntegrationDatabaseBitwardenSecretName` | `dbConnectionString-AceCommander-utat022-Integration` | No        | Used by `Invoke-FlywayRehearsal`.                                                                                               |

### 8.5 Automation call

```powershell
Set-BuildMasterApplicationVariables `
  -ApplicationName 'ATAP.Utilities-CSharp' `
  -Variables @{
    ApplicationName = 'ATAP.Utilities'
    Branch = '100-Sprint-0007-work-items'
    SourcePath = 'C:\BuildMaster\work\ATAP.Utilities\$ReleaseNumber'
    Configuration = 'Release'
    MetaPackageName = 'ATAP.Utilities'
    SolutionPath = 'ATAP.Utilities.sln'
    ProGetApiKey = @{
      Value = (Get-BitWardenSecret -SearchName 'PROGET_ADMIN_API_KEY' -FieldName 'token')
      Sensitive = $true
    }
  } `
  -BuildMasterBaseUrl $BuildMasterBaseUrl `
  -ApiKey $BuildMasterApiKey
```

Use the same function for the PowerShell and Release Bundle application
variable tables above. The function checks existing simple values and skips
unchanged entries; sensitive/evaluated values are written through the scoped
variable API so the metadata is preserved.

UI fallback:

1. Open **Application -> Settings -> Variables**.
2. Add each variable without a leading `$`.
3. Mark `ProGetApiKey` sensitive/obscured.
4. Reopen the page and confirm the key displays as hidden.

### 8.6 Safe operator path for ProGet API key

To set `ProGetApiKey` as a sensitive variable without exposing it in transcripts
or plain-text URL parameters, always use the hashtable form with `Sensitive = $true`:

```powershell
Set-BuildMasterApplicationVariables `
  -ApplicationName 'ATAP.Utilities-CSharp' `
  -Variables @{ ProGetApiKey = @{ Value = $env:PROGET_ADMIN_API_KEY; Sensitive = $true } } `
  -ApiKey $env:BUILDMASTER_ADMIN_API_KEY
```

This routes the variable through the `/api/variables/scoped/single` endpoint, which
carries the `sensitive` flag in the JSON body. Because the value is in the JSON body
(not in the URL), it does not appear in network logs or `Invoke-RestMethod` URI traces.
The value is never written to `$changed` or `$unchanged` output fields; only the key
name `TestApp/ProGetApiKey` is recorded there.

> **Important:** Do not use the simple string form `@{ ProGetApiKey = $env:PROGET_ADMIN_API_KEY }`.
> The simple path uses the single-variable entity endpoint (`/api/variables/application/{app}/{var}`)
> with a plain-text `GET` then `POST`. That path cannot mark a newly created variable sensitive
> and will expose the value in the `POST` body without the sensitivity flag.

The `PROGET_ADMIN_API_KEY` environment variable must be loaded from Bitwarden by the login
profile before calling this function. Never paste the key value into this runbook or into any
source file.

---

## 9. Configure default raft scripts and pipelines

### 9.1 Default raft rule

Sprint 0007 BuildMaster bootstrap uses the default database raft for all
BuildMaster-owned storage. Do not create or depend on the Git raft while this
runbook is stabilizing. Keep the authored source files in Git, then publish
copies into BuildMaster's default raft with API calls.

The implemented script functions target Native API raft item storage with
`Raft_Id = 1`.

### 9.1.1 Raft strategy decision (Sprint 0007)

- Decision: use the default database raft, `Raft_Id = 1`, for all `.otter`
  upload via `New-BuildMasterScript` and `Sync-BuildMasterPlans` during
  Sprint 0007.
- The Git raft path is deferred until either BuildMaster supports a
  subfolder field, or repo-root `Plans/`, `Monitors/`, `Scripts/` mirror
  folders are restored.
- This matches `BuildMasterDefaultRaftId = 1` in `$global:settings` and the
  helper cmdlet defaults in `New-BuildMasterScript`,
  `Remove-BuildMasterScript`, and `Sync-BuildMasterPlans`.

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
$PlansRoot = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-100-Sprint-0007-work-items\src\ATAP.Utilities.BuildTooling.BuildMaster\Plans'

Get-ChildItem -LiteralPath $PlansRoot -Filter '*.otter' | ForEach-Object {
  New-BuildMasterScript `
    -ScriptName $_.Name `
    -Path $_.FullName `
    -BuildMasterBaseUrl $BuildMasterBaseUrl `
    -ApiKey $BuildMasterApiKey
}
```

The function is idempotent. If a script raft item already exists, it is
updated in place; otherwise it is created. To remove a failed or obsolete
script:

```powershell
Remove-BuildMasterScript `
  -ScriptName 'Old-Experimental-Script.otter' `
  -BuildMasterBaseUrl $BuildMasterBaseUrl `
  -ApiKey $BuildMasterApiKey `
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
#   -ApiKey $BuildMasterApiKey
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
- [ ] `BUILDMASTER_ADMIN_API_KEY` is present in the operator PowerShell process.
- [ ] Environments exist: Experimental, Development, Integration, QA, Production.
- [ ] Applications exist: `ATAP.Utilities-CSharp`,
      `ATAP.Utilities-PowerShell`, `AceCommander-ReleaseBundle`.
- [ ] Each application has the variables listed in section 8.
- [ ] `ProGetApiKey` is hidden/sensitive in the UI.
- [ ] Global pipelines exist and use the canonical stage order.
- [ ] No Distribution stage is wired for the Release Bundle in Sprint 0007.
- [ ] Plans/scripts are visible in the default raft.
- [ ] PowerShell feed names are reconciled between ProGet, docs, and `.otter`
      files.
- [ ] Placeholder/current releases are bound to the global pipelines.
- [ ] A dry-run or test package can create a BuildMaster build through the API.

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
