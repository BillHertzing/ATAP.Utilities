# Worked example — `ATAP.Services.ConsoleMonitor`

Rehearsal target for this skill, in the ATAP.Utilities sprint worktree:

```text
src/ATAP.Services.ConsoleMonitor/
src/ATAP.Services.ConsoleMonitor.Interfaces/
```

It is a good exercise because it exhibits four wrinkles the Loader conversion
did not: a `.csproj` file name that does not match its directory name, an
absorbed sibling that contains no source at all, embedded `.resx` resources with
designer-file metadata, and consumers that are already broken before you touch
anything.

Verify the current state yourself before acting — the tree may have moved on
since this was written.

---

## Step 1 — Inventory

```powershell
Get-ChildItem -Path 'src\ATAP.Services.ConsoleMonitor' -Recurse -File `
  -Exclude 'bin','obj' | Select-Object -ExpandProperty FullName
```

Observed contents:

| File | Destination child |
| --- | --- |
| `ConsoleMonitor.cs` | `Model/` |
| `ConsoleMonitorStringConstants.cs` | `StringConstants/` |
| `StringConstants.cs` | `StringConstants/` |
| `ConsoleMonitorDefaultConfiguration .cs` | `DefaultConfiguration/` |
| `DefaultConfiguration.cs` | `DefaultConfiguration/` |
| `ConsoleMonitorSettings.json` | `Model/` (copied to output at runtime) |
| `Resources/DebugResources/*` | `Model/` |
| `Resources/ExceptionResources/*` | `Model/` |
| `version.json`, `packages.lock.json` | stay at the facade |

Note the literal space in `ConsoleMonitorDefaultConfiguration .cs`. Quote the
path when you `git mv` it, and take the opportunity to drop the space.

The sibling `src/ATAP.Services.ConsoleMonitor.Interfaces/` holds **only**
`ConsoleMonitor.Interfaces.csproj`, `version.json`, and `packages.lock.json` —
no `.cs` files. It is a project shell that never received its contract types.
Absorb it as `Interfaces/` regardless: it is a real solution project with real
consumers, so deleting it or leaving it flat both break things. Absorbing it now
means the interfaces land in the right place when someone finally writes them.

---

## Step 2 — Note the file-name mismatch

The project is at `src/ATAP.Services.ConsoleMonitor/ConsoleMonitor.csproj` —
directory `ATAP.Services.ConsoleMonitor`, file `ConsoleMonitor.csproj`. Consumers
reference that exact path.

**Do not "fix" this.** Renaming the facade file is precisely the change the
facade pattern exists to avoid; it would break all five consumers for no benefit.
The facade keeps the name `ConsoleMonitor.csproj`.

Derive child names from the *stem the repository already uses*, so the
no-duplicate-file-names rule is satisfied against the facade's actual file name:

```text
src/ATAP.Services.ConsoleMonitor/
  ConsoleMonitor.csproj                              <- facade, unchanged path
  Interfaces/ConsoleMonitor.Interfaces.csproj        <- moved in, name unchanged
  Model/ConsoleMonitor.Model.csproj
  StringConstants/ConsoleMonitor.StringConstants.csproj
  DefaultConfiguration/ConsoleMonitor.DefaultConfiguration.csproj
```

`ConsoleMonitor.Interfaces.csproj` keeps its name because it is unique already
and because keeping it makes the `git mv` a clean rename rather than a
rename-plus-retitle.

---

## Step 3 — Find every consumer, and record what is already broken

```powershell
Select-String -Path (Get-ChildItem -Recurse -Filter '*.csproj').FullName `
  -Pattern 'ConsoleMonitor' | Format-Table Path, LineNumber, Line
```

Five sample projects reference the pair:

| Consumer | References |
| --- | --- |
| `samples/ATAP.Console.Console01` | `..\..\src\ATAP.Services.ConsoleMonitor.Interfaces\…`, `..\..\src\ATAP.Services.ConsoleMonitor\ConsoleMonitor.csproj` |
| `samples/ATAP.Console.Console02` | same |
| `samples/ATAP.Console.Console03` | same |
| `samples/ATAP.Service.Service01` | same |
| `samples/ATAP.Service.Service02` | `..\ATAP.Services.ConsoleMonitor.Interfaces\…`, `..\ATAP.Services.ConsoleMonitor\…` |

`Service02` uses a single `..\`, which resolves to `samples\ATAP.Services.ConsoleMonitor*`
— directories that do not exist. **Those two references are already broken,
before any facade work.** Capture that in your notes now.

This distinction matters when you report results. A pre-existing break that your
sweep uncovers is a finding, not a regression, and conflating the two makes the
conversion look like it caused damage it did not. Fix it as part of the sweep
and say plainly that it was already broken.

---

## Step 4 — Move with `git mv`

```powershell
$root = 'src\ATAP.Services.ConsoleMonitor'
New-Item -ItemType Directory -Path "$root\Model", "$root\StringConstants", "$root\DefaultConfiguration" -Force

git mv 'src\ATAP.Services.ConsoleMonitor.Interfaces' "$root\Interfaces"

git mv "$root\ConsoleMonitor.cs"                        "$root\Model\ConsoleMonitor.cs"
git mv "$root\ConsoleMonitorSettings.json"              "$root\Model\ConsoleMonitorSettings.json"
git mv "$root\Resources"                                "$root\Model\Resources"

git mv "$root\ConsoleMonitorStringConstants.cs"         "$root\StringConstants\ConsoleMonitorStringConstants.cs"
git mv "$root\StringConstants.cs"                       "$root\StringConstants\StringConstants.cs"

git mv "$root\ConsoleMonitorDefaultConfiguration .cs"   "$root\DefaultConfiguration\ConsoleMonitorDefaultConfiguration.cs"
git mv "$root\DefaultConfiguration.cs"                  "$root\DefaultConfiguration\DefaultConfiguration.cs"
```

`New Text Document.txt` is scratch and is not referenced by the build; leave it
or delete it in a separate commit, but do not fold an unrelated deletion into
the restructure diff.

---

## Step 5 — The facade `.csproj`

Rewrite `ConsoleMonitor.csproj` in place. The original is `1.0.0` /
`Production`, and those values stay:

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Library</OutputType>
    <!-- NO TargetFramework/TargetFrameworks here — inherited from Directory.Build.props -->
    <RootNamespace>ATAP.Services.ConsoleMonitor</RootNamespace>
    <GeneratePackageOnBuild>true</GeneratePackageOnBuild>
    <IsPackable>true</IsPackable>
    <MajorVersion>1</MajorVersion>
    <MinorVersion>0</MinorVersion>
    <PatchVersion>0</PatchVersion>
    <PackageLifeCycleStage>Production</PackageLifeCycleStage>
    <PackageLabel>NA</PackageLabel>
    <EnableDefaultItems>false</EnableDefaultItems>
  </PropertyGroup>

  <ItemGroup>
    <ProjectReference Include="StringConstants\ConsoleMonitor.StringConstants.csproj" />
    <ProjectReference Include="Interfaces\ConsoleMonitor.Interfaces.csproj" />
    <ProjectReference Include="DefaultConfiguration\ConsoleMonitor.DefaultConfiguration.csproj" />
    <ProjectReference Include="Model\ConsoleMonitor.Model.csproj" />
  </ItemGroup>

  <!-- Packages and projects to implement IL Weaving using Fody during the build process -->
  <ItemGroup>
    <ProjectReference Include="..\ATAP.Utilities.ETW\ATAP.Utilities.ETW.csproj" />
  </ItemGroup>
</Project>
```

`RootNamespace` is set explicitly. Without it the children would derive
namespaces from their own directory names and produce
`ATAP.Services.ConsoleMonitor.Model.*` — a silent public-API change. Set the
same `RootNamespace` on every child.

The ETW reference stays on the facade: it is weaving infrastructure for the
whole family, matching how `ATAP.Utilities.Secrets` handles it.

---

## Step 6 — The `Model` child

`Model/ConsoleMonitor.Model.csproj` inherits the working content of the old
project, with every outward path deepened by one level and the sibling
references repointed:

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Library</OutputType>
    <RootNamespace>ATAP.Services.ConsoleMonitor</RootNamespace>
    <GeneratePackageOnBuild>true</GeneratePackageOnBuild>
    <IsPackable>true</IsPackable>
    <MajorVersion>1</MajorVersion>
    <MinorVersion>0</MinorVersion>
    <PatchVersion>0</PatchVersion>
    <PackageLifeCycleStage>Production</PackageLifeCycleStage>
    <PackageLabel>NA</PackageLabel>
  </PropertyGroup>

  <ItemGroup>
    <ProjectReference Include="..\Interfaces\ConsoleMonitor.Interfaces.csproj" />
    <ProjectReference Include="..\StringConstants\ConsoleMonitor.StringConstants.csproj" />
    <ProjectReference Include="..\DefaultConfiguration\ConsoleMonitor.DefaultConfiguration.csproj" />
    <ProjectReference Include="..\..\ATAP.Utilities.Configuration\Extensions\ATAP.Utilities.Configuration.Extensions.csproj" />
    <ProjectReference Include="..\..\ATAP.Utilities.Reactive.Extensions\ATAP.Utilities.Reactive.Extensions.csproj" />
    <ProjectReference Include="..\..\ATAP.Services.ConsoleSink.Interfaces\ConsoleSink.Interfaces.csproj" />
    <ProjectReference Include="..\..\ATAP.Services.ConsoleSource.Interfaces\ConsoleSource.Interfaces.csproj" />
  </ItemGroup>

  <ItemGroup>
    <PackageReference Include="System.Reactive" />
  </ItemGroup>

  <!-- Packages necessary to run the ASP.Net Core Generic Host and web server hosts Server -->
  <ItemGroup>
    <PackageReference Include="Microsoft.Extensions.Configuration" />
    <PackageReference Include="Microsoft.Extensions.Configuration.CommandLine" />
    <PackageReference Include="Microsoft.Extensions.Configuration.EnvironmentVariables" />
    <PackageReference Include="Microsoft.Extensions.Configuration.Json" />
    <PackageReference Include="Microsoft.Extensions.Hosting" />
    <PackageReference Include="Microsoft.Extensions.Localization" />
    <PackageReference Include="Microsoft.Extensions.Logging" />
  </ItemGroup>

  <ItemGroup>
    <None Update="ConsoleMonitorSettings.json">
      <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
    </None>
  </ItemGroup>

  <ItemGroup>
    <Compile Update="Resources\DebugResources\DebugMessages.Designer.cs">
      <DesignTime>True</DesignTime>
      <AutoGen>True</AutoGen>
      <DependentUpon>DebugMessages.resx</DependentUpon>
    </Compile>
    <EmbeddedResource Update="Resources\DebugResources\DebugMessages.resx">
      <Generator>ResXFileCodeGenerator</Generator>
      <LastGenOutput>DebugMessages.Designer.cs</LastGenOutput>
    </EmbeddedResource>
    <Compile Update="Resources\ExceptionResources\ExceptionMessages.Designer.cs">
      <DesignTime>True</DesignTime>
      <AutoGen>True</AutoGen>
      <DependentUpon>ExceptionMessages.resx</DependentUpon>
    </Compile>
    <EmbeddedResource Update="Resources\ExceptionResources\ExceptionMessages.resx">
      <Generator>ResXFileCodeGenerator</Generator>
      <LastGenOutput>ExceptionMessages.Designer.cs</LastGenOutput>
    </EmbeddedResource>
  </ItemGroup>
</Project>
```

Three things to get right here:

- The resource `Compile Update` / `EmbeddedResource Update` metadata travels
  **with the resources** into `Model/`, and its paths stay relative to `Model/`
  — so they are unchanged. `Update` (not `Include`) only decorates items the
  default glob already found, which is why `Model/` must keep `EnableDefaultItems`
  at its default `true`. Only the facade turns the glob off.
- Two `None Update` entries existed in the original; one named
  `FileSystemWatchers.config`, a file that is not in the project. Drop it. A
  `None Update` for a non-existent file is inert, but carrying dead metadata
  into a fresh file is how it survives another decade.
- `RootNamespace` repeats the parent's value, per Step 5.

The `StringConstants` and `DefaultConfiguration` children are properties-only,
like `Loader/StringConstants` — plus `RootNamespace`. `Interfaces/` keeps the
references it already has, each deepened by one `..` level.

---

## Step 7 — Repoint consumers

The facade path is unchanged, so `ConsoleMonitor.csproj` references need no
edit — that is the pattern working as designed. The absorbed sibling is what
moves:

```text
..\..\src\ATAP.Services.ConsoleMonitor.Interfaces\ConsoleMonitor.Interfaces.csproj
->
..\..\src\ATAP.Services.ConsoleMonitor\Interfaces\ConsoleMonitor.Interfaces.csproj
```

Apply to Console01, Console02, Console03, and Service01. For Service02, correct
the missing `..\` level at the same time and note it as a pre-existing defect.

---

## Step 8 — Solution and verification

Add `Project(...)` entries with fresh GUIDs for the four children, a
`ConsoleMonitor` solution folder, `NestedProjects` mappings, and
`Debug|Any CPU` / `Release|Any CPU` rows in `ProjectConfigurationPlatforms` for
each new GUID. The facade keeps its existing GUID.

```powershell
dotnet build src\ATAP.Services.ConsoleMonitor\ConsoleMonitor.csproj
dotnet build ATAP.Utilities.sln
Select-String -Path (Get-ChildItem -Recurse -Filter '*.csproj').FullName `
  -Pattern 'ATAP\.Services\.ConsoleMonitor\.Interfaces\\'   # expect zero hits
```

Success criteria for the rehearsal:

- Both builds succeed.
- Zero references to the old flat `ATAP.Services.ConsoleMonitor.Interfaces\`
  directory remain.
- `src/ATAP.Services.ConsoleMonitor/ConsoleMonitor.csproj` is at the same path
  with the same name it started with.
- `git status` shows the moves as renames (`R`), not add/delete pairs.
- Types still resolve as `ATAP.Services.ConsoleMonitor.*`, with no `.Model.` or
  `.StringConstants.` segment introduced into the namespace.
- The Service02 path correction is reported as a pre-existing defect found, not
  as a regression fixed.

Write the build output to `_generated/` per SC-0033.
