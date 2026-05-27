<#
.SYNOPSIS
  Backs up the Production ATAPUtilities database and seeds the Integration
  and QA databases from that backup, so all sprint work starts from a
  known-good production baseline.

.DESCRIPTION
  Export-ProductionDatabaseForSprintInit performs three operations in sequence:
    1. Full backup of the Production SQL Server instance.
    2. Restore (with replace) of that backup onto the Integration SQL instance.
    3. Restore (with replace) of that same backup onto the QA SQL instance.

  All SQL instance names and database names are resolved from
  $global:settings[$global:configRootKeys[...]] so that the function is
  portable across machines and environments.  The caller supplies override
  parameters only when defaults from global settings must be bypassed.

  Requires the dbatools module and sufficient DBA or admin rights on all
  three SQL instances.

.PARAMETER SprintNumber
  The sprint number (e.g. 7 for Sprint-0007).  Used to construct the backup
  subdirectory name, e.g.
    <BackupRootPath>\Sprint-0007\ATAPUtilities_Production_<timestamp>.bak

.PARAMETER DatabaseName
  Name of the database to back up and restore.  Defaults to 'ATAPUtilities'.

.PARAMETER BackupRootPath
  Root folder for backup output.  Sprint-specific subdirectory is created
  automatically.  Defaults to the value stored in global settings, or
  C:\ProgramData\ATAP\DatabaseBackups if the setting is absent.

.PARAMETER ProductionSqlInstance
  Connection string (Server\Instance or Server,Port) for the Production
  SQL Server.  Defaults to the global-settings value for the Production
  database instance.

.PARAMETER IntegrationSqlInstance
  Connection string for the Integration SQL Server.  Defaults to global
  settings.

.PARAMETER QaSqlInstance
  Connection string for the QA SQL Server.  Defaults to global settings.

.EXAMPLE
  Export-ProductionDatabaseForSprintInit -SprintNumber 7

  Uses all defaults from $global:settings.  Creates a dated .bak under
  C:\ProgramData\ATAP\DatabaseBackups\Sprint-0007\ and restores onto
  Integration and QA instances.

.EXAMPLE
  Export-ProductionDatabaseForSprintInit `
      -SprintNumber 8 `
      -BackupRootPath 'D:\Backups\ATAP' `
      -ProductionSqlInstance 'PRODSERVER\SQLEXPRESS' `
      -IntegrationSqlInstance 'INTSERVER\SQLEXPRESS' `
      -QaSqlInstance 'QASERVER\SQLEXPRESS'

  Overrides all SQL instance names and the backup root.

.OUTPUTS
  [PSCustomObject] with properties:
    Sprint            [int]       Sprint number supplied by caller.
    DatabaseName      [string]    Name of the database that was processed.
    BackupFile        [string]    Full path to the .bak file that was created.
    BackupSizeMB      [double]    Size of the .bak file in megabytes.
    IntegrationSeeded [bool]      Whether the Integration DB was seeded.
    QASeeded          [bool]      Whether the QA DB was seeded.
    Timestamp         [datetime]  When the operation completed.

.NOTES
  AI assisted using ./claude/Rules/Powershell.md as guidelines

  Dependencies:
    - dbatools (Install-Module dbatools -Scope CurrentUser)
    - PSFramework (Install-Module PSFramework -Scope CurrentUser)
    - $global:settings / $global:configRootKeys populated by host profile

  Security:
    SQL credentials are retrieved from $global:settings / Bitwarden.
    Never hardcode connection strings or passwords in this file.
#>
function Export-ProductionDatabaseForSprintInit {
  [CmdletBinding(SupportsShouldProcess)]
  param (
    [Parameter(Mandatory)]
    [ValidateRange(1, 9999)]
    [int]$SprintNumber,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$DatabaseName = 'ATAPUtilities',

    [Parameter()]
    [string]$BackupRootPath,

    [Parameter()]
    [string]$ProductionSqlInstance,

    [Parameter()]
    [string]$IntegrationSqlInstance,

    [Parameter()]
    [string]$QaSqlInstance
  )

  BEGIN {
    $fn = 'Export-ProductionDatabaseForSprintInit'
    $mn = 'Database.Powershell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
      -Message "Starting $fn for Sprint-{0:D4}, database '{1}'" -StringValues $SprintNumber, $DatabaseName

    # -----------------------------------------------------------------------
    # Resolve dbatools
    # -----------------------------------------------------------------------
    if (-not (Get-Module -Name dbatools -ListAvailable -ErrorAction SilentlyContinue)) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
        -Message 'dbatools not found – installing for current user.'
      Install-Module -Name dbatools -Scope CurrentUser -Force -AllowClobber
    }
    Import-Module dbatools -ErrorAction Stop

    # -----------------------------------------------------------------------
    # Resolve parameters from global settings where not supplied by caller
    # -----------------------------------------------------------------------
    $sprintLabel = 'Sprint-{0:D4}' -f $SprintNumber

    if (-not $BackupRootPath) {
      $BackupRootPath = $global:settings[$global:configRootKeys['DatabaseBackupRootPathConfigRootKey']]
      if ([string]::IsNullOrWhiteSpace($BackupRootPath)) {
        $BackupRootPath = 'C:\ProgramData\ATAP\DatabaseBackups'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
          -Message 'BackupRootPath not found in global:settings; defaulting to C:\ProgramData\ATAP\DatabaseBackups'
      }
    }

    $dbSettings = $global:settings[$global:configRootKeys['DatabasesCollectionConfigRootKey']]

    if (-not $ProductionSqlInstance) {
      $prodCfg              = $dbSettings['ATAPUtilities']['Production']
      $ProductionSqlInstance = '{0}\{1}' -f $prodCfg['DatabaseHost'], $prodCfg['SqlInstance']
    }

    if (-not $IntegrationSqlInstance) {
      $intCfg               = $dbSettings['ATAPUtilities']['Integration']
      $IntegrationSqlInstance = '{0}\{1}' -f $intCfg['DatabaseHost'], $intCfg['SqlInstance']
    }

    if (-not $QaSqlInstance) {
      $qaCfg         = $dbSettings['ATAPUtilities']['QA']
      $QaSqlInstance = '{0}\{1}' -f $qaCfg['DatabaseHost'], $qaCfg['SqlInstance']
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
      -Message 'Resolved instances: Production={0}  Integration={1}  QA={2}' `
      -StringValues $ProductionSqlInstance, $IntegrationSqlInstance, $QaSqlInstance

    # -----------------------------------------------------------------------
    # Build backup output path
    # -----------------------------------------------------------------------
    $timestamp  = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
    $backupDir  = Join-Path $BackupRootPath $sprintLabel
    $bakFileName = '{0}_Production_{1}.bak' -f $DatabaseName, $timestamp
    $bakFilePath = Join-Path $backupDir $bakFileName

    if (-not (Test-Path $backupDir)) {
      $null = New-Item -ItemType Directory -Path $backupDir -Force
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
        -Message 'Created backup directory: {0}' -StringValues $backupDir
    }

    # -----------------------------------------------------------------------
    # Track seeding outcomes (for output object)
    # -----------------------------------------------------------------------
    $integrationSeeded = $false
    $qaSeeded          = $false
  }

  PROCESS {
    # =======================================================================
    # STEP 1 — Verify Production instance is accessible
    # =======================================================================
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
      -Message 'Testing connection to Production instance: {0}' -StringValues $ProductionSqlInstance

    $connTest = Test-DbaConnection -SqlInstance $ProductionSqlInstance -ErrorAction SilentlyContinue
    if (-not $connTest.ConnectSuccess) {
      $msg = "Cannot reach Production SQL instance '{0}'. Aborting." -f $ProductionSqlInstance
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
      -Message 'Production instance reachable: {0}' -StringValues $ProductionSqlInstance

    # =======================================================================
    # STEP 2 — Full backup of Production DB
    # =======================================================================
    if ($PSCmdlet.ShouldProcess($ProductionSqlInstance, "Full backup of $DatabaseName to $bakFilePath")) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
        -Message 'Starting full backup: {0} on {1} → {2}' `
        -StringValues $DatabaseName, $ProductionSqlInstance, $bakFilePath

      try {
        $backupResult = Backup-DbaDatabase `
          -SqlInstance    $ProductionSqlInstance `
          -Database       $DatabaseName `
          -BackupDirectory $backupDir `
          -BackupFileName  $bakFileName `
          -Type            Full `
          -CompressBackup `
          -ErrorAction     Stop
      } catch {
        $errMsg = "Backup of '{0}' on '{1}' failed: {2}" -f $DatabaseName, $ProductionSqlInstance, $_.Exception.Message
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errMsg
        throw $errMsg
      }

      $bakSizeMB = [math]::Round((Get-Item $bakFilePath).Length / 1MB, 2)
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
        -Message 'Backup complete. File: {0}  Size: {1} MB' -StringValues $bakFilePath, $bakSizeMB
    }
    else {
      # WhatIf: assign placeholder so output object is still valid
      $bakFilePath = '<WhatIf — no backup created>'
      $bakSizeMB   = 0
    }

    # =======================================================================
    # STEP 3 — Restore Production backup onto Integration DB
    # =======================================================================
    if ($PSCmdlet.ShouldProcess($IntegrationSqlInstance, "Restore $DatabaseName from $bakFilePath (with replace)")) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
        -Message 'Seeding Integration DB from backup: {0} → {1}' `
        -StringValues $bakFilePath, $IntegrationSqlInstance

      try {
        $null = Restore-DbaDatabase `
          -SqlInstance  $IntegrationSqlInstance `
          -Database     $DatabaseName `
          -Path         $bakFilePath `
          -WithReplace `
          -ErrorAction  Stop

        $integrationSeeded = $true
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
          -Message 'Integration DB seeded successfully from {0} backup.' -StringValues $sprintLabel
      } catch {
        $errMsg = "Restore to Integration instance '{0}' failed: {1}" -f $IntegrationSqlInstance, $_.Exception.Message
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errMsg
        throw $errMsg
      }
    }

    # =======================================================================
    # STEP 4 — Restore Production backup onto QA DB
    # =======================================================================
    if ($PSCmdlet.ShouldProcess($QaSqlInstance, "Restore $DatabaseName from $bakFilePath (with replace)")) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
        -Message 'Seeding QA DB from backup: {0} → {1}' `
        -StringValues $bakFilePath, $QaSqlInstance

      try {
        $null = Restore-DbaDatabase `
          -SqlInstance  $QaSqlInstance `
          -Database     $DatabaseName `
          -Path         $bakFilePath `
          -WithReplace `
          -ErrorAction  Stop

        $qaSeeded = $true
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
          -Message 'QA DB seeded successfully from {0} backup.' -StringValues $sprintLabel
      } catch {
        $errMsg = "Restore to QA instance '{0}' failed: {1}" -f $QaSqlInstance, $_.Exception.Message
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errMsg
        throw $errMsg
      }
    }
  }

  END {
    $result = [PSCustomObject]@{
      Sprint            = $SprintNumber
      DatabaseName      = $DatabaseName
      BackupFile        = $bakFilePath
      BackupSizeMB      = $bakSizeMB
      IntegrationSeeded = $integrationSeeded
      QASeeded          = $qaSeeded
      Timestamp         = Get-Date
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
      -Message '$fn complete. Sprint={0}  BackupFile={1}  IntegrationSeeded={2}  QASeeded={3}' `
      -StringValues $SprintNumber, $bakFilePath, $integrationSeeded, $qaSeeded

    $result
  }
}
