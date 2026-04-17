# BuildMaster + ProGet: C# Package Build and Publish Pipeline

**Repository:** ATAP.Utilities
**Scope:** All C# / .NET projects under `src/`
**Goal:** Build and publish every package individually _and_ as a single `ATAP.Utilities` meta-package, following the 5-tier promotion model already used for PowerShell modules.

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
The ProGet admin API key is stored in Bitwarden under the env var `PROGET_ADMIN_API_KEY`.

### 2.1 Feed Settings Checklist

For **each** of the five feeds, apply these settings in the ProGet admin UI
(Manage Feed → Feed Settings):

- **Package promotion**: enabled (to allow BuildMaster to promote from tier N to N+1).
- **Drop-older-prerelease**: enabled on `nuget-experimental` to prevent unbounded growth.
- **Connectors**: add `nuget.org` as a connector on `nuget-experimental` (upstream packages flow down only).
- **Require API key for push**: yes — use `PROGET_ADMIN_API_KEY` stored as a BuildMaster variable (masked).
- **Allow anonymous read**: yes on all feeds (matches `<packageSourceCredentials>` — no credentials block).

### 2.2 Feed Connector Topology

Each feed exposes a **restore source** that spans itself and selected upstream feeds via ProGet
connectors. Configure these connector relationships in the ProGet admin UI (Manage Feed → Connectors).

| Restore from feed    | Resolves packages from                                                     |
| -------------------- | -------------------------------------------------------------------------- |
| `nuget-experimental` | `nuget-experimental` + `nuget.org` (upstream connector)                   |
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
  "version": "0.1-Sprint.{height}",
  "nuGetPackageVersion": { "semVer": 2 }
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

Each stage gate:

- **Experimental → Development**: automatic (no gate) on passing build.
- **Development → Integration**: requires no open blocker issues; optionally a manual approval.
- **Integration → QA**: requires integration test results artifact present with zero failures.
- **QA → Production**: requires manual approval from the release manager.

---

## 5. OtterScript Plan — `CSharpPackage-5Stage.otter`

Save this file as `Build/BuildMaster/Plans/CSharpPackage-5Stage.otter`.

The plan follows exactly the same shape as `PowerShellModule-5Stage.otter`:

1. Acquire source.
2. Resolve tier from NBGV.
3. Dispatch to the matching stage block.

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
# Stage Development — build + unit tests + pack + publish to nuget-development
# -------------------------------------------------------------------------
stage Development
{
    if $Tier == Development
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
            Arguments: `test ATAP.Utilities.sln --configuration $Configuration --no-build --logger trx --results-directory _generated\testresults\$Tier`,
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

        Create-Artifact TestResults
        (
            From: _generated\testresults\$Tier,
            Include: @(*.trx)
        );
        Create-Artifact Packages
        (
            From: _generated\nuget\$Tier,
            Include: @(*.nupkg, *.snupkg)
        );
    }
}

# -------------------------------------------------------------------------
# Stage Integration — build + unit + integration tests + pack + publish
# -------------------------------------------------------------------------
stage Integration
{
    if $Tier == Integration
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
            Arguments: `test ATAP.Utilities.sln --configuration $Configuration --no-build --filter "Category=Unit|Category=Integration" --logger trx --results-directory _generated\testresults\$Tier`,
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

        Create-Artifact TestResults ( From: _generated\testresults\$Tier, Include: @(*.trx) );
        Create-Artifact Packages    ( From: _generated\nuget\$Tier,       Include: @(*.nupkg, *.snupkg) );
    }
}

# -------------------------------------------------------------------------
# Stage QA — full suite + coverage + pack + publish
# -------------------------------------------------------------------------
stage QA
{
    if $Tier == QA
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
            Arguments: `test ATAP.Utilities.sln --configuration $Configuration --no-build --collect:"XPlat Code Coverage" --results-directory _generated\testresults\$Tier`,
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

        Create-Artifact TestResults ( From: _generated\testresults\$Tier, Include: @(*.trx, coverage.cobertura.xml) );
        Create-Artifact Packages    ( From: _generated\nuget\$Tier,       Include: @(*.nupkg, *.snupkg) );
    }
}

# -------------------------------------------------------------------------
# Stage Production — signed packages + full suite + publish to nuget-stable
# -------------------------------------------------------------------------
stage Production
{
    if $Tier == Production
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
            Arguments: `test ATAP.Utilities.sln --configuration $Configuration --no-build --collect:"XPlat Code Coverage" --results-directory _generated\testresults\$Tier`,
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

        # Optional: sign packages before push
        # Exec ( FileName: dotnet, Arguments: `nuget sign _generated\nuget\$Tier\*.nupkg --certificate-path ... --timestamper ...` );

        Exec
        (
            FileName: dotnet,
            Arguments: `nuget push _generated\nuget\$Tier\*.nupkg --source $ProGetUrl/nuget/$FeedName/v3/index.json --api-key $Decrypt($ProGetApiKey)`,
            WorkingDirectory: $SourcePath,
            SuccessExitCode: 0
        );

        Create-Artifact TestResults ( From: _generated\testresults\$Tier, Include: @(*.trx, coverage.cobertura.xml) );
        Create-Artifact Packages    ( From: _generated\nuget\$Tier,       Include: @(*.nupkg, *.snupkg) );
    }
}
```

> **Individual project builds:** Replace `ATAP.Utilities.sln` in every `dotnet build / test / pack` call with the specific `.csproj` path (e.g. `src\ATAP.Utilities.Philote\ATAP.Utilities.Philote.csproj`) to build or pack a single package. The parameterized plan `Build/BuildMaster/Plans/CSharpPackage-PerProject.otter` and its matching monitors `Build/BuildMaster/Monitors/CSharpPackage-RepositoryMonitors.otter` implement this pattern — see §9 below.

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

Create one **Repository Monitor** per tier-branch pattern:

| Monitor name             | Git ref pattern          | Triggers build for |
| ------------------------ | ------------------------ | ------------------ |
| `ATAP.CSharp-Sprint`     | `refs/heads/*-sprint-*`  | Sprint stage       |
| `ATAP.CSharp-Alpha`      | `refs/heads/*-alpha-*`   | Alpha stage        |
| `ATAP.CSharp-Beta`       | `refs/heads/integration` | Beta stage         |
| `ATAP.CSharp-QA`         | `refs/heads/qa`          | QA stage           |
| `ATAP.CSharp-Production` | `refs/heads/main`        | Production stage   |

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

`CSharpPackage-PerProject.otter` (`Build/BuildMaster/Plans/CSharpPackage-PerProject.otter`)
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

| File | Role |
| ---- | ---- |
| `version.json` (repo root) | NBGV configuration; sets the default prerelease label and SemVer 2 mode for all projects |
| `{project}/version.json` | Optional per-project NBGV override; inherits from root when absent |
| `Directory.Build.targets` | Solution-wide import of `ATAP.Utilities.BuildTooling.targets`; contains legacy `<PackageReference Update>` overrides (being migrated to `Directory.Packages.props`) |
| `Directory.Packages.props` | Central Package Management — target state after migration; declares all `<PackageVersion>` entries with `ManagePackageVersionsCentrally=true` |
| `src/ATAP.Utilities.BuildTooling.PowerShell/public/Publish-ATAPUtilities.ps1` | Batch script to build and push all libraries locally in dependency order; used outside of BuildMaster for developer publishing runs |
| `Build/BuildMaster/Plans/CSharpPackage-5Stage.otter` | OtterScript plan for full-solution builds (§5) |
| `Build/BuildMaster/Plans/CSharpPackage-PerProject.otter` | OtterScript plan for individual package builds (§9) |

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
