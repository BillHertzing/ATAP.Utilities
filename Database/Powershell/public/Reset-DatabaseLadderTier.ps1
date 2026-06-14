#Requires -Version 7.0
<#
.SYNOPSIS
  Task 9.9 - Drop & recreate the ATAPUtilities database on a single ladder tier
  from the consolidated Flyway migration set, with a pre-drop backup and post-build
  verification.

.DESCRIPTION
  Sprint 0009 Stream DB Task 9.9. The Integration / QA / Production tiers each ran a
  DIVERGENT, in-place-unrepairable Flyway history (see Task 9.8 report). Disposition:
  drop + recreate the ATAPUtilities database on each tier from the consolidated
  migration set in Database/Flyway/SQL, executed one tier at a time with an explicit
  confirmation gate (Integration -> QA -> Production).

  This driver operates on EXACTLY ONE tier per invocation so the caller can gate each
  destructive step. Per tier it:
    1. GUARDS: the only database it will ever drop is ATAPUtilities. On the PRODUCTION
       instance the co-located BuildMaster / BuildSets / ProGet server databases are
       enumerated and asserted-present before and after; they are NEVER touched.
    2. BACKS UP: a Full backup of the existing ATAPUtilities (permanent tiers, unless
       -SkipBackup) before anything is dropped. Recoverable by design - non-Exp tiers
       carry only seed data, but the backup is belt-and-suspenders.
    3. DROPS + RECREATES + MIGRATES: via Build-DatabaseWithFlyway -Force, which runs
       DropAndCreateDatabase.sql (drops only the named DB), provisions login/user +
       flyway_schema_history, then `flyway migrate` over the consolidated set.
    4. VERIFIES: queries flyway_schema_history for a single contiguous baseline ending
       at 00.02.000040, runs `flyway validate` (must exit 0), and spot-checks seed
       row counts. On Production, re-asserts the protected databases are still ONLINE.

  The High-impact ShouldProcess gate is a code-level safety. Interactive callers are
  prompted; non-interactive orchestration passes -Force (the human confirmation is
  obtained out-of-band, before invoking this driver for QA / Production).

.PARAMETER Tier
  One of Experimental, Integration, QA, Production. Experimental targets the ephemeral
  EXPWHERTZING instance and is the zero-risk rehearsal tier.

.PARAMETER DatabaseHost
  SQL Server host. Defaults to localhost.

.PARAMETER SkipBackup
  Skip the pre-drop Full backup (implied for Experimental, which has no live data).

.PARAMETER BackupRoot
  Folder root for pre-drop backups. Defaults to C:\LocalDBs\_backups\Task9.9.

.PARAMETER Force
  Bypass the interactive confirmation prompt (ConfirmPreference = None). The drop still
  runs; use only after the human go/no-go for this tier has been obtained.

.OUTPUTS
  PSCustomObject summarizing the tier reset (backup, build, verification, protected DBs).

.NOTES
  AI assisted using Powershell.instructions.md as guidelines.
  Sprint 0009 / Stream DB / Task 9.9. See _generated/DatabaseLadder/Task-9.8-Flyway-Info-Report.md.
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('Experimental', 'Integration', 'QA', 'Production')]
  [string]$Tier,

  [Parameter(Mandatory = $false)]
  [string]$DatabaseHost = 'localhost',

  [Parameter(Mandatory = $false)]
  [switch]$SkipBackup,

  [Parameter(Mandatory = $false)]
  [string]$BackupRoot = 'C:\LocalDBs\_backups\Task9.9',

  [Parameter(Mandatory = $false)]
  [switch]$Force
)

$ErrorActionPreference = 'Stop'
$fn = 'Reset-DatabaseLadderTier'
$mn = 'ATAP.Utilities.DatabaseManagement.Powershell'

if ($Force) { $ConfirmPreference = 'None' }

# This driver uses the canonical Build-DatabaseWithFlyway / DatabaseProvisioning /
# Invoke-Flyway path, which resolves host/tier configuration through Get-PVal against
# $global:settings (built by the ATAP AllUsersAllHosts profile). Agent/CI shells start
# without profiles, so populate $global:settings if absent - never pass -NoProfile for
# ATAP work (the profile is what supplies the DatabasesCollection + configRootKeys).
if (-not $global:settings -or $global:settings.Count -eq 0) {
  if (Test-Path $PROFILE.AllUsersAllHosts) { . $PROFILE.AllUsersAllHosts }
}
if (-not $global:settings -or $global:settings.Count -eq 0 -or -not $global:configRootKeys) {
  throw 'global:settings/configRootKeys not populated and the AllUsersAllHosts profile did not build them. Cannot resolve host/tier configuration for the canonical build path.'
}

# -- The ONLY database this driver is ever allowed to drop ---------------------
$DatabaseName = 'ATAPUtilities'
# Databases that must NEVER be dropped (co-located on the Production instance).
$ProtectedDatabases = @('BuildMaster', 'BuildSets', 'ProGet')

# -- Tier -> instance / environment / data-path map ----------------------------
#   Two DIFFERENT Environment vocabularies are in play (and they disagree for QA/Integration):
#     * DatabaseProvisioning accepts {Production, QA, Integration, Development, Experimental}
#     * Invoke-Flyway accepts      {Production, Testing, Development, Experimental}  (legacy drift:
#       Integration->Development, QA->Testing; see Task 9.8 report).
#   The actual target instance comes from -SqlInstance (explicit), NOT from Environment, so each
#   value only needs to satisfy its own function's ValidValues.
$tierMap = @{
  Experimental = @{ SqlInstance = 'EXPWHERTZING'; ProvisioningEnvironment = 'Experimental'; FlywayEnvironment = 'Experimental'; DataFolder = 'Expwhertzing' }
  Integration  = @{ SqlInstance = 'INTEGRATION';  ProvisioningEnvironment = 'Integration';  FlywayEnvironment = 'Development';  DataFolder = 'Integration' }
  QA           = @{ SqlInstance = 'QA';           ProvisioningEnvironment = 'QA';           FlywayEnvironment = 'Testing';      DataFolder = 'QA' }
  Production   = @{ SqlInstance = 'PRODUCTION';   ProvisioningEnvironment = 'Production';    FlywayEnvironment = 'Production';   DataFolder = 'Production' }
}
$map = $tierMap[$Tier]
$sqlInstanceName = $map.SqlInstance
$provisioningEnvironment = $map.ProvisioningEnvironment
$flywayEnvironment = $map.FlywayEnvironment
$serverInstance = "$DatabaseHost\$sqlInstanceName"
$isPermanentTier = $Tier -in @('Integration', 'QA', 'Production')
$databaseFilePath = "C:\LocalDBs\$($map.DataFolder)\$DatabaseName"

# -- Repo root + consolidated migration paths ---------------------------------
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$flywayBasePath = Join-Path $repositoryRoot 'Database\Flyway'
$flywaySqlMigrationsPath = Join-Path $flywayBasePath 'SQL'
$flywayDataPath = Join-Path $flywayBasePath 'Data'
$flywayTomlPath = Join-Path $flywayBasePath 'flyway.toml'
$provisioningScriptsPath = Join-Path $repositoryRoot 'src\ATAP.Utilities.DatabaseManagement\SharedSQL'
$sharedSqlMigrationsPath = $provisioningScriptsPath

# -- Toolchain (Flyway 11.x + JRE 21; see Task 9.8 runbook) -------------------
$jre21 = 'C:\Program Files\Eclipse Adoptium\jre-21.0.8.9-hotspot'
if (Test-Path $jre21) { $env:JAVA_HOME = $jre21 }
$flywayDir = 'C:\Program Files\Flyway'
if ((Test-Path (Join-Path $flywayDir 'flyway.cmd')) -and ($env:PATH -notlike "*$flywayDir*")) {
  $env:PATH = "$flywayDir;$env:PATH"
}

function Write-Step { param([string]$Message) Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message $Message }
function Write-Detail { param([string]$Message) Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message $Message }

# -- Load tooling -------------------------------------------------------------
#   dbatools and the SqlServer module ship incompatible Microsoft.Data.SqlClient
#   versions and CANNOT coexist. The ATAP DatabaseManagement *module* (.psm1)
#   `#Requires -Modules SqlServer`, so importing it pulls in SqlServer and conflicts
#   with dbatools. We therefore import ONLY dbatools (gives MDS 6.0 + Backup-DbaDatabase
#   + Invoke-DbaQuery) and DOT-SOURCE the public DB functions - bypassing the .psm1
#   #requires. Same pattern as Rebuild-All-AllInstances.ps1. All ad-hoc queries use
#   Invoke-DbaQuery (never Invoke-Sqlcmd) to keep the session on a single MDS.
if (-not (Get-Module -Name dbatools)) { Import-Module dbatools -ErrorAction Stop }
Set-DbatoolsConfig -FullName sql.connection.trustcert -Value $true -PassThru | Register-DbatoolsConfig | Out-Null
Set-DbatoolsConfig -FullName sql.connection.encrypt -Value $false -PassThru | Register-DbatoolsConfig | Out-Null
$helperScripts = @(
  'src\ATAP.Utilities.BuildTooling.PowerShell\public\Get-RepositoryRoot.ps1',
  'src\ATAP.Utilities.Powershell\public\Get-ParameterValueFromNeoConfigurationRoot.ps1',
  'src\ATAP.Utilities.BuildTooling.PowerShell\public\Get-SecretATAPBitwarden.ps1',
  'src\ATAP.Utilities.BuildTooling.PowerShell\public\Get-SecretATAP.ps1',
  'src\ATAP.Utilities.DatabaseManagement.Powershell\public\New-ConnectionStringBuilderFromDbaTools.ps1',
  'src\ATAP.Utilities.DatabaseManagement.Powershell\public\Resolve-DatabaseSqlConnection.ps1',
  'src\ATAP.Utilities.DatabaseManagement.Powershell\public\DatabaseProvisioning.ps1',
  'src\ATAP.Utilities.DatabaseManagement.Powershell\public\Invoke-Flyway.ps1',
  'src\ATAP.Utilities.DatabaseManagement.Powershell\public\Build-DatabaseWithFlyway.ps1'
)
foreach ($hs in $helperScripts) {
  $p = Join-Path $repositoryRoot $hs
  if (-not (Test-Path $p)) { throw "Required helper script not found: $p" }
  . $p
}

$result = [ordered]@{
  Tier               = $Tier
  ServerInstance     = $serverInstance
  DatabaseName       = $DatabaseName
  FlywayEnvironment  = $flywayEnvironment
  PreState           = $null
  BackupFile         = $null
  BuildSuccess       = $false
  ValidateSuccess    = $false
  SchemaVersion      = $null
  AppliedCount       = $null
  SeedCounts         = $null
  ProtectedDbState   = $null
  Errors             = @()
  StartTimeUtc       = (Get-Date).ToUniversalTime().ToString('o')
  EndTimeUtc         = $null
}

try {
  Write-Step "=== Task 9.9 reset: tier=$Tier instance=$serverInstance db=$DatabaseName ==="

  # -- 1. Preflight + guardrail -----------------------------------------------
  $existingDbs = @(Invoke-DbaQuery -SqlInstance $serverInstance -Database master -Query "SELECT name FROM sys.databases WHERE database_id > 4;" -EnableException | Select-Object -ExpandProperty name)
  Write-Step "Databases currently on ${serverInstance}: $($existingDbs -join ', ')"
  $result.PreState = $existingDbs -join ', '

  if ($Tier -eq 'Production') {
    $missingProtected = @($ProtectedDatabases | Where-Object { $_ -notin $existingDbs })
    if ($missingProtected.Count -gt 0) {
      throw "GUARDRAIL: expected protected database(s) [$($missingProtected -join ', ')] not found on $serverInstance. Refusing to proceed - wrong instance?"
    }
    Write-Step "GUARDRAIL OK: protected databases present and will NOT be touched: $($ProtectedDatabases -join ', ')"
  }

  $dbExists = $DatabaseName -in $existingDbs

  # -- 2. Pre-drop backup -----------------------------------------------------
  if ($isPermanentTier -and $dbExists -and -not $SkipBackup) {
    $backupDir = Join-Path $BackupRoot $Tier
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $bakName = "${DatabaseName}_Task9.9_PreDrop_${stamp}.bak"
    Write-Step "Backing up $DatabaseName -> $backupDir\$bakName"
    if ($PSCmdlet.ShouldProcess("$serverInstance\$DatabaseName", "Full backup before drop")) {
      $bk = Backup-DbaDatabase -SqlInstance $serverInstance -Database $DatabaseName -Path $backupDir -FilePath $bakName -Type Full -Verify -EnableException
      $result.BackupFile = $bk.FullName
      Write-Step "Backup complete: $($bk.FullName)"
    }
  } else {
    Write-Step "Skipping pre-drop backup (Tier=$Tier dbExists=$dbExists SkipBackup=$SkipBackup)."
  }

  # -- 3. Drop + recreate + consolidated migrate ------------------------------
  $confirmTarget = "$serverInstance\$DatabaseName"
  $confirmAction = "DROP and RECREATE from consolidated Flyway set (Tier=$Tier)"
  if ($PSCmdlet.ShouldProcess($confirmTarget, $confirmAction)) {
    # We drive the two canonical steps directly (DatabaseProvisioning then Invoke-Flyway)
    # rather than through Build-DatabaseWithFlyway: the wrapper forwards BOTH -SqlConnection
    # and -IntegratedSecurity to Invoke-Flyway, which belong to mutually-exclusive parameter
    # sets and fail to bind once $PSDefaultParameterValues default-binds -Settings (from the
    # profile). Calling each step with the ConnectionParts set avoids that.

    # 3a. DROP + RECREATE (DropAndCreateDatabase.sql drops ONLY $DatabaseName) + login + schema-history.
    Write-Step "Provisioning (drop + recreate) $DatabaseName on $serverInstance..."
    $prov = DatabaseProvisioning `
      -DatabaseName $DatabaseName `
      -Environment $provisioningEnvironment `
      -DatabaseHost $DatabaseHost `
      -SqlInstance $sqlInstanceName `
      -IntegratedSecurity `
      -DatabasePath $databaseFilePath `
      -ProvisioningScriptsPath $provisioningScriptsPath `
      -Force
    if (-not $prov -or -not $prov.Success) {
      throw "DatabaseProvisioning failed: $($prov.Errors -join '; ')"
    }

    # 3b. MIGRATE the consolidated set (ConnectionParts + IntegratedSecurity - same param set as validate).
    Write-Step "Running consolidated flyway migrate..."
    $migrate = Invoke-Flyway `
      -DatabaseName $DatabaseName `
      -Environment $flywayEnvironment `
      -DatabaseHost $DatabaseHost `
      -SqlInstance $sqlInstanceName `
      -IntegratedSecurity `
      -FlywayBasePath $flywayBasePath `
      -FlywaySqlMigrationsPath $flywaySqlMigrationsPath `
      -FlywaySharedSqlMigrationsPath $sharedSqlMigrationsPath `
      -FlywayDataPath $flywayDataPath `
      -FlywayTomlPath $flywayTomlPath `
      -FlywayCommand 'migrate' `
      -PackageName "$DatabaseName.Functions" -PackageVersion 1
    if (-not $migrate.Success) {
      throw "flyway migrate failed: $($migrate.Errors -join '; ')"
    }
    $result.BuildSuccess = $true
    Write-Step "Drop + recreate + migrate completed."
  } else {
    Write-Step "ShouldProcess declined - no changes made."
    $result.EndTimeUtc = (Get-Date).ToUniversalTime().ToString('o')
    return [PSCustomObject]$result
  }

  # -- 4. Verify --------------------------------------------------------------
  Write-Step "Verifying applied migration history..."
  $hist = @(Invoke-DbaQuery -SqlInstance $serverInstance -Database $DatabaseName -Query "SELECT installed_rank, version, description, success FROM dbo.flyway_schema_history WHERE version IS NOT NULL ORDER BY installed_rank;" -EnableException)
  $result.AppliedCount = $hist.Count
  $top = $hist | Sort-Object installed_rank -Descending | Select-Object -First 1
  $result.SchemaVersion = $top.version
  $anyFailed = @($hist | Where-Object { -not $_.success })
  Write-Step "Applied versioned migrations: $($hist.Count); schema version: $($top.version); failed rows: $($anyFailed.Count)"
  if ($anyFailed.Count -gt 0) { throw "One or more migrations recorded success=0." }

  Write-Step "Running flyway validate..."
  $validate = Invoke-Flyway `
    -DatabaseName $DatabaseName `
    -Environment $flywayEnvironment `
    -DatabaseHost $DatabaseHost `
    -SqlInstance $sqlInstanceName `
    -IntegratedSecurity `
    -FlywayBasePath $flywayBasePath `
    -FlywaySqlMigrationsPath $flywaySqlMigrationsPath `
    -FlywayDataPath $flywayDataPath `
    -FlywayTomlPath $flywayTomlPath `
    -FlywayCommand 'validate' `
    -PackageName "$DatabaseName.Functions" -PackageVersion 1
  $result.ValidateSuccess = [bool]$validate.Success
  if (-not $validate.Success) { throw "flyway validate failed: $($validate.Errors -join '; ')" }
  Write-Step "flyway validate: PASS"

  # Seed sanity counts
  $seed = Invoke-DbaQuery -SqlInstance $serverInstance -Database $DatabaseName -EnableException -Query @"
SELECT
  (SELECT COUNT(*) FROM ATAPUtilities.PrimitiveLanguageKind) AS Kinds,
  (SELECT COUNT(*) FROM ATAPUtilities.RulePrimitive)         AS Primitives,
  (SELECT COUNT(*) FROM ATAPUtilities.[User])                AS Users;
"@
  $result.SeedCounts = "Kinds=$($seed.Kinds); Primitives=$($seed.Primitives); Users=$($seed.Users)"
  Write-Step "Seed counts: $($result.SeedCounts)"

  # -- 5. Production post-check: protected DBs untouched ----------------------
  if ($Tier -eq 'Production') {
    $post = Invoke-DbaQuery -SqlInstance $serverInstance -Database master -EnableException -Query "SELECT name, state_desc FROM sys.databases WHERE name IN ('BuildMaster','BuildSets','ProGet') ORDER BY name;"
    $result.ProtectedDbState = ($post | ForEach-Object { "$($_.name)=$($_.state_desc)" }) -join '; '
    $notOnline = @($post | Where-Object { $_.state_desc -ne 'ONLINE' })
    Write-Step "Protected DB post-state: $($result.ProtectedDbState)"
    if (($post | Measure-Object).Count -ne $ProtectedDatabases.Count -or $notOnline.Count -gt 0) {
      throw "GUARDRAIL POST-CHECK FAILED: protected databases not all ONLINE: $($result.ProtectedDbState)"
    }
    Write-Step "GUARDRAIL POST-CHECK OK: BuildMaster / BuildSets / ProGet all ONLINE and untouched."
  }

  Write-Step "=== Tier $Tier reset SUCCEEDED ==="
} catch {
  $result.Errors += $_.Exception.Message
  Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Tier $Tier reset FAILED: $($_.Exception.Message)"
  Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Stack: $($_.ScriptStackTrace)"
  $result.EndTimeUtc = (Get-Date).ToUniversalTime().ToString('o')
  Write-Output ([PSCustomObject]$result)
  throw
}

$result.EndTimeUtc = (Get-Date).ToUniversalTime().ToString('o')
Write-Output ([PSCustomObject]$result)
