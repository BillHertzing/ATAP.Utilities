# Database Package Ceiling File

**Scope:** Defines the source-controlled file that caps the highest database
package feed a branch or release lane may consume while building, testing, or
assembling an application/release bundle.
**Audience:** BuildMaster plan authors, release engineers, database package
implementers, and application-package consumers.
**Status:** Sprint-0007 V4-E03 decision.

**Companion docs:**

- [Database Package Artifact and Feed Decision](Database-Package-Artifact-And-Feed-Decision.md)
  - database packages are NuGet content packages in the `database-*` feed
  family.
- [version.json as Promotion Ceiling](VersionJsonAsCeiling.md) - the producer
  artifact promotion ceiling derived from NBGV.
- [Database Change Unit and Flyway Promotion](Database-Change-Unit-and-Flyway-Promotion.md)
  - the physical DB change unit payload.
- [schemas/database-package-ceiling.schema.json](schemas/database-package-ceiling.schema.json)
  - the machine-readable schema for this file.

---

## Decision

The file name is:

```text
database-package-ceiling.json
```

The canonical location is the database package root, next to that package's
`version.json` and release-unit manifests:

```text
Database/<App>/database-package-ceiling.json
Database/<App>/version.json
Database/<App>/releases/<Version>.json
```

Future multi-stream database packages use one file per stream:

```text
Database/<App>/<Stream>/database-package-ceiling.json
Database/<App>/<Stream>/version.json
Database/<App>/<Stream>/releases/<Version>.json
```

During the current ATAPUtilities single-stream transition, cmdlets may accept an
explicit `-DatabasePackageCeilingPath` pointing at the repo's current
`Database/` layout. New implementation work should prefer the per-app layout
above.

---

## What The File Means

`database-package-ceiling.json` is a **consumer ceiling**. It answers:

> What is the highest database package feed this branch/lane is allowed to
> consume from?

It does **not** replace `version.json`.

| File | Owner | Meaning |
| --- | --- | --- |
| `version.json` | package producer | Highest tier the newly built immutable database package may be promoted to. |
| `database-package-ceiling.json` | package consumer/lane | Highest `database-*` feed this branch/lane may resolve from while restoring, testing, or bundling a database package. |

The two values normally move together, but they answer different questions. A
BuildMaster database package producer reads `version.json` to decide whether a
package may promote beyond Experimental. A release bundle or app-package
consumer reads `database-package-ceiling.json` to decide whether it may resolve
from `database-integration`, `database-qa`, or `database-stable`.

---

## Schema Summary

The schema id is:

```text
https://atap.example.com/schemas/database-package-ceiling/v1.json
```

Required properties:

| Property | Purpose |
| --- | --- |
| `schemaVersion` | Must be `1`. |
| `fileKind` | Must be `database-package-ceiling`. Prevents accidental use of another JSON file. |
| `branchKind` | One of `sprint`, `feature`, `integration`, `qa`, `release`, `hotfix`. |
| `branchName` | Human-readable branch or lane name. |
| `packageId` | Database package id, e.g. `ATAPUtilities.Database` or `AceCommander.Database`. |
| `maxConsumableTier` | Highest canonical tier this lane may consume: `Experimental`, `Development`, `Integration`, `QA`, or `Production`. |
| `maxConsumableFeed` | Feed name matching `maxConsumableTier`: `database-experimental`, `database-development`, `database-integration`, `database-qa`, or `database-stable`. |
| `versionJsonPrereleaseLabel` | Expected `version.json` prerelease label for the lane, or `null` for stable/release lanes. |
| `reason` | Short human-readable justification. |

Optional properties:

| Property | Purpose |
| --- | --- |
| `owner` | Responsible person, group, or automation owner. |
| `effectiveUtc` | UTC timestamp when the ceiling became effective. |
| `expiresUtc` | UTC timestamp when a temporary ceiling should be revisited; use `null` for no planned expiry. |
| `notes` | Free-form operator notes. |

The schema enforces the `maxConsumableTier` -> `maxConsumableFeed` mapping. For
example, `maxConsumableTier = QA` requires `maxConsumableFeed = database-qa`.
The Production tier maps to the stable feed name `database-stable`.

---

## Branch/Lane Examples

Example files live under `SolutionDocumentation/schemas/examples/`.

| Branch/lane kind | Example file | Typical ceiling |
| --- | --- | --- |
| Sprint branch | `database-package-ceiling-sprint.example.json` | Experimental |
| Feature branch | `database-package-ceiling-feature.example.json` | Experimental |
| Integration branch/lane | `database-package-ceiling-integration.example.json` | Integration |
| QA branch/lane | `database-package-ceiling-qa.example.json` | QA |
| Release branch | `database-package-ceiling-release.example.json` | Production (`database-stable`) |
| Hotfix branch | `database-package-ceiling-hotfix.example.json` | Production (`database-stable`) |

Hotfix branches start from the released Production baseline, so their consumer
ceiling normally allows `database-stable`. A hotfix rehearsal lane may lower
this to `QA` while a candidate is still under validation, but the production
hotfix branch must not silently consume an Experimental or Development-only DB
package.

---

## Resolver Rules

The first implementation of the database package resolver should:

1. Load `database-package-ceiling.json`.
2. Validate it against `schemas/database-package-ceiling.schema.json`.
3. Verify the `packageId` matches the requested database package.
4. Resolve `maxConsumableTier` to `maxConsumableFeed`.
5. Refuse to resolve any database package from a feed above the ceiling.
6. Record the loaded file path, package id, max tier, max feed, and branch kind
   in BuildMaster run evidence.

The file is source-controlled and must not contain secrets. It is safe to copy
into evidence bundles.

---

## Minimal Example

```json
{
  "schemaVersion": 1,
  "fileKind": "database-package-ceiling",
  "branchKind": "sprint",
  "branchName": "100-Sprint-0007-work-items",
  "packageId": "ATAPUtilities.Database",
  "maxConsumableTier": "Experimental",
  "maxConsumableFeed": "database-experimental",
  "versionJsonPrereleaseLabel": "Sprint",
  "reason": "Sprint work may consume only Experimental database packages until promoted."
}
```

---

## Open Follow-Up Work

- V4-E06 should add cmdlet-level ceiling validation that loads this file and
  rejects package/feed mismatches.
- V4-E08 should persist the loaded ceiling file values into
  `_generated/buildmaster/<BuildMasterBuildId>/build-context.json`.
- V4-E11 should teach database package consumers to use this file when choosing
  `database-*` feed sources.
- V4-D07 should reconcile this database-specific consumer ceiling with the
  broader root vs per-project `version.json` policy.

