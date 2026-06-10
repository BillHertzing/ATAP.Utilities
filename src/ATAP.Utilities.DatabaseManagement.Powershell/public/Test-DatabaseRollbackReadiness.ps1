#Requires -Version 7.0
function Test-DatabaseRollbackReadiness {
  <#
.SYNOPSIS
    Checks whether a valid pre-migration snapshot is available for rollback.

.DESCRIPTION
    Reads the pre-migration-snapshot-evidence.json written by
    New-DatabasePreMigrationSnapshot and verifies:
      1. The evidence file exists and parses correctly.
      2. The backup file recorded in the evidence exists on disk.
      3. The evidence timestamp is within MaxAgeMinutes of the current time.

    Returns IsReady = $true only when all three checks pass. Returns $false with a
    human-readable Reason string otherwise. Does not connect to SQL Server.

.PARAMETER EvidencePath
    Absolute path to the pre-migration-snapshot-evidence.json file written by
    New-DatabasePreMigrationSnapshot.

.PARAMETER MaxAgeMinutes
    Maximum age (in minutes) of the evidence timestamp before the snapshot is
    considered stale. Default: 60. A stale snapshot may not be safe to use as a
    rollback target after several migration steps.

.OUTPUTS
    [PSCustomObject] with properties:
      IsReady   [bool]    $true if all checks pass
      Reason    [string]  Human-readable explanation (populated when IsReady = $false)
      BackupFile [string]  Absolute path of the .bak file recorded in the evidence

.EXAMPLE
    Test-DatabaseRollbackReadiness `
        -EvidencePath 'C:\..._generated\database-packages\ATAPUtilities\pre-migration-snapshot-evidence.json'

.EXAMPLE
    Test-DatabaseRollbackReadiness `
        -EvidencePath '...\pre-migration-snapshot-evidence.json' -MaxAgeMinutes 30

.NOTES
    AI assisted using Powershell.instructions.md as guidelines.
    Task: TASKS_V4-DBA1.md DBA1-T05 / V4-E13.
#>
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$EvidencePath,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 10080)]
    [int]$MaxAgeMinutes = 60
  )

  begin {
    $fn = 'Test-DatabaseRollbackReadiness'
    $mn = 'ATAP.Utilities.DatabaseManagement.Powershell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
      -Message "Entering $fn (EvidencePath='$EvidencePath', MaxAgeMinutes=$MaxAgeMinutes)" -Tag 'Trace'
  }

  process {
    # ── Check 1: evidence file exists ─────────────────────────────────────────
    if (-not (Test-Path $EvidencePath -PathType Leaf)) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
        -Message "Evidence file not found: '$EvidencePath'" -Tag 'Rollback'
      return Write-Output ([PSCustomObject]@{
          IsReady    = $false
          Reason     = "Evidence file not found: '$EvidencePath'"
          BackupFile = $null
        })
    }

    # ── Check 2: evidence file parses ─────────────────────────────────────────
    $evidence = $null
    try {
      $evidence = Get-Content $EvidencePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    } catch {
      $reason = "Evidence file could not be parsed: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message $reason -Tag 'Rollback'
      return Write-Output ([PSCustomObject]@{
          IsReady    = $false
          Reason     = $reason
          BackupFile = $null
        })
    }

    $backupFile = $evidence.backupFile

    # ── Check 3: backup file exists ───────────────────────────────────────────
    if (-not $backupFile -or -not (Test-Path $backupFile -PathType Leaf)) {
      $reason = "Backup file does not exist at recorded path: '$backupFile'"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message $reason -Tag 'Rollback'
      return Write-Output ([PSCustomObject]@{
          IsReady    = $false
          Reason     = $reason
          BackupFile = $backupFile
        })
    }

    # ── Check 4: evidence age ─────────────────────────────────────────────────
    $snapshotTime = $null
    try {
      $snapshotTime = [datetime]::Parse($evidence.timestamp, $null,
        [System.Globalization.DateTimeStyles]::RoundtripKind)
    } catch {
      $reason = "Evidence timestamp '$($evidence.timestamp)' could not be parsed: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message $reason -Tag 'Rollback'
      return Write-Output ([PSCustomObject]@{
          IsReady    = $false
          Reason     = $reason
          BackupFile = $backupFile
        })
    }

    $ageMinutes = ([datetime]::UtcNow - $snapshotTime.ToUniversalTime()).TotalMinutes
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
      -Message "Snapshot age: $([math]::Round($ageMinutes, 1)) minutes (max allowed: $MaxAgeMinutes)" -Tag 'Rollback'

    if ($ageMinutes -gt $MaxAgeMinutes) {
      $reason = "Snapshot is $([math]::Round($ageMinutes, 0)) minutes old; maximum allowed is $MaxAgeMinutes minutes."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message $reason -Tag 'Rollback'
      return Write-Output ([PSCustomObject]@{
          IsReady    = $false
          Reason     = $reason
          BackupFile = $backupFile
        })
    }

    # ── All checks passed ─────────────────────────────────────────────────────
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
      -Message "Rollback readiness check passed." -Tag 'Rollback'

    Write-Output ([PSCustomObject]@{
        IsReady    = $true
        Reason     = $null
        BackupFile = $backupFile
      })
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Exiting $fn" -Tag 'Trace'
  }
}
