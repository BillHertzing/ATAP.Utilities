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

## Source Ingestion

Source ingestion should populate or update `SourceModule` rows from the
repository tree. For each module, the ingester should record:

- module name;
- module kind (`PowerShell`, `CSharp`, or `PlannedPowerShell`);
- source root relative path;
- manifest path, when a `.psd1` exists;
- public and private function folders, when present;
- whether the module is planned rather than present on disk.

The first implementation can be a PowerShell function in the database or
rules-management tooling that scans `src/`, normalizes relative paths, and
writes inventory rows. It must not write generated output outside `_generated/`.

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

Tasks 12.26.b and 12.26.c remain the implementation follow-on:

- build the source ingester that updates `SourceModule` from repository
  source;
- build renderers that consume `ManifestationArtifact`;
- add tests that compare v1 artifacts with the real repository state and verify
  the v1-to-v2 module diff.
