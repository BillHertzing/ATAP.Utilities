function New-SprintStage2Result {
  <#
  .SYNOPSIS
    Builds the structured Stage 2 return object.
  .DESCRIPTION
    Builds the structured PSCustomObject representing the Stage 2 results, keeping
    it consistent in exactly one place.
  .PARAMETER DryRun
    Specifies if this was a dry run.
  .PARAMETER RepoResults
    Array of repository results.
  .PARAMETER ClaudeSettingsError
    Any error that occurred during Claude Code user settings render.
  .PARAMETER UserSettingsLinked
    Specifies if the VS Code user settings symlink was successfully retargeted.
  .PARAMETER UserSettingsError
    Any error that occurred during UserSettings.jsonc symlink creation.
  .PARAMETER ProfileSymlinksRetargeted
    True when the machine-wide PowerShell 7 profile payload was deployed and
    HostSettings.ps1 was successfully retargeted to the sprint worktree.
  .PARAMETER ProfileSymlinkError
    Any error that occurred while deploying the profile or retargeting HostSettings.
  .PARAMETER BuildMasterVariablesSet
    Array of BuildMaster variable names that were successfully set.
  .PARAMETER BuildMasterVariablesErrors
    Array of BuildMaster errors.
  .PARAMETER BuildMasterError
    Any error that occurred during BuildMaster variable setup.
  .PARAMETER DatabaseResets
    Array of database reset results.
  .PARAMETER DatabaseResetError
    Any error that occurred during database resets.
  .PARAMETER OverviewWorkspacePath
    Path to the generated Overview.Sprint.NNNN.code-workspace file (Task 10.14.a).
  .PARAMETER OverviewWorkspaceVerified
    True when the Overview sprint workspace was generated and the verification
    gate confirmed it exists and resolves at least one sprint worktree folder.
  .PARAMETER OverviewWorkspaceError
    Any error that occurred while generating or verifying the Overview sprint
    workspace.
  .PARAMETER AIInstructionsResult
    Aggregate returned by Build-AIInstructionsPerRepository.
  .PARAMETER AIInstructionsError
    Any error that prevented or failed the single AI-instruction distribution
    step.
  .OUTPUTS
    [PSCustomObject]
  .NOTES
    Part of the SprintStartAgent repair.
  #>
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory=$false)]
    [switch]$DryRun,

    [Parameter(Mandatory=$false)]
    [array]$RepoResults = @(),

    [Parameter(Mandatory=$false)]
    [string]$ClaudeSettingsError,

    [Parameter(Mandatory=$false)]
    [bool]$UserSettingsLinked = $false,

    [Parameter(Mandatory=$false)]
    [string]$UserSettingsError,

    [Parameter(Mandatory=$false)]
    [bool]$ProfileSymlinksRetargeted = $false,

    [Parameter(Mandatory=$false)]
    [string]$ProfileSymlinkError,

    [Parameter(Mandatory=$false)]
    [array]$BuildMasterVariablesSet = @(),

    [Parameter(Mandatory=$false)]
    [array]$BuildMasterVariablesErrors = @(),

    [Parameter(Mandatory=$false)]
    [string]$BuildMasterError,

    [Parameter(Mandatory=$false)]
    [array]$DatabaseResets = @(),

    [Parameter(Mandatory=$false)]
    [string]$DatabaseResetError,

    [Parameter(Mandatory=$false)]
    [string]$OverviewWorkspacePath,

    [Parameter(Mandatory=$false)]
    [bool]$OverviewWorkspaceVerified = $false,

    [Parameter(Mandatory=$false)]
    [string]$OverviewWorkspaceError,

    [Parameter(Mandatory=$false)]
    [PSCustomObject]$AIInstructionsResult,

    [Parameter(Mandatory=$false)]
    [string]$AIInstructionsError
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn in module $mn"
  }

  process {
    $finalResult = [PSCustomObject]@{
      dryRun         = $DryRun.IsPresent
      repoResults    = $RepoResults
      infrastructure = [PSCustomObject]@{
        claudeSettingsError        = $ClaudeSettingsError
        userSettingsLinked         = $UserSettingsLinked
        userSettingsError          = $UserSettingsError
        profileSymlinksRetargeted  = $ProfileSymlinksRetargeted
        profileSymlinkError        = $ProfileSymlinkError
        buildMasterVariablesSet    = $BuildMasterVariablesSet
        buildMasterVariablesErrors = $BuildMasterVariablesErrors
        buildMasterVariablesError  = $BuildMasterError
        databaseResets             = $DatabaseResets
        databaseResetError         = $DatabaseResetError
        overviewWorkspacePath      = $OverviewWorkspacePath
        overviewWorkspaceVerified  = $OverviewWorkspaceVerified
        overviewWorkspaceError     = $OverviewWorkspaceError
        aiInstructions             = $AIInstructionsResult
        aiInstructionsError        = $AIInstructionsError
      }
    }
    return $finalResult
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn in module $mn"
  }
}
