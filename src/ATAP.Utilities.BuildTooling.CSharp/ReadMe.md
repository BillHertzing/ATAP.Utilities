# ATAP.Utilities.BuildTooling.CSharp

This project is the canonical NuGet distribution point for the ATAP C# MSBuild
package contract. It builds the custom-task assembly and ships
`ATAP.Utilities.BuildTooling.targets` through both NuGet import conventions:

- `build/ATAP.Utilities.BuildTooling.targets` for direct consumers.
- `buildTransitive/ATAP.Utilities.BuildTooling.targets` for transitive consumers.
- `tools/<target-framework>/ATAP.Utilities.BuildTooling.CSharp.dll` through the
  project's configured SDK package build-output folder; it is not a consumer
  compile reference.

The imported targets file is deliberately inert. It exposes contract-version,
compatibility-sentinel, import-provenance, import-directory, and task-assembly
properties, but it has no build, pack, publish, copy, delete, credential, or
external-system target.

## Release and publication boundary

`GeneratePackageOnBuild` is disabled. An ordinary `Release` build only compiles;
it does not pack, publish, deploy, update a sentinel file, read credentials, or
mutate a feed. Packaging requires an explicit `dotnet pack` invocation.
Publication requires a separately authorized publication workflow and is not
implemented by this project or its imported targets.

The package source slice does not wire repository consumers to this package.
Consumer integration, version selection, restore, packaging proof, and deployed
parity belong to later Task 15.180 units.

## Import interface

After NuGet imports the targets file, consumers can inspect:

| Property | Meaning |
| --- | --- |
| `ATAPBuildToolingImported` | `true` when this contract file was evaluated. |
| `ATAPBuildToolingContractVersion` | Integer compatibility contract; currently `1`. |
| `ATAPBuildToolingCompatibilitySentinel` | Stable identity `ATAP.Utilities.BuildTooling.CSharp/1`. |
| `ATAPBuildToolingImportProvenance` | Exact imported targets-file path. |
| `ATAPBuildToolingImportDirectory` | Directory containing the imported targets file. |
| `ATAPBuildToolingTaskTargetFramework` | Task-assembly TFM, defaulting to `net10.0`. |
| `ATAPUtilitiesBuildToolingTasksAssembly` | Package-relative custom-task assembly path. |

The task TFM may be overridden before import for a proven compatible consumer.
No custom task is registered or executed by this source slice.

## Validation boundary

Task 15.180.d performs static XML and package-contract validation only. It does
not restore, build, pack, publish, or deploy. The generated handoff therefore
separates verified source claims from unverified package and deployed-state
claims.
