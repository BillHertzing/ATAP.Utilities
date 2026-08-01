#Requires -Modules Pester

# Task 13.88 — AI agent memory junction provisioning at sprint start.
# These tests create REAL git repos, REAL worktrees, and REAL NTFS junctions under
# a temp root. Directory junctions need no elevation, and the pre-existing sprint
# suites already shell out to git, so this stays consistent with the module.

BeforeAll {
  $script:FunctionPath = Join-Path $PSScriptRoot '..' '..' 'private' 'Set-AIAgentMemoryJunction.ps1'
  . $script:FunctionPath

  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments)]$Rest) }
  }

  function script:New-TestRepoWithWorktree {
    param([string]$Root, [string]$RepoName = 'TestRepo')

    $repoPath = Join-Path $Root $RepoName
    New-Item -ItemType Directory -Path $repoPath -Force | Out-Null
    & git -C $repoPath init --quiet 2>&1 | Out-Null
    & git -C $repoPath config user.email 'test@example.com' 2>&1 | Out-Null
    & git -C $repoPath config user.name 'Test' 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repoPath 'seed.txt') -Value 'seed'
    & git -C $repoPath add . 2>&1 | Out-Null
    & git -C $repoPath commit -m 'seed' --quiet 2>&1 | Out-Null

    $wtPath = Join-Path $Root "$RepoName-wt-99-Sprint-9999-work-items"
    & git -C $repoPath worktree add $wtPath -b 'test-sprint-branch' 2>&1 | Out-Null

    [PSCustomObject]@{ RepoPath = $repoPath; WorktreePath = $wtPath }
  }
}

Describe 'Set-AIAgentMemoryJunction' {

  BeforeEach {
    $script:TestRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("aimem-" + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $script:TestRoot -Force | Out-Null
    $script:ProjectsRoot = Join-Path $script:TestRoot 'projects'
    $script:MemoryRoot = Join-Path $script:TestRoot 'AIAgentMemory'
    New-Item -ItemType Directory -Path $script:ProjectsRoot -Force | Out-Null
  }

  AfterEach {
    if ($script:TestRoot -and (Test-Path -LiteralPath $script:TestRoot)) {
      # Remove junctions before the tree so the targets are never followed.
      Get-ChildItem -LiteralPath $script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.LinkType } |
        ForEach-Object { & cmd /c rmdir "$($_.FullName)" 2>&1 | Out-Null }
      Remove-Item -LiteralPath $script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  It 'creates junctions for BOTH the main-repo slug and the worktree slug' {
    $env = script:New-TestRepoWithWorktree -Root $script:TestRoot

    $r = Set-AIAgentMemoryJunction -WorktreePath $env.WorktreePath `
      -AIAgentMemoryRoot $script:MemoryRoot -ClaudeProjectsRoot $script:ProjectsRoot -Confirm:$false

    $r.Success | Should -BeTrue
    $r.Skipped | Should -BeFalse
    # Two distinct slugs: this is the whole point of the fix.
    $r.JunctionsCreated | Should -Be 2
    $r.Junctions.Count | Should -Be 2
    ($r.Junctions.Slug | Select-Object -Unique).Count | Should -Be 2
  }

  It 'points both junctions at the SAME store, so Claude Code and the checkpoint agree' {
    $env = script:New-TestRepoWithWorktree -Root $script:TestRoot

    $r = Set-AIAgentMemoryJunction -WorktreePath $env.WorktreePath `
      -AIAgentMemoryRoot $script:MemoryRoot -ClaudeProjectsRoot $script:ProjectsRoot -Confirm:$false

    ($r.Junctions.Target | Select-Object -Unique).Count | Should -Be 1

    # Round trip: write via one junction, read via the other.
    $a, $b = $r.Junctions
    Set-Content -LiteralPath (Join-Path $a.Link 'probe.md') -Value 'written-through-a'
    (Get-Content -LiteralPath (Join-Path $b.Link 'probe.md') -Raw).Trim() | Should -Be 'written-through-a'
  }

  It 'resolves the main repo from the git common dir, not by trimming the worktree name' {
    $env = script:New-TestRepoWithWorktree -Root $script:TestRoot -RepoName 'Odd.Repo_Name'

    $r = Set-AIAgentMemoryJunction -WorktreePath $env.WorktreePath `
      -AIAgentMemoryRoot $script:MemoryRoot -ClaudeProjectsRoot $script:ProjectsRoot -Confirm:$false

    $r.Success | Should -BeTrue
    $r.RepositoryName | Should -Be 'Odd.Repo_Name'
    # The store is named for the MAIN repo, so all worktrees share one store.
    $r.MemoryRoot | Should -Be (Join-Path $script:MemoryRoot 'Odd.Repo_Name')
  }

  It 'is idempotent — a second run re-points rather than failing' {
    $env = script:New-TestRepoWithWorktree -Root $script:TestRoot

    $first = Set-AIAgentMemoryJunction -WorktreePath $env.WorktreePath `
      -AIAgentMemoryRoot $script:MemoryRoot -ClaudeProjectsRoot $script:ProjectsRoot -Confirm:$false
    Set-Content -LiteralPath (Join-Path $first.Junctions[0].Link 'keep.md') -Value 'survives'

    $second = Set-AIAgentMemoryJunction -WorktreePath $env.WorktreePath `
      -AIAgentMemoryRoot $script:MemoryRoot -ClaudeProjectsRoot $script:ProjectsRoot -Confirm:$false

    $second.Success | Should -BeTrue
    $second.JunctionsCreated | Should -Be 2
    # Re-running must not destroy stored memory.
    (Get-Content -LiteralPath (Join-Path $second.Junctions[0].Link 'keep.md') -Raw).Trim() | Should -Be 'survives'
  }

  It 'migrates a pre-existing REAL memory directory instead of clobbering it' {
    $env = script:New-TestRepoWithWorktree -Root $script:TestRoot

    # Simulate the Sprint 0013 starting state: real memory dir at the worktree slug.
    $makeSlug = { param([string]$p) ($p.Substring(0, 1).ToLower() + $p.Substring(1)) -replace ':', '-' -replace '\\', '-' -replace '_', '-' -replace '\.', '-' -replace '^-', '' }
    $wtSlug = & $makeSlug $env.WorktreePath
    $realMem = Join-Path $script:ProjectsRoot "$wtSlug\memory"
    New-Item -ItemType Directory -Path $realMem -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $realMem 'pre-existing.md') -Value 'must-not-be-lost'

    $r = Set-AIAgentMemoryJunction -WorktreePath $env.WorktreePath `
      -AIAgentMemoryRoot $script:MemoryRoot -ClaudeProjectsRoot $script:ProjectsRoot -Confirm:$false

    $r.Success | Should -BeTrue
    $migrated = Join-Path (Join-Path $script:MemoryRoot 'TestRepo') 'pre-existing.md'
    Test-Path -LiteralPath $migrated | Should -BeTrue
    (Get-Content -LiteralPath $migrated -Raw).Trim() | Should -Be 'must-not-be-lost'
    # And it is now reachable through the junction.
    (Get-Item -LiteralPath $realMem -Force).LinkType | Should -Be 'Junction'
  }

  It 'SKIPS without guessing a path when the Dropbox config root key is unavailable' {
    $env = script:New-TestRepoWithWorktree -Root $script:TestRoot

    $savedSettings = $global:settings
    $savedKeys = $global:configRootKeys
    try {
      $global:settings = @{}
      $global:configRootKeys = @{}

      $r = Set-AIAgentMemoryJunction -WorktreePath $env.WorktreePath `
        -ClaudeProjectsRoot $script:ProjectsRoot -Confirm:$false

      $r.Skipped | Should -BeTrue
      $r.Success | Should -BeTrue          # a skip is not a failure
      $r.JunctionsCreated | Should -Be 0
      $r.MemoryRoot | Should -BeNullOrEmpty
      $r.SkipReason | Should -Match 'DropboxBasePathConfigRootKey'
    } finally {
      $global:settings = $savedSettings
      $global:configRootKeys = $savedKeys
    }
  }

  It 'reports failure rather than throwing when the worktree path does not exist' {
    $r = Set-AIAgentMemoryJunction -WorktreePath (Join-Path $script:TestRoot 'no-such-worktree') `
      -AIAgentMemoryRoot $script:MemoryRoot -ClaudeProjectsRoot $script:ProjectsRoot -Confirm:$false

    $r.Success | Should -BeFalse
    $r.Errors.Count | Should -BeGreaterThan 0
    $r.Errors[0] | Should -Match 'Worktree path not found'
  }

  It 'honours -WhatIf and creates nothing' {
    $env = script:New-TestRepoWithWorktree -Root $script:TestRoot

    $r = Set-AIAgentMemoryJunction -WorktreePath $env.WorktreePath `
      -AIAgentMemoryRoot $script:MemoryRoot -ClaudeProjectsRoot $script:ProjectsRoot -WhatIf

    $r.JunctionsCreated | Should -Be 0
    Test-Path -LiteralPath (Join-Path $script:MemoryRoot 'TestRepo') | Should -BeFalse
  }
}
