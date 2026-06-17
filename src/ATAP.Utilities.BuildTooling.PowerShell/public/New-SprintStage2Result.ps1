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
    Any error that occurred during claude-settings.json symlink creation.
  .PARAMETER UserSettingsLinked
    Specifies if the VS Code user settings symlink was successfully retargeted.
  .PARAMETER UserSettingsError
    Any error that occurred during UserSettings.jsonc symlink creation.
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
  .OUTPUTS
    [PSCustomObject]
  .NOTES
    Part of the SprintStartAgent repair.
  #>
  [CmdletBinding()]
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
    [array]$BuildMasterVariablesSet = @(),

    [Parameter(Mandatory=$false)]
    [array]$BuildMasterVariablesErrors = @(),

    [Parameter(Mandatory=$false)]
    [string]$BuildMasterError,

    [Parameter(Mandatory=$false)]
    [array]$DatabaseResets = @(),

    [Parameter(Mandatory=$false)]
    [string]$DatabaseResetError
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
        buildMasterVariablesSet    = $BuildMasterVariablesSet
        buildMasterVariablesErrors = $BuildMasterVariablesErrors
        buildMasterVariablesError  = $BuildMasterError
        databaseResets             = $DatabaseResets
        databaseResetError         = $DatabaseResetError
      }
    }
    return $finalResult
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn in module $mn"
  }
}
