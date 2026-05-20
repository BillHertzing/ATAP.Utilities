# PowerShell Modules — Test Process

**Scope:** Sprint-0006/0007. How PowerShell modules in the ATAP.Utilities
repository are tested with Pester 5+, statically analyzed with
PSScriptAnalyzer, and gated for code coverage as they move through the
5-tier promotion model.

**Audience:** Module authors writing Pester tests, anyone debugging why a
tier promotion failed at the test gate, anyone extending the build-tooling
test cmdlets.

**Status:** Authoritative for sprint-0006/0007.

> **Strategy update (sprint-0007 — Immutable Build).** Tests at every tier
> run **against the existing promoted `.nupkg`** that was built once at
> Experimental and is being promoted upward. The test cmdlets
> (`Invoke-PSModulePesterTests`, `Invoke-PSModulePSScriptAnalyzer`,
> `Test-CodeCoverageGate`) accept the promoted module's path or feed-name
> as input; they do **not** re-pack or re-build. Test results are attached
> to the BuildMaster release record for that exact `(ModuleId, Version)`,
> not embedded into the `.nupkg` itself. See
> [Immutable-Build-Strategy.md](Immutable-Build-Strategy.md).

**Not in this doc:**
- How modules are built / packed / published → see the three sibling
  PowerShell docs.
- xUnit / C# tests → see [CSharp-Packages-Test-Process.md](CSharp-Packages-Test-Process.md).
- Tier ↔ feed mapping → see [BuildMaster-ProGet-CSharp-Package-Pipeline.md](BuildMaster-ProGet-CSharp-Package-Pipeline.md).

---

## 1. Test stack

| Layer                | Tool                  | Required version |
| -------------------- | --------------------- | ---------------- |
| Unit + integration   | Pester                | 5.0+             |
| Static analysis      | PSScriptAnalyzer      | latest           |
| Coverage format      | JaCoCo XML (default), Cobertura XML supported | n/a |
| Test result format   | JUnit XML             | n/a              |
| Assertion helpers    | `Should`, `Assert` (optional) | Pester 5 built-in |

PSFramework's `Write-PSFMessage` is used inside test helper code but tests
themselves do not depend on it.

Install once on a fresh machine:

```powershell
Install-Module Pester           -MinimumVersion 5.0.0 -Scope CurrentUser -Force
Install-Module PSScriptAnalyzer -Scope CurrentUser -Force
Install-Module Assert           -Scope CurrentUser -Force   # optional
```

Per CLAUDE.md: **never run Pester with `-NoProfile`**. The PowerShell profile
loads `$global:configRootKeys` and `$global:settings` which several test
helpers read.

---

## 2. Test layout per module

```text
src/<ModuleName>/
└── tests/
    ├── Unit/                           # tagged 'Unit'
    │   └── <Verb-Noun>.Tests.ps1
    ├── Integration/                    # tagged 'Integration'
    │   └── <feature>.Tests.ps1
    ├── <Verb-Noun>.Tests.ps1            # untagged or 'Functional'
    └── _helpers/                        # shared mocks (optional)
```

Conventions:
- One `*.Tests.ps1` per public function. The file name matches the function
  name.
- `Describe` block name matches the function name; `Context` blocks group
  related scenarios; `It` blocks state the assertion in plain English.
- Tags applied at the `Describe` or `It` level — see §4.

---

## 3. The two test driver cmdlets

### 3.1 `Invoke-PSModulePesterTests`

`src/.../public/Invoke-PSModulePesterTests.ps1`

**Inputs**
- `-ModuleRoot`         — module folder.
- `-Tier`               — `Sprint`/`Alpha`/`Beta`/`QA`/`Production`.
- `-OutputPath`         — JUnit XML destination.
- `-CoverageOutputPath` — JaCoCo XML destination.
- `-TestPaths`          — optional override; defaults to `$ModuleRoot/tests`.
- `-PesterOutputVerbosity` — optional Pester console verbosity; defaults to `Normal`.

**Behavior**
1. **Sprint tier**: skip Pester entirely; return `GatePass = $true` with
   zero counts. The build still succeeds — fast feedback at the Experimental tier.
2. **Alpha+**: confirm Pester 5+ is installed; throw with install hint
   otherwise.
3. Build a `[PesterConfiguration]` via `New-PSModulePesterConfiguration`
   helper:
   - `Run.Path = $TestPaths`
   - `Filter.Tag` / `Filter.ExcludeTag` driven by tier (see §4)
   - `TestResult.OutputFormat = 'JUnitXml'`, written to `$OutputPath`
   - `CodeCoverage.OutputFormat = 'JaCoCo'`, written to `$CoverageOutputPath`
   - `CodeCoverage.Path` = `public/` and `private/` if they exist
   - `Output.Verbosity = $PesterOutputVerbosity`; BuildMaster should normally
     keep the `Normal` default and use `Detailed`/`Diagnostic` only while debugging.
4. Run `Invoke-Pester -Configuration $cfg`.
5. Return a structured object including `GatePass = ($FailedCount -eq 0)`.

**Output**
```text
Tier         : Alpha
Passed       : 42
Failed       : 0
SkippedCount : 3
TotalCount   : 45
Duration     : 00:00:12
GatePass     : True
OutputFile   : .../test-results/PesterResults.xml
CoverageFile : .../coverage/CoverageResults.xml
```

### 3.2 `Invoke-PSModulePSScriptAnalyzer`

`src/.../public/Invoke-PSModulePSScriptAnalyzer.ps1`

**Inputs**
- `-Path`        — module root or single file.
- `-Tier`        — same five-value validate set.
- `-OutputPath`  — NUnit-style XML destination.

**Behavior**
1. **Sprint tier**: skip the analyzer; emit a placeholder NUnit XML so
   downstream pipeline steps can rely on the file existing.
2. **Alpha+**: ensure PSScriptAnalyzer is installed; throw otherwise.
3. Neutralize any ambient `$PSDefaultParameterValues['*:Settings']` to
   prevent accidental rule-set injection from the user's profile.
4. Run `Invoke-ScriptAnalyzer -Path $Path -Severity Warning,Error -Recurse`.
5. Compose an NUnit-style XML with one `<test-case>` per finding.
6. Gate passes only when **both** `ErrorCount` and `WarningCount` are zero.
   `Information`-severity findings are recorded but do not fail the gate.

**Output**
```text
Tier             : Alpha
ErrorCount       : 0
WarningCount     : 0
InformationCount : 5
GatePass         : True
OutputFile       : .../test-results/PSScriptAnalyzerResults.xml
```

---

## 4. Tier-to-tag filter matrix

`Get-PSModulePesterTierFilter` is the authoritative source. Tag filters
mirror the C# trait taxonomy at the same tier (see
[CSharp-Packages-Test-Process.md](CSharp-Packages-Test-Process.md) §4).

| Tier       | IncludeTag                                                               | ExcludeTag           | Pester runs? |
| ---------- | ------------------------------------------------------------------------ | -------------------- | ------------ |
| Sprint     | *(none)*                                                                 | `Disabled`           | **No**       |
| Alpha      | `Unit`                                                                   | `Slow`, `Disabled`   | Yes          |
| Beta       | `Unit`, `Integration`                                                    | `Slow`, `Disabled`   | Yes          |
| QA         | `Unit`, `Integration`, `Functional`, `Regression`, `E2E`, `Performance`  | `Disabled`           | Yes          |
| Production | `Unit`, `Integration`, `Functional`, `Regression`, `E2E`, `Performance`, `Smoke` | `Disabled`   | Yes          |

Tag selection is enforced inside the `It` block:

```powershell
Describe 'Get-PSModuleVersionFromNBGV' -Tag 'Unit' {
    It 'parses a Sprint label' -Tag 'Unit' {
        # ...
    }

    It 'rejects malformed NBGV output' -Tag 'Unit' {
        # ...
    }
}

Describe 'Publish-PSModuleToProGetFeed integration' -Tag 'Integration' {
    It 'publishes to a real ProGet Experimental feed' -Tag 'Integration' {
        # ...
    }
}
```

The `Slow` tag is reserved for tests that take more than ~5 seconds; it
suppresses them at Alpha/Beta but allows them at QA+.

---

## 5. The unit-vs-integration boundary

The same rule that applies in C# (see
[CSharp-Packages-Test-Process.md](CSharp-Packages-Test-Process.md) §8)
applies here:

- **Unit tests** mock every external dependency: file system writes, network
  calls, `git`, `nbgv`, `Get-BitWardenSecret`, `Publish-PSResource`. They
  must run identically with no network and no Bitwarden vault.
- **Integration tests** hit the real thing: a real ProGet feed (often a
  developer's local instance), a real `nbgv` invocation against a real
  `version.json`, real Bitwarden secret retrieval.

Mocking pattern in Pester 5:

```powershell
Describe 'Publish-PSModuleToProGetFeed' -Tag 'Unit' {
    BeforeAll {
        Mock -CommandName 'Publish-PSResource'         -MockWith { } -ModuleName ATAP.Utilities.BuildTooling.PowerShell
        Mock -CommandName 'Register-PSResourceRepository' -MockWith { } -ModuleName ATAP.Utilities.BuildTooling.PowerShell
        Mock -CommandName 'Get-BitWardenSecret'        -MockWith { 'fake-key' } -ModuleName ATAP.Utilities.BuildTooling.PowerShell
    }

    It 'maps Sprint tier to PowershellGet-experimental' {
        # ...
    }
}
```

`-ModuleName` is required to mock cmdlets *inside* the module under test.

### 5.1 DB-backed integration tests against a promoted module

`Invoke-PromotedModuleTests` restores the promoted `.nupkg` and imports it as
the system-under-test, then delegates the Pester run to
`Invoke-PSModulePesterTests` (see
[PowerShell-Modules-Build-Process.md](PowerShell-Modules-Build-Process.md) and
the M3 task in the V4 plan). The restored module carries the module code
**only** — it holds no connection string and no knowledge of which database
tier it is being exercised against. So a DB-backed integration test obtains
its connection input the same way whether the module under test came from the
source tree or from a promoted feed:

1. A test never hard-codes a connection string and never reads one out of the
   restored module.
2. The connection string lives in a Bitwarden Secure Note whose name follows
   [SprintInfrastructure-Naming.md §4](SprintInfrastructure-Naming.md#4-bitwarden-connection-string-secret-naming).
3. The pipeline (or the developer, locally) passes the **secret name** — not
   the secret value — to the test step in the `ATAPUTILITIES_DB_SECRET_NAME`
   environment variable. The integration test reads that variable and calls
   `Get-BitwardenSecret -SecretName $env:ATAPUTILITIES_DB_SECRET_NAME` (from
   `ATAP.Utilities.Security.Powershell`) to resolve a live connection string
   at run time.
4. If `ATAPUTILITIES_DB_SECRET_NAME` is unset, DB-backed integration tests
   **skip** (`It ... -Skip` with an `# acknowledged:` reason, per §7) rather
   than fail — the same convention applied to ProGet integration tests that
   need `localhost:50000` (§12 item 5).

| Tier                     | Bitwarden secret-name form                                    | SQL instance            |
| ------------------------ | ------------------------------------------------------------- | ----------------------- |
| Sprint / Experimental    | `dbConnectionString-ATAPUtilities-<Host>-Experimental-<User>` | `<Host>\Exp<username>`  |
| Alpha (Development)      | `dbConnectionString-ATAPUtilities-<Host>-Development-<User>`  | `<Host>\Dev<username>`  |
| Beta (Integration)       | `dbConnectionString-ATAPUtilities-utat022-Integration`        | `utat022\Integration`   |
| QA                       | `dbConnectionString-ATAPUtilities-utat022-QA`                 | `utat022\QA`            |
| Production               | `dbConnectionString-ATAPUtilities-utat022-Production`         | `utat022\Production`    |

The BuildMaster release plan holds the name in its per-tier variable (for the
Integration tier this is the existing `IntegrationDatabaseBitwardenSecretName`
stable variable; see [SprintInfrastructure-Naming.md §6.2](SprintInfrastructure-Naming.md#62-stable-variables-set-once-during-ecosystem-onboarding))
and exports it into the agent process as `ATAPUTILITIES_DB_SECRET_NAME` for
the test step. Locally a developer points the same variable at the
per-sprint, username-suffixed secret created by `New-SprintBitwardenSecrets`.
The value crossing the process boundary is always a *name*; the credential
itself is fetched at run time from Bitwarden and never appears in a build
log, package, or test artifact.

---

## 6. Coverage gate: `Test-CodeCoverageGate`

`src/.../public/Test-CodeCoverageGate.ps1`

**Inputs**
- `-CoverageFile` — JaCoCo (root `<report>`) or Cobertura (root `<coverage>`).
- `-Tier`         — five-value validate set.
- `-Threshold`    — percentage; defaults to `70.0`.

**Behavior**
- **Sprint, Alpha, Beta**: gate is **skipped**, returns `GatePass=$true`,
  `Skipped=$true`. Coverage is informational only at the lower tiers.
- **QA, Production**: parse the XML, compute total line coverage, compare
  to `$Threshold`. Gate passes when `coveragePct >= Threshold`.

**Format detection**
- Root element `<coverage>` → Cobertura. Read `line-rate` attribute,
  multiply by 100.
- Root element `<report>` → JaCoCo. Sum `<counter type="LINE">` covered
  and missed values, compute `covered / (covered + missed) * 100`.
- Any other root element → throw with the unrecognized element name.

**Output**
```text
Tier        : QA
CoveragePct : 78.42
Threshold   : 70.0
GatePass    : True
Skipped     : False
```

The default `70%` threshold can be overridden per module — there is no
central registry of per-module thresholds yet (see §11).

---

## 7. Failure-acknowledgement gate

`tests/Test-FailureAcknowledgedGate.Tests.ps1` is a **meta-test** that
ensures no test file contains an `It "..." -Skip` annotation without an
accompanying `# acknowledged: <reason>` comment. The intent is to keep
"temporarily skipped" tests from accumulating silently.

Behavior at Sprint tier: skipped (matches Pester gate).

---

## 8. Test artifacts and the `_generated/` layout

All test outputs go under `_generated/psmodules/<Module>/` per SC-0033:

```text
_generated/psmodules/<Module>/
├── test-results/
│   ├── PesterResults.xml              # JUnit-format
│   └── PSScriptAnalyzerResults.xml    # NUnit-format
├── coverage/
│   └── CoverageResults.xml            # JaCoCo (or Cobertura)
└── artifacts/
    ├── TestResults.7z                  # written by Compress-PSModuleArtifacts
    └── CoverageReport.7z
```

The `.7z` archives are what BuildMaster uploads as the promotable artifact
bundle (see [PowerShell-Modules-Build-Process.md](PowerShell-Modules-Build-Process.md) §9).

---

## 9. Writing a Pester 5 test — canonical pattern

```powershell
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }

BeforeAll {
    $script:moduleRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
    Import-Module (Join-Path $script:moduleRoot 'ATAP.Utilities.FileIO.PowerShell.psd1') -Force
}

Describe 'Get-RelativePath' -Tag 'Unit' {

    Context 'when both paths share a common ancestor' {

        It 'returns a forward-slash relative path' {
            $result = Get-RelativePath -From 'C:/repo/src/Foo' -To 'C:/repo/src/Foo/Bar/baz.txt'
            $result | Should -Be 'Bar/baz.txt'
        }

        It 'handles trailing separators on the source' {
            $result = Get-RelativePath -From 'C:/repo/src/Foo/' -To 'C:/repo/src/Foo/Bar'
            $result | Should -Be 'Bar'
        }
    }

    Context 'when paths are on different drives' {

        It 'throws a clear error' {
            { Get-RelativePath -From 'C:/foo' -To 'D:/bar' } |
                Should -Throw -ExpectedMessage '*cross-drive*'
        }
    }
}

AfterAll {
    Remove-Module ATAP.Utilities.FileIO.PowerShell -Force -ErrorAction SilentlyContinue
}
```

Rules of thumb:
- **One `Describe` per function**. Multiple `Context` blocks for scenarios.
- **`Should`** is the only assertion DSL used; do not mix in `Assert`-style
  unless explicitly imported.
- **No `Start-Sleep` in unit tests.** If a test depends on time, mock the
  clock.
- **Re-import the module under `BeforeAll`** with `-Force` so previous test
  runs do not leak into the current one.

---

## 10. Running tests locally

A single test file:

```powershell
Invoke-Pester -Path ./src/ATAP.Utilities.FileIO.PowerShell/tests/Get-RelativePath.Tests.ps1 -Output Detailed
```

A whole module at the Alpha gate:

```powershell
Invoke-PSModulePesterTests `
  -ModuleRoot ./src/ATAP.Utilities.FileIO.PowerShell `
  -Tier Alpha `
  -OutputPath  ./_generated/psmodules/ATAP.Utilities.FileIO.PowerShell/test-results/PesterResults.xml `
  -CoverageOutputPath ./_generated/psmodules/ATAP.Utilities.FileIO.PowerShell/coverage/CoverageResults.xml
```

Static-analyze + gate together:

```powershell
$pester  = Invoke-PSModulePesterTests        @pesterArgs
$pssa    = Invoke-PSModulePSScriptAnalyzer   @pssaArgs
$cov     = Test-CodeCoverageGate -CoverageFile $pester.CoverageFile -Tier Alpha
if (-not ($pester.GatePass -and $pssa.GatePass -and $cov.GatePass)) { throw "Tier gate FAILED" }
```

---

## 11. Common failures and remedies

| Error                                                                               | Cause                                                          | Fix                                                              |
| ----------------------------------------------------------------------------------- | -------------------------------------------------------------- | ---------------------------------------------------------------- |
| `Pester 5 or newer is not installed`                                                | Stale Pester 3/4 from Windows PowerShell                       | `Install-Module Pester -MinimumVersion 5.0.0 -Scope CurrentUser -Force` |
| `Mock not invoked` failures inside module-internal cmdlets                          | Forgot `-ModuleName` on `Mock`                                  | Always pass `-ModuleName ATAP.Utilities.BuildTooling.PowerShell` |
| PSScriptAnalyzer chokes on user-profile rule-set                                   | Profile sets `$PSDefaultParameterValues['*:Settings']`         | The cmdlet now neutralizes this; if you see it again, file a bug |
| `<counter type="LINE">` missing from JaCoCo                                         | Pester 5 emitted an empty coverage report (no covered files)   | Confirm `CodeCoverage.Path` includes `public/` / `private/`      |
| Pester runs but produces no JUnit XML                                               | `TestResult.Enabled = $false` (default in some Pester versions) | The driver sets this to `$true`; check Pester version             |
| Tests pass locally, fail in CI with "Cannot find variable `$global:settings`"      | CI shell ran with `-NoProfile`                                  | Drop `-NoProfile`; load the user profile per CLAUDE.md           |
| `Test-CodeCoverageGate` reports 0%                                                 | Coverage XML covered no executable statements                  | Confirm the test file `Import-Module`s the module (not just dot-sources files) |

---

## 12. Known drift and gaps (sprint-0006)

1. **Coverage threshold is hard-coded to 70%.** No per-module override
   mechanism. A module with low natural coverage (e.g. interactive UI
   helpers) cannot be exempted without editing the call site.

2. **`Skip` reason audit is informal.** `Test-FailureAcknowledgedGate`
   greps for a comment near `-Skip`, but the comment's content is not
   validated.

3. **No mutation testing.** Stryker-equivalent for PowerShell exists
   (`PSStryker`) but is not integrated.

4. **Pester 5 module re-import is brittle.** Running the same test twice
   sometimes leaves stale function definitions; `-Force` mitigates but
   doesn't eliminate. Tracked.

5. **Integration tests against ProGet require a live local server.**
   There is no test-double / containerized ProGet for hermetic CI runs;
   integration tests are skipped on machines without `localhost:50000`
   reachable.

6. **PSScriptAnalyzer rule-set is the built-in default.** No project-level
   `PSScriptAnalyzerSettings.psd1` exists, so suppressions live inline as
   `[Diagnostics.CodeAnalysis.SuppressMessageAttribute(...)]`.

---

## 13. Quick reference

Run all unit tests for one module:

```powershell
Invoke-Pester -Path ./src/<Module>/tests/Unit -Output Detailed
```

Run a single test file with full output:

```powershell
Invoke-Pester -Path ./src/<Module>/tests/Get-Foo.Tests.ps1 -Output Detailed
```

Gate one module at Alpha:

```powershell
Invoke-PSModulePesterTests -ModuleRoot ./src/<Module> -Tier Alpha `
  -OutputPath ./_generated/psmodules/<Module>/test-results/PesterResults.xml `
  -CoverageOutputPath ./_generated/psmodules/<Module>/coverage/CoverageResults.xml
```

Static-analyze one module:

```powershell
Invoke-PSModulePSScriptAnalyzer -Path ./src/<Module> -Tier Alpha `
  -OutputPath ./_generated/psmodules/<Module>/test-results/PSScriptAnalyzerResults.xml
```

Coverage gate at QA with 80% bar:

```powershell
Test-CodeCoverageGate -CoverageFile ./coverage.xml -Tier QA -Threshold 80
```

---

## Related Documents

- [Production-and-Tooling-Overview.md](Production-and-Tooling-Overview.md) — index.
- [PowerShell-Modules-Build-Process.md](PowerShell-Modules-Build-Process.md) — what the tests run against.
- [PowerShell-Modules-Versioning.md](PowerShell-Modules-Versioning.md) — tier label that drives the gate.
- [PowerShell-Modules-Pack-and-Publish.md](PowerShell-Modules-Pack-and-Publish.md) — what happens after the gate passes.
- [CSharp-Packages-Test-Process.md](CSharp-Packages-Test-Process.md) — sister doc for xUnit; tag taxonomy mirrors this one.
