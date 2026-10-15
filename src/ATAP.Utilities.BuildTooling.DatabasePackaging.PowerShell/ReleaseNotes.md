# Release notes

## 0.1.3 (release candidate)

- Keep `Remove-SprintDatabases` output to one typed result per instance/database
  pair by suppressing dbatools status objects, including partial status output.
- Request terminating dbatools errors so failed removals return an error row
  without claiming the database was dropped. Preserve existing WhatIf, DryRun,
  instance preflight, and Flyway restrictions.

## 0.1.0

- Initial DatabasePackaging extraction from the BuildTooling compatibility parent.
- Owns database package evidence, build context, feed/compatibility, developer SQL
  instance, and sprint database workflows.
