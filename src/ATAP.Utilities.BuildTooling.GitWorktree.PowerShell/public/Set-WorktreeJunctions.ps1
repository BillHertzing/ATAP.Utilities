<#
.SYNOPSIS
Gets junctions from a source repository and recreates matching junctions in an existing worktree.

.DESCRIPTION
This function scans the source repository for junction points (directory symbolic links).
All junctions found in the source repository are recreated in an existing worktree with the same
relative paths and targets.

This is useful when working with repositories that use junctions for shared configuration
or dependencies, ensuring an existing worktree maintains the same junction structure as the source repository.

This function can also remove an existing junction and replace it with a similar junction only pointing to a worktree
instance of the source folder. This is useful during development, to point junctions like .claude and .github to
an instance of the source folder that is being developed - it allows a development branch / worktree to access
folders a development / branch worktree in another repository

.PARAMETER SourceRepoPath
The absolute path to the source git repository. This is the main repository from which
junctions will be scanned.

.PARAMETER SourceRepoPathInfo
A file system path object for the source git repository (for example, DirectoryInfo,
FileInfo, or PathInfo). The underlying path must resolve to an existing directory.

.PARAMETER WorktreePath
The path to an existing worktree where junctions will be recreated. Can be relative or absolute.
Example: "..\ATAP.Utilities-branch63"

.PARAMETER DevSourceRepoPath
The path to an existing folder. Can be relative or absolute.
Example: "..\ATAP.Utilities-branch63"

.PARAMETER DevSourceRepoPathInfo
A file system path object to a folder (for example, DirectoryInfo, FileInfo, or PathInfo).
The underlying path must resolve to an existing directory.

.PARAMETER DevSourceRepoFolderNames
A string array containing the names of the folders in the source repository that should be
recreated as junctions in the worktree, but with their targets pointing to a development source repository.
This is useful for development scenarios where you want certain junctions to point to a different location
(like a development branch) while still maintaining the same relative paths.

.PARAMETER SourceRepoFolderNames
Optional string array containing the names of source-repository junction folders
that should be recreated in the worktree. When omitted, all source junctions are
recreated.

.OUTPUTS
System.Management.Automation.PSCustomObject
Returns a result object containing:
  - Success (bool): Whether the operation completed successfully
    - WorktreePath (string): The full path to the worktree
  - JunctionsCreated (int): Number of junctions recreated
  - JunctionsList (array): List of junctions created with their targets
  - Errors (array): Any errors encountered during the operation


.EXAMPLE
Set-WorktreeJunctions -SourceRepoPath 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities' -WorktreePath '..\ATAP.Utilities-branch63'

Scans the source repository and recreates matching junctions in an existing worktree.

.EXAMPLE
$result = Set-WorktreeJunctions -SourceRepoPath 'C:\repos\MyProject' -WorktreePath 'C:\workTrees\feature-branch'
if ($result.Success) {
    Write-Output "Created $($result.JunctionsCreated) junctions"
}

Recreates junctions in an existing worktree and checks the result object for success.

.NOTES
AI assisted using Powershell.instructions.md as guidelines
The source repository must be a valid git repository.
Junction points are Windows-specific; this cmdlet is designed for Windows environments.

.LINK
https://github.com/BillHertzing/ATAP.Utilities
#>
function Set-WorktreeJunctions {
    [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'ByPath')]
    param(
        [Parameter(
            Mandatory = $true,
            Position = 0,
            ParameterSetName = 'ByPath',
            ValueFromPipeline = $false,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'The absolute path to the source git repository'
        )]
        [Parameter(
            Mandatory = $true,
            Position = 0,
            ParameterSetName = 'ByPathWithDev',
            ValueFromPipeline = $false,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'The absolute path to the source git repository'
        )]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-Path $_ -PathType Container })]
        [string]$SourceRepoPath,

        [Parameter(
            Mandatory = $true,
            Position = 0,
            ParameterSetName = 'ByPathInfo',
            ValueFromPipeline = $false,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'A path object for the source git repository directory'
        )]
        [Parameter(
            Mandatory = $true,
            Position = 0,
            ParameterSetName = 'ByPathInfoWithDev',
            ValueFromPipeline = $false,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'A path object for the source git repository directory'
        )]
        [ValidateNotNull()]
        [object]$SourceRepoPathInfo,

        [Parameter(
            Mandatory = $true,
            Position = 1,
            ValueFromPipeline = $false,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'The path to an existing worktree where junctions will be recreated'
        )]
        [ValidateNotNullOrEmpty()]
        [string]$WorktreePath,

        [Parameter(
            Mandatory = $true,
            Position = 2,
            ParameterSetName = 'ByPathWithDev',
            ValueFromPipeline = $false,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'The path to an existing dev source folder whose sub-folders will be used as junction targets'
        )]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-Path $_ -PathType Container })]
        [string]$DevSourceRepoPath,

        [Parameter(
            Mandatory = $true,
            Position = 2,
            ParameterSetName = 'ByPathInfoWithDev',
            ValueFromPipeline = $false,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'A path object for the dev source folder whose sub-folders will be used as junction targets'
        )]
        [ValidateNotNull()]
        [object]$DevSourceRepoPathInfo,

        [Parameter(
            Mandatory = $true,
            Position = 3,
            ParameterSetName = 'ByPathWithDev',
            ValueFromPipeline = $false,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'Names of junction folders whose targets should be redirected to the dev source repository'
        )]
        [Parameter(
            Mandatory = $true,
            Position = 3,
            ParameterSetName = 'ByPathInfoWithDev',
            ValueFromPipeline = $false,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'Names of junction folders whose targets should be redirected to the dev source repository'
        )]
        [ValidateNotNullOrEmpty()]
        [string[]]$DevSourceRepoFolderNames,

        [Parameter()]
        [string[]]$SourceRepoFolderNames
    )

    begin {
        $fn = 'Set-WorktreeJunctions'
        $mn = 'ATAP.Utilities.BuildTooling.GitWorktree.PowerShell'
        $sourceRepoFullPath = $null
        $devSourceRepoFullPath = $null

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

        # Resolve and validate source repository path
        try {
            $sourceRepoInputPath = $null
            if ($PSCmdlet.ParameterSetName -in @('ByPath', 'ByPathWithDev')) {
                if (-not $PSBoundParameters.ContainsKey('SourceRepoPath') -or [string]::IsNullOrWhiteSpace($SourceRepoPath)) {
                    throw 'Parameter SourceRepoPath is required but was not provided or is empty'
                }
                $sourceRepoInputPath = $SourceRepoPath
            } else {
                if (-not $PSBoundParameters.ContainsKey('SourceRepoPathInfo') -or $null -eq $SourceRepoPathInfo) {
                    throw 'Parameter SourceRepoPathInfo is required but was not provided'
                }

                if ($SourceRepoPathInfo -is [System.Management.Automation.PathInfo]) {
                    $sourceRepoInputPath = $SourceRepoPathInfo.Path
                } elseif ($SourceRepoPathInfo -is [System.IO.FileSystemInfo]) {
                    $sourceRepoInputPath = $SourceRepoPathInfo.FullName
                } elseif ($SourceRepoPathInfo.PSObject.Properties.Name -contains 'FullName') {
                    $sourceRepoInputPath = $SourceRepoPathInfo.FullName
                } elseif ($SourceRepoPathInfo.PSObject.Properties.Name -contains 'Path') {
                    $sourceRepoInputPath = $SourceRepoPathInfo.Path
                }

                if ([string]::IsNullOrWhiteSpace($sourceRepoInputPath)) {
                    throw 'SourceRepoPathInfo must contain a usable path value via FullName or Path'
                }
            }

            $resolvedSourceRepoPath = Resolve-Path $sourceRepoInputPath -ErrorAction Stop
            if (-not (Test-Path $resolvedSourceRepoPath.Path -PathType Container)) {
                throw "Source repository path '$($resolvedSourceRepoPath.Path)' is not a directory"
            }

            $sourceRepoFullPath = $resolvedSourceRepoPath.Path
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Source repository path resolved to: $sourceRepoFullPath"
        } catch {
            $errorMessage = "Failed to resolve SourceRepoPath: $($_.Exception.Message)"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
            throw $errorMessage
        }

        # Resolve and validate worktree path
        try {
            $resolvedWorktreePath = Resolve-Path $WorktreePath -ErrorAction Stop
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Worktree path resolved to: $resolvedWorktreePath"
        } catch {
            $errorMessage = "Failed to resolve WorktreePath: $($_.Exception.Message)"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
            throw $errorMessage
        }

        # Verify source and worktree are different locations
        if ($sourceRepoFullPath -eq $resolvedWorktreePath.Path) {
            $errorMessage = 'SourceRepoPath and WorktreePath must be different paths'
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
            throw $errorMessage
        }

        # Verify source repo is a git repository
        try {
            $gitOutput = git -C $sourceRepoFullPath rev-parse --is-inside-work-tree 2>&1 | Out-String
            if ($LASTEXITCODE -ne 0 -or $gitOutput.Trim() -ne 'true') {
                throw "Path '$sourceRepoFullPath' is not a git repository"
            }
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Source repository validated as git repository'
        } catch {
            $errorMessage = "Failed to validate SourceRepoPath as git repository: $($_.Exception.Message)"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
            throw $errorMessage
        }

        # Require WorktreePath.
        if (-not $PSBoundParameters.ContainsKey('WorktreePath') -or [string]::IsNullOrWhiteSpace($WorktreePath)) {
            $errorMessage = 'Parameter WorktreePath is required but was not provided or is empty'
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
            throw $errorMessage
        }

        # Resolve and validate dev source repository path (only for Dev parameter sets)
        if ($PSCmdlet.ParameterSetName -in @('ByPathWithDev', 'ByPathInfoWithDev')) {
            try {
                $devSourceRepoInputPath = $null
                if ($PSCmdlet.ParameterSetName -eq 'ByPathWithDev') {
                    if (-not $PSBoundParameters.ContainsKey('DevSourceRepoPath') -or [string]::IsNullOrWhiteSpace($DevSourceRepoPath)) {
                        throw 'Parameter DevSourceRepoPath is required but was not provided or is empty'
                    }
                    $devSourceRepoInputPath = $DevSourceRepoPath
                } else {
                    if (-not $PSBoundParameters.ContainsKey('DevSourceRepoPathInfo') -or $null -eq $DevSourceRepoPathInfo) {
                        throw 'Parameter DevSourceRepoPathInfo is required but was not provided'
                    }

                    if ($DevSourceRepoPathInfo -is [System.Management.Automation.PathInfo]) {
                        $devSourceRepoInputPath = $DevSourceRepoPathInfo.Path
                    } elseif ($DevSourceRepoPathInfo -is [System.IO.FileSystemInfo]) {
                        $devSourceRepoInputPath = $DevSourceRepoPathInfo.FullName
                    } elseif ($DevSourceRepoPathInfo.PSObject.Properties.Name -contains 'FullName') {
                        $devSourceRepoInputPath = $DevSourceRepoPathInfo.FullName
                    } elseif ($DevSourceRepoPathInfo.PSObject.Properties.Name -contains 'Path') {
                        $devSourceRepoInputPath = $DevSourceRepoPathInfo.Path
                    }

                    if ([string]::IsNullOrWhiteSpace($devSourceRepoInputPath)) {
                        throw 'DevSourceRepoPathInfo must contain a usable path value via FullName or Path'
                    }
                }

                $resolvedDevSourceRepoPath = Resolve-Path $devSourceRepoInputPath -ErrorAction Stop
                if (-not (Test-Path $resolvedDevSourceRepoPath.Path -PathType Container)) {
                    throw "Dev source repository path '$($resolvedDevSourceRepoPath.Path)' is not a directory"
                }

                $devSourceRepoFullPath = $resolvedDevSourceRepoPath.Path
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Dev source repository path resolved to: $devSourceRepoFullPath"

                # Require DevSourceRepoFolderNames for the Dev parameter sets.
                if (-not $PSBoundParameters.ContainsKey('DevSourceRepoFolderNames') -or $null -eq $DevSourceRepoFolderNames -or $DevSourceRepoFolderNames.Count -eq 0) {
                    $errorMessage = 'Parameter DevSourceRepoFolderNames is required but was not provided or is empty'
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
                    throw $errorMessage
                }

                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Dev source folder names to redirect: $($DevSourceRepoFolderNames -join ', ')"
            } catch {
                $errorMessage = "Failed to resolve DevSourceRepoPath: $($_.Exception.Message)"
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
                throw $errorMessage
            }
        }

        # Initialize result object
        $result = [PSCustomObject]@{
            Success          = $false
            WorktreePath     = $resolvedWorktreePath.Path
            JunctionsCreated = 0
            JunctionsList    = @()
            Errors           = @()
        }

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'All parameters validated successfully'
    }

    process {
        try {
            # Step 1: Find all junctions in the source repo
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Scanning for junctions in '$sourceRepoFullPath'"

            if ($PSCmdlet.ShouldProcess("$($result.WorktreePath)", 'Recreate junctions from source repository')) {
                try {
                    $junctions = @(Get-ChildItem -Path $sourceRepoFullPath -Recurse -Force -Attributes ReparsePoint -ErrorAction Stop |
                        Where-Object { $_.LinkType -eq 'Junction' }
                    )

                    if ($PSBoundParameters.ContainsKey('SourceRepoFolderNames') -and @($SourceRepoFolderNames).Count -gt 0) {
                        $junctions = @(
                            $junctions |
                                Where-Object { $SourceRepoFolderNames -contains $_.Name }
                        )
                        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Filtered source junctions to: $($SourceRepoFolderNames -join ', ')"
                    }

                    if (-not $junctions) {
                        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'No junctions found in source repository'
                        $result.Success = $true
                        return $result
                    }

                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Found $($junctions.Count) junction(s). Recreating in worktree"

                    # Step 2: Recreate junctions in worktree
                    foreach ($junction in $junctions) {
                        try {
                            # Compute the relative path from source repo root
                            $relativePath = $junction.FullName.Substring($sourceRepoFullPath.Length).TrimStart('\\')

                            # Target path in the existing worktree
                            $newJunctionPath = Join-Path $result.WorktreePath $relativePath

                            # Junction's current target — redirect to dev source if folder name matches
                            $junctionLeafName = Split-Path $relativePath -Leaf
                            $target = $junction.Target
                            if ($devSourceRepoFullPath -and $DevSourceRepoFolderNames -contains $junctionLeafName) {
                                $devTarget = Join-Path $devSourceRepoFullPath $junctionLeafName
                                if (Test-Path $devTarget -PathType Container) {
                                    $target = $devTarget
                                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Redirecting junction '$junctionLeafName' to dev source: $target"
                                } else {
                                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Dev source folder '$devTarget' not found; using original target for '$junctionLeafName'"
                                }
                            }

                            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Processing junction: $relativePath -> $target"

                            # Ensure the parent directory exists in the worktree
                            $parentDir = Split-Path $newJunctionPath -Parent
                            if (-not (Test-Path $parentDir)) {
                                New-Item -ItemType Directory -Path $parentDir -Force -ErrorAction Stop | Out-Null
                                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Created parent directory: $parentDir"
                            }

                            # Remove existing item at the target path.
                            # Use 'cmd /c rmdir' for junctions to avoid deleting junction target contents.
                            if (Test-Path $newJunctionPath) {
                                $existingItem = Get-Item -LiteralPath $newJunctionPath -Force -ErrorAction Stop
                                if ($existingItem.LinkType -eq 'Junction') {
                                    cmd /c rmdir "$newJunctionPath"
                                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Removed existing junction at: $newJunctionPath"
                                } else {
                                    Remove-Item $newJunctionPath -Force -Recurse -ErrorAction Stop
                                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Removed existing item at: $newJunctionPath"
                                }
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
                        } catch {
                            $errorMessage = "Failed to create junction '$relativePath': $($_.Exception.Message)"
                            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
                            $result.Errors += $errorMessage
                            # Continue processing other junctions
                        }
                    }

                    $result.Success = $true
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Junction recreation complete with $($result.JunctionsCreated) junction(s) recreated"
                } catch {
                    $errorMessage = "Failed to scan or recreate junctions: $($_.Exception.Message)"
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
                    $result.Errors += $errorMessage
                    throw
                }
            } else {
                $result.Success = $true
            }
        } catch {
            $errorMessage = "Set-WorktreeJunctions failed: $($_.Exception.Message)"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
            $result.Success = $false
            if (-not $result.Errors.Contains($errorMessage)) {
                $result.Errors += $errorMessage
            }
            throw
        }
    }

    end {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
        $result
    }
}
