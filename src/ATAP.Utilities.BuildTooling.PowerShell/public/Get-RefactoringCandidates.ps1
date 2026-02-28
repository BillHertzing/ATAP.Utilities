function Get-RefactoringCandidates {
  <#
  .SYNOPSIS
    Analyzes folder structure to identify refactoring opportunities for grouping related folders under parent containers.

  .DESCRIPTION
    Scans a source directory to find folders that follow multi-part naming conventions (e.g., ATAP.Utilities.X.Y.Z)
    and identifies opportunities to group them under parent folders. This supports the refactoring pattern of
    combining peer folders with common prefixes under a container parent folder.

    The function:
    - Identifies all folders with three or more dot-separated parts
    - Groups them by their common prefix (first N-1 parts)
    - Checks for .csproj files to identify project conflicts
    - Analyzes existing parent folders and their contents
    - Reports potential refactoring opportunities

  .PARAMETER SourcePath
    The root path to analyze. Defaults to the 'src' folder in the repository root.

  .PARAMETER MinimumGroupSize
    Minimum number of folders with the same prefix to consider as a refactoring candidate. Default is 2.

  .PARAMETER IncludeExistingParents
    If specified, includes analysis of existing parent folders that might already contain subfolders.

  .PARAMETER OutputFormat
    Format for output: 'Text', 'JSON', or 'Object'. Default is 'Object'.

  .EXAMPLE
    Get-RefactoringCandidates -SourcePath "C:\repo\src"

    Analyzes the src folder and returns refactoring candidates as PowerShell objects.

  .EXAMPLE
    Get-RefactoringCandidates -MinimumGroupSize 3 -OutputFormat JSON

    Finds groups with at least 3 related folders and outputs as JSON.

  .EXAMPLE
    Get-RefactoringCandidates -IncludeExistingParents | Where-Object { $_.ConflictType -eq 'None' }

    Gets only refactoring candidates that have no conflicts.

  .OUTPUTS
    PSCustomObject[] with properties:
    - GroupPrefix: The common prefix (e.g., "ATAP.Utilities.ComputerInventory")
    - CandidateFolders: Array of folder names that would be grouped
    - FolderCount: Number of folders in the group
    - ParentFolderExists: Boolean indicating if parent folder already exists
    - ParentContainsProject: Boolean indicating if parent contains a .csproj file
    - ConflictType: 'None', 'ParentHasProject', 'ParentHasSubfolders', or 'Both'
    - RecommendedAction: Suggested refactoring approach
    - FullPaths: Array of full paths to the candidate folders

  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
    This function is part of the ATAP.Utilities.BuildTooling.PowerShell module.
    It supports the refactoring workflow documented in the SharedVSCode prompts.

  .LINK
    https://github.com/BillHertzing/ATAP.Utilities
  #>

  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false, Position = 0)]
    [string]$SourcePath,

    [Parameter(Mandatory = $false, Position = 1)]
    [ValidateRange(1, 100)]
    [int]$MinimumGroupSize = 2,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeExistingParents,

    [Parameter(Mandatory = $false)]
    [ValidateSet('Text', 'JSON', 'Object')]
    [string]$OutputFormat = 'Object'
  )

  begin {
    $fn = 'Get-RefactoringCandidates'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    # Snippet: Check and populate simple parameter
    if (-not $PSBoundParameters.ContainsKey('SourcePath') -or [string]::IsNullOrWhiteSpace($SourcePath)) {
      # Try to find repository root and use src folder
      try {
        if (Get-Command Get-RepositoryRoot -ErrorAction SilentlyContinue) {
          $repoRoot = Get-RepositoryRoot
          $SourcePath = Join-Path -Path $repoRoot -ChildPath 'src'
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "SourcePath not provided, using repository src folder: $SourcePath"
        }
        else {
          $errorMessage = 'No SourcePath specified and Get-RepositoryRoot is not available. Please specify -SourcePath.'
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
          throw $errorMessage
        }
      }
      catch {
        $errorMessage = "Failed to determine SourcePath. Exception: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        throw
      }
    }

    # Snippet: Check and populate simple parameter as Type (int)
    if ($MinimumGroupSize -lt 1) {
      $errorMessage = "MinimumGroupSize must be at least 1, received: $MinimumGroupSize"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw $errorMessage
    }

    # Snippet: Try-Catch-Finally - Validate source path exists
    try {
      if (-not (Test-Path -Path $SourcePath -PathType Container)) {
        $errorMessage = "Source path does not exist or is not a directory: $SourcePath"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        throw $errorMessage
      }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Analyzing folder structure in: $SourcePath"
    }
    catch {
      $errorMessage = "Failed to validate SourcePath. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "MinimumGroupSize is $MinimumGroupSize"
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "IncludeExistingParents is $IncludeExistingParents"
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "OutputFormat is $OutputFormat"
  }

  process {
    try {
      # Get all directories in the source path (first level only)
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Getting all directories in source path'
      $allFolders = Get-ChildItem -Path $SourcePath -Directory -ErrorAction Stop | Select-Object -ExpandProperty Name

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Found $($allFolders.Count) folders to analyze"

      # Group folders by their potential parent (all parts except the last)
      $groupedFolders = @{}

      foreach ($folder in $allFolders) {
        $parts = $folder -split '\.'

        # Only consider folders with 3 or more parts (e.g., ATAP.Utilities.Something)
        if ($parts.Count -ge 3) {
          # Parent would be everything except the last part
          $parentName = ($parts[0..($parts.Count - 2)] -join '.')

          if (-not $groupedFolders.ContainsKey($parentName)) {
            $groupedFolders[$parentName] = @()
          }

          $groupedFolders[$parentName] += $folder
        }
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Identified $($groupedFolders.Count) potential parent groups"

      # Analyze each group
      $results = @()

      foreach ($parentName in $groupedFolders.Keys | Sort-Object) {
        $candidates = $groupedFolders[$parentName]

        # Skip if below minimum group size
        if ($candidates.Count -lt $MinimumGroupSize) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Skipping $parentName - only $($candidates.Count) folders (minimum: $MinimumGroupSize)"
          continue
        }

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Analyzing group: $parentName with $($candidates.Count) candidates"

        # Check if parent folder exists
        $parentPath = Join-Path -Path $SourcePath -ChildPath $parentName
        $parentExists = Test-Path -Path $parentPath -PathType Container

        # Initialize conflict analysis
        $parentHasProject = $false
        $parentHasSubfolders = $false
        $conflictType = 'None'
        $recommendedAction = 'Safe to refactor - create parent folder and move children'

        if ($parentExists) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Parent folder exists: $parentPath"

          # Check for .csproj in parent
          $projectFiles = Get-ChildItem -Path $parentPath -Filter '*.csproj' -File -ErrorAction SilentlyContinue
          $parentHasProject = $projectFiles.Count -gt 0

          # Check for existing subfolders
          $existingSubfolders = Get-ChildItem -Path $parentPath -Directory -ErrorAction SilentlyContinue
          $parentHasSubfolders = $existingSubfolders.Count -gt 0

          # Determine conflict type
          if ($parentHasProject -and $parentHasSubfolders) {
            $conflictType = 'Both'
            $recommendedAction = 'Complex refactor - parent has both project and subfolders. Consider creating intermediate folder.'
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Conflict detected for $parentName - both project and subfolders exist"
          }
          elseif ($parentHasProject) {
            $conflictType = 'ParentHasProject'
            $recommendedAction = 'Moderate refactor - move parent project to subfolder, then move peer folders.'
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Conflict detected for $parentName - parent has project file"
          }
          elseif ($parentHasSubfolders) {
            $conflictType = 'ParentHasSubfolders'
            if ($IncludeExistingParents) {
              $recommendedAction = 'Simple refactor - parent already exists with subfolders, just move peer folders.'
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Parent $parentName has subfolders but including due to -IncludeExistingParents"
            }
            else {
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Skipping $parentName - parent has subfolders (use -IncludeExistingParents to include)"
              continue
            }
          }
        }

        # Build result object
        $result = [PSCustomObject]@{
          GroupPrefix           = $parentName
          CandidateFolders      = $candidates | Sort-Object
          FolderCount           = $candidates.Count
          ParentFolderExists    = $parentExists
          ParentContainsProject = $parentHasProject
          ParentHasSubfolders   = $parentHasSubfolders
          ConflictType          = $conflictType
          RecommendedAction     = $recommendedAction
          FullPaths             = $candidates | ForEach-Object { Join-Path -Path $SourcePath -ChildPath $_ }
        }

        $results += $result
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Found $($results.Count) refactoring candidates"

      # Output based on format
      switch ($OutputFormat) {
        'JSON' {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Converting results to JSON'
          return $results | ConvertTo-Json -Depth 5
        }
        'Text' {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Formatting results as text'
          foreach ($result in $results) {
            Write-Output ''
            Write-Output "=== Refactoring Candidate: $($result.GroupPrefix) ==="
            Write-Output "Candidate Folders ($($result.FolderCount)):"
            $result.CandidateFolders | ForEach-Object { Write-Output "  - $_" }
            Write-Output "Parent Exists: $($result.ParentFolderExists)"
            if ($result.ParentFolderExists) {
              Write-Output "Parent Has Project: $($result.ParentContainsProject)"
              Write-Output "Parent Has Subfolders: $($result.ParentHasSubfolders)"
            }
            Write-Output "Conflict Type: $($result.ConflictType)"
            Write-Output "Recommended Action: $($result.RecommendedAction)"
          }
        }
        'Object' {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Returning results as objects'
          return $results
        }
      }
    }
    catch {
      $errorMessage = "Failed to analyze folder structure. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}

# Export the function
Export-ModuleMember -Function Get-RefactoringCandidates
