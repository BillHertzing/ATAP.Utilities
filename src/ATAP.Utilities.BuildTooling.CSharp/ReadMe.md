# ATAP.Utilities.BuildTooling.CSharp

This project is the canonical NuGet distribution point for the ATAP C# MSBuild
package contract. It builds the custom-task assembly and ships identical
`ATAP.Utilities.BuildTooling.CSharp.targets` bytes through both NuGet import
conventions:

- `build/ATAP.Utilities.BuildTooling.CSharp.targets` for direct consumers.
- `buildTransitive/ATAP.Utilities.BuildTooling.CSharp.targets` for transitive consumers.
- `tools/<target-framework>/ATAP.Utilities.BuildTooling.CSharp.dll` as an
  MSBuild-hosted task assembly, not a consumer compile reference.

The imported file exposes version, compatibility, provenance, and task-assembly
properties. Its only target is a pre-compilation, side-effect-free compatibility
gate with stable diagnostics `ATAPBUILD010` through `ATAPBUILD012`. It has no
pack, publish, copy, delete, credential, or external-system target.

## Bootstrap and exact selection

NuGet restore is the only first-use deployment mechanism. A repository selects
one exact immutable package version through Central Package Management and its
lock files; it never copies an editable targets or task-assembly fork into a
consumer. Direct and transitive consumers import identical package bytes.

After restore, `ATAPValidateBuildToolingCompatibility` fails closed when the
contract version or compatibility sentinel differs from the repository-required
values. Projects registering a packaged custom task set
`ATAPBuildToolingRequireTaskAssembly=true`, which makes a missing task assembly
fail closed. A completely absent package/import is detected by the repository
bootstrap gate owned by Tasks 15.180.j and 15.180.k.

Repeated restore of the same immutable version is idempotent. Rollback changes
the exact central version and lock to a previously verified immutable package,
then performs forced locked restore; it never overwrites or re-signs a published
version.

## Provenance and signing

The SDK package records repository type, URL, and commit metadata. The imported
`ATAPBuildToolingImportProvenance` property records the evaluated package path,
and package verification hashes every payload. Local candidates may be unsigned.
Promotion requires the separately authorized signing/publication pipeline to
validate the intended signing identity and immutable package hash; this project
never reads a signing key or publication credential.

## Release and publication boundary

`GeneratePackageOnBuild` is disabled. An ordinary `Release` build only compiles;
it does not pack, publish, deploy, update a sentinel file, read credentials, or
mutate a feed. Packaging requires explicit `dotnet pack`. Publication requires a
separately authorized workflow and is not implemented by this project or its
imported targets.

Repository integration and missing-import enforcement belong to Tasks 15.180.j
and 15.180.k; publication and deployed parity remain gated by Tasks 15.180.s and
15.180.t.

## Import interface

| Property | Meaning |
| --- | --- |
| `ATAPBuildToolingImported` | `true` when the contract file was evaluated. |
| `ATAPBuildToolingPackageId` | Stable package identity. |
| `ATAPBuildToolingContractVersion` | Integer compatibility contract; currently `1`. |
| `ATAPBuildToolingCompatibilitySentinel` | Stable identity `ATAP.Utilities.BuildTooling.CSharp/1`. |
| `ATAPBuildToolingRequiredContractVersion` | Consumer-required version; defaults to `1`. |
| `ATAPBuildToolingRequiredCompatibilitySentinel` | Consumer-required sentinel; defaults to v1. |
| `ATAPBuildToolingImportProvenance` | Exact imported targets-file path. |
| `ATAPBuildToolingImportDirectory` | Directory containing the imported targets file. |
| `ATAPBuildToolingTaskTargetFramework` | Task-assembly TFM; defaults to `net10.0`. |
| `ATAPUtilitiesBuildToolingTasksAssembly` | Package-relative custom-task assembly path. |

## Validation boundary

Task 15.180.d performs static validation, offline local packing, package payload
inspection, and isolated local-feed consumer evaluation. It does not contact or
mutate a feed, use credentials or signing keys, publish, install to either real
repository, or deploy. Evidence separates verified package/isolated-consumer
claims from later repository and deployed-state claims.
