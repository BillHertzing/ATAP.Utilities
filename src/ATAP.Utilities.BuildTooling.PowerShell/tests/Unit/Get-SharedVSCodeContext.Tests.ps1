# SOURCE-ONLY HANDOFF: separate import/fixture/test admission is required.
# Fresh profiled child + Pester 6.2.0; never import the installed parent module.
BeforeAll {
  $script:fixtureBase = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../_generated/Sprint0017/17.66/IncludeRouting/Get-SharedVSCodeContext.Tests')).Replace('\', '/')
  $script:ownerId = [guid]::NewGuid().ToString('N')
  $script:runRoot = $script:fixtureBase + '/' + $script:ownerId
  $script:gitExecutable = [IO.Path]::Combine([Environment]::GetFolderPath('ProgramFiles'), 'Git', 'cmd', 'git.exe')
  $script:savedEnvironment = @{}
  $script:environmentCaptured = $false
  $script:raceAction = $null
  $script:loggerFailureStage = $null
  $script:loggerFailureKind = $null
  $script:logCalls = [Collections.Generic.List[object]]::new()
  function script:Assert-OwnedFixturePath {
    param([string]$Path, [switch]$AllowRun)
    if ($Path -notmatch '^[A-Za-z]:[/\\]' -or $Path.Substring(2) -match '[:*?\[\]\x00-\x1f]' -or $Path.Replace('\', '/') -match '(?:^|/)\.\.?(?:/|$)') { throw 'Unsafe fixture path' }
    $full = [IO.Path]::GetFullPath($Path).Replace('\', '/').TrimEnd('/')
    if (!$full.StartsWith($script:runRoot + '/', [StringComparison]::OrdinalIgnoreCase) -and !($AllowRun -and [string]::Equals($full, $script:runRoot, [StringComparison]::OrdinalIgnoreCase))) { throw 'Fixture escaped owning run' }
    $ancestor = [IO.DirectoryInfo]::new($full)
    while ($null -ne $ancestor) {
      if ($ancestor.Exists -and $null -ne $ancestor.LinkTarget) { throw 'Fixture link ancestry changed' }
      $ancestor = $ancestor.Parent
    }
    if ([IO.File]::Exists($full) -and $null -ne ([IO.FileInfo]::new($full)).LinkTarget) { throw 'Fixture file redirected' }
    return $full
  }
  function script:Write-FixtureText {
    param([string]$Path, [string]$Text)
    $full = Assert-OwnedFixturePath $Path
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($full)) | Out-Null
    [IO.File]::WriteAllText($full, $Text, [Text.UTF8Encoding]::new($false))
  }
  function script:Invoke-FixtureGit {
    param([string]$Root, [string[]]$Arguments)
    $full = Assert-OwnedFixturePath $Root
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $script:gitExecutable
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($value in @('-c', 'core.longpaths=true', '--no-optional-locks', '-C', $full) + $Arguments) { $start.ArgumentList.Add($value) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    try {
      $null = $process.Start()
      $stdout = $process.StandardOutput.ReadToEndAsync()
      $stderr = $process.StandardError.ReadToEndAsync()
      $process.WaitForExit()
      $text = $stdout.GetAwaiter().GetResult()
      $errorText = $stderr.GetAwaiter().GetResult()
      if ($process.ExitCode -ne 0) {
        $nativeExitCode = $process.ExitCode
        $diagnosticName = 'native-failure-' + [guid]::NewGuid().ToString('N') + '.json'
        $diagnosticStatus = 'not retained'
        try {
          $diagnosticPath = Assert-OwnedFixturePath ($script:runRoot + '/' + $diagnosticName)
          $diagnostic = [ordered]@{
            SchemaVersion = 1
            DiagnosticId = $diagnosticName
            Executable = $start.FileName
            Arguments = @($start.ArgumentList)
            FixturePath = $full
            ExitCode = $nativeExitCode
            StandardOutput = $text
            StandardError = $errorText
          }
          $diagnosticBytes = [Text.UTF8Encoding]::new($false).GetBytes(($diagnostic | ConvertTo-Json -Depth 4))
          $diagnosticStream = [IO.File]::Open($diagnosticPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
          try {
            $diagnosticStream.Write($diagnosticBytes, 0, $diagnosticBytes.Length)
          } finally { $diagnosticStream.Dispose() }
          $diagnosticStatus = 'retained'
        } catch {
          # Keep native failure primary, including when evidence retention fails.
          $diagnosticStatus = 'retention failed: ' + $_.Exception.GetType().FullName
        }
        throw ('Fixture native command failed (exit {0}; diagnostic {1}; {2})' -f $nativeExitCode, $diagnosticName, $diagnosticStatus)
      }
      return $text.TrimEnd([char[]]@([char]13, [char]10))
    } finally { $process.Dispose() }
  }
  function script:Fixture-Config {
    param([string]$Root, [string]$Scope, [string]$Key, [string]$Value)
    $null = Invoke-FixtureGit $Root @('config', $Scope, '--replace-all', $Key, $Value)
  }
  function script:Get-FixtureTemplateOrigins {
    param([string]$Root)
    # Independent actual-Git activation oracle. --null avoids quoting/space
    # ambiguities; each origin/value pair retains its native order. A direct
    # worktree override cannot manufacture an included-file origin occurrence.
    $raw = Invoke-FixtureGit $Root @('config', '--includes', '--null', '--show-origin', '--get-all', 'commit.template')
    $fields = $raw.Split([char]0)
    if ($fields[-1] -ne '' -or (($fields.Count - 1) % 2) -ne 0) { throw 'Malformed fixture template-origin frame' }
    for ($index = 0; $index -lt $fields.Count - 1; $index += 2) {
      if (!$fields[$index].StartsWith('file:')) { throw 'Non-file fixture template origin' }
      $origin = $fields[$index].Substring(5).Replace('\', '/')
      if ($origin -notmatch '^[A-Za-z]:/') { $origin = [IO.Path]::Combine($Root, $origin) }
      $origin = Assert-OwnedFixturePath $origin
      [pscustomobject]@{ OriginPath = $origin; Value = $fields[$index + 1] }
    }
  }
  function script:New-FixtureRepository {
    param([string]$Root)
    $null = Assert-OwnedFixturePath $Root
    [IO.Directory]::CreateDirectory($Root) | Out-Null
    $null = Invoke-FixtureGit $Root @('init', '--initial-branch=main', ('--template=' + $script:emptyTemplates))
    Fixture-Config $Root '--local' 'user.name' 'Resolver Fixture'
    Fixture-Config $Root '--local' 'user.email' 'resolver-fixture@example.invalid'
    Fixture-Config $Root '--local' 'commit.gpgsign' 'false'
    Fixture-Config $Root '--local' 'core.hooksPath' $script:emptyHooks
    $null = Invoke-FixtureGit $Root @('commit', '--allow-empty', '--no-verify', '-m', 'fixture')
    Fixture-Config $Root '--local' 'extensions.worktreeConfig' 'true'
  }
  function script:New-FixtureAssets {
    param([string]$Root)
    Write-FixtureText ($Root + '/.gitconfig') "[core]`n autocrlf = false`n[commit]`n template = GitTemplates/git.commit.template.txt`n"
    Write-FixtureText ($Root + '/.gitattributes') "* text=auto eol=lf`n"
    Write-FixtureText ($Root + '/GitTemplates/git.commit.template.txt') "Fixture template`n"
    $null = Assert-OwnedFixturePath ($Root + '/.githooks')
    [IO.Directory]::CreateDirectory($Root + '/.githooks') | Out-Null
  }
  function script:Write-FixtureRender {
    param([string]$TargetRoot, [string]$SourceRoot)
    $source = Assert-OwnedFixturePath ($SourceRoot + '/.gitconfig')
    $header = @('# ===================================================================', '# GENERATED FILE - DO NOT EDIT DIRECTLY', '# Source: SharedVSCode/.gitconfig', '# Regenerate using Set-DownstreamSharedVSCodeContext', '# ===================================================================', '') -join "`n"
    Write-FixtureText ($TargetRoot + '/.gitconfig.shared') ($header + ([IO.File]::ReadAllText($source) -replace '\r\n?', "`n") + "`n")
  }
  function script:Set-FixtureCommonRoute {
    param([string]$MainRoot, [string]$StableSource, [switch]$Canonical)
    $dir = (Invoke-FixtureGit $MainRoot @('rev-parse', '--absolute-git-dir')).Replace('\', '/')
    $target = if ($Canonical) { $MainRoot + '/.gitconfig' } else { $MainRoot + '/.gitconfig.shared' }
    if (!$Canonical) { Write-FixtureRender $MainRoot $StableSource }
    $null = Invoke-FixtureGit $MainRoot @('config', '--local', '--unset-all', 'core.hooksPath')
    Fixture-Config $MainRoot '--local' ('includeIf.gitdir/i:' + $dir + '.path') $target
    # Git's key setter reuses the existing [core] section. Append fresh context
    # sections after include instead, in this OWNED fixture config only.
    $configPath = $dir + '/config'
    $current = [IO.File]::ReadAllText((Assert-OwnedFixturePath $configPath))
    $suffix = "`n[core]`n hooksPath = $StableSource/.githooks`n[commit]`n template = $StableSource/GitTemplates/git.commit.template.txt`n"
    Write-FixtureText $configPath ($current + $suffix)
    return $dir
  }
  function script:Set-FixtureLinkedRoute {
    param([string]$Root, [string]$Source, [switch]$Canonical)
    $dir = (Invoke-FixtureGit $Root @('rev-parse', '--absolute-git-dir')).Replace('\', '/')
    $target = if ($Canonical) { $Source + '/.gitconfig' } else { $Root + '/.gitconfig.shared' }
    if (!$Canonical) { Write-FixtureRender $Root $Source }
    Fixture-Config $Root '--worktree' ('includeIf.gitdir/i:' + $dir + '.path') $target
    Fixture-Config $Root '--worktree' 'core.hooksPath' ($Source + '/.githooks')
    Fixture-Config $Root '--worktree' 'commit.template' ($Source + '/GitTemplates/git.commit.template.txt')
    return $dir
  }
  function script:Write-FixtureWorkspace {
    param([string]$Root, [string]$Ref = 'main', [string]$Name = 'Fixture.code-workspace', [string]$Profile = 'default')
    $path = $Root + '/' + $Name
    Write-FixtureText $path (@{ folders = @(@{ path = '.' }); settings = @{ 'atap.sharedVSCode.templateRef' = $Ref; 'atap.sharedVSCode.profile' = $Profile } } | ConvertTo-Json -Depth 8)
    return $path
  }
  function script:Invoke-FixtureResolver {
    param([string[]]$WorkspaceFiles, [hashtable]$Options = @{})
    if (!$Options.ContainsKey('GitRoot')) { throw 'SharedVSCodeContext.ExplicitFixtureGitRootRequired' }
    $null = Assert-OwnedFixturePath $Options.GitRoot
    foreach ($workspace in $WorkspaceFiles) { $null = Assert-OwnedFixturePath $workspace }
    return Get-SharedVSCodeContext -WorkspaceFiles $WorkspaceFiles @Options
  }
  function script:Get-FixtureSnapshot {
    param([string]$Root)
    $full = Assert-OwnedFixturePath $Root
    $pins = [ordered]@{}
    $pending = [Collections.Generic.Queue[string]]::new()
    $pending.Enqueue($full)
    while ($pending.Count) {
      foreach ($entry in [IO.Directory]::EnumerateFileSystemEntries($pending.Dequeue()) | Sort-Object) {
        $null = Assert-OwnedFixturePath $entry
        if ([IO.Directory]::Exists($entry)) { $pending.Enqueue($entry) }
        else { $pins[$entry] = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([IO.File]::ReadAllBytes($entry))) }
      }
    }
    return ($pins | ConvertTo-Json -Compress)
  }
  function script:Remove-OwnedFixtureChild {
    param([string]$Path)
    $full = Assert-OwnedFixturePath $Path
    $markerPath = $full + '/.owner'
    if (![IO.File]::Exists($markerPath) -or [IO.File]::ReadAllText($markerPath) -cne $script:ownerId) { throw 'Missing/changed cleanup marker' }
    $pending = [Collections.Generic.Queue[string]]::new()
    $pending.Enqueue($full)
    while ($pending.Count) {
      foreach ($child in [IO.Directory]::EnumerateFileSystemEntries($pending.Dequeue())) {
        $null = Assert-OwnedFixturePath $child
        if ([IO.Directory]::Exists($child)) { $pending.Enqueue($child) }
      }
    }
    $null = Assert-OwnedFixturePath $full
    if ([IO.File]::ReadAllText($markerPath) -cne $script:ownerId) { throw 'Cleanup ownership changed' }
    Remove-Item -LiteralPath $full -Recurse -Force -ErrorAction Stop
  }
  function script:Assert-ResolverFailure {
    param([scriptblock]$Action, [string]$Code)
    $output = [Collections.Generic.List[object]]::new()
    $failure = $null
    try { & $Action | ForEach-Object { $output.Add($_) } } catch { $failure = $_ }
    $failure | Should -Not -BeNullOrEmpty
    $failure.FullyQualifiedErrorId | Should -BeLike ('SharedVSCodeContext.' + $Code + '*')
    $output.Count | Should -Be 0
  }
  function script:Invoke-ReadParserOracle {
    [CmdletBinding()]
    param([string]$Kind, [string]$Raw, [string]$Inside = 'true', [switch]$MultipleTop, [switch]$MainIdentity,
      [string]$ConfigRoot = $script:sprintTarget)
    # Parser-only negative tests use the EXACT named, function-only definitions
    # from reviewed source. They are NOT actual-Git or transport proof. A closed
    # local readGit stub cannot forward to any process or production repository.
    $resolverCmdlet = $PSCmdlet
    $comparison = [StringComparison]::OrdinalIgnoreCase
    $watch = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::OrdinalIgnoreCase)
    $watchOrder = [Collections.Generic.List[string]]::new()
    $identityWatch = [Collections.Generic.Dictionary[string, string]]::new([StringComparer]::OrdinalIgnoreCase)
    $tokens = $null; $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($script:resolverPath, [ref]$tokens, [ref]$errors)
    if ($errors.Count) { throw 'Cannot extract parser definitions from invalid source' }
    foreach ($name in @('failContext', 'samePath', 'safeRelative', 'localPath', 'containedPath', 'snapshotFile', 'oneGit', 'registeredIdentity', 'readContextConfig')) {
      $definitions = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name }, $true))
      if ($definitions.Count -ne 1) { throw 'Parser definition scope changed; review required' }
      . ([scriptblock]::Create($definitions[0].Extent.Text))
    }
    $oracleDir = (Invoke-FixtureGit $script:sprintTarget @('rev-parse', '--absolute-git-dir')).Replace('\', '/')
    $oracleCommon = (Invoke-FixtureGit $script:sprintTarget @('rev-parse', '--path-format=absolute', '--git-common-dir')).Replace('\', '/')
    function readGit([string]$Root, [string[]]$Arguments, [bool]$Optional = $false) {
      switch ($Arguments -join ' ') {
        'rev-parse --is-inside-work-tree' { return ($Inside + [char]10) }
        'rev-parse --show-toplevel' {
          $identityTop = if ($MainIdentity) { $script:stableTarget } else { $script:sprintTarget }
          if ($MultipleTop) { return ($identityTop + [char]10 + $identityTop + [char]10) }
          return ($identityTop + [char]10)
        }
        'rev-parse --absolute-git-dir' { if ($Root -eq $script:stableTarget) { return ($oracleCommon + [char]10) }; return ($oracleDir + [char]10) }
        'rev-parse --path-format=absolute --git-common-dir' { return ($oracleCommon + [char]10) }
        'worktree list --porcelain -z' { return $Raw }
        default { if ($Arguments[0] -eq 'config') { return $Raw }; throw 'Closed parser oracle: unexpected native query' }
      }
    }
    if ($Kind -eq 'Identity') {
      $identityRoot = if ($MainIdentity) { $script:stableTarget } else { $script:sprintTarget }
      return (registeredIdentity $identityRoot)
    }
    if ($Kind -eq 'Config') {
      $null = Assert-OwnedFixturePath $ConfigRoot
      return @(readContextConfig $ConfigRoot)
    }
    throw 'Closed parser oracle: invalid kind'
  }
  function script:Write-PSFMessage {
    [CmdletBinding()]
    param([string]$FunctionName, [string]$ModuleName, [string]$Level, [string]$Message, [string[]]$Tag)
    $script:logCalls.Add([pscustomobject]@{ FunctionName = $FunctionName; ModuleName = $ModuleName; Level = $Level })
    if ($Message -eq $script:loggerFailureStage) {
      if ($script:loggerFailureKind -eq 'Nonterminating') {
        Write-Error 'Owned fixture logger continuing error' -ErrorAction Continue
        return 'logger-success-output-must-not-escape'
      }
      if ($script:loggerFailureKind -eq 'Throw') { throw 'Owned fixture logger throw' }
    }
    if ($Message -eq 'Rechecking read-only context' -and $null -ne $script:raceAction) {
      $action = $script:raceAction
      $script:raceAction = $null
      $null = & $action # Deliberate owned-fixture race only; no real logging sink.
    }
  }
  try {
    $null = Assert-OwnedFixturePath $script:runRoot -AllowRun
    if (Test-Path -LiteralPath $script:runRoot) { throw 'Do not adopt an existing run' }
    [IO.Directory]::CreateDirectory($script:runRoot) | Out-Null
    Write-FixtureText ($script:runRoot + '/.owner') $script:ownerId
    foreach ($entry in [Environment]::GetEnvironmentVariables().GetEnumerator()) {
      if ($entry.Key -like 'GIT_*' -or $entry.Key -in @('HOME', 'USERPROFILE', 'XDG_CONFIG_HOME')) { $script:savedEnvironment[$entry.Key] = $entry.Value }
    }
    $script:environmentCaptured = $true
    foreach ($key in @([Environment]::GetEnvironmentVariables().Keys)) { if ($key -like 'GIT_*') { [Environment]::SetEnvironmentVariable($key, [NullString]::Value, 'Process') } }
    $script:homeRoot = $script:runRoot + '/home'
    $script:emptyTemplates = $script:runRoot + '/empty-templates'
    $script:emptyHooks = $script:runRoot + '/empty-hooks'
    foreach ($dir in @($script:homeRoot, $script:emptyTemplates, $script:emptyHooks)) {
      $null = Assert-OwnedFixturePath $dir
      [IO.Directory]::CreateDirectory($dir) | Out-Null
    }
    foreach ($key in @('HOME', 'USERPROFILE', 'XDG_CONFIG_HOME')) { [Environment]::SetEnvironmentVariable($key, $script:homeRoot, 'Process') }
    [Environment]::SetEnvironmentVariable('GIT_CONFIG_NOSYSTEM', '1', 'Process')
    [Environment]::SetEnvironmentVariable('GIT_CONFIG_GLOBAL', ($script:homeRoot + '/global.config'), 'Process')
    [Environment]::SetEnvironmentVariable('GIT_CONFIG_SYSTEM', ($script:homeRoot + '/system.config'), 'Process')
    # Deep repository-root evidence paths can exceed MAX_PATH; only the isolated
    # fixture global config/arrangement opts into long paths, never user config.
    Write-FixtureText ($script:homeRoot + '/global.config') "[core]`n longpaths = true`n"
    Write-FixtureText ($script:homeRoot + '/system.config') ''
    if (![IO.File]::Exists($script:gitExecutable)) { throw 'Installed Git unavailable; no install/fallback' }
    $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:resolverPath = Join-Path $moduleRoot 'public/Get-SharedVSCodeContext.ps1'
    . $script:resolverPath # Function-only source; no parent/helper import.
  } catch {
    if ($script:environmentCaptured) {
      foreach ($key in @([Environment]::GetEnvironmentVariables().Keys)) { if ($key -like 'GIT_*' -or $key -in @('HOME', 'USERPROFILE', 'XDG_CONFIG_HOME')) { [Environment]::SetEnvironmentVariable($key, [NullString]::Value, 'Process') } }
      foreach ($key in $script:savedEnvironment.Keys) { [Environment]::SetEnvironmentVariable($key, $script:savedEnvironment[$key], 'Process') }
    }
    throw
  }
}
AfterAll {
  $script:raceAction = $null
  $script:loggerFailureStage = $null
  $script:loggerFailureKind = $null
  if ($script:environmentCaptured) {
    foreach ($key in @([Environment]::GetEnvironmentVariables().Keys)) { if ($key -like 'GIT_*' -or $key -in @('HOME', 'USERPROFILE', 'XDG_CONFIG_HOME')) { [Environment]::SetEnvironmentVariable($key, [NullString]::Value, 'Process') } }
    foreach ($key in $script:savedEnvironment.Keys) { [Environment]::SetEnvironmentVariable($key, $script:savedEnvironment[$key], 'Process') }
  }
  # Retain all fixture repos/registrations/evidence under the owning run.
  # Test script scope, including logger/resolver, expires with the fresh child.
}
Describe 'Get-SharedVSCodeContext Normal (source-only; execution separately admitted)' {
  BeforeEach {
    $script:raceAction = $null
    $script:loggerFailureStage = $null
    $script:loggerFailureKind = $null
    $script:caseRoot = $script:runRoot + '/' + [guid]::NewGuid().ToString('N').Substring(0, 8)
    $null = Assert-OwnedFixturePath $script:caseRoot
    if (Test-Path -LiteralPath $script:caseRoot) { throw 'Do not adopt an existing case' }
    [IO.Directory]::CreateDirectory($script:caseRoot) | Out-Null
    Write-FixtureText ($script:caseRoot + '/.owner') $script:ownerId
    $script:stableSource = $script:caseRoot + '/SharedVSCode'
    $script:sprintSource = $script:caseRoot + '/SharedVSCode-wt-source'
    $script:stableTarget = $script:caseRoot + '/Downstream A'
    $script:sprintTarget = $script:caseRoot + '/Downstream A-wt-target'
    New-FixtureRepository $script:stableSource
    $null = Invoke-FixtureGit $script:stableSource @('worktree', 'add', '-b', 'fixture-source', $script:sprintSource)
    New-FixtureAssets $script:stableSource
    New-FixtureAssets $script:sprintSource
    Write-FixtureText ($script:sprintSource + '/.gitconfig') "[core]`n autocrlf = false`n[alias]`n fixture = status`n[commit]`n template = GitTemplates/git.commit.template.txt`n"
    $script:sourceMainDir = Set-FixtureCommonRoute $script:stableSource $script:stableSource -Canonical
    New-FixtureRepository $script:stableTarget
    $null = Invoke-FixtureGit $script:stableTarget @('worktree', 'add', '-b', 'fixture-target', $script:sprintTarget)
    $script:targetMainDir = Set-FixtureCommonRoute $script:stableTarget $script:stableSource
    $script:workspace = Write-FixtureWorkspace $script:sprintTarget 'SharedVSCode-wt-source' -Profile 'sprint-fixture'
    $script:options = @{ GitRoot = $script:caseRoot }
  }
  It 'R01 preserves eight legacy fields and adds versioned Normal Plan without editing workspace' {
    $before = Get-FileHash -LiteralPath $script:workspace
    $result = @(Invoke-FixtureResolver @($script:workspace) $script:options)
    $result.Count | Should -Be 1
    foreach ($name in @('WorkspaceFile', 'TemplateRef', 'Profile', 'SharedRoot', 'GitConfig', 'GitAttributes', 'CommitTemplate', 'HooksPath')) { $result[0].PSObject.Properties.Name | Should -Contain $name }
    $result[0].TemplateRef | Should -Be 'SharedVSCode-wt-source'
    $result[0].OriginalTemplateRef | Should -Be 'SharedVSCode-wt-source'
    $result[0].Profile | Should -Be 'sprint-fixture'
    $result[0].GitConfig | Should -Be ($script:sprintSource + '/.gitconfig')
    $result[0].GitAttributes | Should -Be ($script:sprintSource + '/.gitattributes')
    $result[0].CommitTemplate | Should -Be ($script:sprintSource + '/GitTemplates/git.commit.template.txt')
    $result[0].HooksPath | Should -Be ($script:sprintSource + '/.githooks')
    $result[0].Plan.SchemaVersion | Should -Be 2
    $result[0].Plan.ContextMode | Should -Be 'Normal'
    $result[0].Plan.PSObject.Properties.Name | Should -Not -Contain 'EffectiveGitContext'
    (Get-FileHash -LiteralPath $script:workspace).Hash | Should -Be $before.Hash
  }
  It 'R01 preserves missing-profile default and main plus compatible duplicate input order' {
    Write-FixtureText $script:workspace '{"settings":{"atap.sharedVSCode.templateRef":"main"}}'
    $second = Write-FixtureWorkspace $script:sprintTarget 'main' 'Second.code-workspace'
    $result = @(Invoke-FixtureResolver @($second, $script:workspace, $second) $script:options)
    $result.Count | Should -Be 3
    $result[0].WorkspaceFile | Should -Be $second
    $result[1].Profile | Should -Be 'default'
    $result[0].Plan.WorkspaceGroup.Count | Should -Be 2
    $result[0].SharedRoot | Should -Be $script:stableSource
  }
  It 'R01 rejects malformed JSON, missing settings/ref and wrong profile type without partial output' {
    foreach ($variant in @(
        @{ Text = '{'; Code = 'InvalidWorkspaceJson' },
        @{ Text = '{}'; Code = 'MissingWorkspaceSetting' },
        @{ Text = '{"settings":{}}'; Code = 'MissingWorkspaceSetting' },
        @{ Text = '{"settings":{"atap.sharedVSCode.templateRef":"main","atap.sharedVSCode.profile":[]}}'; Code = 'InvalidWorkspaceJson' }
      )) {
      $bad = $script:sprintTarget + '/Bad.code-workspace'
      Write-FixtureText $bad $variant.Text
      Assert-ResolverFailure { Invoke-FixtureResolver @($bad) $script:options } $variant.Code
    }
  }
  It 'R01 rejects absent source, required asset and explicit empty override' {
    $script:options.RequestedTemplateRef = 'MissingSource'
    Assert-ResolverFailure { Invoke-FixtureResolver @($script:workspace) $script:options } 'MissingPrerequisite'
    $script:options.Remove('RequestedTemplateRef')
    $asset = $script:sprintSource + '/.gitconfig'
    $content = [IO.File]::ReadAllText($asset)
    [IO.File]::Delete((Assert-OwnedFixturePath $asset))
    Assert-ResolverFailure { Invoke-FixtureResolver @($script:workspace) $script:options } 'MissingPrerequisite'
    Write-FixtureText $asset $content
    $script:options.RequestedTemplateRef = ''
    Assert-ResolverFailure { Invoke-FixtureResolver @($script:workspace) $script:options } 'UnsafePath'
  }
  It 'R02 covers ten stable/sprint rows; canonical source never reads stale generated copy' {
    foreach ($pair in @(@{ Root = $script:stableSource; Ref = 'main'; Role = 'CanonicalSourceStable' }, @{ Root = $script:sprintSource; Ref = 'SharedVSCode-wt-source'; Role = 'CanonicalSourceSprint' })) {
      Write-FixtureText ($pair.Root + '/.gitconfig.shared') 'stale canonical generated copy'
      if ($pair.Role -eq 'CanonicalSourceSprint') { $null = Set-FixtureLinkedRoute $pair.Root $pair.Root -Canonical }
      $ws = Write-FixtureWorkspace $pair.Root $pair.Ref
      $plan = (Invoke-FixtureResolver @($ws) $script:options).Plan
      $plan.Role | Should -Be $pair.Role
      $plan.Route.IncludeTarget | Should -Be ($pair.Root + '/.gitconfig')
      $plan.Route.CanRenderConsumerFiles | Should -BeFalse
    }
    foreach ($number in 1..4) {
      $main = $script:caseRoot + '/Consumer' + $number
      $linked = $main + '-wt-linked'
      New-FixtureRepository $main
      $null = Invoke-FixtureGit $main @('worktree', 'add', '-b', ('consumer' + $number), $linked)
      $null = Set-FixtureCommonRoute $main $script:stableSource
      foreach ($pair in @(@{ Root = $main; Ref = 'main'; Role = 'DownstreamStable' }, @{ Root = $linked; Ref = 'SharedVSCode-wt-source'; Role = 'DownstreamSprint' })) {
        if ($pair.Role -eq 'DownstreamSprint') { $null = Set-FixtureLinkedRoute $linked $script:sprintSource }
        $ws = Write-FixtureWorkspace $pair.Root $pair.Ref
        $plan = (Invoke-FixtureResolver @($ws) $script:options).Plan
        $plan.Role | Should -Be $pair.Role
        $plan.Route.IncludeTarget | Should -Be ($pair.Root + '/.gitconfig.shared')
        $plan.AssetPins.Count | Should -Be 3
        $plan.Route.CanRenderConsumerFiles | Should -BeTrue
      }
    }
  }
  It 'R03 binds registered gitdir after renamed checkout, spaces/slashes and sibling-prefix neighbor' {
    $oldDir = (Invoke-FixtureGit $script:sprintTarget @('rev-parse', '--absolute-git-dir')).Replace('\', '/')
    $renamed = $script:caseRoot + '/Renamed target with spaces'
    $null = Invoke-FixtureGit $script:stableTarget @('worktree', 'move', $script:sprintTarget, $renamed)
    $ws = Write-FixtureWorkspace $renamed 'SharedVSCode-wt-source'
    # Match the actual administrative gitdir prefix, not a guessed checkout name.
    $sibling = $script:caseRoot + '/' + [IO.Path]::GetFileName($oldDir) + 'n'
    $null = Invoke-FixtureGit $script:stableTarget @('worktree', 'add', '-b', 'neighbor', $sibling)
    $neighborDir = (Invoke-FixtureGit $sibling @('rev-parse', '--absolute-git-dir')).Replace('\', '/')
    $neighborDir.StartsWith($oldDir + 'n', [StringComparison]::OrdinalIgnoreCase) | Should -BeTrue
    $null = Set-FixtureLinkedRoute $renamed $script:sprintSource
    $plan = (Invoke-FixtureResolver @($ws.Replace('/', '\')) $script:options).Plan
    $plan.Target.GitDir | Should -Be $oldDir
    $plan.Route.Condition | Should -Be ('gitdir/i:' + $oldDir)
    $plan.Route.Condition | Should -Not -Match '/$|[*?]'
    $plan.Target.TopLevel | Should -Be $renamed
    $active = @(Get-FixtureTemplateOrigins $renamed)
    @($active | Where-Object { $_.OriginPath -eq ($renamed + '/.gitconfig.shared') -and $_.Value -eq 'GitTemplates/git.commit.template.txt' }).Count | Should -Be 1

    # Put a temporary probe in the COMMON fixture config so BOTH registered
    # gitdirs can see the condition. Never call the resolver while this extra
    # oracle-only route is present. Direct target overrides stay unchanged.
    $probe = $script:caseRoot + '/activation-probe.config'
    Write-FixtureText $probe "[commit]`n template = RR02-included-file-only`n"
    $commonPath = Assert-OwnedFixturePath ($script:targetMainDir + '/config')
    $savedCommon = [IO.File]::ReadAllBytes($commonPath)
    try {
      foreach ($variant in @(
          @{ Condition = $oldDir; Target = 1; Neighbor = 0 },
          @{ Condition = ($oldDir + '-nonmatching'); Target = 0; Neighbor = 0 },
          @{ Condition = ($oldDir + '*'); Target = 1; Neighbor = 1 }
        )) {
        [IO.File]::WriteAllBytes($commonPath, $savedCommon)
        Fixture-Config $script:stableTarget '--local' ('includeIf.gitdir/i:' + $variant.Condition + '.path') $probe
        $targetRows = @(Get-FixtureTemplateOrigins $renamed)
        $neighborRows = @(Get-FixtureTemplateOrigins $sibling)
        @($targetRows | Where-Object { $_.OriginPath -eq $probe -and $_.Value -eq 'RR02-included-file-only' }).Count | Should -Be $variant.Target
        @($neighborRows | Where-Object { $_.OriginPath -eq $probe -and $_.Value -eq 'RR02-included-file-only' }).Count | Should -Be $variant.Neighbor
        $targetRows[-1].Value | Should -Be ($script:sprintSource + '/GitTemplates/git.commit.template.txt')
      }
    } finally { [IO.File]::WriteAllBytes($commonPath, $savedCommon) }
    (Invoke-FixtureResolver @($ws) $script:options).Plan.Target.GitDir | Should -Be $oldDir
  }
  It 'R04 RP01-A1 compares desired include and template origins with independent actual Git query' {
    $null = Set-FixtureLinkedRoute $script:sprintTarget $script:sprintSource
    $result = Invoke-FixtureResolver @($script:workspace) $script:options
    $result.Plan.CurrentRouteState | Should -Be 'AlreadyDesired'
    $oracle = Invoke-FixtureGit $script:sprintTarget @('config', '--includes', '--show-origin', '--get-all', 'commit.template')
    $oracle | Should -Match ([regex]::Escape($script:sprintSource + '/GitTemplates/git.commit.template.txt'))
    $originRows = @(Get-FixtureTemplateOrigins $script:sprintTarget)
    $includedRows = @($originRows | Where-Object { $_.OriginPath -eq ($script:sprintTarget + '/.gitconfig.shared') })
    $includedRows.Count | Should -Be 1
    $includedRows[0].Value | Should -Be 'GitTemplates/git.commit.template.txt'
    $originRows[-1].OriginPath | Should -Be ($result.Plan.Target.GitDir + '/config.worktree')
    $originRows[-1].Value | Should -Be ($script:sprintSource + '/GitTemplates/git.commit.template.txt')
    $result.Plan.ObservedIncludes.Count | Should -Be 2
    @($result.Plan.ObservedIncludes | Where-Object AppliesToTarget).Count | Should -Be 1
    $result.Plan.ObservedContext.Template.OriginPath | Should -Be $result.Plan.Route.ConfigPath
  }
  It 'R04 RP01-A2/A3 accepts safe absence and unrelated overlay; current baseline differs desired' {
    $result = Invoke-FixtureResolver @($script:workspace) $script:options
    $result.Plan.CurrentRouteState | Should -Be 'SafeUnconfiguredLinked'
    $result.Plan.DestinationPins[0].Exists | Should -BeFalse
    $result.Plan.DestinationPins[0].Sha256 | Should -BeNullOrEmpty
    $result.Plan.ObservedContext.Hooks.Value | Should -Be ($script:stableSource + '/.githooks')
    $result.Plan.Route.HooksTarget | Should -Be ($script:sprintSource + '/.githooks')
    Fixture-Config $script:sprintTarget '--worktree' 'fixture.unrelated' 'preserve'
    Write-FixtureText ($script:sprintTarget + '/.gitconfig.shared') 'unowned inactive bytes'
    $again = Invoke-FixtureResolver @($script:workspace) $script:options
    $again.Plan.CurrentRouteState | Should -Be 'SafeUnconfiguredLinked'
    $again.Plan.DestinationPins[0].Ownership | Should -Be 'Unasserted'
  }
  It 'R04 RP01-N1/N2 rejects missing extension, legacy common include and active dangling target' {
    Fixture-Config $script:stableTarget '--local' 'extensions.worktreeConfig' 'false'
    Assert-ResolverFailure { Invoke-FixtureResolver @($script:workspace) $script:options } 'MissingPrerequisite'
    Fixture-Config $script:stableTarget '--local' 'extensions.worktreeConfig' 'true'
    Fixture-Config $script:stableTarget '--local' 'include.path' ($script:stableTarget + '/.gitconfig.shared')
    Assert-ResolverFailure { Invoke-FixtureResolver @($script:workspace) $script:options } 'UnsafeIncludeRoute'
    $null = Invoke-FixtureGit $script:stableTarget @('config', '--local', '--unset-all', 'include.path')
    $null = Set-FixtureLinkedRoute $script:sprintTarget $script:sprintSource
    [IO.File]::Delete((Assert-OwnedFixturePath ($script:sprintTarget + '/.gitconfig.shared')))
    Assert-ResolverFailure { Invoke-FixtureResolver @($script:workspace) $script:options } 'MissingPrerequisite'
  }
  It 'R01/R04 RP01-T1/T2 accepts override in safe-unconfigured or already-desired context only' {
    $script:options.RequestedTemplateRef = 'main'
    $first = Invoke-FixtureResolver @($script:workspace) $script:options
    $first.TemplateRef | Should -Be 'main'
    $first.OriginalTemplateRef | Should -Be 'SharedVSCode-wt-source'
    $null = Set-FixtureLinkedRoute $script:sprintTarget $script:stableSource
    $second = Invoke-FixtureResolver @($script:workspace) $script:options
    $second.Plan.CurrentRouteState | Should -Be 'AlreadyDesired'
    $second.Profile | Should -Be 'sprint-fixture'
  }
  It 'R04 RP01-T3/T4 holds old configured transition and rejects unknown context' {
    $null = Set-FixtureLinkedRoute $script:sprintTarget $script:sprintSource
    $script:options.RequestedTemplateRef = 'main'
    Assert-ResolverFailure { Invoke-FixtureResolver @($script:workspace) $script:options } 'TransitionPlanningHeld'
    $script:options.Remove('RequestedTemplateRef')
    Fixture-Config $script:sprintTarget '--worktree' 'core.hooksPath' $script:emptyHooks
    Assert-ResolverFailure { Invoke-FixtureResolver @($script:workspace) $script:options } 'UnsafeIncludeRoute'
  }
  It 'RP02-S1/S3 accepts absent main overlay or unrelated overlay keys for BOTH stable roles' {
    foreach ($root in @($script:stableSource, $script:stableTarget)) {
      $ws = Write-FixtureWorkspace $root
      $plan = (Invoke-FixtureResolver @($ws) $script:options).Plan
      $plan.CurrentRouteState | Should -Be 'AlreadyDesired'
      $overlay = @($plan.ConfigPins | Where-Object { $_.Path.EndsWith('/config.worktree') -and $_.Path.StartsWith($root + '/') })
      $overlay.Count | Should -Be 1
      $overlay[0].Exists | Should -BeFalse
      $overlay[0].Sha256 | Should -BeNullOrEmpty
      Fixture-Config $root '--worktree' 'fixture.unrelated' 'kept'
      $again = (Invoke-FixtureResolver @($ws) $script:options).Plan
      @($again.ConfigPins | Where-Object { $_.Path -eq $overlay[0].Path })[0].Exists | Should -BeTrue
    }
  }
  It 'RP02-S2 rejects missing required stable common route for BOTH stable roles' {
    foreach ($root in @($script:stableSource, $script:stableTarget)) {
      $ws = Write-FixtureWorkspace $root
      $dir = (Invoke-FixtureGit $root @('rev-parse', '--absolute-git-dir')).Replace('\', '/')
      $null = Invoke-FixtureGit $root @('config', '--local', '--unset-all', ('includeIf.gitdir/i:' + $dir + '.path'))
      Assert-ResolverFailure { Invoke-FixtureResolver @($ws) $script:options } 'MissingPrerequisite'
    }
  }
  It 'RP02-S3 rejects conflicting/redundant relevant main overlay origins for BOTH stable roles' {
    foreach ($root in @($script:stableSource, $script:stableTarget)) {
      $ws = Write-FixtureWorkspace $root
      Fixture-Config $root '--worktree' 'core.hooksPath' ($script:stableSource + '/.githooks')
      Assert-ResolverFailure { Invoke-FixtureResolver @($ws) $script:options } 'UnsafeIncludeRoute'
    }
  }
  It 'RP02-S4 absent main overlay appearing at recheck gives ObservationChanged and batch success0 for BOTH roles' {
    foreach ($root in @($script:stableSource, $script:stableTarget)) {
      $ws = Write-FixtureWorkspace $root
      $second = Write-FixtureWorkspace $root 'main' 'Second.code-workspace'
      $dir = (Invoke-FixtureGit $root @('rev-parse', '--absolute-git-dir')).Replace('\', '/')
      $script:raceOverlay = $dir + '/config.worktree'
      $script:raceAction = { Write-FixtureText $script:raceOverlay "[fixture]`n unrelated = appeared`n" }
      Assert-ResolverFailure { Invoke-FixtureResolver @($ws, $second) $script:options } 'ObservationChanged'
    }
  }
  It 'R05 rejects original refs/profiles conflicts, cross-repo batches and Normal source-to-other-source' {
    $bad = Write-FixtureWorkspace $script:sprintTarget 'main' 'Conflict.code-workspace'
    $script:options.RequestedTemplateRef = 'main'
    Assert-ResolverFailure { Invoke-FixtureResolver @($script:workspace, $bad) $script:options } 'WorkspaceConflict'
    $script:options.Remove('RequestedTemplateRef')
    $other = Write-FixtureWorkspace $script:stableTarget 'SharedVSCode-wt-source'
    Assert-ResolverFailure { Invoke-FixtureResolver @($script:workspace, $other) $script:options } 'WorkspaceConflict'
    $sourceWs = Write-FixtureWorkspace $script:sprintSource 'main'
    Assert-ResolverFailure { Invoke-FixtureResolver @($sourceWs) $script:options } 'SourceSelfSelectionRequired'
  }
  It 'R05/R09 wrong CWD is read-only for both repos and repeat plan is deterministic' {
    $before = Get-FixtureSnapshot $script:caseRoot
    Push-Location $script:stableTarget
    try {
      $one = Invoke-FixtureResolver @($script:workspace) $script:options
      $two = Invoke-FixtureResolver @($script:workspace) $script:options
    } finally { Pop-Location }
    ($one.Plan | ConvertTo-Json -Depth 20 -Compress) | Should -Be ($two.Plan | ConvertTo-Json -Depth 20 -Compress)
    (Get-FixtureSnapshot $script:caseRoot) | Should -Be $before
  }
  It 'R06 rejects provider/wildcard/traversal/ref close variants before escape' {
    foreach ($variant in @('relative.code-workspace', 'Env:HOME', ($script:sprintTarget + '/*.code-workspace'), ($script:sprintTarget + '/../escape.code-workspace'))) {
      Assert-ResolverFailure { Get-SharedVSCodeContext -WorkspaceFiles @($variant) -GitRoot $script:caseRoot } 'UnsafePath'
    }
    foreach ($value in @('../other', 'C:/other', 'source*', 'CON', 'source.')) {
      $options = @{ GitRoot = $script:caseRoot; RequestedTemplateRef = $value }
      Assert-ResolverFailure { Invoke-FixtureResolver @($script:workspace) $options } 'UnsafePath'
    }
    { Invoke-FixtureResolver @($script:workspace) @{} } | Should -Throw '*ExplicitFixtureGitRootRequired*'
  }
  It 'R06 rejects malformed extension and broken registration/native error without repair' {
    $commonDirectory = Assert-OwnedFixturePath $script:targetMainDir
    $expectedDirectory = Assert-OwnedFixturePath ($script:stableTarget + '/.git')
    if (![string]::Equals($commonDirectory, $expectedDirectory, [StringComparison]::OrdinalIgnoreCase)) { throw 'Fixture common directory identity changed' }
    $commonInfo = [IO.DirectoryInfo]::new($commonDirectory)
    if (!$commonInfo.Exists) { throw 'Fixture common directory missing' }
    $commonCreationTicks = $commonInfo.CreationTimeUtc.Ticks
    $caseMarker = Assert-OwnedFixturePath ($script:caseRoot + '/.owner')
    if ([IO.File]::ReadAllText($caseMarker) -cne $script:ownerId) { throw 'Fixture case ownership changed' }
    $commonConfig = Assert-OwnedFixturePath ($commonDirectory + '/config')
    $savedCommonConfig = [IO.File]::ReadAllBytes($commonConfig)
    try {
      Fixture-Config $script:stableTarget '--local' 'extensions.worktreeConfig' 'invalid'
      Assert-ResolverFailure { Invoke-FixtureResolver @($script:workspace) $script:options } 'NativeReadFailed'
    } finally {
      $restoreDirectory = Assert-OwnedFixturePath $script:targetMainDir
      $restoreInfo = [IO.DirectoryInfo]::new($restoreDirectory)
      if (![string]::Equals($restoreDirectory, $commonDirectory, [StringComparison]::OrdinalIgnoreCase) -or !$restoreInfo.Exists -or $restoreInfo.CreationTimeUtc.Ticks -ne $commonCreationTicks) { throw 'Fixture common directory identity changed before restore' }
      $restoreMarker = Assert-OwnedFixturePath ($script:caseRoot + '/.owner')
      if (![string]::Equals($restoreMarker, $caseMarker, [StringComparison]::OrdinalIgnoreCase) -or [IO.File]::ReadAllText($restoreMarker) -cne $script:ownerId) { throw 'Fixture case ownership changed before restore' }
      $restoreConfig = Assert-OwnedFixturePath ($restoreDirectory + '/config')
      if (![string]::Equals($restoreConfig, $commonConfig, [StringComparison]::OrdinalIgnoreCase)) { throw 'Fixture common config identity changed before restore' }
      [IO.File]::WriteAllBytes($restoreConfig, $savedCommonConfig)
    }
    $gitFilePath = Assert-OwnedFixturePath ($script:sprintTarget + '/.git')
    $expectedGitFile = Assert-OwnedFixturePath ($script:caseRoot + '/Downstream A-wt-target/.git')
    if (![string]::Equals($gitFilePath, $expectedGitFile, [StringComparison]::OrdinalIgnoreCase)) { throw 'Fixture linked gitfile path changed' }
    $gitFileMarker = Assert-OwnedFixturePath ($script:caseRoot + '/.owner')
    if ([IO.File]::ReadAllText($gitFileMarker) -cne $script:ownerId) { throw 'Fixture case ownership changed before gitfile write' }
    $gitFileInfo = [IO.FileInfo]::new($gitFilePath)
    if (!$gitFileInfo.Exists -or $null -ne $gitFileInfo.LinkTarget -or ($gitFileInfo.Attributes -band [IO.FileAttributes]::Directory)) { throw 'Fixture linked gitfile must be an existing ordinary nonlink file' }
    $corruptGitFileBytes = [Text.UTF8Encoding]::new($false).GetBytes('gitdir: ' + $script:caseRoot + '/missing-registration')
    $gitFileStream = [IO.File]::Open($gitFilePath, [IO.FileMode]::Open, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
      $gitFileStream.SetLength(0)
      $gitFileStream.Write($corruptGitFileBytes, 0, $corruptGitFileBytes.Length)
    } finally { $gitFileStream.Dispose() }
    Assert-ResolverFailure { Invoke-FixtureResolver @($script:workspace) $script:options } 'NativeReadFailed'
  }
  It 'R07 rejects injected GIT_DIR and keeps scoped non-emitting logger without implicit import' {
    $beforeWasPresent = [Environment]::GetEnvironmentVariables('Process').Contains('GIT_DIR')
    $before = [Environment]::GetEnvironmentVariable('GIT_DIR', 'Process')
    try {
      [Environment]::SetEnvironmentVariable('GIT_DIR', ($script:stableTarget + '/.git'), 'Process')
      Assert-ResolverFailure { Invoke-FixtureResolver @($script:workspace) $script:options } 'InvalidInput'
      [Environment]::GetEnvironmentVariable('GIT_DIR', 'Process') | Should -Be ($script:stableTarget + '/.git')
    } finally {
      if ($beforeWasPresent) {
        [Environment]::SetEnvironmentVariable('GIT_DIR', $before, 'Process')
      } else {
        [Environment]::SetEnvironmentVariable('GIT_DIR', [NullString]::Value, 'Process')
      }
    }
    (Get-Command Write-PSFMessage -ListImported).CommandType | Should -Be 'Function'
  }
  It 'RR04 logger continuing errors and throws at initial or recheck boundary emit zero batch success' {
    $second = Write-FixtureWorkspace $script:sprintTarget 'SharedVSCode-wt-source' 'Second.code-workspace' 'sprint-fixture'
    $callerPreference = $ErrorActionPreference
    $globalPreference = $global:ErrorActionPreference
    try {
      foreach ($stage in @('Validating Normal read-only context', 'Rechecking read-only context')) {
        foreach ($kind in @('Nonterminating', 'Throw')) {
          $script:loggerFailureStage = $stage
          $script:loggerFailureKind = $kind
          & {
            # A child scope models an ordinary continuing caller. Neither the
            # resolver nor the test changes script/global preference values.
            $ErrorActionPreference = 'Continue'
            Assert-ResolverFailure { Invoke-FixtureResolver @($script:workspace, $second) $script:options } 'InvalidInput'
            $ErrorActionPreference | Should -Be 'Continue'
          }
          $ErrorActionPreference | Should -Be $callerPreference
          $global:ErrorActionPreference | Should -Be $globalPreference
        }
      }
    } finally {
      $script:loggerFailureStage = $null
      $script:loggerFailureKind = $null
    }
    @(Invoke-FixtureResolver @($script:workspace, $second) $script:options).Count | Should -Be 2
  }
  It 'R08 cleanup rejects run root/sibling/traversal/unmarked paths; exact owned child alone is disposable' {
    foreach ($path in @($script:runRoot, ($script:runRoot + '-neighbor'), ($script:caseRoot + '/../other'), ($script:caseRoot + '/unmarked'))) {
      { Remove-OwnedFixtureChild $path } | Should -Throw
    }
    $owned = $script:caseRoot + '/cleanup-positive'
    Write-FixtureText ($owned + '/.owner') $script:ownerId
    Write-FixtureText ($owned + '/data.txt') 'disposable owned fixture child'
    Remove-OwnedFixtureChild $owned
    [IO.Directory]::Exists($owned) | Should -BeFalse
    [IO.Directory]::Exists($script:caseRoot) | Should -BeTrue
  }
  It 'R09 RP01-B1/B2 workspace and destination races leave whole-batch success stream EMPTY' {
    $second = Write-FixtureWorkspace $script:sprintTarget 'SharedVSCode-wt-source' 'Second.code-workspace' 'sprint-fixture'
    $script:raceFile = $second
    $script:raceAction = { Write-FixtureText $script:raceFile '{"settings":{}}' }
    Assert-ResolverFailure { Invoke-FixtureResolver @($script:workspace, $second) $script:options } 'ObservationChanged'
    $second = Write-FixtureWorkspace $script:sprintTarget 'SharedVSCode-wt-source' 'Second.code-workspace' 'sprint-fixture'
    $script:raceFile = $script:sprintTarget + '/.gitconfig.shared'
    $script:raceAction = { Write-FixtureText $script:raceFile 'appeared between snapshots' }
    Assert-ResolverFailure { Invoke-FixtureResolver @($script:workspace, $second) $script:options } 'ObservationChanged'
  }
  It 'R04 rejects duplicate active routes and canonical transitive includes without following unknown ownership' {
    $dir = Set-FixtureLinkedRoute $script:sprintTarget $script:sprintSource
    $key = 'includeIf.gitdir/i:' + $dir + '.path'
    $null = Invoke-FixtureGit $script:sprintTarget @('config', '--worktree', '--add', $key, ($script:sprintTarget + '/.gitconfig.shared'))
    Assert-ResolverFailure { Invoke-FixtureResolver @($script:workspace) $script:options } 'UnsafeIncludeRoute'
    $null = Invoke-FixtureGit $script:sprintTarget @('config', '--worktree', '--unset-all', $key)
    Fixture-Config $script:sprintTarget '--worktree' $key ($script:sprintTarget + '/.gitconfig.shared')
    $extraConfig = $script:caseRoot + '/extra.config'
    Write-FixtureText $extraConfig "[alias]`n fixture = status`n"
    $original = [IO.File]::ReadAllText($script:sprintSource + '/.gitconfig')
    Write-FixtureText ($script:sprintSource + '/.gitconfig') ($original + "[include]`n path = $extraConfig`n")
    Write-FixtureRender $script:sprintTarget $script:sprintSource
    Assert-ResolverFailure { Invoke-FixtureResolver @($script:workspace) $script:options } 'UnsafeIncludeRoute'
  }
  It 'R06 requires every canonical file and hooks directory, not a generated target substitute' {
    foreach ($relative in @('.gitconfig', '.gitattributes', 'GitTemplates/git.commit.template.txt')) {
      $path = $script:sprintSource + '/' + $relative
      $saved = [IO.File]::ReadAllText($path)
      [IO.File]::Delete((Assert-OwnedFixturePath $path))
      Assert-ResolverFailure { Invoke-FixtureResolver @($script:workspace) $script:options } 'MissingPrerequisite'
      Write-FixtureText $path $saved
    }
    Write-FixtureText ($script:sprintSource + '/.githooks/.owner') $script:ownerId
    Remove-OwnedFixtureChild ($script:sprintSource + '/.githooks')
    Assert-ResolverFailure { Invoke-FixtureResolver @($script:workspace) $script:options } 'MissingPrerequisite'
  }
  It 'R05 rejects a lookalike selected-source repository despite safe asset filenames' {
    $impostor = $script:caseRoot + '/SharedVSCode-lookalike'
    New-FixtureRepository $impostor
    New-FixtureAssets $impostor
    $script:options.RequestedTemplateRef = 'SharedVSCode-lookalike'
    Assert-ResolverFailure { Invoke-FixtureResolver @($script:workspace) $script:options } 'SourceAuthorityMismatch'
  }
  It 'RP02-S2 required common FILE absence cannot use optional-main-overlay exception for BOTH roles' {
    foreach ($root in @($script:stableSource, $script:stableTarget)) {
      $ws = Write-FixtureWorkspace $root
      $dir = (Invoke-FixtureGit $root @('rev-parse', '--absolute-git-dir')).Replace('\', '/')
      $configPath = Assert-OwnedFixturePath ($dir + '/config')
      $saved = [IO.File]::ReadAllBytes($configPath)
      try {
        [IO.File]::Delete($configPath)
        Assert-ResolverFailure { Invoke-FixtureResolver @($ws) $script:options } 'MissingPrerequisite'
      } finally { [IO.File]::WriteAllBytes($configPath, $saved) }
    }
  }
  It 'R06/RR03 parser oracle preserves single/multiple records and rejects malformed terminal/interior markers' {
    $raw = Invoke-FixtureGit $script:sprintTarget @('worktree', 'list', '--porcelain', '-z')
    $control = Invoke-ReadParserOracle -Kind Identity -Raw $raw
    $control.TopLevel | Should -Be $script:sprintTarget
    $control.IsLinkedWorktree | Should -BeTrue
    $control.Records.Count | Should -Be 2
    $singleRaw = 'worktree ' + $script:stableTarget + [char]0 + 'HEAD ' + ('0' * 40) + [char]0 + 'branch refs/heads/main' + [char]0 + [char]0
    $single = Invoke-ReadParserOracle -Kind Identity -Raw $singleRaw -MainIdentity
    $single.TopLevel | Should -Be $script:stableTarget
    $single.IsLinkedWorktree | Should -BeFalse
    $single.Records.Count | Should -Be 1
    Assert-ResolverFailure { Invoke-ReadParserOracle -Kind Identity -Raw $raw -Inside 'false' } 'InvalidTargetIdentity'
    Assert-ResolverFailure { Invoke-ReadParserOracle -Kind Identity -Raw $raw -MultipleTop } 'AmbiguousIdentity'
    Assert-ResolverFailure { Invoke-ReadParserOracle -Kind Identity -Raw '' } 'AmbiguousIdentity'
    Assert-ResolverFailure { Invoke-ReadParserOracle -Kind Identity -Raw ($raw.Substring(0, $raw.Length - 1)) } 'AmbiguousIdentity'
    Assert-ResolverFailure { Invoke-ReadParserOracle -Kind Identity -Raw ($raw.TrimEnd([char]0)) } 'AmbiguousIdentity'
    Assert-ResolverFailure { Invoke-ReadParserOracle -Kind Identity -Raw ($raw + [char]0) } 'AmbiguousIdentity'
    $recordSeparator = $raw.IndexOf(([string][char]0 + [char]0))
    if ($recordSeparator -lt 0) { throw 'Fixture frame lacks an inter-record empty-record marker' }
    $extraInteriorMarker = $raw.Insert($recordSeparator + 2, [char]0)
    Assert-ResolverFailure { Invoke-ReadParserOracle -Kind Identity -Raw $extraInteriorMarker } 'AmbiguousIdentity'
    Assert-ResolverFailure { Invoke-ReadParserOracle -Kind Identity -Raw ($raw + $raw) } 'AmbiguousIdentity'
  }
  It 'R04/R06 parser-only oracle rejects malformed NUL records, unknown scope and duplicate HEAD fields' {
    $common = (Invoke-FixtureGit $script:sprintTarget @('rev-parse', '--path-format=absolute', '--git-common-dir')).Replace('\', '/')
    $valid = 'local' + [char]0 + 'file:' + $common + '/config' + [char]0 + 'extensions.worktreeconfig' + [char]10 + 'true' + [char]0
    $rows = @(Invoke-ReadParserOracle -Kind Config -Raw $valid)
    $rows.Count | Should -Be 1
    $relative = 'local' + [char]0 + 'file:.git/config' + [char]0 + 'extensions.worktreeconfig' + [char]10 + 'true' + [char]0
    Push-Location $script:sprintSource
    try {
      $relativeRows = @(Invoke-ReadParserOracle -Kind Config -Raw $relative -ConfigRoot $script:stableTarget)
      $relativeRows.Count | Should -Be 1
      $relativeRows[0].OriginPath | Should -Be ($script:targetMainDir + '/config')
    } finally { Pop-Location }
    $invalidRelative = 'local' + [char]0 + 'file:../outside.config' + [char]0 + 'extensions.worktreeconfig' + [char]10 + 'true' + [char]0
    Assert-ResolverFailure { Invoke-ReadParserOracle -Kind Config -Raw $invalidRelative -ConfigRoot $script:stableTarget } 'UnsafePath'
    Assert-ResolverFailure { Invoke-ReadParserOracle -Kind Config -Raw ($valid.TrimEnd([char]0)) } 'NativeReadFailed'
    Assert-ResolverFailure { Invoke-ReadParserOracle -Kind Config -Raw ('global' + $valid.Substring(5)) } 'UnsafeIncludeRoute'
    $raw = Invoke-FixtureGit $script:sprintTarget @('worktree', 'list', '--porcelain', '-z')
    $boundary = $raw.IndexOf([char]0) + 1
    $duplicate = $raw.Insert($boundary, ('HEAD ' + ('0' * 40) + [char]0))
    Assert-ResolverFailure { Invoke-ReadParserOracle -Kind Identity -Raw $duplicate } 'AmbiguousIdentity'
  }
}
