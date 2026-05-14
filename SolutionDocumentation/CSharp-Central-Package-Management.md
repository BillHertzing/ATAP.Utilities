# CSharp Central Package Management (CPM)

**Scope:** Sprint-0006/0007. How the four .NET-bearing repos (ATAP.Utilities,
AceCommander, ATAP.IAC, SharedVSCode) centralize NuGet package versions through
`Directory.Packages.props`, including the floating-version strategy for internal
ATAP.Utilities dependencies consumed by AceCommander.

> **Strategy update (sprint-0007 — Immutable Build).** Under the
> immutable-build strategy, the **package being consumed** at any tier is
> the **promoted instance** of the same `(PackageId, Version, SHA-256)` —
> not a tier-specific rebuild. CPM's job is therefore to express
> "AceCommander at Integration consumes the version of `ATAP.Utilities.X`
> that has been promoted to `nuget-integration`." The pinning rules in §6.1
> below are exactly this: floating `0.*-*` is allowed at Experimental and
> Development (where rapid iteration matters) and **pinned versions**
> (resolved by `Set-AceCommanderPackagePins`) are required at Integration,
> QA, and Production (where reproducibility matters). The pinned version is
> the same one that was promoted into the target feed; the consumer does
> not get a "different build" of that version. See
> [Immutable-Build-Strategy.md](Immutable-Build-Strategy.md).

**Audience:** Developers who need to add, upgrade, or pin a NuGet dependency;
anyone investigating NU1507 / NU1008 errors; release engineers promoting package
tiers.

**Status:** Authoritative for sprint-0006. This document supersedes the scattered
notes in `Building.md` and the older `Packaging.md` drafts regarding package
version management. The files referenced in §3 are the source of truth.

**Not in this doc:**

- How versions are generated on _produced_ packages → see
  [CSharp-Packages-Versioning.md](CSharp-Packages-Versioning.md).
- How packages are packed and pushed → see
  [CSharp-Packages-Pack-and-Push.md](CSharp-Packages-Pack-and-Push.md).
- Which ProGet feed is mapped to which prerelease label → see
  [BuildMaster-ProGet-CSharp-Package-Pipeline.md](BuildMaster-ProGet-CSharp-Package-Pipeline.md).
- NuGet feed authentication / API keys → same doc as above.

---

## 1. What CPM is and why we use it

Central Package Management (CPM) is a NuGet feature (NuGet 6.2+, .NET SDK 7+)
that lets a solution declare every package version **once** in a single
`Directory.Packages.props` file at or above the solution root. Individual
`.csproj` files then reference packages without a `Version=` attribute:

```xml
<!-- project.csproj -->
<ItemGroup>
  <PackageReference Include="Serilog" />
  <PackageReference Include="xunit" />
</ItemGroup>
```

The single source of truth lives in `Directory.Packages.props`:

```xml
<ItemGroup Label="Logging">
  <PackageVersion Include="Serilog" Version="4.2.0" />
  <PackageVersion Include="xunit" Version="2.9.3" />
</ItemGroup>
```

We adopted CPM in sprint-0004 for the following reasons:

1. **Version drift elimination** — with 30+ projects per solution, duplicate
   `<PackageReference Version>` entries routinely fell out of sync.
2. **Auditable upgrades** — a single PR touching `Directory.Packages.props`
   shows the full blast radius of a dependency change.
3. **Floating-version support** — CPM is the only place where
   `CentralPackageFloatingVersionsEnabled` has meaning; this is critical for
   AceCommander consuming the internal ATAP.Utilities packages (see §6).

---

## 2. Enabling CPM — the two properties

CPM is enabled by `Directory.Build.props` (or `Directory.Packages.props` itself)
with a single MSBuild property:

```xml
<PropertyGroup>
  <ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>
</PropertyGroup>
```

The optional companion property is set **only** in AceCommander:

```xml
<PropertyGroup>
  <CentralPackageFloatingVersionsEnabled>true</CentralPackageFloatingVersionsEnabled>
</PropertyGroup>
```

This second property allows `<PackageVersion Version="0.*-*" />` in the central
file. Without it, floating ranges in CPM raise NU1011. ATAP.Utilities does
**not** enable floating versions because it is a _producer_ — it pins every
dependency to a concrete version.

---

## 3. File locations

| Repo           | File                                       | Floating enabled |
| -------------- | ------------------------------------------ | ---------------- |
| ATAP.Utilities | `Directory.Packages.props` (solution root) | No               |
| AceCommander   | `Directory.Packages.props` (solution root) | **Yes**          |
| ATAP.IAC       | _(no CPM — PowerShell-centric repo)_       | n/a              |
| SharedVSCode   | _(no CPM — no .csproj files)_              | n/a              |

`Directory.Packages.props` is picked up automatically by MSBuild when it sits
at or above every `.csproj` in the repo. There is intentionally no per-project
override.

---

## 4. Structure: label-grouped ItemGroups

Both CPM files organize `<PackageVersion>` entries into `<ItemGroup Label="...">`
blocks. The label is not semantic to NuGet — it only serves as a reading aid in
the file. ATAP.Utilities uses roughly 20 labels; AceCommander uses ~10.

**Representative ATAP.Utilities groups** (abbreviated):

```xml
<ItemGroup Label="Security Patches">
  <PackageVersion Include="System.Text.Json" Version="9.0.0" />
</ItemGroup>

<ItemGroup Label="ATAP.Utilities.Configuration Family">
  <PackageVersion Include="ATAP.Utilities.Configuration" Version="0.1.0-Alpha-009" />
  <PackageVersion Include="ATAP.Utilities.Configuration.Extensions" Version="0.1.0-Alpha-009" />
</ItemGroup>

<ItemGroup Label="xUnit Testing Suite">
  <PackageVersion Include="xunit" Version="2.4.1" />
  <PackageVersion Include="Microsoft.NET.Test.Sdk" Version="17.0.0" />
  <PackageVersion Include="coverlet.collector" Version="3.1.2" />
</ItemGroup>

<ItemGroup Label="MSBuild Custom Tasks">
  <PackageVersion Include="Nerdbank.GitVersioning" Version="3.9.50" />
</ItemGroup>
```

**Representative AceCommander groups** (full list is shorter):

```xml
<ItemGroup Label="ATAP.Utilities (floating)">
  <PackageVersion Include="ATAP.Utilities.Philote" Version="0.*-*" />
  <PackageVersion Include="ATAP.Utilities.Configuration" Version="0.*-*" />
  <PackageVersion Include="ATAP.Utilities.ETW" Version="0.*-*" />
  <!-- all internal ATAP.Utilities packages use 0.*-* -->
</ItemGroup>

<ItemGroup Label="Blazor / ASP.NET Core">
  <PackageVersion Include="Microsoft.AspNetCore.Components.WebAssembly" Version="10.0.2" />
</ItemGroup>

<ItemGroup Label="Syncfusion Blazor">
  <PackageVersion Include="Syncfusion.Blazor" Version="32.2.7" />
</ItemGroup>

<ItemGroup Label="Testing">
  <PackageVersion Include="xunit" Version="2.9.3" />
  <PackageVersion Include="bunit" Version="1.39.5" />
  <PackageVersion Include="Microsoft.Playwright.MSTest" Version="1.49.0" />
</ItemGroup>
```

---

## 5. Floating versions — `0.*-*`

This pattern only works in AceCommander and only because
`CentralPackageFloatingVersionsEnabled=true` is set.

**Syntax**: `0.*-*` means "the highest `0.x.y.z` version, including any
prerelease label." The first wildcard floats the numeric components; the
second wildcard (`-*`) opts into prerelease versions.

**Effect during restore:**

- `dotnet restore` queries the configured ProGet feed(s).
- The feed returns every available version of `ATAP.Utilities.Philote`.
- NuGet picks the highest one matching `0.*-*`, which is typically the
  freshest `Sprint` prerelease built minutes ago on the developer's machine
  and pushed to the T1/Experimental feed.

**Why we want this**: AceCommander is a _consumer_ of the internal ATAP.Utilities
packages. During active development we want every `dotnet build` to pull the
latest sprint build without editing `Directory.Packages.props`.

**Why this is dangerous in CI**: restore is non-deterministic by definition.
Two consecutive CI runs can resolve different versions of the same floating
reference. Mitigation: `packages.lock.json` (see §8).

---

## 6. The two-repo consumer contract

The contract between ATAP.Utilities (producer) and AceCommander (consumer) is:

1. ATAP.Utilities builds a set of packages with version
   `0.{major}.{minor}-Sprint.{height}` (see
   [CSharp-Packages-Versioning.md](CSharp-Packages-Versioning.md) §4).
2. The packages are pushed to ProGet's T1 feed (see
   [CSharp-Packages-Pack-and-Push.md](CSharp-Packages-Pack-and-Push.md) §7).
3. AceCommander's floating `0.*-*` restore picks up the new version on next
   `dotnet restore`.
4. If the new version breaks AceCommander, the fix is to pin the specific
   offending package in AceCommander's `Directory.Packages.props` temporarily:

   ```xml
   <PackageVersion Include="ATAP.Utilities.Philote" Version="0.1.0-Sprint.42" />
   ```

   and file a follow-up to unpick it once the upstream issue is resolved.

### 6.1 Version-pinning rule at T3 (Integration) and above

**Rule:** Floating version patterns (`0.*-*`) are **only permitted** at T1
(Experimental) and T2 (Development). At T3 (Integration), T4 (QA), and T5
(Stable/Production), every `ATAP.*` entry in AceCommander's
`Directory.Packages.props` **must** be pinned to a concrete version before
`dotnet restore` is called.

| Tier        | Feed                | Floating `0.*-*` allowed? |
| ----------- | ------------------- | ------------------------- |
| Experimental (T1) | `nuget-experimental` | Yes — default working-copy state |
| Development (T2) | `nuget-development`  | Yes — resolves latest Alpha build |
| Integration (T3) | `nuget-integration`  | **No** — must be pinned |
| QA (T4)         | `nuget-qa`           | **No** — must be pinned |
| Stable (T5)     | `nuget-stable`       | **No** — must be pinned |

**Why:** Non-deterministic restores at T3+ undermine the purpose of
integration gating. Two consecutive QA builds could consume different
package versions, making failures unreproducible.

**How (in CI):** The BuildMaster QA stage runs
`Set-AceCommanderPackagePins.ps1` as its first step. The script resolves
each floating entry to the highest concrete version available in the target
feed and rewrites `Directory.Packages.props` in the agent workspace before
`dotnet restore` / `dotnet build` are called. The working-copy file retains
its floating patterns — only the CI agent copy is mutated.

**How (manually):** A developer promoting a branch to Integration or QA
may run:

```powershell
Set-AceCommanderPackagePins `
    -ProGetUrl 'http://proget.local:50000' `
    -FeedName 'nuget-integration'
```

and commit the pinned `Directory.Packages.props` to the promotion branch.

### 6.2 Resolving "latest in feed X" under immutable build

Under the immutable-build strategy a promoted artifact is visible in
every feed it has reached, so a floating reference does not distinguish
"pushed here" from "promoted here":

> Under immutable build, "latest in feed X" means "highest version
> visible through feed X's resolution chain." A floating `0.*-*`
> reference will always pick up the highest version, regardless of
> whether that version was originally pushed to feed X or promoted into
> it. This is intentional — once promoted, the artifact has feed-X
> identity. Consumers who want "the latest version that has not yet been
> promoted out of feed X" must filter by prerelease label (e.g.
> `0.*-Sprint*`).

See [Immutable-Build-Strategy.md](Immutable-Build-Strategy.md) §6.3 for
the producer-side statement of the same rule.

---

## 7. Package source mapping (NU1507)

NuGet 6.x requires `packageSourceMapping` in `NuGet.config` whenever multiple
feeds are configured. Without mapping, restore raises **NU1507**: "There are
N package sources defined. Please map the package sources."

The mapping is declared in each repo's `NuGet.config` (not in
`Directory.Packages.props`):

```xml
<packageSourceMapping>
  <packageSource key="ProGet-T1-Experimental">
    <package pattern="ATAP.*" />
  </packageSource>
  <packageSource key="nuget.org">
    <package pattern="*" />
  </packageSource>
</packageSourceMapping>
```

CPM does not interact directly with this — but the pairing matters:

- Every `PackageVersion` Include in `Directory.Packages.props` must resolve
  to exactly **one** feed via `packageSourceMapping`.
- The `ATAP.*` pattern claims every `ATAP.Utilities.*` name from the internal
  feed; `*` catches everything else from nuget.org.

See [BuildMaster-ProGet-CSharp-Package-Pipeline.md](BuildMaster-ProGet-CSharp-Package-Pipeline.md)
§5 for the full `NuGet.config` reference.

---

## 8. Interaction with `packages.lock.json`

CPM and lock files compose but are not automatic. To enable reproducible restore:

```xml
<!-- Directory.Build.props -->
<PropertyGroup>
  <RestorePackagesWithLockFile>true</RestorePackagesWithLockFile>
  <RestoreLockedMode Condition="'$(ContinuousIntegrationBuild)' == 'true'">true</RestoreLockedMode>
</PropertyGroup>
```

Current status:

- **ATAP.Utilities**: lock files enabled per project — committed to git.
- **AceCommander**: lock files **not yet enabled** (a known gap — tracked in
  `_Planning/TASKS.md`). Floating versions without lock files mean CI restores
  are non-deterministic.

---

## 9. Interaction with `ConstrainATAPPackageDependencyVersionRange`

`Directory.Build.targets` in ATAP.Utilities contains a custom target
`ConstrainATAPPackageDependencyVersionRange` that rewrites the `$version$` token
emitted into `.nuspec` dependency entries during `dotnet pack`. It replaces the
concrete consumer version (e.g., `0.1.0-Sprint.42`) with a range expression
like `[0.1.0, 1.0.0)`.

CPM does **not** override this behavior. The consumer's resolved version feeds
the target; the target then emits the range into the _produced_ package's
`.nuspec`. This is how we decouple "what AceCommander restored during build"
from "what the published ATAP.Utilities package declares as its dependency."

See [CSharp-Packages-Pack-and-Push.md](CSharp-Packages-Pack-and-Push.md) §8 for
the full pack-time rewriting flow.

---

## 10. Migrating a project into CPM

When a new `.csproj` is added to either repo:

1. Confirm `Directory.Packages.props` exists at or above the project path.
2. Write `<PackageReference Include="X" />` — **no `Version=` attribute**.
3. If the package is not yet in `Directory.Packages.props`, add a
   `<PackageVersion Include="X" Version="..." />` to the appropriate labeled
   `ItemGroup`.
4. Run `dotnet restore` — any `NU1008` ("Projects that use central package
   version management should not define the version on the PackageReference
   items") indicates a forgotten `Version=` attribute in the `.csproj`.

---

## 11. Known drift (sprint-0006)

1. **Test-framework version skew** — ATAP.Utilities pins `xunit` at `2.4.1`
   and `Microsoft.NET.Test.Sdk` at `17.0.0`. AceCommander uses `xunit` `2.9.3`
   and `Microsoft.NET.Test.Sdk` `17.12.0`. The older versions in ATAP.Utilities
   are load-bearing for the legacy `MakeBuild` custom task path and have not
   been upgraded because the upgrade requires regenerating test fixtures under
   `ATAP.Utilities.Testing`.

2. **AceCommander lacks lock files** — floating `0.*-*` without a lock file
   means no two CI restores are guaranteed identical.

3. **Some `.csproj` still carry `Version=` attributes** — mostly in older
   projects under `tests/` that predate CPM adoption. A one-shot cleanup is
   pending (tracked as sprint-0006 follow-up).

4. **Security-patch group is out of order** — `System.Text.Json` 9.0.0 is
   pinned in ATAP.Utilities for the transitive-dependency CVE fix even though
   the library itself targets `net8.0`. This is deliberate and should not be
   "fixed" to match the target framework.

5. **`ATAP.Utilities.Configuration` family pinned, not floating** — inside
   ATAP.Utilities itself, the Configuration sub-packages are pinned to
   `0.1.0-Alpha-009` rather than using same-repo ProjectReferences. This is
   a known anti-pattern carried from the pre-CPM era; replacing these with
   `<ProjectReference>` is a tracked cleanup item.

---

## 12. Common failures and remedies

| Error                      | Cause                                                                 | Fix                                                                     |
| -------------------------- | --------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| NU1008                     | `<PackageReference Version="..."/>` present alongside CPM             | Remove `Version=` from the `.csproj`; add to `Directory.Packages.props` |
| NU1011                     | Floating version used without `CentralPackageFloatingVersionsEnabled` | Only valid in AceCommander; pin the version in ATAP.Utilities instead   |
| NU1507                     | Multiple sources in `NuGet.config`, no `packageSourceMapping`         | Add a `packageSourceMapping` entry for every source                     |
| NU1601                     | Restore resolved a version outside the range declared in CPM          | Update the `PackageVersion` entry in `Directory.Packages.props`         |
| NU1603                     | Floating reference resolved a higher version than requested           | Expected when `0.*-*` is used; not an error in AceCommander             |
| `PackageVersion` not found | New `PackageReference` added to `.csproj` without CPM entry           | Add matching `<PackageVersion>` in `Directory.Packages.props`           |

---

## 13. Quick reference

**Add a new third-party package**:

```xml
<!-- Directory.Packages.props -->
<ItemGroup Label="{choose or create label}">
  <PackageVersion Include="Foo.Bar" Version="1.2.3" />
</ItemGroup>

<!-- MyProject.csproj -->
<ItemGroup>
  <PackageReference Include="Foo.Bar" />
</ItemGroup>
```

**Add a new internal ATAP.Utilities package reference from AceCommander**:

```xml
<!-- AceCommander/Directory.Packages.props -->
<ItemGroup Label="ATAP.Utilities (floating)">
  <PackageVersion Include="ATAP.Utilities.{NewName}" Version="0.*-*" />
</ItemGroup>
```

**Pin an ATAP.Utilities package temporarily in AceCommander**:

```xml
<!-- AceCommander/Directory.Packages.props -->
<PackageVersion Include="ATAP.Utilities.Philote" Version="0.1.0-Sprint.42" />
```

---

## Related Documents

- [Production-and-Tooling-Overview.md](Production-and-Tooling-Overview.md) — index.
- [CSharp-Packages-Versioning.md](CSharp-Packages-Versioning.md) — how producer
  versions are generated.
- [CSharp-Packages-Pack-and-Push.md](CSharp-Packages-Pack-and-Push.md) — how
  packages are packed and pushed to ProGet.
- [CSharp-Packages-Test-Process.md](CSharp-Packages-Test-Process.md) — how C#
  tests are structured and executed.
- [BuildMaster-ProGet-CSharp-Package-Pipeline.md](BuildMaster-ProGet-CSharp-Package-Pipeline.md)
  — CI/CD promotion through 5 ProGet feed tiers.
