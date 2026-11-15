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

## Running

Run Pester in a child `pwsh` with profiles loaded (never `-NoProfile`):

```powershell
pwsh -NonInteractive -Command "Import-Module Pester -RequiredVersion 6.2.0; Invoke-Pester -Path 'tests/ATAP.Utilities.Database.Tests/Unit' -Output Minimal"
```

Check the Result and every container, not only the failed-test count: a container that fails to load reports zero
failed tests.
