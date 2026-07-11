# Explainer 0021a — Application Data Backup: ProGet and BuildMaster

> **Moved from `_Planning/Explainers/0021a-proget-buildmaster-application-backup.md` on 2026-07-06** (Sprint 0012 Task 12.45.d,
> documentation reorganization per `PlanDocumentationReorganization.md`). Referenced from
> `Disaster Preparedness.md`.

Created: 2026-04-03 (SprintWorkSession-0004)

## Status

| Field                          | Value                                                                                                  |
| ------------------------------ | ------------------------------------------------------------------------------------------------------ |
| **Motivation**                 | SC-0066 — prerequisite for Task 4.6 (BuildMaster version upgrade)                                      |
| **Host**                       | `utat022`                                                                                              |
| **ProGet data directory**      | `C:\ProgramData\ProGet\` ✅ confirmed (9.3 MB, 54 files — packages + extensions + LocalStorage)        |
| **BuildMaster data directory** | `C:\ProgramData\BuildMaster\` ✅ confirmed (~0 MB currently — extensions + Temp)                       |
| **Cobian config**              | `C:\Program Files\Cobian Reflector\Lists\MainList.lst`                                                 |
| **Backup root**                | `C:\Dropbox\Backups\utat022\`                                                                          |
| **Scheduling tool**            | Cobian Reflector — standard file copy tasks (Full + Incremental)                                       |
| **Function**                   | `New-CobianAppJobs` (autoloaded from `ATAP.Utilities.DatabaseManagement.Powershell`)                   |
| **ProGet full backup**         | ✅ Verified (archive confirmed 2026-04-10)                                                             |
| **BuildMaster full backup**    | ✅ Verified (archive confirmed 2026-04-10)                                                             |
| **Cobian config backup**       | ✅ Verified (archive confirmed 2026-04-05)                                                             |

> Update the status table as each backup type is confirmed working. Replace ⬜ with ✅ and add the date.

---

## Parity journal requirement

Before a step in this runbook creates, changes, removes, or schedules backup
state on `utat022` or `utat01`, append a secret-safe declaration with
`Add-ParityChangeEntry` on the host being changed. Include the category, item,
old/new state, peer host, and a peer action; do not include any secret value.
After the peer applies its corresponding action, acknowledge it from that peer
with `Confirm-ParityChangeApplied`.

---

## 1. Background

ProGet (port 50000) and BuildMaster (port 8622) each consist of two recoverable layers:

| Layer            | Backup mechanism                                  | Explainer  |
| ---------------- | ------------------------------------------------- | ---------- |
| SQL databases    | `Invoke-SqlServerBackup.ps1` via Cobian pre-event | 0021       |
| Application data | Cobian file copy tasks (this explainer)           | **0021a**  |
| Config files     | Git/ATAP.IAC (symlinked via `ProGet.config`)      | 0004, 0002 |

Before upgrading either tool via Inedo Hub (Task 4.6), at least one successful backup of
**both** layers must exist. Task 4.5 covers the SQL layer (complete ✅). This explainer
covers the application data layer (SC-0066).

---

## 2. What Is and Is Not Covered Here

**Covered:**

- ProGet application data on disk: package files stored in feed packages directory,
  extension DLLs installed via Inedo Hub, any on-disk cached data not held in SQL
- BuildMaster application data on disk: build artifacts, extension DLLs, on-disk data
  not held in SQL
- Cobian Reflector configuration: `MainList.lst` (the backup task registry itself)

**Not covered:**

- SQL databases → Explainer 0021 / Task 4.5 (complete)
- `ProGet.config` / `BuildMaster.config` → under Git control via ATAP.IAC
  (`C:\ProgramData\Inedo\SharedConfig\`)
- OS and binaries → recoverable from Inedo Hub installer; no value in backing up

---

## 3. Application Data Directory Inventory

### Confirmed Directories (verified 2026-04-03 on utat022)

Inedo products do **not** store application data under `C:\ProgramData\Inedo\`.
The actual data directories are:

| Application  | Directory                                  | Contents                                                               | Size   | Status            |
| ------------ | ------------------------------------------ | ---------------------------------------------------------------------- | ------ | ----------------- |
| ProGet       | `C:\ProgramData\ProGet\`                   | `Packages\`, `Extensions\`, `LocalStorage\pgmpdb.ahdb`                 | 9.3 MB | ✅ confirmed      |
| ProGet       | `C:\ProgramData\ProGet\Packages\.nugetv2\` | Per-feed subdirs F1–F4: actual `.nupkg` files (covered by parent path) | subset | ✅ confirmed      |
| BuildMaster  | `C:\ProgramData\BuildMaster\`              | `.initconfig.json`, `Extensions\`, `Temp\` (temps not critical)        | ~0 MB  | ✅ confirmed      |
| Inedo shared | `C:\ProgramData\Inedo\ExtensionCache\`     | 20 hash-named extension DLL bundles (re-downloadable from Inedo hub)   | varies | ℹ️ optional       |
| Cobian       | `C:\Program Files\Cobian Reflector\Lists\` | `MainList.lst` — all Cobian backup task definitions (73 KB)            | 73 KB  | ✅ confirmed path |

`C:\ProgramData\Inedo\` contains only:

- `ExtensionCache\` — shared extension DLLs for both ProGet and BuildMaster (re-downloadable)
- `SharedConfig\` — `ProGet.config` + `BuildMaster.config` (already under Git via ATAP.IAC)

> `C:\ProgramData\Inedo\ExtensionCache\` is **not included** in the default `New-CobianAppJobs`
> job definitions because extensions are re-downloadable. Add a 6th task for this path if
> offline recovery without internet access is a requirement.

### ProGet Feed Package Storage

ProGet uses `C:\ProgramData\ProGet\Packages\.nugetv2\F{n}\` where `{n}` is the numeric
feed ID. Backing up `C:\ProgramData\ProGet\` covers all feeds — no per-feed path needed.

### What to Exclude

| Path                                 | Reason                                    |
| ------------------------------------ | ----------------------------------------- |
| `C:\ProgramData\BuildMaster\Temp\`   | Transient execution data, no backup value |
| `C:\ProgramData\Inedo\SharedConfig\` | Already in Git via ATAP.IAC               |
| `C:\Program Files\ProGet\`           | Re-installable via Inedo Hub              |
| `C:\Program Files\BuildMaster\`      | Re-installable via Inedo Hub              |

After creating tasks via script, add a Cobian exclusion filter `Temp\*` on the BuildMaster
task via the Cobian UI if artifact storage grows large.

---

## 4. Backup Job Design

### Job Type: File Copy Tasks (not Dummy/Pre-Event)

Unlike the SQL backup jobs in Explainer 0021 (Dummy tasks with pre-events that invoke
`Invoke-SqlServerBackup.ps1`), application data backup jobs are **standard Cobian file copy
tasks**:

- `TaskBackupType=0` — Full (copy all files)
- `TaskBackupType=1` — Incremental (copy files changed since the last backup of any type)

Cobian copies source files directly to the destination. No script invocation is needed.

### Compression Strategy

| Option              | Used for                    | Notes                                                                  |
| ------------------- | --------------------------- | ---------------------------------------------------------------------- |
| `TaskCompression=2` | 7z (general data)           | Best ratio for config files, text artifacts, and binary extension DLLs |
| `TaskCompression=0` | None (ProGet app data only) | `.nupkg` files are already ZIP archives; see note below                |

#### Why ProGet App Data Is NOT Compressed (`TaskCompression=0`)

ProGet stores all NuGet packages as `.nupkg` files, which are themselves ZIP archives.
Cobian's 7z compressor cannot meaningfully reduce an already-deflated stream; in practice
it produces archives that are the same size or slightly **larger** than the source, while
consuming significant CPU time and doubling the I/O (read source + write archive) for every
backup cycle.

Therefore the two ProGet tasks (`App - ProGet - Full` and `App - ProGet - Incremental`)
use `TaskCompression=0` (None). Cobian copies the source tree directly into a
date-stamped destination folder with no archive wrapping. The `.nupkg` files themselves
serve as the compressed artifact.

BuildMaster and Cobian Config backups use `TaskCompression=2` (7z) because those
directories contain config JSON, extension DLLs, and text files that compress well.

> **Consistency rule:** all three non-ProGet tasks use 7z. ProGet is the only exception,
> and the reason is the ZIP-on-ZIP compression penalty, not an oversight.

### Jobs to Create

| Task name                         | Source path                                | Schedule       | Compress |
| --------------------------------- | ------------------------------------------ | -------------- | -------- |
| `App - ProGet - Full`             | `C:\ProgramData\ProGet\`                   | Weekly Sunday  | None (0) |
| `App - ProGet - Incremental`      | `C:\ProgramData\ProGet\`                   | Weekly Mon–Sat | None (0) |
| `App - BuildMaster - Full`        | `C:\ProgramData\BuildMaster\`              | Weekly Sunday  | 7z (2)   |
| `App - BuildMaster - Incremental` | `C:\ProgramData\BuildMaster\`              | Weekly Mon–Sat | 7z (2)   |
| `App - Cobian Config - Full`      | `C:\Program Files\Cobian Reflector\Lists\` | Weekly Sunday  | 7z (2)   |

Destination paths:

```text
C:\Dropbox\Backups\utat022\
  ProGet-AppData\         ← ProGet Full + Incremental
  BuildMaster-AppData\    ← BuildMaster Full + Incremental
  Cobian-Config\          ← Cobian MainList.lst Full
```

### Schedule Stagger

| Time  | Task                          | Notes                                                         |
| ----- | ----------------------------- | ------------------------------------------------------------- |
| 01:50 | SQL ProGet Full/Diff          | SQL backup fires first (pre-event via Invoke-SqlServerBackup) |
| 02:20 | SQL BuildMaster Full/Diff     | SQL backup fires second                                       |
| 03:00 | App - ProGet - Full/Incr      | After SQL jobs complete                                       |
| 03:30 | App - BuildMaster - Full/Incr | After ProGet app backup completes                             |
| 03:50 | App - Cobian - Full           | Last — captures the updated MainList.lst after other changes  |

Staggering prevents simultaneous I/O contention on SQLServer, Dropbox sync, and the source
directories. Adjust actual times after verifying typical backup durations.

---

## 5. Scripted Job Creation: `New-CobianAppJobs`

### Location

```text
ATAP.Utilities / src / ATAP.Utilities.DatabaseManagement.Powershell / public / New-CobianAppJobs.ps1
```

### Architecture

Follows the same pattern as `New-CobianSqlJobs.ps1` (see Explainer 0023 for the
`MainList.lst` format details):

1. Stop Cobian service
2. Timestamp-backup `MainList.lst`
3. Read the file as a single UTF-8 string
4. Discover root section GUID dynamically (not hardcoded)
5. Check idempotency — skip any job whose `TaskName=` already exists
6. Generate fresh GUIDs for each task's sections (13 sections per task × 5 tasks = 65 sections)
7. Build sections using here-strings
8. Inject root index entries (`BackupTask=` before root section close tag)
9. Append all new sections
10. Write back preserving original encoding (UTF-16 LE when Cobian UI has written the file); normalize new sections to CRLF; restart service

Unlike `New-CobianSqlJobs.ps1`, these tasks use actual file copy configuration:

```powershell
# Task section differences for file-copy tasks vs Dummy tasks:
TaskBackupType=0        # 0=Full, 1=Incremental (not 3=Dummy)
TaskCompression=2       # 0=None, 2=7z (choose per source)
TaskSeparatedBackups=True
TaskFullCopiesToKeep=5
TaskIncrementalCopiesToKeep=6
TaskUseVolumeShadowCopies=False  # VSS not needed for non-locked files
```

> Source section (`SDKind=1`, `SDPath=<appdata-dir>`) and Destination section
> (`SDKind=1`, `SDPath=<dropbox-target-dir>`) use the same format as SQL jobs.
> The mandatory SFTP/FTP empty sub-sections are still required by the format.

### Parameters

| Parameter             | Default / Notes                                                        |
| --------------------- | ---------------------------------------------------------------------- |
| `ProGetDataPath`      | `C:\ProgramData\ProGet\` — confirmed path (verified 2026-04-03)        |
| `BuildMasterDataPath` | `C:\ProgramData\BuildMaster\` — confirmed path (verified 2026-04-03)   |
| `BackupRoot`          | `C:\Dropbox\Backups\utat022\`                                          |
| `WhatIf`              | Dry run — shows what would be created without modifying `MainList.lst` |

### Running the Script

Open an elevated (Administrator) PowerShell terminal on utat022:

```powershell
New-CobianAppJobs
```

**Recovery** — same as for SQL jobs: restore `MainList.lst.bak_*` if anything goes wrong (see Explainer 0023, Recovery Procedure).

---

## 6. Manual Pre-Verification Steps

Before creating Cobian jobs, confirm the source directories are accessible and contain
the expected data:

```powershell
# 1. Confirm ProGet data directory exists and is non-empty
Get-ChildItem 'C:\ProgramData\ProGet\' -ErrorAction Stop | Select-Object -First 10

# 2. Confirm BuildMaster data directory exists and is non-empty
Get-ChildItem 'C:\ProgramData\BuildMaster\' -ErrorAction Stop | Select-Object -First 10

# 3. Confirm Cobian Lists directory
Get-ChildItem 'C:\Program Files\Cobian Reflector\Lists\' | Select-Object Name, LastWriteTime

# 4. Confirm backup destination root exists
New-Item -ItemType Directory -Path 'C:\Dropbox\Backups\utat022\ProGet-AppData'   -Force
New-Item -ItemType Directory -Path 'C:\Dropbox\Backups\utat022\BuildMaster-AppData' -Force
New-Item -ItemType Directory -Path 'C:\Dropbox\Backups\utat022\Cobian-Config'    -Force
```

---

## 7. Post-Creation Verification

After running `New-CobianAppJobs`:

1. **Verify tasks appear in Cobian UI** under a group named `App Data Backups`.
   Schedules are written directly by the script:
   - Full tasks → Weekly, Sunday only
   - Incremental tasks → Weekly, Monday–Saturday

2. **Run Full backups manually** — In Cobian UI, right-click each `Full` task → **Run Now**.

3. **Confirm backup archives appear**:

   ```powershell
   Get-ChildItem 'C:\Dropbox\Backups\utat022\ProGet-AppData'      | Sort-Object LastWriteTime
   Get-ChildItem 'C:\Dropbox\Backups\utat022\BuildMaster-AppData' | Sort-Object LastWriteTime
   Get-ChildItem 'C:\Dropbox\Backups\utat022\Cobian-Config'       | Sort-Object LastWriteTime
   ```

4. **Check archive integrity** (7z):

   ```powershell
   $archive = Get-ChildItem 'C:\Dropbox\Backups\utat022\ProGet-AppData' -Recurse -Filter '*.7z' |
              Sort-Object LastWriteTime -Descending | Select-Object -First 1
   & 'C:\Program Files\7-Zip\7z.exe' t $archive.FullName
   # Expected output: "Everything is Ok"
   ```

5. **Confirm Dropbox sync** — check the Dropbox web UI or tray icon for the new archive
   files, confirming offsite copy exists before proceeding to Task 4.6.

6. **Check Cobian History** — Administration → Log (or History) should show the completed
   jobs without errors.

---

## 8. Retention Policy

Configure in `New-CobianAppJobs`:

| Setting                         | Value | Notes                                         |
| ------------------------------- | ----- | --------------------------------------------- |
| `TaskFullCopiesToKeep=5`        | 5     | ~5 weeks of weekly full backups retained      |
| `TaskIncrementalCopiesToKeep=6` | 6     | 6 nights of incremental retained per database |

Cobian enforces these limits automatically on each run. If tasks were configured manually
(not via script), confirm **Copies to keep** in Task Properties → Files/Archive. If blank,
archives accumulate indefinitely.

---

## 9. Script Path Lifecycle and Backup Scope

### What this script backs up

`New-CobianAppJobs` creates Cobian backup jobs for the **ProGet and BuildMaster
application data directories** (`C:\ProgramData\ProGet\` and `C:\ProgramData\BuildMaster\`).
These directories are persistent infrastructure — they exist and accumulate data regardless
of sprint activity.

**Only production-tier data requires backup.** ProGet's feed tiers have very different
lifetimes:

| Feed tier    | Lifetime               | Backup needed? |
| ------------ | ---------------------- | -------------- |
| Production   | Permanent              | ✅ Yes         |
| Testing      | Ephemeral (per-sprint) | ❌ No          |
| Integration  | Ephemeral (per-sprint) | ❌ No          |
| Development  | Ephemeral (per-sprint) | ❌ No          |
| Experimental | Ephemeral (per-sprint) | ❌ No          |

Non-production feeds are created at sprint start and removed at sprint end. Their packages
are rebuilt from source on the next sprint; there is nothing to lose if they are not backed
up. Cobian backs up the entire `C:\ProgramData\ProGet\` tree, which includes all feeds, but
losing experimental/development/integration/testing package storage is acceptable.

### One-time setup — not sprint-repeatable

Unlike the SQL backup jobs in Explainer 0021, the app backup Cobian jobs created by this
script are **one-time infrastructure setup** tied to when ProGet or BuildMaster is first
installed on a machine. They do not need to be re-created each sprint. Once created, they
run on their own schedule indefinitely.

Re-run `New-CobianAppJobs` only if:

- ProGet or BuildMaster is reinstalled or moved to a new machine
- The `C:\ProgramData\{ProGet|BuildMaster}` path changes
- Cobian is reinstalled and `MainList.lst` is lost

### Script path after sprint merge

The script lives in `ATAP.Utilities.DatabaseManagement.Powershell`. Its path advances
once — when the sprint-0004 branch merges to main (Task 4.5a covers the SQL equivalent;
there is no app-jobs equivalent task needed since the Cobian jobs are already running and
do not reference the script path after creation):

| Stage                          | Invocation                                                                                   |
| ------------------------------ | -------------------------------------------------------------------------------------------- |
| **Module installed (current)** | `New-CobianAppJobs` (autoloaded from `ATAP.Utilities.DatabaseManagement.Powershell` module) |

---

## References

- SC-0066 — This explainer implements SC-0066 (Cobian application-data backup jobs)
- SC-0067 — SQL database backup jobs (Explainer 0021, Task 4.5 ✅)
- TASKS.md Task 4.4 — ProGet and BuildMaster Cobian backup jobs (this explainer's task)
- TASKS.md Task 4.6 — BuildMaster version upgrade (blocked on Tasks 4.4 + 4.5)
- Explainer 0021 — SQL Server backup jobs for ProGet and BuildMaster databases
- Explainer 0023 — Cobian Reflector `MainList.lst` format and PowerShell automation
- Explainer 0002 — ProGet setup (installation, ports, SQL instance)
- Explainer 0004 — BuildMaster setup (installation, service, pipeline)
- `New-CobianSqlJobs.ps1` — reference implementation for the scripted Cobian job creation pattern
