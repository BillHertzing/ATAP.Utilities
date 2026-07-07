# Explainer 0021 — SQL Server Backup Jobs: ProGet and BuildMaster

> **Moved from `_Planning/Explainers/0021-sql-server-backup-proget-buildmaster.md` on 2026-07-06** (Sprint 0012 Task 12.45.d,
> documentation reorganization per `PlanDocumentationReorganization.md`). Referenced from
> `Disaster Preparedness.md`.

Created: 2026-03-27 (SprintWorkSession-0003)

## Status

| Field                       | Value                                                                                                       |
| --------------------------- | ----------------------------------------------------------------------------------------------------------- |
| **Motivation**              | SC-0066, SC-0067 — prerequisite for Task 3.12 (BuildMaster version upgrade)                                 |
| **Host**                    | `utat022`                                                                                                   |
| **SQL Server instance**     | `localhost\Production` (a.k.a. `UTAT022\Production`)                                                        |
| **ProGet database**         | `ProGet`                                                                                                    |
| **BuildMaster database**    | `BuildMaster`                                                                                               |
| **Backup root**             | `C:\Dropbox\Backups\utat022\`                                                                               |
| **Scheduling tool**         | Cobian Reflector (pre-event: `Invoke-SqlServerBackup.ps1` via `pwsh.exe`)                                   |
| **Script location**         | `ATAP.Utilities / src / ATAP.Utilities.DatabaseManagement.Powershell / public / Invoke-SqlServerBackup.ps1` |
| **Compression mode**        | `-SevenZipCompress` (7-Zip LZMA2 level 5 — required for SQL Server Express Edition)                         |
| **Backup file extension**   | `.bak.7z` when using `-SevenZipCompress`; `.bak` otherwise                                                  |
| **ProGet full backup**      | ⬜ Not yet run                                                                                              |
| **BuildMaster full backup** | ⬜ Not yet run                                                                                              |

> Update the status table as each backup type is confirmed working. Replace ⬜ with ✅ and add the date.

---

## 1. Background

ProGet (port 50000) and BuildMaster (port 8622) both store their application data in SQL Server
databases on `localhost\Production`. Before upgrading either tool via Inedo Hub (Task 3.12),
at least one successful full backup of both the application data directories and the SQL Server
databases must exist. This explainer covers the SQL database backup jobs (SC-0067). For
application-data backups of the program files and configuration, see SC-0066.

Backup files are written directly to `C:\Dropbox\Backups\utat022\` by `Invoke-SqlServerBackup.ps1`, which Dropbox syncs offsite automatically. No separate offsite copy step is needed.

---

## 2. Backup Inventory

| Database      | SQL Instance           | Weekly Full   | Nightly Differential |
| ------------- | ---------------------- | ------------- | -------------------- |
| `ProGet`      | `localhost\Production` | Sunday ~01:50 | Mon–Sat ~01:50       |
| `BuildMaster` | `localhost\Production` | Sunday ~02:20 | Mon–Sat ~02:20       |

Backup file paths follow this convention:

```text
C:\Dropbox\Backups\utat022\
  ProGet\
    ProGet_FULL_20260330_015000.bak.7z      ← weekly full (7-Zip compressed)
    ProGet_DIFF_20260331_015000.bak.7z      ← nightly differential (7-Zip compressed)
    ProGet_DIFF_20260401_015000.bak.7z
    …
  BuildMaster\
    BuildMaster_FULL_20260330_022000.bak.7z  ← weekly full (7-Zip compressed)
    BuildMaster_DIFF_20260331_022000.bak.7z  ← nightly differential (7-Zip compressed)
    …
```

> When using the `-SevenZipCompress` switch (recommended for SQL Server Express Edition),
> the raw `.bak` is staged in a temporary directory, compressed with 7-Zip LZMA2 at level 5
> to a `.bak.7z` archive, then moved to `BackupRoot`. The temporary `.bak` is removed after
> successful compression. If `-SevenZipCompress` is omitted, files land in `BackupRoot`
> as plain `.bak` (and if `-CompressBackup` is specified, SQL Server native compression is
> used, which requires Standard or Enterprise Edition).

> All other Cobian backup jobs on utat022 that produce backup archives should also target
> subdirectories under `C:\Dropbox\Backups\utat022\` so that all backups are co-located
> and synced offsite by a single Dropbox folder.

---

## 3. Prerequisites

Before configuring the Cobian jobs:

1. **dbaTools installed** — Run once as an admin:

   ```powershell
   Install-Module dbaTools -Scope AllUsers -Force
   ```

2. **SQL Server Browser running** — Required for named-instance resolution (`Production`):

   ```powershell
   Get-Service -Name 'SQLBrowser' | Start-Service
   Set-Service  -Name 'SQLBrowser' -StartupType Automatic
   ```

3. **Backup directory exists** — The script creates subdirectories automatically, but
   confirm the root exists:

   ```powershell
   New-Item -ItemType Directory -Path 'C:\Dropbox\Backups\utat022' -Force
   ```

4. **SQL Server permissions** — The account that runs the Cobian job must have at minimum
   the `db_backupoperator` role on the `ProGet` and `BuildMaster` databases.
   If Cobian runs as `NetworkService`, the `UTAT022$` computer account needs this role:

   ```sql
   USE [ProGet];
   ALTER ROLE db_backupoperator ADD MEMBER [UTAT022$];

   USE [BuildMaster];
   ALTER ROLE db_backupoperator ADD MEMBER [UTAT022$];
   ```

   If Cobian runs as a specific user account, substitute that account name.

5. **Script deployed** — The path to `Invoke-SqlServerBackup.ps1` evolves through three lifecycle
   stages. Use the stage-appropriate path in Cobian job parameters and manual tests:

   | Stage                        | Path / Invocation                                                                                                                                            |
   | ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
   | **Sprint (current)**         | `C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-94-sprint-0004-work-items\src\ATAP.Utilities.DatabaseManagement.Powershell\public\Invoke-SqlServerBackup.ps1` |
   | **Post-merge (main branch)** | `C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.DatabaseManagement.Powershell\public\Invoke-SqlServerBackup.ps1`                              |
   | **After module packaging**   | `Invoke-SqlServerBackup` — install `ATAP.Utilities.DatabaseManagement.Powershell` via the internal ProGet feed; no script path needed                        |

   Update Cobian job parameters and manual-test commands whenever the lifecycle stage advances.

6. **7-Zip installed** (required when using `-SevenZipCompress`) — Download and install from
   <https://www.7-zip.org>. The script looks for `7z.exe` on `PATH` first, then falls back to
   `C:\Program Files\7-Zip\7z.exe`. Confirm availability:

   ```powershell
   Test-Path 'C:\Program Files\7-Zip\7z.exe'
   # or, if 7z.exe is on PATH:
   Get-Command '7z' -ErrorAction SilentlyContinue
   ```

   SQL Server Express Edition does not support native backup compression (`-CompressBackup`);
   use `-SevenZipCompress` instead to produce significantly smaller `.bak.7z` archives.

---

## 4. The Backup Script

The script is `ATAP.Utilities / src / ATAP.Utilities.DatabaseManagement.Powershell / public / Invoke-SqlServerBackup.ps1`.

It accepts the following parameters:

| Parameter            | Default                                                                                                         | Notes                                                                                   |
| -------------------- | --------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| `DatabaseName`       | _(required)_                                                                                                    | `'ProGet'` or `'BuildMaster'`                                                           |
| `BackupType`         | `'Full'`                                                                                                        | `'Full'` or `'Differential'`                                                            |
| `SqlInstance`        | `'localhost\Production'`                                                                                        | Override for remote testing                                                             |
| `BackupRoot`         | `'C:\Dropbox\Backups\utat022'`                                                                                  | Final destination for `.bak` / `.bak.7z` files                                          |
| `TemporaryDirectory` | `$(Join-Path $global:Settings[$global:ConfigRootKeys['FastTempBasePathConfigRootKey']] 'CobianReflectorBackup'` | Staging directory; raw `.bak` written here first, then compressed/moved to `BackupRoot` |
| `CompressBackup`     | _(switch — off)_                                                                                                | SQL Server **native** backup compression; Standard/Enterprise only — **not** Express    |
| `SevenZipCompress`   | _(switch — off)_                                                                                                | 7-Zip LZMA2 compression; produces `.bak.7z`; **use this on Express Edition**            |

`-CompressBackup` and `-SevenZipCompress` are mutually exclusive (separate parameter sets).

The script:

- Uses `Backup-DbaDatabase` (dbaTools) with backup verification enabled.
- Writes the raw `.bak` to a **temporary staging directory** first, then moves the final file to
  `BackupRoot`. Writing to a fast local temp path reduces I/O contention on the Dropbox-synced
  destination during the write phase.
- When `-SevenZipCompress` is specified: compresses the staged `.bak` with 7-Zip (LZMA2, level 5)
  to produce a `.bak.7z` archive, removes the raw `.bak`, then moves the `.bak.7z` to `BackupRoot`.
- When `-CompressBackup` is specified: enables SQL Server native backup compression (Standard /
  Enterprise editions only — not available on Express Edition).
- When neither switch is specified: the `.bak` is moved to `BackupRoot` uncompressed.
- Creates per-database subdirectories (in both `BackupRoot` and the staging directory) automatically.
- Returns a `PSCustomObject` with `Success`, `BackupFile`, `Duration`, `SizeMB`, `Message`.
  `SizeMB` reflects the final on-disk size (compressed, if applicable).
- Logs all significant events via `Write-PSFMessage` (PSFramework).
- Supports `-WhatIf` for dry runs.

### Manual test (run in a terminal before setting up Cobian)

> **Path note** — These examples use the **sprint worktree** path active during sprint 4.
> After the sprint branch is merged into `ATAP.Utilities` main, replace the worktree path
> with `C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\...`.

```powershell
# Full backup — ProGet (with 7-Zip compression; recommended for SQL Server Express Edition)
pwsh -Command "& 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-94-sprint-0004-work-items\src\ATAP.Utilities.DatabaseManagement.Powershell\public\Invoke-SqlServerBackup.ps1' -DatabaseName 'ProGet' -BackupType 'Full' -SevenZipCompress"

# Full backup — BuildMaster (with 7-Zip compression)
pwsh -Command "& 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-94-sprint-0004-work-items\src\ATAP.Utilities.DatabaseManagement.Powershell\public\Invoke-SqlServerBackup.ps1' -DatabaseName 'BuildMaster' -BackupType 'Full' -SevenZipCompress"

# Differential backup — ProGet (only after a full backup exists)
pwsh -Command "& 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-94-sprint-0004-work-items\src\ATAP.Utilities.DatabaseManagement.Powershell\public\Invoke-SqlServerBackup.ps1' -DatabaseName 'ProGet' -BackupType 'Differential' -SevenZipCompress"
```

Run the full backup test manually first and confirm the `.bak.7z` file appears under
`C:\Dropbox\Backups\utat022\ProGet\` before setting up the Cobian schedule.

---

## 5. Cobian Backup Job Configuration (Scripted)

`New-CobianSqlJobs.ps1` automates creating all four SQL backup jobs. Run it as
**Administrator** on utat022.

### Architecture

Each Cobian task is a **Dummy task** (`TaskBackupType=3`) that fires a pre-event which runs
`Invoke-SqlServerBackup.ps1` via `pwsh.exe`. Cobian acts as both scheduler and executor —
no Windows Task Scheduler involvement.

```text
01:50  Cobian Dummy task fires pre-event:
         pwsh.exe -NonInteractive -File Invoke-SqlServerBackup.ps1
                   -DatabaseName ProGet -BackupType Full -SevenZipCompress
         → .bak.7z → C:\Dropbox\Backups\utat022\ProGet\

02:20  Cobian Dummy task fires pre-event:
         pwsh.exe -NonInteractive -File Invoke-SqlServerBackup.ps1
                   -DatabaseName BuildMaster -BackupType Full -SevenZipCompress
         → .bak.7z → C:\Dropbox\Backups\utat022\BuildMaster\
```

> `TaskCancelIfPreEventFails=True` — if `Invoke-SqlServerBackup.ps1` exits non-zero, Cobian
> marks the task as failed and logs it in Cobian History. Cobian does not copy files
> (no source is defined on Dummy tasks); the pre-event alone produces the backup.

### Step 1 — Run `New-CobianSqlJobs.ps1`

Open an elevated (Administrator) PowerShell terminal and run:

> **Path lifecycle** — These examples use the sprint-worktree path for sprint 4.
> After the ATAP.Utilities branch merges to `main`, replace the worktree segment with
> `C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\...`.

```powershell
pwsh -Command "& 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-94-sprint-0004-work-items\src\ATAP.Utilities.DatabaseManagement.Powershell\public\New-CobianSqlJobs.ps1'"
```

The script stops the Cobian service, saves a timestamped backup of `MainList.lst`, then adds
four Dummy tasks grouped under `SQL Server Backups`:

| Task name                          | Schedule         | Time  | Pre-event                                             |
| ---------------------------------- | ---------------- | ----- | ----------------------------------------------------- |
| `SQL - ProGet - Full`              | Weekly (Sunday)  | 01:50 | `Invoke-SqlServerBackup.ps1 ProGet Full`              |
| `SQL - ProGet - Differential`      | Weekly (Mon–Sat) | 01:50 | `Invoke-SqlServerBackup.ps1 ProGet Differential`      |
| `SQL - BuildMaster - Full`         | Weekly (Sunday)  | 02:20 | `Invoke-SqlServerBackup.ps1 BuildMaster Full`         |
| `SQL - BuildMaster - Differential` | Weekly (Mon–Sat) | 02:20 | `Invoke-SqlServerBackup.ps1 BuildMaster Differential` |

Each task is created with `TaskCancelIfPreEventFails=True`, `TaskFullCopiesToKeep=7`, and
`TaskDifferentialCopiesToKeep=6`. The script is **idempotent**: any task whose name already
exists is skipped. It restarts the Cobian service when done.

**Verify** the four tasks appear in the Cobian UI under the `SQL Server Backups` group.

**Recovery** — If tasks do not appear or Cobian fails to start, restore the original file:

```powershell
$svc = (Get-Service | Where-Object DisplayName -like '*Cobian*' | Select-Object -First 1).Name
Stop-Service $svc -Force
$bak = Get-ChildItem 'C:\Program Files\Cobian Reflector\Lists' -Filter '*.bak_*' |
       Sort-Object LastWriteTime -Descending | Select-Object -First 1
Copy-Item $bak.FullName 'C:\Program Files\Cobian Reflector\Lists\MainList.lst' -Force
Start-Service $svc
```

### Verification

1. In the Cobian UI → `SQL Server Backups` group, right-click each task → **Run Now**.

2. Confirm `.bak.7z` files appear in the backup root:

   ```powershell
   Get-ChildItem 'C:\Dropbox\Backups\utat022\ProGet'      | Sort-Object LastWriteTime
   Get-ChildItem 'C:\Dropbox\Backups\utat022\BuildMaster' | Sort-Object LastWriteTime
   ```

3. Check **Cobian History** — a successful run shows no errors. If the pre-event failed,
   Cobian marks the task run as failed. Review the error output in
   **Cobian Reflector → History**.

4. Proceed to Section 8 to restore-verify the `.bak.7z` files.

---

## 6. Stagger Logic and Consistent Restore Points

The ProGet full backup starts at 01:50 and the BuildMaster full backup at 02:20. This 30-minute
stagger prevents both jobs from hammering the same SQL Server instance simultaneously and ensures
the `.bak.7z` files are written at slightly different times, making it easy to identify which Sunday's
backup represents a consistent ProGet + BuildMaster pair.

For a full restore, always use the full backups from the same Sunday, then apply the differential
from the same night. Do **not** mix full backups from different weeks.

---

## 7. Retention Policy

When jobs are created via `New-CobianSqlJobs.ps1`, Cobian enforces retention automatically:
each task is created with `TaskFullCopiesToKeep=7` (7 weekly fulls retained) and
`TaskDifferentialCopiesToKeep=6` (6 nightly differentials retained per database). Cobian
deletes excess copies on every run — no manual cleanup is needed.

If jobs were configured manually via the Cobian UI (not via the script), confirm the
**Copies to keep** settings in Task Properties → Files/Archive. If blank, backup files will
accumulate in `C:\Dropbox\Backups\utat022\` indefinitely; review monthly and delete copies
older than 90 days until the settings are confirmed or the tasks are re-created via the script.

For the `Invoke-SqlServerBackup.ps1 -SevenZipCompress` approach (Section 4), there is no
automated retention. Compressed `.bak.7z` files are typically under 150 MB each. Manual
pruning is required until SC-0110 is implemented (see SCAFFOLD: retention in Explainer 0022).

---

## 8. Verification Steps

After the first successful scheduled run, confirm:

1. File exists:

   ```powershell
   Get-ChildItem 'C:\Dropbox\Backups\utat022\ProGet'      | Sort-Object LastWriteTime
   Get-ChildItem 'C:\Dropbox\Backups\utat022\BuildMaster' | Sort-Object LastWriteTime
   ```

2. Backup is valid (restore-verify without writing data files):

   `.bak.7z` files must be decompressed before `Restore-DbaDatabase` can read them — SQL Server
   cannot open 7-Zip archives directly.

   ```powershell
   # Decompress the .bak.7z to a temp folder
   $bakFile = Get-ChildItem 'C:\Dropbox\Backups\utat022\ProGet' -Filter '*_FULL_*.bak.7z' |
              Sort-Object LastWriteTime -Descending | Select-Object -First 1
   $restoreTemp = 'C:\Temp\VerifyRestore'
   New-Item -ItemType Directory -Path $restoreTemp -Force | Out-Null
   & 'C:\Program Files\7-Zip\7z.exe' e $bakFile.FullName "-o$restoreTemp" -y

   # Verify the extracted .bak (no data files written)
   $bakPath = Get-ChildItem $restoreTemp -Filter '*.bak' | Select-Object -First 1 -ExpandProperty FullName
   Restore-DbaDatabase -SqlInstance 'localhost\Production' `
       -Path $bakPath `
       -VerifyOnly

   # Clean up
   Remove-Item $restoreTemp -Recurse -Force
   ```

3. Dropbox sync — confirm the `.bak.7z` files appear in the Dropbox web UI or on a second device.

---

## 9. Recovery Procedure (brief)

To restore a database from a full backup followed by a differential:

> **7-Zip decompression step** — If backups were created with `-SevenZipCompress`, the archive
> files have a `.bak.7z` extension. Extract the `.bak` files before running
> `Restore-DbaDatabase`:
>
> ```powershell
> $restoreTemp = 'C:\Temp\Restore'
> New-Item -ItemType Directory -Path $restoreTemp -Force | Out-Null
> & 'C:\Program Files\7-Zip\7z.exe' e "C:\Dropbox\Backups\utat022\ProGet\ProGet_FULL_<timestamp>.bak.7z" "-o$restoreTemp"
> & 'C:\Program Files\7-Zip\7z.exe' e "C:\Dropbox\Backups\utat022\ProGet\ProGet_DIFF_<timestamp>.bak.7z" "-o$restoreTemp"
> ```
>
> Then use the extracted `.bak` paths in the restore commands below.

```powershell
# Step 1 — Restore full backup (NoRecovery leaves DB in restoring state)
# Adjust -Path if you decompressed to C:\Temp\Restore\ above.
Restore-DbaDatabase -SqlInstance 'localhost\Production' `
    -DatabaseName 'ProGet_Restored' `
    -Path 'C:\Dropbox\Backups\utat022\ProGet\ProGet_FULL_<timestamp>.bak' `
    -NoRecovery

# Step 2 — Apply differential backup (WithRecovery brings DB online)
Restore-DbaDatabase -SqlInstance 'localhost\Production' `
    -DatabaseName 'ProGet_Restored' `
    -Path 'C:\Dropbox\Backups\utat022\ProGet\ProGet_DIFF_<timestamp>.bak' `
    -WithRecovery
```

Restore to a different database name first (`ProGet_Restored`) to verify the restore before
replacing the live database. Once verified, take the live ProGet service offline, drop or rename
the old `ProGet` database, and rename `ProGet_Restored` → `ProGet`.

---

## 10. Unblocking Task 3.12

Task 3.12 (BuildMaster version upgrade) is blocked until:

- [x] At least one successful full backup of `ProGet` has completed and the `.bak` or `.bak.7z` file is verified.
- [x] At least one successful full backup of `BuildMaster` has completed and the `.bak` or `.bak.7z` file is verified.
- [x] Both `.bak` or `.bak.7z` files are confirmed synced to Dropbox (offsite copy exists).

Update Task 3.12 in TASKS.md and remove the BLOCKED note once all three checkboxes are ticked.

---

## 11. Multiple Machines — Extending Backup Coverage

> **PLACEHOLDER** — To be expanded. The approach documented in sections 1–10 covers `utat022`
> only. Once it is validated, the same pattern should be applied to all other machines in the
> environment that host SQL Server databases or other data requiring scheduled backup.
>
> Topics to cover here:
>
> - Inventory of other machines and the databases / data directories they host
> - Whether each machine has Cobian Backup installed, and if not, the plan to install it
> - Shared backup root convention: `C:\Dropbox\Backups\<machinename>\` per machine
> - Whether `Invoke-SqlServerBackup.ps1` runs locally on each machine or is invoked remotely
>   (e.g., via `Invoke-Command -ComputerName`)
> - Credential and permission model for multi-machine execution

---

## References

- SC-0066 — Cobian application-data backup jobs for ProGet and BuildMaster
- SC-0067 — This explainer implements SC-0067 (SQL database backup jobs)
- SC-0068 — Referenced alongside SC-0066/SC-0067 in Task 3.12 BLOCKED note
- TASKS.md Task 3.12 — BuildMaster version upgrade (blocked on these backups)
- Explainer 0002 — ProGet setup (`ProGet` database on `localhost\Production`)
- Explainer 0004 — BuildMaster setup (`BuildMaster` database on `localhost\Production`)
- [dbaTools Backup-DbaDatabase](https://docs.dbatools.io/Backup-DbaDatabase)
- [dbaTools Restore-DbaDatabase](https://docs.dbatools.io/Restore-DbaDatabase)
