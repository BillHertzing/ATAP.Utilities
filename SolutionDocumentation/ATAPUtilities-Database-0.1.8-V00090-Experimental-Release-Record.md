# ATAPUtilities.Database 0.1.8 V00090 Experimental Release Record

## Outcome

`ATAPUtilities.Database` 0.1.8 was published only to `database-experimental`, rehearsed
from the exact authorized package, and applied to
`UTAT022\\EXPWHERTZING\\ATAPUtilities` on 2026-09-04. BuildMaster parent and target
executions completed successfully without warnings. Independent verification passed.

No Development, Integration, QA, or Production promotion or apply occurred. Version
0.1.8 is absent from `database-development`, `database-integration`, `database-qa`, and
`database-stable`.

## Immutable identity

- Source commit: `5e67010ec92dcb1cbd6697ea00eed2ea655845bc`.
- BuildMaster application: `ATAPUtilitiesDatabase` (1005).
- BuildMaster release: 10191, release number 0.1.8.
- BuildMaster build: 21350, build number 1.
- Pipeline: `DatabaseChangePackage-5Stage`.
- Package: `ATAPUtilities.Database.0.1.8.nupkg`.
- Package length: 49,685 bytes.
- Package SHA-256:
  `1B2C6BA88088A4B02060BF7CA704ACB532AF01888AB874A3D511F8B72ED80AE8`.
- V00090 SHA-256:
  `34A0EC2A1CE485BECBC0497BD4A726BFEC45CD2DBA7D39E26A753A8A6C594DEB`.
- Experimental parent execution: 22023.
- Experimental target execution: 22024.

The authorization initially transcribed the package name with an extra dot after
`ATAP`. Execution paused fail-closed until the user explicitly confirmed the package ID
and file name shown above with the frozen SHA-256.

Independent archive inspection verified all 19 allowlisted database payloads against
committed source and the embedded manifest, with zero missing, extra, or mismatched
entries. The manifest identifies version 0.1.8, target V00090, and the exact source
commit above.

## Exact-byte safeguard

A second package build from the same committed inputs produced a 49,687-byte container
with a different SHA-256. The payload was deterministic but the NuGet container was not
byte-reproducible. The release therefore did not rebuild and silently substitute bytes.
It published the frozen package, independently downloaded and re-hashed it, and seeded
BuildMaster's supported immutable-package resume context so the Experimental stage used
the exact authorized 49,685-byte artifact.

## C-25 pre-live gate

The final SELECT-only gate ran immediately before the first live mutation and passed:

- zero V00090 target-object collisions and zero V00090 history rows;
- zero failed, duplicate, or unknown Flyway rows;
- predecessor history exactly V00010 through V00080;
- zero stale rehearsal databases;
- BuildMaster release 0.1.8 and ProGet package 0.1.8 absent;
- exact source, package, branch, application, target, feed, and SecretName checks.

## Recovery point

Before publication, a new full backup was created at:

`C:\ProgramData\ATAP\DatabasePackageStaging\snapshots\ATAPUtilities\20260904_183231\ATAPUtilities_PREMIG_20260904_183232.bak`

- Backup length: 11,915,264 bytes.
- Backup SHA-256:
  `10BBA998BF4C77FC440CECAC171C950D267ACDC2E5A5BED88247530D35427D0E`.
- Recorded predecessor Flyway version: V00080.
- Helper-reported and independently calculated hashes matched.
- `RESTORE VERIFYONLY` passed.

The backup is retained. No permanent restore was required or performed.

## Exact-package rehearsal and apply

BuildMaster used the exact published artifact to create, migrate, and drop
`ATAPUtilities-rehearsal-21350-Experimental`. Only after that rehearsal succeeded did
target execution 22024 apply the package to the permanent Experimental database. The
final rehearsal-residue count is zero.

## Independent verification

The independent verifier established:

- the downloaded Experimental package is exactly 49,685 bytes with the frozen SHA-256;
- Flyway `validate` succeeded and history is exactly V00010 through V00090;
- V00090 appears exactly once, with zero failed, duplicate, or unknown rows;
- all four tables, four procedures, five triggers, one table type, the deprecation
  column, and four V00090 indexes exist;
- all nine relation roles, both classification-only endpoint types, two Tags, two Tag
  states, and two deterministic assignments exist;
- assignment and logical-edge query procedures expose the committed result shapes, and
  the Rule assignment query returns `RRSBS_RULE_DEFINITION`;
- the V00080 and V00070 predecessor boundaries remain present;
- parent execution 22023 and target execution 22024 are terminal-success without target
  warnings;
- 0.1.8 exists only in `database-experimental` and no rehearsal database remains.

The adversarial synthetic unknown-version fixture is V01000. Pre-release focused tests
passed 50/50, and the separately authorized disposable fresh/V00080-upgrade gates passed
12/12 with zero residue.

## Evidence and exclusions

The secret-safe evidence index is
`../_generated/Sprint0015/Task15.50/c/stream-a-v00090-experimental-release/release-evidence-index.md`.

No Flyway repair, package deletion, login/user/grant provisioning beyond migration-
defined objects, permanent restore, higher-tier promotion, or checkpoint action
occurred.

The generic five-stage context calculated a Production capability ceiling because
0.1.8 is a stable version. That capability does not authorize promotion. Only the
Experimental parent and target executions exist for this release, and independent feed
checks prove 0.1.8 is absent from all four higher feeds.
