# Release notes

## 0.1.4

- `Reset-SprintDatabases` places sprint database data and log files in the
  target instance's default Data and Log folders (parity fix G7).
- Add `Invoke-DatabaseMaintenanceWindow`, the binding-driven maintenance window
  runner (slice S1). Only `-Mode PrecheckOnly` runs, and its SQL is read-only.
  `BackupOnly`, `Full` and `DropClone` refuse with
  `MaintenanceWindowModeNotImplemented`.
- The manifest `ModuleVersion` now matches `version.json`. It had stayed at 0.1.0.

## 0.1.3

- Keep `Remove-SprintDatabases` output to one typed result per instance/database
  pair by suppressing dbatools status objects, including partial status output.
- Request terminating dbatools errors so failed removals return an error row
  without claiming the database was dropped. Preserve existing WhatIf, DryRun,
  instance preflight, and Flyway restrictions.

## 0.1.0

- Initial DatabasePackaging extraction from the BuildTooling compatibility parent.
- Owns database package evidence, build context, feed/compatibility, developer SQL
  instance, and sprint database workflows.
