# ATAP.Utilities.DatabaseManagement.Powershell — Index

PowerShell module for SQL Server lifecycle management, Flyway migration orchestration,
backup automation, and rule-export utilities in the ATAP 5-tier ecosystem.

---

## Module Files

| File                                                                                                   | Purpose                                         |
| ------------------------------------------------------------------------------------------------------ | ----------------------------------------------- |
| [ATAP.Utilities.DatabaseManagement.Powershell.psd1](ATAP.Utilities.DatabaseManagement.Powershell.psd1) | Module manifest                                 |
| [ATAP.Utilities.DatabaseManagement.Powershell.psm1](ATAP.Utilities.DatabaseManagement.Powershell.psm1) | Module entry point — dot-sources public cmdlets |
| [module.build.ps1](module.build.ps1)                                                                   | Build script (Invoke-Build / PSake tasks)       |
| [version.json](version.json)                                                                           | Nerdbank.GitVersioning version file             |
| [ReadMe.md](ReadMe.md)                                                                                 | Module overview and getting-started pointer     |
| [ReleaseNotes.md](ReleaseNotes.md)                                                                     | Changelog                                       |

---

## Documentation

| File                                                                                                                                                                               | Purpose                                                                                                                                      |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| [Documentation/GettingStarted.md](Documentation/GettingStarted.md)                                                                                                                 | End-to-end workflow guide for the 5-tier database lifecycle                                                                                  |
| [Documentation/Database Design.md](Documentation/Database%20Design.md)                                                                                                             | Schema design notes for the ATAPUtilities database                                                                                           |
| [Documentation/Self-Maintaining, Contigous Effective Dates in Temporal tables.pdf](Documentation/Self-Maintaining%2C%20Contigous%20Effective%20Dates%20in%20Temporal%20tables.pdf) | Reference paper on SQL temporal-table patterns                                                                                               |
| [Documentation/Legacy-DatabaseBuildAndMigrateTasks-Support-Boundary.md](Documentation/Legacy-DatabaseBuildAndMigrateTasks-Support-Boundary.md)                                     | Support boundary for the legacy `DatabaseBuildAndMigrateTasks.ps1` bundle — lists every legacy capability as supported, deferred, or retired |

---

## Public Cmdlets

### Instance Lifecycle

| Cmdlet                             | File                                                                                       | Synopsis                                                                                                                                                                                                                      |
| ---------------------------------- | ------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Install-SqlServerInstance`        | [public/Install-SqlServerInstance.ps1](public/Install-SqlServerInstance.ps1)               | Creates a SQL Server named instance with dbatools `Install-DbaInstance`; resolves and passes the canonical data, log, and backup paths from the target host/instance row in `$global:settings`. |
| `Get-InstalledDatabaseInformation` | [public/Get-InstalledDatabaseInformation.ps1](public/Get-InstalledDatabaseInformation.ps1) | Returns metadata about running database server processes (SQL Server, MySQL, PostgreSQL) on the local machine.                                                                                                                |
| `Initialize-SqlServiceLogin`       | [public/Initialize-SqlServiceLogin.ps1](public/Initialize-SqlServiceLogin.ps1)             | Idempotently creates a Windows server login, database user, and `db_owner` role grant on a SQL Server instance for a service account via dbatools `Invoke-DbaQuery`, avoiding the SqlServer module load conflict; supports `-WhatIf`. |

### Stream J Database Lifecycle

| Cmdlet                      | File                                                                         | Synopsis                                                                                                                     |
| --------------------------- | ---------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `Resolve-DbInstanceName`    | [public/Resolve-DbInstanceName.ps1](public/Resolve-DbInstanceName.ps1)       | Resolves canonical database names for developer scratch, feature sprint, feature shared, trunk, QA, and production tiers.    |
| `New-DeveloperScratchDb`    | [public/New-DeveloperScratchDb.ps1](public/New-DeveloperScratchDb.ps1)       | Idempotently creates `<App>-dev-<GitHandle>` on the requested SQL Server instance.                                           |
| `New-FeatureSharedDb`       | [public/New-FeatureSharedDb.ps1](public/New-FeatureSharedDb.ps1)             | Idempotently creates `<App>-<FeatureSlug>-shared` on the requested SQL Server instance.                                      |
| `Remove-DeveloperScratchDb` | [public/Remove-DeveloperScratchDb.ps1](public/Remove-DeveloperScratchDb.ps1) | Drops disposable developer scratch or per-feature-sprint databases; `-WhatIf` lists targets and `-Force` skips confirmation. |
| `Remove-FeatureSharedDb`    | [public/Remove-FeatureSharedDb.ps1](public/Remove-FeatureSharedDb.ps1)       | Drops disposable feature shared databases; `-WhatIf` lists targets and `-Force` skips confirmation.                          |

### Database Build and Migration

| Cmdlet                     | File                                                                       | Synopsis                                                                                                                                                                                                                                                                              |
| -------------------------- | -------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Build-DatabaseWithFlyway` | [public/Build-DatabaseWithFlyway.ps1](public/Build-DatabaseWithFlyway.ps1) | Orchestrates a complete database build: drops and recreates the database via source-loaded active worktree helpers, then applies all Flyway migrations. Accepts separate `DatabasePath` and `DatabaseLogPath` values, propagates an explicit repository root, and maps canonical QA/Integration names to Invoke-Flyway's legacy Testing/Development vocabulary. |
| `DatabaseProvisioning`     | [public/DatabaseProvisioning.ps1](public/DatabaseProvisioning.ps1)         | Creates (or recreates) a database and associated login/user objects. MDF/NDF files use `DatabasePath`; LDF files use the independently supplied `DatabaseLogPath`. Called internally by `Build-DatabaseWithFlyway`. |
| `Invoke-Flyway`            | [public/Invoke-Flyway.ps1](public/Invoke-Flyway.ps1)                       | Builds a JDBC connection string, exports Flyway placeholder environment variables (including SHA256 migration-file hashes), selects a process-local Java 17+ runtime when PATH points at an older Java, reads User-scope `UserPii` passphrase values for agent shells, and invokes a Flyway command (`migrate`, `baseline`, `info`, etc.). |
| `Invoke-FlywayRehearsal`   | [public/Invoke-FlywayRehearsal.ps1](public/Invoke-FlywayRehearsal.ps1)     | Creates a per-run ephemeral rehearsal database, runs `Invoke-Flyway -FlywayCommand migrate`, drops the DB in `finally`, and optionally writes a JSON log.                                                                                                                             |

### Connection and Credentials

| Cmdlet                                    | File                                                                                                     | Synopsis                                                                                                                                                                                                                        |
| ----------------------------------------- | -------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Resolve-DatabaseSqlConnection`           | [public/Resolve-DatabaseSqlConnection.ps1](public/Resolve-DatabaseSqlConnection.ps1)                     | Resolves the three supported database connection inputs to one open `Microsoft.Data.SqlClient.SqlConnection`: existing connection, Bitwarden connection-string secret, or `Get-PVal`-resolved connection parts. For the secret path, `dbConnectionString.*` values are read through `Get-SecretATAP -SecretStoreType 'BitwardenSecretsManager'`; Development and Experimental names hard-fail when BWS cannot return the value. |
| `New-ConnectionStringBuilderFromDbaTools` | [public/New-ConnectionStringBuilderFromDbaTools.ps1](public/New-ConnectionStringBuilderFromDbaTools.ps1) | Wraps `New-DbaConnectionStringBuilder` with Bitwarden vault integration and JDBC output support. Supports `IntegratedSecurity` and `CredentialsFromVault` parameter sets.                                                       |
| `Get-DatabaseCredentialsKey`              | [public/Get-DatabaseCredentialsKey.ps1](public/Get-DatabaseCredentialsKey.ps1)                           | Constructs the canonical Bitwarden secret name for a database connection string given `DatabaseName`, `DatabaseHost`, and `Environment`. For per-sprint tiers (`Development`, `Experimental`) the key includes `$env:USERNAME`. |

### Backup

| Cmdlet                   | File                                                                   | Synopsis                                                                                                                                                                                                                  |
| ------------------------ | ---------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Invoke-SqlServerBackup` | [public/Invoke-SqlServerBackup.ps1](public/Invoke-SqlServerBackup.ps1) | Backs up a SQL Server database (`localhost\Production`) to `C:\Dropbox\Backups\utat022\<DatabaseName>\`. Supports Full and Differential backup types; uses dbatools. Intended to be called from Cobian Backup pre-events. |
| `New-CobianSqlJobs`      | [public/New-CobianSqlJobs.ps1](public/New-CobianSqlJobs.ps1)           | Creates four Cobian Reflector Dummy tasks (with pre-events) that invoke `Invoke-SqlServerBackup.ps1` for nightly ProGet and BuildMaster SQL backups. Writes directly to Cobian's `MainList.lst`.                          |
| `New-CobianAppJobs`      | [New-CobianAppJobs](public/New-CobianAppJobs.ps1)                      | Autoloaded function. Creates five Cobian Reflector file-copy tasks for backing up ProGet and BuildMaster application-data directories and the Cobian configuration itself.                                                |

### Database Change Packages (V4-E stream)

| Cmdlet                         | File                                                                               | Synopsis                                                                                                                                                                                                                                               | Env vars / Secrets                                                                          |
| ------------------------------ | ---------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------- |
| `New-DatabaseChangePackage`    | [public/New-DatabaseChangePackage.ps1](public/New-DatabaseChangePackage.ps1)       | Packages migrations, repeatables, seeds, and loaders from `Database/<Application>/` into a deterministic `.nupkg` with SHA-256 checksums and a v2 `db-release-unit-manifest.json`.                                                                     | None required; `RepositoryRoot` defaults to module parent.                                  |
| `Get-DatabasePackageManifest`  | [public/Get-DatabasePackageManifest.ps1](public/Get-DatabasePackageManifest.ps1)   | Reads and parses `db-release-unit-manifest.json` from an expanded package folder or a `.nupkg` file; returns a `[PSCustomObject]`.                                                                                                                     | None.                                                                                       |
| `Test-DatabasePackageManifest` | [public/Test-DatabasePackageManifest.ps1](public/Test-DatabasePackageManifest.ps1) | Validates a manifest object against the v2 schema fields and enum constraints; returns `[PSCustomObject]@{ IsValid; Errors }`.                                                                                                                         | None; `SchemaPath` defaults to `SolutionDocumentation/schemas/db-release-unit.schema.json`. |
| `Test-DatabaseChangePackage`   | [public/Test-DatabaseChangePackage.ps1](public/Test-DatabaseChangePackage.ps1)     | Full package validation: manifest validity, per-file SHA-256 checksum re-computation, and optional ceiling policy check via `database-package-ceiling.json`. Returns `[PSCustomObject]@{ IsValid; ManifestErrors; ChecksumErrors; CeilingViolation }`. | None.                                                                                       |
| `Expand-DatabaseChangePackage` | [public/Expand-DatabaseChangePackage.ps1](public/Expand-DatabaseChangePackage.ps1) | Extracts a `.nupkg` to a destination folder (default: `$env:TEMP\dbpkg-expand-<GUID>`) using `ZipFile::ExtractToDirectory`; returns the destination path.                                                                                              | None.                                                                                       |

### Flyway Safety Gates (DBA1-T04 / V4-E07)

| Cmdlet                            | File                                                                                     | Synopsis                                                                                                                                                                                                           | Prerequisites                                                                            |
| --------------------------------- | ---------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------- |
| `Invoke-DatabasePackageRehearsal` | [public/Invoke-DatabasePackageRehearsal.ps1](public/Invoke-DatabasePackageRehearsal.ps1) | Expands a database change package (`.nupkg` or folder) and runs `Invoke-FlywayRehearsal`; returns `[PSCustomObject]@{ Success; PackagePath; ValidateOutput; MigrateOutput; ElapsedSeconds }`.                      | `Expand-DatabaseChangePackage`, `Get-DatabasePackageManifest`, `Invoke-FlywayRehearsal`. |
| `Test-FlywayMigrationSafety`      | [public/Test-FlywayMigrationSafety.ps1](public/Test-FlywayMigrationSafety.ps1)           | Classifies migrations by `destructiveChangeKind`; blocks promotion if evidence files are missing. Returns `[PSCustomObject]@{ IsSafe; DestructiveMigrations; MissingEvidence }`.                                   | `Get-DatabasePackageManifest`; evidence files in package folder.                         |
| `Test-DatabaseSeedIdempotency`    | [public/Test-DatabaseSeedIdempotency.ps1](public/Test-DatabaseSeedIdempotency.ps1)       | Runs each seed/loader script twice and compares row counts and content hashes. Returns `[PSCustomObject]@{ IsIdempotent; Mismatches }`.                                                                            | Live DB connection; `Resolve-DatabaseSqlConnection`; `Get-DatabasePackageManifest`.      |
| `Get-FlywaySchemaVersion`         | [public/Get-FlywaySchemaVersion.ps1](public/Get-FlywaySchemaVersion.ps1)                 | Queries `flyway_schema_history` ordered by `installed_rank DESC`; returns `[PSCustomObject[]]` with InstalledRank, Version, Description, Type, Script, Checksum, InstalledBy, InstalledOn, ExecutionTime, Success. | Live DB connection; `Resolve-DatabaseSqlConnection`.                                     |

### Rollback and Snapshot (DBA1-T05 / V4-E13)

| Cmdlet                             | File                                                                                       | Synopsis                                                                                                                                                                                                                                | Prerequisites                                                                            |
| ---------------------------------- | ------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| `New-DatabasePreMigrationSnapshot` | [public/New-DatabasePreMigrationSnapshot.ps1](public/New-DatabasePreMigrationSnapshot.ps1) | Takes a dbatools Full backup before a migration run; captures Flyway schema version at backup time; writes `pre-migration-snapshot-evidence.json` to `_generated/database-packages/<Application>/`; returns the evidence object.        | dbatools; `Get-FlywaySchemaVersion`; `Get-RepositoryRoot` or explicit `-RepositoryRoot`. |
| `Restore-DatabaseFromSnapshot`     | [public/Restore-DatabaseFromSnapshot.ps1](public/Restore-DatabaseFromSnapshot.ps1)         | Restores a `.bak` via `Restore-DbaDatabase`; verifies post-restore Flyway schema version matches the version recorded in the evidence file. Returns `[PSCustomObject]@{ Restored; VerifiedVersion; Errors }`.                          | dbatools; `Get-FlywaySchemaVersion`.                                                     |
| `Test-DatabaseRollbackReadiness`   | [public/Test-DatabaseRollbackReadiness.ps1](public/Test-DatabaseRollbackReadiness.ps1)     | Reads `pre-migration-snapshot-evidence.json` and verifies: file exists, backup file exists, evidence timestamp is within `MaxAgeMinutes` (default 60). No SQL Server connection required. Returns `[PSCustomObject]@{ IsReady; Reason }`. | None (file-system only).                                                                 |

### Rules and Utilities

| Cmdlet / Script          | File                                                                 | Synopsis                                                                                                                                                                 |
| ------------------------ | -------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `Export-RuleToTextFile`  | [public/Export-RuleToTextFile.ps1](public/Export-RuleToTextFile.ps1) | Retrieves a Rule by name from the ATAPUtilities database and exports all metadata (PhiloteID, purpose, language kind, composition, primitives) to a formatted text file. |
| `Example-RuleExport.ps1` | [public/Example-RuleExport.ps1](public/Example-RuleExport.ps1)       | Example script demonstrating `Export-RuleToTextFile` usage scenarios: single export, batch export, and error handling.                                                   |

### Instantiation Inventory

| Cmdlet                                  | File                                                                                                             | Synopsis                                                                                                                                                                       |
| --------------------------------------- | ---------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `Get-InstantiationSourceModuleInventory` | [public/Get-InstantiationSourceModuleInventory.ps1](public/Get-InstantiationSourceModuleInventory.ps1)           | Scans source modules and optionally emits a deterministic, exact-case, byte-hash-based read-only immutable-version proposal. |
| `Get-InstantiationVersionRuleGraph`      | [public/Get-InstantiationVersionRuleGraph.ps1](public/Get-InstantiationVersionRuleGraph.ps1)                     | Loads the corrected ordered graph plus immutable RuleInstantiation bindings, declared inputs, source lines, and planned artifacts; invalid snapshots fail closed. |
| `Export-InstantiationManifestation`      | [public/Export-InstantiationManifestation.ps1](public/Export-InstantiationManifestation.ps1)                     | Preserves the legacy inventory export and adds safe corrected-graph dry-run/exact-byte rendering with SHA-256 and idempotent SQL provenance. |

Implementation and verification: [Task 13.80 — Instantiation Query, Ingestion, and Execution](../../SolutionDocumentation/Task-13.80-Instantiation-Execution.md).

---

## Obsolete Scripts

Scripts superseded by newer cmdlets; retained for reference.

| File                                                                                                                                 | Notes                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| ------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [public/Obsolete/afterVersioned\_\_ImportData.ps1](public/Obsolete/afterVersioned__ImportData.ps1)                                   | Legacy post-versioning data import                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| [public/Obsolete/ATAPUtilities_Database_BackupDropAndRecreate.ps1](public/Obsolete/ATAPUtilities_Database_BackupDropAndRecreate.ps1) | Superseded by `Build-DatabaseWithFlyway` + `Invoke-SqlServerBackup`                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| [public/Obsolete/ATAPUtilities_Database_BulkDataOut.ps1](public/Obsolete/ATAPUtilities_Database_BulkDataOut.ps1)                     | Legacy bulk-export script                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| [public/Obsolete/DatabaseBuildAndMigrateTasks.ps1](public/Obsolete/DatabaseBuildAndMigrateTasks.ps1)                                 | Obsolete Redgate / Phil Factor PubsAndFlyway task-script collection; no longer exported. See [Documentation/Legacy-DatabaseBuildAndMigrateTasks-Support-Boundary.md](Documentation/Legacy-DatabaseBuildAndMigrateTasks-Support-Boundary.md) for the supported / deferred / retired capability tables, and [Plan-DatabaseBuildAndMigrateTasksReplacement.md](../../../_Planning-wt-14-Sprint-0007-work-items/Plan-DatabaseBuildAndMigrateTasksReplacement.md) for the authoritative analysis before reactivating any behavior. |
| [public/Obsolete/DataLoad.Tests.ps1](public/Obsolete/DataLoad.Tests.ps1)                                                             | Legacy Pester data-load tests                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| [public/Obsolete/Invoke-DatabaseRebuild.ps1](public/Obsolete/Invoke-DatabaseRebuild.ps1)                                             | Superseded by `Build-DatabaseWithFlyway`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| [public/Obsolete/New-DeveloperDatabaseInstances.ps1](public/Obsolete/New-DeveloperDatabaseInstances.ps1)                             | Superseded by `New-SprintSqlServerInstances` (BuildTooling module) — creates both instances and runs full Flyway migrations for all databases                                                                                                                                                                                                                                                                                                                                                                                 |

---

## Tests

| File                                                             | Purpose                                                                                   |
| ---------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| [tests/PesterConfiguration.psd1](tests/PesterConfiguration.psd1) | Pester 5 configuration for this module's test suite                                       |
| [tests/Unit](tests/Unit)                                         | Unit tests for naming, lifecycle cmdlets, and Flyway rehearsal behavior                   |
| [tests/Integration](tests/Integration)                           | Opt-in `EXPWHERTZING`/Flyway rehearsal test; set `ATAP_RUN_DB_INTEGRATION_TESTS=1` to run |

---

## Sprint Database Quick-Reference

To provision both instances and build all databases at sprint start, use `New-SprintSqlServerInstances`
from the BuildTooling module (handles instance creation + full Flyway migrations in one call):

```powershell
# Preferred — creates Dev<username> / Exp<username> and builds ATAPUtilities + AceCommander
New-SprintSqlServerInstances
```

To build databases on already-provisioned instances, call `Build-DatabaseWithFlyway` directly:

```powershell
foreach ($inst in @("Dev$($env:USERNAME)", "Exp$($env:USERNAME)")) {
    foreach ($db in @('ATAPUtilities', 'AceCommander')) {
        Build-DatabaseWithFlyway -DatabaseName $db -SqlInstance $inst -IntegratedSecurity -Force
    }
}
```

**Related documents:**

- [SolutionDocumentation/SprintInfrastructure-Naming.md](../../SolutionDocumentation/SprintInfrastructure-Naming.md) — SQL instance naming rules (16-char max; `Dev<username>` / `Exp<username>`)
- [SolutionDocumentation/Rules Compendium.Powershell.md](../../SolutionDocumentation/Rules%20Compendium.Powershell.md) — `Build-DatabaseWithFlyway` rule primitives

- Version bumped to 0.1.10 in Sprint 11

