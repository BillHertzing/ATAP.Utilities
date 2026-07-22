# ATAP.Utilities.BuildTooling.Common.PowerShell

Shared PowerShell helpers for the `ATAP.Utilities.BuildTooling.*` module family.

## Status

This module contains the first reviewed helper batch created under Sprint 0013 Task 13.70.d.
The parent `ATAP.Utilities.BuildTooling.PowerShell` remains the active provider of these commands
until a later parent-rewire task; the temporary duplicate implementations are intentional.

## Contract

- Requires PowerShell 7.0 or later and the Core edition.
- Declares four explicit function exports and explicit empty cmdlet, variable, and alias exports.
- Keeps public helpers in `public/` and non-exported helpers in `private/`.
- Contains no shared types or assemblies. A later Task 13.70.f decision is required before
  adding either a guarded `lib/*.types.ps1` file or a required assembly.

## First batch

The approved membership is `Assert-GitAvailable`, `Get-WorkspaceJson`,
`Resolve-WorkspaceFiles`, and `Initialize-ATAPConfigurationGlobals`. The four functions are
copied into this module as public commands. Existing parent implementations and tests remain in
place until the separately tracked parent-rewire and Pester-slice tasks.

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
