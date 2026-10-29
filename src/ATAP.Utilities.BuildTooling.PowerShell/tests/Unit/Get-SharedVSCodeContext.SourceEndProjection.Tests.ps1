# SOURCE ONLY: AST-reviewed definitions, not executed by the author.
# Future execution requires a separately reviewed WHOLE-file fixture/native plan,
# a fresh profiled pwsh process and explicit Pester 6.2.0 selection. The guard
# below prevents accidental suite execution; its value is intent, not permission.
BeforeAll {
  if (![string]::Equals([Environment]::GetEnvironmentVariable('ATAP_G2_RESOLVER_FIXTURE_ADMISSION', 'Process'), 'S17-G2-RESOLVER-SOURCE01', [StringComparison]::Ordinal)) {
    throw 'A separate complete G2 resolver fixture execution admission is required.'
  }
  $script:fixtureBase = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../_generated/Sprint0017/g2p')).Replace('\', '/')
  $script:ownerId = [guid]::NewGuid().ToString('N')
  $script:runRoot = $script:fixtureBase + '/' + $script:ownerId
  $script:resolverPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../public/Get-SharedVSCodeContext.ps1'))
  $script:gitExecutable = [IO.Path]::Combine([Environment]::GetFolderPath('ProgramFiles'), 'Git', 'cmd', 'git.exe')
  $script:savedGitEnvironment = @{}
  $script:environmentCaptured = $false
  $script:raceAction = $null

  function script:Assert-G2OwnedPath {
    param([string]$Path, [switch]$Bootstrap)
    if ($Path -notmatch '^[A-Za-z]:[/\\]' -or $Path.Substring(2) -match '[:*?\[\]\x00-\x1f]' -or
      $Path.Replace('\', '/') -match '(?:^|/)\.\.?(?:/|$)') { throw 'Unsafe G2 fixture path' }
    $full = [IO.Path]::GetFullPath($Path).Replace('\', '/').TrimEnd('/')
    if (!$full.StartsWith($script:runRoot + '/', [StringComparison]::OrdinalIgnoreCase) -and
      ![string]::Equals($full, $script:runRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'G2 fixture path escaped owning run' }
    $cursor = [IO.DirectoryInfo]::new($full)
    while ($null -ne $cursor) {
      if ($cursor.Exists -and $null -ne $cursor.LinkTarget) { throw 'G2 fixture link ancestry' }
      $cursor = $cursor.Parent
    }
    if ([IO.File]::Exists($full) -and $null -ne ([IO.FileInfo]::new($full)).LinkTarget) { throw 'G2 fixture file link' }
    if (!$Bootstrap) {
      $marker = $script:runRoot + '/.owner'
      if (![IO.File]::Exists($marker) -or ![string]::Equals([IO.File]::ReadAllText($marker), $script:ownerId, [StringComparison]::Ordinal)) { throw 'G2 fixture ownership changed' }
    }
    return $full
  }
  function script:Write-G2FixtureText {
    param([string]$Path, [string]$Text)
    $full = Assert-G2OwnedPath $Path
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($full)) | Out-Null
    $null = Assert-G2OwnedPath $full
    [IO.File]::WriteAllText($full, $Text, [Text.UTF8Encoding]::new($false))
  }
  function script:Invoke-G2FixtureGit {
    param([string]$Root, [string[]]$Arguments)
    $full = Assert-G2OwnedPath $Root
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $script:gitExecutable
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in @('-c', 'core.longpaths=true', '--no-optional-locks', '-C', $full) + $Arguments) { $start.ArgumentList.Add($argument) }
    $child = [Diagnostics.Process]::new()
    $child.StartInfo = $start
    try {
      $null = $child.Start()
      $stdout = $child.StandardOutput.ReadToEndAsync()
      $stderr = $child.StandardError.ReadToEndAsync()
      $child.WaitForExit()
      $output = $stdout.GetAwaiter().GetResult()
      $errorText = $stderr.GetAwaiter().GetResult()
      if ($child.ExitCode -ne 0) {
        $path = $script:runRoot + '/native-failure-' + [guid]::NewGuid().ToString('N') + '.json'
        Write-G2FixtureText $path (@{ Root = $full; Arguments = $Arguments; ExitCode = $child.ExitCode; StandardOutput = $output; StandardError = $errorText } | ConvertTo-Json -Depth 5)
        throw 'Owned G2 fixture Git command failed; raw evidence retained in owning run.'
      }
      return $output.TrimEnd([char[]]@([char]13, [char]10))
    } finally { $child.Dispose() }
  }
  function script:New-G2Repository {
    param([string]$Root)
    $full = Assert-G2OwnedPath $Root
    [IO.Directory]::CreateDirectory($full) | Out-Null
    $null = Invoke-G2FixtureGit $full @('init', '--initial-branch=main', ('--template=' + $script:emptyTemplates))
    foreach ($binding in @(@('user.name', 'G2 Fixture'), @('user.email', 'g2@example.invalid'), @('commit.gpgsign', 'false'), @('core.hooksPath', $script:emptyHooks))) {
      $null = Invoke-G2FixtureGit $full @('config', '--local', '--replace-all', $binding[0], $binding[1])
    }
    $null = Invoke-G2FixtureGit $full @('commit', '--allow-empty', '--no-verify', '-m', 'owned fixture')
    $null = Invoke-G2FixtureGit $full @('config', '--local', '--replace-all', 'extensions.worktreeConfig', 'true')
  }
  function script:New-G2Assets {
    param([string]$Root)
    Write-G2FixtureText ($Root + '/.gitconfig') "[core]`n autocrlf = false`n[commit]`n template = GitTemplates/git.commit.template.txt`n"
    Write-G2FixtureText ($Root + '/.gitattributes') "* text=auto eol=lf`n"
    Write-G2FixtureText ($Root + '/GitTemplates/git.commit.template.txt') "G2 template`n"
    Write-G2FixtureText ($Root + '/.githooks/fixture.txt') "Non-executable fixture hook payload`n"
  }
  function script:Set-G2LinkedRoute {
    param([string]$Root, [string]$Source)
    $dir = (Invoke-G2FixtureGit $Root @('rev-parse', '--absolute-git-dir')).Replace('\', '/')
    foreach ($binding in @(@(('includeIf.gitdir/i:' + $dir + '.path'), ($Source + '/.gitconfig')), @('core.hooksPath', ($Source + '/.githooks')), @('commit.template', ($Source + '/GitTemplates/git.commit.template.txt')))) {
      $null = Invoke-G2FixtureGit $Root @('config', '--worktree', '--replace-all', $binding[0], $binding[1])
    }
    return $dir
  }
  function script:Write-G2Workspace {
    param([string]$Root, [string]$Ref, [string]$Name = 'Fixture.code-workspace', [string]$Profile = 'sprint')
    $path = $Root + '/' + $Name
    Write-G2FixtureText $path (@{ folders = @(@{ path = '.' }); settings = @{ 'atap.sharedVSCode.templateRef' = $Ref; 'atap.sharedVSCode.profile' = $Profile } } | ConvertTo-Json -Depth 8)
    return $path
  }
  function script:New-G2Authority {
    $pins = foreach ($path in @(($script:stableRoot + '/.gitconfig'), ($script:stableRoot + '/GitTemplates/git.commit.template.txt'), ($script:stableRoot + '/.githooks/fixture.txt'))) {
      $full = Assert-G2OwnedPath $path
      [pscustomobject]@{ Path = $full; SHA256 = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([IO.File]::ReadAllBytes($full))) }
    }
    return [pscustomobject]@{ StableRoot = $script:stableRoot; StableGitDir = $script:commonDir; CommonGitDir = $script:commonDir; StableAssetPins = @($pins); ReceiptCustodyRoot = $script:receiptRoot }
  }
  function script:Get-G2FixtureSnapshot {
    $root = Assert-G2OwnedPath $script:caseRoot
    $pending = [Collections.Generic.Queue[string]]::new()
    $pending.Enqueue($root)
    $files = [Collections.Generic.List[string]]::new()
    while ($pending.Count) {
      foreach ($entry in [IO.Directory]::EnumerateFileSystemEntries($pending.Dequeue())) {
        $full = Assert-G2OwnedPath $entry
        if ([IO.Directory]::Exists($full)) { $pending.Enqueue($full) } else { $files.Add($full) }
      }
    }
    $files.Sort([StringComparer]::OrdinalIgnoreCase)
    $pins = @($files.ToArray() | ForEach-Object { [ordered]@{ Path = $_; SHA256 = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([IO.File]::ReadAllBytes($_))) } })
    return (ConvertTo-Json -InputObject $pins -Depth 5 -Compress)
  }
  function script:Invoke-G2Projection {
    param([string[]]$WorkspaceFiles = @($script:workspace), [hashtable]$Overrides = @{})
    $parameters = @{
      WorkspaceFiles = $WorkspaceFiles; GitRoot = $script:caseRoot; SharedVSCodeRepoName = 'Canonical-main'
      ContextMode = 'SourceEndProjection'; ExpectedSourceRoot = $script:sourceRoot; ProjectionAuthority = $script:authority
    }
    foreach ($key in $Overrides.Keys) { $parameters[$key] = $Overrides[$key] }
    return Get-SharedVSCodeContext @parameters
  }
  function script:Assert-G2ResolverFailure {
    param([scriptblock]$Action, [string]$Code = '*')
    $output = [Collections.Generic.List[object]]::new()
    $failure = $null
    try { & $Action | ForEach-Object { $output.Add($_) } } catch { $failure = $_ }
    $failure | Should -Not -BeNullOrEmpty
    $failure.FullyQualifiedErrorId | Should -BeLike ('SharedVSCodeContext.' + $Code + '*')
    $output.Count | Should -Be 0
  }
  function script:Write-PSFMessage {
    [CmdletBinding()]
    param([string]$FunctionName, [string]$ModuleName, [string]$Level, [string]$Message, [string[]]$Tag)
    if ($Message -ceq 'Rechecking read-only context' -and $null -ne $script:raceAction) {
      $action = $script:raceAction; $script:raceAction = $null
      $null = & $action
    }
  }
  function script:Set-WorkspaceSharedVSCodeReference { }
  function script:Set-DownstreamSharedVSCodeContext { }
  function script:New-GeneratedFileContent { }

  $null = Assert-G2OwnedPath $script:runRoot -Bootstrap
  if ([IO.Directory]::Exists($script:runRoot) -or [IO.File]::Exists($script:runRoot)) { throw 'Never adopt an existing fixture run' }
  [IO.Directory]::CreateDirectory($script:runRoot) | Out-Null
  [IO.File]::WriteAllText(($script:runRoot + '/.owner'), $script:ownerId, [Text.UTF8Encoding]::new($false))
  # Process-only Git configuration isolation; no HOME/profile/host settings change.
  foreach ($entry in [Environment]::GetEnvironmentVariables().GetEnumerator()) {
    if ([string]$entry.Key -like 'GIT_*') { $script:savedGitEnvironment[$entry.Key] = $entry.Value }
  }
  $script:environmentCaptured = $true
  foreach ($key in @([Environment]::GetEnvironmentVariables().Keys)) {
    if ([string]$key -like 'GIT_*') { [Environment]::SetEnvironmentVariable($key, [NullString]::Value, 'Process') }
  }
  $script:emptyTemplates = $script:runRoot + '/empty-templates'
  $script:emptyHooks = $script:runRoot + '/empty-hooks'
  foreach ($path in @($script:emptyTemplates, $script:emptyHooks)) {
    $null = Assert-G2OwnedPath $path
    [IO.Directory]::CreateDirectory($path) | Out-Null
  }
  $emptyConfig = $script:runRoot + '/empty-git-config'
  Write-G2FixtureText $emptyConfig ''
  [Environment]::SetEnvironmentVariable('GIT_CONFIG_NOSYSTEM', '1', 'Process')
  [Environment]::SetEnvironmentVariable('GIT_CONFIG_GLOBAL', $emptyConfig, 'Process')
  [Environment]::SetEnvironmentVariable('GIT_CONFIG_SYSTEM', $emptyConfig, 'Process')
  [Environment]::SetEnvironmentVariable('GIT_TERMINAL_PROMPT', '0', 'Process')
  # Defines only the exact source function; no installed parent module import.
  . $script:resolverPath
}

AfterAll {
  if ($script:environmentCaptured) {
    foreach ($key in @([Environment]::GetEnvironmentVariables().Keys)) {
      if ([string]$key -like 'GIT_*') { [Environment]::SetEnvironmentVariable($key, [NullString]::Value, 'Process') }
    }
    foreach ($entry in $script:savedGitEnvironment.GetEnumerator()) { [Environment]::SetEnvironmentVariable($entry.Key, $entry.Value, 'Process') }
  }
  # Retain all owned fixtures, native failures and preimages for review. No deletion.
}

Describe 'Get-SharedVSCodeContext explicit source-End read-only projection' {
  BeforeEach {
    $script:caseRoot = $script:runRoot + '/cases/' + [guid]::NewGuid().ToString('N')
    $null = Assert-G2OwnedPath $script:caseRoot
    [IO.Directory]::CreateDirectory($script:caseRoot) | Out-Null
    $script:stableRoot = $script:caseRoot + '/Canonical-main'
    $script:sourceRoot = $script:caseRoot + '/Outgoing-source'
    $script:otherRoot = $script:caseRoot + '/SharedVSCode-wt-lookalike'
    $script:receiptRoot = $script:caseRoot + '/_generated/SourceEnd'
    $null = Assert-G2OwnedPath $script:receiptRoot
    [IO.Directory]::CreateDirectory($script:receiptRoot) | Out-Null
    New-G2Repository $script:stableRoot
    New-G2Repository $script:otherRoot
    $null = Invoke-G2FixtureGit $script:stableRoot @('worktree', 'add', '-b', 'owned-source', $script:sourceRoot)
    New-G2Assets $script:stableRoot
    New-G2Assets $script:sourceRoot
    $script:commonDir = (Invoke-G2FixtureGit $script:stableRoot @('rev-parse', '--absolute-git-dir')).Replace('\', '/')
    $null = Invoke-G2FixtureGit $script:stableRoot @('config', '--local', '--unset-all', 'core.hooksPath')
    $null = Invoke-G2FixtureGit $script:stableRoot @('config', '--local', '--replace-all', ('includeIf.gitdir/i:' + $script:commonDir + '.path'), ($script:stableRoot + '/.gitconfig'))
    $commonPath = Assert-G2OwnedPath ($script:commonDir + '/config')
    $suffix = "`n[core]`n hooksPath = $script:stableRoot/.githooks`n[commit]`n template = $script:stableRoot/GitTemplates/git.commit.template.txt`n"
    Write-G2FixtureText $commonPath ([IO.File]::ReadAllText($commonPath) + $suffix)
    $script:sourceGitDir = Set-G2LinkedRoute $script:sourceRoot $script:sourceRoot
    $script:workspace = Write-G2Workspace $script:sourceRoot 'Outgoing-source'
    $script:authority = New-G2Authority
    $script:raceAction = $null
    Mock Set-WorkspaceSharedVSCodeReference { throw 'Forbidden workspace writer' }
    Mock Set-DownstreamSharedVSCodeContext { throw 'Forbidden consumer writer' }
    Mock New-GeneratedFileContent { throw 'Forbidden renderer' }
  }
  AfterEach {
    Should -Invoke Set-WorkspaceSharedVSCodeReference -Times 0 -Exactly
    Should -Invoke Set-DownstreamSharedVSCodeContext -Times 0 -Exactly
    Should -Invoke New-GeneratedFileContent -Times 0 -Exactly
  }
  It 'SE01 keeps Normal source identity and rejects implicit main selection with zero output on failure' {
    $before = Get-G2FixtureSnapshot
    $normal = @(Get-SharedVSCodeContext -WorkspaceFiles $script:workspace -GitRoot $script:caseRoot -SharedVSCodeRepoName 'Canonical-main')
    $normal.Count | Should -Be 1
    $normal[0].SharedRoot | Should -BeExactly ($script:caseRoot + '/Outgoing-source')
    $normal[0].Plan.ContextMode | Should -BeExactly 'Normal'
    $normal[0].PSObject.Properties.Name | Should -Not -Contain 'EffectiveGitContext'
    Assert-G2ResolverFailure { Get-SharedVSCodeContext -WorkspaceFiles $script:workspace -GitRoot $script:caseRoot -SharedVSCodeRepoName 'Canonical-main' -RequestedTemplateRef main } 'SourceSelfSelectionRequired'
    (Get-G2FixtureSnapshot) | Should -BeExactly $before
  }
  It 'SE02 preserves all eight legacy getters and returns exact stable projection pins without writes' {
    Write-G2FixtureText ($script:sourceRoot + '/.gitconfig.shared') 'Stale cache must never be selected'
    $before = Get-G2FixtureSnapshot
    $result = @(Invoke-G2Projection)
    $result.Count | Should -Be 1
    $result[0].WorkspaceFile | Should -BeExactly $script:workspace
    $result[0].TemplateRef | Should -BeExactly 'Outgoing-source'
    $result[0].Profile | Should -BeExactly 'sprint'
    $result[0].SharedRoot | Should -BeExactly ($script:caseRoot + '/Outgoing-source')
    $result[0].GitConfig | Should -BeExactly ($script:caseRoot + '/Outgoing-source/.gitconfig')
    $result[0].GitAttributes | Should -BeExactly ($script:caseRoot + '/Outgoing-source/.gitattributes')
    $result[0].CommitTemplate | Should -BeExactly ($script:caseRoot + '/Outgoing-source/GitTemplates/git.commit.template.txt')
    $result[0].HooksPath | Should -BeExactly ($script:caseRoot + '/Outgoing-source/.githooks')
    $result[0].CanRenderConsumerFiles | Should -BeFalse
    $effective = $result[0].EffectiveGitContext
    $effective.GitConfig | Should -BeExactly ($script:caseRoot + '/Canonical-main/.gitconfig')
    $effective.HooksPath | Should -BeExactly ($script:caseRoot + '/Canonical-main/.githooks')
    $plan = $effective.Plan
    $plan.Mode | Should -BeExactly 'SourceEndProjection'
    $plan.ValidationStatus | Should -BeExactly 'ValidatedReadOnlyPlan'
    $plan.Role | Should -BeExactly 'CanonicalSourceSprint'
    $plan.Target.TopLevel | Should -BeExactly $script:sourceRoot
    $plan.Target.GitDir | Should -BeExactly $script:sourceGitDir
    $plan.Route.Condition | Should -BeExactly ('gitdir/i:' + $script:sourceGitDir)
    $plan.Route.ConfigPath | Should -BeExactly ($script:sourceGitDir + '/config.worktree')
    $plan.Route.IncludeTarget | Should -BeExactly ($script:caseRoot + '/Canonical-main/.gitconfig')
    $plan.Route.CanRenderConsumerFiles | Should -BeFalse
    $plan.CurrentRouteState | Should -BeExactly 'ProjectionRequired'
    $plan.ReceiptCustodyRoot | Should -BeExactly $script:receiptRoot
    $plan.DirectoryPins.Count | Should -Be 2
    foreach ($pin in @($plan.Workspaces) + @($plan.AssetPins) + @($plan.ConfigPins) + @($plan.ProtectedPins)) {
      $pin.Exists | Should -Be $pin.Existence
      $pin.Existence | Should -BeOfType ([bool])
      $pin.SHA256 | Should -Match '^[0-9A-Fa-f]{64}\z'
      $pin.Length | Should -Not -BeNullOrEmpty
    }
    @($plan.ProtectedPins | Where-Object Path -eq $plan.Route.ConfigPath).Count | Should -Be 0
    (Get-G2FixtureSnapshot) | Should -BeExactly $before
  }
  It 'SE03 recognizes a repeat stable route only after complete revalidation and zero byte changes' {
    $null = Set-G2LinkedRoute $script:sourceRoot $script:stableRoot
    $before = Get-G2FixtureSnapshot
    $result = @(Invoke-G2Projection)
    $result[0].EffectiveGitContext.Plan.CurrentRouteState | Should -BeExactly 'AlreadyDesired'
    $result[0].SharedRoot | Should -BeExactly $script:sourceRoot
    (Get-G2FixtureSnapshot) | Should -BeExactly $before
  }
  It 'SE02 returns only a read-only plan under WhatIf and leaves every fixture byte unchanged' {
    $before = Get-G2FixtureSnapshot
    $result = @(Invoke-G2Projection -Overrides @{ WhatIf = $true })
    $result[0].EffectiveGitContext.Plan.Mode | Should -BeExactly 'SourceEndProjection'
    (Get-G2FixtureSnapshot) | Should -BeExactly $before
  }
  It 'SE03 rejects a hidden outgoing include even when final stable scalar values match' {
    $null = Set-G2LinkedRoute $script:sourceRoot $script:stableRoot
    $null = Invoke-G2FixtureGit $script:sourceRoot @('config', '--worktree', '--add', 'include.path', ($script:sourceRoot + '/.gitconfig'))
    $before = Get-G2FixtureSnapshot
    Assert-G2ResolverFailure { Invoke-G2Projection } 'UnsafeIncludeRoute'
    (Get-G2FixtureSnapshot) | Should -BeExactly $before
  }
  It 'SE03 rejects a stale authority pin instead of blessing repeat context' {
    $null = Set-G2LinkedRoute $script:sourceRoot $script:stableRoot
    Write-G2FixtureText ($script:stableRoot + '/GitTemplates/git.commit.template.txt') 'Peer changed template'
    $before = Get-G2FixtureSnapshot
    Assert-G2ResolverFailure { Invoke-G2Projection } 'ProjectionAuthorityMismatch'
    (Get-G2FixtureSnapshot) | Should -BeExactly $before
  }
  It 'SE04 fails before effects when the exact source registration is missing' {
    $missing = Assert-G2OwnedPath ($script:sourceGitDir + '-removed')
    $null = Assert-G2OwnedPath $script:sourceGitDir
    [IO.Directory]::Move($script:sourceGitDir, $missing)
    $before = Get-G2FixtureSnapshot
    Assert-G2ResolverFailure { Invoke-G2Projection }
    [IO.Directory]::Exists($script:sourceGitDir) | Should -BeFalse
    (Get-G2FixtureSnapshot) | Should -BeExactly $before
  }
  It 'SE05 rejects a different expected source root' {
    $before = Get-G2FixtureSnapshot
    Assert-G2ResolverFailure { Invoke-G2Projection -Overrides @{ ExpectedSourceRoot = $script:otherRoot } } 'InvalidProjectionTarget'
    (Get-G2FixtureSnapshot) | Should -BeExactly $before
  }
  It 'SE05 rejects the stable target itself even when the folder authority exists' {
    $workspace = Write-G2Workspace $script:stableRoot 'main'
    $before = Get-G2FixtureSnapshot
    Assert-G2ResolverFailure { Invoke-G2Projection -WorkspaceFiles $workspace -Overrides @{ ExpectedSourceRoot = $script:stableRoot } } 'InvalidProjectionTarget'
    (Get-G2FixtureSnapshot) | Should -BeExactly $before
  }
  It 'SE05 rejects a lookalike downstream checkout rather than infer source role from its name' {
    $workspace = Write-G2Workspace $script:otherRoot 'Outgoing-source'
    $before = Get-G2FixtureSnapshot
    Assert-G2ResolverFailure { Invoke-G2Projection -WorkspaceFiles $workspace -Overrides @{ ExpectedSourceRoot = $script:otherRoot } } 'InvalidProjectionTarget'
    (Get-G2FixtureSnapshot) | Should -BeExactly $before
  }
  It 'SE05 uses the explicit source rather than the current unrelated working directory' {
    $before = Get-G2FixtureSnapshot
    Push-Location -LiteralPath $script:otherRoot
    try { $result = @(Invoke-G2Projection) } finally { Pop-Location }
    $result[0].EffectiveGitContext.Plan.Target.TopLevel | Should -BeExactly $script:sourceRoot
    (Get-G2FixtureSnapshot) | Should -BeExactly $before
  }
  It 'SE05 rejects a wrong stable/common authority binding' {
    $script:authority.CommonGitDir = $script:otherRoot + '/.git'
    $before = Get-G2FixtureSnapshot
    Assert-G2ResolverFailure { Invoke-G2Projection } 'ProjectionAuthorityMismatch'
    (Get-G2FixtureSnapshot) | Should -BeExactly $before
  }
  It 'SE06 validates every compatible workspace without retargeting any payload' {
    $other = Write-G2Workspace $script:sourceRoot 'Outgoing-source' 'Second.code-workspace'
    $before = Get-G2FixtureSnapshot
    $result = @(Invoke-G2Projection -WorkspaceFiles @($script:workspace, $other))
    $result.Count | Should -Be 2
    $result[0].EffectiveGitContext.Plan.Workspaces.Count | Should -Be 2
    (Get-G2FixtureSnapshot) | Should -BeExactly $before
  }
  It 'SE06 rejects contradictory source references before returning partial output' {
    $other = Write-G2Workspace $script:sourceRoot 'main' 'Contradictory.code-workspace' 'default'
    $before = Get-G2FixtureSnapshot
    Assert-G2ResolverFailure { Invoke-G2Projection -WorkspaceFiles @($script:workspace, $other) } 'WorkspaceConflict'
    (Get-G2FixtureSnapshot) | Should -BeExactly $before
  }
  It 'SE06 rejects mixed repositories in a workspace batch' {
    $other = Write-G2Workspace $script:otherRoot 'Outgoing-source'
    $before = Get-G2FixtureSnapshot
    Assert-G2ResolverFailure { Invoke-G2Projection -WorkspaceFiles @($script:workspace, $other) } 'WorkspaceConflict'
    (Get-G2FixtureSnapshot) | Should -BeExactly $before
  }
  It 'SE06 rejects missing worktreeConfig isolation without enabling it' {
    $null = Invoke-G2FixtureGit $script:stableRoot @('config', '--local', '--replace-all', 'extensions.worktreeConfig', 'false')
    $before = Get-G2FixtureSnapshot
    Assert-G2ResolverFailure { Invoke-G2Projection } 'MissingPrerequisite'
    (Get-G2FixtureSnapshot) | Should -BeExactly $before
  }
  It 'SE06 rejects absent authority and an added unpinned stable hook' {
    $before = Get-G2FixtureSnapshot
    Assert-G2ResolverFailure { Invoke-G2Projection -Overrides @{ ProjectionAuthority = $null } } 'ProjectionAuthorityRequired'
    (Get-G2FixtureSnapshot) | Should -BeExactly $before
    Write-G2FixtureText ($script:stableRoot + '/.githooks/new-hook') 'Unpinned peer hook'
    $before = Get-G2FixtureSnapshot
    Assert-G2ResolverFailure { Invoke-G2Projection } 'ProjectionAuthorityRequired'
    (Get-G2FixtureSnapshot) | Should -BeExactly $before
  }
  It 'SE06 pins only the exact allowed absent config target without creating it' {
    $path = Assert-G2OwnedPath ($script:sourceGitDir + '/config.worktree')
    [IO.File]::Delete($path)
    $before = Get-G2FixtureSnapshot
    $result = @(Invoke-G2Projection)
    $plan = $result[0].EffectiveGitContext.Plan
    $plan.CurrentRouteState | Should -BeExactly 'SafeUnconfiguredLinked'
    $missing = @($plan.ConfigPins | Where-Object { !$_.Existence })
    $missing.Count | Should -Be 1
    $missing[0].Path | Should -BeExactly $path
    $missing[0].Exists | Should -BeFalse
    $missing[0].SHA256 | Should -BeNullOrEmpty
    $missing[0].Length | Should -BeNullOrEmpty
    @($plan.ProtectedPins | Where-Object { !$_.Existence }).Count | Should -Be 0
    [IO.File]::Exists($path) | Should -BeFalse
    (Get-G2FixtureSnapshot) | Should -BeExactly $before
  }
  It 'SE06 rejects a missing custody-root binding before returning a plan' {
    $script:authority.ReceiptCustodyRoot = $null
    $before = Get-G2FixtureSnapshot
    Assert-G2ResolverFailure { Invoke-G2Projection } 'ProjectionAuthorityRequired'
    (Get-G2FixtureSnapshot) | Should -BeExactly $before
  }
  It 'SE06 rejects stable transitive includes rather than trusting matching scalar paths' {
    $extra = $script:stableRoot + '/unexpected-config'
    Write-G2FixtureText $extra "[commit]`n template = GitTemplates/git.commit.template.txt`n"
    $path = $script:stableRoot + '/.gitconfig'
    Write-G2FixtureText $path ([IO.File]::ReadAllText($path) + "[include]`n path = $extra`n")
    $script:authority = New-G2Authority
    $before = Get-G2FixtureSnapshot
    Assert-G2ResolverFailure { Invoke-G2Projection } 'UnsafeIncludeRoute'
    (Get-G2FixtureSnapshot) | Should -BeExactly $before
  }
  It 'SE06 rejects a source hooks junction even when its target stays inside the owned fixture' {
    $path = Assert-G2OwnedPath ($script:sourceRoot + '/.githooks')
    $relocated = Assert-G2OwnedPath ($script:sourceRoot + '/owned-hook-target')
    $payload = [IO.File]::ReadAllBytes($path + '/fixture.txt')
    [IO.Directory]::Move($path, $relocated)
    $null = Assert-G2OwnedPath $path
    New-Item -ItemType Junction -Path $path -Target $relocated -ErrorAction Stop | Out-Null
    Assert-G2ResolverFailure { Invoke-G2Projection } 'UnsafePath'
    [Linq.Enumerable]::SequenceEqual([byte[]]$payload, [byte[]][IO.File]::ReadAllBytes($relocated + '/fixture.txt')) | Should -BeTrue
  }
  It 'SE06 rejects a stable hook hard link instead of treating a matching content hash as ordinary authority' {
    $path = Assert-G2OwnedPath ($script:stableRoot + '/.githooks/fixture.txt')
    $target = Assert-G2OwnedPath ($script:caseRoot + '/owned-hook-payload.txt')
    Write-G2FixtureText $target ([IO.File]::ReadAllText($path))
    [IO.File]::Delete($path)
    $null = Assert-G2OwnedPath $path
    New-Item -ItemType HardLink -Path $path -Target $target -ErrorAction Stop | Out-Null
    $before = [IO.File]::ReadAllBytes($target)
    Assert-G2ResolverFailure { Invoke-G2Projection } 'UnsafePath'
    [Linq.Enumerable]::SequenceEqual([byte[]]$before, [byte[]][IO.File]::ReadAllBytes($target)) | Should -BeTrue
  }
  It 'SE06 rejects changed hook directory membership during final observation recheck' {
    $script:raceAction = { Write-G2FixtureText ($script:stableRoot + '/.githooks/late-hook') 'Deliberate owned-fixture peer race' }
    Assert-G2ResolverFailure { Invoke-G2Projection } 'ObservationChanged'
    [IO.File]::Exists($script:stableRoot + '/.githooks/late-hook') | Should -BeTrue
  }
}
