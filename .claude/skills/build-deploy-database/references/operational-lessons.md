# Build/deploy database operational lessons

This reference records reusable failure modes observed while releasing
`ATAPUtilities.Database` `0.1.3` on 2026-07-30. It is diagnostic guidance, not a
license to bypass release gates.

## What worked

- One immutable package moved through BuildMaster and all `database-*` ProGet
  feeds; the stable download matched the local artifact byte-for-byte.
- Exact filename exclusion kept deferred migration `000120` out of the archive,
  manifest, and every real tier.
- Copy-only backup/restore rehearsal caught Production-only legacy checksum
  drift before promotion or apply.
- A shared staging root accessible to BuildMaster and SQL Server made package
  expansion, `BULK INSERT`, backup, and clone restore reliable.
- Explicit source-tree binding prevented older installed PowerShell functions
  from shadowing new release contracts.
- Destination-aware ProGet promotion made a retry safe after a prior stage had
  promoted the package but failed during a later gate.
- Hashed full backup, documented checksum comparison, exact-package Flyway
  repair, and full stage retry reconciled the Production history safely.

## Failures and durable responses

| Failure | Durable response |
| --- | --- |
| BuildMaster/ProGet database engine stopped after a crash | Check services and backing databases before release work. |
| Pipeline create/clone dialogs did not persist | Use the supported BuildMaster Native API and retain the request/result. |
| BuildMaster service identity hit Git dubious ownership | Add only the exact sprint worktree to system `safe.directory`. |
| Installed package/build commands shadowed source | Dot-source the reviewed source implementation explicitly. |
| ProGet URL was absent in a no-profile service process | Pass the reviewed base URL explicitly. |
| SQL login lacked database/create or bulk-load rights | Provision the minimum login, database role, and required server roles; document them. |
| Package expected `Data` but archive used `db/seeds` | Make package layout and `flyway.toml` self-contained and test archive paths. |
| Strict mode broke scalar `.Count` assumptions | Wrap uncertain output with `@(...)` before `.Count`. |
| NuGet package ID was used as SQL database name | Keep package identity and database application identity separate. |
| Rehearsal mixed secret and host parameter sets | Keep secret-based and structured connection modes mutually exclusive. |
| SQL Server could not access service temp paths | Use a dedicated shared staging root with explicit ACLs. |
| Empty-database rehearsal failed on legacy `USE` assumptions | Clone the current target tier through backup/restore. |
| Local SQL certificates failed validation | Use explicit trusted-local dbatools connection options only for approved local endpoints. |
| Native Flyway output polluted structured results | Capture native stdout/stderr and return a normalized PowerShell result object. |
| Snapshot caller and function signatures diverged | Source-bind the snapshot function and regression-test the plan contract. |
| Stage failed after ProGet promotion | If exact version is already in destination and absent from source, resume idempotently. |
| Production clone found legacy checksum drift | Stop, compare tiers and git history, back up, justify repair or create a forward migration, then rerun the full stage. |

## Anti-patterns

- Editing an already-applied versioned migration creates checksum drift.
  Prefer a new forward migration.
- `flyway repair` does not execute changed migration content. It changes schema
  history metadata.
- A permanent `Experimental` SQL instance must not be recreated. The logical
  stage targets an ephemeral `Exp<DeveloperName>` instance.
- A successful deployment API response proves only that work was accepted.
- A package visible in ProGet proves neither database apply nor migration
  exclusion.
- A ProGet publish/promotion and its corresponding database apply form one
  stage gate. Missing connection configuration or an apply bypass must fail the
  stage before a completion marker is written.
- Rebuilding the same package version after promotion destroys artifact
  traceability.
