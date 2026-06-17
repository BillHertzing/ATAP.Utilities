# Load contract: dot-source this file to define Initialize-SprintAIAdapters. No top-level
# code executes on load — all side effects occur only when the function is called.
function Initialize-SprintAIAdapters {
  <#
  .SYNOPSIS
    Wrapper to invoke Render-AIAdapters.ps1 to materialize manifest declared targets.
  .DESCRIPTION
    Dot-sources Render-AIAdapters.ps1 from the SharedVSCode worktree and invokes it
    to materialize instruction/configuration files into a target sprint worktree.
  .PARAMETER TargetRoot
    The root path of the target sprint worktree to materialize into.
  .PARAMETER SharedVSCodeWorktreePath
    The path to the SharedVSCode sprint worktree containing the .ai source tree.
  .PARAMETER ManifestPath
    Optional path to the instruction-map manifest. Defaults to
    <SharedVSCodeWorktreePath>/.ai/manifests/instruction-map.json.
  .PARAMETER UpdateManifest
    Switch to update manifest hashes/states in the source manifest.
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
    . $renderScript
  }

  process {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
      -Message "Materializing AI adapters from manifest $ManifestPath into $TargetRoot"

    $renderParams = @{
      ManifestPath   = $ManifestPath
      TargetRoot     = $TargetRoot
      UpdateManifest = $UpdateManifest
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

      return $renderResult
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn in module $mn"
  }
}
