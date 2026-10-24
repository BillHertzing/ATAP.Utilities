BeforeAll {
  . (Join-Path $PSScriptRoot '../../private/Get-GeneratedRemediationByteComparison.ps1')
  $script:fixtureBase = [IO.Path]::GetFullPath("$PSScriptRoot/../../../../_generated/Sprint0016/Task16.84/ByteComparisonTests-v1")
  $null = New-Item -ItemType Directory -Path $script:fixtureBase -Force
  $cursor = $script:fixtureBase
  while ($cursor) {
    $item = Get-Item -LiteralPath $cursor -Force
    if ($item.LinkType -or $item.Target) { throw 'Redirected synthetic fixture boundary.' }
    $cursor = Split-Path -Parent $cursor
  }
  $script:realGetItem = Get-Command Get-Item -CommandType Cmdlet
}
Describe 'Default-data byte comparison witness' {
  BeforeEach {
    $script:runRoot = Join-Path $script:fixtureBase ([guid]::NewGuid().ToString('N'))
    $script:stable = Join-Path $script:runRoot 'Repo'
    $script:sprint = Join-Path $script:runRoot 'Repo-wt-1-Sprint-0016-work-items'
    $script:relative = "_generated/space $([char]0xfc).bin"
    foreach ($root in @($script:stable, $script:sprint)) {
      $null = New-Item -ItemType Directory -Path (Join-Path $root '_generated') -Force
      [IO.File]::WriteAllBytes((Join-Path $root $script:relative), [byte[]]@(0, 1, 255, 0))
    }
    $script:arguments = @{ StableRoot = $script:stable; SprintRoot = $script:sprint; RepositoryName = 'Repo'; RelativePath = $script:relative }
  }
  AfterEach {
    $resolved = (Resolve-Path -LiteralPath $script:runRoot).ProviderPath
    $prefix = $script:fixtureBase.TrimEnd('\') + '\'
    if (-not $resolved.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -or
      (& $script:realGetItem -LiteralPath $resolved -Force).LinkType) { throw 'Cleanup escaped fixture boundary.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force -ErrorAction Stop
  }
  It 'returns one equal witness without approval, ADS, custody or repository-identity claims' {
    $items = @(Get-GeneratedRemediationByteComparison @arguments)
    $items.Count | Should -Be 1
    $r = $items[0]
    $r.Status | Should -Be Equal
    $r.DefaultDataEqual | Should -BeTrue
    $r.BytesCompared | Should -Be 4
    $r.StableSHA256 | Should -Be (Get-FileHash -LiteralPath (Join-Path $stable $relative)).Hash
    $r.SprintSHA256 | Should -Be $r.StableSHA256
    foreach ($flag in @('Approved', 'ReadyForRemoval', 'CustodyVerified', 'NamedStreamsVerified', 'RepositoryIdentityVerified')) {
      $r.$flag | Should -BeFalse
    }
  }
  It 'handles empty files' {
    foreach ($root in @($stable, $sprint)) { [IO.File]::WriteAllBytes((Join-Path $root $relative), [byte[]]@()) }
    $r = Get-GeneratedRemediationByteComparison @arguments
    $r.Status | Should -Be Equal
    $r.BytesCompared | Should -Be 0
    $r.StableSHA256 | Should -Be (Get-FileHash -LiteralPath (Join-Path $stable $relative)).Hash
  }
  It 'compares complete and final partial buffers and detects a final-byte mismatch' {
    $bytes = [byte[]]::new(65539)
    $bytes[65538] = 123
    foreach ($root in @($stable, $sprint)) { [IO.File]::WriteAllBytes((Join-Path $root $relative), $bytes) }
    $r = Get-GeneratedRemediationByteComparison @arguments
    $r.Status | Should -Be Equal
    $r.BytesCompared | Should -Be 65539
    $bytes[65538] = 124
    [IO.File]::WriteAllBytes((Join-Path $sprint $relative), $bytes)
    $r = Get-GeneratedRemediationByteComparison @arguments
    $r.Status | Should -Be Different
    $r.DefaultDataEqual | Should -BeFalse
    $r.BytesCompared | Should -Be 65539
  }
  It 'does not equate equal length with equal bytes' {
    [IO.File]::WriteAllBytes((Join-Path $sprint $relative), [byte[]]@(0, 2, 255, 0))
    $r = Get-GeneratedRemediationByteComparison @arguments
    $r.Status | Should -Be Different
    $r.DefaultDataEqual | Should -BeFalse
  }
  It 'distinguishes unequal lengths' {
    [IO.File]::WriteAllBytes((Join-Path $sprint $relative), [byte[]]@(0, 1))
    $r = Get-GeneratedRemediationByteComparison @arguments
    $r.Status | Should -Be Different
    $r.BytesCompared | Should -Be 0
  }
  It 'does not normalize CRLF, LF, or encoding' {
    [IO.File]::WriteAllBytes((Join-Path $stable $relative), [byte[]]@(65, 13, 10))
    [IO.File]::WriteAllBytes((Join-Path $sprint $relative), [byte[]]@(65, 10))
    (Get-GeneratedRemediationByteComparison @arguments).DefaultDataEqual | Should -BeFalse
  }
  It 'holds missing partners instead of matching identical bytes at another path' {
    Move-Item -LiteralPath (Join-Path $stable $relative) -Destination (Join-Path $stable '_generated/other.bin')
    $r = Get-GeneratedRemediationByteComparison @arguments
    $r.Status | Should -Be Hold
    $r.DefaultDataEqual | Should -BeNullOrEmpty
    $r.Approved | Should -BeFalse
  }
  It 'refuses mismatched supplied repository binding before opening data' {
    $arguments.RepositoryName = 'OtherRepo'
    $r = Get-GeneratedRemediationByteComparison @arguments
    $r.Status | Should -Be Hold
    $r.BytesCompared | Should -Be 0
    $r.Errors -join ' ' | Should -Match 'binding refused'
  }
  It 'rejects invalid relative paths before metadata acquisition' {
    Mock Get-Item { throw 'Unexpected target probe' }
    foreach ($path in @('../escape', '_generated/../escape', '_generated/a:notes', '_generated/NUL.txt',
      '_generated/a\\b', '_generated/a.', '_generated//a', '_generated/.git/config',
      'C:/file', '\\server/share', ('_generated/a' + [char]0), "_generated/COM$([char]0xb9).txt")) {
      $arguments.RelativePath = $path
      (Get-GeneratedRemediationByteComparison @arguments).Status | Should -Be Hold
    }
    Should -Invoke Get-Item -Times 0
  }
  It 'rejects relative, UNC, device and traversal roots without metadata acquisition' {
    Mock Get-Item { throw 'Unexpected target probe' }
    foreach ($root in @('C:relative', '\\server/share', '\\?\C:\somewhere', 'C:/a/../b')) {
      $arguments.StableRoot = $root
      (Get-GeneratedRemediationByteComparison @arguments).Status | Should -Be Hold
    }
    Should -Invoke Get-Item -Times 0
  }
  It 'holds a directory in place of a file' {
    Remove-Item -LiteralPath (Join-Path $stable $relative) -Force
    $null = New-Item -ItemType Directory -Path (Join-Path $stable $relative)
    (Get-GeneratedRemediationByteComparison @arguments).Status | Should -Be Hold
  }
  It 'returns Hold for null or empty bindings without prompting or probing' {
    Mock Get-Item { throw 'Unexpected target probe' }
    foreach ($key in @('StableRoot', 'SprintRoot', 'RepositoryName', 'RelativePath')) {
      foreach ($value in @($null, '')) {
        $invalid = $arguments.Clone()
        $invalid[$key] = $value
        $r = Get-GeneratedRemediationByteComparison @invalid
        $r.Status | Should -Be Hold
        $r.DefaultDataEqual | Should -BeNullOrEmpty
      }
    }
    Should -Invoke Get-Item -Times 0
  }
  It 'holds unsupported offline file metadata before default-data reads' {
    Mock Get-Item {
      $item = & $script:realGetItem @PesterBoundParameters
      if ($LiteralPath -eq (Join-Path $script:stable $script:relative)) {
        return [pscustomobject]@{ PSIsContainer = $false; Attributes = [IO.FileAttributes]::Offline }
      }
      $item
    }
    $r = Get-GeneratedRemediationByteComparison @arguments
    $r.Status | Should -Be Hold
    $r.BytesCompared | Should -Be 0
    $r.Errors -join ' ' | Should -Match 'Unsupported'
  }
  It 'refuses an actual redirecting directory before descendant data acquisition' {
    $link = Join-Path $stable '_generated/link'
    $null = New-Item -ItemType Junction -Path $link -Target (Join-Path $sprint '_generated')
    try {
      $arguments.RelativePath = "_generated/link/space $([char]0xfc).bin"
      $r = Get-GeneratedRemediationByteComparison @arguments
      $r.Status | Should -Be Hold
      $r.Errors -join ' ' | Should -Match 'Redirecting'
      $r.BytesCompared | Should -Be 0
    } finally { Remove-Item -LiteralPath $link -Force }
  }
  It 'holds a nested repository boundary' {
    $null = New-Item -ItemType Directory -Path (Join-Path $stable '_generated/.git')
    $r = Get-GeneratedRemediationByteComparison @arguments
    $r.Status | Should -Be Hold
    $r.Errors -join ' ' | Should -Match 'Nested repository'
  }
  It 'disposes the first stream if opening the second fails' {
    $locked = [IO.File]::Open((Join-Path $sprint $relative), [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    try { $r = Get-GeneratedRemediationByteComparison @arguments } finally { $locked.Dispose() }
    $r.Status | Should -Be Hold
    $r.DefaultDataEqual | Should -BeNullOrEmpty
    foreach ($root in @($stable, $sprint)) {
      $handle = [IO.File]::Open((Join-Path $root $relative), [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
      $handle.Dispose()
    }
  }
  It 'holds metadata drift even after matching the bytes and disposes both streams' {
    $script:stableLeafCalls = 0
    Mock Get-Item {
      $item = & $script:realGetItem @PesterBoundParameters
      if ($LiteralPath -eq (Join-Path $script:stable $script:relative)) {
        $script:stableLeafCalls++
        if ($script:stableLeafCalls -ge 2) {
          return [pscustomobject]@{ PSIsContainer = $false; Attributes = $item.Attributes; Length = $item.Length + 1
            CreationTimeUtc = $item.CreationTimeUtc; LastWriteTimeUtc = $item.LastWriteTimeUtc }
        }
      }
      $item
    }
    $r = Get-GeneratedRemediationByteComparison @arguments
    $r.Status | Should -Be Hold
    $r.DefaultDataEqual | Should -BeNullOrEmpty
    $r.Errors -join ' ' | Should -Match 'drift'
    foreach ($root in @($stable, $sprint)) {
      $handle = [IO.File]::Open((Join-Path $root $relative), [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
      $handle.Dispose()
    }
  }
  It 'does not upgrade different named streams into ADS verification or removal approval' {
    [IO.File]::WriteAllText((Join-Path $stable $relative) + ':notes', 'stable-only stream')
    [IO.File]::WriteAllText((Join-Path $sprint $relative) + ':notes', 'different sprint stream')
    $r = Get-GeneratedRemediationByteComparison @arguments
    $r.Status | Should -Be Equal
    $r.NamedStreamsVerified | Should -BeFalse
    $r.ReadyForRemoval | Should -BeFalse
    $r.CustodyVerified | Should -BeFalse
  }
}
