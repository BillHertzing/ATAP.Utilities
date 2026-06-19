function Invoke-SprintAISettingsLifecycle {
  <#
  .SYNOPSIS
    Invokes the SharedVSCode canonical AI settings sprint lifecycle.
  .DESCRIPTION
    Loads Invoke-AISettingsLifecycle.ps1 from the selected SharedVSCode stable
    or sprint worktree and forwards a Start materialization or End drift audit.
    The canonical tool defaults to project-scope targets; user/global writes
    remain opt-in and are never enabled by SprintStart automatically.
  .PARAMETER Boundary
    Start materializes canonical project settings. End audits for retarget or
    promote/regenerate review.
  .PARAMETER TargetRoot
    Repository or isolated fixture root containing native caller targets.
  .PARAMETER SharedVSCodeWorktreePath
    SharedVSCode stable or sprint worktree containing the canonical .ai tree.
  .PARAMETER FixtureMode
    Redirects user-scope caller targets beneath TargetRoot for isolated tests.
  .PARAMETER AllowUserGlobalWrite
    Explicit approval required before live user/global targets can be written.
  .PARAMETER EvidenceRoot
    Optional _generated evidence and backup directory.
  .OUTPUTS
    PSCustomObject returned by Invoke-AISettingsLifecycle.
  .EXAMPLE
    Invoke-SprintAISettingsLifecycle -Boundary Start `
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

    [string]$EvidenceRoot
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    $TargetRoot = [IO.Path]::GetFullPath($TargetRoot)
    $SharedVSCodeWorktreePath = [IO.Path]::GetFullPath($SharedVSCodeWorktreePath)
    $lifecycleScript = Join-Path $SharedVSCodeWorktreePath '.ai/tools/Invoke-AISettingsLifecycle.ps1'
    if (-not (Test-Path -LiteralPath $lifecycleScript -PathType Leaf)) {
      throw "Invoke-AISettingsLifecycle.ps1 not found at expected path: $lifecycleScript"
    }

    . $lifecycleScript
  }

  process {
    if ($PSCmdlet.ShouldProcess($TargetRoot, "$Boundary AI settings lifecycle")) {
      $parameters = @{
        Boundary = $Boundary
        TargetRoot = $TargetRoot
        SourceRoot = $SharedVSCodeWorktreePath
        FixtureMode = $FixtureMode
        AllowUserGlobalWrite = $AllowUserGlobalWrite
        Confirm = $false
      }
      if (-not [string]::IsNullOrWhiteSpace($EvidenceRoot)) {
        $parameters.EvidenceRoot = $EvidenceRoot
      }

      return Invoke-AISettingsLifecycle @parameters -WhatIf:$WhatIfPreference
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn in module $mn"
  }
}