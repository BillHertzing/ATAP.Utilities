# Archive — ATAP.Utilities.DatabaseManagement.PowerShell

Scripts here are no longer in active use but are retained for reference.

## New-SqlWinScheduledTasks.ps1

**Archived:** 2026-04-02
**Current location:** `src/_AdminRequiresHoldingPen/ATAP.Utilities.DatabaseManagement.Powershell/archive/New-SqlWinScheduledTasks.ps1`
**Reason:** Replaced by `New-CobianSqlJobs.ps1`, which schedules SQL Server backups via
Cobian Reflector pre-events (`Invoke-SqlServerBackup.ps1 -SevenZipCompress`) rather than
Windows Task Scheduler.

**Keep because:** If a future need arises to schedule `sqlcmd`-based jobs via Windows Task
Scheduler (e.g., on a machine that does not run Cobian), this script provides a working
starting point.
