# 5-Tier Swarm Tasks — `module.build.ps1`

**Partner documents:** [5Tier gaps.md](./5Tier%20gaps.md), [5tier Implementation plan.md](./5tier%20Implementation%20plan.md)
**Purpose:** A flat, self-contained backlog of tasks an AI-agent swarm can pick up in parallel to bring `module.build.ps1` into 5-Tier compliance. Each task is atomic, specifies its inputs/outputs, names the gap(s) from `5Tier gaps.md` it addresses, and lists its dependencies on other tasks in this file. No task is larger than a single PR.

**Conventions for every task:**

- **Target repo:** `ATAP.Utilities` (unless explicitly noted).
- **Shell:** PowerShell 7.x (pwsh). Use `Select-String`, `Get-ChildItem`, etc. — never bash.
- **Logging:** `Write-PSFMessage` only. No `Write-Host`, no `Write-Output` for logging.
- **Tests:** Every new public cmdlet ships with Pester 5+ unit tests under `tests/` and passes `Invoke-Pester -Output Detailed`.
- **Commit style:** Conventional Commits. Reference the task ID (e.g., `feat(bt): T-03 add Get-PSModuleVersionFromNBGV`).
- **Boundary rule:** Only edit files under this repo's `src/ATAP.Utilities.BuildTooling.PowerShell/` or `tests/` for that module unless a task says otherwise.

---

## Task Completion Checklist

### Phase 0 — Prep and Housekeeping

- [x] T-00 · Delete the orphan `module.build.ps1.ChatGPTGenerated`
- [x] T-01 · Add `version.json` to every PowerShell module folder under `src/`
- [x] T-02 · Remove the `Releases/` directory from every PowerShell module root

### Phase 1 — Extract Cmdlets (parallelizable)

- [x] T-10 · `Resolve-PSModuleMetadata`
- [x] T-11 · `Get-PSModuleVersionFromNBGV`
- [x] T-12 · `Get-TierFromNBGVLabel`
- [x] T-13 · `Build-PSModulePsm1`
- [x] T-14 · `Build-PSModuleManifest`
- [x] T-15 · `Invoke-PSModulePSScriptAnalyzer`
- [x] T-16 · `Invoke-PSModulePesterTests`
- [x] T-17 · `Test-FailureAcknowledgedGate`
- [x] T-18 · `Test-CodeCoverageGate`
- [x] T-19 · `Publish-PSModuleToProGetFeed`
- [x] T-1A · `Compress-PSModuleArtifacts`

### Phase 2 — ATAP.IAC Integration

- [x] T-30 · Add legacy `Get-ATAPIACConstant` bootstrap cmdlet
- [x] T-31 · Resolve PowerShellGet feed metadata from `$global:Settings`

### Phase 3 — Rewrite `module.build.ps1`

- [x] T-40 · Strip the legacy lifecycle matrix
- [x] T-41 · Replace `Enter-Build` with `Resolve-PSModuleMetadata` call
- [x] T-42 · Use NBGV for version and manifest generation
- [x] T-43 · Collapse package tasks to a single `Package` task
- [x] T-44 · Replace `PublishPSPackage` with `Publish-PSModuleToProGetFeed`
- [x] T-45 · Replace `UnitTestPSModule` / `IntegrationTestPSModule` with `Invoke-PSModulePesterTests`
- [x] T-46 · Add `Analyze`, `GateAck`, `GateCoverage` tasks
- [x] T-47 · Replace the default task chains
- [x] T-48 · Add `Compress` task for BuildMaster artifact handoff
- [x] T-49 · Emit a structured build summary

### Phase 4 — BuildMaster Plan

- [ ] T-60 · Create `PowerShellModule-5Stage` OtterScript plan
- [x] T-61 · Add Repository Monitors for PowerShell-module branches
- [ ] T-62 · Pilot the new plan on `ATAP.Utilities.BuildTooling.PowerShell`
- [ ] T-63 · Roll out to the remaining PowerShell modules

### Phase 5 — Documentation, Cleanup, Retrospective

- [ ] T-70 · Update module READMEs and `GettingStarted.md`
- [ ] T-71 · Delete dead code and legacy helpers
- [ ] T-72 · Retrospective memo

---

## Phase 0 — Prep and Housekeeping

### T-00 · Delete the orphan `module.build.ps1.ChatGPTGenerated`

- [x]

**Gap:** G-30
**Inputs:** None
**Steps:**

1. Remove the file at [src/ATAP.Utilities.BuildTooling.PowerShell/module.build.ps1.ChatGPTGenerated](../module.build.ps1.ChatGPTGenerated).
2. Grep the repository for references to that filename and confirm none exist.
   **Acceptance:** File is gone; no references.
   **Dependencies:** None.

### T-01 · Add `version.json` to every PowerShell module folder under `src/`

- [x]

**Gap:** G-04
**Inputs:** List of PowerShell module folders (any directory containing `*.psd1` under `src/`).
**Steps:**

1. Find every `*.psd1` file under `src/` that is a module manifest (not a test helper).
2. In each module's folder, write a `version.json` matching the plan's 3.3 template, starting at `0.1-alpha.1`.
3. Add `pathFilters: ["./"]` so NBGV scopes commit-height to the module.
   **Acceptance:** Every PowerShell module has a committed `version.json`; `nbgv get-version` succeeds when run in each module folder.
   **Dependencies:** None.

### T-02 · Remove the `Releases/` directory from every PowerShell module root

- [x]

**Gap:** G-11, G-12
**Inputs:** Same module list as T-01.
**Steps:**

1. Delete each `Releases/` folder and any contents still present.
2. Add `Releases/` and `_generated/` to the repo-root `.gitignore` if not already present.
   **Acceptance:** No module has a `Releases/` folder; git status is clean.
   **Dependencies:** None (but coordinate with T-06).

---

## Phase 1 — Extract Cmdlets (parallelizable)

Each T-1x task delivers one public cmdlet in [src/ATAP.Utilities.BuildTooling.PowerShell/public/](../public/) with full Pester tests in [tests/](../tests/). These tasks do NOT modify `module.build.ps1` — they only add cmdlets.

### T-10 · `Resolve-PSModuleMetadata`

- [x]

**Gap:** G-13, G-14, G-15, G-16
**Inputs:** `-StartPath` (defaults to `$PSScriptRoot`).
**Outputs:** `[PSCustomObject]` with `ModuleName`, `ModuleRoot`, `RepoRoot`, `ManifestPath`, `OutputRoot` (= `$RepoRoot/_generated/PSModules/<ModuleName>/`).
**Steps:**

1. Find the single `*.psd1` whose `BaseName` matches the folder name.
2. Resolve `RepoRoot` via `git rev-parse --show-toplevel`.
3. Build the five fields and return them.
4. Throw with a clear message if zero or multiple matching `.psd1` files are found.
   **Acceptance:** Pester tests cover: module at depth 2 below `src/`, module at depth 4 below `src/`, module reached via NTFS junction, module with no `.psd1`, and module with two `.psd1`.
   **Dependencies:** None.

### T-11 · `Get-PSModuleVersionFromNBGV`

- [x]

**Gap:** G-03
**Inputs:** `-ModuleRoot`.
**Outputs:** `[PSCustomObject]` with `ModuleVersion` (3-part System.Version), `Prerelease` (string, no dots/hyphens, empty for stable), `FullNuGetVersion`.
**Steps:**

1. `nbgv get-version --variable NuGetPackageVersion` in `$ModuleRoot`.
2. Split `M.m.p-Label.N` into parts.
3. Concatenate `Label` + `N` with no separator → `Prerelease`.
4. Return the object.
   **Acceptance:** Pester tests cover each tier label (`Sprint`, `Alpha`, `Beta`, `QA`, stable), and confirm the returned `Prerelease` passes `Update-ModuleManifest` validation.
   **Dependencies:** T-01 (so NBGV has something to read).

### T-12 · `Get-TierFromNBGVLabel`

- [x]

**Gap:** G-02, G-07
**Inputs:** `-PrereleaseLabel`.
**Outputs:** `[PSCustomObject]` with `TierNumber` (1-5), `TierName`, `FeedName` (one of `powershellget-experimental` ... `-stable`).
**Steps:**

1. Map the label per the table in Plan §4.1.
2. Throw on unknown labels.
   **Acceptance:** Pester tests cover each of the five labels plus at least two error cases.
   **Dependencies:** None.

### T-13 · `Build-PSModulePsm1`

- [x]

**Gap:** G-32
**Inputs:** `-ModuleRoot`, `-OutputPath`, `-SourceDirectoryNames` (default `public`, `private`, `lib`).
**Outputs:** The generated `.psm1` file on disk.
**Steps:**

1. Enumerate `.ps1` files under each source directory.
2. Parse each file's AST; collect `using namespace` statements into a set.
3. Emit the `using` statements first, then each file body with a `# <fileName>` comment above.
4. Write the result via `Set-Content -Encoding utf8BOM`.
   **Acceptance:** Pester tests: empty module, module with `using` statements in two files (deduplicated), module with only private functions.
   **Dependencies:** None.

### T-14 · `Build-PSModuleManifest`

- [x]

**Gap:** G-02, G-03, G-35
**Inputs:** `-SourceManifestPath`, `-OutputManifestPath`, `-ModuleVersion`, `-Prerelease`, `-PublicFunctions`, `-Aliases`, `-RequiredAssemblies`, `-FormatFiles`, `-DscResources`.
**Outputs:** The generated `.psd1` on disk.
**Steps:**

1. Copy the source manifest to the output path.
2. Call `Update-ModuleManifest` with the version and prerelease fields.
3. Populate `FunctionsToExport` and the other lists.
4. Omit `-Prerelease` entirely when `$Prerelease` is empty (for T5 stable).
   **Acceptance:** Pester tests validate the resulting `.psd1` parses via `Test-ModuleManifest` at each tier label.
   **Dependencies:** T-11 (indirectly — tests supply a known Version object).

### T-15 · `Invoke-PSModulePSScriptAnalyzer`

- [x]

**Gap:** G-21
**Inputs:** `-Path`, `-Tier`, `-OutputPath`.
**Outputs:** XML file under the output directory plus a `[PSCustomObject]` summary.
**Steps:**

1. If `$Tier -eq 'Sprint'`, skip and return a success object.
2. Run `Invoke-ScriptAnalyzer -Path $Path -Severity Warning,Error -Recurse`.
3. Serialize results as NUnit XML.
4. Return pass/fail summary.
   **Acceptance:** Pester tests cover clean module (pass), module with a `Write-Host` call (fail at Warning severity).
   **Dependencies:** None.

### T-16 · `Invoke-PSModulePesterTests`

- [x]

**Gap:** G-19, G-24
**Inputs:** `-ModuleRoot`, `-Tier`, `-OutputPath`, `-CoverageOutputPath`.
**Outputs:** Pester result object; JUnit XML at `$OutputPath`; Cobertura XML at `$CoverageOutputPath`.
**Steps:**

1. Look up the tier's tag filter from Plan §5.2.
2. Skip entirely if `$Tier -eq 'Sprint'`.
3. Build a Pester 5 `Configuration` object with `TestResult.Enabled`, `TestResult.OutputFormat = 'JUnitXml'`, `CodeCoverage.Enabled`, `CodeCoverage.OutputFormat = 'JaCoCo'` (or Cobertura via PSCodeCoverage helper).
4. Run `Invoke-Pester -Configuration $cfg`.
   **Acceptance:** Pester tests (meta) cover the filter selection logic and verify the config object shape for each tier.
   **Dependencies:** T-12.

### T-17 · `Test-FailureAcknowledgedGate`

- [x]

**Gap:** G-20
**Inputs:** `-ResultFile` (Pester JUnit XML), `-AcknowledgedFile` (JSON), `-Tier`.
**Outputs:** `[PSCustomObject]` with `Passed`, `Failed`, `Acknowledged`, `GatePass` (bool).
**Steps:**

1. Parse the Pester result file.
2. Load the acknowledged registry.
3. For each failure, check for a matching entry whose `tier` field is `>= $Tier`.
4. Set `GatePass = (Failed == 0) -or ((Failed - Acknowledged) == 0)`.
   **Acceptance:** Pester tests cover: no failures, one acknowledged failure at the same tier, one acknowledged failure at a lower tier (should still count), one unacknowledged failure (gate fails).
   **Dependencies:** None.

### T-18 · `Test-CodeCoverageGate`

- [x]

**Gap:** G-22
**Inputs:** `-CoverageFile` (Cobertura), `-Tier`, `-Threshold` (defaults come from ATAP.IAC).
**Outputs:** `[PSCustomObject]` with `CoveragePct`, `Threshold`, `GatePass`.
**Steps:**

1. Skip if `$Tier` is `Sprint`, `Alpha`, or `Beta` (coverage gated at T4/T5 per Explainer 9.4).
2. Read total line coverage from the Cobertura file.
3. Compare to `$Threshold`.
   **Acceptance:** Pester tests cover: coverage above threshold (pass), below threshold (fail), skipped at lower tier.
   **Dependencies:** None.

### T-19 · `Publish-PSModuleToProGetFeed`

- [x]

**Gap:** G-06, G-08, G-09, G-18
**Inputs:** `-NupkgPath`, `-Tier`, `-AllowTierOverride`.
**Outputs:** Publish result object.
**Steps:**

1. Resolve the target feed via `$global:Settings[$global:configRootKeys['ProGetFeedCollectionConfigRootKey']]`.
2. Ensure the repository is registered (`Register-PSResourceRepository` if missing; `Set-PSResourceRepository` if present).
3. Fetch the API key via `Get-SecretATAP -SecretName "ProGet_PowerShellGet_${tier}_ApiKey"`; fall back to the feed entry's configured `ApiKeyName` environment variable if Bitwarden is unavailable.
4. Call `Publish-PSResource -Path $NupkgPath -Repository $shortName -ApiKey $key`.
   **Acceptance:** Pester tests mock `Publish-PSResource` and verify the correct repository and API key name are resolved for each tier.
**Dependencies:** T-12, T-31.

### T-1A · `Compress-PSModuleArtifacts`

- [x]

**Gap:** G-27
**Inputs:** `-ModuleRoot`, `-OutputRoot` (`_generated/PSModules/<name>/`).
**Outputs:** Three `.7z` files under `$OutputRoot/artifacts/`: `TestResults.7z`, `CoverageReport.7z`, `Packages.7z`.
**Steps:**

1. Resolve 7zip path (`Get-Command 7z.exe`).
2. Create `$OutputRoot/artifacts/` if missing.
3. Archive each source directory into its matching `.7z`.
   **Acceptance:** Pester tests using a temp folder confirm all three bundles are created and contain expected files.
   **Dependencies:** None.

---

## Phase 2 — ATAP.IAC Integration

### T-30 · Add legacy `Get-ATAPIACConstant` bootstrap cmdlet

- [x]

**Gap:** G-17
**Inputs:** `-Name`.
**Outputs:** The constant value (scalar or object).
**Steps:**

1. Look in `$global:settings[$global:configRootKeys[$Name]]` first for back-compat.
2. If not found, load `ATAP.IAC/constants/*.psd1` directly and read the value.
3. Throw with a helpful message if neither source has it.
**Acceptance:** Cmdlet works in a fresh pwsh shell with no profile loaded (simulates BuildMaster agent).
**Current status:** Legacy compatibility only. Current feed-aware cmdlets use `$global:Settings` through `Resolve-ProGetFeedFromSettings` instead of calling this bootstrap helper.
**Dependencies:** None (but coordinates with ATAP.IAC work).

### T-31 · Resolve PowerShellGet feed metadata from `$global:Settings`

- [x]

**Gap:** G-06
**Repo:** `ATAP.IAC` and `ATAP.Utilities` (branch: current sprint branch)
**Inputs:** `Add-PackageRepositoriesConfigRootKeys.ps1` and `HostSettings.IAC.Fragment.PackageRepositories.ps1`.
**Outputs:** `$global:Settings[$global:configRootKeys['ProGetFeedCollectionConfigRootKey']]` contains all canonical feed metadata for NuGet and PowerShellGet feeds.
**Steps:** Populate feed names, endpoint URIs, feed types, tiers, connectors, retention metadata, and API-key environment variable names in host settings. Update BuildTooling cmdlets to resolve feed metadata through `Resolve-ProGetFeedFromSettings`.
**Acceptance:** `Publish-PSModuleToProGetFeed`, `Register-ProGetFeedSet`, and BuildMaster stable variable setup resolve lowercase `powershellget-*` feed names from `$global:Settings` without calling `Get-ATAPIACConstant`.
**Dependencies:** ConfigRootKeys and HostSettings fragments are loaded before build tooling feed operations.

---

## Phase 3 — Rewrite `module.build.ps1`

### T-40 · Strip the legacy lifecycle matrix

- [x]

**Gap:** G-01, G-07, G-10, G-29
**Inputs:** [module.build.ps1](../module.build.ps1)
**Steps:**

1. Delete the `packageProviderNames`, `SoftwarePackageTypes`, and `CrossProduct` helper.
2. Remove the `QualityAssurance` / `Production` branches.
3. Replace the parameter list with the plan §2.1 contract (`-Tier`, `-Configuration`, etc.).
   **Acceptance:** `Invoke-Build Short -Tier Alpha` still succeeds on a pilot module after the swap.
   **Dependencies:** T-10, T-11, T-12, T-13, T-14, T-19.

### T-41 · Replace `Enter-Build` with `Resolve-PSModuleMetadata` call

- [x]

**Gap:** G-11, G-12, G-13, G-16, G-17
**Steps:**

1. Delete the `Releases/` directory check.
2. Call `Resolve-PSModuleMetadata` and expose the result as script variables.
3. Point every output path under `$meta.OutputRoot` (i.e. `_generated/PSModules/<name>/`).
   **Acceptance:** Running the script fails gracefully if the module has no `.psd1`; succeeds otherwise; produces output only under `_generated/`.
   **Dependencies:** T-10, T-40.

### T-42 · Use NBGV for version and manifest generation

- [x]

**Gap:** G-02, G-03, G-04, G-05
**Steps:**

1. Call `Get-PSModuleVersionFromNBGV` once in `Enter-Build`.
2. Pass the result to `Build-PSModuleManifest`.
3. Remove the hardcoded `[SemanticVersion]` lines and the manual prerelease logic.
   **Acceptance:** A commit with `version.json = "0.1-Alpha"` produces a package named `<Module>.0.1.0-Alpha6.nupkg` at commit height 6.
   **Dependencies:** T-11, T-14, T-40, T-41.

### T-43 · Collapse package tasks to a single `Package` task

- [x]

**Gap:** G-05, G-08
**Steps:**

1. Delete `BuildPackageSpecificPSD1AndPSM1`, `BuildNuSpecFromManifest`, `AddReadMeToNuSpec`, `BuildChocolateyPackage`.
2. Introduce one `Package` task that calls `New-PSResourcePackage` (or uses `Publish-PSResource -WhatIf` to produce a nupkg locally).
   **Acceptance:** One `.nupkg` file lands under `_generated/PSModules/<name>/packages/`.
   **Dependencies:** T-42.

### T-44 · Replace `PublishPSPackage` with `Publish-PSModuleToProGetFeed`

- [x]

**Gap:** G-06, G-07, G-08, G-09, G-18
**Steps:**

1. Delete the entire `PublishPSPackage` block in `module.build.ps1`.
2. Introduce a `Publish` task that calls `Publish-PSModuleToProGetFeed`.
3. Honor `-SkipPublish` for local dev runs.
**Acceptance:** `Invoke-Build Publish -Tier Alpha -SkipPublish` succeeds without touching the network; without `-SkipPublish` it pushes the package to `powershellget-development`.
   **Dependencies:** T-19, T-43.

### T-45 · Replace `UnitTestPSModule` / `IntegrationTestPSModule` with `Invoke-PSModulePesterTests`

- [x]

**Gap:** G-19, G-24
**Steps:**

1. Delete both test tasks.
2. Introduce one `Test` task driven by `$Tier`.
3. Output JUnit XML under `_generated/PSModules/<name>/test-results/`.
   **Acceptance:** `Invoke-Build Test -Tier Beta` runs Unit + Integration tests; `-Tier QA` runs the full set.
   **Dependencies:** T-16, T-41.

### T-46 · Add `Analyze`, `GateAck`, `GateCoverage` tasks

- [x]

**Gap:** G-20, G-21, G-22, G-23
**Steps:**

1. Add `Analyze` task calling `Invoke-PSModulePSScriptAnalyzer`.
2. Add `GateAck` task calling `Test-FailureAcknowledgedGate`.
3. Add `GateCoverage` task calling `Test-CodeCoverageGate`.
4. Wire them into the new `Verify` and `All` task chains.
   **Acceptance:** A module with an unacknowledged failing test fails the `Verify` chain at `GateAck`; an acknowledged failure passes.
   **Dependencies:** T-15, T-17, T-18, T-45.

### T-47 · Replace the default task chains

- [x]

**Gap:** G-01, G-05
**Steps:**

1. Delete `Short`, `NoDoc`, `NoTest`, `All`, `CleanAll` as they exist today.
2. Introduce `Short`, `Verify`, `All`, `CI`, `Local`, `Clean` per Plan §2.3.
   **Acceptance:** Every chain passes on the pilot module `ATAP.Utilities.BuildTooling.PowerShell` at tier Alpha.
   **Dependencies:** T-40 through T-46.

### T-48 · Add `Compress` task for BuildMaster artifact handoff

- [x]

**Gap:** G-27
**Steps:** One-liner task calling `Compress-PSModuleArtifacts`.
**Acceptance:** Three `.7z` files are created under `_generated/PSModules/<name>/artifacts/`.
**Dependencies:** T-1A, T-47.

### T-49 · Emit a structured build summary

- [x]

**Gap:** G-28
**Steps:**

1. At the end of `Verify` / `All`, write a JSON summary to `_generated/PSModules/<name>/artifacts/BuildSummary.json` with `Version`, `Tier`, `CommitSha`, `Passed`, `Failed`, `Acknowledged`, `CoveragePct`.
2. Echo a single-line human-readable form to the log.
   **Acceptance:** File exists after every full build; schema matches the BuildMaster Overview tab expectations.
   **Dependencies:** T-47.

---

## Phase 4 — BuildMaster Plan

### T-60 · Create `PowerShellModule-5Stage` OtterScript plan

- [ ]

**Gap:** G-26
**Repo:** BuildMaster admin (tracked in `ATAP.IAC` scripts folder for source control)
**Steps:** Implement the plan skeleton in Plan §6.1. Add one stage per tier.
**Acceptance:** Plan lints via BuildMaster, dry-runs against a pilot branch.
**Dependencies:** T-47, T-48, T-49.

### T-61 · Add Repository Monitors for PowerShell-module branches

- [x]

**Gap:** G-26
**Steps:** Point BuildMaster monitors at each `sprint-*`, `integration`, `qa`, `main`, and `release/v*` branch for this repo (see Explainer 14.3).
**Acceptance:** A push to any monitored branch triggers the correct stage within the configured interval.
**Dependencies:** T-60.

**Status:** Complete for the `ATAP.Utilities.BuildTooling.PowerShell` pilot
module. `PowerShellModule-RepositoryMonitors.otter` defines `main` and
`*-Sprint-*-work-items` monitors scoped to
`src/ATAP.Utilities.BuildTooling.PowerShell/**` and passes `Branch`,
`ModuleName`, and `PackageName` into the shared `ATAP.Utilities-PowerShell`
application. The archived `integration`/`qa`/`release/v*` branch-monitor list
is superseded by the immutable-build model: only sprint and `main` source
pushes start builds; later tiers are promotion stages. Follow-on module rollout
remains owned by T-63.

### T-62 · Pilot the new plan on `ATAP.Utilities.BuildTooling.PowerShell`

- [ ]

**Gap:** All
**Steps:**

1. Run `Verify -Tier Alpha` locally, confirm green.
2. Push to a sprint branch and watch the BuildMaster stage run.
3. Promote the branch to `integration` and confirm the Beta stage runs.
**Acceptance:** Module reaches the `powershellget-integration` feed end-to-end via the new pipeline.
   **Dependencies:** T-60, T-61.

### T-63 · Roll out to the remaining PowerShell modules

- [ ]

**Gap:** All
**Steps:** For each remaining module: add `version.json`, delete `Releases/`, run the pilot loop, fix module-specific issues.
**Acceptance:** Every PowerShell module under `src/` builds via the new pipeline.
**Dependencies:** T-62.

---

## Phase 5 — Documentation, Cleanup, Retrospective

### T-70 · Update module READMEs and `GettingStarted.md`

- [ ]

**Gap:** G-28
**Steps:** Document the new `-Tier` parameter, the `_generated/` output layout, and how to consume modules from the tier-appropriate feed.
**Dependencies:** T-47.

### T-71 · Delete dead code and legacy helpers

- [ ]

**Gap:** G-15, G-29, G-32, G-33
**Steps:** Remove every `# ToDo:` that the new cmdlets have resolved; delete `CrossProduct`, the hardcoded absolute path to `Get-NuSpecFromManifest.ps1`, and any lingering lifecycle-matrix remnants.
**Dependencies:** T-47.

### T-72 · Retrospective memo

- [ ]

**Gap:** None (process)
**Steps:** Write a 1-page retrospective to `_Planning` comparing the old script's build time, failure modes, and developer ergonomics against the new pipeline. Capture anything worth feeding back into Explainer 602.
**Dependencies:** T-63.

---

## Parallelization Plan

Agents can swarm Phase 1 (T-10 through T-1A) in parallel — none of those tasks touch `module.build.ps1` itself. Phase 2 (T-30, T-31) runs in parallel with Phase 1. Phase 3 is mostly sequential because each task modifies the same file, but T-45 and T-46 can land in parallel once T-41 is merged. Phase 4 starts only after T-47 is green. Phase 5 can begin in parallel with Phase 4 once the pilot is running.

## Dependency Graph (Condensed)

```text
T-00, T-01, T-02                     (prep)
  |
  +-- T-10 .. T-1A   (Phase 1, parallel)
  +-- T-30, T-31     (Phase 2, parallel)
           |
           v
         T-40 -> T-41 -> T-42 -> T-43 -> T-44
                     \-> T-45 -> T-46
                                   \-> T-47 -> T-48 -> T-49
                                                  \-> T-60 -> T-61 -> T-62 -> T-63
                                                                              \-> T-70, T-71, T-72
```
