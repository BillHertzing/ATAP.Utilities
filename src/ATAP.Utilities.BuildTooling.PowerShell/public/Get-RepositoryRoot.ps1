<#
.SYNOPSIS
Finds and returns the repository root directory by searching upward for a .git folder.

.DESCRIPTION
Searches from the current working directory upward through the directory tree
until it finds a .git folder, indicating the repository root. Returns the
relative path from the current directory to the repository root.

.PARAMETER StartPath
Optional starting path for the search. Defaults to current working directory (Get-Location).

.OUTPUTS
String - Relative path to repository root, or $null if not found.

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
    return $null
  }

  # Get absolute path in case relative path was provided
  $currentPath = (Resolve-Path $StartPath).Path
  $originalPath = $currentPath

  Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Resolved start path to: $currentPath"

  # Search upward through directory tree
  $maxDepth = 50  # Safety limit to prevent infinite loop
  $depth = 0

  while ($currentPath -and $depth -lt $maxDepth) {
    $gitPath = Join-Path $currentPath '.git'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Checking for .git folder at: $gitPath"

    if (Test-Path $gitPath -PathType Container) {
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

    # Move up one directory level
    $parentPath = Split-Path $currentPath -Parent

    # Check if we've reached the root of the drive
    if (-not $parentPath -or $parentPath -eq $currentPath) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "Reached filesystem root without finding .git folder"
      return $null
    }

    $currentPath = $parentPath
    $depth++
  }

  # If we exceeded max depth, something is wrong
  if ($depth -ge $maxDepth) {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Exceeded maximum search depth ($maxDepth) without finding repository root"
  }
  else {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "Repository root not found"
  }

  return $null
}
