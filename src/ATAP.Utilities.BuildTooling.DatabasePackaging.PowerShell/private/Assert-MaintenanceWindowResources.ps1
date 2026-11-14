function Assert-MaintenanceWindowResources {
  <#
  .SYNOPSIS
    Refuses unless every pinned LF maintenance resource file has exactly its pinned SHA-256.
  .DESCRIPTION
    .sql and .json resources cannot carry an Authenticode signature, so their hashes live in the
    signed Get-MaintenanceWindowResourcePins. The signature on that script carries the trust to them.
    Throws 'MaintenanceWindowResourceChanged|<relative path>' or 'MaintenanceWindowResourceMissing|<relative path>'.
  .PARAMETER ModuleRoot
    The module root; defaults to Get-MaintenanceWindowModuleRoot.
  .OUTPUTS
    Ordered dictionary of relative path to verified SHA-256.
  .EXAMPLE
    Assert-MaintenanceWindowResources
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines. DB-Runner-S1-Foundation.
  .LINK
    Get-MaintenanceWindowResourcePins
  #>
  [CmdletBinding()]
  param([string]$ModuleRoot)
  begin {
    $fn = 'Assert-MaintenanceWindowResources'
    $mn = 'ATAP.Utilities.BuildTooling.DatabasePackaging.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
  }
  process {
    if ([string]::IsNullOrWhiteSpace($ModuleRoot)) { $ModuleRoot = Get-MaintenanceWindowModuleRoot }
    $verified = [ordered]@{}
    $pins = Get-MaintenanceWindowResourcePins
    foreach ($relative in $pins.Keys) {
      $path = Join-Path $ModuleRoot $relative
      if (-not [IO.File]::Exists($path)) { throw "MaintenanceWindowResourceMissing|$relative" }
      $hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([IO.File]::ReadAllBytes($path)))
      if (-not [string]::Equals($hash, $pins[$relative], [StringComparison]::OrdinalIgnoreCase)) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Resource hash differs from its pin: $relative"
        throw "MaintenanceWindowResourceChanged|$relative"
      }
      $verified[$relative] = $hash
    }
    $verified
  }
  end {}
}
