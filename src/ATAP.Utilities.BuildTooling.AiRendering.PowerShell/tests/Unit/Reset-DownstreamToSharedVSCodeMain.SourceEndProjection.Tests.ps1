# Source-only test handoff. No test execution is admitted by this file.
# Future execution requires a distinct hermetic native-Git fixture admission.
BeforeAll {
  $script:repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
  $script:fixtureBase = Join-Path $script:repositoryRoot '_generated/Sprint0017/17.66/G2ResetTestSource01/Fixtures'
  $script:sourcePath = Join-Path $PSScriptRoot '../../public/Reset-DownstreamToSharedVSCodeMain.ps1'
  . $script:sourcePath
  function Write-PSFMessage { param($FunctionName, $ModuleName, $Level, $Message) }
  function Set-WorkspaceSharedVSCodeReference { [CmdletBinding()]param($WorkspaceFiles, $TemplateRef, $Profile); throw 'Unexpected workspace setter.' }
  function Set-DownstreamSharedVSCodeContext { [CmdletBinding()]param($WorkspaceFiles, $GitRoot, $SharedVSCodeRepoName, $SharedHooksSubPath, $CommitTemplateRelativePath); throw 'Unexpected generic writer.' }
  function Get-SharedVSCodeContext {
    [CmdletBinding()]param($WorkspaceFiles, $GitRoot, $SharedVSCodeRepoName, $SharedHooksSubPath, $CommitTemplateRelativePath, $ContextMode, $ExpectedSourceRoot, $ProjectionAuthority)
    throw 'Unmocked resolver is forbidden.'
  }
  function Invoke-CaseGit {
    param(
      [Parameter(Mandatory, Position = 0, ValueFromRemainingArguments = $true)]
      [ValidateNotNullOrEmpty()]
      [string[]]$Arguments
    )
    # Advanced functions can see an ancestor's $args; only this invocation owns leftovers.
    $boundArguments = [string[]]@(foreach ($token in $Arguments) { [string]::new($token.ToCharArray()) })
    $invocationUnbound = @($MyInvocation.UnboundArguments)
    $unboundArguments = [string[]]@(foreach ($token in $invocationUnbound) { if ($token -is [string]) { [string]::new($token.ToCharArray()) } })
    $unboundArgumentTypes = [string[]]@(foreach ($token in $invocationUnbound) { if ($null -eq $token) { 'NULL' } else { $token.GetType().FullName } })
    $intendedArguments = @($boundArguments) + @($unboundArguments)
    $caseRoot = [IO.Path]::GetFullPath($script:caseRoot)
    $fixtureBase = [IO.Path]::GetFullPath($script:fixtureBase)
    if (-not $caseRoot.StartsWith(($fixtureBase + [IO.Path]::DirectorySeparatorChar), [StringComparison]::OrdinalIgnoreCase) -or
      [IO.Path]::GetDirectoryName($caseRoot) -ine $fixtureBase -or
      [IO.Path]::GetFileName($caseRoot) -cnotmatch '^[0-9a-f]{32}$') { throw 'Git diagnostics require the fresh generated case root.' }
    $cursor = $caseRoot
    while ($cursor) {
      $item = Get-Item -LiteralPath $cursor -Force -ErrorAction Stop
      if ($item.LinkType -or $item.LinkTarget) { throw 'Git fixture ancestor is a filesystem link.' }
      $cursor = [IO.Path]::GetDirectoryName($cursor)
    }
    $ownerPath = Join-Path $caseRoot '.fixture-owner'
    $ownerItem = Get-Item -LiteralPath $ownerPath -Force -ErrorAction Stop
    if ($ownerItem.PSIsContainer -or $ownerItem.LinkType -or $ownerItem.LinkTarget) { throw 'Git fixture owner is not a regular file.' }
    $owner = [IO.File]::ReadAllText($ownerPath)
    if ($owner -cnotmatch '^[0-9a-f]{32}$') { throw 'Git fixture owner marker is invalid.' }
    $invocationId = [guid]::NewGuid().ToString('N')
    function Save-CaseGitDiagnostic([string]$Suffix, [object]$Value) {
      if ([IO.File]::ReadAllText($ownerPath) -cne $owner) { throw 'Git fixture owner changed.' }
      $path = Join-Path $caseRoot ('GitInvocation.' + $invocationId + '.' + $Suffix + '.json')
      # Serialize only this fixed primitive schema, never inherited objects or ETS graphs.
      $payload = [ordered]@{}
      foreach ($name in @('InvocationId', 'CaseRoot', 'ArgumentEvidence', 'GitPath', 'ExpectedGitPath', 'ExpectedGitSHA256', 'ActualGitSHA256', 'TargetPath', 'PowerShellLocation', 'ProcessCurrentDirectory', 'NativeWorkingDirectory', 'NativePIDStatus', 'SeparateStderrStatus', 'Status')) {
        $field = $Value[$name]
        if ($null -ne $field -and $field -isnot [string]) { throw 'Git diagnostic string field is not primitive.' }
        $payload[$name] = if ($null -eq $field) { $null } else { [string]::new($field.ToCharArray()) }
      }
      foreach ($name in @('IntendedArguments', 'BoundArguments', 'UnboundArguments', 'UnboundArgumentTypes', 'MergedOutput', 'EnvironmentPresence')) {
        $payload[$name] = [string[]]@(foreach ($field in $Value[$name]) {
          if ($field -isnot [string]) { throw 'Git diagnostic token is not a string.' }
          [string]::new($field.ToCharArray())
        })
      }
      $payload.UnboundArgumentCount = [int]$Value.UnboundArgumentCount
      $payload.ExpectedGitLength = [long]$Value.ExpectedGitLength
      $payload.ActualGitLength = if ($null -eq $Value.ActualGitLength) { $null } else { [long]$Value.ActualGitLength }
      $payload.NativeExitCode = if ($null -eq $Value.NativeExitCode) { $null } else { [int]$Value.NativeExitCode }
      foreach ($name in @('Attempted', 'CommandReturned', 'ExitCodeKnown', 'MergedOutputComplete', 'NoRetry', 'NoCleanup')) { $payload[$name] = [bool]$Value[$name] }
      $payload.NativePID = $null
      $payload.SeparateStderr = $null
      $payload.Error = if ($null -eq $Value.Error) { $null } else {
        [ordered]@{ Record = [string]$Value.Error.Record; Type = [string]$Value.Error.Type; Message = [string]$Value.Error.Message; HResult = [int]$Value.Error.HResult; ScriptStackTrace = [string]$Value.Error.ScriptStackTrace; Exception = [string]$Value.Error.Exception }
      }
      try { $bytes = [Text.UTF8Encoding]::new($false).GetBytes(($payload | ConvertTo-Json -Depth 6 -ErrorAction Stop)) }
      catch { [Console]::Error.WriteLine('Git diagnostic serialization failed; receipt NOT_PUBLISHED. ' + $_.Exception.ToString()); throw }
      $stream = [IO.FileStream]::new($path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::Read, 4096, [IO.FileOptions]::WriteThrough)
      try { $stream.Write($bytes, 0, $bytes.Length); $stream.Flush($true) } finally { $stream.Dispose() }
    }
    $evidence = [ordered]@{
      InvocationId = $invocationId; CaseRoot = $caseRoot
      IntendedArguments = $intendedArguments; BoundArguments = $boundArguments; UnboundArguments = $unboundArguments
      UnboundArgumentCount = $invocationUnbound.Count; UnboundArgumentTypes = $unboundArgumentTypes
      ArgumentEvidence = 'Current-invocation bound tokens plus string leftovers only; other leftovers have count/type only. Not an independent native argv observation.'
      GitPath = $script:gitExe; ExpectedGitPath = 'C:/Program Files/Git/cmd/git.exe'
      ExpectedGitSHA256 = '78211C7ED73988DA93A6D8A33D47EC6187F464D7EA2A9A00C182BBD7A1ECF30F'; ExpectedGitLength = 43352
      ActualGitSHA256 = $null; ActualGitLength = $null; TargetPath = $null
      PowerShellLocation = $null; ProcessCurrentDirectory = $null; NativeWorkingDirectory = 'UNKNOWN_NOT_OBSERVED'
      NativePID = $null; NativePIDStatus = 'NOT_OBSERVED'
      Attempted = $false; CommandReturned = $false; NativeExitCode = $null; ExitCodeKnown = $false
      MergedOutput = @(); MergedOutputComplete = $false; EnvironmentPresence = @()
      SeparateStderr = $null; SeparateStderrStatus = 'UNAVAILABLE_MERGED_WITH_STDOUT'
      Status = 'VALIDATING'; Error = $null; NoRetry = $true; NoCleanup = $true
    }
    $mergedOutput = [Collections.Generic.List[string]]::new()
    try {
      if ($invocationUnbound.Count -ne 0) { throw 'Git argument tokens remained unbound.' }
      $stable = [IO.Path]::GetFullPath((Join-Path $caseRoot 'Stable'))
      $outgoing = [IO.Path]::GetFullPath((Join-Path $caseRoot 'Outgoing'))
      if ($Arguments[0] -ceq 'init') {
        if ($Arguments.Count -ne 6 -or $Arguments[1] -cne '--template' -or $Arguments[3] -cne '-b' -or $Arguments[4] -cne 'main' -or
          -not [IO.Path]::IsPathFullyQualified($Arguments[2]) -or -not [IO.Path]::IsPathFullyQualified($Arguments[5]) -or
          [IO.Path]::GetFullPath($Arguments[2]) -ine (Join-Path $caseRoot 'EmptyTemplate') -or
          [IO.Path]::GetFullPath($Arguments[5]) -ine $stable) { throw 'Git init requires the exact generated template and Stable target.' }
        $evidence.TargetPath = $stable
      }
      elseif ($Arguments[0] -ceq '-C') {
        if ($Arguments.Count -lt 3 -or -not [IO.Path]::IsPathFullyQualified($Arguments[1])) { throw 'Git -C requires an explicit generated repository path.' }
        $targetPath = [IO.Path]::GetFullPath($Arguments[1])
        if ($targetPath -ine $stable -and $targetPath -ine $outgoing) { throw 'Git -C escaped the generated Stable/Outgoing case targets.' }
        if ($Arguments[2] -cnotin @('add', '-c', 'config', 'worktree', 'rev-parse')) { throw 'Unexpected fixture Git operation.' }
        if ($Arguments[2] -ceq 'worktree' -and ($Arguments.Count -ne 7 -or $Arguments[3] -cne 'add' -or $Arguments[4] -cne '-b' -or $Arguments[5] -cne 'fixture-source' -or
          -not [IO.Path]::IsPathFullyQualified($Arguments[6]) -or [IO.Path]::GetFullPath($Arguments[6]) -ine $outgoing)) { throw 'Git worktree requires the exact generated Outgoing target.' }
        $evidence.TargetPath = $targetPath
      }
      else { throw 'Git fixture requires explicit init target or -C; no cwd-dependent invocation.' }
      $gitPath = [IO.Path]::GetFullPath($script:gitExe)
      if ($gitPath -ine [IO.Path]::GetFullPath($evidence.ExpectedGitPath)) { throw 'Git executable differs from the fixture pin.' }
      $evidence.ActualGitSHA256 = (Get-FileHash -LiteralPath $gitPath -Algorithm SHA256).Hash
      $evidence.ActualGitLength = (Get-Item -LiteralPath $gitPath -Force).Length
      if ($evidence.ActualGitSHA256 -cne $evidence.ExpectedGitSHA256 -or $evidence.ActualGitLength -ne $evidence.ExpectedGitLength) { throw 'Git executable bytes differ from the fixture pin.' }
      $evidence.PowerShellLocation = $PWD.Path
      $evidence.ProcessCurrentDirectory = [Environment]::CurrentDirectory
      # Names, presence and lengths only; never values.
      $presenceNames = [Collections.Generic.SortedSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
      foreach ($key in @([Environment]::GetEnvironmentVariables('Process').Keys)) { if ([string]$key -like 'GIT_*') { [void]$presenceNames.Add([string]$key) } }
      foreach ($key in @('HOME', 'USERPROFILE', 'XDG_CONFIG_HOME', 'TEMP', 'TMP')) { [void]$presenceNames.Add($key) }
      $evidence.EnvironmentPresence = [string[]]@(foreach ($key in $presenceNames) {
        $value = [Environment]::GetEnvironmentVariable($key, 'Process')
        if ($null -eq $value) { $key + '|False|' } else { $key + '|True|' + $value.Length }
      })
      $evidence.Status = 'INTENT'
      Save-CaseGitDiagnostic 'Intent' $evidence
      if ([IO.File]::ReadAllText($ownerPath) -cne $owner) { throw 'Git fixture owner changed before native invocation.' }
      $evidence.Attempted = $true
      & $script:gitExe @Arguments 2>&1 | ForEach-Object { $mergedOutput.Add([string]$_) }
      $evidence.NativeExitCode = $LASTEXITCODE
      $evidence.ExitCodeKnown = $null -ne $LASTEXITCODE
      $evidence.CommandReturned = $true
      $evidence.MergedOutput = $mergedOutput.ToArray()
      $evidence.MergedOutputComplete = $true
      $evidence.Status = if ($evidence.ExitCodeKnown -and $evidence.NativeExitCode -eq 0) { 'NATIVE_RETURNED_ZERO' } else { 'NATIVE_RETURNED_NONZERO_OR_UNKNOWN' }
      Save-CaseGitDiagnostic 'Outcome' $evidence
      if (-not $evidence.ExitCodeKnown -or $evidence.NativeExitCode -ne 0) { throw 'Synthetic fixture Git boundary failed; retain exact invocation diagnostics.' }
      return ($mergedOutput.ToArray() -join [char]10)
    }
    catch {
      $originalFailure = $_
      $evidence.MergedOutput = $mergedOutput.ToArray()
      $evidence.Status = 'FAILED'
      $evidence.Error = [ordered]@{
        Record = $originalFailure.ToString(); Type = $originalFailure.Exception.GetType().FullName
        Message = $originalFailure.Exception.Message; HResult = $originalFailure.Exception.HResult
        ScriptStackTrace = $originalFailure.ScriptStackTrace; Exception = $originalFailure.Exception.ToString()
      }
      try { Save-CaseGitDiagnostic 'Failure' $evidence }
      catch { [Console]::Error.WriteLine('Git diagnostic receipt unavailable; original failure remains nonacceptance. ' + $_.Exception.ToString()) }
      throw $originalFailure
    }
  }
  function New-CasePin([string]$Path) {
    $exists = [IO.File]::Exists($Path)
    return [pscustomobject]@{
      Path = [IO.Path]::GetFullPath($Path); Exists = $exists; Existence = $exists
      SHA256 = $(if ($exists) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash } else { $null })
      Length = $(if ($exists) { (Get-Item -LiteralPath $Path -Force).Length } else { $null })
    }
  }
  function New-CaseTree([string]$Path) {
    return [pscustomobject]@{
      Path = [IO.Path]::GetFullPath($Path); Exists = $true
      Files = @(Get-ChildItem -LiteralPath $Path -File -Recurse | ForEach-Object { New-CasePin $_.FullName } | Sort-Object Path)
      Directories = @(Get-ChildItem -LiteralPath $Path -Directory -Recurse | Sort-Object FullName | ForEach-Object { [pscustomobject]@{ Path = $_.FullName } })
    }
  }
  function Get-CaseContext {
    # Return a fresh copy: refresh ONLY the mutable target pin after the effect.
    $context = $script:caseContext | ConvertTo-Json -Depth 40 | ConvertFrom-Json -Depth 40
    $context.EffectiveGitContext.Plan.ConfigPins[0] = New-CasePin $script:configPath
    return $context
  }
}

Describe 'Reset source projection G2 SE01-SE04 (fixture admission required)' {
  BeforeEach {
    $script:savedGitEnvironment = @{}
    $script:savedGitPresence = @{}
    foreach ($name in @('GIT_CONFIG_NOSYSTEM', 'GIT_CONFIG_GLOBAL', 'GIT_CONFIG_SYSTEM', 'GIT_CONFIG_COUNT', 'GIT_CONFIG_PARAMETERS', 'GIT_CONFIG', 'GIT_DIR', 'GIT_WORK_TREE', 'GIT_COMMON_DIR', 'GIT_INDEX_FILE', 'GIT_OBJECT_DIRECTORY', 'GIT_ALTERNATE_OBJECT_DIRECTORIES', 'GIT_TEMPLATE_DIR')) {
      $script:savedGitPresence[$name] = [Environment]::GetEnvironmentVariables('Process').Contains($name)
      $script:savedGitEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
      # Untyped $null becomes String.Empty (present-empty); typed NullString deletes the variable.
      [Environment]::SetEnvironmentVariable($name, [NullString]::Value, 'Process')
    }
    $script:gitExe = (Get-Command git -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
    $script:caseRoot = Join-Path $script:fixtureBase ([guid]::NewGuid().ToString('N'))
    if (-not $script:caseRoot.StartsWith(([IO.Path]::GetFullPath($script:fixtureBase) + [IO.Path]::DirectorySeparatorChar), [StringComparison]::OrdinalIgnoreCase)) { throw 'Fixture containment failed.' }
    $ancestor = $script:fixtureBase
    while ($ancestor) {
      $item = Get-Item -LiteralPath $ancestor -Force -ErrorAction SilentlyContinue
      if ($item -and ($item.LinkType -or $item.LinkTarget)) { throw 'Fixture ancestor is a filesystem link.' }
      $ancestor = [IO.Path]::GetDirectoryName($ancestor)
    }
    if (Test-Path -LiteralPath $script:caseRoot) { throw 'Fixture already exists; never reuse.' }
    [void][IO.Directory]::CreateDirectory($script:caseRoot)
    $rootItem = Get-Item -LiteralPath $script:caseRoot -Force
    if ($rootItem.LinkType -or $rootItem.LinkTarget) { throw 'Fixture root is a filesystem link.' }
    $ownerStream = [IO.File]::Open((Join-Path $script:caseRoot '.fixture-owner'), [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $ownerBytes = [Text.Encoding]::ASCII.GetBytes([guid]::NewGuid().ToString('N')); $ownerStream.Write($ownerBytes, 0, $ownerBytes.Length) } finally { $ownerStream.Dispose() }
    $emptyGlobal = Join-Path $script:caseRoot 'EmptyGlobal.config'
    [IO.File]::WriteAllText($emptyGlobal, '')
    [Environment]::SetEnvironmentVariable('GIT_CONFIG_NOSYSTEM', '1', 'Process')
    [Environment]::SetEnvironmentVariable('GIT_CONFIG_GLOBAL', $emptyGlobal, 'Process')
    $script:stable = Join-Path $script:caseRoot 'Stable'
    $script:outgoing = Join-Path $script:caseRoot 'Outgoing'
    $emptyTemplate = Join-Path $script:caseRoot 'EmptyTemplate'
    [void][IO.Directory]::CreateDirectory($emptyTemplate)
    $null = Invoke-CaseGit @('init', '--template', $emptyTemplate, '-b', 'main', $script:stable)
    [IO.File]::WriteAllText((Join-Path $script:stable 'seed.txt'), 'synthetic')
    $null = Invoke-CaseGit @('-C', $script:stable, 'add', '--', 'seed.txt')
    $null = Invoke-CaseGit @('-C', $script:stable, '-c', 'user.name=G2Fixture', '-c', 'user.email=fixture@example.invalid', '-c', 'commit.gpgsign=false', 'commit', '-m', 'synthetic fixture')
    $null = Invoke-CaseGit @('-C', $script:stable, 'config', 'extensions.worktreeConfig', 'true')
    $null = Invoke-CaseGit @('-C', $script:stable, 'worktree', 'add', '-b', 'fixture-source', $script:outgoing)
    foreach ($root in @($script:stable, $script:outgoing)) {
      [void][IO.Directory]::CreateDirectory((Join-Path $root '.githooks'))
      [void][IO.Directory]::CreateDirectory((Join-Path $root 'GitTemplates'))
      [IO.File]::WriteAllText((Join-Path $root '.gitconfig'), "[user]`nname = Synthetic`n")
      [IO.File]::WriteAllText((Join-Path $root '.gitattributes'), '* text=auto')
      [IO.File]::WriteAllText((Join-Path $root '.githooks/pre-commit'), 'synthetic hook, never invoked')
      [IO.File]::WriteAllText((Join-Path $root 'GitTemplates/git.commit.template.txt'), 'synthetic template')
    }
    $script:workspace = Join-Path $script:outgoing 'fixture.code-workspace'
    [IO.File]::WriteAllText($script:workspace, '{"folders":[],"settings":{"templateRef":"fixture-source"}}')
    $gitDir = [IO.Path]::GetFullPath((Invoke-CaseGit @('-C', $script:outgoing, 'rev-parse', '--absolute-git-dir')).Trim())
    $common = [IO.Path]::GetFullPath((Join-Path $script:stable '.git'))
    $script:configPath = Join-Path $gitDir 'config.worktree'
    $script:condition = 'gitdir/i:' + $gitDir.Replace('\', '/')
    $null = Invoke-CaseGit @('-C', $script:outgoing, 'config', '--worktree', ('includeIf.' + $script:condition + '.path'), (Join-Path $script:outgoing '.gitconfig'))
    $null = Invoke-CaseGit @('-C', $script:outgoing, 'config', '--worktree', 'core.hooksPath', (Join-Path $script:outgoing '.githooks'))
    $null = Invoke-CaseGit @('-C', $script:outgoing, 'config', '--worktree', 'commit.template', (Join-Path $script:outgoing 'GitTemplates/git.commit.template.txt'))
    $assets = @((New-CasePin (Join-Path $script:stable '.gitconfig')), (New-CasePin (Join-Path $script:stable 'GitTemplates/git.commit.template.txt')), (New-CasePin (Join-Path $script:stable '.githooks/pre-commit')))
    $protected = @(
      (New-CasePin $script:workspace), (New-CasePin (Join-Path $common 'config')),
      (New-CasePin (Join-Path $script:outgoing '.git')), (New-CasePin (Join-Path $script:outgoing '.gitconfig')),
      (New-CasePin (Join-Path $script:outgoing '.gitattributes'))
    )
    $plan = [pscustomobject]@{
      Mode = 'SourceEndProjection'; ValidationStatus = 'ValidatedReadOnlyPlan'; Role = 'CanonicalSourceSprint'
      ReceiptCustodyRoot = (Join-Path $script:caseRoot 'Receipts')
      Target = [pscustomobject]@{ TopLevel = $script:outgoing; GitDir = $gitDir; CommonDir = $common; IsLinkedWorktree = $true; WorktreeConfigEnabled = $true; WorktreeConfigPath = $script:configPath }
      Route = [pscustomobject]@{ ConfigPath = $script:configPath; Condition = $script:condition; IncludeTarget = (Join-Path $script:stable '.gitconfig'); HooksTarget = (Join-Path $script:stable '.githooks'); TemplateTarget = (Join-Path $script:stable 'GitTemplates/git.commit.template.txt'); CanRenderConsumerFiles = $false }
      Workspaces = @((New-CasePin $script:workspace)); AssetPins = $assets; ProtectedPins = $protected
      ConfigPins = @((New-CasePin $script:configPath))
      DirectoryPins = @((New-CaseTree (Join-Path $script:outgoing '.githooks')), (New-CaseTree (Join-Path $script:stable '.githooks')))
    }
    $script:caseContext = [pscustomobject]@{
      WorkspaceFile = $script:workspace; TemplateRef = 'fixture-source'; Profile = 'default'
      SharedRoot = $script:outgoing; GitConfig = (Join-Path $script:outgoing '.gitconfig'); GitAttributes = (Join-Path $script:outgoing '.gitattributes')
      CommitTemplate = (Join-Path $script:outgoing 'GitTemplates/git.commit.template.txt'); HooksPath = (Join-Path $script:outgoing '.githooks')
      ContextMode = 'SourceEndProjection'; CanRenderConsumerFiles = $false; Plan = [pscustomobject]@{ Role = 'CanonicalSourceSprint' }
      EffectiveGitContext = [pscustomobject]@{ SharedRoot = $script:stable; Plan = $plan }
    }
    $script:receiptRoot = Join-Path $script:caseRoot 'Receipts'
    [void][IO.Directory]::CreateDirectory($script:receiptRoot)
    $script:parameters = @{
      WorkspaceFiles = @($script:workspace); GitRoot = $script:caseRoot; ContextMode = 'SourceEndProjection'
      ExpectedSourceRoot = $script:outgoing; ProjectionReceiptRoot = $script:receiptRoot
      ProjectionAuthority = [pscustomobject]@{ StableRoot = $script:stable; StableGitDir = $common; CommonGitDir = $common; StableAssetPins = $assets; ReceiptCustodyRoot = $script:receiptRoot }
      Confirm = $false
    }
    $script:initialConfigHash = (Get-FileHash -LiteralPath $script:configPath -Algorithm SHA256).Hash
    Mock Get-SharedVSCodeContext { Get-CaseContext }
    Mock Set-WorkspaceSharedVSCodeReference { throw 'Workspace setter must never run for source.' }
    Mock Set-DownstreamSharedVSCodeContext { throw 'Generic consumer writer must never run for source.' }
  }
  AfterEach {
    foreach ($name in $script:savedGitEnvironment.Keys) {
      if ($script:savedGitPresence[$name]) {
        [Environment]::SetEnvironmentVariable($name, $script:savedGitEnvironment[$name], 'Process')
      } else {
        [Environment]::SetEnvironmentVariable($name, [NullString]::Value, 'Process')
      }
    }
    # Retain all owned fixtures/evidence, including failures. No recursive cleanup.
  }
  It 'SE01 rejects Normal source before workspace/config effects' {
    { Reset-DownstreamToSharedVSCodeMain -WorkspaceFiles @($script:workspace) -GitRoot $script:caseRoot } | Should -Throw '*Normal source reset forbidden*'
    (Get-FileHash -LiteralPath $script:configPath -Algorithm SHA256).Hash | Should -BeExactly $script:initialConfigHash
    @(Get-ChildItem -LiteralPath $script:receiptRoot).Count | Should -Be 0
    Should -Invoke Set-WorkspaceSharedVSCodeReference -Times 0 -Exactly
    Should -Invoke Set-DownstreamSharedVSCodeContext -Times 0 -Exactly
  }
  It 'SE02 projects only managed config and preserves canonical bytes' {
    $result = Reset-DownstreamToSharedVSCodeMain @script:parameters
    $result.Disposition | Should -BeExactly 'ProjectedToStable'
    Test-Path -LiteralPath $result.ReceiptPath | Should -BeTrue
    foreach ($pin in @($script:caseContext.EffectiveGitContext.Plan.ProtectedPins) + @($script:caseContext.EffectiveGitContext.Plan.AssetPins)) {
      (Get-FileHash -LiteralPath $pin.Path -Algorithm SHA256).Hash | Should -BeExactly $pin.SHA256
    }
    Should -Invoke Set-WorkspaceSharedVSCodeReference -Times 0 -Exactly
    Should -Invoke Set-DownstreamSharedVSCodeContext -Times 0 -Exactly
  }
  It 'SE03 repeats only after revalidation and performs no second target write' {
    (Reset-DownstreamToSharedVSCodeMain @script:parameters).Disposition | Should -BeExactly 'ProjectedToStable'
    $before = Get-Item -LiteralPath $script:configPath -Force
    $hash = (Get-FileHash -LiteralPath $script:configPath -Algorithm SHA256).Hash
    $repeat = Reset-DownstreamToSharedVSCodeMain @script:parameters
    $repeat.Disposition | Should -BeExactly 'NoChange'
    (Get-FileHash -LiteralPath $script:configPath -Algorithm SHA256).Hash | Should -BeExactly $hash
    (Get-Item -LiteralPath $script:configPath -Force).LastWriteTimeUtc | Should -Be $before.LastWriteTimeUtc
    Should -Invoke Get-SharedVSCodeContext -Times 6 -Exactly
    Should -Invoke Set-WorkspaceSharedVSCodeReference -Times 0 -Exactly
    Should -Invoke Set-DownstreamSharedVSCodeContext -Times 0 -Exactly
  }
  It 'SE04 rejects missing registration before effects' {
    Mock Get-SharedVSCodeContext { throw 'MissingRegistration' }
    { Reset-DownstreamToSharedVSCodeMain @script:parameters } | Should -Throw '*MissingRegistration*'
    (Get-FileHash -LiteralPath $script:configPath -Algorithm SHA256).Hash | Should -BeExactly $script:initialConfigHash
    @(Get-ChildItem -LiteralPath $script:receiptRoot).Count | Should -Be 0
  }
  It 'SE04 holds after registration disappears following publication, without peer restoration' {
    $script:resolutionCount = 0
    Mock Get-SharedVSCodeContext {
      $script:resolutionCount++
      if ($script:resolutionCount -eq 3) {
        [IO.File]::Move((Join-Path $script:outgoing '.git'), (Join-Path $script:caseRoot 'RetainedPeerGitPointer'))
        throw 'MissingRegistrationAfterEffect'
      }
      Get-CaseContext
    }
    $result = Reset-DownstreamToSharedVSCodeMain @script:parameters
    $result.Disposition | Should -BeExactly 'HELD_RECOVERY'
    Test-Path -LiteralPath (Join-Path $script:caseRoot 'RetainedPeerGitPointer') | Should -BeTrue
    Test-Path -LiteralPath (Join-Path $script:outgoing '.git') | Should -BeFalse
    @(Get-ChildItem -LiteralPath $script:receiptRoot -Filter '*.active.json').Count | Should -Be 1
    Should -Invoke Set-WorkspaceSharedVSCodeReference -Times 0 -Exactly
    Should -Invoke Set-DownstreamSharedVSCodeContext -Times 0 -Exactly
  }

  It 'RESET-R01 holds a NoChange attempt when the second resolver observes unrelated peer bytes' {
    (Reset-DownstreamToSharedVSCodeMain @script:parameters).Disposition | Should -BeExactly 'ProjectedToStable'
    $baseline = (Get-FileHash -LiteralPath $script:configPath -Algorithm SHA256).Hash
    $script:resolutionCount = 0
    $script:peerTargetHash = $null
    Mock Get-SharedVSCodeContext {
      $script:resolutionCount++
      if ($script:resolutionCount -eq 2) {
        $peerText = @('', '[peer]', 'note = keep-second-resolver', '') -join [char]10
        [IO.File]::AppendAllText($script:configPath, $peerText)
        $script:peerTargetHash = (Get-FileHash -LiteralPath $script:configPath -Algorithm SHA256).Hash
      }
      Get-CaseContext
    }
    $result = Reset-DownstreamToSharedVSCodeMain @script:parameters

    $result.Disposition | Should -BeExactly 'HELD_RECOVERY'
    $script:resolutionCount | Should -Be 2
    $script:peerTargetHash | Should -Not -BeExactly $baseline
    (Get-FileHash -LiteralPath $script:configPath -Algorithm SHA256).Hash | Should -BeExactly $script:peerTargetHash
    @(Get-ChildItem -LiteralPath $script:receiptRoot -Filter '*.active.json').Count | Should -Be 1
    Test-Path -LiteralPath $result.ReceiptPath | Should -BeTrue
    Should -Invoke Set-WorkspaceSharedVSCodeReference -Times 0 -Exactly
    Should -Invoke Set-DownstreamSharedVSCodeContext -Times 0 -Exactly
  }

  It 'RESET-R01 preserves unrelated peer bytes appended at the third post-publication resolver' {
    $script:resolutionCount = 0
    $script:peerTargetHash = $null
    Mock Get-SharedVSCodeContext {
      $script:resolutionCount++
      if ($script:resolutionCount -eq 3) {
        $peerText = @('', '[peer]', 'note = keep-third-resolver', '') -join [char]10
        [IO.File]::AppendAllText($script:configPath, $peerText)
        $script:peerTargetHash = (Get-FileHash -LiteralPath $script:configPath -Algorithm SHA256).Hash
      }
      Get-CaseContext
    }
    $result = Reset-DownstreamToSharedVSCodeMain @script:parameters

    $result.Disposition | Should -BeExactly 'HELD_RECOVERY'
    $script:resolutionCount | Should -Be 3
    $script:peerTargetHash | Should -Not -BeNullOrEmpty
    (Get-FileHash -LiteralPath $script:configPath -Algorithm SHA256).Hash | Should -BeExactly $script:peerTargetHash
    @(Get-ChildItem -LiteralPath $script:receiptRoot -Filter '*.active.json').Count | Should -Be 1
    Test-Path -LiteralPath $result.ReceiptPath | Should -BeTrue
    Should -Invoke Set-WorkspaceSharedVSCodeReference -Times 0 -Exactly
    Should -Invoke Set-DownstreamSharedVSCodeContext -Times 0 -Exactly
  }
}
