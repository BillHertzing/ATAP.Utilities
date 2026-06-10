function Remove-DeveloperDatabaseInstances {
  <#
  .SYNOPSIS
  Removes per-developer SQL Server named instances created at sprint start.

  .DESCRIPTION
  At the end of a sprint, removes the two named instances that were created per developer:
    - Dev{DeveloperName}   — T2 Development/Alpha tier
    - Exp{DeveloperName}   — T1 Experimental/Sprint tier

  Instance removal uses the SQL Server setup.exe with /ACTION=Uninstall.
  The setup media folder must contain a valid setup.exe.

  The set of developer names is resolved (in priority order) from:
    1. The -DeveloperNames parameter if supplied
    2. $global:settings[$global:configRootKeys['SprintDeveloperNamesConfigRootKey']]
       (dotted path: Sprint.DeveloperNames)
    3. $env:USERNAME (single-developer default)

  Caller is responsible for pre-loading the Get-PVal helper function.

  .PARAMETER SprintNumber
  Four-character zero-padded sprint number, e.g. '0006'. No longer used in instance names;
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

  .OUTPUTS
  PSCustomObject with fields:
    SprintNumber     string
    DeveloperNames   string[]
    RemovalResults   PSCustomObject[]  — one entry per (developer × instance type)
    OverallSuccess   bool
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  param(
    [Parameter(Mandatory = $false)]
    [ValidatePattern('^\d{4}$')]
    [string]$SprintNumber,

    [Parameter(Mandatory = $false)]
    [string[]]$DeveloperNames,

    [Parameter(Mandatory = $false)]
    [string]$SqlServerSetupPath = 'D:\Temp\SQLExpr\extracted',

    [Parameter(Mandatory = $false)]
    [switch]$SkipDatabaseDrop
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
      $existingInstance = Get-DbaRegisteredServer -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq "localhost\$($inst.SqlInstance)" }
      # Simpler check: try to connect
      $instanceExists = $null
      try {
        $instanceExists = Connect-DbaInstance -SqlInstance "localhost\$($inst.SqlInstance)" `
          -TrustServerCertificate -ConnectTimeout 5 -ErrorAction Stop
      } catch {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
          -Message "Instance 'localhost\$($inst.SqlInstance)' is not reachable — it may not exist or may already be removed. Skipping."
        $entry.Skipped = $true
        $removalResults.Add($entry)
        continue
      }

      if (-not $SkipDatabaseDrop -and $null -ne $instanceExists) {
        # Explicitly drop ATAPUtilities and AceCommander before instance removal
        foreach ($dbName in @('ATAPUtilities', 'AceCommander')) {
          try {
            $db = Get-DbaDatabase -SqlInstance $instanceExists -Database $dbName -ErrorAction SilentlyContinue
            if ($db) {
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
                -Message "Dropping database '$dbName' from '$($inst.SqlInstance)'..."
              Remove-DbaDatabase -SqlInstance $instanceExists -Database $dbName -Confirm:$false
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
