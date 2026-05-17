# BuildMaster Pipeline Topology

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
- [BuildMaster-ProGet-CSharp-Package-Pipeline.md](BuildMaster-ProGet-CSharp-Package-Pipeline.md)
  — detailed C# pipeline reference.
- [Release-Bundle-Pipeline.md](Release-Bundle-Pipeline.md) — detailed
  Release Bundle pipeline reference.

---

## 1. Three durable pipelines

| Pipeline name                | Artifact family                      | Tier feeds                                                               | Trigger                                                                                  |
| ---------------------------- | ------------------------------------ | ------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------- |
| `CSharp-Package-Pipeline`    | C# NuGet packages                    | `nuget-experimental` → `nuget-stable`                                    | ProGet polling on `nuget-experimental`; manual create-build.                             |
| `PowerShell-Module-Pipeline` | PowerShellGet modules                | `PowershellGet-experimental` → `PowershellGet-stable`                    | ProGet polling on `PowershellGet-experimental`; manual create-build.                     |
| `Release-Bundle-Pipeline`    | Release Bundles (Universal Packages) | `releasebundle-experimental` → `releasebundle-production` (Distribution stage on hold per D-06) | ProGet polling on `releasebundle-experimental`; manual create-build at release-tag time. |

These are the **only** pipelines. There is no per-project pipeline, no
per-sprint pipeline, no per-feature pipeline. New components reuse the
shared pipeline by being wired up as new BuildMaster Applications that
route through the same plan.

### Pipeline Inventory — Plans, Applications, Final Feeds

Per `ExplainerEliminationPlan_V1.md` decisions **D-05** (shared `.otter`
plans, multiple Applications) and **D-06** (Release Bundle terminates at
`releasebundle-production`; Chocolatey/WinGet on hold), the durable
pipelines map to canonical `.otter` files and BuildMaster Applications as:

| Pipeline           | OtterScript Plan (canonical)        | BuildMaster Application(s)                       | Final ProGet Feed         | Notes                                                                                            |
| ------------------ | ----------------------------------- | ------------------------------------------------ | ------------------------- | ------------------------------------------------------------------------------------------------ |
| C# Package         | `CSharpPackage-5Stage.otter`        | `ATAP.Utilities-CSharp`, `AceCommander`          | `nuget-stable`            | Shared plan; two Applications per D-05. `$SolutionPath` Application Variable selects the `.sln`. |
| PowerShell Module  | `PowerShellModule-5Stage.otter`     | `ATAP.Utilities`                                 | `powershellget-stable`    | PowerShell modules live only in ATAP.Utilities.                                                  |
| Release Bundle     | `ReleaseBundle-6Stage.otter`        | `AceCommander-ReleaseBundle`                     | `releasebundle-production`| Per D-06, BuildMaster Pipeline must NOT include the `Distribution` stage; terminates at Production. Chocolatey/WinGet deferred. |

All plan files live in `src/ATAP.Utilities.BuildTooling.BuildMaster/Plans/`
and carry header banners documenting the immutable build strategy.

### Required Application Variables per BuildMaster Application

Each BuildMaster Application supplies its own values for the variables its
`.otter` plan reads. Concrete values:

| Variable Name                                | `ATAP.Utilities-CSharp`                  | `AceCommander`                                | `ATAP.Utilities` (PowerShell)             | `AceCommander-ReleaseBundle`              |
| -------------------------------------------- | ---------------------------------------- | --------------------------------------------- | ----------------------------------------- | ----------------------------------------- |
| `$ApplicationName`                           | `ATAP.Utilities-CSharp`                  | `AceCommander`                                | `ATAP.Utilities`                          | `AceCommander-ReleaseBundle`              |
| `$Branch`                                    | injected by Repository Monitor           | injected by Repository Monitor                | injected by Repository Monitor            | injected by Repository Monitor            |
| `$SourcePath`                                | path to ATAP.Utilities worktree          | path to AceCommander worktree                 | path to ATAP.Utilities worktree           | path to AceCommander worktree             |
| `$Configuration`                             | `Release`                                | `Release`                                     | _(not used)_                              | _(not used)_                              |
| `$ProGetApiKey`                              | masked, from `PROGET_ADMIN_API_KEY`      | masked, from `PROGET_ADMIN_API_KEY`           | masked, from `PROGET_ADMIN_API_KEY`       | masked, from `PROGET_ADMIN_API_KEY`       |
| `$MetaPackageName`                           | `ATAP.Utilities`                         | `AceCommander`                                | _(not used)_                              | _(not used)_                              |
| `$SolutionPath` _(new per BD-10)_            | `ATAP.Utilities.sln`                     | `AceCommander.sln`                            | _(not used)_                              | _(not used)_                              |
| `$ModuleName`                                | _(not used)_                             | _(not used)_                                  | module folder under `src/`                | _(not used)_                              |
| `$PackageName`                               | _(not used)_                             | _(not used)_                                  | normally same as `$ModuleName`            | _(not used)_                              |
| `$PackageVersion`                            | _(derived via Get-BuildContext)_         | _(derived via Get-BuildContext)_              | exact package version to promote/test     | _(not used directly)_                     |
| `$Tier`                                      | _(derived via Get-BuildContext)_         | _(derived via Get-BuildContext)_              | current tier (BD-14 may align)            | _(derived via Get-BuildContext)_          |
| `$ProductName`                               | _(not used)_                             | _(not used)_                                  | _(not used)_                              | `AceCommander`                            |
| `$ReleaseTag`                                | _(not used)_                             | _(not used)_                                  | _(not used)_                              | e.g. `v1.4.0` (or empty → use `$Branch`)  |
| `$ProGetUrl`                                 | _(not used directly)_                    | _(not used directly)_                         | _(not used directly)_                     | `http://localhost:50000`                  |
| `$ReleaseBundleExperimentalFeedName`         | _(not used)_                             | _(not used)_                                  | _(not used)_                              | `releasebundle-experimental`              |
| `$ReleaseBundleDevelopmentFeedName`          | _(not used)_                             | _(not used)_                                  | _(not used)_                              | `releasebundle-development`               |
| `$ReleaseBundleIntegrationFeedName`          | _(not used)_                             | _(not used)_                                  | _(not used)_                              | `releasebundle-integration`               |
| `$ReleaseBundleQAFeedName`                   | _(not used)_                             | _(not used)_                                  | _(not used)_                              | `releasebundle-qa`                        |
| `$ReleaseBundleProductionFeedName`           | _(not used)_                             | _(not used)_                                  | _(not used)_                              | `releasebundle-production`                |
| `$PreviousProductionBackupPath`              | _(not used)_                             | _(not used)_                                  | _(not used)_                              | path to prior production `.bak` (Flyway rehearsal) |
| `$IntegrationDatabaseBitwardenSecretName`    | _(not used)_                             | _(not used)_                                  | _(not used)_                              | `dbConnectionString-AceCommander-utat022-Integration` |

> **BD-13 follow-up:** The `$Tier` field is currently derived via
> `Get-BuildContext` in the C# and ReleaseBundle plans, but its resolution
> semantics (NBGV label vs BuildMaster pipeline stage context) need
> verification. See `ExplainerEliminationPlan_V1.md` Section 0c.

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
through one of the three pipelines**. Variables on the Application
parameterize the pipeline.

| Application                                       | Routes through               | Notes                                                         |
| ------------------------------------------------- | ---------------------------- | ------------------------------------------------------------- |
| `ATAP.Utilities-CSharp`                           | `CSharp-Package-Pipeline`    | All ATAP.Utilities NuGet packages.                            |
| `AceCommander-CSharp`                             | `CSharp-Package-Pipeline`    | AceCommander's library packages (excluding the bundle).       |
| `ATAP.Utilities-PowerShell`                       | `PowerShell-Module-Pipeline` | The build-tooling module itself.                              |
| _(all modules share `ATAP.Utilities-PowerShell`)_ | `PowerShell-Module-Pipeline` | `$ModuleName` build variable identifies the module per build. |
| `AceCommander-ReleaseBundle`                      | `Release-Bundle-Pipeline`    | The customer-facing AceCommander installer.                   |

All PowerShell modules share a single BuildMaster application,
`ATAP.Utilities-PowerShell`. The module identity is injected at build time
via the `$ModuleName` build variable (with `$PackageName` and
`$PackageVersion`), mirroring the way `$ProjectPath` parameterizes the
`ATAP.Utilities-CSharp` application. No new BuildMaster application is
required when adding a new PowerShell module.

---

## 4. PowerShell automation surface

`ATAP.Utilities.BuildTooling.PowerShell` exposes the cmdlets that
BuildMaster stages call. The pipeline is dumb glue; the cmdlets are where
the logic lives. This is intentional — moving logic out of OtterScript
into cmdlets makes it testable with Pester and reusable from a developer
workstation.

> Cmdlets marked `spec` are referenced by the strategy docs and the BuildMaster pipelines but have not yet been implemented in `ATAP.Utilities.BuildTooling.PowerShell`. Cmdlets marked `partial` have a sibling implementation under a different (legacy or decomposed) name. The Status column below was populated on 2026-05-08 by enumerating `*.ps1` files in the module's `public/` and `private/` folders, then **refined on 2026-05-09** from a developer workstation by reading the module manifest's `FunctionsToExport` list and inspecting the body of every candidate sibling file. It was updated on 2026-05-11 for the Stream I Release Bundle cmdlets.

| Cmdlet                             | Used by                                            | Role                                                                                                                                                                                                       | Status      |
| ---------------------------------- | -------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| `Get-BuildContext`                 | All three pipelines                                | Resolve branch type, application, version, tier from environment.                                                                                                                                          | implemented |
| `New-ReleaseManifest`              | Release-Bundle pipeline                            | Generate `manifest.json` for a release tag.                                                                                                                                                                | implemented |
| `New-ReleaseBundle`                | Release-Bundle pipeline                            | Assemble the bundle directory tree and pack to `.upack`.                                                                                                                                                   | implemented |
| `Get-DeployedReleaseManifest`      | Release-Bundle support                             | Read and validate a deployed bundle's `manifest.json`.                                                                                                                                                     | implemented |
| `Compare-ReleaseManifest`          | Release-Bundle support                             | Summarize package, migration, and checksum differences between two manifests.                                                                                                                              | implemented |
| `Publish-NuGetPackageToProGet`     | C# pipeline                                        | Push a `.nupkg` to a ProGet NuGet feed (single source of truth for the push command).                                                                                                                      | implemented |
| `New-PSModuleNupkg`                | PowerShell pipeline                                | Pack a PowerShell module folder into a `.nupkg` without publishing it.                                                                                                                                     | implemented |
| `Publish-PSModuleToProGet`         | PowerShell pipeline                                | Push a PowerShell `.nupkg` to a ProGet PowerShellGet feed.                                                                                                                                                 | implemented |
| `Publish-UniversalPackageToProGet` | Release-Bundle pipeline                            | Push a `.upack` to a ProGet Universal feed.                                                                                                                                                                | implemented |
| `Promote-ProGetPackage`            | All three pipelines                                | Call ProGet's promotion API to copy a package between feeds. Idempotent — no-op if already promoted.                                                                                                       | implemented |
| `New-BuildMasterRelease`           | All three pipelines                                | Create / update a BuildMaster release record for a specific version.                                                                                                                                       | implemented |
| `Start-BuildMasterPipeline`        | Polling task                                       | Trigger a release's pipeline run via BuildMaster API.                                                                                                                                                      | implemented |
| `Approve-BuildMasterStage`         | All three pipelines                                | Mark a tier gate passed.                                                                                                                                                                                   | implemented |
| `Invoke-FlywayRehearsal`           | Release-Bundle pipeline                            | Apply bundled migrations in a per-run ephemeral rehearsal DB and capture the log.                                                                                                                          | implemented |
| `Publish-ChocolateyRelease`        | Release-Bundle pipeline (Distribution stage)       | Push the Chocolatey wrapper package.                                                                                                                                                                       | spec        |
| `Update-WinGetManifestSource`      | Release-Bundle pipeline (Distribution stage)       | Update the WinGet manifest set.                                                                                                                                                                            | spec        |
| `Invoke-PromotedPackageTests`      | C# pipeline (Development–Production tiers)         | Run `dotnet test` against the `.Tests.csproj` project with `UsePackageReferenceForSUT=true` and `SUTVersion` set to the promoted version; accepts `-TestFilter` for tier-appropriate `--filter` arguments. | spec        |
| `Invoke-PromotedModuleTests`       | PowerShell pipeline (Development–Production tiers) | Run Pester against the installed promoted PowerShell module version from the tier's feed.                                                                                                                  | spec        |

> **Audit-defect resolved (2026-05-11).** `public/Publish-PSModuleToProGetFeed.ps1` now defines `Publish-PSModuleToProGetFeed`; the unused public `Get-PSModuleFeedUri` helper was removed while Stream G introduced the new `Publish-PSModuleToProGet` wrapper.

All cmdlets:

- Are **idempotent** where possible (re-running with the same inputs
  produces the same result and never errors on "already done" states).
- Read environment-specific configuration (feed URLs, API keys) from
  version-controlled `*.psd1` files plus User-scope environment variables.
- Never hard-code feed URLs, API keys, or pipeline IDs.

---

## 5. Pipeline plan storage

OtterScript plans live under
`src/ATAP.Utilities.BuildTooling.BuildMaster/Plans/` in the ATAP.Utilities
repo. The plans are short — they delegate to PowerShell cmdlets:

```text
Plans/
├── CSharpPackage-5Stage.otter             # full-solution C# pipeline
├── CSharpPackage-PerProject.otter         # single-project C# pipeline (manual trigger)
├── PowerShellModule-5Stage.otter          # PowerShell module pipeline
└── ReleaseBundle-6Stage.otter             # Release Bundle pipeline (5 tiers + Distribution)
```

A typical OtterScript stage now looks like:

```otter
stage Development
{
    if $Tier == Development
    {
        # No build. Promote the existing artifact.
        Exec
        (
            FileName: pwsh,
            Arguments: `-Command "Promote-ProGetPackage -Name $PackageName -Version $PackageVersion -FromFeed nuget-experimental -ToFeed nuget-development -Reason 'Pipeline gate DEV-PASS for build $BuildId'"`
        );

        # Run integration tests against the existing package.
        Exec
        (
            FileName: pwsh,
            Arguments: `-Command "Invoke-PromotedPackageTests -Name $PackageName -Version $PackageVersion -TestFilter 'Category=Integration' -ResultsPath _generated/testresults/development"`,
            SuccessExitCode: 0
        );

        Create-Artifact TestResults ( From: _generated\testresults\development, Include: @(*.trx) );
    }
}

# Source of truth: src/ATAP.Utilities.BuildTooling.BuildMaster/Plans/*.otter
# This Markdown snippet is illustrative; the .otter files are what BuildMaster loads.
```

Note the absence of `dotnet pack` in the Development stage — that ran
exactly once at Experimental. The Development stage's job is to **test
and promote**, not to rebuild.

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
- `PowershellGet-experimental` → triggers PowerShell pipeline.
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
in Bitwarden and retrieved at poller startup with `Get-BitWardenSecret`; the
resolved values exist only in the running poller process and are never
written to the polling state file, package metadata, the scheduled-task
definition, or runbook examples. The exact Bitwarden item names, and the
minimum scope each key carries (ProGet: read on the three Experimental feeds
only — not promote or delete; BuildMaster: release-create and build-start on
the three durable Applications only), are recorded in the BuildMaster
configuration runbook. Do not reuse the broad `PROGET_ADMIN_API_KEY` for the
poller.

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
2. **OtterScript plans still reference per-tier `dotnet pack` calls.**
   Plans need to be rewritten to call `Promote-ProGetPackage` at all tiers
   except Experimental. Tracked.
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
