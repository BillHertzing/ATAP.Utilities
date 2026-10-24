#Requires -Version 7.0

# Task 16.91.b (SC-0470): the R-38 gate that keeps _generated out of stable
# branches. Fixtures are real git repositories under TestDrive.

BeforeAll {
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
  }
  $moduleRoot = Join-Path $PSScriptRoot '..\..'
  . (Join-Path $moduleRoot 'private\Invoke-SprintEndNativeCommand.ps1')
  . (Join-Path $moduleRoot 'private\Get-SprintGeneratedArtifactState.ps1')

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

Describe 'Get-SprintGeneratedArtifactState' {
  BeforeEach {
    $script:root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    $script:planning = New-FixtureRepository (Join-Path $script:root '_Planning-wt-40-Sprint-0016-work-items')
    $script:ace = New-FixtureRepository (Join-Path $script:root 'Ace-wt-47-Sprint-0016-work-items')
    $script:worktrees = @($script:planning, $script:ace)
  }

  It 'passes when nothing under _generated is tracked or cited' {
    New-FixtureFile (Join-Path $script:ace '_generated/Sprint0016/scratch.log')
    New-FixtureFile (Join-Path $script:planning 'Tasks.Sprint0016.md') '- [ ] Task 16.1 no evidence yet'

    $result = Get-SprintGeneratedArtifactState -WorktreePaths $script:worktrees -PlanningRoot $script:planning

    $result.Ok | Should -BeTrue
    $result.TrackedPaths.Count | Should -Be 0
    $result.CitedPaths.Count | Should -Be 0
  }

  It 'fails on a force-added _generated file and names it' {
    New-FixtureFile (Join-Path $script:ace '_generated/Sprint0016/evidence.json')
    & git -C $script:ace add -f '_generated/Sprint0016/evidence.json' 2>&1 | Out-Null

    $result = Get-SprintGeneratedArtifactState -WorktreePaths $script:worktrees -PlanningRoot $script:planning

    $result.Ok | Should -BeFalse
    $result.Failures | Should -Contain 'TrackedGeneratedArtifacts'
    $result.TrackedPaths.Count | Should -Be 1
    $result.TrackedPaths[0].Path | Should -Be '_generated/Sprint0016/evidence.json'
    $result.TrackedPaths[0].Worktree | Should -Be ([IO.Path]::GetFullPath($script:ace))
  }

  It 'fails when a board cites an existing _generated file' {
    New-FixtureFile (Join-Path $script:planning '_generated/Sprint0016/Task16.1/Evidence.md')
    New-FixtureFile (Join-Path $script:planning 'Tasks.Sprint0016.md') `
      '- [x] Task 16.1 Evidence: `_generated/Sprint0016/Task16.1/Evidence.md`.'

    $result = Get-SprintGeneratedArtifactState -WorktreePaths $script:worktrees -PlanningRoot $script:planning

    $result.Ok | Should -BeFalse
    $result.Failures | Should -Contain 'CitedGeneratedArtifacts'
    $result.CitedPaths.Count | Should -Be 1
    $result.CitedPaths[0].LineNumber | Should -Be 1
    $result.CitedPaths[0].ResolvedPath |
      Should -Be ([IO.Path]::GetFullPath((Join-Path $script:planning '_generated/Sprint0016/Task16.1/Evidence.md')))
  }

  It 'fails when InformationForTheFuture cites an existing _generated directory with backslashes and a trailing period' {
    New-FixtureFile (Join-Path $script:ace '_generated/Sprint0016/Task16.2/run.json')
    New-FixtureFile (Join-Path $script:planning 'InformationForTheFuture/Sprint0016/Note.md') `
      'Results are in _generated\Sprint0016\Task16.2\.'

    $result = Get-SprintGeneratedArtifactState -WorktreePaths $script:worktrees -PlanningRoot $script:planning

    $result.Ok | Should -BeFalse
    $result.CitedPaths.ResolvedPath |
      Should -Contain ([IO.Path]::GetFullPath((Join-Path $script:ace '_generated/Sprint0016/Task16.2')))
  }

  It 'resolves a JSON-escaped citation in the HTML board' {
    New-FixtureFile (Join-Path $script:planning '_generated/Sprint0016/Task16.3/run.json')
    New-FixtureFile (Join-Path $script:planning 'Tasks.Sprint0016.html') `
      '{"purpose":"Evidence: _generated\\Sprint0016\\Task16.3\\run.json"}'

    $result = Get-SprintGeneratedArtifactState -WorktreePaths $script:worktrees -PlanningRoot $script:planning

    $result.CitedPaths.Count | Should -Be 1
    $result.CitedPaths[0].ResolvedPath |
      Should -Be ([IO.Path]::GetFullPath((Join-Path $script:planning '_generated/Sprint0016/Task16.3/run.json')))
  }

  It 'passes once the cited evidence is relocated, even though the citation text remains' {
    New-FixtureFile (Join-Path $script:planning 'Tasks.Sprint0016.md') `
      '- [x] Task 16.1 Evidence: _generated/Sprint0016/Task16.1/Evidence.md (moved to InformationForTheFuture)'

    $result = Get-SprintGeneratedArtifactState -WorktreePaths $script:worktrees -PlanningRoot $script:planning

    $result.Ok | Should -BeTrue
  }

  It 'resolves a citation that names a worktree folder only against that worktree' {
    New-FixtureFile (Join-Path $script:planning '_generated/Sprint0016/shared.md')
    New-FixtureFile (Join-Path $script:planning 'Tasks.Sprint0016.md') `
      'See C:/Repos/Ace-wt-47-Sprint-0016-work-items/_generated/Sprint0016/shared.md'

    $result = Get-SprintGeneratedArtifactState -WorktreePaths $script:worktrees -PlanningRoot $script:planning

    $result.Ok | Should -BeTrue
  }

  It 'does not resolve wildcard citations' {
    New-FixtureFile (Join-Path $script:planning '_generated/Sprint0016/Task16.1/Evidence.md')
    New-FixtureFile (Join-Path $script:planning 'Tasks.Sprint0016.md') 'Never remove _generated/Sprint0016/Task16.?'

    $result = Get-SprintGeneratedArtifactState -WorktreePaths $script:worktrees -PlanningRoot $script:planning

    $result.CitedPaths.Count | Should -Be 0
  }

  It 'ignores citations in planning files outside the boards and InformationForTheFuture' {
    New-FixtureFile (Join-Path $script:planning '_generated/Sprint0016/Task16.1/Evidence.md')
    New-FixtureFile (Join-Path $script:planning 'Research/Note.md') '_generated/Sprint0016/Task16.1/Evidence.md'

    $result = Get-SprintGeneratedArtifactState -WorktreePaths $script:worktrees -PlanningRoot $script:planning

    $result.Ok | Should -BeTrue
  }

  It 'fails closed when a worktree is not a git repository' {
    $plain = Join-Path $script:root 'NotARepo-wt-1-Sprint-0016-work-items'
    New-Item -ItemType Directory -Path $plain -Force | Out-Null

    $result = Get-SprintGeneratedArtifactState -WorktreePaths @($script:planning, $plain) -PlanningRoot $script:planning

    $result.Ok | Should -BeFalse
    $result.Failures | Should -Contain "GitListFailed:$([IO.Path]::GetFullPath($plain))"
  }

  It 'fails closed when the planning root is missing' {
    $result = Get-SprintGeneratedArtifactState -WorktreePaths @($script:ace) -PlanningRoot (Join-Path $script:root 'missing')

    $result.Ok | Should -BeFalse
    $result.Failures | Should -Contain 'PlanningRootMissing'
  }
}
