# PowerShell Modules — Build Process

**Scope:** Sprint-0006. How PowerShell modules in the ATAP.Utilities repository
are produced from loose `.ps1` source files into a single consolidated `.psm1`
script module plus a validated `.psd1` manifest, ready for packing.

**Audience:** Developers who add/edit PowerShell cmdlets, anyone wiring a new
module into the 5-tier pipeline, and CI engineers debugging
`ATAP.Utilities.BuildTooling.PowerShell` build failures.

**Status:** Authoritative for sprint-0006. Supersedes scattered notes in the
legacy `Publish-PSPackage.ps1` header comments.

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
| `ATAP.Utilities.BuildTooling.PowerShell`     | Build/pack/publish cmdlets for the whole pipeline (self-hosting)    |
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

`ATAP.Utilities.BuildTooling.PowerShell` builds itself — the build cmdlets
live inside the module they build. The bootstrap order is:

1. **Source import** — the module is imported directly from `src/` via
   dot-sourcing (not from a previously-built `.psm1`). This happens in
   `build.ps1` or the developer's profile.
2. **Self-build** — the imported cmdlets are invoked against the module's own
   folder, producing a `.psm1` + `.psd1` under `_generated/`.
3. **Re-import (optional)** — the generated module can be re-imported to
   verify it behaves identically to the source-imported version.

There is no circular dependency because the source-imported functions are
entirely self-contained — they depend only on built-in cmdlets and PSFramework.

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
   §7 is documented but not scripted. Each developer currently invokes the
   cmdlets manually or via `Publish-ATAPUtilities.ps1` (see Pack-and-Publish
   doc).

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

## Related Documents

- [Production-and-Tooling-Overview.md](Production-and-Tooling-Overview.md) — index.
- [PowerShell-Modules-Versioning.md](PowerShell-Modules-Versioning.md) — NBGV → `.psd1` version translation.
- [PowerShell-Modules-Pack-and-Publish.md](PowerShell-Modules-Pack-and-Publish.md) — from `.psm1`+`.psd1` to `.nupkg` on ProGet.
- [PowerShell-Modules-Test-Process.md](PowerShell-Modules-Test-Process.md) — Pester, coverage, PSScriptAnalyzer.
- [PowerShell-Script-Consolidation.md](PowerShell-Script-Consolidation.md) — standalone scripts outside modules.
