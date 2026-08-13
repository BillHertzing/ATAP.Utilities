# ATAP.Utilities.DatabaseManagement.Powershell

`ATAP.Utilities.DatabaseManagement.PowerShell` is a PowerShell module that provides
database lifecycle management for the ATAP ecosystem. It covers:

- **Database change packaging** — deterministic `.nupkg` creation, manifest validation,
  and checksum verification for Flyway-managed databases.
- **Flyway safety gates** — rehearsal runs, migration safety analysis, seed idempotency
  checks, and schema-version queries before committing a migration to a shared environment.
- **Rollback and snapshot automation** — pre-migration SQL Server backups, post-restore
  verification, and rollback-readiness checks.
- **SQL Server lifecycle helpers** — instance installation, developer scratch databases,
  feature shared databases, backup jobs, and connection string resolution.
- **Instantiation inventory helpers** — scan repository PowerShell/C# module source
  into database-shaped `SourceModule` rows and render manifestation evidence for
  Sprint 0012 instantiation work.

## Importing the Module

```powershell
# From a repo worktree (development):
Import-Module (Resolve-Path './src/ATAP.Utilities.DatabaseManagement.Powershell/ATAP.Utilities.DatabaseManagement.Powershell.psd1') -Force

# After the module is promoted to a ProGet feed:
Install-Module -Name ATAP.Utilities.DatabaseManagement.Powershell -Repository <FeedName> -Force
Import-Module ATAP.Utilities.DatabaseManagement.Powershell
```

## Full Cmdlet Reference

See **[INDEX.md](INDEX.md)** for the complete, categorized list of every public cmdlet,
its synopsis, required environment variables, and Bitwarden secret names.

## Connection-String Secrets

`Resolve-DatabaseSqlConnection` treats `DBConnectionString*` /
`dbConnectionString-*` names as Bitwarden Secrets Manager values. Runtime secret
reads use `Get-SecretATAP -SecretStoreType 'BitwardenSecretsManager'` and do not
derive missing Development or Experimental strings locally. Use
`New-SprintBitwardenSecrets` in BuildTooling to create/check the expected Dev/Exp
BWS entries before database rebuilds.

## Deep Reference Documentation

See **[Documentation/](Documentation/)** for implementation details, required
configuration keys, example invocations, and integration notes for each cmdlet family.

## 5-Tier Module Flow

Use the module-level getting started guide for the lifecycle workflow:

- [Documentation/GettingStarted.md](Documentation/GettingStarted.md)

## Public Cmdlets (Summary)

| Cmdlet                                    | Category            | Description                                                                                                                |
| ----------------------------------------- | ------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `New-DatabaseChangePackage`               | Change Packages     | Packages migrations, repeatables, seeds, and loaders into a deterministic `.nupkg` with SHA-256 checksums and v2 manifest. |
| `Get-DatabasePackageManifest`             | Change Packages     | Reads and parses `db-release-unit-manifest.json` from a folder or `.nupkg`.                                                |
| `Test-DatabasePackageManifest`            | Change Packages     | Validates a manifest against the v2 schema; returns `IsValid` + `Errors`.                                                  |
| `Test-DatabaseChangePackage`              | Change Packages     | Full package validation: manifest, per-file SHA-256, and ceiling policy check.                                             |
| `Expand-DatabaseChangePackage`            | Change Packages     | Extracts a `.nupkg` to a folder for inspection or deployment.                                                              |
| `Invoke-DatabasePackageRehearsal`         | Flyway Safety Gates | Expands a package and runs `Invoke-FlywayRehearsal`; returns rehearsal output and elapsed time.                            |
| `Test-FlywayMigrationSafety`              | Flyway Safety Gates | Classifies migrations by destructive-change kind; blocks promotion if evidence files are missing.                          |
| `Test-DatabaseSeedIdempotency`            | Flyway Safety Gates | Runs seed/loader scripts twice and compares row counts and content hashes.                                                 |
| `Get-FlywaySchemaVersion`                 | Flyway Safety Gates | Queries `flyway_schema_history` and returns the version history ordered by `installed_rank DESC`.                          |
| `New-DatabasePreMigrationSnapshot`        | Rollback / Snapshot | Takes a Full backup before migration; captures Flyway version; writes evidence JSON.                                       |
| `Restore-DatabaseFromSnapshot`            | Rollback / Snapshot | Restores from a pre-migration `.bak` via dbatools; verifies post-restore Flyway version.                                   |
| `Test-DatabaseRollbackReadiness`          | Rollback / Snapshot | Checks evidence file age, backup file presence, and timestamp — no SQL connection required.                                |
| `Build-DatabaseWithFlyway`                | Flyway Helpers      | Rebuild a target database using active worktree helper files; keeps data and log files in independently supplied settings-backed paths and maps canonical QA/Integration tier names at the legacy Flyway boundary. |
| `Get-DatabaseCredentialsKey`              | Connection Helpers  | Resolve the Bitwarden credentials key for a given database / tier / host.                                                  |
| `Get-InstalledDatabaseInformation`        | Instance Management | Return metadata about installed SQL Server instances.                                                                      |
| `Initialize-SqlServiceLogin`              | Instance Management | Initialise SQL Server service logins using dbatools `Invoke-DbaQuery` without loading the SqlServer module.                 |
| `Install-SqlServerInstance`               | Instance Management | Install and configure a SQL Server instance using the target host/instance data, log, and backup paths from `$global:settings`. |
| `Invoke-Flyway`                           | Flyway Helpers      | Invoke Flyway with Java 17+ selection and User-scope `UserPii` passphrase fallback for agent shells.                       |
| `Invoke-FlywayRehearsal`                  | Flyway Helpers      | Run Flyway against a per-run ephemeral rehearsal database.                                                                 |
| `Invoke-SqlServerBackup`                  | Backup              | Back up a SQL Server database using dbatools.                                                                              |
| `New-CobianAppJobs`                       | Backup              | Create Cobian Backup application jobs.                                                                                     |
| `New-CobianSqlJobs`                       | Backup              | Create Cobian Backup SQL Server jobs.                                                                                      |
| `New-ConnectionStringBuilderFromDbaTools` | Connection Helpers  | Build a connection string using dbatools conventions.                                                                      |
| `New-DeveloperScratchDb`                  | Developer Databases | Idempotently create a per-developer scratch database.                                                                      |
| `New-FeatureSharedDb`                     | Developer Databases | Idempotently create a per-feature shared database.                                                                         |
| `Remove-DeveloperScratchDb`               | Developer Databases | Drop disposable developer scratch databases.                                                                               |
| `Remove-FeatureSharedDb`                  | Developer Databases | Drop disposable per-feature shared databases.                                                                              |
| `Resolve-DatabaseSqlConnection`           | Connection Helpers  | Resolve a SqlConnection from three connection-method parameter sets.                                                       |
| `Resolve-DbInstanceName`                  | Instance Management | Resolve canonical Stream J database names.                                                                                 |
| `Get-InstantiationSourceModuleInventory`  | Instantiation       | Scan source modules or emit a deterministic read-only immutable-version proposal from exact-case paths and byte hashes. |
| `Get-InstantiationVersionRuleGraph`       | Instantiation       | Load the corrected ordered version graph and validate immutable RuleInstantiation inputs and exact source lines. |
| `Export-InstantiationManifestation`       | Instantiation       | Dry-run or safely render a corrected graph below the approved root with exact bytes, SHA-256, and idempotent provenance; legacy inventory evidence remains supported. |

See [Task 13.80 — Instantiation Query, Ingestion, and Execution](../../SolutionDocumentation/Task-13.80-Instantiation-Execution.md)
for the execution contract, safety gates, and verification evidence.
- Version bumped to 0.1.10 in Sprint 11

## Functional area

Database & Flyway - START HERE: SolutionDocumentation\Database-Change-Unit-and-Flyway-Promotion.md (link-up added 2026-07-07, Sprint 0012 Task 12.46.f)
