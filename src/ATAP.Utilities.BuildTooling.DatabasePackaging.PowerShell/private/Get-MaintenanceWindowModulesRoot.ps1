function Get-MaintenanceWindowModulesRoot {
  <#
  .SYNOPSIS
    Returns the only AllUsers module root the LF maintenance runner trusts.
  .DESCRIPTION
    A constant, kept as a function so unit tests can mock it to a TestDrive root.
  .OUTPUTS
    System.String
  .EXAMPLE
    Get-MaintenanceWindowModulesRoot
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines. DB-Runner-S1-Foundation.
  .LINK
    Assert-MaintenanceWindowDependency
  #>
  [CmdletBinding()]
  [OutputType([string])]
  param()
  begin { $fn = 'Get-MaintenanceWindowModulesRoot'; $mn = 'ATAP.Utilities.BuildTooling.DatabasePackaging.PowerShell' }
  process { 'C:\Program Files\PowerShell\Modules' }
  end {}
}
