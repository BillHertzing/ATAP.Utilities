# Database/Documentation

This folder holds the **deep implementation reference** for the database
pipeline that ships in the `ATAP.Utilities` repository. It sits next to
`Database/ATAPUtilities/` and stores the per-detail design notes, PlantUML
diagrams, and operator references that callers and contributors need when
working on database change packages, migrations, seed loaders, and the
BuildMaster/ProGet pipeline that promotes them.

> **Note on scope.** Process and release documentation lives in
> `SolutionDocumentation/` at the repo root. This folder is for
> implementation-level material that is too detailed (or too schema-
> specific) for the cross-cutting `SolutionDocumentation/` index. The
> [INDEX.md](INDEX.md) in this folder links to the relevant
> `SolutionDocumentation/` documents rather than duplicating them.

## Major sections

- [INDEX.md](INDEX.md) — full inventory of artifacts in this folder, plus
  deep-link pointers to the matching `SolutionDocumentation/` documents
  for the database pipeline.
- [FolderStructure.md](FolderStructure.md) — annotated tree of the
  entire `Database/` subtree.
- [README.RRSBS.md](README.RRSBS.md) — Rules, Rule Sets, and Build Sets
  subsystem overview.
- [README_RuleExport.md](README_RuleExport.md) — Rule Export utility
  quick-start.
- PlantUML diagrams: schema (`CoreSchema_*.puml`) and pipeline
  (`DB-*.puml`); see [INDEX.md](INDEX.md) for the full list.

## Cross-cutting documents in `SolutionDocumentation/`

The following root-level documents are authoritative for the database
pipeline. This folder links to them; it does **not** restate them:

- [Database Package Artifact and Feed Decision](../../SolutionDocumentation/Database-Package-Artifact-And-Feed-Decision.md)
- [Database Change Unit and Flyway Promotion](../../SolutionDocumentation/Database-Change-Unit-and-Flyway-Promotion.md)
- [Database Package Consumer Resolution](../../SolutionDocumentation/Database-Package-Consumer-Resolution.md)
- [Database Package Compatibility](../../SolutionDocumentation/Database-Package-Compatibility.md)
- [Database Package Ceiling File](../../SolutionDocumentation/Database-Package-Ceiling-File.md)
- [Database MultiDB Future Requirements](../../SolutionDocumentation/Database-MultiDB-Future-Requirements.md)
- [BuildMaster Install Runbook §Database package applications](../../SolutionDocumentation/BuildMaster-Install-Runbook.md)

## Where to find specific implementation details

| You need… | Look in… |
| --- | --- |
| Schema ER diagram for the Rules tables | `CoreSchema_Rules.puml` |
| Component diagram of the .nupkg layout | `DB-PromotionPackage-Files.puml` |
| Pipeline sequence diagram | `DB-PromotionPipeline-BuildMaster-ProGet.puml` |
| Developer inner-loop activity diagram | `DB-DeveloperWorkflow.puml` |
| Production backup → Integration/QA reseed | `DB-ProductionBackup-SprintInit.puml` |
| Stable package build-once workflow | `DB-StablePackageBuildOnce.puml` |
| Cross-schema view design | `CrossSchema_UserView_Design.md` |
| Rule Export REST API spec | `API_Specification_RuleExport.md` |
| Hello-World example walkthrough | `HelloWorld-Example-Remediation-Plan.md` |
