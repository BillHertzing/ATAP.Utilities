#############################################################################
#region Get-GitFileDates
<#
.SYNOPSIS
Returns first-commit and last-commit dates per file in a git repository, using one history walk.

.DESCRIPTION
Runs a single `git log --name-only` walk over the history reachable from HEAD and builds a map of
repo-relative path -> FirstCommitDate (oldest commit touching the path), LastCommitDate (newest),
and CommitCount. Emits one record per path, or — when -RelativePath is supplied — one record per
requested path, with IsTracked = $false and null dates for paths absent from history.

This is the DR-1.2 building block of the ATAP Documentation Review program
(_Planning\DocumentationReview\DocumentationReview-Plan.md). Because documentation files live under
git control, filesystem timestamps are unreliable; the first/last commit dates are the program's
creation/modification proxies.

Rename tradeoff (documented per DR-1.2.b): the batch walk does not follow renames, so a renamed
file's FirstCommitDate reflects the commit that created its CURRENT name. Per-file
`git log --follow` is deliberately not used here (1,600+ invocations is prohibitively slow); run it
manually for individual files flagged as suspiciously young.

.PARAMETER RepositoryRoot
Root of the git repository or worktree to walk. Must contain a resolvable git work tree.

.PARAMETER RelativePath
Optional repo-relative path(s) (either slash style) to look up, bindable from the pipeline by
property name so inventory records can be piped in. When omitted, every path in history is emitted.

.INPUTS
Objects with a RelativePath property (e.g., Get-DocumentationFileInventory output).

.OUTPUTS
PSCustomObject with properties: RelativePath (backslash-normalized), FirstCommitDate,
LastCommitDate ([datetimeoffset]), CommitCount, IsTracked.

.EXAMPLE
Get-GitFileDates -RepositoryRoot 'C:\Dropbox\whertzing\GitHub\ATAP.IAC-wt-15-Sprint-0012-work-items'

.EXAMPLE
Get-GitFileDates -RepositoryRoot $root -RelativePath 'ReadMe.md','docs\setup.md'

.EXAMPLE
Get-DocumentationFileInventory -RootPath $root | Get-GitFileDates -RepositoryRoot $root
#>
Function Get-GitFileDates {
  #region FunctionParameters
  [CmdletBinding()]
  param (
    [parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string] $RepositoryRoot
    , [parameter(ValueFromPipelineByPropertyName = $true)]
    [string[]] $RelativePath
  )
  #endregion FunctionParameters
  #region FunctionBeginBlock
  ########################################
  BEGIN {
    Write-PSFMessage -Level Debug -Message 'Entering Function Get-GitFileDates in module ATAP.Utilities.Powershell' -Tag 'Trace'
    & git -C $RepositoryRoot rev-parse --is-inside-work-tree *> $null
    if ($LASTEXITCODE -ne 0) {
      throw "Get-GitFileDates: '$RepositoryRoot' is not inside a git work tree."
    }

    # One history walk: newest-first commits, each header '#<author-date-ISO8601>', followed by
    # the touched paths. First sighting of a path = LastCommitDate; every later sighting pushes
    # FirstCommitDate older.
    $dateMap = @{}
    $currentDate = $null
    & git -C $RepositoryRoot -c core.quotepath=false log --format='#%aI' --name-only 2>$null |
      ForEach-Object {
        if ($_.Length -eq 0) { return }
        if ($_ -match '^#\d{4}-\d{2}-\d{2}T') {
          $currentDate = [datetimeoffset]::Parse($_.Substring(1))
          return
        }
        $key = $_.Replace('/', '\')
        $entry = $dateMap[$key]
        if ($null -eq $entry) {
          $dateMap[$key] = @{ First = $currentDate; Last = $currentDate; Count = 1 }
        } else {
          $entry.First = $currentDate   # walk is newest-first, so each sighting is older
          $entry.Count++
        }
      }
    Write-PSFMessage -Level Verbose -Message "Get-GitFileDates: history walk of $RepositoryRoot mapped $($dateMap.Count) paths" -Tag 'DocumentationReview'
    $requestedAny = $false
  }
  #endregion FunctionBeginBlock
  #region FunctionProcessBlock
  ########################################
  PROCESS {
    if (-not $RelativePath) { return }
    $requestedAny = $true
    foreach ($path in $RelativePath) {
      $key = $path.Replace('/', '\')
      $entry = $dateMap[$key]
      if ($null -eq $entry) {
        [PSCustomObject]@{
          RelativePath    = $key
          FirstCommitDate = $null
          LastCommitDate  = $null
          CommitCount     = 0
          IsTracked       = $false
        }
      } else {
        [PSCustomObject]@{
          RelativePath    = $key
          FirstCommitDate = $entry.First
          LastCommitDate  = $entry.Last
          CommitCount     = $entry.Count
          IsTracked       = $true
        }
      }
    }
  }
  #endregion FunctionProcessBlock
  #region FunctionEndBlock
  ########################################
  END {
    if (-not $requestedAny) {
      foreach ($key in $dateMap.Keys) {
        $entry = $dateMap[$key]
        [PSCustomObject]@{
          RelativePath    = $key
          FirstCommitDate = $entry.First
          LastCommitDate  = $entry.Last
          CommitCount     = $entry.Count
          IsTracked       = $true
        }
      }
    }
    Write-PSFMessage -Level Debug -Message 'Leaving Function Get-GitFileDates in module ATAP.Utilities.Powershell' -Tag 'Trace'
  }
  #endregion FunctionEndBlock
}
#endregion Get-GitFileDates
#############################################################################
