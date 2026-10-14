# ATAPUtilities.Database 0.1.4 V50 Experimental release record

Date: 2026-08-31  
Authorized tier: Experimental only

## Release identity

- Package: `ATAPUtilities.Database` `0.1.4`
- ProGet feed: `database-experimental`
- BuildMaster application: `ATAPUtilitiesDatabase` (`1005`)
- Release/build: `10179` / `21333` (`0.1.4` / build `1`)
- Successful Experimental execution: `21943`
- SQL target: `ATAPUtilities` on `utat022\EXPWHERTZING`
- Captured and published package length: `26288` bytes
- Captured and published SHA-256:
  `58750DE4C2EBFB33C0FF689FD0A49E9B92A474226BB9C1DC1BF717EB39246FB8`

The package contains exactly V00010, V00030, V00040, V00050, and the eleven
canonical seed CSV files. V00030 is retained as historical schema continuity;
its prototype table is planned for removal during a future V00010 core-schema
rewrite.

## Recovery point

Before migration, a full backup was created at:

`C:\ProgramData\ATAP\DatabasePackageStaging\snapshots\ATAPUtilities\20260831_091048\ATAPUtilities_PREMIG_20260831_091103.bak`

- size: `7.988 MB`;
- SHA-256:
  `8D59065CBA57CC97B0BBEEA7E79067096A4BD6FA14A44F2186F7B492CFCDCAF2B`;
- SQL Server `RESTORE VERIFYONLY`: valid;
- pre-migration Flyway history: successful V00010 and V00030 only.

The backup helper reported the Flyway version as `unknown` because its TCP
connection path could not resolve the named instance. Independent `sqlcmd`
verification through `.\EXPWHERTZING` established the pre-migration history and
the backup validity. The backup set does not contain SQL Server backup checksums,
so `RESTORE VERIFYONLY WITH CHECKSUM` is not applicable.

## Deployment outcome

Initial execution `21941` built and published the immutable package, then failed
before migration because `UTAT022\SvcBuildmaster` no longer had a database user
in `ATAPUtilities`. No V00040/V00050 history row existed at that point.

The lifecycle-bound operational grant documented by the previous Experimental
release was restored only in this database: a user for the existing Windows
login and membership in `db_owner`. The same BuildMaster build was redeployed.
The retry contract reused the captured package, skipped build and publication,
and succeeded as execution `21943`.

## Independent validation

- ProGet download and captured package are byte-identical at the length and hash
  above.
- Flyway history contains four successful rows: V00010, V00030, V00040, and
  V00050; failed-row count is zero.
- V00040 constraint
  `UQ_PhiloteValidityPeriod_PhiloteId_PhiloteValidityPeriodId` exists.
- V00050 objects exist in schema `ATAPUtilities`: six `Tag*` tables,
  `CreateTagNamespace`, `RetractTag`, and `ResolveTagAsOf`.
- A read-only missing-tag call to `ResolveTagAsOf` returned `Inactive`, hop 0.
- Tag tables remain empty, as expected; no seed tags were introduced.

No package promotion or database deployment to Development, Integration, QA,
or Production was authorized or performed.

## Evidence

Point-in-time evidence is under
`_generated/Sprint0015/Task15.140/c/T2/experimental-release/`.
