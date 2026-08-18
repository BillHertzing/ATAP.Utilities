# C# Packages — Pack and Push

> **Task 13.62 security cutover:** Do not use legacy direct-tool,
> environment-variable, or sensitive-value examples. The publishing leaf
> resolves the key with `Get-SecretATAP` from a SecretName; no raw key value
> ever appears in a parameter, environment variable, or log.

> **SecretName host suffix (SC-0288) — read before copying any example below.**
> Every ProGet SecretName is stored in the canonical host-suffixed form
> `<BaseName>.<service-host>` — the suffix names the host running the ProGet
> instance the credential authenticates against (see
> [SecretName-HostSuffix-Convention.md](SecretName-HostSuffix-Convention.md)).
> The suffixless base names `ProGet.BuildMaster.API.Key` (CI) and
> `ProGet.Admin.API.Key` (administration) **do not exist in the vault** and fail
> closed with "No Bitwarden Secrets Manager secret found with key ... in the
> BWS token's granted projects."
>
> **Therefore: omit `-ProGetApiKeySecretName` entirely.** Each BuildTooling
> cmdlet applies `Resolve-HostSuffixedSecretName` in its BEGIN block *only when
> the caller did not bind the parameter*, deriving the host from the
> `ServicePlacementMap` setting. Passing the bare base name explicitly is
> honoured verbatim and therefore **defeats** that resolver — this is the single
> most common cause of a failed push. If you must name it explicitly (for
> cross-host administration), derive the host rather than hard-coding it:
>
> ```powershell
> # Correct: let the BEGIN-block resolver supply the host suffix.
> Publish-NuGetPackageToProGet -NupkgPath $nupkg -Feed 'nuget-experimental'
>
> # Also correct: take the already-suffixed name from host settings.
> $secretName = $global:settings['ProGetBuildMasterApiKeySecretName']
> ```
>
> Never hard-code a literal `.utat01` / `.utat022` suffix in a command, plan, or
> example — that is prohibited by the convention's §4.

**Scope:** Producing `.nupkg` / `.snupkg` files from `ATAP.Utilities.*` and
`AceCommander.*` C# projects and pushing them to the correct ProGet feed.
**Audience:** Developers cutting packages locally; anyone troubleshooting a failed push.
**Status:** Authoritative. Consolidates pack/push content from
`BuildMaster-ProGet-CSharp-Package-Pipeline.md` and `Building.md`.
`Publish-ATAPUtilities.ps1` was deleted in sprint-0007 (V4-G10); see §6 for the migration note.

> **Strategy update (sprint-0007 — Immutable Build).** A package is packed
> and pushed **exactly once**, into the Experimental feed (`nuget-experimental`).
> Movement into the Development, Integration, QA, and Production feeds is by
> **promotion**, not by re-pack/re-push. This doc therefore documents:
>
> - The pack and push commands as they run **at Experimental** (still the
>   authoritative reference for the commands themselves).
> - The single-source-of-truth cmdlet `Publish-NuGetPackageToProGet` that
>   wraps `dotnet nuget push` for use both in local dev and in the
>   Experimental BuildMaster stage.
> - The promotion mechanism (`Promote-ProGetPackage`) used at every stage
>   above Experimental.
>
> See [Immutable-Build-Strategy.md §5](Immutable-Build-Strategy.md#5-what-promotion-is-and-is-not)
> for what promotion is and is not. References below to "the push at tier T"
> for T > Experimental are legacy and should be read as "the promotion at
> tier T."

**Not in this doc:**

- How versions are computed / promoted (→ `CSharp-Packages-Versioning.md`).
- MSBuild target wiring that prepares the project for packing
  (→ `CSharp-Packages-Build-Process.md`).
- BuildMaster OtterScript orchestration across the 5 tiers
  (→ `BuildMaster-ProGet-CSharp-Package-Pipeline.md`).
- Central Package Management for consumers (→ `CSharp-Central-Package-Management.md`).

---

## 1. What "pack" Actually Produces

The `Pack` MSBuild target writes two files per packable project:

| File       | Contents                                                         | When produced                       |
| ---------- | ---------------------------------------------------------------- | ----------------------------------- |
| `*.nupkg`  | The library DLL, transitive metadata (`.nuspec`), icons, readme. | Always, when `IsPackable != false`. |
| `*.snupkg` | PDB symbols + SourceLink metadata for debugger step-into.        | Only when `IncludeSymbols=true`.    |

Both are zip files — renameable to `.zip` and inspectable with any archive tool.
The `.nuspec` inside the `.nupkg` is an XML manifest generated from the
`.csproj` properties documented in §3.

The output folder is controlled by `-o|--output`; the default is
`bin/<Config>/<TFM>/`. Consuming the output via a repo-relative path keeps all
generated artifacts under `_generated/nuget/` per the SC-0033 rule:

```powershell
$msbuild = 'C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\MSBuild\Current\Bin\MSBuild.exe'
$sourceDateEpoch = (& git show -s --format=%ct HEAD).Trim()
& $msbuild src\ATAP.Utilities.Philote\ATAP.Utilities.Philote.csproj `
    /t:Pack /p:Configuration=Release `
    /p:PackageOutputPath=_generated\nuget\local `
    /p:ContinuousIntegrationBuild=true /p:Deterministic=true `
    "/p:DeterministicTimestamp=$sourceDateEpoch" /m:1 /nr:false
```

The sanctioned production path requires stable Visual Studio Build Tools 2026
18.8+, MSBuild 18.8+, `Microsoft.NetCore.Component.SDK`, and NuGet Pack 7.8+.
Repository `global.json` pins stable SDK 10.0.400 so Visual Studio MSBuild loads
NuGet Pack 7.9 rather than the non-deterministic NuGet 7.6 task in older SDK
bands. The BuildMaster runner fails closed if a component is absent or too old.
Local exploratory `dotnet pack` output is not eligible for immutable publication.

Before the one Experimental publication, pack twice from the same Git commit
into isolated roots and require identical identity, nuspec, archive entries, and
full `.nupkg` SHA-256. The Git commit epoch supplies
`DeterministicTimestamp`; wall-clock time is not a release input.

---

## 2. Packable vs Non-Packable Projects

Not every project in the solution is shipped. The current inventory in
[BuildMaster-ProGet-CSharp-Package-Pipeline.md §1.1](BuildMaster-ProGet-CSharp-Package-Pipeline.md#11-project-families) classifies them:

| Category                  | Example                        | `IsPackable` | Goes to ProGet? |
| ------------------------- | ------------------------------ | ------------ | --------------- |
| Console apps              | `ATAP.Console.HelloWorld`      | `false`      | No              |
| Service libraries (§1.1b) | `ATAP.Services.ConsoleMonitor` | `true`       | Yes             |
| Utility libraries (§1.1c) | `ATAP.Utilities.ETW`           | `true`       | Yes             |
| Meta-package (§1.1d)      | `ATAP.Utilities`               | `true`       | Yes             |
| Unit test projects        | `ATAP.Utilities.Testing.Tests` | `false`      | No              |

`IsPackable` defaults to `true` for SDK-style projects. Console and test
projects set it to `false` explicitly in their `.csproj`. If a library project
is missing from ProGet after a push step, check this property first.

---

## 3. NuGet Metadata Applied at Pack Time

These properties — most from `Directory.Build.props`, some per-project — end up
inside the generated `.nuspec`:

| MSBuild property             | Current value (in `Directory.Build.props`)                      |
| ---------------------------- | --------------------------------------------------------------- |
| `Company`                    | _(empty)_                                                       |
| `Copyright`                  | `William Hertzing`                                              |
| `Authors`                    | `William Hertzing`                                              |
| `Product` / `ProductName`    | `ATAP.Utilities`                                                |
| `RepositoryUrl`              | `https://github.com/BillHertzing/ATAP.Utilities`                |
| `RepositoryType`             | `GitHub`                                                        |
| `PackageLicenseExpression`   | `MIT`                                                           |
| `PackageProjectUrl`          | `www.project.url` _(placeholder — see §10)_                     |
| `PackageIconUrl`             | `www.icon.url` _(placeholder — see §10)_                        |
| `PackageTags`                | `Testing, experimental, alpha, ATAP, ATAP.Utilities`            |
| `PackageReleaseNotes`        | `Initial implementation/test of ATAP.Utilities Nuget packaging` |
| `Version` / `PackageVersion` | Computed (see `CSharp-Packages-Versioning.md`).                 |
| `PackageId`                  | Defaults to `$(AssemblyName)`.                                  |

**Per-project overrides:** Any `.csproj` can set `Description`, `Title`,
`PackageId`, `PackageTags`, or `PackageReleaseNotes` in its own `PropertyGroup`
to override the solution-wide defaults. The meta-package
(`src/ATAP.Utilities/ATAP.Utilities.csproj`) is an example — it sets its own
`Description` explaining the roll-up purpose.

---

## Embedded Provenance Metadata

Every NuGet package (`.nupkg`) carries the following metadata in its
`.nuspec` and assembly attributes. This metadata records the package's
provenance — who built it, when, from which commit, and what runtime/tier
context produced it — and is the load-bearing evidence trail behind the
immutable promote-bytes model.

| Metadata Field                   | Source                                   | Example                                                |
| -------------------------------- | ---------------------------------------- | ------------------------------------------------------ |
| **PackageId**                    | .csproj `<PackageId>` or assembly name   | `ATAP.Utilities.Serialization`                         |
| **Version**                      | Computed by `UpdateVersion` MSBuild task | `0.1.0-Alpha-007`                                      |
| **AssemblyVersion**              | `Properties/AssemblyInfo.cs`             | `0.1.0.0`                                              |
| **AssemblyFileVersion**          | `Properties/AssemblyInfo.cs`             | `0.1.0.20260329`                                       |
| **AssemblyInformationalVersion** | `Properties/AssemblyInfo.cs` + Git info  | `0.1.0-Alpha-007+abc1234`                              |
| **Commit Hash**                  | Git `HEAD` at build time                 | `abc1234def5678`                                       |
| **Branch**                       | `git branch --show-current`              | `91-sprint-0003-work-items`                            |
| **Build Timestamp**              | MSBuild `$(BuildTimestamp)`              | `2026-03-29T14:30:00Z`                                 |
| **Build Configuration**          | MSBuild `$(Configuration)`               | `Release`, `Debug`, or `Trace`                         |
| **Target Frameworks**            | .csproj `<TargetFrameworks>`             | `net8.0;net9.0;net10.0`                                |
| **PackageLifeCycleStage**        | .csproj property                         | `Experimental`, `Development`, `Testing`, `Production` |
| **Authors**                      | .csproj `<Authors>`                      | `ATAPUtilities Foundation`                             |
| **Description**                  | .csproj `<Description>`                  | Component description                                  |

Because the same artifact is promoted byte-for-byte through the five tiers
under the immutable strategy, this metadata is fixed at Experimental-stage
pack time and is the authoritative provenance record for every later tier
appearance of the same `(PackageId, Version)`.

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

With SourceLink in place, Visual Studio or VS Code consumers of an ATAP.\*
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

# 4) Push through the SecretName-only PowerShell boundary.
#    -ProGetApiKeySecretName is intentionally omitted so the cmdlet's
#    Resolve-HostSuffixedSecretName BEGIN block supplies the host suffix.
Get-ChildItem _generated\nuget\local -Filter '*.nupkg' | ForEach-Object {
  Publish-NuGetPackageToProGet `
    -NupkgPath $_.FullName `
    -Feed 'nuget-experimental'
}
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

## 6. ~~`Publish-ATAPUtilities.ps1` Helper~~ — **Deleted (V4-G10, sprint-0007)**

> **`Publish-ATAPUtilities.ps1` no longer exists.** Both the repo-root copy and
> the `BuildTooling/public/` copy were deleted as part of sprint-0007 cleanup
> (task V4-G10 / `PowerShell-Script-Consolidation.md` §10.4).
>
> **Migration:**
>
> - For C# libraries: use `Invoke-DotnetBuildWithRetry` from
>   `ATAP.Utilities.BuildTooling.PowerShell`, or the `Publish-NuGetPackageToProGet`
>   cmdlet after a `dotnet pack` run (see §5 above).
> - For PowerShell modules: use `Invoke-ModuleBuildWithRetry`, which orchestrates
>   `module.build.ps1` via `Invoke-Build` with NBGV-derived tier resolution and
>   automatic retry.
> - For the CI path: packages are published to `nuget-experimental` by the
>   BuildMaster `CSharpPackage-5Stage` plan via `Invoke-CSharpPackageBuildMasterStage.ps1`;
>   no standalone script is involved.

The historical documentation for this script (what it did, its parameter set, the
dependency-ordered library list) can be recovered from git history if needed:

```powershell
git log --all --oneline -- 'src/ATAP.Utilities.BuildTooling.PowerShell/public/Publish-ATAPUtilities.ps1'
```

---

## 7. Feed Topology and Tier → Feed Mapping

Single ProGet instance at `http://localhost:50000`. Five feeds, one per tier:

| Tier         | Feed name            | Push URL (Experimental only — others reached by promotion)      |
| ------------ | -------------------- | --------------------------------------------------------------- |
| Experimental | `nuget-experimental` | `http://localhost:50000/nuget/nuget-experimental/v3/index.json` |
| Development  | `nuget-development`  | (target of promotion from `nuget-experimental`)                 |
| Integration  | `nuget-integration`  | (target of promotion from `nuget-development`)                  |
| QA           | `nuget-qa`           | (target of promotion from `nuget-integration`)                  |
| Production   | `nuget-stable`       | (target of promotion from `nuget-qa`)                           |

Under the immutable-build strategy, only `nuget-experimental` is a push
target in the normal flow. Higher feeds are reached via
`Promote-ProGetPackage`, which calls ProGet's promotion API and copies the
exact same `.nupkg` bytes between feeds. The push URLs for the higher feeds
remain valid (a release engineer can still push directly in an emergency
override) but should not be used by automated pipelines above Experimental.

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

### 8.1 Worktree `NuGet.config`

Every sprint worktree lists **all five permanent** feeds as package sources.
This is intentional — a sprint worktree may need to restore a dependency
from any tier while iterating. The feed list is static; sprint start/end
never mutates `NuGet.config`. See [SprintInfrastructure-Naming.md](SprintInfrastructure-Naming.md) §3.

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

### 8.2 Feed list is permanent across all branches

All five `nuget-*` feeds are listed in `NuGet.config` on every branch. There
are no per-sprint feeds and no per-branch feed mutations.

Hermetic isolation at the Integration and QA tiers is enforced at the
**ProGet feed level** (hermetic connectors — no `nuget.org` uplink) and at
the **package-source-mapping level** (only `ATAP.*` packages resolve from
local feeds), not by pruning the source list. See [SprintInfrastructure-Naming.md](SprintInfrastructure-Naming.md) §3.

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
- The publishing leaf performs the tool-required API-key handoff internally.
  Callers normally pass no SecretName at all — the leaf resolves the
  host-suffixed `ProGet.BuildMaster.API.Key.<service-host>` itself. See the
  host-suffix note at the top of this document.

---

## 8.5 Promotion (the Sprint-7 mechanism for moving between feeds)

Above Experimental, packages move between feeds by **promotion**, not by
push. The single source of truth for promotion is `Promote-ProGetPackage`
in `ATAP.Utilities.BuildTooling.PowerShell`.

```powershell
Promote-ProGetPackage `
  -Name     'ATAP.Utilities.Philote' `
  -Version  '0.1.0-Beta.42' `
  -FromFeed 'nuget-development' `
  -ToFeed   'nuget-integration' `
  -Reason   'INT-PASS for build #4271'
```

The cmdlet:

- Calls ProGet's `POST /api/promotions/promote` endpoint.
- Is **idempotent** — re-running with `(Name, Version, ToFeed)` already
  present is a no-op that returns success.
- Does not touch the `.nupkg` bytes.
- Records the promotion reason in ProGet's audit log so you can later
  trace "why is this package in QA?" back to a specific BuildMaster
  pipeline run.

See [Immutable-Build-Strategy.md §5](Immutable-Build-Strategy.md#5-what-promotion-is-and-is-not)
and [BuildMaster-Pipeline-Topology.md §4](BuildMaster-Pipeline-Topology.md#4-powershell-automation-surface)
for the full automation surface.

---

## 9. Push Command Reference

### 9.1 Single package, single feed

```powershell
Publish-NuGetPackageToProGet `
  -NupkgPath .\path\to\ATAP.Utilities.ETW.0.1.0-Sprint.47.nupkg `
  -Feed 'nuget-experimental'
```

### 9.2 All `.nupkg` in a folder

```powershell
Get-ChildItem _generated\nuget\local -Filter '*.nupkg' | ForEach-Object {
  Publish-NuGetPackageToProGet `
    -NupkgPath $_.FullName `
    -Feed 'nuget-experimental'
}
```

`--skip-duplicate` prevents the push from erroring on packages that already
exist at the exact same version — useful when re-running a partial publish
where some packages already made it through.

### 9.3 Via feed _name_ (not URL)

If the source is already defined in `NuGet.config`, the feed name alone is
accepted:

```powershell
Publish-NuGetPackageToProGet `
  -NupkgPath .\Package.1.0.0.nupkg `
  -Feed 'nuget-experimental'
```

This is the form used by BuildMaster's OtterScript — the feed name resolves via
the checked-out `NuGet.config`, so the same command works on every tier
without hardcoding URLs.

### 9.4 Pushing symbol packages

`.snupkg` files alongside `.nupkg` files are pushed automatically. To push
**only** the symbol package separately, keep the same SecretName boundary:

```powershell
Publish-NuGetPackageToProGet `
  -NupkgPath '.\ATAP.Utilities.ETW.0.1.0-Sprint.47.snupkg' `
  -Feed 'nuget-experimental'
```

---

## 10. Known Drift and Open Items

> **Feed topology is canonical.** ProGet feeds are permanent (`nuget-experimental`
> through `nuget-stable`). No per-sprint feeds exist. See
> [SprintInfrastructure-Naming.md](SprintInfrastructure-Naming.md) §3.

Remaining open items:

- **`PackageProjectUrl` placeholder.** `Directory.Build.props` line 92 has
  `www.project.url`. Every `.nupkg` currently ships with this literal string.
  Real URL should be the GitHub repo page or a GitHub Pages site; fix as a
  one-line edit during a pack-cleanup task.
- **`PackageIconUrl` placeholder.** Same issue on line 93. Also note that
  `PackageIconUrl` has been _deprecated_ in favor of `PackageIcon` (embedded
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

- The resolved SecretName cannot resolve for the current identity or lacks
  publish permission. Verify metadata and grants without displaying the value.
- Wrong feed name in the URL — `nuget-experimental` is one hyphenated token,
  not `nuget/experimental`.
- ProGet has `Require API key for push` enabled but the `--api-key` flag was
  omitted.

### 11.1a `No Bitwarden Secrets Manager secret found with key '...'`

The full text is:

```text
No Bitwarden Secrets Manager secret found with key 'ProGet.BuildMaster.API.Key'
in the BWS token's granted projects.
```

The SecretName was passed **suffixless**. Vault entries are host-suffixed
(`<BaseName>.<service-host>`), so the bare base name matches nothing and the
resolver fails closed. Because an explicitly bound `-ProGetApiKeySecretName` is
honoured verbatim, binding the bare name suppresses the BEGIN-block
`Resolve-HostSuffixedSecretName` that would otherwise have added the suffix.

Fix: drop the `-ProGetApiKeySecretName` argument. Confirm what the resolver
will use with:

```powershell
$global:settings['ProGetBuildMasterApiKeySecretName']   # CI publishing key
$global:settings['ProGetAdminApiKeySecretName']         # administration key
```

If `$global:settings` is empty, the shell has no ATAP profile loaded — dot-source
`$PROFILE.AllUsersAllHosts` and `$PROFILE.CurrentUserAllHosts` first. Agent-spawned
shells frequently do not inherit them.

### 11.2 `409 Conflict`

The exact `(PackageId, Version)` already exists in the target feed. Either:

- Add `--skip-duplicate` to the push command (preferred for re-runs), or
- Bump the version. In the NBGV workflow this means producing the next
  `{height}` by committing a new filtered change.

### 11.3 `NU5017 — Cannot create a package that has no dependencies nor content`

The project has no source files and no `<PackageReference>` entries. This
applies to the meta-package (`src/ATAP.Utilities/ATAP.Utilities.csproj`) if
all of its PackageReferences are missing — SDK-style projects rely on the
meta-package having _something_ to ship. Either add `<EnableDefaultItems>false</EnableDefaultItems>`
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

### 11.5a Push reports success but lands in a `database-*` feed

Requires `ATAP.Utilities.BuildTooling.ProGet.PowerShell` **0.1.20 or later**.

In 0.1.19 and earlier, `Resolve-ProGetFeedFromSettings` matched feeds on
*transport* `FeedType` only. Database feeds legitimately declare transport type
`nuget`, so a request for `nuget-experimental` could return
`database-experimental`. `Publish-NuGetPackageToProGet` then reported
`Published = True` against the wrong feed, and the subsequent promotion failed
with "found in neither source feed ... nor destination feed".

`-Feed` is parsed only for its tier suffix and the feed is then re-resolved, so
the argument alone does not pin the destination. Always confirm the returned
object:

```powershell
$r = Publish-NuGetPackageToProGet -NupkgPath $nupkg -Feed 'nuget-experimental'
if ($r.FeedName -ne 'nuget-experimental') { throw "Wrong feed: $($r.FeedName)" }
```

Fixed in 0.1.20 by classifying the feed family from the canonical feed-name
prefix (`nuget-`, `database-`, `powershellget-`, ...) before falling back to
transport type.

### 11.6 "The package 'X' is not listed in the package source"

NuGet's package-source-mapping block rejected the lookup. Check `NuGet.config`
§8.1 — if an `ATAP.*` package is being requested, only the ATAP.\* mapping
applies; `nuget.org` will not be consulted.

---

## 12. Security

- The ProGet API key is equivalent to a write token — leaking it lets any
  actor push arbitrary packages to production feeds. **Never** commit it,
  log it to stdout, or paste it into issue comments.
- Keep the tool-required raw handoff inside the authenticated PowerShell leaf.
  BuildMaster and operator callers pass only `ProGetApiKeySecretName`; no
  resolved value belongs in Application Variables, arguments, or environments.
- The current feeds accept anonymous reads. This is intentional for developer
  ergonomics but represents a known security gap — production hardening
  should require an API key for reads on `nuget-stable` at minimum.

---

## 13. Related Documents

- [CSharp-Packages-Build-Process.md](CSharp-Packages-Build-Process.md) — MSBuild targets feeding into `Pack`.
- [CSharp-Packages-Versioning.md](CSharp-Packages-Versioning.md) — how the version in the `.nupkg` filename is computed.
- [CSharp-Central-Package-Management.md](CSharp-Central-Package-Management.md) — the consumer-side `Directory.Packages.props`.
- [BuildMaster-Pipeline-Topology.md](BuildMaster-Pipeline-Topology.md) — CI-side orchestration of this pipeline and full application variable tables.
- [Production-and-Tooling-Overview.md](Production-and-Tooling-Overview.md) — the index this doc belongs to.
- ~~`Publish-ATAPUtilities.ps1`~~ — deleted in sprint-0007 (V4-G10); see §6.
