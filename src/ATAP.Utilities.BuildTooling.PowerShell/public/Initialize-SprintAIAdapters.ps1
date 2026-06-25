# Load contract: dot-source this file to define Initialize-SprintAIAdapters. No top-level
# code executes on load — all side effects occur only when the function is called.
function Initialize-SprintAIAdapters {
  <#
  .SYNOPSIS
    Wrapper to invoke Render-AIAdapters.ps1 to materialize manifest declared targets.
  .DESCRIPTION
    Dot-sources Render-AIAdapters.ps1 from the SharedVSCode worktree and invokes it
    to materialize instruction/configuration files into a target sprint worktree.
    After instruction adapter rendering, canonical project-scope settings and
    permissions are materialized through Invoke-SprintAIAdapterLifecycle.
  .PARAMETER TargetRoot
    The root path of the target sprint worktree to materialize into.
  .PARAMETER SharedVSCodeWorktreePath
    The path to the SharedVSCode sprint worktree containing the .ai source tree.
  .PARAMETER ManifestPath
    Optional path to the instruction-map manifest. Defaults to
    <SharedVSCodeWorktreePath>/.ai/manifests/instruction-map.json.
  .PARAMETER UpdateManifest
    Switch to update manifest hashes/states in the source manifest.
  .PARAMETER SkipAIAdapterLifecycle
    Skip canonical project-scope adapter lifecycle materialization. Intended only for
    diagnostics and narrowly scoped repair workflows.
  .PARAMETER Force
    Switch to force overwrite of existing target files or recreate links.
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

    if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
      $ManifestPath = Join-Path $SharedVSCodeWorktreePath '.ai/manifests/instruction-map.json'
    } else {
      $ManifestPath = [System.IO.Path]::GetFullPath($ManifestPath)
    }

    $renderScript = Join-Path $SharedVSCodeWorktreePath '.ai/tools/Render-AIAdapters.ps1'

    if (-not (Test-Path -LiteralPath $renderScript -PathType Leaf)) {
      throw "Render-AIAdapters.ps1 not found at expected path: $renderScript"
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
      -Message "Loading Render-AIAdapters script from $renderScript"
    # FSS-62: Dot-source Render-AIAdapters from the SharedVSCode worktree (not installed as module cmdlet).
    # This function is supplied as a tool script within each sprint worktree's .ai/tools/ folder.
    . $renderScript
  }

  process {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
      -Message "Materializing AI adapters from manifest $ManifestPath into $TargetRoot"

    # Load and filter manifest to enforce D-3 outside-junction scoping
    try {
      $manifestContent = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
      throw "Failed to parse manifest at $ManifestPath : $_"
    }

    # Create a filtered copy with only outside-junction targets
    $filteredManifest = $manifestContent | ConvertTo-Json -Depth 10 | ConvertFrom-Json
    $outsideJunctionCount = 0
    $filteredJunctionCount = 0

    foreach ($record in $filteredManifest.records) {
      $filteredTargets = @()
      foreach ($target in $record.targets) {
        # Null-safe scope read (Task 10.3.f): many manifest targets legitimately omit
        # 'scope', and a direct $target.scope member access throws PropertyNotFoundException
        # under Set-StrictMode -Version Latest (the original Sprint 0010 start defect).
        $scopeProperty = $target.PSObject.Properties['scope']
        $scopeValue = if ($scopeProperty) { $scopeProperty.Value } else { $null }
        if ($scopeValue -eq 'outside-junction' -or -not $scopeValue) {
          # Keep targets marked outside-junction; also keep unscoped targets for backwards compatibility
          $filteredTargets += $target
          $outsideJunctionCount++
        } else {
          $filteredJunctionCount++
          $pathProperty = $target.PSObject.Properties['path']
          $targetPath = if ($pathProperty) { $pathProperty.Value } else { '(unknown path)' }
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
            -Message "Filtering out junctioned target: $targetPath"
        }
      }
      $record.targets = $filteredTargets
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
      -Message "Materialization scope: keeping $outsideJunctionCount outside-junction targets, filtering $filteredJunctionCount junctioned targets"

    # Write the filtered manifest to a temporary file for Render-AIAdapters
    $tempManifestPath = Join-Path $SharedVSCodeWorktreePath ".ai/manifests/instruction-map-filtered-$(Get-Random).json"
    try {
      $filteredManifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $tempManifestPath -Encoding utf8

      $renderParams = @{
        ManifestPath   = $tempManifestPath
        TargetRoot     = $TargetRoot
        UpdateManifest = $false
        Force          = $Force
      }

      if ($PSCmdlet.ShouldProcess($TargetRoot, 'Materialize AI adapters')) {
        $renderResult = Render-AIAdapters @renderParams -WhatIf:$WhatIfPreference

        # Log result summary
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
          -Message "AI adapter materialization complete: changed $($renderResult.ChangedCount), errors $($renderResult.ErrorCount)"

        if ($renderResult.ErrorCount -gt 0) {
          $failedTargets = $renderResult.Results | Where-Object { $_.Action -eq 'error' } | ForEach-Object { "$($_.Path): $($_.Message)" }
          throw "Failed to materialize all AI adapters: $($failedTargets -join '; ')"
        }

        $adapterLifecycleResult = $null
        if (-not $SkipAIAdapterLifecycle -and $PSCmdlet.ShouldProcess($TargetRoot, 'Materialize canonical project AI adapters')) {
          $adapterLifecycleResult = Invoke-SprintAIAdapterLifecycle `
            -Boundary Start `
            -TargetRoot $TargetRoot `
            -SharedVSCodeWorktreePath $SharedVSCodeWorktreePath `
            -Confirm:$false
        }
        $renderResult | Add-Member -NotePropertyName AdapterLifecycle -NotePropertyValue $adapterLifecycleResult -Force
        $renderResult | Add-Member -NotePropertyName SettingsLifecycle -NotePropertyValue $adapterLifecycleResult -Force

        return $renderResult
      }
    } finally {
      # Clean up temporary manifest
      if (Test-Path -LiteralPath $tempManifestPath) {
        Remove-Item -LiteralPath $tempManifestPath -Force -ErrorAction SilentlyContinue
      }
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn in module $mn"
  }
}
