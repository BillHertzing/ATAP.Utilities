#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.2.0' }
param([Parameter()][string] $FixtureRoot = $(
  $base = [Environment]::GetEnvironmentVariable('ARTIFACTS_PATH', 'Process')
  if (-not $base) { $base = [Environment]::GetEnvironmentVariable('ARTIFACTS_PATH', 'User') }
  if (-not $base) { throw 'ARTIFACTS_PATH is required.' }
  Join-Path $base 'Sprint0017/Task17.9.b/ComposerByteIdentity/PackageTests'
))

BeforeAll {
  $artifacts = [Environment]::GetEnvironmentVariable('ARTIFACTS_PATH', 'Process')
  if (-not $artifacts) { $artifacts = [Environment]::GetEnvironmentVariable('ARTIFACTS_PATH', 'User') }
  if (-not $artifacts) { throw 'ARTIFACTS_PATH is required.' }
  $mappedRoot = switch ([Environment]::MachineName.ToUpperInvariant()) {
    'UTAT022' { 'D:\ATAPArtifacts' }
    'UTAT01' { 'C:\ATAPArtifacts' }
    default { throw 'No approved artifact root is mapped for this host.' }
  }
  if (-not [string]::Equals([IO.Path]::GetFullPath($artifacts).TrimEnd('\', '/'), $mappedRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'ARTIFACTS_PATH does not match the approved host mapping.'
  }
  $allowed = [IO.Path]::GetFullPath($artifacts).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
  $script:runRoot = [IO.Path]::GetFullPath($FixtureRoot)
  if (-not $runRoot.StartsWith($allowed, [StringComparison]::OrdinalIgnoreCase)) { throw 'FixtureRoot must be beneath ARTIFACTS_PATH.' }
  [IO.Directory]::CreateDirectory($runRoot) | Out-Null
  $null = Get-Command Write-PSFMessage -ErrorAction Stop
  $script:fixedTime = [datetime]::new(2026, 1, 2, 3, 4, 5)
  $moduleRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
  foreach ($relative in @(
      'private/Get-AICoreInstructionBody.ps1',
      'public/Build-AGENTSPerRepository.ps1',
      'public/Build-CLAUDEPerRepository.ps1',
      'public/Build-AgentSpecificPerRepository.ps1'
    )) {
    $tokens = $null; $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $moduleRoot $relative), [ref]$tokens, [ref]$errors)
    if ($errors.Count -or $ast.EndBlock.Statements.Count -ne 1 -or
        $ast.EndBlock.Statements[0] -isnot [Management.Automation.Language.FunctionDefinitionAst]) { throw 'Expected a single source-only function.' }
    . ([scriptblock]::Create($ast.EndBlock.Statements[0].Extent.Text))
  }
  function Write-ComposerByteFixture {
    param([string] $Path, [string] $Text)
    [IO.Directory]::CreateDirectory((Split-Path $Path -Parent)) | Out-Null
    [IO.File]::WriteAllText($Path, $Text, [Text.UTF8Encoding]::new($false))
    [IO.File]::SetLastWriteTime($Path, $fixedTime)
  }
  function New-ComposerByteFixture {
    param([string] $Identity = ([string][char]0xE9))
    $root = Join-Path $runRoot ([guid]::NewGuid().ToString('N'))
    $shared = Join-Path $root 'SharedVSCode-wt-1-Sprint-0017-work-items'
    $repo = Join-Path $root 'Fixture-wt-2-Sprint-0017-work-items'
    $stable = Join-Path $root 'StableFixture'
    foreach ($directory in @($shared, $repo, $stable)) { [IO.Directory]::CreateDirectory($directory) | Out-Null }
    $local = Join-Path $repo 'ai-local.md'
    Write-ComposerByteFixture $local ("# Local identity: " + $Identity + "`r`nLocal body`r")
    Write-ComposerByteFixture (Join-Path $shared 'AGENTS-base.md') "# Shared core fixture`n"
    Write-ComposerByteFixture (Join-Path $shared 'CLAUDE-base.md') "# Shared Claude core fixture`n"
    $bases = @((Join-Path $shared 'GEMINI.md'), (Join-Path $shared '.github/copilot-instructions.md'))
    foreach ($path in $bases) { Write-ComposerByteFixture $path ("# Agent identity: " + $Identity + "`n") }
    $stableFiles = @('AGENTS.md', 'CLAUDE.md', 'GEMINI.md', '.github/copilot-instructions.md')
    foreach ($relative in $stableFiles) {
      $path = Join-Path $stable $relative
      [IO.Directory]::CreateDirectory((Split-Path $path -Parent)) | Out-Null
      [IO.File]::WriteAllText($path, "Stable caller bytes`r`n", [Text.UTF8Encoding]::new($true))
    }
    $context = [pscustomobject]@{
      WorkspacePath = Join-Path $root 'synthetic.code-workspace'
      SharedVSCodePath = $shared
      SprintWorktreePattern = '-wt-\d+-Sprint-\d{4}-work-items$'
      Repositories = @(
        [pscustomobject]@{ Repository = 'Fixture-wt-2-Sprint-0017-work-items'; Path = $repo; Skipped = $false; ResolutionError = $null },
        [pscustomobject]@{ Repository = 'StableFixture'; Path = $stable; Skipped = $true; ResolutionError = $null }
      )
    }
    return @{ Root = $root; Shared = $shared; Repo = $repo; Stable = $stable; Local = $local; Bases = $bases; Context = $context }
  }
  function Invoke-ComposerByteFixture {
    param([string] $Lane, $Fixture, [switch] $WhatIf)
    $arguments = @{ RepositoryContext = $Fixture.Context; Confirm = $false }
    if ($WhatIf) { $arguments.WhatIf = $true }
    & ('Build-' + $Lane + 'PerRepository') @arguments
  }
  function Get-ComposerBytePaths {
    param([string] $Lane, $Fixture)
    $relative = switch ($Lane) {
      'AGENTS' { @('AGENTS.md') }
      'CLAUDE' { @('CLAUDE.md') }
      'AgentSpecific' { @('GEMINI.md', '.github/copilot-instructions.md') }
    }
    return @($relative | ForEach-Object { Join-Path $Fixture.Repo $_ })
  }
  function Assert-ComposerByteActions {
    param([string] $Lane, $Result, [string] $Expected)
    $Result.Success | Should -BeTrue
    $rows = @($Result.RepositoryResults | Where-Object { -not $_.Skipped })
    $rows.Count | Should -Be 1
    if ($Lane -eq 'AgentSpecific') {
      $rows[0].Files.Count | Should -Be 2
      foreach ($file in $rows[0].Files) { $file.Action | Should -BeExactly $Expected; $file.Success | Should -BeTrue }
    }
    else {
      $rows[0].Action | Should -BeExactly $Expected
      $Result.CoreOrigin | Should -BeExactly 'legacy-base'
    }
    @($Result.RepositoryResults | Where-Object Skipped).Count | Should -Be 1
  }
  function Get-ComposerByteState {
    param([string[]] $Path)
    return @($Path | ForEach-Object { $_ + ':' + [Convert]::ToBase64String([IO.File]::ReadAllBytes($_)) }) -join [char]10
  }
  function Get-ComposerAllFixtureState {
    param([string] $Root)
    return @(Get-ChildItem -LiteralPath $Root -Recurse -Force | Sort-Object FullName | ForEach-Object {
        if ($_.PSIsContainer) { 'D:' + $_.FullName }
        else { 'F:' + $_.FullName + ':' + [Convert]::ToBase64String([IO.File]::ReadAllBytes($_.FullName)) + ':' + $_.LastWriteTimeUtc.Ticks }
      }) -join [char]10
  }
}

Describe 'Actual composer lane byte identity on disposable RepositoryContext inputs' {
  BeforeEach {
    Mock Write-PSFMessage {}
    Mock Get-Date { [datetime]::new(2026, 1, 2, 3, 4, 5) }
  }

  It '<Lane> repairs same-content BOM bytes and then is a genuine no-op' -ForEach @(
    @{ Lane = 'AGENTS' }, @{ Lane = 'CLAUDE' }, @{ Lane = 'AgentSpecific' }
  ) {
    $f = New-ComposerByteFixture
    $inputs = @($f.Local) + @($f.Bases) + @(Get-ChildItem -LiteralPath $f.Stable -Recurse -File | ForEach-Object FullName)
    $beforeInputs = Get-ComposerByteState $inputs
    $first = Invoke-ComposerByteFixture $Lane $f
    Assert-ComposerByteActions $Lane $first 'written'
    $paths = Get-ComposerBytePaths $Lane $f
    $expected = @{}
    foreach ($path in $paths) {
      $expected[$path] = [IO.File]::ReadAllBytes($path)
      [IO.File]::WriteAllBytes($path, [byte[]](@(239, 187, 191) + $expected[$path]))
    }
    $repair = Invoke-ComposerByteFixture $Lane $f
    Assert-ComposerByteActions $Lane $repair 'written'
    foreach ($path in $paths) {
      $bytes = [IO.File]::ReadAllBytes($path)
      [Convert]::ToBase64String($bytes) | Should -BeExactly ([Convert]::ToBase64String($expected[$path]))
      [Convert]::ToHexString($bytes) | Should -Not -Match '^EFBBBF'
      ($bytes -contains [byte]13) | Should -BeFalse
      $bytes[-1] | Should -Be 10
    }
    $beforeRepeat = Get-ComposerAllFixtureState $f.Root
    Assert-ComposerByteActions $Lane (Invoke-ComposerByteFixture $Lane $f) 'unchanged'
    Get-ComposerAllFixtureState $f.Root | Should -BeExactly $beforeRepeat
    Get-ComposerByteState $inputs | Should -BeExactly $beforeInputs
  }

  It '<Lane> writes exact <Form> bytes after a culture-equivalent local or base change' -ForEach @(
    @{ Lane = 'AGENTS'; Form = 'NFD' }, @{ Lane = 'AGENTS'; Form = 'NFC' },
    @{ Lane = 'CLAUDE'; Form = 'NFD' }, @{ Lane = 'CLAUDE'; Form = 'NFC' },
    @{ Lane = 'AgentSpecific'; Form = 'NFD' }, @{ Lane = 'AgentSpecific'; Form = 'NFC' }
  ) {
    $priorCulture = [Threading.Thread]::CurrentThread.CurrentCulture
    try {
      [Threading.Thread]::CurrentThread.CurrentCulture = [Globalization.CultureInfo]::GetCultureInfo('en-US')
      $nfc = [string][char]0xE9
      $nfd = 'e' + [char]0x301
      $old = if ($Form -eq 'NFD') { $nfc } else { $nfd }
      $next = if ($Form -eq 'NFD') { $nfd } else { $nfc }
      $f = New-ComposerByteFixture -Identity $old
      Assert-ComposerByteActions $Lane (Invoke-ComposerByteFixture $Lane $f) 'written'
      $paths = Get-ComposerBytePaths $Lane $f
      $expected = @{}
      foreach ($path in $paths) { $expected[$path] = [Text.Encoding]::UTF8.GetBytes([IO.File]::ReadAllText($path).Replace($old, $next)) }
      $changedInputs = if ($Lane -eq 'AgentSpecific') { @($f.Bases) } else { @($f.Local) }
      foreach ($path in $changedInputs) { Write-ComposerByteFixture $path ([IO.File]::ReadAllText($path).Replace($old, $next)) }
      $protected = @($f.Local) + @(Get-ChildItem -LiteralPath $f.Stable -Recurse -File | ForEach-Object FullName)
      $protectedBefore = Get-ComposerByteState $protected
      Assert-ComposerByteActions $Lane (Invoke-ComposerByteFixture $Lane $f) 'written'
      foreach ($path in $paths) {
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($path)) | Should -BeExactly ([Convert]::ToBase64String($expected[$path]))
      }
      Assert-ComposerByteActions $Lane (Invoke-ComposerByteFixture $Lane $f) 'unchanged'
      Get-ComposerByteState $protected | Should -BeExactly $protectedBefore
    }
    finally { [Threading.Thread]::CurrentThread.CurrentCulture = $priorCulture }
  }

  It '<Lane> WhatIf preserves all input/output bytes and missing destination directories' -ForEach @(
    @{ Lane = 'AGENTS' }, @{ Lane = 'CLAUDE' }, @{ Lane = 'AgentSpecific' }
  ) {
    $f = New-ComposerByteFixture
    $before = Get-ComposerAllFixtureState $f.Root
    $null = Invoke-ComposerByteFixture $Lane $f -WhatIf
    Get-ComposerAllFixtureState $f.Root | Should -BeExactly $before
    foreach ($path in (Get-ComposerBytePaths $Lane $f)) { Test-Path -LiteralPath $path | Should -BeFalse }
  }
}
