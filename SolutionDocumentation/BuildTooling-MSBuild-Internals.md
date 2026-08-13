# BuildTooling MSBuild Internals

> **Task 13.62 security cutover:** Inline MSBuild raw-key examples below are superseded. `PublishAfterBuild` passes `ProGet.Admin.API.Key` only as a SecretName to `Invoke-ProGetNuGetPublish.ps1`; MSBuild never receives a key value.

_Migrated from `_Planning/Explainers/0013-BuildTooling-CSharp-MSBuild-interaction.md` (lines 1-791). Describes how `Directory.Build.props`, `Directory.Build.targets`, the `ATAP.Utilities.BuildTooling.CSharp` task DLL, and `ATAP.Utilities.BuildTooling.targets` cooperate to give every solution project automatic version management, JSON-settings copying, multi-RID publishing, and NuGet push-to-ProGet during an ordinary `dotnet build` or `dotnet pack`._

> **Production pack engine (Task 14.105):** local `dotnet pack` is not a
> release-artifact source. The C# BuildMaster runner resolves stable Visual
> Studio Build Tools 2026 MSBuild 18.8+, verifies the NuGet Build Tools component
> and SDK-selected `NuGet.Build.Tasks.Pack.dll` are NuGet 7.8+, and requires
> `Microsoft.NetCore.Component.SDK` for full-MSBuild SDK resolution. It invokes
> `/t:Pack` with `Deterministic=true` and a Git-commit-derived
> `DeterministicTimestamp`; the two-pack hash gate precedes publication.

---

## File Roles

| File                                      | Role                                                                           |
| ----------------------------------------- | ------------------------------------------------------------------------------ |
| `Directory.Build.props`                   | Solution-wide property defaults, injected **before** each `.csproj`            |
| `Directory.Build.targets`                 | Solution-wide targets, injected **after** each `.csproj`                       |
| `src/ATAP.Utilities.BuildTooling.CSharp/` | The project that compiles the custom MSBuild task DLL                          |
| `ATAP.Utilities.BuildTooling.targets`     | The targets file shipped with the task DLL; activates tasks during every build |

---

## How MSBuild Discovers and Loads These Files

MSBuild walks **up** the directory tree from each `.csproj` file, searching for `Directory.Build.props` and `Directory.Build.targets`. It stops at the first file it finds. Because both files live at the solution root, every project in `src/` and `tests/` inherits them — no explicit `Import` in individual `.csproj` files.

Load order per project build:

```text
1. Directory.Build.props          ← injected BEFORE .csproj processing
2. <ProjectName>.csproj           ← the individual project file
3. Directory.Build.targets        ← injected AFTER .csproj processing
4. ATAP.Utilities.BuildTooling.targets  ← imported by Directory.Build.targets
```

---

## Directory.Build.props — Solution-Wide Property Defaults

### 1. Disable auto-generated AssemblyInfo

```xml
<GenerateAssemblyInfo>false</GenerateAssemblyInfo>
```

Lets each project own its `Properties/AssemblyInfo.cs` — the source of truth for version numbers that the custom tasks read and rewrite.

### 2. Solution-wide defaults for every project

```xml
<TargetFramework>net10.0</TargetFramework>
<RuntimeIdentifiers>win-x64;linux-x64</RuntimeIdentifiers>
<LangVersion>latest</LangVersion>
<Nullable>enable</Nullable>
<Configurations>Debug;Release;ReleaseWithTrace</Configurations>
```

Individual `.csproj` can override. The BuildTooling project itself clears `<TargetFramework></TargetFramework>` then sets `<TargetFrameworks>net8.0;net9.0;net10.0</TargetFrameworks>` to multi-target — the documented escape hatch.

### 3. Solution root and build-tools directory

```xml
<SolutionDir>$(MSBuildThisFileDirectory)</SolutionDir>
<SolutionBuildToolsBaseDir>$(SolutionDir)Build\</SolutionBuildToolsBaseDir>
```

### 4. Locate the pre-built custom task assembly (sentinel-file approach)

```xml
<!-- Read the deployed BuildTooling version from the sentinel file written by DeployBuildToolingToBuildDirectory. -->
<!-- Fallback to the last known-good version if the file does not yet exist (first bootstrap). -->
<ATAPBuildToolingVersion Condition="Exists('$(SolutionBuildToolsBaseDir)ATAP.Utilities.BuildTooling.current-version')"
  >$([System.IO.File]::ReadAllText('$(SolutionBuildToolsBaseDir)ATAP.Utilities.BuildTooling.current-version').Trim())</ATAPBuildToolingVersion>
<ATAPBuildToolingVersion Condition="'$(ATAPBuildToolingVersion)' == ''">0.1.0.1</ATAPBuildToolingVersion>
<ATAPBuildToolingRelativeBasePath>ATAP.Utilities.BuildTooling.$(ATAPBuildToolingVersion)\build\</ATAPBuildToolingRelativeBasePath>
<ATAPUtilitiesBuildToolingTargetsPath>$(SolutionBuildToolsBaseDir)$(ATAPBuildToolingRelativeBasePath)</ATAPUtilitiesBuildToolingTargetsPath>
<ATAPUtilitiesBuildToolingTasksAssembly Condition=" '$(MSBuildRuntimeType)' == 'Core'">
    $(ATAPUtilitiesBuildToolingTasksPath)\Release\net10.0\ATAP.Utilities.BuildTooling.CSharp.dll
</ATAPUtilitiesBuildToolingTasksAssembly>
```

`$([System.IO.File]::ReadAllText(...).Trim())` is an MSBuild property function that executes at property evaluation time. It reads the sentinel file content (e.g., `0.1.0`) and `.Trim()` strips trailing newlines. The `Exists` condition makes it safe before bootstrap. The fallback line provides a hardcoded default for the first-ever build.

Assembled path (for version `0.1.0`): `Build\ATAP.Utilities.BuildTooling.0.1.0\build\Release\net10.0\ATAP.Utilities.BuildTooling.CSharp.dll`.

### 5. Control task verbosity

```xml
<ATAPBuildToolingConfiguration>Debug</ATAPBuildToolingConfiguration>
<ATAPBuildToolingDebugVerbosity>Trace</ATAPBuildToolingDebugVerbosity>
```

When `ATAPBuildToolingConfiguration` is `Debug`, the targets file and tasks emit detailed log messages.

### 6. NuGet package metadata applied to every project

Author, copyright, license expression, repository URL, source-link settings — all set here so individual projects do not repeat them.

### 7. Suppress legacy code analysis and binding-redirect generation

```xml
<RunCodeAnalysis>false</RunCodeAnalysis>
<AutoGenerateBindingRedirects>false</AutoGenerateBindingRedirects>
```

---

## Directory.Build.targets — Solution-Wide Targets

Runs **after** each project's `.csproj`, so it can act on properties the `.csproj` set and extend the standard build pipeline.

### 1. Import the custom BuildTooling targets

```xml
<Import Project="$(ATAPUtilitiesBuildToolingTargetsPath)\ATAP.Utilities.BuildTooling.targets"
        Condition="Exists('$(ATAPUtilitiesBuildToolingTargetsPath)\ATAP.Utilities.BuildTooling.targets')" />
```

The `Condition="Exists(...)"` guard is critical. If the file does not yet exist (before bootstrap), the import is silently skipped and other projects can still compile.

### 2. Copy JSON settings files to the output directory

```xml
<Target Name="CopyJSONSettingsFilesToOutputDirectory">
    <Copy SourceFiles="@(JsonSettingsFiles)" DestinationFolder="$(OutDir)" />
</Target>
```

Files matching `*[Ss]ettings*.json` in a project directory are copied to build output. Hooked into `PrepareForRunDependsOn`.

### 3. Multi-RID / multi-framework `PublishAll` targets

`PublishAll`, `PublishProjectForAllRIDsIfTargetFrameworkSet`, `PublishProjectForAllFrameworksIfFrameworkUnset` allow `dotnet msbuild -t:PublishAll` to publish a project for every (TFM × RID) combination declared in the project.

### 4. Microsoft SourceLink in every project

```xml
<ItemGroup>
    <PackageReference Include="Microsoft.SourceLink.GitHub">
        <PrivateAssets>all</PrivateAssets>
    </PackageReference>
</ItemGroup>
```

Embeds git commit info into PDB files so debuggers can fetch the exact source.

---

## ATAP.Utilities.BuildTooling.CSharp — The Custom Tasks Project

A standard C# class library that produces a DLL loadable by MSBuild as a custom task assembly. It is also a NuGet package (`GeneratePackageOnBuild=true`).

### Key project file decisions

```xml
<!-- Clear the Directory.Build.props default so multi-targeting takes effect -->
<TargetFramework></TargetFramework>
<TargetFrameworks>net8.0;net9.0;net10.0</TargetFrameworks>

<GeneratePackageOnBuild>true</GeneratePackageOnBuild>
<IsPackable>true</IsPackable>
```

**Why clear `TargetFramework`?** `Directory.Build.props` sets `<TargetFramework>net10.0</TargetFramework>`. If a project sets `<TargetFrameworks>` (plural) without clearing the singular form first, MSBuild sees both and ignores the multi-value one.

**Why multi-target net8/9/10?** The task DLL is loaded by MSBuild's own process. Different developer machines may run different SDK versions, so shipping multiple TFMs maximizes compatibility.

### MSBuild task SDK references

```xml
<PackageReference Include="Microsoft.Build.Framework"/>
<PackageReference Include="Microsoft.Build.Utilities.Core" />
```

Provide the `Task` base class, `TaskLoggingHelper`, and `[Required]` / `[Output]` attributes.

### The targets file is shipped alongside the DLL

```xml
<None Update="ATAP.Utilities.BuildTooling.targets">
    <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
</None>
```

`ATAP.Utilities.BuildTooling.targets` is copied verbatim to `bin/Release/net*/`. When the NuGet package is created, both DLL and targets are embedded in `build/` per NuGet convention.

### The source code

`Utilities` (static) holds all executable logic. Task classes are thin wrappers because MSBuild does not allow a `Task`-derived class to call another `Task`-derived class's `Execute()` at runtime.

| Method                   | Purpose                                                                                                       |
| ------------------------ | ------------------------------------------------------------------------------------------------------------- |
| `GetVersion`             | Reads `Properties/AssemblyInfo.cs` using regex; extracts Major, Minor, Patch, Build, Revision, PackageVersion |
| `MakeBuild`              | Build = days since 2000-01-01; Revision = seconds-since-midnight ÷ 2                                          |
| `MakePackageVersion`     | Assembles the NuGet version string (e.g., `0.1.0-Alpha-005`), incrementing the label counter                  |
| `SetVersion`             | Rewrites `Properties/AssemblyInfo.cs` in-place with new version values                                        |
| `TryParsePackageVersion` | Parses an existing NuGet version string to determine current label/counter                                    |

Three MSBuild Task classes wrap these: **`GetVersion`** (reads current values; outputs `MajorVersion`, `MinorVersion`, `PatchVersion`, `PackageVersion`, `Build`, `Revision`), **`UpdateVersion`** (the primary workhorse — increments the label counter and writes back), **`SetVersion`** (writes a fully specified version).

### Version encoding in `Properties/AssemblyInfo.cs`

```csharp
[assembly:AssemblyVersion("0.1.0")]
[assembly:AssemblyFileVersion("0.1.9576.8317")]
[assembly:AssemblyInformationalVersion("0.1.0-Alpha-005")]
```

| Attribute                      | Encoded data                | Example           |
| ------------------------------ | --------------------------- | ----------------- |
| `AssemblyVersion`              | Major.Minor.Patch           | `0.1.0`           |
| `AssemblyFileVersion`          | Major.Minor.Build.Revision  | `0.1.9576.8317`   |
| `AssemblyInformationalVersion` | NuGet PackageVersion string | `0.1.0-Alpha-005` |

`Build = 9576` means 9576 days after 2000-01-01. `Revision = 8317` means 16,634 seconds past midnight UTC (8317 × 2).

---

## ATAP.Utilities.BuildTooling.targets — The Custom Targets File

Lives in two places:

- Canonical source: `src/ATAP.Utilities.BuildTooling.CSharp/ATAP.Utilities.BuildTooling.targets`
- Deployed copy (consumed at build time): `Build/ATAP.Utilities.BuildTooling.<version>/build/ATAP.Utilities.BuildTooling.targets` (version determined by sentinel file)

### `UsingTask` declarations

```xml
<UsingTask TaskName="ATAP.Utilities.BuildTooling.GetVersion"    AssemblyFile="$(ATAPUtilitiesBuildToolingTasksAssembly)" Condition="'$(ATAPUtilitiesBuildToolingTasksAssembly)' != ''" />
<UsingTask TaskName="ATAP.Utilities.BuildTooling.UpdateVersion" AssemblyFile="$(ATAPUtilitiesBuildToolingTasksAssembly)" Condition="'$(ATAPUtilitiesBuildToolingTasksAssembly)' != ''" />
<UsingTask TaskName="ATAP.Utilities.BuildTooling.SetVersion"    AssemblyFile="$(ATAPUtilitiesBuildToolingTasksAssembly)" Condition="'$(ATAPUtilitiesBuildToolingTasksAssembly)' != ''" />
```

The condition guards against (a) bootstrap before the assembly exists and (b) IDE static analysis without an MSBuild evaluation context.

### `BeforeCompile` — the version-update gate

Standard MSBuild extension point that runs before the C# compiler is invoked. Inputs/outputs make it incremental — skipped if no source file is newer than any output. Currently calls `UpdatePackageVersionBeforeOuterBuild` (the call site is commented out pending refactoring).

### `UpdatePackageVersionBeforeOuterBuild` — the workhorse

```xml
<Target Name="UpdatePackageVersionBeforeOuterBuild">
    <!-- 1. Create a lock file (multi-TFM deduplication) -->
    <Touch Files="$(UpdatePackageVersionLockFilePath)" AlwaysCreate="true"/>
    <!-- 2. (Debug only) Call GetVersion to log current version -->
    <GetVersion ... Condition="'$(ATAPBuildToolingConfiguration)'=='Debug'" />
    <!-- 3. Call UpdateVersion — reads AssemblyInfo, computes new version, writes it back -->
    <ATAP.Utilities.BuildTooling.UpdateVersion
        VersionFile="$(VersionFile)"
        MajorVersion="$(MajorVersion)" MinorVersion="$(MinorVersion)" PatchVersion="$(PatchVersion)"
        PackageLifeCycleStage="$(PackageLifeCycleStage)" PackageLabel="$(PackageLabel)" ...>
        <Output TaskParameter="Build"          PropertyName="Build" />
        <Output TaskParameter="PackageVersion" PropertyName="PackageVersion" />
        <Output TaskParameter="Revision"       PropertyName="Revision" />
    </ATAP.Utilities.BuildTooling.UpdateVersion>
</Target>
```

**Why the lock file?** When a project targets multiple frameworks (`TargetFrameworks`), MSBuild performs an _outer build_ that dispatches to one _inner build_ per framework. Without a lock file, `UpdateVersion` would run once per framework, incrementing the label counter multiple times in a single build. The lock file is created before the first inner build and deleted after all inner builds finish, so the version increments exactly once.

### `UpdatePackageVersionAfterOuterBuild` — cleanup

```xml
<Target Name="UpdatePackageVersionAfterOuterBuild" AfterTargets="DispatchToInnerBuilds;AfterBuild">
    <Delete Files="$(UpdatePackageVersionLockFilePath)"/>
</Target>
```

### `SetPackageVersionForPack` — bridge to outer scope

For multi-TFM projects, `UpdateVersion` runs inside an inner build; the updated `PackageVersion` is not visible in the outer build where `GenerateNuspec` runs. `SetPackageVersionForPack` (BeforeTargets="GenerateNuspec") re-reads the updated `AssemblyInfo.cs` immediately before `GenerateNuspec`, making the correct version available to NuGet packaging.

### `PublishAfterBuild` — push to ProGet

```xml
<Target Name="PublishAfterBuild" AfterTargets="GenerateNuspec">
    <Exec Command="pwsh -File &quot;$(MSBuildThisFileDirectory)Invoke-ProGetNuGetPublish.ps1&quot;
                   -NupkgPath &quot;...$(PackageId).$(PackageVersion).nupkg&quot;
                   -Source &quot;$(ProGetExperimentalFeedUrl)&quot;
                   -ProGetApiKeySecretName &quot;ProGet.Admin.API.Key&quot;" />
</Target>
```

Pushes through a PowerShell leaf that resolves `ProGet.Admin.API.Key` with
`Get-SecretATAP`. `ProGetExperimentalFeedUrl` defaults to
`http://localhost:50000/nuget/nuget-experimental/v3/index.json`.

### `DeployBuildToolingToBuildDirectory` — automated deployment

Runs only for the BuildTooling project itself, Release configuration, and only the `net10.0` inner build (to avoid redundant copies across multi-TFM builds).

1. Computes `_NewBuildToolingVersion = MajorVersion.MinorVersion.PatchVersion`.
2. Creates `$(SolutionBuildToolsBaseDir)ATAP.Utilities.BuildTooling.<version>\build\Release\net10.0\`.
3. Copies `ATAP.Utilities.BuildTooling.CSharp.dll` and `.pdb` into the TFM subdirectory.
4. Copies the source `.targets` file into `build\` (always overwrites).
5. Writes `Build/ATAP.Utilities.BuildTooling.current-version` with the version string.

**Effect:** After a Release build of `ATAP.Utilities.BuildTooling.CSharp`, the next build of any project in the solution automatically loads the updated DLL and targets file.

---

## Bootstrap Sequence: The Chicken-and-Egg Problem

The custom tasks DLL must exist **before** any project that uses the tasks can be built. But the DLL is produced by building the `ATAP.Utilities.BuildTooling.CSharp` project — itself a project in the solution.

### Step 1 — Build the BuildTooling project in isolation

```powershell
dotnet build src\ATAP.Utilities.BuildTooling.CSharp\ATAP.Utilities.BuildTooling.CSharp.csproj `
    --configuration Release
```

Works because `Directory.Build.targets` imports `ATAP.Utilities.BuildTooling.targets` with `Condition="Exists(...)"`. If the DLL does not yet exist, the import is silently skipped. The `CallTarget` to `UpdatePackageVersionBeforeOuterBuild` is commented out, so no task invocation is attempted. The project's own version update is skipped on bootstrap; `AssemblyInfo.cs` must have valid values already.

### Step 2 — `DeployBuildToolingToBuildDirectory` runs automatically

Fires at the end of the Release build above (conditioned on `net10.0` inner build only). Creates the versioned deploy directory, copies DLL/PDB/targets, writes the sentinel file.

**First-ever bootstrap exception:** On the very first bootstrap, the `.targets` containing `DeployBuildToolingToBuildDirectory` has never been deployed yet, so MSBuild can't load it. The one-time fix:

```powershell
# One-time only: push updated .targets into the previously-deployed location
Copy-Item `
    src\ATAP.Utilities.BuildTooling.CSharp\ATAP.Utilities.BuildTooling.targets `
    Build\ATAP.Utilities.BuildTooling.0.1.0.1\build\ `
    -Force
```

### Step 3 — Build any other project normally

```powershell
dotnet build --configuration Release
```

DLL is now present at the sentinel-file path; `Directory.Build.props` resolves the path dynamically; `Directory.Build.targets` imports the `.targets` file successfully; `UsingTask` registers the three task classes.

---

## End-to-End Data Flow for a Typical Project Build

```text
dotnet build MyProject.csproj --configuration Release
│
├── MSBuild loads Directory.Build.props
│   └── Sets SolutionDir, ATAPUtilitiesBuildToolingTasksAssembly, etc.
│
├── MSBuild loads MyProject.csproj
│   └── Project-specific TargetFramework, version parts (MajorVersion, etc.)
│
├── MSBuild loads Directory.Build.targets
│   └── Imports ATAP.Utilities.BuildTooling.targets
│       └── Registers UsingTask for GetVersion, UpdateVersion, SetVersion
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
│   ├── SetPackageVersionForPack runs first (re-reads PackageVersion into outer scope)
│   └── NuSpec is generated with correct PackageVersion
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

## Key Property Reference

| Property                                       | Set in                                              | Example value                                                          | Purpose                                                                                         |
| ---------------------------------------------- | --------------------------------------------------- | ---------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `SolutionDir`                                  | `Directory.Build.props`                             | `C:\...\ATAP.Utilities\`                                               | Root of the repository                                                                          |
| `SolutionBuildToolsBaseDir`                    | `Directory.Build.props`                             | `$(SolutionDir)Build\`                                                 | Where pre-built task tools live                                                                 |
| `ATAPBuildToolingConfiguration`                | `Directory.Build.props`                             | `Debug` or `Release`                                                   | Controls verbose logging inside tasks                                                           |
| `ATAPBuildToolingVersion`                      | `Directory.Build.props` (sentinel file or fallback) | `0.1.0`                                                                | Version of deployed BuildTooling; read from `Build\ATAP.Utilities.BuildTooling.current-version` |
| `ATAPUtilitiesBuildToolingTargetsPath`         | `Directory.Build.props`                             | `$(SolutionBuildToolsBaseDir)ATAP.Utilities.BuildTooling.0.1.0\build\` | Where `ATAP.Utilities.BuildTooling.targets` is loaded from                                      |
| `ATAPUtilitiesBuildToolingTasksAssembly`       | `Directory.Build.props`                             | `...\Release\net10.0\ATAP.Utilities.BuildTooling.CSharp.dll`           | The task DLL path                                                                               |
| `VersionFile`                                  | `Directory.Build.props`                             | `$(MSBuildProjectDirectory)\Properties\AssemblyInfo.cs`                | Per-project version file                                                                        |
| `UpdatePackageVersionLockFilePath`             | `Directory.Build.props`                             | `$(MSBuildProjectDirectory)\<ProjectName>.UpdatePackageVersion.lock`   | Multi-TFM deduplication lock                                                                    |
| `MajorVersion`, `MinorVersion`, `PatchVersion` | Individual `.csproj`                                | `0`, `1`, `0`                                                          | Semantic version parts, read by `UpdateVersion`                                                 |
| `PackageLifeCycleStage`                        | Individual `.csproj`                                | `Development`                                                          | Controls whether a pre-release suffix is added                                                  |
| `PackageLabel`                                 | Individual `.csproj`                                | `Alpha`                                                                | Pre-release label string                                                                        |
| `ProGetExperimentalFeedUrl`                    | `ATAP.Utilities.BuildTooling.targets`               | `http://localhost:50000/nuget/nuget-experimental/v3/index.json`        | Push destination                                                                                |
| `ProGetApiKeySecretName`                       | `ATAP.Utilities.BuildTooling.targets`               | `ProGet.Admin.API.Key`                                                  | Non-secret name passed to the PowerShell publishing leaf                                        |

---

## AI Agent Bootstrap Guide (Replicating This System Elsewhere)

For an AI agent that must replicate this build system in another repository:

### Preconditions

1. Target repository is a .NET SDK-style project repository.
2. Agent has write access to the repository root.
3. `dotnet` (SDK 8.0+) is available.
4. Shell is PowerShell 7 (`pwsh`).
5. A ProGet instance is reachable and `ProGet.Admin.API.Key` resolves through
   `Get-SecretATAP`. If ProGet is not used, disable `PublishAfterBuild`.

### Sequence

1. Decide the initial bootstrap version string (e.g. `0.1.0.1`) and set it as the fallback in `Directory.Build.props`.
2. Create `Directory.Build.props` at the repo root with sections 1-7 above.
3. Create `Directory.Build.targets` at the repo root with the import-with-Exists-guard pattern.
4. Create `src/ATAP.Utilities.BuildTooling.CSharp/` with the `.csproj` shown above and the `Utilities` + three Task classes.
5. Create `ATAP.Utilities.BuildTooling.targets` alongside the `.csproj` with `UsingTask` declarations, the `BeforeCompile` gate, `UpdatePackageVersionBeforeOuterBuild`, `SetPackageVersionForPack`, `PublishAfterBuild`, and `DeployBuildToolingToBuildDirectory`.
6. Run Step 1 of the Bootstrap Sequence above.
7. Verify the sentinel file `Build/ATAP.Utilities.BuildTooling.current-version` was written.
8. Build a second project to confirm the task DLL is loaded and `UpdateVersion` increments `AssemblyInfo.cs`.

### Verification

A successful bootstrap is signaled by:

- `Build/ATAP.Utilities.BuildTooling.<version>/build/Release/net10.0/ATAP.Utilities.BuildTooling.CSharp.dll` exists.
- `Build/ATAP.Utilities.BuildTooling.current-version` contains the version string.
- A subsequent build of any project increments the `Alpha-NNN` counter in its `Properties/AssemblyInfo.cs`.
- A `.nupkg` is pushed to ProGet `nuget-experimental` (visible in the ProGet UI).
