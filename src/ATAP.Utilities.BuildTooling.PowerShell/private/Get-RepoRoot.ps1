function Get-RepoRoot {
  <#
  .SYNOPSIS
    Returns the absolute path of the current Git repository root.
  .DESCRIPTION
    Calls Assert-GitAvailable, then `git rev-parse --show-toplevel`.
    Throws if the current directory is not inside a Git working tree.
  #>
  [CmdletBinding()]
  [OutputType([string])]
  param()

  Assert-GitAvailable

  $repoRoot = git rev-parse --show-toplevel 2>$null
  if (-not $repoRoot) {
    throw 'Current directory is not inside a Git working tree.'
  }
  return $repoRoot.Trim()
}
