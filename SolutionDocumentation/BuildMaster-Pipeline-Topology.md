# BuildMaster Pipeline Topology

**Scope:** The catalog of durable BuildMaster pipelines, their relationship to
ProGet feeds, the PowerShell automation surface that drives them, and the
ProGet-webhook integration that triggers them.
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

| Pipeline name             | Artifact family              | Tier feeds                                   | Trigger                                   |
| ------------------------- | ---------------------------- | -------------------------------------------- | ----------------------------------------- |
| `CSharp-Package-Pipeline` | C# NuGet packages            | `nuget-experimental` → `nuget-stable`        | ProGet webhook on `nuget-experimental`; manual create-build. |
| `PowerShell-Module-Pipeline` | PowerShellGet modules     | `PowershellGet-experimental` → `PowershellGet-stable` | ProGet webhook on `PowershellGet-experimental`; manual create-build. |
| `Release-Bundle-Pipeline` | Release Bundles (Universal Packages) | `ReleaseBundle-Experimental` → `ReleaseBundle-Production` + Distribution | ProGet webhook on `ReleaseBundle-Experimental`; manual create-build at release-tag time. |

These are the **only** pipelines. There is no per-project pipeline, no
per-sprint pipeline, no per-feature pipeline. New components reuse the
shared pipeline by being wired up as new BuildMaster Applications that
route through the same plan.

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

| Application                          | Routes through                | Notes                                                       |
| ------------------------------------ | ----------------------------- | ----------------------------------------------------------- |
| `ATAP.Utilities-CSharp`              | `CSharp-Package-Pipeline`     | All ATAP.Utilities NuGet packages.                          |
| `AceCommander-CSharp`                | `CSharp-Package-Pipeline`     | AceCommander's library packages (excluding the bundle).     |
| `ATAP.Utilities.BuildTooling.PowerShell-PSModule` | `PowerShell-Module-Pipeline` | The build-tooling module itself.                  |
| `ATAP.Utilities.FileIO.PowerShell-PSModule`       | `PowerShell-Module-Pipeline` | One application per first-party module.                    |
| `…` (one app per PowerShell module)  | `PowerShell-Module-Pipeline`  |                                                             |
| `AceCommander-ReleaseBundle`         | `Release-Bundle-Pipeline`     | The customer-facing AceCommander installer.                 |

The "one app per module" rule for PowerShell is a convenience for
BuildMaster's UI (each app shows the latest build of its module on its own
page). It does not multiply pipelines — all PowerShell apps share the same
plan and the same pipeline definition.

---

## 4. PowerShell automation surface

`ATAP.Utilities.BuildTooling.PowerShell` exposes the cmdlets that
BuildMaster stages call. The pipeline is dumb glue; the cmdlets are where
the logic lives. This is intentional — moving logic out of OtterScript
into cmdlets makes it testable with Pester and reusable from a developer
workstation.

| Cmdlet                            | Used by                          | Role                                                                                                |
| --------------------------------- | -------------------------------- | --------------------------------------------------------------------------------------------------- |
| `Get-BuildContext`                | All three pipelines              | Resolve branch type, application, version, tier from environment.                                   |
| `New-ReleaseManifest`             | Release-Bundle pipeline          | Generate `manifest.json` for a release tag.                                                         |
| `New-ReleaseBundle`               | Release-Bundle pipeline          | Assemble the bundle directory tree and pack to `.upack`.                                            |
| `Publish-NuGetPackageToProGet`    | C# pipeline                      | Push a `.nupkg` to a ProGet NuGet feed (single source of truth for the push command).               |
| `Publish-PSModuleToProGet`        | PowerShell pipeline              | Push a PowerShell `.nupkg` to a ProGet PowerShellGet feed.                                          |
| `Publish-UniversalPackageToProGet`| Release-Bundle pipeline          | Push a `.upack` to a ProGet Universal feed.                                                         |
| `Promote-ProGetPackage`           | All three pipelines              | Call ProGet's promotion API to copy a package between feeds. Idempotent — no-op if already promoted. |
| `New-BuildMasterRelease`          | All three pipelines              | Create / update a BuildMaster release record for a specific version.                                |
| `Start-BuildMasterPipeline`       | Trigger handlers                 | Trigger a release's pipeline run via BuildMaster API.                                               |
| `Approve-BuildMasterStage`        | All three pipelines              | Mark a tier gate passed.                                                                            |
| `Invoke-FlywayRehearsal`          | Release-Bundle pipeline          | Apply bundled migrations to a previous-prod snapshot.                                               |
| `Publish-ChocolateyRelease`       | Release-Bundle pipeline (Distribution stage) | Push the Chocolatey wrapper package.                                                    |
| `Update-WinGetManifestSource`     | Release-Bundle pipeline (Distribution stage) | Update the WinGet manifest set.                                                         |

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
            Arguments: `-Command "Invoke-IntegrationTests -PackageName $PackageName -PackageVersion $PackageVersion -ResultsPath _generated/testresults/development"`,
            SuccessExitCode: 0
        );

        Create-Artifact TestResults ( From: _generated\testresults\development, Include: @(*.trx) );
    }
}
```

Note the absence of `dotnet pack` in the Development stage — that ran
exactly once at Experimental. The Development stage's job is to **test
and promote**, not to rebuild.

---

## 6. ProGet webhook integration

ProGet is the event source. BuildMaster is the automation engine.
Webhooks are the bridge.

### 6.1 What ProGet sends

ProGet's "Notifications & Webhooks" feature sends a custom HTTP POST to a
BuildMaster API endpoint when a configured event fires. Configured events:

- `package-added` on `nuget-experimental` → triggers C# pipeline.
- `package-added` on `PowershellGet-experimental` → triggers PowerShell pipeline.
- `package-added` on `ReleaseBundle-Experimental` → triggers Release Bundle pipeline.
- `package-promoted` on any feed → updates BuildMaster release-record metadata
  (no new pipeline run).

### 6.2 Webhook payload

ProGet supports OtterScript variable substitution in the webhook payload:

```json
{
  "applicationName":  "$PackageName",
  "releaseNumber":    "$PackageVersion",
  "feedName":         "$FeedName",
  "reason":           "$PackageName $PackageVersion pushed to $FeedName"
}
```

`$PackageName`, `$PackageVersion`, `$FeedName` are ProGet-side variables
resolved at fire time.

### 6.3 What BuildMaster does

BuildMaster receives the POST at
`https://buildmaster.example.com/api/releases/builds/import` (or an
equivalent CI endpoint). It:

1. Parses the JSON.
2. Looks up which Application matches `applicationName`.
3. Either:
   - Creates a new release/build for that application + version, or
   - Attaches the package to an existing release as an artifact.
4. Triggers the appropriate pipeline (C#, PowerShell, or Release Bundle)
   based on the `feedName` prefix.

If no Application matches `applicationName` exactly, BuildMaster routes
the webhook to a "proxy" application whose first plan inspects the
payload and decides how to handle it.

### 6.4 Edition note

ProGet Free has limitations around custom webhooks (it's a licensed
feature in some configurations). Confirm the running ProGet edition
supports custom-webhook payloads before relying on this integration. If
custom webhooks aren't available, fall back to a PowerShell scheduled
task that polls ProGet's `/api/packages/list` endpoint and calls
`Start-BuildMasterPipeline` on new arrivals.

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

| Boundary       | Pipelines | Releases / metadata                                                          |
| -------------- | --------- | ---------------------------------------------------------------------------- |
| Feature start  | None      | Create prerelease suffix; experimental feed only.                            |
| Sprint start   | None      | Create release-train naming context; package versions inherit it.            |
| During sprint  | None      | Each push triggers an Experimental build via the durable pipeline.           |
| Feature end    | None      | Stop emitting the feature's prerelease suffix; archive the BuildMaster release record. |
| Sprint end     | None      | Cut a `release/*` branch from stable; build artifacts from the tag.          |
| Release cut    | None      | Build the Release Bundle once from the release-branch tag; promote the same artifact through five tiers; publish to Chocolatey / WinGet. |

The first time a brand-new component is added (one that needs its own
BuildMaster Application identity) is the only sprint-cadence change to
BuildMaster configuration — and even then it's one new Application, not a
new pipeline.

---

## 9. Pipeline failure semantics

| Failure                                       | Action                                                                                                  |
| --------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| Build (Experimental) fails                    | No artifact pushed. BuildMaster marks the release `failed`. No promotion possible.                      |
| Test gate at any later tier fails             | The artifact stays in its current feed. BuildMaster marks the gate `failed`. The artifact is not promoted, but is also not destroyed (developers can investigate). |
| Promotion API call fails (transient)          | The cmdlet retries with exponential backoff. Persistent failures abort the stage and require manual ProGet investigation. |
| Distribution (Chocolatey / WinGet) fails      | The Production-tier promotion still succeeded. Distribution is retried manually after fixing the issue.  |

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
4. **ProGet-webhook `$FeedName` routing is not yet wired.** Currently
   webhooks land on a single endpoint regardless of source feed.
5. **BuildMaster API endpoint URL is host-specific** (`utat022:81` vs.
   `localhost:81` vs. eventual production hostname). Centralize in a
   single `*.psd1` config file consumed by all webhook payloads.

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
