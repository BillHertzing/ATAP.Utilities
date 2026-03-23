# ATAP.Utilities — Versioning Strategy

Created: 2026-03-20

---

## Overview

ATAP.Utilities uses a SemVer pre-release label convention that maps directly to the promotion tier a package is in. The same format is used for both local developer builds and CI/CD pipeline builds — the label value changes as the package is promoted through tiers.

---

## Version Format

```text
{Major}.{Minor}.{Patch}-{Label}-{LabelCount}
```

| Component | Example | Notes |
| --------- | ------- | ----- |
| `Major` | `0` | Set in `.csproj` as `<MajorVersion>` |
| `Minor` | `1` | Set in `.csproj` as `<MinorVersion>` |
| `Patch` | `0` | Set in `.csproj` as `<PatchVersion>` |
| `Label` | `Alpha` | Set in `.csproj` as `<PackageLabel>`; ignored when `<PackageLifeCycleStage>` is `Production` |
| `LabelCount` | `007` | Three-digit zero-padded counter; auto-incremented on each build by the BuildTooling pipeline |

### Label values by tier

| Tier | `<PackageLabel>` | Example version | Feed |
| ---- | --------------- | --------------- | ---- |
| Experimental (dev builds) | `Alpha` | `0.1.0-Alpha-007` | `nuget-experimental` |
| Development (CI promoted) | `Beta` | `0.1.0-Beta-001` | `nuget-development` |
| Testing / QA | `QA` | `0.1.0-QA-001` | `nuget-testing` |
| Production | *(none — `PackageLifeCycleStage=Production`)* | `0.1.0` | `nuget-production` |

Pre-release packages (`Alpha`, `Beta`, `QA`) are consumed during development. Only stable packages (`0.1.0`) flow to `nuget-production`.

---

## SemVer validity

The hyphen separator (`Alpha-007`) is a single pre-release string identifier, valid under both SemVer 1.0 and 2.0.

A **dot** separator (`Alpha.007`) is **invalid** — SemVer 2.0 treats `007` as a numeric identifier and disallows leading zeros, causing NuGet error `NU5024`.

---

## How the pipeline works

On every `dotnet build -c Release`:

1. **`UpdateVersion`** (`BeforeCompile`) — reads `Properties/AssemblyInfo.cs`, increments `LabelCount`, writes updated `AssemblyInformationalVersion` back.
2. **`SetPackageVersionForPack`** (`BeforeTargets="GenerateNuspec"`) — reads the updated version into the outer build scope so the `.nupkg` filename matches.
3. **`GenerateNuspec` + `Pack`** — creates the `.nupkg` with the correct version.
4. **`PublishAfterBuild`** (`AfterTargets="GenerateNuspec"`) — pushes the `.nupkg` to `nuget-experimental` via `dotnet nuget push` using `$env:PROGET_ADMIN_API_TOKEN`.

A lock file prevents the counter incrementing multiple times in a multi-TFM build.

---

## Promotion flow

```text
Developer build
  dotnet build -c Release
  → 0.1.0-Alpha-007 pushed to nuget-experimental
        │
        ▼  (CI gate: tests pass; bump PackageLabel to Beta, reset or continue LabelCount)
  0.1.0-Beta-001 pushed to nuget-development
        │
        ▼  (CI gate: integration tests pass; bump PackageLabel to QA)
  0.1.0-QA-001 pushed to nuget-testing
        │
        ▼  (gate: manual approval; set PackageLifeCycleStage=Production)
  0.1.0 pushed to nuget-production
```

The `<PackageLabel>` in the `.csproj` is updated at each promotion gate. The `LabelCount` resets to `001` when the label changes, or continues incrementing if multiple builds occur at the same tier.

---

## Feed routing

| Consumer restore source | Sees packages from |
| ---------------------- | ------------------ |
| `nuget-experimental` | experimental + nuget.org (via connector) |
| `nuget-development` | development + experimental + nuget.org (via inter-tier connector) |
| `nuget-testing` | testing + development only (hermetic — no public fallback) |
| `nuget-production` | production + testing + nuget.org (via connectors) |

---

## Files involved

| File | Role |
| ---- | ---- |
| `{project}/Properties/AssemblyInfo.cs` | Stores current version; read and updated by BuildTooling on every build |
| `{project}/{project}.csproj` | Declares `MajorVersion`, `MinorVersion`, `PatchVersion`, `PackageLabel`, `PackageLifeCycleStage` |
| `Build/ATAP.Utilities.BuildTooling.0.1.0.1/build/ATAP.Utilities.BuildTooling.targets` | Deployed targets file |
| `Directory.Build.targets` | Solution-wide import of BuildTooling targets |
| `src/ATAP.Utilities.BuildTooling.PowerShell/public/Publish-ATAPUtilities.ps1` | Batch script to build and publish all libraries |

---

## Adding a new library to the pipeline

1. Add to the library's `.csproj`:

   ```xml
   <GeneratePackageOnBuild>true</GeneratePackageOnBuild>
   <IsPackable>true</IsPackable>
   <MajorVersion>0</MajorVersion>
   <MinorVersion>1</MinorVersion>
   <PatchVersion>0</PatchVersion>
   <PackageLifeCycleStage>Development</PackageLifeCycleStage>
   <PackageLabel>Alpha</PackageLabel>
   <Authors>ATAP</Authors>
   <Description>...</Description>
   ```

2. Create `Properties/AssemblyInfo.cs` with the initial version:

   ```csharp
   using System.Reflection;
   [assembly:AssemblyFileVersion("0.1.0.0")]
   [assembly:AssemblyInformationalVersion("0.1.0-Alpha-001")]
   [assembly:AssemblyVersion("0.1.0")]
   ```

3. Add the library to `Publish-ATAPUtilities.ps1` in dependency order (dependencies first).

4. Run `dotnet build {project}.csproj -c Release` — the pipeline handles the rest.
