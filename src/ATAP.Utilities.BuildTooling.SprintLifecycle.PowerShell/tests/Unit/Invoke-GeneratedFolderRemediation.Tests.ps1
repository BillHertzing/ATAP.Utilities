BeforeAll {
  . "$PSScriptRoot\..\..\public\Invoke-GeneratedFolderRemediation.ps1"
  . "$PSScriptRoot\..\..\private\Get-GeneratedRemediationByteComparison.ps1"
  $script:fixtureRoot = [IO.Path]::GetFullPath("$PSScriptRoot/../../../../_generated/Sprint0016/Task16.84/CarryoverByteGuardTests-v1/Fixtures")
  $script:realGitCommand = Get-Command 'C:/Program Files/Git/cmd/git.exe' -CommandType Application -ErrorAction Stop
  $ordinaryGit = Get-Command git -ErrorAction Stop
  if ($ordinaryGit.CommandType -ne 'Application' -or $ordinaryGit.Path -ine $script:realGitCommand.Path) {
    throw 'Unmocked public git resolution differs from the preferred Git executable.'
  }
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
    $out = & $script:realGitCommand -C $Repo -c user.name=Test -c user.email=test@example.invalid -c core.autocrlf=false @GitArgs 2>&1
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
      & $script:realGitCommand -C $cleanup.Stable worktree remove --force $cleanup.Sprint 2>$null | Out-Null
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

  It 'refuses all worktree execution preserving default and named data directories index and HEAD' {
    $payloads=@()
    $nodes=@()
    foreach($root in @($script:stable,$script:sprint)){
      $generated=Join-Path $root '_generated'
      $directory=Join-Path $generated 'ads-only'
      $null=New-Item -ItemType Directory -Path $directory
      $file=Join-Path $generated 'legacy-tracked.txt'
      [IO.File]::WriteAllText($file+':notes','named sentinel')
      [IO.File]::WriteAllText($generated+':root-note','root sentinel')
      [IO.File]::WriteAllBytes($directory+':empty',[byte[]]@())
      [IO.File]::WriteAllBytes($directory+':'+[char]0x9644,[byte[]]@(0,9,255))
      $payloads+=@($file,($file+':notes'),($generated+':root-note'),($directory+':empty'),($directory+':'+[char]0x9644))
      $nodes+=@($generated,$directory)
    }
    $before=@(foreach($path in $payloads){[pscustomobject]@{Path=$path;Hash=(Get-FileHash -LiteralPath $path).Hash}})
    $streamSets=@(foreach($path in $nodes){[pscustomobject]@{Path=$path;Streams=@(Get-Item -LiteralPath $path -Stream '*'|Select-Object Stream,Length)}})
    $gitState=@(foreach($root in @($script:stable,$script:sprint)){
      $index=(& $script:realGitCommand -C $root rev-parse --path-format=absolute --git-path index)
      [pscustomobject]@{Root=$root;Index=$index;IndexHash=(Get-FileHash -LiteralPath $index).Hash;Head=(& $script:realGitCommand -C $root rev-parse HEAD)}
    })
    $output=Join-Path $script:gitRoot 'evidence/report.json'
    Mock git { throw 'No Git call permitted during refusal' }
    Mock Get-Command { throw 'No helper lookup permitted' }
    Mock New-Item { throw 'No output permitted' }
    Mock Compress-Archive { throw 'No archive permitted' }
    foreach($options in @(
      @{Scope=@('StableWorktree')},@{Scope=@('SprintCarryover')},
      @{Scope=@('StableWorktree','SprintCarryover')},
      @{Scope=@('StableWorktree','SprintCarryover');WhatIf=$true}
    )){
      { Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Execute -ArchiveRoot $script:archive -EvidencePath $output -Confirm:$false @options } | Should -Throw '*Execution held*complete approved*root/directory*'
    }
    Should -Invoke git -Times 0
    Should -Invoke Get-Command -Times 0
    Should -Invoke New-Item -Times 0
    Should -Invoke Compress-Archive -Times 0
    foreach($row in $before){(Get-FileHash -LiteralPath $row.Path).Hash | Should -Be $row.Hash}
    foreach($row in $streamSets){
      Test-Path -LiteralPath $row.Path -PathType Container | Should -BeTrue
      $after=@(Get-Item -LiteralPath $row.Path -Stream '*'|Select-Object Stream,Length)
      ($after|ConvertTo-Json -Compress) | Should -Be ($row.Streams|ConvertTo-Json -Compress)
    }
    foreach($row in $gitState){
      (Get-FileHash -LiteralPath $row.Index).Hash | Should -Be $row.IndexHash
      (& $script:realGitCommand -C $row.Root rev-parse HEAD) | Should -Be $row.Head
    }
    Test-Path -LiteralPath $script:archive | Should -BeFalse
    Test-Path -LiteralPath $output | Should -BeFalse
  }

  It 'protects every nested current or future sprint match in planning across all three selectors and refuses execution' {
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

    { Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Scope StableWorktree,SprintCarryover -Execute -ArchiveRoot $script:archive -Confirm:$false } | Should -Throw '*Execution held*'
    foreach ($path in $before.Keys) { (Get-FileHash -LiteralPath $path).Hash | Should -Be $before[$path] }
    Test-Path -LiteralPath (Join-Path $script:stable $oldUntracked) | Should -BeTrue
    Test-Path -LiteralPath (Join-Path $script:sprint $oldUntracked) | Should -BeTrue
  }

  It 'skips inherited files that have uncommitted modifications' {
    Set-Content -LiteralPath (Join-Path $script:sprint '_generated/legacy-tracked.txt') -Value 'edited'
    $r = Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName 'Repo' `
      -Scope SprintCarryover -ArchiveRoot $script:archive -Confirm:$false

    $r.Sprint[0].SkippedModified | Should -Contain '_generated/legacy-tracked.txt'
    Test-Path (Join-Path $script:sprint '_generated/legacy-tracked.txt') | Should -BeTrue
  }

  It 'plans only actual same-path equal candidates and preserves different or missing partners' {
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

    { Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Scope SprintCarryover -Execute -ArchiveRoot $script:archive -Confirm:$false } | Should -Throw '*Execution held*'
    foreach($rel in @($equal,$empty,$different,$missing)){Test-Path -LiteralPath (Join-Path $script:sprint $rel) | Should -BeTrue}
    (Get-FileHash -LiteralPath (Join-Path $script:sprint $different)).Hash | Should -Be $beforeDifferent
    $plan.Sprint[0].ReadyForRemoval | Should -BeFalse
    $plan.Sprint[0].NamedStreamsVerified | Should -BeFalse
    $plan.Sprint[0].CustodyVerified | Should -BeFalse
  }

  It 'plans combined scopes without removing either equal partner' {
    $rel='_generated/Sprint0015/combined.bin'
    foreach($root in @($script:stable,$script:sprint)){New-TestFile $root $rel 'equal baseline'}
    $r=Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Scope StableWorktree,SprintCarryover
    $r.Errors | Should -BeNullOrEmpty
    $r.Sprint[0].PriorSprintNamedUntracked | Should -Contain $rel
    Test-Path -LiteralPath (Join-Path $script:stable $rel) | Should -BeTrue
    Test-Path -LiteralPath (Join-Path $script:sprint $rel) | Should -BeTrue
  }

  It 'preserves staged changes before asking the byte comparator' {
    New-TestFile $script:sprint '_generated/legacy-tracked.txt' 'staged WIP'
    Invoke-TestGit $script:sprint add -f -- _generated/legacy-tracked.txt | Out-Null
    $r = Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Scope SprintCarryover -ArchiveRoot $script:archive -Confirm:$false
    $r.Sprint[0].SkippedModified | Should -Contain '_generated/legacy-tracked.txt'
    (Get-Content -LiteralPath (Join-Path $script:sprint '_generated/legacy-tracked.txt') -Raw).Trim() | Should -Be 'staged WIP'
    ($r.Sprint[0].DefaultDataWitnesses.Binding.RelativePath) | Should -Not -Contain '_generated/legacy-tracked.txt'
  }

  It 'holds carryover when stable branch identity differs' {
    Invoke-TestGit $script:stable checkout -q -b other | Out-Null
    $r = Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Scope SprintCarryover -ArchiveRoot $script:archive -Confirm:$false
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
    $r = Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Scope SprintCarryover -ArchiveRoot $script:archive -Confirm:$false
    $r.Sprint[0].Action | Should -Be Held
    $r.Errors -join ' ' | Should -Match 'Git inventory failed'
    $r.Sprint[0].Archive | Should -BeNullOrEmpty
    Test-Path -LiteralPath (Join-Path $script:sprint '_generated/legacy-tracked.txt') | Should -BeTrue
  }

  It 'refuses before legacy archive hooks can change source bytes or the index' {
    Mock Compress-Archive { throw 'Archive hook must not run' }
    { Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Scope SprintCarryover -Execute -ArchiveRoot $script:archive -Confirm:$false } | Should -Throw '*Execution held*'
    Should -Invoke Compress-Archive -Times 0
    Test-Path -LiteralPath $script:archive | Should -BeFalse
    @(Invoke-TestGit $script:sprint diff --cached --name-only).Count | Should -Be 0
  }





  It 'loads the private helper from source when it is not already available' {
    Remove-Item Function:\Get-GeneratedRemediationByteComparison -ErrorAction Stop
    try {
      $r = Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Scope SprintCarryover
      $r.Errors | Should -BeNullOrEmpty
      $r.Sprint[0].InheritedTracked | Should -Contain '_generated/legacy-tracked.txt'
    } finally { . "$PSScriptRoot\..\..\private\Get-GeneratedRemediationByteComparison.ps1" }
  }

  It 'refuses missing custody before requiring an archive destination' {
    { Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Scope StableWorktree -Execute -Confirm:$false } | Should -Throw '*Execution held*complete approved*'
  }

  It 'rejects unsupported options before Git autoload output or source and index mutation' {
    $sourcePath=Join-Path $script:sprint '_generated/legacy-tracked.txt'
    $sourceHash=(Get-FileHash -LiteralPath $sourcePath).Hash
    $indexPath=(& $script:realGitCommand -C $script:sprint rev-parse --path-format=absolute --git-path index)
    $indexHash=(Get-FileHash -LiteralPath $indexPath).Hash
    $history=Join-Path $script:gitRoot 'history'
    $evidence=Join-Path $script:gitRoot 'output/report.json'
    Mock git { throw 'Unexpected Git call' }
    Mock Get-Command { throw 'Unexpected helper lookup' }
    Mock Import-Module { throw 'Unexpected helper loading' }
    Mock New-Item { throw 'Unexpected output creation' }
    $cases=@(
      @{Execute=$true;NoArchive=$true;Scope=@('StableWorktree')},
      @{Execute=$true;NoArchive=$true;Scope=@('SprintCarryover')},
      @{Execute=$true;NoArchive=$true;Scope=@('StableWorktree','SprintCarryover');WhatIf=$true},
      @{Execute=$true;Scope=@('StableHistory')},
      @{Execute=$true;Scope=@('StableWorktree','StableHistory')},
      @{Execute=$true},
      @{PushRewrittenHistory=$true;Scope=@('StableHistory')},
      @{Execute=$true;PushRewrittenHistory=$true;Scope=@('SprintCarryover')}
    )
    foreach($options in $cases){
      { Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -ArchiveRoot $script:archive -HistoryWorkRoot $history -EvidencePath $evidence -Confirm:$false @options } | Should -Throw
    }
    { Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Scope SprintCarryover -Execute -NoArchive -Confirm:$false } | Should -Throw '*NoArchive*unsupported*'
    { Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Scope StableHistory -Execute -Confirm:$false } | Should -Throw '*StableHistory execution is retired*'
    { Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -PushRewrittenHistory } | Should -Throw '*PushRewrittenHistory is retired*'
    Should -Invoke git -Times 0
    Should -Invoke Get-Command -Times 0
    Should -Invoke Import-Module -Times 0
    Should -Invoke New-Item -Times 0
    foreach($path in @($script:archive,$history,$evidence)){Test-Path -LiteralPath $path | Should -BeFalse}
    (Get-FileHash -LiteralPath $sourcePath).Hash | Should -Be $sourceHash
    (Get-FileHash -LiteralPath $indexPath).Hash | Should -Be $indexHash
  }

  It 'does not accept an archive-looking destination as complete custody proof' {
    $destination=Join-Path $script:stable '_generated/arch'
    { Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Scope StableWorktree -Execute -ArchiveRoot $destination -Confirm:$false } | Should -Throw '*Execution held*'
    Test-Path -LiteralPath $destination | Should -BeFalse
  }

  It 'keeps history and NoArchive planning read-only with legacy parameters' {
    $history=Join-Path $script:gitRoot 'unused-history'
    $r=Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Scope StableHistory -NoArchive -HistoryWorkRoot $history
    $r.Mode | Should -Be Plan
    $r.History[0].Action | Should -Be Planned
    $r.History[0].HistoryPathCount | Should -Be 2
    $r.History[0].BareClone | Should -BeNullOrEmpty
    $r.History[0].RefsRewritten | Should -BeNullOrEmpty
    $r.History[0].Pushed | Should -BeFalse
    Test-Path -LiteralPath $history | Should -BeFalse
    Test-Path -LiteralPath $script:archive | Should -BeFalse
    $worktreePlan=Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Scope StableWorktree,SprintCarryover -NoArchive
    $worktreePlan.Mode | Should -Be Plan
    $worktreePlan.Errors | Should -BeNullOrEmpty
    Test-Path -LiteralPath (Join-Path $script:sprint '_generated/legacy-tracked.txt') | Should -BeTrue
  }

  It 'skips the stable scope when the stable worktree is not on the stable branch' {
    Invoke-TestGit $script:stable checkout -q -b other | Out-Null
    $r = Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName 'Repo' `
      -Scope StableWorktree -ArchiveRoot $script:archive -Confirm:$false
    $r.Stable[0].Action | Should -BeLike 'Skipped*'
    Test-Path (Join-Path $script:stable '_generated/AIAdapterBackups/backup.json') | Should -BeTrue
  }

  It 'refuses execution even when the supplied archive destination is a file' {
    New-TestFile $script:gitRoot 'blocked-archive' 'sentinel'
    $path=Join-Path $script:gitRoot 'blocked-archive'
    $before=(Get-FileHash -LiteralPath $path).Hash
    { Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Scope StableWorktree -Execute -ArchiveRoot $path -Confirm:$false } | Should -Throw '*Execution held*'
    (Get-FileHash -LiteralPath $path).Hash | Should -Be $before
  }

  It 'exposes no caller-supplied approval or receipt bypass' {
    foreach($forged in @(@{Approved=$true},@{CustodyVerified=$true},@{CustodyReceipt=[pscustomobject]@{Status='Verified'}})){
      { Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Scope SprintCarryover -Execute -ArchiveRoot $script:archive @forged } | Should -Throw '*parameter*'
    }
    Test-Path -LiteralPath $script:archive | Should -BeFalse
  }

  It 'refuses before attempting a selected payload that would be unavailable' {
    Mock Get-Item { throw 'Unavailable selected payload' } -ParameterFilter { $LiteralPath -like '*backup.json' }
    { Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Scope StableWorktree -Execute -ArchiveRoot $script:archive -Confirm:$false } | Should -Throw '*Execution held*'
    Should -Invoke Get-Item -Times 0 -ParameterFilter { $LiteralPath -like '*backup.json' }
    Test-Path -LiteralPath (Join-Path $script:stable '_generated/AIAdapterBackups/backup.json') | Should -BeTrue
  }

  It 'aborts on native Git inventory failure without deleting untracked files' {
    Mock git { $global:LASTEXITCODE = 128; 'fatal: inventory unavailable' }
    { Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo `
        -Scope StableWorktree -ArchiveRoot $script:archive -Confirm:$false } | Should -Throw '*Git inventory failed*'
    Test-Path (Join-Path $script:stable '_generated/AIAdapterBackups/backup.json') | Should -BeTrue
  }

  It 'rejects a junction before following it or deleting any original' {
    New-TestFile $script:gitRoot 'outside/keep.txt'
    $junction = Join-Path $script:stable '_generated/external'
    New-Item -ItemType Junction -Path $junction -Target (Join-Path $script:gitRoot 'outside') -ErrorAction Stop | Out-Null
    try {
      { Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo `
          -Scope StableWorktree -ArchiveRoot $script:archive -Confirm:$false } | Should -Throw '*Reparse point*'
      Test-Path (Join-Path $script:gitRoot 'outside/keep.txt') | Should -BeTrue
      Test-Path (Join-Path $script:stable '_generated/AIAdapterBackups/backup.json') | Should -BeTrue
    } finally { Remove-Item -LiteralPath $junction -Force }
  }

  It 'includes hidden files in repeated read-only planning without creating archives' {
    New-TestFile $script:stable '_generated/hidden.bin' 'hidden bytes'
    $hidden=Join-Path $script:stable '_generated/hidden.bin'
    (Get-Item -LiteralPath $hidden).Attributes=[IO.FileAttributes]::Hidden
    $before=(Get-FileHash -LiteralPath $hidden).Hash
    foreach($pass in 1..2){
      $r=Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Scope StableWorktree
      $r.Mode | Should -Be Plan
      $r.Stable[0].UntrackedFiles | Should -Be 2
      $r.Stable[0].CurrentSprintProtected | Should -Be 1
      @($r.Stable[0].TrackedDeferred).Count | Should -Be 2
      (Get-FileHash -LiteralPath $hidden).Hash | Should -Be $before
    }
    Test-Path -LiteralPath $script:archive | Should -BeFalse
  }
}
