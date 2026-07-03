function Invoke-SprintEndOverviewClose {
  <#
  .SYNOPSIS
  Updates the parent Overview workspace and archives the closing sprint workspace.

  .DESCRIPTION
  Requires the closing sprint Overview workspace at the Git root, invokes
  Update-OverviewWorkspaceStableInfo with its real RootWorkspacePath contract,
  then archives the sprint workspace beneath the active planning worktree.

  .PARAMETER GitRoot
  Parent directory containing Overview.code-workspace and the sprint workspace.

  .PARAMETER PlanningRoot
  Active planning sprint worktree that receives the workspace archive.

  .PARAMETER SprintNumber
  Closing sprint number.

  .OUTPUTS
  PSCustomObject containing update and archive results.

  .NOTES
  AI assisted using Powershell.instructions.md as guidelines.
  #>
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$GitRoot,

    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$PlanningRoot,

    [Parameter(Mandatory)]
    [ValidateRange(1, 9999)]
    [int]$SprintNumber
  )

  begin {
    $fn = 'Invoke-SprintEndOverviewClose'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
  }

  process {
    $gitRootFull = [IO.Path]::GetFullPath($GitRoot)
    $planningRootFull = [IO.Path]::GetFullPath($PlanningRoot)
    $sprintText = '{0:D4}' -f $SprintNumber
    $sourceWorkspaceCandidates = @(
      (Join-Path $gitRootFull "Overview.Sprint$sprintText.code-workspace"),
      (Join-Path $gitRootFull "OverviewSprint$sprintText.code-workspace"),
      (Join-Path $gitRootFull "OverViewSprint$sprintText.code-workspace")
    )
    $sourceWorkspacePath = @(
      $sourceWorkspaceCandidates |
        Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }
    ) | Select-Object -First 1
    if (-not (Test-Path -LiteralPath $sourceWorkspacePath -PathType Leaf)) {
      throw "Required closing-sprint workspace does not exist. Tried: $($sourceWorkspaceCandidates -join ', ')."
    }

    $preferredRoot = Join-Path $gitRootFull 'Overview.code-workspace'
    $legacyRoot = Join-Path $gitRootFull 'OverView.code-workspace'
    $rootWorkspacePath = if (Test-Path -LiteralPath $preferredRoot -PathType Leaf) {
      $preferredRoot
    } elseif (Test-Path -LiteralPath $legacyRoot -PathType Leaf) {
      $legacyRoot
    } else {
      $preferredRoot
    }
    $archiveDirectory = Join-Path $planningRootFull 'SprintRetrospective\WorkspaceArchive'

    $updateParameters = @{
      GitRoot             = $gitRootFull
      RootWorkspacePath   = $rootWorkspacePath
      SourceWorkspacePath = $sourceWorkspacePath
      Confirm             = $false
    }
    if ($WhatIfPreference) { $updateParameters.WhatIf = $true }
    $update = Update-OverviewWorkspaceStableInfo @updateParameters

    $archiveParameters = @{
      SprintNumber        = $SprintNumber
      GitRoot             = $gitRootFull
      SourceWorkspacePath = $sourceWorkspacePath
      ArchiveDirectoryPath = $archiveDirectory
      Confirm             = $false
    }
    if ($WhatIfPreference) { $archiveParameters.WhatIf = $true }
    $archive = Remove-OverviewSprintWorkspace @archiveParameters

    return [PSCustomObject]@{
      Ok                      = (@($update.errors).Count -eq 0)
      SprintNumber            = $sprintText
      RootWorkspacePath       = $rootWorkspacePath
      SourceWorkspacePath     = $sourceWorkspacePath
      ArchiveDirectoryPath    = $archiveDirectory
      Update                  = $update
      Archive                 = $archive
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
