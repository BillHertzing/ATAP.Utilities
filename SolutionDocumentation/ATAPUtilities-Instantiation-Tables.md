# ATAPUtilities Instantiation Tables

Sprint 0012 Tasks 12.25 and 12.26 define the first database-backed model for
describing an ATAPUtilities instantiation and producing a manifestation from it.

## Current State

The existing `ATAPUtilities` schema already has RRSBS rule-instantiation tables:

- `RuleInstantiation` records one concrete application of a `Rule`.
- `RuleInstantiationBinding` records key/value inputs for that rule instance.
- The HelloWorld example uses those tables to render a small folder and file set.

Those tables are suitable for code-generation artifacts, but they do not model
the owned environment that an instantiation represents. Missing pieces are:

- organization identity;
- non-PII user membership;
- computer/hardware membership;
- repository membership and stable/sprint roots;
- PowerShell and library module membership;
- instantiation versions and diffs between versions;
- manifestation artifacts that renderers can consume without reverse-engineering
  the inventory tables.

## Target Model

The Sprint 0012 database change unit adds Philote-backed inventory tables and a
versioned manifestation layer:

- `Organization`
- `OrganizationUser`
- `Computer`
- `Repository`
- `SourceModule`
- `Instantiation`
- `InstantiationVersion`
- `InstantiationVersionComputer`
- `InstantiationVersionRepository`
- `InstantiationVersionSourceModule`
- `ManifestationArtifact`

The inventory tables describe durable things. The version tables describe which
things belong to a specific instantiation version. The manifestation table
describes concrete renderer outputs such as directories, module source folders,
module manifests, and reports.

## Effective-Dated Versioning

`V00.02.000100__Add_RRSBS_Effective_Dating.sql` makes temporal validity the
authoritative version contract for the RRSBS instantiation tree. Every
Philote-backed version and every membership/input row that participates in the
tree carries `EffectiveFrom` and `EffectiveTo` in UTC.

- A row is current exactly when `EffectiveTo IS NULL`.
- A logical parent can have exactly one current child version; filtered unique
  indexes enforce that invariant.
- `VersionNumber` and `VersionLabel` remain useful historical annotations, but
  neither determines which row is current.
- A revision closes the current row by setting `EffectiveTo` to the revision
  UTC timestamp, then inserts its successor with the same logical parent
  Philote ID, `EffectiveFrom` equal to that timestamp, and `EffectiveTo = NULL`.
- Published content is append-only. The only permitted update to a temporal
  RRSBS row is closing a previously open interval. Deletes, content rewrites,
  re-opening, and invalid/future close timestamps are rejected by triggers.

For example, a Rule revision retains `RulePhiloteId` as its durable identity:
the old `RuleVersion` is closed and a new `RuleVersion` is inserted with the
same `RulePhiloteId` and revised content/composition. The same pattern applies
upward through RuleSet, BuildSet, and Instantiation versions, and downward
through primitive-composition, membership, rule-instantiation, and input
binding records. Consumers select the current tree by filtering each temporal
relation on `EffectiveTo IS NULL`, or reconstruct an earlier tree with an
as-of timestamp predicate.

## Source Ingestion

Source ingestion should populate or update `SourceModule` rows from the
repository tree. For each module, the ingester should record:

- module name;
- module kind (`PowerShell`, `CSharp`, or `PlannedPowerShell`);
- source root relative path;
- manifest path, when a `.psd1` exists;
- public and private function folders, when present;
- whether the module is planned rather than present on disk.

The first implementation is
`src/ATAP.Utilities.DatabaseManagement.Powershell/public/Get-InstantiationSourceModuleInventory.ps1`.
It scans `src/`, normalizes relative paths, returns database-shaped
`SourceModule` rows, supports optional C# project discovery, and supports
caller-supplied planned PowerShell modules. It is read-only: SQL upsert behavior
remains a later layer, and any scan evidence must be written under `_generated/`.

## Renderer Contract

Renderers should consume `ManifestationArtifact` rows ordered by `SortOrder`.
Each row provides:

- the instantiation version;
- artifact kind (`Directory`, `ModuleSource`, `ModuleManifest`, `Report`);
- relative path;
- optional source object kind and Philote ID;
- render policy (`InspectOnly`, `RenderFromModel`, or `Planned`);
- optional content hash.

This keeps renderers independent from the physical table layout. A renderer can
materialize a folder tree, produce a report, or compare the model to the real
repository state using the same artifact list.

The first implementation is
`src/ATAP.Utilities.DatabaseManagement.Powershell/public/Export-InstantiationManifestation.ps1`.
It renders source-module model rows to `_generated/Instantiation` as model JSON,
source-file inventory JSON, folder-tree text, summary JSON, and a markdown
report. The renderer performs exact-case path checks so Windows' case-insensitive
filesystem behavior does not hide the v2 `Powershell` to `PowerShell` planned
layout correction.

## Versioned Seed

The first migration seeds `ATAP Utilities Sprint 0012` with two versions:

- **v1** represents the current organization, one non-PII user row, `utat022`,
  `UTAT01`, the `ATAP.Utilities` repository, and the existing
  `ATAP.Utilities.Security.Powershell` and `ATAP.Utilities.Secrets` modules.
- **v2** derives from v1, keeps the same organization/computer/repository
  membership, adds the planned `ATAP.Utilities.Secrets.PowerShell` module, and
  records the planned casing/layout correction for
  `ATAP.Utilities.Security.PowerShell`.

## Follow-On Work

Tasks 12.26.b through 12.26.e implemented the read-only scanner, renderer, and
v1/v2 manifestation evidence. Remaining follow-on outside the current slice is
the SQL persistence layer that upserts scanner output into the live
`ATAPUtilities.SourceModule` tables once the sprint SQL endpoint is available.
