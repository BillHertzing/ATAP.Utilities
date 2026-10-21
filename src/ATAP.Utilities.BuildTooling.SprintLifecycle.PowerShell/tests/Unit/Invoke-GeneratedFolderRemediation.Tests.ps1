BeforeAll {
  . "$PSScriptRoot\..\..\public\Invoke-GeneratedFolderRemediation.ps1"
  . "$PSScriptRoot\..\..\private\Get-GeneratedRemediationByteComparison.ps1"
  $script:fixtureRoot = [IO.Path]::GetFullPath("$PSScriptRoot/../../../../_generated/Sprint0016/Task16.84/CarryoverByteGuardTests-v1/Fixtures")
  $script:realGitCommand = Get-Command git -CommandType Application | Select-Object -First 1
  $script:realCompressArchive = Get-Command Compress-Archive -CommandType Function, Cmdlet
  $null = New-Item -ItemType Directory -Path $script:fixtureRoot -Force
  $cursor = $script:fixtureRoot
  while ($cursor) {
    $item = Get-Item -LiteralPath $cursor -Force
    if ($item.LinkType -or $item.Target) { throw 'Redirecting fixture ancestor.' }
    $cursor = Split-Path -Parent $cursor
  }

  function script:Get-TestCleanupPaths {
    param([string]$Root, [string]$Stable, [string]$Sprint)

    $separators = [char[]]@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd($separators)
    if ((Resolve-Path -LiteralPath $rootFull).ProviderPath -ine $rootFull -or
      (Get-Item -LiteralPath $rootFull -Force).LinkType) { throw 'Redirected fixture cleanup root.' }
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
    @($r.Sprint[0].PriorSprintNamedUntracked).Count | Should -Be 0
    @($r.Sprint[0].PreservedFiles).Count | Should -Be 2
    $r.History[0].HistoryPathCount | Should -Be 2
    $r.History[0].Action | Should -Be 'Planned'
    Test-Path (Join-Path $script:stable '_generated/AIAdapterBackups/backup.json') | Should -BeTrue
    Test-Path (Join-Path $script:sprint '_generated/sprint-end-0007/stale.log') | Should -BeTrue
  }

  It 'removes stable debris and equal tracked carryover while preserving orphan untracked evidence' {
    $r = Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName 'Repo' `
      -Scope StableWorktree, SprintCarryover -Execute -ArchiveRoot $script:archive -Confirm:$false

    $r.Errors | Should -BeNullOrEmpty
    $r.Stable[0].Action | Should -Be 'Deleted'
    Test-Path (Join-Path $script:stable '_generated/AIAdapterBackups') | Should -BeFalse
    Test-Path (Join-Path $script:stable '_generated/Sprint0016/current.md') | Should -BeTrue
    Test-Path (Join-Path $script:stable '_generated/legacy-tracked.txt') | Should -BeTrue  # tracked: deferred to the sprint merge

    $r.Sprint[0].Action | Should -Be 'Removed'
    $r.Sprint[0].GitRemoved | Should -Be 2
    $r.Sprint[0].DeletedFiles | Should -Be 0
    Test-Path (Join-Path $script:sprint '_generated/Sprint0016/Task16.80/evidence.md') | Should -BeTrue
    Test-Path (Join-Path $script:sprint '_generated/Sprint0016/tracked-now.md') | Should -BeTrue
    Test-Path (Join-Path $script:sprint '_generated/scratch/no-sprint-name.txt') | Should -BeTrue
    Test-Path (Join-Path $script:sprint '_generated/sprint-end-0007') | Should -BeTrue

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
    Test-Path -LiteralPath (Join-Path $script:sprint $oldUntracked) | Should -BeTrue
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

  It 'removes only actual same-path equal candidates and preserves different or missing partners' {
    $equal = '_generated/Sprint0015/equal.bin'
    $empty = '_generated/Sprint0015/empty.bin'
    $different = '_generated/Sprint0015/different.bin'
    $missing = '_generated/Sprint0015/missing.bin'
    foreach ($root in @($script:stable, $script:sprint)) {
      New-TestFile $root $equal 'same bytes'
      New-TestFile $root $empty ''
      [IO.File]::WriteAllBytes((Join-Path $root $empty), [byte[]]@())
      New-TestFile $root $different 'AAAA'
    }
    New-TestFile $script:sprint $different 'BBBB'
    New-TestFile $script:sprint $missing 'same bytes'
    New-TestFile $script:stable '_generated/Sprint0015/other-name.bin' 'same bytes'
    New-TestFile $script:sprint '_generated/legacy-tracked.txt' 'different committed bytes'
    Invoke-TestGit $script:sprint add -f -- _generated/legacy-tracked.txt | Out-Null
    Invoke-TestGit $script:sprint commit -q -m 'different tracked content' | Out-Null
    $beforeDifferent = (Get-FileHash -LiteralPath (Join-Path $script:sprint $different)).Hash

    $plan = Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Scope SprintCarryover
    $plan.Errors | Should -BeNullOrEmpty
    $plan.Sprint[0].PriorSprintNamedUntracked | Should -Contain $equal
    $plan.Sprint[0].PriorSprintNamedUntracked | Should -Contain $empty
    $plan.Sprint[0].PriorSprintNamedUntracked | Should -Not -Contain $different
    $plan.Sprint[0].PriorSprintNamedUntracked | Should -Not -Contain $missing
    ($plan.Sprint[0].PreservedFiles | Where-Object Path -EQ $different).Status | Should -Be Different
    ($plan.Sprint[0].PreservedFiles | Where-Object Path -EQ $missing).Status | Should -Be Hold
    $plan.Sprint[0].InheritedTracked | Should -Not -Contain '_generated/legacy-tracked.txt'

    $r = Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Scope SprintCarryover -Execute -ArchiveRoot $script:archive -Confirm:$false
    $r.Errors | Should -BeNullOrEmpty
    $r.Sprint[0].DeletedFiles | Should -Be 2
    Test-Path -LiteralPath (Join-Path $script:sprint $equal) | Should -BeFalse
    Test-Path -LiteralPath (Join-Path $script:sprint $empty) | Should -BeFalse
    (Get-FileHash -LiteralPath (Join-Path $script:sprint $different)).Hash | Should -Be $beforeDifferent
    Test-Path -LiteralPath (Join-Path $script:sprint $missing) | Should -BeTrue
    Test-Path -LiteralPath (Join-Path $script:sprint '_generated/legacy-tracked.txt') | Should -BeTrue
    $r.Sprint[0].ReadyForRemoval | Should -BeFalse
    $r.Sprint[0].NamedStreamsVerified | Should -BeFalse
    $r.Sprint[0].CustodyVerified | Should -BeFalse
  }

  It 'preserves an equal untracked sprint file after combined stable mode removes its partner' {
    $rel = '_generated/Sprint0015/combined.bin'
    foreach ($root in @($script:stable, $script:sprint)) { New-TestFile $root $rel 'equal baseline' }
    $r = Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Scope StableWorktree, SprintCarryover -Execute -ArchiveRoot $script:archive -Confirm:$false
    $r.Errors | Should -BeNullOrEmpty
    Test-Path -LiteralPath (Join-Path $script:stable $rel) | Should -BeFalse
    Test-Path -LiteralPath (Join-Path $script:sprint $rel) | Should -BeTrue
    ($r.Sprint[0].PreservedFiles | Where-Object Path -EQ $rel).Status | Should -Be Hold
  }

  It 'preserves staged changes before asking the byte comparator' {
    New-TestFile $script:sprint '_generated/legacy-tracked.txt' 'staged WIP'
    Invoke-TestGit $script:sprint add -f -- _generated/legacy-tracked.txt | Out-Null
    $r = Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Scope SprintCarryover -Execute -NoArchive -Confirm:$false
    $r.Sprint[0].SkippedModified | Should -Contain '_generated/legacy-tracked.txt'
    (Get-Content -LiteralPath (Join-Path $script:sprint '_generated/legacy-tracked.txt') -Raw).Trim() | Should -Be 'staged WIP'
    ($r.Sprint[0].DefaultDataWitnesses.Binding.RelativePath) | Should -Not -Contain '_generated/legacy-tracked.txt'
  }

  It 'holds carryover when stable branch identity differs' {
    Invoke-TestGit $script:stable checkout -q -b other | Out-Null
    $r = Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Scope SprintCarryover -Execute -NoArchive -Confirm:$false
    $r.Sprint[0].Action | Should -Be Held
    $r.Errors -join ' ' | Should -Match 'Stable branch binding'
    $r.Sprint[0].GitRemoved | Should -Be 0
  }

  It 'holds an unrelated repository with a matching sprint directory name' {
    $unrelated = Join-Path $script:gitRoot 'Repo-wt-9-Sprint-0016-work-items'
    $null = New-Item -ItemType Directory -Path $unrelated
    Invoke-TestGit $unrelated init -q -b main | Out-Null
    New-TestFile $unrelated 'seed.txt'
    Invoke-TestGit $unrelated add seed.txt | Out-Null
    Invoke-TestGit $unrelated commit -q -m 'unrelated' | Out-Null
    $r = Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Scope SprintCarryover
    ($r.Sprint | Where-Object Path -EQ $unrelated).Action | Should -Be Held
    $r.Errors -join ' ' | Should -Match 'common repository binding'
  }

  It 'does not turn a failed common-repository query into an empty successful plan' {
    Mock git {
      if ($args -contains '--git-common-dir') { $global:LASTEXITCODE = 128; return 'identity query failed' }
      & $script:realGitCommand @args
    }
    $r = Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Scope SprintCarryover -Execute -NoArchive -Confirm:$false
    $r.Sprint[0].Action | Should -Be Held
    $r.Errors -join ' ' | Should -Match 'Git inventory failed'
    $r.Sprint[0].Archive | Should -BeNullOrEmpty
    Test-Path -LiteralPath (Join-Path $script:sprint '_generated/legacy-tracked.txt') | Should -BeTrue
  }

  It 'preserves the entire batch when selected default bytes drift after archiving' {
    $script:driftRelative = '_generated/Sprint0015/selected.bin'
    foreach ($root in @($script:stable, $script:sprint)) { New-TestFile $root $script:driftRelative 'AAAA' }
    Mock Compress-Archive {
      & $script:realCompressArchive @PesterBoundParameters
      New-TestFile $script:sprint $script:driftRelative 'BBBB'
    }
    $r = Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Scope SprintCarryover -Execute -ArchiveRoot $script:archive -Confirm:$false
    $r.Sprint[0].Action | Should -Be Failed
    $r.Errors -join ' ' | Should -Match 'byte witness drift'
    $r.Sprint[0].GitRemoved | Should -Be 0
    $r.Sprint[0].DeletedFiles | Should -Be 0
    Test-Path -LiteralPath (Join-Path $script:sprint '_generated/legacy-tracked.txt') | Should -BeTrue
    Test-Path -LiteralPath (Join-Path $script:sprint $script:driftRelative) | Should -BeTrue
    @(Invoke-TestGit $script:sprint diff --cached --name-only).Count | Should -Be 0
  }

  It 'preserves the entire batch when the index changes after archiving' {
    Mock Compress-Archive {
      & $script:realCompressArchive @PesterBoundParameters
      New-TestFile $script:sprint '_generated/Sprint0016/new-stage.txt'
      Invoke-TestGit $script:sprint add -f -- _generated/Sprint0016/new-stage.txt | Out-Null
    }
    $r = Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Scope SprintCarryover -Execute -ArchiveRoot $script:archive -Confirm:$false
    $r.Sprint[0].Action | Should -Be Failed
    $r.Errors -join ' ' | Should -Match 'selection/index/HEAD drift'
    $r.Sprint[0].GitRemoved | Should -Be 0
    Test-Path -LiteralPath (Join-Path $script:sprint '_generated/legacy-tracked.txt') | Should -BeTrue
  }

  It 'refuses an equal pair whose shared bytes changed after archiving' {
    $script:driftRelative = '_generated/Sprint0015/both-drift.bin'
    foreach ($root in @($script:stable, $script:sprint)) { New-TestFile $root $script:driftRelative 'AAAA' }
    Mock Compress-Archive {
      & $script:realCompressArchive @PesterBoundParameters
      foreach ($root in @($script:stable, $script:sprint)) { New-TestFile $root $script:driftRelative 'BBBB' }
    }
    $r = Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Scope SprintCarryover -Execute -ArchiveRoot $script:archive -Confirm:$false
    $r.Sprint[0].Action | Should -Be Failed
    $r.Errors -join ' ' | Should -Match 'byte witness drift'
    $r.Sprint[0].GitRemoved | Should -Be 0
    $r.Sprint[0].DeletedFiles | Should -Be 0
    Test-Path -LiteralPath (Join-Path $script:sprint $script:driftRelative) | Should -BeTrue
  }

  It 'loads the private helper from source when it is not already available' {
    Remove-Item Function:\Get-GeneratedRemediationByteComparison -ErrorAction Stop
    try {
      $r = Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Scope SprintCarryover
      $r.Errors | Should -BeNullOrEmpty
      $r.Sprint[0].InheritedTracked | Should -Contain '_generated/legacy-tracked.txt'
    } finally { . "$PSScriptRoot\..\..\private\Get-GeneratedRemediationByteComparison.ps1" }
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
