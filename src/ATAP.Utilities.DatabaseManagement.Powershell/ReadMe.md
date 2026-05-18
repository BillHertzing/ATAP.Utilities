# ATAP.Utilities.DatabaseManagement.Powershell

Flyway migration helpers, SQL Server lifecycle management, and rule-export utilities for the ATAP ecosystem.

## 5-Tier Module Flow

Use the module-level getting started guide for the lifecycle workflow:

- [Documentation/GettingStarted.md](Documentation/GettingStarted.md)

## Public Cmdlets

| Cmdlet                                    | Description                                                            |
| ----------------------------------------- | ---------------------------------------------------------------------- |
| `Build-DatabaseWithFlyway`                | Run Flyway migrations against a target database instance               |
| `DatabaseProvisioning`                    | Provision a new database instance                                      |
| `Export-RuleToTextFile`                   | Export a Rule from the ATAPUtilities database to a formatted text file |
| `Get-DatabaseCredentialsKey`              | Resolve the Bitwarden credentials key for a given database/tier/host   |
| `Get-InstalledDatabaseInformation`        | Return metadata about installed SQL Server instances                   |
| `Install-SqlServerInstance`               | Install and configure a SQL Server Express instance                    |
| `Invoke-Flyway`                           | Invoke a Flyway command against a configured database                  |
| `Invoke-FlywayRehearsal`                  | Run Flyway against a per-run ephemeral rehearsal database              |
| `Invoke-SqlServerBackup`                  | Back up a SQL Server database                                          |
| `New-CobianAppJobs`                       | Create Cobian Backup application jobs                                  |
| `New-CobianSqlJobs`                       | Create Cobian Backup SQL Server jobs                                   |
| `New-ConnectionStringBuilderFromDbaTools` | Build a connection string using dbaTools conventions                   |
| `New-DeveloperScratchDb`                  | Idempotently create a per-developer scratch database                   |
| `New-FeatureSharedDb`                     | Idempotently create a per-feature shared database                      |
| `Remove-DeveloperScratchDb`               | Drop disposable developer scratch or per-feature-sprint databases      |
| `Remove-FeatureSharedDb`                  | Drop disposable per-feature shared databases                           |
| `Resolve-DbInstanceName`                  | Resolve canonical Stream J database names                              |

### Example Scripts

- `public/Example-RuleExport.ps1` — demonstrates `Export-RuleToTextFile` usage
