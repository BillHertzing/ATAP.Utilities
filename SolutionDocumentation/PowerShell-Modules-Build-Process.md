# PowerShell Modules — Build Process

**Scope:** Sprint-0006/0007. How PowerShell modules in the ATAP.Utilities
repository are produced from loose `.ps1` source files into a single
consolidated `.psm1` script module plus a validated `.psd1` manifest, ready
for packing.

**Audience:** Developers who add/edit PowerShell cmdlets, anyone wiring a new
module into the 5-tier pipeline, and CI engineers debugging
`ATAP.Utilities.BuildTooling.PowerShell` build failures.

**Status:** Authoritative for sprint-0006/0007. Supersedes scattered notes
in the legacy `Publish-PSPackage.ps1` header comments.

> **Strategy update (sprint-0007 — Immutable Build).** A PowerShell module
> `.nupkg` is built and packed **exactly once** (at the Experimental tier)
> and then promoted unchanged through Development → Integration → QA →
> Production via `Promote-ProGetPackage`. Higher tiers do **not** rebuild;
> they restore the existing module from the next-higher feed and run
> Pester / PSScriptAnalyzer / coverage gates against it. This document
> covers what happens during the single build at Experimental. See
> [Immutable-Build-Strategy.md](Immutable-Build-Strategy.md) for the
> overall policy.

**Not in this doc:**
- How versions are assigned → see [PowerShell-Modules-Versioning.md](PowerShell-Modules-Versioning.md).
- How the output is packed/pushed → see [PowerShell-Modules-Pack-and-Publish.md](PowerShell-Modules-Pack-and-Publish.md).
- Pester tests and coverage → see [PowerShell-Modules-Test-Process.md](PowerShell-Modules-Test-Process.md).
- Scripts that are **not** part of any module (standalone `.ps1`) → see
  [PowerShell-Script-Consolidation.md](PowerShell-Script-Consolidation.md).

---

## 1. Module inventory (sprint-0006)

There are ~12 first-party PowerShell modules under `src/`, each in its own
folder named after the module. Every folder contains exactly one `.psd1`
manifest whose `BaseName` matches the folder name.

| Module                                       | Purpose                                                             |
| -------------------------------------------- | ------------------------------------------------------------------- |
| `ATAP.Utilities.PowerShell`                  | Cross-cutting utilities, profile helpers                            |
| `ATAP.Utilities.BuildTooling.PowerShell`     | Compatibility parent for the BuildTooling child-module family       |
| `ATAP.Utilities.FileIO.PowerShell`           | File / path helpers                                                 |
| `ATAP.Utilities.Security.Powershell`         | Bitwarden access, secret retrieval                                  |
| `ATAP.Utilities.DatabaseManagement.Powershell` | Flyway, SQL Server lifecycle helpers                              |
| `ATAP.Utilities.Neo4j.Powershell`            | Neo4j admin helpers                                                 |
| `ATAP.Utilities.Hydrus.Powershell`           | Hydrus automation                                                   |
| `ATAP.Utilities.IAC.Ansible.Powershell`      | Ansible wrappers                                                    |
| `ATAP.Utilities.FinancialAPI`                | Financial data fetchers                                             |
| `ATAP.Utilities.Speech.Powershell`           | TTS / STT helpers                                                   |
| `ATAP.Utilities.VoiceRecognition.Powershell` | Voice recognition helpers                                           |
| `ATAP.Console.QueryChatGPT.Powershell`       | CLI wrapper for OpenAI queries                                      |

The build-tooling module is intentionally self-hosted — it builds itself using
its own cmdlets (see §8).

---

## 2. Canonical source layout

Every module folder follows the same structure:

```text
src/<ModuleName>/
├── <ModuleName>.psd1      # authored manifest (template)
├── <ModuleName>.psm1      # OPTIONAL hand-written root module (rare)
├── public/                # cmdlets exported by the module — one .ps1 per function
│   └── <Verb-Noun>.ps1
├── private/               # internal helpers — not exported
│   └── <helper>.ps1
├── lib/                   # optional: loose native assemblies or auxiliary .ps1
├── tests/                 # Pester tests — not shipped
│   ├── Unit/
│   └── Integration/
├── version.json           # NBGV config
└── Documentation/         # module-level docs
```

Key invariants:

- **Folder name = manifest `BaseName`**. `Resolve-PSModuleMetadata` relies on
  this to locate the single `.psd1`.
- **One function per `.ps1` file in `public/`**. The file's base name
  matches the function name (`Verb-Noun` form).
- **Private helpers live in `private/`** and are not enumerated for
  `FunctionsToExport`.
- **Pester tests live in `tests/`** — never shipped.

### 2.1 Standard module scaffold (mandatory — Sprint 0012 Task 12.46, plan 1.b)

Beyond the build-relevant layout above, every first-party module and submodule
under `src/` MUST carry this scaffold (see `PlanPowershellReorganization.md`):

| Item | Requirement |
| --- | --- |
| `ReadMe.md` | Module purpose, public-function table, layout, deployment notes — real content, not boilerplate |
| `INDEX.md` | One row per file/folder in the module with a one-line description |
| `tests/` | Pester suite; every public function has at least one test |
| `Documentation/` | Module-level docs (at minimum an `Overview.md`) |
| `Documentation/images/` | Images referenced by module docs (keep a `.gitkeep` when empty) |
| `version.json` | NBGV config (packaging prerequisite) |
| BuildMaster map entry | A reviewed row in `BuildMasterApplicationByModuleConfigRootKey` (ATAP.IAC BuildMaster HostSettings fragment); all PowerShell modules share the consolidated application `ATAP.Utilities-PowerShell` |
| Area link-up | `Documentation/` links to the module's functional-area START-HERE doc in `SolutionDocumentation/INDEX.md`, and the area row links back |

Code standards for every module `.ps1` (enforced by the Task 12.46 compliance
sweep): no top-level executable code (BEGIN-block helper fallbacks,
function-local constants, aliases only in the `.psm1`, `&`-proof guards for
dual-purpose scripts), PSFramework logging levels only
(`Debug`/`Verbose`/`Important`/`Error`), and secrets referenced by SecretName
via `Get-SecretATAP` — never literals.

---

## 3. Build concept: consolidation, not copy

The "build" of a PowerShell module is **source consolidation**. Instead of
loading dozens of `.ps1` files at import time via dot-sourcing, the build:

1. Concatenates every `public/*.ps1`, `private/*.ps1`, and `lib/*.ps1` into
   one generated `.psm1`.
2. Hoists and de-duplicates `using namespace` / `using assembly` statements
   to the top.
3. Writes a new `.psd1` next to the generated `.psm1`, stamped with an
   NBGV-derived version and an accurate `FunctionsToExport` list.
4. Emits everything under `_generated/psmodules/<ModuleName>/packages/<ModuleName>/`
   (per rule SC-0033).

This approach (a) keeps source files small and reviewable, (b) makes
`Import-Module` fast because only one `.psm1` is read, and (c) lets the packer
treat the generated folder as a self-contained module directory.

---

## 4. The two build cmdlets

Both live in `ATAP.Utilities.BuildTooling.PowerShell/public/`:

### 4.1 `Build-PSModulePsm1` — generate the script module

`src/ATAP.Utilities.BuildTooling.PowerShell/public/Build-PSModulePsm1.ps1`

**Inputs**
- `-ModuleRoot`  — absolute path of the source module folder.
- `-OutputPath`  — absolute path of the generated `.psm1`.
- `-SourceDirectoryNames` (optional) — defaults to `@('public','private','lib')`.

**Algorithm**
1. Enumerate `*.ps1` files under each requested sub-directory (recursive).
2. If zero files found, write an empty `.psm1` and log a warning
   (not an error — some modules ship only assemblies).
3. For each `.ps1`:
   - Parse into an AST via `[Parser]::ParseFile`.
   - Extract every `UsingStatement` (`using namespace`, `using assembly`,
     `using module`) into a hash-set.
   - Delete each using-statement's span from the file text by offset
     (descending sort prevents offset shift).
   - Record the remaining body text keyed by source file name.
4. Re-order the unique `using` statements: namespace → assembly → module,
   preserving discovery order within each group.
5. Write the output: hoisted using block → blank line → for each source
   file a `# <filename>.ps1` header then the stripped body.
6. File encoding is **UTF-8 with BOM** (required by `Test-ModuleManifest`
   when the manifest's `RootModule` points at the file).

**Output**: `System.IO.FileInfo` to the generated `.psm1`.

### 4.2 `Build-PSModuleManifest` — stamp the module manifest

`src/ATAP.Utilities.BuildTooling.PowerShell/public/Build-PSModuleManifest.ps1`

**Inputs**
- `-SourceManifestPath`  — path to the authored template `.psd1`.
- `-OutputManifestPath`  — destination path (next to generated `.psm1`).
- `-ModuleVersion`       — `[System.Version]` (3-part).
- `-Prerelease`          — alphanumeric-only string; empty clears.
- `-PublicFunctions`     — string array → `FunctionsToExport`.
- `-Aliases`             — string array → `AliasesToExport`.
- `-RequiredAssemblies`  — string array → `RequiredAssemblies`.
- `-FormatFiles`         — string array → `FormatsToProcess`.
- `-DscResources`        — string array → `DscResourcesToExport`.

**Algorithm**
1. Copy the source `.psd1` to the output path.
2. Build a splat hashtable of `Update-ModuleManifest` parameters. `ModuleVersion`
   and `Prerelease` are always included; the list-valued parameters are
   included only when non-empty.
3. Invoke `Update-ModuleManifest @params`.
4. Validate the result with `Test-ModuleManifest` and throw on error.

**Output**: `System.IO.FileInfo` to the generated `.psd1`.

---

## 5. The canonical `_generated/` layout

Per SC-0033, every build artifact goes under `_generated/` at the repo root.
`Resolve-PSModuleMetadata` computes the path:

```text
_generated/psmodules/<ModuleName>/
├── packages/
│   └── <ModuleName>/
│       ├── <ModuleName>.psm1       # from Build-PSModulePsm1
│       └── <ModuleName>.psd1       # from Build-PSModuleManifest
├── test-results/                    # Pester TRX / NUnit / JUnit
├── coverage/                        # coverlet / Pester coverage
└── artifacts/                       # 7z archives (see §9)
```

The double `<ModuleName>` nesting under `packages/` is deliberate — the inner
folder is the thing that gets packed into a NuGet-style `.nupkg`, and NuGet's
PowerShellGet convention requires the module to sit at `tools/<ModuleName>/`
inside the package layout. See
[PowerShell-Modules-Pack-and-Publish.md](PowerShell-Modules-Pack-and-Publish.md) §3.

---

## 6. Resolving module metadata

`Resolve-PSModuleMetadata` (`src/.../public/Resolve-PSModuleMetadata.ps1`) is
the single source of truth for paths. Every higher-level cmdlet calls it first.

**Inputs**: `-StartPath` (default `$PSScriptRoot`).

**Outputs**: `[PSCustomObject]` with
- `ModuleName`  — the `.psd1` `BaseName` (also the folder name).
- `ModuleRoot`  — normalized absolute path to the source module folder.
- `RepoRoot`    — `git rev-parse --show-toplevel` result.
- `ManifestPath`— absolute path to the authored `.psd1`.
- `OutputRoot`  — `<RepoRoot>/_generated/psmodules/<ModuleName>/`.

This cmdlet is **strictly read-only**. It does not create any folders — the
build cmdlets that consume `OutputRoot` create directories on demand.

---

## 7. End-to-end build flow

The typical per-module build sequence invoked by a build script:

```powershell
Import-Module ATAP.Utilities.BuildTooling.PowerShell

$meta = Resolve-PSModuleMetadata -StartPath (Join-Path $repoRoot "src/$moduleName")

# 1. Compute version from NBGV
$v = Get-PSModuleVersionFromNBGV -ModuleRoot $meta.ModuleRoot

# 2. Enumerate function names from public/
$publicFns = Get-ChildItem "$($meta.ModuleRoot)/public" -Filter '*.ps1' -File |
    ForEach-Object { $_.BaseName }

# 3. Concatenate sources into generated .psm1
$psm1 = Join-Path $meta.OutputRoot "packages/$($meta.ModuleName)/$($meta.ModuleName).psm1"
Build-PSModulePsm1 -ModuleRoot $meta.ModuleRoot -OutputPath $psm1

# 4. Stamp the manifest
$psd1 = Join-Path $meta.OutputRoot "packages/$($meta.ModuleName)/$($meta.ModuleName).psd1"
Build-PSModuleManifest `
    -SourceManifestPath $meta.ManifestPath `
    -OutputManifestPath $psd1 `
    -ModuleVersion $v.ModuleVersion `
    -Prerelease $v.Prerelease `
    -PublicFunctions $publicFns

# 5. Run Pester against the generated module (see Test-Process doc)
# 6. Compress artifacts (see §9)
# 7. Publish to ProGet (see Pack-and-Publish doc)
```

---

## 8. The self-hosting bootstrap

The BuildTooling family is self-hosted through its independently buildable child
modules. `ATAP.Utilities.BuildTooling.PowerShell` is the compatibility parent: it
imports required children and re-exports the legacy command surface. The family
topology is maintained in
[`BuildToolingFamilyArchitecture.puml`](../src/ATAP.Utilities.BuildTooling.PowerShell/Documentation/BuildToolingFamilyArchitecture.puml).

During the Task 13.73 endgame, build and packaging commands are supplied by the
child modules rather than by a source-imported monolith. The compatibility parent
continues to be built last, after its child dependencies. The bootstrap order is:

1. **Installed child tooling** — import the accepted installed child modules,
   never packaging commands from an in-flight source tree.
2. **Dependency-order build** — build, test, publish, and promote `Common`, then
   each child in `Build/ModuleFamily.psd1` order.
3. **Compatibility-parent build** — build and test the parent after the child
   versions satisfy its minimum requirements.
4. **Fresh-session verification** — verify both child-only imports and the
   parent compatibility surface from installed paths.

This keeps the dependency direction one way: `Common` → children → compatibility
parent. The prior bootstrap pin remains in place until a complete tier cycle and
two-host deploy-state audit prove that it can be retired.

---

## 9. Artifact compression (`Compress-PSModuleArtifacts`)

After test and pack, `Compress-PSModuleArtifacts` packs the per-module
`_generated/` tree into three `.7z` archives under `artifacts/`:

| Source folder            | Output archive                              |
| ------------------------ | ------------------------------------------- |
| `<OutputRoot>/test-results` | `<OutputRoot>/artifacts/TestResults.7z`  |
| `<OutputRoot>/coverage`     | `<OutputRoot>/artifacts/CoverageReport.7z` |
| `<OutputRoot>/packages`     | `<OutputRoot>/artifacts/Packages.7z`     |

Empty or missing source folders are skipped with a warning (no failure).
Requires `7z.exe` on PATH (`choco install 7zip`). The archives are what
BuildMaster uploads as the "promotable" artifact bundle (see
[BuildMaster-ProGet-CSharp-Package-Pipeline.md](BuildMaster-ProGet-CSharp-Package-Pipeline.md)).

---

## 10. Encoding, line endings, and BOM

- Generated `.psm1` — **UTF-8 with BOM** (`Set-Content -Encoding utf8BOM`).
  Required for `Test-ModuleManifest` when the manifest's `RootModule` points
  at a file with non-ASCII content.
- Generated `.psd1` — whatever `Update-ModuleManifest` emits (typically
  UTF-8 with BOM).
- Authored `.ps1` sources — mixed (UTF-8 with and without BOM historically).
  The build is indifferent to input encoding because `ParseFile` handles
  both; output is always re-written with BOM.

---

## 11. Common failures and remedies

| Error                                                                     | Cause                                                             | Fix                                                                     |
| ------------------------------------------------------------------------- | ----------------------------------------------------------------- | ----------------------------------------------------------------------- |
| `Test-ModuleManifest` fails with "The Guid 'abc...' is not valid"          | Template `.psd1` has a placeholder GUID                          | Fix the `GUID = '...'` line in the source manifest                      |
| `Build-PSModulePsm1` writes empty `.psm1` with warning                    | No `.ps1` files under `public/`, `private/`, or `lib/`           | Expected when the module is assembly-only; silence by passing `-SourceDirectoryNames @('lib')` |
| `Update-ModuleManifest` fails with "cannot bind parameter 'Prerelease'"   | Prerelease contains `.`, `-`, or other non-alphanumeric character | Re-run `Get-PSModuleVersionFromNBGV` (it zero-pads and strips separators) |
| Double-BOM in generated `.psm1`                                           | Two invocations piped through `Add-Content` instead of `Set-Content` | Use `Set-Content -Encoding utf8BOM` (what `Build-PSModulePsm1` does)  |
| `ParseFile` returns errors array                                          | Syntax error in a source `.ps1`                                   | The cmdlet does **not** inspect the errors array (known gap)           |
| Resolve-PSModuleMetadata: "zero or multiple manifests found"              | Folder name ≠ `.psd1` base name, or two `.psd1` files present    | Rename the folder to match; delete stray manifests                      |

---

## 12. Known drift and gaps (sprint-0006)

1. **`Build-PSModulePsm1` silently ignores parse errors.** The AST's
   `ParseErrors` collection is extracted but never checked. A malformed source
   file produces a successful but broken `.psm1`. Tracked for sprint-0007.

2. **`using module` hoisting is untested.** The sort treats `using module` as
   a catch-all (neither `namespace` nor `assembly`). No module in the repo
   currently uses `using module`, so this path has no coverage.

3. **`Publish-PSPackage.ps1` is legacy Jenkins-era dead code.** It is still
   exported by the module but is not called by any current build script.
   Marked for removal in sprint-0007.

4. **No `Build.ps1` orchestrator at the repo root.** The end-to-end flow in
   §7 is documented but not scripted. Each developer invokes the cmdlets
   manually (`New-PSModuleNupkg` → `Publish-PSModuleToProGet`), or the
   BuildMaster PowerShell-module pipeline runs them via
   `Invoke-ModuleBuildWithRetry`. (The legacy repo-root
   `Publish-ATAPUtilities.ps1` orchestrator was deleted in sprint-0007
   (V4-G10); see Pack-and-Publish doc §11.)

5. **`ATAP.Utilities.PowerShell.psd1` is UTF-16 encoded.** This is a legacy
   byproduct of Windows PowerShell ISE. `Update-ModuleManifest` normalizes
   it to UTF-8 during build, but the on-disk source is awkward to grep.
   Cleanup is tracked.

---

## 13. Quick reference

Build one module:

```powershell
$meta = Resolve-PSModuleMetadata -StartPath (Resolve-Path ./src/ATAP.Utilities.FileIO.PowerShell)
$v = Get-PSModuleVersionFromNBGV -ModuleRoot $meta.ModuleRoot
$pkg = "$($meta.OutputRoot)/packages/$($meta.ModuleName)"
New-Item -ItemType Directory -Path $pkg -Force | Out-Null
Build-PSModulePsm1 -ModuleRoot $meta.ModuleRoot -OutputPath "$pkg/$($meta.ModuleName).psm1"
Build-PSModuleManifest `
  -SourceManifestPath $meta.ManifestPath `
  -OutputManifestPath "$pkg/$($meta.ModuleName).psd1" `
  -ModuleVersion $v.ModuleVersion -Prerelease $v.Prerelease `
  -PublicFunctions (Get-ChildItem "$($meta.ModuleRoot)/public" -Filter '*.ps1').BaseName
```

Build all modules (one-liner loop):

```powershell
Get-ChildItem ./src -Directory -Filter '*Powershell*' | ForEach-Object {
    Build-SinglePSModule -ModulePath $_.FullName   # helper not yet written — see gap §12.4
}
```

---

## 14. Hybrid Build via module.build.ps1 (Invoke-Build DAG)

**Source:** Migrated from `Explainers/602 - 5Tier Software Production process
Revision 2.md` §14.6 and §14.6.1 (row `602-psbuild`).

PowerShell module builds in ATAP use a **hybrid architecture** that combines
`module.build.ps1` (an Invoke-Build task DAG) with OtterScript `PSCall` in
BuildMaster. This replaces an earlier approach that embedded all PowerShell
module build logic directly in OtterScript.

### 14.1 Rationale

The hybrid approach solves three problems:

1. **OtterScript bloat.** Embedding full build logic in OtterScript made the
   `.otter` plan files long, unreviewable, and impossible to run locally.
   `module.build.ps1` keeps OtterScript thin — it only triggers the build and
   captures artifacts.
2. **Local / CI parity.** Developers run
   `Invoke-Build -File module.build.ps1 -Task Build` locally using the same
   cmdlets that BuildMaster calls. There is no hidden CI-only build logic.
3. **Testable units.** All behavior lives in individual cmdlets in
   `ATAP.Utilities.BuildTooling.PowerShell`. Each cmdlet is independently
   Pester-testable. The script itself contains minimal logic — it is purely
   a task DAG that calls the cmdlets in the correct order.

**Architecture overview:**

```text
BuildMaster OtterScript Plan
  |
  +-- PSCall(module.build.ps1, Task: 'Build')
         |
         +-- Resolve-PSModuleMetadata
         +-- Get-PSModuleVersionFromNBGV
         +-- Get-TierFromNBGVLabel     (legacy ceiling/feed helper)
         +-- Invoke-PSModuleBuild
         +-- Test-PSModule              (Pester wrapper)
         +-- Assert-PSModuleQualityGate
         +-- New-PSModuleArtifactLayout
         +-- Publish-PSModuleToProGetFeed
         +-- Register-PSModuleBuildMasterPackage
```

**OtterScript invocation example:**

```otterscript
# Call module.build.ps1 via PSCall for PowerShell module builds
PSCall module.build.ps1
(
    Task: Build,
    Branch: $Branch,
    VersionLabel: $PrereleaseLabel,
    TargetFeed: $TargetFeed,
    BitWardenApiKeySecretName: ProGet.BuildMaster.API.Key
);
```

### 14.2 Task Hierarchy

`module.build.ps1` defines a small set of named Invoke-Build tasks composed
out of the 10 cmdlets in §14.3. The composition is layered so that local
developers, CI, and BuildMaster all enter the DAG at the appropriate level:

| Task      | Composition                                                                                        | Used by                                                            |
| --------- | -------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------ |
| `Short`   | `Resolve-PSModuleMetadata` → `Get-PSModuleVersionFromNBGV` → `Invoke-PSModuleBuild`                | Fast inner-loop build; no tests, no publish                        |
| `Verify`  | `Short` + `Test-PSModule` (Unit tag) + `Assert-PSModuleQualityGate`                                | Pre-commit / quick PR check                                        |
| `All`     | `Verify` + `Test-PSModule` (Integration tag) + `New-PSModuleArtifactLayout`                        | Default local "everything passes" gate before pushing              |
| `Local`   | `All`                                                                                              | Developer-facing alias (matches the convention developers expect)  |
| `CI`      | `All` + Pester result file emission + structured logging                                           | Continuous-integration runs that capture results for upload        |
| `Publish` | `CI` + `Publish-PSModuleToProGetFeed` + `Register-PSModuleBuildMasterPackage`                      | BuildMaster pipeline (Experimental stage only — immutable strategy) |

Notes:

- `Short`, `Verify`, `All`, `Local`, `CI`, `Publish` form a strict superset
  chain: each task depends on (and re-executes) the prior task. There is no
  alternate path that skips earlier steps.
- The `Build` task referenced from OtterScript (§14.1) is the BuildMaster
  entry point; in the canonical DAG it is an alias for `Publish` when the
  caller is BuildMaster, and may be aliased to `All` for local developers
  who want the same surface name.
- Under the immutable build strategy, `Publish-PSModuleToProGetFeed` runs
  **only at the Experimental tier**. Later tiers run `Verify` against the
  promoted `.nupkg` but never re-invoke `Publish`.

### 14.3 Cmdlet Extraction Plan (module.build.ps1 → ATAP.Utilities.BuildTooling.PowerShell)

The following 10 cmdlets are to be extracted from `module.build.ps1` into
the `ATAP.Utilities.BuildTooling.PowerShell` module so each is independently
testable with Pester and reusable across build scripts.

| Cmdlet                                | Responsibility                                                                                         |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| `Resolve-PSModuleMetadata`            | Reads `.psd1` + `version.json`, returns a module metadata hashtable                                    |
| `Get-PSModuleVersionFromNBGV`         | Calls `nbgv get-version`, parses and returns version components (label, height, full SemVer)           |
| `Get-TierFromNBGVLabel`               | Legacy helper that maps NBGV prerelease label (Sprint / feature / Alpha / Beta / QA / empty) to ceiling tier name and PowerShellGet feed |
| `Invoke-PSModuleBuild`                | Wraps `dotnet publish` or `Build-Module`, writes staged output to a named output directory             |
| `Publish-PSModuleToProGetFeed`        | Calls `Publish-PSResource`, reading the ProGet API key from Bitwarden via `-BitWardenSecretName`       |
| `Test-PSModule`                       | Pester 5+ wrapper that applies the tier-appropriate tag filter (`-Tag Unit`, `-Tag Integration`, etc.) |
| `Assert-PSModuleQualityGate`          | Verifies coverage ≥ `PassingCodeCoveragePct` and test pass rate; throws on gate failure                |
| `Move-ProGetPackageInterTier`         | Promotes a package from one tier's feed to the next (existing cmdlet — update to 5-tier order)         |
| `New-PSModuleArtifactLayout`          | Creates the staging directory structure: `.nupkg`, `.psd1`, metadata, and test-result files            |
| `Register-PSModuleBuildMasterPackage` | Registers the built package with the BuildMaster API so it appears in the build artifacts              |

**Development conventions for all extracted cmdlets:**

- Logging via `Write-PSFMessage -Level Important` (PSFramework); never
  `Write-Host`.
- API keys always sourced from Bitwarden via `-BitWardenSecretName` parameter
  — never hardcoded.
- Error handling via PSFramework structured errors; no bare `throw`
  statements.
- Each cmdlet must have a corresponding `*.Tests.ps1` file in the module's
  `tests/Unit/` folder.

---

## Related Documents

- [Production-and-Tooling-Overview.md](Production-and-Tooling-Overview.md) — index.
- [PowerShell-Modules-Versioning.md](PowerShell-Modules-Versioning.md) — NBGV → `.psd1` version translation.
- [PowerShell-Modules-Pack-and-Publish.md](PowerShell-Modules-Pack-and-Publish.md) — from `.psm1`+`.psd1` to `.nupkg` on ProGet.
- [PowerShell-Modules-Test-Process.md](PowerShell-Modules-Test-Process.md) — Pester, coverage, PSScriptAnalyzer.
- [PowerShell-Script-Consolidation.md](PowerShell-Script-Consolidation.md) — standalone scripts outside modules.
