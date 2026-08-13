function Get-SprintWorktreeClassification {
  <#
  .SYNOPSIS
    Classifies a filesystem path as a sprint worktree, a stable worktree, or a
    location outside the Git root.

  .DESCRIPTION
    Task 14.10. SprintEnd must never write an implementation fix into a stable
    worktree: stable content is produced by merging the sprint branch, not by
    editing the stable checkout ahead of the merge. Every SprintEnd write-target
    decision reduces to the same question -- "is this path inside a sprint
    worktree?" -- so that question lives in exactly one testable place.

    A repository folder directly beneath GitRoot whose leaf name matches
    '<repo>-wt-<issue>-Sprint-<nnnn>-work-items' is a sprint worktree. Any other
    repository folder beneath GitRoot is a stable worktree. Anything not beneath
    GitRoot is unclassified and is treated as not writable without an explicit
    caller allowance.

    This is a pure path function. It performs no filesystem or Git access, so it
    classifies deleted, planned, and fabricated paths identically to live ones.
    Relative traversal is resolved first, so a sprint-prefixed path that escapes
    into a stable repository ('...-wt-1-Sprint-0014-work-items\..\Repo') is
    correctly classified as stable.

    Known limitation: because it never touches the filesystem, it cannot follow
    a symbolic link or NTFS junction. A link inside a sprint worktree whose
    target is a stable worktree classifies by its literal path and is allowed.
    Resolving links would require filesystem access and would forfeit the
    ability to gate planned paths, which is the more valuable property. Sprint
    worktree junctions are provisioned by Set-SprintBoundaryContext and point at
    '.vscode' only.

  .PARAMETER Path
    The path to classify. It does not need to exist.

  .PARAMETER GitRoot
    Root directory that contains every repository and sprint worktree.

  .OUTPUTS
    PSCustomObject with Path, GitRoot, RepositoryFolderName, RepositoryName,
    Classification, SprintNumber, IssueNumber, StableRepositoryPath,
    WriteAllowedDuringSprintEnd, and Reason.

  .EXAMPLE
    Get-SprintWorktreeClassification -Path 'C:\Repos\ATAP.Utilities' -GitRoot 'C:\Repos'

  .NOTES
    AI assisted using ./.claude/rules/Powershell.md as guidelines.
  #>
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Path,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$GitRoot
  )

  begin {
    $fn = 'Get-SprintWorktreeClassification'
    $mn = 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
    $sprintWorktreePattern = '^(?<repo>.+)-wt-(?<issue>\d+)-[Ss]print-(?<sprint>\d{3,4})-work-items$'
  }

  process {
    $fullPath = ([IO.Path]::GetFullPath($Path)).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $fullGitRoot = ([IO.Path]::GetFullPath($GitRoot)).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)

    $entry = [ordered]@{
      Path                        = $fullPath
      GitRoot                     = $fullGitRoot
      RepositoryFolderName        = $null
      RepositoryName              = $null
      Classification              = 'OutsideGitRoot'
      SprintNumber                = $null
      IssueNumber                 = $null
      StableRepositoryPath        = $null
      WriteAllowedDuringSprintEnd = $false
      Reason                      = $null
    }

    $gitRootPrefix = $fullGitRoot + [IO.Path]::DirectorySeparatorChar
    if (-not $fullPath.StartsWith($gitRootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
      $entry.Reason = "'$fullPath' is not beneath the Git root '$fullGitRoot'; SprintEnd will not write here without an explicit caller allowance."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message $entry.Reason
      return [PSCustomObject]$entry
    }

    $relative = $fullPath.Substring($gitRootPrefix.Length)
    $repositoryFolderName = ($relative -split '[\\/]', 2)[0]
    $entry.RepositoryFolderName = $repositoryFolderName
    $entry.RepositoryName = $repositoryFolderName

    $match = [regex]::Match($repositoryFolderName, $sprintWorktreePattern)
    if ($match.Success) {
      $entry.Classification = 'SprintWorktree'
      $entry.RepositoryName = $match.Groups['repo'].Value
      $entry.SprintNumber = $match.Groups['sprint'].Value
      $entry.IssueNumber = [int]$match.Groups['issue'].Value
      $entry.StableRepositoryPath = Join-Path $fullGitRoot $match.Groups['repo'].Value
      $entry.WriteAllowedDuringSprintEnd = $true
      $entry.Reason = "'$repositoryFolderName' is the Sprint $($entry.SprintNumber) worktree for '$($entry.RepositoryName)'; SprintEnd writes belong here."
    } else {
      $entry.Classification = 'StableWorktree'
      $entry.StableRepositoryPath = Join-Path $fullGitRoot $repositoryFolderName
      $entry.WriteAllowedDuringSprintEnd = $false
      $entry.Reason = "'$repositoryFolderName' is a stable repository worktree. SprintEnd must not write implementation changes here; stable content arrives by merging the sprint branch."
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message $entry.Reason
    return [PSCustomObject]$entry
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
