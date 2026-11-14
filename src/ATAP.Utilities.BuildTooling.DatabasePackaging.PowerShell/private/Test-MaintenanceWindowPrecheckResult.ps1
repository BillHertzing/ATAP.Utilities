function Test-MaintenanceWindowPrecheckResult {
  <#
  .SYNOPSIS
    Evaluates a WindowPrecheck.sql capture and the disk space into a PASS or FAIL verdict.
  .DESCRIPTION
    Pure apart from the drive-space reads. Checks, each recorded by name:
      SqlCompleted       the batch completed (a THROW 63021/63031/63033/63041/63042/63060/63061/63062 fails it);
      WindowOpen         exactly one row; OtherSessionCount 0; ONLINE, MULTI_USER, not read-only;
      NoOtherSessions    the OtherSessions set is empty;
      RunnerRights       VIEW SERVER STATE (or sysadmin), CREATE ANY DATABASE, msdb backupset and
                         restorehistory SELECT, and CONTROL on the catalog are all 1;
      NoNameCollision    no NameCheck row equals the clone name or the gate's rehearsal name;
      NoClonePathInUse   the ClonePathCheck set is empty;
      DiskSpace          the backup drive has at least 2x the source size free, the clone data drive at
                         least 2x the data size and the clone log drive at least 2x the log size.
    A set is found by its EvidenceSet column, never by position.
  .PARAMETER Capture
    The Invoke-MaintenanceSqlDataSet result.
  .PARAMETER Binding
    The validated binding.
  .PARAMETER RehearsalName
    The gate's rehearsal clone name for this build and tier.
  .OUTPUTS
    Ordered dictionary: Status (Passed or Failed), Checks, FailedChecks, SourceDataBytes, SourceLogBytes.
  .EXAMPLE
    Test-MaintenanceWindowPrecheckResult -Capture $c -Binding $b -RehearsalName $r
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines. DB-Runner-S1-Foundation.
  .LINK
    Invoke-DatabaseMaintenanceWindow
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]$Capture,
    [Parameter(Mandatory)]$Binding,
    [Parameter(Mandatory)][string]$RehearsalName
  )
  begin { $fn = 'Test-MaintenanceWindowPrecheckResult'; $mn = 'ATAP.Utilities.BuildTooling.DatabasePackaging.PowerShell' }
  process {
    $rowsOf = {
      param($name)
      @(foreach ($set in @($Capture.ResultSets)) { foreach ($row in @($set)) { if ($row -is [Collections.IDictionary] -and [string]$row['EvidenceSet'] -ceq $name) { $row } } })
    }
    $checks = [ordered]@{}
    $checks.SqlCompleted = ([string]$Capture.Status -ceq 'Completed')
    # @(...) everywhere: a single-row set must stay an array, or .Count counts the row's keys.
    $open = @(& $rowsOf 'WindowOpen')
    $checks.WindowOpen = ($open.Count -eq 1 -and [long]$open[0]['OtherSessionCount'] -eq 0 -and [string]$open[0]['state_desc'] -ceq 'ONLINE' -and
      [string]$open[0]['user_access_desc'] -ceq 'MULTI_USER' -and -not [bool]$open[0]['is_read_only'])
    $checks.NoOtherSessions = ($checks.SqlCompleted -and @(& $rowsOf 'OtherSessions').Count -eq 0)
    $rights = @(& $rowsOf 'RunnerRights')
    $checks.RunnerRights = ($rights.Count -eq 1 -and
      ([int]$rights[0]['IsSysadmin'] -eq 1 -or [int]$rights[0]['ViewServerState'] -eq 1) -and
      [int]$rights[0]['CreateAnyDatabase'] -eq 1 -and [int]$rights[0]['MsdbBackupsetSelect'] -eq 1 -and
      [int]$rights[0]['MsdbRestoreHistorySelect'] -eq 1 -and [int]$rights[0]['CatalogControl'] -eq 1)
    $names = @(& $rowsOf 'NameCheck' | ForEach-Object { [string]$_['name'] })
    $checks.NoNameCollision = ($checks.SqlCompleted -and $names -cnotcontains [string]$Binding.cloneName -and $names -cnotcontains $RehearsalName)
    $checks.NoClonePathInUse = ($checks.SqlCompleted -and @(& $rowsOf 'ClonePathCheck').Count -eq 0)

    $files = @(& $rowsOf 'SourceFiles')
    $dataBytes = [long](($files | Where-Object { [string]$_['type_desc'] -ceq 'ROWS' } | ForEach-Object { [long]$_['SizePages'] } | Measure-Object -Sum).Sum) * 8192
    $logBytes = [long](($files | Where-Object { [string]$_['type_desc'] -ceq 'LOG' } | ForEach-Object { [long]$_['SizePages'] } | Measure-Object -Sum).Sum) * 8192
    $disk = [ordered]@{ BackupFree = $null; CloneDataFree = $null; CloneLogFree = $null }
    $diskOk = $false
    if ($files.Count -gt 0 -and $dataBytes -gt 0) {
      $disk.BackupFree = Get-MaintenanceWindowDriveFreeBytes -Path ([string]$Binding.backupPath)
      $disk.CloneDataFree = Get-MaintenanceWindowDriveFreeBytes -Path ([string]$Binding.cloneDataPath)
      $disk.CloneLogFree = Get-MaintenanceWindowDriveFreeBytes -Path ([string]$Binding.cloneLogPath)
      $diskOk = ($disk.BackupFree -ge 2 * ($dataBytes + $logBytes) -and $disk.CloneDataFree -ge 2 * $dataBytes -and $disk.CloneLogFree -ge 2 * $logBytes)
    }
    $checks.DiskSpace = $diskOk

    $failed = @($checks.Keys | Where-Object { -not $checks[$_] })
    [ordered]@{
      Status          = $(if ($failed.Count -eq 0) { 'Passed' } else { 'Failed' })
      Checks          = $checks
      FailedChecks    = $failed
      SqlErrorNumber  = $Capture.SqlErrorNumber
      SourceDataBytes = $dataBytes
      SourceLogBytes  = $logBytes
      DriveFreeBytes  = $disk
    }
  }
  end {}
}
