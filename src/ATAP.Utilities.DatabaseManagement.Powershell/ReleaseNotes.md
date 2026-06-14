# Release Notes — ATAP.Utilities.DatabaseManagement.Powershell

## sprint-0009

- **0.1.6** — Rebuilt and re-promoted to Production (`powershellget-stable`) via the
  BuildMaster `PowerShellModule-5Stage` pipeline. This supersedes the **0.1.4** package,
  which was defective: it shipped only the `.psd1`/`.psm1` and omitted the `public/` +
  `private/` source folders, so its source `.psm1` (which dot-sources
  `$PSScriptRoot\public\*.ps1`) loaded **0 of 32** functions at import. The 0.1.6 package
  is built through `module.build.ps1`, which inlines every function into a self-contained
  `.psm1` (`Build-PSModulePsm1`), so the module exports all of its cmdlets when installed
  from the feed. Install with
  `Install-Module -Name ATAP.Utilities.DatabaseManagement.Powershell -RequiredVersion 0.1.6 -Repository powershellget-stable -Scope AllUsers`.
- Fixed a unit-test bug in `Invoke-FlywayRehearsal.Tests.ps1` ("passes the resolved
  SqlConnection through to Invoke-Flyway") that passed a `[PSCustomObject]` into the real
  `Invoke-Flyway`'s `[Microsoft.Data.SqlClient.SqlConnection]`-typed parameter and failed
  only under the promoted-module tier tests (where the real module assembly is loaded). The
  test now constructs a real unopened `SqlConnection` when the type is available and skips
  cleanly otherwise.

## sprint-0007

- Added Stream J database lifecycle cmdlets: `Resolve-DbInstanceName`, `New-DeveloperScratchDb`, `New-FeatureSharedDb`, `Remove-DeveloperScratchDb`, and `Remove-FeatureSharedDb`.
- Added `Invoke-FlywayRehearsal` to run Flyway against a per-run ephemeral rehearsal database and drop it in `finally`.
- Added `Resolve-DatabaseSqlConnection` to centralize validation for existing SQL connections, Bitwarden connection-string secrets, and `Get-PVal`-resolved connection parts.
- Added mocked unit tests for the lifecycle cmdlets and an opt-in `Integration` test for the `EXPWHERTZING`/Flyway rehearsal path.
- Removed import-time side effects from public scripts so the module can import and export the Stream J cmdlets cleanly.

## sprint-0006

- Moved `Export-RuleToTextFile.ps1` and `Example-RuleExport.ps1` from `Database/Powershell/public/` into this module's `public/` directory. These functions are now packaged and versioned with the module.
