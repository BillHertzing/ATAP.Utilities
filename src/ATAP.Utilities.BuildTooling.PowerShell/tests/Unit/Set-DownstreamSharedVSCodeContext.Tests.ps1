# Focused source suite: real disposable Git, deterministic logger double.
BeforeAll {
  $artifactRoot = [Environment]::GetEnvironmentVariable('ARTIFACTS_PATH', 'Process')
  if (!$artifactRoot) { $artifactRoot = [Environment]::GetEnvironmentVariable('ARTIFACTS_PATH', 'User') }
  if (!$artifactRoot) { throw 'ARTIFACTS_PATH is required for writer fixtures.' }
  $script:runRoot = [IO.Path]::GetFullPath((Join-Path $artifactRoot ('Sprint0017/Task17.66.c/Writer23/Fixtures/' + [guid]::NewGuid().ToString('N')))).Replace('\', '/')
  $script:gitExecutable = [IO.Path]::Combine([Environment]::GetFolderPath('ProgramFiles'), 'Git', 'cmd', 'git.exe')
  if (![IO.File]::Exists($script:gitExecutable)) { throw 'Native Git required; no fallback.' }
  function script:Assert-OwnedFixturePath([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path).Replace('\', '/').TrimEnd('/')
    if (!$full.StartsWith(($script:runRoot + '/'), [StringComparison]::OrdinalIgnoreCase)) { throw 'Fixture escaped owning run.' }
    for ($parent = [IO.DirectoryInfo]::new($full); $null -ne $parent; $parent = $parent.Parent) {
      if ($parent.Exists -and $parent.LinkTarget) { throw 'Fixture link ancestry.' }
    }
    if ([IO.File]::Exists($full) -and ([IO.FileInfo]::new($full)).LinkTarget) { throw 'Fixture file link.' }
    return $full
  }
  function script:Write-FixtureText([string]$Path, [string]$Text) {
    $full = Assert-OwnedFixturePath $Path
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($full)) | Out-Null
    [IO.File]::WriteAllText($full, $Text, [Text.UTF8Encoding]::new($false))
  }
  function script:Invoke-FixtureGit([string]$Root, [string[]]$Arguments) {
    $full = Assert-OwnedFixturePath $Root
    $start = [Diagnostics.ProcessStartInfo]::new($script:gitExecutable)
    $start.UseShellExecute = $false; $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true; $start.RedirectStandardError = $true
    foreach ($arg in @('-c', 'core.longpaths=true', '--no-optional-locks', '-C', $full) + $Arguments) { $start.ArgumentList.Add($arg) }
    $process = [Diagnostics.Process]::new(); $process.StartInfo = $start
    try {
      $null = $process.Start()
      $stdout = $process.StandardOutput.ReadToEndAsync(); $stderr = $process.StandardError.ReadToEndAsync()
      $process.WaitForExit()
      $text = $stdout.GetAwaiter().GetResult(); $errorText = $stderr.GetAwaiter().GetResult()
      if ($process.ExitCode -ne 0) { throw ('Fixture Git exit {0}: {1}' -f $process.ExitCode, $errorText) }
      return $text.TrimEnd([char]13, [char]10)
    } finally { $process.Dispose() }
  }
  function script:Fixture-Config([string]$Root, [string]$Scope, [string]$Key, [string]$Value) {
    $null = Invoke-FixtureGit $Root @('config', $Scope, '--replace-all', $Key, $Value)
  }
  function script:New-FixtureRepository([string]$Root) {
    [IO.Directory]::CreateDirectory((Assert-OwnedFixturePath $Root)) | Out-Null
    $null = Invoke-FixtureGit $Root @('init', '--initial-branch=main', ('--template=' + $script:emptyTemplates))
    Fixture-Config $Root '--local' 'user.name' 'Writer Fixture'
    Fixture-Config $Root '--local' 'user.email' 'writer@example.invalid'
    Fixture-Config $Root '--local' 'commit.gpgsign' 'false'
    Fixture-Config $Root '--local' 'core.hooksPath' $script:emptyHooks
    $null = Invoke-FixtureGit $Root @('commit', '--allow-empty', '--no-verify', '-m', 'fixture')
    Fixture-Config $Root '--local' 'extensions.worktreeConfig' 'true'
  }
  function script:New-FixtureAssets([string]$Root) {
    Write-FixtureText (($Root + '/.gitconfig')) "[alias]`n fixture = status`n[commit]`n template = GitTemplates/git.commit.template.txt`n"
    Write-FixtureText (($Root + '/.gitattributes')) "* text=auto eol=lf`r`n*.cmd text eol=crlf`r`n"
    Write-FixtureText (($Root + '/GitTemplates/git.commit.template.txt')) "Fixture template`n"
    [IO.Directory]::CreateDirectory((Assert-OwnedFixturePath (($Root + '/.githooks')))) | Out-Null
  }
  function script:Write-FixtureRender([string]$Root, [string]$Source) {
    $header = @('# ===================================================================', '# GENERATED FILE - DO NOT EDIT DIRECTLY', '# Source: SharedVSCode/.gitconfig', '# Regenerate using Set-DownstreamSharedVSCodeContext', '# ===================================================================', '') -join "`n"
    Write-FixtureText (($Root + '/.gitconfig.shared')) ($header + ([IO.File]::ReadAllText(($Source + '/.gitconfig')) -replace '\r\n?', "`n") + "`n")
  }
  function script:Set-FixtureCommonRoute([string]$Root, [switch]$Canonical) {
    $dir = (Invoke-FixtureGit $Root @('rev-parse', '--absolute-git-dir')).Replace('\', '/')
    $include = if ($Canonical) { ($Root + '/.gitconfig') } else { ($Root + '/.gitconfig.shared') }
    if (!$Canonical) { Write-FixtureRender $Root $script:stableSource }
    $null = Invoke-FixtureGit $Root @('config', '--local', '--unset-all', 'core.hooksPath')
    Fixture-Config $Root '--local' ('includeIf.gitdir/i:' + $dir + '.path') $include
    $config = ($dir + '/config')
    Write-FixtureText $config ([IO.File]::ReadAllText($config) + "`n[core]`n hooksPath = $script:stableSource/.githooks`n[commit]`n template = $script:stableSource/GitTemplates/git.commit.template.txt`n")
    return $dir
  }
  function script:Write-FixtureWorkspace([string]$Root, [string]$Ref = 'SharedVSCode-wt-source', [string]$Name = 'Fixture.code-workspace') {
    $path = ($Root + '/') + $Name
    Write-FixtureText $path (@{ settings = @{ 'atap.sharedVSCode.templateRef' = $Ref; 'atap.sharedVSCode.profile' = 'fixture' }; folders = @(@{path='.'}) } | ConvertTo-Json -Depth 8)
    return $path
  }
  function script:Get-FixturePins([string[]]$Paths) {
    $records = foreach ($path in $Paths) {
      $null = Assert-OwnedFixturePath $path
      [ordered]@{ path = $path; hash = if ([IO.File]::Exists($path)) { (Get-FileHash -LiteralPath $path).Hash } else { $null } }
    }
    return (ConvertTo-Json -InputObject @($records) -Compress)
  }
  function script:Invoke-FixtureWriter([string[]]$Files = @($script:workspace), [switch]$WhatIf) {
    foreach ($file in $Files) { $null = Assert-OwnedFixturePath $file }
    Set-DownstreamSharedVSCodeContext -WorkspaceFiles $Files -GitRoot $script:caseRoot -WhatIf:$WhatIf -Confirm:$false
  }
  # Deliberate logging failure injection only; no production logging assertion.
  function Write-PSFMessage {
    [CmdletBinding()]
    param($FunctionName, $ModuleName, $Level, $Message, $Tag)
    if ($FunctionName -ne 'Set-DownstreamSharedVSCodeContext') { return }
    if ($script:fault -eq 'before-config' -and $Message -eq ('Writing: ' + $script:overlay)) { throw 'InjectedConfigBoundaryFailure' }
    if ($script:fault -eq 'peer-after-attributes' -and $Message -eq ('Wrote: ' + ($script:sprintTarget + '/.gitattributes'))) {
      Write-FixtureText (($script:sprintTarget + '/.gitattributes')) 'peer bytes'
      throw 'InjectedPeerPostimageChange'
    }
  }
  $script:savedGitEnvironment = @{}
  foreach ($key in @([Environment]::GetEnvironmentVariables().Keys)) {
    if ($key -like 'GIT_*') { $script:savedGitEnvironment[$key] = [Environment]::GetEnvironmentVariable($key); [Environment]::SetEnvironmentVariable($key, [NullString]::Value) }
  }
  $script:emptyTemplates = ($script:runRoot + '/empty-templates')
  $script:emptyHooks = ($script:runRoot + '/empty-hooks')
  [IO.Directory]::CreateDirectory((Assert-OwnedFixturePath $script:emptyTemplates)) | Out-Null
  [IO.Directory]::CreateDirectory((Assert-OwnedFixturePath $script:emptyHooks)) | Out-Null
  Write-FixtureText (($script:runRoot + '/global.config')) "[core]`n longpaths = true`n"
  Write-FixtureText (($script:runRoot + '/system.config')) ''
  [Environment]::SetEnvironmentVariable('GIT_CONFIG_GLOBAL', (($script:runRoot + '/global.config')))
  [Environment]::SetEnvironmentVariable('GIT_CONFIG_SYSTEM', (($script:runRoot + '/system.config')))
  $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  . (Join-Path $moduleRoot 'public/Get-SharedVSCodeContext.ps1')
  . (Join-Path $moduleRoot 'public/Set-DownstreamSharedVSCodeContext.ps1')
  . (Join-Path $moduleRoot 'private/New-GeneratedFileContent.ps1')
}
AfterAll {
  foreach ($key in @([Environment]::GetEnvironmentVariables().Keys)) { if ($key -like 'GIT_*') { [Environment]::SetEnvironmentVariable($key, [NullString]::Value) } }
  foreach ($key in $script:savedGitEnvironment.Keys) { [Environment]::SetEnvironmentVariable($key, $script:savedGitEnvironment[$key]) }
  # Keep owned Git fixtures and registrations for independent review; no cleanup.
}
Describe 'Set-DownstreamSharedVSCodeContext validated routing (real fixture Git)' {
  BeforeEach {
    $script:fault = $null
    $script:caseRoot = ($script:runRoot + '/') + [guid]::NewGuid().ToString('N').Substring(0, 8)
    $script:stableSource = ($script:caseRoot + '/SharedVSCode')
    $script:sprintSource = ($script:caseRoot + '/SharedVSCode-wt-source')
    $script:stableTarget = ($script:caseRoot + '/Downstream A')
    $script:sprintTarget = ($script:caseRoot + '/Target renamed with spaces')
    $script:wrongRoot = ($script:caseRoot + '/Wrong caller')
    New-FixtureRepository $script:stableSource
    $null = Invoke-FixtureGit $script:stableSource @('worktree', 'add', '-b', 'source', $script:sprintSource)
    New-FixtureAssets $script:stableSource
    New-FixtureAssets $script:sprintSource
    $script:sourceDir = Set-FixtureCommonRoute $script:stableSource -Canonical
    New-FixtureRepository $script:stableTarget
    $null = Invoke-FixtureGit $script:stableTarget @('worktree', 'add', '-b', 'target', $script:sprintTarget)
    $script:targetDir = Set-FixtureCommonRoute $script:stableTarget
    New-FixtureRepository $script:wrongRoot
    $script:targetGitDir = (Invoke-FixtureGit $script:sprintTarget @('rev-parse', '--absolute-git-dir')).Replace('\', '/')
    $script:overlay = ($script:targetGitDir + '/config.worktree')
    $script:workspace = Write-FixtureWorkspace $script:sprintTarget
    $script:protected = @(($script:targetDir + '/config'), ($script:stableTarget + '/.gitconfig.shared'), ($script:stableTarget + '/.gitattributes'), ($script:wrongRoot + '/.git/config'), ($script:sourceDir + '/config'))
    foreach ($root in @($script:stableSource, $script:sprintSource)) {
      $script:protected += @(($root + '/.gitconfig'), ($root + '/.gitattributes'), ($root + '/GitTemplates/git.commit.template.txt'))
    }
  }
  It 'writes the exact registered linked route from a wrong caller; preserves common/stable/source/caller bytes' {
    Write-FixtureText $script:overlay "# unrelated bytes`n[core]`n autocrlf = false`n[commit]`n gpgsign = false`n[fixture]`n keep = yes`n"
    $prefix = [IO.File]::ReadAllText($script:overlay)
    $before = Get-FixturePins $script:protected
    Push-Location $script:wrongRoot
    try { Invoke-FixtureWriter } finally { Pop-Location }
    Get-FixturePins $script:protected | Should -BeExactly $before
    [IO.File]::ReadAllText($script:overlay).StartsWith($prefix, [StringComparison]::Ordinal) | Should -BeTrue
    Invoke-FixtureGit $script:sprintTarget @('config', '--worktree', '--get', 'fixture.keep') | Should -BeExactly 'yes'
    $ctx = Get-SharedVSCodeContext -WorkspaceFiles $script:workspace -GitRoot $script:caseRoot
    $ctx.Plan.CurrentRouteState | Should -BeExactly 'AlreadyDesired'
    $ctx.Plan.Route.Condition | Should -BeExactly ('gitdir/i:' + $script:targetGitDir)
    $ctx.Plan.ObservedContext.Template.OriginPath | Should -BeExactly $script:overlay
    $rows = Invoke-FixtureGit $script:sprintTarget @('config', '--includes', '--show-origin', '--get-all', 'commit.template')
    $rows | Should -Match ([regex]::Escape(($script:sprintTarget + '/.gitconfig.shared')))
    $ctx.Plan.ObservedContext.Template.Value | Should -BeExactly (($script:sprintSource + '/GitTemplates/git.commit.template.txt'))
  }
  It 'creates an absent overlay without NUL and generates LF-only BOM-free consumer files' {
    Invoke-FixtureWriter
    [IO.File]::ReadAllBytes($script:overlay) | Should -Not -Contain ([byte]0)
    foreach ($name in @('.gitattributes', '.gitconfig.shared')) {
      $b = [IO.File]::ReadAllBytes(($script:sprintTarget + '/') + $name)
      $b | Should -Not -Contain ([byte]13)
      ($b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF) | Should -BeFalse
      [Text.Encoding]::UTF8.GetString($b) | Should -Match 'GENERATED FILE'
    }
    [IO.File]::ReadAllText(($script:sprintTarget + '/.gitattributes')) | Should -Match '\*\.cmd text eol=crlf'
    (Get-SharedVSCodeContext -WorkspaceFiles $script:workspace -GitRoot $script:caseRoot).Plan.CurrentRouteState | Should -BeExactly 'AlreadyDesired'
  }
  It 'does not rewrite any of the three unchanged targets on repeated application' {
    Invoke-FixtureWriter
    $paths = @($script:overlay, ($script:sprintTarget + '/.gitattributes'), ($script:sprintTarget + '/.gitconfig.shared'))
    $before = Get-FixturePins $paths
    $marker = [datetime]::new(2001, 1, 1, 0, 0, 0, [DateTimeKind]::Utc)
    foreach ($p in $paths) { [IO.File]::SetLastWriteTimeUtc($p, $marker) }
    Invoke-FixtureWriter
    Get-FixturePins $paths | Should -BeExactly $before
    foreach ($p in $paths) { [IO.File]::GetLastWriteTimeUtc($p) | Should -Be $marker }
  }
  It 'routes canonical source directly and leaves canonical attributes and stale generated copy untouched' {
    $ws = Write-FixtureWorkspace $script:sprintSource
    Write-FixtureText (($script:sprintSource + '/.gitconfig.shared')) 'stale source copy'
    $paths = @(($script:sprintSource + '/.gitconfig'), ($script:sprintSource + '/.gitattributes'), ($script:sprintSource + '/.gitconfig.shared'), ($script:sourceDir + '/config'))
    $before = Get-FixturePins $paths
    Invoke-FixtureWriter @($ws)
    Get-FixturePins $paths | Should -BeExactly $before
    $ctx = Get-SharedVSCodeContext -WorkspaceFiles $ws -GitRoot $script:caseRoot
    $ctx.Plan.Role | Should -BeExactly 'CanonicalSourceSprint'
    $ctx.Plan.Route.IncludeTarget | Should -BeExactly (($script:sprintSource + '/.gitconfig'))
    $ctx.Plan.CurrentRouteState | Should -BeExactly 'AlreadyDesired'
  }
  It 'leaves an already configured canonical stable source completely unchanged' {
    $ws = Write-FixtureWorkspace $script:stableSource 'main'
    $paths = @(($script:stableSource + '/.gitconfig'), ($script:stableSource + '/.gitattributes'), ($script:sourceDir + '/config'))
    $before = Get-FixturePins $paths
    Invoke-FixtureWriter @($ws)
    Get-FixturePins $paths | Should -BeExactly $before
    [IO.File]::Exists(($script:stableSource + '/.gitconfig.shared')) | Should -BeFalse
  }
  It 'retains downstream stable attribute rendering without rewriting common routing' {
    $ws = Write-FixtureWorkspace $script:stableTarget 'main'
    $before = Get-FixturePins @(($script:targetDir + '/config'), ($script:stableTarget + '/.gitconfig.shared'))
    Invoke-FixtureWriter @($ws)
    Get-FixturePins @(($script:targetDir + '/config'), ($script:stableTarget + '/.gitconfig.shared')) | Should -BeExactly $before
    [IO.File]::ReadAllText(($script:stableTarget + '/.gitattributes')) | Should -Match 'GENERATED FILE'
  }
  It 'performs zero output writes with WhatIf' {
    $paths = @($script:protected) + @($script:overlay, ($script:sprintTarget + '/.gitattributes'), ($script:sprintTarget + '/.gitconfig.shared'))
    $before = Get-FixturePins $paths
    Invoke-FixtureWriter -WhatIf
    Get-FixturePins $paths | Should -BeExactly $before
  }
  It 'rejects cross-repository workspace groups before output writes' {
    $other = Write-FixtureWorkspace $script:wrongRoot
    $before = Get-FixturePins @($script:overlay, ($script:sprintTarget + '/.gitattributes'), ($script:sprintTarget + '/.gitconfig.shared'))
    { Invoke-FixtureWriter @($script:workspace, $other) } | Should -Throw '*WorkspaceConflict*'
    Get-FixturePins @($script:overlay, ($script:sprintTarget + '/.gitattributes'), ($script:sprintTarget + '/.gitconfig.shared')) | Should -BeExactly $before
  }
  It 'accepts compatible duplicate workspaces without duplicating route keys' {
    $second = Write-FixtureWorkspace $script:sprintTarget 'SharedVSCode-wt-source' 'Second.code-workspace'
    Invoke-FixtureWriter @($script:workspace, $second, $script:workspace)
    $value = Invoke-FixtureGit $script:sprintTarget @('config', '--worktree', '--get-all', ('includeIf.gitdir/i:' + $script:targetGitDir + '.path'))
    $value | Should -BeExactly (($script:sprintTarget + '/.gitconfig.shared'))
  }
  It 'refuses missing worktreeConfig instead of implicitly migrating common config' {
    $null = Invoke-FixtureGit $script:stableTarget @('config', '--local', '--unset-all', 'extensions.worktreeConfig')
    $before = Get-FixturePins @(($script:targetDir + '/config'), $script:overlay)
    { Invoke-FixtureWriter } | Should -Throw '*MissingPrerequisite*'
    Get-FixturePins @(($script:targetDir + '/config'), $script:overlay) | Should -BeExactly $before
  }
  It 'refuses legacy unconditional common include without changing it' {
    Fixture-Config $script:stableTarget '--local' 'include.path' (($script:stableTarget + '/.gitconfig.shared'))
    $before = Get-FixturePins @(($script:targetDir + '/config'), $script:overlay)
    { Invoke-FixtureWriter } | Should -Throw '*UnsafeIncludeRoute*'
    Get-FixturePins @(($script:targetDir + '/config'), $script:overlay) | Should -BeExactly $before
  }
  It 'rejects an output directory before generating files or writing routing' {
    [IO.Directory]::CreateDirectory((Assert-OwnedFixturePath (($script:sprintTarget + '/.gitattributes')))) | Out-Null
    { Invoke-FixtureWriter } | Should -Throw '*OutputIsDirectory*'
    [IO.File]::Exists(($script:sprintTarget + '/.gitconfig.shared')) | Should -BeFalse
    [IO.File]::Exists($script:overlay) | Should -BeFalse
  }
  It 'restores both known generated postimages and absence when the config boundary fails' {
    $script:fault = 'before-config'
    { Invoke-FixtureWriter } | Should -Throw '*InjectedConfigBoundaryFailure*'
    foreach ($p in @($script:overlay, ($script:sprintTarget + '/.gitattributes'), ($script:sprintTarget + '/.gitconfig.shared'))) { [IO.File]::Exists($p) | Should -BeFalse }
  }
  It 'holds recovery and preserves a peer-changed postimage instead of restoring over it' {
    $script:fault = 'peer-after-attributes'
    { Invoke-FixtureWriter } | Should -Throw '*HeldRecovery*'
    [IO.File]::ReadAllText(($script:sprintTarget + '/.gitattributes')) | Should -BeExactly 'peer bytes'
    [IO.File]::Exists($script:overlay) | Should -BeFalse
  }
}
