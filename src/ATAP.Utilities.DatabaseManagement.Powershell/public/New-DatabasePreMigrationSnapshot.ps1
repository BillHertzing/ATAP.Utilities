#Requires -Version 7.0
function New-DatabasePreMigrationSnapshot {
  <#
.SYNOPSIS
    Takes a SQL Server backup before a migration run and writes a JSON evidence record.

.DESCRIPTION
    Calls Backup-DbaDatabase (dbatools) to create a Full backup of the target database
    immediately before a Flyway migration is applied. Captures the current Flyway schema
    version at backup time, computes the SHA-256 of the .bak file, and writes all
    metadata to a JSON evidence file under:

        _generated/database-packages/<Application>/pre-migration-snapshot-evidence.json

    The evidence file is consumed by Restore-DatabaseFromSnapshot and
    Test-DatabaseRollbackReadiness to validate rollback viability.

.PARAMETER Application
    Short application name used to locate the database configuration and to scope the
    evidence file output folder (e.g. 'ATAPUtilities').

.PARAMETER DatabaseName
    Name of the SQL Server database to back up.

.PARAMETER SqlInstance
    SQL Server instance string, e.g. 'localhost\SQLEXPRESS'. Defaults to
    "$($global:settings[$global:configRootKeys['DatabaseHostConfigRootKey']])\$($global:settings[$global:configRootKeys['SqlInstanceConfigRootKey']])"
    when not supplied.

.PARAMETER DBConnectionStringSecretName
    Bitwarden secret name whose notes field contains the target SQL connection
    string. When supplied, the SQL instance is derived from that connection and
    the same secret is used to read the Flyway schema version.

.PARAMETER BackupPath
    Destination folder for the .bak file. Defaults to a timestamped subdirectory
    under $env:TEMP when not supplied.

.PARAMETER RepositoryRoot
    Root of the repository. Defaults to the value returned by Get-RepositoryRoot.
    Used to resolve the _generated/ output folder.

.OUTPUTS
    [PSCustomObject] with properties:
      Application       [string]    Name of the application
      DatabaseName      [string]    Database that was backed up
      BackupFile        [string]    Absolute path of the .bak file written
      BackupSizeMB      [double]    Size of the .bak file in megabytes
      Sha256            [string]    Lower-case hex SHA-256 of the .bak file
      Timestamp         [string]    ISO-8601 UTC timestamp of the backup
      FlywayVersion     [string]    Flyway schema version at time of backup
      EvidenceFile      [string]    Absolute path of the evidence JSON written
      SnapshotPath      [string]    Alias of BackupFile for pipeline consumers

.EXAMPLE
    New-DatabasePreMigrationSnapshot -Application ATAPUtilities -DatabaseName ATAPUtilities `
        -SqlInstance 'localhost\SQLEXPRESS'

.NOTES
    AI assisted using Powershell.instructions.md as guidelines.
    Task: TASKS_V4-DBA1.md DBA1-T05 / V4-E13.
#>
  [CmdletBinding(SupportsShouldProcess)]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Application,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$DatabaseName,

    [Parameter(Mandatory = $false)]
    [string]$SqlInstance,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$DBConnectionStringSecretName,

    [Parameter(Mandatory = $false)]
    [string]$BackupPath,

    [Parameter(Mandatory = $false)]
    [string]$RepositoryRoot
  )

  begin {
    $fn = 'New-DatabasePreMigrationSnapshot'
    $mn = 'ATAP.Utilities.DatabaseManagement.Powershell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
      -Message "Entering $fn (Application='$Application', DatabaseName='$DatabaseName')" -Tag 'Trace'

    if (-not $RepositoryRoot) {
      $RepositoryRoot = if (Get-Command -Name Get-RepositoryRoot -ErrorAction SilentlyContinue) {
        Get-RepositoryRoot -ErrorAction Stop
      }
      else {
        (Get-Location).Path
      }
    }

    $connectionResolution = $null
    if (-not [string]::IsNullOrWhiteSpace($DBConnectionStringSecretName)) {
      $connectionResolution = Resolve-DatabaseSqlConnection `
        -OriginalPSBoundParameters $PSBoundParameters `
        -DBConnectionStringSecretName $DBConnectionStringSecretName `
        -DatabaseName $DatabaseName `
        -ErrorAction Stop
      $builder = [Microsoft.Data.SqlClient.SqlConnectionStringBuilder]::new(
        $connectionResolution.Connection.ConnectionString)
      $SqlInstance = $builder.DataSource
    }
    elseif (-not $SqlInstance) {
      $host_ = $global:settings[$global:configRootKeys['DatabaseHostConfigRootKey']]
      $inst  = $global:settings[$global:configRootKeys['SqlInstanceConfigRootKey']]
      $SqlInstance = if ($inst) { "$host_\$inst" } else { $host_ }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
        -Message "Resolved SqlInstance from settings: '$SqlInstance'" -Tag 'Trace'
    }

    if (-not $BackupPath) {
      $stagingRoot = if (-not [string]::IsNullOrWhiteSpace($env:ATAP_DATABASE_PACKAGE_STAGING_ROOT)) {
        $env:ATAP_DATABASE_PACKAGE_STAGING_ROOT
      }
      else {
        Join-Path $env:ProgramData 'ATAP\DatabasePackageStaging'
      }
      $BackupPath = Join-Path $stagingRoot "snapshots\$Application\$(Get-Date -Format 'yyyyMMdd_HHmmss')"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
        -Message "Using generated BackupPath: '$BackupPath'" -Tag 'Trace'
    }
  }

  process {
    # ── Create backup destination folder ─────────────────────────────────────
    if ($PSCmdlet.ShouldProcess($BackupPath, 'New-Item directory')) {
      New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null
    }

    # ── Capture Flyway schema version before backup ───────────────────────────
    $flywayVersion = $null
    try {
      $flywayVersionParameters = @{
        DatabaseName = $DatabaseName
        ErrorAction  = 'Stop'
      }
      if (-not [string]::IsNullOrWhiteSpace($DBConnectionStringSecretName)) {
        $flywayVersionParameters['DBConnectionStringSecretName'] = $DBConnectionStringSecretName
      }
      else {
        $flywayVersionParameters['SqlInstance'] = $SqlInstance
        $flywayVersionParameters['IntegratedSecurity'] = $true
      }
      $rows = Get-FlywaySchemaVersion @flywayVersionParameters
      $latestRow = $rows | Where-Object { $_.Success -eq $true } | Sort-Object InstalledRank -Descending | Select-Object -First 1
      $flywayVersion = if ($latestRow) { $latestRow.Version } else { 'none' }
    } catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning `
        -Message "Could not read Flyway schema version: $($_.Exception.Message). Defaulting to 'unknown'." -Tag 'Snapshot'
      $flywayVersion = 'unknown'
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
      -Message "Flyway version at snapshot time: '$flywayVersion'" -Tag 'Snapshot'

    # ── Run the dbatools backup ───────────────────────────────────────────────
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $bakFileName = "${DatabaseName}_PREMIG_${timestamp}.bak"
    $bakFilePath = Join-Path $BackupPath $bakFileName

    if ($PSCmdlet.ShouldProcess($SqlInstance, "Backup-DbaDatabase $DatabaseName to $bakFilePath")) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
        -Message "Starting Backup-DbaDatabase on '$SqlInstance' db='$DatabaseName'" -Tag 'Snapshot'

      $dbaConnection = $null
      try {
        $dbaConnection = Connect-DbaInstance -SqlInstance $SqlInstance `
          -TrustServerCertificate -AllowTrustServerCertificate -ErrorAction Stop
        $backupResult = Backup-DbaDatabase `
          -SqlInstance $dbaConnection `
          -Database $DatabaseName `
          -Path $BackupPath `
          -FilePath $bakFileName `
          -Type Full `
          -Verify `
          -EnableException `
          -ErrorAction Stop
      }
      finally {
        if ($null -ne $dbaConnection) {
          $dbaConnection.ConnectionContext.Disconnect()
        }
      }

      if (-not $backupResult) {
        $PSCmdlet.ThrowTerminatingError(
          [System.Management.Automation.ErrorRecord]::new(
            [System.IO.IOException]::new("Backup-DbaDatabase returned no result for database '$DatabaseName'."),
            'BackupFailed', [System.Management.Automation.ErrorCategory]::WriteError, $SqlInstance))
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
        -Message "Backup completed. TotalSize=$($backupResult.TotalSize)" -Tag 'Snapshot'
    } else {
      # WhatIf — create a zero-byte placeholder so evidence writing doesn't fail
      [System.IO.File]::WriteAllBytes($bakFilePath, @())
    }

    # ── Compute SHA-256 ───────────────────────────────────────────────────────
    $sha256 = (Get-FileHash -Path $bakFilePath -Algorithm SHA256).Hash.ToLower()
    $sizeMB = [math]::Round((Get-Item $bakFilePath).Length / 1MB, 3)

    # ── Write evidence JSON ───────────────────────────────────────────────────
    $evidenceFolder = Join-Path $RepositoryRoot '_generated' 'database-packages' $Application
    New-Item -ItemType Directory -Path $evidenceFolder -Force | Out-Null

    $evidenceFile = Join-Path $evidenceFolder 'pre-migration-snapshot-evidence.json'
    $evidenceObj = [ordered]@{
      application   = $Application
      databaseName  = $DatabaseName
      sqlInstance   = $SqlInstance
      backupFile    = $bakFilePath
      backupSizeMB  = $sizeMB
      sha256        = $sha256
      timestamp     = (Get-Date).ToUniversalTime().ToString('o')
      flywayVersion = $flywayVersion
    }
    $evidenceObj | ConvertTo-Json -Depth 4 | Set-Content -Path $evidenceFile -Encoding UTF8

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
      -Message "Evidence written to '$evidenceFile'" -Tag 'Snapshot'

    Write-Output ([PSCustomObject]@{
        Application   = $Application
        DatabaseName  = $DatabaseName
        BackupFile    = $bakFilePath
        BackupSizeMB  = $sizeMB
        Sha256        = $sha256
        Timestamp     = $evidenceObj.timestamp
        FlywayVersion = $flywayVersion
        EvidenceFile  = $evidenceFile
        SnapshotPath  = $bakFilePath
      })
  }

  end {
    if ($null -ne $connectionResolution -and -not [bool]$connectionResolution.IsCallerOwned) {
      $connectionResolution.Connection.Close()
      $connectionResolution.Connection.Dispose()
    }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Exiting $fn" -Tag 'Trace'
  }
}
