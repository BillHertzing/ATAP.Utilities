function Get-LocalGitWorktreeMetadata {
  [CmdletBinding()]
  param([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string[]] $RootPath)

  begin {
    if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
      Import-Module PSFramework -ErrorAction Stop
    }
    if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) { throw 'PSFramework logging is unavailable.' }
  }
  process {
    foreach ($root in $RootPath) {
      $coverage = @('root', 'top-level', 'git-dir', 'common-dir', 'selected-registration', 'branch', 'registration-flags')
      $result = [ordered]@{ RootPath = $root; Status = 'Inconclusive'; CheckedCoverage = @(); Evidence = @(); Reason = $null }
      try {
        if (-not (Test-Path -LiteralPath $root -PathType Container -ErrorAction Stop)) { throw 'RootMissingOrInaccessible' }
        if (-not (Get-Command git -CommandType Application -ErrorAction SilentlyContinue)) { throw 'GitUnavailable' }
        $expected = [IO.Path]::GetFullPath($root).TrimEnd([char[]]@('/', '\'))
        $top = @(git -C $root rev-parse --show-toplevel 2>$null); if ($LASTEXITCODE -ne 0 -or $top.Count -ne 1) { throw 'TopLevelUnavailable' }
        $gitDir = @(git -C $root rev-parse --absolute-git-dir 2>$null); if ($LASTEXITCODE -ne 0 -or $gitDir.Count -ne 1) { throw 'GitDirUnavailable' }
        $common = @(git -C $root rev-parse --git-common-dir 2>$null); if ($LASTEXITCODE -ne 0 -or $common.Count -ne 1) { throw 'CommonDirUnavailable' }
        $list = @(git -C $root worktree list --porcelain 2>$null); if ($LASTEXITCODE -ne 0 -or $list.Count -eq 0) { throw 'WorktreeListUnavailable' }
        $branch = @(git -C $root symbolic-ref --quiet --short HEAD 2>$null); $branchExit = $LASTEXITCODE
        $actual = [IO.Path]::GetFullPath($top[0]).TrimEnd([char[]]@('/', '\'))
        $absoluteCommon = [IO.Path]::GetFullPath($common[0], $expected)
        if (-not (Test-Path -LiteralPath $gitDir[0] -PathType Container -ErrorAction Stop) -or -not (Test-Path -LiteralPath $absoluteCommon -PathType Container -ErrorAction Stop)) { throw 'GitMetadataDirectoryMissing' }
        $blocks = (($list -join "`n") -split "`n`n")
        $selected = @($blocks | Where-Object { $_ -match '(?m)^worktree (.+)$' -and [string]::Equals([IO.Path]::GetFullPath($Matches[1]).TrimEnd([char[]]@('/', '\')), $expected, [StringComparison]::OrdinalIgnoreCase) })
        if ($selected.Count -ne 1) { throw 'SelectedRegistrationMissingOrAmbiguous' }
        $lines = @($selected[0] -split "`n")
        if (@($lines | Where-Object { $_ -match '^HEAD [0-9a-fA-F]{40,64}$' }).Count -ne 1) { throw 'MalformedRegistration' }
        if (@($lines | Where-Object { $_ -and $_ -notmatch '^(worktree |HEAD |branch |locked( |$)|prunable( |$)|detached$|bare$)' }).Count) { throw 'UnsupportedRegistration' }
        $flags = @($lines | Where-Object { $_ -match '^(locked|prunable|detached)( |$)' })
        $registeredBranch = @($lines | Where-Object { $_ -match '^branch refs/heads/' })
        if ($flags -notcontains 'detached' -and ($branchExit -ne 0 -or $branch.Count -ne 1 -or $registeredBranch.Count -ne 1)) { throw 'BranchUnavailableOrUnsupported' }
        $findings = @()
        if (-not [string]::Equals($expected, $actual, [StringComparison]::OrdinalIgnoreCase)) { $findings += 'TopLevelMismatch' }
        $findings += $flags
        if ($branchExit -eq 0 -and $registeredBranch.Count -eq 1 -and $registeredBranch[0] -cne ('branch refs/heads/' + $branch[0])) { $findings += 'BranchMismatch' }
        $result.CheckedCoverage = $coverage
        $result.Evidence = @("TopLevel=$actual", "GitDir=$($gitDir[0])", "CommonDir=$absoluteCommon", "Branch=$($branch -join '')") + $findings
        $result.Status = if ($findings.Count) { 'Finding' } else { 'NoFindingsInCheckedMetadata' }
      } catch {
        $result.Reason = 'Required metadata unavailable, malformed, interrupted, or unsupported.'
        Write-PSFMessage -FunctionName 'Get-LocalGitWorktreeMetadata' -ModuleName 'ATAP.Utilities.BuildTooling.PowerShell' -Level Debug -Message 'Local Git metadata observation was inconclusive.'
      }
      [pscustomobject]$result
    }
  }
}
