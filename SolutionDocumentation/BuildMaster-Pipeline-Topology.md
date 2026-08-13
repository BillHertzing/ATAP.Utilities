# BuildMaster Pipeline Topology

> **Task 13.62 security cutover:** Any raw `ApiKey` parameter or ProGet API-key environment guidance below is superseded. Active callers pass `ProGet.BuildMaster.API.Key` (CI) or `ProGet.Admin.API.Key` (administration) only as a SecretName to a `Get-SecretATAP` leaf, with no fallback.

**Scope:** The catalog of durable BuildMaster pipelines, their relationship to
ProGet feeds, the PowerShell automation surface that drives them, and the
ProGet polling integration that triggers them.
**Audience:** CI engineers maintaining BuildMaster; anyone who needs to
understand which pipeline runs in which scenario; anyone wiring a new
component into the ecosystem.
**Status:** Authoritative for sprint-0007. Replaces the per-area pipeline
diagrams scattered across the C# and PowerShell pipeline docs.

**Companion docs:**

- [Immutable-Build-Strategy.md](Immutable-Build-Strategy.md) — the policy the
  pipelines enforce.
- [BuildMaster-Install-Runbook.md](BuildMaster-Install-Runbook.md)
  — detailed C# and database pipeline reference; install and verify checklist.
- [Release-Bundle-Pipeline.md](Release-Bundle-Pipeline.md) — detailed
  Release Bundle pipeline reference.

---

## 1. Four durable pipelines

| Pipeline name                | Artifact family                      | Tier feeds                                                                                      | Trigger                                                                                  |
| ---------------------------- | ------------------------------------ | ----------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| `CSharp-Package-Pipeline`    | C# NuGet packages                    | `nuget-experimental` → `nuget-stable`                                                           | ProGet polling on `nuget-experimental`; manual create-build.                             |
| `PowerShell-Module-Pipeline` | PowerShellGet modules                | `powershellget-experimental` → `powershellget-stable`                                           | Pilot Git repository monitor for `ATAP.Utilities.BuildTooling.PowerShell`; ProGet polling/manual create-build when the trigger supplies module variables. |
| `Release-Bundle-Pipeline`    | Release Bundles (Universal Packages) | `releasebundle-experimental` → `releasebundle-production` (Distribution stage on hold per D-06) | ProGet polling on `releasebundle-experimental`; manual create-build at release-tag time. |
| `Database-Package-Pipeline`  | Database change-unit NuGet packages  | `database-experimental` → `database-stable`                                                     | ProGet polling on `database-experimental`; manual create-build.                          |

These are the **only four** pipelines. There is no per-project pipeline, no
per-sprint pipeline, no per-feature pipeline. New components reuse the
shared pipeline by being wired up as new BuildMaster Applications that
route through the same plan.

### Pipeline Inventory — Plans, Applications, Final Feeds

Per `ExplainerEliminationPlan_V1.md` decisions **D-05** (shared `.otter`
plans, multiple Applications) and **D-06** (Release Bundle terminates at
`releasebundle-production`; Chocolatey/WinGet on hold), the durable
pipelines map to canonical `.otter` files and BuildMaster Applications as:

| Pipeline          | OtterScript Plan (canonical)         | BuildMaster Application(s)                      | Final ProGet Feed          | Notes                                                                                                                           |
| ----------------- | ------------------------------------ | ----------------------------------------------- | -------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| C# Package        | `CSharpPackage-5Stage.otter`         | `ATAP.Utilities-CSharp`, `AceCommander`         | `nuget-stable`             | Shared plan; package identity is supplied per build by repository monitors or manual build variables. C# pipelines run `Build\Invoke-RepoHealthGate.ps1` after restore and before pack/publish, then use stable Visual Studio Build Tools 2026 MSBuild 18.8+ with SDK-resolved NuGet Pack 7.8+, a Git-derived deterministic timestamp, and a two-pack hash gate. |
| PowerShell Module | `PowerShellModule-5Stage.otter`      | `ATAP.Utilities-PowerShell`                     | `powershellget-stable`     | Shared application for ATAP.Utilities PowerShell modules; `$ModuleName`/`$PackageName` identify the module per build.           |
| Release Bundle    | `ReleaseBundle-6Stage.otter`         | `AceCommander-ReleaseBundle`                    | `releasebundle-production` | Per D-06, BuildMaster Pipeline must NOT include the `Distribution` stage; terminates at Production. Chocolatey/WinGet deferred. |
| Database Package  | `DatabaseChangePackage-5Stage.otter` | `ATAPUtilitiesDatabase`, `AceCommanderDatabase` | `database-stable`          | Shared plan per V4-E. `$DatabaseApplication` and `$DatabaseStream` Application Variables identify the app and stream.           |

All plan files live in `src/ATAP.Utilities.BuildTooling.BuildMaster/Plans/`
and carry header banners documenting the immutable build strategy.

### Required Application Variables per BuildMaster Application

Each BuildMaster Application supplies its own values for the variables its
`.otter` plan reads. Concrete values:

| Variable Name                                      | `ATAP.Utilities-CSharp`                            | `AceCommander`                                     | `ATAP.Utilities` (PowerShell)                               | `AceCommander-ReleaseBundle`                          |
| -------------------------------------------------- | -------------------------------------------------- | -------------------------------------------------- | ----------------------------------------------------------- | ----------------------------------------------------- |
| `$ApplicationName`                                 | `ATAP.Utilities`                                   | `AceCommander`                                     | `ATAP.Utilities-PowerShell`                                 | `AceCommander-ReleaseBundle`                          |
| `$Branch`                                          | injected by Repository Monitor                     | injected by Repository Monitor                     | injected by Repository Monitor or build-trigger script       | injected by Repository Monitor                        |
| `$SourcePath`                                      | path to ATAP.Utilities worktree                    | path to AceCommander worktree                      | path to ATAP.Utilities worktree                             | path to AceCommander worktree                         |
| `$Configuration`                                   | `Release`                                          | `Release`                                          | _(not used)_                                                | _(not used)_                                          |
| `$ProGetApiKeySecretName`                          | `ProGet.BuildMaster.API.Key`                       | `ProGet.BuildMaster.API.Key`                       | `ProGet.BuildMaster.API.Key`                                | `ProGet.BuildMaster.API.Key`                          |
| `$MetaPackageName`                                 | `ATAP.Utilities.StronglyTypedId` (pilot monitor)   | `AceCommander`                                     | _(not used)_                                                | _(not used)_                                          |
| `$SolutionPath` _(new per BD-10)_                  | `ATAP.Utilities.Production.slnf` (pilot monitor)   | `AceCommander.sln`                                 | _(not used)_                                                | _(not used)_                                          |
| `$ProjectPath`                                     | `src/ATAP.Utilities.StronglyTypedId/ATAP.Utilities.StronglyTypedId.csproj` (pilot monitor) | project directory or `.csproj` for NBGV | _(not used)_                                                | _(not used)_                                          |
| `$ModuleName`                                      | _(not used)_                                       | _(not used)_                                       | module folder under `src/`; supplied by monitor or trigger   | _(not used)_                                          |
| `$PackageName`                                     | `ATAP.Utilities.StronglyTypedId` (pilot monitor)   | _(not used)_                                       | normally same as `$ModuleName`; supplied by monitor or trigger | _(not used)_                                        |
| `$PackageVersion`                                  | _(not used; derived as `$ResolvedPackageVersion`)_ | _(not used; derived as `$ResolvedPackageVersion`)_ | _(not used; plan reads captured `$ResolvedPackageVersion`)_ | _(not used directly)_                                 |
| `$Tier`                                            | BuildMaster stage context                          | BuildMaster stage context                          | BuildMaster stage context                                   | BuildMaster stage context                             |
| `$CeilingTier`                                     | preamble-set from `version.json`                   | preamble-set from `version.json`                   | preamble-set from `version.json`                            | preamble-set from `version.json`                      |
| `$ProductName`                                     | _(not used)_                                       | _(not used)_                                       | _(not used)_                                                | `AceCommander`                                        |
| `$ReleaseTag`                                      | _(not used)_                                       | _(not used)_                                       | _(not used)_                                                | e.g. `v1.4.0` (or empty → use `$Branch`)              |
| `$ProGetUrl`                                       | `http://localhost:50000`                           | `http://localhost:50000`                           | `http://localhost:50000`                                    | `http://localhost:50000`                              |
| `$ReleaseBundleExperimentalFeedName`               | _(not used)_                                       | _(not used)_                                       | _(not used)_                                                | `releasebundle-experimental`                          |
| `$ReleaseBundleDevelopmentFeedName`                | _(not used)_                                       | _(not used)_                                       | _(not used)_                                                | `releasebundle-development`                           |
| `$ReleaseBundleIntegrationFeedName`                | _(not used)_                                       | _(not used)_                                       | _(not used)_                                                | `releasebundle-integration`                           |
| `$ReleaseBundleQAFeedName`                         | _(not used)_                                       | _(not used)_                                       | _(not used)_                                                | `releasebundle-qa`                                    |
| `$ReleaseBundleProductionFeedName`                 | _(not used)_                                       | _(not used)_                                       | _(not used)_                                                | `releasebundle-production`                            |
| `$PreviousProductionBackupPath`                    | _(not used)_                                       | _(not used)_                                       | _(not used)_                                                | path to prior production `.bak` (Flyway rehearsal)    |
| `$IntegrationDatabaseDBConnectionStringSecretName` | _(not used)_                                       | _(not used)_                                       | _(not used)_                                                | `dbConnectionString.AceCommander.utat022.Integration` |

`$Tier` is the current BuildMaster stage. `$BuildMasterBuildId` is derived in
each plan with `$BuildMasterId(build)` and is used only for generated run-state
isolation. `$CeilingTier` is not configured on the Application; each plan
preamble computes it with `Get-BuildContext` from the NBGV prerelease label,
writes it to the build-id scoped context folder, and uses
`Test-PromotionWithinCeiling` to skip stages above that ceiling.

> **Do not configure `$CeilingTier` as a BuildMaster Application Variable or
> Pipeline Variable.** It is **preamble-derived runtime state**, not a static
> input. If you find a BuildMaster Application with `$CeilingTier` listed
> under Variables in the UI, delete it — a stale static value will silently
> override the preamble's computed value and either block legitimate
> promotions or allow ones that violate the ceiling. The only correct sources
> for `$CeilingTier` are: (a) the value computed by `Get-BuildContext` in the
> stage preamble, and (b) the captured value re-read from
> `_generated/buildmaster/<BuildMasterBuildId>/build-context.json` by later
> stages of the same build. The same prohibition applies to
> `$ResolvedPackageVersion`, `$AllowDevelopment`, `$AllowIntegration`,
> `$AllowQA`, and `$AllowProduction` — all are preamble-derived.

### Build-id scoped run-state contract

Sprint 0007 selected the file-based Option A state channel:

```text
_generated/buildmaster/<BuildMasterBuildId>/
```

BuildMaster runtime/build variables are not the selected propagation mechanism.
The preamble scripts under
`src/ATAP.Utilities.BuildTooling.BuildMaster/Plans/` initialize this folder at
the start of every stage, using `$BuildMasterId(build)` as the isolation key.
The folder is generated state, not source, and contains the stage's temp files
plus `build-context.json` evidence.

The state folder holds these facts as applicable to the plan: current tier,
ceiling tier, resolved package/module/bundle version, prerelease label,
allow/skip decisions, module nupkg path, ReleaseBundle manifest path, bundle
path, and bundle identity. Later stages read these files from their own build-id
folder; no stage reads flat `_generated/buildmaster/*.tmp` files.

Variable categories are deliberately separate:

- Application/configuration variables are static BuildMaster inputs such as
  `$SourcePath`, `$ModuleName`, and feed names.
- Stage context variables are BuildMaster-provided values such as `$Tier`,
  `$BuildNumber`, `$ExecutionId`, and `$BuildMasterId(build)`.
- Preamble-derived run state is generated from `Get-BuildContext` and stored
  under `_generated/buildmaster/<BuildMasterBuildId>/`.
- Per-build evidence files are generated JSON/temp files retained for
  diagnostics.

Retry semantics: the preamble refreshes recomputable state, but fails if an
existing `build-context.json` in the same build-id folder captured a different
resolved version. Cleanup semantics: helper scripts remove old build-id folders
after 14 days and never delete the active build-id folder.

Operational assumption: every stage in a BuildMaster run must see the same
`$SourcePath` workspace or an equivalent artifact/shared-storage transfer of
`_generated/buildmaster/<BuildMasterBuildId>/`. If stages move across isolated
agents with clean workspaces, add artifact transfer before relying on this
state channel.

---

## 2. What was removed

The previous topology included:

- **Per-project experimental C# 5-tier pipeline** — per-project pipelines
  proliferated even though they only differed by application name and
  package ID. **Replaced** by a single parameterized C# pipeline; the
  per-project plan (`CSharpPackage-PerProject.otter`) is loaded into the
  same Application as the full-solution plan and is selected at build
  time via the `$ProjectPath` build variable.
- **Sprint-specific pipelines** — these never existed in BuildMaster
  itself, but the docs sometimes implied a "sprint pipeline" concept.
  Pipelines do not change per sprint. Sprint-specific behavior lives in
  the prerelease label, not in the pipeline.

---

## 3. BuildMaster Application catalog

Each shipping component has a BuildMaster Application that **routes
through one of the four pipelines**. Variables on the Application
parameterize the pipeline.

| Application                                       | Routes through               | Notes                                                         |
| ------------------------------------------------- | ---------------------------- | ------------------------------------------------------------- |
| `ATAP.Utilities-CSharp`                           | `CSharp-Package-Pipeline`    | All ATAP.Utilities NuGet packages.                            |
| `AceCommander-CSharp`                             | `CSharp-Package-Pipeline`    | AceCommander's library packages (excluding the bundle).       |
| `ATAP.Utilities-PowerShell`                       | `PowerShell-Module-Pipeline` | The build-tooling module itself.                              |
| _(all modules share `ATAP.Utilities-PowerShell`)_ | `PowerShell-Module-Pipeline` | `$ModuleName` build variable identifies the module per build. |
| `AceCommander-ReleaseBundle`                      | `Release-Bundle-Pipeline`    | The customer-facing AceCommander installer.                   |
| `ATAPUtilitiesDatabase`                           | `Database-Package-Pipeline`  | ATAP.Utilities database schema change units.                  |
| `AceCommanderDatabase`                            | `Database-Package-Pipeline`  | AceCommander database schema change units.                    |

All PowerShell modules share a single BuildMaster application,
`ATAP.Utilities-PowerShell`. The module identity is injected at build time
via the `$ModuleName` build variable (with `$PackageName` and
`$PackageVersion`), mirroring the way `$ProjectPath` parameterizes the
`ATAP.Utilities-CSharp` application. No new BuildMaster application is
required when adding a new PowerShell module.

The BuildMaster-native path remains the GitHub repository monitor in
`src/ATAP.Utilities.BuildTooling.BuildMaster/Monitors/PowerShellModule-RepositoryMonitors.otter`.
For local comparison, `Start-LocalPowerShellModuleBuildMasterPoller` performs a
single committed-HEAD poll against `src/ATAP.Utilities.BuildTooling.PowerShell/`,
persists the last seen SHA under `_generated/buildmaster/local-poller/`, and
uses the same `Start-BuildMasterPackagePipeline` handoff when a matching local
commit is detected.

### 3.1 PowerShell Module Release Naming and Collision Avoidance

To support building multiple arbitrary PowerShell modules within the single consolidated BuildMaster application (`ATAP.Utilities-PowerShell`) without collisions, the BuildMaster `ReleaseNumber` is generated uniquely per module.

#### Release Number Format
Because multiple modules (e.g., `ATAP.Utilities.PowerShell` and `ATAP.Utilities.ConfigRootKeys.PowerShell`) can share the same version number (e.g., `0.1.0`), using only the version as the release number would cause them to share/collide on a single BuildMaster release. 

To solve this, `Start-BuildMasterPackagePipeline` constructs the BuildMaster `ReleaseNumber` using the module name as a suffix, conforming strictly to SemVer 2.0.0:
* **Prerelease versions** (e.g., `0.1.0-Alpha.6`): The module name is appended as an additional dot-separated identifier:
  `0.1.0-Alpha.6.ATAP.Utilities.PowerShell`
* **Stable versions** (e.g., `0.1.0`): The module name is appended as a prerelease suffix:
  `0.1.0-ATAP.Utilities.PowerShell`

#### Uniqueness and Isolation
This naming guarantees that each module+version combination receives its own distinct release record and independent execution pipeline in BuildMaster, avoiding release conflicts in the BuildMaster API (e.g., HTTP 409 conflict errors).

#### Internal Scope (No Bleeding)
The module-suffixed release number is strictly internal to BuildMaster. It does **not** bleed into the built package's name, version, or manifest (`.psd1`) file:
* **Manifest and Package Name**: During compilation/pack, versioning is resolved locally from `version.json` via NBGV. The output `.nupkg` package name (e.g., `ATAP.Utilities.PowerShell.0.1.0.nupkg`) and the `.psd1` file contain only the clean version (e.g., `0.1.0`).
* **Promotion and Testing**: Stage runner scripts (like `Invoke-PowerShellModuleBuildMasterStage.ps1`) resolve the package version from the built `.nupkg` file itself or `version.json`, saving it to `build-context.json` under `PackageVersion`. Downstream promotion and testing APIs consume this clean version, so ProGet only ever registers clean package names and versions.

---

## 4. PowerShell automation surface

`ATAP.Utilities.BuildTooling.PowerShell` exposes the cmdlets that
BuildMaster stages call. The pipeline is dumb glue; the cmdlets are where
the logic lives. This is intentional — moving logic out of OtterScript
into cmdlets makes it testable with Pester and reusable from a developer
workstation.

> Cmdlets marked `spec` are referenced by the strategy docs and the BuildMaster pipelines but have not yet been implemented in `ATAP.Utilities.BuildTooling.PowerShell`. Cmdlets marked `partial` have a sibling implementation under a different (legacy or decomposed) name. The Status column below was populated on 2026-05-08 by enumerating `*.ps1` files in the module's `public/` and `private/` folders, then **refined on 2026-05-09** from a developer workstation by reading the module manifest's `FunctionsToExport` list and inspecting the body of every candidate sibling file. It was updated on 2026-05-11 for the Stream I Release Bundle cmdlets.

| Cmdlet                                  | Used by                                            | Role                                                                                                                                                                                                                                                                                                                                                                                                | Status      |
| --------------------------------------- | -------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| `Get-BuildContext`                      | All three pipelines                                | Resolve branch type, application, version, `CurrentTier`, and `CeilingTier`. `.Tier` is a deprecated alias for `CeilingTier` until the next removal release.                                                                                                                                                                                                                                        | implemented |
| `Get-TierOrder`                         | All three pipelines / promotion guards             | Return the canonical tier ordering used for ceiling checks.                                                                                                                                                                                                                                                                                                                                         | implemented |
| `Test-PromotionWithinCeiling`           | All three pipelines / `Promote-ProGetPackage`      | Stop stage execution or promotion before ProGet is called when the destination/current tier is above `CeilingTier`.                                                                                                                                                                                                                                                                                 | implemented |
| `New-ReleaseManifest`                   | Release-Bundle pipeline                            | Generate `manifest.json` for a release tag.                                                                                                                                                                                                                                                                                                                                                         | implemented |
| `New-ReleaseBundle`                     | Release-Bundle pipeline                            | Assemble the bundle directory tree and pack to `.upack`.                                                                                                                                                                                                                                                                                                                                            | implemented |
| `Get-DeployedReleaseManifest`           | Release-Bundle support                             | Read and validate a deployed bundle's `manifest.json`.                                                                                                                                                                                                                                                                                                                                              | implemented |
| `Compare-ReleaseManifest`               | Release-Bundle support                             | Summarize package, migration, and checksum differences between two manifests.                                                                                                                                                                                                                                                                                                                       | implemented |
| `Publish-NuGetPackageToProGet`          | C# pipeline                                        | Push a `.nupkg` to a ProGet NuGet feed (single source of truth for the push command).                                                                                                                                                                                                                                                                                                               | implemented |
| `New-PSModuleNupkg`                     | PowerShell pipeline                                | Pack a PowerShell module folder into a `.nupkg` without publishing it.                                                                                                                                                                                                                                                                                                                              | implemented |
| `Publish-PSModuleToProGet`              | PowerShell pipeline                                | Push a PowerShell `.nupkg` to a ProGet PowerShellGet feed.                                                                                                                                                                                                                                                                                                                                          | implemented |
| `Publish-UniversalPackageToProGet`      | Release-Bundle pipeline                            | Push a `.upack` to a ProGet Universal feed.                                                                                                                                                                                                                                                                                                                                                         | implemented |
| `Promote-ProGetPackage`                 | All three pipelines                                | Call ProGet's promotion API to copy a package between feeds. Idempotent — no-op if already promoted.                                                                                                                                                                                                                                                                                                | implemented |
| `New-BuildMasterRelease`                | All three pipelines                                | Create / update a BuildMaster release record for a specific version.                                                                                                                                                                                                                                                                                                                                | implemented |
| `Start-BuildMasterPipeline`             | Polling task                                       | Trigger a release's pipeline run via BuildMaster API.                                                                                                                                                                                                                                                                                                                                               | implemented |
| `Approve-BuildMasterStage`              | All three pipelines                                | Mark a tier gate passed.                                                                                                                                                                                                                                                                                                                                                                            | implemented |
| `Invoke-FlywayRehearsal`                | Release-Bundle pipeline                            | Apply bundled migrations in a per-run ephemeral rehearsal DB and capture the log.                                                                                                                                                                                                                                                                                                                   | implemented |
| `Publish-ChocolateyRelease`             | Release-Bundle pipeline (Distribution stage)       | Push the Chocolatey wrapper package.                                                                                                                                                                                                                                                                                                                                                                | spec        |
| `Update-WinGetManifestSource`           | Release-Bundle pipeline (Distribution stage)       | Update the WinGet manifest set.                                                                                                                                                                                                                                                                                                                                                                     | spec        |
| `Invoke-PromotedPackageTests`           | C# pipeline (Development–Production tiers)         | Run `dotnet test` against the `.Tests.csproj` project with `UsePackageReferenceForSUT=true` and `SUTVersion` set to the promoted version; accepts `-TestFilter` for tier-appropriate `--filter` arguments. Integration, QA, and Production pass `-LockedRestore`, which adds `dotnet restore --locked-mode`; Development remains unlocked to materialize the per-build promoted-package lock state. | implemented |
| `Invoke-PromotedModuleTests`            | PowerShell pipeline (Development–Production tiers) | Run Pester against the installed promoted PowerShell module version from the tier's feed.                                                                                                                                                                                                                                                                                                           | spec        |
| `New-DatabaseChangePackage`             | Database pipeline (Experimental stage)             | Assemble a database change-unit NuGet content package from Flyway migrations and seed scripts.                                                                                                                                                                                                                                                                                                      | implemented |
| `Get-DatabasePackageManifest`           | Database pipeline / consumer cmdlets               | Read and return the `manifest.json` from a database change package.                                                                                                                                                                                                                                                                                                                                 | implemented |
| `Test-DatabasePackageManifest`          | Database pipeline (Experimental stage)             | Validate the database package manifest against schema and required-field rules.                                                                                                                                                                                                                                                                                                                     | implemented |
| `Test-DatabaseChangePackage`            | Database pipeline (Experimental stage)             | Verify all declared migration scripts are present and checksums match.                                                                                                                                                                                                                                                                                                                              | implemented |
| `Expand-DatabaseChangePackage`          | Database pipeline / rehearsal                      | Extract a database change package to a working directory for inspection or rehearsal.                                                                                                                                                                                                                                                                                                               | implemented |
| `Invoke-DatabasePackageRehearsal`       | Database pipeline (Development stage)              | Apply the package's Flyway migrations against an ephemeral rehearsal database and capture results.                                                                                                                                                                                                                                                                                                  | implemented |
| `Test-FlywayMigrationSafety`            | Database pipeline (Development stage)              | Validate all migrations in the package are additive-only (no destructive DDL).                                                                                                                                                                                                                                                                                                                      | implemented |
| `Test-DatabaseSeedIdempotency`          | Database pipeline (Development stage)              | Verify seed scripts can be run more than once without error or data duplication.                                                                                                                                                                                                                                                                                                                    | implemented |
| `Get-FlywaySchemaVersion`               | Database pipeline / consumer cmdlets               | Return the current Flyway schema version of a target database instance.                                                                                                                                                                                                                                                                                                                             | implemented |
| `New-DatabasePreMigrationSnapshot`      | Database pipeline (QA/Production stages)           | Capture a pre-migration snapshot of the target database for rollback readiness.                                                                                                                                                                                                                                                                                                                     | implemented |
| `Restore-DatabaseFromSnapshot`          | Database pipeline (QA/Production stages)           | Restore a database from a previously captured snapshot.                                                                                                                                                                                                                                                                                                                                             | implemented |
| `Test-DatabaseRollbackReadiness`        | Database pipeline (QA/Production stages)           | Verify that a snapshot is present, restorable, and matches the pre-migration state.                                                                                                                                                                                                                                                                                                                 | implemented |
| `Publish-DatabaseChangePackageToProGet` | Database pipeline (Experimental stage)             | Push a database change-unit NuGet package to the `database-experimental` ProGet feed.                                                                                                                                                                                                                                                                                                               | implemented |
| `Promote-DatabaseChangePackage`         | Database pipeline (all promotion stages)           | Promote a database package between `database-*` feeds, respecting `CeilingTier`.                                                                                                                                                                                                                                                                                                                    | implemented |
| `Resolve-DatabasePackageFeed`           | Database pipeline / consumer cmdlets               | Resolve the correct `database-*` feed for a given environment tier, respecting the ceiling file.                                                                                                                                                                                                                                                                                                    | implemented |
| `Test-DatabasePackageCompatibility`     | Database pipeline (all stages)                     | Validate `compatibleAppPackageRanges` in the database package manifest against the consuming application package version.                                                                                                                                                                                                                                                                           | implemented |
| `Collect-DatabasePackageEvidence`       | Database pipeline (all stages)                     | Gather and archive test results, rehearsal logs, and snapshot metadata as pipeline evidence artifacts.                                                                                                                                                                                                                                                                                              | implemented |

> **Audit-defect resolved (2026-05-11).** `public/Publish-PSModuleToProGetFeed.ps1` now defines `Publish-PSModuleToProGetFeed`; the unused public `Get-PSModuleFeedUri` helper was removed while Stream G introduced the new `Publish-PSModuleToProGet` wrapper.

All cmdlets:

- Are **idempotent** where possible (re-running with the same inputs
  produces the same result and never errors on "already done" states).
- Read environment-specific configuration (feed URLs, API keys) from
  version-controlled `*.psd1` files plus User-scope environment variables.
- Never hard-code feed URLs, API keys, or pipeline IDs.

Ceiling observability: publish and promotion wrappers echo `CeilingTier` in
their returned objects and the Otter preamble writes `build-context.json` plus
temp evidence under `_generated/buildmaster/<BuildMasterBuildId>/`. ProGet
package metadata is not mutated by this implementation; the documented
[ProGet Packages API](https://docs.inedo.com/docs/proget/api/packages)
exposes upload, promote, status, and metadata-read surfaces, but no general
package-metadata write endpoint. If ProGet adds or exposes such a write
surface, the wrappers can attach the same `CeilingTier` value there without
changing the stage guard contract.

---

## 5. Pipeline plan storage

OtterScript plans live under
`src/ATAP.Utilities.BuildTooling.BuildMaster/Plans/` in the ATAP.Utilities
repo. The plans are short — they delegate to PowerShell cmdlets:

```text
Plans/
├── BuildMasterRunContext.Common.ps1       # shared run-state helper
├── Initialize-CSharpPackageBuildContext.ps1
├── Initialize-PowerShellModuleBuildContext.ps1
├── Initialize-ReleaseBundleBuildContext.ps1
├── New-ReleaseBundleBuildMasterPackage.ps1
├── CSharpPackage-5Stage.otter             # full-solution C# pipeline
├── CSharpPackage-PerProject.otter         # single-project C# pipeline (manual trigger)
├── PowerShellModule-5Stage.otter               # PowerShell module pipeline
├── ReleaseBundle-6Stage.otter                  # Release Bundle pipeline (5 tiers + Distribution)
├── Invoke-DatabasePackageBuildMasterStage.ps1  # database pipeline stage runner
└── DatabaseChangePackage-5Stage.otter          # database change-unit pipeline
```

A typical OtterScript stage now looks like:

```otter
stage Development
{
    if $Tier == Development
    {
        if $AllowDevelopment == true
        {
            # No build. Promote the existing artifact, guarded by CeilingTier.
            Exec
            (
                FileName: pwsh,
                Arguments: `-Command "Promote-ProGetPackage -Name $PackageName -Version $ResolvedPackageVersion -FromFeed nuget-experimental -ToFeed nuget-development -Reason 'Pipeline gate DEV-PASS for build $BuildMasterBuildId' -CeilingTier $CeilingTier"`
            );

            # Run integration tests against the existing package.
            Exec
            (
                FileName: pwsh,
                Arguments: `-Command "Invoke-PromotedPackageTests -Name $PackageName -Version $ResolvedPackageVersion -TestFilter 'Category=Integration' -ResultsPath _generated/testresults/development"`,
                SuccessExitCode: 0
            );

            Create-Artifact TestResults ( From: _generated\testresults\development, Include: @(*.trx) );
        }
    }
}

# Source of truth: src/ATAP.Utilities.BuildTooling.BuildMaster/Plans/*.otter
# This Markdown snippet is illustrative; the .otter files are what BuildMaster loads.
```

The plan preamble writes `$AllowDevelopment` by calling the plan-specific
`Initialize-*BuildContext.ps1` script, which in turn calls
`Test-PromotionWithinCeiling -CurrentTier Development -CeilingTier $CeilingTier -AsBoolean`.
Note the absence of `dotnet pack` in the Development stage; that
ran exactly once at Experimental. The Development stage's job is to **test and
promote**, not to rebuild.

### 5.1 Preamble scripts (C10 deliverable)

The OtterScript plans no longer embed multi-line `pwsh -Command` preambles.
Each plan calls a single preamble script via `pwsh -File` with explicit
arguments. The scripts live alongside the `.otter` files in
`src/ATAP.Utilities.BuildTooling.BuildMaster/Plans/` and share state through
the build-id scoped folder described above.

| Preamble script                               | Called from                                               | Computes / captures                                                                                                                                        |
| --------------------------------------------- | --------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `BuildMasterRunContext.Common.ps1`            | dot-sourced by the three `Initialize-*` scripts           | Build-id folder resolution (`_generated/buildmaster/<BuildMasterBuildId>/`), `build-context.json` read/write, retention cleanup, conflicting-version guard |
| `Initialize-CSharpPackageBuildContext.ps1`    | `CSharpPackage-5Stage.otter` Experimental preamble        | `CurrentTier`, `CeilingTier`, `ResolvedPackageVersion`, prerelease label, `AllowDevelopment`/`AllowIntegration`/`AllowQA`/`AllowProduction` flags          |
| `Initialize-PowerShellModuleBuildContext.ps1` | `PowerShellModule-5Stage.otter` Experimental preamble     | Same as C# plus module nupkg path                                                                                                                          |
| `Initialize-ReleaseBundleBuildContext.ps1`    | `ReleaseBundle-6Stage.otter` Experimental preamble        | Same as C# plus bundle name, bundle version, bundle path, manifest path                                                                                    |
| `New-ReleaseBundleBuildMasterPackage.ps1`     | `ReleaseBundle-6Stage.otter` Experimental capture/publish | Assembles and publishes the `.upack`; emits state for later stages                                                                                         |

Each `Initialize-*` script is idempotent within a single BuildMaster build id:
re-invocation refreshes recomputable fields but fails if a previously written
`build-context.json` recorded a different resolved version (retry safety —
see §1 "Build-id scoped run-state contract"). Later stages of the same build
**do not re-invoke** the preamble; they read `build-context.json` from the
shared build-id folder. This is the single mechanism by which `$CeilingTier`,
`$ResolvedPackageVersion`, and the four `$Allow*` flags propagate.

The OtterScript invocation pattern is:

```otter
Exec
(
    FileName: pwsh,
    Arguments: `-File "$SourcePath\src\ATAP.Utilities.BuildTooling.BuildMaster\Plans\Initialize-CSharpPackageBuildContext.ps1" -SourcePath "$SourcePath" -ProjectPath "$ProjectPath" -BuildMasterBuildId "$BuildMasterId(build)" -Tier "$Tier"`
);
```

`pwsh -Command` one-liners are no longer used for preambles. See task C10 in
`_Planning-wt-14-Sprint-0007-work-items\TASKS_V3GPT5.5.md` for the migration
record.

### 5.2 Ceiling-skip markers (pending C12)

When a stage's `$Allow<Tier>` flag is `false` — meaning `Test-PromotionWithinCeiling`
reported `CurrentTier > CeilingTier` — the stage body is skipped entirely.
For audit, every skip must emit a **ceiling-skip marker** so a reader of the
BuildMaster build log can answer "why didn't QA run?" without re-deriving the
ceiling math.

The contract (to be implemented in task **C12**, currently open):

| Element               | Value                                                                                                                        |
| --------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| Marker type           | BuildMaster artifact named `CeilingSkipMarkers`                                                                              |
| One marker per        | skipped stage in a single build                                                                                              |
| Marker payload (JSON) | `{ stage, currentTier, ceilingTier, resolvedVersion, prereleaseLabel, buildMasterBuildId, reason }`                          |
| Storage location      | `_generated/buildmaster/<BuildMasterBuildId>/ceiling-skip-<Stage>.json`, then attached as the `CeilingSkipMarkers` artifact  |
| Log line              | `Stage <Stage> skipped: CurrentTier=<X> exceeds CeilingTier=<Y> for <PackageName> <Version>` (PSFramework `Important` level) |

Until C12 lands, the plans skip stages cleanly but do not emit the structured
marker. A Sprint 0007 ceiling smoke run (task C02) will be re-verified against
this contract once C12 ships.

---

## 6. ProGet polling integration

ProGet is the package source. A polling task is the event detector.
BuildMaster is the automation engine.

Polling is the baseline integration because ProGet Free does not provide
custom package-event callbacks. The poller runs on a controlled host,
queries ProGet at a fixed interval, normalizes newly detected packages,
and calls BuildMaster APIs to create or start the matching release.

### 6.1 What the poller queries

The poller checks the Experimental feed for each durable pipeline:

- `nuget-experimental` → triggers C# pipeline.
- `powershellget-experimental` → triggers PowerShell pipeline.
- `releasebundle-experimental` → triggers Release Bundle pipeline.

Promotions between later feeds are not new-build triggers. Promotion
metadata can be reconciled by the poller or by the pipeline stage that
performs the promotion, but it must not create a second BuildMaster run.

### 6.2 Polling event record

For each package version not yet handed to BuildMaster, the poller
normalizes the ProGet response into a stable event record:

```json
{
  "source": "ProGetPolling",
  "applicationName": "ATAP.Utilities-CSharp",
  "packageName": "ATAP.Utilities",
  "packageVersion": "0.1.0-Sprint.142",
  "feedName": "nuget-experimental",
  "packageType": "nuget",
  "detectedUtc": "2026-05-12T14:30:00Z",
  "reason": "ATAP.Utilities 0.1.0-Sprint.142 detected in nuget-experimental"
}
```

`feedName`, `packageName`, and `packageVersion` come from ProGet.
`applicationName` is resolved from the feed/package-to-Application map
recorded in the BuildMaster configuration runbook.

### 6.3 What the poller does

The poller:

1. Reads the configured ProGet base URL, BuildMaster base URL, feed list,
   feed/package-to-Application map, and state-file path, and retrieves the
   ProGet and BuildMaster API keys from Bitwarden (see §6.4).
2. Queries ProGet package-list APIs for each Experimental feed.
3. Compares each `(feedName, packageName, packageVersion)` tuple against
   durable polling state.
4. Calls `New-BuildMasterRelease` for the mapped Application and version.
5. Calls `Start-BuildMasterPipeline` for the same Application and version.
6. Marks the tuple consumed only after the BuildMaster calls succeed.

The state file must be durable across restarts and protected from casual
edits; use a host-local operations path such as
`C:\ProgramData\ATAP.Utilities\BuildMaster\proget-polling-state.json` or a
runbook-approved equivalent. If a BuildMaster call fails, the tuple stays
unconsumed so the next poll can retry.

### 6.4 Scheduling, idempotency, and security

The default polling interval is 60 seconds unless the operations runbook
chooses a slower interval for the host. The polling task can be a Windows
Scheduled Task, a BuildMaster recurring job, or another controlled
operations runner, but it must have exactly one active writer for the
state file.

The integration is idempotent at the `(feedName, packageName,
packageVersion)` level. Existing BuildMaster release records are updated
or reused; a package version that has already triggered a run is not
started again unless the state entry is intentionally removed during a
documented replay.

No inbound endpoint is required.

**Credential source.** The poller needs two API keys — a ProGet key (feed
read) and a BuildMaster key (release create / build start). Both are stored
in Bitwarden and retrieved at poller startup with `Get-SecretATAP`; the
configured provider may be Bitwarden Password Manager (`bw`) or Bitwarden
Secrets Manager (`bws`). The resolved values exist only in the running
poller process and are never
written to the polling state file, package metadata, the scheduled-task
definition, or runbook examples. The exact Bitwarden item names, and the
minimum scope each key carries (ProGet: read on the three Experimental feeds
only — not promote or delete; BuildMaster: release-create and build-start on
the three durable Applications only), are recorded in the BuildMaster
configuration runbook. The poller uses its approved canonical SecretName and
never receives or exports a resolved ProGet value.

**Runner identity and state-file ACL.** The single active runner executes
under a dedicated operations service account — not a developer's interactive
account — and that account is the only writer of the state file. The state
file is ACL'd so that only the runner's service account and local
administrators can read or write it; it holds `(feedName, packageName,
packageVersion)` tuples and timestamps only, never a credential.

---

## 7. Tiers — five is enough

The five-tier ladder (Experimental → Development → Integration → QA →
Production) is sufficient for everything the ecosystem ships today. The
research note explicitly evaluated additions and rejected them:

- **PreProd / Staging** — not added. QA is production-shaped; a separate
  Staging tier would only add value if we needed customer-data masking
  with topology-identical-to-prod, which we do not have today.
- **Hotfix** — not a tier. Hotfixes are a branch/release type that flows
  through the same five tiers with compressed gates.

If a future component requires materially different approval logic or
deployment topology, the right answer is usually "a new BuildMaster
Application routing through the same pipeline" rather than "a sixth
tier."

---

## 8. Branch and release behavior at sprint boundaries

(Reproduced from [Immutable-Build-Strategy.md §8](Immutable-Build-Strategy.md#8-branch-behavior-at-sprint--feature-boundaries) for convenience.)

| Boundary                          | Pipelines | Releases / metadata                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| --------------------------------- | --------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Feature start                     | None      | BuildMaster creates a **new Release scoped to `$FeatureSlug`** (distinct from the trunk Release). `$FeatureSlug` is computed from the branch name per E-DEC-01 (PascalCase, ≤16 chars, derived from the `feature/` suffix). The first Experimental build produces `0.1.0-<FeatureSlug>.1`. Feature artifacts share the trunk feeds; the prerelease suffix provides isolation.                                                                                                                                                                                         |
| Feature in progress (each sprint) | None      | Feature artifacts are promoted through **all five tiers** under the feature suffix (`0.1.0-<FeatureSlug>.NNN`) using `Promote-ProGetPackage`. The **QA gate is required before merge to stable** — feature artifacts may be promoted to QA, but **no Production promotion** of feature artifacts is permitted until merge. DB migrations on the feature branch must be **additive-only** (no `ALTER COLUMN`, no `DROP`).                                                                                                                                              |
| Sprint start                      | None      | Create release-train naming context; package versions inherit it.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| During sprint                     | None      | Each push triggers an Experimental build via the durable pipeline.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| Feature end / merge to stable     | None      | Before merge: **DB migrations are squashed and re-sequenced** to follow trunk's highest existing migration number (no gaps). `version.json` on trunk is updated so the prerelease label is **`Sprint`** (manual step, must precede the pipeline run). After merge, a **trunk Experimental build is triggered**; the first trunk artifact is `Sprint.NNN` where `NNN` resets to trunk's HEAD height. The **feature BuildMaster Release is archived**. The feature's `<FeatureSlug>.NNN` artifacts remain in feeds under their suffix but receive no further promotion. |
| Sprint end                        | None      | Cut a `release/*` branch from stable; build artifacts from the tag.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| Release cut                       | None      | Build the Release Bundle once from the release-branch tag; promote the same artifact through five tiers; publish to Chocolatey / WinGet.                                                                                                                                                                                                                                                                                                                                                                                                                              |
| _Full lifecycle details_          | _—_       | _See [`Long-Developing-Features.md`](Long-Developing-Features.md) for the complete feature-branch lifecycle, version-string rules (E-DEC-01), sprint-slice interaction (E-DEC-02), feed targets (E-DEC-03), merge mechanics (E-DEC-04), and DB-compatibility rule (E-DEC-05)._                                                                                                                                                                                                                                                                                        |

The first time a brand-new component is added (one that needs its own
BuildMaster Application identity) is the only sprint-cadence change to
BuildMaster configuration — and even then it's one new Application, not a
new pipeline.

---

## 9. Pipeline failure semantics

| Failure                                  | Action                                                                                                                                                             |
| ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Build (Experimental) fails               | No artifact pushed. BuildMaster marks the release `failed`. No promotion possible.                                                                                 |
| Test gate at any later tier fails        | The artifact stays in its current feed. BuildMaster marks the gate `failed`. The artifact is not promoted, but is also not destroyed (developers can investigate). |
| Promotion API call fails (transient)     | The cmdlet retries with exponential backoff. Persistent failures abort the stage and require manual ProGet investigation.                                          |
| Distribution (Chocolatey / WinGet) fails | The Production-tier promotion still succeeded. Distribution is retried manually after fixing the issue.                                                            |

A failed gate **never** rebuilds the artifact in an attempt to "make it
work this time." If the fix requires a new artifact, the source must
change, the version must bump (NBGV `{height}` does this automatically on
a new commit), and the new artifact starts from Experimental again.

---

## 10. Known drift and gaps (sprint-0007)

1. **Old per-project experimental C# pipelines may still exist in
   BuildMaster.** Audit task: list all pipelines, delete any that are not
   one of the three durable ones.
2. **Historical per-tier `dotnet pack` drift is resolved in the canonical
   plans.** `CSharpPackage-5Stage.otter` and `PowerShellModule-5Stage.otter`
   now build/package only at Experimental and promote the captured version in
   later tiers. Remaining risk is stale Markdown snippets or archived plans
   outside `src/ATAP.Utilities.BuildTooling.BuildMaster/Plans/`.
3. **`Publish-NuGetPackageToProGet` consolidation is incomplete.** The
   single-source-of-truth cmdlet exists but legacy scripts still call
   `dotnet nuget push` directly in some places.
4. **ProGet polling trigger is not yet wired.** The polling task, schedule,
   state-file path, feed/package-to-Application map, credential source
   (Bitwarden), runner service account, and state-file ACL still need to be
   implemented and recorded in the BuildMaster configuration runbook.
5. **BuildMaster API base URL is host-specific** (`utat022:81` vs.
   `localhost:81` vs. eventual production hostname). Centralize it in the
   same configuration consumed by the polling task.

---

## 11. Quick reference

List the durable pipelines:

```powershell
Get-BuildMasterPipeline | Where-Object { $_.Name -in @(
    'CSharp-Package-Pipeline',
    'PowerShell-Module-Pipeline',
    'Release-Bundle-Pipeline'
) }
```

Trigger the Release Bundle pipeline manually for a release tag:

```powershell
Start-BuildMasterPipeline `
  -Pipeline      'Release-Bundle-Pipeline' `
  -Application   'AceCommander-ReleaseBundle' `
  -ReleaseNumber '1.4.0' `
  -Reason        'Manual cut for v1.4.0'
```

Promote a C# package between tiers (idempotent):

```powershell
Promote-ProGetPackage `
  -Name     'ATAP.Utilities.Philote' `
  -Version  '0.1.0-Beta.42' `
  -FromFeed 'nuget-development' `
  -ToFeed   'nuget-integration' `
  -Reason   'INT-PASS for build #4271'
```

---

## 12. Related documents

- [Immutable-Build-Strategy.md](Immutable-Build-Strategy.md) — the policy.
- [BuildMaster-ProGet-CSharp-Package-Pipeline.md](BuildMaster-ProGet-CSharp-Package-Pipeline.md) — detailed C# plan.
- [Release-Bundle-Pipeline.md](Release-Bundle-Pipeline.md) — detailed Release Bundle plan.
- [Release-Branch-and-Manifest.md](Release-Branch-and-Manifest.md) — what the bundle pipeline consumes.
- [Database-Change-Unit-and-Flyway-Promotion.md](Database-Change-Unit-and-Flyway-Promotion.md) — DB content the bundle wraps.
- [Production-and-Tooling-Overview.md](Production-and-Tooling-Overview.md) — index.
