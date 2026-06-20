function Invoke-SprintAISettingsLifecycle {
  <#
  .SYNOPSIS
    Compatibility wrapper for Invoke-SprintAIAdapterLifecycle.
  .DESCRIPTION
    Preserves the Task 10.20 command name while forwarding to the registry-backed
    adapter lifecycle. This function contains no settings renderer or drift logic.
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

  process {
    $parameters = @{
      Boundary = $Boundary
      TargetRoot = $TargetRoot
      SharedVSCodeWorktreePath = $SharedVSCodeWorktreePath
      FixtureMode = $FixtureMode
      AllowUserGlobalWrite = $AllowUserGlobalWrite
      CheckpointConfirmed = $CheckpointConfirmed
      Confirm = $false
    }
    if (-not [string]::IsNullOrWhiteSpace($EvidenceRoot)) {
      $parameters.EvidenceRoot = $EvidenceRoot
    }

    if ($PSCmdlet.ShouldProcess($TargetRoot, "$Boundary AI adapter lifecycle compatibility call")) {
      return Invoke-SprintAIAdapterLifecycle @parameters -WhatIf:$WhatIfPreference
    }
  }
}
