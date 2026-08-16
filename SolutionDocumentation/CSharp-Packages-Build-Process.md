# CSharp Packages — Build Process

> **Task 13.62 security cutover:** Inline `--api-key` and ProGet API-key environment examples below are superseded. `PublishAfterBuild` passes only `ProGet.Admin.API.Key` as a SecretName to its PowerShell wrapper.

**Scope.** How `dotnet build` and the sanctioned Visual Studio MSBuild `Pack` target turn the ~170 `.csproj` files in the
ATAP.Utilities solution into NuGet packages. Focus is on **what happens on a
developer workstation or BuildMaster agent** — the MSBuild file hierarchy, the
custom task DLL that participates in every build, the bootstrap sequence that gets
that DLL into place, and the end-to-end data flow for one project build.

> **Strategy update (sprint-0007 — Immutable Build).** Each `.nupkg` is built
> **exactly once** (at the Experimental tier) and then **promoted unchanged**
> through Development → Integration → QA → Production via ProGet's promotion
> API. This document covers what happens during that single build.
> Higher-tier stages do **not** rebuild — they restore the existing artifact,
> run tier-appropriate tests against it, and on pass call
> `Promote-ProGetPackage`. See [Immutable-Build-Strategy.md](Immutable-Build-Strategy.md)
> for the policy and [BuildMaster-Pipeline-Topology.md](BuildMaster-Pipeline-Topology.md)
> for how this build slots into the larger pipeline catalog.

> **Deterministic production pack baseline (Task 14.105).** BuildMaster uses
> `dotnet build`, then stable Visual Studio Build Tools 2026 MSBuild `/t:Pack`.
> Required minimums are VS Build Tools/MSBuild 18.8 and NuGet Pack 7.8, plus
> `Microsoft.NetCore.Component.SDK`. The repo pins stable SDK 10.0.400; the
> runner validates the SDK-selected `NuGet.Build.Tasks.Pack.dll`, sets
> `Deterministic=true`, and binds `DeterministicTimestamp` to the Git commit
> epoch. Missing or older tooling blocks publication.

**Not in this doc:**

- **Versioning** (NBGV `version.json`, `AssemblyInfo.cs`, label promotion) — see [CSharp-Packages-Versioning.md](CSharp-Packages-Versioning.md).
- **Pack and push** (nuspec generation, ProGet feed push, meta-package) — see [CSharp-Packages-Pack-and-Push.md](CSharp-Packages-Pack-and-Push.md).
- **Test execution** (xUnit, coverlet, test-artifact collection) — see [CSharp-Packages-Test-Process.md](CSharp-Packages-Test-Process.md).
- **Central Package Management** (Directory.Packages.props migration) — see [CSharp-Central-Package-Management.md](CSharp-Central-Package-Management.md).
- **BuildMaster 5-stage CI pipeline** — see [BuildMaster-ProGet-CSharp-Package-Pipeline.md](BuildMaster-ProGet-CSharp-Package-Pipeline.md).

This doc **consolidates and supersedes** the build-process content previously
scattered across [Building.md](Building.md) and [\_Planning/Explainers/0013-BuildTooling-CSharp-MSBuild-interaction.md](../../_Planning-wt-12-sprint-0006-work-items/Explainers/0013-BuildTooling-CSharp-MSBuild-interaction.md).

---

## Sprint 0015 Stream P — Ace and ATAP.Utilities convergence ledger

This file is the primary description of the C# build process for both
ATAP.Utilities and Ace. [Immutable-Build-Strategy.md](Immutable-Build-Strategy.md)
remains authoritative for the build-once/promote-the-same-artifact policy, and
the focused versioning, testing, central-package-management, pack/push, and
BuildMaster documents remain authoritative for their narrower subjects.

### Target architecture (PROPOSED — pending operator ratification)

> **Ratification status.** Everything in this subsection and in the two
> subsections that follow it is **proposed, not ratified**. Task 15.160.c
> drafted it from the 15.160.b classification and assembled the ratification
> packet at
> `_Planning/InformationForTheFuture/Sprint0015/StreamP/Task-15.160.c/ratification-packet.md`.
> No operator ruling has been recorded. Tasks 15.161-15.166 are blocked on that
> ruling for every item below that depends on an unresolved decision.

The target architecture is one shared C# production process with small,
explicit repository overlays. Unit 15.160.b classified 41 differences into four
dispositions, and the numbered points below are restated in those terms so a
reader can tell a settled obligation from an open question:

1. **Shared invariants — 11 entries (`D01`, `D04`, `D05`, `D07`, `D09`, `D18`,
   `D20`, `D22`, `D23`, `D25`, `D27`).** C# libraries in both repositories use
   the same pinned toolchain, restore, central-package policy, versioning,
   compilation, analysis, test, deterministic pack, provenance, immutable
   publication, promotion, and health gates. Divergence on these is a defect.
   `D18` and `D09` are unambiguous defects independent of every open decision
   and may be fixed without waiting for ratification. **Proposed as
   invariants; the set itself is what the operator is being asked to ratify.**
2. **Explicit overlays — 8 entries (`D02`, `D17`, `D21`, `D24`, `D32`, `D39`,
   `D40`, `D41`).** Repository/product identity, dependency catalogs,
   target-framework and RID matrices, package metadata, solution membership,
   and application-specific deployment checks are explicit, bounded overlays.
   They are not reasons to fork the shared build mechanics. C# services and
   applications use the shared process through restore, version, compile,
   analysis, test, deterministic output, provenance, and promotion
   eligibility, diverging only where their artifact type requires it:
   `dotnet publish`, runtime/self-contained choices, service or application
   startup validation, Release Bundle assembly, installation, and deployment.
   **Caution:** Ace's application artifacts are **not** discoverable by
   `OutputType` alone — `AceCommander.Client` and `AceCommander.Server` declare
   their nature through the `Sdk` attribute
   (`Microsoft.NET.Sdk.BlazorWebAssembly`, `Microsoft.NET.Sdk.Web`), and only
   `AceOutpost.Windows` declares `OutputType=Exe`. Any criterion keyed on
   `OutputType` covers one of three.
3. **Obsolete legacy behavior — 9 entries (`D06`, `D11`, `D15`, `D26`, `D28`,
   `D29`, `D30`, `D36`, `D38`).** These exist only because something was never
   removed; disposition is deletion, not convergence. `D29` is the load-bearing
   one: **ATAP.Utilities' canonical BuildTooling source still deletes a package
   version from the feed before pushing it**
   (`src/ATAP.Utilities.BuildTooling.CSharp/ATAP.Utilities.BuildTooling.targets`
   lines 180-183), which contradicts
   [Immutable-Build-Strategy.md](Immutable-Build-Strategy.md) §5 and §9.
   Deletion must happen in the canonical source **before** that tooling is
   deployed to Ace, or rebinding Ace propagates the defect.
4. **Unresolved decisions — 13 entries.** Listed in full under _Unresolved
   decisions pending operator ratification_ below. Ten of the 19 entries on the
   six axes the board named for rationale are unresolved, so Stream P's
   dominant blocker is architecture that was never decided rather than drift to
   be repaired.

Ownership is unchanged and is not in question: ATAP.Utilities owns the
canonical BuildTooling source and shared BuildMaster runner; Ace consumes
versioned deployed tooling and supplies only its repository/application
variables and approved overlays. **This ownership statement carries no claim
that either repository is immutable-compliant today** — see `D29` above and
baseline row 9 below.

Evidence for every claim in this subsection:
`_generated/Sprint0015/StreamP/Task-15.160.a/` (inventory, evaluated
properties, inventory report) and
`_generated/Sprint0015/StreamP/Task-15.160.b/classification.json` in both
repositories, with the prose classification and the six-axis rationale under
`_Planning/InformationForTheFuture/Sprint0015/StreamP/Task-15.160.b/`.

### Acceptance matrix for the proposed shared invariants (PROPOSED)

One row per proposed mandatory shared invariant. **An acceptance criterion that
no command can decide is not an acceptance criterion** — such rows are marked
`NEEDS A DECIDING COMMAND` and must acquire one before the invariant can gate
anything. Nothing in this matrix asserts that a criterion currently passes; the
`Decided by` column names the command or artifact that _would_ decide it.

| ID    | Proposed invariant                                                  | Acceptance criterion                                                                                                                                                           | Decided by                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| ----- | ------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `D01` | One declared SDK/toolchain in both repositories.                    | Both repositories contain a root `global.json` pinning the same SDK version with the same `rollForward` and `allowPrerelease`, and a build fails when that SDK is unavailable. | `Test-Path -LiteralPath <repo>/global.json` in both, plus `dotnet --version` compared against the pinned value. Present in ATAP.Utilities; absent in Ace (15.160.a inventory `sdk-selection`).                                                                                                                                                                                                                                              |
| `D04` | Missing build tooling fails the build closed, not open.             | With the deployed BuildTooling absent, the build terminates with a named diagnostic instead of silently skipping the import.                                                   | **NEEDS A DECIDING COMMAND.** Today the import is `Condition="Exists(...)"`, so no command distinguishes "tooling present" from "tooling silently skipped". A criterion becomes decidable only once the guard is replaced by an explicit error; the test is then a build with the tooling directory absent, expecting a non-zero exit and that diagnostic code.                                                                             |
| `D05` | One canonical versioned tooling deployment, consumed identically.   | In both repositories the sentinel-selected version resolves to a directory that exists and contains both the targets file and the custom-task assembly.                        | `dotnet msbuild <project> -getProperty:ATAPUtilitiesBuildToolingTargetsPath` then `Test-Path -LiteralPath` on the result and on `Release/net10.0/ATAP.Utilities.BuildTooling.CSharp.dll`. Currently resolves to a non-existent path in ATAP.Utilities (15.160.a).                                                                                                                                                                           |
| `D07` | The committed diagnostic-verbosity default is `Release` in both.    | `ATAPBuildToolingConfiguration` evaluates to `Release` in both repositories on a clean checkout.                                                                               | `dotnet msbuild <project> -getProperty:ATAPBuildToolingConfiguration`. Evaluates `Debug` in ATAP.Utilities, `Release` in Ace (15.160.a evaluated properties).                                                                                                                                                                                                                                                                               |
| `D09` | Fody **core** version is a declared input wherever weaving runs.    | Every repository containing at least one Fody weaver reference declares a central `Fody` `PackageVersion` at or above the .NET 10 floor (6.9.3).                               | `Select-String -Path <repo>/Directory.Packages.props -Pattern 'PackageVersion Include="Fody"'` in both. Present in ATAP.Utilities (6.9.3); absent in Ace, which weaves in six projects. Independent of the `D08` model decision.                                                                                                                                                                                                            |
| `D18` | The ATAP.\* dependency-range rewrite is prerelease-gated in both.   | A **stable**-versioned packable project retains its resolved stable dependency range; only prerelease builds are rewritten to `[0.0.0-alpha-000, 2.0.0)`.                      | Pack a stable-versioned project in each repository and read the dependency range from the generated `.nuspec`. Textual precursor: compare the `Condition` on `ConstrainATAPPackageDependencyVersionRange` (ATAP.Utilities `Directory.Build.targets:161-163` vs Ace `:60-62`).                                                                                                                                                               |
| `D20` | A lifecycle-stage-to-branch publication gate exists in both.        | Building a packable project on a ref that is not stable-capable, with an empty `PackageLifeCycleStage`, fails with the gate's diagnostic.                                      | Build on such a ref expecting `ATAP5TIER001`. Gate present at ATAP.Utilities `Directory.Build.props:335-347`; no counterpart in Ace.                                                                                                                                                                                                                                                                                                        |
| `D22` | An equivalent repository-wide health gate runs in both.             | The gate script exists in both repositories and exits 0 before pack/publish.                                                                                                   | `pwsh -File <repo>/Build/Invoke-RepoHealthGate.ps1`. Present in ATAP.Utilities; **the script does not exist in Ace**, so the command cannot be run there yet. See the note below on what this gate actually asserts.                                                                                                                                                                                                                        |
| `D23` | Each repository declares an explicit production scope.              | A production `.slnf` exists in both and restores under `--locked-mode`.                                                                                                        | `Test-Path -LiteralPath <repo>/<name>.Production.slnf`, then `dotnet restore <slnf> --locked-mode`. Three `.slnf` in ATAP.Utilities; zero in Ace. Filter _membership_ remains an overlay; filter _existence_ is the invariant.                                                                                                                                                                                                              |
| `D25` | HTTPS transport with no insecure fallbacks in both.                 | No NuGet source in either repository uses `http://`, and no source carries `allowInsecureConnections`.                                                                         | `Select-String -Path <repo>/NuGet.\*onfig -Pattern 'http://                                                                                                                                                                                                                                                                                                                                                                                 | allowInsecureConnections'`expecting no matches. Ace currently has five`releasebundle-_`sources on`http://localhost:50000`and`allowInsecureConnections="true"`on five`nuget-_` sources. |
| `D27` | One canonical spelling of the central NuGet configuration filename. | Both repositories spell the file identically, so probing succeeds on a case-sensitive filesystem.                                                                              | **PARTIALLY DECIDABLE — NEEDS A DECIDING COMMAND for the failure it guards against.** `Get-ChildItem -LiteralPath <repo> -Filter 'NuGet.*onfig' \| Select-Object Name` compares the spellings (`NuGet.Config` vs `NuGet.config`), but Windows is case-insensitive, so no command _on this workstation_ reproduces the Linux restore failure the invariant exists to prevent. Deciding it requires a restore on a case-sensitive filesystem. |

Two notes that bear directly on this matrix, both carried from the 15.160.c
cross-check (`_generated/Sprint0015/StreamP/Task-15.160.c/cross-check-findings.md`):

- **The `D22` gate does not currently assert what §8.1 of this document says it
  asserts.** `tests/RepoHealth/Directory.Build.Props.Properties.Tests.ps1`
  (lines 13, 119-124) evaluates a property spelled
  `CentralPackageVersionOverridesEnabled` — plural _Overrides_ — and requires it
  to equal `false`. The NuGet property is
  `CentralPackageVersionOverrideEnabled`, singular _Override_, and 15.160.a/b
  measured that property as **unset in both repositories**. The name in
  circulation is not a NuGet property, which is the most economical explanation
  for why nobody ever set it. §8.1 of this document repeats the plural spelling.
  Correcting the gate and its test is outside unit 15.160.c's writable scope and
  is reported, not fixed.
- **Locked-mode restore is conditioned on a property that is unset in both
  repositories.** [CSharp-Central-Package-Management.md](CSharp-Central-Package-Management.md)
  line 344 makes `RestoreLockedMode` conditional on
  `ContinuousIntegrationBuild == 'true'`, and that property evaluates empty in
  both repositories (`D37`). Any acceptance criterion that assumes locked
  restore is in force must first settle `D37`.

### Verified divergence baseline (2026-08-15, re-verified by 15.160.a/b)

This table records the live Sprint 0015 worktree state that motivated
`_Planning/Tasks.Sprint0015.md` Stream P. It is evidence of current divergence,
not approval to preserve that divergence. A row may be marked aligned only by
updating this ledger with the task and evidence that proves the deployed state.

**No row is marked aligned by unit 15.160.c.** This unit edited documentation
only and changed no build behavior, so no row's deployed state changed and none
could qualify. Rows 3, 5, 7, and 9 below are **restated** where 15.160.a/b
re-verification found the original wording inaccurate or imprecise — a
restatement corrects the description of the divergence and never records its
resolution.

| Area                                                                                                       | Ace Sprint worktree                                                                                                                                                                                                                                                           | ATAP.Utilities Sprint worktree                                                                                                                                                                                                                                                 | Required disposition                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| ---------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| SDK selection                                                                                              | Uses the installed SDK; no repository `global.json`.                                                                                                                                                                                                                          | Pins SDK `10.0.400` with `latestPatch`.                                                                                                                                                                                                                                        | Pin and validate one supported SDK/toolchain policy in both repositories.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| Framework/RID defaults                                                                                     | Centrally targets `net10.0`; no shared RID matrix.                                                                                                                                                                                                                            | Centrally targets `net8.0;net9.0;net10.0` and `win-x64;linux-x64`.                                                                                                                                                                                                             | Keep only a ratified product overlay; share the mechanics that consume the matrix.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| BuildTooling deployment **(row 3 — RESTATED, sharpened; NOT aligned)**                                     | Sentinel selects `0.1.0.1`; `Build/ATAP.Utilities.BuildTooling.0.1.0.1/` contains **only** `build/ATAP.Utilities.BuildTooling.targets` — no `Release/net10.0/*.dll`.                                                                                                          | Sentinel selects `1.0.1.0`, but `Build/ATAP.Utilities.BuildTooling.1.0.1.0/` is absent entirely, so the `Exists()`-conditioned import is skipped.                                                                                                                              | **Sharpening:** the compiled custom-task assembly is absent from **both** repositories (`D04`), not just one; Ace merely has a deployed _targets_ file that ATAP.Utilities lacks (`D05`). This is survivable today only because the three `UsingTask` declarations are commented out as superseded by NBGV (`D06`), which is precisely why the fail-open defect went unnoticed. Produce one canonical, versioned deployment; make missing/mismatched tooling fail closed after an explicit bootstrap path.                                                                                                                                                                          |
| Shared MSBuild policy                                                                                      | Smaller `Directory.Build.*` surface; no global Fody core injection, no lifecycle-to-feed validation, and dependency-range rewriting applies to all packable builds.                                                                                                           | Larger legacy surface; global Fody injection and lifecycle validation; dependency-range rewriting is prerelease-only.                                                                                                                                                          | Ratify and implement one common policy surface, with deliberate feature switches rather than repository drift.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| Central package policy **(row 5 — RESTATED against `CentralPackageFloatingVersionsEnabled`; NOT aligned)** | `CentralPackageFloatingVersionsEnabled=true` (`Directory.Packages.props:8`); nine internal `ATAP.Utilities.*` packages pinned to the floating range `0.*-*` (`:15-26`), while three RRSBS packages are pinned exactly (`:29-33`) — so the floating policy is already partial. | `CentralPackageFloatingVersionsEnabled` is **unset**, and internal dependencies use explicit pinned versions.                                                                                                                                                                  | **Retraction:** the original row named `CentralPackageVersionOverrideEnabled` and claimed ATAP.Utilities "disables central version overrides". That property evaluates **empty in both repositories** and is declared in neither, so it described no divergence at all; it is excluded as `X01`. The real measured divergence is `CentralPackageFloatingVersionsEnabled` (`D16`), which is an **unresolved decision**, not a defect to converge. Define common restore/lock determinism and explicit ownership of any permitted floating development inputs. Dependency catalogs may legitimately differ (`D17`).                                                                   |
| NuGet/ProGet transport                                                                                     | NuGet feeds are partly migrated to `https://utat022:50000`, but retain stale insecure-connection comments/attributes; ReleaseBundle feeds still use HTTP localhost.                                                                                                           | Uses `https://utat022:50000` without `allowInsecureConnections`.                                                                                                                                                                                                               | Use the same HTTPS endpoints, source mapping, audit sources, and SecretName boundary; remove stale insecure fallbacks.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| Lock-file CI **(row 7 — RESTATED, narrowed to restore scope; NOT aligned)**                                | `.github/workflows/lock-file-guard.yml` restores `AceCommander.sln --locked-mode`; adds a `samples/**` exclusion to the `git diff` check.                                                                                                                                     | The same workflow, from a near-identical template, restores `ATAP.Utilities.Production.slnf --locked-mode`.                                                                                                                                                                    | **Narrowing:** the original row overstated the gap. The gate itself is already converged — same workflow name, triggers, runner labels, and `--locked-mode` + `git diff --exit-code` shape in both repositories (`D24`, classified an overlay). What actually differs is the **restore scope**, which is downstream of `D23` (Ace has no production `.slnf`): once Ace has one, the scope difference becomes a one-line overlay of the same template. The `samples/**` exclusion is a legitimate repository-content overlay. The residual invariant is `D23`, not the workflow.                                                                                                     |
| RepoHealth                                                                                                 | No equivalent repository-wide shared-property gate.                                                                                                                                                                                                                           | Runs `Build/Invoke-RepoHealthGate.ps1` before pack/publish.                                                                                                                                                                                                                    | Run equivalent evaluated-property, packaging, and drift gates in both repositories.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| Publishing implementation **(row 9 — RESTATED, sharpened; NOT aligned)**                                   | Deployed `0.1.0.1` target uses `http://localhost:50000`, reads a raw `$env:PROGET_ADMIN_API_KEY` inside an inline `Invoke-RestMethod -Method Delete`, then pushes (`D28`).                                                                                                    | Current source uses `https://utat022:50000` and a SecretName-mediated PowerShell leaf, but the selected deployed target is absent — **and the source still deletes the existing version from the feed before pushing** (`ATAP.Utilities.BuildTooling.targets:180-183`, `D29`). | **Sharpening — read this before rebinding Ace:** ATAP.Utilities' improvement over Ace's deployed copy is transport and secret handling, **not** the removal of delete-and-republish. This row must not be read as "ATAP.Utilities is already immutable-compliant"; delete-before-push contradicts [Immutable-Build-Strategy.md](Immutable-Build-Strategy.md) §5 and §9 in both repositories. Deploying current ATAP.Utilities tooling to Ace would fix `D28` while **propagating** `D29`, so the deletion must be removed from the canonical source _first_. Publish a new immutable version once, never delete/reuse a package version, and promote identical bytes through tiers. |
| BuildMaster binding                                                                                        | Documentation and variables still carry historical AceCommander repository/branch/path assumptions.                                                                                                                                                                           | Owns the common five-stage C# plan and stage runner.                                                                                                                                                                                                                           | Rebind Ace to its current identity while retaining one common plan/runner; synchronize and verify the deployed raft copy.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| Services/applications                                                                                      | Application outputs are not governed by a complete parity contract with library builds.                                                                                                                                                                                       | Library/package documentation dominates; executable samples/services have no single shared closeout matrix.                                                                                                                                                                    | Reuse the library pipeline through deterministic build/test, then add a narrow publish/ReleaseBundle/install/deploy tail.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |

### Unresolved decisions pending operator ratification

**Thirteen** decisions must be ruled on before the work they gate can proceed.
They are reproduced here so this file is self-contained; the packet the operator
rules on is
`_Planning/InformationForTheFuture/Sprint0015/StreamP/Task-15.160.c/ratification-packet.md`,
which carries the same thirteen with fuller context and, where defensible, a
recommendation.

**No ruling has been recorded on any of them.** Nothing below may be treated as
settled, and no successor task may resolve one of these by writing code that
assumes an answer. Ten of the thirteen fall on the six axes the Sprint 0015
board named as requiring rationale.

1. **`D03` — RIDs for Ace's application artifacts.** For `AceCommander.Client`
   (Blazor WASM), `AceCommander.Server` (ASP.NET Core), and `AceOutpost.Windows`
   (console `Exe`), which RIDs must each publish for, and is publication
   framework-dependent or self-contained? _Options:_ (a) adopt
   `win-x64;linux-x64` centrally in Ace; (b) declare RIDs on application
   projects only, leaving libraries RID-less; (c) ratify framework-dependent
   portable publication with no RID. _Consequence:_ blocks any publish/Release
   Bundle work in the 15.161-15.166 sequence, and is a hard prerequisite for
   `D33`.
2. **`D08` — the canonical Fody injection model.** _Options:_ (a) global
   injection plus a documented per-project opt-out able to express
   `AceCommander.Server`'s async-weaving exclusion; (b) per-project opt-in in
   both repositories, converting ATAP.Utilities' global injection into explicit
   references; (c) global injection in ATAP.Utilities only, ratified as a
   library-repository overlay with Ace permanently opt-in. _Consequence:_
   gates any shared-MSBuild-policy convergence task. Naive convergence is
   **unsafe** — p`documents a deliberate
exclusion.`D09` (pin the Fody core version) holds under every option and
   need not wait.
3. **`D10` — the shared Roslyn analyzer policy.** Is `EnableNETAnalyzers` on, at
   what `AnalysisLevel` and `AnalysisMode`, is `EnforceCodeStyleInBuild` on, and
   do violations fail the build or warn? _This is a shared gap, not a
   divergence:_ neither repository sets any of the four. _Consequence:_ gates
   the analysis stage of the shared process; should be decided together with
   `D13`, since analyzers without `TreatWarningsAsErrors` produce diagnostics
   nobody is obliged to act on.
4. **`D12` — `SYSLIB0011` as an error.** Is Ace's escalation a shared policy to
   adopt in ATAP.Utilities, or an Ace-specific overlay to document and bound?
   If shared, does ATAP.Utilities compile clean under it today? _Consequence:_
   small, but it changes the warning-policy convergence target.
5. **`D13` — `TreatWarningsAsErrors`.** Should it be `true` in both
   repositories, and at which tier does it become blocking — developer inner
   loop, CI, or promotion gate only? _Shared gap: unset in both._
   _Consequence:_ sets the floor for the analysis stage; remediation cost is
   unmeasured, so a measurement task should probably precede the ruling.
6. **`D14` — the nullable `NoWarn` suppression.** Does ATAP.Utilities remove it
   to match Ace (which has already commented the identical block out), keep it
   as a bounded and dated exception, or does Ace re-adopt it? _Consequence:_
   removal exposes an unmeasured nullability warning surface across 210
   projects; measure before ruling.
7. **`D16` — floating internal `0.*-*` dependencies in Ace.** _Options:_ (a) pin
   explicitly and converge; (b) permit floating in sprint/experimental branches
   only, enforced by a gate that fails a `main`/`release` build containing any
   floating range — which is what Ace's own comment promises and nothing
   enforces; (c) ratify floating permanently and accept the lock file as the
   sole record of build inputs. Under (b), who owns the pin-before-merge step?
   _Consequence:_ this is the restated row 5 and it gates the
   restore/lock-determinism task. Note the tension with
   [Immutable-Build-Strategy.md](Immutable-Build-Strategy.md) §6.3, which
   already describes floating `0.*-*` resolution as intentional for consumers —
   see the cross-check findings before ruling.
8. **`D19` — packability default.** Is packability opt-in (central
   `IsPackable=false`, publishable projects opting in) or opt-out (SDK default,
   non-publishable projects opting out)? If opt-in, does the `D22` health gate
   enforce that every packable project is a deliberate declaration?
   _Consequence:_ the opt-out direction has a silent failure mode — a new
   ATAP.Utilities project is publishable unless someone remembers to opt out,
   and 72 projects have already needed that opt-out.
9. **`D31` — the deployed BuildMaster raft.** Who performs the live comparison
   against the canonical five-stage plan and stage runner, under what approval,
   and does the result become a recurring gate or a one-time reconciliation?
   _Consequence:_ undecidable by any file-reading unit; it needs a live
   BuildMaster action, which is a gated operation no Stream P worker may take.
10. **`D33` — how Ace's application publish inputs are declared.** _Options:_
    (a) `.pubxml` profiles committed per application project, matching
    ATAP.Utilities' 15; (b) BuildMaster stage parameters with no in-repository
    profile; (c) a Release Bundle definition superseding both. _Consequence:_
    Ace has **zero** publish profiles beside three deployable applications;
    `D03` must be answered first, since a publish profile without a RID
    decision is not authorable.
11. **`D34` — the application/service parity contract.** Which library-pipeline
    stages (restore, version, compile, analysis, test, deterministic output,
    provenance, promotion eligibility) are mandatory for application projects,
    and what is the narrow additional tail (publish, Release Bundle, install,
    deploy) that applies only to them? _Consequence:_ this is baseline row 11.
    Writing the contract **is** the decision — no file check can measure
    conformance to a contract that does not yet exist.
12. **`D35` — version-file granularity.** Is per-package independent versioning
    (ATAP.Utilities' 181 project-adjacent `version.json`, no root file)
    ratified as a library-repository overlay, or does ATAP.Utilities also need a
    repository-level `version.json`? If ratified as-is, what identifies an
    ATAP.Utilities repository-level release? _Consequence:_ without a
    repository-level version there is no single version for tier promotion and
    Release Bundle identity to anchor to.
13. **`D37` — where `ContinuousIntegrationBuild=true` is set.** Unconditionally
    in `Directory.Build.props`, or only when a CI environment variable is
    present? _Consequence:_ the property is unset in **both** repositories
    today, so deterministic path normalization and SourceLink are not fully in
    effect, and the locked-restore condition in
    [CSharp-Central-Package-Management.md](CSharp-Central-Package-Management.md)
    line 344 never fires. Note that
    [Immutable-Build-Strategy.md](Immutable-Build-Strategy.md) §6.4 already
    **mandates** `ContinuousIntegrationBuild=true` for the Experimental build,
    so the _whether_ may already be settled policy and only the _where_ is
    genuinely open — the operator should confirm which reading governs.

### Stream P documentation rule

Tasks 15.160 through 15.166 must update this section as their work finishes.
Each completed task must replace its affected divergence statement with the
implemented contract and link the command or `_generated/Sprint0015/` artifact
that proves it. Task 15.166 performs the final consistency pass across this file,
the focused companion documents, both repositories' nearest indexes/readmes, and
the synchronized Sprint 0015 planning board. Until that closeout is complete,
older examples elsewhere in this document—especially legacy custom version-task,
HTTP feed, bootstrap-copy, or build-per-tier examples—must be treated as historical
material when they conflict with this ledger or Immutable Build Strategy.

---

## 1. The Four Files That Cooperate

Every project build in this solution is driven by four files working together.

| File                                     | Role                                                                                                                 | Location                                                                              |
| ---------------------------------------- | -------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| `Directory.Build.props`                  | Solution-wide property defaults; injected **before** each `.csproj` is processed.                                    | Solution root                                                                         |
| `Directory.Build.targets`                | Solution-wide targets and item-group imports; injected **after** each `.csproj` is processed.                        | Solution root                                                                         |
| `ATAP.Utilities.BuildTooling.CSharp.dll` | Compiled MSBuild custom-task assembly containing `GetVersion` / `UpdateVersion` / `SetVersion`.                      | `Build/ATAP.Utilities.BuildTooling.<ver>/build/Release/net10.0/`                      |
| `ATAP.Utilities.BuildTooling.targets`    | The "wiring harness" that registers the three tasks via `UsingTask` and plugs them into the standard build pipeline. | Alongside the DLL, plus canonical source in `src/ATAP.Utilities.BuildTooling.CSharp/` |

MSBuild walks **up** the directory tree from each `.csproj`, searching for
`Directory.Build.props` and `Directory.Build.targets`. It stops at the first file
found. Because both files live at the solution root, every project in `src/` and
`tests/` inherits them automatically — no explicit `<Import>` is needed in any
individual `.csproj`.

Test projects follow the unified post-sprint-0007 `.Tests` naming convention in
both folder and project-file names, for example
`tests/ATAP.Utilities.Philote.Tests/ATAP.Utilities.Philote.Tests.csproj`.
Unit, integration, and performance distinctions now live in source-file suffixes
and xUnit traits rather than tier-specific project-name suffixes. Test projects
still participate in normal build property inheritance, but they set
`IsPackable=false` and `GeneratePackageOnBuild=false` so they do not produce
NuGet packages.

**Load order for one project build:**

```text
1. Directory.Build.props          ← injected BEFORE .csproj processing
2. <ProjectName>.csproj           ← the individual project file
3. Directory.Build.targets        ← injected AFTER .csproj processing
4. ATAP.Utilities.BuildTooling.targets  ← imported by Directory.Build.targets (conditional)
```

---

## 2. Directory.Build.props — Solution-Wide Property Defaults

### 2.1 Disable auto-generated AssemblyInfo

```xml
<GenerateAssemblyInfo>false</GenerateAssemblyInfo>
```

The SDK normally generates `AssemblyInfo.cs` automatically. Disabling this lets each
project own its `Properties/AssemblyInfo.cs` file, which is the source of truth for
the legacy versioning flow. (NBGV migration in progress — see §9.)

### 2.2 Solution-wide defaults for every project

```xml
<TargetFramework>net10.0</TargetFramework>
<RuntimeIdentifiers>win-x64;linux-x64</RuntimeIdentifiers>
<LangVersion>latest</LangVersion>
<Nullable>enable</Nullable>
<Configurations>Debug;Release;ReleaseWithTrace</Configurations>
```

Individual `.csproj` files override any of these when needed. Projects that
multi-target use the **empty-override escape hatch**:

```xml
<TargetFramework></TargetFramework>
<TargetFrameworks>net8.0;net9.0;net10.0</TargetFrameworks>
```

Without clearing the singular form first, MSBuild sees both and ignores the
plural-form list.

### 2.3 Solution root and build-tools directory

```xml
<SolutionDir>$(MSBuildThisFileDirectory)</SolutionDir>
<SolutionBuildToolsBaseDir>$(SolutionDir)Build\</SolutionBuildToolsBaseDir>
```

`$(MSBuildThisFileDirectory)` resolves to the directory containing
`Directory.Build.props` regardless of how deeply nested the project is. This makes
paths correct for both `dotnet build` and Visual Studio builds.

> **Do not replace with a hardcoded absolute path.** The `$(MSBuildThisFileDirectory)`
> form is the reason the same props file works across workTrees and machines.

### 2.4 Locate the pre-built custom-task assembly (sentinel-file pattern)

The version of the deployed BuildTooling DLL is read **at property-evaluation time**
from a sentinel file:

```xml
<ATAPBuildToolingVersion
    Condition="Exists('$(SolutionBuildToolsBaseDir)ATAP.Utilities.BuildTooling.current-version')"
    >$([System.IO.File]::ReadAllText('$(SolutionBuildToolsBaseDir)ATAP.Utilities.BuildTooling.current-version').Trim())</ATAPBuildToolingVersion>
<ATAPBuildToolingVersion Condition="'$(ATAPBuildToolingVersion)' == ''">0.1.0.1</ATAPBuildToolingVersion>
<ATAPBuildToolingRelativeBasePath>ATAP.Utilities.BuildTooling.$(ATAPBuildToolingVersion)\build\</ATAPBuildToolingRelativeBasePath>
<ATAPUtilitiesBuildToolingTasksPath>$(SolutionBuildToolsBaseDir)$(ATAPBuildToolingRelativeBasePath)</ATAPUtilitiesBuildToolingTasksPath>
<ATAPUtilitiesBuildToolingTasksAssembly Condition=" '$(MSBuildRuntimeType)' == 'Core'"
    >$(ATAPUtilitiesBuildToolingTasksPath)Release\net10.0\ATAP.Utilities.BuildTooling.CSharp.dll</ATAPUtilitiesBuildToolingTasksAssembly>
<ATAPUtilitiesBuildToolingTasksAssembly Condition=" '$(MSBuildRuntimeType)' != 'Core'"
    >$(ATAPUtilitiesBuildToolingTasksPath)Release\net471\ATAP.Utilities.BuildTooling.CSharp.dll</ATAPUtilitiesBuildToolingTasksAssembly>
```

**How it works:**

1. `$([System.IO.File]::ReadAllText(...).Trim())` is an MSBuild property function that
   executes before any target runs. It reads the sentinel-file contents (e.g. `0.1.0`)
   and trims trailing newlines.
2. The `Condition="Exists(...)"` guard makes it a no-op if the sentinel file does not
   yet exist (first-ever bootstrap).
3. The second `<ATAPBuildToolingVersion>` line provides a hardcoded fallback for the
   very first bootstrap before any sentinel file has been written.
4. The `MSBuildRuntimeType` switch picks `net10.0` when building via `dotnet` and
   `net471` when building via Visual Studio's full-framework MSBuild.

Result for version `0.1.0` via `dotnet build`:

```text
Build\ATAP.Utilities.BuildTooling.0.1.0\build\Release\net10.0\ATAP.Utilities.BuildTooling.CSharp.dll
```

The sentinel file is written automatically by `DeployBuildToolingToBuildDirectory`
each time `ATAP.Utilities.BuildTooling.CSharp` is built in Release — see §6.3.

### 2.5 Task verbosity

```xml
<ATAPBuildToolingConfiguration>Debug</ATAPBuildToolingConfiguration>
<ATAPBuildToolingDebugVerbosity>Trace</ATAPBuildToolingDebugVerbosity>
```

When `ATAPBuildToolingConfiguration == Debug`, the `.targets` file and the C# tasks
emit detailed log messages (target `PrintBuildVariables` dumps the full property
set). Set to `Release` for silent production builds.

### 2.6 NuGet package metadata applied to every project

Author, copyright, license expression, repository URL, and source-link settings are
set here so individual projects do not repeat them:

```xml
<Authors>William Hertzing</Authors>
<Copyright>William Hertzing</Copyright>
<Product>ATAP.Utilities</Product>
<RepositoryUrl>https://github.com/BillHertzing/ATAP.Utilities</RepositoryUrl>
<RepositoryType>GitHub</RepositoryType>
<PackageLicenseExpression>MIT</PackageLicenseExpression>
<AllowedOutputExtensionsInPackageBuildOutputFolder>$(AllowedOutputExtensionsInPackageBuildOutputFolder);.pdb</AllowedOutputExtensionsInPackageBuildOutputFolder>
<EmbedUntrackedSources>true</EmbedUntrackedSources>
```

The last two lines enable SourceLink: PDB files are included in the NuGet package
and generated source files are embedded so a debugger can fetch the exact source
that produced a binary.

### 2.7 Version-file and lock-file paths

```xml
<VersionFile Condition=" '$(VersionFile)' == '' ">$(MSBuildProjectDirectory)\properties\AssemblyInfo.cs</VersionFile>
<UpdatePackageVersionLockFilePath Condition=" '$(UpdatePackageVersionLockFilePath)' == '' "
    >$(MSBuildProjectDirectory)\$(MSBuildProjectName).UpdatePackageVersion.lock</UpdatePackageVersionLockFilePath>
```

`$(VersionFile)` is where `GetVersion`, `UpdateVersion`, and `SetVersion` read and
write version data. `$(UpdatePackageVersionLockFilePath)` is the per-project lock
file that prevents the multi-TFM outer build from running the version update more
than once per build — see §7.2.

### 2.8 Configuration-conditional compilation symbols

```xml
<PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Release|AnyCPU'">
    <DefineConstants>$(DefineConstants);RELEASE;</DefineConstants>
</PropertyGroup>
<PropertyGroup Condition="'$(Configuration)|$(Platform)'=='ReleaseWithTrace|AnyCPU'">
    <DefineConstants>$(DefineConstants);RELEASE;TRACE;</DefineConstants>
</PropertyGroup>
<PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Debug|AnyCPU'">
    <DefineConstants>$(DefineConstants);DEBUG;TRACE;</DefineConstants>
</PropertyGroup>
```

Framework-conditional symbols (`NETCORE`, `NETSTANDARD`, `NETDESKTOP`, `NET47`, etc.)
are also set here so source code can guard platform-specific code paths with
`#if NETCORE` / `#else`.

### 2.9 Suppress legacy analyzers and binding-redirect generation

```xml
<RunCodeAnalysis>false</RunCodeAnalysis>
<AutoGenerateBindingRedirects Condition=" '$(AutoGenerateBindingRedirects)' == '' ">false</AutoGenerateBindingRedirects>
```

The legacy FxCop post-build analyzers are disabled in favor of the
Roslyn-based `Microsoft.CodeAnalysis.NetAnalyzers` NuGet package.

### 2.10 Nullable-warning suppression

```xml
<NoWarn>$(NoWarn);8600;8601;8602;8603;8604;8605;8618;8625;8629</NoWarn>
```

These suppress nullable-reference-type warnings that cannot currently be fixed
without sweeping changes to default-argument handling. This list is a tracking item
for future cleanup, not a permanent design choice.

### 2.11 NBGV injection (in-progress migration)

```xml
<ItemGroup>
    <PackageReference Include="Nerdbank.GitVersioning" PrivateAssets="all" />
</ItemGroup>
```

Every project receives the `Nerdbank.GitVersioning` package via this solution-wide
item group so the build uses `version.json` instead of the SDK default `1.0.0`.
The NBGV-injected version and the legacy `AssemblyInfo.cs` / `GetVersion` /
`UpdateVersion` flow currently coexist — see §9 and [CSharp-Packages-Versioning.md](CSharp-Packages-Versioning.md).

### 2.12 Build-parallelism cap for readable logs

```xml
<maxcpucount>1</maxcpucount>
```

Set to 1 so the build log is linear and readable during development. BuildMaster
agents may override this for throughput.

---

## 3. Directory.Build.targets — Solution-Wide Targets

This file is injected **after** each `.csproj` is loaded, so it can act on
properties the `.csproj` has already set and can extend (rather than replace) the
standard build pipeline.

### 3.1 Import the custom BuildTooling targets

```xml
<Import Project="$(ATAPUtilitiesBuildToolingTargetsPath)\ATAP.Utilities.BuildTooling.targets"
        Condition="Exists('$(ATAPUtilitiesBuildToolingTargetsPath)\ATAP.Utilities.BuildTooling.targets')" />
```

The `Condition="Exists(...)"` guard is critical. If the file does not yet exist
(before bootstrap), the import is silently skipped and other projects can still
compile — they just don't get automatic version updates.

### 3.2 Copy JSON settings files to the output directory

```xml
<PropertyGroup>
    <PrepareForRunDependsOn>$(PrepareForRunDependsOn);CopyJSONSettingsFilesToOutputDirectory</PrepareForRunDependsOn>
</PropertyGroup>
<ItemGroup>
    <JsonSettingsFiles Include="*.json"
        Condition="$([System.Text.RegularExpressions.Regex]::IsMatch(%(Filename), '[Ss]ettings.*json$'))" />
</ItemGroup>
<Target Name="CopyJSONSettingsFilesToOutputDirectory">
    <Copy SourceFiles="@(JsonSettingsFiles)" DestinationFolder="$(OutDir)" />
</Target>
```

Any file matching `*[Ss]ettings*.json` in a project directory is copied to the
build output. The target hooks `PrepareForRunDependsOn` so it runs before the
project would execute.

### 3.3 Multi-RID and multi-framework `PublishAll` targets

Three chained targets (`PublishAll`, `PublishProjectForAllRIDsIfTargetFrameworkSet`,
`PublishProjectForAllFrameworksIfFrameworkUnset`) let `dotnet msbuild -t:PublishAll`
publish a project for every combination of TFM and runtime identifier declared in
the project:

```xml
<Target Name="PublishProjectForAllRIDsIfTargetFrameworkSet"
    Condition=" '$(TargetFramework)' != '' and '$(RuntimeIdentifiers)' != '' and '$(RuntimeIdentifier)' == ''  ">
    <ItemGroup><_PublishRuntimeIdentifier Include="$(RuntimeIdentifiers)" /></ItemGroup>
    <MSBuild Projects="$(MSBuildProjectFile)" Targets="PublishAll"
        Properties="TargetFramework=$(TargetFramework);RuntimeIdentifier=%(_PublishRuntimeIdentifier.Identity)" />
</Target>
```

### 3.4 SourceLink for every project

```xml
<ItemGroup>
    <PackageReference Include="Microsoft.SourceLink.GitHub">
        <PrivateAssets>all</PrivateAssets>
        <IncludeAssets>runtime; build; native; contentfiles; analyzers</IncludeAssets>
    </PackageReference>
</ItemGroup>
```

Combined with `§2.6` (`.pdb` in package, `EmbedUntrackedSources=true`), this makes
every shipped NuGet package debuggable from source on GitHub.

### 3.5 Constrain ATAP.\* ProjectReference dependency version ranges

```xml
<Target Name="ConstrainATAPPackageDependencyVersionRange"
        AfterTargets="_GetProjectReferenceVersions"
        Condition="'$(IsPackable)' == 'true'">
    <ItemGroup>
        <_ProjectReferencesWithVersions
            Update="@(_ProjectReferencesWithVersions)"
            Condition="$([System.String]::Copy('%(Filename)').StartsWith('ATAP.'))"
            ProjectVersion="[0.0.0-alpha-000, 2.0.0)" />
    </ItemGroup>
</Target>
```

Without this, `dotnet pack` writes inter-project dependencies as `>= resolved-version`,
which pins each dependency too tightly. This target rewrites every ATAP.\*
ProjectReference dependency to the open range `[0.0.0-alpha-000, 2.0.0)` immediately
before `GenerateNuspec` consumes the item group. See
[CSharp-Packages-Pack-and-Push.md](CSharp-Packages-Pack-and-Push.md) for the pack
flow this target affects.

### 3.6 Compute `$(Version)` at property-evaluation time

```xml
<PropertyGroup Condition="'$(MajorVersion)' != ''">
    <Version Condition="'$(PackageLabel)' != '' and '$(BuildRevision)' != ''"
        >$(MajorVersion).$(MinorVersion).$(PatchVersion)-$(PackageLabel)-$(BuildRevision)</Version>
    <Version Condition="'$(PackageLabel)' != '' and '$(BuildRevision)' == ''"
        >$(MajorVersion).$(MinorVersion).$(PatchVersion)-$(PackageLabel)</Version>
    <Version Condition="'$(PackageLabel)' == ''"
        >$(MajorVersion).$(MinorVersion).$(PatchVersion)</Version>
</PropertyGroup>
```

> **Why this must live in `.targets`, not `.props`.** The per-project properties
> `MajorVersion`, `MinorVersion`, `PatchVersion`, `PackageLabel` are set in the
> individual `.csproj`, which MSBuild loads **between** `.props` and `.targets`.
> Placing the `Version` computation in `.props` would evaluate it before those
> properties are set, producing an empty version string. The custom `UpdateVersion`
> task runs at build time — too late for pack dependency resolution — so this
> property-evaluation-time computation is needed to drive the nuspec dependency
> ranges correctly.

---

## 4. ATAP.Utilities.BuildTooling.CSharp — The Custom-Task Project

**Directory:** `src/ATAP.Utilities.BuildTooling.CSharp/`

A standard C# class library that produces a DLL loadable by MSBuild as a custom
task assembly. It is also a NuGet package (`GeneratePackageOnBuild=true`).

### 4.1 Project-file key decisions

```xml
<!-- Clear the Directory.Build.props default so multi-targeting takes effect -->
<TargetFramework></TargetFramework>
<TargetFrameworks>net8.0;net9.0;net10.0</TargetFrameworks>

<GeneratePackageOnBuild>true</GeneratePackageOnBuild>
<IsPackable>true</IsPackable>
```

Multi-targeting `net8/net9/net10` maximizes compatibility: the task DLL is loaded
by MSBuild itself, and different developer machines and BuildMaster agents may run
different SDK versions.

### 4.2 MSBuild task SDK references

```xml
<PackageReference Include="Microsoft.Build.Framework" />
<PackageReference Include="Microsoft.Build.Utilities.Core" />
```

These provide the `Task` base class, `TaskLoggingHelper`, and the
`[Required]` / `[Output]` attributes that define the contract between MSBuild and
the task implementation.

### 4.3 The targets file ships with the DLL

```xml
<None Update="ATAP.Utilities.BuildTooling.targets">
    <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
</None>
```

`ATAP.Utilities.BuildTooling.targets` lives in the project directory and is copied
verbatim to `bin/Release/net*/`. When the NuGet package is created, both the DLL
and the targets file are embedded in the package's `build/` folder per NuGet
convention.

### 4.4 Source code — `ATAP.Utilities.BuildTooling.CSharp.cs`

The file defines one static helper class and three MSBuild task classes.

**`Utilities` (static).** All executable logic lives here. Task classes are thin
wrappers that call into `Utilities`, because MSBuild does not allow a
`Task`-derived class to call another `Task`-derived class's `Execute()` method at
runtime.

| Method                   | Purpose                                                                                                       |
| ------------------------ | ------------------------------------------------------------------------------------------------------------- |
| `GetVersion`             | Reads `Properties/AssemblyInfo.cs` with regex; extracts Major, Minor, Patch, Build, Revision, PackageVersion. |
| `MakeBuild`              | Computes Build (days since 2000-01-01) and Revision (seconds-since-midnight ÷ 2) from current UTC time.       |
| `MakePackageVersion`     | Assembles the NuGet version string (e.g. `0.1.0-Alpha-005`), incrementing the label counter.                  |
| `SetVersion`             | Rewrites `Properties/AssemblyInfo.cs` in place with new version values.                                       |
| `TryParsePackageVersion` | Parses an existing NuGet version string to determine the current label/counter.                               |

**`GetVersion` task.** Reads current version data from `$(VersionFile)` and exposes
it as MSBuild output properties: `MajorVersion`, `MinorVersion`, `PatchVersion`,
`PackageVersion`, `Build`, `Revision`.

**`UpdateVersion` task.** The primary workhorse. Reads the current version,
generates new Build and Revision from current UTC time, increments the label
counter (or resets it if Major/Minor/Patch/Label changed), writes the updated
version back to `$(VersionFile)`. Output: `Build`, `Revision`, `PackageVersion`.

**`SetVersion` task.** Writes a fully specified version to `$(VersionFile)`. Used
when all version parts are already known (e.g. from a CI variable).

### 4.5 Version encoding in `Properties/AssemblyInfo.cs`

```csharp
[assembly: AssemblyVersion("0.1.0")]
[assembly: AssemblyFileVersion("0.1.9576.8317")]
[assembly: AssemblyInformationalVersion("0.1.0-Alpha-005")]
```

| Attribute                      | Encoded data                 | Example           |
| ------------------------------ | ---------------------------- | ----------------- |
| `AssemblyVersion`              | `Major.Minor.Patch`          | `0.1.0`           |
| `AssemblyFileVersion`          | `Major.Minor.Build.Revision` | `0.1.9576.8317`   |
| `AssemblyInformationalVersion` | NuGet PackageVersion string  | `0.1.0-Alpha-005` |

Build `9576` means 9576 days since 2000-01-01. Revision `8317` means 16 634 seconds
past midnight UTC (8317 × 2).

Full NBGV-vs-AssemblyInfo.cs detail is in [CSharp-Packages-Versioning.md](CSharp-Packages-Versioning.md).

---

## 5. ATAP.Utilities.BuildTooling.targets — The Wiring Harness

This file is the "wiring harness" that plugs the task DLL into the standard MSBuild
pipeline. It lives in two places:

- **Canonical source:** `src/ATAP.Utilities.BuildTooling.CSharp/ATAP.Utilities.BuildTooling.targets`
- **Deployed copy** (consumed at build time): `Build/ATAP.Utilities.BuildTooling.<ver>/build/ATAP.Utilities.BuildTooling.targets`

### 5.1 `UsingTask` declarations

```xml
<UsingTask TaskName="ATAP.Utilities.BuildTooling.GetVersion"
    AssemblyFile="$(ATAPUtilitiesBuildToolingTasksAssembly)"
    Condition="'$(ATAPUtilitiesBuildToolingTasksAssembly)' != ''" />
<UsingTask TaskName="ATAP.Utilities.BuildTooling.UpdateVersion"
    AssemblyFile="$(ATAPUtilitiesBuildToolingTasksAssembly)"
    Condition="'$(ATAPUtilitiesBuildToolingTasksAssembly)' != ''" />
<UsingTask TaskName="ATAP.Utilities.BuildTooling.SetVersion"
    AssemblyFile="$(ATAPUtilitiesBuildToolingTasksAssembly)"
    Condition="'$(ATAPUtilitiesBuildToolingTasksAssembly)' != ''" />
```

`$(ATAPUtilitiesBuildToolingTasksAssembly)` is computed in `Directory.Build.props`
(§2.4). The `UsingTask` tells MSBuild to load the named type from that DLL when the
task is first used.

The `Condition="'$(ATAPUtilitiesBuildToolingTasksAssembly)' != ''"` guard serves
two purposes:

1. **Bootstrap safety.** When the sentinel file points to a version directory that
   does not yet exist, the computed path evaluates to an empty string and the
   condition prevents `MSB4022` ("The result of evaluating the value … of the
   AssemblyFile attribute in element UsingTask is invalid") — a false positive
   that would otherwise appear in the IDE's error list.
2. **IDE static analysis.** Visual Studio evaluates `UsingTask` elements without
   an MSBuild evaluation context; the condition suppresses the IDE warning.

### 5.2 `BeforeCompile` — the version-update gate

```xml
<Target Name="BeforeCompile" Inputs="..." Outputs="...">
    <!-- Guards: skip if DesignTimeBuild==true OR lock file exists -->
    <!-- TEMPORARILY DISABLED: <CallTarget Targets="UpdatePackageVersionBeforeOuterBuild" ... /> -->
</Target>
```

`BeforeCompile` is a standard MSBuild extension point that runs just before the C#
compiler is invoked. The inputs/outputs list makes it incremental — MSBuild skips
the target entirely if no source file is newer than any output. The `CallTarget`
to `UpdatePackageVersionBeforeOuterBuild` is currently **commented out** pending
refactoring. When re-enabled it will trigger automatic version bumps on every
real (non-design-time) build.

### 5.3 `UpdatePackageVersionBeforeOuterBuild` — the version-update workhorse

```xml
<Target Name="UpdatePackageVersionBeforeOuterBuild">
    <Touch Files="$(UpdatePackageVersionLockFilePath)" AlwaysCreate="true"/>
    <GetVersion VersionFile="$(VersionFile)"
        Condition="'$(ATAPBuildToolingConfiguration)'=='Debug'" />
    <ATAP.Utilities.BuildTooling.UpdateVersion
        VersionFile="$(VersionFile)"
        MajorVersion="$(MajorVersion)"
        MinorVersion="$(MinorVersion)"
        PatchVersion="$(PatchVersion)"
        PackageLifeCycleStage="$(PackageLifeCycleStage)"
        PackageLabel="$(PackageLabel)" …>
        <Output TaskParameter="Build"          PropertyName="Build" />
        <Output TaskParameter="PackageVersion" PropertyName="PackageVersion" />
        <Output TaskParameter="Revision"       PropertyName="Revision" />
    </ATAP.Utilities.BuildTooling.UpdateVersion>
</Target>
```

**Why the lock file?** When a project targets multiple frameworks
(`<TargetFrameworks>`), MSBuild performs an _outer build_ that dispatches to one
_inner build_ per framework. Without the lock file, `UpdateVersion` would run once
per framework, incrementing the label counter multiple times in a single build.
The lock file is created before the first inner build and deleted after the last,
so the version increments exactly once.

### 5.4 `UpdatePackageVersionAfterOuterBuild` — lock-file cleanup

```xml
<Target Name="UpdatePackageVersionAfterOuterBuild" AfterTargets="DispatchToInnerBuilds;AfterBuild">
    <Delete Files="$(UpdatePackageVersionLockFilePath)"/>
</Target>
```

Runs after all framework builds complete; removes the lock file so the next build
starts clean.

### 5.5 `SetPackageVersionForPack` — bridge to the outer build scope

```xml
<Target Name="SetPackageVersionForPack" BeforeTargets="GenerateNuspec">
    <GetVersion VersionFile="$(VersionFile)">
        <Output TaskParameter="PackageVersion" PropertyName="PackageVersion" />
    </GetVersion>
</Target>
```

For multi-TFM projects, `UpdateVersion` runs inside an inner build and the updated
`PackageVersion` property is not visible in the outer build where `GenerateNuspec`
runs. This target re-reads the already-updated `AssemblyInfo.cs` file immediately
before `GenerateNuspec`, making the correct version available to the NuGet
packaging step.

### 5.6 `PublishAfterBuild` — automatic ProGet push

```xml
<Target Name="PublishAfterBuild" AfterTargets="GenerateNuspec">
    <Exec Command="pwsh -File &quot;$(MSBuildThisFileDirectory)Invoke-ProGetNuGetPublish.ps1&quot;
                   -NupkgPath &quot;...$(PackageId).$(PackageVersion).nupkg&quot;
                   -Source &quot;$(ProGetExperimentalFeedUrl)&quot;
                   -ProGetApiKeySecretName &quot;ProGet.Admin.API.Key&quot;" />
</Target>
```

Pushes the freshly-packed `.nupkg` to the ProGet `nuget-experimental` feed.
The wrapper resolves `ProGet.Admin.API.Key` with `Get-SecretATAP` only at the
authenticated leaf. Full pack-and-push mechanics — meta-package, feed promotion,
cache clearing — are in [CSharp-Packages-Pack-and-Push.md](CSharp-Packages-Pack-and-Push.md).

### 5.7 `PrintBuildVariables` — debug tracing

Runs `BeforeTargets="PublishAfterBuild"`. Dumps all relevant build properties to
the build log when `ATAPBuildToolingConfiguration == Debug`. Set
`BeforeTargets="Never"` to disable.

---

## 6. Bootstrap Sequence — The Chicken-and-Egg Problem

The custom-tasks DLL must exist **before** any project that uses the tasks can be
built. But the DLL is produced by building the `ATAP.Utilities.BuildTooling.CSharp`
project — which is itself a project in the solution.

The design resolves this in three steps.

### 6.1 Step 1 — Build the BuildTooling project in isolation

```powershell
dotnet build src\ATAP.Utilities.BuildTooling.CSharp\ATAP.Utilities.BuildTooling.CSharp.csproj `
    --configuration Release
```

This works because:

- `Directory.Build.targets` imports `ATAP.Utilities.BuildTooling.targets` with a
  `Condition="Exists(...)"` guard. If the DLL does not yet exist, the import is
  silently skipped.
- The `CallTarget` to `UpdatePackageVersionBeforeOuterBuild` is currently
  commented out, so no task invocation is attempted.
- The project's own version update is thus skipped on the bootstrap build;
  `AssemblyInfo.cs` must have valid values already.

Output files produced:

```text
src\ATAP.Utilities.BuildTooling.CSharp\bin\Release\net10.0\ATAP.Utilities.BuildTooling.CSharp.dll
src\ATAP.Utilities.BuildTooling.CSharp\bin\Release\net10.0\ATAP.Utilities.BuildTooling.targets
```

### 6.2 Step 2 — Deploy runs automatically

```xml
<Target Name="DeployBuildToolingToBuildDirectory"
        AfterTargets="Build"
        Condition="'$(MSBuildProjectName)' == 'ATAP.Utilities.BuildTooling.CSharp'
                   AND '$(Configuration)' == 'Release'
                   AND '$(TargetFramework)' == 'net10.0'">
    <!-- … -->
</Target>
```

This target runs **only** for the BuildTooling project itself, Release
configuration, and only for the `net10.0` inner build (not net8/net9) to avoid
redundant copies across multi-TFM builds. It:

1. Computes `_NewBuildToolingVersion` as `$(MajorVersion).$(MinorVersion).$(PatchVersion)`
   from the project's own version properties.
2. Creates `$(SolutionBuildToolsBaseDir)ATAP.Utilities.BuildTooling.<ver>\build\Release\net10.0\`.
3. Copies `ATAP.Utilities.BuildTooling.CSharp.dll` and `.pdb` into that TFM
   subdirectory.
4. Copies the source `ATAP.Utilities.BuildTooling.targets` file into the `build\`
   directory (always overwrites, so target edits take effect on the next project
   build).
5. Writes `$(SolutionBuildToolsBaseDir)ATAP.Utilities.BuildTooling.current-version`
   with the version string, so `Directory.Build.props` picks up the new path on
   the next evaluation.

**Effect.** After a Release build of `ATAP.Utilities.BuildTooling.CSharp`, the
next build of any project in the solution automatically loads the updated DLL and
targets file — no manual copy step required.

### 6.3 First-ever bootstrap exception

On the very first bootstrap, the targets file containing
`DeployBuildToolingToBuildDirectory` has never been deployed yet, so MSBuild can't
load it. The one-time fix is to manually copy the updated source `.targets` into
the currently deployed location before running Step 1:

```powershell
Copy-Item `
    src\ATAP.Utilities.BuildTooling.CSharp\ATAP.Utilities.BuildTooling.targets `
    Build\ATAP.Utilities.BuildTooling.0.1.0\build\ `
    -Force
```

After this one-time copy, Step 1 loads the updated targets file, runs
`DeployBuildToolingToBuildDirectory`, creates the new versioned directory, and
writes the sentinel file. All subsequent builds are fully automated.

### 6.4 Step 3 — Build any other project normally

```powershell
dotnet build --configuration Release
```

The DLL is now at the path written by the sentinel file; `Directory.Build.props`
resolves the path dynamically; `Directory.Build.targets` imports the `.targets`
file successfully; `UsingTask` registers the three task classes; the per-project
version machinery runs on every build.

### 6.5 The `Build/` directory is source-controlled

The versioned `Build\ATAP.Utilities.BuildTooling.<ver>\` directory (including the
DLL) is **committed to the repository**. Unlike NuGet packages restored to a
per-user cache, this pre-built DLL is a deliberate part of the source tree. Any
developer who clones the repository gets a working build system immediately —
no bootstrap step required after the initial setup.

---

## 7. End-to-End Build Flow for One Project

```text
dotnet build MyProject.csproj --configuration Release
│
├── MSBuild loads Directory.Build.props
│   └── Sets SolutionDir, ATAPUtilitiesBuildToolingTasksAssembly,
│       VersionFile, UpdatePackageVersionLockFilePath, etc.
│
├── MSBuild loads MyProject.csproj
│   └── Project-specific TargetFramework(s),
│       version parts (MajorVersion, MinorVersion, PatchVersion,
│       PackageLifeCycleStage, PackageLabel)
│
├── MSBuild loads Directory.Build.targets
│   └── Imports ATAP.Utilities.BuildTooling.targets
│       └── Registers UsingTask for GetVersion, UpdateVersion, SetVersion
│   └── Evaluates <Version> property group (§3.6)
│
├── BeforeCompile target fires
│   └── (when enabled) Calls UpdatePackageVersionBeforeOuterBuild
│       ├── Creates lock file
│       ├── Calls UpdateVersion task → reads Properties/AssemblyInfo.cs
│       │   ├── Reads MajorVersion, MinorVersion, PatchVersion, PackageVersion
│       │   ├── Parses existing label count
│       │   ├── Computes new Build (days) and Revision (seconds/2)
│       │   ├── Increments label count (or resets if version parts changed)
│       │   └── Writes updated AssemblyInfo.cs
│       └── MSBuild properties Build, Revision, PackageVersion are updated
│
├── Compile (C# compiler reads updated AssemblyInfo.cs)
│
├── (if IsPackable) GenerateNuspec fires
│   ├── SetPackageVersionForPack runs first
│   │   └── re-reads PackageVersion into outer scope
│   ├── ConstrainATAPPackageDependencyVersionRange runs
│   │   └── rewrites ATAP.* project-ref dep ranges to [0.0.0-alpha-000, 2.0.0)
│   └── NuSpec is generated with correct PackageVersion and dep ranges
│
├── Pack → produces .nupkg
│
├── PublishAfterBuild fires
│   └── dotnet nuget push → uploads .nupkg to ProGet nuget-experimental feed
│
└── UpdatePackageVersionAfterOuterBuild fires
    └── Deletes lock file
```

---

## 8. Key Property Reference

| Property                                       | Set in                                              | Example value                                                          | Purpose                                                                                       |
| ---------------------------------------------- | --------------------------------------------------- | ---------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| `SolutionDir`                                  | `Directory.Build.props`                             | `C:\...\ATAP.Utilities\`                                               | Root of the repository.                                                                       |
| `SolutionBuildToolsBaseDir`                    | `Directory.Build.props`                             | `$(SolutionDir)Build\`                                                 | Where pre-built task tools live.                                                              |
| `ATAPBuildToolingConfiguration`                | `Directory.Build.props`                             | `Debug` or `Release`                                                   | Verbose-logging switch inside tasks.                                                          |
| `ATAPBuildToolingDebugVerbosity`               | `Directory.Build.props`                             | `Trace`                                                                | Sub-level logging verbosity.                                                                  |
| `ATAPBuildToolingVersion`                      | `Directory.Build.props` (sentinel file or fallback) | `0.1.0`                                                                | Deployed BuildTooling version; read from `Build\ATAP.Utilities.BuildTooling.current-version`. |
| `ATAPUtilitiesBuildToolingTargetsPath`         | `Directory.Build.props`                             | `$(SolutionBuildToolsBaseDir)ATAP.Utilities.BuildTooling.0.1.0\build\` | Where `ATAP.Utilities.BuildTooling.targets` is loaded from.                                   |
| `ATAPUtilitiesBuildToolingTasksAssembly`       | `Directory.Build.props`                             | `...\Release\net10.0\ATAP.Utilities.BuildTooling.CSharp.dll`           | The task DLL path.                                                                            |
| `VersionFile`                                  | `Directory.Build.props`                             | `$(MSBuildProjectDirectory)\Properties\AssemblyInfo.cs`                | Per-project version file.                                                                     |
| `UpdatePackageVersionLockFilePath`             | `Directory.Build.props`                             | `$(MSBuildProjectDirectory)\<ProjectName>.UpdatePackageVersion.lock`   | Multi-TFM deduplication lock.                                                                 |
| `MajorVersion`, `MinorVersion`, `PatchVersion` | Individual `.csproj`                                | `0`, `1`, `0`                                                          | Semantic version parts; read by `UpdateVersion`.                                              |
| `PackageLifeCycleStage`                        | Individual `.csproj`                                | `Development`                                                          | Controls whether a pre-release suffix is added.                                               |
| `PackageLabel`                                 | Individual `.csproj`                                | `Alpha`                                                                | Pre-release label string.                                                                     |
| `ProGetExperimentalFeedUrl`                    | `ATAP.Utilities.BuildTooling.targets`               | `http://localhost:50000/nuget/nuget-experimental/v3/index.json`        | Push destination.                                                                             |
| `ProGetApiKeySecretName`                       | `ATAP.Utilities.BuildTooling.targets`               | `ProGet.Admin.API.Key`                                                 | Non-secret name passed to the publishing wrapper.                                             |

### 8.1 RepoHealth gate for shared MSBuild properties

The repository-wide MSBuild property audit is a **RepoHealth** gate, not a
package test. Run it with:

```powershell
pwsh -File Build\Invoke-RepoHealthGate.ps1
```

The gate invokes `tests\RepoHealth\Directory.Build.Props.Properties.Tests.ps1`
and evaluates `PackageLifeCycleStage`, `TargetProGetFeed`, and
`CentralPackageVersionOverridesEnabled` through `dotnet msbuild -getProperty`
for every C# project under `src/`. C# CI and BuildMaster flows should run this
after restore and before `dotnet pack` or publish. It intentionally lives
outside `src\ATAP.Utilities.BuildTooling.PowerShell\tests` so a single
PowerShell module package build does not enumerate all C# projects.

---

## 9. Concurrent Migration — NBGV Alongside AssemblyInfo.cs

A migration is currently in progress: the solution is moving from the legacy
`AssemblyInfo.cs`-plus-custom-tasks versioning flow to **Nerdbank.GitVersioning**
(`version.json`). As of sprint 6:

- `Directory.Build.props §2.11` injects the `Nerdbank.GitVersioning` package into
  every project via a solution-wide `<PackageReference>`.
- The solution-root `version.json` defines the NBGV schema (e.g. `0.1-Sprint.{height}`).
- The legacy `GetVersion` / `UpdateVersion` / `SetVersion` custom tasks still run
  (per §5) for projects that have not yet migrated; their `CallTarget` inside
  `BeforeCompile` is temporarily commented out so NBGV can drive the version
  during the transition.

The two systems **coexist** during the transition. After NBGV migration completes,
the `AssemblyInfo.cs` per-project files can be removed and the custom-task DLL
retired (or repurposed for non-version tasks).

Full details — `version.json` schema, NBGV label promotion, per-project overrides,
coexistence rules, retirement plan — are in [CSharp-Packages-Versioning.md](CSharp-Packages-Versioning.md).

---

## 10. Visual Studio and IDE Considerations

### 10.1 Project-type GUID in `.sln`

Because `TargetFrameworks` is imported from `Directory.Build.props` and does not
appear in individual `.csproj` files, using the default project-type GUID will
cause Visual Studio to think the project is old-style and attempt an SDK-style
upgrade. Ensure the `.sln` entry uses the SDK-style GUID
`{9A19103F-16F7-4668-BE54-9A1E7A4F7556}`:

```text
Project("{9A19103F-16F7-4668-BE54-9A1E7A4F7556}") = "LibraryName", "LibraryName.csproj", "{ADFEAAF5-225C-4E13-8B65-77057AAC44B8}"
EndProject
```

### 10.2 BuildTooling DLL is locked by VS when building

When Visual Studio builds a project, it locks
`ATAP.Utilities.BuildTooling.CSharp.dll`. To replace or update the DLL, quit the
IDE before building the BuildTooling project, or use `dotnet build` from the
command line.

### 10.3 Recommended VS extensions

- **Project System Tools** — structured MSBuild log viewer inside VS. Install from the
  [VS Marketplace](https://marketplace.visualstudio.com/items?itemName=VisualStudioProductTeam.ProjectSystemTools).
  `View > Other Windows > Build Logging` → play button → double-click a log to open it.
- **MSBuild Structured Log Viewer** (standalone) — `http://msbuildlog.com/`. Opens
  `.binlog` files produced by `dotnet build -bl` or the `<binaryLogger>` property
  in `Directory.Build.props §2.8`.
- **Microsoft Visual Studio Test Extensions** — test runner integration.
- **PowerShell Tools for Visual Studio** — syntax support for build scripts.

### 10.4 Deterministic builds

Deterministic-build flags produce byte-identical binaries for a given source tree,
which matters for SourceLink traceability and supply-chain verification:

```powershell
dotnet build --configuration Release -p:ContinuousIntegrationBuild=true
```

`ContinuousIntegrationBuild=true` is set automatically by BuildMaster agents.
Do not set it for `Debug` builds — it disables some diagnostic output.

See also [github.com/clairernovotny/DeterministicBuilds](https://github.com/clairernovotny/DeterministicBuilds).

---

## 11. Common Failure Modes

| Symptom                                                                             | Cause                                                                             | Fix                                                                                                                                                               |
| ----------------------------------------------------------------------------------- | --------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `MSB4062: The "ATAP.Utilities.BuildTooling.UpdateVersion" task could not be loaded` | DLL not at the path computed by `ATAPUtilitiesBuildToolingTasksAssembly`.         | Verify the DLL exists at `Build\...\Release\net10.0\ATAP.Utilities.BuildTooling.CSharp.dll`; check `ATAPBuildToolingRelativeBasePath` in `Directory.Build.props`. |
| `ATAP.Utilities.BuildTooling.targets` import silently skipped                       | `Condition="Exists(...)"` evaluated false; file not deployed.                     | Re-run the bootstrap (§6.1–6.2).                                                                                                                                  |
| Version not incrementing                                                            | `CallTarget` inside `BeforeCompile` is commented out.                             | Intentional in current state; uncomment when ready, or rely on NBGV (§9).                                                                                         |
| Version incremented N times per build (N = number of TFMs)                          | Lock file logic not working; lock file path resolves differently per inner build. | Verify `$(UpdatePackageVersionLockFilePath)` uses `$(MSBuildProjectDirectory)`, not a relative path.                                                              |
| `AssemblyInfo.cs` has all-zero versions after first build                           | File was not created with valid initial values before bootstrap.                  | Write valid initial content (see [CSharp-Packages-Versioning.md](CSharp-Packages-Versioning.md)).                                                                 |
| ProGet push fails with 401                                                          | `ProGet.Admin.API.Key` cannot resolve or lacks permission.                        | Verify the SecretName metadata and grant; never print or export its value.                                                                                        |
| DesignTime build in Visual Studio triggers version update                           | `DesignTimeBuild` condition missing from `BeforeCompile` inputs.                  | Restore the `$(DesignTimeBuild) != true` guard inside `BeforeCompile`.                                                                                            |
| `MSB4022` "result of evaluating the value … is invalid" on `UsingTask`              | Sentinel file points to a nonexistent directory during bootstrap.                 | The `Condition="'$(ATAP…Assembly)' != ''"` guard on `UsingTask` (§5.1) normally prevents this; verify the guard is still present.                                 |
| Project pack writes dependency `>= resolved-version`                                | `ConstrainATAPPackageDependencyVersionRange` (§3.5) did not run.                  | Verify `IsPackable=true` on the project; confirm the target is present in `Directory.Build.targets`.                                                              |

---

## 12. What NOT to Do

- Do not add `<Import>` statements for `Directory.Build.props` or
  `Directory.Build.targets` into individual `.csproj` files. MSBuild finds them
  automatically; explicit imports cause double-loading.
- Do not set both `<TargetFramework>` and `<TargetFrameworks>` to non-empty values
  in the same project. Use the empty-override pattern
  (`<TargetFramework></TargetFramework>` followed by `<TargetFrameworks>…`) when
  a project needs to multi-target despite the single-TFM default.
- Do not call `UpdateVersion` from within the `ATAP.Utilities.BuildTooling.CSharp`
  project's own build until the DLL is already deployed to the `Build\`
  directory. The project's `AssemblyInfo.cs` must be updated manually until the
  bootstrap is complete.
- Do not modify the deployed DLL in `Build\` directly. Always rebuild the project
  and re-deploy.
- Do not replace `<SolutionDir>$(MSBuildThisFileDirectory)</SolutionDir>` with a
  hardcoded absolute path — it breaks cross-worktree and cross-machine builds.

---

## 13. Replicating in a New Repository

This section gives the exact sequence to replicate the same custom-task build
system in another repository. Read it top-to-bottom before taking any action.

### 13.1 Preconditions

1. Target repository is a .NET SDK-style project repository.
2. Agent has write access to the repository root and all subdirectories.
3. `dotnet` (SDK 8.0+) is available in the shell.
4. Shell is **PowerShell 7** (`pwsh`). No bash syntax.
5. A ProGet instance is reachable and `ProGet.Admin.API.Key` resolves through
   `Get-SecretATAP`. If ProGet is not used, disable `PublishAfterBuild`.

### 13.2 Step 1 — Choose initial bootstrap version

Pick a starting version string for the BuildTooling package (e.g. `0.1.0`). This
is used only during the first-ever bootstrap as the fallback value in
`Directory.Build.props`. After the first successful Release build, the sentinel
file takes over.

### 13.3 Step 2 — Create directory structure

```powershell
New-Item -ItemType Directory -Path "Build\ATAP.Utilities.BuildTooling.0.1.0\build\Release\net10.0" -Force
New-Item -ItemType Directory -Path "src\ATAP.Utilities.BuildTooling.CSharp\Properties" -Force
```

### 13.4 Step 3 — Copy the four files

Copy from this repository verbatim and adjust only as noted:

| Source                                                                             | Copy to          | Adjust                                                                                                                                  |
| ---------------------------------------------------------------------------------- | ---------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| `Directory.Build.props`                                                            | Target repo root | Fallback `<ATAPBuildToolingVersion>`; `<Copyright>`, `<Authors>`, `<Product>`, `<RepositoryUrl>`; `<NuGetLocalFeedPath>` if different.  |
| `Directory.Build.targets`                                                          | Target repo root | Comment out `PublishAfterBuild` target if ProGet not used; remove `Microsoft.SourceLink.GitHub` reference if SourceLink not configured. |
| `src/ATAP.Utilities.BuildTooling.CSharp/ATAP.Utilities.BuildTooling.CSharp.csproj` | Same path        | `<MajorVersion>`, `<MinorVersion>`, `<PatchVersion>` for the tooling's own version.                                                     |
| `src/ATAP.Utilities.BuildTooling.CSharp/ATAP.Utilities.BuildTooling.CSharp.cs`     | Same path        | No changes.                                                                                                                             |
| `src/ATAP.Utilities.BuildTooling.CSharp/ATAP.Utilities.BuildTooling.targets`       | Same path        | `<ProGetExperimentalFeedUrl>` if different; uncomment `<CallTarget>` inside `BeforeCompile` when ready for auto-updates.                |

### 13.5 Step 4 — Create `AssemblyInfo.cs` for the tooling project

```csharp
using System.Reflection;
[assembly: AssemblyFileVersion("0.1.0.0")]
[assembly: AssemblyInformationalVersion("0.1.0-Alpha-001")]
[assembly: AssemblyVersion("0.1.0")]
```

Path: `src\ATAP.Utilities.BuildTooling.CSharp\Properties\AssemblyInfo.cs`.

### 13.6 Step 5 — Create `AssemblyInfo.cs` for each other project

Each project that will participate in automatic version management needs its own
`Properties\AssemblyInfo.cs` with the three-attribute structure, plus the
version-part properties in its `.csproj`:

```xml
<MajorVersion>1</MajorVersion>
<MinorVersion>0</MinorVersion>
<PatchVersion>0</PatchVersion>
<PackageLifeCycleStage>Development</PackageLifeCycleStage>
<PackageLabel>Alpha</PackageLabel>
```

### 13.7 Step 6 — Bootstrap build

One-time pre-bootstrap copy (only on the very first run):

```powershell
Copy-Item `
    src\ATAP.Utilities.BuildTooling.CSharp\ATAP.Utilities.BuildTooling.targets `
    Build\ATAP.Utilities.BuildTooling.0.1.0\build\ `
    -Force
```

Then build the tooling project in Release:

```powershell
dotnet build src\ATAP.Utilities.BuildTooling.CSharp\ATAP.Utilities.BuildTooling.CSharp.csproj `
    --configuration Release
```

`DeployBuildToolingToBuildDirectory` fires at end-of-build and writes the sentinel
file. Verify:

```text
Build\ATAP.Utilities.BuildTooling.current-version                                     ← contains "0.1.0"
Build\ATAP.Utilities.BuildTooling.0.1.0\build\ATAP.Utilities.BuildTooling.targets
Build\ATAP.Utilities.BuildTooling.0.1.0\build\Release\net10.0\ATAP.Utilities.BuildTooling.CSharp.dll
```

### 13.8 Step 7 — Validate with a test project build

```powershell
dotnet build src\<SomeOtherProject>\<SomeOtherProject>.csproj --configuration Release --verbosity normal
```

Look for these messages in the output to confirm the tasks are active:

- With `ATAPBuildToolingConfiguration=Debug`, `PrintBuildVariables` logs
  `MajorVersion`, `MinorVersion`, `PackageVersion`, etc.
- With `UpdatePackageVersionBeforeOuterBuild` enabled, `AssemblyInfo.cs` shows
  an incremented label count after the build.

### 13.9 Step 8 — Commit the `Build\` directory

Commit `Build\ATAP.Utilities.BuildTooling.0.1.0\` (including the DLL) to the
repository so every cloner gets a working build system immediately.

---

## 14. Related Documents

- [CSharp-Packages-Versioning.md](CSharp-Packages-Versioning.md) — NBGV, label promotion, `version.json`, `AssemblyInfo.cs` retirement plan.
- [CSharp-Packages-Pack-and-Push.md](CSharp-Packages-Pack-and-Push.md) — `dotnet pack`, nuspec generation, ProGet push, meta-package, cache clearing.
- [CSharp-Packages-Test-Process.md](CSharp-Packages-Test-Process.md) — xUnit conventions, `dotnet test`, coverlet, test-artifact collection.
- [CSharp-Central-Package-Management.md](CSharp-Central-Package-Management.md) — migration to `Directory.Packages.props`.
- [BuildMaster-ProGet-CSharp-Package-Pipeline.md](BuildMaster-ProGet-CSharp-Package-Pipeline.md) — 5-stage CI pipeline (Experimental → Development → Integration → QA → Production).
- [Rules Compendium.MSBuild.md](Rules%20Compendium.MSBuild.md) — MSBuild rule primitives (Philote-GUID-identified).
- [\_Planning/Explainers/0107-build-artifacts-trace-etw.md](../../_Planning-wt-12-sprint-0006-work-items/Explainers/0107-build-artifacts-trace-etw.md) — 13-field build metadata, TRACE config, ETW providers.
