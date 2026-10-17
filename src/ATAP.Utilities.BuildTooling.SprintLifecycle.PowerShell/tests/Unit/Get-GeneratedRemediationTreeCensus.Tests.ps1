BeforeAll {
  . (Join-Path $PSScriptRoot '../../private/Get-GeneratedRemediationTreeCensus.ps1')
  $script:fixtureBase = 'D:/ATAPArtifacts/_generated/GeneratedFolderRemediation/Sprint0016/TreeCensus/' + [guid]::NewGuid().ToString('N')
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
