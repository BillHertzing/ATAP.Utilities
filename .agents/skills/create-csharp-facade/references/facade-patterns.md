# Facade patterns — annotated before/after from ATAP.Utilities

Source of truth: commit `39f5e28da` in `ATAP.Utilities`
("feat(secrets,migr): add secrets plugin stack and project reference fixes (#97)").
That commit converted `ATAP.Utilities.Loader`, `ATAP.Utilities.Secrets`,
`ATAP.Utilities.ManimVideoGenerator`, `ATAP.Console.PluginDemo`, and
`ATAP.Console.ManimDemo` to the facade layout, then spent two follow-up fix
commits repairing what the move broke. Both halves are instructive.

## Contents

- [1. Loader — the canonical library conversion](#1-loader)
- [2. Secrets — facade keeping a parent-level file](#2-secrets)
- [3. PluginDemo / ManimDemo — facade over an executable](#3-executable-children)
- [4. The two rename waves and what caused them](#4-rename-waves)
- [5. Solution file mechanics](#5-solution-file-mechanics)

---

## 1. Loader

The clearest example, because it is a real restructure of an existing project
rather than a greenfield layout.

### Before

`src/ATAP.Utilities.Loader/ATAP.Utilities.Loader.csproj` carried everything, and
two flat siblings sat beside it: `src/ATAP.Utilities.Loader.Interfaces/` and
`src/ATAP.Utilities.Loader.StringConstants/`.

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Library</OutputType>
    <GeneratePackageOnBuild>true</GeneratePackageOnBuild>
    <IsPackable>true</IsPackable>
    <MajorVersion>0</MajorVersion>
    <MinorVersion>1</MinorVersion>
    <PatchVersion>0</PatchVersion>
    <PackageLifeCycleStage>Development</PackageLifeCycleStage>
    <PackageLabel>Alpha</PackageLabel>
  </PropertyGroup>

  <PropertyGroup>
    <TargetFrameworks>net10.0</TargetFrameworks>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.Extensions.DependencyInjection" />
  </ItemGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.Extensions.Configuration" />
    <PackageReference Include="Microsoft.Extensions.Configuration.Binder" />
  </ItemGroup>

  <ItemGroup Condition="...IsMatch($(TargetFramework), '^(core|net[5-9]|net1[0-9])')">
    <ProjectReference Include="..\ATAP.Utilities.Loader.Interfaces\ATAP.Utilities.Loader.Interfaces.csproj" />
    <ProjectReference Include="..\ATAP.Utilities.Loader.StringConstants\ATAP.Utilities.Loader.StringConstants.csproj" />
  </ItemGroup>

  <ItemGroup>
    <ProjectReference Include="..\ATAP.Utilities.FIleIO\ATAP.Utilities.FileIO.csproj" />
  </ItemGroup>
</Project>
```

### After — the facade

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Library</OutputType>
    <GeneratePackageOnBuild>true</GeneratePackageOnBuild>
    <IsPackable>true</IsPackable>
    <MajorVersion>0</MajorVersion>
    <MinorVersion>1</MinorVersion>
    <PatchVersion>0</PatchVersion>
    <PackageLifeCycleStage>Development</PackageLifeCycleStage>
    <PackageLabel>Alpha</PackageLabel>
    <EnableDefaultItems>false</EnableDefaultItems>
  </PropertyGroup>

  <ItemGroup>
    <ProjectReference Include="Interfaces\ATAP.Utilities.Loader.Interfaces.csproj" />
    <ProjectReference Include="Model\ATAP.Utilities.Loader.Model.csproj" />
    <ProjectReference Include="StringConstants\ATAP.Utilities.Loader.StringConstants.csproj" />
  </ItemGroup>
</Project>
```

What changed and why:

| Change | Reason |
| --- | --- |
| `EnableDefaultItems=false` added | Children now live under the facade's directory; the default `**/*.cs` glob would compile them twice |
| Explicit `<TargetFrameworks>` removed | `Directory.Build.props` supplies it; restating it in a child of a centralized build is drift waiting to happen |
| All `PackageReference` items removed | They belonged to the implementation, which is now `Model/` |
| `FileIO` reference removed | Moved down to `Model/` and `Interfaces/`, the projects that actually consume it |
| Version/lifecycle properties untouched | They are the published identity of the package the facade emits |
| `Condition` on the reference group dropped | The facade has no framework-conditional behavior left to guard |

### After — `Model/ATAP.Utilities.Loader.Model.csproj`

The implementation project inherits everything the old parent had, with paths
rewritten one level deeper:

```xml
<ItemGroup Condition="...IsMatch($(TargetFramework), '^(core|net[5-9]|net1[0-9])')">
  <ProjectReference Include="..\Interfaces\ATAP.Utilities.Loader.Interfaces.csproj" />
  <ProjectReference Include="..\StringConstants\ATAP.Utilities.Loader.StringConstants.csproj" />
</ItemGroup>

<ItemGroup>
  <ProjectReference Include="..\..\ATAP.Utilities.FIleIO\ATAP.Utilities.FileIO.csproj" />
</ItemGroup>
```

Note the two distinct prefixes: `..\` reaches a sibling child, `..\..\` reaches
out of the facade entirely. Every path inherited from the old parent gained one
level.

### After — `Interfaces/ATAP.Utilities.Loader.Interfaces.csproj`

Moved wholesale via `git mv` (git recorded it as a 79%-similarity rename), with
only its outward path adjusted. Its version properties differ from the facade's,
and that is deliberate:

```xml
<MajorVersion>1</MajorVersion>
<MinorVersion>0</MinorVersion>
<PatchVersion>0</PatchVersion>
<PackageLifeCycleStage>Production</PackageLifeCycleStage>
<PackageLabel>NA</PackageLabel>
```

A stable contract at `1.0.0`/`Production` sitting under a facade at
`0.1.0`/`Development` is the normal, intended outcome. Independent versioning is
a reason the split exists.

### After — `StringConstants/ATAP.Utilities.Loader.StringConstants.csproj`

The leaf of the dependency order — properties only, no references at all.

---

## 2. Secrets

`ATAP.Utilities.Secrets` shows a facade that must keep one file compiling at the
parent level. Because `EnableDefaultItems=false` disables the glob, the file has
to be named explicitly:

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Library</OutputType>
    <EnableDefaultItems>false</EnableDefaultItems>
    <GeneratePackageOnBuild>true</GeneratePackageOnBuild>
    <IsPackable>true</IsPackable>
    <MajorVersion>0</MajorVersion>
    <MinorVersion>1</MinorVersion>
    <PatchVersion>0</PatchVersion>
    <PackageLifeCycleStage>Development</PackageLifeCycleStage>
    <PackageLabel>Alpha</PackageLabel>
  </PropertyGroup>

  <ItemGroup>
    <Compile Include="Properties\AssemblyInfo.cs" />
  </ItemGroup>

  <ItemGroup>
    <ProjectReference Include="StringConstants\ATAP.Utilities.Secrets.StringConstants.csproj" />
    <ProjectReference Include="Enumerations\ATAP.Utilities.Secrets.Enumerations.csproj" />
    <ProjectReference Include="Interfaces\ATAP.Utilities.Secrets.Interfaces.csproj" />
    <ProjectReference Include="Model\ATAP.Utilities.Secrets.Model.csproj" />
    <ProjectReference Include="Shim\ATAP.Utilities.Secrets.Shim.csproj" />
  </ItemGroup>

  <!-- Packages and projects to implement IL Weaving using Fody during the build process -->
  <ItemGroup>
    <PackageReference Include="MethodBoundaryAspect.Fody" />
    <ProjectReference Include="..\ATAP.Utilities.ETW\ATAP.Utilities.ETW.csproj" />
  </ItemGroup>
</Project>
```

Two things to carry forward:

- The reference list is written in **dependency order** —
  `StringConstants → Enumerations → Interfaces → Model → Shim`. MSBuild does not
  require the ordering, but writing it this way makes an illegal upward
  reference visible on sight.
- `Shim/` is itself a facade with its own children (`Shim/Bitwarden/`,
  `Shim/Plugin/`). The pattern nests, and the same rules apply at each level.

`ManimVideoGenerator` follows the identical shape with
`DefaultSettings / Enumerations / Interfaces / Models / StringConstants`,
plus `<NoWarn>$(NoWarn);2008</NoWarn>` — a facade with no compile items of its
own can otherwise emit MSBuild warning 2008.

---

## 3. Executable children

`ATAP.Console.PluginDemo` and `ATAP.Console.ManimDemo` put the entry point in a
child and keep the facade a library:

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Library</OutputType>
    <!-- NO TargetFramework/TargetFrameworks here — inherited from Directory.Build.props -->
    <RootNamespace>ATAP.Console.PluginDemo</RootNamespace>
    <GeneratePackageOnBuild>false</GeneratePackageOnBuild>
    <IsPackable>false</IsPackable>
    <MajorVersion>0</MajorVersion>
    <MinorVersion>1</MinorVersion>
    <PatchVersion>0</PatchVersion>
    <PackageLifeCycleStage>Development</PackageLifeCycleStage>
    <PackageLabel>Alpha</PackageLabel>
    <EnableDefaultItems>false</EnableDefaultItems>
  </PropertyGroup>

  <ItemGroup>
    <!-- ReferenceOutputAssembly=false prevents NETSDK1150:
         the facade doesn't try to link the Exe's output assembly -->
    <ProjectReference Include="Model\ATAP.Console.PluginDemo.Model.csproj">
      <ReferenceOutputAssembly>false</ReferenceOutputAssembly>
    </ProjectReference>
    <ProjectReference Include="StringConstants\ATAP.Console.PluginDemo.StringConstants.csproj" />
  </ItemGroup>
</Project>
```

Points specific to console facades:

- `GeneratePackageOnBuild` and `IsPackable` are `false` — a demo is not shipped
  as a package, and the facade should say so rather than inheriting a library
  default.
- `RootNamespace` is set explicitly on both facade and child, so the child's
  types keep the parent's namespace despite living one directory deeper.
- The `Model` child sets `<OutputType>Exe</OutputType>` and holds the runtime
  assets:

  ```xml
  <ItemGroup>
    <None Update="appsettings.json">
      <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
    </None>
  </ItemGroup>
  ```

  Content files travel with the project that produces the executable, not with
  the facade.

---

## 4. Rename waves

Both follow-up fix commits in this squash exist because of mistakes made during
the initial move. They are the cheapest available lesson.

### Wave 1 — `fix(sln): restore Console projects and fix duplicate csproj filename conflicts`

Three children had been given the same `.csproj` file name as their facade:

```text
Persistence\Model\ATAP.Utilities.Persistence.csproj    -> ...Persistence.Model.csproj
MessageQueue\Model\ATAP.Utilities.MessageQueue.csproj  -> ...MessageQueue.Model.csproj
Testing.DI.Fixture.Serialization\...Serialization.csproj -> ....Serialization.DI.csproj
```

The rename then forced updates to `ProjectReference` paths across **ten**
consumer `.csproj` files. Naming children `<Parent>.<Role>.csproj` from the
start avoids the whole sequence.

### Wave 2 — `fix(csproj): correct broken project references across src and tests`

Seven distinct categories of stale `ProjectReference` paths, in both `src/` and
`tests/`, left behind by the reorganization. This is the predictable cost of
absorbing sibling projects: the sibling's old path was referenced from places
nobody was looking at. Do the repo-wide reference sweep as part of the move, not
as a follow-up.

---

## 5. Solution file mechanics

Each child gets a normal project entry with a fresh GUID; the facade keeps the
GUID it already had:

```text
Project("{9A19103F-16F7-4668-BE54-9A1E7A4F7556}") = "ATAP.Utilities.Loader.StringConstants", "src\ATAP.Utilities.Loader\StringConstants\ATAP.Utilities.Loader.StringConstants.csproj", "{35B1ACB4-...}"
Project("{9A19103F-16F7-4668-BE54-9A1E7A4F7556}") = "ATAP.Utilities.Loader.Interfaces",      "src\ATAP.Utilities.Loader\Interfaces\ATAP.Utilities.Loader.Interfaces.csproj",           "{8DB16880-...}"
Project("{9A19103F-16F7-4668-BE54-9A1E7A4F7556}") = "ATAP.Utilities.Loader.Model",           "src\ATAP.Utilities.Loader\Model\ATAP.Utilities.Loader.Model.csproj",                     "{955751DB-...}"
Project("{9A19103F-16F7-4668-BE54-9A1E7A4F7556}") = "ATAP.Utilities.Loader",                 "src\ATAP.Utilities.Loader\ATAP.Utilities.Loader.csproj",                                 "{8CDA64FB-...}"
```

A solution folder groups the family (folder type GUID
`{2150E333-8FDC-42A3-9474-1A3956D46DE8}`):

```text
Project("{2150E333-8FDC-42A3-9474-1A3956D46DE8}") = "Loader", "Loader", "{A1B2C3D4-0004-4004-8004-000000000004}"
```

Each child is then mapped under that folder in the `NestedProjects` section, and
each new project GUID needs its `Debug|Any CPU` / `Release|Any CPU` entries in
`ProjectConfigurationPlatforms`. Omitting the configuration rows produces
projects that appear in the solution but never build.
