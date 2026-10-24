BeforeAll {
  . (Join-Path $PSScriptRoot '../../private/Get-GeneratedRemediationTreeCensus.ps1')
  . (Join-Path $PSScriptRoot '../../private/Get-GeneratedRemediationPathMetadata.ps1')
  $script:fixtureBase = 'D:/ATAPArtifacts/_generated/GeneratedFolderRemediation/Sprint0016/TreeCensus/CloudMetadata/DocumentedTags/' + [guid]::NewGuid().ToString('N')
  $script:getItemCommand = Get-Command Microsoft.PowerShell.Management\Get-Item
  $script:getChildrenCommand = Get-Command Microsoft.PowerShell.Management\Get-ChildItem
}
Describe 'Bounded structural tree census' {
  BeforeEach {
    $script:fixture = $fixtureBase + '/' + [guid]::NewGuid().ToString('N').Substring(0, 8)
    $null = New-Item -ItemType Directory -Path "$fixture/_generated" -Force
    Mock Get-Item { & $script:getItemCommand -LiteralPath $LiteralPath -Force -ErrorAction Stop }
    Mock Get-ChildItem { & $script:getChildrenCommand -LiteralPath $LiteralPath -Force -ErrorAction Stop }
  }
  It 'returns one result and two matching structural observations for an empty root' {
    $results = @(Get-GeneratedRemediationTreeCensus $fixture)
    $results.Count | Should -Be 1
    $result = $results[0]
    $result.Success | Should -BeTrue
    $result.RootState | Should -Be 'Present'
    $result.StructuralInventoryComplete | Should -BeTrue
    $result.Observations.Count | Should -Be 2
    $result.Observations[0].Rows.Count | Should -Be 1
    $result.InventoryComplete | Should -BeFalse
    $result.ReadyForManifest | Should -BeFalse
    $result.CustodyVerified | Should -BeFalse
  }
  It 'distinguishes a missing root from an empty root' {
    $missing = "$fixture/no-generated"
    $null = New-Item -ItemType Directory -Path $missing
    $result = Get-GeneratedRemediationTreeCensus $missing
    $result.Success | Should -BeFalse
    $result.RootState | Should -Be 'Missing'
    $result.Observations.Count | Should -Be 0
  }
  It 'includes hidden Unicode long paths and preserves contents and streams' {
    $deep = '_generated/' + ('longdirectory012345/' * 10) + 'space ü'
    $null = New-Item -ItemType Directory -Path "$fixture/$deep" -Force
    $path = "$fixture/$deep/data.txt"
    [IO.File]::WriteAllText($path, 'content')
    [IO.File]::WriteAllText($path + ':notes', 'ADS')
    [IO.File]::SetAttributes($path, [IO.FileAttributes]::Hidden)
    $before = (Get-FileHash -LiteralPath $path).Hash
    $adsBefore = (Get-FileHash -LiteralPath ($path + ':notes')).Hash
    $result = Get-GeneratedRemediationTreeCensus $fixture
    $result.StructuralInventoryComplete | Should -BeTrue
    $result.Observations[0].Rows.RelativePath | Should -Contain ($deep + '/data.txt')
    (Get-FileHash -LiteralPath $path).Hash | Should -Be $before
    (Get-FileHash -LiteralPath ($path + ':notes')).Hash | Should -Be $adsBefore
  }
  It 'can census metadata while file data is exclusively locked' {
    $path = "$fixture/_generated/locked"
    [IO.File]::WriteAllText($path, 'data')
    $handle = [IO.File]::Open($path, 'Open', 'ReadWrite', 'None')
    try { (Get-GeneratedRemediationTreeCensus $fixture).StructuralInventoryComplete | Should -BeTrue }
    finally { $handle.Dispose() }
  }
  It 'rejects malformed root syntax without filesystem probes' {
    foreach ($root in @('\\do-not-contact.invalid\share', '\\?\C:\temp', 'C:relative', 'C:/NUL', 'C:/a/../b')) {
      (Get-GeneratedRemediationTreeCensus $root).Success | Should -BeFalse
    }
    Should -Invoke Get-Item -Times 0
    Should -Invoke Get-ChildItem -Times 0
  }
  It 'refuses an unsafe ancestor before descendant access' {
    Mock Get-Item { [pscustomobject]@{Attributes=[IO.FileAttributes]::ReparsePoint;LinkTarget='do-not-follow';PSIsContainer=$true} } -ParameterFilter { $LiteralPath.TrimEnd('\','/') -eq $script:fixture.Replace('/','\') }
    (Get-GeneratedRemediationTreeCensus $fixture).Success | Should -BeFalse
    Should -Invoke Get-ChildItem -Times 0
  }
  It 'holds a child junction without descending into its target' {
    $outside = "$fixture/outside"
    $null = New-Item -ItemType Directory -Path $outside
    [IO.File]::WriteAllText("$outside/never-read", 'preserve')
    $null = New-Item -ItemType Junction -Path "$fixture/_generated/link" -Target $outside
    $result = Get-GeneratedRemediationTreeCensus $fixture
    $result.Success | Should -BeTrue
    $result.StructuralInventoryComplete | Should -BeFalse
    ($result.Observations[0].Rows | Where-Object RelativePath -EQ '_generated/link').Kind | Should -Be 'RedirectingLink'
    Should -Invoke Get-ChildItem -Times 0 -ParameterFilter { $LiteralPath -like '*link*' -or $LiteralPath -like '*outside*' }
  }
  It 'holds a redirecting target root without reading children' {
    Mock Get-Item { [pscustomobject]@{Attributes=[IO.FileAttributes]::ReparsePoint;LinkTarget='do-not-follow';PSIsContainer=$true;LastWriteTimeUtc=[datetime]::MinValue;CreationTimeUtc=[datetime]::MinValue} } -ParameterFilter { $LiteralPath.Replace('\','/') -eq "$script:fixture/_generated" }
    $result = Get-GeneratedRemediationTreeCensus $fixture
    $result.StructuralInventoryComplete | Should -BeFalse
    $result.Observations[0].Rows[0].Kind | Should -Be 'RedirectingLink'
    Should -Invoke Get-ChildItem -Times 0 -ParameterFilter { $LiteralPath -like '*_generated' }
  }
  It 'holds nested Git without entering .git or siblings' {
    $null = New-Item -ItemType Directory -Path "$fixture/_generated/nested/.git" -Force
    $null = New-Item -ItemType Directory -Path "$fixture/_generated/nested/child" -Force
    $result = Get-GeneratedRemediationTreeCensus $fixture
    $result.StructuralInventoryComplete | Should -BeFalse
    ($result.Observations[0].Rows | Where-Object RelativePath -EQ '_generated/nested').Kind | Should -Be 'NestedRepository'
    Should -Invoke Get-ChildItem -Times 0 -ParameterFilter { $LiteralPath -like '*.git*' -or $LiteralPath -like '*nested*child*' }
  }
  It 'holds a possible bare repository by names without reading its controls' {
    $null = New-Item -ItemType Directory -Path "$fixture/_generated/bare/objects", "$fixture/_generated/bare/refs" -Force
    [IO.File]::WriteAllText("$fixture/_generated/bare/HEAD", 'not inspected')
    $result = Get-GeneratedRemediationTreeCensus $fixture
    $result.StructuralInventoryComplete | Should -BeFalse
    ($result.Observations[0].Rows | Where-Object RelativePath -EQ '_generated/bare').Kind | Should -Be 'PossibleBareRepository'
    Should -Invoke Get-ChildItem -Times 0 -ParameterFilter { $LiteralPath -like '*objects*' -or $LiteralPath -like '*refs*' }
  }
  It 'fails closed on entry and depth limits with partial rows retained' {
    $null = New-Item -ItemType Directory -Path "$fixture/_generated/a/b" -Force
    foreach ($limits in @(@{MaxEntries=1}, @{MaxDepth=1})) {
      $result = Get-GeneratedRemediationTreeCensus $fixture @limits
      $result.Success | Should -BeFalse
      $result.StructuralInventoryComplete | Should -BeFalse
      $result.FailedWalks.Count | Should -Be 1
      $result.FailedWalks[0].PartialRows.Count | Should -BeGreaterThan 0
    }
  }
  It 'rejects case aliases and invalid child names rather than choosing a row' {
    foreach ($mode in @('alias','invalid')) {
      $script:censusMode=$mode
      Mock Get-ChildItem {
        if ($script:censusMode -eq 'alias') { [pscustomobject]@{Name='data'};[pscustomobject]@{Name='DATA'} }
        else { [pscustomobject]@{Name='../escape'} }
      } -ParameterFilter { $LiteralPath -like '*_generated' }
      $result = Get-GeneratedRemediationTreeCensus $fixture
      $result.Success | Should -BeFalse
      $result.StructuralInventoryComplete | Should -BeFalse
    }
  }
  It 'does not convert partial enumeration failure to empty success' {
    Mock Get-ChildItem { [pscustomobject]@{Name='partial'}; throw [InvalidOperationException]::new('partial enumeration') } -ParameterFilter { $LiteralPath -like '*_generated' }
    $result = Get-GeneratedRemediationTreeCensus $fixture
    $result.Success | Should -BeFalse
    $result.Observations.Count | Should -Be 0
    $result.Errors[0] | Should -Match 'partial enumeration'
  }
  It 'retains exhausted access errors and never reports an empty tree' {
    Mock Start-Sleep { }
    Mock Get-ChildItem { throw [UnauthorizedAccessException]::new('locked') } -ParameterFilter { $LiteralPath -like '*_generated' }
    $result = Get-GeneratedRemediationTreeCensus $fixture
    $result.Success | Should -BeFalse
    $result.Attempts.Count | Should -Be 3
    $result.FailedWalks.Count | Should -Be 3
    Should -Invoke Start-Sleep -Times 1 -ParameterFilter { $Milliseconds -eq 500 }
    Should -Invoke Start-Sleep -Times 1 -ParameterFilter { $Milliseconds -eq 1000 }
  }
  It 'retries transient access but retains an incomplete verdict after any failed walk' {
    $script:reads=0
    Mock Start-Sleep { }
    Mock Get-ChildItem {
      $script:reads++
      if ($script:reads -eq 1) { throw [UnauthorizedAccessException]::new('transient') }
      & $script:getChildrenCommand -LiteralPath $LiteralPath -Force -ErrorAction Stop
    } -ParameterFilter { $LiteralPath -like '*_generated' }
    $result = Get-GeneratedRemediationTreeCensus $fixture
    $result.Success | Should -BeTrue
    $result.StructuralInventoryComplete | Should -BeFalse
    $result.FailedWalks.Count | Should -Be 1
    $result.Observations.Count | Should -Be 2
  }
  It 'detects entry-set drift even when directory write time is restored' {
    $script:reads=0
    $script:originalTime=[IO.Directory]::GetLastWriteTimeUtc("$fixture/_generated")
    Mock Get-ChildItem {
      $script:reads++
      if ($script:reads -eq 2) {
        [IO.File]::WriteAllText("$script:fixture/_generated/new", 'new')
        [IO.Directory]::SetLastWriteTimeUtc("$script:fixture/_generated", $script:originalTime)
      }
      & $script:getChildrenCommand -LiteralPath $LiteralPath -Force -ErrorAction Stop
    } -ParameterFilter { $LiteralPath -like '*_generated' }
    $result=Get-GeneratedRemediationTreeCensus $fixture
    $result.Success | Should -BeFalse
    $result.Errors[0] | Should -Match 'Structural drift'
  }
  It 'holds unknown reparse and encrypted entries without descending' {
    Mock Get-ChildItem {
      foreach ($kind in @('ReparsePoint','Encrypted')) {
        [pscustomobject]@{Name=$kind;Attributes=[IO.FileAttributes]$kind;LinkTarget=$null;PSIsContainer=$true;LastWriteTimeUtc=[datetime]::MinValue;CreationTimeUtc=[datetime]::MinValue}
      }
    } -ParameterFilter { $LiteralPath -like '*_generated' }
    $result=Get-GeneratedRemediationTreeCensus $fixture
    $result.StructuralInventoryComplete | Should -BeFalse
    $result.Observations[0].Holds | Should -Be 2
    Should -Invoke Get-ChildItem -Times 0 -ParameterFilter { $LiteralPath -like '*ReparsePoint*' -or $LiteralPath -like '*Encrypted*' }
  }
  It 'returns rows in ordinal order independently of enumeration order' {
    foreach ($name in @('z','A','ü')) { [IO.File]::WriteAllText("$fixture/_generated/$name", 'content') }
    $result=Get-GeneratedRemediationTreeCensus $fixture
    $result.StructuralInventoryComplete | Should -BeTrue
    ($result.Observations[0].Rows.RelativePath -join '|') | Should -Be '_generated|_generated/A|_generated/z|_generated/ü'
  }
  It 'detects file metadata drift between walks without data reads' {
    $path="$fixture/_generated/data"
    [IO.File]::WriteAllText($path, 'first')
    $script:reads=0
    Mock Get-ChildItem {
      $script:reads++
      if ($script:reads -eq 2) { [IO.File]::WriteAllText("$script:fixture/_generated/data", 'longer') }
      & $script:getChildrenCommand -LiteralPath $LiteralPath -Force -ErrorAction Stop
    } -ParameterFilter { $LiteralPath -like '*_generated' }
    $result=Get-GeneratedRemediationTreeCensus $fixture
    $result.Success | Should -BeFalse
    $result.StructuralInventoryComplete | Should -BeFalse
    $result.Errors[0] | Should -Match 'drift'
  }
  It 'rechecks ancestors after a transient error and refuses a new redirect' {
    $script:redirect=$false
    Mock Start-Sleep { }
    Mock Get-ChildItem { $script:redirect=$true; throw [UnauthorizedAccessException]::new('transient') } -ParameterFilter { $LiteralPath -like '*_generated' }
    Mock Get-Item {
      if ($script:redirect) { [pscustomobject]@{Attributes=[IO.FileAttributes]::ReparsePoint;LinkTarget='do-not-follow';PSIsContainer=$true} }
      else { & $script:getItemCommand -LiteralPath $LiteralPath -Force -ErrorAction Stop }
    } -ParameterFilter { $LiteralPath.TrimEnd('\','/').Replace('\','/') -eq $script:fixture }
    $result=Get-GeneratedRemediationTreeCensus $fixture
    $result.Success | Should -BeFalse
    $result.Attempts.Count | Should -Be 2
    Should -Invoke Get-ChildItem -Times 1 -ParameterFilter { $LiteralPath -like '*_generated' }
  }
  It 'rejects wildcard and module-qualified acquisition defaults before any target call' {
    foreach ($key in @('Get-ChildItem:Recurse', 'Get-ChildItem:Depth', 'Get-ChildItem:Filter', 'Get-ChildItem:Name',
      'Get-ChildItem:Attributes', 'Get-Item:Stream', 'Get-Item:Include', 'Get-Item:Exclude',
      'Microsoft.PowerShell.Management\Get-Item:Filter', '*:Recurse', 'Get-*:Filter', '*\Get-ChildItem:Name',
      'gci:Recurse', 'Get-Command:Name', 'Import-Module:Name')) {
      $savedDefaults = $PSDefaultParameterValues
      $PSDefaultParameterValues = @{$key = $true}
      try { $result = Get-GeneratedRemediationTreeCensus $fixture }
      finally { $PSDefaultParameterValues = $savedDefaults }
      $result.Success | Should -BeFalse
      $result.Errors[0] | Should -Match 'ambient parameter defaults'
    }
    Should -Invoke Get-Item -Times 0
    Should -Invoke Get-ChildItem -Times 0
  }
}

Describe 'Actual provider ambient-default isolation without mocks' {
  It 'rejects ambient recursion while baseline stops at the nested repository' {
    $root = $fixtureBase + '/actual-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
    $null = New-Item -ItemType Directory -Path "$root/_generated/nested/.git/objects" -Force
    $savedDefaults = $PSDefaultParameterValues
    try {
      $PSDefaultParameterValues = @{}
      $baseline = Get-GeneratedRemediationTreeCensus $root
      $baseline.Success | Should -BeTrue
      ($baseline.Observations[0].Rows | Where-Object RelativePath -EQ '_generated/nested').Kind | Should -Be 'NestedRepository'
      $defaults = @{'Get-ChildItem:Recurse' = $true}
      $PSDefaultParameterValues = $defaults
      $result = Get-GeneratedRemediationTreeCensus $root
      $result.Success | Should -BeFalse
      $result.RootState | Should -Be 'NotObserved'
      $result.Observations.Count | Should -Be 0
      $defaults.Count | Should -Be 1
      $defaults['Get-ChildItem:Recurse'] | Should -BeTrue
    } finally { $PSDefaultParameterValues = $savedDefaults }
  }
  It 'does not evaluate scriptblock defaults or change the caller dictionary' {
    $savedDefaults = $PSDefaultParameterValues
    $script:defaultEvaluated = $false
    $value = { $script:defaultEvaluated = $true; '*' }
    $defaults = @{'Microsoft.PowerShell.Management\Get-Item:Stream' = $value; 'Disabled' = $true}
    try {
      $PSDefaultParameterValues = $defaults
      $result = Get-GeneratedRemediationTreeCensus $fixtureBase
      $result.Success | Should -BeFalse
      $result.RootState | Should -Be 'NotObserved'
      $script:defaultEvaluated | Should -BeFalse
      $defaults.Count | Should -Be 2
      [object]::ReferenceEquals($defaults['Microsoft.PowerShell.Management\Get-Item:Stream'], $value) | Should -BeTrue
      $defaults.Disabled | Should -BeTrue
    } finally { $PSDefaultParameterValues = $savedDefaults }
  }
}

Describe 'Native final-component metadata on local synthetic fixtures' {
  It 'uses the exact ABI and disposes the successful directory handle' {
    $null = New-Item -ItemType Directory -Path $fixtureBase -Force
    $r = Get-GeneratedRemediationPathMetadata $fixtureBase
    $r.Success | Should -BeTrue
    $r.HandleOpened | Should -BeTrue
    $r.HandleClosed | Should -BeTrue
    $r.ReparseTag | Should -Be 0
    ($r.Attributes -band 16) | Should -Be 16
    [Runtime.InteropServices.Marshal]::SizeOf([Activator]::CreateInstance([type]'ATAP.GeneratedRemediation.AttributeTagInfoV1')) | Should -Be 8
    [ATAP.GeneratedRemediation.NativePathMetadataV1]::DesiredAccess | Should -Be 0
    [ATAP.GeneratedRemediation.NativePathMetadataV1]::ShareMode | Should -Be 7
    [ATAP.GeneratedRemediation.NativePathMetadataV1]::Disposition | Should -Be 3
    [ATAP.GeneratedRemediation.NativePathMetadataV1]::Flags | Should -Be 0x02200000
    [ATAP.GeneratedRemediation.NativePathMetadataV1]::InformationClass | Should -Be 9
  }
  It 'reads the actual junction tag instead of its target and closes the handle' {
    $target = "$fixtureBase/native-target"
    $link = "$fixtureBase/native-junction"
    $null = New-Item -ItemType Directory -Path $target -Force
    $null = New-Item -ItemType Junction -Path $link -Target $target
    $r = Get-GeneratedRemediationPathMetadata $link
    $r.Success | Should -BeTrue
    $r.ReparseTag | Should -Be 2684354563
    ($r.Attributes -band 1024) | Should -Be 1024
    $r.HandleClosed | Should -BeTrue
  }
  It 'returns missing-path Win32 error without claiming a valid open' {
    $r = Get-GeneratedRemediationPathMetadata "$fixtureBase/does-not-exist"
    $r.Success | Should -BeFalse
    $r.ErrorCode | Should -BeIn @(2,3)
    $r.HandleOpened | Should -BeFalse
    $r.HandleClosed | Should -BeTrue
  }
  It 'supports local Unicode extended-length directory paths' {
    $path = "$fixtureBase/" + ('unicode-ü-0123456789/' * 12) + 'end'
    $null = New-Item -ItemType Directory -Path $path -Force
    (Get-GeneratedRemediationPathMetadata $path).Success | Should -BeTrue
  }
  It 'refuses a changed source hash before native access' {
    Mock Get-FileHash { [pscustomobject]@{Hash='different'} }
    { Get-GeneratedRemediationPathMetadata $fixtureBase } | Should -Throw '*Untrusted*'
  }
  It 'refuses absent provenance for an already loaded type' {
    $saved = $script:GeneratedRemediationNativeProvenanceV1
    try {
      $script:GeneratedRemediationNativeProvenanceV1 = $null
      { Get-GeneratedRemediationPathMetadata $fixtureBase } | Should -Throw '*Untrusted*'
    } finally { $script:GeneratedRemediationNativeProvenanceV1 = $saved }
  }
  It 'rejects adapter and loader defaults without evaluating or mutating them' {
    foreach ($key in @('Add-Type:TypeDefinition','*\Add-Type:ReferencedAssemblies','Get-FileHash:InputStream','gv:Scope','Join-Path:AdditionalChildPath','Get-GeneratedRemediationPathMetadata:Verbose')) {
      $saved = $PSDefaultParameterValues
      $script:wasEvaluated=$false
      $value={ $script:wasEvaluated=$true; throw 'default executed' }
      $defaults=@{$key=$value;Disabled=$true}
      try {
        $PSDefaultParameterValues=$defaults
        { Get-GeneratedRemediationPathMetadata $fixtureBase } | Should -Throw '*ambient*'
        $script:wasEvaluated | Should -BeFalse
        $defaults.Count | Should -Be 2
        [object]::ReferenceEquals($defaults[$key],$value) | Should -BeTrue
      } finally { $PSDefaultParameterValues=$saved }
    }
  }
}

Describe 'Opt-in cloud policy with mocked native metadata' {
  BeforeEach {
    $script:fixture = $fixtureBase + '/cloud-' + [guid]::NewGuid().ToString('N').Substring(0,8)
    $null = New-Item -ItemType Directory -Path "$fixture/_generated" -Force
    $script:cloudAttributes = [uint32]525360
    $script:cloudTag = [uint32]2415964186
    $script:providerAttributes = [long]525360
    $script:providerLink = $null
    $script:metadataFailure = $false
    $script:nativeRootReads = 0
    $script:driftAt = 0
    Mock Get-GeneratedRemediationPathMetadata {
      $isRoot = $LiteralPath.Replace('\','/').TrimEnd('/') -eq "$script:fixture/_generated"
      if ($isRoot) {
        $script:nativeRootReads++
        $tag = if ($script:driftAt -gt 0 -and $script:nativeRootReads -ge $script:driftAt) { [uint32]2415960090 } else {$script:cloudTag}
        [pscustomobject]@{Success=(!$script:metadataFailure);Attributes=$script:cloudAttributes;ReparseTag=$tag;ErrorCode=[int]0;HandleOpened=$true;HandleClosed=$true}
      } else {
        # Synthetic local-only metadata; provider command invoked outside census mocks.
        $item = & $script:getItemCommand -LiteralPath $LiteralPath -Force -ErrorAction Stop
        [pscustomobject]@{Success=$true;Attributes=[uint32]$item.Attributes;ReparseTag=[uint32]0;ErrorCode=[int]0;HandleOpened=$true;HandleClosed=$true}
      }
    }
    Mock Get-Item {
      if ($LiteralPath.Replace('\','/').TrimEnd('/') -eq "$script:fixture/_generated") {
        [pscustomobject]@{Attributes=$script:providerAttributes;PSIsContainer=$true;LinkTarget=$script:providerLink;LinkType=$null;LastWriteTimeUtc=[datetime]::MinValue;CreationTimeUtc=[datetime]::MinValue}
      } else { & $script:getItemCommand -LiteralPath $LiteralPath -Force -ErrorAction Stop }
    }
    Mock Get-ChildItem { & $script:getChildrenCommand -LiteralPath $LiteralPath -Force -Recurse:$false -FollowSymlink:$false -ErrorAction Stop }
  }
  It 'requires explicit opt-in and records the exact admitted tag and attributes' {
    $baseline = Get-GeneratedRemediationTreeCensus $fixture
    $baseline.StructuralInventoryComplete | Should -BeFalse
    Should -Invoke Get-GeneratedRemediationPathMetadata -Times 0
    $r = Get-GeneratedRemediationTreeCensus $fixture -AllowVerifiedCloudDirectoryMetadata
    $r.StructuralInventoryComplete | Should -BeTrue
    $r.Observations.Count | Should -Be 2
    $r.Observations[0].Rows[0].ReparseTag | Should -Be 2415964186
    $r.Observations[0].Rows[0].Attributes | Should -Be 525360
    $r.NativePathObservations.Count | Should -BeGreaterThan 1
    $r.InventoryComplete | Should -BeFalse
    $r.ReadyForManifest | Should -BeFalse
    $r.CustodyVerified | Should -BeFalse
  }
  # Independent explicit hex cases transcribed from Microsoft winnt.h, rather
  # than deriving expected tags from the implementation or using its bit mask.
  It 'admits documented directory tag <TagHex> only after opt-in' -ForEach @(
    @{TagHex='9000001A'}, @{TagHex='9000101A'}, @{TagHex='9000201A'}, @{TagHex='9000301A'},
    @{TagHex='9000401A'}, @{TagHex='9000501A'}, @{TagHex='9000601A'}, @{TagHex='9000701A'},
    @{TagHex='9000801A'}, @{TagHex='9000901A'}, @{TagHex='9000A01A'}, @{TagHex='9000B01A'},
    @{TagHex='9000C01A'}, @{TagHex='9000D01A'}, @{TagHex='9000E01A'}, @{TagHex='9000F01A'}
  ) {
    $script:cloudTag=[Convert]::ToUInt32($TagHex,16)
    $null=New-Item -ItemType Directory -Path "$fixture/_generated/child"
    (Get-GeneratedRemediationTreeCensus $fixture).StructuralInventoryComplete | Should -BeFalse
    Should -Invoke Get-GeneratedRemediationPathMetadata -Times 0
    Should -Invoke Get-ChildItem -Times 0 -ParameterFilter { $LiteralPath.Replace('\','/').TrimEnd('/') -eq "$script:fixture/_generated" }
    foreach($attributes in @(1072,525360)) {
      $script:cloudAttributes=[uint32]$attributes
      $script:providerAttributes=[long]$attributes
      $r=Get-GeneratedRemediationTreeCensus $fixture -AllowVerifiedCloudDirectoryMetadata
      $r.StructuralInventoryComplete | Should -BeTrue
      $r.Observations[0].Rows[0].ReparseTag | Should -Be ([Convert]::ToUInt32($TagHex,16))
      $r.Observations[0].Rows.RelativePath | Should -Contain '_generated/child'
      $r.ReadyForManifest | Should -BeFalse
      $r.CustodyVerified | Should -BeFalse
      $r.InventoryComplete | Should -BeFalse
    }
  }
  It 'rejects adjacent reserved wrong-prefix and redirecting tags before provider or child access' {
    foreach($hex in @('90000019','9000001B','9000E019','9000E01B','9000F019','9000F01B',
      '9001001A','9000FFFF','9000011A','D000E01A','B000E01A','1000E01A','8000E01A',
      'A0000003','A000000C','80000021','00000000','FFFFFFFF')) {
      $script:cloudTag=[Convert]::ToUInt32($hex,16)
      $r=Get-GeneratedRemediationTreeCensus $fixture -AllowVerifiedCloudDirectoryMetadata
      $r.StructuralInventoryComplete | Should -BeFalse
      $r.Observations[0].Rows[0].Kind | Should -Be 'UnsupportedNativeReparsePoint'
    }
    Should -Invoke Get-Item -Times 0 -ParameterFilter { $LiteralPath.Replace('\','/').TrimEnd('/') -eq "$script:fixture/_generated" }
    Should -Invoke Get-ChildItem -Times 0 -ParameterFilter { $LiteralPath.Replace('\','/').TrimEnd('/') -eq "$script:fixture/_generated" }
  }
  It 'holds files for every documented cloud tag before provider access' {
    foreach($hex in @('9000001A','9000101A','9000201A','9000301A','9000401A','9000501A','9000601A','9000701A',
      '9000801A','9000901A','9000A01A','9000B01A','9000C01A','9000D01A','9000E01A','9000F01A')) {
      $script:cloudTag=[Convert]::ToUInt32($hex,16)
      $script:cloudAttributes=[uint32]1056
      $r=Get-GeneratedRemediationTreeCensus $fixture -AllowVerifiedCloudDirectoryMetadata
      $r.StructuralInventoryComplete | Should -BeFalse
      $r.Observations[0].Rows[0].Kind | Should -Be 'UnsupportedNativeReparsePoint'
    }
    Should -Invoke Get-Item -Times 0 -ParameterFilter { $LiteralPath.Replace('\','/').TrimEnd('/') -eq "$script:fixture/_generated" }
    Should -Invoke Get-ChildItem -Times 0 -ParameterFilter { $LiteralPath.Replace('\','/').TrimEnd('/') -eq "$script:fixture/_generated" }
  }
  It 'does not expand the attribute mask for the newly admitted E tag' {
    $script:cloudTag=[Convert]::ToUInt32('9000E01A',16)
    foreach($bit in @(4096,16384,262144,4194304,1048576,2147483648L,128,256,512,2048)) {
      $script:cloudAttributes=[uint32](1072 -bor $bit)
      $r=Get-GeneratedRemediationTreeCensus $fixture -AllowVerifiedCloudDirectoryMetadata
      $r.StructuralInventoryComplete | Should -BeFalse
      $r.Observations[0].Rows[0].Hold | Should -BeTrue
    }
    Should -Invoke Get-Item -Times 0 -ParameterFilter { $LiteralPath.Replace('\','/').TrimEnd('/') -eq "$script:fixture/_generated" }
    Should -Invoke Get-ChildItem -Times 0 -ParameterFilter { $LiteralPath.Replace('\','/').TrimEnd('/') -eq "$script:fixture/_generated" }
  }
  It 'holds undocumented tags, surrogate tags, forbidden bits and cloud files before provider access' {
    foreach ($case in @(
      @{A=525360;T=2415919131}, @{A=525360;T=2952835098},
      @{A=(525360 -bor 4096);T=2415964186}, @{A=(525360 -bor 16384);T=2415964186},
      @{A=(525360 -bor 262144);T=2415964186}, @{A=(525360 -bor 4194304);T=2415964186},
      @{A=(525360 -bor 1048576);T=2415964186}, @{A=(525360 -bor 2147483648L);T=2415964186},
      @{A=(525360 -band (-bnot 16));T=2415964186})) {
      $script:cloudAttributes=[uint32]$case.A; $script:cloudTag=[uint32]$case.T
      $r = Get-GeneratedRemediationTreeCensus $fixture -AllowVerifiedCloudDirectoryMetadata
      $r.StructuralInventoryComplete | Should -BeFalse
      $r.Observations[0].Rows[0].Hold | Should -BeTrue
    }
    Should -Invoke Get-Item -Times 0 -ParameterFilter { $LiteralPath.Replace('\','/').TrimEnd('/') -eq "$script:fixture/_generated" }
    Should -Invoke Get-ChildItem -Times 0 -ParameterFilter { $LiteralPath.Replace('\','/').TrimEnd('/') -eq "$script:fixture/_generated" }
  }
  It 'rejects provider mismatch and surfaced links before reading children' {
    foreach ($case in @('attributes','link')) {
      $script:providerAttributes=if ($case -eq 'attributes') {16} else {525360}
      $script:providerLink=if ($case -eq 'link') {'unexpected'} else {$null}
      $r = Get-GeneratedRemediationTreeCensus $fixture -AllowVerifiedCloudDirectoryMetadata
      $r.Success | Should -BeFalse
      $r.Errors[0] | Should -Match 'mismatch|link'
    }
    Should -Invoke Get-ChildItem -Times 0 -ParameterFilter { $LiteralPath.Replace('\','/').TrimEnd('/') -eq "$script:fixture/_generated" }
  }
  It 'rejects native failures before the provider probes the failed path' {
    $script:metadataFailure=$true
    $r = Get-GeneratedRemediationTreeCensus $fixture -AllowVerifiedCloudDirectoryMetadata
    $r.Success | Should -BeFalse
    Should -Invoke Get-Item -Times 0 -ParameterFilter { $LiteralPath.Replace('\','/').TrimEnd('/') -eq "$script:fixture/_generated" }
  }
  It 'detects tag drift before a directory read and across the second walk' {
    foreach ($read in @(2,4)) {
      $script:nativeRootReads=0; $script:driftAt=$read
      $r=Get-GeneratedRemediationTreeCensus $fixture -AllowVerifiedCloudDirectoryMetadata
      $r.Success | Should -BeFalse
      $r.Errors[0] | Should -Match 'drift'
    }
  }
  It 'refuses loader defaults before any acquisition' {
    $saved=$PSDefaultParameterValues
    try {
      $PSDefaultParameterValues=@{'Add-Type:TypeDefinition'={throw 'never run'}}
      $r=Get-GeneratedRemediationTreeCensus $fixture -AllowVerifiedCloudDirectoryMetadata
    } finally {$PSDefaultParameterValues=$saved}
    $r.Success | Should -BeFalse
    Should -Invoke Get-GeneratedRemediationPathMetadata -Times 0
    Should -Invoke Get-Item -Times 0
    Should -Invoke Get-ChildItem -Times 0
  }
}

Describe 'Additional fail-closed cloud guard cases' {
  BeforeEach {
    $script:fixture = $fixtureBase + '/adversarial-' + [guid]::NewGuid().ToString('N').Substring(0,8)
    $null=New-Item -ItemType Directory -Path "$fixture/_generated/child" -Force
    $script:nativeCalls=0
    Mock Get-Item { & $script:getItemCommand -LiteralPath $LiteralPath -Force -ErrorAction Stop }
    Mock Get-ChildItem { & $script:getChildrenCommand -LiteralPath $LiteralPath -Force -Recurse:$false -FollowSymlink:$false -ErrorAction Stop }
    Mock Start-Sleep {}
  }
  It 'refuses malformed native success before any provider call' {
    foreach ($field in @('Success','Attributes','ReparseTag','ErrorCode','HandleOpened','HandleClosed')) {
      $script:badField=$field
      Mock Get-GeneratedRemediationPathMetadata {
        $r=[pscustomobject]@{Success=$true;Attributes=[uint32]16;ReparseTag=[uint32]0;ErrorCode=[int]0;HandleOpened=$true;HandleClosed=$true}
        $r.($script:badField)='malformed'
        $r
      }
      (Get-GeneratedRemediationTreeCensus $fixture -AllowVerifiedCloudDirectoryMetadata).Success | Should -BeFalse
    }
    Should -Invoke Get-Item -Times 0
    Should -Invoke Get-ChildItem -Times 0
  }
  It 'never crosses an unapproved native ancestor' {
    Mock Get-GeneratedRemediationPathMetadata {
      [pscustomobject]@{Success=$true;Attributes=[uint32]1040;ReparseTag=[uint32]2684354563;ErrorCode=[int]0;HandleOpened=$true;HandleClosed=$true}
    }
    $r=Get-GeneratedRemediationTreeCensus $fixture -AllowVerifiedCloudDirectoryMetadata
    $r.Success | Should -BeFalse
    Should -Invoke Get-GeneratedRemediationPathMetadata -Times 1 -Exactly
    Should -Invoke Get-Item -Times 0
    Should -Invoke Get-ChildItem -Times 0
  }
  It 'retries native access and sharing failures but never calls an incomplete run complete' {
    foreach ($errorCode in @(5,32,33)) {
      $script:failureCode=$errorCode; $script:nativeCalls=0
      Mock Get-GeneratedRemediationPathMetadata {
        $script:nativeCalls++
        if ($script:nativeCalls -eq 1) {
          [pscustomobject]@{Success=$false;Attributes=[uint32]0;ReparseTag=[uint32]0;ErrorCode=[int]$script:failureCode;HandleOpened=$false;HandleClosed=$true}
        } else {
          $item=& $script:getItemCommand -LiteralPath $LiteralPath -Force -ErrorAction Stop
          [pscustomobject]@{Success=$true;Attributes=[uint32]$item.Attributes;ReparseTag=[uint32]0;ErrorCode=[int]0;HandleOpened=$true;HandleClosed=$true}
        }
      }
      $r=Get-GeneratedRemediationTreeCensus $fixture -AllowVerifiedCloudDirectoryMetadata
      $r.Success | Should -BeTrue
      $r.StructuralInventoryComplete | Should -BeFalse
      $r.FailedWalks.Count | Should -Be 1
    }
  }
  It 'retains native query failure after an opened and closed handle without provider access' {
    Mock Get-GeneratedRemediationPathMetadata {
      [pscustomobject]@{Success=$false;Attributes=[uint32]0;ReparseTag=[uint32]0;ErrorCode=[int]87;HandleOpened=$true;HandleClosed=$true}
    }
    $r=Get-GeneratedRemediationTreeCensus $fixture -AllowVerifiedCloudDirectoryMetadata
    $r.Success | Should -BeFalse
    $r.Attempts.Count | Should -Be 1
    Should -Invoke Get-Item -Times 0
  }
  It 'detects native ancestor change after a transient provider error' {
    $script:changed=$false
    Mock Get-GeneratedRemediationPathMetadata {
      $item=& $script:getItemCommand -LiteralPath $LiteralPath -Force -ErrorAction Stop
      $tag=[uint32]0; $attr=[uint32]$item.Attributes
      if ($script:changed -and $LiteralPath -eq 'D:\') {$tag=[uint32]2684354563; $attr=[uint32]1040}
      [pscustomobject]@{Success=$true;Attributes=$attr;ReparseTag=$tag;ErrorCode=[int]0;HandleOpened=$true;HandleClosed=$true}
    }
    Mock Get-ChildItem { $script:changed=$true; throw [UnauthorizedAccessException]::new('transient') }
    $r=Get-GeneratedRemediationTreeCensus $fixture -AllowVerifiedCloudDirectoryMetadata
    $r.Success | Should -BeFalse
    $r.Attempts.Count | Should -Be 2
    $r.Errors[0] | Should -Match 'drift'
    Should -Invoke Get-ChildItem -Times 1 -Exactly
  }
}
