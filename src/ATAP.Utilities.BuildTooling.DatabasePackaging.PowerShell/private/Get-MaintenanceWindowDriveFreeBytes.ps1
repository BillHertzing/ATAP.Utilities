function Get-MaintenanceWindowDriveFreeBytes {
  <#
  .SYNOPSIS
    Returns the available free bytes of the local drive that holds a path.
  .DESCRIPTION
    Read-only (System.IO.DriveInfo). Kept as a function so unit tests can mock it.
  .PARAMETER Path
    A fully qualified local path; only its root is used.
  .OUTPUTS
    System.Int64
  .EXAMPLE
    Get-MaintenanceWindowDriveFreeBytes -Path 'D:\ATAPArtifacts\x.bak'
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines. DB-Runner-S1-Foundation.
  .LINK
    Test-MaintenanceWindowPrecheckResult
  #>
  [CmdletBinding()]
  [OutputType([long])]
  param([Parameter(Mandatory)][string]$Path)
  begin { $fn = 'Get-MaintenanceWindowDriveFreeBytes'; $mn = 'ATAP.Utilities.BuildTooling.DatabasePackaging.PowerShell' }
  process { [long]([IO.DriveInfo]::new([IO.Path]::GetPathRoot([IO.Path]::GetFullPath($Path))).AvailableFreeSpace) }
  end {}
}
