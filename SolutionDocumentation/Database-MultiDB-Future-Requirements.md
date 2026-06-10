# Multi-Database and AceCommander Future Requirements

**Status:** Forward-looking. Not implemented in Sprint 0007.
**Source task:** V4-E16 / DBA2-T06.

This document records the multi-database scope deliberately deferred from
the Sprint 0007 database pipeline implementation, so future sprints can
extend the pipeline without re-deriving the design.

---

## Current implementation targets `ATAPUtilities` only — by design

The Sprint 0007 implementation ships a single 5-tier database promotion
pipeline whose first (and only) target is the `ATAPUtilities` database.
This is deliberate, not a limitation:

- The pipeline contract (`DatabaseChangePackage-5Stage.otter`, the
  `Invoke-DatabasePackageBuildMasterStage.ps1` runner, the
  `database-experimental` → `database-stable` feed family) needs to be
  exercised end-to-end on a known, stable target before being generalised
  across multiple databases.
- The `ATAPUtilities` database is the only database whose schema and
  Flyway lifecycle is fully owned by this repo today.
- Multi-tenancy concerns (per-user AceCommander databases, parallel
  migration of many tenant DBs) introduce orchestration shape that is
  best designed once the single-DB contract is proven in production.

`ATAPUtilities` is therefore the canonical example, not a special case.
Every contract documented in
`Database-Package-Artifact-And-Feed-Decision.md`,
`Database-Package-Consumer-Resolution.md`, and
`Database-Package-Compatibility.md` is intended to extend to additional
databases without redesign.

---

## AceCommander per-user database evolution

AceCommander is multi-tenant: each tenant gets its own database. The
shape that future sprints will need to support:

- **Package naming convention.** The package id will be
  `AceCommander.Database` while the underlying schema is single-tenant.
  When per-tenant schemas diverge (tenant-specific extensions, isolated
  identity columns), a future per-tenant suffix will be needed; the
  exact suffix shape (e.g. `AceCommander.Database.<TenantId>`, or a
  per-tenant `Stream` value passed to
  `Get-DatabasePackageBuildContext`) is **TBD** and will be settled when
  the first tenant-specific migration ships.
- **Tenant lifecycle.** New tenants need their database created from a
  known seed at the highest tier the lane allows (typically
  `database-stable`). Tenant teardown needs a safe rollback equivalent
  to `Restore-DatabaseFromSnapshot` at a tenant scope.
- **Schema migration.** Tenant DB migrations run against many DBs of
  the same schema. The orchestration shape — sequential, fan-out, or
  staggered with per-tenant ceiling files — is **deferred**. Sprint
  0007's single-DB runner does not yet model the fan-out.
- **Per-user data isolation.** A single physical SQL Server instance
  may host many tenant DBs. Migrations must not cross tenant
  boundaries. The pre-migration snapshot taken by
  `New-DatabasePreMigrationSnapshot` (DBA1) is per-DB and already
  composes correctly with a tenant fan-out, but the rehearsal harness
  will need to validate the cross-tenant case explicitly.

---

## Multi-stream databases

The `Get-DatabasePackageBuildContext` cmdlet already accepts an optional
`-Stream` parameter that resolves the package id to
`<Application>.<Stream>.Database` and the source folder to
`Database/<Application>/<Stream>/`. This is reserved for multi-stream
databases (e.g. a single product with separate `Reporting`, `Tags`, and
`Workspace` schemas that ship independently) but is **not yet used**.

When the first multi-stream database ships:

- Each stream gets its own `version.json` under the stream sub-folder.
- Each stream is published as a distinct package id and promoted
  independently through `database-*` feeds.
- The ceiling file (`database-package-ceiling.json`) currently sits at
  `Database/<App>/` — single-stream scope. A per-stream ceiling needs
  to be designed (likely
  `Database/<App>/<Stream>/database-package-ceiling.json` with the
  application-level file removed) before the first multi-stream
  rollout. The current `Promote-DatabaseChangePackage` ceiling lookup
  walks to `Database/<App>/database-package-ceiling.json`; it must be
  extended for streams in tandem.

---

## AceCommander database schema lifecycle

The future-state AceCommander schema lifecycle, when multi-tenant ships,
will need to address:

| Concern | Sketch |
| --- | --- |
| Tenant creation | Apply current `database-stable` package to a freshly created per-tenant DB. Seed initial reference data. |
| Schema migration | Promote a new `AceCommander.Database` version through the 5-tier feeds, then fan out the migration across every tenant DB. Each tenant gets its own rehearsal + pre-migration snapshot. |
| Per-user data isolation | A migration that adds a column must not enumerate or read user data across tenants. Migrations remain Flyway-driven so this constraint inherits from Flyway's per-DB scope. |
| Tenant teardown | Snapshot the tenant DB, drop it, archive the snapshot. The snapshot is the system of record after teardown. |
| Tenant migration parallelism | TBD. A migration that takes 30 seconds across 1,000 tenants must not run for 8 hours serially. Likely a configurable per-tier concurrency limit, with the ceiling file gating risky tiers to single-tenant rollout. |

---

## Known gaps deferred to future sprints

The following work is explicitly out of scope for Sprint 0007 and is
recorded here so a later sprint plan can pick it up without rediscovery:

- **Multi-tenant migration orchestration.** No cmdlet today fans
  `Promote-DatabaseChangePackage` (or the underlying Flyway run) across
  many tenant DBs. Future cmdlet name suggestion:
  `Invoke-DatabasePackageTenantFanout`.
- **Parallel migration of many tenant DBs.** No throttling, no
  partial-failure model, no tenant-by-tenant evidence aggregation.
- **Tenant-specific ceiling files.** The current single ceiling per
  application database is insufficient when one tenant is on a slow
  upgrade lane.
- **Cross-tenant rehearsal harness.** The current rehearsal harness is
  per-DB. Future work needs a rehearsal scaffold that exercises the
  migration across a representative mix of tenant data shapes.
- **Tenant-level rollback readiness.** `Test-DatabaseRollbackReadiness`
  currently runs against one DB. A tenant fan-out variant is needed
  before multi-tenant production migrations begin.

---

## Cross-references

- [Database Package Artifact and Feed Decision](Database-Package-Artifact-And-Feed-Decision.md)
- [Database Package Consumer Resolution](Database-Package-Consumer-Resolution.md)
- [Database Package Compatibility](Database-Package-Compatibility.md)
- [Database Package Ceiling File](Database-Package-Ceiling-File.md)
