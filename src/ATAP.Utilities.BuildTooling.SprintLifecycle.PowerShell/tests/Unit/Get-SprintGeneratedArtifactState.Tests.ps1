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

  It 'accepts only an exact preserved file while retaining raw citations and unrelated failures' {
    $original = Join-Path $script:planning '_generated/Sprint0016/evidence.txt'
    New-FixtureFile $original 'proof'
    New-FixtureFile (Join-Path $script:planning 'Tasks.Sprint0016.md') '_generated/Sprint0016/evidence.txt'
    $raw = Get-SprintGeneratedArtifactState -WorktreePaths $script:worktrees -PlanningRoot $script:planning
    $proof = Join-Path $script:root 'proof'
    New-Item -ItemType Directory -Path $proof | Out-Null
    $raw | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $proof 'raw.json')
    Copy-Item $original (Join-Path $proof 'preserved.txt')
    $manifest = @{ schemaVersion = '1.0.0'; files = @(@{ worktree = (Split-Path $script:planning -Leaf); relativePath = 'Sprint0016/evidence.txt'; preservedPath = 'preserved.txt'; sha256 = (Get-FileHash $original).Hash; bytes = (Get-Item $original).Length }) }
    $manifest | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $proof 'manifest.json')
    $disposition = @{ schemaVersion = '1.0.0'; SprintNumber = '0016'; GateName = 'CitedGeneratedArtifacts'; RawFailure = @{ path = 'raw.json'; sha256 = (Get-FileHash (Join-Path $proof 'raw.json')).Hash }; ExternalManifest = @{ path = 'manifest.json'; sha256 = (Get-FileHash (Join-Path $proof 'manifest.json')).Hash }; AuthorityReference = 'fixture'; ExpiresAfterSprint = '0016' }
    $record = Join-Path $proof 'disposition.json'
    $disposition | ConvertTo-Json -Depth 10 | Set-Content $record
    $result = Get-SprintGeneratedArtifactState -WorktreePaths $script:worktrees -PlanningRoot $script:planning -GeneratedArtifactDisposition $record
    $result.Ok | Should -BeTrue
    $result.CitedPaths.Count | Should -Be 1
    $result.DispositionedPaths.Count | Should -Be 1
    $result.OriginalFailures | Should -Contain 'CitedGeneratedArtifacts'
    $ephemeralCopy = Join-Path $script:planning '_generated/Sprint0016/copy.txt'
    Copy-Item $original $ephemeralCopy
    Copy-Item (Join-Path $proof 'raw.json') (Join-Path $script:planning 'raw-proof.json')
    $manifest.files[0].preservedPath = '_generated/Sprint0016/copy.txt'
    $manifest | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $script:planning 'manifest-proof.json')
    $ephemeralDisposition = @{ schemaVersion = '1.0.0'; SprintNumber = '0016'; GateName = 'CitedGeneratedArtifacts'; RawFailure = @{ path = 'raw-proof.json'; sha256 = (Get-FileHash (Join-Path $script:planning 'raw-proof.json')).Hash }; ExternalManifest = @{ path = 'manifest-proof.json'; sha256 = (Get-FileHash (Join-Path $script:planning 'manifest-proof.json')).Hash }; AuthorityReference = 'fixture'; ExpiresAfterSprint = '0016' }
    $ephemeralRecord = Join-Path $script:planning 'disposition-proof.json'
    $ephemeralDisposition | ConvertTo-Json -Depth 10 | Set-Content $ephemeralRecord
    $ephemeral = Get-SprintGeneratedArtifactState -WorktreePaths $script:worktrees -PlanningRoot $script:planning -GeneratedArtifactDisposition $ephemeralRecord
    $ephemeral.Ok | Should -BeFalse
    $ephemeral.Failures | Should -Contain 'InvalidGeneratedArtifactDisposition'
    $ephemeral.DispositionError | Should -Be 'NonDurableProofPath'
    $ephemeral.CitedPaths.Count | Should -Be 1
    $ephemeral.DispositionedPaths.Count | Should -Be 0
    New-FixtureFile (Join-Path $script:ace '_generated/Sprint0016/tracked.txt')
    & git -C $script:ace add -f '_generated/Sprint0016/tracked.txt' 2>&1 | Out-Null
    $unrelated = Get-SprintGeneratedArtifactState -WorktreePaths $script:worktrees -PlanningRoot $script:planning -GeneratedArtifactDisposition $record
    $unrelated.Ok | Should -BeFalse
    $unrelated.Failures | Should -Contain 'TrackedGeneratedArtifacts'
    $unrelated.DispositionedPaths.Count | Should -Be 1
    New-FixtureFile (Join-Path $proof 'preserved.txt') 'tampered'
    $bad = Get-SprintGeneratedArtifactState -WorktreePaths $script:worktrees -PlanningRoot $script:planning -GeneratedArtifactDisposition $record
    $bad.Ok | Should -BeFalse
    $bad.Failures | Should -Contain 'CitedGeneratedArtifacts'
    $bad.Failures | Should -Contain 'InvalidGeneratedArtifactDisposition'
    $bad.DispositionedPaths.Count | Should -Be 0
    $legacy = Get-SprintGeneratedArtifactState -WorktreePaths $script:worktrees -PlanningRoot $script:planning
    $legacy.Ok | Should -BeFalse
    $legacy.Failures | Should -Contain 'CitedGeneratedArtifacts'
    $legacy.CitedPaths.Count | Should -Be 1
  }

  It 'rejects nonconforming v1 <Case> while retaining the citation failure' -ForEach @(
    @{ Case = 'numeric sprint and expiry'; RecordSprint = 1234; RecordExpiry = 1234; RawOutcome = $false; ExpectedError = 'InvalidDisposition' }
    @{ Case = 'numeric expiry'; RecordSprint = '0016'; RecordExpiry = 16; RawOutcome = $false; ExpectedError = 'InvalidDisposition' }
    @{ Case = 'non-ASCII sprint and expiry'; RecordSprint = '٠٠١٦'; RecordExpiry = '٠٠١٦'; RawOutcome = $false; ExpectedError = 'InvalidDisposition' }
    @{ Case = 'trailing line feed'; RecordSprint = ('0016' + [char]10); RecordExpiry = ('0016' + [char]10); RawOutcome = $false; ExpectedError = 'InvalidDisposition' }
    @{ Case = 'string false raw outcome'; RecordSprint = '0016'; RecordExpiry = '0016'; RawOutcome = 'false'; ExpectedError = 'InvalidRawFailure' }
  ) {
    $original = Join-Path $script:planning '_generated/Sprint0016/evidence.txt'
    New-FixtureFile $original 'proof'
    New-FixtureFile (Join-Path $script:planning 'Tasks.Sprint0016.md') '_generated/Sprint0016/evidence.txt'
    $raw = Get-SprintGeneratedArtifactState -WorktreePaths $script:worktrees -PlanningRoot $script:planning
    $raw.Ok = $RawOutcome
    $proof = Join-Path $script:root 'proof'
    $rawPath = Join-Path $proof 'raw.json'
    New-FixtureFile $rawPath ($raw | ConvertTo-Json -Depth 10)
    Copy-Item -LiteralPath $original -Destination (Join-Path $proof 'preserved.txt')
    $manifest = @{
      schemaVersion = '1.0.0'
      files = @(@{
        worktree = Split-Path $script:planning -Leaf
        relativePath = 'Sprint0016/evidence.txt'
        preservedPath = 'preserved.txt'
        sha256 = (Get-FileHash -LiteralPath $original).Hash
        bytes = (Get-Item -LiteralPath $original).Length
      })
    }
    $manifestPath = Join-Path $proof 'manifest.json'
    New-FixtureFile $manifestPath ($manifest | ConvertTo-Json -Depth 10)
    $disposition = @{
      schemaVersion = '1.0.0'
      SprintNumber = $RecordSprint
      GateName = 'CitedGeneratedArtifacts'
      RawFailure = @{ path = 'raw.json'; sha256 = (Get-FileHash -LiteralPath $rawPath).Hash }
      ExternalManifest = @{ path = 'manifest.json'; sha256 = (Get-FileHash -LiteralPath $manifestPath).Hash }
      AuthorityReference = 'fixture'
      ExpiresAfterSprint = $RecordExpiry
    }
    $record = Join-Path $proof 'disposition.json'
    New-FixtureFile $record ($disposition | ConvertTo-Json -Depth 10)

    $result = Get-SprintGeneratedArtifactState -WorktreePaths $script:worktrees -PlanningRoot $script:planning -GeneratedArtifactDisposition $record

    $result.Ok | Should -BeFalse
    $result.Failures | Should -Contain 'CitedGeneratedArtifacts'
    $result.Failures | Should -Contain 'InvalidGeneratedArtifactDisposition'
    $result.DispositionError | Should -BeExactly $ExpectedError
    $result.CitedPaths.Count | Should -Be 1
    $result.DispositionedPaths.Count | Should -Be 0
  }
}
