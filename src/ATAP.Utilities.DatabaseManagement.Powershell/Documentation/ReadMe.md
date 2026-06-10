# ATAP.Utilities.DatabaseManagement.PowerShell — Documentation

This folder is the **deep reference** for the database-pipeline cmdlets in
the `ATAP.Utilities.DatabaseManagement.PowerShell` module. The module
root [`../ReadMe.md`](../ReadMe.md) and [`../INDEX.md`](../INDEX.md) are
the canonical entry points and authoritative list of cmdlets; this folder
holds the longer-form deep-reference material that does not belong in the
module-root pages.

## Contents

- [INDEX.md](INDEX.md) — Per-cmdlet deep references for the database
  pipeline cmdlets (description, required environment variables,
  Bitwarden secret names, example invocation).
- [Database Design.md](Database%20Design.md) — High-level design notes
  for the ATAPUtilities database schema and the migration lifecycle.
- [GettingStarted.md](GettingStarted.md) — Module quick-start for the
  5-tier database-pipeline flow.
- [Legacy-DatabaseBuildAndMigrateTasks-Support-Boundary.md](Legacy-DatabaseBuildAndMigrateTasks-Support-Boundary.md)
  — Support-boundary record for the legacy Redgate / Phil Factor
  `DatabaseBuildAndMigrateTasks.ps1` scripts: which legacy capabilities
  are supported by current cmdlets, which are deferred, which are
  retired, and the reactivation procedure.

## Required environment variables

The database pipeline cmdlets resolve secrets and base URLs from
User-scope environment variables and the `$global:settings` two-tier
configuration system. The cmdlets in this module use the following
variable names (values are never stored in this folder):

| Variable | Source | Purpose |
| --- | --- | --- |
| `BW_SESSION` | Set by `LoginScript.ps1` at User scope | Bitwarden CLI session token used by `Get-BitWardenSecret`. |
| `PROGET_BUILDMASTER_API_KEY` (preferred) | Set by `LoginScript.ps1` at User scope | ProGet API key used by the publish/promote cmdlets in `ATAP.Utilities.BuildTooling.PowerShell` that this module's pipeline triggers. |
| `PROGET_ADMIN_API_KEY` (fallback) | Set by `LoginScript.ps1` at User scope | Fallback ProGet API key when the BuildMaster-only key is absent. |
| `BuildMaster.Admin.API.Key` (secret) | Stored in Bitwarden Secrets Manager; read via `Get-SecretATAP` | BuildMaster API key, used when this module's cmdlets interact with the BuildMaster REST API. |
| `BUILDMASTER_BUILD_ID` | Set by BuildMaster at run-time | Build identifier propagated into evidence bundles produced by this module's rehearsal cmdlets. |

## Required Bitwarden secret names

Connection strings for SQL Server are stored in Bitwarden as secure-note
items. The cmdlets resolve them **by name** at runtime via
`Get-BitWardenSecret`. Names follow the patterns in
[`.claude/Rules/Bitwarden.md`](../../../.claude/Rules/Bitwarden.md):

### Permanent tiers

```
dbConnectionString-<Database>-<Host>-<Production|QA|Integration>
```

Examples used today on the `utat022` workstation:

- `dbConnectionString-ATAPUtilities-utat022-Integration`
- `dbConnectionString-ATAPUtilities-utat022-QA`
- `dbConnectionString-ATAPUtilities-utat022-Production`
- `dbConnectionString-AceCommander-utat022-Integration`
- `dbConnectionString-AceCommander-utat022-QA`
- `dbConnectionString-AceCommander-utat022-Production`

### Ephemeral sprint instances

```
dbConnectionString-<Database>-<Host>-<Dev|Exp>-<UserName>
```

The `master` database needs a connection string for every SQL Server
instance the module may create, migrate, inspect, or tear down. See
[`.claude/Rules/Bitwarden.md` §Master Database Coverage](../../../.claude/Rules/Bitwarden.md)
for the exhaustive list.

No actual secret values appear in this folder.

## Cross-references

- Module manifest: [`../ATAP.Utilities.DatabaseManagement.Powershell.psd1`](../ATAP.Utilities.DatabaseManagement.Powershell.psd1)
- Module root readme: [`../ReadMe.md`](../ReadMe.md)
- Module root index: [`../INDEX.md`](../INDEX.md)
- Pipeline overview: [`../../../SolutionDocumentation/Database-Change-Unit-and-Flyway-Promotion.md`](../../../SolutionDocumentation/Database-Change-Unit-and-Flyway-Promotion.md)
- Artifact and feed decision: [`../../../SolutionDocumentation/Database-Package-Artifact-And-Feed-Decision.md`](../../../SolutionDocumentation/Database-Package-Artifact-And-Feed-Decision.md)
- Compatibility cmdlet doc: [`../../../SolutionDocumentation/Database-Package-Compatibility.md`](../../../SolutionDocumentation/Database-Package-Compatibility.md)
