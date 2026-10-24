BeforeAll {
  # Isolate this synthetic test process; the production helper never changes its parent environment.
  $script:savedGitEnvironment = @{}
  foreach ($key in @([Environment]::GetEnvironmentVariables().Keys | Where-Object { $_ -like 'GIT_*' })) {
    $script:savedGitEnvironment[$key] = [Environment]::GetEnvironmentVariable($key, 'Process')
    Remove-Item -LiteralPath "Env:$key"
  }
  . "$PSScriptRoot/../../private/Get-GeneratedRemediationGitSnapshot.ps1"
  $script:evidenceRoot = [IO.Path]::GetFullPath("$PSScriptRoot/../../../../_generated/Sprint0016/Task16.84/GitSnapshot")
  $script:fixtureRoot = Join-Path $script:evidenceRoot ('Fixtures-' + [guid]::NewGuid().ToString('N').Substring(0, 12))
  $null = New-Item -ItemType Directory -Path $script:fixtureRoot -Force
  function Invoke-FixtureGit {
    param([string]$Root, [string[]]$Arguments)
    $output = & git -C $Root -c core.hooksPath= -c user.name=Fixture -c user.email=fixture@example.invalid -c commit.gpgsign=false @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Fixture Git failed: $output" }
    $output
  }
  function Get-FixtureRepository {
    $root = Join-Path $script:fixtureRoot ([guid]::NewGuid().ToString('N').Substring(0, 12))
    $null = New-Item -ItemType Directory -Path $root
    $null = Invoke-FixtureGit $root @('init', '-q', '-b', 'main')
    [IO.File]::WriteAllText("$root/tracked.txt", 'initial')
    [IO.File]::WriteAllText("$root/.gitignore", "ignored/`n")
    $null = Invoke-FixtureGit $root @('add', '--all')
    $null = Invoke-FixtureGit $root @('commit', '-q', '-m', 'fixture')
    return $root
  }
}

AfterAll {
  foreach ($key in @([Environment]::GetEnvironmentVariables().Keys | Where-Object { $_ -like 'GIT_*' })) { Remove-Item -LiteralPath "Env:$key" }
  foreach ($key in $script:savedGitEnvironment.Keys) { [Environment]::SetEnvironmentVariable($key, $script:savedGitEnvironment[$key], 'Process') }
}

Describe 'Read-only Git metadata capture' {
  It 'emits exactly one bound snapshot without changing index bytes or refs' {
    $root = Get-FixtureRepository
    $indexBefore = (Get-FileHash -LiteralPath "$root/.git/index").Hash
    $refsBefore = @(Invoke-FixtureGit $root @('show-ref')) -join "`n"
    $result = @(Get-GeneratedRemediationGitSnapshot -RootPath $root -ExpectedCommonGitDir "$root/.git")
    $result.Count | Should -Be 1
    $result[0].Success | Should -BeTrue -Because ($result[0].Errors -join ';')
    $result[0].Consistent | Should -BeTrue
    $result[0].Binding.Root | Should -Be ([IO.Path]::GetFullPath($root))
    $result[0].Observations.Count | Should -Be 2
    $result[0].InventoryComplete | Should -BeFalse
    $result[0].ReadyForManifest | Should -BeFalse
    (Get-FileHash -LiteralPath "$root/.git/index").Hash | Should -Be $indexBefore
    (@(Invoke-FixtureGit $root @('show-ref')) -join "`n") | Should -BeExactly $refsBefore
  }
  It 'binds a linked worktree to its own gitDir/index and shared commonDir' {
    $root = Get-FixtureRepository
    $linked = $root + '-linked'
    $null = Invoke-FixtureGit $root @('worktree', 'add', '-q', '-b', 'linked', $linked)
    $r = Get-GeneratedRemediationGitSnapshot $linked "$root/.git"
    $r.Success | Should -BeTrue -Because ($r.Errors -join ';')
    $r.Binding.CommonGitDir | Should -Be ([IO.Path]::GetFullPath("$root/.git"))
    $r.Binding.GitDir | Should -Not -Be $r.Binding.CommonGitDir
    $r.Observations[0].Branch | Should -Be 'refs/heads/linked'
  }
  It 'explicitly reports a detached HEAD' {
    $root = Get-FixtureRepository
    $null = Invoke-FixtureGit $root @('checkout', '--detach', '-q', 'HEAD')
    $r = Get-GeneratedRemediationGitSnapshot $root "$root/.git"
    $r.Success | Should -BeTrue -Because ($r.Errors -join ';')
    $r.Observations[0].Detached | Should -BeTrue
    $r.Observations[0].Branch | Should -BeNullOrEmpty
  }
  It 'retains NUL delimiters and UTF8 spaces/Unicode in staged, unstaged, untracked and ignored records' {
    $root = Get-FixtureRepository
    $unicodeName = 'space ' + [char]0x96ea + '.txt'
    [IO.File]::WriteAllText((Join-Path $root $unicodeName), 'stage')
    $null = Invoke-FixtureGit $root @('add', '--', $unicodeName)
    [IO.File]::WriteAllText("$root/tracked.txt", 'unstaged')
    [IO.File]::WriteAllText("$root/untracked file.txt", 'new')
    $null = New-Item -ItemType Directory -Path "$root/ignored"
    [IO.File]::WriteAllText("$root/ignored/item.txt", 'ignored')
    $indexBefore = (Get-FileHash -LiteralPath "$root/.git/index").Hash
    $r = Get-GeneratedRemediationGitSnapshot $root "$root/.git"
    $r.Success | Should -BeTrue -Because ($r.Errors -join ';')
    $statusBytes = [Convert]::FromBase64String($r.Observations[0].StatusBytesBase64)
    $statusText = [Text.UTF8Encoding]::new($false, $true).GetString($statusBytes)
    $statusText.Contains([char]0) | Should -BeTrue
    $statusText.Contains($unicodeName) | Should -BeTrue
    $statusText.Contains('tracked.txt') | Should -BeTrue
    $statusText.Contains('? untracked file.txt') | Should -BeTrue
    $statusText.Contains('! ignored/') | Should -BeTrue
    $stageText = [Text.UTF8Encoding]::new($false, $true).GetString([Convert]::FromBase64String($r.Observations[0].StageBytesBase64))
    $stageText.Contains($unicodeName) | Should -BeTrue
    (Get-FileHash -LiteralPath "$root/.git/index").Hash | Should -Be $indexBefore
  }
  It 'fails closed for invalid roots, subdirectory roots and commonDir mismatches' {
    $root = Get-FixtureRepository
    $null = New-Item -ItemType Directory -Path "$root/child"
    foreach ($inputRoot in @("$root/missing", "$root/child")) {
      (Get-GeneratedRemediationGitSnapshot $inputRoot "$root/.git").Success | Should -BeFalse
    }
    (Get-GeneratedRemediationGitSnapshot $root $script:fixtureRoot).Success | Should -BeFalse
  }
  It 'rejects ambient Git redirection without changing the parent environment' {
    $root = Get-FixtureRepository
    $oldValue = [Environment]::GetEnvironmentVariable('GIT_DIR', 'Process')
    try {
      [Environment]::SetEnvironmentVariable('GIT_DIR', 'deliberately-invalid', 'Process')
      $r = Get-GeneratedRemediationGitSnapshot $root "$root/.git"
      $r.Success | Should -BeFalse
      ($r.Errors -join ';') | Should -Match 'Ambient'
      [Environment]::GetEnvironmentVariable('GIT_DIR', 'Process') | Should -BeExactly 'deliberately-invalid'
    } finally {
      if ($null -eq $oldValue) { Remove-Item -LiteralPath Env:GIT_DIR }
      else { [Environment]::SetEnvironmentVariable('GIT_DIR', $oldValue, 'Process') }
    }
  }
  It 'fails closed on unborn HEAD, missing index, index locks and malformed native HEAD state' {
    $unborn = Join-Path $script:fixtureRoot 'unborn'
    $null = New-Item -ItemType Directory -Path $unborn
    $null = Invoke-FixtureGit $unborn @('init', '-q', '-b', 'main')
    (Get-GeneratedRemediationGitSnapshot $unborn "$unborn/.git").Success | Should -BeFalse
    $root = Get-FixtureRepository
    # Fixture-only move preserves the original bytes and creates a missing-index state.
    Move-Item -LiteralPath "$root/.git/index" -Destination "$root/.git/index.saved"
    (Get-GeneratedRemediationGitSnapshot $root "$root/.git").Success | Should -BeFalse
    $root = Get-FixtureRepository
    [IO.File]::WriteAllText("$root/.git/index.lock", 'fixture lock')
    (Get-GeneratedRemediationGitSnapshot $root "$root/.git").Success | Should -BeFalse
    $root = Get-FixtureRepository
    [IO.File]::WriteAllText("$root/.git/HEAD", "ref: refs/heads/nonexistent`n")
    $r = Get-GeneratedRemediationGitSnapshot $root "$root/.git"
    $r.Success | Should -BeFalse
    ($r.Errors -join ';') | Should -Match 'exit'
  }
  It 'does not execute configured filters and rejects their unsupported state' {
    $root = Get-FixtureRepository
    $null = Invoke-FixtureGit $root @('config', 'filter.fixture.clean', 'deliberately-not-a-command')
    $r = Get-GeneratedRemediationGitSnapshot $root "$root/.git"
    $r.Success | Should -BeFalse
    ($r.Errors -join ';') | Should -Match 'configuration is unsupported'
  }
  It 'drains large binary stdout without losing records or writing the index' {
    $root = Get-FixtureRepository
    for ($i = 0; $i -lt 900; $i++) {
      $name = ('item-{0:D4}-' -f $i) + ('x' * 90) + '.txt'
      [IO.File]::WriteAllText((Join-Path $root $name), 'fixture')
    }
    $null = Invoke-FixtureGit $root @('add', '--all')
    $indexBefore = (Get-FileHash -LiteralPath "$root/.git/index").Hash
    $r = Get-GeneratedRemediationGitSnapshot $root "$root/.git"
    $r.Success | Should -BeTrue -Because ($r.Errors -join ';')
    [Convert]::FromBase64String($r.Observations[0].StageBytesBase64).Length | Should -BeGreaterThan 65536
    [Convert]::FromBase64String($r.Observations[0].StatusBytesBase64).Length | Should -BeGreaterThan 65536
    (Get-FileHash -LiteralPath "$root/.git/index").Hash | Should -Be $indexBefore
  }
  It 'does not mistake equal untracked-status records for equal file contents' {
    $root = Get-FixtureRepository
    [IO.File]::WriteAllText("$root/untracked.txt", 'one')
    $first = Get-GeneratedRemediationGitSnapshot $root "$root/.git"
    [IO.File]::WriteAllText("$root/untracked.txt", 'different bytes')
    $second = Get-GeneratedRemediationGitSnapshot $root "$root/.git"
    $first.Success | Should -BeTrue
    $second.Success | Should -BeTrue
    $first.Observations[0].StatusBytesSHA256 | Should -Be $second.Observations[0].StatusBytesSHA256
    $second.InventoryComplete | Should -BeFalse
    $second.ReadyForManifest | Should -BeFalse
    $second.Limitations | Should -Match 'not atomic'
  }
  It 'rejects a redirecting root ancestor without following it for a snapshot' {
    $root = Get-FixtureRepository
    $aliasPath = $root + '-junction'
    $null = New-Item -ItemType Junction -Path $aliasPath -Target $root
    $r = Get-GeneratedRemediationGitSnapshot $aliasPath "$root/.git"
    $r.Success | Should -BeFalse
    ($r.Errors -join ';') | Should -Match 'Redirecting'
  }
  It 'fails closed on split-index configuration and preserves its bytes' {
    $root = Get-FixtureRepository
    $null = Invoke-FixtureGit $root @('update-index', '--split-index')
    $indexBefore = (Get-FileHash -LiteralPath "$root/.git/index").Hash
    $r = Get-GeneratedRemediationGitSnapshot $root "$root/.git"
    $r.Success | Should -BeFalse
    ($r.Errors -join ';') | Should -Match 'Split index'
    (Get-FileHash -LiteralPath "$root/.git/index").Hash | Should -Be $indexBefore
  }
  It 'checks redirecting ancestors before requesting any descendant metadata' {
    $script:actualGetItem = Get-Command Get-Item -CommandType Cmdlet
    Mock Get-Item { & $script:actualGetItem @PesterBoundParameters }
    Mock Get-Item {
      if ($LiteralPath -eq 'C:\snapshotmock') { return [pscustomobject]@{ Attributes = [IO.FileAttributes]::Directory; LinkTarget = $null } }
      if ($LiteralPath -eq 'C:\snapshotmock\junction') { return [pscustomobject]@{ Attributes = [IO.FileAttributes]::ReparsePoint; LinkTarget = 'C:\elsewhere' } }
      throw 'Descendant metadata must not be requested'
    } -ParameterFilter { $LiteralPath -like 'C:\snapshotmock*' }
    $r = Get-GeneratedRemediationGitSnapshot 'C:\snapshotmock\junction\child' 'C:\snapshotmock\expected'
    $r.Success | Should -BeFalse
    ($r.Errors -join ';') | Should -Match 'Redirecting'
    Should -Invoke Get-Item -Times 0 -Exactly -ParameterFilter { $LiteralPath -like 'C:\snapshotmock\junction\*' }
    Should -Invoke Get-Item -Times 1 -Exactly -ParameterFilter { $LiteralPath -eq 'C:\snapshotmock' }
  }
  It 'rejects UNC and device root/common paths before any target metadata or Git discovery' {
    $root = Get-FixtureRepository
    $script:actualGetItem = Get-Command Get-Item -CommandType Cmdlet
    $script:actualGetCommand = Get-Command Get-Command -CommandType Cmdlet
    Mock Get-Item { & $script:actualGetItem @PesterBoundParameters }
    Mock Get-Item { throw 'Forbidden remote metadata probe' } -ParameterFilter { $LiteralPath -match '^[\\/]{2}' }
    Mock Get-Command { & $script:actualGetCommand @PesterBoundParameters }
    Mock Get-Command { throw 'Forbidden Git discovery' } -ParameterFilter { $Name -eq 'git' }
    foreach ($unsafe in @('\\do-not-contact.invalid\share\repo', '\\?\C:\repo', '\\.\C:\repo', '//do-not-contact.invalid/share/repo')) {
      (Get-GeneratedRemediationGitSnapshot $unsafe "$root/.git").Success | Should -BeFalse
      (Get-GeneratedRemediationGitSnapshot $root $unsafe).Success | Should -BeFalse
    }
    Should -Invoke Get-Item -Times 0 -Exactly -ParameterFilter { $LiteralPath -match '^[\\/]{2}' }
    Should -Invoke Get-Command -Times 0 -Exactly -ParameterFilter { $Name -eq 'git' }
  }
  It 'rejects remote .git and commondir pointers before Git or remote metadata probes' {
    $root = Get-FixtureRepository
    $fakeRoot = Join-Path $script:fixtureRoot ('pointer-' + [guid]::NewGuid().ToString('N').Substring(0, 12))
    $null = New-Item -ItemType Directory -Path $fakeRoot
    [IO.File]::WriteAllText("$fakeRoot/.git", "gitdir: \\do-not-contact.invalid\share\gitdir`n")
    $linked = $root + '-pointerlinked'
    $null = Invoke-FixtureGit $root @('worktree', 'add', '-q', '-b', 'pointerlinked', $linked)
    $gitDir = (Invoke-FixtureGit $linked @('rev-parse', '--absolute-git-dir')).Trim()
    [IO.File]::WriteAllText("$gitDir/commondir", "\\do-not-contact.invalid\share\common`n")
    $script:actualGetItem = Get-Command Get-Item -CommandType Cmdlet
    $script:actualGetCommand = Get-Command Get-Command -CommandType Cmdlet
    Mock Get-Item { & $script:actualGetItem @PesterBoundParameters }
    Mock Get-Item { throw 'Forbidden remote probe' } -ParameterFilter { $LiteralPath -match '^[\\/]{2}' }
    Mock Get-Command { & $script:actualGetCommand @PesterBoundParameters }
    Mock Get-Command { throw 'Forbidden Git discovery' } -ParameterFilter { $Name -eq 'git' }
    foreach ($path in @($fakeRoot, $linked)) {
      $r = Get-GeneratedRemediationGitSnapshot $path "$root/.git"
      $r.Success | Should -BeFalse
      ($r.Errors -join ';') | Should -Match 'control pointer'
    }
    Should -Invoke Get-Command -Times 0 -Exactly -ParameterFilter { $Name -eq 'git' }
    Should -Invoke Get-Item -Times 0 -Exactly -ParameterFilter { $LiteralPath -match '^[\\/]{2}' }
  }
  It 'rejects partial-clone and promisor configuration without running status' {
    foreach ($key in @('extensions.partialClone', 'remote.origin.promisor', 'remote.origin.partialCloneFilter')) {
      $root = Get-FixtureRepository
      $null = Invoke-FixtureGit $root @('config', $key, 'true')
      $r = Get-GeneratedRemediationGitSnapshot $root "$root/.git"
      $r.Success | Should -BeFalse
      $r.Observations.Count | Should -Be 0
      ($r.Errors -join ';') | Should -Match 'configuration is unsupported'
    }
  }
  It 'rejects alternate and promisor stores before Git discovery without reading redirect contents' {
    $roots = @()
    foreach ($name in @('alternates', 'http-alternates', 'fixture.promisor')) {
      $root = Get-FixtureRepository
      $roots += $root
      $store = if ($name -eq 'fixture.promisor') { 'pack' } else { 'info' }
      [IO.File]::WriteAllText("$root/.git/objects/$store/$name", "\\do-not-contact.invalid\share\objects`n")
    }
    $script:actualGetCommand = Get-Command Get-Command -CommandType Cmdlet
    Mock Get-Command { & $script:actualGetCommand @PesterBoundParameters }
    Mock Get-Command { throw 'Forbidden Git discovery' } -ParameterFilter { $Name -eq 'git' }
    foreach ($root in $roots) {
      $r = Get-GeneratedRemediationGitSnapshot $root "$root/.git"
      $r.Success | Should -BeFalse
      ($r.Errors -join ';') | Should -Match 'object stores are unsupported'
    }
    Should -Invoke Get-Command -Times 0 -Exactly -ParameterFilter { $Name -eq 'git' }
  }
  It 'rejects a non-fixed drive before requesting its target metadata' {
    $existing = [IO.Directory]::GetLogicalDrives()
    $unused = @('Z:\', 'Y:\', 'X:\', 'W:\', 'V:\', 'U:\') | Where-Object { $_ -notin $existing } | Select-Object -First 1
    if (-not $unused) { throw 'No unassigned drive available for the no-contact fixture.' }
    $root = Get-FixtureRepository
    $script:actualGetItem = Get-Command Get-Item -CommandType Cmdlet
    Mock Get-Item { & $script:actualGetItem @PesterBoundParameters }
    $script:unsupportedDrive = $unused
    Mock Get-Item { throw 'Forbidden non-fixed drive probe' } -ParameterFilter { $LiteralPath.StartsWith($script:unsupportedDrive) }
    $r = Get-GeneratedRemediationGitSnapshot ($unused + 'no-contact') "$root/.git"
    $r.Success | Should -BeFalse
    ($r.Errors -join ';') | Should -Match 'fixed local drives'
    Should -Invoke Get-Item -Times 0 -Exactly -ParameterFilter { $LiteralPath.StartsWith($script:unsupportedDrive) }
  }
}
