# Release notes — ATAP.Utilities.BuildTooling.Common.PowerShell

## 0.1.0

- Created the empty, PowerShell 7/Core-only Common module scaffold for Sprint 0013 Task 13.70.c.
- Copied the first approved public helper batch under Task 13.70.d: `Assert-GitAvailable`,
  `Get-WorkspaceJson`, `Initialize-ATAPConfigurationGlobals`, and `Resolve-WorkspaceFiles`.
- Parent implementations remain temporarily to preserve the unrewired parent contract.
- Added the Common-owned Pester slice for each exported helper under Task 13.70.e.
