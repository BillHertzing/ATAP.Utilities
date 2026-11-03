BeforeAll {
  # Local logger: do not replace or remove the caller's global PSFramework command.
  function Write-PSFMessage {
    [CmdletBinding()]
    param([string]$FunctionName, [string]$ModuleName, [string]$Level, [string]$Message, [string[]]$Tag)
  }
  . "$PSScriptRoot\..\..\public\Build-AgentSpecificPerRepository.ps1"
  $script:owningRepo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
  $script:fixtureAnchor = Join-Path $script:owningRepo '_generated/Sprint0017/17.9.b/AgentSpecificLF/Fixtures'
  [void][IO.Directory]::CreateDirectory($script:fixtureAnchor)
  $script:carriers = @('GEMINI.md', '.github\copilot-instructions.md')

  function Assert-AgentSpecificFixturePath {
    param([Parameter(Mandatory)][string]$Path)
    $root = [IO.Path]::GetFullPath($script:gitRoot).TrimEnd([char]92, [char]47)
    $expected = Join-Path $script:fixtureAnchor $script:fixtureOwner
    $full = [IO.Path]::GetFullPath($Path)
    if (-not [StringComparer]::OrdinalIgnoreCase.Equals($root, $expected) -or
      (-not [StringComparer]::OrdinalIgnoreCase.Equals($full, $root) -and
        -not $full.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase))) {
      throw 'Path escaped the exact owned AgentSpecific generated fixture.'
    }
    $item = Get-Item -LiteralPath $root -Force -ErrorAction Stop
    if (-not $item.PSIsContainer -or $item.LinkType -in @('Junction', 'SymbolicLink')) {
      throw 'Fixture identity or marker changed; retain evidence.'
    }
    $markerPath = Join-Path $root '.owner'
    $marker = Get-Item -LiteralPath $markerPath -Force -ErrorAction Stop
    if ($marker.PSIsContainer -or $marker.LinkType -in @('Junction', 'SymbolicLink') -or
      $marker.Length -ne [Text.UTF8Encoding]::new($false).GetByteCount($script:fixtureMarker) -or
      [IO.File]::ReadAllText($markerPath) -cne $script:fixtureMarker) {
      throw 'Fixture identity or marker changed; retain evidence.'
    }
  }

  function Save-AgentSpecificSharingRetention {
    param([System.Management.Automation.ErrorRecord]$Failure, [string]$FailedPath)
    # Match only HRESULT_FROM_WIN32(ERROR_SHARING_VIOLATION), through PS wrappers.
    $exception = $Failure.Exception
    while ($null -ne $exception -and
      -not ($exception -is [IO.IOException] -and $exception.HResult -eq -2147024864)) {
      $exception = $exception.InnerException
    }
    if ($null -eq $exception) { throw $Failure }

    # Earlier cleanup may already have removed .owner; keep provenance beside the
    # GUID run instead of recreating its marker or retrying any deletion.
    $disposition = [ordered]@{
      Task = '17.9.b'; Owner = $script:fixtureOwner; OwnerMarker = $script:fixtureMarker
      FixtureRoot = $script:gitRoot; FailedPath = $FailedPath
      Disposition = 'RETAINED_SHARING_VIOLATION'; HResult = $exception.HResult
      Error = $Failure.ToString(); RemainingContents = 'Not removed or audited'
    }
    $receiptPath = Join-Path $script:fixtureAnchor ($script:fixtureOwner + '.cleanup-retained.json')
    $stream = [IO.File]::Open($receiptPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
      $bytes = [Text.UTF8Encoding]::new($false).GetBytes(($disposition | ConvertTo-Json -Depth 4))
      $stream.Write($bytes, 0, $bytes.Length)
    }
    finally { $stream.Dispose() }
  }

  function Remove-AgentSpecificFixture {
    # Preflight without recursive traversal. Cloud ReparsePoint alone is allowed.
    Assert-AgentSpecificFixturePath -Path $script:gitRoot
    $pending = [Collections.Generic.Stack[string]]::new()
    $directories = [Collections.Generic.List[object]]::new()
    $files = [Collections.Generic.List[object]]::new()
    $pending.Push($script:gitRoot)
    while ($pending.Count -gt 0) {
      $path = $pending.Pop()
      $item = Get-Item -LiteralPath $path -Force -ErrorAction Stop
      if (-not $item.PSIsContainer -or $item.LinkType -in @('Junction', 'SymbolicLink')) {
        throw 'Fixture cleanup encountered a redirected directory; retain evidence.'
      }
      $directories.Add([pscustomobject]@{ Path = $path; CreationTicks = $item.CreationTimeUtc.Ticks })
      foreach ($child in @(Get-ChildItem -LiteralPath $path -Force -ErrorAction Stop)) {
        Assert-AgentSpecificFixturePath -Path $child.FullName
        if ($child.LinkType -in @('Junction', 'SymbolicLink')) { throw 'Fixture cleanup refuses a child link.' }
        if ($child.PSIsContainer) { $pending.Push($child.FullName) }
        else {
          $files.Add([pscustomobject]@{
              Path = $child.FullName; Length = $child.Length; WriteTicks = $child.LastWriteTimeUtc.Ticks
            })
        }
      }
    }
    Assert-AgentSpecificFixturePath -Path $script:gitRoot
    foreach ($file in @($files | Sort-Object { (Split-Path $_.Path -Leaf) -eq '.owner' })) {
      $item = Get-Item -LiteralPath $file.Path -Force -ErrorAction Stop
      if ($item.PSIsContainer -or $item.LinkType -in @('Junction', 'SymbolicLink') -or
        $item.Length -ne $file.Length -or $item.LastWriteTimeUtc.Ticks -ne $file.WriteTicks) {
        throw 'Fixture file changed during cleanup; retain remaining evidence.'
      }
      try {
        Remove-Item -LiteralPath $file.Path -Force -Confirm:$false -ErrorAction Stop
      }
      catch {
        Save-AgentSpecificSharingRetention -Failure $_ -FailedPath $file.Path
        return
      }
    }
    for ($i = $directories.Count - 1; $i -ge 0; $i--) {
      $directory = $directories[$i]
      $item = Get-Item -LiteralPath $directory.Path -Force -ErrorAction Stop
      if (-not $item.PSIsContainer -or $item.LinkType -in @('Junction', 'SymbolicLink') -or
        $item.CreationTimeUtc.Ticks -ne $directory.CreationTicks) {
        throw 'Fixture directory changed during cleanup; retain remaining evidence.'
      }
      # Nonrecursive deletion refuses unexpected new children.
      try {
        [IO.Directory]::Delete($directory.Path, $false)
      }
      catch {
        Save-AgentSpecificSharingRetention -Failure $_ -FailedPath $directory.Path
        return
      }
    }
  }

  function Assert-AgentSpecificBytes {
    param([string]$Path, [string]$Expected)
    Assert-AgentSpecificFixturePath -Path $Path
    $actual = [IO.File]::ReadAllBytes($Path)
    $wanted = [Text.UTF8Encoding]::new($false).GetBytes($Expected)
    [Convert]::ToBase64String($actual) | Should -BeExactly ([Convert]::ToBase64String($wanted))
    [IO.File]::ReadAllText($Path) | Should -Not -Match "\r"
    ($actual.Length -ge 3 -and $actual[0] -eq 0xEF -and $actual[1] -eq 0xBB -and $actual[2] -eq 0xBF) |
      Should -BeFalse
  }
}

Describe 'Build-AgentSpecificPerRepository [public]' -Tag 'Unit', 'AgentSpecificLF' {
  BeforeEach {
    $script:fixtureOwner = [guid]::NewGuid().ToString('N')
    $script:gitRoot = Join-Path $script:fixtureAnchor $script:fixtureOwner
    $script:fixtureMarker = "task=17.9.b;owner=$($script:fixtureOwner)"
    if (Test-Path -LiteralPath $script:gitRoot) { throw 'Never adopt an existing fixture run.' }
    New-Item -ItemType Directory -Path $script:gitRoot -ErrorAction Stop | Out-Null
    $stream = [IO.File]::Open((Join-Path $script:gitRoot '.owner'),
      [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
      $bytes = [Text.UTF8Encoding]::new($false).GetBytes($script:fixtureMarker)
      $stream.Write($bytes, 0, $bytes.Length)
    }
    finally { $stream.Dispose() }
    Assert-AgentSpecificFixturePath -Path $script:gitRoot

    $script:sharedSprint = New-Item -ItemType Directory -Path (Join-Path $script:gitRoot 'SharedVSCode-wt-48-Sprint-0017-work-items')
    $script:repoSprint = New-Item -ItemType Directory -Path (Join-Path $script:gitRoot 'ATAP.Utilities-wt-115-Sprint-0017-work-items')
    $script:planningSprint = New-Item -ItemType Directory -Path (Join-Path $script:gitRoot '_Planning-wt-20-Sprint-0017-work-items')
    $script:stableOnly = New-Item -ItemType Directory -Path (Join-Path $script:gitRoot 'AceCommander')
    New-Item -ItemType Directory -Path (Join-Path $script:sharedSprint '.github') | Out-Null
    $script:expectedGemini = "# Gemini Δ`n<!-- SourceId: ai.agent-specific.gemini.v1 -->`n<!-- DELTA:BEGIN -->`n  Unicode café 😀  `nCore instructions live in AGENTS.md.`n<!-- DELTA:END -->`n"
    $script:expectedCopilot = "# Copilot Δ`n<!-- SourceId: ai.agent-specific.copilot.v1 -->`n<!-- DELTA:BEGIN -->`n  Unicode café 😀  `nCore instructions live in AGENTS.md.`n<!-- DELTA:END -->`n`n"
    Set-Content -LiteralPath (Join-Path $script:sharedSprint 'GEMINI.md') -Value $script:expectedGemini -Encoding utf8 -NoNewline
    Set-Content -LiteralPath (Join-Path $script:sharedSprint '.github\copilot-instructions.md') -Value $script:expectedCopilot -Encoding utf8 -NoNewline

    $script:workspacePath = Join-Path $script:gitRoot 'OverviewSprint0017.code-workspace'
    @{
      folders = @(
        @{ path = $script:sharedSprint.Name }
        @{ path = $script:repoSprint.Name }
        @{ path = $script:planningSprint.Name }
        @{ path = $script:stableOnly.Name }
      )
      sprintEphemeral = @{ sprintNumber = '0017' }
    } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $script:workspacePath -Encoding utf8
  }

  AfterEach {
    if ($script:gitRoot) { Remove-AgentSpecificFixture }
  }

  It 'copies both agent-specific files and skips stable-only repositories' {
    $result = Build-AgentSpecificPerRepository -WorktreeRoot $script:planningSprint.FullName `
      -WorkspacePath $script:workspacePath -Confirm:$false
    $result.Success | Should -BeTrue
    foreach ($relativePath in $script:carriers) {
      $destination = Join-Path $script:repoSprint $relativePath
      Test-Path -LiteralPath $destination | Should -BeTrue
      (Get-Content -LiteralPath $destination -Raw) |
        Should -BeExactly (Get-Content -LiteralPath (Join-Path $script:sharedSprint $relativePath) -Raw)
      Test-Path -LiteralPath (Join-Path $script:stableOnly $relativePath) | Should -BeFalse
    }
    ($result.RepositoryResults | Where-Object Repository -eq $script:stableOnly.Name).Skipped | Should -BeTrue
  }

  It 'reports unchanged and preserves both hashes, bytes and mtimes on a second run' {
    (Build-AgentSpecificPerRepository -WorktreeRoot $script:planningSprint.FullName `
      -WorkspacePath $script:workspacePath -Confirm:$false).Success | Should -BeTrue
    $snapshots = foreach ($relative in $script:carriers) {
      $path = Join-Path $script:repoSprint $relative
      [IO.File]::SetLastWriteTimeUtc($path, [datetime]'2020-01-02T03:04:05Z')
      [pscustomobject]@{
        Path = $path; Hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
        Bytes = [Convert]::ToBase64String([IO.File]::ReadAllBytes($path))
        Mtime = [IO.File]::GetLastWriteTimeUtc($path)
      }
    }
    $second = Build-AgentSpecificPerRepository -WorktreeRoot $script:planningSprint.FullName `
      -WorkspacePath $script:workspacePath -Confirm:$false
    $repo = $second.RepositoryResults | Where-Object Repository -eq $script:repoSprint.Name
    @($repo.Files | Select-Object -ExpandProperty Action -Unique) | Should -Be @('unchanged')
    foreach ($before in $snapshots) {
      (Get-FileHash -LiteralPath $before.Path -Algorithm SHA256).Hash | Should -BeExactly $before.Hash
      [Convert]::ToBase64String([IO.File]::ReadAllBytes($before.Path)) | Should -BeExactly $before.Bytes
      [IO.File]::GetLastWriteTimeUtc($before.Path) | Should -Be $before.Mtime
    }
  }

  It 'rejects an agent-specific base that duplicates the shared core body' {
    Set-Content -LiteralPath (Join-Path $script:sharedSprint 'GEMINI.md') `
      -Value "<!--`nSourceId: ai.core.main-instructions.v1`n-->`n# duplicated core`n" -Encoding utf8 -NoNewline
    { Build-AgentSpecificPerRepository -WorktreeRoot $script:planningSprint.FullName `
        -WorkspacePath $script:workspacePath -Confirm:$false } | Should -Throw '*no-double-core invariant*'
  }

  It 'normalizes <Style> carrier inputs while preserving metadata, sentinels, Unicode and final LFs' -ForEach @(
    @{ Style = 'LF' }, @{ Style = 'CRLF' }, @{ Style = 'mixed-loneCR' }
  ) {
    foreach ($relative in $script:carriers) {
      $expected = if ($relative -eq 'GEMINI.md') { $script:expectedGemini } else { $script:expectedCopilot }
      $inputText = switch ($Style) {
        'LF' { $expected }
        'CRLF' { $expected.Replace("`n", "`r`n") }
        'mixed-loneCR' {
          # Keep every original line break; alternate lone CR, CRLF and LF.
          $parts = $expected.Split("`n")
          $builder = [Text.StringBuilder]::new()
          for ($i = 0; $i -lt $parts.Length; $i++) {
            [void]$builder.Append($parts[$i])
            if ($i -lt $parts.Length - 1) {
              [void]$builder.Append(@("`r", "`r`n", "`n")[$i % 3])
            }
          }
          $builder.ToString()
        }
      }
      [IO.File]::WriteAllText((Join-Path $script:sharedSprint $relative), $inputText, [Text.UTF8Encoding]::new($false))
    }
    $result = Build-AgentSpecificPerRepository -WorktreeRoot $script:planningSprint.FullName `
      -WorkspacePath $script:workspacePath -Confirm:$false
    $result.Success | Should -BeTrue
    foreach ($repository in @($script:sharedSprint, $script:repoSprint, $script:planningSprint)) {
      Assert-AgentSpecificBytes -Path (Join-Path $repository 'GEMINI.md') -Expected $script:expectedGemini
      Assert-AgentSpecificBytes -Path (Join-Path $repository '.github\copilot-instructions.md') -Expected $script:expectedCopilot
    }
  }

  It 'repairs old CRLF destinations from LF bases then becomes unchanged' {
    (Build-AgentSpecificPerRepository -WorktreeRoot $script:planningSprint.FullName `
      -WorkspacePath $script:workspacePath -Confirm:$false).Success | Should -BeTrue
    foreach ($relative in $script:carriers) {
      $expected = if ($relative -eq 'GEMINI.md') { $script:expectedGemini } else { $script:expectedCopilot }
      [IO.File]::WriteAllText((Join-Path $script:repoSprint $relative),
        $expected.Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))
    }
    $repair = Build-AgentSpecificPerRepository -WorktreeRoot $script:planningSprint.FullName `
      -WorkspacePath $script:workspacePath -Confirm:$false
    $files = ($repair.RepositoryResults | Where-Object Repository -eq $script:repoSprint.Name).Files
    @($files.Action | Select-Object -Unique) | Should -Be @('written')
    Assert-AgentSpecificBytes -Path (Join-Path $script:repoSprint 'GEMINI.md') -Expected $script:expectedGemini
    Assert-AgentSpecificBytes -Path (Join-Path $script:repoSprint '.github\copilot-instructions.md') -Expected $script:expectedCopilot
    $repeat = Build-AgentSpecificPerRepository -WorktreeRoot $script:planningSprint.FullName `
      -WorkspacePath $script:workspacePath -Confirm:$false
    @((($repeat.RepositoryResults | Where-Object Repository -eq $script:repoSprint.Name).Files).Action |
      Select-Object -Unique) | Should -Be @('unchanged')
  }

  It 'does not rewrite already-LF source self-copies or change their input bytes' {
    $before = foreach ($relative in $script:carriers) {
      $path = Join-Path $script:sharedSprint $relative
      [IO.File]::SetLastWriteTimeUtc($path, [datetime]'2020-01-02T03:04:05Z')
      [pscustomobject]@{
        Path = $path; Bytes = [Convert]::ToBase64String([IO.File]::ReadAllBytes($path))
        Mtime = [IO.File]::GetLastWriteTimeUtc($path)
      }
    }
    $result = Build-AgentSpecificPerRepository -WorktreeRoot $script:planningSprint.FullName `
      -WorkspacePath $script:workspacePath -Confirm:$false
    @((($result.RepositoryResults | Where-Object Repository -eq $script:sharedSprint.Name).Files).Action |
      Select-Object -Unique) | Should -Be @('unchanged')
    foreach ($snapshot in $before) {
      [Convert]::ToBase64String([IO.File]::ReadAllBytes($snapshot.Path)) | Should -BeExactly $snapshot.Bytes
      [IO.File]::GetLastWriteTimeUtc($snapshot.Path) | Should -Be $snapshot.Mtime
    }
  }

  It 'preserves unterminated copy content without inserting or trimming characters' {
    $expected = '# Gemini Δ with no terminating newline  '
    [IO.File]::WriteAllText((Join-Path $script:sharedSprint 'GEMINI.md'), $expected, [Text.UTF8Encoding]::new($false))
    (Build-AgentSpecificPerRepository -WorktreeRoot $script:planningSprint.FullName `
      -WorkspacePath $script:workspacePath -Confirm:$false).Success | Should -BeTrue
    Assert-AgentSpecificBytes -Path (Join-Path $script:repoSprint 'GEMINI.md') -Expected $expected
  }
}
