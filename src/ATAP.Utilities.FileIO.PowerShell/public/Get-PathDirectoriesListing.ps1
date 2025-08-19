# .SYNOPSIS
# Returns a listing of directories in the PATH environment variable that either do not exist or do not contain any executable files.

# .DESCRIPTION
# This function checks each directory in the provided PATH for existence and whether it contains any executable files (.exe).

# .PARAMETER Paths
# An array of paths to check. Defaults to the PATH environment variable split by the system's path separator.

#.OUTPUTS
#  # It returns a hashtable with two arrays:
# - PathDoesNotExist: arrays of paths that do not exist

# .EXAMPLE
# Get-PathDirectoriesListing
# Returns a listing of directories in the PATH environment variable that do not exist or do not contain executable files.

# .NOTES
# ToDo: pass a parameter to specify the list of file extensions to consider as executables, currently it is hardcoded to .exe

function Get-PathDirectoriesListing {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
    [string[]]$Paths = $env:PATH -split [IO.Path]::PathSeparator
  )

  BEGIN {
    Write-PSFMessage -FunctionName 'Get-PathDirectoriesListing' -ModuleName 'ATAP.Utilities.FileIO.PowerShell' -Level Debug -Message 'Entering Function Get-PathDirectoriesListing in module ATAP.Utilities.FileIO.PowerShell'
  }

  PROCESS {
    $results = @{ PathDoesNotExist = @(); PathHasNoExes = @() }

    foreach ($path in $Paths) {
      if (-not (Test-Path -Path $path)) {
        $results.PathDoesNotExist += $path
      }
      elseif (-not (Get-ChildItem -Path $path -Filter *.exe -ErrorAction SilentlyContinue)) {
        $results.PathHasNoExes += $path
      }
    }

    Write-Output $results
  }

  END {
    Write-PSFMessage -FunctionName 'Get-PathDirectoriesListing' -ModuleName 'ATAP.Utilities.FileIO.PowerShell' -Level Debug -Message 'Leaving Function Get-PathDirectoriesListing in module ATAP.Utilities.FileIO.PowerShell'
  }
}

