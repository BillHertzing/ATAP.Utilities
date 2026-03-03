<#
.SYNOPSIS
Creates a git worktree and recreates all junction points from the source repository.

.DESCRIPTION
This function creates a new git worktree for a specified branch and then scans the source
repository for junction points (directory symbolic links). All junctions found in the source
repository are recreated in the new worktree with the same relative paths and targets.

This is useful when working with repositories that use junctions for shared configuration
or dependencies, ensuring the worktree maintains the same structure as the main repository.

.PARAMETER SourceRepoPath
The absolute path to the source git repository. This is the main repository from which
the worktree will be created and junctions will be scanned.

.PARAMETER WorktreePath
The path where the new worktree will be created. Can be relative or absolute.
Example: "..\ATAP.Utilities-branch63"

.PARAMETER BranchName
The name of the git branch to checkout in the new worktree.
Example: "63-update-atap-utilities-database-scripts"

.OUTPUTS
System.Management.Automation.PSCustomObject
Returns a result object containing:
  - Success (bool): Whether the operation completed successfully
  - WorktreePath (string): The full path to the created worktree
  - JunctionsCreated (int): Number of junctions recreated
  - JunctionsList (array): List of junctions created with their targets
  - Errors (array): Any errors encountered during the operation

.EXAMPLE
New-WorktreeWithJunctions -SourceRepoPath 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities' -WorktreePath '..\ATAP.Utilities-branch63' -BranchName '63-update-atap-utilities-database-scripts'

Creates a new worktree in the parent directory for branch 63 and recreates all junctions.

.EXAMPLE
$result = New-WorktreeWithJunctions -SourceRepoPath 'C:\repos\MyProject' -WorktreePath 'C:\worktrees\feature-branch' -BranchName 'feature/new-feature'
if ($result.Success) {
    Write-Output "Created worktree with $($result.JunctionsCreated) junctions"
}

Creates a worktree and checks the result object for success.

.NOTES
AI assisted using Powershell.instructions.md as guidelines
Requires git to be installed and available in the PATH.
The source repository must be a valid git repository.
Junction points are Windows-specific; this cmdlet is designed for Windows environments.

.LINK
https://github.com/BillHertzing/ATAP.Utilities
#>
function New-WorktreeWithJunctions {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(
            Mandatory = $true,
            Position = 0,
            ValueFromPipeline = $false,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'The absolute path to the source git repository'
        )]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-Path $_ -PathType Container })]
        [string]$SourceRepoPath,

        [Parameter(
            Mandatory = $true,
            Position = 1,
            ValueFromPipeline = $false,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'The path where the new worktree will be created'
        )]
        [ValidateNotNullOrEmpty()]
        [string]$WorktreePath,

        [Parameter(
            Mandatory = $true,
            Position = 2,
            ValueFromPipeline = $false,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'The name of the git branch to checkout in the new worktree'
        )]
        [ValidateNotNullOrEmpty()]
        [string]$BranchName
    )

    BEGIN {
        $fn = 'New-WorktreeWithJunctions'
        $mn = 'ATAP.Utilities.BuildTooling.PowerShell'

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

        # Snippet: Check and populate simple parameter as Type
        # Parameter: SourceRepoPath
        if (-not $PSBoundParameters.ContainsKey('SourceRepoPath') -or [string]::IsNullOrWhiteSpace($SourceRepoPath)) {
            $errorMessage = 'Parameter SourceRepoPath is required but was not provided or is empty'
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
            throw $errorMessage
        }

        # Resolve and validate source repository path
        try {
            $SourceRepoPath = Resolve-Path $SourceRepoPath -ErrorAction Stop
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Source repository path resolved to: $SourceRepoPath"
        }
        catch {
            $errorMessage = "Failed to resolve SourceRepoPath: $($_.Exception.Message)"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
            throw $errorMessage
        }

        # Verify git is available
        try {
            $gitVersion = git --version 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw 'git command failed'
            }
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Git is available: $gitVersion"
        }
        catch {
            $errorMessage = 'git is not installed or not available in PATH'
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
            throw $errorMessage
        }

        # Snippet: Check and populate simple parameter
        # Parameter: WorktreePath
        if (-not $PSBoundParameters.ContainsKey('WorktreePath') -or [string]::IsNullOrWhiteSpace($WorktreePath)) {
            $errorMessage = 'Parameter WorktreePath is required but was not provided or is empty'
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
            throw $errorMessage
        }

        # Snippet: Check and populate simple parameter
        # Parameter: BranchName
        if (-not $PSBoundParameters.ContainsKey('BranchName') -or [string]::IsNullOrWhiteSpace($BranchName)) {
            $errorMessage = 'Parameter BranchName is required but was not provided or is empty'
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
            throw $errorMessage
        }

        # Initialize result object
        $result = [PSCustomObject]@{
            Success          = $false
            WorktreePath     = $null
            JunctionsCreated = 0
            JunctionsList    = @()
            Errors           = @()
        }

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'All parameters validated successfully'
    }

    PROCESS {
        try {
            # Step 1: Create the worktree
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Creating worktree at '$WorktreePath' for branch '$BranchName'"

            if ($PSCmdlet.ShouldProcess("$WorktreePath", "Create git worktree for branch '$BranchName'")) {
                # Snippet: Try-Catch-Finally
                try {
                    $gitOutput = git -C $SourceRepoPath worktree add $WorktreePath $BranchName 2>&1 | Out-String
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Git worktree output: $gitOutput"
                    if ($LASTEXITCODE -ne 0) {
                        $gitError = $gitOutput.Trim()
                        throw "git worktree add command failed with exit code ${LASTEXITCODE}. Git output: $gitError"
                    }
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Git worktree created successfully'
                }
                catch {
                    $errorMessage = "Failed to create git worktree: $($_.Exception.Message)"
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
                    $result.Errors += $errorMessage
                    throw
                }

                # Resolve the full worktree path
                try {
                    $WorktreeFullPath = Resolve-Path $WorktreePath -ErrorAction Stop
                    $result.WorktreePath = $WorktreeFullPath.Path
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Worktree path resolved to: $WorktreeFullPath"
                }
                catch {
                    $errorMessage = "Failed to resolve WorktreePath after creation: $($_.Exception.Message)"
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
                    $result.Errors += $errorMessage
                    throw
                }

                # Step 2: Find all junctions in the source repo
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Scanning for junctions in '$SourceRepoPath'"

                try {
                    $junctions = Get-ChildItem -Path $SourceRepoPath -Recurse -Force -Attributes ReparsePoint -ErrorAction Stop |
                    Where-Object { $_.LinkType -eq 'Junction' }

                    if (-not $junctions) {
                        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'No junctions found in source repository'
                        $result.Success = $true
                        return $result
                    }

                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Found $($junctions.Count) junction(s). Recreating in worktree"

                    # Step 3: Recreate junctions in worktree
                    foreach ($junction in $junctions) {
                        try {
                            # Compute the relative path from source repo root
                            $relativePath = $junction.FullName.Substring($SourceRepoPath.Path.Length).TrimStart('\')

                            # Target path in the new worktree
                            $newJunctionPath = Join-Path $WorktreeFullPath $relativePath

                            # Junction's current target
                            $target = $junction.Target

                            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Processing junction: $relativePath -> $target"

                            # Ensure the parent directory exists in the worktree
                            $parentDir = Split-Path $newJunctionPath -Parent
                            if (-not (Test-Path $parentDir)) {
                                New-Item -ItemType Directory -Path $parentDir -Force -ErrorAction Stop | Out-Null
                                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Created parent directory: $parentDir"
                            }

                            # Remove placeholder folder if git created one, then create junction
                            if (Test-Path $newJunctionPath) {
                                Remove-Item $newJunctionPath -Force -Recurse -ErrorAction Stop
                                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Removed existing item at: $newJunctionPath"
                            }

                            # Create the junction
                            New-Item -ItemType Junction -Path $newJunctionPath -Target $target -ErrorAction Stop | Out-Null
                            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Created junction: $newJunctionPath -> $target"

                            $result.JunctionsCreated++
                            $result.JunctionsList += [PSCustomObject]@{
                                RelativePath = $relativePath
                                Target       = $target
                                FullPath     = $newJunctionPath
                            }
                        }
                        catch {
                            $errorMessage = "Failed to create junction '$relativePath': $($_.Exception.Message)"
                            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
                            $result.Errors += $errorMessage
                            # Continue processing other junctions
                        }
                    }

                    $result.Success = $true
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Worktree setup complete with $($result.JunctionsCreated) junction(s) recreated"
                }
                catch {
                    $errorMessage = "Failed to scan or recreate junctions: $($_.Exception.Message)"
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
                    $result.Errors += $errorMessage
                    throw
                }
            }
        }
        catch {
            $errorMessage = "New-WorktreeWithJunctions failed: $($_.Exception.Message)"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
            $result.Success = $false
            if (-not $result.Errors.Contains($errorMessage)) {
                $result.Errors += $errorMessage
            }
            throw
        }
    }

    END {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
        $result
    }
}
