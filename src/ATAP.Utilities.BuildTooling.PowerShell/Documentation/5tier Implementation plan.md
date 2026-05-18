# 5-Tier Implementation Plan — `module.build.ps1`

**Partner documents:** [5Tier gaps.md](./5Tier%20gaps.md), [5Tier tasks for module.build.ps1.md](./5Tier%20tasks%20for%20module.build.ps1.md)
**Authoritative reference:** [602 - 5Tier Software Production process Revision 2.md](../../../../_Planning-wt-12-sprint-0006-work-items/Explainers/602%20-%205Tier%20Software%20Production%20process%20Revision%202.md)
**Goal:** Bring `module.build.ps1` into full compliance with the 5-Tier software production process so that every PowerShell module under `src/` in ATAP.Utilities builds, tests, packages, and publishes through the same pipeline as the C# / .NET projects.

---

## 1. Strategic Decision: Hybrid BuildMaster + Invoke-Build

Three approaches were considered:

| Option                                        | Description                                                                                                                                                                                                                                                                                                                                                  | Verdict                                                                                                                                                                       |
| --------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **A. Pure BuildMaster OtterScript**           | Rewrite everything as OtterScript tasks inside a `PowerShellModule-5Stage` pipeline. `module.build.ps1` is deleted.                                                                                                                                                                                                                                          | **Rejected.** Developers lose the ability to run a full build locally before pushing; OtterScript is harder to iterate on than PowerShell.                                    |
| **B. Pure Invoke-Build (keep current shape)** | Keep `module.build.ps1` as the only entry point, extend it with all 5-Tier features. BuildMaster just calls it.                                                                                                                                                                                                                                              | **Rejected.** BuildMaster already provides artifact capture, structured test panes, promotion triggers, and credentials — re-implementing those in PowerShell is duplication. |
| **C. Hybrid (recommended)**                   | Keep `module.build.ps1` as the **local developer and CI entry point**, but refactor it into a thin task DAG that delegates all 5-Tier logic to named cmdlets in `ATAP.Utilities.BuildTooling.PowerShell`. BuildMaster's `PowerShellModule-5Stage` OtterScript plan executes the same `module.build.ps1` with tier-specific arguments and captures artifacts. | **Selected.**                                                                                                                                                                 |

**Rationale for C:**

- A developer running `Invoke-Build NoDoc` locally and BuildMaster running its CI pipeline execute **the same script with the same behavior** — removing the "works on my machine" risk.
- All tier-specific logic lives in **unit-testable PowerShell cmdlets** rather than OtterScript or inline script blocks.
- BuildMaster's OtterScript shrinks to: (1) check out source, (2) call `module.build.ps1 -Tier <X>`, (3) capture the known artifact paths, (4) push to the tier-appropriate ProGet feed.
- The script remains symlink-safe: any module's root can invoke it, any depth below `src/`.

---

## 2. Target Architecture

### 2.1 Entry-Point Contract

`module.build.ps1` becomes a thin, parameter-driven Invoke-Build script with this contract:

```powershell
param(
  [ValidateSet('Sprint','Alpha','Beta','QA','Production')]
  [string]$Tier = 'Alpha',                    # overridden by NBGV when available

  [ValidateSet('Release')]
  [string]$Configuration = 'Release',         # PowerShell modules ship Release only

  [string]$ModuleRoot = $PSScriptRoot,        # auto-detect; override only for tests
  [string]$RepoRoot,                           # auto-detect via git rev-parse
  [string]$OutputRoot,                         # defaults to $RepoRoot/_generated/PSModules/$moduleName
  [switch]$SkipPublish,                        # local-dev fast path
  [switch]$SkipTests,                          # doc-only runs
  [string]$FailureAcknowledgedFile             # defaults to $ModuleRoot/FailureAcknowledged.json
)
```

The script's responsibilities shrink to: orchestrate tasks, stream logs, exit with the correct code. Every non-trivial operation is implemented in a public cmdlet in `ATAP.Utilities.BuildTooling.PowerShell`.

### 2.2 Cmdlet Extraction

Each of the following becomes a dedicated, Pester-tested public cmdlet:

| Cmdlet                            | Responsibility                                                                                                                         | Replaces                                              |
| --------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------- |
| `Resolve-PSModuleMetadata`        | Discover module name, .psd1 path, source folders, repo root, \_generated output path from any depth under `src/`.                      | Manual `Split-Path` logic and global-settings lookups |
| `Get-PSModuleVersionFromNBGV`     | Run `nbgv get-version --variable NuGetPackageVersion`, split into `ModuleVersion` + `Prerelease` suitable for `Update-ModuleManifest`. | Hardcoded `[SemanticVersion]::new(...)`               |
| `Get-TierFromNBGVLabel`           | Compatibility helper: map a NBGV prerelease label (`Sprint`, feature labels, `Alpha`, `Beta`, `QA`, empty) to a ceiling tier and PowerShellGet feed. | `CrossProduct` × `SoftwarePackageTypes` matrix        |
| `Build-PSModulePsm1`              | Concatenate `.ps1` files into the generated `.psm1`, stripping `using` directives to the top.                                          | `Task BuildPSM1`                                      |
| `Build-PSModuleManifest`          | Produce the generated `.psd1` with the NBGV-derived version, populated functions/cmdlets/aliases.                                      | `Task BuildBasePSD1`                                  |
| `Invoke-PSModulePSScriptAnalyzer` | Run PSScriptAnalyzer against the generated `.psm1` / `.psd1` at the correct severity for the tier.                                     | _(new)_                                               |
| `Invoke-PSModulePesterTests`      | Run Pester with the tier-appropriate tag filter, emit JUnit XML and coverage.                                                          | `Task UnitTestPSModule`, `IntegrationTestPSModule`    |
| `Test-FailureAcknowledgedGate`    | Evaluate `(passed + acknowledged) == total` against `FailureAcknowledged.json`.                                                        | _(new)_                                               |
| `Test-CodeCoverageGate`           | Compare coverage to the configured tier threshold.                                                                                     | _(new)_                                               |
| `Publish-PSModuleToProGetFeed`    | Select the target `powershellget-*` feed from `$global:Settings`, authenticate via `Get-BitWardenSecret` or the feed API-key env var, and call `Publish-PSResource`. | `Task PublishPSPackage`                               |
| `Compress-PSModuleArtifacts`      | Create `TestResults.7z`, `CoverageReport.7z`, `Packages.7z` at well-known paths.                                                       | _(new)_                                               |

After extraction, `module.build.ps1` reduces to a DAG of `Task` blocks that each call one cmdlet.

### 2.3 Task DAG (post-refactor)

```text
Short      = Resolve -> BuildPsm1 -> BuildManifest -> Package         -> Publish
Verify     = Resolve -> BuildPsm1 -> BuildManifest -> Analyze -> Test -> Package -> Publish
All        = Verify  + GenerateDocs
CI         = Verify  + CompressArtifacts   (no publish; BuildMaster pushes)
Local      = Verify  -SkipPublish
Clean      = wipe $OutputRoot under _generated/ only
```

### 2.4 Artifact Layout (SC-0033 Compliant)

All generated output moves to the repo-root `_generated/` folder:

```text
<repoRoot>/_generated/PSModules/<moduleName>/
  src/                            # generated .psm1 + manifest
  intermediate/                   # pre-publish nuspec, README, ReleaseNotes
  packages/                       # final .nupkg files
  test-results/                   # Pester JUnit XML
  coverage/                       # Cobertura XML + HTML report
  artifacts/                      # TestResults.7z, CoverageReport.7z, Packages.7z
```

The `Releases/` folder at each module root is **deleted** and its existence check removed from `Enter-Build`.

---

## 3. Version Generation

### 3.1 Source of Truth

`nbgv get-version` is run **once** per build (via `Get-PSModuleVersionFromNBGV`). It produces:

- `SimpleVersion` — `0.1.0` (the three-part `Major.Minor.Patch`)
- `PrereleaseVersion` — `-Alpha.6` or empty for production
- `NuGetPackageVersion` — `0.1.0-Alpha.6`
- `Version` — full four-part build version

### 3.2 Mapping NBGV → PowerShell Module Manifest

`Update-ModuleManifest` and PowerShell's manifest schema have two quirks:

1. `ModuleVersion` **must** be a 3- or 4-part `System.Version` with no prerelease suffix.
2. `PrivateData.PSData.Prerelease` **cannot contain dots or hyphens** — only alphanumerics.

So the translation is:

| NBGV `NuGetPackageVersion` | `ModuleVersion` | `Prerelease` (stored in PSData) |
| -------------------------- | --------------- | ------------------------------- |
| `0.1.0-Sprint.1` (T1)      | `0.1.0`         | `Sprint1`                       |
| `0.1.0-Alpha.6` (T2)       | `0.1.0`         | `Alpha6`                        |
| `0.1.0-Beta.3` (T3)        | `0.1.0`         | `Beta3`                         |
| `0.1.0-QA.2` (T4)          | `0.1.0`         | `QA2`                           |
| `0.1.0` (T5)               | `0.1.0`         | _(absent / `$null`)_            |

`Get-PSModuleVersionFromNBGV` returns a `[PSCustomObject]` with both fields already transformed. `Update-ModuleManifest` is called with `-ModuleVersion $v.ModuleVersion -Prerelease $v.Prerelease` (omit `-Prerelease` when stable).

### 3.3 `version.json` Per Branch

Every PowerShell module's folder gets a `version.json` committed to the branch, tracking the branch's target tier (mirrors the C# rule in Section 7.2 of Explainer 602):

```json
{
  "$schema": "https://raw.githubusercontent.com/dotnet/Nerdbank.GitVersioning/main/src/NerdBank.GitVersioning/version.schema.json",
  "version": "0.1-alpha.{height}"
  "nuGetPackageVersion": { "semVer": 2 },
  "pathFilters": ["./"]
}
```

`pathFilters` scopes the NBGV commit-height calculation to the module folder so that unrelated edits elsewhere in the repo do not bump this module's version.

### 3.4 Local vs. CI Version Determination

- **Local developer runs:** NBGV resolves from `version.json` + uncommitted-files flag. Developers may pass `-Tier Sprint` for a throwaway build that does not require a clean working tree.
- **BuildMaster runs:** NBGV runs against a clean checkout. The `$Tier` parameter is either set from the label NBGV returns, or overridden by the pipeline stage's OtterScript variable.
- **Conflict rule:** If `$Tier` is passed explicitly AND disagrees with NBGV's label, the script **fails** unless `-AllowTierOverride` is also set. This prevents a developer accidentally publishing an `Alpha`-labeled package into `powershellget-stable`.

---

## 4. Feed Routing

### 4.1 Feed Map

```text
Sprint      -> powershellget-experimental
Alpha       -> powershellget-development
Beta        -> powershellget-integration
QA          -> powershellget-qa
(stable)    -> powershellget-stable
```

This map now lives in `$global:Settings` as the package-repository feed collection populated by the ConfigRootKeys and HostSettings package-repository fragments:

```powershell
$global:Settings[$global:configRootKeys['ProGetFeedCollectionConfigRootKey']]
```

BuildTooling cmdlets resolve feed metadata through `Resolve-ProGetFeedFromSettings`, not through `Get-ATAPIACConstant` or direct PSD1 imports. The feed collection contains the canonical lowercase feed name, feed type, tier, endpoint URI, and API-key environment variable name for each of the five PowerShellGet feeds.

### 4.2 Restore-time visibility

Publishing and restore visibility are separate decisions. `Publish-PSModuleToProGetFeed` publishes to the target tier feed. Dependency restore and validation must use the same-tier-or-more-stable repository set described in Explainer 0111:

| Consumer tier | Allowed PowerShellGet repositories |
| --- | --- |
| Sprint / Experimental | experimental, development, integration, qa, stable |
| Alpha / Development | development, integration, qa, stable |
| Beta / Integration | integration, qa, stable |
| QA | qa, stable |
| Production / Stable | stable |

### 4.3 Authentication

API keys come from Bitwarden first. If Bitwarden is unavailable, `Publish-PSModuleToProGetFeed` uses the `ApiKeyName` value from the resolved feed entry and reads that environment variable from Process or User scope:

```powershell
$feed   = Resolve-ProGetFeedFromSettings -FeedType powershellget -Tier $tier
$apiKey = Get-BitWardenSecret -SecretName "ProGet_PowerShellGet_$($tier)_ApiKey"
Publish-PSResource -NupkgPath $Nupkg -Repository $feed.FeedName -ApiKey $apiKey
```

If an agent shell cannot see the Bitwarden session, the configured feed `ApiKeyName` environment variable is the fallback. The temporary `PROGET_ADMIN_API_KEY` fallback is retained only for bootstrap and should be removed once per-feed keys are fully provisioned.

### 4.4 PSResourceRepository Registration

`Publish-PSModuleToProGetFeed` ensures the **branch-appropriate** set of `PSResourceRepository` entries are registered before publish (mirrors Section 13 of Explainer 602 for `NuGet.config`):

| Branch                   | Registered Repositories                                       |
| ------------------------ | ------------------------------------------------------------- |
| Sprint                   | experimental, development, integration, qa, stable, PSGallery |
| Alpha development sprint | development, integration, qa, stable, PSGallery               |
| `integration`            | integration, qa, stable, PSGallery                            |
| `qa`                     | qa, stable, PSGallery                                         |
| `main`                   | stable, PSGallery                                             |

The registration is idempotent (`Set-PSResourceRepository` if present, else `Register-PSResourceRepository`).

---

## 5. Quality Gates

### 5.1 PSScriptAnalyzer

`Invoke-PSModulePSScriptAnalyzer` runs with severity ≥ `Warning` at T2 and above, severity `Error` only at T1. Output is a `PSScriptAnalyzerResults.xml` written into `_generated/PSModules/<name>/test-results/`.

### 5.2 Pester With Tier Filter

The filter expression mirrors Section 9.3 of the Explainer, translated to Pester tags:

| Tier          | Tag Include                                                             | Tag Exclude        |
| ------------- | ----------------------------------------------------------------------- | ------------------ |
| T1 Sprint     | _(none — tests skipped)_                                                | —                  |
| T2 Alpha      | `Unit`                                                                  | `Slow`, `Disabled` |
| T3 Beta       | `Unit`, `Integration`                                                   | `Slow`, `Disabled` |
| T4 QA         | `Unit`, `Integration`, `Functional`, `Regression`, `E2E`, `Performance` | `Disabled`         |
| T5 Production | same as T4 plus `Smoke`                                                 | `Disabled`         |

### 5.3 Failure-Acknowledged Gate

`Test-FailureAcknowledgedGate` reads `$ModuleRoot/FailureAcknowledged.json`:

```json
[
  {
    "testName": "Build-ProGetFeedEndpointURL.Tests.ps1::gives correct URL for internal feed",
    "tier": "T2",
    "category": "Test is wrong",
    "issueNumber": "#142",
    "acknowledgedBy": "whertzing",
    "date": "2026-04-13",
    "notes": "Pattern needs updating; tracked in #142"
  }
]
```

The gate passes when every failing test in the Pester result file has a matching entry by test name. All non-acknowledged failures fail the gate.

### 5.4 Coverage Gate

`Test-CodeCoverageGate` reads the Cobertura XML emitted by Pester's `CodeCoverage` configuration and compares total line coverage to `PassingCodeCoveragePct` from ATAP.IAC. The threshold defaults to **70%** for standard PowerShell modules (per Section 9.4 of the Explainer). Only runs at T4/T5.

---

## 6. BuildMaster Integration

### 6.1 OtterScript Plan Skeleton

```otterscript
# Stage: PowerShellModule-5Stage
GitHub::Get-Source(Organization: ATAP, Repository: $ApplicationName, Branch: $Branch);

# 1. Read NBGV label (used for routing only; module.build.ps1 also reads it)
set $NbgvVersion     = $Exec(nbgv get-version --variable NuGetPackageVersion);
set $PrereleaseLabel = $RegexReplace($NbgvVersion, `^.*-([A-Za-z]+)\..*$`, `$1`);

# 2. Determine tier from label
set $Tier = Sprint;
if $PrereleaseLabel == Alpha { set $Tier = Alpha; }
if $PrereleaseLabel == Beta  { set $Tier = Beta;  }
if $PrereleaseLabel == QA    { set $Tier = QA;    }
if $PrereleaseLabel == ``    { set $Tier = Production; }

# 3. Iterate every PowerShell module under src/ (BuildMaster variable $Modules)
for each $Module in $Modules
{
    Exec(FileName: pwsh,
         Arguments: `-NoProfile -File src/$Module/module.build.ps1 Verify -Tier $Tier`,
         WorkingDirectory: $SourcePath);

    # Capture artifacts from the known _generated path
    Create-Artifact $Module-TestResults     (From: _generated/PSModules/$Module/artifacts, Include: @(TestResults.7z));
    Create-Artifact $Module-CoverageReport  (From: _generated/PSModules/$Module/artifacts, Include: @(CoverageReport.7z));
    Create-Artifact $Module-Packages        (From: _generated/PSModules/$Module/artifacts, Include: @(Packages.7z));
}

# 4. Publish all modules after the entire batch succeeds
for each $Module in $Modules
{
    Exec(FileName: pwsh,
         Arguments: `-NoProfile -File src/$Module/module.build.ps1 Publish -Tier $Tier`,
         WorkingDirectory: $SourcePath);
}
```

### 6.2 Why Build Then Publish Separately

Splitting `Verify` from `Publish` lets BuildMaster verify every module first, then publish them as a batch. If any module fails `Verify`, nothing is published — matching the "all or nothing" promotion discipline of the 5-Tier model.

---

## 7. Symlink and Depth Handling

`Resolve-PSModuleMetadata` makes the script indifferent to where it lives on disk:

```powershell
function Resolve-PSModuleMetadata {
  param([string]$StartPath = $PSScriptRoot)

  # 1. Module root = the folder containing exactly one .psd1
  $psd1 = Get-ChildItem -Path $StartPath -Filter '*.psd1' -File |
          Where-Object BaseName -eq (Split-Path $StartPath -Leaf)
  if (-not $psd1) { throw "No .psd1 found in $StartPath" }

  # 2. Repo root from git
  $repoRoot = (git -C $StartPath rev-parse --show-toplevel) -replace '/','\'

  # 3. Derive names
  [PSCustomObject]@{
    ModuleName = $psd1.BaseName
    ModuleRoot = $StartPath
    RepoRoot   = $repoRoot
    ManifestPath = $psd1.FullName
    OutputRoot = Join-Path $repoRoot "_generated/PSModules/$($psd1.BaseName)"
  }
}
```

This works identically whether the module lives at `src/ATAP.Utilities.BuildTooling.PowerShell/` or `src/nested/group/ATAP.Utilities.Foo.PowerShell/` and whether `module.build.ps1` is a symlink or a real file.

The self-referential `notmatch 'ATAP.Utilities.BuildTooling.Powershell'` check is removed — the bootstrap cmdlet list is discovered from the module that contains `Resolve-PSModuleMetadata` itself, so there is no cycle.

---

## 8. Migration Order

Each step is a stand-alone PR; the script remains functional throughout.

1. **Introduce cmdlets, keep old tasks.** Add every `Resolve-…`, `Get-…`, `Invoke-…`, `Publish-…` cmdlet in `public/` with full Pester tests. No behavioral change yet.
2. **Swap `Enter-Build` to use `Resolve-PSModuleMetadata`.** Remove the `Releases/` requirement. Move outputs to `_generated/PSModules/<name>/`.
3. **Wire NBGV.** Add `version.json` to each PowerShell module; replace `BuildBasePSD1`'s version logic with `Get-PSModuleVersionFromNBGV`.
4. **Collapse the CrossProduct.** Delete `packageProviderNames`, `SoftwarePackageTypes`, the provider × lifecycle matrix. Replace with a single `$Tier`-driven flow.
5. **Replace feed routing.** Delete `PackageRepositoryInternal...` lookups. Resolve feed metadata from `$global:Settings` and publish with `Publish-PSResource`.
6. **Add PSScriptAnalyzer, Failure-Acknowledged, and coverage gates.** Wire them into new tasks (`Analyze`, `GateAck`, `GateCoverage`).
7. **BuildMaster OtterScript plan.** Add `PowerShellModule-5Stage` and point it at two or three pilot modules.
8. **Full rollout.** Delete `module.build.ps1.ChatGPTGenerated`. Update every module's `version.json`. Cut over BuildMaster monitors to the new plan.

---

## 9. Open Questions / Future Work

- **Chocolatey feeds:** deferred (Section 11.1 note). No action in this plan; `Publish-PSModuleToProGetFeed` has a `[-Chocolatey]` reserved parameter for future use.
- **Module-level NBGV vs. repo-level NBGV:** Section 7 of the Explainer assumes repo-wide NBGV. PowerShell modules in `src/` may want per-module `pathFilters` so one module's changes don't bump the others. The plan above assumes per-module `version.json` files — confirm with release engineer before full rollout.
- **PowerShell module dependency resolution:** When one module depends on another (`RequiredModules`), the consumer registration path in 4.3 must also inject the tier-appropriate feed list. Tracked as a follow-up task in the task file.
- **RRSBS database migration:** Feed-aware cmdlets now depend on the `$global:Settings` feed collection. A future RRSBS-backed provider should populate the same settings shape so BuildTooling cmdlets do not change.
