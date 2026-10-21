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
    param()
    # Synthetic dependency envelope from an explicit fixture list, never a walker.
    $rows=@(foreach($relative in $script:fixturePaths){
      $item=& $script:realGetItem -LiteralPath (Join-Path $script:root $relative) -Force
      [pscustomobject]@{RelativePath=$relative;Depth=[int]($relative.Split('/').Count-1)
        Kind=if($item.PSIsContainer){'Directory'}else{'File'};ReparseTag=$null
        Attributes=[long]$item.Attributes;LastWriteTicks=[long]$item.LastWriteTimeUtc.Ticks
        CreationTicks=[long]$item.CreationTimeUtc.Ticks;Length=if($item.PSIsContainer){$null}else{[long]$item.Length};Hold=$false}
    })
    $first=[pscustomobject]@{Rows=$rows;Holds=0}
    $second=[Management.Automation.PSSerializer]::Deserialize([Management.Automation.PSSerializer]::Serialize($first))
    [pscustomobject]@{SyntheticCensus=$true;Success=$true;Consistent=$true;StructuralInventoryComplete=$true;RootState='Present'
      Errors=@();FailedWalks=@();Binding=[pscustomobject]@{Root=$script:root;RelativePath='_generated';MaxEntries=16;MaxDepth=8}
      Observations=@($first,$second)}
  }
  $script:realCensus = (Get-Command Get-GeneratedRemediationTreeCensus).ScriptBlock
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
    [IO.File]::WriteAllBytes($script:emptyFile,[byte[]]@())
    [IO.File]::WriteAllBytes($script:file+':notes',[byte[]]@(8,7,0,6))
    [IO.File]::WriteAllBytes($script:generated+':root-note',[byte[]]@(9,8,7,6))
    [IO.File]::WriteAllBytes($script:sub+':empty',[byte[]]@())
    [IO.File]::WriteAllBytes($script:sub+':'+[char]0x9644,[byte[]]@(9,0,255))
    $script:arguments = @{RootPath=$script:root;BundleRoot=$script:bundle;MaxEntries=16;MaxDepth=8;MaxBundlePayloadBytes=1024L}
    $script:before = (Get-FileHash -LiteralPath $script:file).Hash
    $script:fixturePaths=@('_generated','_generated/empty','_generated/file.bin','_generated/sub','_generated/sub/empty.bin')
    $script:census = Get-BundleFixtureCensus
    Mock Get-GeneratedRemediationTreeCensus { Get-BundleFixtureCensus }
  }
  AfterEach {
    $resolved = (Resolve-Path -LiteralPath $script:run).ProviderPath
    if (-not $resolved.StartsWith($script:base.TrimEnd('\') + '\',[StringComparison]::OrdinalIgnoreCase) -or
      (& $script:realGetItem -LiteralPath $resolved -Force).LinkType) { throw 'Cleanup escaped owned fixture.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force -ErrorAction Stop
  }
  It 'actually archives and restores every mixed-tree entry with distinct proof roots and false global flags' {
    $r = New-GeneratedRemediationCustodyBundle @arguments -Confirm:$false
    $r.Status | Should -Be Verified -Because ($r.Errors -join ';')
    $r.EntryProofCoverageComplete | Should -BeTrue
    if($null -ne $script:bundleReceiptSink){$script:bundleReceiptSink.Add($r)}
    $r.ExpectedEntries | Should -Be 5
    $r.VerifiedEntries | Should -Be 5
    $r.PreflightPayloadBytes | Should -Be 15
    $r.VerifiedPayloadBytes | Should -Be 15
    @($r.Entries.ProofRoot | Select-Object -Unique).Count | Should -Be 5
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
    Test-Path -LiteralPath (Join-Path $rootProof 'file.bin') | Should -BeFalse
    foreach ($flag in @('Approved','ReadyForRemoval','CustodyVerified','RootStreamsVerified','DirectoryStreamsVerified',
      'CoherentTreeRestoreVerified','AggregateSourceBytesRechecked')) { $r.$flag | Should -BeFalse }
    (Get-FileHash -LiteralPath $file).Hash | Should -Be $before
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
    $r.VerifiedEntries | Should -Be 2
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
    Test-Path -LiteralPath (Join-Path $bundle 'proofs/0000/_generated') | Should -BeTrue
  }
  It 'refuses a structurally changed final census after retaining all entry proofs' {
    $script:calls=0
    Mock Get-GeneratedRemediationTreeCensus {
      $script:calls++
      if($script:calls -eq 2){$null=New-Item -ItemType Directory -Path (Join-Path $script:generated 'late');$script:fixturePaths+=@('_generated/late')}
      Get-BundleFixtureCensus
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
  It 'does not turn late content-only changes into aggregate or coherent restore claims' {
    $script:calls=0
    Mock Get-GeneratedRemediationTreeCensus {
      $script:calls++
      if($script:calls -eq 2){
        $written=[IO.File]::GetLastWriteTimeUtc($script:file)
        [IO.File]::WriteAllBytes($script:file,[byte[]]@(9,8,7,6))
        [IO.File]::SetLastWriteTimeUtc($script:file,$written)
      }
      Get-BundleFixtureCensus
    }
    $r=New-GeneratedRemediationCustodyBundle @arguments -Confirm:$false
    $r.Status | Should -Be Verified -Because ($r.Errors -join ';')
    $r.EntryProofCoverageComplete | Should -BeTrue
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
}
