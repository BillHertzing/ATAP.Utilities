function Resolve-WorkspaceFiles {
  <#
  .SYNOPSIS
    Resolves an array of workspace file paths to their full provider paths.
  .DESCRIPTION
    Each path is resolved via Resolve-Path. Throws immediately if any path
    does not exist.
  .PARAMETER WorkspaceFiles
    One or more paths to .code-workspace files.
  #>
  [CmdletBinding()]
  [OutputType([string[]])]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string[]]$WorkspaceFiles
  )

  $resolved = [System.Collections.Generic.List[string]]::new()
  foreach ($workspaceFile in $WorkspaceFiles) {
    $item = Resolve-Path -Path $workspaceFile -ErrorAction Stop
    $resolved.Add($item.ProviderPath)
  }
  return [string[]]$resolved
}
