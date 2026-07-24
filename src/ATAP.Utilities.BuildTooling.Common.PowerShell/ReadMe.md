# ATAP.Utilities.BuildTooling.Common.PowerShell

Shared PowerShell helpers for the `ATAP.Utilities.BuildTooling.*` module family.

## Status

This module contains reviewed helper batches created under Sprint 0013 Tasks 13.70, 13.68.c,
and 13.72.5. Production version `0.1.5` completed the UTAT01 BuildMaster tier path and is
installed for all users. Version `0.1.6` is burned after Integration exposed retained
nested-module state in the promoted-test runner. Version `0.1.7` carries the unchanged
shared settings contract through the corrected runner and is pending promotion.

## Contract

- Requires PowerShell 7.0 or later and the Core edition.
- Declares six explicit function exports and explicit empty cmdlet, variable, and alias exports.
- Keeps public helpers in `public/` and non-exported helpers in `private/`.
- Contains no shared types or assemblies in the approved first batch. Task 13.70.f determined
  that neither a guarded `lib/*.types.ps1` loader nor `RequiredAssemblies` is applicable until a
  future extraction introduces an explicitly shared type.

## Reviewed membership

The approved membership is `Assert-GitAvailable`, `Get-RepositoryRoot`,
`Get-WorkspaceJson`, `Resolve-WorkspaceFiles`, and `Initialize-ATAPConfigurationGlobals`.
Task 13.72.5 adds `Resolve-BuildToolingSettingValue` as the shared settings-resolution contract.
Task 13.66.b (SC-0288) adds `Resolve-HostSuffixedSecretName` as the single resolver for the
canonical `<BaseName>.<placement-host>` ProGet/BuildMaster SecretName form. It belongs in Common
because the ProGet, BuildMaster, and parent BuildTooling modules all consume it, and because the
convention must have exactly one implementation — a second copy would drift and silently emit a
wrong-host SecretName. It resolves names only and never reads a secret value; see
`SolutionDocumentation/SecretName-HostSuffix-Convention.md`.
`Get-RepositoryRoot` is the PesterScaffolding prerequisite approved to remove that pilot's
GitWorktree dependency. `Resolve-BuildToolingSettingValue` has no duplicate parent definition;
the parent and later children consume the Common export.

`Initialize-ATAPConfigurationGlobals` requires `PSFramework` for its existing structured logging.
Its other configuration dependencies remain dynamically resolved by design, preserving its
source-first behavior when `-RepositoryRoot` identifies an active worktree.

## Verification

```powershell
Invoke-Pester -Path './tests/Unit' -Output Minimal
```

The Common-owned slice covers all six exported commands. Aggregate parent tests continue to
exercise the shared contract through the required Common module.

The `Assert-GitAvailable` mock-only tests retain the `Unit` tag but also carry
`PromotedModuleHostSensitive`: BuildMaster's promoted-module gate restores the package and then
the tests re-import source code to install module-scoped mocks, so these checks do not validate
the restored artifact and are excluded from that service-account gate.
