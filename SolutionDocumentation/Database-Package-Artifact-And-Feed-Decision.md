# Database package artifact and feed decision

**Scope:** Records the sprint-0007 sprint-owner decision for the artifact type,
ProGet feed family, package-id convention, and package-version convention used
to ship per-application database change units through the same immutable
build / promote pipeline that already governs C# packages and PowerShell
modules.
**Audience:** Anyone implementing V4-E04 (manifest schema), V4-E05
(`New-DatabaseChangePackage`), V4-E08 (BuildMaster DB-package plan), and
V4-E10 (publish/promote cmdlets); reviewers verifying the database feed
topology in ProGet; release engineers reasoning about DB promotions.
**Status:** Authoritative decision for sprint-0007. Implementation work is
owned by V4-E04, V4-E05, V4-E08, and V4-E10. This document is the *decision
record* only; it does not specify code, schema, or BuildMaster plan
internals.

**Companion docs:**

- [Database-Change-Unit-and-Flyway-Promotion.md](Database-Change-Unit-and-Flyway-Promotion.md)
  — the authoritative description of what a DB change unit physically is
  (Flyway migrations + repeatables + seed CSV + loader scripts + per-release
  YAML manifest).
- [Immutable-Build-Strategy.md](Immutable-Build-Strategy.md) — the build-once
  / promote-the-artifact policy this decision plugs into.
- [CSharp-Packages-Versioning.md](CSharp-Packages-Versioning.md) — the
  version-label / tier-ceiling pattern this decision mirrors.
- [PowerShell-Modules-Versioning.md](PowerShell-Modules-Versioning.md) — the
  sibling versioning pattern this decision mirrors.
- [ProGet-Install-Runbook.md](ProGet-Install-Runbook.md) — the operational
  runbook in which the five new `database-*` feeds are provisioned.

---

## 1. Decision

> **Database change units ship as NuGet packages of the NuGet content-package
> shape, pushed and promoted through a dedicated five-tier ProGet feed
> family named `database-experimental` / `database-development` /
> `database-integration` / `database-qa` / `database-stable`.**

The artifact type is a NuGet `.nupkg`. The payload is carried as
`contentFiles` (a content package), not as compiled `lib` assemblies. The
package is built **once** at the Experimental tier and promoted unchanged
through the five feeds, exactly as C# NuGet packages and PowerShell module
`.nupkg` files already are under the immutable-build strategy.

This decision answers the sprint-owner question recorded as Q4 in
[`_Planning/TASKS_V4.md`](../../_Planning/TASKS_V4.md) ("Open Decisions For
Sprint Owner") and unblocks the database-pipeline work items listed in §6
below.

---

## 2. Five feed names

The five permanent ProGet feeds for database content are:

- `database-experimental`
- `database-development`
- `database-integration`
- `database-qa`
- `database-stable`

These feeds follow the same naming pattern already used by `nuget-*` and
`powershellget-*`:

- One feed per tier — Experimental, Development, Integration, QA, Production.
- The Production-tier feed uses the `-stable` suffix (matching `nuget-stable`
  and `powershellget-stable`), so the literal feed name on disk is
  `database-stable` even though the canonical pipeline-side tier name is
  Production.
- The feeds are permanent topology, not created or torn down per sprint.

The feeds are NuGet-type feeds in ProGet (combined push + pull, anonymous
read, `X-ApiKey`-authenticated writes), exactly like the existing
`nuget-*` feeds. See [ProGet-Install-Runbook.md](ProGet-Install-Runbook.md)
for the access-policy and connector configuration.

---

## 3. Package-id convention

The package id is dotted NuGet-style, with the literal token `.Database`
identifying the package as a database content package for the named
application:

```text
<App>.Database
```

Concrete examples:

- `AceCommander.Database`
- `ATAPUtilities.Database`

This mirrors the convention already used to name the underlying DB change
unit (`<App>-db-<Version>` per
[Database-Change-Unit-and-Flyway-Promotion.md §1](Database-Change-Unit-and-Flyway-Promotion.md#1-the-release-unit-principle)).
The dotted form `<App>.Database` is preferred for the NuGet package id
because:

- It matches the existing `ATAP.Utilities.*` and `AceCommander.*` NuGet
  package-id conventions used in the `nuget-*` feeds.
- The hyphenated form `<App>-db-<Version>` carries the version inside the
  identifier, which would collide with NuGet's `(Id, Version)` identity
  rule. Putting the version in the NuGet `<Version>` field (per §4) and
  the identity in the package id keeps the two concerns separate.
- The token `.Database` is unambiguous in `Search-ProGetPackage` listings
  and in `PackageReference` declarations.

One database NuGet package corresponds to one application's DB change unit
for one release. If a single application ever needs multiple parallel
database content streams (e.g. main schema plus a reporting schema), the
naming convention extends to `<App>.<Stream>.Database`
(e.g. `AceCommander.Reporting.Database`). That extension is reserved; the
sprint-0007 implementation work only needs the single-stream form.

---

## 4. Package-version convention

Database content packages use **SemVer 2.0** version strings, computed by
NBGV from each application's database `version.json`, with the exact same
five prerelease labels already used by the C# and PowerShell ecosystems:

| Ceiling tier         | `version.json` label | Example package version | Promotes through                           |
| -------------------- | -------------------- | ----------------------- | ------------------------------------------ |
| Experimental         | `Sprint`             | `0.1.0-Sprint.42`       | Experimental only                          |
| Development          | `Alpha`              | `0.1.0-Alpha.7`         | Experimental, Development                  |
| Integration          | `Beta`               | `0.1.0-Beta.3`          | Experimental, Development, Integration     |
| QA                   | `QA`                 | `0.1.0-QA.1`            | Experimental, Development, Integration, QA |
| Production (=Stable) | _(none)_             | `0.1.0`                 | Experimental through Production            |

This matches
[CSharp-Packages-Versioning.md §3](CSharp-Packages-Versioning.md#3-the-five-tier-promotion-model)
and
[PowerShell-Modules-Versioning.md §5](PowerShell-Modules-Versioning.md#5-ceiling-tier-to-label-mapping)
verbatim. Database packages are not allowed to invent additional labels and
are not allowed to use any version shape that the C#/PowerShell pipelines
would refuse.

Specifically:

- The prerelease segment uses the **NuGet/SemVer 2.0 dot form**
  (`Sprint.42`, `Alpha.7`, `Beta.3`, `QA.1`) — the database package never
  needs the PowerShell-style alphanumeric-concatenated form
  (`Sprint042`), because NuGet itself accepts SemVer 2.0 prereleases.
- The version is computed **once** at Experimental from NBGV and stays
  identical across all five feeds; promotion is a metadata operation in
  ProGet and never re-evaluates `version.json`.
- The `+<gitshorthash>` build metadata is stripped from the `.nupkg`
  filename, exactly like the C# packages (see
  [CSharp-Packages-Versioning.md §6.4](CSharp-Packages-Versioning.md)).

The prerelease label is the **ceiling tier** for one immutable run, not the
current tier. See
[VersionJsonAsCeiling.md](VersionJsonAsCeiling.md) for the canonical Stage
× Ceiling matrix.

---

## 5. Rejected alternatives

### 5.1 Universal Packages (upack)

ProGet's Universal Package format (`.upack`) was considered as the artifact
type because the existing Release Bundle already ships as a Universal
Package (see
[Immutable-Build-Strategy.md §4](Immutable-Build-Strategy.md#4-proget-feed-per-tier-per-package-family))
and a DB change unit carries mixed-shape content (SQL files, CSV, YAML
manifest, optional PowerShell loaders) that fits Universal Packages
naturally. Universal Packages were rejected for the following reasons:

- **Pipeline consistency.** The C# package pipeline already uses
  `dotnet pack` + `Publish-NuGetPackageToProGet` + `Promote-ProGetPackage`,
  and the PowerShell module pipeline already uses `Publish-PSModuleToProGet`
  + `Promote-ProGetPackage`. Both push NuGet-format `.nupkg` files to
  NuGet-type feeds. Reusing that tooling for database content keeps the
  publish/promote code paths uniform across the three package families
  that flow through the per-package-family feeds, which simplifies
  `Promote-ProGetPackage`, the BuildMaster plans, and the ceiling-check
  logic.
- **Single push/promote shape.** A NuGet `.nupkg` carrying `contentFiles`
  is sufficient for the DB change unit payload. The package shape does not
  need to be `lib`-bearing, but the format itself is already supported by
  NuGet tooling, ProGet NuGet feeds, and the existing immutable-build
  promotion code.

What Universal Packages would have offered that NuGet content packages
do not:

- A first-class "non-package payload" identity (Universal Packages do not
  pretend to be a code library). The team chose to accept the slight
  semantic awkwardness of a NuGet content package carrying SQL rather than
  introduce a parallel publish/promote tool family.
- Slightly looser file-naming conventions inside the package. NuGet
  `contentFiles` carries its own pathing rules; the DB change unit layout
  must conform. This is a minor inconvenience that the implementation
  tasks (V4-E04 and V4-E05) will absorb.

The Release Bundle remains a Universal Package because it is itself a
multi-family bundle (app code + DB content + installer); the choice for the
per-application DB change unit is independent of that bundle decision.

### 5.2 Reusing the existing `nuget-*` feed family

Putting database content into the existing `nuget-*` feeds was considered
and rejected because:

- It would mix two distinct artifact families in one feed namespace,
  confusing `Search-ProGetPackage` listings and consumer restore policy.
- The tier-specific restore policy in
  [Immutable-Build-Strategy.md §11](Immutable-Build-Strategy.md#11-dependency-restoration-invariant)
  is keyed off feed family. Adding DB content to `nuget-*` would force
  every C#-package consumer's restore configuration to also resolve DB
  packages, which is operationally noisier than a dedicated `database-*`
  feed family.

A dedicated `database-*` feed family is therefore the chosen design.

---

## 6. Package contents

The authoritative description of what physically goes into a DB change
unit lives in
[Database-Change-Unit-and-Flyway-Promotion.md](Database-Change-Unit-and-Flyway-Promotion.md)
— specifically §2 (repository layout), §5 (DB instances by tier), and §8
(the DB sub-manifest format). This decision doc does not re-state that
content shape; it only records how that content is wrapped.

For reference, the NuGet content package's `contentFiles` will carry:

- `flyway/V*.sql` — versioned migration scripts.
- `flyway/R*.sql` — repeatable migration scripts.
- `seed/*.csv` — CSV seed / static-data files.
- `seed/*.sql` — SQL bulk-load / upsert loader scripts for the CSV seeds.
- `releases/<Version>.yml` — the per-release YAML manifest authored by the
  application owner (per
  [Database-Change-Unit-and-Flyway-Promotion.md §2](Database-Change-Unit-and-Flyway-Promotion.md#2-repository-layout)).
- `db-manifest.json` — the sidecar produced by `New-ReleaseManifest` with
  SHA-256 checksums for every payload file. This sidecar is what the
  consumer (the Release Bundle installer or a standalone Flyway run) reads
  to verify integrity before applying any migration.

The exact `contentFiles` pathing inside the `.nupkg`, the `.nuspec`
template, and the `New-DatabaseChangePackage` cmdlet that produces the
package are owned by V4-E05.

---

## 7. Promotion direction

Database packages follow the same immutable-build promotion model as
NuGet and PowerShellGet:

1. Built **once** at the Experimental tier by the same kind of BuildMaster
   plan that already publishes C# and PowerShell packages (V4-E08 owns the
   plan implementation).
2. Pushed to `database-experimental` with `--skip-duplicate` so partial
   runs are idempotent.
3. Promoted **unchanged** to `database-development`,
   `database-integration`, `database-qa`, and `database-stable` as each
   tier's gate passes. Promotion is a ProGet metadata operation
   (`POST /api/promotions/promote`), never a rebuild. See
   [Immutable-Build-Strategy.md §5](Immutable-Build-Strategy.md#5-what-promotion-is-and-is-not).
4. Ceiling enforcement: `Promote-ProGetPackage` reads the package's
   `CeilingTier` from its prerelease label (per §4 above) and refuses
   promotions above that ceiling, exactly as it already does for NuGet
   and PowerShellGet packages. The publish/promote cmdlet work in V4-E10
   wires this in.

The same `(PackageId, Version, SHA-256)` triple identifies the database
package across all five feeds at any time it is in transit between tiers.

---

## 8. Consumer feed mapping

A consumer at tier T may pull database packages from `database-T` and from
any tier above T (more stable). The table below mirrors
[Immutable-Build-Strategy.md §11.1](Immutable-Build-Strategy.md#111-required-c-restore-policy):

| Consumer tier | Enabled `database-*` sources for restore                                                                  |
| ------------- | --------------------------------------------------------------------------------------------------------- |
| Experimental  | `database-experimental`, `database-development`, `database-integration`, `database-qa`, `database-stable` |
| Development   | `database-development`, `database-integration`, `database-qa`, `database-stable`                          |
| Integration   | `database-integration`, `database-qa`, `database-stable`                                                  |
| QA            | `database-qa`, `database-stable`                                                                          |
| Stable        | `database-stable`                                                                                         |

The DB content package's id pattern (`<App>.Database`) is the matcher
used by the tier-specific NuGet source mapping. Source mappings for
`*.Database` should be pinned to the `database-*` feed family, just as
`ATAP.*` is pinned to `nuget-*` for the C# package family.

`nuget.org` is **not** added as a connector to any `database-*` feed.
There is no upstream public source of these packages and there should be
no fallback path for `*.Database` package ids.

---

## 9. Implementation owners

This document is **the decision doc** for V4-E02. The corresponding code
and operational work is owned by other tasks in the V4 epic:

| Task   | Scope                                                                                                                                          |
| ------ | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| V4-E04 | Authoritative DB change-unit manifest schema (`db-release-unit.schema.yaml`).                                                                  |
| V4-E05 | `New-DatabaseChangePackage` cmdlet — packs the DB change unit into a NuGet content `.nupkg` per the conventions in this doc.                   |
| V4-E08 | BuildMaster pipeline plan for the DB content package — mirrors the existing C# and PowerShell five-stage plans.                                |
| V4-E10 | Publish / promote cmdlets — `Publish-DatabaseChangePackageToProGet` and the database-aware additions to `Promote-ProGetPackage` (or a sibling). |

Any deviation from the package-id, version-label, feed-name, or
promotion-direction rules above must be raised as a new decision and
recorded against this document. The current text is the contract those
implementation tasks build to.

---

## 10. Related documents

- [Database-Change-Unit-and-Flyway-Promotion.md](Database-Change-Unit-and-Flyway-Promotion.md)
  — the authoritative description of what a DB change unit physically is.
- [Immutable-Build-Strategy.md](Immutable-Build-Strategy.md) — the
  build-once / promote-the-artifact policy.
- [CSharp-Packages-Versioning.md](CSharp-Packages-Versioning.md) — the
  C# version-label / tier-ceiling pattern this decision mirrors.
- [PowerShell-Modules-Versioning.md](PowerShell-Modules-Versioning.md) —
  the PowerShell sibling pattern this decision mirrors.
- [VersionJsonAsCeiling.md](VersionJsonAsCeiling.md) — the canonical
  cross-ecosystem ceiling narrative.
- [Database-Package-Ceiling-File.md](Database-Package-Ceiling-File.md) —
  defines `database-package-ceiling.json`, the consumer-side file that caps the
  highest `database-*` feed a branch or release lane may resolve from.
- [ProGet-Install-Runbook.md](ProGet-Install-Runbook.md) — the operational
  runbook that provisions the five `database-*` feeds.
- [Release-Bundle-Pipeline.md](Release-Bundle-Pipeline.md) — the pipeline
  that bundles the DB change unit with app code into the final installer.
- [BuildMaster-Pipeline-Topology.md](BuildMaster-Pipeline-Topology.md) —
  the BuildMaster pipeline catalog that the V4-E08 DB plan will join.
