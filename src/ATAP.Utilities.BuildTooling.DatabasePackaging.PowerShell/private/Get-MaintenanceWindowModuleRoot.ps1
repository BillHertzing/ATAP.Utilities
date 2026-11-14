function Get-MaintenanceWindowModuleRoot {
  <#
  .SYNOPSIS
    Returns the DatabasePackaging module root that holds Resources\MaintenanceWindow and schemas.
  .DESCRIPTION
    Prefers the loaded module's ModuleBase. When the private file is dot-sourced from source, falls
    back to the parent of private\. The built module inlines this file into the psm1, so there
    $PSScriptRoot is already the module root.
  .OUTPUTS
    System.String
  .EXAMPLE
    Get-MaintenanceWindowModuleRoot
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines. DB-Runner-S1-Foundation.
  .LINK
    Get-MaintenanceWindowResourcePins
  #>
  [CmdletBinding()]
  [OutputType([string])]
  param()
  begin {
    $fn = 'Get-MaintenanceWindowModuleRoot'
    $mn = 'ATAP.Utilities.BuildTooling.DatabasePackaging.PowerShell'
  }
  process {
    $module = $MyInvocation.MyCommand.Module
    if ($module -and -not [string]::IsNullOrWhiteSpace($module.ModuleBase)) { return [IO.Path]::GetFullPath($module.ModuleBase) }
    $leaf = Split-Path -Path $PSScriptRoot -Leaf
    if ($leaf -ieq 'private' -or $leaf -ieq 'public') { return [IO.Path]::GetFullPath((Split-Path -Path $PSScriptRoot -Parent)) }
    [IO.Path]::GetFullPath($PSScriptRoot)
  }
  end {}
}
