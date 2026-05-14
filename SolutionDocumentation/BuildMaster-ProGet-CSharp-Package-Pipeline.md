# BuildMaster + ProGet: C# Package Build and Publish Pipeline

**Repository:** ATAP.Utilities
**Scope:** All C# / .NET projects under `src/`
**Goal:** Build every package individually _and_ as a single `ATAP.Utilities` meta-package **exactly once**, then promote the resulting `.nupkg` (byte-for-byte unchanged) through the 5-tier ProGet feed chain.

> **Strategy update (sprint-0007 — Immutable Build).** This pipeline now follows
> the **build-once / promote-the-artifact** pattern. The Experimental tier runs
> `dotnet pack` and pushes to `nuget-experimental` exactly once. Every later
> tier (Development, Integration, QA, Production) runs **tests against the
> existing artifact** and, on pass, calls `Promote-ProGetPackage` to copy the
> same `.nupkg` to the next feed. **No tier above Experimental rebuilds.**
> The full strategy is in [Immutable-Build-Strategy.md](Immutable-Build-Strategy.md);
> the pipeline catalog is in [BuildMaster-Pipeline-Topology.md](BuildMaster-Pipeline-Topology.md).
>
> Older sections of this document still illustrate per-stage `dotnet pack` /
> `dotnet nuget push` calls because they remain accurate for the **Experimental
> stage only** and as a single-source reference for the commands themselves.
> When you read a non-Experimental stage that contains `dotnet pack`, treat
> that as legacy text being replaced — the Sprint-7 pattern is to call
> `Promote-ProGetPackage` instead.

---

## 1. Package Inventory

### 1.1 Project Families

The 171 `.csproj` files fall into four categories.

#### 1.1a Console Applications (not published as NuGet packages)

| Project                        | Notes                                            |
| ------------------------------ | ------------------------------------------------ |
| `ATAP.Console.CodeAnalysis`    | Roslyn analysis driver                           |
| `ATAP.Console.Console01/02/03` | Template consoles + StringConstants sub-projects |
| `ATAP.Console.HelloWorld`      |                                                  |
| `ATAP.Console.ManimDemo`       | + DefaultConfiguration, Model, StringConstants   |
| `ATAP.Console.PluginDemo`      | + Model, StringConstants                         |

Console apps are _built_ by BuildMaster for CI validation but are **not** pushed to ProGet.

#### 1.1b Service Libraries (published individually)

| Package (root NuGet ID)            | Sub-projects                  |
| ---------------------------------- | ----------------------------- |
| `ATAP.Service.Service01/02`        |                               |
| `ATAP.Services.ConsoleMonitor`     | + Interfaces                  |
| `ATAP.Services.ConsoleSink`        | + Interfaces                  |
| `ATAP.Services.ConsoleSource`      | + Interfaces                  |
| `ATAP.Services.FileSystemWatchers` | + Interfaces                  |
| `ATAP.Services.GenerateProgram`    | + Interfaces, StringConstants |
| `ATAP.Services.TcpWithResilience`  | + Interfaces                  |
| `ATAP.Services.Timers`             | + Interfaces                  |

#### 1.1c Utility Libraries (published individually)

| Package (root NuGet ID)                          | Significant sub-projects                                                                                                                                                                                                                                                              |
| ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ATAP.Utilities.AutoDoc`                         |                                                                                                                                                                                                                                                                                       |
| `ATAP.Utilities.BuildTooling.CSharp`             | MSBuild custom tasks                                                                                                                                                                                                                                                                  |
| `ATAP.Utilities.BuildTooling.Jenkins`            |                                                                                                                                                                                                                                                                                       |
| `ATAP.Utilities.Collection.Extensions`           |                                                                                                                                                                                                                                                                                       |
| `ATAP.Utilities.ComputerInventory`               | Configuration, Enumerations, Extensions, Hardware (Enumerations, Extensions, Interfaces, Models, StringConstants), Interfaces, Models, ProcessInfo (Enumerations, Extensions, Interfaces, Models, StringConstants), Software (DefaultConfiguration, Enumerations, Interfaces, Models) |
| `ATAP.Utilities.ConcurrentObservableCollections` |                                                                                                                                                                                                                                                                                       |
| `ATAP.Utilities.Configuration`                   | Extensions, Secrets (Shims: Bitwarden, Interfaces)                                                                                                                                                                                                                                    |
| `ATAP.Utilities.CryptoCoin`                      | Enumerations, Extensions, Interfaces, Models                                                                                                                                                                                                                                          |
| `ATAP.Utilities.CryptoMiner`                     | Enumerations, Extensions, Interfaces, Models                                                                                                                                                                                                                                          |
| `ATAP.Utilities.DatabaseManagement`              |                                                                                                                                                                                                                                                                                       |
| `ATAP.Utilities.DateTime`                        |                                                                                                                                                                                                                                                                                       |
| `ATAP.Utilities.Enumeration`                     |                                                                                                                                                                                                                                                                                       |
| `ATAP.Utilities.ETW`                             |                                                                                                                                                                                                                                                                                       |
| `ATAP.Utilities.FileIO`                          |                                                                                                                                                                                                                                                                                       |
| `ATAP.Utilities.GenerateProgram`                 | + Interfaces                                                                                                                                                                                                                                                                          |
| `ATAP.Utilities.GenericHost.Extensions`          |                                                                                                                                                                                                                                                                                       |
| `ATAP.Utilities.Gmail`                           | Enumerations, StringConstants                                                                                                                                                                                                                                                         |
| `ATAP.Utilities.GraphDataStructures`             | + Interfaces                                                                                                                                                                                                                                                                          |
| `ATAP.Utilities.Http`                            |                                                                                                                                                                                                                                                                                       |
| `ATAP.Utilities.IAC.Ansible`                     | Enumerations, Interfaces, Models, StringConstants                                                                                                                                                                                                                                     |
| `ATAP.Utilities.Images.Enumerations`             |                                                                                                                                                                                                                                                                                       |
| `ATAP.Utilities.Loader`                          | Interfaces, Model, StringConstants                                                                                                                                                                                                                                                    |
| `ATAP.Utilities.Logging`                         |                                                                                                                                                                                                                                                                                       |
| `ATAP.Utilities.ManimVideoGenerator`             | DefaultSettings, Enumerations, Interfaces, Models, StringConstants                                                                                                                                                                                                                    |
| `ATAP.Utilities.MessageQueue`                    | Extensions, Interfaces, Model, Shim (RabbitMQ, TPL), StringConstants                                                                                                                                                                                                                  |
| `ATAP.Utilities.ORMLite.Models`                  |                                                                                                                                                                                                                                                                                       |
| `ATAP.Utilities.Persistence`                     | Extensions, Interfaces, Model, StringConstants                                                                                                                                                                                                                                        |
| `ATAP.Utilities.Philote`                         | Converters.Interfaces, DefaultConfiguration, Interfaces, JsonConverter.Shim.SystemTextJson, Models                                                                                                                                                                                    |
| `ATAP.Utilities.Plugin`                          | Interfaces, Model, StringConstants                                                                                                                                                                                                                                                    |
| `ATAP.Utilities.Reactive.Extensions`             |                                                                                                                                                                                                                                                                                       |
| `ATAP.Utilities.RealEstate.Enumerations`         |                                                                                                                                                                                                                                                                                       |
| `ATAP.Utilities.Secrets`                         | Enumerations, Interfaces, Model, Shim (Bitwarden, Plugin), StringConstants                                                                                                                                                                                                            |
| `ATAP.Utilities.Serializer`                      | Interfaces, Model, Shim (Newtonsoft, Plugin, ServiceStack, SystemTextJson), StringConstants                                                                                                                                                                                           |
| `ATAP.Utilities.String`                          |                                                                                                                                                                                                                                                                                       |
| `ATAP.Utilities.StronglyTypedId`                 | Interfaces, JsonConverter.Shim.SystemTextJson, Models                                                                                                                                                                                                                                 |
| `ATAP.Utilities.Testing`                         | DI, DI.Fixture.Serialization, Fixture.Database, Fixture.Serialization (Shim: Newtonsoft, Plugin, ServiceStack, SystemTextJson)                                                                                                                                                        |
| `ATAP.Utilities.VoiceAttack`                     |                                                                                                                                                                                                                                                                                       |

#### 1.1d Meta-package

| Package ID       | Description                                              |
| ---------------- | -------------------------------------------------------- |
| `ATAP.Utilities` | Depends on every library listed in §1.1b and §1.1c above |

---

## 2. ProGet Feed Structure

The 5-tier NuGet promotion ladder maps to five ProGet feeds. These are already present in `NuGet.Config`.

| Feed name            | ProGet URL path              | Tier purpose                                 |
| -------------------- | ---------------------------- | -------------------------------------------- |
| `nuget-experimental` | `/nuget/nuget-experimental/` | Sprint / exploratory builds                  |
| `nuget-development`  | `/nuget/nuget-development/`  | Alpha — passes PSScriptAnalyzer + unit tests |
| `nuget-integration`  | `/nuget/nuget-integration/`  | Beta — passes integration tests              |
| `nuget-qa`           | `/nuget/nuget-qa/`           | QA — full regression suite                   |
| `nuget-stable`       | `/nuget/nuget-stable/`       | Production — signed, stamped release         |

All feeds are served from `http://localhost:50000` (Inedo Hub default).
The ProGet admin API key is stored in Bitwarden and is used to populate the env var `PROGET_ADMIN_API_KEY`.

### 2.1 Feed Settings Checklist

For **each** of the five feeds, apply these settings in the ProGet admin UI
(Manage Feed → Feed Settings):

- **Package promotion**: enabled (to allow BuildMaster to promote from tier N to N+1).
- **Drop-older-prerelease**: enabled on `nuget-experimental` to prevent unbounded growth.
- **Connectors**: add `nuget.org` as a connector on `nuget-experimental` (upstream packages flow down only).
- **Require API key for push**: yes — use the env var `PROGET_ADMIN_API_KEY` stored as a BuildMaster variable (masked).
- **Allow anonymous read**: yes on all feeds (matches `<packageSourceCredentials>` — no credentials block).

### 2.2 Feed Connector Topology

Each feed exposes a **restore source** that spans itself and selected upstream feeds via ProGet
connectors. Configure these connector relationships in the ProGet admin UI (Manage Feed → Connectors).

| Restore from feed    | Resolves packages from                                                     |
| -------------------- | -------------------------------------------------------------------------- |
| `nuget-experimental` | `nuget-experimental` + `nuget.org` (upstream connector)                    |
| `nuget-development`  | `nuget-development` + `nuget-experimental` + `nuget.org` (chain connector) |
| `nuget-integration`  | `nuget-integration` + `nuget-development` (hermetic — no public fallback)  |
| `nuget-qa`           | `nuget-qa` + `nuget-integration` (hermetic)                                |
| `nuget-stable`       | `nuget-stable` + `nuget.org` (upstream connector)                          |

`nuget-integration` and `nuget-qa` are intentionally hermetic: only packages that have been
explicitly promoted to that tier (or lower) are visible, preventing accidental resolution from
public upstream sources during integration and regression testing.

---

## 3. Version Strategy

Versioning is driven by **Nerdbank.GitVersioning (NBGV)** via a `version.json` at the repo root.
The prerelease label in `version.json` controls which tier a package belongs to:

```json
{
  "$schema": "https://raw.githubusercontent.com/dotnet/Nerdbank.GitVersioning/main/src/NerdBank.GitVersioning/version.schema.json",
  "version": "0.1-Sprint.{height}",
  "nuGetPackageVersion": { "semVer": 2 },
  "pathFilters": ["./"],
  "publicReleaseRefSpec": [".*"]
}
```

| `version` field       | Prerelease label | Tier name    | Feed target          |
| --------------------- | ---------------- | ------------ | -------------------- |
| `0.1-Sprint.{height}` | `Sprint`         | Experimental | `nuget-experimental` |
| `0.1-Alpha.{height}`  | `Alpha`          | Development  | `nuget-development`  |
| `0.1-Beta.{height}`   | `Beta`           | Integration  | `nuget-integration`  |
| `0.1-QA.{height}`     | `QA`             | QA           | `nuget-qa`           |
| `0.1.{height}`        | _(empty)_        | Production   | `nuget-stable`       |

Override at the package level by adding a `version.json` in the individual project folder.

### 3.1 SemVer validity

This project uses the **dot separator without leading-zero padding** for prerelease identifiers (e.g. `0.1.0-Sprint.42`, `0.1.0-Alpha.3`). This is the NBGV default and is fully valid under SemVer 2.0.

**Avoid leading-zero padding** (e.g. `Alpha.007`) — SemVer 2.0 treats a zero-padded string as a numeric identifier and disallows leading zeros. NuGet reports this as error `NU5024`.

---

## 4. BuildMaster Application Structure

Use **one BuildMaster Application** named `ATAP.Utilities-CSharp`.

### 4.1 Application Variables

Navigate to **Applications → ATAP.Utilities-CSharp → Settings → Variables** and add each row below.
Enter the variable name **without** the leading `$` (the `$` is OtterScript reference syntax, not the stored name).

| Variable (OtterScript name) | Example value                                       | Notes                                                                         |
| --------------------------- | --------------------------------------------------- | ----------------------------------------------------------------------------- |
| `$ApplicationName`          | `ATAP.Utilities`                                    | Repository name                                                               |
| `$SourcePath`               | `C:\BuildMaster\work\ATAP.Utilities\$ReleaseNumber` | Working directory                                                             |
| `$Branch`                   | `98-sprint-0006-work-items`                         | Updated by Repository Monitor                                                 |
| `$ProGetUrl`                | `http://localhost:50000`                            |                                                                               |
| `$ProGetApiKey`             | _(paste plaintext key; tick **Sensitive**)_         | BuildMaster encrypts it; retrieve key from Bitwarden (`PROGET_ADMIN_API_KEY`) |
| `$Configuration`            | `Release`                                           | MSBuild configuration                                                         |
| `$MetaPackageName`          | `ATAP.Utilities`                                    | Name of the roll-up meta-package                                              |

### 4.2 Release Pipelines

Create one **Release** in the application with five **stages** corresponding to the tiers:

```text
Experimental (nuget-experimental)  →  Development (nuget-development)  →  Integration (nuget-integration)  →  QA (nuget-qa)  →  Production (nuget-stable)
```

> **Sprint-7 stage semantics (immutable build).** Only the Experimental stage
> builds. Every later stage **promotes the existing artifact** via
> `Promote-ProGetPackage` (which calls ProGet's promotion API) and then runs
> tier-appropriate tests against that artifact. The same `(PackageId,
Version, SHA-256)` flows through all five feeds.

Each stage:

| Stage        | What runs                                                                                                                                                                                   | Gate to next stage                                |
| ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------- |
| Experimental | `dotnet build`, `dotnet pack`, push to `nuget-experimental` (single push of record).                                                                                                        | Automatic on packaging success.                   |
| Development  | `Promote-ProGetPackage` (Experimental → Development); restore the promoted package; run integration tests (`--filter Category=Integration`). Unit tests already gated at Experimental tier. | Zero failures. Optionally a manual approval.      |
| Integration  | `Promote-ProGetPackage` (Development → Integration); restore the promoted package; run integration tests.                                                                                   | Integration test artifact present, zero failures. |
| QA           | `Promote-ProGetPackage` (Integration → QA); restore the promoted package; full regression + coverage.                                                                                       | Coverage threshold met; full regression green.    |
| Production   | `Promote-ProGetPackage` (QA → Production). No new tests beyond a smoke check against the promoted package.                                                                                  | Manual approval from the release manager.         |

Promotion is a metadata operation in ProGet — it does not rebuild the
`.nupkg`. See [Immutable-Build-Strategy.md §5](Immutable-Build-Strategy.md#5-what-promotion-is-and-is-not).

### 4.3 Package immutability and republish semantics

<!-- Philote: 19ec4ccb-7769-46f3-9cc6-c4300efcfac5 -->

NuGet feeds — including local folder feeds managed with `nuget add` — treat **published packages as immutable**.
Attempting to push the same `id@version` again will be **silently rejected** (the push exits 0 but the old package remains).

**Why this matters for the promotion pipeline:**
If you need to re-push a package from a lower feed to a higher feed with the exact same version string,
the higher feed must not already contain that version.
BuildMaster's promotion step should either:

- skip promotion when the target feed already has the exact version, or
- delete the older copy from the target before pushing (use the ProGet API: `DELETE /api/packages/bulk/delete`).

**Safe local republish pattern** (`Republish-NuGet.ps1`):

```powershell
param (
    [Parameter(Mandatory)] [string]$PackagePath,    # path to .nupkg
    [Parameter(Mandatory)] [string]$LocalFeedPath   # local folder feed root
)

$packageFile = Split-Path $PackagePath -Leaf
if ($packageFile -notmatch '^(.+)\.([0-9]+\.[0-9]+\.[0-9]+.*)\.nupkg$') {
    throw "Filename must follow ID.Version.nupkg format"
}
$packageId      = $Matches[1]
$packageVersion = $Matches[2]
$targetDir      = Join-Path $LocalFeedPath "$packageId\$packageVersion"

if (Test-Path $targetDir) {
    Write-Host "Removing existing version at: $targetDir"
    Remove-Item -Recurse -Force -Path $targetDir
}
nuget add $PackagePath -Source $LocalFeedPath
```

This pattern is suitable for **development and integration feeds only**.
Production feeds should be treated strictly immutable; promotion to production is always a new unique version.

**SHA-embedding circularity (why byte-for-byte republish is impossible):**

If a build step attempts to hash the final `.nupkg` and embed that hash back into the package
(e.g., as a metadata field or a file inside the archive), the act of embedding changes the package
— which changes the hash — creating an infinite cycle.

| Approach                                    | Circular? | Recommended use                    |
| ------------------------------------------- | --------- | ---------------------------------- |
| Embed SHA of `.nupkg` inside itself         | ❌ Yes    | Not practical                      |
| SHA of folder contents **before** packing   | ✅ No     | Embed in `.nuspec` metadata        |
| SHA of final `.nupkg` stored **externally** | ✅ No     | Integrity sidecar file (`.sha256`) |
| NuGet package signing (`nuget sign`)        | ✅ No     | Official integrity mechanism       |

Generate an external hash sidecar after building:

```powershell
Get-FileHash '.\MyPackage.1.0.0.nupkg' -Algorithm SHA256 |
    Select-Object -ExpandProperty Hash |
    Out-File '.\MyPackage.1.0.0.nupkg.sha256' -Encoding ascii
```

---

## 5. OtterScript Plan — `CSharpPackage-5Stage.otter`

Save this file as `src/ATAP.Utilities.BuildTooling.BuildMaster/Plans/CSharpPackage-5Stage.otter`.

The plan follows exactly the same shape as `PowerShellModule-5Stage.otter`:

1. Acquire source.
2. Resolve tier from NBGV.
3. Dispatch to the matching stage block.

> **Sprint-7 note:** the OtterScript below follows the **immutable-build
> shape**. Only the Experimental stage builds and pushes the artifact. Each
> non-Experimental stage calls `Promote-ProGetPackage` to copy the existing
> artifact between feeds, then runs tier-appropriate tests **against the
> promoted package** (no rebuild).
> See [BuildMaster-Pipeline-Topology.md §5](BuildMaster-Pipeline-Topology.md#5-pipeline-plan-storage)
> for the canonical stage shape and [Immutable-Build-Strategy.md §5](Immutable-Build-Strategy.md#5-what-promotion-is-and-is-not)
> for what promotion is (and is not).
>
> **`UsePackageReferenceForSUT` / `SUTVersion` (Development–Production tiers).**
> Every non-Experimental
> stage tests against the _promoted package_, not source. `Invoke-PromotedPackageTests`
> passes `/p:UsePackageReferenceForSUT=true /p:SUTVersion=$ResolvedPackageVersion`
> to the underlying `dotnet test` invocation. The `-Version` parameter on
> `Invoke-PromotedPackageTests` is the `SUTVersion` value. See
> [CSharp-Packages-Test-Process.md §11.2](CSharp-Packages-Test-Process.md#112-t2t5--packagereference-mode-promoted-artifact)
> for the raw `dotnet test` equivalent.
>
> **TestSlice (`.slnf`) status.** As of Sprint-7, no `*.slnf` solution-filter
> files have been created in this repository. The `Invoke-PromotedPackageTests`
> cmdlet currently invokes `dotnet test` against the full `ATAP.Utilities.sln`.
> When TestSlice files are introduced, update the `-ProjectPath` parameter of
> `Invoke-PromotedPackageTests` to reference the appropriate `.slnf` filter
> and replace any bare `.sln` references in this document with `.slnf` paths.
> Tier-to-filter mapping is in [CSharp-Packages-Test-Process.md §4](CSharp-Packages-Test-Process.md#4-organizing-tests-with-categories-traits).

```otter
##########################################################################
# CSharpPackage-5Stage — BuildMaster OtterScript Plan
#
# Variables (Application Variables):
#   $ApplicationName  — "ATAP.Utilities"
#   $Branch           — branch being built
#   $SourcePath       — absolute path to worktree
#   $Configuration    — "Release"
#   $ProGetUrl        — e.g. "http://localhost:50000"
#   $ProGetApiKey     — masked; from PROGET_ADMIN_API_KEY env var
#   $MetaPackageName  — "ATAP.Utilities"
##########################################################################

GitHub::Get-Source
(
    Organization: BillHertzing,
    Repository: $ApplicationName,
    Branch: $Branch,
    OutputDirectory: $SourcePath
);

# Resolve tier from NBGV
set $NbgvVersion = $Exec
(
    FileName: nbgv,
    Arguments: `get-version --variable NuGetPackageVersion`,
    WorkingDirectory: $SourcePath
);

set $PrereleaseLabel = $RegexReplace($NbgvVersion, `^[0-9]+\.[0-9]+\.[0-9]+-?([A-Za-z]*).*$`, `$1`);

set $Tier = Experimental;
if $PrereleaseLabel == Alpha      { set $Tier = Development;  }
if $PrereleaseLabel == Beta       { set $Tier = Integration;  }
if $PrereleaseLabel == QA         { set $Tier = QA;           }
if $PrereleaseLabel == ``         { set $Tier = Production;   }

set $FeedName = nuget-experimental;
if $Tier == Development { set $FeedName = nuget-development;  }
if $Tier == Integration { set $FeedName = nuget-integration;  }
if $Tier == QA          { set $FeedName = nuget-qa;           }
if $Tier == Production  { set $FeedName = nuget-stable;       }

Log-Debug `Resolved Tier=$Tier  Feed=$FeedName  from NuGetPackageVersion=$NbgvVersion`;

# -------------------------------------------------------------------------
# Stage Experimental — build + pack only; no tests; push to nuget-experimental
# -------------------------------------------------------------------------
stage Experimental
{
    if $Tier == Experimental
    {
        Exec
        (
            FileName: dotnet,
            Arguments: `build ATAP.Utilities.sln --configuration $Configuration --no-incremental`,
            WorkingDirectory: $SourcePath,
            SuccessExitCode: 0
        );

        Exec
        (
            FileName: dotnet,
            Arguments: `pack ATAP.Utilities.sln --configuration $Configuration --no-build --output _generated\nuget\$Tier`,
            WorkingDirectory: $SourcePath,
            SuccessExitCode: 0
        );

        Exec
        (
            FileName: dotnet,
            Arguments: `nuget push _generated\nuget\$Tier\*.nupkg --source $ProGetUrl/nuget/$FeedName/v3/index.json --api-key $Decrypt($ProGetApiKey)`,
            WorkingDirectory: $SourcePath,
            SuccessExitCode: 0
        );

        Create-Artifact Packages
        (
            From: _generated\nuget\$Tier,
            Include: @(*.nupkg, *.snupkg)
        );
    }
}

# -------------------------------------------------------------------------
# Stage Development — promote artifact + run unit tests against it
# -------------------------------------------------------------------------
stage Development
{
    if $Tier == Development
    {
        # Promote the existing artifact (no rebuild).
        Exec
        (
            FileName: pwsh,
            Arguments: `-Command "Promote-ProGetPackage -Name $PackageName -Version $ResolvedPackageVersion -FromFeed nuget-experimental -ToFeed nuget-development -Reason 'DEV-PASS for build $BuildId'"`,
            WorkingDirectory: $SourcePath,
            SuccessExitCode: 0
        );

        # Restore the promoted package and run tier-appropriate tests against it.
        # (Tests use the package as a build dependency; they do NOT rebuild it.)
        Exec
        (
            FileName: pwsh,
            Arguments: `-Command "Invoke-PromotedPackageTests -Name $PackageName -Version $ResolvedPackageVersion -Feed nuget-development -TestFilter 'Category=Integration' -ResultsPath _generated\testresults\$Tier"`,
            WorkingDirectory: $SourcePath,
            SuccessExitCode: 0
        );

        Create-Artifact TestResults ( From: _generated\testresults\$Tier, Include: @(*.trx) );
    }
}

# -------------------------------------------------------------------------
# Stage Integration — promote artifact + run unit + integration tests against it
# -------------------------------------------------------------------------
stage Integration
{
    if $Tier == Integration
    {
        # Promote the existing artifact (no rebuild).
        Exec
        (
            FileName: pwsh,
            Arguments: `-Command "Promote-ProGetPackage -Name $PackageName -Version $ResolvedPackageVersion -FromFeed nuget-development -ToFeed nuget-integration -Reason 'INT-PASS for build $BuildId'"`,
            WorkingDirectory: $SourcePath,
            SuccessExitCode: 0
        );

        # Restore the promoted package and run tier-appropriate tests against it.
        # (Tests use the package as a build dependency; they do NOT rebuild it.)
        Exec
        (
            FileName: pwsh,
            Arguments: `-Command "Invoke-PromotedPackageTests -Name $PackageName -Version $ResolvedPackageVersion -Feed nuget-integration -TestFilter 'Category=Unit|Category=Integration' -ResultsPath _generated\testresults\$Tier"`,
            WorkingDirectory: $SourcePath,
            SuccessExitCode: 0
        );

        Create-Artifact TestResults ( From: _generated\testresults\$Tier, Include: @(*.trx) );
    }
}

# -------------------------------------------------------------------------
# Stage QA — promote artifact + run full regression suite with coverage
# -------------------------------------------------------------------------
stage QA
{
    if $Tier == QA
    {
        # Promote the existing artifact (no rebuild).
        Exec
        (
            FileName: pwsh,
            Arguments: `-Command "Promote-ProGetPackage -Name $PackageName -Version $ResolvedPackageVersion -FromFeed nuget-integration -ToFeed nuget-qa -Reason 'QA-PASS for build $BuildId'"`,
            WorkingDirectory: $SourcePath,
            SuccessExitCode: 0
        );

        # Restore the promoted package and run the full regression suite with coverage.
        # (Tests use the package as a build dependency; they do NOT rebuild it.)
        Exec
        (
            FileName: pwsh,
            Arguments: `-Command "Invoke-PromotedPackageTests -Name $PackageName -Version $ResolvedPackageVersion -Feed nuget-qa -CollectCoverage -ResultsPath _generated\testresults\$Tier"`,
            WorkingDirectory: $SourcePath,
            SuccessExitCode: 0
        );

        Create-Artifact TestResults ( From: _generated\testresults\$Tier, Include: @(*.trx, coverage.cobertura.xml) );
    }
}

# -------------------------------------------------------------------------
# Stage Production — promote artifact to nuget-stable + smoke test
# -------------------------------------------------------------------------
stage Production
{
    if $Tier == Production
    {
        # Promote the existing artifact (no rebuild).
        Exec
        (
            FileName: pwsh,
            Arguments: `-Command "Promote-ProGetPackage -Name $PackageName -Version $ResolvedPackageVersion -FromFeed nuget-qa -ToFeed nuget-stable -Reason 'PROD-APPROVAL for build $BuildId'"`,
            WorkingDirectory: $SourcePath,
            SuccessExitCode: 0
        );

        # Smoke check against the promoted package on the production feed.
        # (Tests use the package as a build dependency; they do NOT rebuild it.)
        Exec
        (
            FileName: pwsh,
            Arguments: `-Command "Invoke-PromotedPackageTests -Name $PackageName -Version $ResolvedPackageVersion -Feed nuget-stable -TestFilter 'Category=Smoke' -ResultsPath _generated\testresults\$Tier"`,
            WorkingDirectory: $SourcePath,
            SuccessExitCode: 0
        );

        Create-Artifact TestResults ( From: _generated\testresults\$Tier, Include: @(*.trx) );
    }
}
```

> _`Promote-ProGetPackage` is implemented; `Invoke-PromotedPackageTests`
> is currently spec — see [BuildMaster-Pipeline-Topology.md §4](BuildMaster-Pipeline-Topology.md#4-powershell-automation-surface)
> for status. Both `Invoke-PromotedPackageTests` and
> `Invoke-PromotedModuleTests` now appear in the §4 cmdlet inventory._

**Individual project builds:** the per-project plan
`src/ATAP.Utilities.BuildTooling.BuildMaster/Plans/CSharpPackage-PerProject.otter`
follows exactly the same shape as the solution-level plan above — the
Experimental stage builds and pushes a single `.csproj` (with `$ProjectPath`
overridden), and every non-Experimental stage calls `Promote-ProGetPackage`
against that one package and then runs `Invoke-PromotedPackageTests` against
the promoted artifact. The artifact is built once at Experimental and promoted
thereafter; no non-Experimental stage rebuilds. See §9 below for the
per-project plan inputs and how to trigger a manual build.

---

## 6. The `ATAP.Utilities` Meta-package

A meta-package is an empty project whose only content is `<PackageReference>` entries pointing to every individual library. It gives consumers a single install that pulls in everything.

### 6.1 Create the project

```path
src/
└── ATAP.Utilities/
    └── ATAP.Utilities.csproj
```

Minimal `.csproj`:

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <IsPackable>true</IsPackable>
    <!-- No code — only dependencies -->
    <EnableDefaultItems>false</EnableDefaultItems>
    <Description>
      Meta-package that pulls in all ATAP.Utilities C# libraries in one install.
    </Description>
    <PackageTags>ATAP utilities meta-package</PackageTags>
  </PropertyGroup>

  <!-- ── Service libraries ── -->
  <ItemGroup>
    <PackageReference Include="ATAP.Services.ConsoleMonitor"          Version="*" />
    <PackageReference Include="ATAP.Services.ConsoleMonitor.Interfaces" Version="*" />
    <PackageReference Include="ATAP.Services.ConsoleSink"             Version="*" />
    <PackageReference Include="ATAP.Services.ConsoleSink.Interfaces"  Version="*" />
    <PackageReference Include="ATAP.Services.ConsoleSource"           Version="*" />
    <PackageReference Include="ATAP.Services.ConsoleSource.Interfaces" Version="*" />
    <PackageReference Include="ATAP.Services.FileSystemWatchers"      Version="*" />
    <PackageReference Include="ATAP.Services.FileSystemWatchers.Interfaces" Version="*" />
    <PackageReference Include="ATAP.Services.GenerateProgram"         Version="*" />
    <PackageReference Include="ATAP.Services.GenerateProgram.Interfaces" Version="*" />
    <PackageReference Include="ATAP.Services.GenerateProgram.StringConstants" Version="*" />
    <PackageReference Include="ATAP.Services.TcpWithResilience"       Version="*" />
    <PackageReference Include="ATAP.Services.TcpWithResilience.Interfaces" Version="*" />
    <PackageReference Include="ATAP.Services.Timers"                  Version="*" />
    <PackageReference Include="ATAP.Services.Timers.Interfaces"       Version="*" />
  </ItemGroup>

  <!-- ── Utility libraries ── -->
  <ItemGroup>
    <PackageReference Include="ATAP.Utilities.AutoDoc"                Version="*" />
    <PackageReference Include="ATAP.Utilities.BuildTooling.CSharp"    Version="*" />
    <PackageReference Include="ATAP.Utilities.Collection.Extensions"  Version="*" />
    <PackageReference Include="ATAP.Utilities.ComputerInventory"      Version="*" />
    <PackageReference Include="ATAP.Utilities.ConcurrentObservableCollections" Version="*" />
    <PackageReference Include="ATAP.Utilities.Configuration"          Version="*" />
    <PackageReference Include="ATAP.Utilities.Configuration.Extensions" Version="*" />
    <PackageReference Include="ATAP.Utilities.Configuration.Secrets"  Version="*" />
    <PackageReference Include="ATAP.Utilities.CryptoCoin"             Version="*" />
    <PackageReference Include="ATAP.Utilities.CryptoMiner"            Version="*" />
    <PackageReference Include="ATAP.Utilities.DatabaseManagement"     Version="*" />
    <PackageReference Include="ATAP.Utilities.DateTime"               Version="*" />
    <PackageReference Include="ATAP.Utilities.Enumeration"            Version="*" />
    <PackageReference Include="ATAP.Utilities.ETW"                    Version="*" />
    <PackageReference Include="ATAP.Utilities.FileIO"                 Version="*" />
    <PackageReference Include="ATAP.Utilities.GenerateProgram"        Version="*" />
    <PackageReference Include="ATAP.Utilities.GenerateProgram.Interfaces" Version="*" />
    <PackageReference Include="ATAP.Utilities.GenericHost.Extensions" Version="*" />
    <PackageReference Include="ATAP.Utilities.Gmail"                  Version="*" />
    <PackageReference Include="ATAP.Utilities.GraphDataStructures"    Version="*" />
    <PackageReference Include="ATAP.Utilities.GraphDataStructures.Interfaces" Version="*" />
    <PackageReference Include="ATAP.Utilities.Http"                   Version="*" />
    <PackageReference Include="ATAP.Utilities.IAC.Ansible"            Version="*" />
    <PackageReference Include="ATAP.Utilities.Images.Enumerations"    Version="*" />
    <PackageReference Include="ATAP.Utilities.Loader"                 Version="*" />
    <PackageReference Include="ATAP.Utilities.Logging"                Version="*" />
    <PackageReference Include="ATAP.Utilities.ManimVideoGenerator"    Version="*" />
    <PackageReference Include="ATAP.Utilities.MessageQueue"           Version="*" />
    <PackageReference Include="ATAP.Utilities.ORMLite.Models"         Version="*" />
    <PackageReference Include="ATAP.Utilities.Persistence"            Version="*" />
    <PackageReference Include="ATAP.Utilities.Philote"                Version="*" />
    <PackageReference Include="ATAP.Utilities.Plugin"                 Version="*" />
    <PackageReference Include="ATAP.Utilities.Reactive.Extensions"    Version="*" />
    <PackageReference Include="ATAP.Utilities.RealEstate.Enumerations" Version="*" />
    <PackageReference Include="ATAP.Utilities.Secrets"                Version="*" />
    <PackageReference Include="ATAP.Utilities.Serializer"             Version="*" />
    <PackageReference Include="ATAP.Utilities.String"                 Version="*" />
    <PackageReference Include="ATAP.Utilities.StronglyTypedId"        Version="*" />
    <PackageReference Include="ATAP.Utilities.Testing"                Version="*" />
    <PackageReference Include="ATAP.Utilities.VoiceAttack"            Version="*" />
  </ItemGroup>
</Project>
```

> `Version="*"` resolves to the highest _compatible_ version available in the active feed. For locked production releases, pin to an exact version (e.g. `Version="0.1.42"`).

### 6.2 Add to `ATAP.Utilities.sln`

```powershell
dotnet sln ATAP.Utilities.sln add src\ATAP.Utilities\ATAP.Utilities.csproj
```

The solution-level `dotnet pack` in the OtterScript plan will then include it automatically.

---

## 7. Building an Individual Package Locally

```powershell
# Build one package
dotnet build src\ATAP.Utilities.Philote\ATAP.Utilities.Philote.csproj --configuration Release

# Pack one package
dotnet pack src\ATAP.Utilities.Philote\ATAP.Utilities.Philote.csproj `
    --configuration Release `
    --output _generated\nuget\local

# Push to local experimental feed (requires PROGET_ADMIN_API_KEY env var)
$apiKey = [System.Environment]::GetEnvironmentVariable('PROGET_ADMIN_API_KEY', 'User')
dotnet nuget push _generated\nuget\local\*.nupkg `
    --source http://localhost:50000/nuget/nuget-experimental/v3/index.json `
    --api-key $apiKey
```

---

## 8. Repository Monitors in BuildMaster

> **Sprint-7 note:** under the immutable-build strategy, the **build** is
> triggered exactly once (from the branch that produces the artifact) and the
> tier is resolved from the NBGV prerelease label, not from the branch the
> build came from. The monitors below remain useful as **automatic triggers**
> for the Experimental build on each branch type, but the tier they imply is
> only the _starting_ tier — the artifact's actual journey through the five
> feeds is driven by promotion calls, not by branch matches. Treat the
> "Production stage" monitor as the trigger for "build the
> release-branch artifact and start it at Experimental, then promote upward as
> tests pass." The Production tier is reached by promotion, not by direct
> push from a `main` build. See [Release-Branch-and-Manifest.md](Release-Branch-and-Manifest.md)
> for release-branch flow.

Create one **Repository Monitor** per branch-type to **trigger the
Experimental build**:

| Monitor name             | Git ref pattern          | Triggers Experimental build for |
| ------------------------ | ------------------------ | ------------------------------- |
| `ATAP.CSharp-Sprint`     | `refs/heads/*-sprint-*`  | Sprint-branch commits           |
| `ATAP.CSharp-Alpha`      | `refs/heads/*-alpha-*`   | Alpha-branch commits            |
| `ATAP.CSharp-Beta`       | `refs/heads/integration` | Integration-branch commits      |
| `ATAP.CSharp-QA`         | `refs/heads/qa`          | QA-branch commits               |
| `ATAP.CSharp-Production` | `refs/heads/release/*`   | Release-branch tag commits      |

Steps to create (BuildMaster UI):

1. **Admin → Repository Monitors → Add Monitor**
2. Select the `ATAP.Utilities-CSharp` application.
3. Set **Repository** to the GitHub repo (`BillHertzing/ATAP.Utilities`).
4. Set **Git Ref Filter** to the pattern from the table above.
5. Set **Plan** to `CSharpPackage-5Stage`.
6. Set **Release** to the active release in the application.

---

## 9. Per-Package Builds — Shared Application with `$ProjectPath` Override

With 100+ packages in the solution, a dedicated BuildMaster Application per package is not
tractable. Instead, the `CSharpPackage-PerProject` plan is loaded into the **same**
`ATAP.Utilities-CSharp` application used for full-solution builds. A per-package build is
triggered manually by overriding `$ProjectPath` at build time.

No additional Repository Monitors are needed — the five monitors defined in §8 already cover
all tier-branch patterns. `CSharpPackage-RepositoryMonitors.otter` in the repo is retained as
a reference document but is not imported into BuildMaster.

### 9.1 How the plan works

`CSharpPackage-PerProject.otter` (`src/ATAP.Utilities.BuildTooling.BuildMaster/Plans/CSharpPackage-PerProject.otter`)
accepts the following Build Variables:

| Variable         | Required | Default         | Description                                                 |
| ---------------- | -------- | --------------- | ----------------------------------------------------------- |
| `$ProjectPath`   | yes      | —               | Repo-root-relative path to the `.csproj` (or a mini `.sln`) |
| `$Configuration` | no       | `Release`       | MSBuild configuration                                       |
| `$RunTests`      | no       | `true`          | Set `false` to skip the test step                           |
| `$TestFilter`    | no       | _(empty = all)_ | xUnit trait filter e.g. `Category=Unit`                     |
| `$ForcePublish`  | no       | `false`         | Set `true` to push packages even at Sprint tier             |

The plan:

1. Acquires source via `GitHub::Get-Source`.
2. Reads `nbgv get-version` to determine the tier and target feed — same logic as the full-solution plan.
3. Runs `dotnet build $ProjectPath`.
4. Runs `dotnet test $ProjectPath` (skipped at Sprint unless `$RunTests = true`); collects code coverage at QA and Production tiers.
5. Runs `dotnet pack $ProjectPath` and captures a `{PackageSlug}-Packages` artifact.
6. Runs `dotnet nuget push` to the resolved feed (skipped at Sprint unless `$ForcePublish = true`).

### 9.2 Triggering a per-package build

1. Open BuildMaster → application **`ATAP.Utilities-CSharp`**.
2. Click **Builds → Create Build**.
3. Select plan **`CSharpPackage-PerProject`**.
4. In the **Build Variables** panel, set `$ProjectPath` to the desired project (see §9.3).
5. Optionally set `$RunTests`, `$TestFilter`, or `$ForcePublish`.
6. Click **Create**.

The build resolves the tier from the NBGV label in the checked-out branch and targets the
correct ProGet feed automatically.

### 9.3 Package path reference

Set `$ProjectPath` to one of these values when creating a manual build:

| Package                              | `$ProjectPath` value                                                               |
| ------------------------------------ | ---------------------------------------------------------------------------------- |
| `ATAP.Utilities.Philote`             | `src\ATAP.Utilities.Philote\ATAP.Utilities.Philote.csproj`                         |
| `ATAP.Utilities.Serializer`          | `src\ATAP.Utilities.Serializer\ATAP.Utilities.Serializer.csproj`                   |
| `ATAP.Utilities.Secrets`             | `src\ATAP.Utilities.Secrets\ATAP.Utilities.Secrets.csproj`                         |
| `ATAP.Utilities.StronglyTypedId`     | `src\ATAP.Utilities.StronglyTypedId\ATAP.Utilities.StronglyTypedId.csproj`         |
| `ATAP.Utilities.Persistence`         | `src\ATAP.Utilities.Persistence\ATAP.Utilities.Persistence.csproj`                 |
| `ATAP.Utilities.MessageQueue`        | `src\ATAP.Utilities.MessageQueue\ATAP.Utilities.MessageQueue.csproj`               |
| `ATAP.Utilities.Configuration`       | `src\ATAP.Utilities.Configuration\ATAP.Utilities.Configuration.csproj`             |
| `ATAP.Utilities.ComputerInventory`   | `src\ATAP.Utilities.ComputerInventory\ATAP.Utilities.ComputerInventory.csproj`     |
| `ATAP.Utilities.AutoDoc`             | `src\ATAP.Utilities.AutoDoc\ATAP.Utilities.AutoDoc.csproj`                         |
| `ATAP.Utilities.CryptoCoin`          | `src\ATAP.Utilities.CryptoCoin\ATAP.Utilities.CryptoCoin.csproj`                   |
| `ATAP.Utilities.CryptoMiner`         | `src\ATAP.Utilities.CryptoMiner\ATAP.Utilities.CryptoMiner.csproj`                 |
| `ATAP.Utilities.DatabaseManagement`  | `src\ATAP.Utilities.DatabaseManagement\ATAP.Utilities.DatabaseManagement.csproj`   |
| `ATAP.Utilities.GenerateProgram`     | `src\ATAP.Utilities.GenerateProgram\ATAP.Utilities.GenerateProgram.csproj`         |
| `ATAP.Utilities.GraphDataStructures` | `src\ATAP.Utilities.GraphDataStructures\ATAP.Utilities.GraphDataStructures.csproj` |
| `ATAP.Utilities.Logging`             | `src\ATAP.Utilities.Logging\ATAP.Utilities.Logging.csproj`                         |
| `ATAP.Utilities.Plugin`              | `src\ATAP.Utilities.Plugin\ATAP.Utilities.Plugin.csproj`                           |
| `ATAP.Utilities.Testing`             | `src\ATAP.Utilities.Testing\ATAP.Utilities.Testing.csproj`                         |
| `ATAP.Utilities` _(meta)_            | `src\ATAP.Utilities\ATAP.Utilities.csproj`                                         |

---

## 10. Security Notes

- **Never** store the ProGet API key in source. Always read from the `PROGET_ADMIN_API_KEY` User-scope environment variable:

  ```powershell
  $apiKey = [System.Environment]::GetEnvironmentVariable('PROGET_ADMIN_API_KEY', 'User')
  ```

- In OtterScript, wrap the key with `$Decrypt(...)` and declare it as a **masked** Application Variable.
- `dotnet nuget push` leaks the key to process stdout if `--api-key` is visible in logs — use BuildMaster's masked variable support so the value is redacted in the build log.

---

## 11. Key Source Files

| File                                                                               | Role                                                                                                                                                                |
| ---------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `version.json` (repo root)                                                         | NBGV configuration; sets the default prerelease label and SemVer 2 mode for all projects                                                                            |
| `{project}/version.json`                                                           | Optional per-project NBGV override; inherits from root when absent                                                                                                  |
| `Directory.Build.targets`                                                          | Solution-wide import of `ATAP.Utilities.BuildTooling.targets`; contains legacy `<PackageReference Update>` overrides (being migrated to `Directory.Packages.props`) |
| `Directory.Packages.props`                                                         | Central Package Management — target state after migration; declares all `<PackageVersion>` entries with `ManagePackageVersionsCentrally=true`                       |
| `src/ATAP.Utilities.BuildTooling.PowerShell/public/Publish-ATAPUtilities.ps1`      | Batch script to build and push all libraries locally in dependency order; used outside of BuildMaster for developer publishing runs                                 |
| `src/ATAP.Utilities.BuildTooling.BuildMaster/Plans/CSharpPackage-5Stage.otter`     | OtterScript plan for full-solution builds (§5)                                                                                                                      |
| `src/ATAP.Utilities.BuildTooling.BuildMaster/Plans/CSharpPackage-PerProject.otter` | OtterScript plan for individual package builds (§9)                                                                                                                 |

---

## 12. Quick-start Checklist

- [ ] Verify all five ProGet feeds exist and are reachable at `http://localhost:50000`
- [ ] Store `PROGET_ADMIN_API_KEY` in Bitwarden and confirm the env var is set at User scope
- [ ] Create the `ATAP.Utilities-CSharp` BuildMaster application and set Application Variables (§4.1)
- [ ] Load `CSharpPackage-5Stage` plan into BuildMaster via UI paste or Git raft (see §5 / §12)
- [ ] Load `CSharpPackage-PerProject` plan into the same application (see §9)
- [ ] Add `src\ATAP.Utilities\ATAP.Utilities.csproj` (meta-package) and add it to the solution
- [ ] Add to `ATAP.Utilities.sln` all projects that currently lack a solution entry
- [ ] Create five Repository Monitors (§8) pointing to `CSharpPackage-5Stage`
- [ ] Trigger a manual Sprint build (full solution) and verify packages land in `nuget-experimental`
- [ ] To rebuild one package: Create Build → plan `CSharpPackage-PerProject` → override `$ProjectPath` (§9.2)
- [ ] Promote to Alpha by changing `version.json` label to `Alpha` and pushing

---

## 13. NuGet.config Reference

<!-- Philote: 3bf42c43-15a3-4d8b-9ada-83365d37c450 -->

### 13.1 Correct schema for HTTP feeds

ToDo: Figure out how to create the NuGet.config file per host - maybe have it written when a sprint starts, and re-written before it gets committed at sprint end?
The NuGet.config file is placed at the base of the ATAP.Utilities repository
The entries have been built from the following $global:Settings variables

ProGetAdminUriHost = localhost
ProGetAdminUriPort = 50000
ProGetAdminUriScheme = http
ProGetBaseUrl = `http://localhost:50000`

ToDo: add HTTPS protocol once PKI infrastructure for the organization is in place
All five ProGet feeds are currently served over HTTP (`http://localhost:50000`).
NuGet 6.0+ enforces HTTPS by default and will refuse to connect to an HTTP source **unless**
`allowInsecureConnections = true` is declared for that source.

ToDo: Document PackageSourceMapping to support AceCommander packages. The example here below is for AceCommander repository. The ATAP.Utilities repository's NuGet.config file does not contain the line `<package pattern="AceCommander.*" />` under the `packageSource` property

```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
    <!-- ProGet feeds — local dev workstation (5-tier model, sprint branch) -->
    <!-- ProGet installed on port 50000 (configured in ProGet.config, symlinked from ATAP.IAC) -->
    <!-- Override port in NuGet.config if ProGet moves to a different port -->
    <!-- allowInsecureConnections is required because localhost ProGet uses HTTP, not HTTPS -->
    <!-- ToDo: [Security Concern] make the feeds require HTTPS -->
    <add key="nuget-experimental"
      value="http://localhost:50000/nuget/nuget-experimental/v3/index.json"
      allowInsecureConnections="true" />
    <add key="nuget-development"
      value="http://localhost:50000/nuget/nuget-development/v3/index.json"
      allowInsecureConnections="true" />
    <add key="nuget-integration"
      value="http://localhost:50000/nuget/nuget-integration/v3/index.json"
      allowInsecureConnections="true" />
    <add key="nuget-qa"
      value="http://localhost:50000/nuget/nuget-qa/v3/index.json"
      allowInsecureConnections="true" />
    <add key="nuget-stable"
      value="http://localhost:50000/nuget/nuget-stable/v3/index.json"
      allowInsecureConnections="true" />
    <!-- nuget.org — primary source for all third-party packages -->
    <add key="nuget.org"
      value="https://api.nuget.org/v3/index.json"
      protocolVersion="3" />
  </packageSources>

<!-- ==================== Package Source Mapping ====================
    Required to resolve NuGet warning NU1507.
    When Central Package Management (CPM) is enabled via Directory.Packages.props
    (ManagePackageVersionsCentrally=true), NuGet requires that all defined package
    sources be mapped to package name patterns. Without this, NuGet warns that
    it cannot deterministically decide which source to use for a given package.

    Rules:
      - Every active packageSource must have at least one <package pattern="..." /> entry.
      - The wildcard pattern "*" on nuget.org catches all third-party packages
        not explicitly mapped to another source.
      - The "ATAP.*" and AceCommander.* patterns on the ProGet feeds ensures internal packages are
        resolved exclusively from the local ProGet instance and are never
        accidentally queried from nuget.org.
      - Packages that match a pattern on a source will ONLY be resolved from
        that source — NuGet will not fall back to other sources.

    See: https://aka.ms/nuget-package-source-mapping
    See: https://learn.microsoft.com/en-us/nuget/reference/errors-and-warnings/nu1507
  -->
  <packageSourceMapping>
    <!-- All standard third-party packages come from nuget.org -->
    <packageSource key="nuget.org">
      <package pattern="*" />
    </packageSource>
    <!-- Internal ATAP packages: on sprint branches, resolve only from nuget-experimental.
         Higher-tier feeds are listed for restore visibility but ATAP.* packages are only
         pinned to nuget-experimental here. BuildMaster promotes packages up the tier chain.
         See SC-INFRA-001 in TASKS.md for the full package migration/promotion design. -->
    <packageSource key="nuget-experimental">
      <package pattern="ATAP.*" />
      <package pattern="AceCommander.*" />
    </packageSource>
    <!-- nuget-development through nuget-stable: required entries for NU1507 compliance.
         All 5 feeds must have a mapping entry when listed as active sources. -->
    <packageSource key="nuget-development">
      <package pattern="AceCommander.*" />
      <package pattern="ATAP.*" />
    </packageSource>
    <packageSource key="nuget-integration">
      <package pattern="AceCommander.*" />
      <package pattern="ATAP.*" />
    </packageSource>
    <packageSource key="nuget-qa">
      <package pattern="AceCommander.*" />
      <package pattern="ATAP.*" />
    </packageSource>
    <packageSource key="nuget-stable">
      <package pattern="AceCommander.*" />
      <package pattern="ATAP.*" />
    </packageSource>
  </packageSourceMapping>
</configuration>
```

> Note: the ProGet base URL port `50000` corresponds to `$global:configRootKeys['ProGetAdminUriPortConfigRootKey']`
> in `HostSettings.ps1`. If you change the port, update all six URLs here and re-run `dotnet nuget list source`.

### 13.2 Verify effective config

After editing, confirm NuGet picks up the settings:

```Powershell
# Lists all registered sources and their enabled/disabled state
dotnet nuget list source
```

## 14. Lightweight Local Alternative: BaGet

BaGet is a viable FOSS NuGet server for developer machines, labs, and other lightweight scenarios where the goal is simply to host a NuGet v3 feed without standing up the broader ProGet feature set.

### 14.1 When BaGet is useful

- Single-container deployment for a local or offline development environment.
- Simple package push and restore workflows over the NuGet v3 protocol.
- Low-friction experimentation when a developer wants a disposable internal feed.

A minimal local BaGet instance can be started with Docker:

```Powershell
docker run --name baget `
  -p 5555:8080 `
  -e ApiKey='local-dev-key' `
  -v C:\BagetData:/var/baget `
  loicsharma/baget:latest
```

Once running, the feed endpoint is typically:

```text
http://localhost:5555/v3/index.json
```

That makes BaGet a reasonable option for local package validation or isolated developer workflows.

### 14.2 Why this repository chose ProGet instead

BaGet was evaluated as a possible replacement for ProGet, but it is not sufficient for the repository's operational pipeline needs.

Compared to ProGet, BaGet lacks many of the features required by the 5-tier package promotion model described in this document:

- No built-in package promotion pipeline across Experimental, Development, Integration, QA, and Stable feeds.
- No equivalent administrative model for feed connectors, broader governance, or richer operational controls.
- No comparable out-of-the-box support for the release-management workflow expected by BuildMaster and the repository's promotion stages.

In addition, while BaGet remains a useful FOSS project, it appears to have seen relatively limited recent development activity compared to ProGet's actively maintained commercial platform. For this repository, that raised additional risk around long-term operational fit.

The result is a clear split in guidance:

- Use ProGet for the authoritative repository pipeline described in this document.
- Use BaGet only as a lightweight local alternative when you need a small, disposable, developer-focused NuGet v3 server.
