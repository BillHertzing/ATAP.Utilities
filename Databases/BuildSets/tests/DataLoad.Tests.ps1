
<#
  .SYNOPSIS
    Pester data-load verification tests.
  Parameters aligned with DatabaseProvisioning function patterns so the same
  environment + instance resolution logic can be reused consistently.

  .DESCRIPTION
  Runs one or more SQL scripts (in a defined order) against a target SQL Server instance to provision
  a database. Each script is executed with structured logging and robust error handling.


  .PARAMETER DatabaseName
  Name of the database to create or update.

  .PARAMETER Environment
  Name of the environment, which influences the DatabaseHost, SqlInstance amd the DatabasePath. This is usually supplied by an environment variable or from the global settings. but can be overridden here.

  .PARAMETER DatabaseHost
  Computer (host) name of the machine that hosts the database server instance.
  This is usually supplied by an environment variable or from the global settings. but can be overridden here.

  .PARAMETER ConnectionMethod
  How to connect to the SQL instance: 'tcp' (default), 'np' (named pipes), or 'lpc' (shared memory).
  This is usually supplied by an environment variable or from the global settings. but can be overridden here.

  .PARAMETER SqlInstance
  SQL Server instance (local or remote) to target (e.g. '<hostname>\PRODUCTION').
  This is usually supplied by an environment variable or from the global settings. but can be overridden here.
  If there exists a database with the same name as the database in the DatabaseHost\SqlInstance path, the operation is aborted unless force is true.
  If force is true, the existing database is deleted.

.PARAMETER UseNamedLogin
  Boolean. if false, the database is created with integrated security, using the current Windows's user that is running this scrip.
    the current Windows's user that is running this script is granted datareader / datawriter access, and DBO  and BulkAdmin per the appropriate parameter.
  If true and LoginName is nonblank, then if the LoginName follows a Window's user's name pattern "contains '\' or \@\",
  That window's login is granted datareader / datawriter access, and DBO and BulkAdmin per the appropriate parameter.
  If the LoginName does not follow a Window's user's name pattern a SQL login is created or ensured as part of the provisioning.
  This is usually supplied by an environment variable or from the global settings. but can be overridden here.

  .PARAMETER LoginName
  The Windows or SQL Login name to create or ensure if UseNamedLogin is true.  If UseNamedLogin is false, this parameter is ignored.
  This is usually supplied by an environment variable or from the global settings. but can be overridden here.

  .PARAMETER LoginPasswordVaultKey
  The key used to retrieve the password for the login if UseNamedLogin is true and the LoginName is not a Windows' username pattern
  This is usually supplied by an environment variable or from the global settings. but can be overridden here.

  .EXAMPLE


  .EXAMPLE


  .EXAMPLE

  .NOTES
  AI assisted using Powershell.instructions.md as guidelines
  #>


Param(
  # Name of the target database (matches -DatabaseName in DatabaseProvisioning)
  [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
  [string]$DatabaseName = 'BuildSets',

  # Environment selector: Production | Testing | Development | Experimental
  [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
  [ValidateSet('Production', 'Testing', 'Development', 'Experimental')]
  [string]$Environment,

  # Host machine where SQL Server instance runs (maps to -DatabaseHost)
  [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
  [string]$DatabaseHost,

  # Connection method: tcp | np | lpc  (maps to -ConnectionMethod)
  [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
  [ValidateSet('tcp', 'np', 'lpc')]
  [string]$ConnectionMethod,

  # Optional named instance (e.g. SQLEXPRESS, Production, Testing)
  [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
  [string]$SqlInstance,

  # Root path where CSV data files live (maps conceptually to -DatabasePath / DATA dir)
  [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
  [string]$DataRoot,

  # Optional: if tests ever need to distinguish auth mode (mirrors -UseNamedLogin)
  [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
  [bool]$UseNamedLogin = $false,

  # Optional login name if SQL auth or Windows principal required (mirrors -LoginName)
  [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
  [string]$LoginName,

  # Optional vault key (mirrors -LoginPasswordVaultKey)
  [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
  [string]$LoginPasswordVaultKey
)

# --- Helper functions (trimmed pattern from DatabaseProvisioning) ---
function Get-Env([string]$key) {
  [Environment]::GetEnvironmentVariable($key, 'Process')
}

function Test-Blank([string]$s) { [string]::IsNullOrWhiteSpace($s) }
function Resolve-FromSettings([string]$db, [string]$env, [string]$leafKey) {
  if ($settings.ContainsKey($global:configRootKeys['DatabasesCollectionConfigRootKey'])) {
    $root = $settings[$global:configRootKeys['DatabasesCollectionConfigRootKey']]
    if ($root.ContainsKey($db) -and $root[$db].ContainsKey($env) -and $root[$db][$env].ContainsKey($leafKey)) {
      $val = $root[$db][$env][$leafKey]
      if (-not (Test-Blank $val)) { return $val }
    }
  }
  return $null
}


$csvSpec = @(
  @{ Name = 'RuleSet'; File = 'RuleSet.csv'; Table = 'dbo.RuleSet'; Key = 'ID'; Columns = @('ID', 'Name') }
  @{ Name = 'RuleItem'; File = 'RuleItem.csv'; Table = 'dbo.RuleItem'; Key = 'ID'; Columns = @('ID', 'ParentID', 'PeerSortOrder', 'SymbolicName', 'ItemText') }
  @{ Name = 'RuleSetHavingRuleItem'; File = 'RuleSetHavingRuleItem.csv'; Table = 'dbo.RuleSetHavingRuleItem'; Key = 'RuleSetID,RuleItemID'; Columns = @('RuleSetID', 'RuleItemID') }
  @{ Name = 'BuildSet'; File = 'BuildSet.csv'; Table = 'dbo.BuildSet'; Key = 'ID'; Columns = @('ID', 'Name') }
  @{ Name = 'BuildSetHavingRuleSet'; File = 'BuildSetHavingRuleSet.csv'; Table = 'dbo.BuildSetHavingRuleSet'; Key = 'BuildSetID,RuleSetID'; Columns = @('BuildSetID', 'RuleSetID') }
)

Describe "BuildSets data load ($DatabaseName)" -Tag 'Data', 'BuildSets' {
  BeforeAll {
    Import-Module SqlServer -ErrorAction Stop

    # --- Environment: param -> env -> $global:settings['Environment'] -> throw
    if (Test-Blank $Environment) {
      # Try environment variable first (e.g., via a configured key like 'EnvironmentConfigRootKey')
      $envVal = Get-Env $global:configRootKeys['EnvironmentConfigRootKey']
      if (Test-Blank $envVal) {
        # Then try global settings at the top level: $global:settings['Environment']
        $setVal = $null
        if ($null -ne $global:settings -and $global:settings.ContainsKey('Environment')) {
          $setVal = $global:settings['Environment']
        }

        if (Test-Blank $setVal) {
          $errorMessage = "Environment not found via parameter, env '$($global:configRootKeys['EnvironmentConfigRootKey'])', or global settings['Environment']."
          Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Error -Message $errorMessage -Tag 'Validation', 'Error'
          throw $errorMessage
        }
        else {
          $Environment = $setVal
        }
      }
      else {
        $Environment = $envVal
      }
    }
    # Normalize to one of the allowed values (case-insensitive) and hard-validate
    $allowedEnvs = 'Production', 'Testing', 'Development', 'Experimental'
    $match = $allowedEnvs | Where-Object { $_.ToLowerInvariant() -eq $Environment.ToString().ToLowerInvariant() }

    if ($null -ne $match) {
      # Snap to canonical casing from $allowedEnvs
      $Environment = $match
    }
    else {
      $errorMessage = "Environment '$Environment' must be one of: $($allowedEnvs -join ', ')."
      Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Error -Message $errorMessage -Tag 'Validation', 'Error'
      throw $errorMessage
    }

    # --- DatabaseHost: param -> env -> settings -> throw
    if (Test-Blank $DatabaseHost) {
      $dbh = 'Database' + $DatabaseName + $Environment + 'DatabaseHostConfigRootKey'
      $envVal = Get-Env $global:configRootKeys[$dbh]
      if (Test-Blank $envVal) {
        $setVal = Resolve-FromSettings -db $DatabaseName -env $Environment -leafKey 'DatabaseHost'
        if (Test-Blank $setVal) {
          $errorMessage = "DatabaseHost not found via parameter, env '$($global:configRootKeys[$dbh])', or settings for '$DatabaseName'/'$Environment'."
          Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Error -Message $errorMessage -Tag 'Validation', 'Error'
          throw $errorMessage
        }
        else { $DatabaseHost = $setVal }
      }
      else { $DatabaseHost = $envVal }
    }

    # --- ConnectionMethod: param -> env -> settings -> throw
    if (Test-Blank $ConnectionMethod) {
      $envVal = Get-Env $global:configRootKeys['ConnectionMethodConfigRootKey']
      if (Test-Blank $envVal) {
        $setVal = Resolve-FromSettings -db $DatabaseName -env $Environment -leafKey 'ConnectionMethod'
        if (Test-Blank $setVal) {
          $errorMessage = "ConnectionMethod not found via parameter, env '$($global:configRootKeys['ConnectionMethodConfigRootKey'])', or settings for '$DatabaseName'/'$Environment'."
          Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Error -Message $errorMessage -Tag 'Validation', 'Error'
          throw $errorMessage
        }
        else { $ConnectionMethod = $setVal }
      }
      else { $ConnectionMethod = $envVal }
    }

    # Normalize and hard-validate (defensive; complements [ValidateSet()])
    $ConnectionMethod = $ConnectionMethod.ToString().ToLowerInvariant()
    if ('tcp', 'np', 'lpc' -notcontains $ConnectionMethod) {
      $errorMessage = "ConnectionMethod '$ConnectionMethod' must be one of: tcp, np, lpc."
      Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Error -Message $errorMessage -Tag 'Validation', 'Error'
      throw $errorMessage
    }

    # --- SqlInstance: param -> env -> settings -> throw
    if (Test-Blank $SqlInstance) {
      $envVal = Get-Env $global:configRootKeys['SqlInstanceConfigRootKey']
      if (Test-Blank $envVal) {
        $setVal = Resolve-FromSettings -db $DatabaseName -env $Environment -leafKey 'SqlInstance'
        if (Test-Blank $setVal) {
          $errorMessage = "SqlInstance not found via parameter, env '$($global:configRootKeys['SqlInstanceConfigRootKey'])', or settings for '$DatabaseName'/'$Environment'."
          Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Error -Message $errorMessage -Tag 'Validation', 'Error'
          throw $errorMessage
        }
        else { $SqlInstance = $setVal }
      }
      else { $SqlInstance = $envVal }
    }


    # Apply defaults NOW (runtime) because Run.Parameters are injected only after discovery.
    if (Test-Blank $DataRoot) { $DataRoot = (Join-Path $PSScriptRoot '..\DATA' | Resolve-Path | ForEach-Object Path) }


    # Build server instance string (protocol:host\instance)
    $script:ServerInstance = "{0}:{1}" -f $ConnectionMethod, $DatabaseHost
    if (-not (Test-Blank $SqlInstance)) {
      $script:ServerInstance = "$script:ServerInstance\$SqlInstance"
    }

    Write-Host "DataLoad Tests -> ServerInstance=$script:ServerInstance; DB=$DatabaseName; Env=$Environment; DataRoot=$DataRoot" -ForegroundColor Cyan

    function Get-DbRows {
      param([string]$Query)
      Invoke-Sqlcmd -ServerInstance $script:ServerInstance -Database $DatabaseName -Query $Query -ErrorAction Stop
    }
  }

  Context "Row counts match CSV" {
    foreach ($spec in $csvSpec) {
      It "$($spec.Name) row count matches" {
        $csvPath = Join-Path $DataRoot $spec.File
        Test-Path $csvPath | Should -BeTrue
        $csv = Import-Csv $csvPath
        # Drop blank lines if any
        $csv = $csv | Where-Object { $_.$($spec.Columns[0]) -and $_.$($spec.Columns[0]).ToString().Trim() -ne '' }
        $dbCount = (Get-DbRows -Query "SELECT COUNT(*) AS C FROM $($spec.Table)").C
        $csv.Count | Should -Be $dbCount
      }
    }
  }

  Context "Key presence (no missing / extra)" {
    foreach ($spec in $csvSpec) {
      It "$($spec.Name) keys match exactly" {
        $csvPath = Join-Path $DataRoot $spec.File
        $csv = Import-Csv $csvPath
        $csv = $csv | Where-Object { $_.$($spec.Columns[0]) }
        if ($spec.Key -like '*,*') {
          $keyScript = ($spec.Key -split ',') | ForEach-Object { "\$_.${_}" } -join '+\":\"+'
          $csvKeys = $csv | ForEach-Object { Invoke-Expression $keyScript }
          $dbKeys = (Get-DbRows -Query "SELECT CONCAT_WS(':', $($spec.Key -replace ',',',')) AS K FROM $($spec.Table)").K
        }
        else {
          $csvKeys = $csv | ForEach-Object { $_.$($spec.Key) }
          $dbKeys = (Get-DbRows -Query "SELECT $($spec.Key) AS K FROM $($spec.Table)").K
        }
        @($csvKeys | Sort-Object) | Should -Be (@($dbKeys | Sort-Object))
      }
    }
  }

  Context "Procedure dbo.VerifyRuleSets executes" {
    It "dbo.VerifyRuleSets runs without error" {
      { Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $DatabaseName -Query 'EXEC dbo.VerifyRuleSets @MaxDepth=-1,@IncludeRulesOnly=0;' -ErrorAction Stop } | Should -Not -Throw
    }
  }
}
