<#
.SYNOPSIS
    Creates four Windows Scheduled Tasks that run sqlcmd to write .bak files
    into the Cobian staging folders before Cobian Reflector copies them.

.DESCRIPTION
    Timing:
      01:50 → sqlcmd ProGet Full (Sunday) or Differential (Mon-Sat)
               → C:\CobianSqlStaging\ProGet\ProGet.bak
      02:00 → Cobian copies ProGet staging to D:\Backups\SQL\ProGet

      02:20 → sqlcmd BuildMaster Full (Sunday) or Differential (Mon-Sat)
               → C:\CobianSqlStaging\BuildMaster\BuildMaster.bak
      02:30 → Cobian copies BuildMaster staging to D:\Backups\SQL\BuildMaster

    The 10-minute gap between sqlcmd completing and Cobian running ensures
    the .bak file is fully written before Cobian copies it.

.PARAMETER SqlInstance
    SQL Server instance name.
    Default: localhost
    For a named instance use e.g.: utat022\PROD

.PARAMETER StagingRoot
    Must match -StagingRoot used in New-CobianSqlJobs.ps1.
    Default: C:\CobianSqlStaging

.NOTES
    ► Run as Administrator on utat022
    ► Runs sqlcmd as NT AUTHORITY\SYSTEM — same account as Cobian,
      already has sysadmin on the SQL instance (no extra grants needed)
    ► Re-running removes and recreates tasks (idempotent)
    ► sqlcmd.exe must be on the system PATH
      (installed with SQL Server tools / SSMS)
#>

#Requires -RunAsAdministrator

param(
  [string]$SqlInstance = 'localhost',
  [string]$StagingRoot = 'C:\CobianSqlStaging'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-SqlTask {
  param(
    [string]   $TaskName,
    [string]   $Database,
    [string]   $BakPath,
    [string]   $BackupSql,
    [string]   $StartTime,
    [string[]] $DaysOfWeek
  )

  # Remove existing task if present (idempotent)
  if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Warning "  Replaced existing task: $TaskName"
  }

  # sqlcmd arguments:
  #   -S  instance name
  #   -E  Windows Authentication (NT AUTHORITY\SYSTEM)
  #   -b  exit with error code on SQL failure (so Task Scheduler records failures)
  #   -Q  query to execute then exit
  $sqlArgs = "-S `"$SqlInstance`" -E -b -Q `"$BackupSql`""

  $action = New-ScheduledTaskAction `
    -Execute 'sqlcmd.exe' `
    -Argument $sqlArgs

  $trigger = New-ScheduledTaskTrigger `
    -Weekly `
    -DaysOfWeek $DaysOfWeek `
    -At $StartTime

  $principal = New-ScheduledTaskPrincipal `
    -UserId 'NT AUTHORITY\SYSTEM' `
    -LogonType ServiceAccount `
    -RunLevel Highest

  $settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit (New-TimeSpan -Hours 2) `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew

  Register-ScheduledTask `
    -TaskName $TaskName `
    -TaskPath '\SQL Server Backups\' `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Settings $settings `
    -Description "sqlcmd backup of [$Database] to $BakPath" |
    Out-Null

  Write-Host ('  [+] {0,-45} ({1} at {2})' -f $TaskName, $DaysOfWeek[0], $StartTime) -ForegroundColor Green
}

# ── Main ──────────────────────────────────────────────────────────────────────

Write-Host "`n===== New-SqlWinScheduledTasks =====" -ForegroundColor Cyan
Write-Host "SQL Instance : $SqlInstance"
Write-Host "Staging root : $StagingRoot"
Write-Host ''

# Ensure staging folders exist
foreach ($db in @('ProGet', 'BuildMaster')) {
  $dir = Join-Path $StagingRoot $db
  if (-not (Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    Write-Host "  Created: $dir"
  }
}

# ── ProGet ────────────────────────────────────────────────────────────────────
$pgBak = "$StagingRoot\ProGet\ProGet.bak"

New-SqlTask `
  -TaskName 'SQL Backup - ProGet - Full' `
  -Database 'ProGet' `
  -BakPath $pgBak `
  -BackupSql "BACKUP DATABASE [ProGet] TO DISK = N'$pgBak' WITH FORMAT, INIT, NAME = N'ProGet-Full', COMPRESSION, STATS = 10" `
  -StartTime '01:50' `
  -DaysOfWeek @('Sunday')

New-SqlTask `
  -TaskName 'SQL Backup - ProGet - Differential' `
  -Database 'ProGet' `
  -BakPath $pgBak `
  -BackupSql "BACKUP DATABASE [ProGet] TO DISK = N'$pgBak' WITH DIFFERENTIAL, INIT, NAME = N'ProGet-Diff', COMPRESSION, STATS = 10" `
  -StartTime '01:50' `
  -DaysOfWeek @('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday')

# ── BuildMaster ───────────────────────────────────────────────────────────────
$bmBak = "$StagingRoot\BuildMaster\BuildMaster.bak"

New-SqlTask `
  -TaskName 'SQL Backup - BuildMaster - Full' `
  -Database 'BuildMaster' `
  -BakPath $bmBak `
  -BackupSql "BACKUP DATABASE [BuildMaster] TO DISK = N'$bmBak' WITH FORMAT, INIT, NAME = N'BuildMaster-Full', COMPRESSION, STATS = 10" `
  -StartTime '02:20' `
  -DaysOfWeek @('Sunday')

New-SqlTask `
  -TaskName 'SQL Backup - BuildMaster - Differential' `
  -Database 'BuildMaster' `
  -BakPath $bmBak `
  -BackupSql "BACKUP DATABASE [BuildMaster] TO DISK = N'$bmBak' WITH DIFFERENTIAL, INIT, NAME = N'BuildMaster-Diff', COMPRESSION, STATS = 10" `
  -StartTime '02:20' `
  -DaysOfWeek @('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday')

# ── Summary ───────────────────────────────────────────────────────────────────
Write-Host @"

===== Done =====
Verify in Task Scheduler → Task Scheduler Library → \SQL Server Backups\
Four tasks should appear.

Test each by right-clicking → Run, then confirm .bak files appear:
  $StagingRoot\ProGet\ProGet.bak
  $StagingRoot\BuildMaster\BuildMaster.bak

Check the Last Run Result column in Task Scheduler — 0x0 = success.
If sqlcmd.exe is not found, install SQL Server Management Tools or add
its folder to the system PATH, then re-run this script.
"@ -ForegroundColor White
