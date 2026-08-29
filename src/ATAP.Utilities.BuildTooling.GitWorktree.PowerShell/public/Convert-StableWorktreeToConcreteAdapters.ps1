<#
.SYNOPSIS
De-junctions a stable repository root's AI-adapter folders and restores their tracked,
concrete git content.

.DESCRIPTION
Sprint 0011/0012 moved the AI-adapter model to concrete, git-tracked directories
(`.claude`, `.github`) as the canonical form (SC-0231 decision); `.vscode` remains a
junction by design. Some stable worktrees still carry `.claude`/`.github` as NTFS
junctions left over from the older dev-redirect model, so a plain `git status` /
checkout on stable sees a junction where the branch actually has real tracked files.

For each requested folder name under RepoRoot, this function:
  1. Skips the folder if it does not exist, or if it exists but is not a junction
     (nothing to convert).
  2. Refuses to touch a folder if the index carries a normalized content delta under
     that folder — the caller must resolve those staged changes first. Worktree-only
     and untracked paths remain outside this deliberately index-only quarantine.
  3. Removes the junction with `cmd /c rmdir` (NEVER `Remove-Item -Recurse`, which
     deletes the junction TARGET's contents rather than the junction pointer itself).
  4. Runs `git -C <RepoRoot> checkout -- <folder>` to restore the tracked concrete
     content from the current HEAD.

Every mutation is guarded by `ShouldProcess`, so `-WhatIf` previews the full plan
(including the staged-changes refusal check, which is read-only) without removing any
junction or invoking `git checkout`.

.PARAMETER RepoRoot
Absolute path to the repository root (a stable worktree) whose junctioned adapter
folders should be converted to concrete, tracked content.

.PARAMETER FolderNames
Names of the folders under RepoRoot to convert. Defaults to '.claude', '.github'.
Do NOT include '.vscode' here — it intentionally remains a junction (SC-0231).

.OUTPUTS
System.Management.Automation.PSCustomObject with RepoRoot, a per-folder Results array
(Folder, Path, WasJunction, JunctionTarget, StagedChangesBlocked, Removed, Restored,
Skipped, SkipReason, Error), and an aggregate Errors array.

.EXAMPLE
Convert-StableWorktreeToConcreteAdapters -RepoRoot 'C:\Dropbox\whertzing\GitHub\_Planning'

Converts '.claude' and '.github' from junctions to concrete tracked directories in the
_Planning stable worktree.

.EXAMPLE
Convert-StableWorktreeToConcreteAdapters -RepoRoot 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities' -WhatIf

Previews the conversion without removing any junction or mutating the worktree.

.NOTES
AI assisted using ./.claude/Rules/Powershell.md as guidelines.
Board Task 12.1 / plan Task 12.2.a (Sprint 0012, Stream A). This function is
execution-only tooling for board Task 12.2.b's HITL one-time stable-worktree
migration; running it against a stable worktree is an explicit stable-maintenance
action and must be confirmed with the user first.

.LINK
Set-WorktreeJunctions
#>
function Convert-StableWorktreeToConcreteAdapters {
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$RepoRoot,

    [Parameter(Position = 1)]
    [string[]]$FolderNames = @('.claude', '.github')
  )

  begin {
    $fn = 'Convert-StableWorktreeToConcreteAdapters'
    $mn = 'ATAP.Utilities.BuildTooling.GitWorktree.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn (RepoRoot=$RepoRoot)"

    $resolvedRepoRoot = (Resolve-Path -LiteralPath $RepoRoot -ErrorAction Stop).Path

    $gitCheck = git -C $resolvedRepoRoot rev-parse --is-inside-work-tree 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0 -or $gitCheck.Trim() -ne 'true') {
      throw "RepoRoot '$resolvedRepoRoot' is not a git repository"
    }

    $results = [System.Collections.Generic.List[object]]::new()
    $errors = [System.Collections.Generic.List[string]]::new()
  }

  process {
    foreach ($folderName in $FolderNames) {
      $folderPath = Join-Path $resolvedRepoRoot $folderName
      $entry = [ordered]@{
        Folder               = $folderName
        Path                 = $folderPath
        WasJunction          = $false
        JunctionTarget       = $null
        StagedChangesBlocked = $false
        Removed              = $false
        Restored             = $false
        Skipped              = $false
        SkipReason           = $null
        Error                = $null
      }

      try {
        if (-not (Test-Path -LiteralPath $folderPath)) {
          $entry.Skipped = $true
          $entry.SkipReason = 'Folder does not exist'
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Skipping '$folderPath': does not exist"
          $results.Add([PSCustomObject]$entry)
          continue
        }

        $item = Get-Item -LiteralPath $folderPath -Force
        if ($item.LinkType -ne 'Junction') {
          $entry.Skipped = $true
          $entry.SkipReason = "Not a junction (LinkType='$($item.LinkType)')"
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Skipping '$folderPath': not a junction"
          $results.Add([PSCustomObject]$entry)
          continue
        }

        $entry.WasJunction = $true
        $entry.JunctionTarget = $item.Target | Select-Object -First 1

        # This quarantine is intentionally index-only. Git's diff machinery compares
        # normalized blob content, so an EOL-only worktree representation does not
        # become a false staged change. Worktree-only and untracked paths remain safe.
        git -C $resolvedRepoRoot diff --cached --quiet -- $folderName
        $stagedDiffExitCode = $LASTEXITCODE
        if ($stagedDiffExitCode -gt 1) {
          throw "git diff --cached --quiet failed for '$folderName' (exit code $stagedDiffExitCode)"
        }
        if ($stagedDiffExitCode -eq 1) {
          $stagedLines = @(git -C $resolvedRepoRoot diff --cached --name-status -- $folderName 2>&1)
          if ($LASTEXITCODE -ne 0) {
            throw "git diff --cached --name-status failed for '$folderName': $($stagedLines -join '; ')"
          }
          $entry.StagedChangesBlocked = $true
          $entry.SkipReason = "Refusing to convert '$folderName': staged content changes present ($($stagedLines -join '; '))"
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $entry.SkipReason
          $errors.Add($entry.SkipReason)
          $results.Add([PSCustomObject]$entry)
          continue
        }

        if ($PSCmdlet.ShouldProcess($folderPath, 'Remove junction and restore tracked concrete content')) {
          # Never use Remove-Item -Recurse on a junction: it deletes the junction
          # TARGET's contents. cmd /c rmdir removes only the junction pointer.
          cmd /c rmdir "$folderPath" 2>&1 | Out-Null
          if (Test-Path -LiteralPath $folderPath) {
            throw "Junction removal did not succeed for '$folderPath'"
          }
          $entry.Removed = $true
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Removed junction at '$folderPath' (target preserved: $($entry.JunctionTarget))"

          $checkoutOutput = git -C $resolvedRepoRoot checkout -- $folderName 2>&1
          if ($LASTEXITCODE -ne 0) {
            throw "git checkout -- '$folderName' failed: $($checkoutOutput -join '; ')"
          }
          $entry.Restored = $true
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Restored tracked concrete content for '$folderName' via git checkout"
        }
      } catch {
        $entry.Error = $_.Exception.Message
        $errors.Add("Conversion failed for '$folderName': $($_.Exception.Message)")
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Conversion failed for '$folderPath': $($_.Exception.Message)"
      }

      $results.Add([PSCustomObject]$entry)
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn ($($errors.Count) error(s))"
    [PSCustomObject]@{
      RepoRoot = $resolvedRepoRoot
      Results  = $results.ToArray()
      Errors   = $errors.ToArray()
    }
  }
}
