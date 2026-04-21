function New-SprintSqlServerInstances {
  <#
  .SYNOPSIS
    Creates the `Development` and `Experimental` SQL Server named instances for
    the sprint environment and runs the Flyway baseline for all target databases.
  .DESCRIPTION
    Idempotently creates two SQL Server named instances — `Development` and
    `Experimental` — that serve the T2/T1 tiers respectively during the sprint.
    Instance names contain no user or sprint suffix (§1.1 of 5TierRemainingTasks_V2.md).

    For each instance that is successfully created (or already present), the
    function runs `Invoke-Flyway -FlywayCommand baseline` against every database
    in -Databases so that Flyway's schema-history table exists before
    the first `migrate` call.

    Idempotency rules:
    - If the Windows service `MSSQL$<InstanceName>` already exists, instance
      creation is skipped and a warning is logged.
    - If the Flyway baseline exits with code 0, the result is recorded as
      successful regardless of whether the history table already existed.

    Depends on:
    - `Install-SqlServerInstance` (ATAP.Utilities.DatabaseManagement.Powershell)
    - `Invoke-Flyway` (ATAP.Utilities.DatabaseManagement.Powershell)

    Both helpers are dot-sourced from the repository root if not already loaded.
  .PARAMETER InstanceNames
    SQL Server named-instance names to create.
    Default: @('Development', 'Experimental')
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
      baselined     [bool]    — Flyway baseline completed successfully
      error         [string]  — error message if any step failed; $null on success
  .EXAMPLE
    $results = New-SprintSqlServerInstances
    $results | Format-Table instanceName, database, instanceReady, baselined, error
  .EXAMPLE
    New-SprintSqlServerInstances -WhatIf
  .EXAMPLE
    New-SprintSqlServerInstances -InstanceNames @('Development') `
      -Databases @('ATAPUtilities') -Verbose
  .NOTES
    AI assisted using ./claude/Rules/Powershell.md as guidelines
  .LINK
    New-SprintStage2
  .LINK
    Remove-SprintSqlServerInstances
  .LINK
    Invoke-Flyway
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
      $InstanceNames = @('Development', 'Experimental')
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

    # Ensure dbatools is imported — Invoke-Flyway requires [Microsoft.Data.SqlClient.SqlConnection]
    if (-not (Get-Module -Name 'dbatools')) {
      if (-not (Get-Module -Name 'dbatools' -ListAvailable)) {
        throw 'dbatools module is required by Invoke-Flyway but is not installed. Run: Install-Module dbatools -Scope CurrentUser'
      }
      Import-Module dbatools -ErrorAction Stop
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Imported dbatools module'
    }

    # Ensure Invoke-Flyway is available
    if (-not (Get-Command -Name 'Invoke-Flyway' -CommandType Function -ErrorAction SilentlyContinue)) {
      $flywayFnPath = Join-Path $RepositoryRoot 'src' 'ATAP.Utilities.DatabaseManagement.Powershell' 'public' 'Invoke-Flyway.ps1'
      if (-not (Test-Path $flywayFnPath)) {
        throw "Invoke-Flyway.ps1 not found at: $flywayFnPath"
      }
      . $flywayFnPath
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
        -Message "Loaded Invoke-Flyway from $flywayFnPath"
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

      # --- Flyway baseline for each database on this instance ---
      foreach ($db in $Databases) {
        $baselined = $false
        $baselineError = $instanceError  # inherit instance error if creation failed

        if ($instanceReady) {
          $flywayTarget = "${instanceName}/${db}"
          if ($PSCmdlet.ShouldProcess($flywayTarget, 'Run Flyway baseline')) {
            try {
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
                -Message "Running Flyway baseline: instance=$instanceName  db=$db"

              # Ensure the database exists before Flyway baseline — Flyway cannot create it.
              $sqlServerInstance = "${DatabaseHost}\${instanceName}"
              $existingDb = Get-DbaDatabase -SqlInstance $sqlServerInstance -Database $db -ErrorAction SilentlyContinue
              if ($null -eq $existingDb) {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
                  -Message "Creating database '$db' on instance '$sqlServerInstance' (required before Flyway baseline)"
                New-DbaDatabase -SqlInstance $sqlServerInstance -Name $db -ErrorAction Stop | Out-Null
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
                  -Message "Database '$db' created on '$sqlServerInstance'."
              }

              Invoke-Flyway `
                -DatabaseName $db `
                -Environment $instanceName `
                -DatabaseHost $DatabaseHost `
                -SqlInstance $instanceName `
                -ConnectionMethod $ConnectionMethod `
                -FlywayBasePath $FlywayBasePath `
                -FlywayTomlPath $flywayTomlPath `
                -FlywaySqlMigrationsPath (Join-Path $FlywayBasePath 'SQL') `
                -FlywayCommand 'baseline' `
                -IntegratedSecurity

              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
                -Message "Flyway baseline succeeded: instance=$instanceName  db=$db"
              $baselined = $true
            } catch {
              $baselineError = "Flyway baseline failed for instance='$instanceName' db='$db'. Exception: $($_.Exception.Message)"
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $baselineError
            }
          } else {
            # -WhatIf path
            $baselined = $true
          }
        }

        $entry = [PSCustomObject]@{
          instanceName  = $instanceName
          database      = $db
          instanceReady = $instanceReady
          baselined     = $baselined
          error         = $baselineError
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
