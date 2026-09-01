# ATAPUtilities.Database 0.1.5 V60 Experimental release record

Date: 2026-08-31  
Authorized tier: Experimental only

## Release identity

- Source commit: `09385b5a5611de188a639f45bc888ddaee06cb63`.
- Package: `ATAPUtilities.Database` `0.1.5`.
- ProGet feed: `database-experimental`.
- BuildMaster application: `ATAPUtilitiesDatabase` (`1005`).
- Pipeline: `DatabaseChangePackage-5Stage`.
- Release/build: `10183` / `21338` (`0.1.5` / build `1`).
- Parent/target executions: `21974` / `21975`; both completed successfully.
- SQL target: `ATAPUtilities` on `utat022\EXPWHERTZING`.
- Captured and independently downloaded package length: `30,573` bytes.
- Captured and independently downloaded SHA-256:
  `C234C3561D1833D58E4C621CBC8DACADD2AD72CEC12BD4FBB7334CE4576135A2`.

The immutable package contains exactly V00010, V00030, V00040, V00050,
V00060, and the eleven canonical seed CSV files. The packaged V00060 SHA-256
is `953705FEE9678B532FFF52D780182AA8A7EF3D000DB96873DB9EB58AAAEB46FB`.

## Recovery point

Before release creation, a non-overwriting full backup was created at:

`C:\ProgramData\ATAP\DatabasePackageStaging\snapshots\ATAPUtilities\20260831_185714\ATAPUtilities_PREMIG_20260831_185714.bak`

- length: `8,769,536` bytes;
- SHA-256:
  `B42EEF50C26A179CC52A7BFB9890AAABAA21DDF6932DF794A8DE3988068AC7EB`;
- independent SQL Server `RESTORE VERIFYONLY`: valid;
- pre-migration Flyway head: successful V00050 with zero failed rows.

No restore or Flyway repair was required.

## Deployment outcome

The amended Experimental runner published the immutable package, cloned the
current target through backup/restore, migrated the clone with the exact
package, dropped the clone, and only then applied the same package to the
permanent Experimental database. The runner records `Created=true`,
`Dropped=true`, rehearsal `Success=true`, an apply marker, and a completion
marker. A separate SQL query confirmed no matching rehearsal database remains.

The initial release/build/deployment invocation succeeded without a release
retry, package rebuild, republish, SQL principal repair, Flyway repair, or
database restore.

## Independent validation

- BuildMaster parent execution `21974`: terminal `Succeeded`.
- BuildMaster target execution `21975`: terminal `Succeeded`, with no warning
  log indicator.
- ProGet download and captured build package are byte-identical.
- Flyway history is successful V00010/V00030/V00040/V00050/V00060 with zero
  failed rows; V00060 appears exactly once.
- The `Ace` schema contains the four V00060 tables, two procedures, one table
  type, four append-only triggers, and three database roles.
- The two executor roles have exactly the four intended `EXECUTE` grants across
  their procedure and table-type boundaries.
- The authoritative `ATAPUtilities.Tag*` tables still contain zero rows.
- The V00060 seed produced one `Ace.TagNamespace` row; `Ace.Tag`,
  `Ace.GatherContentSubmission`, and `Ace.GatherContentSubmissionTag` remain
  empty before live REST acceptance.

The first independent verifier run exposed only evidence-script formatting
issues (`sqlcmd` JSON width/options and two shortened expected filenames).
After correcting the read-only verifier to use unlimited-width output and the
canonical allowlist filenames, every independent check passed. These failures
did not affect BuildMaster, ProGet, the package, or database state.

## Scope boundary

No package promotion or database deployment to Development, Integration, QA,
or Production was authorized or performed. No stable-feed, identity/grant,
service, REST-traffic, certificate/PKI, firewall, proxy, vault, Flyway-repair,
or restore action occurred. Task 15.185.b remains open for the separately
gated AISupervisor/proxy database breadth; this record closes only the bounded
gather-content V00060 deployment slice.

## Evidence

Point-in-time evidence is under
`_generated/Sprint0015/Task15.185/b/REST-DB02/release/amendment/` and
`_generated/buildmaster/21338/`.
