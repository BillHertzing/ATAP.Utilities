# Task 13.82 — Instantiation package rehearsal

Status: complete. The Task 13.82.g operator approval was granted on
2026-07-30 for the exact package hash and `ExpWhertzing.ATAPUtilities` target.
Task 13.83 retains its independent final preflight and filesystem-write gates.

## Approved candidate

- Package: `ATAPUtilities.Database.0.1.1.nupkg`
- SHA-256:
  `02495D66DA6D640A39259E169DD230B6A49BD17627B67A4BDFD30EF758462448`
- Manifest target: `00.02.000110`
- Manifest entries: 66 (19 migrations and 47 seed-data files)
- Created from Git commit:
  `89a258667d97000bb61395c90379a2b9f4ebb02d`
- Intended deployment target after approval:
  `ExpWhertzing.ATAPUtilities`

The older 0.1.0 package and its `B01C...` hash are superseded. They stop at
`00.02.000060` and do not contain the completed corrected Instantiation slice.

## Gates

The expanded-package manifest, every declared file checksum, the release
package checksum, migration naming, and the non-destructive safety classification
passed. ScriptDom `TSql160Parser` parsed all 19 package migrations with zero
errors. The package builder tests passed; the direct manifest,
change-package, and safety functions returned valid/safe.

The broad legacy package-validation Pester file is not release evidence. It has
fixture defects (a `PSCustomObject` is passed to a `hashtable[]` parameter, one
manifest is written before its directory exists, and module-scoped mocks run
without importing the module). The package was therefore evaluated by the
functions themselves and by the exact rehearsals.

Seed idempotency is scoped to the new seed migration
`V00.02.000110__Seed_ATAPorg_Instantiation_V1.sql`. Its second execution on
both rehearsal shapes retained 75 source lines, eight snapshot members, five
planned artifacts, zero retired sample versions, and three deprecation markers.
Replaying the entire historical migration chain after `000100` is prohibited:
`000060` would try to recreate samples removed by `000080` without the later
required effective-date fields. Flyway's immutable schema history prevents that
unsupported replay.

## Exact rehearsals

The fresh rehearsal used a temporary SQL Express instance named
`REHEARSAL1382`, with an empty database named exactly `ATAPUtilities`. This was
required because the immutable bootstrap migration contains
`USE [ATAPUtilities]`. Flyway migrated the exact package from empty to
`00.02.000110`; verification reconstructed 75 source lines, the exact relative
path, 2,800 bytes, and SHA-256
`207425988293F2ACA9BAC4A9B72E7F18CA971EB3CF5AFE78FEB46130C219F63A`.
The database and temporary SQL instance were removed.

The current-state rehearsal used a copy-only backup of
`ExpWhertzing.ATAPUtilities`, restored as
`ATAPUtilities_Task1382_Current_Ephemeral`. Flyway applied the exact package
through `00.02.000110`. The read-only durable-schema verifier passed; zero
Sprint 0012 sample versions remain; three typed-membership deprecation markers,
75 source lines, eight snapshot members, and five artifacts were verified. The
database-to-temporary-root integration passed 1/1, and both the clone and
backup were removed.

## Adversarial review

The focused loader, inventory, renderer, and duplicate-identity suite passed
32/32. Negative controls reject missing, duplicate, undeclared, and
out-of-graph inputs; absent graphs; absolute paths; drive changes; parent
traversal; duplicate outputs; case-colliding outputs; and exact-byte hash
mismatch.

One deployed-schema limitation remains explicit: the older all-history
`UQ_ManifestationArtifact_Path` constraint prevents an effective-dated
successor row for the same path. The renderer therefore promotes the unique
planned artifact in place and no-ops an exact repeat. The isolated SQL E2E
proves this behavior, but a future schema migration should remove or replace
the older constraint before multiple historical artifact rows per path are
required.

No generic SQL instance named `Experimental` was created. The temporary
rehearsal name was `REHEARSAL1382`; after removal, UTAT022 retains only
Production, QA, Integration, DevWhertzing, and ExpWhertzing.

## Evidence

Generated, ignored evidence is under `_generated/InstantiationFix/13.82/` and
`_generated/database-packages/ATAPUtilities.Database.0.1.1/`:

- `Task-13.82-Fresh-Rehearsal.json`
- `Task-13.82-Current-Rehearsal.json`
- `Task-13.82-Fresh-Flyway.log`
- `Task-13.82-Current-Flyway.log`
- `db-release-unit-manifest.json`
- `package-evidence.json`
- `nupkg/ATAPUtilities.Database.0.1.1.nupkg`
