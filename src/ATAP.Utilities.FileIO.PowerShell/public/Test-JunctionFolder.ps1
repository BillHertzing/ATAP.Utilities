<#
.SYNOPSIS
Tests if a folder is a junction and returns its target path.

.DESCRIPTION
Checks whether the specified folder is a directory junction (also known as a soft link)
and optionally returns the target path if it is a junction.

.PARAMETER Path
The folder path to test.

.PARAMETER ReturnTarget
Switch to return the target path instead of a boolean.

.OUTPUTS
System.Boolean or System.String
Returns $true/$false by default, or the target path string if -ReturnTarget is specified.

.EXAMPLE
Test-JunctionFolder -Path 'C:\MyJunction'
Returns $true if the folder is a junction, $false otherwise.

.EXAMPLE
$target = Test-JunctionFolder -Path 'C:\MyJunction' -ReturnTarget
Returns the target path if the folder is a junction, $null otherwise.

.EXAMPLE
$item = Get-Item 'C:\MyJunction'
Test-JunctionFolder -Path $item.FullName
Tests if the item is a junction.

.NOTES
AI assisted using Powershell.instructions.md as guidelines

.LINK
https://github.com/whertzing/ATAP.Utilities
#>
function Test-JunctionFolder {
  [CmdletBinding()]
  [OutputType([bool], [string])]
  param(
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [string]$Path,

    [Parameter(Mandatory = $false)]
    [switch]$ReturnTarget
  )

  BEGIN {
    $fn = 'Test-JunctionFolder'
    $mn = 'ATAP.Utilities.FileIO.PowerShell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    # Load required helper functions
    try {
      if (-not (Get-Command -Name 'Get-ParameterValueFromNeoConfigurationRoot' -CommandType Function -ErrorAction SilentlyContinue)) {
        . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\Get-ParameterValueFromNeoConfigurationRoot.ps1'
      }
      if (-not (Get-Command -Name 'Resolve-ParameterValueToList' -CommandType Function -ErrorAction SilentlyContinue)) {
        . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\Resolve-ParameterValueToList.ps1'
      }
    }
    catch {
      $errorMessage = "Failed to load required functions. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }

    # Snippet: Check and populate simple parameter - Path
    $Path = Get-PVal Path $PSBoundParameters Path

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Testing if path is a junction: $Path"
  }

  PROCESS {
    # Snippet: Try-Catch-Finally
    try {
      # Validate path exists
      if (-not (Test-Path $Path)) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "Path does not exist: $Path"
        if ($ReturnTarget) {
          return $null
        }
        else {
          return $false
        }
      }

      # Get the item with Force to include hidden/system items
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Retrieving item details for: $Path"
      $item = Get-Item -Path $Path -Force -ErrorAction Stop

      # Check if it's a junction
      $isJunction = $item.LinkType -eq 'Junction'

      if ($isJunction) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Path is a junction. Target: $($item.Target)"

        if ($ReturnTarget) {
          # Return the target path
          $targetPath = $item.Target
          if ($targetPath -is [array]) {
            # If multiple targets (rare), return the first one
            $targetPath = $targetPath[0]
          }
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Returning target path: $targetPath"
          return $targetPath
        }
        else {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Path is a junction: $true'
          return $true
        }
      }
      else {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Path is NOT a junction. LinkType: $($item.LinkType)"

        if ($ReturnTarget) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Path is not a junction: returning $null'
          return $null
        }
        else {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Path is not a junction: $false'
          return $false
        }
      }
    }
    catch {
      $errorMessage = "Failed to test junction folder. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      # ToDo: accumulate the errors; potentially add to 'Problems'
      throw # the unadorned throw will throw the $_ exception and keep the stack trace intact
    }
    finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving Function $fn in module $mn"
    }
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
