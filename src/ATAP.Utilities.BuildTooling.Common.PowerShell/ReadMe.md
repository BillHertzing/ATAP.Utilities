# ATAP.Utilities.BuildTooling.Common.PowerShell

Shared PowerShell helpers for the `ATAP.Utilities.BuildTooling.*` module family.

## Status

This module contains reviewed helper batches created under Sprint 0013 Tasks 13.70 and 13.68.c.
The parent `ATAP.Utilities.BuildTooling.PowerShell` remains the active provider of these commands
until a later parent-rewire task; the temporary duplicate implementations are intentional.

Production version `0.1.1` has completed the UTAT01 BuildMaster tier path and is installed for
all users at `C:\Program Files\PowerShell\Modules\ATAP.Utilities.BuildTooling.Common.PowerShell\0.1.1`.
A fresh profile-loaded PowerShell import resolves that installed module. The parent remains
unrewired.

## Contract

- Requires PowerShell 7.0 or later and the Core edition.
- Declares four explicit function exports and explicit empty cmdlet, variable, and alias exports.
- Keeps public helpers in `public/` and non-exported helpers in `private/`.
- Contains no shared types or assemblies in the approved first batch. Task 13.70.f determined
  that neither a guarded `lib/*.types.ps1` loader nor `RequiredAssemblies` is applicable until a
  future extraction introduces an explicitly shared type.

## Reviewed membership

The approved membership is `Assert-GitAvailable`, `Get-RepositoryRoot`,
`Get-WorkspaceJson`, `Resolve-WorkspaceFiles`, and `Initialize-ATAPConfigurationGlobals`.
`Get-RepositoryRoot` is the PesterScaffolding prerequisite approved to remove that pilot's
GitWorktree dependency. Existing parent implementations and tests remain in place until the
separately tracked parent-rewire and Pester-slice tasks.

`Initialize-ATAPConfigurationGlobals` requires `PSFramework` for its existing structured logging.
Its other configuration dependencies remain dynamically resolved by design, preserving its
source-first behavior when `-RepositoryRoot` identifies an active worktree.

## Verification

```powershell
Invoke-Pester -Path './tests/Unit' -Output Minimal
```

The Common-owned slice covers all four exported commands. The parent suite remains in place
while the parent owns the active command surface; it will be reconciled when parent rewire work
is authorized.

The `Assert-GitAvailable` mock-only tests retain the `Unit` tag but also carry
`PromotedModuleHostSensitive`: BuildMaster's promoted-module gate restores the package and then
the tests re-import source code to install module-scoped mocks, so these checks do not validate
the restored artifact and are excluded from that service-account gate.
