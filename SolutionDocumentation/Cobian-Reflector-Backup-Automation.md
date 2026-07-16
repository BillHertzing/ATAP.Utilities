# Cobian Reflector — MainList.lst Format & PowerShell Automation

> **Moved from `_Planning/Explainers/0023-Cobian Reflector — MainList.lst Format, PowerShell Automation.md` on 2026-07-06** (Sprint 0012 Task 12.45.d,
> documentation reorganization per `PlanDocumentationReorganization.md`). Referenced from
> `Disaster Preparedness.md`.

## Overview

Cobian Reflector does not use XML or a database to store its backup task
definitions. Instead, all tasks are persisted in a single plain-text file:

    C:\Program Files\Cobian Reflector\Lists\MainList.lst

The file uses a **custom GUID-sectioned key=value format** invented by the
Cobian Reflector developer.

---

## The Section Format

Every object in the file is wrapped in a pair of delimiter tags:

    <§- {GUID} -§>
    §DuplicatedKeys:{True|False}
    §CaseSensitive:False
    §PairSeparator:=
    Key=Value
    ...
    <§§- {GUID} -§§>

| Delimiter               | Meaning                                 |
| ----------------------- | --------------------------------------- |
| `<§- GUID -§>`          | Opening tag                             |
| `<§§- GUID -§§>`        | Closing tag (note the double `§§`)      |
| `§DuplicatedKeys:True`  | Same key name may appear more than once |
| `§DuplicatedKeys:False` | Each key name is unique                 |
| `§CaseSensitive:False`  | Key lookups are case-insensitive        |
| `§PairSeparator:=`      | Separator between keys and values       |

The `§` character (Unicode U+00A7, Section Sign) was chosen because it is
unlikely to appear in file paths or backup names.

### Cross-References Between Sections

    TaskSource={ *§* da6f0fd7-7564-4d9d-b9a0-41406aadc207 *§* }

The `{ *§* GUID *§* }` pattern is Cobian's pointer syntax. The application
resolves these at runtime by looking up the GUID as a section elsewhere in
the same file. All sections live flat in the same file — relationships are
expressed via GUID references, not nesting.

---

## File Structure

    ┌─────────────────────────────────────────────────────┐
    │  ROOT SECTION  (index of all tasks)                 │
    │  BackupTask={ *§* TASK-A-GUID *§* }                 │
    │  BackupTask={ *§* TASK-B-GUID *§* }                 │
    └─────────────────────────────────────────────────────┘
    ┌─────────────────────────────────────────────────────┐
    │  TASK SECTION                                       │
    │  TaskSource={ *§* SOURCE-GUID *§* }                 │
    │  TaskDestination={ *§* DEST-GUID *§* }              │
    │  TaskSchedule={ *§* SCHED-GUID *§* }                │
    └─────────────────────────────────────────────────────┘
    ┌─────────────────────────────────────────────────────┐
    │  SOURCE SECTION                                     │
    │  SDSftp={ *§* SFTP-GUID *§* }   ← always required  │
    │  SDFtp={ *§*  FTP-GUID  *§* }   ← always required  │
    └─────────────────────────────────────────────────────┘
    ... SFTP section, SFTP Proxy, FTP section, FTP Proxy ...
    ... DESTINATION SECTION (same structure as source)   ...
    ┌─────────────────────────────────────────────────────┐
    │  SCHEDULE SECTION                                   │
    │  SchSchedule=1  (Daily)                             │
    │  SchDateAndTime=2026-04-05 02:00:00:000             │
    └─────────────────────────────────────────────────────┘

> **Important:** Even for plain local paths, the format requires `SDSftp=`
> and `SDFtp=` sub-sections with proxy sub-sections. Omitting them causes
> Cobian to fail parsing the task.

---

## Section Count Per Task

| #   | Section Type           | Notes                                      |
| --- | ---------------------- | ------------------------------------------ |
| 1   | Task                   | Name, type, refs to source/dest/schedule   |
| 2   | Source path            | `SDKind=1`, `SDPath=`                      |
| 3   | Source SFTP            | Empty for local paths — required by format |
| 4   | Source SFTP Proxy      | Empty — required by SFTP section           |
| 5   | Source FTP             | Empty for local paths — required by format |
| 6   | Source FTP Proxy       | Empty — required by FTP section            |
| 7   | Destination path       | `SDKind=1`, `SDPath=`                      |
| 8   | Destination SFTP       | Empty — required                           |
| 9   | Destination SFTP Proxy | Empty — required                           |
| 10  | Destination FTP        | Empty — required                           |
| 11  | Destination FTP Proxy  | Empty — required                           |
| 12  | Schedule               | `SchSchedule`, `SchDateAndTime`            |
| +   | Root index entry       | `BackupTask=` added to root section        |

**13 sections per task × 4 SQL tasks = 52 new sections** appended to the file.

---

## Key Properties Reference

### Task Section

| Key                            | Type   | Values / Notes                                         |
| ------------------------------ | ------ | ------------------------------------------------------ |
| `TaskId`                       | GUID   | Internal identity — separate from section GUID         |
| `TaskName`                     | string | Display name in Cobian UI                              |
| `TaskGroup`                    | string | Group/folder name. Empty = ungrouped                   |
| `TaskEnabled`                  | bool   | `True` / `False`                                       |
| `TaskBackupType`               | int    | `0`=Full, `1`=Incremental, `2`=Differential, `3`=Dummy |
| `TaskSeparatedBackups`         | bool   | `True` = creates dated versioned copies                |
| `TaskUseVolumeShadowCopies`    | bool   | VSS — `False` for `.bak` files (not locked)            |
| `TaskFullCopiesToKeep`         | int    | Versioned full copies to retain                        |
| `TaskDifferentialCopiesToKeep` | int    | Versioned differential copies to retain                |
| `TaskCompression`              | int    | `0`=None, `1`=Zip, `2`=7z, `3`=Tar                     |
| `TaskPriority`                 | int    | `1`=Low, `2`=Normal, `3`=High                          |
| `TaskSource`                   | ref    | `{ *§* GUID *§* }` — repeatable                        |
| `TaskDestination`              | ref    | `{ *§* GUID *§* }`                                     |
| `TaskSchedule`                 | ref    | `{ *§* GUID *§* }`                                     |

### Source / Destination Section

| Key      | Type   | Values / Notes                    |
| -------- | ------ | --------------------------------- |
| `SDKind` | int    | `1`=Local/UNC, `2`=FTP, `3`=SFTP  |
| `SDPath` | string | e.g. `C:\CobianSqlStaging\ProGet` |
| `SDSftp` | ref    | Required even for local paths     |
| `SDFtp`  | ref    | Required even for local paths     |

### Schedule Section

| Key                | Type     | Values / Notes                                                                    |
| ------------------ | -------- | --------------------------------------------------------------------------------- |
| `SchSchedule`      | int      | `0`=Once, `1`=Daily, `2`=Weekly, `3`=Monthly, `4`=Yearly, `5`=Timer, `6`=Manual  |
| `SchDateAndTime`   | datetime | `YYYY-MM-DD HH:MM:SS:` (trailing colon, no ms) — format written by Cobian UI     |
| `SchDaysOfWeek`    | int      | Repeating key (§DuplicatedKeys:True): `0`=Sun, `1`=Mon … `6`=Sat                 |
| `SchTimer`         | int      | Timer interval in minutes (`SchSchedule=5` only)                                  |

> **Weekly schedule — confirmed format (2026-04-05, from live MainList.lst):**
> ```
> SchSchedule=2
> SchDateAndTime=2026-04-05 01:50:00:   ← trailing colon, no milliseconds
> SchDaysOfWeek=0                        ← Sunday only  (one entry)
> ```
> For Mon–Sat:
> ```
> SchDaysOfWeek=1
> SchDaysOfWeek=2
> SchDaysOfWeek=3
> SchDaysOfWeek=4
> SchDaysOfWeek=5
> SchDaysOfWeek=6
> ```
> The `SchDaysOfWeek` key repeats once per selected day.  The section **must** have
> `§DuplicatedKeys:True` (already required by the schedule section format).
>
> Scripts must use `SchSchedule=2` and the `SchDaysOfWeek=N` multi-entry pattern
> to produce correct weekly schedules directly — no manual UI update required.

### Encrypted Password Format

    #Cob2#00028<base64-ciphertext>=000010

All password fields use this proprietary format. Scripts copy blank/unused
values verbatim from the existing file. Never enter real credentials via
script — always use the Cobian UI.

---

## How `New-CobianSqlJobs.ps1` Works

### 1 — Stop the Service

    `Stop-Service -Name $svc.Name -Force`

Cobian holds an exclusive write lock on `MainList.lst`. Must be stopped first.

### 2 — Backup the Original File

    `Copy-Item $ListPath "$ListPath.bak_20260402_180000"`

Timestamped backup created before any changes.

### 3 — Read and Detect Native Encoding

```powershell
$sr = [System.IO.StreamReader]::new($ListPath, $true)   # detectEncodingFromBom=true
$raw = $sr.ReadToEnd()
$fileEncoding = $sr.CurrentEncoding
$sr.Dispose()
```

Read whole file as one string so multi-line section patterns can be matched.
The encoding is detected from the BOM and stored so step 10 can write it back unchanged.

> **Why this matters:** When the Cobian UI modifies and saves `MainList.lst` (e.g. when the
> user changes a schedule), it rewrites the file as **UTF-16 LE** (Unicode with BOM).
> If the script reads as UTF-8 (auto-detecting the BOM) but writes back without the BOM as
> UTF-8, Cobian throws `ArgumentOutOfRangeException` on startup and refuses to run.
> Always preserve the original encoding.

### 4 — Discover Root GUID (Not Hardcoded)

```powershell
$raw -match '<§- ([0-9a-f]{8}-[0-9a-f]{4}-...) -§>'
$rootGuid = $Matches[1]
```

The root GUID is found by matching the first section header. This makes the
script resilient to reinstalls or different Cobian versions.

### 5 — Idempotency Check

```powershell
$existingNames = [regex]::Matches($raw, '(?m)^TaskName=(.+)$') |
                 ForEach-Object { $_.Groups.Value.Trim() }[1]
```

Scans all `TaskName=` values. Any job whose name already exists is skipped.
The script is safe to re-run.

### 6 — Generate Fresh GUIDs

```powershell
$tg  = [guid]::NewGuid().ToString().ToLower()  # task section
$sg  = [guid]::NewGuid().ToString().ToLower()  # source path
$ssg = [guid]::NewGuid().ToString().ToLower()  # source SFTP
$ssp = [guid]::NewGuid().ToString().ToLower()  # source SFTP proxy
$sfg = [guid]::NewGuid().ToString().ToLower()  # source FTP
$sfp = [guid]::NewGuid().ToString().ToLower()  # source FTP proxy
# ... 5 more for destination + 1 for schedule
```

13 UUIDs per task, lowercased to match existing file style.

### 7 — Build Sections with Here-Strings

```powershell
function Sec-Path([string]$g, [string]$path, [string]$sftp, [string]$ftp) {
    return @"

<§- $g -§>
§DuplicatedKeys:False
§CaseSensitive:False
§PairSeparator:=
SDKind=1
SDPath=$path
SDSftp={ *§* $sftp *§* }
SDFtp={ *§* $ftp *§* }
<§§- $g -§§>
"@
}
```

PowerShell here-strings allow the exact multi-line format including `§`
characters without any escaping.

### 8 — Inject Root Index Entries

```powershell
$closeTag  = "<§§- $rootGuid -§§>"
$insertion = "BackupTask={ *§* $newTaskGuid *§* }`r`n"
$raw       = $raw.Replace($closeTag, $insertion + $closeTag)
```

New `BackupTask=` lines are inserted immediately before the root section's
closing tag. `.Replace()` (not regex) is used because the close tag already
contains unique characters that need no escaping. The root section's
`§DuplicatedKeys:True` explicitly permits multiple `BackupTask=` lines.

### 9 — Append All 52 New Sections

```powershell
$raw += $newSections.ToString()
```

All sections appended to end of file. Cobian's parser searches the entire
file for GUIDs — order does not matter.

### 10 — Write and Restart

```powershell
[System.IO.File]::WriteAllText($ListPath, $raw, $fileEncoding)
Start-Service -Name $svc.Name
```

`WriteAllText` used (not `Set-Content`) for binary-exact encoding control.
`$fileEncoding` was captured from the BOM in step 3 — preserves UTF-16 LE when the
Cobian UI last saved the file, or UTF-8 if the file has never been touched by the UI.

---

## How `New-SqlWinScheduledTasks.ps1` Works

Creates four Windows Scheduled Tasks under `\SQL Server Backups\`:

    01:50  sqlcmd → ProGet Full (Sunday) or Differential (Mon–Sat)
                 → C:\CobianSqlStaging\ProGet\ProGet.bak
    02:00  Cobian copies staging → D:\Backups\SQL\ProGet\

    02:20  sqlcmd → BuildMaster Full (Sunday) or Differential (Mon–Sat)
                 → C:\CobianSqlStaging\BuildMaster\BuildMaster.bak
    02:30  Cobian copies staging → D:\Backups\SQL\BuildMaster\

Each task runs as `NT AUTHORITY\SYSTEM` (same as Cobian — already has
sysadmin on SQL Server). The reason for Windows Task Scheduler rather than
Cobian pre-events is that the pre-event key names were not present in the
existing `.lst` file and could not be confirmed safely.

---

## Recovery Procedure

```powershell
# 1. Stop service
Stop-Service -Name (Get-Service | Where-Object DisplayName -like '*Cobian*').Name -Force

# 2. Restore most recent backup
$bak = Get-ChildItem 'C:\Program Files\Cobian Reflector\Lists\' -Filter '*.bak_*' |
       Sort-Object LastWriteTime -Descending | Select-Object -First 1
Copy-Item $bak.FullName 'C:\Program Files\Cobian Reflector\Lists\MainList.lst' -Force

# 3. Restart
Start-Service -Name (Get-Service | Where-Object DisplayName -like '*Cobian*').Name
```

---

## Object Graph — One Task

    ROOT SECTION
      └─ BackupTask ─────────────────────────► TASK SECTION
                                                 ├─ TaskSource ───► SOURCE PATH
                                                 │                    ├─ SDSftp ──► SFTP ──► SFTP PROXY
                                                 │                    └─ SDFtp  ──► FTP  ──► FTP  PROXY
                                                 ├─ TaskDestination ► DEST PATH
                                                 │                    ├─ SDSftp ──► SFTP ──► SFTP PROXY
                                                 │                    └─ SDFtp  ──► FTP  ──► FTP  PROXY
                                                 └─ TaskSchedule ──► SCHEDULE SECTION

    13 sections per task · 4 tasks = 52 sections + 4 root entries
