# Rebuild Experimental Databases on Expwhertzing

> **Instance-naming correction (2026-08-08):** `Experimental` is a logical
> database role, not a physical SQL Server instance name. Developer-scoped
> instances follow `Exp<DeveloperName>`; `Expwhertzing` is the specific instance
> for developer `whertzing`. Never provision or address an instance named
> `Experimental`.

## Prerequisites

- PowerShell 7.x (`pwsh`)
- Flyway CLI available in `PATH`
- SQL Server instance `Expwhertzing` is running
- Windows Integrated Security access to `localhost\Expwhertzing`
- All ATAP PowerShell modules are autoloaded (available in `PSModulePath`)

---

## Dry-run validation (optional but recommended)

**Step 1 — Check Flyway migration state without touching the database**

```powershell
$repoRoot   = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-100-Sprint-0007-work-items'
$flywayBase = "$repoRoot\Database\Flyway"

Invoke-Flyway `
  -DatabaseName   'ATAPUtilities' `
  -Environment    'Experimental' `
  -SqlInstance    'Expwhertzing' `
  -DatabaseHost   'localhost' `
  -IntegratedSecurity `
  -FlywayCommand  'info' `
  -FlywayBasePath $flywayBase
```

---

## Drop and recreate the database

**Step 2 — Run the full rebuild** (provisions DB + runs all active Flyway migrations)

```powershell
$repoRoot = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-100-Sprint-0007-work-items'

$result = Build-DatabaseWithFlyway `
  -DatabaseName    'ATAPUtilities' `
  -Environment     'Experimental' `
  -SqlInstance     'Expwhertzing' `
  -DatabaseHost    'localhost' `
  -DatabasePath    'C:\LocalDBs\Expwhertzing' `
  -IntegratedSecurity `
  -Force

$result
```

`-Force` drops the existing database and recreates it. `-IntegratedSecurity` uses Windows auth (no vault lookup needed).

**What this does internally:**

1. Connects to `master` on `localhost\Expwhertzing`
2. Drops `ATAPUtilities` if it exists (because `-Force`)
3. Runs `DropAndCreateDatabase.sql`, `CreateLoginAndUser.sql`, `AddFlywaySchemaHistoryTable.sql` from `src\ATAP.Utilities.DatabaseManagement\SharedSQL`
4. Sets `FLYWAY_URL` and placeholder env vars, then runs `flyway migrate` against all active migrations in `Database\Flyway\SQL\` (V00.01.000010 through V00.01.000301)

The 9 SQL files in `Database\Flyway\SQL\Obsolete\` are outside the `flyway.toml` scan path (`filesystem:./SQL`) and are ignored automatically.

Database `.mdf` and `.ldf` files are written to `C:\LocalDBs\Expwhertzing\`.

---

## Verify the migration was applied

**Step 3 — Confirm schema history**

```powershell
Invoke-Flyway `
  -DatabaseName   'ATAPUtilities' `
  -Environment    'Experimental' `
  -SqlInstance    'Expwhertzing' `
  -DatabaseHost   'localhost' `
  -IntegratedSecurity `
  -FlywayCommand  'info' `
  -FlywayBasePath "$repoRoot\Database\Flyway"
```

---

## Additional databases

If more than one experimental database needs rebuilding (e.g., `PCMSC`), repeat Step 2 with `-DatabaseName 'PCMSC'`. Note that `PCMSC` migrations live in a different repository; omit or skip Flyway for databases whose migration scripts are not present under `Database\Flyway\SQL\`.
