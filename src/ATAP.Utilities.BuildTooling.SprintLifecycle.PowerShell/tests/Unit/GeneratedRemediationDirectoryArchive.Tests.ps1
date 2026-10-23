BeforeAll {
  . (Join-Path $PSScriptRoot '../../private/New-GeneratedRemediationDirectoryArchive.ps1')
  . (Join-Path $PSScriptRoot '../../private/Restore-GeneratedRemediationDirectoryArchive.ps1')
  $script:base = [IO.Path]::GetFullPath("$PSScriptRoot/../../../../_generated/Sprint0016/Task16.84/DirectoryArchiveTests-v1")
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
Describe 'One-directory sparse ADS archive and independent proof restore' {
  BeforeEach {
    $script:run = Join-Path $script:base ([guid]::NewGuid().ToString('N'))
    $script:root = Join-Path $script:run 'source'
    $script:relative = '_generated/directory'
    $script:source = Join-Path $script:root $script:relative
    $script:archive = Join-Path $script:run 'archive.zip'
    $script:proof = Join-Path $script:run 'proof'
    $null = New-Item -ItemType Directory -Path $script:source -Force
    $script:child = Join-Path $script:source 'child.bin'
    [IO.File]::WriteAllBytes($script:child, [byte[]]@(0, 1, 255, 17))
    [IO.File]::WriteAllBytes($script:source + ':notes', [byte[]]@(0, 1, 255, 17))
    $script:writerArguments = @{RootPath=$script:root; RelativePath=$script:relative; ArchivePath=$script:archive}
    $script:validManifest = [ordered]@{Version=1; SourceKind='DirectoryNamedStreams'; SourceRoot=$script:root; RelativePath=$script:relative; Streams=@(
      [ordered]@{Name='notes';Bytes=4;SHA256=(Get-FileHash -LiteralPath ($script:source + ':notes')).Hash;Entry='data/0000.bin'}
    )}
  }
  AfterEach {
    $resolved = (Resolve-Path -LiteralPath $script:run).ProviderPath
    if (-not $resolved.StartsWith($script:base.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase) -or
      (& $script:realGetItem -LiteralPath $resolved -Force).LinkType) { throw 'Archive test cleanup escaped owned root.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force -ErrorAction Stop
  }
  It 'archives an empty stream set for the generated root and restores only that directory' {
    $writerArguments.RelativePath = '_generated'
    $childHash = (Get-FileHash -LiteralPath $child).Hash
    $created = New-GeneratedRemediationDirectoryArchive @writerArguments -Confirm:$false
    $created.Status | Should -Be Verified
    $created.Branch | Should -Be NoNamedStreams
    $created.NamedStreamCount | Should -Be 0
    $created.Manifest.SourceKind | Should -Be DirectoryNamedStreams
    $created.Manifest.Streams.Count | Should -Be 0
    $r = Restore-GeneratedRemediationDirectoryArchive -RootPath $root -ArchivePath $archive -ExpectedArchiveSHA256 $created.ArchiveSHA256 -ProofRoot $proof -Confirm:$false
    $r.Status | Should -Be Verified
    $r.DirectoryRestoreVerified | Should -BeTrue
    $r.ProofPath | Should -Be (Join-Path $proof '_generated')
    @(Get-Item -LiteralPath $r.ProofPath -Stream '*' | Where-Object Stream -CNE ':$DATA').Count | Should -Be 0
    Test-Path -LiteralPath (Join-Path $r.ProofPath 'directory') | Should -BeFalse
    (Get-FileHash -LiteralPath $child).Hash | Should -Be $childHash
    foreach ($item in @($created, $r)) {
      foreach ($flag in @('Approved','ReadyForRemoval','CustodyVerified','DirectoryStreamsVerified','RootStreamsVerified')) { $item.$flag | Should -BeFalse }
    }
  }
  It 'independently verifies an empty descendant stream set without copying children' {
    [IO.File]::Delete($source + ':notes')
    $created = New-GeneratedRemediationDirectoryArchive @writerArguments -Confirm:$false
    $created.DirectoryArchiveVerified | Should -BeTrue
    $created.Manifest.Streams.Count | Should -Be 0
    $r = Restore-GeneratedRemediationDirectoryArchive -RootPath $root -ArchivePath $archive -ExpectedArchiveSHA256 $created.ArchiveSHA256 -ProofRoot $proof -Confirm:$false
    $r.DirectoryRestoreVerified | Should -BeTrue
    Test-Path -LiteralPath (Join-Path $r.ProofPath 'child.bin') | Should -BeFalse
    Test-Path -LiteralPath $child | Should -BeTrue
  }
  It 'archives only present named payloads including Unicode and empty streams and actually restores them' {
    $unicode = [string][char]0x9644 + [char]0x6ce8
    [IO.File]::WriteAllText($source + ':notes', 'named payload')
    [IO.File]::WriteAllBytes($source + ':empty', [byte[]]@())
    [IO.File]::WriteAllBytes($source + ':' + $unicode, [byte[]]@(9, 8, 0, 7))
    $before = @{}
    foreach ($name in @('notes','empty',$unicode)) { $before[$name] = (Get-FileHash -LiteralPath ($source + ':' + $name)).Hash }
    $created = New-GeneratedRemediationDirectoryArchive @writerArguments -Confirm:$false
    $created.Status | Should -Be Verified
    $created.Branch | Should -Be NamedStreamsPresent
    $created.NamedStreamCount | Should -Be 3
    $r = Restore-GeneratedRemediationDirectoryArchive -RootPath $root -ArchivePath $archive -ExpectedArchiveSHA256 $created.ArchiveSHA256 -ProofRoot $proof -Confirm:$false
    $r.Status | Should -Be Verified
    $r.NamedStreamCount | Should -Be 3
    foreach ($name in $before.Keys) {
      (Get-FileHash -LiteralPath ($r.ProofPath + ':' + $name)).Hash | Should -Be $before[$name]
      (Get-FileHash -LiteralPath ($source + ':' + $name)).Hash | Should -Be $before[$name]
    }
    @(Get-Item -LiteralPath $r.ProofPath -Stream '*' | Where-Object Stream -CNE ':$DATA').Count | Should -Be 3
    Test-Path -LiteralPath (Join-Path $r.ProofPath 'child.bin') | Should -BeFalse
  }
  It 'supports WhatIf without creating an archive or proof' {
    $r = New-GeneratedRemediationDirectoryArchive @writerArguments -WhatIf
    $r.Status | Should -Be Skipped
    Test-Path -LiteralPath $archive | Should -BeFalse
    $created = New-GeneratedRemediationDirectoryArchive @writerArguments -Confirm:$false
    $r = Restore-GeneratedRemediationDirectoryArchive -RootPath $root -ArchivePath $archive -ExpectedArchiveSHA256 $created.ArchiveSHA256 -ProofRoot $proof -WhatIf
    $r.Status | Should -Be Skipped
    Test-Path -LiteralPath $proof | Should -BeFalse
  }
  It 'refuses missing and unsupported source shapes before creating outputs' {
    Remove-Item -LiteralPath $source -Recurse -Force
    (New-GeneratedRemediationDirectoryArchive @writerArguments -Confirm:$false).Status | Should -Be Hold
    [IO.File]::WriteAllBytes($source, [byte[]]@(1))
    (New-GeneratedRemediationDirectoryArchive @writerArguments -Confirm:$false).Status | Should -Be Hold
    Test-Path -LiteralPath $archive | Should -BeFalse
  }
  It 'preserves an existing archive sentinel and refuses overlap' {
    [IO.File]::WriteAllText($archive, 'sentinel')
    $before = (Get-FileHash -LiteralPath $archive).Hash
    (New-GeneratedRemediationDirectoryArchive @writerArguments -Confirm:$false).Status | Should -Be Hold
    (Get-FileHash -LiteralPath $archive).Hash | Should -Be $before
    $writerArguments.ArchivePath = Join-Path $root 'inside.zip'
    (New-GeneratedRemediationDirectoryArchive @writerArguments -Confirm:$false).Status | Should -Be Hold
    Test-Path -LiteralPath $writerArguments.ArchivePath | Should -BeFalse
  }
  It 'holds possible DOS short-name spellings before stream acquisition' {
    $writerArguments.RelativePath = '_generated/FILE~1.bin'
    $null = New-Item -ItemType Directory -Path (Join-Path $root $writerArguments.RelativePath)
    Mock Get-Item { throw 'Unexpected stream acquisition' } -ParameterFilter { $Stream -eq '*' }
    $r = New-GeneratedRemediationDirectoryArchive @writerArguments -Confirm:$false
    $r.Status | Should -Be Hold
    $r.ArchiveCreated | Should -BeFalse
    Should -Invoke Get-Item -Times 0 -ParameterFilter { $Stream -eq '*' }
  }
  It 'refuses device-name strings in writer paths before stream acquisition without touching devices' {
    $before = (Get-FileHash -LiteralPath ($source + ':notes')).Hash
    Mock Get-Item { throw 'Unexpected stream acquisition' } -ParameterFilter { $Stream -eq '*' }
    foreach ($name in $script:unsafeDeviceNames) {
      foreach ($field in @('RelativePath', 'RootPath', 'ArchivePath')) {
        $invalid = $writerArguments.Clone()
        $invalid[$field] = switch ($field) {
          RelativePath { '_generated/' + $name }
          RootPath { Join-Path $root $name }
          ArchivePath { Join-Path $run $name }
        }
        $r = New-GeneratedRemediationDirectoryArchive @invalid -Confirm:$false
        $r.Status | Should -Be Hold
        $r.ArchiveCreated | Should -BeFalse
      }
    }
    Should -Invoke Get-Item -Times 0 -ParameterFilter { $Stream -eq '*' }
    (Get-FileHash -LiteralPath ($source + ':notes')).Hash | Should -Be $before
    Test-Path -LiteralPath $archive | Should -BeFalse
  }

  It 'refuses device-name restore manifests before proof writes and permits a close ordinary name' {
    $json = $validManifest | ConvertTo-Json -Depth 5 -Compress
    foreach ($name in $script:unsafeDeviceNames) {
      $hash = New-ArchiveFixtureZip -Json ($json.Replace('_generated/directory', '_generated/' + $name)) -Entries @{'data/0000.bin'=[byte[]]@(0,1,255,17)}
      $beforeArchive = (Get-FileHash -LiteralPath $archive).Hash
      $r = Restore-GeneratedRemediationDirectoryArchive -RootPath $root -ArchivePath $archive -ExpectedArchiveSHA256 $hash -ProofRoot $proof -Confirm:$false
      $r.Status | Should -Be Hold
      $r.ProofCreated | Should -BeFalse
      Test-Path -LiteralPath $proof | Should -BeFalse
      (Get-FileHash -LiteralPath $archive).Hash | Should -Be $beforeArchive
      Remove-Item -LiteralPath $archive -Force
    }
    $writerArguments.RelativePath = '_generated/CONIN$-ordinary.bin'
    $null = New-Item -ItemType Directory -Path (Join-Path $root $writerArguments.RelativePath)
    $created = New-GeneratedRemediationDirectoryArchive @writerArguments -Confirm:$false
    $created.Status | Should -Be Verified
    $r = Restore-GeneratedRemediationDirectoryArchive -RootPath $root -ArchivePath $archive -ExpectedArchiveSHA256 $created.ArchiveSHA256 -ProofRoot $proof -Confirm:$false
    $r.DirectoryRestoreVerified | Should -BeTrue
  }

  It 'refuses a redirecting archive destination without writing through it' {
    $outside = Join-Path $run 'outside'
    $null = New-Item -ItemType Directory -Path $outside
    $link = Join-Path $run 'linked'
    $null = New-Item -ItemType Junction -Path $link -Target $outside
    try {
      $writerArguments.ArchivePath = Join-Path $link 'archive.zip'
      (New-GeneratedRemediationDirectoryArchive @writerArguments -Confirm:$false).Status | Should -Be Hold
      Test-Path -LiteralPath (Join-Path $outside 'archive.zip') | Should -BeFalse
    } finally { Remove-Item -LiteralPath $link -Force }
  }
  It 'refuses excessive stream count or declared bytes without acquiring payload' {
    Mock Get-Item {
      & $script:realGetItem @PesterBoundParameters
      if ($script:limitMode -eq 'count') {
        foreach ($i in 1..65) { [pscustomobject]@{Stream="extra$i";Length=0L} }
      } else { [pscustomobject]@{Stream='too-large';Length=67108865L} }
    } -ParameterFilter { $Stream -eq '*' }
    foreach ($mode in @('count', 'bytes')) {
      $script:limitMode = $mode
      $r = New-GeneratedRemediationDirectoryArchive @writerArguments -Confirm:$false
      $r.Status | Should -Be Hold
      $r.ArchiveCreated | Should -BeFalse
      Test-Path -LiteralPath $archive | Should -BeFalse
    }
  }

  It 'refuses a redirecting proof parent before any writes through it' {
    $created = New-GeneratedRemediationDirectoryArchive @writerArguments -Confirm:$false
    $outside = Join-Path $run 'outside-proof'
    $null = New-Item -ItemType Directory -Path $outside
    $link = Join-Path $run 'proof-link'
    $null = New-Item -ItemType Junction -Path $link -Target $outside
    try {
      $r = Restore-GeneratedRemediationDirectoryArchive -RootPath $root -ArchivePath $archive -ExpectedArchiveSHA256 $created.ArchiveSHA256 -ProofRoot (Join-Path $link 'new-proof') -Confirm:$false
      $r.Status | Should -Be Hold
      $r.ProofCreated | Should -BeFalse
      Test-Path -LiteralPath (Join-Path $outside 'new-proof') | Should -BeFalse
    } finally { Remove-Item -LiteralPath $link -Force }
  }

  It 'holds source stream-set drift and preserves the partial archive' {
    $script:censusCalls = 0
    Mock Get-Item {
      if ($Stream -eq '*') {
        $script:censusCalls++
        if ($script:censusCalls -eq 2) { [IO.File]::WriteAllText($script:source + ':late', 'new stream') }
      }
      & $script:realGetItem @PesterBoundParameters
    }
    $r = New-GeneratedRemediationDirectoryArchive @writerArguments -Confirm:$false
    $r.Status | Should -Be Hold
    $r.ArchiveCreated | Should -BeTrue
    $r.DirectoryArchiveVerified | Should -BeFalse
    Test-Path -LiteralPath $archive | Should -BeTrue
    $r.Errors -join ' ' | Should -Match 'drift'
  }
  It 'holds changed content even with restored size and timestamp' {
    $script:censusCalls = 0
    Mock Get-Item {
      if ($Stream -eq '*') {
        $script:censusCalls++
        if ($script:censusCalls -eq 2) {
          $written = [IO.Directory]::GetLastWriteTimeUtc($script:source)
          [IO.File]::WriteAllBytes($script:source + ':notes', [byte[]]@(5, 4, 3, 2))
          [IO.Directory]::SetLastWriteTimeUtc($script:source, $written)
        }
      }
      & $script:realGetItem @PesterBoundParameters
    }
    $r = New-GeneratedRemediationDirectoryArchive @writerArguments -Confirm:$false
    $r.Status | Should -Be Hold
    $r.DirectoryArchiveVerified | Should -BeFalse
    $r.Errors -join ' ' | Should -Match 'content drift'
  }
  It 'rejects a bad expected hash and existing or overlapping proof targets without overwriting' {
    $created = New-GeneratedRemediationDirectoryArchive @writerArguments -Confirm:$false
    (Restore-GeneratedRemediationDirectoryArchive -RootPath $root -ArchivePath $archive -ExpectedArchiveSHA256 ('0'*64) -ProofRoot $proof -Confirm:$false).Status | Should -Be Hold
    Test-Path -LiteralPath $proof | Should -BeFalse
    $null = New-Item -ItemType Directory -Path $proof
    [IO.File]::WriteAllText((Join-Path $proof 'sentinel'), 'keep')
    (Restore-GeneratedRemediationDirectoryArchive -RootPath $root -ArchivePath $archive -ExpectedArchiveSHA256 $created.ArchiveSHA256 -ProofRoot $proof -Confirm:$false).Status | Should -Be Hold
    (Get-Content -LiteralPath (Join-Path $proof 'sentinel') -Raw) | Should -Be keep
    (Restore-GeneratedRemediationDirectoryArchive -RootPath $root -ArchivePath $archive -ExpectedArchiveSHA256 $created.ArchiveSHA256 -ProofRoot (Join-Path $root 'proof') -Confirm:$false).Status | Should -Be Hold
    Test-Path -LiteralPath (Join-Path $root 'proof') | Should -BeFalse
  }
  It 'refuses a substituted source boundary even with the correct archive hash' {
    $created = New-GeneratedRemediationDirectoryArchive @writerArguments -Confirm:$false
    $otherRoot = Join-Path $run 'other-source'
    $null = New-Item -ItemType Directory -Path $otherRoot
    $r = Restore-GeneratedRemediationDirectoryArchive -RootPath $otherRoot -ArchivePath $archive -ExpectedArchiveSHA256 $created.ArchiveSHA256 -ProofRoot $proof -Confirm:$false
    $r.Status | Should -Be Hold
    $r.Errors -join ' ' | Should -Match 'source boundary differs'
    Test-Path -LiteralPath $proof | Should -BeFalse
  }
  It 'holds final restored stream-set drift and retains partial proof' {
    $created = New-GeneratedRemediationDirectoryArchive @writerArguments -Confirm:$false
    $script:proofCensusCalls = 0
    Mock Get-Item {
      $script:proofCensusCalls++
      if ($script:proofCensusCalls -eq 2) { [IO.File]::WriteAllText((Join-Path $script:proof $script:relative) + ':late', 'unexpected') }
      & $script:realGetItem @PesterBoundParameters
    } -ParameterFilter { $Stream -eq '*' }
    $r = Restore-GeneratedRemediationDirectoryArchive -RootPath $root -ArchivePath $archive -ExpectedArchiveSHA256 $created.ArchiveSHA256 -ProofRoot $proof -Confirm:$false
    $r.Status | Should -Be Hold
    $r.DirectoryRestoreVerified | Should -BeFalse
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
      $baseJson.Replace('"SourceKind":"DirectoryNamedStreams",', ''),
      $baseJson.Replace('DirectoryNamedStreams', 'File'),
      $baseJson.Replace('"SourceKind":"DirectoryNamedStreams"', '"SourceKind":0'),
      $baseJson.Replace('"Name":"notes"', '"Name":"notes","name":"notes"'),
      $baseJson.Replace('"Name":"notes"', '"Name":0'),
      $baseJson.Replace('"Bytes":4', '"Bytes":"4"'),
      $baseJson.Replace('"Bytes":4', '"Bytes":true'),
      $baseJson.Replace('"Bytes":4', '"Bytes":9223372036854775808'),
      $baseJson.Replace('"Bytes":4', '"Bytes":4e0'),
      $baseJson.Replace('"Streams":[', '"Streams":{"Items":[').TrimEnd('}') + '}}',
      $baseJson.Replace('_generated/directory', '_generated/../escape'),
      $baseJson.Replace('_generated/directory', '_generated/NUL.txt'),
      $baseJson.Replace('_generated/directory', '_generated/FILE~1.bin'),
      $baseJson.Replace('"Name":"notes"', '"Name":"unsafe:stream"'),
      $baseJson.Replace('"Name":"notes"', '"Name":":$DATA"'),
      $baseJson.Replace('"Bytes":4', '"Bytes":67108865'),
      $baseJson.Replace('"Bytes":4', '"Bytes":4.0'),
      $baseJson.Replace('"Bytes":4', '"Bytes":-1'),
      $baseJson.Replace('"Bytes":4', '"Bytes":3'),
      $baseJson.Replace('data/0000.bin', '../escape'),
      $baseJson.Replace($validManifest.Streams[0].SHA256, ('0'*64)),
      $baseJson.Replace($validManifest.Streams[0].SHA256, 'abc'),
      '{"Version":1}',
      'not-json'
    )
    foreach ($json in $variants) {
      $hash = New-ArchiveFixtureZip -Json $json -Entries @{'data/0000.bin'=[byte[]]@(0,1,255,17)}
      $r = Restore-GeneratedRemediationDirectoryArchive -RootPath $root -ArchivePath $archive -ExpectedArchiveSHA256 $hash -ProofRoot $proof -Confirm:$false
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
      (Restore-GeneratedRemediationDirectoryArchive -RootPath $root -ArchivePath $archive -ExpectedArchiveSHA256 $hash -ProofRoot $proof -Confirm:$false).Status | Should -Be Hold
      Test-Path -LiteralPath $proof | Should -BeFalse
      Remove-Item -LiteralPath $archive -Force
    }
    # Update mode permits a case alias alongside the existing entry.
    $created = New-GeneratedRemediationDirectoryArchive @writerArguments -Confirm:$false
    $created.DirectoryArchiveVerified | Should -BeTrue
    $zip = [IO.Compression.ZipFile]::Open($archive, [IO.Compression.ZipArchiveMode]::Update)
    try { $null = $zip.CreateEntry('DATA/0000.bin') } finally { $zip.Dispose() }
    $hash = (Get-FileHash -LiteralPath $archive).Hash
    (Restore-GeneratedRemediationDirectoryArchive -RootPath $root -ArchivePath $archive -ExpectedArchiveSHA256 $hash -ProofRoot $proof -Confirm:$false).Status | Should -Be Hold
    Test-Path -LiteralPath $proof | Should -BeFalse
  }

  It 'excludes only an exact zero long DATA marker and refuses unsupported markers before writes' {
    # Pester 6 throws for a Get-Item call no -ParameterFilter matches; pass other calls through to the
    # captured real cmdlet with explicit parameters (a PSBoundParameters splat hangs in a default mock).
    # Only non -Stream calls reach this default, so it must not read $Stream: unbound, it resolves
    # dynamically to the function's own 'foreach ($stream ...)' variable.
    Mock Get-Item { & $script:realGetItem -LiteralPath $LiteralPath -Force:$Force -ErrorAction Stop }
    Mock Get-Item {
      & $script:realGetItem @PesterBoundParameters | Where-Object Stream -CNE ':$DATA'
      foreach ($marker in $script:markers) { $marker }
    } -ParameterFilter { $Stream -eq '*' }
    foreach ($markers in @(
      @([pscustomobject]@{Stream=':$DATA';Length=1L}),
      @([pscustomobject]@{Stream=':$DATA';Length=0}),
      @([pscustomobject]@{Stream=':$DATA';Length=0L},[pscustomobject]@{Stream=':$DATA';Length=0L}),
      @([pscustomobject]@{Stream=':$data';Length=0L})
    )) {
      $script:markers = $markers
      $r = New-GeneratedRemediationDirectoryArchive @writerArguments -Confirm:$false
      $r.Status | Should -Be Hold
      $r.ArchiveCreated | Should -BeFalse
    }
    $script:markers = @([pscustomobject]@{Stream=':$DATA';Length=0L})
    $r = New-GeneratedRemediationDirectoryArchive @writerArguments -Confirm:$false
    $r.Status | Should -Be Verified -Because ($r.Errors -join '; ')
    $r.NamedStreamCount | Should -Be 1
  }
  It 'refuses directory nested repository boundaries without child enumeration' {
    $null = New-Item -ItemType Directory -Path (Join-Path $source '.git')
    Mock Get-ChildItem { throw 'Child enumeration forbidden' }
    $r = New-GeneratedRemediationDirectoryArchive @writerArguments -Confirm:$false
    $r.Status | Should -Be Hold
    $r.ArchiveCreated | Should -BeFalse
    Should -Invoke Get-ChildItem -Times 0
  }
  It 'archives root named streams separately without acquiring descendant streams' {
    $writerArguments.RelativePath = '_generated'
    $rootDirectory = Join-Path $root '_generated'
    [IO.File]::WriteAllText($rootDirectory + ':root-note', 'root only')
    Mock Get-ChildItem { throw 'Child enumeration forbidden' }
    $created = New-GeneratedRemediationDirectoryArchive @writerArguments -Confirm:$false
    $created.Status | Should -Be Verified
    $created.Manifest.Streams.Count | Should -Be 1
    $created.Manifest.Streams[0].Name | Should -Be root-note
    $r = Restore-GeneratedRemediationDirectoryArchive -RootPath $root -ArchivePath $archive -ExpectedArchiveSHA256 $created.ArchiveSHA256 -ProofRoot $proof -Confirm:$false
    $r.Status | Should -Be Verified
    [IO.File]::ReadAllText($r.ProofPath + ':root-note') | Should -Be 'root only'
    Test-Path -LiteralPath (Join-Path $r.ProofPath 'directory') | Should -BeFalse
    Should -Invoke Get-ChildItem -Times 0
  }
  It 'refuses a redirecting source directory before acquisition' {
    $outside = Join-Path $run 'outside-source'
    $null = New-Item -ItemType Directory -Path $outside
    [IO.File]::WriteAllText((Join-Path $outside 'sentinel'), 'untouched')
    $link = Join-Path $root '_generated/link'
    $null = New-Item -ItemType Junction -Path $link -Target $outside
    try {
      $writerArguments.RelativePath = '_generated/link'
      $r = New-GeneratedRemediationDirectoryArchive @writerArguments -Confirm:$false
      $r.Status | Should -Be Hold
      $r.ArchiveCreated | Should -BeFalse
      (Get-Content -LiteralPath (Join-Path $outside 'sentinel') -Raw) | Should -Be untouched
    } finally { Remove-Item -LiteralPath $link -Force }
  }

  It 'composes only a new expected target into an existing proof root and never overwrites it' {
    $created = New-GeneratedRemediationDirectoryArchive @writerArguments -Confirm:$false
    $null = New-Item -ItemType Directory -Path (Join-Path $proof '_generated') -Force
    [IO.File]::WriteAllText((Join-Path $proof 'sentinel'),'keep')
    $r = Restore-GeneratedRemediationDirectoryArchive -RootPath $root -ArchivePath $archive -ExpectedArchiveSHA256 $created.ArchiveSHA256 -ProofRoot $proof -ComposeIntoProofRoot -ExpectedRelativePath $relative -Confirm:$false
    $r.Status | Should -Be Verified -Because ($r.Errors -join ';')
    $r.DirectoryRestoreVerified | Should -BeTrue
    $r.RestoreMode | Should -Be Composition
    (Get-FileHash -LiteralPath ($r.ProofPath + ':notes')).Hash | Should -Be (Get-FileHash -LiteralPath ($source + ':notes')).Hash
    $r2 = Restore-GeneratedRemediationDirectoryArchive -RootPath $root -ArchivePath $archive -ExpectedArchiveSHA256 $created.ArchiveSHA256 -ProofRoot $proof -ComposeIntoProofRoot -ExpectedRelativePath $relative -Confirm:$false
    $r2.Status | Should -Be Hold
    $r2.DirectoryRestoreVerified | Should -BeFalse
    (Get-Content -LiteralPath (Join-Path $proof 'sentinel') -Raw) | Should -Be keep
    (Get-FileHash -LiteralPath ($r.ProofPath + ':notes')).Hash | Should -Be (Get-FileHash -LiteralPath ($source + ':notes')).Hash
    $r.CustodyVerified | Should -BeFalse
    $r.ReadyForRemoval | Should -BeFalse
  }
  It 'checks composition path binding and existing parents before any target write' {
    $created = New-GeneratedRemediationDirectoryArchive @writerArguments -Confirm:$false
    $null = New-Item -ItemType Directory -Path (Join-Path $proof '_generated') -Force
    foreach($expected in @('_generated/other','')){
      $r = Restore-GeneratedRemediationDirectoryArchive -RootPath $root -ArchivePath $archive -ExpectedArchiveSHA256 $created.ArchiveSHA256 -ProofRoot $proof -ComposeIntoProofRoot -ExpectedRelativePath $expected -Confirm:$false
      $r.Status | Should -Be Hold
      $r.ProofCreated | Should -BeFalse
      Test-Path -LiteralPath (Join-Path $proof $relative) | Should -BeFalse
    }
    $withoutParent=Join-Path $run 'without-parent'
    $null=New-Item -ItemType Directory -Path $withoutParent
    $r = Restore-GeneratedRemediationDirectoryArchive -RootPath $root -ArchivePath $archive -ExpectedArchiveSHA256 $created.ArchiveSHA256 -ProofRoot $withoutParent -ComposeIntoProofRoot -ExpectedRelativePath $relative -Confirm:$false
    $r.Status | Should -Be Hold
    Test-Path -LiteralPath (Join-Path $withoutParent '_generated') | Should -BeFalse
  }
}

