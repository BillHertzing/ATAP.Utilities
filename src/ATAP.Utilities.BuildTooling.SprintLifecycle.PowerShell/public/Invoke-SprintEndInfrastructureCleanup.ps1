function Invoke-SprintEndInfrastructureCleanup {
  <#
  .SYNOPSIS
  Runs the safe SprintEnd infrastructure teardown sequence.

  .DESCRIPTION
  Performs the infrastructure health check, drops only per-sprint databases,
  clears BuildMaster sprint variables, and reasserts stable boundary settings.
  SQL Server instances are permanent developer infrastructure and are retained.
  This cmdlet never calls Remove-SprintBitwardenSecrets or any SQL-instance
  removal command.

  .PARAMETER GitRoot
  Parent directory containing stable repositories.

  .PARAMETER DeveloperNames
  Developer suffixes whose Dev/Exp databases are removed.

  .PARAMETER Apply
  Executes cleanup. Without Apply, only the read-only health check runs.

  .PARAMETER DatabaseCleanupTargets
  Optional exact local instance/database records with InstanceName and Databases.
  Only Dev/Exp developer instances, Integration, and QA are allowed. Production
  and system databases are protected. An explicitly empty list is invalid.
  Omit this parameter to retain the default Dev/Exp database cleanup.

  .PARAMETER LoginScriptPath
  Explicit development LoginScript.ps1 target for this invocation only. An explicitly
  supplied empty target is invalid. Omit to audit the stable Utilities default.

  .PARAMETER WorktreePaths
  Worktrees being removed. The selected login target must survive their removal.

  .PARAMETER ProfiledRemotingPolicy
  Policy passed to the stable boundary reassertion. Defaults to Auto.

  .PARAMETER HostDisposition
      Explicit operator-approved host and identity disposition. Allows only the declared
      personal BW_SESSION scopes and login-task mode; omission retains strict defaults.

  .OUTPUTS
  PSCustomObject with health, database, BuildMaster, and boundary results.

  .EXAMPLE
  Invoke-SprintEndInfrastructureCleanup -GitRoot C:\Repos -WhatIf

  .NOTES
  AI assisted using Powershell.instructions.md as guidelines.
  #>
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$GitRoot,

    [Parameter()]
    [string[]]$DeveloperNames = @($env:USERNAME),

    [Parameter()]
    [AllowNull()][AllowEmptyCollection()]
    [object[]]$DatabaseCleanupTargets,

    [Parameter()]
    [string]$BuildMasterAdminApiKeySecretName = 'BuildMaster.Admin.API.Key',

    [Parameter()]
    [switch]$Apply,

    [Parameter()]
    [AllowNull()][AllowEmptyString()]
    [string]$LoginScriptPath,

    [Parameter()]
    [string[]]$WorktreePaths = @(),

    [Parameter()]
    [ValidateSet('Disabled', 'Auto', 'Required')]
    [string]$ProfiledRemotingPolicy = 'Auto',

    [Parameter()]
    [AllowNull()]
    [object]$HostDisposition
  )

  begin {
    # An invocation-scoped operator disposition is validated before effects.
    # No policy preserves the existing strict task/environment contract.
    $hostDispositionParameters = @{}
    $hostDispositionContext = $null
    if ($PSBoundParameters.ContainsKey('HostDisposition')) {
      if (-not (Get-Command -Name 'Resolve-SprintEndHostDisposition' -ErrorAction SilentlyContinue) -or
          -not (Get-Command -Name 'Test-SprintEndEnvironmentVariablePresent' -ErrorAction SilentlyContinue)) {
        $hostDispositionHelper = Join-Path $PSScriptRoot '../private/Resolve-SprintEndHostDisposition.ps1'
        if (-not (Test-Path -LiteralPath $hostDispositionHelper -PathType Leaf)) { throw 'Required host disposition helper is unavailable.' }
        . $hostDispositionHelper
      }
      if ($PSBoundParameters.ContainsKey('HostDisposition')) {
        $hostDispositionContext = Resolve-SprintEndHostDisposition -HostDisposition $HostDisposition
        $hostDispositionParameters.HostDisposition = $hostDispositionContext.Metadata
      }
    }

    $fn = 'Invoke-SprintEndInfrastructureCleanup'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    $exactDatabaseCleanup = $PSBoundParameters.ContainsKey('DatabaseCleanupTargets')
    $databaseCleanupMode = 'SprintDatabasesOnly'
    $databaseTargetSelectionMode = if ($exactDatabaseCleanup) { 'ExactDatabaseTargets' } else { 'DeveloperDefaults' }
    $validatedDatabaseTargets = @()
    if ($exactDatabaseCleanup) {
      if ($null -eq $DatabaseCleanupTargets -or $DatabaseCleanupTargets.Count -eq 0) {
        throw 'DatabaseCleanupTargets must contain at least one exact instance/database record.'
      }
      $seenInstances = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
      foreach ($target in $DatabaseCleanupTargets) {
        if ($null -eq $target -or $target.InstanceName -isnot [string] -or
          $target.InstanceName -notmatch '^(Dev[A-Za-z0-9_]+|Exp[A-Za-z0-9_]+|Integration|QA)$' -or
          -not $seenInstances.Add($target.InstanceName)) {
          throw 'DatabaseCleanupTargets requires unique local Dev/Exp, Integration, or QA instance names.'
        }
        if ($null -eq $target.Databases -or $target.Databases -is [string] -or @($target.Databases).Count -eq 0) {
          throw 'Each DatabaseCleanupTargets record requires a nonempty Databases array.'
        }
        $seenDatabases = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach ($database in $target.Databases) {
          if ($database -isnot [string] -or [string]::IsNullOrWhiteSpace($database) -or
            $database -ne $database.Trim() -or $database -in @('master', 'model', 'msdb', 'tempdb') -or
            -not $seenDatabases.Add($database)) {
            throw 'DatabaseCleanupTargets contains an empty, duplicate, malformed, or protected system database name.'
          }
        }
        $validatedDatabaseTargets += [pscustomobject]@{ InstanceName = $target.InstanceName; Databases = @($target.Databases) }
      }
    }
    # SC-0288 / Task 13.66.b: the SecretName host suffix is derived from the service placement
    # host, never hard-coded. Resolution order is the authoritative host setting,
    # then the placement map; an unknown placement host fails closed.
    if (-not $PSBoundParameters.ContainsKey('BuildMasterAdminApiKeySecretName')) {
      if (-not (Get-Command -Name 'Resolve-HostSuffixedSecretName' -ErrorAction SilentlyContinue)) {
        . (Join-Path $PSScriptRoot '..' '..' 'ATAP.Utilities.BuildTooling.Common.PowerShell' 'public' 'Resolve-HostSuffixedSecretName.ps1')
      }
      $BuildMasterAdminApiKeySecretName = Resolve-HostSuffixedSecretName `
        -BaseName $BuildMasterAdminApiKeySecretName -ServiceName 'BuildMaster' -SettingName 'BuildMasterAdminApiKeySecretName'
    }

    $fn = 'Invoke-SprintEndInfrastructureCleanup'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
  }

  process {
    $databaseResults = @()
    $buildMasterResult = $null
    $boundaryResult = $null
    $actions = [System.Collections.Generic.List[string]]::new()
    $failures = [System.Collections.Generic.List[string]]::new()
    $loginScheduledTasks = $null
    try {
      if (-not (Get-Command Set-SprintLoginScheduledTaskTarget -ErrorAction SilentlyContinue)) {
        . (Join-Path $PSScriptRoot '..\private\Set-SprintLoginScheduledTaskTarget.ps1')
      }
      $loginParameters = @{
        Boundary = 'End'
        GitRoot = $GitRoot
        WorktreePaths = $WorktreePaths
        Confirm = $false
      }
      if ($PSBoundParameters.ContainsKey('LoginScriptPath')) {
        $loginParameters.LoginScriptPath = $LoginScriptPath
      }
      if ($Apply -and $WhatIfPreference) {
        # The outer lifecycle only planned the boundary reset. Validate and plan
        # this pair without demanding that the retained sprint bindings changed.
        $loginParameters.WhatIf = $true
      } else {
        $loginParameters.CheckOnly = $true
      }
      $loginScheduledTasks = Set-SprintLoginScheduledTaskTarget @loginParameters @hostDispositionParameters
      if ($null -eq $loginScheduledTasks -or -not $loginScheduledTasks.Ok) {
        [void]$failures.Add('LoginScheduledTasks')
      }
    } catch {
      [void]$failures.Add("LoginScheduledTasks: $($_.Exception.Message)")
    }
    if ($failures.Count -gt 0) {
      return [PSCustomObject]@{
        HostDisposition = $hostDispositionParameters['HostDisposition']
        Ok = $false; Applied = $false; Planned = [bool]($Apply -and $WhatIfPreference)
        Health = $null; DatabaseResults = $databaseResults; DatabaseCleanupMode = $databaseCleanupMode
        DatabaseTargetSelectionMode = $databaseTargetSelectionMode; DatabaseCleanupTargets = $validatedDatabaseTargets
        BuildMasterResult = $null; BoundaryResult = $null; LoginScheduledTasks = $loginScheduledTasks
        BitwardenSecretsRemoved = $false; SqlInstancesRetained = $true
        Actions = $actions.ToArray(); Failures = $failures.ToArray()
      }
    }

    # The End-boundary preview plans removal of a process-scoped BWS token but
    # correctly leaves the current process unchanged. Project that one planned
    # removal while running the read-only health check, then restore the exact
    # prior process value so -WhatIf has no net environment mutation. Also keep
    # ambient WhatIf from suppressing Get-SecretATAP's own transient cleanup.
    $priorProcessBwsAccessToken = [Environment]::GetEnvironmentVariable('BWS_ACCESS_TOKEN', 'Process')
    $projectProcessBwsRemoval = ($WhatIfPreference -and -not [string]::IsNullOrWhiteSpace($priorProcessBwsAccessToken))
    try {
      if ($projectProcessBwsRemoval) {
        [Environment]::SetEnvironmentVariable('BWS_ACCESS_TOKEN', $null, 'Process')
      }
      $health = & {
        $WhatIfPreference = $false
        Test-SprintInfrastructureHealth @hostDispositionParameters `
          -BuildMasterAdminApiKeySecretName $BuildMasterAdminApiKeySecretName
      }
    } finally {
      if ($projectProcessBwsRemoval) {
        [Environment]::SetEnvironmentVariable('BWS_ACCESS_TOKEN', $priorProcessBwsAccessToken, 'Process')
      }
    }
    if ($Apply) {
      if (-not $health.AllOk) {
        throw "Sprint infrastructure health failed: $($health.Failures -join ', ')."
      }
      $databaseScope = if ($exactDatabaseCleanup) {
        ($validatedDatabaseTargets | ForEach-Object { "$($_.InstanceName): $($_.Databases -join ', ')" }) -join '; '
      } else { $DeveloperNames -join ', ' }
      if ($PSCmdlet.ShouldProcess($databaseScope, 'Drop sprint databases only')) {
        try {
          if (-not (Get-Command -Name Get-DbaDatabase -ErrorAction SilentlyContinue)) {
            throw 'Get-DbaDatabase is required to independently verify database cleanup; install/import dbatools.'
          }
          if ($exactDatabaseCleanup) {
            foreach ($target in $validatedDatabaseTargets) {
              $rows = @(Remove-SprintDatabases -InstanceNames @($target.InstanceName) -Databases $target.Databases -Force -Confirm:$false)
              $databaseResults += $rows
              foreach ($database in $target.Databases) {
                $matchingRows = @($rows | Where-Object { $_.instanceName -eq $target.InstanceName -and $_.database -eq $database })
                if ($matchingRows.Count -ne 1) { throw "Missing or duplicate cleanup result for $($target.InstanceName)/$database." }
              }
              if ($rows.Count -ne $target.Databases.Count) { throw 'Unexpected database cleanup result rows.' }
              foreach ($row in $rows) {
                if ($null -eq $row -or $row.error -or -not $row.instanceReady -or $row.dryRun -or
                  (-not $row.dropped -and -not $row.skipped)) { throw 'Database cleanup returned an unsuccessful result.' }
                $remainingDatabase = @(Get-DbaDatabase -SqlInstance ("localhost\$($row.instanceName)") -Database $row.database -EnableException -ErrorAction Stop)
                if ($remainingDatabase.Count -gt 0) { throw "Database still exists after cleanup: $($row.instanceName)/$($row.database)." }
              }
            }
          } else {
            $databaseResults = @(Remove-SprintDatabases -DeveloperNames $DeveloperNames -Force -Confirm:$false)
            if ($databaseResults.Count -eq 0) { throw 'Database cleanup returned no results.' }
            foreach ($developer in $DeveloperNames) {
              foreach ($instance in @("Dev$developer", "Exp$developer")) {
                foreach ($database in @('ATAPUtilities', 'AceCommander')) {
                  if (@($databaseResults | Where-Object { $_.instanceName -eq $instance -and $_.database -eq $database }).Count -ne 1) {
                    throw "Missing or duplicate cleanup result for $instance/$database."
                  }
                }
              }
            }
            foreach ($row in $databaseResults) {
              if ($null -eq $row -or $row.error -or -not $row.instanceReady -or $row.dryRun -or
                (-not $row.dropped -and -not $row.skipped)) { throw 'Database cleanup returned an unsuccessful result.' }
              $remainingDatabase = @(Get-DbaDatabase -SqlInstance ("localhost\$($row.instanceName)") -Database $row.database -EnableException -ErrorAction Stop)
              if ($remainingDatabase.Count -gt 0) { throw "Database still exists after cleanup: $($row.instanceName)/$($row.database)." }
            }
          }
          [void]$actions.Add('Removed per-sprint databases.')
        } catch {
          [void]$failures.Add("DatabaseCleanup: $($_.Exception.Message)")
        }
      } elseif (-not $WhatIfPreference) {
        [void]$failures.Add('DatabaseCleanup: database removal was not approved.')
      }
      if ($failures.Count -eq 0 -and $PSCmdlet.ShouldProcess('BuildMaster applications', 'Clear sprint variables')) {
        try {
          $buildMasterResult = Clear-BuildMasterSprintVariables -Confirm:$false
          if ($null -eq $buildMasterResult -or @($buildMasterResult.errors).Count -gt 0) {
            [void]$failures.Add('BuildMasterCleanup')
          } else {
            [void]$actions.Add('Cleared BuildMaster sprint variables.')
          }
        } catch {
          [void]$failures.Add("BuildMasterCleanup: $($_.Exception.Message)")
        }
      }
      $stableSharedVSCode = Join-Path ([IO.Path]::GetFullPath($GitRoot)) 'SharedVSCode'
      if ($failures.Count -eq 0 -and $PSCmdlet.ShouldProcess($stableSharedVSCode, 'Reassert stable SprintEnd boundary')) {
        try {
          $boundaryResult = Set-SprintBoundaryContext @hostDispositionParameters `
            -Boundary End `
            -SharedVSCodeWorktreePath $stableSharedVSCode `
            -GitRoot $GitRoot `
            -WorktreePaths @() `
            -SkipLoginScheduledTasks `
            -ProfiledRemotingPolicy $ProfiledRemotingPolicy `
            -Confirm:$false
          if ($null -eq $boundaryResult -or @($boundaryResult.Errors).Count -gt 0) {
            [void]$failures.Add('BoundaryReset')
          } else {
            [void]$actions.Add('Reasserted stable boundary.')
          }
        } catch {
          [void]$failures.Add("BoundaryReset: $($_.Exception.Message)")
        }
      }
    }

    $cleanupOk = ($health.AllOk -and $failures.Count -eq 0 -and
      (-not $Apply -or $WhatIfPreference -or ($null -ne $buildMasterResult -and $null -ne $boundaryResult)))
    return [PSCustomObject]@{
      HostDisposition = $hostDispositionParameters['HostDisposition']
      Ok                         = $cleanupOk
      Applied                    = [bool]($Apply -and -not $WhatIfPreference -and $cleanupOk)
      Planned                    = [bool]($Apply -and $WhatIfPreference)
      Health                     = $health
      DatabaseResults            = $databaseResults
      DatabaseCleanupMode        = $databaseCleanupMode
      DatabaseTargetSelectionMode = $databaseTargetSelectionMode
      DatabaseCleanupTargets     = $validatedDatabaseTargets
      BuildMasterResult          = $buildMasterResult
      BoundaryResult             = $boundaryResult
      LoginScheduledTasks        = $loginScheduledTasks
      BitwardenSecretsRemoved    = $false
      SqlInstancesRetained       = $true
      Actions                    = $actions.ToArray()
      Failures                   = $failures.ToArray()
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
