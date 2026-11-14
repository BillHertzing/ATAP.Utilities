function Get-MaintenanceWindowTierMap {
  <#
  .SYNOPSIS
    Returns the fixed, signed tier map that every LF maintenance window binding is checked against.
  .DESCRIPTION
    The binding supplies tier values; this table decides which values are allowed. It mirrors the
    LF release gate's own maps (DatabasePackageLFReleaseGate.ps1 lines 72-73: instance names and
    connection SecretNames) and adds the runner identity, the artifact root and the pinned
    Microsoft.Data.SqlClient assembly. Experimental is deliberately absent: the operator runs the
    Experimental window by hand from the reviewed packets.
    The runner identity is UTAT022\SvcBuildmaster; its SID is the one Junior Dev #2's grant packet
    pins (0x01050000000000051500000079DFF8272CF1F6998E5E7D6DEF030000).
    FlywayEnvironment follows Get-DatabaseTierEnvironment (Integration and QA map to 'Testing') until
    slice S0 releases Invoke-Flyway with the runtime tier names.
  .PARAMETER Tier
    One tier, or omit for the whole map.
  .OUTPUTS
    PSCustomObject (one tier) or an ordered dictionary of tier name to PSCustomObject.
  .EXAMPLE
    Get-MaintenanceWindowTierMap -Tier Production
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines. DB-Runner-S1-Foundation.
  .LINK
    Invoke-DatabaseMaintenanceWindow
  #>
  [CmdletBinding()]
  [OutputType([pscustomobject])]
  param(
    [ValidateSet('Development', 'Integration', 'QA', 'Production')]
    [string]$Tier
  )
  begin {
    $fn = 'Get-MaintenanceWindowTierMap'
    $mn = 'ATAP.Utilities.BuildTooling.DatabasePackaging.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
  }
  process {
    $common = [ordered]@{
      MachineName       = 'UTAT022'
      Catalog           = 'ATAPUtilities'
      RunnerLogin       = 'UTAT022\SvcBuildmaster'
      RunnerSid         = 'S-1-5-21-670621561-2583097644-1836932750-1007'
      ArtifactRoot      = 'D:\ATAPArtifacts\'
      SqlClientPath     = 'C:\Program Files\PowerShell\Modules\dbatools.library\2025.12.28\core\lib\Microsoft.Data.SqlClient.dll'
      SqlClientSha256   = 'FAFFA55E5DB0BF0503F31B54F65F5FB203412B77D1C38CE8AD0A0A45485DE90B'
      MaxWindowHours    = 6
    }
    $tiers = [ordered]@{
      Development = [ordered]@{ InstanceName = 'DEVWHERTZING'; SqlInstance = 'UTAT022\Devwhertzing'; ConnectionSecretName = 'dbConnectionString.ATAPUtilities.localhost.Dev.whertzing'; FlywayEnvironment = 'Development'; AllowedModes = @('PrecheckOnly', 'BackupOnly', 'Full', 'DropClone'); RequiresProductionPauseRecord = $false }
      Integration = [ordered]@{ InstanceName = 'INTEGRATION'; SqlInstance = 'UTAT022\Integration'; ConnectionSecretName = 'dbConnectionString.ATAPUtilities.localhost.Integration'; FlywayEnvironment = 'Testing'; AllowedModes = @('PrecheckOnly', 'BackupOnly', 'Full', 'DropClone'); RequiresProductionPauseRecord = $false }
      QA          = [ordered]@{ InstanceName = 'QA'; SqlInstance = 'UTAT022\QA'; ConnectionSecretName = 'dbConnectionString.ATAPUtilities.localhost.QA'; FlywayEnvironment = 'Testing'; AllowedModes = @('PrecheckOnly', 'BackupOnly', 'DropClone'); RequiresProductionPauseRecord = $false }
      Production  = [ordered]@{ InstanceName = 'PRODUCTION'; SqlInstance = 'UTAT022\Production'; ConnectionSecretName = 'dbConnectionString.ATAPUtilities.localhost.Production'; FlywayEnvironment = 'Production'; AllowedModes = @('PrecheckOnly', 'BackupOnly', 'Full', 'DropClone'); RequiresProductionPauseRecord = $true }
    }
    $build = {
      param($name)
      $entry = [ordered]@{ Tier = $name }
      foreach ($k in $common.Keys) { $entry[$k] = $common[$k] }
      foreach ($k in $tiers[$name].Keys) { $entry[$k] = $tiers[$name][$k] }
      [pscustomobject]$entry
    }
    if ($Tier) { return (& $build $Tier) }
    $all = [ordered]@{}
    foreach ($name in $tiers.Keys) { $all[$name] = & $build $name }
    $all
  }
  end {}
}
