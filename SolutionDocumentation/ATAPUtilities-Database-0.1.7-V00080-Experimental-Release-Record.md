# ATAPUtilities.Database 0.1.7 V00080 Experimental Release Record

## Outcome

`ATAPUtilities.Database` 0.1.7 was built once, published only to
`database-experimental`, rehearsed from the exact package, and applied to
`UTAT022\EXPWHERTZING\ATAPUtilities` on 2026-09-04. BuildMaster parent and target
executions completed successfully without warnings. Independent verification passed.

No Development, Integration, QA, or Production promotion or apply occurred. Version
0.1.7 is absent from `database-development`, `database-integration`, `database-qa`, and
`database-stable`.

## Immutable identity

- Package source commit: `ef3479f16829049142cf841d4592c6e9523dd005`.
- Documentation commit preceding it:
  `ebc97992279fc8ea0a40ff6e3fcdf8ac4f671065`.
- BuildMaster application: `ATAPUtilitiesDatabase` (1005).
- BuildMaster release: 10187, release number 0.1.7.
- BuildMaster build: 21349, build number 1.
- Pipeline: `DatabaseChangePackage-5Stage`.
- Package: `ATAPUtilities.Database.0.1.7.nupkg`.
- Package length: 43,469 bytes.
- Package SHA-256:
  `64C1942AC2CAE51450967A918CFBE939EB451CED4C4F1A728E1193B516FDBED6`.
- V00080 SHA-256:
  `F7BDAA9688D081DCD61E57466AFAD8AEDB1C256F0223BE6C9C8B5C2FE2B01763`.
- Experimental parent execution: 22021.
- Experimental target execution: 22022.

The independently downloaded package matched the captured BuildMaster artifact in
length and SHA-256. Its manifest identifies version 0.1.7, target V00080, and the exact
source commit above. The archive contains exactly seven migrations and eleven seed CSV
files, and every packaged SQL/CSV hash matches the committed 18-file allowlist.

## C-25 pre-live gate

The separately recorded, SELECT-only metadata inventory ran before the first live
mutation and passed:

- existing V00080 target-object collision count: zero;
- V00080 Flyway history rows: zero;
- failed Flyway history rows: zero;
- duplicate or unknown successful history rows: zero;
- predecessor history exactly V00010, V00030, V00040, V00050, V00060, and V00070;
- stale 0.1.7 rehearsal databases: zero;
- BuildMaster release 0.1.7 and ProGet package 0.1.7 absent;
- exact source, branch, application, target, feed, and SecretName checks passed.

## Recovery point

Before publication, a new pre-migration backup of the permanent Experimental database
was created at:

`C:\ProgramData\ATAP\DatabasePackageStaging\snapshots\ATAPUtilities\20260904_165729\ATAPUtilities_PREMIG_20260904_165730.bak`

- Backup length: 11,063,296 bytes.
- Backup SHA-256:
  `6792A8ACB4AB9C55C2084CD01AFE40DFCA2110A8D54D130E8D2677E2F8F4E2E5`.
- Recorded predecessor Flyway version: V00070.
- Helper-reported and independently calculated hashes matched.
- `RESTORE VERIFYONLY` passed.

The backup is retained. No restore was required or performed.

## Exact-package rehearsal and apply

BuildMaster restored/rehearsed the immutable package against
`ATAPUtilities-rehearsal-21349-Experimental`. The rehearsal migrated successfully from
the predecessor boundary and dropped its owned database. Only after rehearsal success
did target execution 22022 apply the package to the permanent Experimental database.

The BuildMaster trace records rehearsal success, permanent apply completion, and no
warning. Independent cleanup verification found no remaining database with the exact
rehearsal name.

## Independent verification

The independent verifier established:

- Flyway `validate` succeeded against the permanent database using the downloaded exact
  package;
- successful history is exactly V00010, V00030, V00040, V00050, V00060, V00070, and
  V00080;
- V00080 appears exactly once and failed history count is zero;
- all 15 V00080 tables, all 15 triggers, and
  `ATAPUtilities.ResolveBuildSetRulesAsOf` exist;
- the V00070 seven-table, two-table-type, four-procedure, seven-trigger, and two-role
  predecessor boundary remains present;
- parent execution 22021 and target execution 22022 are terminal-success, with no target
  warning indicator;
- the exact-package rehearsal database was removed;
- 0.1.7 exists only in `database-experimental`.

Committed-source regression before release discovered 106 tests: 98 passed, zero
failed, and eight database-gated tests skipped. The earlier authorized disposable gates
passed both fresh and V00070-upgrade paths with zero residue.

## Evidence and exclusions

The secret-safe evidence index is
`../_generated/Sprint0015/Task15.140/c/stream-a-v00080-experimental-release/release-evidence-index.md`.

No Flyway repair, package rebuild, package deletion, login/user/grant provisioning,
permanent restore, service deployment, endpoint action, or higher-tier action occurred.

The generic five-stage run context calculated `CeilingTier` as `Production` for this
non-prerelease version, so the package remains technically eligible for a separately
authorized future promotion. This execution was operationally bounded to Experimental:
only the Experimental parent and target executions exist, and independent feed checks
prove 0.1.7 is absent from all four higher feeds. No future promotion is authorized by
this release record.
