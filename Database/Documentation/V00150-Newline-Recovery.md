# V00150 newline recovery

V00150 matches a literal CRLF boundary in the V00070 capture procedure. An LF checkout creates an LF definition, causing error 60603. Production already applied V00150; preserve every versioned migration and package checksum. This explicit operator recovery changes only the canonical predecessor's newline representation, then runs the original migration.

## Authorized targets and prerequisites

The recovery command is restricted to `ATAPUtilities` on local `Devwhertzing` or `Expwhertzing` instances. Other tiers require a separately reviewed procedure. Use a profile-enabled PowerShell 7 process and installed DatabaseManagement 0.1.24, PSFramework and Flyway 10.21 with its matching signed JDBC native-auth DLL. Keep the actual current sprint source/config/SQL/data paths explicit.

Inspect existing history first. Failed history, substantive procedure differences, wrong source content or mismatched module SET options stop recovery. Never reset a database or run `flyway repair` to bypass a failure.

## Procedure

1. Capture database identity, creation date, history/checksums, table row counts and canonical migration hashes under the owning repository's `_generated/`.
2. If the database is below V00140, run installed `Invoke-Flyway` with `FlywayCommand=migrate` and `FlywayAdditionalArgs` containing `-target=140`. Use the current sprint `Database/Flyway` base/config/SQL/data paths and Windows integrated authentication. Do not invoke provisioning or reset helpers.
3. Dot-source `Database/Powershell/public/Repair-AISupervisorV00150Newlines.ps1`. Open a `Microsoft.Data.SqlClient.SqlConnection` to the authorized database and pass it with the exact V00070 migration path. Preview with `-WhatIf`; apply with `-Confirm:$false` only after authorization.
4. The function verifies the newline-normalized canonical source SHA-256, extracts the complete procedure literal, compares the entire database definition using binary comparison and exact byte length, and transactionally converts LF/CRLF/mixed/bare-CR text to CRLF. It preserves CREATE/ALTER metadata equivalence and refuses session SET option changes. Status is `Changed`, `Unchanged`, `WouldChange` or `AlreadyApplied`.
5. Run installed Flyway `migrate` without a target override, then `validate`. V00150's existing predecessor/content and postcondition checks remain active.
6. Execute `Database/Verify/Verify_AISupervisorV00150.sql` against each developer database. It checks 14 successful versions, CacheTokens schema and timeline contracts, enabled/trusted constraints, legacy omitted-cache callers, zero/positive round trips and negative capture rejection. All synthetic telemetry is rolled back. Compare identities, prior histories/checksums, permissions/module options and existing table row counts with the baseline.
7. Repeat recovery and Flyway migrate: recovery must report `AlreadyApplied`, and migration must add no history rows. Preserve receipts and update the planning board; do not infer completion from a build or validation alone.

The command is an explicit source runbook tool, not a changed installed PowerShell module or an automatic Flyway callback. Fresh LF database creation still needs this bounded step between V00140 and V00150. Automatic lifecycle integration is outside this repair. Packaging and permanent-tier promotion remain unchanged.

## Regression coverage and rollback

`Database/Powershell/tests/AISupervisorV00150Newlines.Recovery.Tests.ps1` uses an explicitly opted-in developer predecessor at V00140 via `ATAP_V00150_TEST_SERVER`. It runs LF/CRLF/mixed/bare-CR variants, stable second calls, drift rejection and preview in rolled-back transactions. Do not run this predecessor fixture on a database already at V00150. Six cases passed on UTAT022 before application.

The repair transaction rolls back on mismatches. After V00150 succeeds, do not revert the procedure to V00070 or remove history: the schema is now forward migrated. A future behavioral defect needs a new reviewed migration. No migration files, package manifests, ProGet versions, credentials or installed module versions were changed by this recovery.

## Sprint 0016 result

On UTAT022, Dev and Exp each reached all 14 migrations through V00150, checksum `910403273`; validation and repeated migration passed. Database identities/creation dates and existing Dev data row counts were preserved. Production history remained unchanged; QA/Integration ATAPUtilities was inaccessible to the current login, so their applied state is unknown. No writes targeted those tiers.

Evidence is under Planning `_generated/Sprint0016/StartupRecovery/V00150/` and Utilities `_generated/Sprint0016/StartupRecovery/V00150/`. Durable planning report: `InformationForTheFuture/Sprint0016/V00150-Recovery.md`. No commits were made.
