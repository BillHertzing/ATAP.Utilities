#############################################################################
#region Get-GitFileDates
<#
.SYNOPSIS
Returns git-derived no-earlier-than / no-later-than datetime bounds for each file's creation and last write, using one history walk.

.DESCRIPTION
Runs a single `git log --name-only` walk over the history reachable from HEAD and derives, per
repo-relative path, the temporal-bounds fields of the ATAP Documentation Review program's §3a
schema (_Planning\DocumentationReview\DocumentationReview-Plan.md):

  CreatedNoEarlierThan   — author date of the commit immediately preceding (in git log order) the
                           first commit that introduced the path; $null when the path arrived in
                           the root commit (no lower bound exists).
  CreatedNoLaterThan     — author date of the first commit that introduced the path.
  LastWriteNoEarlierThan — author date of the second-newest commit touching the path; for
                           single-commit files, equals CreatedNoEarlierThan.
  LastWriteNoLaterThan   — author date of the newest commit touching the path.

All values are [datetimeoffset] converted to UTC. Emits one record per path in history, or — when
-RelativePath is supplied — one record per requested path, with IsTracked = $false and null bounds
for paths absent from history.

Known approximations (per DR-1.2.b): "immediately preceding commit" is the next commit in the
single-walk `git log` output, which for non-linear history may not be the literal parent — the
bound stays conservative for ordinary sprint workflows. The walk does not follow renames, so a
renamed file's Created bounds reflect the commit that created its CURRENT name; per-file
`git log --follow` is deliberately not used (1,600+ invocations is prohibitively slow) — run it
manually for files flagged as suspiciously young.

.PARAMETER RepositoryRoot
Root of the git repository or worktree to walk. Must contain a resolvable git work tree.

.PARAMETER RelativePath
Optional repo-relative path(s) (either slash style) to look up, bindable from the pipeline by
property name so inventory records can be piped in. When omitted, every path in history is emitted.

.INPUTS
Objects with a RelativePath property (e.g., Get-DocumentationFileInventory output).

.OUTPUTS
PSCustomObject with properties: RelativePath (backslash-normalized), CreatedNoEarlierThan,
CreatedNoLaterThan, LastWriteNoEarlierThan, LastWriteNoLaterThan ([datetimeoffset] UTC or $null),
CommitCount, IsTracked.

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

    # One newest-first history walk. Each header line is '#<author-date-ISO8601>'; the lines that
    # follow are the paths that commit touched. Per path we track:
    #   NewestDate       (first sighting)        -> LastWriteNoLaterThan
    #   SecondNewestDate (second sighting)       -> LastWriteNoEarlierThan
    #   OldestIndex      (index of last sighting) -> CreatedNoLaterThan = commitDates[OldestIndex],
    #                                                CreatedNoEarlierThan = commitDates[OldestIndex+1]
    $commitDates = [System.Collections.Generic.List[datetimeoffset]]::new()
    $pathMap = @{}
    & git -C $RepositoryRoot -c core.quotepath=false log --format='#%aI' --name-only 2>$null |
      ForEach-Object {
        if ($_.Length -eq 0) { return }
        if ($_ -match '^#\d{4}-\d{2}-\d{2}T') {
          $commitDates.Add([datetimeoffset]::Parse($_.Substring(1)).ToUniversalTime())
          return
        }
        $key = $_.Replace('/', '\')
        $commitIndex = $commitDates.Count - 1
        $entry = $pathMap[$key]
        if ($null -eq $entry) {
          $pathMap[$key] = @{
            NewestDate       = $commitDates[$commitIndex]
            SecondNewestDate = $null
            OldestIndex      = $commitIndex
            Count            = 1
          }
        } else {
          if ($null -eq $entry.SecondNewestDate) { $entry.SecondNewestDate = $commitDates[$commitIndex] }
          $entry.OldestIndex = $commitIndex
          $entry.Count++
        }
      }
    Write-PSFMessage -Level Verbose -Message "Get-GitFileDates: history walk of $RepositoryRoot mapped $($pathMap.Count) paths across $($commitDates.Count) commits" -Tag 'DocumentationReview'

    $resolveEntry = {
      param($key, $entry)
      $createdNoEarlier = if ($entry.OldestIndex + 1 -lt $commitDates.Count) { $commitDates[$entry.OldestIndex + 1] } else { $null }
      [PSCustomObject]@{
        RelativePath           = $key
        CreatedNoEarlierThan   = $createdNoEarlier
        CreatedNoLaterThan     = $commitDates[$entry.OldestIndex]
        LastWriteNoEarlierThan = if ($null -ne $entry.SecondNewestDate) { $entry.SecondNewestDate } else { $createdNoEarlier }
        LastWriteNoLaterThan   = $entry.NewestDate
        CommitCount            = $entry.Count
        IsTracked              = $true
      }
    }
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
      $entry = $pathMap[$key]
      if ($null -eq $entry) {
        [PSCustomObject]@{
          RelativePath           = $key
          CreatedNoEarlierThan   = $null
          CreatedNoLaterThan     = $null
          LastWriteNoEarlierThan = $null
          LastWriteNoLaterThan   = $null
          CommitCount            = 0
          IsTracked              = $false
        }
      } else {
        & $resolveEntry $key $entry
      }
    }
  }
  #endregion FunctionProcessBlock
  #region FunctionEndBlock
  ########################################
  END {
    if (-not $requestedAny) {
      foreach ($key in $pathMap.Keys) {
        & $resolveEntry $key $pathMap[$key]
      }
    }
    Write-PSFMessage -Level Debug -Message 'Leaving Function Get-GitFileDates in module ATAP.Utilities.Powershell' -Tag 'Trace'
  }
  #endregion FunctionEndBlock
}
#endregion Get-GitFileDates
#############################################################################
