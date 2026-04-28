function Save-WorkspaceJson {
  <#
  .SYNOPSIS
    Serializes a PSCustomObject back to a .code-workspace file as JSON.
  .DESCRIPTION
    Converts the object to JSON (depth 20) and writes it as UTF-8.
  .PARAMETER WorkspaceFile
    Path to the .code-workspace file.
  .PARAMETER Json
    The PSCustomObject to serialize.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$WorkspaceFile,

    [Parameter(Mandatory)]
    [PSCustomObject]$Json
  )

  $Json | ConvertTo-Json -Depth 20 | Set-Content -Path $WorkspaceFile -Encoding UTF8
}
