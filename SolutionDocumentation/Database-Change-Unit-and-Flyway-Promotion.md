# Database Change Unit and Flyway Promotion

**Scope:** How Flyway migration scripts and CSV seed data are grouped into
versioned **DB change units**, mapped to application release versions, and
promoted through the five tiers as part of the Release Bundle.
**Audience:** Developers writing SQL migrations or seed loaders; release
engineers reviewing what DB content goes into a release; anyone debugging a
mismatch between an installed application version and its database schema.
**Status:** Authoritative for sprint-0007.

**Companion docs:**

- [Immutable-Build-Strategy.md](Immutable-Build-Strategy.md) — the policy the
  DB change unit follows (built once, promoted unchanged).
- [Release-Bundle-Pipeline.md](Release-Bundle-Pipeline.md) — the pipeline
  that bundles DB content with app code.
- [Release-Branch-and-Manifest.md](Release-Branch-and-Manifest.md) — the
  release-manifest fields that name the DB content.

---

## 1. The release-unit principle

> Every shipped release contains both app code **and** the DB content needed
> to install or upgrade the database to the version that supports that app.

This is the consequence of shipping to Chocolatey / WinGet: end users
expect a single install/upgrade command to handle everything, including the
database. The release model therefore treats the **(app, DB)** pair as a
single atomic release unit, even when one of them is unchanged from the
prior release.

A "DB change unit" is the versioned set of:

- Flyway migration scripts (`V*.sql`, `R*.sql`).
- CSV seed / static-data files.
- SQL or PowerShell loader scripts that bulk-load or upsert from CSV.
- A DB sub-manifest enumerating the above with checksums and target Flyway
  version.

For application version `<Major>.<Minor>.<Patch>`, the corresponding DB
change unit is named `<App>-db-<Major>.<Minor>.<Patch>` and travels inside
the Release Bundle.

---

## 2. Repository layout

```text
db/<App>/
├── flyway/
│   ├── V1.4.0__baseline_schema.sql
│   ├── V1.4.1__add_new_feature_tables.sql
│   ├── V1.4.2__add_audit_columns.sql
│   └── R__views_and_procs.sql                # repeatable
├── seed/
│   ├── S1_4_0_roles.csv
│   ├── S1_4_0_roles_load.sql
│   ├── S1_4_0_permissions.csv
│   ├── S1_4_0_permissions_load.sql
│   └── R__seed_lookup_tables.sql             # repeatable seed for slowly-changing reference data
└── releases/
    ├── 1.4.0.yml                              # DB change unit manifest for app 1.4.0
    ├── 1.4.1.yml
    └── 1.4.2.yml
```

The per-release YAML manifest is the authoritative declaration of what
constitutes a DB change unit. The machine-readable schema lives at
[SolutionDocumentation/schemas/db-release-unit.schema.yaml](schemas/db-release-unit.schema.yaml):

```yaml
# db/AceCommander/releases/1.4.0.yml
appVersion: 1.4.0
dbChangeUnit: AceCommander-db-1.4.0
flywayTargetVersion: 1.4.2
migrations:
  - V1.4.0__baseline_schema.sql
  - V1.4.1__add_new_feature_tables.sql
  - V1.4.2__add_audit_columns.sql
repeatables:
  - R__views_and_procs.sql
seedFiles:
  - S1_4_0_roles.csv
  - S1_4_0_permissions.csv
seedLoaders:
  - S1_4_0_roles_load.sql
  - S1_4_0_permissions_load.sql
  - R__seed_lookup_tables.sql
expectedRowCounts:
  Roles: 12
  Permissions: 134
notes: |
  Adds AuditCreatedAt / AuditCreatedBy columns to all primary tables.
  Backwards compatible — old rows get a NULL backfill.
```

`New-ReleaseManifest` reads this file, computes SHA-256 checksums for every
named DB file, and writes both the top-level `manifest.json` and a
`db-manifest.json` sidecar. `New-ReleaseBundle` copies the named scripts into
the Release Bundle's `db/` folder and places the sidecar at
`db/db-manifest.json`.

---

## 3. The mapping: app version ↔ DB change unit

Every release manifest (the JSON one at the bundle root) carries:

```json
{
  "appPackageId": "AceCommander",
  "appPackageVersion": "1.4.0",
  "databasePackageIncluded": true,
  "dbChangeUnit": "AceCommander-db-1.4.0",
  "flywayTargetVersion": "1.4.2",
  "migrationFiles": ["...", "..."],
  "seedFiles": ["...", "..."],
  "seedLoaderScripts": ["...", "..."],
  "checksums": {
    "V1.4.0__baseline_schema.sql": "sha256:...",
    "S1_4_0_roles.csv": "sha256:..."
  }
}
```

This makes the mapping machine-readable. Deployment tooling can:

- Assert that the bundle contains the DB change unit it claims to.
- Verify on every install that the Flyway history table now matches the
  declared `flywayTargetVersion`.
- Refuse to roll forward an app version whose `dbChangeUnit` is not at or
  beyond the version the app expects.

---

## 4. Code-only releases

A release that introduces no new schema or seed changes still ships a DB
change unit. Two equivalent patterns:

1. **Reuse the prior version explicitly.** The new release's DB change
   unit YAML lists the same files as the prior release (no new `V` script
   is added). `flywayTargetVersion` is unchanged. The release manifest
   records `databasePackageIncluded: true` and the same Flyway target as
   before.
2. **Always re-emit a manifest.** Even with no change, the release pipeline
   produces a fresh `db-manifest.json` so consumers always have an explicit
   declaration. There is no special-case "no DB section" mode.

This deliberately rejects the older "skip DB for code-only releases" model
in favor of always shipping a complete, self-describing bundle.

The install/upgrade scripts (`installer/Install-Application.ps1` and
`installer/Update-Application.ps1`) detect the no-op case ("current Flyway
version equals target") and skip migration entirely. The bundle still
contains the migrations so a fresh install can build the database from
scratch.

---

## 5. DB instances by tier and developer scope

A DB change unit is **not** a separately-promoted artifact. It is an
intrinsic part of the Release Bundle, and the bundle is what gets promoted
through `releasebundle-experimental → … → releasebundle-production`.

The model is **not** one DB per tier. A real team has multiple developers,
parallel feature branches, and parallel pipeline runs, each of which needs
its own isolated DB instance to avoid stepping on the others. The full
inventory of DB instance types is:

| Instance type         | Naming pattern                                | Lifetime                                                                                               | Cardinality                        | Tiers supported |
| --------------------- | --------------------------------------------- | ------------------------------------------------------------------------------------------------------ | ---------------------------------- | --------------- |
| Per-developer scratch | `<App>-dev-<GitHandle>` (≤64 chars total)     | Ephemeral — created at SprintStart, destroyed at SprintEnd                                             | 1 per developer × repo × sprint    | Experimental    |
| Per-feature-sprint    | `<App>-<FeatureSlug>-<GitHandle>` (≤64 chars) | Ephemeral — created at FeatureStart or sprint-slice start, destroyed when slice is abandoned or merged | 1 per feature × sprint × developer | Experimental    |
| Per-feature shared    | `<App>-<FeatureSlug>-shared`                  | Persistent for life of feature branch                                                                  | 1 per active feature branch        | Development     |
| Trunk Development     | `<App>-dev`                                   | Persistent                                                                                             | 1 per repo                         | Development     |
| Trunk Integration     | `<App>-integration`                           | Rotating snapshot (restored before each Integration pipeline run)                                      | 1 per repo                         | Integration     |
| Trunk QA Gold         | `<App>-qa`                                    | Persistent, anonymised prod-shaped data                                                                | 1 per repo                         | QA              |
| Customer Production   | `<App>` (or customer-specific name)           | Permanent                                                                                              | N — one per customer               | Production      |

Tier-specific DB validation (regardless of instance type):

| Tier         | DB-related action in the pipeline                                                                                                                                |
| ------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Experimental | Apply migrations against the empty Experimental SQL Server instance (`localhost\EXPWHERTZING` in this worktree); assert no errors; assert seed loaders complete. |
| Development  | Apply against a small dev fixture DB.                                                                                                                            |
| Integration  | Apply against a snapshot of the **previous-prod** DB (taken at the last Production release). Assert no data corruption.                                          |
| QA           | Apply against a "QA gold" DB (production-shaped, anonymized customer data). Run integration test suite against the result.                                       |
| Production   | The artifact is promoted, not re-tested. The Production gate is a manual approval based on the QA evidence.                                                      |

The "previous-prod snapshot" used at Integration is restored from the
backup that `Invoke-SqlServerBackup.ps1` makes for the last Production
release. This is the most important DB validation step — it catches
migrations that work on an empty schema but break when applied to real
historical data.

`Invoke-FlywayRehearsal` (in `ATAP.Utilities.DatabaseManagement.Powershell`) is
the cmdlet the BuildMaster stages call to run these rehearsals. It creates a
per-run ephemeral rehearsal database, invokes Flyway, drops the database in a
`finally` block, and records the Flyway log as an artifact attached to the
BuildMaster release record. The ReleaseBundle BuildMaster plan uses one DB
connection mode for the Integration rehearsal:
`-DBConnectionStringSecretName $IntegrationDatabaseDBConnectionStringSecretName`. That BuildMaster
Application variable stores the permanent Integration-tier Bitwarden item name
from [SprintInfrastructure-Naming.md §4](SprintInfrastructure-Naming.md#4-bitwarden-connection-string-secret-naming),
for example `dbConnectionString-AceCommander-utat022-Integration`; the plan does
not pass `-DatabaseHost` / `-SqlInstance` for this rehearsal. The `-BackupPath`
value is recorded for traceability; restoring the previous-production backup
remains environment-specific.

### 5.1 Naming convention and length limits

- **Total DB name length: ≤64 characters.** SQL Server permits 128, but the
  64-character cap leaves headroom for environment prefixes (e.g., a host
  qualifier or a backup-set tag) and avoids truncation in tooling output
  windows.
- **`<FeatureSlug>`** is the same slug computed by BuildMaster per the
  feature-branch versioning rule (PascalCase, ≤16 characters). See
  [Long-Developing-Features.md §2](Long-Developing-Features.md) for the
  authoritative slug derivation.
- **`<GitHandle>`** is the developer's GitHub handle, truncated to 12
  characters if longer. Lower-case is preferred for consistency, but the
  comparison is case-insensitive.
- **Delimiters: hyphens only.** No underscores, no dots. SQL Server accepts
  more, but the simpler set keeps names readable in URLs, log lines, and
  PowerShell output.

Examples:

| Scenario                                               | DB name                               |
| ------------------------------------------------------ | ------------------------------------- |
| Dev scratch, app `AceCommander`, handle `wh`           | `AceCommander-dev-wh`                 |
| Feature sprint, feature `PaymentRefactor`, handle `wh` | `AceCommander-PaymentRefactor-wh`     |
| Feature shared, feature `PaymentRefactor`              | `AceCommander-PaymentRefactor-shared` |
| Trunk Development                                      | `AceCommander-dev`                    |

### 5.2 Lifecycle hooks

Per-developer and per-feature DB instances are created and destroyed at
specific lifecycle events. The four cmdlets that own these transitions are:

| Event                                   | Action                                                                                                                                                                                                       | Cmdlet                                                                |
| --------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------- |
| `SprintStart`                           | Provision a per-developer scratch DB for each active developer.                                                                                                                                              | `New-DeveloperScratchDb`                                              |
| `FeatureStart`                          | Provision the per-feature shared DB.                                                                                                                                                                         | `New-FeatureSharedDb`                                                 |
| `SprintEnd`                             | Destroy per-developer scratch DBs for the closing sprint. Data is **not** backed up — scratch DBs are disposable by definition. Any migration under test must be committed to source before the sprint ends. | `Remove-DeveloperScratchDb`                                           |
| `FeatureEnd` (feature merged to stable) | Destroy the per-feature shared DB and any per-feature-sprint DBs for that feature.                                                                                                                           | `Remove-FeatureSharedDb`, `Remove-DeveloperScratchDb -Feature <slug>` |

**Trigger mechanism.** The hooks are currently **manual PowerShell calls**
made by the developer or release engineer at the listed events. The Stream J
cmdlets are implemented and idempotent; wiring them to BuildMaster pipeline
events (`SprintStart` / `SprintEnd` release-record transitions) is still future
automation work.

**Module home.** All four cmdlets live in
`ATAP.Utilities.DatabaseManagement.Powershell`. They are siblings of the
existing `Invoke-FlywayRehearsal` and `Invoke-SqlServerBackup` family
in the same module's public API surface.

---

## 6. Backward / forward compatibility rules

To keep code-only releases viable (releases that ship without
schema-bumping migrations), DB changes follow these rules:

- **Additive only by default.** New tables, new columns with `NULL`
  default, new indexes. Old code keeps working.
- **No `DROP COLUMN`, no `ALTER COLUMN` narrowing in a single release.**
  Both require a deprecation cycle: introduce the new column, dual-write,
  ship a release, switch reads, ship a release, then drop in a later
  release.
- **No destructive migrations on Integration / QA / Production tiers.**
  Destructive changes are allowed in Experimental (sprint-line code) only,
  and only in a controlled Flyway history that can be replayed from
  scratch.
- **Seed-data updates** that are repeatable (`R__seed_*.sql`) re-run on
  every Flyway invocation; versioned seed loaders (`V*` or `S*`) run once
  per environment and must be idempotent (use `MERGE` or `IF NOT EXISTS`
  patterns).

**Additive-only rule for feature branches.** Feature branches with DB
changes must use **additive-only migrations** until merged to trunk: no
`ALTER COLUMN`, no `DROP COLUMN`, no `DROP TABLE` against existing
trunk-schema objects. The rationale is that feature branches share the
Production DB shape with trunk, so additive migrations are safe to apply
independently of trunk's own migration sequence. This rule is **policy,
not yet enforced by tooling**; a future Flyway dry-run check at the
feature Experimental stage (validating against the trunk Integration DB
snapshot) is tracked. See
[Long-Developing-Features.md §5](Long-Developing-Features.md) for the
full feature-branch DB-change policy.

The compatibility rules are enforced by code review, not by a static check.
A future automated check (linting `V*.sql` files for `DROP COLUMN`) is
tracked in TASKS.md.

---

## 7. Seed-data conventions

Seed data is divided into three categories, each handled differently:

| Category              | Example                                                                                  | Where it lives               | Loaded by                               |
| --------------------- | ---------------------------------------------------------------------------------------- | ---------------------------- | --------------------------------------- |
| **Static reference**  | Country codes, currency codes, RRSBS rule primitives                                     | Inline in versioned `V*.sql` | Flyway, once per environment            |
| **Slowly-changing**   | Roles, permissions, feature flags                                                        | CSV + `S*` loader (`MERGE`)  | Flyway, once per release that adds rows |
| **Repeatable lookup** | View definitions, stored procs, lookup tables that should always reflect source-of-truth | CSV + `R__*` loader          | Flyway, every invocation                |

The CSV-plus-loader pattern is preferred for anything more than ~20 rows
because:

- The CSV is reviewable in source control as a table, not as nested SQL.
- The same CSV can be re-run during local development without churning the
  Flyway version history.
- The loader script enforces upsert semantics (`MERGE INTO ... USING ...`)
  so re-running is safe.

---

## 8. The DB sub-manifest format

`db/db-manifest.json` inside the Release Bundle. The machine-readable schema
lives at [SolutionDocumentation/schemas/db-manifest.schema.json](schemas/db-manifest.schema.json):

```json
{
  "schemaVersion": 1,
  "dbChangeUnit": "AceCommander-db-1.4.0",
  "appVersion": "1.4.0",
  "flywayTargetVersion": "1.4.2",
  "createdUtc": "2026-05-06T14:32:11Z",
  "createdFromGitTag": "v1.4.0",
  "createdFromGitSha": "8f4b2c1d3e5f...",
  "files": [
    {
      "path": "flyway/V1.4.0__baseline_schema.sql",
      "kind": "migration",
      "checksumSha256": "..."
    },
    {
      "path": "seed/S1_4_0_roles.csv",
      "kind": "seed",
      "checksumSha256": "...",
      "expectedRowCount": 12
    }
  ],
  "expectedRowCounts": {
    "Roles": 12,
    "Permissions": 134
  },
  "rollbackSupported": false,
  "rollbackNotes": "This release adds NOT NULL columns. To downgrade, restore from backup."
}
```

The DB sub-manifest exists alongside the bundle's `manifest.json` so DB
tooling (the install / upgrade scripts, audit reports) can consume it
independently without parsing the larger release manifest.

---

## 9. Install / upgrade script behavior

`installer/Install-Application.ps1` reads the release manifest and decides
its DB action:

```text
1. Detect current state:
     - DB exists?            (query master.sys.databases)
     - Flyway schema_history present?  (query <db>.flyway_schema_history)
     - Current Flyway version?
2. Decide action:
     - DB absent:               CREATE DATABASE; apply all migrations; run seed loaders.
     - DB present, Flyway absent: BASELINE at the manifest's baseline version; then migrate.
     - DB at target version:    no-op for migrations; re-run repeatable loaders only.
     - DB below target version: migrate up; run any new versioned seed loaders.
     - DB above target version: ABORT with a clear error (downgrade is not supported).
3. Verify:
     - Flyway history table now lists the manifest's expected versions.
     - All file checksums in the manifest match the files actually used.
     - Expected row counts match.
4. Report:
     - Write a summary line to STDOUT.
     - Write a structured log to %ProgramData%\<Product>\install-log\<timestamp>.json.
```

The script is the same on every tier — only the input bundle changes.
That keeps the install path identical from QA rehearsal to Production
deployment.

---

## 10. Drift detection between releases

For each Production release, the pipeline stores a **schema snapshot**
(generated DDL or a hash of the schema) as part of the BuildMaster release
artifacts. A future pipeline step compares the snapshot from release N+1
against release N to catch out-of-band schema changes (manual `ALTER TABLE`
on a production DB) that should have flowed through Flyway.

The snapshot is captured by `Invoke-SchemaSnapshot` (PowerShell wrapper
around `dbatools` / SQL Server's `Generate Scripts` task). Stored in
`tests/schema-snapshot.sql` inside the bundle.

---

## 11. Known drift and gaps (sprint-0007)

1. **Per-app `db/<App>/releases/*.yml` files are not yet authored.** The
   format is defined; the files need to be created at the start of each
   app's release-bundle work.
2. **No automated `DROP COLUMN` linter on `V*.sql`.** Tracked.
3. **No checksum verification at install time.** The script reads
   checksums from the manifest but does not yet recompute and compare
   them. Tracked.
4. **No schema-snapshot drift detection.** The snapshot is captured but
   not yet automatically diffed against the prior release. Tracked.

Resolved in Stream J on 2026-05-12: `Invoke-FlywayRehearsal` now uses
`<App>-rehearsal-<BuildId>` by default, honors explicit `-RehearsalDb`
overrides, creates the ephemeral DB at the start of the run, and drops it in a
`finally` block.

---

## 12. Quick reference

Author a new DB change unit for app version `1.4.0`:

```powershell
# 1. Add migrations, seed CSV, and loaders under db/AceCommander/
# 2. Author db/AceCommander/releases/1.4.0.yml listing them
# 3. Build the release bundle (which copies them into the bundle and
#    generates db-manifest.json with checksums)
$ctx  = Get-BuildContext -ReleaseTag 'v1.4.0' -Application AceCommander -ProjectPath .
$mfst = New-ReleaseManifest -Context $ctx
New-ReleaseBundle -Manifest $mfst -OutputPath ./_generated/release-bundle/
```

Rehearse Flyway migrations against the previous-prod snapshot:

```powershell
Invoke-FlywayRehearsal `
  -Application AceCommander `
  -BuildId     1-4-0 `
  -DBConnectionStringSecretName dbConnectionString-AceCommander-utat022-Integration `
  -BundlePath  ./_generated/release-bundle/AceCommander.1.4.0.upack `
  -BackupPath  C:\Dropbox\Backups\utat022\Production\AceCommander\latest.bak `
  -LogPath     ./_generated/flyway-rehearsal-1.4.0.log
```

---

## 14. SQL Server Instance Naming

> Migrated from `_Planning/Explainers/0104-sql-databases-lifecycle.md` §2.2-§2.3 and §4.3.
> Updated 2026-06-11 (Sprint 0008, Task 8.5): the per-developer instances are now
> **permanent onboarding infrastructure** — sprint boundaries reset only the
> **databases** inside them, not the instances. See
> [Developer-SqlServerInstances-Runbook.md](Developer-SqlServerInstances-Runbook.md).

SQL Server supports one **default instance** and multiple **named instances**
per host. ATAP uses named instances to isolate databases by tier. Each tier and
each developer gets isolated **named instances**; the **databases** inside the
per-developer instances are the per-sprint unit (dropped, recreated, and
re-migrated at sprint boundaries — the instances persist).

### 14.1 Instance name constraints

- SQL Server instance names may not contain hyphens (`-`) or dots (`.`).
- The **16-character limit** applies to the instance name.
- Per-developer instances follow the pattern `{Prefix}{user}`: a 3-char prefix
  (`Dev` or `Exp`) directly concatenated with the developer's Windows
  `$env:USERNAME` (≤12 chars) — **no separator character**.
- The authoritative username-to-host mapping is in
  `Overview.code-workspace`.
- **Isolation between sprints is achieved at the database level** — the
  `ATAPUtilities` and `AceCommander` databases inside each instance are dropped,
  recreated, and re-migrated at sprint boundaries. The named instances
  themselves are **not** destroyed and recreated; they are permanent
  developer-onboarding infrastructure.

`Dev{user}` hosts active feature-development work (Development tier,
`-Alpha` label packages). `Exp{user}` hosts throwaway prototypes and spikes
(Experimental tier, `-Sprint` label packages).

The `New-DeveloperSqlServerInstances.ps1` cmdlet creates both instances in a
single call **once per developer per workstation** (developer onboarding);
`Remove-DeveloperSqlServerInstances.ps1` destroys both **only** at developer
offboarding. At sprint boundaries, `Reset-SprintDatabases.ps1` (sprint start)
and `Remove-SprintDatabases.ps1` (sprint end) operate on the databases inside
the existing instances and never create or destroy an instance. (The former
`New-SprintSqlServerInstances` / `Remove-SprintSqlServerInstances` names survive
only as deprecated aliases of the `*-Developer*` cmdlets.)

### 14.2 Per-developer instances and the per-sprint database unit

| Instance Name      | Tier         | Lifetime                                                                    | Created By                            |
| ------------------ | ------------ | --------------------------------------------------------------------------- | ------------------------------------- |
| `Dev{user}`        | Development  | **Permanent** — created at developer onboarding; persists across sprints    | `New-DeveloperSqlServerInstances.ps1` |
| `Exp{user}`        | Experimental | **Permanent** — created at developer onboarding; persists across sprints    | `New-DeveloperSqlServerInstances.ps1` |
| `Release_{SemVer}` | Production   | Created for release validation; persisted with the release                  | Manual / SprintEndAgent               |
| `Hotfix_{issue}`   | Emergency    | Created for hotfix work; destroyed after merge                              | Manual                                |

The **databases** inside `Dev{user}` / `Exp{user}` are the per-sprint unit:

| Database          | Inside instances        | Lifetime                                                         | Reset / dropped by                            |
| ----------------- | ----------------------- | --------------------------------------------------------------- | --------------------------------------------- |
| `ATAPUtilities`   | `Dev{user}`, `Exp{user}` | Dropped + recreated + re-migrated at sprint start; dropped at sprint end | `Reset-SprintDatabases` / `Remove-SprintDatabases` |
| `AceCommander`    | `Dev{user}`, `Exp{user}` | Dropped + recreated + re-migrated at sprint start; dropped at sprint end | `Reset-SprintDatabases` / `Remove-SprintDatabases` |

### 14.3 SemVer normalization in instance names

SQL Server instance names cannot contain dots (`.`) or hyphens (`-`). Both
are replaced with underscores (`_`). When a SemVer version appears in an
instance name, all dots and hyphens are replaced with underscores:

| SemVer  | Instance Name   |
| ------- | --------------- |
| `1.0.0` | `Release_1_0_0` |
| `2.1.3` | `Release_2_1_3` |

Branch names _may_ contain dots and hyphens (`Release-1.0.0`), but the
corresponding SQL instance name _must_ use underscores (`Release_1_0_0`).
This normalization is applied by the sprint lifecycle automation.

### 14.4 Host configuration

Current hosts:

| Host        | Role                        | Instances                                                                                                |
| ----------- | --------------------------- | -------------------------------------------------------------------------------------------------------- |
| **utat022** | Primary development machine | PRODUCTION, Dev, `Dev{user}`, `Exp{user}`, Testing, `Testing_Perf`, SQLEXPRESS, Integration, `Release_*` |
| **ncat016** | Secondary/remote machine    | Dev, `Dev{user}`, `Exp{user}` (for second developer remote access)                                       |

Connection uses TCP/IP on the default port with a self-signed certificate.
Admin accounts on the host have SQL Server admin rights. Integrated
Security is used (no SQL users/passwords required).

---

## 15. Flyway Migration Immutability Rules

> Migrated from `_Planning/Explainers/0104-sql-databases-lifecycle.md` §6.4-§6.6.

Once a versioned migration has been **shared** with another developer or
**pushed to an integration branch**, it becomes immutable:

| Migration State                                        | May Modify?        | Rationale                                                                  |
| ------------------------------------------------------ | ------------------ | -------------------------------------------------------------------------- |
| Local only (developer's own sprint branch, not pushed) | Yes                | Developer's sandbox; no downstream consumers                               |
| Pushed to remote sprint branch but not consumed        | Yes (with caution) | No other developer has applied it yet                                      |
| Consumed by another developer (merge/cherry-pick)      | **No**             | Other developer has applied it; modifying would break their Flyway history |
| Merged to integration branch                           | **No**             | Integration database has applied it; immutable from this point             |
| Merged to main                                         | **No**             | Development and downstream instances have applied it                       |

**If a shared migration needs correction:** create a new versioned
migration that applies the corrective change. Never modify a migration that
another developer or integration instance has already applied.

**Repeatable migrations** (`R__`) are exempt from this rule — they are
designed to be modified and re-applied. Use repeatable migrations for
functions, views, and other objects that should reflect the latest
definition.

### 15.1 Sprint database sharing rules

Developers do not share a live sprint database instance. When developers
exchange partial implementations during a sprint:

1. Developer A takes Developer B's code changes by merge or cherry-pick.
2. Developer A also takes the corresponding Flyway migration commits.
3. Developer A applies those migrations to Developer A's own sprint
   database instances (`Dev_{username}` and `Exp_{username}`).
4. The sprint integration database (`Integration_{NNNN}`) validates the
   combined migration graph before changes move toward the Development
   tier.

### 15.2 Hotfix database rules

Hotfix database validation starts from the **release-tag baseline**, not
from active sprint databases:

1. Create a hotfix database instance from the release tag's migration state
   (e.g., `Hotfix_42`).
2. The regression test must reproduce the production bug on this release
   baseline before the fix is applied.
3. Apply the hotfix migration to the hotfix instance and verify the fix.
4. If multiple developers collaborate on the hotfix, each gets a
   per-developer hotfix instance (`Hotfix_42_alice`, `Hotfix_42_bob`) and
   a shared hotfix integration instance (`Hotfix_42_itg`) validates the
   combined fix.
5. After acceptance, the validated migration is merged back to `main`.

---

## 16. Interim Catalog/Schema Decision (Sprint 0007)

> Migrated from `_Planning/Explainers/0111-acecommander-database-interim-architecture.md` (Executive Recommendation).
> Reflects locked decision **D-07** from `ExplainerEliminationPlan_V1.md` §0a.

For Sprint 0007, keep the server-side AceCommander data model in **one SQL
Server catalog named `ATAPUtilities`**, with separate schemas:

| Logical area               | SQL Server catalog | Schema                                  | Role                                                                  |
| -------------------------- | ------------------ | --------------------------------------- | --------------------------------------------------------------------- |
| Reference data             | `ATAPUtilities`    | `ATAPUtilities` or `MinimalTableSet`    | Immutable between database revisions; read-only to AceCommander       |
| AceCommander writable data | `ATAPUtilities`    | `AceCommander`                          | User/app extensions, scheduled tasks, mutable application data        |

This matches the current Flyway implementation, fixes the immediate
confusion that caused AceCommander to look for a database catalog named
`AceCommander`, and preserves the two-DbContext shape already in the
application.

### 16.1 Both DbContexts point at the `ATAPUtilities` catalog

AceCommander uses two EF Core contexts:

| Context                  | Connection string config key                    | Schema behavior                                                          | Access intent |
| ------------------------ | ----------------------------------------------- | ------------------------------------------------------------------------ | ------------- |
| `ReferenceDbContext`     | `Database:ReferenceDatabase:ConnectionString`   | Configurable schema, allowed values `ATAPUtilities` and `MinimalTableSet` | Read-only     |
| `AceCommanderDbContext`  | `Database:AceCommander:ConnectionString`        | Fixed default schema `AceCommander`                                       | Read/write    |

**Both contexts should connect to the same `ATAPUtilities` catalog** for
Sprint 0007 unless/until a future task formalizes separate catalogs.

### 16.2 Why this fixes the startup error

The scheduled-task startup failure:

```text
Cannot open database "AceCommander" requested by the login.
```

is consistent with the runtime using a connection string whose
`Initial Catalog` / `Database` is `AceCommander`. For the current database
definition, that connection string should target the `ATAPUtilities`
catalog and let EF select the `AceCommander` schema.

The implemented database is already a **one-catalog, multi-schema** design:

- `V00.01.000010__Create_ATAPUtilities_Core_Schema.sql` starts with
  `USE ATAPUtilities;` and creates schema `ATAPUtilities`.
- `V00.01.000040__Create_AceCommander_Schema.sql` also starts with
  `USE ATAPUtilities;` and creates schema `AceCommander`.
- `V00.01.000050__Populate_AceCommander_User_Tables.sql` copies user-related
  data from `ATAPUtilities` to `AceCommander` inside the same catalog.
- `V00.02.000010__CreateScheduledTaskTables.sql` creates
  `AceCommander.ScheduledTask` and `AceCommander.ScheduledTaskRun`.

Pointing both DbContexts at the `ATAPUtilities` catalog aligns the
application with the database that already exists.

### 16.3 Deferred architectural deep dive

The deeper questions around database packaging, offline sync, tenant
isolation, SQLCipher data modeling, and release-channel ownership are
deliberately deferred for Sprint 0007. They need to be decided together,
not piecemeal. See [`DeveloperMusings.md`](DeveloperMusings.md) for:

- "Database Packaging Options A-D" — the option matrix (one catalog
  multi-schema, separate databases, dedicated DB-definition repository,
  SQLCipher local encrypted database).
- "Deferred Database Deep-Dive Questions" — the eight open architectural
  questions that the deep dive must resolve.

---

## 17. Promotion Failure Recovery

> Migrated from `_Planning/Explainers/602 - 5Tier Software Production process Revision 2.md` §16.3.1.

Database migrations during promotion (especially to `Integration`, `QA`, or
`PRODUCTION`) can fail due to schema conflicts, data integrity violations,
or migration script errors. To mitigate the risk of a failed promotion
leaving a higher-tier database in an inconsistent state:

### 17.1 Pre-promotion snapshot

Before applying Flyway migrations to a higher-tier database, take a
**database snapshot** (or full backup) of the target instance. This
provides a rollback point if the migration fails partway through.

```powershell
# Before promoting migrations to QA
Backup-SqlDatabase -ServerInstance "utat022\QA" -Database "ATAPUtilities" `
    -BackupFile "C:\Dropbox\Backups\utat022\QA\ATAPUtilities_pre-promotion_$(Get-Date -Format 'yyyyMMdd_HHmmss').bak"
```

### 17.2 Recovery procedures

| Failure Type                          | Recovery Action                                                                                                                    |
| ------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| **Schema migration fails mid-run**    | Restore from pre-promotion backup. Fix the migration script on the source branch, re-test at the lower tier, then retry promotion. |
| **Data migration fails**              | Restore from pre-promotion backup. Investigate data incompatibility; add corrective migration or fix data on the source branch.    |
| **Migration succeeds but tests fail** | Do NOT roll back the database (the schema is correct). Fix the code or tests on the source branch and promote again.               |
| **Production promotion fails**        | Restore from pre-promotion backup. This is a critical incident — halt the release, investigate, and re-validate from QA.           |

### 17.3 Automation

The `Invoke-Flyway` wrapper (or a higher-level promotion cmdlet) should
automatically create a backup before running `migrate` against permanent
instances (`Integration`, `QA`, `QAPerf`, `PRODUCTION`). Ephemeral sprint
instances do not require pre-migration backups because they can be
recreated from scratch.

---

## 18. Related documents

- [Immutable-Build-Strategy.md](Immutable-Build-Strategy.md) — DB change units follow the build-once policy.
- [Release-Bundle-Pipeline.md](Release-Bundle-Pipeline.md) — what wraps the DB change unit.
- [Release-Branch-and-Manifest.md](Release-Branch-and-Manifest.md) — release manifest schema.
- [BuildMaster-Pipeline-Topology.md](BuildMaster-Pipeline-Topology.md) — pipeline catalog.
- `_Planning/Explainers/0104-sql-databases-lifecycle.md` — SQL instance / schema model.
- [Developer-SqlServerInstances-Runbook.md](Developer-SqlServerInstances-Runbook.md) — permanent per-developer instance onboarding/offboarding and the per-sprint database-reset lifecycle (§14).
- [Production-and-Tooling-Overview.md](Production-and-Tooling-Overview.md) — index.
