> **DEPRECATED:** This working runbook is retained only for Stream L history
> and UI-session notes. The maintained BuildMaster install/configuration
> runbook is now [BuildMaster-Install-Runbook.md](BuildMaster-Install-Runbook.md).
> Do not execute new BuildMaster configuration from this file.
>
> **Task 13.62:** All resolved ProGet-value, fixed sprint-branch, and
> environment-variable instructions below are historical/non-executable. Active callers
> derive `ProGet.BuildMaster.API.Key.<service-host>` from the placement host and pass only
> that SecretName.
>
> **Task 13.66 / SC-0288:** the host-suffix rule for every ProGet and BuildMaster SecretName
> is specified in [SecretName-HostSuffix-Convention.md](SecretName-HostSuffix-Convention.md).
>
> Service-account bootstrap steps that used to be scattered here — the git
> `safe.directory` entry that lets `SvcBuildmaster` operate on Dropbox-owned
> worktrees, and the machine-wide NBGV install required for
> `Get-BuildContext` under `SvcBuildmaster` — are canonical in
> [NewComputerSetup.md § 9.4](NewComputerSetup.md) and
> [NewComputerSetup.md § 4.4](NewComputerSetup.md). See
> [BuildMaster-Install-Runbook.md § 4.3](BuildMaster-Install-Runbook.md) for
> the verification snippet.

# Runbook: BuildMaster Configuration for Stream L

**Purpose:** Working runbook for Stream L in
`Plan-DocsUpdateForImmutablePackages_V3.md`.

**Scope:** BuildMaster UI configuration for:

- L1 — create the three BuildMaster Applications.
- L2 — configure ProGet polling to trigger BuildMaster pipelines.
- L3 — document cleanup of old per-project pipelines.

**Status:** First approximation, prepared before the UI session.

**How to maintain this document:** As the user executes each UI step, the
assisting agent should update this file with the actual UI labels, exact values
entered, screenshots or artifact links if useful, and any deviations from the
approximation below. Do not record API-key or secret values.

---

## 1. Preconditions

Before starting L1, confirm:

- BuildMaster is reachable from the operator workstation.
- The operator account can create Applications and edit Application Variables.
- The durable BuildMaster plans from Stream K are present and selectable:
  - `CSharpPackage-5Stage`
  - `PowerShellModule-5Stage`
  - `ReleaseBundle-6Stage`
- The ProGet base URL is known. Current documentation examples use
  `http://localhost:50000`.
- The ProGet API key is available to the operator from the approved secret
  source. It must be pasted only into a BuildMaster sensitive variable.

If any precondition fails, pause L1 and update **Issues and Observations**.

Precondition check result (2026-05-14):

- BuildMaster reachable from operator workstation: Yes.
- Operator can create Applications: Yes.
- Operator can edit Application Variables: Yes.
- No permission or access errors were shown during the check.

---

## 2. L1 — Create the Three BuildMaster Applications

### 2.1 Target Applications

| BuildMaster Application      | Durable plan to route through | Purpose                                                                                                                                                             |
| ---------------------------- | ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ATAP.Utilities-CSharp`      | `CSharpPackage-5Stage`        | Builds and promotes the ATAP.Utilities C# NuGet package family.                                                                                                     |
| `ATAP.Utilities-PowerShell`  | `PowerShellModule-5Stage`     | Builds and promotes **all** ATAP.Utilities PowerShell modules. Module identity (`ModuleName`, `PackageName`, `PackageVersion`) is supplied per-build by the poller. |
| `AceCommander-ReleaseBundle` | `ReleaseBundle-6Stage`        | Builds, promotes, and distributes the AceCommander Release Bundle.                                                                                                  |

### 2.2 Common UI Pattern

The exact UI labels must be verified during execution. Expected flow:

1. Open BuildMaster.
2. Navigate to **Applications**.
3. Select **Create Application** or **New Application**.
4. Enter the Application name from the table in §2.1.
5. If BuildMaster asks for an Application group, use an existing ATAP or
   AceCommander group if one exists; otherwise leave ungrouped and record what
   was chosen.
6. Save the Application.
7. Open the new Application.
8. Navigate to **Settings** → **Variables**.
9. Add the variables listed for that Application below. Store names without the
   leading `$`; the `$` is OtterScript reference syntax only.
10. Set non-secret `ProGetApiKeySecretName` to `ProGet.BuildMaster.API.Key.<service-host>`.
11. Navigate to the Application's pipeline/plan configuration page. Verify the
    actual UI label, then select the durable plan from §2.1 as the default route
    for builds in this Application.
12. Save the Application settings.
13. Return to **Applications** and confirm the Application appears in the list.
14. Record the actual UI path and any label differences in §2.8.

### 2.3 `ATAP.Utilities-CSharp` Variables

Source: `SolutionDocumentation/BuildMaster-ProGet-CSharp-Package-Pipeline.md`
§4.1 and `src/ATAP.Utilities.BuildTooling.BuildMaster/Plans/CSharpPackage-5Stage.otter`.

**Application-scope variables** (set once, stable across package builds):

| Variable name  | Initial value                                       | Sensitive? | Notes                                                                                |
| -------------- | --------------------------------------------------- | ---------- | ------------------------------------------------------------------------------------ |
| `SourcePath`   | `C:\BuildMaster\work\ATAP.Utilities\$ReleaseNumber` | No         | Confirm actual BuildMaster worktree path during UI session.                          |
| `Branch`       | `<active-sprint-branch>`                        | No         | Default only; the Repository Monitor supplies the triggering branch at build scope.   |
| `ProGetUrl`    | `http://localhost:50000`                            | No         | Confirm host-specific ProGet URL.                                                    |
| `ProGetApiKeySecretName` | `ProGet.BuildMaster.API.Key.<service-host>`              | No         | Non-secret name; authenticated leaf resolution only.                                  |

**Build-scope variables** (supplied by the concrete C# Repository Monitor or manual build):

| Variable name      | StronglyTypedId pilot value                                                 | Notes                                                                                                       |
| ------------------ | --------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| `$ApplicationName` | `ATAP.Utilities`                                                             | Repository/application name passed to `Get-BuildContext`.                                                   |
| `$MetaPackageName` | `ATAP.Utilities.StronglyTypedId`                                             | Roll-up NuGet package ID used by the plan.                                                                  |
| `$PackageName`     | `ATAP.Utilities.StronglyTypedId`                                             | Package ID promoted and tested after Experimental.                                                          |
| `$ProjectPath`     | `src/ATAP.Utilities.StronglyTypedId/ATAP.Utilities.StronglyTypedId.csproj`   | Passed to `Get-BuildContext -ProjectPath`; source of the project-adjacent `version.json` promotion ceiling. |
| `$SolutionPath`    | `ATAP.Utilities.Production.slnf`                                             | Solution filter used by promoted-package tests after Experimental.                                          |
| `$Configuration`   | `Release`                                                                    | MSBuild configuration.                                                                                      |

Execution notes (final state, verified 2026-05-14):

- UI path: **Applications → ATAP.Utilities-CSharp → Settings**.
- Pipeline selection: `global::CSharpPackage-5Stage`, bound via the `Placeholder` release on the Overview tab.
- Git connection: `BillHertzing/ATAP.Utilities`.
- Resource Monitor: `Monitoring all branches (BillHertzing/ATAP.Utilities) → Create Build with Pipeline global::CSharpPackage-5Stage`.
- Application-scope variables as configured:

  | Variable           | Value                                                      |
  | ------------------ | ---------------------------------------------------------- |
  | `$ApplicationName` | `ATAP.Utilities`                                           |
  | `$Branch`          | `<active-sprint-branch>`                               |
  | `$Configuration`   | `Release`                                                  |
  | `$MetaPackageName` | `ATAP.Utilities`                                           |
  | `$ProGetApiKeySecretName` | `ProGet.BuildMaster.API.Key.<service-host>`                        |
  | `$ProGetUrl`       | `http://localhost:50000`                                   |
  | `$ProjectPath`     | `src\ATAP.Utilities.Philote\ATAP.Utilities.Philote.csproj` |
  | `$SourcePath`      | `C:\BuildMaster\work\ATAP.Utilities\$ReleaseNumber`        |

- Current monitor pilot: `CSharpPackage-RepositoryMonitors.otter` overrides the historical app-scope package defaults with the StronglyTypedId build-scope variables above.
- Version caveat (2026-06-01): `src/ATAP.Utilities.StronglyTypedId/version.json` currently resolves as `0.1.0-QA.{height}`. The monitor starts the pipeline at Experimental, but the runner will allow promotion up to the QA ceiling unless that version label is lowered or a Sprint-ceiling package such as `ATAP.Utilities.ETW` is used for the smoke.
- Ceiling note: `$Tier` is the BuildMaster stage context. `$CeilingTier` is preamble-set from `version.json`; do not configure it as an Application variable.

### 2.4 `ATAP.Utilities-PowerShell` Variables

Source: `src/ATAP.Utilities.BuildTooling.BuildMaster/Plans/PowerShellModule-5Stage.otter`.

**Design:** This single application handles **all** ATAP.Utilities PowerShell modules. The
module identity is supplied per-build by the ProGet poller; `ModuleName`, `PackageName`,
and `PackageVersion` are **Build-scope variables** set at build creation time, not Application
variables. The OtterScript plan uses `$ModuleName` wherever the module identity is needed,
so no new application is required per module.

**Application-scope variables** (set once, stable across all builds):

| Variable name     | Initial value                                       | Sensitive? | Notes                                                                                                         |
| ----------------- | --------------------------------------------------- | ---------- | ------------------------------------------------------------------------------------------------------------- |
| `ApplicationName` | `ATAP.Utilities-PowerShell`                         | No         | BuildMaster Application identity used in log/reason text.                                                     |
| `Branch`          | `<active-sprint-branch>`                        | No         | Source branch for checkout. Update each sprint. Present in CSharp app; required here for the same reason.     |
| `SourcePath`      | `C:\BuildMaster\work\ATAP.Utilities\$ReleaseNumber` | No         | Use the durable BuildMaster-managed path. Do NOT use a concrete Dropbox worktree path (see CSharp deviation). |
| `ProGetUrl`       | `http://localhost:50000`                            | No         | Confirm host-specific ProGet URL.                                                                             |
| `ProGetApiKeySecretName` | `ProGet.BuildMaster.API.Key.<service-host>`              | No         | Non-secret name; authenticated leaf resolution only.                                                   |

**Build-scope variables** (supplied by the poller at `New-BuildMasterBuild` call time):

| Variable name    | Example value                  | Notes                                             |
| ---------------- | ------------------------------ | ------------------------------------------------- |
| `ModuleName`     | `ATAP.Utilities.Serialization` | Module folder under `src\` and ProGet package ID. |
| `PackageName`    | `ATAP.Utilities.Serialization` | Usually equals `ModuleName`; override if needed.  |
| `PackageVersion` | `2.1.0`                        | Supplied by the poller from the ProGet event.     |

Execution notes (final state, verified 2026-05-14):

- UI path: **Applications → ATAP.Utilities-PowerShell → Settings**.
- Pipeline selection: `global::PowerShellModule-5Stage`, bound via the `Placeholder` release (Release number `0.0.0`) on the Overview tab.
- Create New Release dialog has **no Branch field** — branch is supplied via the Application-scope `$Branch` variable (same pattern as the CSharp app).
- Git connection: `BillHertzing/ATAP.Utilities`.
- Resource Monitor: **historical L1 state was none**. Superseding guidance lives
  in [BuildMaster-Install-Runbook.md §16](BuildMaster-Install-Runbook.md):
  the pilot `ATAP.Utilities.BuildTooling.PowerShell` repository monitors are
  valid because they provide Build-scope `$ModuleName` and `$PackageName`.
  Generic PowerShell Git monitors remain invalid unless they supply those
  variables; the ProGet poller/manual trigger path may also supply them.
- Application-scope variables as configured:

  | Variable           | Value                                               |
  | ------------------ | --------------------------------------------------- |
  | `$ApplicationName` | `ATAP.Utilities-PowerShell`                         |
  | `$Branch`          | `<active-sprint-branch>`                        |
  | `$ProGetApiKeySecretName` | `ProGet.BuildMaster.API.Key.<service-host>`                 |
  | `$ProGetUrl`       | `http://localhost:50000`                            |
  | `$SourcePath`      | `C:\BuildMaster\work\ATAP.Utilities\$ReleaseNumber` |

- The PowerShell plan derives the module location at runtime via `$ModulePath = $PathCombine($SourcePath, src\$ModuleName)`, so no `$ProjectPath` variable is needed on this app.
- The PowerShell plan computes `$CeilingTier` from `$ModulePath\version.json` in its preamble. `$Tier` remains the BuildMaster stage context.
- Until Stream L2 lands, manual builds via the Placeholder release's **Create Build** button will fail because `$ModuleName` is unset. Wait for the ProGet poller before triggering a build.

### 2.5 `AceCommander-ReleaseBundle` Variables

Source: `src/ATAP.Utilities.BuildTooling.BuildMaster/Plans/ReleaseBundle-6Stage.otter`,
`SolutionDocumentation/Release-Bundle-Pipeline.md`, and
`SolutionDocumentation/SprintInfrastructure-Naming.md` §6.2.

| Variable name                                     | Initial value                                         | Sensitive? | Notes                                                                                                                                    |
| ------------------------------------------------- | ----------------------------------------------------- | ---------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `ApplicationName`                                 | `AceCommander-ReleaseBundle`                          | No         | BuildMaster Application identity.                                                                                                        |
| `ProductName`                                     | `AceCommander`                                        | No         | Product name passed to `Get-BuildContext`.                                                                                               |
| `ReleaseTag`                                      | `<blank until release cut>`                           | No         | Use for release-tag builds, for example `v1.4.0`.                                                                                        |
| `Branch`                                          | `<current release or sprint branch>`                  | No         | Branch fallback when `ReleaseTag` is blank.                                                                                              |
| `SourcePath`                                      | `C:\BuildMaster\work\AceCommander\$ReleaseNumber`     | No         | Confirm actual product worktree path during UI session; also passed as `Get-BuildContext -ProjectPath` for the repo-root `version.json`. |
| `ProGetUrl`                                       | `http://localhost:50000`                              | No         | Confirm host-specific ProGet URL.                                                                                                        |
| `ProGetApiKeySecretName`                          | `ProGet.BuildMaster.API.Key.<service-host>`                          | No         | Non-secret name; authenticated leaf resolution only.                                                                                     |
| `ReleaseBundleExperimentalFeedName`               | `releasebundle-experimental`                          | No         | Universal Package feed.                                                                                                                  |
| `ReleaseBundleDevelopmentFeedName`                | `releasebundle-development`                           | No         | Universal Package feed.                                                                                                                  |
| `ReleaseBundleIntegrationFeedName`                | `releasebundle-integration`                           | No         | Universal Package feed.                                                                                                                  |
| `ReleaseBundleQAFeedName`                         | `releasebundle-qa`                                    | No         | Universal Package feed.                                                                                                                  |
| `ReleaseBundleProductionFeedName`                 | `releasebundle-production`                            | No         | Universal Package feed.                                                                                                                  |
| `PreviousProductionBackupPath`                    | `<approved .bak path>`                                | No         | Required for Integration Flyway rehearsal traceability.                                                                                  |
| `IntegrationDatabaseDBConnectionStringSecretName` | `dbConnectionString-AceCommander-utat022-Integration` | No         | Follows `SprintInfrastructure-Naming.md`; pass-through to `Invoke-FlywayRehearsal -DBConnectionStringSecretName`.                        |

Execution notes:

- Actual UI path used:
- Actual plan/pipeline selector label:
- Decision for `ReleaseTag` / `Branch` seed values:
- Confirmed `PreviousProductionBackupPath`:
- Deviations:

### 2.6 L1 Verification

After the three Applications are created:

1. Reopen **Applications** and confirm all three names appear exactly as listed
   in §2.1.
2. Open each Application and confirm the selected durable plan is correct.
3. Open each Application's variables page and confirm:
   - Required variable names exist without leading `$`.
   - `ProGetApiKeySecretName` is exactly `ProGet.BuildMaster.API.Key.<service-host>`.
   - No secret value appears in page text, notes, screenshots, or this runbook.
4. If BuildMaster has an audit/history page, record the audit entry ID or
   timestamp for each Application creation.
5. Update the status table in §2.7.

### 2.7 L1 Status Table

| Application                  | Created?           | Variables entered? | Plan selected?                                                          | Verified by | Verified date | Notes                                                                                                                                                                                                                      |
| ---------------------------- | ------------------ | ------------------ | ----------------------------------------------------------------------- | ----------- | ------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ATAP.Utilities-CSharp`      | Yes (pre-existing) | Yes ✓              | `global::CSharpPackage-5Stage` (Placeholder release + Resource Monitor) | User        | 2026-05-14    | L1 accepted. Git Resource Monitor on `BillHertzing/ATAP.Utilities` triggers builds via the durable plan. `$ProjectPath` remains as legacy per-project pinning; deferred to durable Build-scope migration, not blocking L1. |
| `ATAP.Utilities-PowerShell`  | Yes                | Yes ✓              | `global::PowerShellModule-5Stage` (Placeholder release `0.0.0`)         | User        | 2026-05-14    | L1 accepted. Single parameterized app for all PS modules. Historical L1 had no Resource Monitor; current setup uses pilot BuildTooling monitors only when `ModuleName`/`PackageName` are supplied as build variables.       |
| `AceCommander-ReleaseBundle` | Pending            | Pending            | Pending                                                                 |             |               |                                                                                                                                                                                                                            |

### 2.8 L1 UI Corrections Captured During Execution

Final UI paths and pipeline facts captured during L1:

- Application Variables: **Application → Settings → Variables**.
- Durable plan/pipeline selection: **Application → Settings → Pipelines**. The Pipelines page has an `Application` tab and a `Global (Shared)` tab; durable plans live under `Global (Shared)` and are referenced as `global::<PlanName>`.
- Raft assignment: **Application → Settings → Advanced → Artifact & Component Hosting**. Use this dialog to assign the Git raft to the application.
- Canonical stage order: `Experimental → Development → Integration → QA → Production`.

Durable pipelines created in `Global (Shared)`:

- `global::CSharpPackage-5Stage`
  - Description: `5-Stage pipeline for creating packages from CSharp projects`.
  - Event listeners: `Set status to Deployed` and `Create New Release`, both on **When build completes pipeline**.
  - Serves `ATAP.Utilities-CSharp`.
- `global::PowerShellModule-5Stage`
  - Created by cloning `CSharpPackage-5Stage` and updating name/description.
  - Description: `5-Stage pipeline for creating Modules from PowerShell projects`.
  - Event listeners carried over from the source pipeline.
  - Serves the single `ATAP.Utilities-PowerShell` application; all PS module builds route through this pipeline regardless of which module is building.

### 2.9 Source Control Credentials and Rafts [HISTORICAL — Git raft deferred]

> **⚠ HISTORICAL — NOT THE ACTIVE PATH (Sprint 0007 and later).**
> Sprint 0007 uses the default database raft (`Raft_Id = 1`) for all `.otter`
> uploads via `New-BuildMasterScript` and `Sync-BuildMasterPlans`.
> The Git raft design and credential details captured below are preserved as
> historical reference. **Do not configure a Git raft unless a future sprint
> decision explicitly adopts it and updates `BuildMaster-Install-Runbook.md`
> §9.1.1.**
> See `BuildMaster-Install-Runbook.md` §9.1.1 for the authoritative raft
> strategy decision (V4-A08).

BuildMaster can ingest `.otter` plans/pipelines from a Git **Raft** rather than via copy/paste into the UI. The OtterScript `stage X { ... }` grammar is pipeline-as-code and cannot be pasted into a Plan's Text Editor (parser rejects it with `Expected ( or ;` at the first `stage` line).

**Canonical Git credential:**

| Credential name  | Type           | Username       | Scope  | Secret backing                                       |
| ---------------- | -------------- | -------------- | ------ | ---------------------------------------------------- |
| `global::GitHub` | GitHub Account | `BillHertzing` | global | Bitwarden item `GitHub-PAT-BillHertzing-BuildMaster` |

PAT scope: classic `repo` (full), or fine-grained with **Contents: Read** on `BillHertzing/ATAP.Utilities` and `BillHertzing/AceCommander`. Set a calendar reminder for the PAT expiration date. After saving, click **Test...** to confirm authentication. The PAT field displays `unchanged` after save by design.

**Canonical raft:**

| Raft name                     | Repository URL                                       | Branch                                                       | Credential       | Consumes                                          |
| ----------------------------- | ---------------------------------------------------- | ------------------------------------------------------------ | ---------------- | ------------------------------------------------- |
| `ATAP-Utilities-BuildTooling` | `https://github.com/BillHertzing/ATAP.Utilities.git` | `<active-sprint-branch>` (sprint) → `main` at sprint-end | `global::GitHub` | `/Plans/`, `/Monitors/`, `/Scripts/` at repo root |

BuildMaster's Git raft has no Path/subfolder field; it reads `Plans/`, `Monitors/`, `Scripts/` (and `Pipelines/` if present) from the **repo root**. The OtterScript and supporting folders were relocated on 2026-05-14 from `src/ATAP.Utilities.BuildTooling.BuildMaster/{Plans,Monitors,Scripts}/` to the repo root of `ATAP.Utilities` to satisfy this convention.

Sprint-end retarget: SprintEndAgent must flip the raft's Branch field from `<active-sprint-branch>` back to `main` just before merge, alongside the other stable-branch pointer retargets called out in CLAUDE.md.

---

## 3. L2 — Configure ProGet Polling to Trigger BuildMaster

**Status:** Placeholder. Fill this section during L2 execution.

Expected information to capture:

- Polling runner host:
- Polling interval:
- ProGet base URL:
- BuildMaster base URL:
- Credential source for ProGet API key:
- Credential source for BuildMaster API key:
- Polling state-file path:
- State-file ACL / owner:
- Feed/package-to-Application map:

Initial map:

| ProGet feed                  | Package family                           | BuildMaster Application      | BuildMaster plan          |
| ---------------------------- | ---------------------------------------- | ---------------------------- | ------------------------- |
| `nuget-experimental`         | `ATAP.Utilities` NuGet packages          | `ATAP.Utilities-CSharp`      | `CSharpPackage-5Stage`    |
| `powershellget-experimental` | Any `ATAP.Utilities.*` PowerShell module | `ATAP.Utilities-PowerShell`  | `PowerShellModule-5Stage` |
| `releasebundle-experimental` | `AceCommander` Release Bundle            | `AceCommander-ReleaseBundle` | `ReleaseBundle-6Stage`    |

Placeholder steps:

1. Decide whether the runner is a Windows Scheduled Task, BuildMaster recurring
   job, or another approved operations runner.
2. Configure the runner to poll the three Experimental feeds.
3. Configure durable state for consumed `(feedName, packageName,
packageVersion)` tuples.
4. Configure calls to `New-BuildMasterRelease` and `Start-BuildMasterPipeline`.
5. Push or identify a safe test package in `nuget-experimental`.
6. Confirm the matching BuildMaster build starts within the configured polling
   interval.
7. Record replay/recovery steps.

Actual L2 steps and evidence:

- To be filled during execution.

---

## 4. L3 — Document Old Per-Project Pipeline Cleanup

**Status:** Placeholder. Fill this section during L3 execution.

Expected UI flow:

1. Open BuildMaster pipeline/plan inventory.
2. List every existing BuildMaster pipeline or plan that is not one of:
   - `CSharpPackage-5Stage`
   - `PowerShellModule-5Stage`
   - `ReleaseBundle-6Stage`

3. For each old item, decide whether it is deleted immediately, disabled, or
   marked for deletion.
4. Record the decision and date.
5. Confirm `BuildMaster-Pipeline-Topology.md` gap §10.1 is closed or update the
   gap if cleanup is incomplete.

Cleanup inventory:

| Existing pipeline/plan | Keep/delete/disable | Reason | Action date | Operator | Notes |
| ---------------------- | ------------------- | ------ | ----------- | -------- | ----- |
|                        |                     |        |             |          |       |

Actual L3 steps and evidence:

- To be filled during execution.

---

## 5. Issues and Observations

| Date       | Stream task | Issue / observation                                                                                                                                                                                                                                                                                                                                                                                   | Decision / next action                                                                                                                                                                                                                                                                                                                                                                            |
| ---------- | ----------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-05-13 | L1          | First approximation written before UI execution.                                                                                                                                                                                                                                                                                                                                                      | Revise as the user executes the BuildMaster steps.                                                                                                                                                                                                                                                                                                                                                |
| 2026-05-14 | L1          | Preconditions verified in UI with no errors.                                                                                                                                                                                                                                                                                                                                                          | Proceed to create first Application in L1.                                                                                                                                                                                                                                                                                                                                                        |
| 2026-05-14 | L1          | `ATAP.Utilities-CSharp` overview shows `ReleasePerProject` on active releases.                                                                                                                                                                                                                                                                                                                        | Locate and switch Application/Release pipeline binding to durable `CSharpPackage-5Stage`.                                                                                                                                                                                                                                                                                                         |
| 2026-05-14 | L1          | Confirmed `Settings` -> `Pipelines` shows `Release` and `ReleasePerProject` under Application scope.                                                                                                                                                                                                                                                                                                  | Check `Global (Shared)` for `CSharpPackage-5Stage`; if absent, create/align durable pipeline.                                                                                                                                                                                                                                                                                                     |
| 2026-05-14 | L1          | `Global (Shared)` shows no pipelines.                                                                                                                                                                                                                                                                                                                                                                 | Create shared pipeline `CSharpPackage-5Stage` and then bind the application to it.                                                                                                                                                                                                                                                                                                                |
| 2026-05-14 | L1          | Shared pipeline `global::CSharpPackage-5Stage` created and stage order corrected to `Experimental -> Development -> Integration -> QA -> Production`.                                                                                                                                                                                                                                                 | Proceed to bind `ATAP.Utilities-CSharp` releases/builds to the shared durable pipeline and retire legacy `ReleasePerProject` usage.                                                                                                                                                                                                                                                               |
| 2026-05-14 | L1          | Release binding mechanism discovered: Application Settings → Pipelines page shows only Application-scoped pipelines; pipeline selection occurs at Release creation time.                                                                                                                                                                                                                              | Releases tab has "Create Release" button → dialog includes Pipeline dropdown with both Application and Global (Shared) sections.                                                                                                                                                                                                                                                                  |
| 2026-05-14 | L1          | Branch variable updated from `98-sprint-0006-work-items` to `<active-sprint-branch>` in ATAP.Utilities-CSharp application scope for cross-worktree parameterization.                                                                                                                                                                                                                              | Proceed to create Release 'current' with Release name 'current', Pipeline set to `global::CSharpPackage-5Stage`, Branch field defaulting to updated variable.                                                                                                                                                                                                                                     |
| 2026-05-14 | L1          | Create Release dialog shows a `v` prefix in the Release number field as a default placeholder. User accidentally submitted `v` as a release name.                                                                                                                                                                                                                                                     | Clear the entire Release number field before typing the desired name. The `v` prefix is purely cosmetic; BuildMaster does not enforce semantic versioning format.                                                                                                                                                                                                                                 |
| 2026-05-14 | L1          | Attempting to create a release named `current` returned an error: a release with that name already exists (not visible in All Releases list with Status: any — likely in an archived or closed state). The pre-existing "Placeholder" release is already bound to `global::CSharpPackage-5Stage` with branch `<active-sprint-branch>` and no prior builds. This meets all L1 acceptance criteria. | Decision: use the pre-existing "Placeholder" release as the active Sprint-0007 release for ATAP.Utilities-CSharp. Do not attempt to delete or rename. ATAP.Utilities-CSharp L1 complete. Proceed to create `ATAP.Utilities-PowerShell` application.                                                                                                                                               |
| 2026-05-14 | L1          | Creating one BuildMaster application per PowerShell module would require maintaining N applications for N modules — unscalable in a monorepo with many PS modules.                                                                                                                                                                                                                                    | Decision: use a single parameterized `ATAP.Utilities-PowerShell` application for all PowerShell modules. `ModuleName`, `PackageName`, and `PackageVersion` become Build-scope variables supplied by the poller at `New-BuildMasterBuild` call time. Runbook §2.1, §2.4, §2.7, §2.8, and §3 updated accordingly.                                                                                   |
| 2026-05-14 | L1          | Pasting `ReleaseBundle-6Stage.otter` into a Pipeline's JSON Editor failed (`Unexpected character #`); pasting into a Plan's Text Editor failed (`Expected ( or ;` at `stage Experimental {`). OtterScript `stage X { ... }` is pipeline-as-code grammar, not Plan grammar, and the Pipeline JSON Editor describes stage/gate structure, not OtterScript.                                              | Decision: ingest `.otter` files via a Git Raft. Created credential `global::GitHub` (Bitwarden-backed PAT) and raft `ATAP.Utilities-BuildTooling` pointing at `https://github.com/BillHertzing/ATAP.Utilities.git`, branch `<active-sprint-branch>`, path `src/ATAP.Utilities.BuildTooling.BuildMaster`. Runbook §2.9 added. SprintEndAgent must repoint raft Branch to `main` at sprint-end. |
| 2026-05-14 | L1          | BuildMaster Edit Raft dialog has no Path/subfolder field; Git rafts read `Plans/`, `Monitors/`, `Scripts/` from the **repo root** only.                                                                                                                                                                                                                                                               | Relocated `Plans/`, `Monitors/`, `Scripts/` from `src/ATAP.Utilities.BuildTooling.BuildMaster/` to the **ATAP.Utilities repo root** in the sprint worktree. Raft created without a Path field. Runbook §2.9 raft table updated. Commit/push the move so the raft can ingest the files.                                                                                                            |
