# ATAP.Utilities.DatabaseManagement.PowerShell/Documentation — Index

Per-cmdlet deep references for the database-pipeline cmdlets in this
module. The module root [`../INDEX.md`](../INDEX.md) is the canonical
full list of every cmdlet in the module; this file scopes to the
database-pipeline cmdlets and adds the **required env vars, secret
names, and example invocation** for each one.

> **Conventions used by every cmdlet in this list:**
> - SQL Server connection strings are resolved by name from Bitwarden
>   via `Get-BitWardenSecret`. Names follow the pattern documented in
>   [`.claude/Rules/Bitwarden.md`](../../../.claude/Rules/Bitwarden.md).
> - ProGet API keys are resolved from User-scope environment variables.
> - All cmdlets log with `Write-PSFMessage` (`Debug`/`Verbose`/`Important`/`Error`); none use `Write-Host`.

---

## Package authoring

### `New-DatabaseChangePackage`

- **Source:** [`../public/New-DatabaseChangePackage.ps1`](../public/New-DatabaseChangePackage.ps1)
- **What it does:** Collects files from `Database/<Application>/`, computes
  SHA-256 checksums, generates `db-release-unit-manifest.json`, and runs
  `dotnet pack` to produce a `.nupkg`. Deterministic: identical inputs
  produce identical manifests.
- **Required env vars:** None directly (the cmdlet does not push to ProGet).
- **Required Bitwarden secret names:** None at package authoring time.
- **Example:**
  ```powershell
  $nupkg = New-DatabaseChangePackage -Application 'ATAPUtilities'
  ```

### `Get-DatabasePackageManifest`

- **Source:** [`../public/Get-DatabasePackageManifest.ps1`](../public/Get-DatabasePackageManifest.ps1)
- **What it does:** Reads the `db-release-unit-manifest.json` from inside
  an expanded database change package and returns a PSCustomObject.
- **Required env vars:** None.
- **Required Bitwarden secret names:** None.
- **Example:**
  ```powershell
  $manifest = Get-DatabasePackageManifest -PackagePath './expanded/ATAPUtilities.Database.1.5.0/'
  ```

### `Test-DatabasePackageManifest`

- **Source:** [`../public/Test-DatabasePackageManifest.ps1`](../public/Test-DatabasePackageManifest.ps1)
- **What it does:** Validates a manifest against
  [`SolutionDocumentation/schemas/db-release-unit.schema.json`](../../../SolutionDocumentation/schemas/db-release-unit.schema.json).
- **Required env vars:** None.
- **Required Bitwarden secret names:** None.
- **Example:**
  ```powershell
  Test-DatabasePackageManifest -ManifestPath './db-release-unit-manifest.json'
  ```

### `Test-DatabaseChangePackage`

- **Source:** [`../public/Test-DatabaseChangePackage.ps1`](../public/Test-DatabaseChangePackage.ps1)
- **What it does:** Validates a `.nupkg` produced by
  `New-DatabaseChangePackage`: manifest conformance, checksum integrity,
  required files present.
- **Required env vars:** None.
- **Required Bitwarden secret names:** None.
- **Example:**
  ```powershell
  Test-DatabaseChangePackage -NupkgPath './out/ATAPUtilities.Database.1.5.0.nupkg'
  ```

### `Expand-DatabaseChangePackage`

- **Source:** [`../public/Expand-DatabaseChangePackage.ps1`](../public/Expand-DatabaseChangePackage.ps1)
- **What it does:** Extracts a database change package `.nupkg` into a
  folder ready for rehearsal or deployment.
- **Required env vars:** None.
- **Required Bitwarden secret names:** None.
- **Example:**
  ```powershell
  Expand-DatabaseChangePackage -NupkgPath './ATAPUtilities.Database.1.5.0.nupkg' -DestinationPath './expanded/1.5.0/'
  ```

---

## Rehearsal and validation

### `Invoke-DatabasePackageRehearsal`

- **Source:** [`../public/Invoke-DatabasePackageRehearsal.ps1`](../public/Invoke-DatabasePackageRehearsal.ps1)
- **What it does:** Runs the database change package against a target
  SQL Server instance in a rehearsal mode: optional pre-migration
  snapshot, Flyway migrate, seed loader, Pester validation, and
  evidence capture.
- **Required env vars:** `BW_SESSION` (for connection-string resolution).
- **Required Bitwarden secret names:**
  - `dbConnectionString.<Database>.<Host>.<Tier>` for the target instance.
- **Example:**
  ```powershell
  Invoke-DatabasePackageRehearsal `
      -ExpandedPackagePath './expanded/1.5.0/' `
      -Database 'ATAPUtilities' `
      -Host 'utat022' `
      -Tier 'Integration'
  ```

### `Test-FlywayMigrationSafety`

- **Source:** [`../public/Test-FlywayMigrationSafety.ps1`](../public/Test-FlywayMigrationSafety.ps1)
- **What it does:** Static-analysis check on Flyway migrations for unsafe
  patterns (DROP TABLE, NOT NULL without DEFAULT on existing rows, etc.).
  Runs without touching a real database.
- **Required env vars:** None.
- **Required Bitwarden secret names:** None.
- **Example:**
  ```powershell
  Test-FlywayMigrationSafety -MigrationsPath './expanded/1.5.0/migrations/'
  ```

### `Test-DatabaseSeedIdempotency`

- **Source:** [`../public/Test-DatabaseSeedIdempotency.ps1`](../public/Test-DatabaseSeedIdempotency.ps1)
- **What it does:** Runs the seed loader twice and confirms the second
  run is a no-op (idempotent). Compares row counts and content
  checksums.
- **Required env vars:** `BW_SESSION`.
- **Required Bitwarden secret names:**
  - `dbConnectionString.<Database>.<Host>.<Tier>` for the target instance.
- **Example:**
  ```powershell
  Test-DatabaseSeedIdempotency -SeedLoaderPath './expanded/1.5.0/seed-loader.ps1' `
      -Database 'ATAPUtilities' -Host 'utat022' -Tier 'Integration'
  ```

### `Get-FlywaySchemaVersion`

- **Source:** [`../public/Get-FlywaySchemaVersion.ps1`](../public/Get-FlywaySchemaVersion.ps1)
- **What it does:** Returns the highest applied Flyway version on the
  target database.
- **Required env vars:** `BW_SESSION`.
- **Required Bitwarden secret names:**
  - `dbConnectionString.<Database>.<Host>.<Tier>` for the target instance.
- **Example:**
  ```powershell
  Get-FlywaySchemaVersion -Database 'ATAPUtilities' -Host 'utat022' -Tier 'Production'
  ```

---

## Pre-migration snapshot and rollback

The three cmdlets below complete the rollback story owned by DBA1-T05.

### `New-DatabasePreMigrationSnapshot`

- **Source:** `../public/New-DatabasePreMigrationSnapshot.ps1`
- **Synopsis:** Takes a dbatools Full backup immediately before a Flyway migration run.
  Captures the Flyway schema version at backup time, computes the SHA-256 of the `.bak`
  file, and writes all metadata to
  `_generated/database-packages/<Application>/pre-migration-snapshot-evidence.json`.
  Returns the evidence object.
- **Parameters:** `-Application` (required), `-DatabaseName` (required),
  `-SqlInstance` (optional, defaults from `$global:settings`),
  `-BackupPath` (optional, defaults to `$env:TEMP\dbsnap-…`),
  `-RepositoryRoot` (optional, defaults via `Get-RepositoryRoot`).
- **Required env vars:** `BW_SESSION` (for `Get-FlywaySchemaVersion`).
- **Required Bitwarden secret names:**
  - `dbConnectionString.<Application>.<Host>.<Tier>` (SELECT on `flyway_schema_history`).
- **Example:**
  ```powershell
  New-DatabasePreMigrationSnapshot -Application ATAPUtilities -DatabaseName ATAPUtilities `
      -SqlInstance 'localhost\SQLEXPRESS'
  ```

### `Restore-DatabaseFromSnapshot`

- **Source:** `../public/Restore-DatabaseFromSnapshot.ps1`
- **Synopsis:** Restores a database from a `.bak` file via `Restore-DbaDatabase`.
  After restore, calls `Get-FlywaySchemaVersion` and verifies the post-restore schema
  version matches the version recorded in the evidence file.
  Returns `[PSCustomObject]@{ Restored; VerifiedVersion; Errors }`.
- **Parameters:** `-BackupPath` (required), `-DatabaseName` (required),
  `-SqlInstance` (required), `-EvidenceFile` (optional), `-WithReplace` (switch).
- **Required env vars:** `BW_SESSION`.
- **Required Bitwarden secret names:**
  - `dbConnectionString.master.<Host>.<Tier>` (ALTER DATABASE rights for restore).
- **Example:**
  ```powershell
  Restore-DatabaseFromSnapshot -BackupPath 'C:\Temp\…\ATAPUtilities_PREMIG_….bak' `
      -EvidenceFile 'C:\…\_generated\database-packages\ATAPUtilities\pre-migration-snapshot-evidence.json' `
      -DatabaseName ATAPUtilities -SqlInstance 'localhost\SQLEXPRESS' -WithReplace
  ```

### `Test-DatabaseRollbackReadiness`

- **Source:** `../public/Test-DatabaseRollbackReadiness.ps1`
- **Synopsis:** Reads `pre-migration-snapshot-evidence.json` and checks (without
  connecting to SQL Server): evidence file exists and parses, backup file exists at the
  recorded path, evidence timestamp is within `MaxAgeMinutes` (default 60).
  Returns `[PSCustomObject]@{ IsReady; Reason; BackupFile }`.
- **Parameters:** `-EvidencePath` (required), `-MaxAgeMinutes` (optional, default 60).
- **Required env vars:** None.
- **Required Bitwarden secret names:** None.
- **Example:**
  ```powershell
  $r = Test-DatabaseRollbackReadiness `
      -EvidencePath 'C:\…\_generated\database-packages\ATAPUtilities\pre-migration-snapshot-evidence.json'
  if (-not $r.IsReady) { throw "Not ready to roll back: $($r.Reason)" }
  ```

---

## See also

- [ReadMe.md](ReadMe.md) — folder purpose, env-var summary, secret-name
  conventions.
- [`../INDEX.md`](../INDEX.md) — module root index (canonical full
  cmdlet inventory; owned by DBA1).
- [`../ReadMe.md`](../ReadMe.md) — module root readme (owned by DBA1).
- [Database-Package-Artifact-And-Feed-Decision.md](../../../SolutionDocumentation/Database-Package-Artifact-And-Feed-Decision.md)
- [Database-Change-Unit-and-Flyway-Promotion.md](../../../SolutionDocumentation/Database-Change-Unit-and-Flyway-Promotion.md)
- [Database-Package-Compatibility.md](../../../SolutionDocumentation/Database-Package-Compatibility.md)
