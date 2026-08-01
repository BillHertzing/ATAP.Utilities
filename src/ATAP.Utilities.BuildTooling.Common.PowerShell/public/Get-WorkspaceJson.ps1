function Get-WorkspaceJson {
  <#
  .SYNOPSIS
    Reads a .code-workspace file and returns its parsed JSON object.
  .DESCRIPTION
    Reads the file as UTF-8 text and deserializes with ConvertFrom-Json.
    Throws if the file does not exist.
  .PARAMETER WorkspaceFile
    Absolute or relative path to the .code-workspace file.
  #>
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$WorkspaceFile
  )

  if (-not (Test-Path -Path $WorkspaceFile)) {
    throw "Workspace file not found: '$WorkspaceFile'."
  }

  Get-Content -Path $WorkspaceFile -Raw -Encoding UTF8 | ConvertFrom-Json
}
