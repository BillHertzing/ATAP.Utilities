function Reset-DownstreamToSharedVSCodeMain {
  <#
  .SYNOPSIS
    Resets downstream context or explicitly projects source Git metadata to stable.
  .DESCRIPTION
    Classifies all workspaces before any workspace setter. Normal source reset is
    forbidden. Explicit SourceEndProjection changes only registered config.worktree,
    never canonical workspaces, sources, stable assets or common configuration.
    Preparation uses a generated candidate and immutable receipt/preimage files.
    A matching known postimage may be rolled back; uncertain/peer-diverged effects
    retain HELD_RECOVERY and their reservation. No implicit retry or teardown.
  .PARAMETER WorkspaceFiles
    Complete workspace set, validated by Get-SharedVSCodeContext.
  .PARAMETER GitRoot
    Repository parent.
  .PARAMETER SharedVSCodeRepoName
    Stable canonical repository name.
  .PARAMETER SharedHooksSubPath
    Relative canonical hooks directory.
  .PARAMETER CommitTemplateRelativePath
    Relative canonical commit template.
  .PARAMETER ContextMode
    Normal (default) or explicitly requested SourceEndProjection.
  .PARAMETER ExpectedSourceRoot
    Exact outgoing registered canonical source, required for projection.
  .PARAMETER ProjectionAuthority
    StableRoot, StableGitDir, CommonGitDir, complete StableAssetPins and stable
    ReceiptCustodyRoot matching ProjectionReceiptRoot (X069).
    Intent/evidence binding does not itself grant mutation permission.
  .PARAMETER ProjectionReceiptRoot
    Existing separately owned nonsecret sink beneath this repository _generated.
  .OUTPUTS
    Projection Mode/Disposition/ReceiptPath/Target. HELD_RECOVERY is not success.
    Normal preserves the existing downstream writer output.
  .EXAMPLE
    Reset-DownstreamToSharedVSCodeMain -WorkspaceFiles './repo.code-workspace' -WhatIf
  .NOTES
    Cooperative transaction, not a hostile-filesystem/cross-host exclusion scheme.
    Source implementation requires distinct fixture review and deployment admission.
  #>
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string[]]$WorkspaceFiles,
    [string]$GitRoot = 'C:\dropbox\whertzing\GitHub',
    [string]$SharedVSCodeRepoName = 'SharedVSCode',
    [string]$SharedHooksSubPath = '.githooks',
    [string]$CommitTemplateRelativePath = 'GitTemplates\git.commit.template.txt',
    [ValidateSet('Normal', 'SourceEndProjection')][string]$ContextMode = 'Normal',
    [string]$ExpectedSourceRoot,
    [object]$ProjectionAuthority,
    [string]$ProjectionReceiptRoot
  )
  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.AiRendering.PowerShell'
    foreach ($required in @('Write-PSFMessage', 'Get-SharedVSCodeContext')) {
      if (-not (Get-Command -Name $required -ErrorAction SilentlyContinue)) { throw "Required command unavailable: $required" }
    }
    function fullProjectionPath([string]$Path) {
      if ([string]::IsNullOrWhiteSpace($Path) -or -not [IO.Path]::IsPathFullyQualified($Path)) { throw 'Absolute projection path required.' }
      return [IO.Path]::GetFullPath($Path).TrimEnd([IO.Path]::DirectorySeparatorChar)
    }
    function sameProjectionPath([string]$Left, [string]$Right) {
      return [string]::Equals((fullProjectionPath $Left), (fullProjectionPath $Right), [StringComparison]::OrdinalIgnoreCase)
    }
    function assertProjectionPath([string]$Path, [bool]$AllowAbsent = $false) {
      $cursor = fullProjectionPath $Path
      if (-not (Test-Path -LiteralPath $cursor) -and -not $AllowAbsent) { throw 'Projection path missing.' }
      while ($cursor) {
        $item = Get-Item -LiteralPath $cursor -Force -ErrorAction SilentlyContinue
        if ($item -and ($item.LinkType -or $item.LinkTarget)) { throw 'Projection path traverses a filesystem link.' }
        $parent = [IO.Path]::GetDirectoryName($cursor)
        if ($parent -eq $cursor) { break }
        $cursor = $parent
      }
    }
    function projectionHash([byte[]]$Bytes) {
      return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes))
    }
    function projectionSnapshot([string]$Path) {
      assertProjectionPath $Path $true
      $exists = [IO.File]::Exists($Path)
      if ((Test-Path -LiteralPath $Path) -and -not $exists) { throw 'Expected regular projection file.' }
      [byte[]]$bytes = [byte[]]::new(0)
      if ($exists) { $bytes = [IO.File]::ReadAllBytes($Path) }
      return [pscustomobject]@{
        Path = (fullProjectionPath $Path); Existence = $exists
        SHA256 = $(if ($exists) { projectionHash $bytes } else { $null })
        Length = $(if ($exists) { $bytes.Length } else { $null }); Bytes = $bytes
      }
    }
    function assertProjectionPin($Pin, [bool]$AllowAbsent = $false) {
      if ($null -eq $Pin -or $Pin.Existence -isnot [bool] -or $Pin.Exists -isnot [bool] -or $Pin.Exists -ne $Pin.Existence) { throw 'Malformed projection pin/alias.' }
      if (-not $Pin.Existence -and (-not $AllowAbsent -or $null -ne $Pin.SHA256 -or $null -ne $Pin.Length)) { throw 'Absent projection prerequisite.' }
      $actual = projectionSnapshot $Pin.Path
      if ($actual.Existence -ne $Pin.Existence -or ($actual.Existence -and ($actual.SHA256 -ine $Pin.SHA256 -or $actual.Length -ne $Pin.Length))) { throw 'Projection file pin drift.' }
    }
    function assertProjectionTarget($Expected, [object[]]$ObservedContexts = @()) {
      # The expected pin comes only from the original plan or prepared candidate,
      # never from a later resolver observation of potentially peer-edited bytes.
      foreach ($context in $ObservedContexts) {
        $observedPins = @($context.EffectiveGitContext.Plan.ConfigPins | Where-Object { sameProjectionPath $_.Path $Expected.Path })
        if ($observedPins.Count -ne 1) { throw 'Projection target observation pin missing or ambiguous.' }
        $pin = $observedPins[0]
        if ($pin.Exists -isnot [bool] -or $pin.Existence -isnot [bool] -or $pin.Exists -ne $pin.Existence -or $pin.Existence -ne $Expected.Existence -or $pin.SHA256 -ine $Expected.SHA256 -or $pin.Length -ne $Expected.Length) { throw 'Projection target observation drift.' }
      }
      assertProjectionPin $Expected $true
    }
    function assertProjectionTree($Pin) {
      if ($null -eq $Pin -or $Pin.Exists -ne $true) { throw 'Projection hooks tree prerequisite missing.' }
      assertProjectionPath $Pin.Path
      if (-not [IO.Directory]::Exists($Pin.Path)) { throw 'Projection hooks root is not a directory.' }
      $files = [Collections.Generic.List[object]]::new()
      $directories = [Collections.Generic.List[string]]::new()
      $pending = [Collections.Generic.Stack[string]]::new()
      $pending.Push((fullProjectionPath $Pin.Path))
      while ($pending.Count -gt 0) {
        $directory = $pending.Pop()
        foreach ($item in @(Get-ChildItem -LiteralPath $directory -Force -ErrorAction Stop)) {
          if ($item.LinkType -or $item.LinkTarget) { throw 'Projection hooks tree contains a link.' }
          if ($item.PSIsContainer) { $directories.Add((fullProjectionPath $item.FullName)); $pending.Push($item.FullName) }
          elseif ($item -is [IO.FileInfo]) { $files.Add((projectionSnapshot $item.FullName)) }
          else { throw 'Unknown hooks tree item type.' }
        }
      }
      $expectedFiles = @($Pin.Files | Sort-Object Path)
      $actualFiles = @($files | Sort-Object Path)
      if ($actualFiles.Count -ne $expectedFiles.Count) { throw 'Projection hooks file membership changed.' }
      for ($index = 0; $index -lt $expectedFiles.Count; $index++) {
        if (-not (sameProjectionPath $actualFiles[$index].Path $expectedFiles[$index].Path) -or $actualFiles[$index].SHA256 -ine $expectedFiles[$index].SHA256 -or $actualFiles[$index].Length -ne $expectedFiles[$index].Length) { throw 'Projection hooks file changed.' }
      }
      $expectedDirectories = @($Pin.Directories | ForEach-Object { (fullProjectionPath $_.Path).ToUpperInvariant() } | Sort-Object)
      $actualDirectories = @($directories | ForEach-Object { $_.ToUpperInvariant() } | Sort-Object)
      if (($expectedDirectories -join [char]0) -cne ($actualDirectories -join [char]0)) { throw 'Projection hooks directory membership changed.' }
    }
    function saveProjectionRecord([string]$Path, $Record) {
      $bytes = [Text.UTF8Encoding]::new($false).GetBytes(($Record | ConvertTo-Json -Depth 40))
      $stream = [IO.FileStream]::new($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::Read, 4096, [IO.FileOptions]::WriteThrough)
      try { $stream.Write($bytes, 0, $bytes.Length); $stream.Flush($true) } finally { $stream.Dispose() }
    }
    function projectionGit([string[]]$Arguments, [int[]]$AllowedExit = @(0)) {
      # PowerShell drains the native pipeline; no explicit redirected-buffer wait.
      # Native exit handling is owned here; do not change the caller/global policy.
      $PSNativeCommandUseErrorActionPreference = $false
      $output = @(& $gitApplication @Arguments 2>&1)
      $code = $LASTEXITCODE
      if ($code -notin $AllowedExit) { throw "Projection Git boundary failed (exit $code)." }
      return [pscustomobject]@{ ExitCode = $code; Text = (($output | ForEach-Object { [string]$_ }) -join [char]10) }
    }
    function assertProjectionIdentity($Target) {
      foreach ($path in @($Target.TopLevel, $Target.GitDir, $Target.CommonDir)) { assertProjectionPath $path }
      $top = (projectionGit @('-C', $Target.TopLevel, 'rev-parse', '--show-toplevel')).Text.Trim()
      $dir = (projectionGit @('-C', $Target.TopLevel, 'rev-parse', '--absolute-git-dir')).Text.Trim()
      $common = (projectionGit @('-C', $Target.TopLevel, 'rev-parse', '--path-format=absolute', '--git-common-dir')).Text.Trim()
      if (-not (sameProjectionPath $top $Target.TopLevel) -or -not (sameProjectionPath $dir $Target.GitDir) -or -not (sameProjectionPath $common $Target.CommonDir)) { throw 'Projection registration identity changed.' }
      $registered = (projectionGit @('-C', $Target.TopLevel, 'worktree', 'list', '--porcelain')).Text -split [char]10
      $matches = @($registered | Where-Object { $_.StartsWith('worktree ') -and (sameProjectionPath ($_.Substring(9).Trim()) $Target.TopLevel) })
      if ($matches.Count -ne 1 -or -not (sameProjectionPath $Target.WorktreeConfigPath (Join-Path $dir 'config.worktree'))) { throw 'Projection registration/config target mismatch.' }
    }
    function getProjectionContexts {
      $arguments = @{ WorkspaceFiles = $WorkspaceFiles; GitRoot = $GitRoot; SharedVSCodeRepoName = $SharedVSCodeRepoName; SharedHooksSubPath = $SharedHooksSubPath; CommitTemplateRelativePath = $CommitTemplateRelativePath; ContextMode = $ContextMode; ErrorAction = 'Stop' }
      if ($ContextMode -eq 'SourceEndProjection') { $arguments.ExpectedSourceRoot = $ExpectedSourceRoot; $arguments.ProjectionAuthority = $ProjectionAuthority }
      return @(Get-SharedVSCodeContext @arguments)
    }
    function projectionFingerprint($Plan) {
      # Exclude only mutable target bytes, never its identity or unrelated config pins.
      return ([ordered]@{
        Mode = $Plan.Mode; Role = $Plan.Role; Target = $Plan.Target; Route = $Plan.Route
        Workspaces = @($Plan.Workspaces); AssetPins = @($Plan.AssetPins); ProtectedPins = @($Plan.ProtectedPins)
        DirectoryPins = @($Plan.DirectoryPins)
        ReceiptCustodyRoot = $Plan.ReceiptCustodyRoot
        ConfigPins = @($Plan.ConfigPins | Where-Object { -not (sameProjectionPath $_.Path $Plan.Route.ConfigPath) })
      } | ConvertTo-Json -Depth 40 -Compress)
    }
  }
  process {
    $contexts = @(getProjectionContexts)
    if ($contexts.Count -ne $WorkspaceFiles.Count) { throw 'Resolver did not validate the complete workspace set.' }
    if ($ContextMode -eq 'Normal') {
      foreach ($context in $contexts) {
        if (-not $context.Plan -or [string]::IsNullOrWhiteSpace($context.Plan.Role)) { throw 'Unclassified Normal reset refused.' }
        if ($context.Plan.Role -like 'CanonicalSource*') { throw 'Normal source reset forbidden; explicit SourceEndProjection required.' }
      }
      if ($PSCmdlet.ShouldProcess(($WorkspaceFiles -join ', '), 'Reset downstream workspace/context to main/default')) {
        foreach ($required in @('Set-WorkspaceSharedVSCodeReference', 'Set-DownstreamSharedVSCodeContext')) {
          if (-not (Get-Command -Name $required -ErrorAction SilentlyContinue)) { throw "Required command unavailable: $required" }
        }
        Set-WorkspaceSharedVSCodeReference -WorkspaceFiles $WorkspaceFiles -TemplateRef 'main' -Profile 'default'
        Set-DownstreamSharedVSCodeContext -WorkspaceFiles $WorkspaceFiles -GitRoot $GitRoot -SharedVSCodeRepoName $SharedVSCodeRepoName -SharedHooksSubPath $SharedHooksSubPath -CommitTemplateRelativePath $CommitTemplateRelativePath
      }
      return
    }
    if (-not $ProjectionAuthority -or [string]::IsNullOrWhiteSpace($ExpectedSourceRoot) -or [string]::IsNullOrWhiteSpace($ProjectionReceiptRoot)) { throw 'Explicit source/stable authority and receipt sink required.' }
    $plan = $contexts[0].EffectiveGitContext.Plan
    if (-not $plan -or $plan.Mode -cne 'SourceEndProjection' -or $plan.ValidationStatus -cne 'ValidatedReadOnlyPlan' -or $plan.Role -cne 'CanonicalSourceSprint' -or $plan.Route.CanRenderConsumerFiles -ne $false -or $contexts[0].CanRenderConsumerFiles -ne $false) { throw 'Invalid source projection plan.' }
    $fingerprint = projectionFingerprint $plan
    foreach ($context in $contexts) {
      if ((projectionFingerprint $context.EffectiveGitContext.Plan) -cne $fingerprint -or $context.CanRenderConsumerFiles -ne $false) { throw 'Workspace projection plans disagree.' }
    }
    $target = $plan.Target
    $configPath = fullProjectionPath $target.WorktreeConfigPath
    if (-not (sameProjectionPath $target.TopLevel $ExpectedSourceRoot) -or -not $target.IsLinkedWorktree -or -not $target.WorktreeConfigEnabled -or -not (sameProjectionPath $plan.Route.ConfigPath $configPath)) { throw 'Projection target identity incomplete.' }
    $stableRoot = fullProjectionPath $ProjectionAuthority.StableRoot
    if ((sameProjectionPath $stableRoot $ExpectedSourceRoot) -or -not (sameProjectionPath $ProjectionAuthority.CommonGitDir $target.CommonDir) -or -not (sameProjectionPath $ProjectionAuthority.StableGitDir $target.CommonDir)) { throw 'Stable authority is not distinct same-repository main source.' }
    foreach ($pair in @(@($contexts[0].EffectiveGitContext.SharedRoot, $stableRoot), @($plan.Route.IncludeTarget, (Join-Path $stableRoot '.gitconfig')), @($plan.Route.HooksTarget, (Join-Path $stableRoot $SharedHooksSubPath)), @($plan.Route.TemplateTarget, (Join-Path $stableRoot $CommitTemplateRelativePath)))) {
      if (-not (sameProjectionPath $pair[0] $pair[1])) { throw 'Stable route disagrees with authority.' }
    }
    if ($plan.Route.Condition -cne ('gitdir/i:' + $target.GitDir.Replace('\', '/'))) { throw 'Condition must match exact registered Git directory.' }
    $allPins = @($plan.Workspaces) + @($plan.AssetPins) + @($plan.ProtectedPins) + @($plan.ConfigPins)
    if (@($plan.Workspaces).Count -ne $WorkspaceFiles.Count -or @($plan.AssetPins).Count -eq 0 -or @($plan.ProtectedPins).Count -eq 0 -or @($plan.ConfigPins).Count -eq 0 -or @($ProjectionAuthority.StableAssetPins).Count -eq 0 -or @($plan.DirectoryPins).Count -lt 2) { throw 'Incomplete projection pin closure.' }
    foreach ($workspace in $WorkspaceFiles) {
      if (@($plan.Workspaces | Where-Object { sameProjectionPath $_.Path $workspace }).Count -ne 1) { throw 'Workspace pin set mismatch.' }
    }
    $targetPreimagePins = @($plan.ConfigPins | Where-Object { sameProjectionPath $_.Path $configPath })
    if ($targetPreimagePins.Count -ne 1) { throw 'Exact target preimage pin required.' }
    $initialTargetPin = [pscustomobject]@{
      Path = $configPath; Exists = $targetPreimagePins[0].Exists; Existence = $targetPreimagePins[0].Existence
      SHA256 = $targetPreimagePins[0].SHA256; Length = $targetPreimagePins[0].Length
    }
    $protected = @($allPins | Where-Object { -not (sameProjectionPath $_.Path $configPath) })
    foreach ($pin in $allPins) { assertProjectionPin $pin (sameProjectionPath $pin.Path $configPath) }
    foreach ($tree in $plan.DirectoryPins) { assertProjectionTree $tree }
    foreach ($pin in $ProjectionAuthority.StableAssetPins) {
      if ([string]$pin.SHA256 -notmatch '^[A-Fa-f0-9]{64}$') { throw 'Stable authority hash missing.' }
      if (@($plan.AssetPins | Where-Object { (sameProjectionPath $_.Path $pin.Path) -and $_.SHA256 -ieq $pin.SHA256 -and $_.Existence }).Count -ne 1) { throw 'Stable authority asset not present in verified plan.' }
    }
    $stableHooks = @($plan.DirectoryPins | Where-Object { sameProjectionPath $_.Path $plan.Route.HooksTarget })
    if ($stableHooks.Count -ne 1) { throw 'Stable hooks tree not pinned exactly once.' }
    if (@($plan.DirectoryPins | Where-Object { sameProjectionPath $_.Path (Join-Path $ExpectedSourceRoot $SharedHooksSubPath) }).Count -ne 1) { throw 'Outgoing source hooks tree not pinned exactly once.' }
    foreach ($path in @($plan.Route.IncludeTarget, $plan.Route.TemplateTarget)) {
      if (@($ProjectionAuthority.StableAssetPins | Where-Object { sameProjectionPath $_.Path $path }).Count -ne 1) { throw 'Stable config/template authority missing.' }
    }
    foreach ($file in $stableHooks[0].Files) {
      if (@($ProjectionAuthority.StableAssetPins | Where-Object { sameProjectionPath $_.Path $file.Path }).Count -ne 1) { throw 'Unbound stable hook authority.' }
    }
    $gitApplication = (Get-Command -Name git -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
    assertProjectionIdentity $target
    $receiptRoot = fullProjectionPath $ProjectionReceiptRoot
    if (-not (sameProjectionPath $receiptRoot $ProjectionAuthority.ReceiptCustodyRoot)) { throw 'Missing/inconsistent admitted receipt custody root.' }
    if (-not (sameProjectionPath $receiptRoot $plan.ReceiptCustodyRoot)) { throw 'Resolver receipt custody proof disagrees with invocation.' }
    $repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
    $generatedPrefix = [IO.Path]::GetFullPath((Join-Path $repositoryRoot '_generated')) + [IO.Path]::DirectorySeparatorChar
    if (-not $receiptRoot.StartsWith($generatedPrefix, [StringComparison]::OrdinalIgnoreCase) -or -not [IO.Directory]::Exists($receiptRoot)) { throw 'Receipt sink must already exist under this repository _generated.' }
    assertProjectionPath $receiptRoot
    $slotId = projectionHash ([Text.Encoding]::UTF8.GetBytes($configPath.ToUpperInvariant()))
    $reservationPath = Join-Path $receiptRoot ($slotId + '.active.json')
    if (Test-Path -LiteralPath $reservationPath) { throw 'Unreleased projection reservation; explicit recovery/custody required.' }
    $initial = projectionSnapshot $configPath
    if ($initial.Existence -ne $initialTargetPin.Existence -or $initial.SHA256 -ine $initialTargetPin.SHA256 -or $initial.Length -ne $initialTargetPin.Length) { throw 'Projection target preimage drift before preparation.' }
    if (-not $PSCmdlet.ShouldProcess($configPath, 'Project registered source Git metadata to stable')) {
      return [pscustomobject]@{ Mode = $ContextMode; Disposition = 'Planned'; ReceiptPath = $null; Target = $target; Plan = $plan }
    }
    $operationId = [guid]::NewGuid().ToString('N')
    $operationRoot = Join-Path $receiptRoot $operationId
    $reservation = @{ OperationId = $operationId; Target = $configPath; OperationRoot = $operationRoot; Mode = $ContextMode }
    saveProjectionRecord $reservationPath $reservation
    $reservationHash = projectionHash ([IO.File]::ReadAllBytes($reservationPath))
    $receiptPath = Join-Path $operationRoot 'Terminal.json'
    $handle = $null; $effectsStarted = $false; $postimageKnown = $false; $receiptFailed = $false
    $postHash = $null; $disposition = 'HELD_RECOVERY'; $failureCode = $null
    try {
      [void][IO.Directory]::CreateDirectory($operationRoot)
      if ($initial.Existence) { [IO.File]::WriteAllBytes((Join-Path $operationRoot 'Preimage.bin'), $initial.Bytes) }
      saveProjectionRecord (Join-Path $operationRoot 'Prepared.json') @{ OperationId = $operationId; Target = $target; Plan = $plan; InitialExistence = $initial.Existence; InitialSHA256 = $initial.SHA256; InitialLength = $initial.Length }
      $candidatePath = Join-Path $operationRoot 'Candidate.config'
      [IO.File]::WriteAllBytes($candidatePath, $initial.Bytes)
      $includeKey = 'includeIf.' + $plan.Route.Condition + '.path'
      $desired = [ordered]@{ $includeKey = $plan.Route.IncludeTarget; 'core.hooksPath' = $plan.Route.HooksTarget; 'commit.template' = $plan.Route.TemplateTarget }
      $includes = projectionGit @('-C', $target.TopLevel, 'config', '--file', $candidatePath, '--no-includes', '--name-only', '--get-regexp', '^include') @(0, 1)
      $includeKeys = @($includes.Text -split [char]10 | Where-Object { $_ })
      if ($includeKeys.Count -gt 1) { throw 'Duplicate/conflicting target include routes.' }
      foreach ($key in $includeKeys) {
        if ($key -ine $includeKey) { throw 'Unexpected include route in target config.' }
      }
      $alreadyMatches = $initial.Existence
      foreach ($key in $desired.Keys) {
        $value = projectionGit @('-C', $target.TopLevel, 'config', '--file', $candidatePath, '--no-includes', '--get-all', $key) @(0, 1)
        if ($value.Text.Contains([char]10)) { throw 'Duplicate or multiline managed value; refusing implicit repair.' }
        if ($value.ExitCode -ne 0 -or $value.Text -cne [string]$desired[$key]) { $alreadyMatches = $false }
      }
      $orderedKeys = (projectionGit @('-C', $target.TopLevel, 'config', '--file', $candidatePath, '--no-includes', '--name-only', '--list')).Text -split [char]10
      $positions = @(foreach ($key in $desired.Keys) {
        $matches = @(for ($index = 0; $index -lt $orderedKeys.Count; $index++) { if ($orderedKeys[$index] -ieq $key) { $index } })
        if ($matches.Count -eq 1) { $matches[0] } else { -1 }
      })
      if ($positions[0] -lt 0 -or $positions[0] -ge $positions[1] -or $positions[1] -ge $positions[2]) { $alreadyMatches = $false }
      # Only managed keys change. Appending establishes include/hooks/template order.
      foreach ($key in $desired.Keys) {
        $null = projectionGit @('-C', $target.TopLevel, 'config', '--file', $candidatePath, '--no-includes', '--unset-all', $key) @(0, 5)
        $null = projectionGit @('-C', $target.TopLevel, 'config', '--file', $candidatePath, '--no-includes', '--add', $key, [string]$desired[$key])
      }
      $candidate = [IO.File]::ReadAllBytes($candidatePath); $postHash = projectionHash $candidate
      $candidateTargetPin = [pscustomobject]@{ Path = $configPath; Exists = $true; Existence = $true; SHA256 = $postHash; Length = $candidate.Length }
      $expectedSuccessTargetPin = if ($alreadyMatches) { $initialTargetPin } else { $candidateTargetPin }
      assertProjectionIdentity $target
      foreach ($pin in $allPins) { assertProjectionPin $pin (sameProjectionPath $pin.Path $configPath) }
      foreach ($tree in $plan.DirectoryPins) { assertProjectionTree $tree }
      $fresh = @(getProjectionContexts)
      if ($fresh.Count -ne $contexts.Count) { throw 'Workspace observation changed.' }
      foreach ($context in $fresh) { if ((projectionFingerprint $context.EffectiveGitContext.Plan) -cne $fingerprint) { throw 'Projection proof drift before effect.' } }
      assertProjectionTarget $initialTargetPin $fresh
      if ($alreadyMatches) { $disposition = 'NoChange' }
      else {
        assertProjectionIdentity $target
        foreach ($pin in $protected) { assertProjectionPin $pin }
        foreach ($tree in $plan.DirectoryPins) { assertProjectionTree $tree }
        saveProjectionRecord (Join-Path $operationRoot 'BeforeEffect.json') @{ OperationId = $operationId; Target = $configPath; Preimage = $initial.SHA256; IntendedPostimage = $postHash; Length = $candidate.Length }
        $mode = if ($initial.Existence) { [IO.FileMode]::Open } else { [IO.FileMode]::CreateNew }
        $handle = [IO.FileStream]::new($configPath, $mode, [IO.FileAccess]::ReadWrite, [IO.FileShare]::Read)
        $effectsStarted = -not $initial.Existence
        $before = [byte[]]::new([int]$handle.Length); $handle.ReadExactly($before, 0, $before.Length)
        if ($initial.Existence -and (projectionHash $before) -cne $initial.SHA256) { throw 'Peer target drift before locked publication.' }
        $effectsStarted = $true
        $handle.Position = 0; $handle.SetLength(0); $handle.Write($candidate, 0, $candidate.Length); $handle.Flush($true)
        $handle.Position = 0
        $observed = [byte[]]::new([int]$handle.Length); $handle.ReadExactly($observed, 0, $observed.Length)
        if ((projectionHash $observed) -cne $postHash) { throw 'Unknown target postimage.' }
        $postimageKnown = $true
        try { saveProjectionRecord (Join-Path $operationRoot 'Postimage.json') @{ OperationId = $operationId; SHA256 = $postHash; Length = $observed.Length } } catch { $receiptFailed = $true; throw }
        # Resolver/native readers use their own sharing modes. Release the handle
        # before those reads; subsequent recovery must acquire and compare anew.
        $handle.Dispose(); $handle = $null
        $disposition = 'ProjectedToStable'
      }
      assertProjectionIdentity $target
      foreach ($pin in $protected) { assertProjectionPin $pin }
      foreach ($tree in $plan.DirectoryPins) { assertProjectionTree $tree }
      foreach ($key in $desired.Keys) {
        $effective = (projectionGit @('-C', $target.TopLevel, 'config', '--includes', '--show-origin', '--get', $key)).Text
        $parts = $effective -split [char]9, 2
        if ($parts.Count -ne 2 -or -not $parts[0].StartsWith('file:') -or -not (sameProjectionPath $parts[0].Substring(5) $configPath) -or $parts[1] -cne [string]$desired[$key]) { throw 'Effective Git value/origin not the exact projected target.' }
      }
      $postContexts = @(getProjectionContexts)
      if ($postContexts.Count -ne $contexts.Count) { throw 'Post-publication workspace count changed.' }
      foreach ($context in $postContexts) { if ((projectionFingerprint $context.EffectiveGitContext.Plan) -cne $fingerprint) { throw 'Protected proof changed after publication.' } }
      assertProjectionTarget $expectedSuccessTargetPin $postContexts
      try { saveProjectionRecord $receiptPath @{ Mode = $ContextMode; Disposition = $disposition; OperationId = $operationId; Target = $target; InitialExistence = $initial.Existence; InitialSHA256 = $initial.SHA256; PostSHA256 = $expectedSuccessTargetPin.SHA256; PostLength = $expectedSuccessTargetPin.Length; PostExistence = $expectedSuccessTargetPin.Existence; ProtectedPinsVerified = $true } } catch { $receiptFailed = $true; throw }
    } catch {
      $failureCode = $_.Exception.Message; $disposition = 'HELD_RECOVERY'
      if ($postimageKnown -and -not $receiptFailed) {
        try {
          if ($null -ne $handle) { $handle.Dispose(); $handle = $null }
          assertProjectionIdentity $target
          foreach ($pin in $protected) { assertProjectionPin $pin }
          foreach ($tree in $plan.DirectoryPins) { assertProjectionTree $tree }
          $current = projectionSnapshot $configPath
          if ($current.SHA256 -cne $postHash) { throw 'Peer target changed; rollback refused.' }
          $handle = [IO.FileStream]::new($configPath, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::Read)
          $lockedPostimage = [byte[]]::new([int]$handle.Length); $handle.ReadExactly($lockedPostimage, 0, $lockedPostimage.Length)
          if ((projectionHash $lockedPostimage) -cne $postHash) { throw 'Peer changed target before locked recovery.' }
          if ($initial.Existence) {
            $handle.Position = 0; $handle.SetLength(0); $handle.Write($initial.Bytes, 0, $initial.Bytes.Length); $handle.Flush($true)
            $handle.Dispose(); $handle = $null
          } else {
            $handle.Dispose(); $handle = $null
            # Cooperative check/delete window; never silently overwrite a divergent peer.
            $current = projectionSnapshot $configPath
            if ($current.SHA256 -cne $postHash) { throw 'Peer changed newly created target; deletion refused.' }
            [IO.File]::Delete($configPath)
          }
          assertProjectionIdentity $target
          foreach ($pin in $allPins) { assertProjectionPin $pin (sameProjectionPath $pin.Path $configPath) }
          foreach ($tree in $plan.DirectoryPins) { assertProjectionTree $tree }
          $disposition = 'RolledBackCoherent'
        } catch { $failureCode += '; RecoveryUnverified: ' + $_.Exception.Message }
      }
      try { saveProjectionRecord (Join-Path $operationRoot 'Failure.json') @{ Mode = $ContextMode; Disposition = $disposition; OperationId = $operationId; Target = $target; Failure = $failureCode; EffectsStarted = $effectsStarted; PostimageKnown = $postimageKnown; ReceiptFailed = $receiptFailed } }
      catch { $disposition = 'HELD_RECOVERY'; $failureCode += '; FailureReceiptUnavailable' }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Source projection $disposition; retain reservation and evidence: $operationRoot"
    } finally {
      if ($null -ne $handle) { $handle.Dispose() }
    }
    if ($disposition -in @('ProjectedToStable', 'NoChange')) {
      try {
        assertProjectionTarget $expectedSuccessTargetPin
        if ((projectionHash ([IO.File]::ReadAllBytes($reservationPath))) -cne $reservationHash) { throw 'Reservation ownership changed.' }
        [IO.File]::Delete($reservationPath)
      } catch {
        $disposition = 'HELD_RECOVERY'; $failureCode = 'ReservationReleaseUncertain'
        try { saveProjectionRecord (Join-Path $operationRoot 'ReleaseFailure.json') @{ Mode = $ContextMode; Disposition = $disposition; OperationId = $operationId; Failure = $failureCode; Target = $target } } catch { $failureCode += '; ReceiptUnavailable' }
      }
    }
    $resultReceipt = if ($disposition -in @('ProjectedToStable', 'NoChange')) { $receiptPath } elseif ($failureCode -like 'ReservationRelease*') { Join-Path $operationRoot 'ReleaseFailure.json' } else { Join-Path $operationRoot 'Failure.json' }
    return [pscustomobject]@{ Mode = $ContextMode; Disposition = $disposition; ReceiptPath = $resultReceipt; Target = $target; Failure = $failureCode; OperationId = $operationId }
  }
  end { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn" }
}
