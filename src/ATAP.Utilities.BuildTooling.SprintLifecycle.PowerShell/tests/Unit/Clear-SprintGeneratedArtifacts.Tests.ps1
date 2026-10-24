#Requires -Version 7.0

# Task 16.91.a (SC-0470): the pre-merge _generated clear and its
# protected-evidence guard. Fixtures are real git repositories under TestDrive.

BeforeAll {
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
  }
  $moduleRoot = Join-Path $PSScriptRoot '..\..'
  . (Join-Path $moduleRoot 'private\Invoke-SprintEndNativeCommand.ps1')
  . (Join-Path $moduleRoot 'private\Get-SprintGeneratedArtifactState.ps1')
  . (Join-Path $moduleRoot 'public\Clear-SprintGeneratedArtifacts.ps1')

  function New-FixtureRepository {
    param([string]$Path)
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    & git -C $Path init --quiet 2>&1 | Out-Null
    & git -C $Path config user.email 'fixture@example.invalid'
    & git -C $Path config user.name 'Fixture'
    Set-Content -LiteralPath (Join-Path $Path '.gitignore') -Value '_generated/'
    Set-Content -LiteralPath (Join-Path $Path 'readme.md') -Value 'fixture'
    & git -C $Path add -A 2>&1 | Out-Null
    & git -C $Path commit --quiet -m 'init' 2>&1 | Out-Null
    $Path
  }

  function New-FixtureFile {
    param([string]$Path, [string]$Value = 'x')
    New-Item -ItemType Directory -Path (Split-Path -Path $Path -Parent) -Force | Out-Null
    Set-Content -LiteralPath $Path -Value $Value
  }
}

Describe 'Clear-SprintGeneratedArtifacts' {
  BeforeEach {
    $script:gitRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    $script:planning = New-FixtureRepository (Join-Path $script:gitRoot '_Planning-wt-40-Sprint-0016-work-items')
    $script:ace = New-FixtureRepository (Join-Path $script:gitRoot 'Ace-wt-47-Sprint-0016-work-items')
    $script:stable = New-FixtureRepository (Join-Path $script:gitRoot 'Ace')
    New-FixtureFile (Join-Path $script:ace '_generated/Sprint0016/scratch/a.log')
    New-FixtureFile (Join-Path $script:ace '_generated/b.log')
    New-FixtureFile (Join-Path $script:stable '_generated/stable.log')
  }

  It 'clears uncited, untracked sprint _generated contents and leaves stable worktrees alone' {
    $result = Clear-SprintGeneratedArtifacts -SprintNumber '0016' -GitRoot $script:gitRoot -Force

    $result.blocked | Should -BeFalse
    $result.errors.Count | Should -Be 0
    $result.filesRemoved | Should -Be 2
    @(Get-ChildItem -LiteralPath (Join-Path $script:ace '_generated') -Force).Count | Should -Be 0
    Test-Path -LiteralPath (Join-Path $script:stable '_generated/stable.log') | Should -BeTrue
  }

  It 'blocks and removes nothing while a board cites an existing _generated path' {
    New-FixtureFile (Join-Path $script:planning 'Tasks.Sprint0016.md') 'Evidence: _generated/Sprint0016/scratch/a.log'

    $result = Clear-SprintGeneratedArtifacts -SprintNumber '0016' -GitRoot $script:gitRoot -Force

    $result.blocked | Should -BeTrue
    $result.filesRemoved | Should -Be 0
    $result.generatedArtifactState.Failures | Should -Contain 'CitedGeneratedArtifacts'
    $result.errors[0] | Should -Match 'Refusing to clear'
    Test-Path -LiteralPath (Join-Path $script:ace '_generated/b.log') | Should -BeTrue
  }

  It 'blocks and removes nothing while any _generated file is tracked' {
    & git -C $script:ace add -f '_generated/b.log' 2>&1 | Out-Null

    $result = Clear-SprintGeneratedArtifacts -SprintNumber '0016' -GitRoot $script:gitRoot -Force

    $result.blocked | Should -BeTrue
    $result.generatedArtifactState.Failures | Should -Contain 'TrackedGeneratedArtifacts'
    Test-Path -LiteralPath (Join-Path $script:ace '_generated/Sprint0016/scratch/a.log') | Should -BeTrue
  }

  It 'clears only the explicit worktrees it is given' {
    New-FixtureFile (Join-Path $script:planning '_generated/keep.log')

    $result = Clear-SprintGeneratedArtifacts -SprintNumber '0016' -GitRoot $script:gitRoot `
      -WorktreePaths @($script:ace) -PlanningRoot $script:planning -Force

    $result.workTreesScanned | Should -Be 1
    Test-Path -LiteralPath (Join-Path $script:ace '_generated/b.log') | Should -BeFalse
    Test-Path -LiteralPath (Join-Path $script:planning '_generated/keep.log') | Should -BeTrue
  }

  It 'refuses a stable worktree in -WorktreePaths' {
    { Clear-SprintGeneratedArtifacts -SprintNumber '0016' -GitRoot $script:gitRoot `
        -WorktreePaths @($script:stable) -PlanningRoot $script:planning -Force } |
      Should -Throw '*not a Sprint 0016 worktree*'
    Test-Path -LiteralPath (Join-Path $script:stable '_generated/stable.log') | Should -BeTrue
  }

  It 'refuses a worktree from another sprint in -WorktreePaths' {
    $other = New-FixtureRepository (Join-Path $script:gitRoot 'Ace-wt-45-Sprint-0015-work-items')
    { Clear-SprintGeneratedArtifacts -SprintNumber '0016' -GitRoot $script:gitRoot `
        -WorktreePaths @($other) -PlanningRoot $script:planning -Force } |
      Should -Throw '*not a Sprint 0016 worktree*'
  }

  It 'throws when the _Planning sprint worktree cannot be resolved' {
    Remove-Item -LiteralPath $script:planning -Recurse -Force

    { Clear-SprintGeneratedArtifacts -SprintNumber '0016' -GitRoot $script:gitRoot -Force } |
      Should -Throw '*exactly one _Planning Sprint 0016 worktree*'
    Test-Path -LiteralPath (Join-Path $script:ace '_generated/b.log') | Should -BeTrue
  }

  It 'removes nothing under -WhatIf' {
    $result = Clear-SprintGeneratedArtifacts -SprintNumber '0016' -GitRoot $script:gitRoot -WhatIf

    $result.blocked | Should -BeFalse
    $result.filesRemoved | Should -Be 0
    Test-Path -LiteralPath (Join-Path $script:ace '_generated/b.log') | Should -BeTrue
  }
}
