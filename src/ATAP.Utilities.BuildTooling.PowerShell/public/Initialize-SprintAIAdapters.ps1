# Load contract: dot-source this file to define Initialize-SprintAIAdapters. No top-level
# code executes on load — all side effects occur only when the function is called.
function Initialize-SprintAIAdapters {
  <#
  .SYNOPSIS
    Back-compat delegate: materializes AI adapters through the single lifecycle
    code path (Invoke-SprintAIAdapterLifecycle -Boundary Start).
  .DESCRIPTION
    Task 12.2.b (SC-0236) consolidated SprintStart adapter materialization into
    ONE code path. Set-SprintBoundaryContext -Boundary Start is the single
    per-worktree entry point (junctions -> context -> adapter materialization),
    and its adapter step is Invoke-SprintAIAdapterLifecycle -Boundary Start,
    which renders ALL canonical domains (instructions, settings, permissions,
    hooks, toolsets) from the SharedVSCode .ai adapter registry.

    Historically this function performed its OWN instructions-domain render
    (via a junction-scope-filtered copy of instruction-map.json) and THEN
    called the lifecycle, rendering the instructions domain twice through two
    different code paths. That duplicate render is removed: this function is
    now a thin delegate retained for back compatibility, and new callers
    should use Set-SprintBoundaryContext (per-worktree provisioning) or
    Invoke-SprintAIAdapterLifecycle (adapter materialization only) directly.
  .PARAMETER TargetRoot
    The root path of the target sprint worktree to materialize into.
  .PARAMETER SharedVSCodeWorktreePath
    The path to the SharedVSCode sprint worktree containing the .ai source tree.
  .PARAMETER ManifestPath
    DEPRECATED (Task 12.2.b). Ignored: the lifecycle renders from the adapter
    registry, not a caller-supplied instruction-map manifest.
  .PARAMETER UpdateManifest
    DEPRECATED (Task 12.2.b). Ignored: manifest hash/state updates are not part
    of the consolidated lifecycle render.
  .PARAMETER SkipAIAdapterLifecycle
    Skip adapter materialization entirely and return a no-op result. With the
    single code path there is no separate "instructions render" left to run.
    Intended only for diagnostics and narrowly scoped repair workflows.
  .PARAMETER Force
    DEPRECATED (Task 12.2.b). Ignored: the lifecycle render manages overwrite
    behavior itself.
  .OUTPUTS
    PSCustomObject: the Invoke-SprintAIAdapterLifecycle result, with back-compat
    AdapterLifecycle / SettingsLifecycle members referencing the same result.
  .LINK
    Set-SprintBoundaryContext
  .LINK
    Invoke-SprintAIAdapterLifecycle
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [Parameter(Mandatory = $true)]
    [string]$TargetRoot,

    [Parameter(Mandatory = $true)]
    [string]$SharedVSCodeWorktreePath,

    [Parameter(Mandatory = $false)]
    [string]$ManifestPath,

    [switch]$UpdateManifest,

    [Alias('SkipAISettings')]
    [switch]$SkipAIAdapterLifecycle,

    [switch]$Force
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    # Normalize paths
    $TargetRoot = [System.IO.Path]::GetFullPath($TargetRoot)
    $SharedVSCodeWorktreePath = [System.IO.Path]::GetFullPath($SharedVSCodeWorktreePath)

    foreach ($deprecated in @('ManifestPath', 'UpdateManifest', 'Force')) {
      if ($PSBoundParameters.ContainsKey($deprecated)) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
          -Message "Parameter -$deprecated is deprecated and ignored: Initialize-SprintAIAdapters delegates to the single Invoke-SprintAIAdapterLifecycle code path (Task 12.2.b)."
      }
    }
  }

  process {
    if ($SkipAIAdapterLifecycle) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
        -Message "SkipAIAdapterLifecycle requested: no adapter materialization performed for $TargetRoot (single code path, Task 12.2.b)."
      return [PSCustomObject]@{
        Skipped           = $true
        TargetRoot        = $TargetRoot
        ChangedCount      = 0
        ErrorCount        = 0
        Results           = @()
        AdapterLifecycle  = $null
        SettingsLifecycle = $null
      }
    }

    if ($PSCmdlet.ShouldProcess($TargetRoot, 'Materialize AI adapters (delegated single lifecycle code path)')) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
        -Message "Delegating AI adapter materialization for $TargetRoot to Invoke-SprintAIAdapterLifecycle -Boundary Start"

      $adapterLifecycleResult = Invoke-SprintAIAdapterLifecycle `
        -Boundary Start `
        -TargetRoot $TargetRoot `
        -SharedVSCodeWorktreePath $SharedVSCodeWorktreePath `
        -Confirm:$false `
        -WhatIf:$WhatIfPreference

      $lifecycleResults = @(if ($adapterLifecycleResult.PSObject.Properties['Results']) { $adapterLifecycleResult.Results })
      $lifecycleErrorCount = @($lifecycleResults | Where-Object {
          $_ -and $_.PSObject.Properties['Action'] -and $_.Action -eq 'error'
        }).Count
      $lifecycleChangedCount = if ($adapterLifecycleResult.PSObject.Properties['ChangedCount']) {
        $adapterLifecycleResult.ChangedCount
      } else { 0 }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
        -Message "AI adapter materialization complete: changed $lifecycleChangedCount, errors $lifecycleErrorCount"

      $delegateResult = [PSCustomObject]@{
        Skipped           = $false
        TargetRoot        = $TargetRoot
        ChangedCount      = $lifecycleChangedCount
        ErrorCount        = $lifecycleErrorCount
        Results           = $lifecycleResults
        AdapterLifecycle  = $adapterLifecycleResult
        SettingsLifecycle = $adapterLifecycleResult
      }

      if ($lifecycleErrorCount -gt 0) {
        $failedTargets = $lifecycleResults |
          Where-Object { $_ -and $_.PSObject.Properties['Action'] -and $_.Action -eq 'error' } |
          ForEach-Object { "$($_.Path): $($_.Message)" }
        throw "Failed to materialize all AI adapters: $($failedTargets -join '; ')"
      }

      return $delegateResult
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn in module $mn"
  }
}
