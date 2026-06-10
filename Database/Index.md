# Database — Index

This file lists all subfolders and key documents in the `Database/` folder of the ATAP.Utilities repository.

## Subfolders

- [ATAPUtilities/](ATAPUtilities/) — Versioning file (`version.json`) for the ATAPUtilities database NuGet promotion package. Nerdbank.GitVersioning reads this file to compute the package version.
- [Documentation/](Documentation/Index.md) — PlantUML diagrams and Markdown design documents for the database schema and package promotion pipeline. See [Documentation/Index.md](Documentation/Index.md) for the full contents list.
- [Flyway/](Flyway/) — Flyway project root. Contains `flyway.toml`, migration SQL scripts under `SQL/`, and seed data files under `Data/`.
- [Powershell/](Powershell/) — PowerShell cmdlets for database management operations (rebuild, backup, restore, provisioning). Public functions are in `Powershell/public/`.
- [Queries/](Queries/) — Ad-hoc and reference SQL query scripts for reporting and diagnostics against the ATAPUtilities schema.
- [StoredProcedures/](StoredProcedures/) — SQL scripts for stored procedures that are applied to the database after schema migrations.
- [Verify/](Verify/) — Smoke-test and acceptance-test SQL scripts run after Flyway migrations to verify schema correctness.

## Key Root Documents

- [Documentation/FolderStructure.md](Documentation/FolderStructure.md) — Annotated tree of the entire `Database/` folder structure.
- [Documentation/README.RRSBS.md](Documentation/README.RRSBS.md) — Overview of the Rules, Rule Sets, and Build Sets subsystem in the ATAPUtilities database.
- [Documentation/PROMOTION_SUMMARY.md](Documentation/PROMOTION_SUMMARY.md) — Executive summary of the database package promotion process.

## PowerShell Public Functions

| File                                                                                                                         | Purpose                                                                                                                                           |
| ---------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| [Powershell/public/Rebuild-All.ps1](Powershell/public/Rebuild-All.ps1)                                                       | Drops and recreates all configured databases (Experimental, Development) from scratch using Flyway.                                               |
| [Powershell/public/Rebuild-All-AllInstances.ps1](Powershell/public/Rebuild-All-AllInstances.ps1)                             | Runs Rebuild-All across every configured SQL instance (wrapper).                                                                                  |
| [Powershell/public/Export-ProductionDatabaseForSprintInit.ps1](Powershell/public/Export-ProductionDatabaseForSprintInit.ps1) | Full backup of the Production database and restore onto Integration and QA instances so each sprint starts from a known-good production baseline. |
