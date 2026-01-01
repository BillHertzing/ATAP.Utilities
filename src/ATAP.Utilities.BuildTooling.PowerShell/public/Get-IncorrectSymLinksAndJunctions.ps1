<#
.SYNOPSIS
Validates symbolic links and junctions in Git repository directories.

.DESCRIPTION
Scans subdirectories of a base path for Git repositories and validates that expected
symbolic links and junctions are present and of the correct type. Reports any missing
or incorrectly typed links.

.PARAMETER BasePath
The base directory path containing Git repositories to scan.

.OUTPUTS
None. Logs validation results via Write-PSFMessage.

.EXAMPLE
Get-IncorrectSymLinksAndJunctions -BasePath 'C:\Dropbox\whertzing\GitHub'

.EXAMPLE
Get-IncorrectSymLinksAndJunctions -BasePath 'C:\Projects'

.NOTES
AI assisted using Powershell.instructions.md as guidelines

.LINK
https://github.com/BillHertzing/ATAP.Utilities
#>
function Get-IncorrectSymLinksAndJunctions {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false)]
    [string]$BasePath = 'C:\Dropbox\whertzing\GitHub'
  )

  BEGIN {
    $fn = 'Get-IncorrectSymLinksAndJunctions'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    # Snippet: Check and populate simple parameter
    $BasePath = Get-PVal BasePath $PSBoundParameters BasePath

    $expectedJunctions = @('.github', '.vscode')
    $expectedSymlinks = @('.gitignore', '.editorconfig', '.markdownlint.yml', '.prettierrc.yml')
    $results = @()
  }

  PROCESS {
    # Snippet: Try-Catch-Finally
    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Scanning base path: $BasePath"

      if (-not (Test-Path $BasePath)) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Base path does not exist: $BasePath"
        throw "Base path does not exist: $BasePath"
      }

      Get-ChildItem $BasePath -Directory | ForEach-Object {
        $folder = $_.FullName
        $folderName = $_.Name
        $status = @{ Folder = $folderName; Missing = @(); UnexpectedType = @(); AllPresent = $true }

        # Only process if a .git folder exists
        $gitPath = Join-Path $folder '.git'
        if (Test-Path $gitPath) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Processing Git repository: $folderName"

          # Check expected junctions
          foreach ($name in $expectedJunctions) {
            $path = Join-Path $folder $name
            if (Test-Path $path) {
              $item = Get-Item $path
              $linkTypeDescription = if ($item.LinkType) { $item.LinkType } elseif ($item.PSIsContainer) { 'Directory' } else { 'File' }
              if (-not $item.LinkType -or $item.LinkType -ne 'Junction') {
                $status.UnexpectedType += "$name (Expected: Junction, Actual: $linkTypeDescription)"
                $status.AllPresent = $false
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Unexpected type in $folderName : $name (Expected: Junction, Actual: $linkTypeDescription)"
              }
            }
            else {
              $status.Missing += "$name (Expected: Junction)"
              $status.AllPresent = $false
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Missing in $folderName : $name (Expected: Junction)"
            }
          }

          # Check expected symbolic links
          foreach ($name in $expectedSymlinks) {
            $path = Join-Path $folder $name
            if (Test-Path $path) {
              $item = Get-Item $path
              $linkTypeDescription = if ($item.LinkType) { $item.LinkType } elseif ($item.PSIsContainer) { 'Directory' } else { 'File' }
              if (-not $item.LinkType -or $item.LinkType -ne 'SymbolicLink') {
                $status.UnexpectedType += "$name (Expected: SymbolicLink, Actual: $linkTypeDescription)"
                $status.AllPresent = $false
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Unexpected type in $folderName : $name (Expected: SymbolicLink, Actual: $linkTypeDescription)"
              }
            }
            else {
              $status.Missing += "$name (Expected: SymbolicLink)"
              $status.AllPresent = $false
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Missing in $folderName : $name (Expected: SymbolicLink)"
            }
          }

          $results += $status
        }
        else {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Skipping non-Git directory: $folderName"
        }
      }

      # Output summary
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Folders that conform:'
      $conformingFolders = $results | Where-Object { $_.AllPresent }
      if ($conformingFolders) {
        foreach ($folder in $conformingFolders) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "  $($folder.Folder)"
        }
      }
      else {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message '  (None)'
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message ''
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Folders that do NOT conform:'
      $nonConformingFolders = $results | Where-Object { -not $_.AllPresent }
      if ($nonConformingFolders) {
        foreach ($folder in $nonConformingFolders) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "  $($folder.Folder)"
          if ($folder.Missing) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "    Missing: $($folder.Missing -join ', ')"
          }
          if ($folder.UnexpectedType) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "    Unexpected Type: $($folder.UnexpectedType -join ', ')"
          }
        }
      }
      else {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message '  (None)'
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Validation complete. Total repositories scanned: $($results.Count)"
    }
    catch {
      $errorMessage = "Failed to validate symbolic links and junctions. Exception: $($_.Exception.Message)"
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
