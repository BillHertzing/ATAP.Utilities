# Release Notes — ATAP.Utilities.Security.Secrets.PowerShell

## 0.1.0 (unreleased)

Initial extraction. Pilot child of the `ATAP.Utilities.Security.*` family
(Sprint 0012 Task 12.55.b).

- Moved the six Bitwarden functions out of `ATAP.Utilities.Security.Powershell`:
  `Get-BitWardenCredential`, `List-BitwardenSecrets`, `Load-BitwardenBackup`,
  `New-BitwardenBackup`, `Set-BitWardenSecret`, `Sync-BitWardenDedicatedSecrets`.
- Moved the three aliases with them: `New-BWSecret`, `Add-BitWardenLogin`,
  `Sync-DedicatedSecrets`. These are now **exported** (they were module-internal in the
  umbrella, whose `AliasesToExport` was `@()`).
- **`Load-BitwardenBackup` is now exported.** It was defined in the umbrella's `public/` but
  omitted from the umbrella's `FunctionsToExport`, so it was unreachable as a cmdlet.
- Manifest born correctly cased, `PowerShellVersion = '7.0'`, `CompatiblePSEditions = 'Core'`,
  explicit `CmdletsToExport`/`VariablesToExport` (no wildcards).
- Added the module's first Pester tests (the umbrella had none).

The umbrella re-exports all six functions and three aliases, so existing consumers that
`Import-Module ATAP.Utilities.Security.Powershell` see an unchanged command surface.

### Known remaining debt (tracked, not fixed in this iteration)

- `Get-BitWardenCredential` mutates state (backs up credential files, creates directories,
  writes CLIXML) but does not declare `SupportsShouldProcess`. Deferred rather than patched
  blind: see `Documentation/Invoke-RotateSecretsATAP.DesignDecisions.md`.
- `List-BitwardenSecrets` and `Load-BitwardenBackup` use non-approved verbs. Rename deferred by
  Sprint 0012 Task 12.55.a; when renamed, the old names ship as exported aliases.
