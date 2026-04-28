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

| File                                                                                                                                                                               | Purpose                                                     |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------- |
| [Documentation/GettingStarted.md](Documentation/GettingStarted.md)                                                                                                                 | End-to-end workflow guide for the 5-tier database lifecycle |
| [Documentation/Database Design.md](Documentation/Database%20Design.md)                                                                                                             | Schema design notes for the ATAPUtilities database          |
| [Documentation/Self-Maintaining, Contigous Effective Dates in Temporal tables.pdf](Documentation/Self-Maintaining%2C%20Contigous%20Effective%20Dates%20in%20Temporal%20tables.pdf) | Reference paper on SQL temporal-table patterns              |

---

## Public Cmdlets

### Instance Lifecycle

| Cmdlet                             | File                                                                                       | Synopsis                                                                                                                                                                                         |
| ---------------------------------- | ------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `Install-SqlServerInstance`        | [public/Install-SqlServerInstance.ps1](public/Install-SqlServerInstance.ps1)               | Creates a SQL Server named instance on a host where SQL Server software is already present; uses dbatools `Install-DbaInstance`.                                                                 |
| `Remove-SprintSqlServerInstances`  | [public/Remove-SprintSqlServerInstances.ps1](public/Remove-SprintSqlServerInstances.ps1)   | Sprint end: removes the two per-developer named instances (`Dev<username>`, `Exp<username>`). Supersedes `Remove-DeveloperDatabaseInstances`. Use `New-SprintSqlServerInstances` to create them. |
| `Get-InstalledDatabaseInformation` | [public/Get-InstalledDatabaseInformation.ps1](public/Get-InstalledDatabaseInformation.ps1) | Returns metadata about running database server processes (SQL Server, MySQL, PostgreSQL) on the local machine.                                                                                   |

### Database Build and Migration

| Cmdlet                         | File                                                                               | Synopsis                                                                                                                                                                                                                                                                              |
| ------------------------------ | ---------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Build-DatabaseWithFlyway`     | [public/Build-DatabaseWithFlyway.ps1](public/Build-DatabaseWithFlyway.ps1)         | Orchestrates a complete database build: drops and recreates the database via `DatabaseProvisioning`, then applies all Flyway migrations. Accepts `-SqlInstance` directly (e.g. `Devwhertzing`, `Expwhertzing`). Primary cmdlet for creating ATAPUtilities and AceCommander databases. |
| `DatabaseProvisioning`         | [public/DatabaseProvisioning.ps1](public/DatabaseProvisioning.ps1)                 | Creates (or recreates) a database and associated login/user objects by executing a sequence of SQL provisioning scripts. Called internally by `Build-DatabaseWithFlyway`.                                                                                                             |
| `Invoke-Flyway`                | [public/Invoke-Flyway.ps1](public/Invoke-Flyway.ps1)                               | Builds a JDBC connection string, exports Flyway placeholder environment variables (including SHA256 migration-file hashes), and invokes a Flyway command (`migrate`, `baseline`, `info`, etc.).                                                                                       |
| `DatabaseBuildAndMigrateTasks` | [public/DatabaseBuildAndMigrateTasks.ps1](public/DatabaseBuildAndMigrateTasks.ps1) | Collection of script-block tasks (Phil Factor / PubsAndFlyway pattern) that can be composed into a pipeline for version-aware database builds and Flyway integration.                                                                                                                 |

### Connection and Credentials

| Cmdlet                                    | File                                                                                                     | Synopsis                                                                                                                                                                                                                        |
| ----------------------------------------- | -------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `New-ConnectionStringBuilderFromDbaTools` | [public/New-ConnectionStringBuilderFromDbaTools.ps1](public/New-ConnectionStringBuilderFromDbaTools.ps1) | Wraps `New-DbaConnectionStringBuilder` with Bitwarden vault integration and JDBC output support. Supports `IntegratedSecurity` and `CredentialsFromVault` parameter sets.                                                       |
| `Get-DatabaseCredentialsKey`              | [public/Get-DatabaseCredentialsKey.ps1](public/Get-DatabaseCredentialsKey.ps1)                           | Constructs the canonical Bitwarden secret name for a database connection string given `DatabaseName`, `DatabaseHost`, and `Environment`. For per-sprint tiers (`Development`, `Experimental`) the key includes `$env:USERNAME`. |

### Backup

| Cmdlet                   | File                                                                   | Synopsis                                                                                                                                                                                                                  |
| ------------------------ | ---------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Invoke-SqlServerBackup` | [public/Invoke-SqlServerBackup.ps1](public/Invoke-SqlServerBackup.ps1) | Backs up a SQL Server database (`localhost\Production`) to `C:\Dropbox\Backups\utat022\<DatabaseName>\`. Supports Full and Differential backup types; uses dbatools. Intended to be called from Cobian Backup pre-events. |
| `New-CobianSqlJobs`      | [public/New-CobianSqlJobs.ps1](public/New-CobianSqlJobs.ps1)           | Creates four Cobian Reflector Dummy tasks (with pre-events) that invoke `Invoke-SqlServerBackup.ps1` for nightly ProGet and BuildMaster SQL backups. Writes directly to Cobian's `MainList.lst`.                          |
| `New-CobianAppJobs`      | [New-CobianAppJobs](public/New-CobianAppJobs.ps1)                      | Autoloaded function. Creates five Cobian Reflector file-copy tasks for backing up ProGet and BuildMaster application-data directories and the Cobian configuration itself.                                                |

### Rules and Utilities

| Cmdlet / Script          | File                                                                 | Synopsis                                                                                                                                                                 |
| ------------------------ | -------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `Export-RuleToTextFile`  | [public/Export-RuleToTextFile.ps1](public/Export-RuleToTextFile.ps1) | Retrieves a Rule by name from the ATAPUtilities database and exports all metadata (PhiloteID, purpose, language kind, composition, primitives) to a formatted text file. |
| `Example-RuleExport.ps1` | [public/Example-RuleExport.ps1](public/Example-RuleExport.ps1)       | Example script demonstrating `Export-RuleToTextFile` usage scenarios: single export, batch export, and error handling.                                                   |

---

## Obsolete Scripts

Scripts superseded by newer cmdlets; retained for reference.

| File                                                                                                                                 | Notes                                                                                                                                         |
| ------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------- |
| [public/Obsolete/afterVersioned\_\_ImportData.ps1](public/Obsolete/afterVersioned__ImportData.ps1)                                   | Legacy post-versioning data import                                                                                                            |
| [public/Obsolete/ATAPUtilities_Database_BackupDropAndRecreate.ps1](public/Obsolete/ATAPUtilities_Database_BackupDropAndRecreate.ps1) | Superseded by `Build-DatabaseWithFlyway` + `Invoke-SqlServerBackup`                                                                           |
| [public/Obsolete/ATAPUtilities_Database_BulkDataOut.ps1](public/Obsolete/ATAPUtilities_Database_BulkDataOut.ps1)                     | Legacy bulk-export script                                                                                                                     |
| [public/Obsolete/DataLoad.Tests.ps1](public/Obsolete/DataLoad.Tests.ps1)                                                             | Legacy Pester data-load tests                                                                                                                 |
| [public/Obsolete/Invoke-DatabaseRebuild.ps1](public/Obsolete/Invoke-DatabaseRebuild.ps1)                                             | Superseded by `Build-DatabaseWithFlyway`                                                                                                      |
| [public/Obsolete/New-DeveloperDatabaseInstances.ps1](public/Obsolete/New-DeveloperDatabaseInstances.ps1)                             | Superseded by `New-SprintSqlServerInstances` (BuildTooling module) — creates both instances and runs full Flyway migrations for all databases |

---

## Tests

| File                                                             | Purpose                                             |
| ---------------------------------------------------------------- | --------------------------------------------------- |
| [tests/PesterConfiguration.psd1](tests/PesterConfiguration.psd1) | Pester 5 configuration for this module's test suite |

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
