param([object]$ReceiptSink)
$script:bundleReceiptSink = $ReceiptSink
BeforeAll {
  $script:bundleReceiptSink = $ReceiptSink
  $script:moduleRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
  foreach ($name in @('Get-GeneratedRemediationTreeCensus','New-GeneratedRemediationFileArchive',
    'Restore-GeneratedRemediationFileArchive','New-GeneratedRemediationDirectoryArchive','Restore-GeneratedRemediationDirectoryArchive',
    'New-GeneratedRemediationCustodyBundle')) { . (Join-Path $script:moduleRoot ('private/' + $name + '.ps1')) }
  $script:base = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../_generated/Sprint0016/Task16.84/CustodyBundleTests-v1'))
  $null = New-Item -ItemType Directory -Path $script:base -Force
  $cursor = $script:base
  while ($cursor) {
    $node = Get-Item -LiteralPath $cursor -Force
    if ($node.LinkType -or $node.Target) { throw 'Redirecting test root.' }
    $cursor = Split-Path -Parent $cursor
  }
  function Get-BundleFixtureCensus {
    [CmdletBinding()]
    param([string]$Boundary = $script:root)
    # Synthetic dependency envelope from an explicit fixture list, never a walker.
    $paths = if ($Boundary -cne $script:root -and $null -ne $script:proofFixturePaths) { $script:proofFixturePaths } else { $script:fixturePaths }
    $rows=@(foreach($relative in $paths){
      $item=& $script:realGetItem -LiteralPath (Join-Path $Boundary $relative) -Force
      [pscustomobject]@{RelativePath=$relative;Depth=[int]($relative.Split('/').Count-1)
        Kind=if($item.PSIsContainer){'Directory'}else{'File'};ReparseTag=$null
        Attributes=[long]$item.Attributes;LastWriteTicks=[long]$item.LastWriteTimeUtc.Ticks
        CreationTicks=[long]$item.CreationTimeUtc.Ticks;Length=if($item.PSIsContainer){$null}else{[long]$item.Length};Hold=$false}
    })
    $first=[pscustomobject]@{Rows=$rows;Holds=0}
    $second=[Management.Automation.PSSerializer]::Deserialize([Management.Automation.PSSerializer]::Serialize($first))
    [pscustomobject]@{SyntheticCensus=$true;Success=$true;Consistent=$true;StructuralInventoryComplete=$true;RootState='Present'
      Errors=@();FailedWalks=@();Binding=[pscustomobject]@{Root=$Boundary;RelativePath='_generated';MaxEntries=16;MaxDepth=8}
      Observations=@($first,$second)}
  }
  $script:realCensus = (Get-Command Get-GeneratedRemediationTreeCensus).ScriptBlock
  $script:realFileWriter = (Get-Command New-GeneratedRemediationFileArchive).ScriptBlock
  $script:realFileRestore = (Get-Command Restore-GeneratedRemediationFileArchive).ScriptBlock
  $script:realDirectoryWriter = (Get-Command New-GeneratedRemediationDirectoryArchive).ScriptBlock
  $script:realDirectoryRestore = (Get-Command Restore-GeneratedRemediationDirectoryArchive).ScriptBlock
  $script:realGetItem = Get-Command Get-Item -CommandType Cmdlet
}
Describe 'Finite independent per-entry custody bundle' {
  BeforeEach {
    $script:run = Join-Path $script:base ([guid]::NewGuid().ToString('N'))
    $script:root = Join-Path $script:run 'source'
    $script:generated = Join-Path $script:root '_generated'
    $script:sub = Join-Path $script:generated 'sub'
    $script:bundle = Join-Path $script:run 'bundle'
    $null = New-Item -ItemType Directory -Path $script:sub,(Join-Path $script:generated 'empty') -Force
    $script:file = Join-Path $script:generated 'file.bin'
    $script:emptyFile = Join-Path $script:sub 'empty.bin'
    [IO.File]::WriteAllBytes($script:file,[byte[]]@(0,1,255,17))
    [IO.File]::SetAttributes($script:file,[IO.FileAttributes]::Hidden)
    [IO.File]::WriteAllBytes($script:emptyFile,[byte[]]@())
    [IO.File]::WriteAllBytes($script:file+':notes',[byte[]]@(8,7,0,6))
    [IO.File]::WriteAllBytes($script:generated+':root-note',[byte[]]@(9,8,7,6))
    [IO.File]::WriteAllBytes($script:sub+':empty',[byte[]]@())
    [IO.File]::WriteAllBytes($script:sub+':'+[char]0x9644,[byte[]]@(9,0,255))
    $script:arguments = @{RootPath=$script:root;BundleRoot=$script:bundle;MaxEntries=16;MaxDepth=8;MaxBundlePayloadBytes=1024L}
    $script:before = (Get-FileHash -LiteralPath $script:file).Hash
    $script:fixturePaths=@('_generated','_generated/empty','_generated/file.bin','_generated/sub','_generated/sub/empty.bin')
    $script:proofFixturePaths=$null
    $script:census = Get-BundleFixtureCensus
    Mock Get-GeneratedRemediationTreeCensus { Get-BundleFixtureCensus -Boundary $RootPath }
  }
  AfterEach {
    $resolved = (Resolve-Path -LiteralPath $script:run).ProviderPath
    if (-not $resolved.StartsWith($script:base.TrimEnd('\') + '\',[StringComparison]::OrdinalIgnoreCase) -or
      (& $script:realGetItem -LiteralPath $resolved -Force).LinkType) { throw 'Cleanup escaped owned fixture.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force -ErrorAction Stop
  }
  It 'actually restores one mixed recovery tree and rechecks source streams with false approval flags' {
    $r = New-GeneratedRemediationCustodyBundle @arguments -Confirm:$false
    $r.Status | Should -Be Verified -Because ($r.Errors -join ';')
    $r.EntryProofCoverageComplete | Should -BeTrue
    if($null -ne $script:bundleReceiptSink){$script:bundleReceiptSink.Add($r)}
    $r.CoverageScope | Should -Be WholeTree
    @($r.IncludedRelativePaths).Count | Should -Be 5
    $r.ExpectedEntries | Should -Be 5
    $r.VerifiedEntries | Should -Be 5
    $r.PreflightPayloadBytes | Should -Be 15
    $r.VerifiedPayloadBytes | Should -Be 15
    @($r.Entries.ProofRoot | Select-Object -Unique).Count | Should -Be 1
    $r.CoherentTreeRestoreVerified | Should -BeTrue
    $r.AggregateSourceBytesRechecked | Should -BeTrue
    $r.SourceStreamVerification.Bytes | Should -Be 15
    $r.ProofStreamVerification.Bytes | Should -Be 15
    @($r.Entries | Where-Object RelativePath -CEQ '_generated').Count | Should -Be 1
    foreach ($entry in $r.Entries) {
      $entry.Verified | Should -BeTrue
      $entry.Restore.ProofPath | Should -Be (Join-Path $entry.ProofRoot $entry.RelativePath)
      foreach ($descriptor in $entry.Writer.Manifest.Streams) {
        $path = if ($descriptor.Name -ceq ':$DATA') { $entry.Restore.ProofPath } else { $entry.Restore.ProofPath + ':' + $descriptor.Name }
        (Get-FileHash -LiteralPath $path).Hash | Should -Be $descriptor.SHA256
      }
    }
    $rootProof = ($r.Entries | Where-Object RelativePath -CEQ '_generated').Restore.ProofPath
    Test-Path -LiteralPath (Join-Path $rootProof 'file.bin') | Should -BeTrue
    $actual=@('_generated') + @(Get-ChildItem -LiteralPath $rootProof -Recurse -Force | ForEach-Object { '_generated/' + [IO.Path]::GetRelativePath($rootProof,$_.FullName).Replace('\','/') })
    @($actual).Count | Should -Be 5
    foreach($path in $script:fixturePaths){$actual | Should -Contain $path}
    foreach ($flag in @('Approved','ReadyForRemoval','CustodyVerified','RootStreamsVerified','DirectoryStreamsVerified')) { $r.$flag | Should -BeFalse }
    (Get-FileHash -LiteralPath $file).Hash | Should -Be $before
  }
  It 'backs up only selected nested files and ancestor streams into the exact recovery tree' {
    $selectedFile = Join-Path $script:sub 'selected.bin'
    [IO.File]::WriteAllBytes($selectedFile,[byte[]]@(21,22))
    [IO.File]::WriteAllBytes($selectedFile+':empty',[byte[]]@())
    [IO.File]::WriteAllBytes($script:emptyFile+':notes',[byte[]]@(1,2,0,4))
    [IO.File]::WriteAllBytes($script:emptyFile+':empty',[byte[]]@())
    foreach ($sprint in @('Sprint0016','Sprint0017')) {
      $directory = Join-Path $script:generated $sprint
      $null = New-Item -ItemType Directory -Path $directory
      [IO.File]::WriteAllBytes((Join-Path $directory 'keep.bin'),[byte[]]::new(100))
      [IO.File]::WriteAllBytes($directory+':keep',[byte[]]::new(100))
      $script:fixturePaths += @("_generated/$sprint","_generated/$sprint/keep.bin")
    }
    $script:fixturePaths += '_generated/sub/selected.bin'
    $script:selected = @('_generated/sub/empty.bin','_generated/sub/selected.bin')
    $script:proofFixturePaths = @('_generated','_generated/sub') + $script:selected
    $script:streamAcquisitions = [Collections.Generic.List[string]]::new()
    Mock Get-Item {
      $path = [IO.Path]::GetFullPath([string]$LiteralPath)
      if ($path.StartsWith($script:root + '\',[StringComparison]::OrdinalIgnoreCase)) {
        $script:streamAcquisitions.Add($path)
        if ($path -cnotin @($script:generated,$script:sub,$script:emptyFile,(Join-Path $script:sub 'selected.bin'))) { throw 'Unselected source stream acquisition.' }
      }
      & $script:realGetItem @PesterBoundParameters
    } -ParameterFilter { $Stream -eq '*' }
    Mock New-GeneratedRemediationFileArchive {
      if ($RelativePath -cnotin $script:selected) { throw 'Unselected file writer.' }
      & $script:realFileWriter @PesterBoundParameters
    }
    $arguments.MaxBundlePayloadBytes = 13L
    $r = New-GeneratedRemediationCustodyBundle @arguments -RelativePaths $script:selected -Confirm:$false
    $r.Status | Should -Be Verified -Because ($r.Errors -join ';')
    $r.CoverageScope | Should -Be SelectedFilesAndAncestors
    ($r.RequestedRelativePaths -join '|') | Should -BeExactly ($script:selected -join '|')
    @($r.IncludedRelativePaths).Count | Should -Be 4
    foreach ($relative in $script:proofFixturePaths) { $r.IncludedRelativePaths | Should -Contain $relative }
    $r.ExpectedEntries | Should -Be 4
    $r.VerifiedEntries | Should -Be 4
    $r.PreflightPayloadBytes | Should -Be 13
    $r.VerifiedPayloadBytes | Should -Be 13
    $r.SourceStreamVerification.Bytes | Should -Be 13
    $r.ProofStreamVerification.Bytes | Should -Be 13
    $r.EntryProofCoverageComplete | Should -BeTrue
    $r.CoherentTreeRestoreVerified | Should -BeTrue
    $r.AggregateSourceBytesRechecked | Should -BeTrue
    $proofGenerated = Join-Path $r.ProofRoot '_generated'
    $actualPaths = @('_generated') + @(Get-ChildItem -LiteralPath $proofGenerated -Recurse -Force | ForEach-Object {
      '_generated/' + [IO.Path]::GetRelativePath($proofGenerated,$_.FullName).Replace('\','/')
    })
    @($actualPaths).Count | Should -Be 4
    foreach ($relative in $script:proofFixturePaths) { $actualPaths | Should -Contain $relative }
    $digests = @(foreach ($entry in $r.Entries) {
      foreach ($descriptor in $entry.Writer.Manifest.Streams) {
        $sourcePath = Join-Path $script:root $entry.RelativePath
        $proofPath = $entry.Restore.ProofPath
        if ($descriptor.Name -cne ':$DATA') { $sourcePath += ':'+$descriptor.Name; $proofPath += ':'+$descriptor.Name }
        $sourceHash = (Get-FileHash -LiteralPath $sourcePath).Hash
        $proofHash = (Get-FileHash -LiteralPath $proofPath).Hash
        $sourceHash | Should -Be $descriptor.SHA256
        $proofHash | Should -Be $descriptor.SHA256
        [pscustomobject]@{RelativePath=$entry.RelativePath;Name=$descriptor.Name;Bytes=$descriptor.Bytes;ManifestSHA256=$descriptor.SHA256;SourceSHA256=$sourceHash;ProofSHA256=$proofHash}
      }
    })
    $digests.Count | Should -Be 8
    @($script:streamAcquisitions | Select-Object -Unique).Count | Should -Be 4
    Should -Invoke New-GeneratedRemediationFileArchive -Times 2 -Exactly
    foreach ($flag in @('Approved','ReadyForRemoval','CustodyVerified','RootStreamsVerified','DirectoryStreamsVerified')) { $r.$flag | Should -BeFalse }
    $r | Add-Member -NotePropertyName SyntheticSelectionEvidence -NotePropertyValue ([pscustomobject]@{
      ActualProofPaths=$actualPaths;ActualStreamDigests=$digests
      SourceStreamAcquisitionPaths=@($script:streamAcquisitions | Select-Object -Unique)
      FullSourceCensusRows=@($r.InitialCensus.Observations[0].Rows).Count
      SelectedClosureOnly=$true;UnselectedSourceStreamInventoryOrWriterInvoked=$false
    })
    if ($null -ne $script:bundleReceiptSink) { $script:bundleReceiptSink.Add($r) }
  }

  It 'holds a small invalid absent directory or duplicate file selection before output' {
    foreach ($selection in @(
      @{Paths=@()}, @{Paths=@('_generated/../outside')}, @{Paths=@('_generated/missing.bin')},
      @{Paths=@('_generated/sub')}, @{Paths=@('_generated/file.bin','_generated/file.bin')},
      @{Paths=@('_generated/file.bin','_generated/FILE.bin')}
    )) {
      $r = New-GeneratedRemediationCustodyBundle @arguments -RelativePaths $selection.Paths -Confirm:$false
      $r.Status | Should -Be Hold
      $r.BundleCreated | Should -BeFalse
      Test-Path -LiteralPath $script:bundle | Should -BeFalse
    }
  }

  It 'holds selected source content drift after restore and retains partial backup output' {
    [IO.File]::WriteAllBytes($script:emptyFile+':notes',[byte[]]@(1,2,3,4))
    $script:proofFixturePaths = @('_generated','_generated/sub','_generated/sub/empty.bin')
    Mock Restore-GeneratedRemediationFileArchive {
      $receipt = & $script:realFileRestore @PesterBoundParameters
      $written = [IO.File]::GetLastWriteTimeUtc($script:emptyFile)
      $stream = [IO.File]::Open($script:emptyFile+':notes',[IO.FileMode]::Open,[IO.FileAccess]::Write,[IO.FileShare]::None)
      try { $stream.Write([byte[]]@(9,8,7,6),0,4) } finally { $stream.Dispose() }
      [IO.File]::SetLastWriteTimeUtc($script:emptyFile,$written)
      $receipt
    }
    $r = New-GeneratedRemediationCustodyBundle @arguments -RelativePaths '_generated/sub/empty.bin' -Confirm:$false
    $r.Status | Should -Be Hold
    $r.Errors -join ';' | Should -Match 'Verification stream content drift'
    $r.BundleCreated | Should -BeTrue
    $r.CoherentTreeRestoreVerified | Should -BeFalse
    $r.AggregateSourceBytesRechecked | Should -BeFalse
    Test-Path -LiteralPath $r.BundlePath | Should -BeTrue
    Test-Path -LiteralPath $r.ProofRoot | Should -BeTrue
  }

  It 'holds extra proof coverage outside the selected closure with outputs retained' {
    $script:proofFixturePaths = @('_generated','_generated/sub','_generated/sub/empty.bin','_generated/extra.bin')
    Mock Restore-GeneratedRemediationFileArchive {
      $receipt = & $script:realFileRestore @PesterBoundParameters
      [IO.File]::WriteAllBytes((Join-Path $ProofRoot '_generated/extra.bin'),[byte[]]@(5))
      $receipt
    }
    $r = New-GeneratedRemediationCustodyBundle @arguments -RelativePaths '_generated/sub/empty.bin' -Confirm:$false
    $r.Status | Should -Be Hold
    $r.Errors -join ';' | Should -Match 'recovery tree inventory mismatch'
    $r.BundleCreated | Should -BeTrue
    $r.EntryProofCoverageComplete | Should -BeFalse
    Test-Path -LiteralPath (Join-Path $r.ProofRoot '_generated/extra.bin') | Should -BeTrue
  }

  It 'plans with WhatIf without any bundle writes' {
    $r = New-GeneratedRemediationCustodyBundle @arguments -WhatIf
    $r.Status | Should -Be Skipped
    $r.PreflightPayloadBytes | Should -Be 15
    $r.BundleCreated | Should -BeFalse
    Test-Path -LiteralPath $bundle | Should -BeFalse
  }
  It 'enforces aggregate metadata budget before writers or bundle creation' {
    Mock New-GeneratedRemediationDirectoryArchive { throw 'No writer expected' }
    $arguments.MaxBundlePayloadBytes=14L
    $r = New-GeneratedRemediationCustodyBundle @arguments -Confirm:$false
    $r.Status | Should -Be Hold
    $r.Errors -join ';' | Should -Match 'budget'
    Test-Path -LiteralPath $bundle | Should -BeFalse
    Should -Invoke New-GeneratedRemediationDirectoryArchive -Times 0
  }
  It 'refuses malformed incomplete held aliased and wrongly bound census envelopes before writes' {
    Mock Get-GeneratedRemediationTreeCensus { $script:bad }
    foreach ($mode in @('SuccessType','Incomplete','FailedWalk','WrongRoot','MissingRoot','Alias','MissingParent','Held','ObservationDrift')) {
      $script:bad=[Management.Automation.PSSerializer]::Deserialize([Management.Automation.PSSerializer]::Serialize($script:census))
      switch ($mode) {
        SuccessType { $script:bad.Success='true' }
        Incomplete { $script:bad.StructuralInventoryComplete=$false }
        FailedWalk { $script:bad.FailedWalks=@([pscustomobject]@{Error='failed'}) }
        WrongRoot { $script:bad.Binding.Root=$script:run }
        MissingRoot { foreach($o in $script:bad.Observations){$o.Rows=@($o.Rows|Where-Object RelativePath -CNE '_generated')} }
        Alias { foreach($o in $script:bad.Observations){$duplicate=$o.Rows[0].PSObject.Copy();$duplicate.RelativePath='_GENERATED';$o.Rows+=@($duplicate)} }
        MissingParent { foreach($o in $script:bad.Observations){$o.Rows=@($o.Rows|Where-Object RelativePath -CNE '_generated/sub')} }
        Held { $script:bad.Observations[0].Rows[0].Hold=$true }
        ObservationDrift { $script:bad.Observations[1].Rows[0].CreationTicks++ }
      }
      $r = New-GeneratedRemediationCustodyBundle @arguments -Confirm:$false
      $r.Status | Should -Be Hold -Because $mode
      $r.BundleCreated | Should -BeFalse
      Test-Path -LiteralPath $bundle | Should -BeFalse
    }
    Should -Invoke Get-GeneratedRemediationTreeCensus -ParameterFilter { $AllowVerifiedCloudDirectoryMetadata } -Times 0
  }
  It 'refuses existing overlapping redirecting or unsafe output paths preserving sentinels' {
    $null = New-Item -ItemType Directory -Path $bundle
    [IO.File]::WriteAllText((Join-Path $bundle 'sentinel'),'keep')
    (New-GeneratedRemediationCustodyBundle @arguments -Confirm:$false).Status | Should -Be Hold
    (Get-Content -LiteralPath (Join-Path $bundle 'sentinel') -Raw) | Should -Be keep
    foreach($path in @((Join-Path $root 'new-bundle'),(Join-Path $run 'CONIN$.zip'),(Join-Path $run 'BUNDLE~1'))){
      $arguments.BundleRoot=$path
      (New-GeneratedRemediationCustodyBundle @arguments -Confirm:$false).Status | Should -Be Hold
    }
    $outside=Join-Path $run 'outside';$link=Join-Path $run 'link'
    $null=New-Item -ItemType Directory -Path $outside
    $null=New-Item -ItemType Junction -Path $link -Target $outside
    try {
      $arguments.BundleRoot=Join-Path $link 'new'
      (New-GeneratedRemediationCustodyBundle @arguments -Confirm:$false).Status | Should -Be Hold
      Test-Path -LiteralPath (Join-Path $outside 'new') | Should -BeFalse
    } finally { Remove-Item -LiteralPath $link -Force }
  }
  It 'holds pre-entry stream-set drift before invoking the first writer' {
    $script:calls=0
    Mock Get-Item {
      $script:calls++
      if($script:calls -eq 6){[IO.File]::WriteAllText($script:generated+':late','new')}
      & $script:realGetItem @PesterBoundParameters
    } -ParameterFilter { $Stream -eq '*' }
    Mock New-GeneratedRemediationDirectoryArchive { throw 'No writer expected' }
    $r=New-GeneratedRemediationCustodyBundle @arguments -Confirm:$false
    $r.Status | Should -Be Hold
    $r.Errors -join ';' | Should -Match 'drift|differs'
    $r.BundleCreated | Should -BeTrue
    $r.Entries.Count | Should -Be 0
    Test-Path -LiteralPath $bundle | Should -BeTrue
    Should -Invoke New-GeneratedRemediationDirectoryArchive -Times 0
  }
  It 'stops on helper Hold and retains prior independent proof and source' {
    Mock New-GeneratedRemediationFileArchive { [pscustomobject]@{Status='Hold';Errors=@('synthetic refusal')} }
    $r=New-GeneratedRemediationCustodyBundle @arguments -Confirm:$false
    $r.Status | Should -Be Hold
    $r.EntryProofCoverageComplete | Should -BeFalse
    $r.VerifiedEntries | Should -Be 3
    Test-Path -LiteralPath $r.Entries[0].Restore.ProofPath | Should -BeTrue
    Test-Path -LiteralPath $bundle | Should -BeTrue
    (Get-FileHash -LiteralPath $file).Hash | Should -Be $before
  }
  It 'refuses substituted writer paths and never starts its restore' {
    Mock New-GeneratedRemediationDirectoryArchive {
      $r=& $script:realDirectoryWriter @PesterBoundParameters
      $r.ArchivePath=$script:file
      $r
    }
    Mock Restore-GeneratedRemediationDirectoryArchive { throw 'No restore expected' }
    $r=New-GeneratedRemediationCustodyBundle @arguments -Confirm:$false
    $r.Status | Should -Be Hold
    $r.VerifiedEntries | Should -Be 0
    Should -Invoke Restore-GeneratedRemediationDirectoryArchive -Times 0
    Test-Path -LiteralPath (Join-Path $bundle 'archives/0000.zip') | Should -BeTrue
  }
  It 'refuses substituted proof receipt paths and retains its partial proof' {
    Mock Restore-GeneratedRemediationDirectoryArchive {
      $r=& $script:realDirectoryRestore @PesterBoundParameters
      $r.ProofPath=$script:generated
      $r
    }
    $r=New-GeneratedRemediationCustodyBundle @arguments -Confirm:$false
    $r.Status | Should -Be Hold
    $r.VerifiedEntries | Should -Be 0
    Test-Path -LiteralPath (Join-Path $bundle 'recovery/_generated') | Should -BeTrue
  }
  It 'refuses a structurally changed final census after retaining all entry proofs' {
    $script:calls=0
    Mock Get-GeneratedRemediationTreeCensus {
      $script:calls++
      if($script:calls -eq 2){$null=New-Item -ItemType Directory -Path (Join-Path $script:generated 'late');$script:fixturePaths+=@('_generated/late')}
      Get-BundleFixtureCensus -Boundary $RootPath
    }
    $r=New-GeneratedRemediationCustodyBundle @arguments -Confirm:$false
    $r.Status | Should -Be Hold
    $r.VerifiedEntries | Should -Be 5
    $r.EntryProofCoverageComplete | Should -BeFalse
    $r.Errors -join ';' | Should -Match 'structural drift'
    Test-Path -LiteralPath $bundle | Should -BeTrue
  }

  It 'refuses malformed oversized and wrong-kind writer receipts before restore or next entry' {
    Mock New-GeneratedRemediationDirectoryArchive {
      $r=& $script:realDirectoryWriter @PesterBoundParameters
      switch($script:receiptMode){
        FlagType { $r.DirectoryArchiveVerified='true' }
        SourceKind { $r.Manifest.SourceKind='File' }
        SourceRoot { $r.Manifest.SourceRoot=$script:run }
        RelativePath { $r.Manifest.RelativePath='_generated/other' }
        Hash { $r.ArchiveSHA256='0'*64 }
        PayloadBudget { $r.Manifest.Streams[0].Bytes=1073741825L }
        NamedCount { $r.NamedStreamCount=99 }
        Multiple { $r }
      }
      $r
    }
    Mock Restore-GeneratedRemediationDirectoryArchive { throw 'No restore expected' }
    foreach($mode in @('FlagType','SourceKind','SourceRoot','RelativePath','Hash','PayloadBudget','NamedCount','Multiple')){
      $script:receiptMode=$mode
      $arguments.BundleRoot=Join-Path $run ('bundle-'+$mode)
      $r=New-GeneratedRemediationCustodyBundle @arguments -Confirm:$false
      $r.Status | Should -Be Hold -Because $mode
      $r.VerifiedEntries | Should -Be 0
      $r.EntryProofCoverageComplete | Should -BeFalse
      $r.Entries.Count | Should -Be 1
      Test-Path -LiteralPath $r.Entries[0].ArchivePath | Should -BeTrue
    }
    Should -Invoke Restore-GeneratedRemediationDirectoryArchive -Times 0
  }
  It 'refuses unsupported stream metadata and entry limits before bundle writes' {
    Mock Get-Item {
      & $script:realGetItem @PesterBoundParameters
      switch($script:streamMode){
        Bytes { [pscustomobject]@{Stream='huge';Length=67108865L} }
        Type { [pscustomobject]@{Stream='length-type';Length='1'} }
        Alias { [pscustomobject]@{Stream='ROOT-NOTE';Length=4L} }
        Count { foreach($i in 1..65){[pscustomobject]@{Stream="extra$i";Length=0L}} }
        Marker { [pscustomobject]@{Stream=':$DATA';Length=1L} }
      }
    } -ParameterFilter { $Stream -eq '*' -and $LiteralPath -eq $script:generated }
    foreach($mode in @('Bytes','Type','Alias','Count','Marker')){
      $script:streamMode=$mode
      $r=New-GeneratedRemediationCustodyBundle @arguments -Confirm:$false
      $r.Status | Should -Be Hold -Because $mode
      $r.BundleCreated | Should -BeFalse
      Test-Path -LiteralPath $bundle | Should -BeFalse
    }
  }

  It 'retains the real default-census ancestry refusal without native opt-in or bundle creation' {
    Mock Get-GeneratedRemediationTreeCensus { & $script:realCensus @PesterBoundParameters }
    $actual=& $script:realCensus -RootPath $root -MaxEntries 16 -MaxDepth 8
    $actual.Success | Should -BeFalse
    $actual.StructuralInventoryComplete | Should -BeFalse
    $actual.Errors -join ';' | Should -Match 'Unsafe or non-directory ancestor'
    $r=New-GeneratedRemediationCustodyBundle @arguments -Confirm:$false
    $r.Status | Should -Be Hold
    $r.BundleCreated | Should -BeFalse
    Test-Path -LiteralPath $bundle | Should -BeFalse
    if($null -ne $script:bundleReceiptSink){$script:bundleReceiptSink.Add([pscustomobject]@{PlatformPrecondition='Default-census ancestry refused in owned Dropbox fixture';ActualCensus=$actual;Bundle=$r})}
  }
  It 'holds a late source content change even when its length and timestamp are restored' {
    $script:calls=0
    Mock Get-GeneratedRemediationTreeCensus {
      $script:calls++
      if($script:calls -eq 2){
        $written=[IO.File]::GetLastWriteTimeUtc($script:file)
        $writer=[IO.File]::Open($script:file,[IO.FileMode]::Open,[IO.FileAccess]::Write,[IO.FileShare]::None)
        try { $writer.Write([byte[]]@(9,8,7,6),0,4) } finally { $writer.Dispose() }
        [IO.File]::SetLastWriteTimeUtc($script:file,$written)
      }
      Get-BundleFixtureCensus -Boundary $RootPath
    }
    $r=New-GeneratedRemediationCustodyBundle @arguments -Confirm:$false
    $r.Status | Should -Be Hold
    $r.Errors -join ';' | Should -Match 'content drift'
    $r.AggregateSourceBytesRechecked | Should -BeFalse
    $r.CoherentTreeRestoreVerified | Should -BeFalse
    $r.CustodyVerified | Should -BeFalse
    (Get-FileHash -LiteralPath $file).Hash | Should -Not -Be $before
    $fileProof=($r.Entries|Where-Object RelativePath -CEQ '_generated/file.bin').Restore.ProofPath
    (Get-FileHash -LiteralPath $fileProof).Hash | Should -Be $before
  }
  It 'enforces explicit census entry and depth bounds before writes' {
    Mock Get-GeneratedRemediationTreeCensus {
      $r=Get-BundleFixtureCensus
      $r.Binding.MaxEntries=$MaxEntries
      $r.Binding.MaxDepth=$MaxDepth
      $r
    }
    $arguments.MaxEntries=4
    (New-GeneratedRemediationCustodyBundle @arguments -Confirm:$false).Status | Should -Be Hold
    Test-Path -LiteralPath $bundle | Should -BeFalse
    $arguments.MaxEntries=16
    $arguments.MaxDepth=1
    (New-GeneratedRemediationCustodyBundle @arguments -Confirm:$false).Status | Should -Be Hold
    Test-Path -LiteralPath $bundle | Should -BeFalse
  }

  It 'holds changed source named content or stream membership after restoration' {
    $script:calls=0
    Mock Get-GeneratedRemediationTreeCensus {
      $script:calls++
      if($script:calls -eq 2){
        $written=[IO.File]::GetLastWriteTimeUtc($script:file)
        [IO.File]::WriteAllBytes($script:file+':notes',[byte[]]@(6,0,7,8))
        [IO.File]::SetLastWriteTimeUtc($script:file,$written)
      }
      Get-BundleFixtureCensus -Boundary $RootPath
    }
    $r=New-GeneratedRemediationCustodyBundle @arguments -Confirm:$false
    $r.Status | Should -Be Hold
    $r.Errors -join ';' | Should -Match 'content drift'
    $r.AggregateSourceBytesRechecked | Should -BeFalse
    $r.CustodyVerified | Should -BeFalse
  }
  It 'holds an extra source stream at the final verification' {
    $script:calls=0
    Mock Get-GeneratedRemediationTreeCensus {
      $script:calls++
      if($script:calls -eq 2){[IO.File]::WriteAllText($script:file+':late','new')}
      Get-BundleFixtureCensus -Boundary $RootPath
    }
    $r=New-GeneratedRemediationCustodyBundle @arguments -Confirm:$false
    $r.Status | Should -Be Hold
    $r.AggregateSourceBytesRechecked | Should -BeFalse
    $r.CustodyVerified | Should -BeFalse
  }
  It 'holds modified recovery bytes or extra recovery entries' {
    Mock Get-GeneratedRemediationTreeCensus {
      if($RootPath -cne $script:root -and -not $script:proofChanged){
        $script:proofChanged=$true
        $path=Join-Path $RootPath '_generated/file.bin'
        if($script:proofMode -eq 'Bytes'){[IO.File]::WriteAllBytes($path,[byte[]]@(4,3,2,1))}
        elseif($script:proofMode -eq 'Archive'){
          $archive=Join-Path $script:bundle 'archives/0000.zip'
          $writer=[IO.File]::Open($archive,[IO.FileMode]::Open,[IO.FileAccess]::Write,[IO.FileShare]::None)
          try { $writer.Position=$writer.Length-1; $writer.WriteByte(123) } finally { $writer.Dispose() }
        }
        elseif($script:proofMode -eq 'MissingStream'){[IO.File]::Delete((Join-Path $RootPath '_generated/sub')+':empty')}
        else {
          [IO.File]::WriteAllText((Join-Path $RootPath '_generated/extra.bin'),'extra')
          $script:proofFixturePaths=@($script:fixturePaths)+@('_generated/extra.bin')
        }
      }
      Get-BundleFixtureCensus -Boundary $RootPath
    }
    foreach($mode in @('Bytes','ExtraEntry','Archive','MissingStream')){
      $script:proofMode=$mode;$script:proofChanged=$false;$script:proofFixturePaths=$null
      $script:bundle=Join-Path $run ('bundle-'+$mode);$arguments.BundleRoot=$script:bundle
      $r=New-GeneratedRemediationCustodyBundle @arguments -Confirm:$false
      $r.Status | Should -Be Hold -Because $mode
      $r.CoherentTreeRestoreVerified | Should -BeFalse
      $r.CustodyVerified | Should -BeFalse
      Test-Path -LiteralPath $r.ProofRoot | Should -BeTrue
    }
  }

  It 'forwards the existing census option explicitly as false or true on all five calls' {
    Mock Get-GeneratedRemediationTreeCensus {
      Get-BundleFixtureCensus -Boundary $RootPath
    }
    $arguments.BundleRoot=Join-Path $run 'default-option'
    $default=New-GeneratedRemediationCustodyBundle @arguments -Confirm:$false
    $default.Status | Should -Be Verified -Because ($default.Errors -join ';')
    Should -Invoke Get-GeneratedRemediationTreeCensus -Times 5 -Exactly -ParameterFilter {
      $PesterBoundParameters.ContainsKey('AllowVerifiedCloudDirectoryMetadata') -and -not [bool]$AllowVerifiedCloudDirectoryMetadata
    }
    $arguments.BundleRoot=Join-Path $run 'enabled-option'
    $enabled=New-GeneratedRemediationCustodyBundle @arguments -AllowVerifiedCloudDirectoryMetadata -Confirm:$false
    $enabled.Status | Should -Be Verified -Because ($enabled.Errors -join ';')
    Should -Invoke Get-GeneratedRemediationTreeCensus -Times 5 -Exactly -ParameterFilter {
      $PesterBoundParameters.ContainsKey('AllowVerifiedCloudDirectoryMetadata') -and [bool]$AllowVerifiedCloudDirectoryMetadata
    }
  }
}
