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
    - Generates detailed action plans with git mv commands
    - Identifies folders and facade projects that need to be created
    - Plans the refactoring to achieve the goal structure defined in the refactor prompt
    - Reports potential refactoring opportunities

  .PARAMETER SourcePath
    The root path to analyze. Defaults to the 'src' folder in the repository root.

  .PARAMETER MinimumGroupSize
    Minimum number of folders with the same prefix to consider as a refactoring candidate. Default is 2.

  .PARAMETER IncludeExistingParents
    If specified, includes analysis of existing parent folders that might already contain subfolders.

  .PARAMETER OutputFormat
    Format for output: 'Text', 'JSON', or 'Object'. Default is 'Object'.

  .PARAMETER ExclusionPatterns
    Array of regular expression patterns to exclude folders from analysis. Folders matching any pattern will be skipped.
    Default patterns exclude: database-related folders, ATAP.Services/Console/IAC/VSCExtension folders, and ATAP.Utilities.Powershell.

  .EXAMPLE
    Get-RefactoringCandidates -SourcePath "C:\repo\src"

    Analyzes the src folder and returns refactoring candidates as PowerShell objects.

  .EXAMPLE
    Get-RefactoringCandidates -MinimumGroupSize 3 -OutputFormat JSON

    Finds groups with at least 3 related folders and outputs as JSON.

  .EXAMPLE
    Get-RefactoringCandidates -IncludeExistingParents | Where-Object { $_.ConflictType -eq 'None' }

    Gets only refactoring candidates that have no conflicts.

  .EXAMPLE
    Get-RefactoringCandidates -ExclusionPatterns @('^ATAP\.Test', '(?i)temp')

    Analyzes folders but excludes any starting with ATAP.Test or containing 'temp' (case-insensitive).

  .OUTPUTS
    PSCustomObject[] with properties:
    - GroupPrefix: The common prefix (e.g., "ATAP.Utilities.ComputerInventory")
    - CandidateFolders: Array of folder names that would be grouped
    - FolderCount: Number of folders in the group
    - ParentFolderExists: Boolean indicating if parent folder already exists
    - ParentContainsProject: Boolean indicating if parent contains a .csproj file
    - ParentHasSubfolders: Boolean indicating if parent has existing subfolders
    - ConflictType: 'None', 'ParentHasProject', 'ParentHasSubfolders', or 'Both'
    - RecommendedAction: Suggested refactoring approach
    - ActionPlan: Array of ordered steps describing the refactoring actions
    - GitMoveCommands: Array of git mv commands to execute the refactoring
    - ItemsToCreate: Array of folders and files that need to be created
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
    [int]$MinimumGroupSize = 2,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeExistingParents,

    [Parameter(Mandatory = $false)]
    [string]$OutputFormat = 'Object',

    [Parameter(Mandatory = $false)]
    [string[]]$ExclusionPatterns
  )

  begin {
    $fn = 'Get-RefactoringCandidates'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    # Load required helper functions
    try {
      if (-not (Get-Command -Name 'Get-ParameterValueFromNeoConfigurationRoot' -CommandType Function -ErrorAction SilentlyContinue)) {
        . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\Get-ParameterValueFromNeoConfigurationRoot.ps1'
      }
      if (-not (Get-Command -Name 'Get-RepositoryRoot' -CommandType Function -ErrorAction SilentlyContinue)) {
        . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.BuildTooling.PowerShell\public\Get-RepositoryRoot.ps1'
      }
    }
    catch {
      $errorMessage = "Failed to load required functions. Exception: $($_.Exception.Message)"
      Write-PSFMessage -Level Error -Message $errorMessage
      throw
    }

    # Snippet: Check and populate simple parameter
    $SourcePath = Get-PVal -ParameterName 'SourcePath' -originalPSBoundParameters $PSBoundParameters -dottedPath 'Get-RefactoringCandidatesSourcePath' -DefaultValue (Join-Path -Path (Get-RepositoryRoot) -ChildPath 'src')

    # Snippet: Check and populate simple parameter as Type (int)
    $MinimumGroupSize = Get-PVal -ParameterName 'MinimumGroupSize' -originalPSBoundParameters $PSBoundParameters -dottedPath 'Get-RefactoringCandidatesMinimumGroupSize' -DefaultValue 2

    $OutputFormat = Get-PVal -ParameterName 'OutputFormat' -originalPSBoundParameters $PSBoundParameters -dottedPath 'Get-RefactoringCandidates.OutputFormat' -DefaultValue 'Object'

    # Snippet: Check and populate simple parameter (exclusion patterns array)
    # Default exclusion patterns based on refactor prompt requirements
    $defaultExclusionPatterns = @(
      '(?i)database',                    # Exclude folders containing "database" (case-insensitive)
      '^ATAP\.Utilities$',               # Exclude ATAP.Utilities itself as a parent container
      '^ATAP\.Service',                 # Exclude ATAP.Service.* folders
      '^ATAP\.Services',                 # Exclude ATAP.Services.* folders
      '^ATAP\.Console',                  # Exclude ATAP.Console.* folders
      '^ATAP\.IAC',                      # Exclude ATAP.IAC.* folders
      '^ATAP\.VSCExtension',             # Exclude ATAP.VSCExtension.* folders
      '^ATAP-AiAssist',                  # Exclude ATAP-AiAssist.* folders
      '^ATAP\.Utilities\.BuildTooling',  # Exclude ATAP.Utilities.BuildTooling.* folders
      '^ATAP\.Utilities\.Powershell$'    # Exclude ATAP.Utilities.Powershell specifically
    )
    $ExclusionPatterns = Get-PVal -ParameterName 'ExclusionPatterns' -originalPSBoundParameters $PSBoundParameters -dottedPath 'ExclusionPatterns' -DefaultValue $defaultExclusionPatterns

    # Compile regex patterns for efficient matching
    $compiledExclusions = @()
    foreach ($pattern in $ExclusionPatterns) {
      try {
        $compiledExclusions += [regex]::new($pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Compiled exclusion pattern: $pattern"
      }
      catch {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "Invalid regex pattern '$pattern': $($_.Exception.Message)"
      }
    }

    # Validate Parameters
    if (-not (Test-Path -Path $SourcePath -PathType Container)) {
      $errorMessage = "Source path does not exist or is not a directory: $SourcePath"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw $errorMessage
    }

    if ($MinimumGroupSize -lt 1 -or $MinimumGroupSize -gt 100) {
      $errorMessage = "MinimumGroupSize must be between 1 and 100, received: $MinimumGroupSize"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw $errorMessage
    }
    if ($OutputFormat -notin @('Text', 'JSON', 'Object')) {
      $errorMessage = "Invalid OutputFormat: $OutputFormat. Valid options are 'Text', 'JSON', or 'Object'."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw $errorMessage
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Analyzing folder structure in: $SourcePath"
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "MinimumGroupSize is $MinimumGroupSize"
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "IncludeExistingParents is $IncludeExistingParents"
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "OutputFormat is $OutputFormat"
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Using $($ExclusionPatterns.Count) exclusion patterns"
  }

  process {
    try {
      # Get all directories in the source path (first level only)
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Getting all directories in source path'
      $allFolders = Get-ChildItem -Path $SourcePath -Directory -ErrorAction Stop | Select-Object -ExpandProperty Name

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Found $($allFolders.Count) folders to analyze"

      # Filter out excluded folders based on regex patterns
      $filteredFolders = @()
      foreach ($folder in $allFolders) {
        $excluded = $false
        foreach ($regex in $compiledExclusions) {
          if ($regex.IsMatch($folder)) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Excluding folder '$folder' (matched pattern: $($regex.ToString()))"
            $excluded = $true
            break
          }
        }
        if (-not $excluded) {
          $filteredFolders += $folder
        }
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "After exclusions: $($filteredFolders.Count) folders remain"

      # Group folders by their potential parent (all parts except the last)
      $groupedFolders = @{}

      foreach ($folder in $filteredFolders) {
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

        # Skip if parent name matches exclusion patterns
        $parentExcluded = $false
        foreach ($regex in $compiledExclusions) {
          if ($regex.IsMatch($parentName)) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Skipping parent '$parentName' - matches exclusion pattern: $($regex.ToString())"
            $parentExcluded = $true
            break
          }
        }
        if ($parentExcluded) {
          continue
        }

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

        # Generate detailed action plan
        $actionPlan = @()
        $gitMoveCommands = @()
        $createItems = @()

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

            # Plan: Move parent project to Model subfolder first
            $actionPlan += "1. Rename parent project folder to Model subfolder to resolve conflict"
            $gitMoveCommands += "git mv `"src/$parentName`" `"src/$parentName.Model`""
            $actionPlan += "2. Create new parent container folder: $parentName"
            $createItems += "Parent folder: src/$parentName"
            $actionPlan += "3. Move Model subfolder under parent"
            $gitMoveCommands += "git mv `"src/$parentName.Model`" `"src/$parentName/Model`""
          }
          elseif ($parentHasProject) {
            $conflictType = 'ParentHasProject'
            $recommendedAction = 'Moderate refactor - move parent project to subfolder, then move peer folders.'
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Conflict detected for $parentName - parent has project file"

            # Plan: Rename existing folder to Model, create new parent, move Model under parent
            $actionPlan += "1. Rename existing project folder to temporary name with Model suffix"
            $gitMoveCommands += "git mv `"src/$parentName`" `"src/$parentName.Model`""
            $actionPlan += "2. Create new parent container folder"
            $createItems += "Parent folder: src/$parentName"
            $createItems += "Properties folder: src/$parentName/Properties"
            $actionPlan += "3. Move renamed folder under parent as Model subfolder"
            $gitMoveCommands += "git mv `"src/$parentName.Model`" `"src/$parentName/Model`""
          }
          elseif ($parentHasSubfolders) {
            $conflictType = 'ParentHasSubfolders'
            if ($IncludeExistingParents) {
              $recommendedAction = 'Simple refactor - parent already exists with subfolders, just move peer folders.'
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Parent $parentName has subfolders but including due to -IncludeExistingParents"

              $actionPlan += "1. Parent folder already exists with subfolders"
              # Check if Properties folder exists
              $propertiesPath = Join-Path -Path $parentPath -ChildPath 'Properties'
              if (-not (Test-Path -Path $propertiesPath)) {
                $createItems += "Properties folder: src/$parentName/Properties"
              }
            }
            else {
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Skipping $parentName - parent has subfolders (use -IncludeExistingParents to include)"
              continue
            }
          }
        }
        else {
          # Parent doesn't exist - straightforward case
          $actionPlan += "1. Create parent container folder"
          $createItems += "Parent folder: src/$parentName"
          $createItems += "Properties folder: src/$parentName/Properties"
        }

        # Process each candidate folder to generate move commands
        foreach ($candidateFolder in $candidates) {
          # Extract role name from folder name (last segment after final dot)
          $roleName = ($candidateFolder -split '\.')[-1]

          # Determine target subfolder name and path
          $targetSubfolder = $roleName
          $targetPath = "src/$parentName/$targetSubfolder"

          $actionPlan += "Move $candidateFolder to $targetSubfolder/"
          $gitMoveCommands += "git mv `"src/$candidateFolder`" `"$targetPath`""
        }

        # Add facade project creation to plan
        # Note: Per refactor prompt (line 95-96), create facade project within each parent container,
        # NOT in the root of SourcePath. This creates it at src/{ParentName}/{ParentName}.csproj
        $facadeProjectPath = "src/$parentName/$parentName.csproj"
        $createItems += "Facade project: $facadeProjectPath"
        $actionPlan += "Create facade .csproj file that references all child projects"

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
          ActionPlan            = $actionPlan
          GitMoveCommands       = $gitMoveCommands
          ItemsToCreate         = $createItems
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
            Write-Output ""
            Write-Output "Action Plan:"
            $result.ActionPlan | ForEach-Object { Write-Output "  $_" }
            Write-Output ""
            Write-Output "Items to Create:"
            $result.ItemsToCreate | ForEach-Object { Write-Output "  - $_" }
            Write-Output ""
            Write-Output "Git Move Commands:"
            $result.GitMoveCommands | ForEach-Object { Write-Output "  $_" }
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
# Export-ModuleMember -Function Get-RefactoringCandidates
