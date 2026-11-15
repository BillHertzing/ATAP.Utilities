# ATAP.Utilities.Database.Tests — Index

Pester 6.2.0 tests for the `ATAPUtilities.Database` package: the Flyway migrations, seeds and package allowlist under
`Database/Flyway/`, the scripts under `Database/Powershell/public/`, and the package contracts under `Database/Verify/`.

These tests moved here from `Database/Powershell/tests/` on 2026-11-15 (Sprint 0017, Phase B of the rehearsal
parameterization plan). The folder has no `.csproj`, so `dotnet test` never discovers it.

## Layout

- `Unit/` — offline tests: static migration contracts, allowlist and package checks, verifier contracts. Some files
  also contain database checks that skip themselves unless their own opt-in variable is set.
- `Integration/` — tests that need a live SQL Server instance.
- `Fixtures/` — JSON fixtures read by tests in both folders (paths are `..\Fixtures\<name>`).

Every test file resolves the repository root as `$PSScriptRoot\..\..\..`, so `Unit/` and `Integration/` must stay
exactly two levels below `tests/`.

## Tags and opt-in

Every live-database `Describe` is tagged `Integration`, `RequiresSql` and skips unless its own opt-in variable names
a target explicitly. There is no implicit `localhost` default.

| File | Opt-in |
| --- | --- |
| `Integration/AceCommander.SchemaParity.Tests.ps1` | `ATAPUTILITIES_SQLINSTANCE` |
| `Integration/AISupervisorV00150Newlines.Recovery.Tests.ps1` | `ATAP_V00150_TEST_SERVER` |
| `Integration/PhiloteTemporalValidity-Database.Tests.ps1` | `PHILOTE_TEMPORAL_VALIDITY_DATABASE_NAME` and `PHILOTE_TEMPORAL_VALIDITY_DATABASE_SECRET_NAME` |
| `Integration/RPRRSBSI-V4-ContentSummarySchemaQuery.Database.Tests.ps1` | `ATAP_CONTENTSUMMARY_V110_DISPOSABLE_AUTHORIZATION` and `..._SQL_INSTANCE` |
| `Integration/RPRRSBSI-V4-CoreIdentityOverlay.Database.Tests.ps1` | `ATAP_TASK15140C_V4_DISPOSABLE_AUTHORIZATION` (its offline fixture `Describe` is tagged `Integration` only) |

The `Unit/` migration files also contain disposable-database checks that skip themselves unless their own
authorization variable is set.

The BuildMaster database stage can run the offline suite: `tests/ATAP.Utilities.Database.Tests/Unit` with
`-ExcludeTag RequiresSql`, in one process.

ScriptDom-based parse tests load the installed `SqlServer` module's `coreclr` ScriptDom only when no ScriptDom parser
type is already loaded. A second copy cannot load into one process.

## Running

Run Pester in a child `pwsh` with profiles loaded (never `-NoProfile`):

```powershell
pwsh -NonInteractive -Command "Import-Module Pester -RequiredVersion 6.2.0; Invoke-Pester -Path 'tests/ATAP.Utilities.Database.Tests/Unit' -Output Minimal"
```

Check the Result and every container, not only the failed-test count: a container that fails to load reports zero
failed tests.
