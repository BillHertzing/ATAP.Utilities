function Invoke-SprintEndInfrastructureCleanup {
  <#
  .SYNOPSIS
  Runs the safe SprintEnd infrastructure teardown sequence.

  .DESCRIPTION
  Performs the infrastructure health check, drops only per-sprint databases,
  clears BuildMaster sprint variables, and reasserts stable boundary settings.
  SQL Server instances are permanent developer infrastructure and are retained.
  This cmdlet never calls Remove-SprintBitwardenSecrets or any SQL-instance
  removal command.

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
    # SC-0288 / Task 13.66.b: the SecretName host suffix is derived from the service placement
    # host, never hard-coded. Resolution order is the authoritative host setting,
    # then the placement map; an unknown placement host fails closed.
    if (-not $PSBoundParameters.ContainsKey('BuildMasterAdminApiKeySecretName')) {
      if (-not (Get-Command -Name 'Resolve-HostSuffixedSecretName' -ErrorAction SilentlyContinue)) {
        . (Join-Path $PSScriptRoot '..' '..' 'ATAP.Utilities.BuildTooling.Common.PowerShell' 'public' 'Resolve-HostSuffixedSecretName.ps1')
      }
      $BuildMasterAdminApiKeySecretName = Resolve-HostSuffixedSecretName `
        -BaseName $BuildMasterAdminApiKeySecretName -ServiceName 'BuildMaster' -SettingName 'BuildMasterAdminApiKeySecretName'
    }

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
      DatabaseCleanupMode        = 'SprintDatabasesOnly'
      BuildMasterResult          = $buildMasterResult
      BoundaryResult             = $boundaryResult
      BitwardenSecretsRemoved    = $false
      SqlInstancesRetained       = $true
      Actions                    = $actions.ToArray()
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
