# Database Access Rewrite Tasks

## Purpose

This document classifies every PowerShell file mentioned in `powershellscriptsaccessingdatabases.md` and breaks the required rewrite work into small tasks suitable for multiple junior developers working in parallel.

The rewrite target is every cmdlet or script function that actually connects to SQL Server, creates or removes databases, creates or removes SQL Server instances, backs up databases, runs Flyway against a database, or reads/writes database data.

Ancillary scripts that only create Bitwarden secrets, build names, discover setup files, generate configuration, or call another command without directly touching SQL Server are listed separately and should not be rewritten unless a parent task explicitly requires a call-site update.

## Required New Pattern

All rewritten database-access cmdlets must support the three connection methods documented in `powershellscriptsaccessingdatabases.md`:

1. An open `[Microsoft.Data.SqlClient.SqlConnection]` supplied directly as `-SqlConnection` or from pipeline input by property name.
2. A Bitwarden secret name supplied directly as `-BitwardenSecretName` or from pipeline input by property name. The secret value must resolve to a SQL Server connection string.
3. Existing connection-part parameters such as `DatabaseHost`, `DatabaseName`, `ConnectionMethod`, `CredentialsKey`, `ApplicationName`, and `InstanceName`, grouped into their own parameter set.

Use `Resolve-DatabaseSqlConnection` from `ATAP.Utilities.DatabaseManagement.Powershell` for Begin-block validation. Do not duplicate the validation logic in each cmdlet.

General implementation rules:

- Add the new parameter sets from the `SampleParameterBlock` section of `powershellscriptsaccessingdatabases.md`.
- Do not use parameter validation attributes for these connection inputs. Validate in `begin`.
- In `begin`, call `Resolve-DatabaseSqlConnection` and store the open connection in a local variable named `$resolvedSqlConnection` unless the file already has a clearer local naming convention.
- Give `SqlConnection` precedence when both pipeline properties and direct parameters make multiple connection choices visible.
- Use `DatabaseName 'master'` or run commands from `master` for database create/drop operations where the target database may not exist or may be about to be removed.
- Preserve existing user-facing parameters unrelated to connection creation.
- Preserve SupportsShouldProcess behavior and ConfirmImpact behavior.
- Add or update Pester tests with mocked connection resolution where possible. Do not require a live SQL Server in unit tests.

Important edge case:

Some scripts create a SQL Server instance that may not exist yet. Those scripts cannot validate an open connection to the target instance before creation. For those files, only apply the new resolver to operations that connect to an existing server or database. Keep setup credentials and instance creation inputs separate unless a senior developer approves a broader redesign.

## Classification Summary

### Direct Database Or Server Access - Rewrite Required

| File | Classification | Evidence | Rewrite priority |
| --- | --- | --- | --- |
| `src/ATAP.Utilities.DatabaseManagement.Powershell/public/New-DeveloperScratchDb.ps1` | Creates database | Uses `Invoke-Sqlcmd` and `CREATE DATABASE` | High |
| `src/ATAP.Utilities.DatabaseManagement.Powershell/public/New-FeatureSharedDb.ps1` | Creates database | Uses `Invoke-Sqlcmd` and `CREATE DATABASE` | High |
| `src/ATAP.Utilities.DatabaseManagement.Powershell/public/Remove-DeveloperScratchDb.ps1` | Removes database | Uses `Invoke-Sqlcmd` and `DROP DATABASE` | High |
| `src/ATAP.Utilities.DatabaseManagement.Powershell/public/Remove-FeatureSharedDb.ps1` | Removes database | Uses `Invoke-Sqlcmd` and `DROP DATABASE` | High |
| `src/ATAP.Utilities.DatabaseManagement.Powershell/public/DatabaseProvisioning.ps1` | Creates/removes/provisions database | Opens SQL connections, calls `Invoke-Sqlcmd`, runs provisioning scripts | High |
| `src/ATAP.Utilities.DatabaseManagement.Powershell/public/Build-DatabaseWithFlyway.ps1` | Builds/migrates database | Opens SQL connections, calls provisioning and Flyway helpers | High |
| `src/ATAP.Utilities.DatabaseManagement.Powershell/public/Invoke-Flyway.ps1` | Runs database migrations | Builds connection strings and invokes Flyway against SQL Server | High |
| `src/ATAP.Utilities.DatabaseManagement.Powershell/public/Invoke-FlywayRehearsal.ps1` | Creates/removes rehearsal database and runs Flyway | Uses `Invoke-Sqlcmd`, `CREATE DATABASE`, `DROP DATABASE`, and `Invoke-Flyway` | High |
| `src/ATAP.Utilities.DatabaseManagement.Powershell/public/Invoke-SqlServerBackup.ps1` | Backs up database | Calls `Backup-DbaDatabase` | Medium |
| `src/ATAP.Utilities.DatabaseManagement.Powershell/public/Export-RuleToTextFile.ps1` | Reads database data | Calls `Invoke-DbaQuery` | Medium |
| `src/ATAP.Utilities.DatabaseManagement.Powershell/public/DatabaseBuildAndMigrateTasks.ps1` | Legacy task runner with SQL access | Uses `sqlcmd` and Flyway task scriptblocks | Medium, special handling |
| `src/ATAP.Utilities.BuildTooling.PowerShell/public/Initialize-ProGetSqlServiceLogin.ps1` | Creates login/user and grants database role | Calls `Invoke-Sqlcmd` | Medium |
| `src/ATAP.Utilities.BuildTooling.PowerShell/public/Read-SourceAndCreateRules.ps1` | Writes rule data to database when DB output is enabled | Calls `Invoke-DbaQuery` | Medium |
| `src/ATAP.Utilities.BuildTooling.PowerShell/public/Sync-RulesToCSV.ps1` | Reads rule data from database | Calls `Invoke-DbaQuery` repeatedly | Medium |
| `src/ATAP.Utilities.BuildTooling.PowerShell/public/New-SprintSqlServerInstances.ps1` | Orchestrates SQL instance creation and database build | Calls `Install-SqlServerInstance`, `Get-DbaDatabase`, and `Build-DatabaseWithFlyway` | Medium, after leaf cmdlets |
| `src/ATAP.Utilities.BuildTooling.PowerShell/public/Remove-SprintSqlServerInstances.ps1` | Removes databases and SQL instances | Calls `Connect-DbaInstance`, `Get-DbaDatabase`, `Remove-DbaDatabase`, then setup uninstall | Medium, server-lifecycle edge case |
| `src/ATAP.Utilities.BuildTooling.PowerShell/private/New-SprintDatabaseInstances.ps1` | Private orchestration wrapper | Calls sprint SQL instance/database build helpers | Low, after public orchestration |
| `src/ATAP.Utilities.DatabaseManagement.Powershell/public/Install-SqlServerInstance.ps1` | Creates SQL Server instance | Calls `Install-DbaInstance`; fetches setup credentials | Special handling |

### Obsolete Or Legacy Direct Access - Defer Unless Reactivated

These files directly access databases or SQL Server, but they live under `public/Obsolete` or legacy `Database/Powershell/public`. Do not rewrite them in the first pass unless the owning developer confirms they are still supported entry points.

| File | Classification | Evidence | Recommended action |
| --- | --- | --- | --- |
| `src/ATAP.Utilities.DatabaseManagement.Powershell/public/Obsolete/Remove-DeveloperDatabaseInstances.ps1` | Legacy database removal | Calls `Remove-DbaDatabase` | Defer |
| `src/ATAP.Utilities.DatabaseManagement.Powershell/public/Obsolete/New-DeveloperDatabaseInstances.ps1` | Legacy database/instance orchestration | Calls `Install-SqlServerInstance` and `Build-DatabaseWithFlyway` | Defer |
| `src/ATAP.Utilities.DatabaseManagement.Powershell/public/Obsolete/Invoke-DatabaseRebuild.ps1` | Legacy Flyway rebuild orchestration | Calls `Build-DatabaseWithFlyway` | Defer |
| `src/ATAP.Utilities.DatabaseManagement.Powershell/public/Obsolete/ATAPUtilities_Database_BulkDataOut.ps1` | Legacy data export | Calls `bcp` | Defer |
| `src/ATAP.Utilities.DatabaseManagement.Powershell/public/Obsolete/ATAPUtilities_Database_BackupDropAndRecreate.ps1` | Legacy backup/drop/recreate | Calls dbatools and `bcp` | Defer |
| `src/ATAP.Utilities.DatabaseManagement.Powershell/public/Obsolete/afterVersioned__ImportData.ps1` | Legacy data import | Calls `bcp` and `sqlcmd` | Defer |
| `src/ATAP.Utilities.DatabaseManagement/Database/Powershell/public/Rebuild-All.ps1` | Legacy rebuild orchestration | Fetches secrets and calls `Build-DatabaseWithFlyway` | Defer |
| `src/ATAP.Utilities.DatabaseManagement/Database/Powershell/public/Rebuild-All-AllInstances.ps1` | Legacy multi-instance rebuild orchestration | Fetches secrets and calls `Build-DatabaseWithFlyway` | Defer |

### Ancillary Or Helper Files - No Rewrite Required

| File | Classification | Reason |
| --- | --- | --- |
| `src/ATAP.Utilities.DatabaseManagement.Powershell/public/Resolve-DbInstanceName.ps1` | Name helper | Resolves instance names only |
| `src/ATAP.Utilities.DatabaseManagement.Powershell/public/Resolve-DatabaseSqlConnection.ps1` | New resolver | This is the shared validation implementation |
| `src/ATAP.Utilities.DatabaseManagement.Powershell/public/New-ConnectionStringBuilderFromDbaTools.ps1` | Connection string helper | Builds connection string builders and retrieves secrets, but does not open SQL connections |
| `src/ATAP.Utilities.DatabaseManagement.Powershell/public/New-CobianSqlJobs.ps1` | Job config helper | Creates Cobian backup jobs, but does not connect to SQL Server itself |
| `src/ATAP.Utilities.DatabaseManagement.Powershell/public/Get-DatabaseCredentialsKey.ps1` | Secret-name helper | Computes/fetches credential key names |
| `src/ATAP.Utilities.DatabaseManagement.Powershell/public/Example-RuleExport.ps1` | Example wrapper | Demonstrates export usage; refresh only if examples are updated |
| `src/ATAP.Utilities.BuildTooling.PowerShell/public/New-OverviewSprintWorkspace.ps1` | Workspace helper | No SQL Server access |
| `src/ATAP.Utilities.BuildTooling.PowerShell/public/New-SprintBitwardenSecrets.ps1` | Bitwarden helper | Creates secrets only |
| `src/ATAP.Utilities.BuildTooling.PowerShell/public/New-SprintStage2.ps1` | Orchestrator | Calls child helpers; no direct SQL call in this file |
| `src/ATAP.Utilities.BuildTooling.PowerShell/public/Remove-SprintBitwardenSecrets.ps1` | Bitwarden helper | Removes secrets only |
| `src/ATAP.Utilities.BuildTooling.PowerShell/public/Set-BuildMasterStableVariables.ps1` | BuildMaster helper | No SQL Server access |
| `src/ATAP.Utilities.BuildTooling.PowerShell/public/New-PermanentBitwardenSecrets.ps1` | Bitwarden helper | Creates secrets only |
| `src/ATAP.Utilities.BuildTooling.PowerShell/private/New-SprintBitwardenConnectionStrings.ps1` | Bitwarden helper | Creates connection-string secrets only |
| `src/ATAP.Utilities.BuildTooling.PowerShell/private/Find-SqlServerSetupExe.ps1` | File discovery helper | Finds setup executable only |

## Swarm Task List

Each task below is intended for one junior developer. Developers should not edit files outside their assigned task unless the task explicitly says to update a caller or test file.

### Task 0 - Shared Preparation

Owner: first developer to start the swarm.

Files:

- `src/ATAP.Utilities.DatabaseManagement.Powershell/public/Resolve-DatabaseSqlConnection.ps1`
- `src/ATAP.Utilities.DatabaseManagement.Powershell/private/DatabaseSqlConnection.Helpers.ps1`
- `_Planning-wt-14-Sprint-0007-work-items/powershellscriptsaccessingdatabases.md`

Steps:

1. Read the `SampleParameterBlock` and `SampleBeginBlockValidation` sections.
2. Confirm `Resolve-DatabaseSqlConnection` is exported by `ATAP.Utilities.DatabaseManagement.Powershell.psd1`.
3. Run or inspect the existing unit tests for `Resolve-DatabaseSqlConnection`.
4. Publish a short note to the swarm with the exact parameter-set names to use.

Acceptance criteria:

- Everyone uses the same parameter names and parameter-set names.
- No per-cmdlet copy of Bitwarden or connection-string validation is introduced.

### Task 1 - Simple Create Database Cmdlets

Files:

- `src/ATAP.Utilities.DatabaseManagement.Powershell/public/New-DeveloperScratchDb.ps1`
- `src/ATAP.Utilities.DatabaseManagement.Powershell/public/New-FeatureSharedDb.ps1`

Goal:

Rewrite both create-database cmdlets to use the new connection parameter sets and `Resolve-DatabaseSqlConnection`.

Steps:

1. Add the new `SqlConnection`, `BitwardenSecretName`, and connection-part parameter sets.
2. Keep target database naming parameters unchanged.
3. In `begin`, resolve an open SQL connection. Use `master` as the connection database because the target database may not exist yet.
4. Replace direct `Invoke-Sqlcmd` usage with commands executed through `$resolvedSqlConnection.CreateCommand()` where practical.
5. Ensure all `CREATE DATABASE` statements are protected by existing `ShouldProcess` behavior.
6. Add unit tests that mock `Resolve-DatabaseSqlConnection` and verify the cmdlets choose the expected target database names.

Acceptance criteria:

- Both cmdlets accept all three connection methods.
- Passing `-SqlConnection` does not attempt to call Bitwarden or `Get-PVal`.
- Create operations still honor `-WhatIf`.
- Tests do not require a live SQL Server.

### Task 2 - Simple Remove Database Cmdlets

Files:

- `src/ATAP.Utilities.DatabaseManagement.Powershell/public/Remove-DeveloperScratchDb.ps1`
- `src/ATAP.Utilities.DatabaseManagement.Powershell/public/Remove-FeatureSharedDb.ps1`

Goal:

Rewrite both remove-database cmdlets to use the new connection parameter sets and `Resolve-DatabaseSqlConnection`.

Steps:

1. Add the new parameter sets.
2. Keep filtering, naming, and confirmation parameters unchanged.
3. Resolve the SQL connection in `begin`. Use `master` as the connection database.
4. Replace `Invoke-Sqlcmd` database-existence queries and `DROP DATABASE` calls with commands executed on `$resolvedSqlConnection`.
5. Preserve any logic that handles active connections, retry behavior, or confirmation prompts.
6. Add unit tests for exact-name removal, pattern/list behavior if present, and `-WhatIf`.

Acceptance criteria:

- Both cmdlets support the three connection methods.
- Drop operations run from `master`.
- Existing safety behavior is preserved.
- Tests mock SQL command execution.

### Task 3 - DatabaseProvisioning

File:

- `src/ATAP.Utilities.DatabaseManagement.Powershell/public/DatabaseProvisioning.ps1`

Goal:

Replace the existing custom connection-selection and validation logic with `Resolve-DatabaseSqlConnection`.

Steps:

1. Compare the current parameter sets to `SampleParameterBlock`.
2. Remove duplicated Begin-block logic that manually opens SQL connections or resolves Bitwarden secrets.
3. Call `Resolve-DatabaseSqlConnection` once in `begin`.
4. Use the resolved connection for database existence checks, create/drop statements, and provisioning commands.
5. Keep the existing provisioning script discovery and execution behavior unchanged.
6. Add tests for each parameter set and for create/drop/provisioning control flow with mocked SQL execution.

Acceptance criteria:

- The file no longer has its own Bitwarden validation path.
- The file no longer calls `.Open()` directly except through the shared resolver.
- Existing create/drop/provisioning options continue to behave the same.

### Task 4 - Build-DatabaseWithFlyway

File:

- `src/ATAP.Utilities.DatabaseManagement.Powershell/public/Build-DatabaseWithFlyway.ps1`

Goal:

Use the shared connection validation flow while preserving the existing build and migration workflow.

Steps:

1. Add or normalize the three connection parameter sets.
2. Resolve the SQL connection in `begin`.
3. Pass the resolved connection or normalized connection details to `DatabaseProvisioning` and `Invoke-Flyway`.
4. Do not rebuild connection strings independently if the shared resolver already validated the inputs.
5. Preserve the order of provisioning, migration, repeatable migration, and optional data operations.
6. Add tests that verify child calls receive the expected connection option.

Acceptance criteria:

- The cmdlet validates connection input through `Resolve-DatabaseSqlConnection`.
- The cmdlet does not perform duplicate Get-PVal or Bitwarden validation.
- Existing Flyway and provisioning switches still route to the same child operations.

### Task 5 - Invoke-Flyway

File:

- `src/ATAP.Utilities.DatabaseManagement.Powershell/public/Invoke-Flyway.ps1`

Goal:

Use the new connection parameter sets while still producing the JDBC URL that Flyway requires.

Steps:

1. Add or normalize the three connection parameter sets.
2. Resolve the SQL connection in `begin`.
3. Derive the Flyway JDBC URL from the validated connection details. Keep using the established connection-string builder helper when it is the safest way to produce a JDBC URL.
4. Ensure `SqlConnection` and `BitwardenSecretName` inputs do not require users to also pass `DatabaseHost` or `CredentialsKey`.
5. Preserve all Flyway command, location, target, baseline, clean, and output behavior.
6. Add tests that mock `Resolve-DatabaseSqlConnection` and verify `FLYWAY_URL` construction for all three connection methods.

Acceptance criteria:

- Flyway receives a valid JDBC URL for each connection method.
- The cmdlet does not silently fall back to connection-part parameters when `SqlConnection` is present.
- The old Flyway arguments and environment behavior remain intact.

### Task 6 - Invoke-FlywayRehearsal

File:

- `src/ATAP.Utilities.DatabaseManagement.Powershell/public/Invoke-FlywayRehearsal.ps1`

Goal:

Rewrite rehearsal database creation/removal and child `Invoke-Flyway` calls to use the shared connection pattern.

Steps:

1. Add the three connection parameter sets.
2. Resolve an open connection to `master` in `begin`.
3. Use the resolved connection for rehearsal `DROP DATABASE` and `CREATE DATABASE` statements.
4. Pass the same connection method through to `Invoke-Flyway` for migration validation.
5. Keep rehearsal database naming, cleanup, and failure behavior unchanged.
6. Add tests for rehearsal database creation, cleanup after success, and cleanup after failure.

Acceptance criteria:

- Rehearsal setup and teardown use the shared resolver.
- The child `Invoke-Flyway` call receives a coherent connection method.
- Cleanup behavior is unchanged.

### Task 7 - Rule Export And CSV Sync

Files:

- `src/ATAP.Utilities.DatabaseManagement.Powershell/public/Export-RuleToTextFile.ps1`
- `src/ATAP.Utilities.BuildTooling.PowerShell/public/Sync-RulesToCSV.ps1`

Goal:

Rewrite read-only rule data access to use the new connection parameter sets.

Steps:

1. Add the three connection parameter sets to both functions.
2. Resolve the SQL connection in `begin`.
3. Replace `Invoke-DbaQuery` calls with ADO.NET command execution against `$resolvedSqlConnection`, or use a shared private helper if one already exists.
4. Preserve existing output file formats, CSV column names, sort order, and error handling.
5. Add tests that mock returned rows and verify generated file content.

Acceptance criteria:

- Both functions can read data using `SqlConnection`, `BitwardenSecretName`, or connection parts.
- No live database is required in unit tests.
- File output remains byte-for-byte compatible where deterministic.

### Task 8 - Rule Import / Create

File:

- `src/ATAP.Utilities.BuildTooling.PowerShell/public/Read-SourceAndCreateRules.ps1`

Goal:

Rewrite optional database writes to use the new connection parameter sets.

Steps:

1. Add the three connection parameter sets.
2. Preserve modes that only read source files and do not write to the database.
3. Resolve the SQL connection only when database output is requested, unless the function semantics require early validation.
4. Replace `Invoke-DbaQuery` writes with parameterized ADO.NET commands where practical.
5. Keep file parsing, rule shaping, and non-database output behavior unchanged.
6. Add tests for no-database mode and database-write mode with mocked commands.

Acceptance criteria:

- Non-database workflows do not require connection parameters.
- Database-write workflows accept all three connection methods.
- SQL writes are parameterized or preserve equivalent escaping behavior.

### Task 9 - Backup And ProGet Login

Files:

- `src/ATAP.Utilities.DatabaseManagement.Powershell/public/Invoke-SqlServerBackup.ps1`
- `src/ATAP.Utilities.BuildTooling.PowerShell/public/Initialize-ProGetSqlServiceLogin.ps1`

Goal:

Rewrite administrative database operations to use the shared connection resolver.

Steps:

1. Add the three connection parameter sets to both functions.
2. Resolve the SQL connection in `begin`.
3. For backup, derive the SQL Server instance and database name from `$resolvedSqlConnection` when the caller used `SqlConnection` or `BitwardenSecretName`.
4. Keep `Backup-DbaDatabase` behavior unless replacing it with native SQL backup is explicitly approved.
5. For ProGet login setup, execute login/user/role commands through the resolved connection.
6. Add tests for each parameter set and for command text generation.

Acceptance criteria:

- Backup and login setup accept all three connection methods.
- Existing backup file naming and retention behavior is preserved.
- ProGet login setup remains idempotent.

### Task 10 - Sprint SQL Orchestration

Files:

- `src/ATAP.Utilities.BuildTooling.PowerShell/public/New-SprintSqlServerInstances.ps1`
- `src/ATAP.Utilities.BuildTooling.PowerShell/public/Remove-SprintSqlServerInstances.ps1`
- `src/ATAP.Utilities.BuildTooling.PowerShell/private/New-SprintDatabaseInstances.ps1`

Goal:

Update orchestration scripts after the leaf database cmdlets have been rewritten.

Steps:

1. Wait for Tasks 1 through 6 to complete before changing these files.
2. Identify every child call that now accepts `SqlConnection`, `BitwardenSecretName`, or connection parts.
3. Pass connection options through to child cmdlets instead of rebuilding connection strings locally.
4. For `Remove-SprintSqlServerInstances`, keep server-instance uninstall logic separate from database connection validation.
5. For `New-SprintSqlServerInstances`, do not require an open connection to an instance that is about to be created.
6. Add integration-style unit tests with all child commands mocked.

Acceptance criteria:

- Orchestration files do not duplicate resolver logic.
- Existing instance creation/removal behavior is preserved.
- Existing Bitwarden secret creation scripts remain untouched unless a call signature must be updated.

### Task 11 - Install-SqlServerInstance Special Handling

File:

- `src/ATAP.Utilities.DatabaseManagement.Powershell/public/Install-SqlServerInstance.ps1`

Goal:

Document and implement only the connection-related changes that make sense for an instance creation command.

Steps:

1. Confirm whether this function ever connects to an already-existing SQL Server before calling `Install-DbaInstance`.
2. If it only installs a new instance, do not require `Resolve-DatabaseSqlConnection` for the target instance.
3. Keep setup credentials and SQL service credentials in their existing parameter model unless a senior developer approves a separate credential resolver.
4. If the function checks an existing host or existing instance, use the shared resolver only for that check.
5. Add a comment explaining why a new-instance operation cannot validate an open connection to the not-yet-created instance.

Acceptance criteria:

- The function is not forced into an impossible "open connection before install" flow.
- Any existing-instance checks use shared validation if they connect to SQL Server.
- Credential and setup behavior remains unchanged.

### Task 12 - DatabaseBuildAndMigrateTasks Special Handling

File:

- `src/ATAP.Utilities.DatabaseManagement.Powershell/public/DatabaseBuildAndMigrateTasks.ps1`

Goal:

Assess and isolate legacy task-runner SQL access before rewriting.

Steps:

1. Inventory each `sqlcmd` invocation and identify the task scriptblock that owns it.
2. Determine whether each SQL operation has a modern public cmdlet replacement after Tasks 1 through 6.
3. Replace direct `sqlcmd` calls with calls to rewritten public cmdlets where possible.
4. If a direct SQL task remains necessary, add the three connection parameter sets to the owning function and call `Resolve-DatabaseSqlConnection`.
5. Add tests around task selection and command dispatch, not live database execution.

Acceptance criteria:

- No direct `sqlcmd` call remains unless it is documented as intentionally retained.
- Retained direct SQL calls use the shared resolver.
- Existing task names and task ordering remain stable.

### Task 13 - Obsolete And Legacy Scripts

Files:

- All files listed in "Obsolete Or Legacy Direct Access - Defer Unless Reactivated".

Goal:

Prevent accidental rewrite churn in obsolete scripts while leaving a clear migration path.

Steps:

1. Do not rewrite these files in the first pass.
2. Add a short planning note or tracking issue for each script that is still invoked by current automation.
3. If any obsolete script is still a supported entry point, move it out of `Obsolete` or explicitly assign it to a new rewrite task.

Acceptance criteria:

- No obsolete script is silently changed as part of unrelated work.
- Any still-supported legacy entry point has an owner and a migration task.

### Task 14 - Final Verification

Owner: one developer after all rewrite tasks merge.

Files:

- `src/ATAP.Utilities.DatabaseManagement.Powershell/public/*.ps1`
- `src/ATAP.Utilities.BuildTooling.PowerShell/public/*.ps1`
- `src/ATAP.Utilities.BuildTooling.PowerShell/private/*.ps1`
- Relevant tests under both modules

Steps:

1. Search for remaining direct database calls: `Invoke-Sqlcmd`, `Invoke-DbaQuery`, `Connect-DbaInstance`, `Get-DbaDatabase`, `Remove-DbaDatabase`, `Backup-DbaDatabase`, `sqlcmd`, `bcp`, and `.Open()`.
2. For each hit, confirm it is either using `Resolve-DatabaseSqlConnection`, intentionally server-lifecycle-only, obsolete/deferred, or ancillary.
3. Run all affected Pester tests.
4. Run `Import-Module` for affected modules and confirm exported commands load.
5. Update `powershellscriptsaccessingdatabases.md` if the final parameter-set names or resolver usage changed.

Acceptance criteria:

- Every supported direct database-access cmdlet accepts all three connection methods.
- The shared resolver is the only validation path for SQL connection inputs.
- Ancillary Bitwarden and setup-helper scripts remain focused on their original responsibilities.

## Suggested Parallel Batches

Batch 1 can run immediately:

- Task 1 - Simple Create Database Cmdlets
- Task 2 - Simple Remove Database Cmdlets
- Task 3 - DatabaseProvisioning
- Task 5 - Invoke-Flyway
- Task 7 - Rule Export And CSV Sync
- Task 8 - Rule Import / Create
- Task 9 - Backup And ProGet Login

Batch 2 should wait for related leaf work:

- Task 4 - Build-DatabaseWithFlyway, after Tasks 3 and 5
- Task 6 - Invoke-FlywayRehearsal, after Task 5
- Task 10 - Sprint SQL Orchestration, after Tasks 1 through 6
- Task 12 - DatabaseBuildAndMigrateTasks, after Tasks 1 through 6

Batch 3 is cleanup and governance:

- Task 11 - Install-SqlServerInstance Special Handling
- Task 13 - Obsolete And Legacy Scripts
- Task 14 - Final Verification

## Do Not Rewrite In This Pass

These files were mentioned in the source planning document but do not directly open SQL Server connections or access database data:

- `src/ATAP.Utilities.DatabaseManagement.Powershell/public/Resolve-DbInstanceName.ps1`
- `src/ATAP.Utilities.DatabaseManagement.Powershell/public/Resolve-DatabaseSqlConnection.ps1`
- `src/ATAP.Utilities.DatabaseManagement.Powershell/public/New-ConnectionStringBuilderFromDbaTools.ps1`
- `src/ATAP.Utilities.DatabaseManagement.Powershell/public/New-CobianSqlJobs.ps1`
- `src/ATAP.Utilities.DatabaseManagement.Powershell/public/Get-DatabaseCredentialsKey.ps1`
- `src/ATAP.Utilities.DatabaseManagement.Powershell/public/Example-RuleExport.ps1`
- `src/ATAP.Utilities.BuildTooling.PowerShell/public/New-OverviewSprintWorkspace.ps1`
- `src/ATAP.Utilities.BuildTooling.PowerShell/public/New-SprintBitwardenSecrets.ps1`
- `src/ATAP.Utilities.BuildTooling.PowerShell/public/New-SprintStage2.ps1`
- `src/ATAP.Utilities.BuildTooling.PowerShell/public/Remove-SprintBitwardenSecrets.ps1`
- `src/ATAP.Utilities.BuildTooling.PowerShell/public/Set-BuildMasterStableVariables.ps1`
- `src/ATAP.Utilities.BuildTooling.PowerShell/public/New-PermanentBitwardenSecrets.ps1`
- `src/ATAP.Utilities.BuildTooling.PowerShell/private/New-SprintBitwardenConnectionStrings.ps1`
- `src/ATAP.Utilities.BuildTooling.PowerShell/private/Find-SqlServerSetupExe.ps1`

## Implementation Status

Implemented in this pass:

- Added shared ADO.NET SQL command helpers for the DatabaseManagement module.
- Added BuildTooling SQL helpers that delegate connection validation to `Resolve-DatabaseSqlConnection`.
- Converted supported create/remove database cmdlets, Flyway rehearsal, rule import/export/sync, ProGet login setup, database provisioning, Flyway invocation, database build orchestration, SQL backup, and sprint orchestration call sites to the shared connection pattern where applicable.
- Added or updated unit tests for the changed supported entry points that can be tested without a live SQL Server.

Intentional exceptions:

- `Install-SqlServerInstance.ps1` remains an instance-creation command and does not require an open connection to the not-yet-created target instance.
- `DatabaseBuildAndMigrateTasks.ps1` remains a legacy Flyway task-script collection with direct `sqlcmd`/`bcp` calls documented at the top of the file. It should be replaced task-by-task with modern public cmdlets before any deeper rewrite.
- `Invoke-SqlServerBackup.ps1` still calls `Backup-DbaDatabase` after validating connection input through `Resolve-DatabaseSqlConnection`, because the task explicitly preserved dbatools backup behavior.
- Sprint instance orchestration still uses dbatools for multi-instance discovery/removal because a single open `SqlConnection` does not model creating/removing several SQL Server instances.
