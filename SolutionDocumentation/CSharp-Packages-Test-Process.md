# C# Packages — Test Process

**Scope:** Writing, organizing, and running automated tests for `ATAP.Utilities.*`
and `AceCommander.*` C# projects; producing and preserving test artifacts.
**Audience:** Developers writing new xUnit / bUnit tests; engineers configuring
tier-appropriate test runs; maintainers of test-project conventions.

> **Strategy update (sprint-0007 — Immutable Build).** Tests at every tier
> run **against the existing `.nupkg`** that was built once at Experimental
> and is being promoted upward. Test results are attached to the BuildMaster
> release record for that exact `(PackageId, Version, SHA-256)` and (for
> headline kinds) embedded into the Release Bundle's `tests/` folder.
> Higher tiers do **not** rebuild the package before testing — they restore
> the promoted package from the next-higher feed and run tests against it.
> See [Immutable-Build-Strategy.md](Immutable-Build-Strategy.md).
>
> **Strategy update (sprint-NNNN — Conditional SUT Reference).** Each test
> project uses a single-project, conditional-reference model: a
> `UsePackageReferenceForSUT` MSBuild property switches the SUT dependency
> between `<ProjectReference>` (developer/experimental tier, the default)
> and `<PackageReference>` (all promotion tiers — Development through
> Production). This eliminates
> duplicate test projects while satisfying the immutable-build requirement
> that higher tiers validate the promoted artifact, not a local rebuild.
> See §3.1 and §11 for mechanics.

> **Status:** Authoritative. Consolidates the C# test portions of
> `_Planning/Explainers/0106-testing-process-and-artifacts.md`, the rules in
> `.claude/rules/xunit.md`, and the sprint-0006 test-project conventions currently
> in the tree.

**Not in this doc:**

- PowerShell / Pester tests (→ `PowerShell-Modules-Test-Process.md`).
- Versioning of the code under test (→ `CSharp-Packages-Versioning.md`).
- BuildMaster pipeline wiring for test stages
  (→ `BuildMaster-ProGet-CSharp-Package-Pipeline.md`).
- E2E / Playwright browser tests (→ `AceCommander-Test-Process.md`, if created).

---

## 1. Test Project Inventory

### 1.1 ATAP.Utilities — `tests/`

~28 test projects, one per shipping library. Naming convention is
`{Library}.UnitTests` adjacent to `src/{Library}/`:

| Category       | Example                                                                                                                              |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| Unit           | `tests/ATAP.Utilities.Philote.UnitTests/…UnitTests.csproj`                                                                           |
| Integration    | `tests/ATAP.Utilities.RabbitMQ.IntegrationTests/…`                                                                                   |
| Data-providers | `tests/ATAP.Utilities.Serializer.DataForTests/…`                                                                                     |
| Excluded       | `tests/ATAP.Services.TcpWithResilience.UnitTests.Exclude.csproj` (name-suffix `.Exclude` — kept out of solution-level `dotnet test`) |

The `.Exclude.csproj` rename is the current mechanism for quarantining a
broken test project without deleting it. A better long-term fix is to put it
in a `TestSlice` that the solution build can opt out of; the rename works
because `dotnet sln` doesn't auto-add files with that suffix.

### 1.2 AceCommander — `<Project>.Tests/`

Three test projects, colocated with the projects they test:

| Project                     | Tests                                       |
| --------------------------- | ------------------------------------------- |
| `AceCommander.Client.Tests` | Blazor WASM client (includes bUnit).        |
| `AceCommander.Server.Tests` | ASP.NET Core server, SignalR, services.     |
| `AceCommander.Shared.Tests` | Plain library shared between client/server. |

AceCommander keeps each test project adjacent to the project under test,
rather than in a top-level `tests/` folder. Either layout is valid; the ATAP
convention has history, the AceCommander convention is closer to the standard
`dotnet new` template.

---

## 2. Frameworks and Packages

Every C# test project is **xUnit-based**. The canonical dependency set comes
from [ATAP.Utilities.Philote.UnitTests.csproj](../tests/ATAP.Utilities.Philote.UnitTests/ATAP.Utilities.Philote.UnitTests.csproj):

```xml
<ItemGroup>
  <PackageReference Include="Microsoft.NET.Test.Sdk" />
  <PackageReference Include="FluentAssertions" />
  <PackageReference Include="Moq" />
  <PackageReference Include="xunit" />
  <PackageReference Include="xunit.runner.console">
    <IncludeAssets>runtime; build; native; contentfiles; analyzers; buildtransitive</IncludeAssets>
    <PrivateAssets>all</PrivateAssets>
  </PackageReference>
  <PackageReference Include="xunit.runner.visualstudio">
    <PrivateAssets>all</PrivateAssets>
    <IncludeAssets>runtime; build; native; contentfiles; analyzers</IncludeAssets>
  </PackageReference>
  <PackageReference Include="coverlet.collector">
    <PrivateAssets>all</PrivateAssets>
    <IncludeAssets>runtime; build; native; contentfiles; analyzers; buildtransitive</IncludeAssets>
  </PackageReference>
</ItemGroup>
```

| Package                     | Role                                                   |
| --------------------------- | ------------------------------------------------------ |
| `Microsoft.NET.Test.SDK`    | MSBuild integration for `dotnet test`.                 |
| `xunit`                     | Test framework.                                        |
| `xunit.runner.visualstudio` | IDE Test Explorer integration.                         |
| `xunit.runner.console`      | Command-line runner (used by some CI configurations).  |
| `FluentAssertions`          | Assertion library. `.Should().Be(...)` style.          |
| `Moq`                       | Mocking library for unit tests.                        |
| `coverlet.collector`        | Code-coverage collector integrated with `dotnet test`. |

**Additional, per-need:**

- `bUnit` — Blazor component tests (AceCommander.Client.Tests only).
- `Testcontainers.*` — for integration tests that require a real DB / broker.
- Project reference to `ATAP.Utilities.Testing` — shared fixtures and DI helpers
  available to any test project via `<ProjectReference>`.

All package **versions** are pinned centrally. The test projects omit version
numbers because `Directory.Packages.props` (→ `CSharp-Central-Package-Management.md`)
supplies them.

---

## 3. Test Project Conventions

Every C# test project sets these properties in its `.csproj`:

```xml
<PropertyGroup>
  <GeneratePackageOnBuild>false</GeneratePackageOnBuild>
  <IsPackable>false</IsPackable>
  <MajorVersion>0</MajorVersion>
  <MinorVersion>1</MinorVersion>
  <PatchVersion>0</PatchVersion>
  <PackageLifeCycleStage>Development</PackageLifeCycleStage>
  <PackageLabel>Alpha</PackageLabel>
</PropertyGroup>
```

- `IsPackable=false` — test DLLs do not ship as NuGet packages.
- `GeneratePackageOnBuild=false` — overrides any solution-level default that
  would auto-pack.
- The `PackageLabel` / `PackageLifeCycleStage` entries are legacy from the
  pre-NBGV era and are harmless. They will go away in the retirement sweep
  (see Versioning doc §9).

### 3.1 Conditional SUT Reference (ProjectReference vs PackageReference)

Each test project references its library under test (the SUT) using a
**conditional reference block** controlled by the `UsePackageReferenceForSUT`
MSBuild property. The default (`false`) uses `<ProjectReference>` for the
developer inner-loop. Promotion tiers pass `UsePackageReferenceForSUT=true`
and `SUTVersion=<promoted-version>` to switch to `<PackageReference>` against
the exact artifact restored from the tier's feed.

**Canonical `.csproj` pattern** (using `ATAP.Utilities.Philote.UnitTests` as
the example):

```xml
<PropertyGroup>
  <!-- Default: false → ProjectReference mode (developer / Experimental tier).
       Set to true in CI promotion tiers (Development–Production) to test the promoted package. -->
  <UsePackageReferenceForSUT
      Condition="'$(UsePackageReferenceForSUT)' == ''">false</UsePackageReferenceForSUT>
</PropertyGroup>

<!-- Developer / Experimental tier: reference local source -->
<ItemGroup Condition="'$(UsePackageReferenceForSUT)' == 'false'">
  <ProjectReference Include="..\..\src\ATAP.Utilities.Philote\ATAP.Utilities.Philote.csproj" />
</ItemGroup>

<!-- Promotion tiers (Development–Production): reference the promoted NuGet package -->
<ItemGroup Condition="'$(UsePackageReferenceForSUT)' == 'true'">
  <PackageReference Include="ATAP.Utilities.Philote" Version="$(SUTVersion)" />
</ItemGroup>
```

> **Important:** `SUTVersion` must be supplied by the pipeline at invocation
> time (see §11). Never hard-code a version in the `.csproj`.

**`ATAP.Utilities.Testing` reference** follows the same pattern when the
library itself is part of the promotion chain. When it is promoted as a
package, switch its reference alongside the primary SUT:

```xml
<!-- Developer / Experimental -->
<ItemGroup Condition="'$(UsePackageReferenceForSUT)' == 'false'">
  <ProjectReference Include="..\..\src\ATAP.Utilities.Philote\ATAP.Utilities.Philote.csproj" />
  <ProjectReference Include="..\..\src\ATAP.Utilities.Testing\ATAP.Utilities.Testing.csproj" />
</ItemGroup>

<!-- Promotion tiers -->
<ItemGroup Condition="'$(UsePackageReferenceForSUT)' == 'true'">
  <PackageReference Include="ATAP.Utilities.Philote"  Version="$(SUTVersion)" />
  <PackageReference Include="ATAP.Utilities.Testing"  Version="$(SUTVersion)" />
</ItemGroup>
```

---

## 4. Organizing Tests with Categories (Traits)

xUnit traits are the filter mechanism for tier-appropriate test runs. The
agreed vocabulary matches the [0106 Testing Process and Artifacts][0106] tier
model:

```csharp
[Trait("Category", "Unit")]          // fast, no externals, run every tier
[Trait("Category", "Integration")]    // real DB, queue, or HTTP dep
[Trait("Category", "Functional")]     // end-to-end through a slice
[Trait("Category", "Regression")]     // guards against a specific prior bug
[Trait("Category", "Performance")]    // ETW-instrumented, Trace build only
```

Usage:

```csharp
public class PhiloteTests
{
    [Fact]
    [Trait("Category", "Unit")]
    public void Can_roundtrip_empty_philote() { ... }

    [Fact]
    [Trait("Category", "Integration")]
    public async Task Persists_to_real_sql() { ... }
}
```

Filter at `dotnet test` time with `--filter`:

```powershell
# Unit tests only
dotnet test --filter "Category=Unit"

# Unit + Integration
dotnet test --filter "Category=Unit|Category=Integration"

# Everything except Performance
dotnet test --filter "Category!=Performance"
```

The tier-to-filter mapping in BuildMaster:

| Tier         | `--filter` argument used                             |
| ------------ | ---------------------------------------------------- |
| Experimental | `Category=Unit`                                      |
| Development  | _(unset — all tests)_                                |
| Integration  | `Category=Unit\|Category=Integration`                |
| QA           | _(unset — full suite with coverage)_                 |
| Production   | `Category=Smoke` _(minimal subset for release gate)_ |

[0106]: ../../_Planning-wt-12-sprint-0006-work-items/Explainers/0106-testing-process-and-artifacts.md

---

## 5. Running Tests Locally

In developer tiers, `UsePackageReferenceForSUT` defaults to `false`, so
`dotnet test` uses `<ProjectReference>` and no extra flags are required.

### 5.0 RepoHealth gate

RepoHealth tests are repository-wide checks, not tests for one C# package or one
PowerShell module. Run them separately:

```powershell
pwsh -File Build\Invoke-RepoHealthGate.ps1
```

The current gate runs
`tests\RepoHealth\Directory.Build.Props.Properties.Tests.ps1`, which audits
`Directory.Build.props` propagation across every C# project under `src/`.
C# pipelines should run it after restore and before pack or publish. It is not
part of `module.build.ps1` for `ATAP.Utilities.BuildTooling.PowerShell`, so
PowerShell module package builds do not evaluate all `.csproj` files.

### 5.1 The whole solution

```powershell
# ATAP.Utilities — ProjectReference mode (default)
dotnet test ATAP.Utilities.sln -c Release

# AceCommander — ProjectReference mode (default)
dotnet test AceCommander.sln -c Release
```

### 5.2 One project

```powershell
dotnet test tests\ATAP.Utilities.Philote.UnitTests\ATAP.Utilities.Philote.UnitTests.csproj `
    -c Release
```

### 5.3 One class or one method

```powershell
# One class
dotnet test ... --filter "FullyQualifiedName~PhiloteTests"

# One method
dotnet test ... --filter "FullyQualifiedName=ATAP.Utilities.Philote.Tests.PhiloteTests.Can_roundtrip_empty_philote"
```

`~` is "contains"; `=` is exact match. `FullyQualifiedName` includes the
namespace.

### 5.4 With verbose output

```powershell
dotnet test ... -c Release --logger "console;verbosity=detailed"
```

Verbose output shows each test's assertion failure message in the terminal —
useful when a CI log omits details.

### 5.5 Simulating a promotion-tier run locally

To reproduce exactly what BuildMaster does at the Development through
Production tiers, ensure the promoted package is available from your local
ProGet feed, then pass the two extra MSBuild properties:

```powershell
dotnet test tests\ATAP.Utilities.Philote.UnitTests\ATAP.Utilities.Philote.UnitTests.csproj `
    -c Release `
    /p:UsePackageReferenceForSUT=true `
    /p:SUTVersion=1.2.3
```

This restores `ATAP.Utilities.Philote` 1.2.3 from the feed and runs the
same test suite against it, rather than the local source. Useful for
debugging a promotion failure without waiting for a full BuildMaster run.

---

## 6. Test Results (TRX) and Artifacts

### 6.1 Generating TRX

Add `--logger trx` to emit a Visual Studio Test Results `.trx` file that
downstream tooling (BuildMaster, ProGet, ReportGenerator) consumes:

```powershell
dotnet test ATAP.Utilities.sln -c Release --no-build `
    --logger trx `
    --results-directory _generated\testresults\experimental
```

The `.trx` lands at
`_generated/testresults/experimental/<timestamp>.trx` per the SC-0033 rule that
all generated artifacts live under `_generated/`.

### 6.2 Keeping artifacts out of git

`_generated/` is in every repo's `.gitignore`. Artifacts that need to survive
a commit must be **embedded into the package** (§7) — do not add exceptions
to `.gitignore`.

### 6.3 Artifacts that travel with the package

> **Sprint-7 note (immutable build).** Test results from each tier are
> attached to the **BuildMaster release record** for that exact `(PackageId,
Version, SHA-256)`, not embedded into the `.nupkg` itself — embedding would
> change the package bytes and violate the build-once invariant. The Release
> Bundle (the customer-facing installer) **does** carry headline test
> evidence in its `tests/` folder, since the bundle is its own artifact built
> once at release-tag time and includes results from every tier that
> validated it. See [Release-Bundle-Pipeline.md §2](Release-Bundle-Pipeline.md#2-what-goes-into-a-bundle)
> and [Release-Branch-and-Manifest.md §3](Release-Branch-and-Manifest.md#3-the-manifest-schema).

Under immutable build, test results are attached to the BuildMaster release
record for the exact `(PackageId, Version, SHA-256)`. Headline test evidence
is also embedded into the Release Bundle's `tests/` folder when a Release
Bundle is built; bundles are their own artifact built once at release-tag
time and so do not violate the immutability of the library `.nupkg`. See
[Release-Branch-and-Manifest.md §3 manifest schema](Release-Branch-and-Manifest.md#3-the-manifest-schema)
for the manifest field that records this evidence. A consumer can audit any
production `.nupkg` by querying the BuildMaster release record for that
version, which links to all the test artifacts collected during promotion.

---

## 7. Code Coverage

### 7.1 Running with coverage

```powershell
dotnet test <project> -c Release --no-build `
    --collect:"XPlat Code Coverage" `
    --results-directory _generated\testresults\qa
```

This invokes `coverlet.collector` (already referenced in every test project)
and writes `coverage.cobertura.xml` inside a GUID-named subfolder of
`--results-directory`.

### 7.2 Merging and viewing

```powershell
# Install ReportGenerator as a global tool once
dotnet tool install -g dotnet-reportgenerator-globaltool

# Generate a static HTML report
reportgenerator `
    -reports:"_generated\testresults\**\coverage.cobertura.xml" `
    -targetdir:"_generated\coverage-html" `
    -reporttypes:Html
```

Open `_generated/coverage-html/index.html` in a browser.

### 7.3 Coverage targets

From the [0106 Explainer][0106]:

| Component type                                            | Target              |
| --------------------------------------------------------- | ------------------- |
| Critical libraries (serialization, security, persistence) | 100%                |
| Standard libraries                                        | 80%+                |
| UI components (Blazor)                                    | Best effort (bUnit) |

These are aspirational today; most ATAP.Utilities libraries have less. The
targets apply at **Development → Testing promotion** — the coverage gate
blocks promotion if the threshold isn't met for the component category.

---

## 8. Unit vs Integration — the Boundary

The rule is "mocks for unit, real for integration":

- **Unit tests** use `Moq` (or a hand-written fake) for every external
  dependency: SQL, HTTP, message queues, filesystem, clock. They must run
  without network access and without Docker.
- **Integration tests** spin up the real dependency — usually via
  `Testcontainers` or a locally-running service (`Sprint-{NNNN}[-{username}]`
  SQL instance for database tests, a local RabbitMQ for message-queue tests).
- **Do NOT mock the database** in tests that exist to validate SQL behavior.
  The feedback memory here is explicit: mock/prod divergence has masked
  broken migrations in the past. Integration tests must hit a real database.

A test project can hold both categories; `[Trait("Category", ...)]` is the
filter used to run only one or the other.

### 8.1 Shared fixtures from `ATAP.Utilities.Testing`

The `ATAP.Utilities.Testing` library ships reusable xUnit fixtures:

- `Fixture.Database` — boilerplate for spinning up a test DB.
- `Fixture.Serialization` — round-trip harness with swappable JSON shims
  (Newtonsoft, ServiceStack, SystemTextJson, custom Plugin).
- `DI` / `DI.Fixture.Serialization` — `IServiceCollection` helpers for the
  Options pattern.

Reference `ATAP.Utilities.Testing` via the conditional SUT reference pattern
(§3.1). In developer / Experimental tiers it resolves as a `<ProjectReference>`;
in promotion tiers it resolves as a `<PackageReference>` to the promoted package.

---

## 9. Blazor Component Tests (bUnit)

AceCommander.Client.Tests uses **bUnit** to render Blazor components in-memory
and assert on the resulting DOM. The package reference is:

```xml
<PackageReference Include="bunit" />
```

Pattern:

```csharp
public class CounterComponentTests : TestContext
{
    [Fact]
    [Trait("Category", "Unit")]
    public void Initial_count_is_zero()
    {
        var cut = RenderComponent<Counter>();
        cut.Find("p").TextContent.Should().Contain("Current count: 0");
    }
}
```

bUnit tests are Unit-category — they do not start a browser. Browser-based
end-to-end tests use Playwright and are scoped to AceCommander only
(`scripts/run-tests-and-coverage.ps1`).

---

## 10. Test Authoring Rules (from `.claude/rules/xunit.md`)

- **Arrange / Act / Assert** structure. Blank lines between sections.
- **FluentAssertions for assertions** — `value.Should().Be(expected)`, not
  `Assert.Equal`. Reads closer to natural language; failure messages are
  clearer.
- **One logical assertion per test** where practical. Multiple `.Should()`
  calls on related properties of one object are fine; three unrelated
  assertions are a smell.
- **`[Fact]` for fixed inputs; `[Theory]` for parameterized**. Use
  `[InlineData]`, `[MemberData]`, or `[ClassData]` as appropriate.
- **Descriptive names**. `Can_roundtrip_empty_philote` is good;
  `Test1` is not. Test names appear verbatim in CI dashboards.
- **No `Thread.Sleep`**. For async code use `await`; for timing-sensitive
  code, take the clock as a dependency (inject `TimeProvider` and supply a
  fake).
- **Every public API should have a unit test**. "Public" means
  `public` or `internal` with `[assembly: InternalsVisibleTo]`.

Full guidance lives in `.claude/rules/xunit.md`; this doc does not duplicate
every item.

---

## 11. Who Runs What, When

Under the immutable-build strategy, the **package is built once** at the
Experimental tier. Every later tier runs tests **against the existing promoted
package**, not against a fresh build. The `UsePackageReferenceForSUT` property
(§3.1) is the mechanism: Experimental-tier and developer runs leave it at the
default (`false` → `<ProjectReference>`); the Development through Production
promotion runs set it to `true` and supply `SUTVersion` matching the exact
package version being promoted.

### 11.1 Developer and Experimental tier — ProjectReference mode

No special flags required. Tests reference the SUT via `<ProjectReference>`:

```powershell
# Developer inner-loop or Experimental-tier CI
dotnet test ATAP.Utilities.sln -c Release `
    --logger trx `
    --results-directory _generated\testresults\experimental
```

The Experimental tier builds and pushes the package to the Experimental feed,
but also runs `Category=Unit` tests in ProjectReference mode as a fast
pre-push gate. The artifact produced here is the package that travels
unchanged through all subsequent tiers.

### 11.2 Development–Production tiers — PackageReference mode (promoted artifact)

The BuildMaster pipeline for each promotion tier must:

1. Restore the promoted package from the tier's ProGet feed — it does
   **not** rebuild from source.
2. Run `dotnet test` with `UsePackageReferenceForSUT=true` and
   `SUTVersion` set to the package version under promotion.
3. Pass `--no-build` only if the test project binaries were already
   produced in the same pipeline step; otherwise omit it.

Locked restore policy:

- Development restore is intentionally unlocked. It is the first promotion tier
  that switches the test project from source `<ProjectReference>` mode to
  promoted-package `<PackageReference>` mode, so the build workspace must be
  allowed to materialize the exact per-build `SUTVersion` in `packages.lock.json`.
- Integration, QA, and Production restore with `--locked-mode` through
  `Invoke-PromotedPackageTests -LockedRestore`. Those tiers must consume the
  same promoted-package lock state and fail instead of silently changing package
  resolution.

Example BuildMaster PowerShell step (Development tier / alpha, unit tests
only as an illustration; adjust `--filter` per the tier table in §4):

```powershell
# Variables supplied by BuildMaster release plan
$version   = $ReleaseNumber          # e.g. "1.2.3"
$tierLabel = "alpha"

dotnet test ATAP.Utilities.sln `
    -c Release `
    /p:UsePackageReferenceForSUT=true `
    /p:SUTVersion=$version `
    --filter "Category=Unit" `
    --logger trx `
    --results-directory "_generated\testresults\$tierLabel"
```

> **Note on `--no-build`:** Because the project file's `<ItemGroup>` switches
> from `<ProjectReference>` to `<PackageReference>` when
> `UsePackageReferenceForSUT=true`, a rebuild **is** required the first time
> this flag changes. Do not pass `--no-build` unless the test assemblies were
> already compiled against the promoted package in the same agent session.

### 11.3 Tier summary

| Trigger                            | `UsePackageReferenceForSUT` | `SUTVersion`     | Locked restore | Scope                                   | Where it runs     |
| ---------------------------------- | --------------------------- | ---------------- | -------------- | --------------------------------------- | ----------------- |
| Developer pre-commit               | `false` (default)           | N/A              | No             | Affected project's unit tests           | Workstation       |
| Developer before push              | `false` (default)           | N/A              | No             | Full `dotnet test` for the repo         | Workstation       |
| BuildMaster Experimental (sprint)  | `false` (default)           | N/A              | No             | `Category=Unit` — **build + push only** | BuildMaster agent |
| BuildMaster Development (alpha)    | `true`                      | promoted version | No             | All tests                               | BuildMaster agent |
| BuildMaster Integration (beta)     | `true`                      | promoted version | Yes            | Unit + Integration                      | BuildMaster agent |
| BuildMaster QA (qa)                | `true`                      | promoted version | Yes            | Full suite with coverage                | BuildMaster agent |
| BuildMaster Production (stable)    | `true`                      | promoted version | Yes            | Smoke subset only                       | BuildMaster/Release agent |

Developer pre-commit is an informal norm, not a hard gate — the sprint
worktree branch has no server-side push policy. CI-side gates begin at the
Experimental tier.

### 11.4 DB-backed integration tests against a promoted package

The promoted `.nupkg` carries the system-under-test assemblies **only** — it
holds no connection string and no knowledge of which database tier it is
being exercised against. The `UsePackageReferenceForSUT` swap (§3.1) changes
*where the SUT assembly is resolved from*; it does **not** change *how a test
obtains its database connection*. DB-backed integration tests therefore get
their connection input the same way in ProjectReference mode and in
PackageReference mode:

1. A test never hard-codes a connection string and never reads one out of
   the package.
2. The connection string lives in a Bitwarden Secure Note whose name follows
   [SprintInfrastructure-Naming.md §4](SprintInfrastructure-Naming.md#4-bitwarden-connection-string-secret-naming).
3. The pipeline (or the developer, locally) passes the **secret name** — not
   the secret value — to the test step in the `ATAPUTILITIES_DB_SECRET_NAME`
   environment variable. The `Fixture.Database` fixture from
   `ATAP.Utilities.Testing` (§8.1) reads that variable and resolves the name
   to a live connection string at run time.
4. If `ATAPUTILITIES_DB_SECRET_NAME` is unset, DB-backed integration tests
   **skip** (they do not fail) — matching the "no live dependency → skip"
   convention used for other integration dependencies.

| Tier                     | Bitwarden secret-name form                                    | SQL instance            |
| ------------------------ | ------------------------------------------------------------- | ----------------------- |
| Developer / Experimental | `dbConnectionString-ATAPUtilities-<Host>-Experimental-<User>` | `<Host>\Exp<username>`  |
| Development (alpha)      | `dbConnectionString-ATAPUtilities-<Host>-Development-<User>`  | `<Host>\Dev<username>`  |
| Integration (beta)       | `dbConnectionString-ATAPUtilities-utat022-Integration`        | `utat022\Integration`   |
| QA                       | `dbConnectionString-ATAPUtilities-utat022-QA`                 | `utat022\QA`            |
| Production (smoke)       | `dbConnectionString-ATAPUtilities-utat022-Production`         | `utat022\Production`    |

The BuildMaster release plan holds the name in its per-tier variable (for the
Integration tier this is the existing `IntegrationDatabaseDBConnectionStringSecretName`
stable variable; see [SprintInfrastructure-Naming.md §6.2](SprintInfrastructure-Naming.md#62-stable-variables-set-once-during-ecosystem-onboarding))
and exports it into the agent process as `ATAPUTILITIES_DB_SECRET_NAME` for
the test step. Locally a developer points the same variable at the
per-sprint, username-suffixed secret created by `New-SprintBitwardenSecrets`.
Either way the value crossing the process boundary is a *name*; the
credential itself is fetched at run time from Bitwarden and never appears in
a build log, package, or test artifact.

---

## 12. Common Failures

### 12.1 `Test project {X} was not found`

- Path in the command line is wrong, or the solution doesn't include the
  project. `dotnet sln list` to confirm.
- The project's name has the `.Exclude` suffix — it was intentionally
  quarantined (§1.1). Look in the `.csproj` for why.

### 12.2 `Could not load file or assembly 'xunit.core'`

- Package restore failed silently. Run `dotnet restore` on the test project
  and re-check. Usually a transient ProGet connectivity issue.
- The test project is targeting a TFM that xUnit doesn't support (e.g.
  `netstandard2.0`). Set `TargetFramework` to `net10.0` (the standard
  across this codebase).

### 12.3 Tests pass locally, fail in BuildMaster

- Machine-specific environment variable is missing on the agent. Check
  `bitwarden`-provisioned vars (`BW_SESSION`, `PROGET_ADMIN_API_KEY`,
  DB connection strings).
- Test's working directory assumption is wrong. Use
  `Path.Combine(AppContext.BaseDirectory, ...)` rather than relative paths.
- Test relies on culture / timezone. Set the culture explicitly in the test
  or pin it via `.runsettings`.

### 12.4 Coverage reports empty

- `coverlet.collector` package reference is missing from the test project.
- `--collect:"XPlat Code Coverage"` was omitted.
- Project under test has no `.pdb` files in `bin/` (check
  `<DebugType>portable</DebugType>` — the default in this codebase, and
  required for coverlet).

### 12.5 `The active test run was aborted`

Usually a dotnet SDK mismatch between the test project's TFM and the
installed SDK. Run `dotnet --info` and confirm the SDK version includes the
target framework.

### 12.6 `Unable to find package 'ATAP.Utilities.Foo' version 'x.y.z'`

Applies only when `UsePackageReferenceForSUT=true`.

- `SUTVersion` was not passed to `dotnet test` or was set incorrectly. Verify
  the BuildMaster variable binding.
- The package has not yet been pushed to the tier's feed. Check the ProGet
  feed for that version and confirm the promotion step completed before the
  test step.
- The NuGet feed is not registered in `nuget.config` or the agent's
  `NuGetSources` variable. Add the tier's ProGet feed URL.

### 12.7 Wrong SUT loaded (ProjectReference vs PackageReference mismatch)

If a promotion-tier test unexpectedly resolves from source (e.g., IntelliSense
shows the wrong assembly path), confirm that `UsePackageReferenceForSUT` was
passed as an MSBuild property (`/p:UsePackageReferenceForSUT=true`), not as an
environment variable. MSBuild properties and environment variables are distinct
in the `dotnet test` invocation; the conditional `<ItemGroup>` in the
`.csproj` only evaluates MSBuild properties.

---

## 13. Test Artifact Lifecycle (summary)

Adapted for the immutable-build model:

1. **Create** — xUnit / Coverlet emit `.trx` and `coverage.cobertura.xml`
   into `_generated/testresults/<tier>/` on the BuildMaster agent.
2. **Local storage** — developer inspects in `_generated/`; never committed.
3. **Attach (not embed)** — BuildMaster attaches each tier's test artifacts
   to the **release record** for the promoted `(PackageId, Version)`. This
   keeps the `.nupkg` byte-identical across tiers.
4. **Bundle (Release Bundle pipeline only)** — when a Release Bundle is
   built from a release-branch tag, the headline test evidence (TRX,
   coverage XML, Flyway-rehearsal log) is embedded into the bundle's
   `tests/` folder. The bundle's release manifest records the
   `checksumSha256` of every embedded test file. See
   [Release-Branch-and-Manifest.md §3](Release-Branch-and-Manifest.md#3-the-manifest-schema).
5. **Retention** — release-record attachments are retained as long as the
   package version exists in ProGet. Bundle-embedded results live for the
   life of the release in `releasebundle-production`.

The key property: **a production release has the test results that
validated it traceable back through the promotion chain** — via BuildMaster
release records for libraries, and via the embedded `tests/` folder for
the Release Bundle that ships to customers.

---

## 14. Related Documents

- [CSharp-Packages-Build-Process.md](CSharp-Packages-Build-Process.md) — build graph that feeds into `dotnet test`.
- [CSharp-Packages-Versioning.md](CSharp-Packages-Versioning.md) — version of the code under test.
- [CSharp-Packages-Pack-and-Push.md](CSharp-Packages-Pack-and-Push.md) — how tests get embedded into published packages.
- [BuildMaster-ProGet-CSharp-Package-Pipeline.md](BuildMaster-ProGet-CSharp-Package-Pipeline.md) — tier-by-tier test orchestration.
- [Production-and-Tooling-Overview.md](Production-and-Tooling-Overview.md) — the index this doc belongs to.
- `_Planning/Explainers/0106-testing-process-and-artifacts.md` — source material; this doc consolidates the C# portions.
- `.claude/rules/xunit.md` — authoring-rule reference.
