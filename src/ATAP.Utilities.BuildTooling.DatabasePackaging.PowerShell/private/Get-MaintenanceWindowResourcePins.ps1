function Get-MaintenanceWindowResourcePins {
  <#
  .SYNOPSIS
    Returns the SHA-256 pin of every LF maintenance resource that cannot carry its own signature.
  .DESCRIPTION
    This script is Authenticode-signed with the module; that signature carries the trust to the .sql
    and .json files listed here. Assert-MaintenanceWindowResources refuses any file whose bytes differ.
    Update a pin only together with the reviewed change to its file (the unit tests fail otherwise).
  .OUTPUTS
    Ordered dictionary of module-relative path to upper-case SHA-256.
  .EXAMPLE
    Get-MaintenanceWindowResourcePins
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines. DB-Runner-S1-Foundation.
  .LINK
    Assert-MaintenanceWindowResources
  #>
  [CmdletBinding()]
  param()
  begin { $fn = 'Get-MaintenanceWindowResourcePins'; $mn = 'ATAP.Utilities.BuildTooling.DatabasePackaging.PowerShell' }
  process {
    [ordered]@{
      'Resources\MaintenanceWindow\WindowPrecheck.sql'             = '88D9D6ECE0B6D632A3D876F81CB66EECE2EA93E116D495E9AD1421DF927188A7'
      'schemas\database-maintenance-binding-v1.schema.json'        = 'B3EB31652860627DC047EB6F1B110059B0502EBC3181C2AB07D1985D9227D2C6'
    }
  }
  end {}
}
