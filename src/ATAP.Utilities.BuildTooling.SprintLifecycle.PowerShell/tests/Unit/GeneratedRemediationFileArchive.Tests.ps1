BeforeAll {
  . (Join-Path $PSScriptRoot '../../private/New-GeneratedRemediationFileArchive.ps1')
  . (Join-Path $PSScriptRoot '../../private/Restore-GeneratedRemediationFileArchive.ps1')
  $script:base = [IO.Path]::GetFullPath("$PSScriptRoot/../../../../_generated/Sprint0016/Task16.84/FileArchiveSparseADSTests-v1")
  $null = New-Item -ItemType Directory -Path $script:base -Force
  $cursor = $script:base
  while ($cursor) {
    $node = Get-Item -LiteralPath $cursor -Force
    if ($node.LinkType -or $node.Target) { throw 'Redirected archive test root.' }
    $cursor = Split-Path -Parent $cursor
  }
  $script:realGetItem = Get-Command Get-Item -CommandType Cmdlet
  $script:unsafeDeviceNames = @('CONIN$', 'conout$', 'CLOCK$', 'CONIN$.txt', 'conout$ .txt',
    'CON .txt', 'NUL  .dat', 'COM1 .log', ('LPT' + [char]0xb2 + ' .txt'), 'conin$ ..txt', 'PRN...log')
  function New-ArchiveFixtureZip {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates only a new owned synthetic ZIP for adversarial tests.')]
    [CmdletBinding()]
    param([string]$Json, [hashtable]$Entries)
    $stream = [IO.File]::Open($script:archive, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    $zip = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Create)
    try {
      $all = @{ 'manifest.json' = [Text.Encoding]::UTF8.GetBytes($Json) }
      foreach ($key in $Entries.Keys) { $all[$key] = $Entries[$key] }
      foreach ($key in $all.Keys) {
        $output = $zip.CreateEntry($key).Open()
        try { $output.Write($all[$key], 0, $all[$key].Length) } finally { $output.Dispose() }
      }
    } finally { $zip.Dispose(); $stream.Dispose() }
    (Get-FileHash -LiteralPath $script:archive).Hash
  }
}
Describe 'One-file sparse ADS archive and independent proof restore' {
  BeforeEach {
    $script:run = Join-Path $script:base ([guid]::NewGuid().ToString('N'))
    $script:root = Join-Path $script:run 'source'
    $script:relative = '_generated/file.bin'
    $script:source = Join-Path $script:root $script:relative
    $script:archive = Join-Path $script:run 'archive.zip'
    $script:proof = Join-Path $script:run 'proof'
    $null = New-Item -ItemType Directory -Path (Split-Path -Parent $script:source) -Force
    [IO.File]::WriteAllBytes($script:source, [byte[]]@(0, 1, 255, 17))
    $script:writerArguments = @{RootPath=$script:root; RelativePath=$script:relative; ArchivePath=$script:archive}
    $script:validManifest = [ordered]@{Version=1; SourceRoot=$script:root; RelativePath=$script:relative; Streams=@(
      [ordered]@{Name=':$DATA';Bytes=4;SHA256=(Get-FileHash -LiteralPath $script:source).Hash;Entry='data/0000.bin'}
    )}
  }
  AfterEach {
    $resolved = (Resolve-Path -LiteralPath $script:run).ProviderPath
    if (-not $resolved.StartsWith($script:base.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase) -or
      (& $script:realGetItem -LiteralPath $resolved -Force).LinkType) { throw 'Archive test cleanup escaped owned root.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force -ErrorAction Stop
  }
  It 'takes the default-only branch and independently restores exact bytes without readiness claims' {
    $before = (Get-FileHash -LiteralPath $source).Hash
    $items = @(New-GeneratedRemediationFileArchive @writerArguments -Confirm:$false)
    $items.Count | Should -Be 1
    $created = $items[0]
    $created.Status | Should -Be Verified
    $created.Branch | Should -Be DefaultOnly
    $created.NamedStreamCount | Should -Be 0
    $created.Manifest.Streams.Count | Should -Be 1
    $created.FileArchiveVerified | Should -BeTrue
    $created.FileRestoreVerified | Should -BeFalse
    $r = Restore-GeneratedRemediationFileArchive -RootPath $root -ArchivePath $archive -ExpectedArchiveSHA256 $created.ArchiveSHA256 -ProofRoot $proof -Confirm:$false
    $r.Status | Should -Be Verified
    $r.FileRestoreVerified | Should -BeTrue
    (Get-FileHash -LiteralPath $r.ProofPath).Hash | Should -Be $before
    (Get-FileHash -LiteralPath $source).Hash | Should -Be $before
    foreach ($item in @($created, $r)) {
      foreach ($flag in @('Approved','ReadyForRemoval','CustodyVerified','DirectoryStreamsVerified','RootStreamsVerified')) { $item.$flag | Should -BeFalse }
    }
  }
  It 'archives and restores an empty default file' {
    [IO.File]::WriteAllBytes($source, [byte[]]@())
    $created = New-GeneratedRemediationFileArchive @writerArguments -Confirm:$false
    $created.FileArchiveVerified | Should -BeTrue
    $r = Restore-GeneratedRemediationFileArchive -RootPath $root -ArchivePath $archive -ExpectedArchiveSHA256 $created.ArchiveSHA256 -ProofRoot $proof -Confirm:$false
    $r.FileRestoreVerified | Should -BeTrue
    (Get-Item -LiteralPath $r.ProofPath).Length | Should -Be 0
  }
  It 'archives only present named payloads including Unicode and empty streams and actually restores them' {
    $unicode = [string][char]0x9644 + [char]0x6ce8
    [IO.File]::WriteAllText($source + ':notes', 'named payload')
    [IO.File]::WriteAllBytes($source + ':empty', [byte[]]@())
    [IO.File]::WriteAllBytes($source + ':' + $unicode, [byte[]]@(9, 8, 0, 7))
    $before = @{}
    foreach ($name in @('notes','empty',$unicode)) { $before[$name] = (Get-FileHash -LiteralPath ($source + ':' + $name)).Hash }
    $created = New-GeneratedRemediationFileArchive @writerArguments -Confirm:$false
    $created.Status | Should -Be Verified
    $created.Branch | Should -Be NamedStreamsPresent
    $created.NamedStreamCount | Should -Be 3
    $r = Restore-GeneratedRemediationFileArchive -RootPath $root -ArchivePath $archive -ExpectedArchiveSHA256 $created.ArchiveSHA256 -ProofRoot $proof -Confirm:$false
    $r.Status | Should -Be Verified
    $r.NamedStreamCount | Should -Be 3
    foreach ($name in $before.Keys) {
      (Get-FileHash -LiteralPath ($r.ProofPath + ':' + $name)).Hash | Should -Be $before[$name]
      (Get-FileHash -LiteralPath ($source + ':' + $name)).Hash | Should -Be $before[$name]
    }
    @(Get-Item -LiteralPath $r.ProofPath -Stream '*').Count | Should -Be 4
  }
  It 'supports WhatIf without creating an archive or proof' {
    $r = New-GeneratedRemediationFileArchive @writerArguments -WhatIf
    $r.Status | Should -Be Skipped
    Test-Path -LiteralPath $archive | Should -BeFalse
    $created = New-GeneratedRemediationFileArchive @writerArguments -Confirm:$false
    $r = Restore-GeneratedRemediationFileArchive -RootPath $root -ArchivePath $archive -ExpectedArchiveSHA256 $created.ArchiveSHA256 -ProofRoot $proof -WhatIf
    $r.Status | Should -Be Skipped
    Test-Path -LiteralPath $proof | Should -BeFalse
  }
  It 'refuses missing and unsupported source shapes before creating outputs' {
    Remove-Item -LiteralPath $source -Force
    (New-GeneratedRemediationFileArchive @writerArguments -Confirm:$false).Status | Should -Be Hold
    $null = New-Item -ItemType Directory -Path $source
    (New-GeneratedRemediationFileArchive @writerArguments -Confirm:$false).Status | Should -Be Hold
    Test-Path -LiteralPath $archive | Should -BeFalse
  }
  It 'preserves an existing archive sentinel and refuses overlap' {
    [IO.File]::WriteAllText($archive, 'sentinel')
    $before = (Get-FileHash -LiteralPath $archive).Hash
    (New-GeneratedRemediationFileArchive @writerArguments -Confirm:$false).Status | Should -Be Hold
    (Get-FileHash -LiteralPath $archive).Hash | Should -Be $before
    $writerArguments.ArchivePath = Join-Path $root 'inside.zip'
    (New-GeneratedRemediationFileArchive @writerArguments -Confirm:$false).Status | Should -Be Hold
    Test-Path -LiteralPath $writerArguments.ArchivePath | Should -BeFalse
  }
  It 'holds possible DOS short-name spellings before stream acquisition' {
    $writerArguments.RelativePath = '_generated/FILE~1.bin'
    [IO.File]::WriteAllBytes((Join-Path $root $writerArguments.RelativePath), [byte[]]@(1))
    Mock Get-Item { throw 'Unexpected stream acquisition' } -ParameterFilter { $Stream }
    $r = New-GeneratedRemediationFileArchive @writerArguments -Confirm:$false
    $r.Status | Should -Be Hold
    $r.ArchiveCreated | Should -BeFalse
    Should -Invoke Get-Item -Times 0 -ParameterFilter { $Stream }
  }
  It 'refuses device-name strings in writer paths before stream acquisition without touching devices' {
    $before = (Get-FileHash -LiteralPath $source).Hash
    Mock Get-Item { throw 'Unexpected stream acquisition' } -ParameterFilter { $Stream }
    foreach ($name in $script:unsafeDeviceNames) {
      foreach ($field in @('RelativePath', 'RootPath', 'ArchivePath')) {
        $invalid = $writerArguments.Clone()
        $invalid[$field] = switch ($field) {
          RelativePath { '_generated/' + $name }
          RootPath { Join-Path $root $name }
          ArchivePath { Join-Path $run $name }
        }
        $r = New-GeneratedRemediationFileArchive @invalid -Confirm:$false
        $r.Status | Should -Be Hold
        $r.ArchiveCreated | Should -BeFalse
      }
    }
    Should -Invoke Get-Item -Times 0 -ParameterFilter { $Stream }
    (Get-FileHash -LiteralPath $source).Hash | Should -Be $before
    Test-Path -LiteralPath $archive | Should -BeFalse
  }

  It 'refuses device-name restore manifests before proof writes and permits a close ordinary name' {
    $json = $validManifest | ConvertTo-Json -Depth 5 -Compress
    foreach ($name in $script:unsafeDeviceNames) {
      $hash = New-ArchiveFixtureZip -Json ($json.Replace('_generated/file.bin', '_generated/' + $name)) -Entries @{'data/0000.bin'=[byte[]]@(0,1,255,17)}
      $beforeArchive = (Get-FileHash -LiteralPath $archive).Hash
      $r = Restore-GeneratedRemediationFileArchive -RootPath $root -ArchivePath $archive -ExpectedArchiveSHA256 $hash -ProofRoot $proof -Confirm:$false
      $r.Status | Should -Be Hold
      $r.ProofCreated | Should -BeFalse
      Test-Path -LiteralPath $proof | Should -BeFalse
      (Get-FileHash -LiteralPath $archive).Hash | Should -Be $beforeArchive
      Remove-Item -LiteralPath $archive -Force
    }
    $writerArguments.RelativePath = '_generated/CONIN$-ordinary.bin'
    [IO.File]::WriteAllBytes((Join-Path $root $writerArguments.RelativePath), [byte[]]@(1, 2, 3))
    $created = New-GeneratedRemediationFileArchive @writerArguments -Confirm:$false
    $created.Status | Should -Be Verified
    $r = Restore-GeneratedRemediationFileArchive -RootPath $root -ArchivePath $archive -ExpectedArchiveSHA256 $created.ArchiveSHA256 -ProofRoot $proof -Confirm:$false
    $r.FileRestoreVerified | Should -BeTrue
  }

  It 'refuses a redirecting archive destination without writing through it' {
    $outside = Join-Path $run 'outside'
    $null = New-Item -ItemType Directory -Path $outside
    $link = Join-Path $run 'linked'
    $null = New-Item -ItemType Junction -Path $link -Target $outside
    try {
      $writerArguments.ArchivePath = Join-Path $link 'archive.zip'
      (New-GeneratedRemediationFileArchive @writerArguments -Confirm:$false).Status | Should -Be Hold
      Test-Path -LiteralPath (Join-Path $outside 'archive.zip') | Should -BeFalse
    } finally { Remove-Item -LiteralPath $link -Force }
  }
  It 'refuses excessive stream count or declared bytes without acquiring payload' {
    Mock Get-Item {
      & $script:realGetItem @PesterBoundParameters
      if ($script:limitMode -eq 'count') {
        foreach ($i in 1..64) { [pscustomobject]@{Stream="extra$i";Length=0L} }
      } else { [pscustomobject]@{Stream='too-large';Length=67108865L} }
    } -ParameterFilter { $Stream }
    foreach ($mode in @('count', 'bytes')) {
      $script:limitMode = $mode
      $r = New-GeneratedRemediationFileArchive @writerArguments -Confirm:$false
      $r.Status | Should -Be Hold
      $r.ArchiveCreated | Should -BeFalse
      Test-Path -LiteralPath $archive | Should -BeFalse
    }
  }

  It 'refuses a redirecting proof parent before any writes through it' {
    $created = New-GeneratedRemediationFileArchive @writerArguments -Confirm:$false
    $outside = Join-Path $run 'outside-proof'
    $null = New-Item -ItemType Directory -Path $outside
    $link = Join-Path $run 'proof-link'
    $null = New-Item -ItemType Junction -Path $link -Target $outside
    try {
      $r = Restore-GeneratedRemediationFileArchive -RootPath $root -ArchivePath $archive -ExpectedArchiveSHA256 $created.ArchiveSHA256 -ProofRoot (Join-Path $link 'new-proof') -Confirm:$false
      $r.Status | Should -Be Hold
      $r.ProofCreated | Should -BeFalse
      Test-Path -LiteralPath (Join-Path $outside 'new-proof') | Should -BeFalse
    } finally { Remove-Item -LiteralPath $link -Force }
  }

  It 'holds source stream-set drift and preserves the partial archive' {
    $script:censusCalls = 0
    Mock Get-Item {
      if ($Stream) {
        $script:censusCalls++
        if ($script:censusCalls -eq 2) { [IO.File]::WriteAllText($script:source + ':late', 'new stream') }
      }
      & $script:realGetItem @PesterBoundParameters
    }
    $r = New-GeneratedRemediationFileArchive @writerArguments -Confirm:$false
    $r.Status | Should -Be Hold
    $r.ArchiveCreated | Should -BeTrue
    $r.FileArchiveVerified | Should -BeFalse
    Test-Path -LiteralPath $archive | Should -BeTrue
    $r.Errors -join ' ' | Should -Match 'drift'
  }
  It 'holds changed content even with restored size and timestamp' {
    $script:censusCalls = 0
    Mock Get-Item {
      if ($Stream) {
        $script:censusCalls++
        if ($script:censusCalls -eq 2) {
          $written = [IO.File]::GetLastWriteTimeUtc($script:source)
          [IO.File]::WriteAllBytes($script:source, [byte[]]@(5, 4, 3, 2))
          [IO.File]::SetLastWriteTimeUtc($script:source, $written)
        }
      }
      & $script:realGetItem @PesterBoundParameters
    }
    $r = New-GeneratedRemediationFileArchive @writerArguments -Confirm:$false
    $r.Status | Should -Be Hold
    $r.FileArchiveVerified | Should -BeFalse
    $r.Errors -join ' ' | Should -Match 'content drift'
  }
  It 'rejects a bad expected hash and existing or overlapping proof targets without overwriting' {
    $created = New-GeneratedRemediationFileArchive @writerArguments -Confirm:$false
    (Restore-GeneratedRemediationFileArchive -RootPath $root -ArchivePath $archive -ExpectedArchiveSHA256 ('0'*64) -ProofRoot $proof -Confirm:$false).Status | Should -Be Hold
    Test-Path -LiteralPath $proof | Should -BeFalse
    $null = New-Item -ItemType Directory -Path $proof
    [IO.File]::WriteAllText((Join-Path $proof 'sentinel'), 'keep')
    (Restore-GeneratedRemediationFileArchive -RootPath $root -ArchivePath $archive -ExpectedArchiveSHA256 $created.ArchiveSHA256 -ProofRoot $proof -Confirm:$false).Status | Should -Be Hold
    (Get-Content -LiteralPath (Join-Path $proof 'sentinel') -Raw) | Should -Be keep
    (Restore-GeneratedRemediationFileArchive -RootPath $root -ArchivePath $archive -ExpectedArchiveSHA256 $created.ArchiveSHA256 -ProofRoot (Join-Path $root 'proof') -Confirm:$false).Status | Should -Be Hold
    Test-Path -LiteralPath (Join-Path $root 'proof') | Should -BeFalse
  }
  It 'refuses a substituted source boundary even with the correct archive hash' {
    $created = New-GeneratedRemediationFileArchive @writerArguments -Confirm:$false
    $otherRoot = Join-Path $run 'other-source'
    $null = New-Item -ItemType Directory -Path $otherRoot
    $r = Restore-GeneratedRemediationFileArchive -RootPath $otherRoot -ArchivePath $archive -ExpectedArchiveSHA256 $created.ArchiveSHA256 -ProofRoot $proof -Confirm:$false
    $r.Status | Should -Be Hold
    $r.Errors -join ' ' | Should -Match 'source boundary differs'
    Test-Path -LiteralPath $proof | Should -BeFalse
  }
  It 'holds final restored stream-set drift and retains partial proof' {
    $created = New-GeneratedRemediationFileArchive @writerArguments -Confirm:$false
    $script:proofCensusCalls = 0
    Mock Get-Item {
      $script:proofCensusCalls++
      if ($script:proofCensusCalls -eq 2) { [IO.File]::WriteAllText((Join-Path $script:proof $script:relative) + ':late', 'unexpected') }
      & $script:realGetItem @PesterBoundParameters
    } -ParameterFilter { $Stream }
    $r = Restore-GeneratedRemediationFileArchive -RootPath $root -ArchivePath $archive -ExpectedArchiveSHA256 $created.ArchiveSHA256 -ProofRoot $proof -Confirm:$false
    $r.Status | Should -Be Hold
    $r.FileRestoreVerified | Should -BeFalse
    $r.ProofCreated | Should -BeTrue
    Test-Path -LiteralPath $proof | Should -BeTrue
    $r.Errors -join ' ' | Should -Match 'stream-set drift'
  }
  It 'rejects malformed schema, unsafe streams, lengths and traversal before proof writes' {
    $baseJson = $validManifest | ConvertTo-Json -Depth 5 -Compress
    $variants = @(
      $baseJson.Replace('"Version":1', '"Version":1,"Version":1'),
      $baseJson.Replace('"Version":1', '"Version":1,"version":1'),
      $baseJson.Replace('"Version":1', '"Version":"1"'),
      $baseJson.Replace('"Version":1', '"Version":1,"Unknown":0'),
      $baseJson.Replace('_generated/file.bin', '_generated/../escape'),
      $baseJson.Replace('_generated/file.bin', '_generated/NUL.txt'),
      $baseJson.Replace('_generated/file.bin', '_generated/FILE~1.bin'),
      $baseJson.Replace(':$DATA', 'unsafe:stream'),
      $baseJson.Replace(':$DATA', 'notes'),
      $baseJson.Replace('"Bytes":4', '"Bytes":67108865'),
      $baseJson.Replace('"Bytes":4', '"Bytes":4.0'),
      $baseJson.Replace('"Bytes":4', '"Bytes":-1'),
      $baseJson.Replace('"Bytes":4', '"Bytes":3'),
      $baseJson.Replace('data/0000.bin', '../escape'),
      $baseJson.Replace($validManifest.Streams[0].SHA256, ('0'*64)),
      '{"Version":1}',
      'not-json'
    )
    foreach ($json in $variants) {
      $hash = New-ArchiveFixtureZip -Json $json -Entries @{'data/0000.bin'=[byte[]]@(0,1,255,17)}
      $r = Restore-GeneratedRemediationFileArchive -RootPath $root -ArchivePath $archive -ExpectedArchiveSHA256 $hash -ProofRoot $proof -Confirm:$false
      $r.Status | Should -Be Hold
      $r.ProofCreated | Should -BeFalse
      Test-Path -LiteralPath $proof | Should -BeFalse
      Remove-Item -LiteralPath $archive -Force
    }
  }
  It 'rejects extra, missing, traversal and case-aliased ZIP entries before proof writes' {
    foreach ($entries in @(
      @{'data/0000.bin'=[byte[]]@(0,1,255,17);'extra.bin'=[byte[]]@(1)},
      @{'data/0001.bin'=[byte[]]@(0,1,255,17)},
      @{'data/0000.bin'=[byte[]]@(0,1,255,17);'../escape'=[byte[]]@(1)}
    )) {
      $hash = New-ArchiveFixtureZip -Json ($validManifest|ConvertTo-Json -Depth 5 -Compress) -Entries $entries
      (Restore-GeneratedRemediationFileArchive -RootPath $root -ArchivePath $archive -ExpectedArchiveSHA256 $hash -ProofRoot $proof -Confirm:$false).Status | Should -Be Hold
      Test-Path -LiteralPath $proof | Should -BeFalse
      Remove-Item -LiteralPath $archive -Force
    }
    # Update mode permits a case alias alongside the existing entry.
    $created = New-GeneratedRemediationFileArchive @writerArguments -Confirm:$false
    $created.FileArchiveVerified | Should -BeTrue
    $zip = [IO.Compression.ZipFile]::Open($archive, [IO.Compression.ZipArchiveMode]::Update)
    try { $null = $zip.CreateEntry('DATA/0000.bin') } finally { $zip.Dispose() }
    $hash = (Get-FileHash -LiteralPath $archive).Hash
    (Restore-GeneratedRemediationFileArchive -RootPath $root -ArchivePath $archive -ExpectedArchiveSHA256 $hash -ProofRoot $proof -Confirm:$false).Status | Should -Be Hold
    Test-Path -LiteralPath $proof | Should -BeFalse
  }
}
