function Invoke-SprintEndInfrastructureCleanup {
  <#
  .SYNOPSIS
  Runs the safe SprintEnd infrastructure teardown sequence.

  .DESCRIPTION
  Performs the infrastructure health check, drops only per-sprint databases,
  clears BuildMaster sprint variables, and reasserts stable boundary settings.
  This cmdlet never calls Remove-SprintBitwardenSecrets and never removes SQL
  Server instances.

  .PARAMETER GitRoot
  Parent directory containing stable repositories.

  .PARAMETER DeveloperNames
  Developer suffixes whose Dev/Exp databases are removed.

  .PARAMETER Apply
  Executes cleanup. Without Apply, only the read-only health check runs.

  .OUTPUTS
  PSCustomObject with health, database, BuildMaster, and boundary results.

  .EXAMPLE
  Invoke-SprintEndInfrastructureCleanup -GitRoot C:\Repos -WhatIf

  .NOTES
  AI assisted using Powershell.instructions.md as guidelines.
  #>
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$GitRoot,

    [Parameter()]
    [string[]]$DeveloperNames = @($env:USERNAME),

    [Parameter()]
    [string]$BuildMasterAdminApiKeySecretName = 'BuildMaster.Admin.API.Key',

    [Parameter()]
    [switch]$Apply
  )

  begin {
    $fn = 'Invoke-SprintEndInfrastructureCleanup'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
  }

  process {
    $health = Test-SprintInfrastructureHealth `
      -BuildMasterAdminApiKeySecretName $BuildMasterAdminApiKeySecretName
    $databaseResults = @()
    $buildMasterResult = $null
    $boundaryResult = $null
    $actions = [System.Collections.Generic.List[string]]::new()

    if ($Apply) {
      if (-not $health.AllOk) {
        throw "Sprint infrastructure health failed: $($health.Failures -join ', ')."
      }
      if ($PSCmdlet.ShouldProcess(($DeveloperNames -join ', '), 'Drop sprint databases only')) {
        $databaseResults = @(Remove-SprintDatabases `
            -DeveloperNames $DeveloperNames -Force -Confirm:$false)
        [void]$actions.Add('Removed per-sprint databases.')
      }
      if ($PSCmdlet.ShouldProcess('BuildMaster applications', 'Clear sprint variables')) {
        $buildMasterResult = Clear-BuildMasterSprintVariables -Confirm:$false
        [void]$actions.Add('Cleared BuildMaster sprint variables.')
      }
      $stableSharedVSCode = Join-Path ([IO.Path]::GetFullPath($GitRoot)) 'SharedVSCode'
      if ($PSCmdlet.ShouldProcess($stableSharedVSCode, 'Reassert stable SprintEnd boundary')) {
        $boundaryResult = Set-SprintBoundaryContext `
          -Boundary End `
          -SharedVSCodeWorktreePath $stableSharedVSCode `
          -WorktreePaths @() `
          -Confirm:$false
        [void]$actions.Add('Reasserted stable boundary.')
      }
    }

    return [PSCustomObject]@{
      Ok                         = ($health.AllOk -and (-not $Apply -or $null -ne $buildMasterResult))
      Applied                    = [bool]$Apply
      Health                     = $health
      DatabaseResults            = $databaseResults
      BuildMasterResult          = $buildMasterResult
      BoundaryResult             = $boundaryResult
      BitwardenSecretsRemoved    = $false
      SqlInstancesRemoved        = $false
      Actions                    = $actions.ToArray()
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
