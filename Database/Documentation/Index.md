# Database/Documentation — Index

This file lists all documentation artifacts in the `Database/Documentation/` folder
and provides deep-link pointers into the cross-cutting `SolutionDocumentation/`
documents that the database pipeline depends on. See [ReadMe.md](ReadMe.md)
for the folder's purpose and scope.

## Canonical ATAPUtilities Source Layout

`Database/Flyway/` is the single source root for the `ATAPUtilities.Database`
package: its `version.json` supplies package metadata, `SQL/` supplies the
versioned Flyway schema and CSV-loader scripts, and `Data/` supplies their CSV
inputs. `SQL/V00.01.000010__Create_ATAPUtilities_Core_Schema.sql` retains the
immutable bytes already applied to permanent tiers. The historical
instantiation, durable RRSBS, typed-membership retirement, invariant, and
effective-dating changes are preserved as forward migrations
`V00.02.000060` through `V00.02.000100` in that same canonical `SQL/`
directory. The former split source directory is retired; existing databases at
`00.02.000040` keep these later migrations pending until a separately reviewed
promotion.

## Database Pipeline — Cross-Cutting References (in `SolutionDocumentation/`)

This folder does **not** duplicate process or release documentation; it links
to the authoritative `SolutionDocumentation/` documents instead.

### Artifact structure and feed family

- [`SolutionDocumentation/Database-Package-Artifact-And-Feed-Decision.md`](../../SolutionDocumentation/Database-Package-Artifact-And-Feed-Decision.md)
  — Sprint 0007 decision record: database change units ship as NuGet
  content packages through the five-feed `database-*` family; package-id
  convention `<App>.Database`; version labels match the existing
  `Sprint` / `Alpha` / `Beta` / `QA` / `(stable)` pattern.

### Flyway mechanics

- [`SolutionDocumentation/Database-Change-Unit-and-Flyway-Promotion.md`](../../SolutionDocumentation/Database-Change-Unit-and-Flyway-Promotion.md)
  — Database change-unit lifecycle, Flyway migration ordering, repeatables,
  and how the promotion pipeline drives Flyway during the rehearsal and
  production stages.

### BuildMaster runner design

- [`SolutionDocumentation/BuildMaster-Install-Runbook.md` §Database package applications](../../SolutionDocumentation/BuildMaster-Install-Runbook.md)
  — Application naming convention (`<App>Database`), the six required
  Application Variables (`ApplicationName`, `DatabaseApplication`,
  `DatabaseStream`, `Branch`, `SourcePath`, `ProGetBaseUrl`), the
  required service-account environment variables for ProGet API keys,
  and the canonical `database-*` ProGet feed list.

### Sprint provenance and steps

- [`_Planning/TASKS_V4.md` §Stream V4-E](../../../_Planning/TASKS_V4.md)
  — Sprint 0007 provenance for the database pipeline (tasks V4-E01
  through V4-E18). Read for ordering and acceptance criteria; this
  folder only documents the implementation result.

### Consumer resolution and compatibility

- [`SolutionDocumentation/Database-Package-Consumer-Resolution.md`](../../SolutionDocumentation/Database-Package-Consumer-Resolution.md)
  — How a consumer selects the correct `database-*` feed for an
  environment tier, respects `database-package-ceiling.json`, and
  resolves a specific package version with `Install-Package` or
  `dotnet restore`. References the helper cmdlet
  `Resolve-DatabasePackageFeed`.
- [`SolutionDocumentation/Database-Package-Compatibility.md`](../../SolutionDocumentation/Database-Package-Compatibility.md)
  — `compatibleAppPackageRanges` semantics and the
  `Test-DatabasePackageCompatibility` cmdlet that release bundles use
  to validate the app/database pairing.

### Version ceiling

- [`SolutionDocumentation/Database-Package-Ceiling-File.md`](../../SolutionDocumentation/Database-Package-Ceiling-File.md)
  — The `database-package-ceiling.json` schema and the rule that the
  promotion runner uses to cap the highest `database-*` feed a sprint,
  feature, integration, QA, release, or hotfix lane may consume.

### Multi-database future scope

- [`SolutionDocumentation/Database-MultiDB-Future-Requirements.md`](../../SolutionDocumentation/Database-MultiDB-Future-Requirements.md)
  — Forward-looking notes for AceCommander per-user databases,
  multi-stream databases, and tenant-fanout migration orchestration
  that are deferred from Sprint 0007.

## Settings keys used by database cmdlets

The database promotion cmdlets resolve ProGet feed URIs through the
`$global:settings` two-tier configuration system. They use the same
ProGet base URL key as the NuGet cmdlets; only the feed name family
differs. The settings keys consulted are:

- `ProGetBaseUrlConfigRootKey` — ProGet host URL (e.g.
  `http://localhost:50000`).
- `ProGetFeedCollectionConfigRootKey` — feed collection hash keyed by
  feed name; the `database-*` entries are added here at runtime by
  the BuildMaster runner.

No actual host values are listed in this index. Read them at runtime via
`$global:settings[$global:configRootKeys['<KeyName>']]`.

## Secret name conventions

The database promotion cmdlets resolve secrets by **name** at runtime.
The actual values live only in Bitwarden Secrets Manager; callers and build
hosts do not export them as environment variables. Names used:

- `ProGet.BuildMaster.API.Key` — CI publishing/promotion SecretName, passed as
  `-ProGetApiKeySecretName`. The authenticated leaf resolves it through
  `Get-SecretATAP` and fails closed; there is no administrator-key fallback.
- `dbConnectionString-<Database>-<Host>-<Tier>` — Bitwarden secure-note
  items for permanent SQL Server connection strings, e.g.
  `dbConnectionString-ATAPUtilities-utat022-Production`. The naming
  convention for permanent and ephemeral sprint instances is defined
  in `.claude/Rules/Bitwarden.md`.

No secret values are stored in this folder or in any of the linked
documents.

---

This file lists all documentation artifacts in the `Database/Documentation/` folder.

## PlantUML Diagrams — Core Schema

These diagrams describe the ATAPUtilities database schema.

Rendered images are generated under `_generated/diagrams/Database/Documentation`.
See
[`SolutionDocumentation/Generated-Diagram-Pipeline.md`](../../SolutionDocumentation/Generated-Diagram-Pipeline.md)
for the `Convert-DiagramsToImages` command and renderer prerequisites.

- [CoreSchema_Overview.puml](CoreSchema_Overview.puml) — Entity-relationship overview of the full ATAPUtilities schema, showing all major tables and their relationships.
- [CoreSchema_Rules.puml](CoreSchema_Rules.puml) — Detailed ER diagram for the Rules subsystem: `PrimitiveLanguageKind`, `RulePrimitive`, `RulePrimitiveInput`, `RulePrimitiveComposition`.
- [CoreSchema_Philote.puml](CoreSchema_Philote.puml) — ER diagram for the Philote identity tables, showing GUID-based entity identity across all objects.
- [CoreSchema_Instantiation.puml](CoreSchema_Instantiation.puml) — ER diagram for the Instantiation subsystem, tracking BuildSet deployment records.

## PlantUML Diagrams — Database Package Promotion Pipeline

These diagrams document the CI/CD workflow for promoting ATAPUtilities database migrations through the environment tiers.

- [DB-PromotionPackage-Files.puml](DB-PromotionPackage-Files.puml) — Component/deployment diagram showing the source files assembled into the `ATAPUtilities.Database` NuGet content package (`.nupkg`) and the internal structure of that package.
- [DB-PromotionPipeline-BuildMaster-ProGet.puml](DB-PromotionPipeline-BuildMaster-ProGet.puml) — Sequence diagram showing all BuildMaster pipeline stages (Experimental → Development → Integration → QA → Production) and the corresponding ProGet NuGet feeds used as stage gates.
- [DB-DeveloperWorkflow.puml](DB-DeveloperWorkflow.puml) — Activity diagram of the developer inner loop: writing a migration, testing locally with Flyway, bumping `version.json`, committing, and handing off to the BuildMaster CI trigger.
- [DB-ProductionBackup-SprintInit.puml](DB-ProductionBackup-SprintInit.puml) — Swimlane activity diagram for `Export-ProductionDatabaseForSprintInit.ps1`: backing up Production, then restoring that snapshot onto Integration and QA so every sprint starts from a known-good baseline.
- [DB-StablePackageBuildOnce.puml](DB-StablePackageBuildOnce.puml) — End-to-end activity diagram for a database package whose `version.json` carries no pre-release label. Covers all BuildMaster stages, the human approval gate before Production, post-deployment tagging, and the final sprint-branch merge into `main`.

## Markdown Design Documents

- [RRSBS-RDB-300-Flyway-Allocation-and-Bootstrap-Contract.md](RRSBS-RDB-300-Flyway-Allocation-and-Bootstrap-Contract.md) — Wave 4 allocation of the isolated RRSBS V2 Flyway lineage (`00010`), package `0.0.1`, history-table boundary, bootstrap contract, and future mixing-rejection requirements.
- [FolderStructure.md](FolderStructure.md) — Annotated folder tree of the entire `Database/` subtree with the purpose of each file and subfolder.
- [CrossSchema_UserView_Design.md](CrossSchema_UserView_Design.md) — Design notes for cross-schema user views that join the Rules, Philote, Tags, and Instantiation schemas.
- [API_Specification_RuleExport.md](API_Specification_RuleExport.md) — REST API specification for the Rule Export endpoint: request/response shapes, error codes, and versioning policy.
- [README_RuleExport.md](README_RuleExport.md) — Usage guide and developer quick-start for the Rule Export utilities.
- [README.RRSBS.md](README.RRSBS.md) — Overview of the Rules, Rule Sets, and Build Sets (RRSBS) subsystem as implemented in the ATAPUtilities database.
- [PROMOTION_SUMMARY.md](PROMOTION_SUMMARY.md) — Narrative summary of the database package promotion process, suitable as an executive overview of the pipeline diagrams above.
- [HelloWorld-Example-Remediation-Plan.md](HelloWorld-Example-Remediation-Plan.md) — Remediation plan and example walkthrough for the canonical "Hello World" BuildSet instantiation.
