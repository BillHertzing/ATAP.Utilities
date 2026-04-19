function New-DeveloperDatabaseInstances {
  <#
  .SYNOPSIS
  Creates per-developer SQL Server named instances and builds the ATAPUtilities database on each.

  .DESCRIPTION
  At the start of each sprint, each developer needs two SQL Server named instances:
    - Sprint{NNNN}{DeveloperName}   — sprint-scoped instance (removed at sprint end)
    - Development{DeveloperName}    — persistent developer instance (also removed at sprint end)

  The set of developer names is resolved (in priority order) from:
    1. The -DeveloperNames parameter if supplied
    2. $global:settings[$global:configRootKeys['SprintDeveloperNamesConfigRootKey']]
       (dotted path: Sprint.DeveloperNames)
    3. $env:USERNAME (single-developer default)

  After instance creation, builds the ATAPUtilities database on each instance using
  Build-DatabaseWithFlyway.  Caller is responsible for pre-loading all helper functions
  (Install-SqlServerInstance, Build-DatabaseWithFlyway, and their dependencies).

  .PARAMETER SprintNumber
  Four-character zero-padded sprint number, e.g. '0006'.

  .PARAMETER DeveloperNames
  Array of developer names to create instances for.  Overrides the global-settings lookup
  and the $env:USERNAME default.

  .PARAMETER SqlServerSetupPath
  Path to the folder containing the extracted SQL Server setup media (setup.exe + CABs).
  Passed directly to Install-SqlServerInstance.  Default: D:\Temp\SQLExpr\extracted.

  .PARAMETER RepositoryRoot
  Root of the ATAP.Utilities repository.  Auto-detected from $PSScriptRoot when not supplied.

  .PARAMETER OverviewWorkspaceFile
  Optional path to OVERViewSprintNNNN.code-workspace.  When supplied, the function appends
  a 'developerDatabaseInstances' array to the JSON file recording which instances were created.

  .PARAMETER Force
  Drop and recreate ATAPUtilities databases even if they already exist.  Default: $true.

  .OUTPUTS
  PSCustomObject with fields:
    SprintNumber     string
    DeveloperNames   string[]
    InstanceResults  PSCustomObject[]  — one entry per (developer × instance type)
    OverallSuccess   bool
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  param(
    [Parameter(Mandatory)]
    [ValidatePattern('^\d{4}$')]
    [string]$SprintNumber,

    [Parameter(Mandatory = $false)]
    [string[]]$DeveloperNames,

    [Parameter(Mandatory = $false)]
    [string]$SqlServerSetupPath = 'D:\Temp\SQLExpr\extracted',

    [Parameter(Mandatory = $false)]
    [string]$RepositoryRoot,

    [Parameter(Mandatory = $false)]
    [string]$OverviewWorkspaceFile,

    [Parameter(Mandatory = $false)]
    [switch]$Force = $true
  )

  $fn = $MyInvocation.MyCommand.Name
  $mn = 'ATAP.Utilities.DatabaseManagement.Powershell'

  # ── Resolve developer names ──────────────────────────────────────────────
  if (-not $PSBoundParameters.ContainsKey('DeveloperNames')) {
    $settingsKey = if ($global:configRootKeys -and $global:configRootKeys['SprintDeveloperNamesConfigRootKey']) {
      $global:configRootKeys['SprintDeveloperNamesConfigRootKey']
    } else {
      'Sprint.DeveloperNames'
    }
    $DeveloperNames = Get-PVal `
      -ParameterName 'DeveloperNames' `
      -originalPSBoundParameters $PSBoundParameters `
      -dottedPath $settingsKey `
      -DefaultValue @($env:USERNAME) `
      -AllowMissing
    if (-not $DeveloperNames) {
      $DeveloperNames = @($env:USERNAME)
    }
  }
  Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
    -Message "Developer names resolved: $($DeveloperNames -join ', ')"

  # ── Resolve repository root ──────────────────────────────────────────────
  if (-not $PSBoundParameters.ContainsKey('RepositoryRoot')) {
    # This file: src\ATAP.Utilities.DatabaseManagement.Powershell\public\<file>.ps1
    # Repo root:  4 levels up
    $RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
  }

  $databaseName = 'ATAPUtilities'
  $databaseHost = 'localhost'
  $connectionMethod = 'tcp'
  $ProvisioningScriptsPath = Join-Path $RepositoryRoot 'src\ATAP.Utilities.DatabaseManagement\SharedSQL'
  $flywayBasePath = Join-Path $RepositoryRoot 'Database\Flyway'
  $flywaySqlMigrationsPath = Join-Path $flywayBasePath 'SQL'
  $flywaySharedSqlMigrationsPath = Join-Path $RepositoryRoot 'src\ATAP.Utilities.DatabaseManagement\SharedSQL'
  $flywayDataPath = Join-Path $flywayBasePath 'Data'
  $FlywayTomlPath = Join-Path $flywayBasePath 'flyway.toml'

  $instanceResults = [System.Collections.Generic.List[PSCustomObject]]::new()
  $overallSuccess = $true

  foreach ($developer in $DeveloperNames) {
    # Two instances per developer
    $instances = @(
      [PSCustomObject]@{
        InstanceLabel = 'Sprint'
        SqlInstance   = "Sprint${SprintNumber}${developer}"
        Environment   = 'Development'
        DatabasePath  = "C:\LocalDBs\Sprint${SprintNumber}${developer}\$databaseName"
      }
      [PSCustomObject]@{
        InstanceLabel = 'Development'
        SqlInstance   = "Development${developer}"
        Environment   = 'Development'
        DatabasePath  = "C:\LocalDBs\Development${developer}\$databaseName"
      }
    )

    foreach ($inst in $instances) {
      $entry = [PSCustomObject]@{
        Developer       = $developer
        InstanceLabel   = $inst.InstanceLabel
        SqlInstance     = $inst.SqlInstance
        InstanceCreated = $false
        DatabaseBuilt   = $false
        InstanceError   = $null
        DatabaseError   = $null
      }

      # ── Create SQL Server instance ────────────────────────────────────────
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
        -Message "Creating SQL Server instance '$($inst.SqlInstance)'..."

      try {
        if ($PSCmdlet.ShouldProcess($inst.SqlInstance, 'Create SQL Server instance')) {
          $installResult = Install-SqlServerInstance `
            -DatabaseHost $databaseHost `
            -SqlInstance $inst.SqlInstance `
            -ConnectionMethod $connectionMethod `
            -AuthenticationMode Windows `
            -SqlServerSetupPath $SqlServerSetupPath `
            -Verbose:$VerbosePreference

          if ($installResult.Cancelled) {
            $entry.InstanceError = 'Cancelled by user'
          } elseif (-not $installResult.Success) {
            $entry.InstanceError = "Install-SqlServerInstance returned Success=False: $($installResult.InstallResult)"
          } else {
            $entry.InstanceCreated = $true
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
              -Message "Instance '$($inst.SqlInstance)' created successfully."
          }
        } else {
          $entry.InstanceError = 'WhatIf: skipped'
        }
      } catch {
        $entry.InstanceError = $_.Exception.Message
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error `
          -Message "Failed to create instance '$($inst.SqlInstance)': $($_.Exception.Message)"
      }

      # ── Build ATAPUtilities database ──────────────────────────────────────
      if ($entry.InstanceCreated) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
          -Message "Building $databaseName on '$($inst.SqlInstance)'..."

        try {
          $buildResult = Build-DatabaseWithFlyway `
            -DatabaseName $databaseName `
            -Environment $inst.Environment `
            -DatabaseHost $databaseHost `
            -SqlInstance $inst.SqlInstance `
            -ConnectionMethod $connectionMethod `
            -DatabasePath $inst.DatabasePath `
            -ProvisioningScriptsPath $ProvisioningScriptsPath `
            -FlywayBasePath $flywayBasePath `
            -FlywaySqlMigrationsPath $flywaySqlMigrationsPath `
            -FlywaySharedSqlMigrationsPath $flywaySharedSqlMigrationsPath `
            -FlywayDataPath $flywayDataPath `
            -FlywayTomlPath $FlywayTomlPath `
            -IntegratedSecurity `
            -Force:$Force `
            -Verbose:$VerbosePreference

          if (-not $buildResult.Success) {
            $entry.DatabaseError = "Build-DatabaseWithFlyway failed: $($buildResult.Errors -join '; ')"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error `
              -Message $entry.DatabaseError
          } else {
            $entry.DatabaseBuilt = $true
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
              -Message "$databaseName on '$($inst.SqlInstance)' built successfully."
          }
        } catch {
          $entry.DatabaseError = $_.Exception.Message
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error `
            -Message "Build-DatabaseWithFlyway failed for '$($inst.SqlInstance)': $($_.Exception.Message)"
        }
      }

      if ($entry.InstanceError -or $entry.DatabaseError) { $overallSuccess = $false }
      $instanceResults.Add($entry)
    }
  }

  # ── Optionally update OverviewSprintNNNN.code-workspace ──────────────────
  if ($PSBoundParameters.ContainsKey('OverviewWorkspaceFile') -and (Test-Path $OverviewWorkspaceFile)) {
    try {
      $ws = Get-Content $OverviewWorkspaceFile -Raw | ConvertFrom-Json
      $ws | Add-Member -NotePropertyName 'developerDatabaseInstances' -NotePropertyValue @(
        $instanceResults | ForEach-Object {
          [PSCustomObject]@{
            developer     = $_.Developer
            instanceLabel = $_.InstanceLabel
            sqlInstance   = $_.SqlInstance
            created       = $_.InstanceCreated
            databaseBuilt = $_.DatabaseBuilt
          }
        }
      ) -Force
      $ws | ConvertTo-Json -Depth 10 | Set-Content $OverviewWorkspaceFile -Encoding UTF8
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
        -Message "Updated '$OverviewWorkspaceFile' with developerDatabaseInstances."
    } catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error `
        -Message "Failed to update workspace file: $($_.Exception.Message)"
    }
  }

  return [PSCustomObject]@{
    SprintNumber    = $SprintNumber
    DeveloperNames  = $DeveloperNames
    InstanceResults = $instanceResults.ToArray()
    OverallSuccess  = $overallSuccess
  }
}
