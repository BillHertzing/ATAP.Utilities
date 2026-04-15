# 5-Tier Compliance Gaps — `module.build.ps1`

**Target file:** [module.build.ps1](../module.build.ps1)
**Authoritative reference:** [602 - 5Tier Software Production process Revision 2.md](../../../../_Planning-wt-12-sprint-0006-work-items/Explainers/602%20-%205Tier%20Software%20Production%20process%20Revision%202.md)
**Scope:** PowerShell module build-and-publish pipeline executed by Invoke-Build against any `.psd1` module folder under `src/` in the ATAP.Utilities repository. The same `module.build.ps1` file is NTFS-symlinked into every PowerShell module root, so any gap below applies to **every** module that uses it.

---

## 1. Summary

`module.build.ps1` was written for the legacy **4-tier** model (Development → Experimental → QA → Production) and predates NBGV, the 5-feed PowerShellGet topology, the Failure-Acknowledged gate, `PassingCodeCoveragePct`, and BuildMaster orchestration. It works as a developer-local packager but cannot serve as the authoritative build for T3/T4/T5 without substantial rework.

The script is **not broken** — it is **misaligned**. Most gaps are structural (missing tiers, missing gates, wrong feed routing) rather than defects in the tasks it does implement.

---

## 2. Gap Inventory

### 2.1 Tier Model Gaps (Section 1, 7, 8 of Explainer 602)

| # | Gap | Current State | 5-Tier Requirement |
|---|-----|---------------|--------------------|
| G-01 | No concept of the five tiers | Hardcoded `SoftwarePackageTypes = @('QualityAssurance','Production')` — only two lifecycle values | Must support T1 Experimental, T2 Development, T3 Integration, T4 QA, T5 Production |
| G-02 | No version-label awareness | Reads `PrivateData.PSData.Prerelease` from the static `.psd1` and builds both `QA` and `Production` variants from every commit (CrossProduct matrix) | Each build produces **one** package whose label is derived from `version.json` / NBGV (`Sprint`, `Alpha`, `Beta`, `QA`, or stable) |
| G-03 | No NBGV integration | Version is taken from the committed `.psd1` manifest and hardcoded in comments (e.g. `[SemanticVersion]::new(0,0,1,'alpha003','')`) | Version must come from `nbgv get-version --variable NuGetPackageVersion`; the commit IS the version bump |
| G-04 | No `version.json` support | Script has no awareness of the per-branch `version.json` file that encodes the tier label | Must read `version.json` (via NBGV) to determine tier and label |
| G-05 | Rebuild/relabel model not implemented | Builds QA and Production side-by-side in one run | Each tier transition is a **new build** from the same source commit with the next tier's label |

### 2.2 Feed Topology Gaps (Section 11 of Explainer 602)

| # | Gap | Current State | 5-Tier Requirement |
|---|-----|---------------|--------------------|
| G-06 | Wrong feed names | Publishes to `PackageRepositoryInternal{Released\|Prerelease}{Provider}{Lifecycle}PushFeed` from `$global:settings` | Publishes to the 5 feeds `PowershellGet-experimental`, `-development`, `-integration`, `-qa`, `-stable` |
| G-07 | No feed-routing by label | Selects destination by (provider × lifecycle) cross-product | Destination feed is a pure function of the NBGV prerelease label |
| G-08 | Uses `nuget.exe pack` + `nuget.exe push` for PowerShell modules | Calls `nuget.exe pack <nuspec>` and `nuget.exe push` via `System.Diagnostics.Process` | Should use `Publish-PSResource` (PSResourceGet) as the primary path; `nuget.exe` is the fallback only for NuGet-shaped feeds |
| G-09 | No `PSResourceRepository` registration | Script assumes the feed is already registered in `$global:settings` | Should register/validate the branch-appropriate set of `PSResourceRepository` entries (tier and above) before publishing |
| G-10 | Fan-out to `Filesystem`, `NuGet`, `ChocolateyGet`, `PSResourceGet` in parallel | Every build tries to produce four provider variants | 5-Tier spec lists a single PowerShellGet feed per tier; Chocolatey is deferred; Filesystem is a local mirror, not a publishing target |

### 2.3 `Releases` Folder Gap (and SC-0033)

| # | Gap | Current State | 5-Tier Requirement |
|---|-----|---------------|--------------------|
| G-11 | Hard failure if `<moduleRoot>/Releases` does not exist | `Enter-Build` throws `"The release directory ... was not found."` | No such folder should exist. Final packages go directly to a ProGet feed; local intermediate artifacts go under `_generated/` per CLAUDE.md SC-0033 |
| G-12 | Violates SC-0033 generated-output rule | Packages end up in a per-module `Releases/` folder inside source | All generated artifacts (nuspec, nupkg, test results, coverage) must be under the repository-root `_generated/` folder |

### 2.4 Symlink-Into-Any-Module Gaps

| # | Gap | Current State | 5-Tier Requirement |
|---|-----|---------------|--------------------|
| G-13 | Module-name inference via `Split-Path $ModuleRoot -Leaf` | Fragile if invoked from a parent directory or with `-ModuleRoot ./`; also breaks when two modules share the same leaf name at different depths | Derive the module name from the **`.psd1` file discovered under `$ModuleRoot`**, not from the folder name |
| G-14 | Self-reference to `ATAP.Utilities.BuildTooling.Powershell` | Contains a hardcoded exemption `if ($moduleName -notmatch 'ATAP.Utilities.BuildTooling.Powershell')` and a dotted-load of its own `.psm1` | The bootstrap must not hardcode its own module name. A prerequisites block should be module-agnostic |
| G-15 | Hardcoded absolute path | `. 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.BuildTooling.PowerShell\public\Get-NuSpecFromManifest.ps1'` | The script must work from any sprint worktree path (e.g. `ATAP.Utilities-wt-98-sprint-0006-work-items`) and with any module depth under `src/` |
| G-16 | Uses `$BuildRoot` for the Releases search | The script expects `Releases/` under `$buildRoot`; the symlink makes `$buildRoot` per-module | Even if retained, the artifact root must be a repo-root-relative path, not per-module |

### 2.5 Global-State and Configuration Gaps

| # | Gap | Current State | 5-Tier Requirement |
|---|-----|---------------|--------------------|
| G-17 | Heavy reliance on `$global:settings[$global:configRootKeys[...]]` | Many paths (temp directory, test results, coverage, feeds, API-key names) come from process-global hashtables populated by a PowerShell profile | In non-interactive BuildMaster agent shells those globals are empty. Configuration must come from ATAP.IAC constants loaded explicitly (Section 4 of the Explainer) |
| G-18 | Secrets read via `[Environment]::GetEnvironmentVariable($PSRepositoryFeed.ApiKeyName)` with process scope | Process-scope env vars are empty in agent-spawned shells (see CLAUDE.md R-10) | Must read with User scope: `[Environment]::GetEnvironmentVariable($name, 'User')`, or via `Get-BitWardenSecret` |

### 2.6 Quality Gate Gaps (Sections 8 and 9 of Explainer 602)

| # | Gap | Current State | 5-Tier Requirement |
|---|-----|---------------|--------------------|
| G-19 | Only two test categories | Tasks `UnitTestPSModule` and `IntegrationTestPSModule` use `-Tag Unit` / `-Tag Integration` | Needs **Unit, Integration, Functional, Regression, Performance, E2E, Smoke** categories with tier-appropriate filters |
| G-20 | No Failure-Acknowledged evaluation | Script calls `Write-Error` the moment `FailedCount -gt 0` | Gate passes when `(passed_count + acknowledged_count) == total_count`; the acknowledgments come from a `FailureAcknowledged.json` registry |
| G-21 | No PSScriptAnalyzer step | Not invoked anywhere | PSScriptAnalyzer must be clean at T2 and above |
| G-22 | No code coverage | No coverage collection, no thresholding, no reports | T4/T5 require coverage ≥ `PassingCodeCoveragePct` (ATAP.IAC-sourced) |
| G-23 | No smoke test stage | Not present | T5 requires smoke tests |
| G-24 | No per-tier test filter selection | Same tests run regardless of tier | Filter must be chosen from the tier/label pair (mirrors the OtterScript plan in Section 14.4) |
| G-25 | No per-tier pre-promotion snapshot / rollback hook | Not present | Database-coupled modules need to invoke the pre-promotion backup path (Section 16.3.1) |

### 2.7 BuildMaster Integration Gaps (Section 14 of Explainer 602)

| # | Gap | Current State | 5-Tier Requirement |
|---|-----|---------------|--------------------|
| G-26 | Not callable as a single idempotent entry-point | A BuildMaster OtterScript plan expects `Exec(FileName: pwsh, Arguments: -File ...)` with a small set of parameters | The entry point should accept `-Tier`, `-Configuration Release`, `-OutputDir`, `-SkipPublish`, etc. — not rely on `$global:settings` |
| G-27 | No artifact contract with BuildMaster | No structured emission of `TestResults.7z`, `CoverageReport.7z`, `Packages.7z` | BuildMaster expects these exact artifact bundle names |
| G-28 | No structured build log | Writes free-form `Write-PSFMessage` | Should emit a single structured summary suitable for BuildMaster's **Overview** tab (version, branch, commit SHA, tier, test totals, coverage %) |

### 2.8 Miscellaneous / Small Gaps

| # | Gap |
|---|-----|
| G-29 | `CrossProduct` helper returns a malformed path: `Join-Path $prefix $packageProviderName $SoftwarePackageType, $suffix` — the trailing comma creates a one-element array and is almost certainly a bug. |
| G-30 | `module.build.ps1.ChatGPTGenerated` exists as a parallel file and is not referenced anywhere — adds confusion. |
| G-31 | `CleanAll` only aliases `Clean`; there is no task to wipe `_generated/` at the repo root. |
| G-32 | `BuildPSM1` concatenates all `.ps1` files into one big `.psm1` without stripping `using` directives (the code has a `ToDo:` comment acknowledging this). |
| G-33 | `BuildBasePSD1` pattern-matches file paths with `[Regex]::Escape([System.IO.Path]::DirectorySeparatorChar + 'public' + …)` — OK on Windows but fragile on POSIX worktrees and slow in large modules. |
| G-34 | No `.gitattributes` guard on per-branch artifacts; `NuGet.config`-style `merge=ours` strategy is not replicated for PowerShell-module `version.json`. |
| G-35 | No handling of the `Trace` configuration referenced in Section 7.5 of the Explainer — PowerShell modules only need `Release`, but the script still emits a `Debug`-flavored `.psd1` via the old lifecycle matrix. |

---

## 3. Classification

| Severity | Count | Gaps |
|----------|-------|------|
| **Blocker** (prevents 5-tier operation) | 11 | G-01, G-02, G-03, G-06, G-07, G-08, G-11, G-13, G-15, G-17, G-19 |
| **Major** (functional but non-compliant) | 14 | G-04, G-05, G-09, G-10, G-12, G-14, G-18, G-20, G-21, G-22, G-24, G-26, G-27, G-29 |
| **Minor** (cosmetic / cleanup) | 10 | G-16, G-23, G-25, G-28, G-30, G-31, G-32, G-33, G-34, G-35 |

---

## 4. What the Script **Does** Do Right (Keep-List)

These aspects are compatible with the 5-Tier model and should be preserved through any rewrite:

- Invoke-Build task DAG with `Inputs`/`Outputs`/`Jobs` — efficient incremental builds.
- `PSFramework` logging with tagged messages — already matches the logging standard in CLAUDE.md.
- Separation of public/private/lib source folders — matches the 5-tier layout expectation.
- Concatenation of `.ps1` files into one `.psm1` for faster module load.
- `Update-ModuleManifest` for regenerating the runtime manifest rather than editing the committed one.
- Parameter-driven test directory and extension discovery.
- Distinct "intermediate" and "distribution" staging directories.
