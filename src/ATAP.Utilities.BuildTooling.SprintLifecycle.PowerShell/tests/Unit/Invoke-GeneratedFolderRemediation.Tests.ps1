BeforeAll {
  . "$PSScriptRoot\..\..\public\Invoke-GeneratedFolderRemediation.ps1"
  $script:fixtureRoot = [IO.Path]::GetFullPath("$PSScriptRoot/../../../../_generated/Sprint0016/Task16.84/NestedProtectionTests-v1/Fixtures")

  function script:Get-TestCleanupPaths {
    param([string]$Root, [string]$Stable, [string]$Sprint)

    $separators = [char[]]@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd($separators)
    $stableFull = [IO.Path]::GetFullPath($Stable).TrimEnd($separators)
    $sprintFull = [IO.Path]::GetFullPath($Sprint).TrimEnd($separators)
    $basePrefix = $script:fixtureRoot.TrimEnd($separators) + [IO.Path]::DirectorySeparatorChar
    $rootPrefix = $rootFull + [IO.Path]::DirectorySeparatorChar
    if (-not $rootFull.StartsWith($basePrefix, [StringComparison]::OrdinalIgnoreCase) -or
      -not $stableFull.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase) -or
      -not $sprintFull.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase) -or
      $stableFull -ine (Join-Path $rootFull 'Repo') -or
      $sprintFull -ine (Join-Path $rootFull 'Repo-wt-7-Sprint-0016-work-items')) {
      throw 'Fixture cleanup paths escape the owned root or expected children.'
    }
    [pscustomobject]@{ Root = $rootFull; Stable = $stableFull; Sprint = $sprintFull }
  }

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
    $script:gitRoot = Join-Path $script:fixtureRoot ([guid]::NewGuid().ToString('N').Substring(0, 8))
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
      $cleanup = script:Get-TestCleanupPaths -Root $script:gitRoot -Stable $script:stable -Sprint $script:sprint
      & git -C $cleanup.Stable worktree remove --force $cleanup.Sprint 2>$null | Out-Null
      $cleanup = script:Get-TestCleanupPaths -Root $script:gitRoot -Stable $script:stable -Sprint $script:sprint
      Remove-Item -LiteralPath $cleanup.Root -Recurse -Force -ErrorAction SilentlyContinue
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

  It 'protects every nested current or future sprint match in plan and execution across all three selectors' {
    $protectedSegments = @(
      'Sprint0015/Sprint0016',
      'Sprint0015/Sprint0017',
      'Sprint0016/Sprint0015',
      'Sprint0015-and-Sprint0016',
      'Sprint0015-and-Sprint0017',
      'sPrInT_0015/SpRiNt-EnD-0016',
      'SprintEnd0015/Sprint-0016',
      'Sprint_0017-and-Sprint0015'
    )
    $protectedStable = @()
    $protectedSprint = @()
    foreach ($segment in $protectedSegments) {
      $stableOnly = "_generated/$segment/stable-only.bin"
      $inherited = "_generated/$segment/inherited.bin"
      $untracked = "_generated/$segment/untracked.bin"
      New-TestFile $script:stable $stableOnly "stable:$segment"
      New-TestFile $script:stable $inherited "inherited:$segment"
      Invoke-TestGit $script:stable add -f -- $inherited | Out-Null
      New-TestFile $script:sprint $inherited "inherited:$segment"
      Invoke-TestGit $script:sprint add -f -- $inherited | Out-Null
      New-TestFile $script:sprint $untracked "untracked:$segment"
      $protectedStable += $stableOnly
      $protectedSprint += $inherited, $untracked
    }
    $oldTracked = '_generated/Sprint0014/Sprint0015/old-tracked.bin'
    $oldUntracked = '_generated/Sprint0014/Sprint0015/old-untracked.bin'
    $noSprint = '_generated/SprintABCD/no-number.bin'
    foreach ($root in @($script:stable, $script:sprint)) {
      New-TestFile $root $oldTracked 'old tracked'
      Invoke-TestGit $root add -f -- $oldTracked | Out-Null
      New-TestFile $root $oldUntracked 'old untracked'
      New-TestFile $root $noSprint 'no sprint number'
      Invoke-TestGit $root commit -q -m 'nested protection fixtures' | Out-Null
    }
    $before = @{}
    foreach ($rel in $protectedStable) {
      $path = Join-Path $script:stable $rel
      $before[$path] = (Get-FileHash -LiteralPath $path).Hash
    }
    foreach ($rel in $protectedSprint) {
      $path = Join-Path $script:sprint $rel
      $before[$path] = (Get-FileHash -LiteralPath $path).Hash
    }

    $plan = Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Scope StableWorktree, SprintCarryover
    $plan.Errors | Should -BeNullOrEmpty
    $plan.Mode | Should -Be Plan
    $plan.Stable[0].CurrentSprintProtected | Should -Be (1 + $protectedSegments.Count)
    foreach ($rel in $protectedSprint) {
      $plan.Sprint[0].InheritedTracked | Should -Not -Contain $rel
      $plan.Sprint[0].PriorSprintNamedTracked | Should -Not -Contain $rel
      $plan.Sprint[0].PriorSprintNamedUntracked | Should -Not -Contain $rel
    }
    $plan.Sprint[0].InheritedTracked | Should -Contain $oldTracked
    $plan.Sprint[0].PriorSprintNamedUntracked | Should -Contain $oldUntracked
    $plan.Sprint[0].PriorSprintNamedUntracked | Should -Not -Contain $noSprint
    foreach ($path in $before.Keys) { (Get-FileHash -LiteralPath $path).Hash | Should -Be $before[$path] }

    $result = Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Scope StableWorktree, SprintCarryover -Execute -ArchiveRoot $script:archive -Confirm:$false
    $result.Errors | Should -BeNullOrEmpty
    foreach ($path in $before.Keys) { (Get-FileHash -LiteralPath $path).Hash | Should -Be $before[$path] }
    $staged = @(Invoke-TestGit $script:sprint diff --cached --name-only)
    foreach ($rel in $protectedSprint) { $staged | Should -Not -Contain $rel }
    $staged | Should -Contain $oldTracked
    Test-Path -LiteralPath (Join-Path $script:sprint $oldUntracked) | Should -BeFalse
    Test-Path -LiteralPath (Join-Path $script:stable $oldUntracked) | Should -BeFalse
    Test-Path -LiteralPath (Join-Path $script:stable $noSprint) | Should -BeFalse
    Test-Path -LiteralPath (Join-Path $script:sprint $noSprint) | Should -BeTrue
  }

  It 'skips inherited files that have uncommitted modifications' {
    Set-Content -LiteralPath (Join-Path $script:sprint '_generated/legacy-tracked.txt') -Value 'edited'
    $r = Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName 'Repo' `
      -Scope SprintCarryover -Execute -NoArchive -Confirm:$false

    $r.Sprint[0].SkippedModified | Should -Contain '_generated/legacy-tracked.txt'
    Test-Path (Join-Path $script:sprint '_generated/legacy-tracked.txt') | Should -BeTrue
  }

  It 'requires an archive root before stable deletion without NoArchive' {
    { Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName 'Repo' `
        -Scope StableWorktree -Execute -Confirm:$false } | Should -Throw '*ArchiveRoot*'
  }

  It 'rejects stable deletion with NoArchive and retains every original byte' {
    $before = @(Get-ChildItem -LiteralPath (Join-Path $script:stable '_generated') -Recurse -File -Force |
        Get-FileHash -Algorithm SHA256 | Sort-Object Path | Select-Object Path, Hash)
    $r = Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo `
      -Scope StableWorktree -Execute -NoArchive -Confirm:$false
    $r.Stable[0].Action | Should -Be Failed
    $r.Stable[0].DeletedFiles | Should -Be 0
    $r.Stable[0].Archive | Should -BeNullOrEmpty
    $r.Errors -join ' ' | Should -Match 'NoArchive is not allowed'
    $after = @(Get-ChildItem -LiteralPath (Join-Path $script:stable '_generated') -Recurse -File -Force |
        Get-FileHash -Algorithm SHA256 | Sort-Object Path | Select-Object Path, Hash)
    ($after | ConvertTo-Json -Compress) | Should -Be ($before | ConvertTo-Json -Compress)
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

  It 'retains every original when the archive cannot be created' {
    New-TestFile $script:gitRoot 'blocked-archive' 'not a directory'
    $r = Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo `
      -Scope StableWorktree -Execute -ArchiveRoot (Join-Path $script:gitRoot 'blocked-archive') -Confirm:$false
    $r.Stable[0].Action | Should -Be Failed
    $r.Stable[0].DeletedFiles | Should -Be 0
    Test-Path (Join-Path $script:stable '_generated/AIAdapterBackups/backup.json') | Should -BeTrue
  }

  It 'retains originals when archive byte verification fails' {
    Mock Get-FileHash { [pscustomobject]@{ Hash = ('0' * 64) } }
    $r = Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo `
      -Scope StableWorktree -Execute -ArchiveRoot $script:archive -Confirm:$false
    $r.Errors -join ' ' | Should -Match 'Archive hash mismatch'
    $r.Stable[0].DeletedFiles | Should -Be 0
    Test-Path (Join-Path $script:stable '_generated/AIAdapterBackups/backup.json') | Should -BeTrue
  }

  It 'retains originals when a selected source is unavailable at archive time' {
    # Pester 6 throws when no filter matches and there is no default mock; pass other calls through.
    # Invoke the cmdlet object itself; a module-qualified name still resolves to the mock and recurses.
    $script:realGetItem = Get-Command -Name Get-Item -CommandType Cmdlet
    Mock Get-Item { & $script:realGetItem @PesterBoundParameters }
    Mock Get-Item { throw 'Source unavailable' } -ParameterFilter { $LiteralPath -like '*backup.json' }
    $r = Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo `
      -Scope StableWorktree -Execute -ArchiveRoot $script:archive -Confirm:$false
    $r.Stable[0].Action | Should -Be Failed
    $r.Stable[0].DeletedFiles | Should -Be 0
    Test-Path (Join-Path $script:stable '_generated/AIAdapterBackups/backup.json') | Should -BeTrue
  }

  It 'aborts on native Git inventory failure without deleting untracked files' {
    Mock git { $global:LASTEXITCODE = 128; 'fatal: inventory unavailable' }
    { Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo `
        -Scope StableWorktree -Execute -ArchiveRoot $script:archive -Confirm:$false } | Should -Throw '*Git inventory failed*'
    Test-Path (Join-Path $script:stable '_generated/AIAdapterBackups/backup.json') | Should -BeTrue
  }

  It 'rejects a junction before following it or deleting any original' {
    New-TestFile $script:gitRoot 'outside/keep.txt'
    $junction = Join-Path $script:stable '_generated/external'
    New-Item -ItemType Junction -Path $junction -Target (Join-Path $script:gitRoot 'outside') -ErrorAction Stop | Out-Null
    try {
      { Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo `
          -Scope StableWorktree -Execute -ArchiveRoot $script:archive -Confirm:$false } | Should -Throw '*Reparse point*'
      Test-Path (Join-Path $script:gitRoot 'outside/keep.txt') | Should -BeTrue
      Test-Path (Join-Path $script:stable '_generated/AIAdapterBackups/backup.json') | Should -BeTrue
    } finally { Remove-Item -LiteralPath $junction -Force }
  }

  It 'verifies hidden files and exact archive paths and is idempotent' {
    New-TestFile $script:stable '_generated/hidden.bin' 'hidden bytes'
    $hidden = Join-Path $script:stable '_generated/hidden.bin'
    (Get-Item $hidden).Attributes = [IO.FileAttributes]::Hidden
    $r = Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo `
      -Scope StableWorktree -Execute -ArchiveRoot $script:archive -Confirm:$false
    $r.Errors | Should -BeNullOrEmpty
    $r.Stable[0].DeletedFiles | Should -Be 2
    $zip = [IO.Compression.ZipFile]::OpenRead($r.Stable[0].Archive)
    try {
      @($zip.Entries.FullName).Count | Should -Be 2
      $zip.Entries.FullName | Should -Contain '_generated/hidden.bin'
      $zip.Entries.FullName | Should -Contain '_generated/AIAdapterBackups/backup.json'
    } finally { $zip.Dispose() }
    $again = Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Scope StableWorktree
    $again.Stable[0].Action | Should -Be NothingToDelete
    $again.Stable[0].CurrentSprintProtected | Should -Be 1
    @($again.Stable[0].TrackedDeferred).Count | Should -Be 2
  }
}
