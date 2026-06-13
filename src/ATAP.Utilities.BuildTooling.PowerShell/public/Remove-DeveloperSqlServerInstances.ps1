function Remove-DeveloperSqlServerInstances {
  <#
  .SYNOPSIS
  Developer-offboarding cmdlet: removes the permanent per-developer SQL Server
  named instances from a workstation.

  .DESCRIPTION
  Run ONLY as part of developer offboarding (or a deliberate workstation teardown).
  Removes the two named instances that were provisioned per developer by
  `New-DeveloperSqlServerInstances`:
    - Dev{DeveloperName}   — T2 Development/Alpha tier
    - Exp{DeveloperName}   — T1 Experimental/Sprint tier

  IMPORTANT (Sprint 0008 requirement change): these instances are permanent
  developer-onboarding infrastructure. They are NOT removed at sprint end. Sprint
  end only drops the databases inside the instances via `Remove-SprintDatabases`.
  Do not call this cmdlet from any sprint-lifecycle agent or script.

  Instance removal uses the SQL Server setup.exe with /ACTION=Uninstall.
  The setup media folder must contain a valid setup.exe.

  The set of developer names is resolved (in priority order) from:
    1. The -DeveloperNames parameter if supplied
    2. $global:settings[$global:configRootKeys['SprintDeveloperNamesConfigRootKey']]
       (dotted path: Sprint.DeveloperNames)
    3. $env:USERNAME (single-developer default)

  Caller is responsible for pre-loading the Get-PVal helper function.

  Supersedes `Remove-SprintSqlServerInstances` (now retained only as a deprecated
  alias of this function) and the earlier `Remove-DeveloperDatabaseInstances`.

  .PARAMETER SprintNumber
  Four-character zero-padded sprint number, e.g. '0006'. Not used in instance names;
  retained for result-object labelling and logging traceability.

  .PARAMETER DeveloperNames
  Array of developer names whose instances should be removed.  Overrides the
  global-settings lookup and the $env:USERNAME default.

  .PARAMETER SqlServerSetupPath
  Path to the folder containing the extracted SQL Server setup media (setup.exe).
  Default: D:\Temp\SQLExpr\extracted.

  .PARAMETER SkipDatabaseDrop
  When set, skips explicitly dropping ATAPUtilities and AceCommander databases
  before removing the instance (SQL Server uninstall drops them automatically, but
  you may want explicit logging of the drop).

  .PARAMETER Force
  Bypasses PowerShell's high-impact ShouldProcess confirmation prompts for
  non-interactive pipeline / agent invocations. Does not override -WhatIf.

  .OUTPUTS
  PSCustomObject with fields:
    SprintNumber     string
    DeveloperNames   string[]
    RemovalResults   PSCustomObject[]  — one entry per (developer × instance type)
    OverallSuccess   bool

  .EXAMPLE
  Remove-DeveloperSqlServerInstances
  Removes Dev<username> and Exp<username> instances for the current user.

  .EXAMPLE
  Remove-DeveloperSqlServerInstances -WhatIf
  Shows what would be removed without making any changes.

  .EXAMPLE
  Remove-DeveloperSqlServerInstances -DeveloperNames @('whertzing', 'jsmith')
  Removes instances for two developers during a shared-workstation teardown.

  .NOTES
  AI assisted using ./claude/Rules/Powershell.md as guidelines

  .LINK
  New-DeveloperSqlServerInstances

  .LINK
  Remove-SprintDatabases

  .LINK
  Install-SqlServerInstance
  #>
  [Alias('Remove-SprintSqlServerInstances', 'Remove-DeveloperDatabaseInstances')]
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  param(
    [Parameter(Mandatory = $false)]
    [ValidatePattern('^\d{4}$')]
    [string]$SprintNumber,

    [Parameter(Mandatory = $false)]
    [string[]]$DeveloperNames,

    [Parameter(Mandatory = $false)]
    [string]$DatabaseHost = 'localhost',

    [Parameter(Mandatory = $false)]
    [string[]]$Databases = @('ATAPUtilities', 'AceCommander'),

    [Parameter(Mandatory = $false)]
    [string]$SqlServerSetupPath = 'D:\Temp\SQLExpr\extracted',

    [Parameter(Mandatory = $false)]
    [switch]$SkipDatabaseDrop,

    [Parameter(Mandatory = $false)]
    [switch]$Force
  )

  $fn = $MyInvocation.MyCommand.Name
  $mn = 'ATAP.Utilities.BuildTooling.PowerShell'

  if ($Force) {
    $ConfirmPreference = 'None'
  }

  # Load Helpers — ToDo: Remove this when packaging works
  # Mirrors the resolution pattern used in New-DeveloperSqlServerInstances: locate the
  # repository root from $PSScriptRoot and dot-source the helper from the in-repo path.
  # Failures are non-fatal — the Get-PVal call below is itself guarded so the cmdlet
  # gracefully falls back to $env:USERNAME if the helper cannot be loaded.
  if (-not (Get-Command -Name 'Get-ParameterValueFromNeoConfigurationRoot' -CommandType Function -ErrorAction SilentlyContinue)) {
    try {
      $repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..') -ErrorAction SilentlyContinue)?.Path
      if ($repositoryRoot) {
        $helperPath = Join-Path $repositoryRoot 'src' 'ATAP.Utilities.Powershell' 'public' 'Get-ParameterValueFromNeoConfigurationRoot.ps1'
        if (Test-Path -LiteralPath $helperPath -PathType Leaf) {
          . $helperPath
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
            -Message "Loaded Get-ParameterValueFromNeoConfigurationRoot from $helperPath"
        } else {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
            -Message "Get-ParameterValueFromNeoConfigurationRoot helper not found at $helperPath; will fall back to defaults."
        }
      }
    } catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
        -Message "Failed to auto-load Get-ParameterValueFromNeoConfigurationRoot helper: $($_.Exception.Message). Will fall back to defaults."
    }
  }

  # ── Resolve developer names ──────────────────────────────────────────────
  if (-not $PSBoundParameters.ContainsKey('DeveloperNames')) {
    $settingsKey = if ($global:configRootKeys -and $global:configRootKeys['SprintDeveloperNamesConfigRootKey']) {
      $global:configRootKeys['SprintDeveloperNamesConfigRootKey']
    } else {
      'Sprint.DeveloperNames'
    }
    if (Get-Command -Name 'Get-PVal' -ErrorAction SilentlyContinue) {
      $DeveloperNames = Get-PVal `
        -ParameterName 'DeveloperNames' `
        -originalPSBoundParameters $PSBoundParameters `
        -dottedPath $settingsKey `
        -DefaultValue @($env:USERNAME) `
        -AllowMissing
    }
    if (-not $DeveloperNames) {
      $DeveloperNames = @($env:USERNAME)
    }
  }
  Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
    -Message "Developer names resolved: $($DeveloperNames -join ', ')"

  # ── Locate setup.exe ──────────────────────────────────────────────────────
  $setupExe = Join-Path $SqlServerSetupPath 'setup.exe'
  if (-not (Test-Path $setupExe -PathType Leaf)) {
    # Fall back: look for setup.exe in the SQL Server Bootstrap folders
    $bootstrapSetup = Get-ChildItem `
      'C:\Program Files\Microsoft SQL Server\*\Setup Bootstrap\*\setup.exe' `
      -ErrorAction SilentlyContinue |
      Sort-Object LastWriteTime -Descending |
      Select-Object -First 1 -ExpandProperty FullName

    if ($bootstrapSetup) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
        -Message "setup.exe not found at '$SqlServerSetupPath'. Using bootstrap copy: '$bootstrapSetup'"
      $setupExe = $bootstrapSetup
    } else {
      $errorMessage = "setup.exe not found at '$SqlServerSetupPath' and no bootstrap copy found. " +
      'Provide a valid -SqlServerSetupPath containing setup.exe.'
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw $errorMessage
    }
  }

  $removalResults = [System.Collections.Generic.List[PSCustomObject]]::new()
  $overallSuccess = $true

  foreach ($developer in $DeveloperNames) {
    $instances = @(
      [PSCustomObject]@{ InstanceLabel = 'Dev'; SqlInstance = "Dev${developer}" }
      [PSCustomObject]@{ InstanceLabel = 'Exp'; SqlInstance = "Exp${developer}" }
    )

    foreach ($inst in $instances) {
      $entry = [PSCustomObject]@{
        Developer     = $developer
        InstanceLabel = $inst.InstanceLabel
        SqlInstance   = $inst.SqlInstance
        Removed       = $false
        Skipped       = $false
        Error         = $null
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
        -Message "Removing SQL Server instance '$($inst.SqlInstance)'..."

      # ── Verify instance exists before attempting removal ──────────────────
      $sqlServerInstance = if ([string]::IsNullOrWhiteSpace($DatabaseHost) -or $DatabaseHost -eq 'localhost') {
        "localhost\$($inst.SqlInstance)"
      } else {
        "$DatabaseHost\$($inst.SqlInstance)"
      }

      $existingInstance = Get-DbaRegisteredServer -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq $sqlServerInstance }
      # Simpler check: try to connect
      $instanceExists = $null
      try {
        $instanceExists = Connect-DbaInstance -SqlInstance $sqlServerInstance `
          -TrustServerCertificate -ConnectTimeout 5 -ErrorAction Stop
      } catch {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
          -Message "Instance '$sqlServerInstance' is not reachable - it may not exist or may already be removed. Skipping."
        $entry.Skipped = $true
        $removalResults.Add($entry)
        continue
      }

      if (-not $SkipDatabaseDrop -and $null -ne $instanceExists) {
        foreach ($dbName in $Databases) {
          try {
            $db = Get-DbaDatabase -SqlInstance $instanceExists -Database $dbName -ErrorAction SilentlyContinue
            if ($db) {
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
                -Message "Dropping database '$dbName' from '$($inst.SqlInstance)'..."
              if ($PSCmdlet.ShouldProcess("$sqlServerInstance\$dbName", 'Drop SQL Server database')) {
                Remove-DbaDatabase -SqlInstance $instanceExists -Database $dbName -Confirm:$false
              }
            }
          } catch {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error `
              -Message "Failed to drop '$dbName' from '$($inst.SqlInstance)': $($_.Exception.Message)"
          }
        }
      }

      if (-not $PSCmdlet.ShouldProcess($inst.SqlInstance, 'Remove SQL Server instance via setup.exe')) {
        $entry.Skipped = $true
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
          -Message "WhatIf: would run: $setupExe /ACTION=Uninstall /FEATURES=SQLENGINE /INSTANCENAME=$($inst.SqlInstance) /QUIET /HIDECONSOLE"
        $removalResults.Add($entry)
        continue
      }

      try {
        $setupArgs = @(
          '/ACTION=Uninstall',
          '/FEATURES=SQLENGINE',
          "/INSTANCENAME=$($inst.SqlInstance)",
          '/QUIET',
          '/HIDECONSOLE'
        )
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
          -Message "Running: $setupExe $($setupArgs -join ' ')"

        $proc = Start-Process -FilePath $setupExe -ArgumentList $setupArgs `
          -Wait -PassThru -NoNewWindow
        if ($proc.ExitCode -eq 0) {
          $entry.Removed = $true
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
            -Message "Instance '$($inst.SqlInstance)' removed successfully (exit code 0)."
        } else {
          $entry.Error = "setup.exe exited with code $($proc.ExitCode). Check '%PROGRAMFILES%\Microsoft SQL Server\*\Setup Bootstrap\Log' for details."
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $entry.Error
        }
      } catch {
        $entry.Error = $_.Exception.Message
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error `
          -Message "Exception removing '$($inst.SqlInstance)': $($_.Exception.Message)"
      }

      if ($entry.Error) { $overallSuccess = $false }
      $removalResults.Add($entry)
    }
  }

  return [PSCustomObject]@{
    SprintNumber   = $SprintNumber
    DeveloperNames = $DeveloperNames
    RemovalResults = $removalResults.ToArray()
    OverallSuccess = $overallSuccess
  }
}
