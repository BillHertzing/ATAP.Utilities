# .SYNOPSIS
# Returns a listing of directories in the PATH environment variable that either do not exist or do not contain any executable files.

# .DESCRIPTION
# This function checks each directory in the provided PATH for existence and whether it contains any executable files (.exe).

# .PARAMETER Paths
# An array of paths to check. Defaults to the PATH environment variable split by the system's path separator.

# .PARAMETER FileSuffixes
# An array of file suffixes to consider as executable. Defaults to '.exe', '.cmd', '.bat', '.ps1'.

#.OUTPUTS
#  # It returns a hashtable with two arrays:
# - PathDoesNotExist: arrays of paths that do not exist

# .EXAMPLE
# Get-PathDirectoriesListing
# Returns a listing of directories in the PATH environment variable that do not exist or do not contain executable files.

# .NOTES
# AI assisted using Powershell.instructions.md as guidelines

function Get-PathDirectoriesListing {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
    [string[]]$Paths = $env:PATH -split [IO.Path]::PathSeparator,

    [Parameter(Mandatory = $false)]
    [string[]]$FileSuffixes = @('.exe', '.cmd', '.bat', '.ps1')
  )

  BEGIN {
    Write-PSFMessage -FunctionName 'Get-PathDirectoriesListing' -ModuleName 'ATAP.Utilities.FileIO.PowerShell' -Level Debug -Message 'Entering Function Get-PathDirectoriesListing in module ATAP.Utilities.FileIO.PowerShell'
  }

  PROCESS {
    $results = @{ PathDoesNotExist = @(); PathHasNoExes = @(); ExesInPath = @{} ;NumTotalPathsChecked = 0;NumPathHasNoExes=0}

    foreach ($path in $Paths) {
      if (-not (Test-Path -Path $path)) {
        $results.PathDoesNotExist += $path
      }
      else {
        $hasFiles = $false
        $filesInPath = @()
        foreach ($suffix in $FileSuffixes) {
          $files = Get-ChildItem -Path $path -Filter *$suffix -ErrorAction SilentlyContinue
          if ($files) {
            $filesInPath += $files.FullName
            $hasFiles = $true
          }
        }
        if ($hasFiles) {
          $results.ExesInPath[$path] = $filesInPath
        }
        else {
          $results.PathHasNoExes += $path
        }
      }
    }

    # Edge case: Check if all paths are non-existing
    if ($results.PathDoesNotExist.Count -eq $Paths.Count) {
      Write-PSFMessage -FunctionName 'Get-PathDirectoriesListing' -ModuleName 'ATAP.Utilities.FileIO.PowerShell' -Level Warning -Message 'All provided paths do not exist.'
    }

    $results.NumTotalPathsChecked = $Paths.Count
    $results.NumPathHasNoExes = $($Results.PathHasNoExes).Count
    return $results
  }

  END {
    Write-PSFMessage -FunctionName 'Get-PathDirectoriesListing' -ModuleName 'ATAP.Utilities.FileIO.PowerShell' -Level Debug -Message 'Leaving Function Get-PathDirectoriesListing in module ATAP.Utilities.FileIO.PowerShell'
  }
}

