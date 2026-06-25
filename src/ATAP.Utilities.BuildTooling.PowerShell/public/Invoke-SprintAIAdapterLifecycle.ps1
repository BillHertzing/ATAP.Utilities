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

    [string]$EvidenceRoot
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    $TargetRoot = [IO.Path]::GetFullPath($TargetRoot)
    $SharedVSCodeWorktreePath = [IO.Path]::GetFullPath($SharedVSCodeWorktreePath)
    $lifecycleScript = Join-Path $SharedVSCodeWorktreePath '.ai/tools/Invoke-AIAdapterLifecycle.ps1'
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

      return Invoke-AIAdapterLifecycle @parameters -WhatIf:$WhatIfPreference
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn in module $mn"
  }
}
