# ATAP.Utilities.DatabaseManagement.PowerShell — Documentation

> **Task 13.62 security cutover:** Database package pipelines pass `ProGet.BuildMaster.API.Key` only as `-ProGetApiKeySecretName`. Publish and promotion leaves resolve it with `Get-SecretATAP`; no ProGet key environment variable or admin fallback is permitted.

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

## Runtime configuration and SecretNames

The database pipeline resolves base URLs from `$global:settings`, carries
SecretNames as ordinary configuration, and resolves secret values only at the
authenticated leaf. It uses these non-secret runtime names:

| Variable | Source | Purpose |
| --- | --- | --- |
| `ProGet.BuildMaster.API.Key` (SecretName) | Passed as `-ProGetApiKeySecretName` | ProGet publish/promotion identity. There is no administrator-key or environment fallback. |
| `BuildMaster.Admin.API.Key` (secret) | Stored in Bitwarden Secrets Manager; read via `Get-SecretATAP` | BuildMaster API key, used when this module's cmdlets interact with the BuildMaster REST API. |
| `BUILDMASTER_BUILD_ID` | Set by BuildMaster at run-time | Build identifier propagated into evidence bundles produced by this module's rehearsal cmdlets. |

## Required Bitwarden secret names

Connection strings for SQL Server are stored in Bitwarden as secure-note
items. The cmdlets resolve them **by name** at runtime via
`Get-BitWardenSecret`. Names follow the patterns in
[`.claude/Rules/Bitwarden.md`](../../../.claude/Rules/Bitwarden.md):

### Permanent tiers

```
dbConnectionString.<Database>.<Host>.<Production|QA|Integration>
```

Examples:

- `dbConnectionString.ProGet.localhost.Production`
- `dbConnectionString.BuildMaster.localhost.Production`
- `dbConnectionString.ATAPUtilities.localhost.Integration`
- `dbConnectionString.ATAPUtilities.localhost.QA`
- `dbConnectionString.ATAPUtilities.localhost.Production`
- `dbConnectionString.AceCommander.localhost.Integration`
- `dbConnectionString.AceCommander.localhost.QA`
- `dbConnectionString.AceCommander.localhost.Production`

### Ephemeral sprint instances

```
dbConnectionString.<Database>.<Host>.<Dev|Exp>.<UserName>
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
