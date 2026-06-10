# ReleaseBundle vs Database Package Architecture Decision

**Date:** 2026-05-28  
**Task:** V4-F01 (TASKS_V4.md)  
**Decision:** Database packages are promoted separately; ReleaseBundle consumes promoted database packages.  
**Status:** Approved for implementation.

---

## Problem Statement

As of Sprint 0007:

- **V4-E** established a complete database package infrastructure with separate artifact type (NuGet content), feed family (`database-experimental` through `database-stable`), manifest schema, and promotion pipeline.
- **Release-Bundle-Pipeline.md §2** documents that database change units (Flyway migrations, seed data) are embedded in the ReleaseBundle archive.
- The current ReleaseBundle-6Stage.otter plan includes a database unit alongside app artifacts, with no separation or independent promotion.

**Question:** Should database packages remain embedded in ReleaseBundle, or should they be promoted separately?

---

## Options Evaluated

### Option A: Database Embedded in ReleaseBundle (Current Design)

**Structure:**
```
releasebundle-X.Y.Z.upack
├── app/           ← app runtime
├── db/            ← Flyway migrations, seed data (embedded)
├── installer/
└── manifest.json  (declares app version, expected DB Flyway version)
```

**Promotion:** Database and app promoted as a single immutable unit through `releasebundle-*` feeds.

**Strengths:**
- Single deployment package (one download = everything needed)
- Clear version correspondence: `releasebundle-1.4.0` includes all app+db artifacts for 1.4.0
- Simpler orchestration (one ReleaseBundle build, one promotion chain)
- Installer script has all artifacts available locally

**Weaknesses:**
- Database schema cannot be promoted or validated independently of app
- Database hotfixes require rebuilding the entire ReleaseBundle
- Inconsistency with immutable-build-strategy for database units (V4-E designed database packages as independent promoted units)
- Duplicates database package maintenance (schema in both `database-*` feeds AND embedded in ReleaseBundle)
- Scaling issue: multi-app systems would duplicate DB units in multiple ReleaseBundle feeds

### Option B: Database Packages Separate, ReleaseBundle Consumes Them (Recommended)

**Structure:**
```
database-X.Y.Z.nupkg    ← independent Flyway package
├── db/migrations, seed, loaders

releasebundle-A.B.C.upack    ← app + installer only
├── app/
├── manifest.json  (declares compatible database-X.Y.Z range)
├── installer/     (resolver script downloads database package at install time)
└── db-package-reference.json  (pinned database package version for this release)
```

**Promotion:**
- Database packages promoted through `database-*` feeds (independent, separate from app)
- ReleaseBundle promoted through `releasebundle-*` feeds
- ReleaseBundle manifest declares compatible database package versions

**Strengths:**
- Database schema can be promoted, validated, and deployed independently
- Hotfixes to schema do not require app rebuild
- Consistent with immutable-build-strategy: each artifact type has one build, N promotions
- Aligns with C#/PowerShell pipeline pattern (separate packages, separate promotion chains)
- No duplication: one source of truth for database schema (the `database-*` feed)
- Scales naturally for multi-app systems with shared databases

**Weaknesses:**
- Two promotion chains instead of one
- Installer must resolve and download database package at install time (network dependency)
- ReleaseBundle manifest must declare compatible database versions (adds complexity)
- If database package is not available in the expected feed, ReleaseBundle install fails (version coupling, but explicit)

### Option C: Shared Manifest / Unified Descriptor

**Structure:** A unified "Application Release Descriptor" that owns both app and database units, generating both ReleaseBundle and database packages from a single specification.

**Evaluation:** Rejected. This introduces unnecessary abstraction. Each artifact type (app, database) has different promotion, validation, and distribution requirements. A unified descriptor would obscure these differences and add complexity.

---

## Decision: Option B

**ReleaseBundle and database packages are promoted through separate, parallel feed hierarchies.**

### Rationale

1. **Consistency with immutable-build-strategy:** Database units are artifacts and should follow the same build-once/promote-N model as app packages.

2. **Design completion:** V4-E established a complete, tested database package infrastructure with independent promotion pipelines. Embedding databases in ReleaseBundle negates that investment and design.

3. **Operational flexibility:** Database schema changes can be promoted, validated, and rolled back independently without app involvement.

4. **Scalability:** Multi-app and multi-database systems can share promoted database packages without duplication.

5. **Alignment with existing patterns:** C# and PowerShell packages are promoted separately. Database packages should follow the same pattern.

---

## Implementation Implications

### 1. ReleaseBundle Manifest Updates

Update `Release-Branch-and-Manifest.md` §3 schema to include:
- `databasePackageCeiling`: the expected database package tier (e.g., `database-stable`)
- `compatibleDatabaseVersions`: SemVer range(s) for compatible database packages
- `databasePackageId`: the canonical package ID (e.g., `AceCommander.Database`)

Example:
```json
{
  "applicationName": "AceCommander",
  "applicationVersion": "1.4.0",
  "buildMetadata": "+8f4b2c1",
  "databasePackageId": "AceCommander.Database",
  "compatibleDatabaseVersions": ["[1.3.0, 1.5.0)"],
  "databasePackageCeiling": "database-stable",
  ...
}
```

### 2. ReleaseBundle Build (Experimental Stage)

- Remove the `db/` directory from the bundle contents
- Build only `app/`, `installer/`, `tests/`, `docs/`
- Manifest generated by `New-ReleaseBundleBuildMasterPackage` must declare the pinned database package version for this release
- Database units are assumed to be built/promoted via the separate `DatabaseChangePackage-5Stage.otter` pipeline

### 3. ReleaseBundle Integration Stage (Flyway Rehearsal)

Change from:
1. Unpack ReleaseBundle, run Flyway from embedded `db/migrations`

To:
1. Resolve the pinned database package version from the ReleaseBundle manifest
2. Download the database package from ProGet `database-*` feed
3. Unpack database package
4. Run Flyway from unpacked database package migrations

Update `Invoke-ReleaseBundleFlywayRehearsal.ps1`:
- Add parameter `-DatabasePackageVersion` (or resolve from manifest)
- Call `Resolve-DatabasePackageFeed` to determine the feed
- Download package from ProGet via `Invoke-RestMethod`
- Unpack via `Expand-DatabaseChangePackage`
- Invoke Flyway rehearsal against unpacked migrations

### 4. Installer Scripts (Install-Application.ps1, Update-Application.ps1)

Update to:
1. Read the release manifest
2. Resolve the compatible database package version (pinned or range)
3. Download from the appropriate `database-*` feed (based on operational tier)
4. Unpack database package
5. Run Flyway / seed loaders from unpacked package

### 5. ReleaseBundle Builder and Promotion Cmdlets

- `New-ReleaseBundleBuildMasterPackage.ps1`: do NOT embed database unit; read expected database version from app config or manifest
- `Promote-ReleaseBundleBuildMasterPackage.ps1`: no changes (still promotes through releasebundle feeds)
- New validation: ensure declared database package exists in the expected feed before allowing promotion

---

## Deferred to Future Sprints

1. **Multi-database support:** Current design targets single shared database per application. Multi-database (e.g., tenant-specific DBs) deferred per `Database-MultiDB-Future-Requirements.md`.

2. **Installer download resilience:** Strategies for handling network failures during database package download (fallback feeds, caching, offline install modes) deferred.

3. **Schema compatibility validation:** Detailed version-range matching and validation rules during install deferred. Current contract is simple range matching.

---

## References

- [Release-Bundle-Pipeline.md](Release-Bundle-Pipeline.md) — to be updated with database package consumption model
- [Database-Change-Unit-and-Flyway-Promotion.md](Database-Change-Unit-and-Flyway-Promotion.md) — database package creation
- [Database-Package-Consumer-Resolution.md](Database-Package-Consumer-Resolution.md) — consuming database packages by tier
- [Database-Package-Compatibility.md](Database-Package-Compatibility.md) — version compatibility rules
- [Immutable-Build-Strategy.md](Immutable-Build-Strategy.md) — build-once/promote-N pattern
- V4-E implementation evidence: `_generated/audit/v4-e/` ← 18 completed tasks, database package MVP delivered

---

## Acceptance Checklist (for future implementation tasks)

- [ ] V4-F04 — Document ReleaseBundle manifest schema update for database package references
- [ ] V4-F05 — Update Release-Bundle-Pipeline.md §2-4 to reflect separate database packages
- [ ] V4-F06 — Refactor ReleaseBundle builder to exclude database unit, reference compatible versions
- [ ] V4-F07 — Update Flyway rehearsal runner to download and unpack database packages
- [ ] V4-F08 — Update installer scripts to resolve and download database packages
- [ ] V4-F09 — Add validation: ReleaseBundle cannot promote if declared database package is absent
