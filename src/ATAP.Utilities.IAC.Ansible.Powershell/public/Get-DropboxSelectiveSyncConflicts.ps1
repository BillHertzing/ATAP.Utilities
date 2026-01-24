<#
.SYNOPSIS
Finds Dropbox Selective Sync conflicts by identifying folders with SelectiveSync pattern and their originals.

.DESCRIPTION
Scans a base path for folders containing 'SelectiveSync' in their names, extracts the base
filename prefix, and searches for corresponding original folders. Returns a hashtable of
conflicts with both the SelectiveSync folder and the original folder paths.

.PARAMETER BasePath
The base directory path to scan for Selective Sync conflicts. Defaults to C:\Dropbox.

.OUTPUTS
Hashtable. A hashtable keyed by folder name containing BaseFileName and OriginalFullPath properties.

.EXAMPLE
Get-DropboxSelectiveSyncConflicts

Scans C:\Dropbox for Selective Sync conflicts.

.EXAMPLE
Get-DropboxSelectiveSyncConflicts -BasePath 'D:\MyDropbox'

Scans D:\MyDropbox for Selective Sync conflicts.

.NOTES
AI assisted using Powershell.instructions.md as guidelines

.LINK
https://github.com/BillHertzing/ATAP.Utilities
#>
function Get-DropboxSelectiveSyncConflicts {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false)]
    [string]$BasePath = 'C:\Dropbox'
  )

  BEGIN {
    $fn = 'Get-DropboxSelectiveSyncConflicts'
    $mn = 'ATAP.Utilities.IAC.Ansible.Powershell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    # Snippet: Check and populate optional parameter
    if (-not $PSBoundParameters.ContainsKey('BasePath')) {
      if ($global:settings -and $global:ConfigRootKeys -and $global:ConfigRootKeys.ContainsKey('DropboxBasePathConfigRootKey')) {
        $configValue = $global:settings[$global:ConfigRootKeys['DropboxBasePathConfigRootKey']]
        if ($configValue) {
          $BasePath = $configValue
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "BasePath parameter populated from configuration: $BasePath"
        }
      }
    }

    $selectiveSyncFolders = @{}
  }

  PROCESS {
    # Snippet: Try-Catch-Finally
    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Scanning base path: $BasePath"

      if (-not (Test-Path $BasePath -PathType Container)) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Base path does not exist or is not a directory: $BasePath"
        throw "Base path does not exist or is not a directory: $BasePath"
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Finding folders with SelectiveSync pattern...'

      # Find all folders with ' (Selective Sync' in their name
      $allFolders = Get-ChildItem -Path $BasePath -Directory -Recurse -ErrorAction SilentlyContinue
      $selectiveSyncMatches = $allFolders | Where-Object { $_.Name -match '\s+\(Selective Sync' }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Found $($selectiveSyncMatches.Count) folders with SelectiveSync pattern"

      # Build hashtable with SelectiveSync folders
      $processedCount = 0
      $totalMatches = $selectiveSyncMatches.Count
      foreach ($folder in $selectiveSyncMatches) {
        $processedCount++
        if ($processedCount % 100 -eq 0) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "First pass: Processed $processedCount of $totalMatches SelectiveSync folders"
        }

        $folderName = $folder.Name

        # Extract base path (everything before ' (Selective Sync')
        if ($folderName -match '^(.+?)\s+\(Selective Sync') {
          $ssIssueBasePath = $Matches[1]

          # Extract the leaf folder name (bottommost folder)
          $leafName = Split-Path -Path $ssIssueBasePath -Leaf

          $selectiveSyncFolders[$folderName] = @{
            FullPath         = $folder.FullName
            SSIssueBasePath  = $ssIssueBasePath
            LeafName         = $leafName
            OriginalFullPath = $null
          }

          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Added SelectiveSync folder: $folderName with base: $ssIssueBasePath, leaf: $leafName"
        }
        else {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Could not extract base path from: $folderName"
        }
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Searching for original folders matching $($selectiveSyncFolders.Count) base filenames..."

      # Search for original folders matching the base filenames
      $searchCount = 0
      $totalKeys = $selectiveSyncFolders.Count
      foreach ($key in $selectiveSyncFolders.Keys) {
        $searchCount++
        if ($searchCount % 50 -eq 0) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Second pass: Searched $searchCount of $totalKeys base filenames"
        }

        $leafName = $selectiveSyncFolders[$key].LeafName

        # Find folders whose leaf name exactly matches (case insensitive)
        $originalFolder = $allFolders | Where-Object { $_.Name -eq $leafName } | Select-Object -First 1

        if ($originalFolder) {
          $selectiveSyncFolders[$key].OriginalFullPath = $originalFolder.FullName
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Found original folder for leaf name '$leafName': $($originalFolder.FullName)"
        }
        else {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "No original folder found for leaf name: $leafName"
        }
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Selective Sync Conflicts:'

      # Print the hashtable using Write-HashIndented
      # if (Get-Command -Name 'Write-HashIndented' -ErrorAction SilentlyContinue) {
      #   Write-HashIndented -Hash $selectiveSyncFolders
      # }
      # else {
      #   # Fallback if Write-HashIndented is not available
      #   Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message ($selectiveSyncFolders | ConvertTo-Json -Depth 3)
      # }

      # Show entries without original folder matches
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "`nEntries without original folder matches:"
      $entriesWithoutOriginal = $selectiveSyncFolders.Keys | Where-Object { -not $selectiveSyncFolders[$_].OriginalFullPath }

      if ($entriesWithoutOriginal.Count -gt 0) {
        foreach ($key in $entriesWithoutOriginal) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "  Key: $key"
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "    FullPath: $($selectiveSyncFolders[$key].FullPath)"
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "    LeafName: $($selectiveSyncFolders[$key].LeafName)"
        }
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Total entries without original folder: $($entriesWithoutOriginal.Count)"
      }
      else {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "  (All entries have matching original folders)"
      }


      # Return the hashtable
      #return $selectiveSyncFolders
    }
    catch {
      $errorMessage = "Failed to find Selective Sync conflicts. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw $errorMessage
    }
    finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving Function $fn in module $mn"
    }
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
