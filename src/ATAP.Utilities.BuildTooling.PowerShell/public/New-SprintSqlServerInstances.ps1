function New-SprintSqlServerInstances {
  <#
  .SYNOPSIS
    Creates the `Dev<username>` and `Exp<username>` SQL Server named instances for
    the sprint environment and builds all target databases from scratch using Flyway migrations.
  .DESCRIPTION
    Idempotently creates two SQL Server named instances — `Dev<username>` (T2
    Development/Alpha tier) and `Exp<username>` (T1 Experimental/Sprint tier) —
    using the authoritative naming convention: 3-char prefix + $env:USERNAME,
    no separator, 16-char SQL Server instance name limit (SprintInfrastructure-Naming.md).

    For each instance that is successfully created (or already present), the
    function calls `Build-DatabaseWithFlyway` against every database in -Databases,
    which drops and recreates the database then applies all Flyway migrations to
    build the complete schema from scratch.

    Supersedes `New-DeveloperDatabaseInstances` (now archived to Obsolete/).

    Idempotency rules:
    - If the Windows service `MSSQL$<InstanceName>` already exists, instance
      creation is skipped and a Verbose message is logged.
    - If the database already exists on the instance (verified via Get-DbaDatabase),
      the full Flyway rebuild is skipped and a Verbose message is logged.
    - Only when the database is absent is `Build-DatabaseWithFlyway` called with
      -Force to create it from scratch and apply all Flyway migrations.

    Depends on:
    - `Install-SqlServerInstance` (ATAP.Utilities.DatabaseManagement.Powershell)
    - `Build-DatabaseWithFlyway` (ATAP.Utilities.DatabaseManagement.Powershell)

    Both helpers are dot-sourced from the repository root if not already loaded.
  .PARAMETER InstanceNames
    SQL Server named-instance names to create.
    Default: @("Dev$($env:USERNAME)", "Exp$($env:USERNAME)")
  .PARAMETER Databases
    Database names for which Flyway baseline is run on every instance.
    Default: @('ATAPUtilities', 'AceCommander')
  .PARAMETER DatabaseHost
    SQL Server host address.
    Default: 'localhost'
  .PARAMETER ConnectionMethod
    Connection protocol: 'tcp', 'namedpipe', or 'sharedmemory'.
    Default: 'tcp'
  .PARAMETER FlywayBasePath
    Root folder that contains `flyway.toml` and the `SQL/` sub-folder.
    Default: resolved from $global:settings if available, otherwise
    `<repoRoot>\Database\Flyway`.
  .PARAMETER RepositoryRoot
    Root of the ATAP.Utilities repository worktree.
    Default: three levels above this script's location.
  .OUTPUTS
    [PSCustomObject[]] — one entry per (instanceName, database) combination:
      instanceName  [string]  — SQL Server instance name
      database      [string]  — database name
      instanceReady [bool]    — instance existed or was created without error
      built         [bool]    — database schema built successfully via full Flyway migrations
      error         [string]  — error message if any step failed; $null on success
  .EXAMPLE
    $results = New-SprintSqlServerInstances
    $results | Format-Table instanceName, database, instanceReady, built, error
  .EXAMPLE
    New-SprintSqlServerInstances -WhatIf
  .EXAMPLE
    New-SprintSqlServerInstances -InstanceNames @("Dev$($env:USERNAME)") `
      -Databases @('ATAPUtilities') -Verbose
  .NOTES
    AI assisted using ./claude/Rules/Powershell.md as guidelines
  .LINK
    New-SprintStage2
  .LINK
    Remove-SprintSqlServerInstances
  .LINK
    Build-DatabaseWithFlyway
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  param(
    [Parameter(Mandatory = $false)]
    [string[]]$InstanceNames,

    [Parameter(Mandatory = $false)]
    [string[]]$Databases,

    [Parameter(Mandatory = $false)]
    [string]$DatabaseHost,

    [Parameter(Mandatory = $false)]
    [string]$ConnectionMethod,

    [Parameter(Mandatory = $false)]
    [string]$FlywayBasePath,

    [Parameter(Mandatory = $false)]
    [string]$RepositoryRoot
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    # Snippet: Check and populate simple parameter as Type - InstanceNames
    if (-not $PSBoundParameters.ContainsKey('InstanceNames') -or $null -eq $InstanceNames -or $InstanceNames.Count -eq 0) {
      $InstanceNames = @("Dev$($env:USERNAME)", "Exp$($env:USERNAME)")
    }

    # Snippet: Check and populate simple parameter as Type - Databases
    if (-not $PSBoundParameters.ContainsKey('Databases') -or $null -eq $Databases -or $Databases.Count -eq 0) {
      $Databases = @('ATAPUtilities', 'AceCommander')
    }

    # Snippet: Check and populate simple parameter - DatabaseHost
    if ([string]::IsNullOrWhiteSpace($DatabaseHost)) {
      $DatabaseHost = 'localhost'
    }

    # Snippet: Check and populate simple parameter - ConnectionMethod
    if ([string]::IsNullOrWhiteSpace($ConnectionMethod)) {
      $ConnectionMethod = 'tcp'
    }

    # Snippet: Check and populate simple parameter - RepositoryRoot
    if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
      # This file lives at <repo>\src\ATAP.Utilities.BuildTooling.PowerShell\public\
      # Three levels up brings us to the repository root.
      $RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..') -ErrorAction SilentlyContinue)?.Path
      if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
        throw 'RepositoryRoot could not be determined from $PSScriptRoot.'
      }
    }

    # Snippet: Check and populate simple parameter - FlywayBasePath
    if ([string]::IsNullOrWhiteSpace($FlywayBasePath)) {
      # Try global settings first (R-10 / configRootKeys pattern)
      $flywayKey = 'FlywayBasePathConfigRootKey'
      if ($null -ne $global:configRootKeys -and $global:configRootKeys.ContainsKey($flywayKey) -and
        $null -ne $global:settings -and -not [string]::IsNullOrWhiteSpace($global:settings[$global:configRootKeys[$flywayKey]])) {
        $FlywayBasePath = $global:settings[$global:configRootKeys[$flywayKey]]
      } else {
        $FlywayBasePath = Join-Path $RepositoryRoot 'Database' 'Flyway'
      }
    }

    $flywayTomlPath = Join-Path $FlywayBasePath 'flyway.toml'
    if (-not (Test-Path $flywayTomlPath)) {
      throw "Flyway configuration file not found: $flywayTomlPath"
    }

    # Ensure Install-SqlServerInstance is available
    if (-not (Get-Command -Name 'Install-SqlServerInstance' -CommandType Function -ErrorAction SilentlyContinue)) {
      $installPath = Join-Path $RepositoryRoot 'src' 'ATAP.Utilities.DatabaseManagement.Powershell' 'public' 'Install-SqlServerInstance.ps1'
      if (-not (Test-Path $installPath)) {
        throw "Install-SqlServerInstance.ps1 not found at: $installPath"
      }
      . $installPath
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
        -Message "Loaded Install-SqlServerInstance from $installPath"
    }

    # Ensure Build-DatabaseWithFlyway is available (handles dbatools, Invoke-Flyway, and DatabaseProvisioning internally)
    if (-not (Get-Command -Name 'Build-DatabaseWithFlyway' -CommandType Function -ErrorAction SilentlyContinue)) {
      $buildDbPath = Join-Path $RepositoryRoot 'src' 'ATAP.Utilities.DatabaseManagement.Powershell' 'public' 'Build-DatabaseWithFlyway.ps1'
      if (-not (Test-Path $buildDbPath)) {
        throw "Build-DatabaseWithFlyway.ps1 not found at: $buildDbPath"
      }
      . $buildDbPath
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
        -Message "Loaded Build-DatabaseWithFlyway from $buildDbPath"
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
      -Message "Instances: $($InstanceNames -join ', ') | Databases: $($Databases -join ', ') | Host: $DatabaseHost | FlywayBase: $FlywayBasePath"
  }

  process {
    $results = [System.Collections.ArrayList]::new()

    foreach ($instanceName in $InstanceNames) {

      # --- Idempotency check — skip if service already exists ---
      $serviceName = "MSSQL`$$instanceName"
      $instanceReady = $false
      $instanceError = $null

      $existingService = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

      if ($null -ne $existingService) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
          -Message "SQL Server instance '$instanceName' already exists (service: $serviceName). Skipping creation."
        $instanceReady = $true
      } else {
        if ($PSCmdlet.ShouldProcess($instanceName, 'Install SQL Server named instance')) {
          try {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
              -Message "Creating SQL Server instance '$instanceName' on $DatabaseHost"

            $installParams = @{
              SQLInstance      = $instanceName
              DatabaseHost     = $DatabaseHost
              ConnectionMethod = $ConnectionMethod
            }

            $installResult = Install-SqlServerInstance @installParams -Confirm:$false

            if ($null -ne $installResult -and $installResult.PSObject.Properties['Success'] -and -not $installResult.Success) {
              if ($installResult.PSObject.Properties['Cancelled'] -and $installResult.Cancelled) {
                $instanceError = "Installation of SQL Server instance '$instanceName' was cancelled by the user."
              } else {
                $instanceError = "Install-SqlServerInstance reported failure for '$instanceName' (Success=False). Check dbatools output above."
              }
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $instanceError
            } else {
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
                -Message "SQL Server instance '$instanceName' created successfully."
              $instanceReady = $true
            }
          } catch {
            $instanceError = "Failed to create SQL Server instance '$instanceName'. Exception: $($_.Exception.Message)"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $instanceError
          }
        } else {
          # -WhatIf path — simulate success so downstream Flyway WhatIf entries are generated
          $instanceReady = $true
        }
      }

      # --- Full database build for each database on this instance ---
      foreach ($db in $Databases) {
        $built = $false
        $buildError = $instanceError  # inherit instance error if creation failed

        if ($instanceReady) {
          # Derive environment tier from instance name prefix (Dev → Development, Exp → Experimental)
          $environment = if ($instanceName.StartsWith('Dev')) { 'Development' }
          elseif ($instanceName.StartsWith('Exp')) { 'Experimental' }
          else { $instanceName }

          # --- Idempotency check — skip rebuild if the database already exists ---
          $sqlServerInstance = if ([string]::IsNullOrWhiteSpace($DatabaseHost) -or $DatabaseHost -eq 'localhost') {
            "localhost\$instanceName"
          } else {
            "$DatabaseHost\$instanceName"
          }

          # Ensure dbatools is available for the existence check
          if (-not (Get-Module -Name dbatools -ErrorAction SilentlyContinue)) {
            Import-Module dbatools -ErrorAction SilentlyContinue
          }

          $existingDb = Get-DbaDatabase -SqlInstance $sqlServerInstance -Database $db -ErrorAction SilentlyContinue

          if ($null -ne $existingDb) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
              -Message "Database '$db' already exists on instance '$instanceName'. Skipping rebuild (idempotent)."
            $built = $true
          } else {
            $buildTarget = "${instanceName}/${db}"
            if ($PSCmdlet.ShouldProcess($buildTarget, 'Build database with Flyway migrations')) {
              try {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
                  -Message "Building database: instance=$instanceName  db=$db  environment=$environment"

                $buildResult = Build-DatabaseWithFlyway `
                  -DatabaseName $db `
                  -Environment $environment `
                  -DatabaseHost $DatabaseHost `
                  -SqlInstance $instanceName `
                  -ConnectionMethod $ConnectionMethod `
                  -FlywayBasePath $FlywayBasePath `
                  -FlywayTomlPath $flywayTomlPath `
                  -FlywaySqlMigrationsPath (Join-Path $FlywayBasePath 'SQL') `
                  -IntegratedSecurity `
                  -Force

                if (-not $buildResult.Success) {
                  $buildError = "Build-DatabaseWithFlyway failed for instance='$instanceName' db='$db': $($buildResult.Errors -join '; ')"
                  Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $buildError
                } else {
                  Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
                    -Message "Database built successfully: instance=$instanceName  db=$db"
                  $built = $true
                }
              } catch {
                $buildError = "Build-DatabaseWithFlyway failed for instance='$instanceName' db='$db'. Exception: $($_.Exception.Message)"
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $buildError
              }
            } else {
              # -WhatIf path
              $built = $true
            }
          }
        }

        $entry = [PSCustomObject]@{
          instanceName  = $instanceName
          database      = $db
          instanceReady = $instanceReady
          built         = $built
          error         = $buildError
        }
        [void]$results.Add($entry)
      }
    }

    return $results.ToArray()
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
