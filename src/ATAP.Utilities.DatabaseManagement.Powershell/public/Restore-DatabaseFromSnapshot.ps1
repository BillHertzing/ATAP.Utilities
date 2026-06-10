#Requires -Version 7.0
function Restore-DatabaseFromSnapshot {
  <#
.SYNOPSIS
    Restores a SQL Server database from a pre-migration snapshot backup.

.DESCRIPTION
    Uses dbatools Restore-DbaDatabase to restore the .bak file recorded in a
    pre-migration snapshot evidence file. After the restore completes, queries
    `flyway_schema_history` via Get-FlywaySchemaVersion and verifies the resulting
    schema version matches the version captured at snapshot time.

.PARAMETER BackupPath
    Absolute path to the .bak file to restore. Must exist and end in .bak.

.PARAMETER EvidenceFile
    Absolute path to the pre-migration-snapshot-evidence.json written by
    New-DatabasePreMigrationSnapshot. When supplied, the Flyway version in the
    evidence is used for post-restore verification.

.PARAMETER DatabaseName
    Target database name.

.PARAMETER SqlInstance
    SQL Server instance string, e.g. 'localhost\SQLEXPRESS'.

.PARAMETER WithReplace
    Pass -WithReplace to Restore-DbaDatabase (required when the database already
    exists). Default: $false.

.OUTPUTS
    [PSCustomObject] with properties:
      Restored        [bool]     $true if the restore succeeded
      VerifiedVersion [string]   Flyway version confirmed after restore (or $null on failure)
      Errors          [string[]] Error messages if Restored = $false

.EXAMPLE
    Restore-DatabaseFromSnapshot `
        -BackupPath 'C:\Temp\dbsnap-ATAPUtilities-20260527_110000\ATAPUtilities_PREMIG_20260527_110000.bak' `
        -EvidenceFile 'C:\..._generated\database-packages\ATAPUtilities\pre-migration-snapshot-evidence.json' `
        -DatabaseName ATAPUtilities -SqlInstance 'localhost\SQLEXPRESS' -WithReplace

.NOTES
    AI assisted using Powershell.instructions.md as guidelines.
    Task: TASKS_V4-DBA1.md DBA1-T05 / V4-E13.
#>
  [CmdletBinding(SupportsShouldProcess)]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$BackupPath,

    [Parameter(Mandatory = $false)]
    [string]$EvidenceFile,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$DatabaseName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$SqlInstance,

    [Parameter(Mandatory = $false)]
    [switch]$WithReplace
  )

  begin {
    $fn = 'Restore-DatabaseFromSnapshot'
    $mn = 'ATAP.Utilities.DatabaseManagement.Powershell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
      -Message "Entering $fn (BackupPath='$BackupPath', DatabaseName='$DatabaseName')" -Tag 'Trace'

    if (-not (Test-Path $BackupPath -PathType Leaf)) {
      $PSCmdlet.ThrowTerminatingError(
        [System.Management.Automation.ErrorRecord]::new(
          [System.IO.FileNotFoundException]::new("Backup file not found: '$BackupPath'"),
          'BackupNotFound', [System.Management.Automation.ErrorCategory]::ObjectNotFound, $BackupPath))
    }
  }

  process {
    $errors = [System.Collections.Generic.List[string]]::new()
    $restored = $false
    $verifiedVersion = $null

    # ── Load expected Flyway version from evidence file ───────────────────────
    $expectedFlywayVersion = $null
    if ($EvidenceFile) {
      if (Test-Path $EvidenceFile -PathType Leaf) {
        try {
          $evidence = Get-Content $EvidenceFile -Raw | ConvertFrom-Json -ErrorAction Stop
          $expectedFlywayVersion = $evidence.flywayVersion
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
            -Message "Expected Flyway version from evidence: '$expectedFlywayVersion'" -Tag 'Restore'
        } catch {
          $errors.Add("Could not parse evidence file '$EvidenceFile': $($_.Exception.Message)")
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning `
            -Message $errors[-1] -Tag 'Restore'
        }
      } else {
        $errors.Add("Evidence file not found: '$EvidenceFile'")
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message $errors[-1] -Tag 'Restore'
      }
    }

    # ── Restore database ──────────────────────────────────────────────────────
    if ($PSCmdlet.ShouldProcess($SqlInstance, "Restore-DbaDatabase $DatabaseName from $BackupPath")) {
      try {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
          -Message "Starting Restore-DbaDatabase on '$SqlInstance' db='$DatabaseName'" -Tag 'Restore'

        $restoreParams = @{
          SqlInstance     = $SqlInstance
          Path            = $BackupPath
          DatabaseName    = $DatabaseName
          EnableException = $true
          ErrorAction     = 'Stop'
        }
        if ($WithReplace) { $restoreParams['WithReplace'] = $true }

        Restore-DbaDatabase @restoreParams | Out-Null
        $restored = $true
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
          -Message "Restore-DbaDatabase succeeded." -Tag 'Restore'
      } catch {
        $errors.Add("Restore failed: $($_.Exception.Message)")
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errors[-1] -Tag 'Restore'
      }
    } else {
      # WhatIf path — simulate success
      $restored = $true
    }

    # ── Verify Flyway version post-restore ────────────────────────────────────
    if ($restored) {
      try {
        $rows = Get-FlywaySchemaVersion -SqlInstance $SqlInstance -DatabaseName $DatabaseName `
                  -IntegratedSecurity -ErrorAction Stop
        $latestRow = $rows | Where-Object { $_.Success -eq $true } |
                      Sort-Object InstalledRank -Descending | Select-Object -First 1
        $verifiedVersion = if ($latestRow) { $latestRow.Version } else { 'none' }

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
          -Message "Post-restore Flyway version: '$verifiedVersion'" -Tag 'Restore'

        if ($expectedFlywayVersion -and ($verifiedVersion -ne $expectedFlywayVersion)) {
          $msg = "Post-restore Flyway version '$verifiedVersion' does not match expected '$expectedFlywayVersion'."
          $errors.Add($msg)
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message $msg -Tag 'Restore'
          $restored = $false
        }
      } catch {
        $errors.Add("Could not verify Flyway version after restore: $($_.Exception.Message)")
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message $errors[-1] -Tag 'Restore'
      }
    }

    Write-Output ([PSCustomObject]@{
        Restored        = $restored
        VerifiedVersion = $verifiedVersion
        Errors          = $errors.ToArray()
      })
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Exiting $fn" -Tag 'Trace'
  }
}
