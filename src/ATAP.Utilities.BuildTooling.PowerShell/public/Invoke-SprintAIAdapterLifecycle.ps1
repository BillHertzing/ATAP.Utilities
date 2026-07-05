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
    to their stable/closed-state form.
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

      $lifecycleCommand = Get-Command -Name Invoke-AIAdapterLifecycle -CommandType Function -ErrorAction Stop
      if ($OmitSprintWorktrees) {
        if ($lifecycleCommand.Parameters.ContainsKey('OmitSprintWorktrees')) {
          $parameters.OmitSprintWorktrees = $true
        } elseif ($Boundary -eq 'Start') {
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
          $renderResult = Render-AIAdapters `
            -RegistryPath $registryPath `
            -Domain $lifecycleDomains `
            -TargetRoot $TargetRoot `
            -BackupRoot (Join-Path $effectiveEvidenceRoot 'backups') `
            -FixtureMode:$FixtureMode `
            -AllowUserGlobalWrite:$AllowUserGlobalWrite `
            -OmitSprintWorktrees `
            -Force `
            -WhatIf:$WhatIfPreference `
            -Confirm:$false

          return [pscustomobject]@{
            Boundary = $Boundary
            Domain = $lifecycleDomains
            TargetRoot = $TargetRoot
            FixtureMode = [bool]$FixtureMode
            CallerOrder = $callerOrder
            Results = @($renderResult.Results)
            ChangedCount = $renderResult.ChangedCount
            SkippedUserScopeCount = $renderResult.SkippedUserScopeCount
            DriftClean = $true
            RenderResult = $renderResult
            DriftResult = $null
            OmitSprintWorktrees = $true
          }
        } else {
          throw '-OmitSprintWorktrees is only supported for render-style lifecycle calls.'
        }
      }

      return Invoke-AIAdapterLifecycle @parameters -WhatIf:$WhatIfPreference
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn in module $mn"
  }
}
