# ATAPUtilities Database 0.1.3 Release Record

Date: 2026-07-30  
BuildMaster application: `ATAPUtilitiesDatabase`  
Release/build: `0.1.3` / `1` (`ReleaseId 9086`, `BuildId 20217`)  
Package: `ATAPUtilities.Database` `0.1.3`

## Sprint 0014 provenance boundary

Sprint 0014 Task 14.104 closes Task 13.78 as superseded. This release record is
the authoritative repository provenance for the completed legacy `V00.*` lineage;
it is not an instruction to repeat the build, publication, promotion, tier apply,
or checksum repair.

Task 14.20 owns the isolated RRSBS V2 lineage beginning at package `0.0.1`,
baseline `00010`, and a separate Flyway history table. Task 14.30 owns
ContentSummary under the sequencing and model decisions established by Task 14.20.
The completed 0.1.3 release and checksum reconciliation remain evidence inputs to
those programs, not open implementation steps.

## Outcome

BuildMaster built, tested, packaged, promoted, snapshotted, and deployed one
immutable database package through its five logical stages. The exact package is
present in all five ProGet `database-*` feeds. The stable download is byte-for-byte
identical to the BuildMaster artifact:

- length: `115463` bytes;
- SHA-256: `f201de23f69270ec82a19f1921f011eab89511489fde5781a4f89fb617d5bce4`;
- manifest source: git `261514c21d09401bcf1f9f368d54e04f8dfde064`;
- manifest target: `00.02.000140`.

The ephemeral Experimental database and the permanent Development, Integration,
QA, and Production databases independently report eight successful release
migrations and head `00.02.000140`. Deferred ContentSummary migration
`V00.02.000120__Add_ContentSummary_Rule_Kind.sql` is absent from the package,
manifest, and every authorized tier.

> **Instance-naming correction (2026-08-08):** Here, Experimental names only
> the logical release/database role. It is not a physical SQL Server instance
> name. Developer-scoped instances follow `Exp<DeveloperName>`;
> `localhost\Expwhertzing` is the specific instance for developer `whertzing`.

## Migration boundary

Included:

- `00.02.000060` — Instantiation manifestation tables;
- `00.02.000070` — durable versioned RRSBS snapshots;
- `00.02.000080` — typed-membership migration and sample retirement;
- `00.02.000090` — RulePrimitive/Rule identity invariant;
- `00.02.000100` — RRSBS effective dating;
- `00.02.000110` — ATAPorg Instantiation V1;
- `00.02.000130` — Markdown Rule Kind;
- `00.02.000140` — ATAPorg Instantiation V2 Markdown.

Excluded:

- `00.02.000120` — ContentSummary Rule Kind. This was an inadvertent/deferred
  migration whose remaining database entities belong to the next sprint.

## Stage results

| Stage | Parent/target execution | Result | Notes |
| --- | --- | --- | --- |
| Experimental | `20578` target | success | Published to `database-experimental`, then applied to the approved ephemeral `localhost\Expwhertzing` database; head `00.02.000140`. `Expwhertzing` is the `whertzing` realization of `Exp<DeveloperName>`; a physical SQL instance named `Experimental` is retired and must not be recreated. |
| Development | `20595` / `20596` | success | Real apply reached `00.02.000140`. |
| Integration | `20599` / `20600` | success | Retry resumed after prior ProGet promotion; snapshot and real apply succeeded. |
| QA | `20601` / `20602` | success | Snapshot, rehearsal, promotion, and real apply succeeded. |
| Production | `20605` / `20606` | success | Succeeded after documented legacy checksum reconciliation. |

## Production checksum reconciliation

The first Production attempt (`20603` / `20604`) stopped during clone rehearsal,
before ProGet promotion or real apply. Flyway found checksum drift in legacy
migrations `00.01.000022` and `00.01.000023`.

Git commit `c682e197b` had changed those already-applied loaders on 2026-07-26.
Development, Integration, and QA histories already held the new checksums;
Production still held the original checksums.

Before repair, a verified full Production backup was created:

- file:
  `C:\ProgramData\ATAP\DatabasePackageStaging\snapshots\ATAPUtilities\20260730_201409\ATAPUtilities_PREMIG_20260730_201410.bak`;
- size: `7.988 MB`;
- SHA-256:
  `a2d4660fe4154c54685a0928dd6eb53748e3548ef05ed9d4484004ab6d1a2e2b`;
- Flyway head at backup: `00.02.000040`.

`flyway repair` then ran against Production with the exact `0.1.3` package.
Only the two expected history checksums were reconciled, after which the entire
Production stage was rerun successfully.

Important limitation: repair updates schema history; it does not execute changed
legacy migration text. Future changes to applied migrations must be expressed as
new forward migrations.

## Pipeline defects fixed during the release

- source-bound database/package/ProGet commands prevent installed older modules
  from shadowing current contracts;
- explicit ProGet base URL supports no-profile service execution;
- package identity remains separate from SQL database identity;
- secret-based and host-based rehearsal parameter sets no longer mix;
- shared package/backup staging supports SQL Server access and `BULK INSERT`;
- rehearsal clones current tier state through copy-only backup/restore;
- local dbatools connections explicitly trust the approved local certificate;
- native Flyway output no longer contaminates structured PowerShell results;
- snapshot accepts the connection-string secret contract, uses the shared staging
  root, and returns the pipeline `SnapshotPath`;
- ProGet promotion retries succeed when the exact artifact is already present in
  the destination after a partially completed stage.
- every stage now fails closed before publish/promotion when its database
  connection-secret name is absent or apply is bypassed; publish/promotion must
  precede the exact-package database apply, and completion follows apply.

## Evidence

Generated evidence is under `_generated/DatabaseRelease/0.1.3/`, including:

- `Final-Tier-Flyway-Audit.json`;
- `Final-ProGet-Feed-Audit.json`;
- `ProGet-Stable-Package-Audit.json`;
- `LegacyChecksumComparison.json`;
- `Production-LegacyChecksumRepair-Snapshot.json`;
- BuildMaster deployment JSON and transcripts;
- focused Pester transcripts.

The reusable procedure and failure catalog were promoted to the canonical
SharedVSCode skill `.ai/skills/build-deploy-database` in commit `f98f800`.
