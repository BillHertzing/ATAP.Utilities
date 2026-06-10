# Release Notes — ATAP.Utilities.DatabaseManagement.Powershell

## sprint-0007

- Added Stream J database lifecycle cmdlets: `Resolve-DbInstanceName`, `New-DeveloperScratchDb`, `New-FeatureSharedDb`, `Remove-DeveloperScratchDb`, and `Remove-FeatureSharedDb`.
- Added `Invoke-FlywayRehearsal` to run Flyway against a per-run ephemeral rehearsal database and drop it in `finally`.
- Added `Resolve-DatabaseSqlConnection` to centralize validation for existing SQL connections, Bitwarden connection-string secrets, and `Get-PVal`-resolved connection parts.
- Added mocked unit tests for the lifecycle cmdlets and an opt-in `Integration` test for the `EXPWHERTZING`/Flyway rehearsal path.
- Removed import-time side effects from public scripts so the module can import and export the Stream J cmdlets cleanly.

## sprint-0006

- Moved `Export-RuleToTextFile.ps1` and `Example-RuleExport.ps1` from `Database/Powershell/public/` into this module's `public/` directory. These functions are now packaged and versioned with the module.
