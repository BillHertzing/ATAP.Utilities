# Legacy DatabaseBuildAndMigrateTasks support boundary

This document closes the support-boundary story for the legacy Redgate / Phil Factor
`PubsAndFlyway` task-script collection that was previously distributed as
`public/DatabaseBuildAndMigrateTasks.ps1` in this module. The file now lives under
`public/Obsolete/DatabaseBuildAndMigrateTasks.ps1` and is no longer exported by
the module manifest.

The authoritative analysis of every legacy capability, its coverage status, and
its replacement priority is in the planning worktree:

- [Plan-DatabaseBuildAndMigrateTasksReplacement.md](../../../../_Planning-wt-14-Sprint-0007-work-items/Plan-DatabaseBuildAndMigrateTasksReplacement.md)

That plan document is the source of truth. This file is a stable in-repo summary
intended for users who reach the module through `INDEX.md`.

---

## Support boundary

The legacy `DatabaseBuildAndMigrateTasks.ps1` script bundle and its
`Process-FlywayTasks` scriptblock orchestrator are not supported; only the
capabilities listed in the "Supported today" table below are part of the
module's supported surface.

---

## Rationale

`DatabaseBuildAndMigrateTasks.ps1` is not on the critical path for the modern
ATAP.Utilities database build and migrate flow
(`New-SprintSqlServerInstances` -> `Build-DatabaseWithFlyway` ->
`DatabaseProvisioning` -> `Invoke-Flyway`). It is a historical bundle of
build-artifact, drift-detection, reporting, and BCP utilities written around the
Redgate `PubsAndFlyway` task pattern. Several of its capabilities are still
useful in principle, but they were never integrated into the supported pipeline
and they carry assumptions (local encrypted-XML secret stores, SQL Compare and
SQL Code Guard tooling on the host, mutable shared-state scriptblock pipelines)
that conflict with the current Bitwarden-and-Flyway-CLI model. This document
records which capabilities are already covered, which are formally deferred to
future sprint work, and which will not be rebuilt.

---

## Supported today

Capabilities already covered by current cmdlets in this module or its sibling
modules. Use the listed cmdlet; do not reactivate the legacy task.

| Legacy capability                                              | Current cmdlet                                                                 |
| -------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| Build Flyway CLI arguments (`$FormatTheBasicFlywayParameters`) | [Invoke-Flyway](../public/Invoke-Flyway.ps1)                                   |
| Run Flyway CLI commands and placeholders                       | [Invoke-Flyway](../public/Invoke-Flyway.ps1)                                   |
| Drop and recreate database, login, user, schema-history table  | [DatabaseProvisioning](../public/DatabaseProvisioning.ps1)                     |
| End-to-end database build + Flyway migrate                     | [Build-DatabaseWithFlyway](../public/Build-DatabaseWithFlyway.ps1)             |
| Ephemeral rehearsal migrate-and-drop cycle                     | [Invoke-FlywayRehearsal](../public/Invoke-FlywayRehearsal.ps1)                 |
| Resolve connection (existing / Bitwarden / parts)              | [Resolve-DatabaseSqlConnection](../public/Resolve-DatabaseSqlConnection.ps1)   |
| Save and load project connection parameter sets                | `$global:settings` + Bitwarden vault (see ConfigRootKeys-and-HostSettings.md) |
| Provision Dev/Exp SQL instances and all sprint databases       | `New-SprintSqlServerInstances` (BuildTooling module)                           |

---

## Deferred

Capabilities that have a named replacement function planned but not yet
authored. Priorities P1-P4 are taken from the plan document; P1 is highest.

| Legacy capability                                                                       | Planned replacement                  | Priority |
| --------------------------------------------------------------------------------------- | ------------------------------------ | -------- |
| Query `flyway_schema_history` for current applied version (`$GetCurrentVersion`)        | `Get-FlywaySchemaVersion`            | P1       |
| Run SQL Code Guard against live database code (`$CheckCodeInDatabase`)                  | `Invoke-DatabaseCodeAnalysis`        | P2       |
| Run SQL Code Guard against `V*.sql` migration files (`$CheckCodeInMigrationFiles`)      | `Invoke-FlywayMigrationCodeAnalysis` | P2       |
| Generate object-level source folders via SQL Compare (`$CreateScriptFoldersIfNecessary`) | `Export-DatabaseObjectScripts`       | P2       |
| Generate full versioned build script via SQL Compare (`$CreateBuildScriptIfNecessary`)  | `Export-DatabaseBuildScript`         | P2       |
| Detect drift between database and object-level source (`$IsDatabaseIdenticalToSource`)  | `Test-DatabaseDriftAgainstSource`    | P2       |
| Generate first-cut undo script via SQL Compare (`$CreateUndoScriptIfNecessary`)         | `New-FlywayUndoScript`               | P3       |
| Table design-smell report (`$ExecuteTableSmellReport`)                                  | `Invoke-DatabaseTableSmellReport`    | P3       |
| Table / column documentation export (`$ExecuteTableDocumentationReport`)                | `Export-DatabaseTableDocumentation`  | P3       |
| JSON database model export (`$SaveDatabaseModelIfNecessary`)                            | `Export-DatabaseModel`               | P3       |
| Generic BCP export of all user tables (`$BulkCopyOut`)                                  | `Export-DatabaseTableDataBcp`        | P3       |
| Generic BCP import from versioned data folder (`$BulkCopyIn`)                           | `Import-DatabaseTableDataBcp`        | P3       |

---

## Retired

Capabilities that will NOT be rebuilt. The reasons are listed inline; if a
strong new requirement emerges, follow the reactivation procedure below.

| Legacy capability                                                                                 | Reason for retirement                                                                                                                                                  |
| ------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Prompt for password and persist to local encrypted XML (`$FetchAnyRequiredPasswords`)             | Conflicts with the canonical Bitwarden secret-vault model. Use `Get-BitWardenSecret` and `Resolve-DatabaseSqlConnection` instead.                                       |
| Run SQL through `sqlcmd` and parse JSON output (`$GetdataFromSQLCMD`)                             | Generic ad-hoc query runner with no consumer in the supported flow. Use ADO.NET (`Microsoft.Data.SqlClient`) or `Invoke-DbaQuery` directly when a real need arises.    |
| Scriptblock-based task list orchestrator (`Process-FlywayTasks`)                                  | Mutable shared-state scriptblock pipeline is incompatible with normal cmdlet composition and `-WhatIf` / `-Confirm`. Compose normal cmdlets instead of restoring it.   |
| `DatabaseBuildAndMigrateTasks` as a manifest-exported function                                    | The file never defined a function of that name; it was a phantom manifest export. Removed from `FunctionsToExport` and will not return.                                |

---

## How to request reactivation

If a deferred capability is needed in a future sprint, or a retired capability
must be reconsidered:

1. Open a new sprint backlog item in the standard `_Planning` issue / TASKS
   flow naming the capability and citing the row in the relevant table above.
2. Reference the
   [Plan-DatabaseBuildAndMigrateTasksReplacement.md](../../../../_Planning-wt-14-Sprint-0007-work-items/Plan-DatabaseBuildAndMigrateTasksReplacement.md)
   document, which carries the full grammar of each legacy task and the
   recommended cmdlet shape for the replacement.
3. The replacement must be authored as a normal public cmdlet in
   `src/ATAP.Utilities.DatabaseManagement.Powershell/public/` following the
   PowerShell rules (advanced function with `BEGIN` / `PROCESS` / `END`,
   `Write-PSFMessage` logging, `-WhatIf` / `-Confirm` support). Do not
   reactivate the legacy `.ps1` bundle in place.

The `public/Obsolete/DatabaseBuildAndMigrateTasks.ps1` file is retained as a
read-only reference for grammar reconstruction only. Deletion of the file is a
separate decision tracked in the plan document and is not part of this
support-boundary closure.
