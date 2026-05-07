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
constitutes a DB change unit:

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

`New-ReleaseManifest` reads this file and copies the named scripts into the
Release Bundle's `db/` folder, also writing `db/db-manifest.json` with the
same data plus computed SHA-256 checksums for every file.

---

## 3. The mapping: app version ↔ DB change unit

Every release manifest (the JSON one at the bundle root) carries:

```json
{
  "appPackageId":      "AceCommander",
  "appPackageVersion": "1.4.0",
  "databasePackageIncluded": true,
  "dbChangeUnit":      "AceCommander-db-1.4.0",
  "flywayTargetVersion": "1.4.2",
  "migrationFiles":    [ "...", "..." ],
  "seedFiles":         [ "...", "..." ],
  "seedLoaderScripts": [ "...", "..." ],
  "checksums": {
    "V1.4.0__baseline_schema.sql": "sha256:...",
    "S1_4_0_roles.csv":            "sha256:..."
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

## 5. Promotion through the five tiers

A DB change unit is **not** a separately-promoted artifact. It is an
intrinsic part of the Release Bundle, and the bundle is what gets promoted
through `ReleaseBundle-Experimental → … → ReleaseBundle-Production`.

Tier-specific DB validation:

| Tier         | DB-related action in the pipeline                                                                                          |
| ------------ | -------------------------------------------------------------------------------------------------------------------------- |
| Experimental | Apply migrations against an empty SQL Server LocalDB; assert no errors; assert seed loaders complete.                      |
| Development  | Apply against a small dev fixture DB.                                                                                      |
| Integration  | Apply against a snapshot of the **previous-prod** DB (taken at the last Production release). Assert no data corruption.    |
| QA           | Apply against a "QA gold" DB (production-shaped, anonymized customer data). Run integration test suite against the result. |
| Production   | The artifact is promoted, not re-tested. The Production gate is a manual approval based on the QA evidence.                |

The "previous-prod snapshot" used at Integration is restored from the
backup that `Invoke-SqlServerBackup.ps1` makes for the last Production
release. This is the most important DB validation step — it catches
migrations that work on an empty schema but break when applied to real
historical data.

`Invoke-FlywayRehearsal` (in `ATAP.Utilities.BuildTooling.PowerShell`) is
the cmdlet the BuildMaster stages call to run these rehearsals. It records
the Flyway log as an artifact attached to the BuildMaster release record.

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

The compatibility rules are enforced by code review, not by a static check.
A future automated check (linting `V*.sql` files for `DROP COLUMN`) is
tracked in TASKS.md.

---

## 7. Seed-data conventions

Seed data is divided into three categories, each handled differently:

| Category               | Example                                              | Where it lives                  | Loaded by                                |
| ---------------------- | ---------------------------------------------------- | ------------------------------- | ---------------------------------------- |
| **Static reference**   | Country codes, currency codes, RRSBS rule primitives | Inline in versioned `V*.sql`    | Flyway, once per environment             |
| **Slowly-changing**    | Roles, permissions, feature flags                    | CSV + `S*` loader (`MERGE`)     | Flyway, once per release that adds rows  |
| **Repeatable lookup**  | View definitions, stored procs, lookup tables that should always reflect source-of-truth | CSV + `R__*` loader | Flyway, every invocation |

The CSV-plus-loader pattern is preferred for anything more than ~20 rows
because:

- The CSV is reviewable in source control as a table, not as nested SQL.
- The same CSV can be re-run during local development without churning the
  Flyway version history.
- The loader script enforces upsert semantics (`MERGE INTO ... USING ...`)
  so re-running is safe.

---

## 8. The DB sub-manifest format

`db/db-manifest.json` inside the Release Bundle:

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
2. **`Invoke-FlywayRehearsal` does not yet rotate the rehearsal DB.** It
   currently restores into a fixed name and re-uses it across runs;
   needs to create a uniquely-named DB per build to allow parallel
   pipeline runs.
3. **No automated `DROP COLUMN` linter on `V*.sql`.** Tracked.
4. **No checksum verification at install time.** The script reads
   checksums from the manifest but does not yet recompute and compare
   them. Tracked.
5. **No schema-snapshot drift detection.** The snapshot is captured but
   not yet automatically diffed against the prior release. Tracked.

---

## 12. Quick reference

Author a new DB change unit for app version `1.4.0`:

```powershell
# 1. Add migrations, seed CSV, and loaders under db/AceCommander/
# 2. Author db/AceCommander/releases/1.4.0.yml listing them
# 3. Build the release bundle (which copies them into the bundle and
#    generates db-manifest.json with checksums)
$ctx  = Get-BuildContext -ReleaseTag 'v1.4.0' -Application AceCommander
$mfst = New-ReleaseManifest -Context $ctx
New-ReleaseBundle -Manifest $mfst -OutputPath ./_generated/release-bundle/
```

Rehearse Flyway migrations against the previous-prod snapshot:

```powershell
Invoke-FlywayRehearsal `
  -BundlePath  ./_generated/release-bundle/AceCommander.1.4.0.upack `
  -BackupPath  C:\Dropbox\Backups\utat022\Production\AceCommander\latest.bak `
  -RehearsalDb AceCommander_Rehearsal_1_4_0 `
  -LogPath     ./_generated/flyway-rehearsal-1.4.0.log
```

---

## 13. Related documents

- [Immutable-Build-Strategy.md](Immutable-Build-Strategy.md) — DB change units follow the build-once policy.
- [Release-Bundle-Pipeline.md](Release-Bundle-Pipeline.md) — what wraps the DB change unit.
- [Release-Branch-and-Manifest.md](Release-Branch-and-Manifest.md) — release manifest schema.
- [BuildMaster-Pipeline-Topology.md](BuildMaster-Pipeline-Topology.md) — pipeline catalog.
- `_Planning/Explainers/0104-sql-databases-lifecycle.md` — SQL instance / schema model.
- [Production-and-Tooling-Overview.md](Production-and-Tooling-Overview.md) — index.
