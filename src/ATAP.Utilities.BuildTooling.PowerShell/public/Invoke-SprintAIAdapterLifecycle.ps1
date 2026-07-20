function Invoke-SprintAIAdapterLifecycle {
  <#
  .SYNOPSIS
    Invokes the SharedVSCode canonical AI adapter sprint lifecycle.
  .DESCRIPTION
    Loads Invoke-AIAdapterLifecycle.ps1 from the selected SharedVSCode stable
    or sprint worktree. SprintStart uses registry-scoped settings/permissions
    rendering; SprintEnd uses the matching adapter drift audit.
  .PARAMETER Boundary
    Start materializes canonical project adapters. End audits for retarget or
    promote/regenerate review.
  .PARAMETER TargetRoot
    Repository or isolated fixture root containing native caller targets.
  .PARAMETER SharedVSCodeWorktreePath
    SharedVSCode stable or sprint worktree containing the canonical .ai tree.
  .PARAMETER FixtureMode
    Redirects user-scope caller targets beneath TargetRoot for isolated tests.
  .PARAMETER AllowUserGlobalWrite
    Explicit approval required before live user/global targets can be written.
  .PARAMETER CheckpointConfirmed
    Confirms a checkpoint completed before live user/global replacement.
  .PARAMETER EvidenceRoot
    Optional _generated evidence and backup directory.
  .PARAMETER OmitSprintWorktrees
    For SprintEnd shared-settings renders, resolves sprint-worktree placeholders
    to their stable/closed-state form. This is a render-only recovery path: it
    performs two passes, requires the second pass to make zero changes, and
    writes a metadata-only user/global intent hash ledger beneath EvidenceRoot.
  .OUTPUTS
    PSCustomObject returned by Invoke-AIAdapterLifecycle.
  .EXAMPLE
    Invoke-SprintAIAdapterLifecycle -Boundary Start `
      -TargetRoot $worktreePath `
      -SharedVSCodeWorktreePath $sharedVSCodeSprintPath
  .LINK
    Initialize-SprintAIAdapters
  .LINK
    Set-SprintBoundaryContext
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [Parameter(Mandatory)]
    [ValidateSet('Start', 'End')]
    [string]$Boundary,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$TargetRoot,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$SharedVSCodeWorktreePath,

    [switch]$FixtureMode,

    [switch]$AllowUserGlobalWrite,

    [switch]$CheckpointConfirmed,

    [string]$EvidenceRoot,

    [switch]$OmitSprintWorktrees
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    $TargetRoot = [IO.Path]::GetFullPath($TargetRoot)
    $SharedVSCodeWorktreePath = [IO.Path]::GetFullPath($SharedVSCodeWorktreePath)
    if ($OmitSprintWorktrees -and $AllowUserGlobalWrite -and -not $FixtureMode -and -not $CheckpointConfirmed) {
      throw 'Live user/global stable-only adapter replacement requires -CheckpointConfirmed after a successful sprint checkpoint.'
    }
    $lifecycleScript = Join-Path $SharedVSCodeWorktreePath '.ai/tools/Invoke-AIAdapterLifecycle.ps1'
    $rendererPath = Join-Path $SharedVSCodeWorktreePath '.ai/tools/Render-AIAdapters.ps1'
    if (-not (Test-Path -LiteralPath $lifecycleScript -PathType Leaf)) {
      throw "Invoke-AIAdapterLifecycle.ps1 not found at expected path: $lifecycleScript"
    }

    . $lifecycleScript
  }

  process {
    if ($PSCmdlet.ShouldProcess($TargetRoot, "$Boundary AI adapter lifecycle")) {
      $parameters = @{
        Boundary = $Boundary
        TargetRoot = $TargetRoot
        SourceRoot = $SharedVSCodeWorktreePath
        FixtureMode = $FixtureMode
        AllowUserGlobalWrite = $AllowUserGlobalWrite
        CheckpointConfirmed = $CheckpointConfirmed
        Confirm = $false
      }
      if (-not [string]::IsNullOrWhiteSpace($EvidenceRoot)) {
        $parameters.EvidenceRoot = $EvidenceRoot
      }

      if ($OmitSprintWorktrees) {
        if ($Boundary -eq 'Start') {
          if (-not (Test-Path -LiteralPath $rendererPath -PathType Leaf)) {
            throw "Render-AIAdapters.ps1 not found at expected path: $rendererPath"
          }
          if (-not (Get-Command -Name Render-AIAdapters -CommandType Function -ErrorAction SilentlyContinue)) {
            . $rendererPath
          }
          $renderCommand = Get-Command -Name Render-AIAdapters -CommandType Function -ErrorAction Stop
          if (-not $renderCommand.Parameters.ContainsKey('OmitSprintWorktrees')) {
            throw 'Render-AIAdapters does not support -OmitSprintWorktrees in the selected SharedVSCode worktree.'
          }
          $registryPath = Join-Path $SharedVSCodeWorktreePath '.ai/manifests/adapter-registry.json'
          $lifecycleDomains = @(
            'instructions',
            'settings',
            'permissions',
            'hooks',
            'toolsets'
          )
          $callerOrder = @('AntigravityCli', 'AntigravityApp', 'Codex', 'ClaudeCode', 'Copilot')
          $effectiveEvidenceRoot = if ([string]::IsNullOrWhiteSpace($EvidenceRoot)) {
            Join-Path $TargetRoot '_generated/AIAdapterLifecycle'
          } else {
            [IO.Path]::GetFullPath($EvidenceRoot)
          }
          $renderParameters = @{
            RegistryPath = $registryPath
            Domain = $lifecycleDomains
            TargetRoot = $TargetRoot
            BackupRoot = Join-Path $effectiveEvidenceRoot 'backups'
            FixtureMode = $FixtureMode
            AllowUserGlobalWrite = $AllowUserGlobalWrite
            OmitSprintWorktrees = $true
            Force = $true
            Confirm = $false
            WhatIf = $WhatIfPreference
          }
          $firstRenderResult = Render-AIAdapters @renderParameters
          $secondRenderResult = Render-AIAdapters @renderParameters

          $secondPassErrorCount = if ($secondRenderResult.PSObject.Properties['ErrorCount']) {
            [int]$secondRenderResult.ErrorCount
          } else {
            @($secondRenderResult.Results | Where-Object Action -EQ 'error').Count
          }
          $secondPassWouldBeClean = if ($secondRenderResult.PSObject.Properties['SecondRunWouldBeClean']) {
            [bool]$secondRenderResult.SecondRunWouldBeClean
          } else {
            $secondPassErrorCount -eq 0
          }
          if ([int]$secondRenderResult.ChangedCount -ne 0 -or $secondPassErrorCount -ne 0 -or -not $secondPassWouldBeClean) {
            throw "Stable-only AI adapter render was not idempotent: second pass changed $($secondRenderResult.ChangedCount) target(s) and reported $secondPassErrorCount error(s)."
          }

          $userGlobalIntent = @(
            foreach ($firstRow in @($firstRenderResult.Results | Where-Object { $_.PSObject.Properties['Scope'] -and $_.Scope -in @('user', 'managed') })) {
              $matchingSecondRow = @(
                $secondRenderResult.Results |
                  Where-Object { $_.Tool -eq $firstRow.Tool -and $_.Path -eq $firstRow.Path -and $_.Scope -eq $firstRow.Scope }
              ) | Select-Object -First 1
              [pscustomobject]@{
                Tool = $firstRow.Tool
                Path = $firstRow.Path
                Scope = $firstRow.Scope
                FirstAction = $firstRow.Action
                FirstSha256 = $firstRow.Sha256
                SecondAction = if ($matchingSecondRow) { $matchingSecondRow.Action } else { $null }
                SecondSha256 = if ($matchingSecondRow) { $matchingSecondRow.Sha256 } else { $null }
              }
            }
          )
          $intentLedgerPath = Join-Path $effectiveEvidenceRoot 'StableRender-UserGlobalIntent.json'
          if (-not $WhatIfPreference) {
            [IO.Directory]::CreateDirectory($effectiveEvidenceRoot) | Out-Null
            $intentLedger = [ordered]@{
              SchemaVersion = 1
              TargetRoot = $TargetRoot
              SourceRoot = $SharedVSCodeWorktreePath
              OmitSprintWorktrees = $true
              AllowUserGlobalWrite = [bool]$AllowUserGlobalWrite
              CheckpointConfirmed = [bool]$CheckpointConfirmed
              FirstPassChangedCount = [int]$firstRenderResult.ChangedCount
              SecondPassChangedCount = [int]$secondRenderResult.ChangedCount
              UserGlobalIntent = $userGlobalIntent
            }
            [IO.File]::WriteAllText(
              $intentLedgerPath,
              (($intentLedger | ConvertTo-Json -Depth 20) + [Environment]::NewLine),
              [Text.UTF8Encoding]::new($false))
          }

          return [pscustomobject]@{
            Boundary = $Boundary
            Domain = $lifecycleDomains
            TargetRoot = $TargetRoot
            FixtureMode = [bool]$FixtureMode
            CallerOrder = $callerOrder
            Results = @($firstRenderResult.Results)
            ChangedCount = $firstRenderResult.ChangedCount
            SkippedUserScopeCount = $firstRenderResult.SkippedUserScopeCount
            DriftClean = $true
            RenderResult = $firstRenderResult
            FirstRenderResult = $firstRenderResult
            SecondRenderResult = $secondRenderResult
            SecondPassChangedCount = [int]$secondRenderResult.ChangedCount
            Idempotent = $true
            UserGlobalIntent = $userGlobalIntent
            UserGlobalIntentLedgerPath = if ($WhatIfPreference) { $null } else { $intentLedgerPath }
            DriftResult = $null
            OmitSprintWorktrees = $true
          }
        } else {
          throw '-OmitSprintWorktrees is only supported for render-style lifecycle calls.'
        }
      }

      $lifecycleCommand = Get-Command -Name Invoke-AIAdapterLifecycle -CommandType Function -ErrorAction Stop
      return Invoke-AIAdapterLifecycle @parameters -WhatIf:$WhatIfPreference
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn in module $mn"
  }
}
