<#
.SYNOPSIS
Finds and returns the repository root directory using git.

.DESCRIPTION
Changes to StartPath then uses 'git rev-parse --show-toplevel' to locate the
repository root. By default returns the relative path from the original working
directory to the repository root. With -Absolute, returns the absolute
repository-root path exactly as reported by git (no relative conversion), which
is required by callers that compare the root against absolute paths such as git
'safe.directory' entries. Supports both standard Git repositories and Git workTrees.

.PARAMETER StartPath
Optional starting path for the search. Defaults to current working directory (Get-Location).

.PARAMETER Absolute
When supplied, return the absolute repository-root path from
'git rev-parse --show-toplevel' without converting it to a path relative to the
original working directory. Backward compatible: omitting this switch preserves
the historical relative-path return value. Use -Absolute inside a git worktree,
where '.git' is a file pointer and the relative conversion yields a path
(e.g. '..\repo-wt-...') that will not match absolute path comparisons.

.OUTPUTS
String - Repository root path. Relative by default; absolute when -Absolute is supplied.

.EXAMPLE
$repoRoot = Get-RepositoryRoot

Returns the relative path to the repository root from the current directory.

.EXAMPLE
$repoRoot = Get-RepositoryRoot -Absolute

Returns the absolute path to the repository root, safe for comparison against
absolute git 'safe.directory' entries even inside a worktree.

.EXAMPLE
$repoRoot = Get-RepositoryRoot -StartPath 'C:\MyProject\src\subfolder'

Returns the relative path to the repository root starting from the specified path.

.NOTES
AI assisted using Powershell.instructions.md as guidelines
#>

function Get-RepositoryRoot {
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory = $false)]
    [string]$StartPath = (Get-Location).Path,

    [Parameter(Mandatory = $false)]
    [switch]$Absolute
  )

  $fn = 'Get-RepositoryRoot'
  $mn = 'ATAP.Utilities.BuildTooling.PowerShell'

  Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Searching for repository root starting from: $StartPath"

  # Validate start path exists
  if (-not (Test-Path $StartPath)) {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Start path does not exist: $StartPath"
    throw "Start path does not exist: $StartPath"
  }

  $originalPath = (Get-Location).Path

  Push-Location
  try {
    Set-Location -Path $StartPath
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Changed to: $StartPath"

    $currentPath = git rev-parse --show-toplevel 2>&1
    if ($LASTEXITCODE -ne 0) {
      $msg = "git rev-parse --show-toplevel failed: $currentPath"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Found repository root at: $currentPath"

    # Normalize the git output to a single trimmed string. git emits the
    # absolute toplevel with forward slashes on Windows.
    $absoluteRoot = ([string]$currentPath).Trim()

    if ($Absolute) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Returning absolute repository root: $absoluteRoot"
      return $absoluteRoot
    }

    # Calculate relative path from original location to repo root
    try {
      $relativePath = Resolve-Path -Path $absoluteRoot -Relative -RelativeBasePath $originalPath
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Relative path to repository root: $relativePath"
      return $relativePath
    } catch {
      # If relative path calculation fails, return absolute path
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Could not calculate relative path, returning absolute path: $($_.Exception.Message)"
      return $absoluteRoot
    }
  } finally {
    Pop-Location
  }
}
