<#
.SYNOPSIS
Finds the largest folders by calculating total file sizes in each child folder.

.DESCRIPTION
Recursively scans all child folders from a starting path, calculates the sum of all
file sizes within each folder, and returns the top N largest folders sorted by size.

.PARAMETER Path
The starting directory path to scan. Defaults to current directory.

.PARAMETER TopN
The number of largest folders to return. Defaults to 10.

.OUTPUTS
PSCustomObject[] Array of custom objects containing FolderPath, SizeBytes, and SizeGB properties.

.EXAMPLE
Get-LargestLeafFolders

Scans current directory and returns top 10 largest folders.

.EXAMPLE
Get-LargestLeafFolders -Path 'C:\Users' -TopN 20

Scans C:\Users directory and returns top 20 largest folders.

.EXAMPLE
Get-LargestLeafFolders -Path 'D:\Projects' | Format-Table -AutoSize

Displays results in a formatted table.

.NOTES
AI assisted using Powershell.instructions.md as guidelines

.LINK
https://github.com/BillHertzing/ATAP.Utilities
#>
function Get-LargestLeafFolders {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false)]
    [string]$Path = 'C:\Dropbox',

    [Parameter(Mandatory = $false)]
    [int]$TopN = 10
  )

  BEGIN {
    $fn = 'Get-LargestLeafFolders'
    $mn = 'ATAP.Utilities.Powershell'

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
      throw $errorMessage
    }

    # Snippet: Check and populate simple parameter
    #$Path = Get-PVal Path $PSBoundParameters Path

    # Snippet: Check and populate simple parameter as Type
    #$TopN = Get-PVal TopN $PSBoundParameters TopN
    if ($PSBoundParameters.ContainsKey('TopN')) {
      $TopN = [int]$TopN
    }

    $folderSizes = @()
  }

  PROCESS {
    # Snippet: Try-Catch-Finally
    try {
      # Convert to absolute path
      $absolutePath = Resolve-Path -Path $Path -ErrorAction Stop
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Scanning path: $absolutePath"

      if (-not (Test-Path $absolutePath -PathType Container)) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Path is not a directory: $absolutePath"
        throw "Path is not a directory: $absolutePath"
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Calculating folder sizes for top $TopN folders..."

      # Get all child directories recursively
      $allFolders = Get-ChildItem -Path $absolutePath -Directory -Recurse -ErrorAction SilentlyContinue

      $totalFolders = $allFolders.Count
      $processedCount = 0

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Found $totalFolders folders to process"

      foreach ($folder in $allFolders) {
        $processedCount++
        if ($processedCount % 100 -eq 0) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Processed $processedCount of $totalFolders folders"
        }

        try {
          # Calculate total size of files directly in this folder only (no recursion)
          $files = Get-ChildItem -Path $folder.FullName -File -ErrorAction SilentlyContinue
          $totalSize = ($files | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum

          if ($null -eq $totalSize) {
            $totalSize = 0
          }

          $folderSizes += [PSCustomObject]@{
            FolderPath = $folder.FullName
            SizeBytes  = $totalSize
            SizeGB     = [math]::Round($totalSize / 1GB, 2)
          }
        }
        catch {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Error processing folder $($folder.FullName): $($_.Exception.Message)"
        }
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Sorting and selecting top $TopN folders"

      # Sort by size descending and take top N
      $result = $folderSizes | Sort-Object -Property SizeBytes -Descending | Select-Object -First $TopN

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Found top $($result.Count) largest folders"

      # Return the results
      return $result
    }
    catch {
      $errorMessage = "Failed to calculate largest folders. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }
    finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving Function $fn in module $mn"
    }
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
