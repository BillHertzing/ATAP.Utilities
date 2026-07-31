function Test-SprintEndCommandSurface {
  <#
  .SYNOPSIS
  Validates the PowerShell command and parameter contracts used by SprintEnd.

  .DESCRIPTION
  Replaces ad hoc command probing and parameter guessing with one compact,
  structured result. Missing commands and missing parameters are reported once.

  .PARAMETER CommandContracts
  Hashtable mapping command names to required parameter-name arrays.

  .PARAMETER ThrowOnFailure
  Throws when any command contract is unavailable.

  .OUTPUTS
  PSCustomObject containing Ok, Commands, and Failures.

  .EXAMPLE
  Test-SprintEndCommandSurface -ThrowOnFailure

  .NOTES
  AI assisted using Powershell.instructions.md as guidelines.
  #>
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter()]
    [hashtable]$CommandContracts = @{
      'Get-SprintEndContext'                = @('GitRoot', 'CurrentPath')
      'Test-SprintPrerequisites'            = @('RequiredRepoWorktrees', 'BuiltModule')
      'Test-SprintInfrastructureHealth'     = @('BuildMasterAdminApiKeySecretName')
      'Set-SprintBoundaryContext'           = @('Boundary', 'SharedVSCodeWorktreePath', 'WorktreePaths', 'ProfiledRemotingPolicy')
      'Reset-DownstreamToSharedVSCodeMain'  = @('WorkspaceFiles')
      'Assert-MainBranchTemplateRef'        = @('WorkspaceFiles')
      'Update-OverviewWorkspaceStableInfo'  = @('RootWorkspacePath', 'SourceWorkspacePath')
      'Remove-OverviewSprintWorkspace'      = @('SprintNumber')
      'Invoke-SprintEndOverviewClose'       = @('GitRoot', 'PlanningRoot', 'SprintNumber')
      'Test-SprintEndPullOverlap'            = @('RepoPath', 'Fetch', 'ThrowOnOverlap')
      'Remove-SprintDatabases'              = @('DeveloperNames')
      'Clear-BuildMasterSprintVariables'    = @()
      'Save-SprintWorkSession'              = @('Agent', 'SprintN', 'PlanningRoot')
      'Save-SprintEndSessionTail'           = @('PlanningRoot', 'SprintNumber', 'Agent')
      'Test-SprintCheckpointCoverage'       = @('PlanningRoot', 'SprintNumber', 'WorktreePaths')
      'Restore-SprintHistoryArtifacts'      = @('PlanningRoot', 'SprintNumber', 'SourceRef', 'SourcePath')
    },

    [Parameter()]
    [switch]$ThrowOnFailure
  )

  begin {
    $fn = 'Test-SprintEndCommandSurface'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
  }

  process {
    $results = [System.Collections.Generic.List[object]]::new()
    $failures = [System.Collections.Generic.List[string]]::new()

    foreach ($commandName in @($CommandContracts.Keys | Sort-Object)) {
      $command = Get-Command -Name $commandName -ErrorAction SilentlyContinue | Select-Object -First 1
      $requiredParameters = @($CommandContracts[$commandName])
      $missingParameters = if ($command) {
        @($requiredParameters | Where-Object { -not $command.Parameters.ContainsKey($_) })
      } else {
        @($requiredParameters)
      }
      $ok = ($null -ne $command -and $missingParameters.Count -eq 0)
      $detail = if (-not $command) {
        'Command not found.'
      } elseif ($missingParameters.Count -gt 0) {
        "Missing parameter(s): $($missingParameters -join ', ')"
      } else {
        'Contract available.'
      }

      if (-not $ok) {
        [void]$failures.Add("${commandName}: $detail")
      }
      [void]$results.Add([PSCustomObject]@{
          Name              = $commandName
          Found             = ($null -ne $command)
          RequiredParameters = $requiredParameters
          MissingParameters = $missingParameters
          Ok                = $ok
          Detail            = $detail
        })
    }

    $result = [PSCustomObject]@{
      Ok       = ($failures.Count -eq 0)
      Commands = $results.ToArray()
      Failures = $failures.ToArray()
    }
    if (-not $result.Ok -and $ThrowOnFailure) {
      throw "SprintEnd command surface validation failed: $($result.Failures -join '; ')"
    }
    return $result
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
