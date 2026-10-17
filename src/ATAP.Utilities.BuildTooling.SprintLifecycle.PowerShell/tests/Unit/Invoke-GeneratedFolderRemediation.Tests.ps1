BeforeAll {
  . "$PSScriptRoot\..\..\public\Invoke-GeneratedFolderRemediation.ps1"

  function script:New-TestFile {
    param([string]$Root, [string]$Relative, [string]$Content = 'x')
    $path = Join-Path $Root $Relative
    New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force | Out-Null
    Set-Content -LiteralPath $path -Value $Content -Encoding utf8
  }

  function script:Invoke-TestGit {
    param([string]$Repo, [Parameter(ValueFromRemainingArguments)][string[]]$GitArgs)
    $out = & git -C $Repo -c user.name=Test -c user.email=test@example.invalid -c core.autocrlf=false @GitArgs 2>&1
    if ($LASTEXITCODE -ne 0) { throw "git $($GitArgs -join ' ') failed: $out" }
    $out
  }
}

Describe 'Invoke-GeneratedFolderRemediation [public]' {
  BeforeEach {
    $script:gitRoot = Join-Path ([IO.Path]::GetTempPath()) "gen_remediation_$([guid]::NewGuid().ToString('N'))"
    $script:stable = Join-Path $script:gitRoot 'Repo'
    $script:sprint = Join-Path $script:gitRoot 'Repo-wt-7-Sprint-0016-work-items'
    $script:archive = Join-Path $script:gitRoot 'archive'
    New-Item -ItemType Directory -Path $script:stable -Force | Out-Null

    Invoke-TestGit $script:stable init -q -b main | Out-Null
    New-TestFile $script:stable '.gitignore' '_generated/'
    New-TestFile $script:stable 'src/a.txt'
    New-TestFile $script:stable '_generated/Sprint0015/old-evidence.md'
    New-TestFile $script:stable '_generated/legacy-tracked.txt'
    Invoke-TestGit $script:stable add .gitignore src/a.txt | Out-Null
    Invoke-TestGit $script:stable add -f _generated/Sprint0015/old-evidence.md _generated/legacy-tracked.txt | Out-Null
    Invoke-TestGit $script:stable commit -q -m 'seed' | Out-Null

    Invoke-TestGit $script:stable worktree add -q -b sprint16 $script:sprint | Out-Null

    # Stable: untracked/ignored debris plus a current-sprint file that must be protected.
    New-TestFile $script:stable '_generated/AIAdapterBackups/backup.json'
    New-TestFile $script:stable '_generated/Sprint0016/current.md'

    # Sprint: current-sprint evidence (tracked and untracked), prior-sprint untracked, one modified inherited file.
    New-TestFile $script:sprint '_generated/Sprint0016/Task16.80/evidence.md'
    New-TestFile $script:sprint '_generated/Sprint0016/tracked-now.md'
    Invoke-TestGit $script:sprint add -f _generated/Sprint0016/tracked-now.md | Out-Null
    Invoke-TestGit $script:sprint commit -q -m 'sprint work' | Out-Null
    New-TestFile $script:sprint '_generated/sprint-end-0007/stale.log'
    New-TestFile $script:sprint '_generated/SprintEnd0013-StableProjection/p.json'
    New-TestFile $script:sprint '_generated/scratch/no-sprint-name.txt'
  }

  AfterEach {
    if ($script:gitRoot -and (Test-Path -LiteralPath $script:gitRoot)) {
      & git -C $script:stable worktree remove --force $script:sprint 2>$null | Out-Null
      Remove-Item -LiteralPath $script:gitRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  It 'plans without changing anything by default' {
    $r = Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName 'Repo'

    $r.Mode | Should -Be 'Plan'
    $r.Stable[0].UntrackedFiles | Should -Be 1
    $r.Stable[0].CurrentSprintProtected | Should -Be 1
    @($r.Stable[0].TrackedDeferred).Count | Should -Be 2
    @($r.Sprint[0].InheritedTracked).Count | Should -Be 2
    @($r.Sprint[0].PriorSprintNamedUntracked).Count | Should -Be 2
    $r.History[0].HistoryPathCount | Should -Be 2
    $r.History[0].Action | Should -Be 'Planned'
    Test-Path (Join-Path $script:stable '_generated/AIAdapterBackups/backup.json') | Should -BeTrue
    Test-Path (Join-Path $script:sprint '_generated/sprint-end-0007/stale.log') | Should -BeTrue
  }

  It 'removes stable debris and prior-sprint carryover, archives it, and protects current-sprint content' {
    $r = Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName 'Repo' `
      -Scope StableWorktree, SprintCarryover -Execute -ArchiveRoot $script:archive -Confirm:$false

    $r.Errors | Should -BeNullOrEmpty
    $r.Stable[0].Action | Should -Be 'Deleted'
    Test-Path (Join-Path $script:stable '_generated/AIAdapterBackups') | Should -BeFalse
    Test-Path (Join-Path $script:stable '_generated/Sprint0016/current.md') | Should -BeTrue
    Test-Path (Join-Path $script:stable '_generated/legacy-tracked.txt') | Should -BeTrue  # tracked: deferred to the sprint merge

    $r.Sprint[0].Action | Should -Be 'Removed'
    $r.Sprint[0].GitRemoved | Should -Be 2
    $r.Sprint[0].DeletedFiles | Should -Be 2
    Test-Path (Join-Path $script:sprint '_generated/Sprint0016/Task16.80/evidence.md') | Should -BeTrue
    Test-Path (Join-Path $script:sprint '_generated/Sprint0016/tracked-now.md') | Should -BeTrue
    Test-Path (Join-Path $script:sprint '_generated/scratch/no-sprint-name.txt') | Should -BeTrue
    Test-Path (Join-Path $script:sprint '_generated/sprint-end-0007') | Should -BeFalse

    $staged = & git -C $script:sprint diff --cached --name-only
    $staged | Should -Contain '_generated/legacy-tracked.txt'
    $staged | Should -Contain '_generated/Sprint0015/old-evidence.md'
    (& git -C $script:sprint log --oneline).Count | Should -Be 2   # nothing committed

    @(Get-ChildItem $script:archive -Filter *.zip).Count | Should -Be 2
  }

  It 'skips inherited files that have uncommitted modifications' {
    Set-Content -LiteralPath (Join-Path $script:sprint '_generated/legacy-tracked.txt') -Value 'edited'
    $r = Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName 'Repo' `
      -Scope SprintCarryover -Execute -NoArchive -Confirm:$false

    $r.Sprint[0].SkippedModified | Should -Contain '_generated/legacy-tracked.txt'
    Test-Path (Join-Path $script:sprint '_generated/legacy-tracked.txt') | Should -BeTrue
  }

  It 'requires an archive root, or -NoArchive, before deleting' {
    { Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName 'Repo' `
        -Scope StableWorktree -Execute -Confirm:$false } | Should -Throw '*ArchiveRoot*'
  }

  It 'refuses an archive root inside a _generated folder under GitRoot' {
    { Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName 'Repo' `
        -Scope StableWorktree -Execute -ArchiveRoot (Join-Path $script:stable '_generated/arch') -Confirm:$false } |
      Should -Throw '*inside a _generated folder*'
  }

  It 'requires -Execute for a push and a work root for a history rewrite' {
    { Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName 'Repo' `
        -Scope StableHistory -PushRewrittenHistory } | Should -Throw '*requires -Execute*'
    { Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName 'Repo' `
        -Scope StableHistory -Execute -Confirm:$false } | Should -Throw '*HistoryWorkRoot*'
  }

  It 'skips the stable scope when the stable worktree is not on the stable branch' {
    Invoke-TestGit $script:stable checkout -q -b other | Out-Null
    $r = Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName 'Repo' `
      -Scope StableWorktree -Execute -NoArchive -Confirm:$false
    $r.Stable[0].Action | Should -BeLike 'Skipped*'
    Test-Path (Join-Path $script:stable '_generated/AIAdapterBackups/backup.json') | Should -BeTrue
  }
}
