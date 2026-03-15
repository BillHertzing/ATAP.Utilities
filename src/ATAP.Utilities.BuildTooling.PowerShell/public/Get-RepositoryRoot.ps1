<#
.SYNOPSIS
Finds and returns the repository root directory using git.

.DESCRIPTION
Changes to StartPath then uses 'git rev-parse --show-toplevel' to locate the
repository root. Returns the relative path from the original working directory
to the repository root. Supports both standard Git repositories and Git worktrees.

.PARAMETER StartPath
Optional starting path for the search. Defaults to current working directory (Get-Location).

.OUTPUTS
String - Relative path to repository root.

.EXAMPLE
$repoRoot = Get-RepositoryRoot

Returns the relative path to the repository root from the current directory.

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
    [string]$StartPath = (Get-Location).Path
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

    # Calculate relative path from original location to repo root
    try {
      $relativePath = Resolve-Path -Path $currentPath -Relative -RelativeBasePath $originalPath
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Relative path to repository root: $relativePath"
      return $relativePath
    }
    catch {
      # If relative path calculation fails, return absolute path
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "Could not calculate relative path, returning absolute path"
      return $currentPath
    }
  }
  finally {
    Pop-Location
  }
}
