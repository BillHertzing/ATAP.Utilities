<#
.SYNOPSIS
Copies the shared .claude, .github, and .vscode folders from the SharedVSCode sprint
worktree into the active sprint worktree of every other repo listed in Overview.code-workspace.

.DESCRIPTION
This function auto-discovers all paths using the following algorithm:

1. Runs git rev-parse --show-toplevel from the current (or specified) working directory
   to find the root of the current worktree.
2. Goes one folder up from the worktree root and looks for Overview.code-workspace.
3. Parses Overview.code-workspace to get the list of workspace folder paths.
4. Verifies that at least one entry matches the pattern 'SharedVSCode'.
5. Finds the directory directly under the Overview parent that matches
   SharedVSCode-wt-* — this is the sprint worktree for the shared sources.
6. Confirms that .claude, .github, and .vscode all exist inside that worktree.
7. For each other folder name in the workspace list, searches under the Overview parent
   for a directory matching '<folderName>-wt-*'. This is the sprint worktree for that repo.
   - If zero matches are found the folder is skipped with a warning.
   - If more than one match is found the function throws and stops immediately.
   - If exactly one match is found, .claude, .github and .vscode are copied into it.
   Any existing directory (including a junction or symlink) at the destination is
   removed before the copy so the content is always fresh.

The function can be invoked from any directory inside any worktree.

.PARAMETER WorkingDirectory
The directory from which git is invoked to locate the current worktree root.
Defaults to the current working directory (Get-Location).

.OUTPUTS
System.Management.Automation.PSCustomObject
Returns a result object containing:
  - Success       (bool)   : $true when all copies completed without errors
  - SourceWorktree (string): Full path to the SharedVSCode-wt-* folder used as the source
  - FoldersCopied (array)  : One entry per subfolder-per-target: SubFolder, Source, Destination
  - Errors        (array)  : Error/warning messages accumulated during the run

.EXAMPLE
Sync-WorktreeShared

Run from any directory inside a worktree. Discovers everything automatically and
copies .claude, .github, and .vscode to all sibling worktrees.

.EXAMPLE
$result = Sync-WorktreeShared -WhatIf
$result.FoldersCopied

Preview what would be copied without making any changes.

.EXAMPLE
$result = Sync-WorktreeShared -WorkingDirectory 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-91-sprint-0003-work-items'
if (-not $result.Success) {
    $result.Errors | ForEach-Object { Write-Warning $_ }
}

Explicitly specify the starting directory and inspect any errors.

.NOTES
AI assisted using Powershell.instructions.md as guidelines
Requires git to be installed and available in PATH.
Designed for Windows (PowerShell 7+). Junction/symlink removal uses DirectoryInfo.Delete().
Overview.code-workspace folder paths may be relative (resolved against the file's parent).

.LINK
https://github.com/BillHertzing/ATAP.Utilities
#>
function Sync-WorktreeShared {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [Parameter(
      Mandatory = $false,
      Position = 0,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $true,
      HelpMessage = 'Directory from which git is invoked. Defaults to the current working directory.'
    )]
    [ValidateScript({ Test-Path $_ -PathType Container })]
    [string]$WorkingDirectory = (Get-Location).Path
  )

  BEGIN {
    $fn = 'Sync-WorktreeShared'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    $sharedFolderNames = @('.claude', '.github', '.vscode')

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    $result = [PSCustomObject]@{
      Success        = $false
      SourceWorktree = $null
      FoldersCopied  = @()
      Errors         = @()
    }
  }

  PROCESS {
    try {
      # ----------------------------------------------------------------
      # Step 1: Locate the root of the current worktree via git
      # ----------------------------------------------------------------
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Locating worktree root from '$WorkingDirectory'"

      try {
        $gitOutput = git -C $WorkingDirectory rev-parse --show-toplevel 2>&1 | Out-String
        $worktreeRoot = $gitOutput.Trim()
        if ($LASTEXITCODE -ne 0) {
          throw "git rev-parse --show-toplevel failed (exit $LASTEXITCODE): $worktreeRoot"
        }
        # git outputs forward slashes on Windows; normalise to backslashes
        $worktreeRoot = $worktreeRoot.Replace('/', '\')
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Worktree root: '$worktreeRoot'"
      }
      catch {
        $errorMessage = "Failed to determine worktree root: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        $result.Errors += $errorMessage
        return $result
      }

      # ----------------------------------------------------------------
      # Step 2: Go up one level and find Overview.code-workspace
      # ----------------------------------------------------------------
      $overviewParent = Split-Path $worktreeRoot -Parent
      $workspaceFile = Join-Path $overviewParent 'Overview.code-workspace'
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Looking for workspace file at '$workspaceFile'"

      if (-not (Test-Path $workspaceFile -PathType Leaf)) {
        $errorMessage = "Overview.code-workspace not found at '$workspaceFile'"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        $result.Errors += $errorMessage
        return $result
      }

      # ----------------------------------------------------------------
      # Step 3: Parse workspace file and resolve folder paths
      # ----------------------------------------------------------------
      try {
        $workspaceJson = Get-Content $workspaceFile -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
      }
      catch {
        $errorMessage = "Failed to parse '$workspaceFile': $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        $result.Errors += $errorMessage
        return $result
      }

      if (-not $workspaceJson.folders -or $workspaceJson.folders.Count -eq 0) {
        $errorMessage = "Overview.code-workspace contains no 'folders' entries"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        $result.Errors += $errorMessage
        return $result
      }

      # Resolve each path relative to the workspace file's parent directory
      $folderPaths = @(foreach ($entry in $workspaceJson.folders) {
          $raw = $entry.path
          if ([System.IO.Path]::IsPathRooted($raw)) {
            $raw
          }
          else {
            [System.IO.Path]::GetFullPath((Join-Path $overviewParent $raw))
          }
        })

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Workspace contains $($folderPaths.Count) folder(s)"

      # ----------------------------------------------------------------
      # Step 4: Verify at least one folder matches 'SharedVSCode'
      # ----------------------------------------------------------------
      $sharedVSCodeMatch = @($folderPaths | Where-Object { $_ -match 'SharedVSCode' })
      if ($sharedVSCodeMatch.Count -eq 0) {
        $errorMessage = "No folder matching 'SharedVSCode' found in Overview.code-workspace"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        $result.Errors += $errorMessage
        return $result
      }

      # ----------------------------------------------------------------
      # Step 5: Find the SharedVSCode-wt-* sprint worktree directory
      # ----------------------------------------------------------------
      $sharedWorktreeCandidates = @(Get-ChildItem -Path $overviewParent -Directory -Force -ErrorAction Stop |
        Where-Object { $_.Name -match '^SharedVSCode-wt-' })

      if ($sharedWorktreeCandidates.Count -eq 0) {
        $errorMessage = "No folder matching 'SharedVSCode-wt-*' found under '$overviewParent'"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        $result.Errors += $errorMessage
        return $result
      }

      if ($sharedWorktreeCandidates.Count -gt 1) {
        $names = ($sharedWorktreeCandidates | Select-Object -ExpandProperty Name) -join "', '"
        $errorMessage = "Multiple SharedVSCode-wt-* folders found: '$names'. Cannot determine which to use as source."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        $result.Errors += $errorMessage
        return $result
      }

      $sharedWorktree = $sharedWorktreeCandidates[0].FullName
      $result.SourceWorktree = $sharedWorktree
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "SharedVSCode sprint worktree: '$sharedWorktree'"

      # ----------------------------------------------------------------
      # Step 6: Verify .claude, .github, .vscode exist in the source
      # ----------------------------------------------------------------
      foreach ($subFolder in $sharedFolderNames) {
        $subFolderPath = Join-Path $sharedWorktree $subFolder
        if (-not (Test-Path $subFolderPath -PathType Container)) {
          $errorMessage = "Required shared subfolder '$subFolder' not found in '$sharedWorktree'"
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
          $result.Errors += $errorMessage
        }
      }

      if ($result.Errors.Count -gt 0) {
        return $result
      }

      # ----------------------------------------------------------------
      # Step 7: For each non-SharedVSCode folder in the workspace list,
      #         find its sprint worktree (<folderName>-wt-*) and copy
      #         the three shared subfolders into it.
      # ----------------------------------------------------------------

      # Collect just the leaf folder names that are NOT the SharedVSCode source
      $sharedWorktreeNormalized = $sharedWorktree.TrimEnd('\').ToLowerInvariant()

      $otherFolderNames = @(foreach ($fp in $folderPaths) {
          $leafName = Split-Path $fp -Leaf
          # Skip if this resolved path IS the SharedVSCode sprint worktree
          if ($fp.TrimEnd('\').ToLowerInvariant() -eq $sharedWorktreeNormalized) { continue }
          # Skip the SharedVSCode main repo entry (the pattern used to locate the source)
          if ($leafName -match 'SharedVSCode') { continue }
          $leafName
        })

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Looking for sprint worktrees for $($otherFolderNames.Count) other repo(s)"

      foreach ($repoName in $otherFolderNames) {
        # Find <repoName>-wt-* directories directly under the Overview parent
        $sprintCandidates = @(Get-ChildItem -Path $overviewParent -Directory -Force -ErrorAction Stop |
          Where-Object { $_.Name -match "^$([regex]::Escape($repoName))-wt-" })

        if ($sprintCandidates.Count -eq 0) {
          $warnMessage = "No sprint worktree matching '$repoName-wt-*' found under '$overviewParent' — skipping"
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message $warnMessage
          $result.Errors += $warnMessage
          continue
        }

        if ($sprintCandidates.Count -gt 1) {
          $names = ($sprintCandidates | Select-Object -ExpandProperty Name) -join "', '"
          $errorMessage = "Multiple sprint worktrees found for '$repoName': '$names'. Cannot determine target — aborting."
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
          $result.Errors += $errorMessage
          throw $errorMessage
        }

        $targetFolder = $sprintCandidates[0].FullName
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Target sprint worktree for '$repoName': '$targetFolder'"

        foreach ($subFolder in $sharedFolderNames) {
          $sourceSubFolder = Join-Path $sharedWorktree $subFolder
          $destSubFolder = Join-Path $targetFolder $subFolder

          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Copy '$sourceSubFolder' -> '$destSubFolder'"

          if ($PSCmdlet.ShouldProcess($destSubFolder, "Sync shared folder '$subFolder' into '$repoName' sprint worktree")) {
            try {
              # Remove any existing content or junction at the destination
              if (Test-Path $destSubFolder) {
                $destItem = Get-Item -Path $destSubFolder -Force -ErrorAction Stop
                if ($destItem.LinkType) {
                  # Junction or symlink — delete the link without touching the target
                  $destItem.Delete()
                  Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Removed $($destItem.LinkType) at '$destSubFolder'"
                }
                else {
                  Remove-Item -Path $destSubFolder -Recurse -Force -ErrorAction Stop
                  Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Removed directory '$destSubFolder'"
                }
              }

              Copy-Item -Path $sourceSubFolder -Destination $destSubFolder -Recurse -Force -ErrorAction Stop

              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Copied '$subFolder' -> '$targetFolder'"

              $result.FoldersCopied += [PSCustomObject]@{
                SubFolder   = $subFolder
                Source      = $sourceSubFolder
                Destination = $destSubFolder
              }
            }
            catch {
              $errorMessage = "Failed to copy '$subFolder' to '$targetFolder': $($_.Exception.Message)"
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
              $result.Errors += $errorMessage
            }
          }
        }
      }

      $result.Success = ($result.Errors.Count -eq 0)

      if ($result.Success) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Sync-WorktreeShared completed successfully ($($result.FoldersCopied.Count) copy operation(s) performed)"
      }
      else {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Sync-WorktreeShared completed with $($result.Errors.Count) error(s)"
      }
    }
    catch {
      $errorMessage = "Unexpected error in Sync-WorktreeShared: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      $result.Errors += $errorMessage
      $result.Success = $false
    }

    return $result
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
