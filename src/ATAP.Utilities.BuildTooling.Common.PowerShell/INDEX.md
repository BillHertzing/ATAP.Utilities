# INDEX — ATAP.Utilities.BuildTooling.Common.PowerShell

module: ATAP.Utilities.BuildTooling.Common.PowerShell
functional-area: BuildTooling
family-parent: ATAP.Utilities.BuildTooling.PowerShell

release-state: 0.1.7 exports Resolve-BuildToolingSettingValue as the shared BuildTooling settings contract and replaces immutable 0.1.5; release pending. Version 0.1.6 is burned after Integration exposed retained nested-module state in the promoted-test runner. Version 0.1.5 is Stable/AllUsers.

## Public functions

| Function | Summary |
| --- | --- |
| `Assert-GitAvailable` | Throws when `git` is unavailable on PATH. |
| `Get-RepositoryRoot` | Resolves a Git repository root, optionally as an absolute worktree path. |
| `Get-WorkspaceJson` | Reads and parses a `.code-workspace` JSON document. |
| `Initialize-ATAPConfigurationGlobals` | Initializes the standard ATAP configuration globals. |
| `Resolve-BuildToolingSettingValue` | Resolves a direct or config-root-mapped setting from the initialized ATAP globals. |
| `Resolve-WorkspaceFiles` | Resolves workspace-file paths to provider paths. |

## Private functions

None.

## Documentation

| File | Purpose |
| --- | --- |
| `ReadMe.md` | Module purpose, boundary, and verification command. |
| `ReleaseNotes.md` | Release history. |
| `Documentation/Task-13.70.d-Batch-1-Disposition.md` | SC-0248, temporary parent-duplication, and Task 13.70.f no-type/no-assembly disposition for the first helper batch. |

## Tests

| File | Covers |
| --- | --- |
| `tests/Unit/CommonModule.Contract.Tests.ps1` | Manifest contract, source import, six-command export surface, and no-type/no-assembly boundary. |
| `tests/Unit/Assert-GitAvailable.Tests.ps1` | Git-available and Git-missing behavior through Common module scope. |
| `tests/Unit/Get-RepositoryRoot.Tests.ps1` | Absolute, relative, and invalid-path Git root behavior through Common module scope. |
| `tests/Unit/Get-WorkspaceJson.Tests.ps1` | Valid, missing, and malformed workspace JSON behavior. |
| `tests/Unit/Initialize-ATAPConfigurationGlobals.Tests.ps1` | Source-first initialization, ready-state no-op, and required settings validation. |
| `tests/Unit/Resolve-BuildToolingSettingValue.Tests.ps1` | Direct and mapped key resolution, value preservation, and failure behavior. |
| `tests/Unit/Resolve-WorkspaceFiles.Tests.ps1` | Single/multiple workspace path resolution and missing-path failure. |
