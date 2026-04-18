# C# Packages — Pack and Push

**Scope:** Producing `.nupkg` / `.snupkg` files from `ATAP.Utilities.*` and
`AceCommander.*` C# projects and pushing them to the correct ProGet feed for a
given pipeline tier.
**Audience:** Developers cutting packages locally; maintainers of the
`Publish-ATAPUtilities.ps1` helper; anyone troubleshooting a failed push.
**Status:** Authoritative. Consolidates pack/push content from
`BuildMaster-ProGet-CSharp-Package-Pipeline.md`, `Building.md`, and
`src/ATAP.Utilities.BuildTooling.PowerShell/public/Publish-ATAPUtilities.ps1`.

**Not in this doc:**

- How versions are computed / promoted (→ `CSharp-Packages-Versioning.md`).
- MSBuild target wiring that prepares the project for packing
  (→ `CSharp-Packages-Build-Process.md`).
- BuildMaster OtterScript orchestration across the 5 tiers
  (→ `BuildMaster-ProGet-CSharp-Package-Pipeline.md`).
- Central Package Management for consumers (→ `CSharp-Central-Package-Management.md`).

---

## 1. What "pack" Actually Produces

`dotnet pack <project>` runs the `Pack` MSBuild target and writes two files per
packable project:

| File            | Contents                                                           | When produced                          |
| --------------- | ------------------------------------------------------------------ | -------------------------------------- |
| `*.nupkg`       | The library DLL, transitive metadata (`.nuspec`), icons, readme.   | Always, when `IsPackable != false`.    |
| `*.snupkg`      | PDB symbols + SourceLink metadata for debugger step-into.          | Only when `IncludeSymbols=true`.        |

Both are zip files — renameable to `.zip` and inspectable with any archive tool.
The `.nuspec` inside the `.nupkg` is an XML manifest generated from the
`.csproj` properties documented in §3.

The output folder is controlled by `-o|--output`; the default is
`bin/<Config>/<TFM>/`. Consuming the output via a repo-relative path keeps all
generated artifacts under `_generated/nuget/` per the SC-0033 rule:

```powershell
dotnet pack src\ATAP.Utilities.Philote\ATAP.Utilities.Philote.csproj `
    --configuration Release `
    --output _generated\nuget\local
```

---

## 2. Packable vs Non-Packable Projects

Not every project in the solution is shipped. The current inventory in
[BuildMaster-ProGet-CSharp-Package-Pipeline.md §1.1](BuildMaster-ProGet-CSharp-Package-Pipeline.md#11-project-families) classifies them:

| Category                    | Example                           | `IsPackable` | Goes to ProGet? |
| --------------------------- | --------------------------------- | ------------ | --------------- |
| Console apps                | `ATAP.Console.HelloWorld`         | `false`      | No              |
| Service libraries (§1.1b)   | `ATAP.Services.ConsoleMonitor`    | `true`       | Yes             |
| Utility libraries (§1.1c)   | `ATAP.Utilities.ETW`              | `true`       | Yes             |
| Meta-package (§1.1d)        | `ATAP.Utilities`                  | `true`       | Yes             |
| Unit test projects          | `ATAP.Utilities.Testing.UnitTests`| `false`      | No              |

`IsPackable` defaults to `true` for SDK-style projects. Console and test
projects set it to `false` explicitly in their `.csproj`. If a library project
is missing from ProGet after a push step, check this property first.

---

## 3. NuGet Metadata Applied at Pack Time

These properties — most from `Directory.Build.props`, some per-project — end up
inside the generated `.nuspec`:

| MSBuild property               | Current value (in `Directory.Build.props`)         |
| ------------------------------ | -------------------------------------------------- |
| `Company`                      | _(empty)_                                          |
| `Copyright`                    | `William Hertzing`                                 |
| `Authors`                      | `William Hertzing`                                 |
| `Product` / `ProductName`      | `ATAP.Utilities`                                   |
| `RepositoryUrl`                | `https://github.com/BillHertzing/ATAP.Utilities`   |
| `RepositoryType`               | `GitHub`                                           |
| `PackageLicenseExpression`     | `MIT`                                              |
| `PackageProjectUrl`            | `www.project.url` _(placeholder — see §10)_        |
| `PackageIconUrl`               | `www.icon.url` _(placeholder — see §10)_           |
| `PackageTags`                  | `Testing, experimental, alpha, ATAP, ATAP.Utilities` |
| `PackageReleaseNotes`          | `Initial implementation/test of ATAP.Utilities Nuget packaging` |
| `Version` / `PackageVersion`   | Computed (see `CSharp-Packages-Versioning.md`).    |
| `PackageId`                    | Defaults to `$(AssemblyName)`.                     |

**Per-project overrides:** Any `.csproj` can set `Description`, `Title`,
`PackageId`, `PackageTags`, or `PackageReleaseNotes` in its own `PropertyGroup`
to override the solution-wide defaults. The meta-package
(`src/ATAP.Utilities/ATAP.Utilities.csproj`) is an example — it sets its own
`Description` explaining the roll-up purpose.

---

## 4. Symbols and SourceLink

SourceLink is enabled via `Microsoft.SourceLink.GitHub` in `Directory.Build.targets`
and two properties in `Directory.Build.props`:

```xml
<AllowedOutputExtensionsInPackageBuildOutputFolder>$(AllowedOutputExtensionsInPackageBuildOutputFolder);.pdb</AllowedOutputExtensionsInPackageBuildOutputFolder>
<EmbedUntrackedSources>true</EmbedUntrackedSources>
```

### 4.1 Producing a symbol package

Add these properties per-project (or at solution scope) to also generate a
`.snupkg`:

```xml
<PropertyGroup>
  <IncludeSymbols>true</IncludeSymbols>
  <SymbolPackageFormat>snupkg</SymbolPackageFormat>
</PropertyGroup>
```

The resulting `<Package>.<Version>.snupkg` lives next to the `.nupkg` in the
output folder. `dotnet nuget push` will pick up `.snupkg` files automatically
when you push `*.nupkg` — ProGet accepts and indexes symbol packages on a
separate symbol server endpoint.

### 4.2 Debugger step-into

With SourceLink in place, Visual Studio or VS Code consumers of an ATAP.*
package can step into the library's source code without a local clone — the
debugger fetches the matching source revision from GitHub using the embedded
SourceLink URLs.

---

## 5. The Local Dev Loop

Typical workflow for an experimental change inside a sprint worktree:

```powershell
# 1) Build — NBGV computes version, tasks generate AssemblyInfo attributes
dotnet build src\ATAP.Utilities.ETW\ATAP.Utilities.ETW.csproj -c Release

# 2) Pack — produces ATAP.Utilities.ETW.0.1.0-Sprint.47.nupkg into _generated
dotnet pack src\ATAP.Utilities.ETW\ATAP.Utilities.ETW.csproj `
    -c Release --no-build `
    -o _generated\nuget\local

# 3) Inspect the filename to confirm the right version label
Get-ChildItem _generated\nuget\local -Filter '*.nupkg' |
    Select-Object -ExpandProperty Name

# 4) Push to experimental feed
$apiKey = [System.Environment]::GetEnvironmentVariable('PROGET_ADMIN_API_KEY', 'User')
dotnet nuget push _generated\nuget\local\*.nupkg `
    --source http://localhost:50000/nuget/nuget-experimental/v3/index.json `
    --api-key $apiKey
```

Use `--no-build` on the `pack` step when you've just run `build` — skipping the
rebuild is faster and guarantees you pack the exact artifact that was just
compiled.

### 5.1 "GeneratePackageOnBuild" shortcut

Several projects set `<GeneratePackageOnBuild>true</GeneratePackageOnBuild>` so
that every `dotnet build` automatically produces a `.nupkg`. This is convenient
during tight dev loops but adds a small build-time cost. Turn it off when
profiling builds or when you want to defer packing to a dedicated `pack`
command.

---

## 6. The `Publish-ATAPUtilities.ps1` Helper

Location: `src/ATAP.Utilities.BuildTooling.PowerShell/public/Publish-ATAPUtilities.ps1`.
(A top-level symlink / copy exists at `Publish-ATAPUtilities.ps1` in the repo
root for convenience.)

### 6.1 What it does

- Builds a curated list of library `.csproj` files in **dependency order**
  (dependencies first).
- Uses the MSBuild pipeline's `PublishAfterBuild` target, which chains
  `Build → Pack → Push` in one `dotnet build` invocation, driven by
  `GeneratePackageOnBuild=true`.
- Pushes to `nuget-experimental` by default. The destination URL is override-able
  via `-p:ProGetExperimentalFeedUrl=<url>`.

### 6.2 Prerequisites

- `PROGET_ADMIN_API_KEY` must be set at **User** scope in Windows environment
  variables. `LoginScript.ps1` provisions it from Bitwarden during normal
  shell startup.
- ProGet Inedo Hub running at `http://localhost:50000` (or the override URL).
- A clean working tree with all `version.json` files reflecting the intended
  tier label (see Versioning doc).

### 6.3 Usage

```powershell
# Standard: publish all libraries in the list to nuget-experimental
.\src\ATAP.Utilities.BuildTooling.PowerShell\public\Publish-ATAPUtilities.ps1

# Verbose custom-task logging
.\...\Publish-ATAPUtilities.ps1 -DebugVerbosity Debug

# Dry run — show what would be built, don't execute
.\...\Publish-ATAPUtilities.ps1 -WhatIf
```

### 6.4 The curated library list

The script's `$libraries` array is the source of truth for which packages are
ready to publish via this path. Currently (sprint-0006):

```text
src\ATAP.Utilities.ETW\ATAP.Utilities.ETW.csproj
src\ATAP.Utilities.Configuration.Extensions\ATAP.Utilities.Configuration.Extensions.csproj
```

This list grows as libraries are onboarded. The order matters — a library must
appear after any library it `ProjectReference`s, because pushing to
nuget-experimental makes the upstream package visible for the downstream
project's subsequent pack. Add new entries at the end of the chain.

### 6.5 When to prefer `dotnet nuget push` directly

The helper script is optimized for the **full local publish** loop. For a
single package or a one-off push, the explicit `pack` + `push` sequence in §5 is
easier to debug and does not require editing the `$libraries` list.

---

## 7. Feed Topology and Tier → Feed Mapping

Single ProGet instance at `http://localhost:50000`. Five feeds, one per tier:

| Tier | Feed name            | Push URL                                                     |
| ---- | -------------------- | ------------------------------------------------------------ |
| T1   | `nuget-experimental` | `http://localhost:50000/nuget/nuget-experimental/v3/index.json` |
| T2   | `nuget-development`  | `http://localhost:50000/nuget/nuget-development/v3/index.json`  |
| T3   | `nuget-integration`  | `http://localhost:50000/nuget/nuget-integration/v3/index.json`  |
| T4   | `nuget-qa`           | `http://localhost:50000/nuget/nuget-qa/v3/index.json`           |
| T5   | `nuget-stable`       | `http://localhost:50000/nuget/nuget-stable/v3/index.json`       |

The 5-tier feed names in `NuGet.config` intentionally **do not** include the
sprint number. Per-sprint isolation is achieved through different mechanisms —
see Versioning doc §3 and the BuildMaster doc's feed-connector topology.

### 7.1 Connectors (read-only chain)

Set in the ProGet admin UI; also documented in
[BuildMaster-ProGet-CSharp-Package-Pipeline.md §2.2](BuildMaster-ProGet-CSharp-Package-Pipeline.md#22-feed-connector-topology):

```text
nuget-experimental  ← connector ← nuget.org            (upstream fetch)
nuget-development   ← connector ← nuget-experimental   (chained)
                                ← nuget.org
nuget-integration   ← connector ← nuget-development    (hermetic — NO nuget.org)
nuget-qa            ← connector ← nuget-integration    (hermetic — NO nuget.org)
nuget-stable        ← connector ← nuget.org            (public restore)
```

Consumers point their `NuGet.config` at **one** feed per tier. The connector
makes upstream packages resolvable through that one source.

---

## 8. `NuGet.config` — the Consumer-Side Contract

Every repo ships a `NuGet.config` at its root. This file has **two** jobs:

1. Tell `dotnet restore` which feeds are available for reads.
2. Tell NuGet's package-source-mapping which packages come from which feed.

### 8.1 Sprint-branch `NuGet.config`

The one currently in the ATAP.Utilities sprint-0006 worktree lists **all five**
feeds as package sources. This is convenient during development — a sprint
worktree may need to restore a Beta or Alpha dependency while iterating.

**Package source mapping** (required by NuGet when CPM is active — see §8.3):

```xml
<packageSourceMapping>
  <packageSource key="nuget.org">
    <package pattern="*" />
  </packageSource>
  <packageSource key="nuget-experimental"><package pattern="ATAP.*" /></packageSource>
  <packageSource key="nuget-development" ><package pattern="ATAP.*" /></packageSource>
  <packageSource key="nuget-integration" ><package pattern="ATAP.*" /></packageSource>
  <packageSource key="nuget-qa"          ><package pattern="ATAP.*" /></packageSource>
  <packageSource key="nuget-stable"      ><package pattern="ATAP.*" /></packageSource>
</packageSourceMapping>
```

This pinning guarantees:

- `ATAP.*` packages are **only** resolved from local ProGet feeds.
- Third-party packages (`Microsoft.*`, `Syncfusion.*`, etc.) are **only**
  resolved from `nuget.org`.
- A typo in a package name can never silently fall through to a wrong source.

### 8.2 Per-branch `NuGet.config` discipline

- **Sprint / Experimental branch** (e.g. `34-sprint-0006-work-items`): all five
  feeds.
- **Integration branch**: only `nuget-integration`, `nuget-qa`, `nuget-stable`,
  `nuget.org`.
- **QA branch**: only `nuget-qa`, `nuget-stable`, `nuget.org`.
- **Main branch**: only `nuget-stable`, `nuget.org`.

This keeps branch-appropriate consumption hermetic. A merge to `integration`
drops the sprint-local feeds; a merge to `main` drops everything except public
and stable.

### 8.3 `packageRestore` and CPM coupling

```xml
<packageRestore>
  <add key="enabled"   value="True" />
  <add key="automatic" value="True" />
</packageRestore>
```

Explicit `True` here overrides any machine-level `%ProgramData%\NuGet\Config`
that might have restrictive defaults on CI runners. The block is required when
Central Package Management (`Directory.Packages.props`, see CPM doc) is in use
because NuGet warning `NU1507` escalates without it.

### 8.4 Anonymous reads, API key for push

- All five feeds permit anonymous read. No `<packageSourceCredentials>` section
  is needed.
- `dotnet nuget push` requires the ProGet admin API key, via `--api-key`. Store
  it only in Bitwarden; load it only via the `PROGET_ADMIN_API_KEY` env var;
  never commit it.

---

## 9. Push Command Reference

### 9.1 Single package, single feed

```powershell
$apiKey = [System.Environment]::GetEnvironmentVariable('PROGET_ADMIN_API_KEY', 'User')
dotnet nuget push .\path\to\ATAP.Utilities.ETW.0.1.0-Sprint.47.nupkg `
    --source http://localhost:50000/nuget/nuget-experimental/v3/index.json `
    --api-key $apiKey
```

### 9.2 All `.nupkg` in a folder

```powershell
dotnet nuget push _generated\nuget\local\*.nupkg `
    --source http://localhost:50000/nuget/nuget-experimental/v3/index.json `
    --api-key $apiKey `
    --skip-duplicate
```

`--skip-duplicate` prevents the push from erroring on packages that already
exist at the exact same version — useful when re-running a partial publish
where some packages already made it through.

### 9.3 Via feed *name* (not URL)

If the source is already defined in `NuGet.config`, the feed name alone is
accepted:

```powershell
dotnet nuget push .\*.nupkg --source nuget-experimental --api-key $apiKey
```

This is the form used by BuildMaster's OtterScript — the feed name resolves via
the checked-out `NuGet.config`, so the same command works on every tier
without hardcoding URLs.

### 9.4 Pushing symbol packages

`.snupkg` files alongside `.nupkg` files are pushed automatically. To push
**only** the symbol package separately:

```powershell
dotnet nuget push .\ATAP.Utilities.ETW.0.1.0-Sprint.47.snupkg `
    --source http://localhost:50000/nuget/nuget-experimental/v3/index.json `
    --api-key $apiKey
```

---

## 10. Known Drift and Open Items

The state below is specific to sprint-0006 and is recorded here so that pack
output can be evaluated without surprises.

- **`PackageProjectUrl` placeholder.** `Directory.Build.props` line 92 has
  `www.project.url`. Every `.nupkg` currently ships with this literal string.
  Real URL should be the GitHub repo page or a GitHub Pages site; fix as a
  one-line edit during a pack-cleanup task.
- **`PackageIconUrl` placeholder.** Same issue on line 93. Also note that
  `PackageIconUrl` has been *deprecated* in favor of `PackageIcon` (embedded
  file reference) since NuGet 5.3. Recommended fix: remove `PackageIconUrl`,
  embed an icon file, and reference it with `<PackageIcon>icon.png</PackageIcon>`.
- **Release notes are generic.** `PackageReleaseNotes` is the same placeholder
  string across every package. Consider making this a computed property (e.g.
  a link to `https://github.com/.../releases/tag/{Version}`) so consumers can
  find actual release notes per-version.
- **Tags are experimental-flavored.** `Testing, experimental, alpha, ATAP,
  ATAP.Utilities` is accurate today but should be tightened to
  `ATAP, ATAP.Utilities, <category>` once packages hit `nuget-stable`.
- **`PackageIcon` embedding not yet implemented.** See §4 / §10 above — ship
  an icon as `<None Include="icon.png" Pack="true" PackagePath=""/>` and
  reference it via `<PackageIcon>icon.png</PackageIcon>`.
- **`PackageReadmeFile` not yet set.** A package-level README embedded into the
  `.nupkg` (`<PackageReadmeFile>README.md</PackageReadmeFile>`) would render in
  ProGet's package detail page. None of the current packages carry one.

---

## 11. Common Failures

### 11.1 `401 Unauthorized` on push

- Empty `PROGET_ADMIN_API_KEY` — `LoginScript.ps1` did not run, or the env var
  is at Process scope rather than User scope.
- Wrong feed name in the URL — `nuget-experimental` is one hyphenated token,
  not `nuget/experimental`.
- ProGet has `Require API key for push` enabled but the `--api-key` flag was
  omitted.

### 11.2 `409 Conflict`

The exact `(PackageId, Version)` already exists in the target feed. Either:

- Add `--skip-duplicate` to the push command (preferred for re-runs), or
- Bump the version. In the NBGV workflow this means producing the next
  `{height}` by committing a new filtered change.

### 11.3 `NU5017 — Cannot create a package that has no dependencies nor content`

The project has no source files and no `<PackageReference>` entries. This
applies to the meta-package (`src/ATAP.Utilities/ATAP.Utilities.csproj`) if
all of its PackageReferences are missing — SDK-style projects rely on the
meta-package having *something* to ship. Either add `<EnableDefaultItems>false</EnableDefaultItems>`
with real PackageReferences, or set `<IncludeBuildOutput>false</IncludeBuildOutput>`.

### 11.4 `NU5024 — The version string is not a valid SemVer 2.0 version`

A prerelease identifier is zero-padded (e.g. `Alpha.007`). SemVer 2.0 treats
zero-padded tokens as invalid numeric identifiers. Fix in `version.json` —
never hand-write `{height}` with padding.

### 11.5 Package pushes but doesn't appear in feed listing

- Feed's `Drop-older-prerelease` setting may have pruned the upload as an
  older prerelease than something already there.
- Browser cache on the ProGet UI. Hard-refresh the feed page.
- Verify via API: `Invoke-RestMethod http://localhost:50000/nuget/nuget-experimental/v3/index.json`.

### 11.6 "The package 'X' is not listed in the package source"

NuGet's package-source-mapping block rejected the lookup. Check `NuGet.config`
§8.1 — if an `ATAP.*` package is being requested, only the ATAP.* mapping
applies; `nuget.org` will not be consulted.

---

## 12. Security

- The ProGet API key is equivalent to a write token — leaking it lets any
  actor push arbitrary packages to production feeds. **Never** commit it,
  log it to stdout, or paste it into issue comments.
- `dotnet nuget push` does not redact `--api-key` in its verbose output. Use
  `--api-key $env:PROGET_ADMIN_API_KEY` and ensure the process-host (BuildMaster,
  Claude Code agent, etc.) masks the env var.
- BuildMaster Application Variables with the **Sensitive** flag are decrypted
  on-demand via `$Decrypt($ProGetApiKey)` in OtterScript and redacted in build
  logs — use this mechanism for CI.
- The current feeds accept anonymous reads. This is intentional for developer
  ergonomics but represents a known security gap — production hardening
  should require an API key for reads on `nuget-stable` at minimum.

---

## 13. Related Documents

- [CSharp-Packages-Build-Process.md](CSharp-Packages-Build-Process.md) — MSBuild targets feeding into `Pack`.
- [CSharp-Packages-Versioning.md](CSharp-Packages-Versioning.md) — how the version in the `.nupkg` filename is computed.
- [CSharp-Central-Package-Management.md](CSharp-Central-Package-Management.md) — the consumer-side `Directory.Packages.props`.
- [BuildMaster-ProGet-CSharp-Package-Pipeline.md](BuildMaster-ProGet-CSharp-Package-Pipeline.md) — CI-side orchestration of this pipeline.
- [Production-and-Tooling-Overview.md](Production-and-Tooling-Overview.md) — the index this doc belongs to.
- `Publish-ATAPUtilities.ps1` — the developer publish helper.
