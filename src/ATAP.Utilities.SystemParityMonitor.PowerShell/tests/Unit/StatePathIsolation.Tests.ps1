# Generated using PesterTestData.instructions.md as guidelines.
# Static-source stage: this file has NOT been admitted for execution. A future
# runner must use profiled PowerShell 7.4+, PSFramework and Pester 6.2.0, with
# result/evidence paths under the owning _generated root. No parity module loads.

Describe 'Owned parity fixture isolation' -Tag 'StatePathIsolation' {
  BeforeAll {
    $script:parityRepoRoot = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-150-Sprint-0017-work-items'
    $script:parityFixtureRoot = Join-Path $script:parityRepoRoot '_generated/Sprint0017/17.6.a/StatePathFixtures'
    $script:parityRunId = [guid]::NewGuid().ToString('N')
    $script:parityOwner = [guid]::NewGuid().ToString('N')
    if (-not (Get-Command -Name Write-PSFMessage -ErrorAction SilentlyContinue)) {
      throw 'The separately admitted runner must preload PSFramework.'
    }
    $script:fixtureGetItem = Get-Command 'Microsoft.PowerShell.Management\Get-Item' -ErrorAction Stop
    $script:fixtureNewItem = Get-Command 'Microsoft.PowerShell.Management\New-Item' -ErrorAction Stop
    . (Join-Path $PSScriptRoot '../Support/Invoke-OwnedParityTestFixture.ps1')
  }

  BeforeEach {
    $caseId = [guid]::NewGuid().ToString('N')
    $casePath = Join-Path (Join-Path $script:parityFixtureRoot $script:parityRunId) $caseId
    $markerPath = Join-Path $casePath '.owned-parity-fixture.json'
    $fixture = @{
      RepositoryRoot = $script:parityRepoRoot; StatePath = $casePath
      RunId = $script:parityRunId; CaseId = $caseId; OwnerToken = $script:parityOwner
    }
    Mock Write-PSFMessage { }
  }

  # No AfterEach recursive cleanup. Negative, foreign, partial and uncertain
  # cases remain evidence. Positive Remove tests exercise only marked ownership.

  Context 'Family1 explicit input and token rejection' {
    It 'rejects omitted <Name> without prompting or mutating' -ForEach @(
      @{ Name = 'Operation' }, @{ Name = 'RepositoryRoot' }, @{ Name = 'StatePath' },
      @{ Name = 'RunId' }, @{ Name = 'CaseId' }, @{ Name = 'OwnerToken' }
    ) {
      $parameters = $fixture.Clone()
      $parameters.Operation = 'Create'
      [void]$parameters.Remove($Name)
      Mock New-Item { throw 'Unexpected fixture creation.' }
      Mock Remove-Item { throw 'Unexpected fixture deletion.' }

      { Invoke-OwnedParityTestFixture @parameters } | Should -Throw '*Explicit*required*'

      Should -Invoke New-Item -Times 0 -Exactly
      Should -Invoke Remove-Item -Times 0 -Exactly
    }

    It 'rejects <Label> StatePath before mutation' -ForEach @(
      @{ Label = 'null'; Value = $null }, @{ Label = 'empty'; Value = '' },
      @{ Label = 'whitespace'; Value = '   ' }
    ) {
      $fixture.StatePath = $Value
      Mock New-Item { throw 'Unexpected fixture creation.' }
      Mock Remove-Item { throw 'Unexpected fixture deletion.' }
      { Invoke-OwnedParityTestFixture @fixture -Operation Create } | Should -Throw '*Explicit StatePath*'
      Should -Invoke New-Item -Times 0 -Exactly
      Should -Invoke Remove-Item -Times 0 -Exactly
    }

    It 'rejects invalid <Token> before mutation' -ForEach @(
      @{ Token = 'RunId' }, @{ Token = 'CaseId' }, @{ Token = 'OwnerToken' }
    ) {
      $fixture[$Token] = 'not-a-guid'
      Mock New-Item { throw 'Unexpected fixture creation.' }
      { Invoke-OwnedParityTestFixture @fixture -Operation Create } | Should -Throw '*GUIDs in N format*'
      Should -Invoke New-Item -Times 0 -Exactly
    }

    It 'rejects an all-zero ownership token and an unknown operation' {
      $fixture.OwnerToken = '00000000000000000000000000000000'
      { Invoke-OwnedParityTestFixture @fixture -Operation Create } | Should -Throw '*GUIDs in N format*'
      $fixture.OwnerToken = $script:parityOwner
      { Invoke-OwnedParityTestFixture @fixture -Operation Adopt } | Should -Throw '*Unknown fixture operation*'
    }
  }

  Context 'Family2 production defaults never become fixtures' {
    It 'rejects production path <Value> without probing it' -ForEach @(
      @{ Value = 'C:\ProgramData\ATAP\ParityState' },
      @{ Value = 'c:/PROGRAMDATA/atap/paritystate/child' },
      @{ Value = 'C:\Dropbox\whertzing\ATAP\ParityState' },
      @{ Value = 'c:/DROPBOX/whertzing/ATAP/ParityState/child' }
    ) {
      $fixture.StatePath = $Value
      Mock Get-Item { throw 'Production metadata must not be probed.' }
      Mock New-Item { throw 'Production fixture must not be created.' }
      Mock Remove-Item { throw 'Production fixture must not be removed.' }
      { Invoke-OwnedParityTestFixture @fixture -Operation Create } | Should -Throw '*exact fixed generated fixture*'
      Should -Invoke Get-Item -Times 0 -Exactly
      Should -Invoke New-Item -Times 0 -Exactly
      Should -Invoke Remove-Item -Times 0 -Exactly
    }
  }

  Context 'Family3 ambiguous path spellings fail before filesystem work' {
    It 'rejects <Value>' -ForEach @(
      @{ Value = 'relative\case' }, @{ Value = 'C:relative' }, @{ Value = '\root-relative' },
      @{ Value = '\\server\share\case' }, @{ Value = '\\?\C:\case' }, @{ Value = '\\.\C:\case' },
      @{ Value = 'FileSystem::C:\case' }, @{ Value = 'HKLM:\Software\case' },
      @{ Value = 'C:\case*' }, @{ Value = 'C:\case[1]' }, @{ Value = 'C:\case:stream' },
      @{ Value = 'C:\safe\..\case' }, @{ Value = 'C:\safe\.\case' },
      @{ Value = 'C:\case.' }, @{ Value = 'C:\case ' }, @{ Value = 'C:\NUL\case' }
    ) {
      $fixture.StatePath = $Value
      Mock Get-Item { throw 'No invalid-path metadata access.' }
      Mock New-Item { throw 'No invalid-path creation.' }
      Mock Remove-Item { throw 'No invalid-path deletion.' }
      { Invoke-OwnedParityTestFixture @fixture -Operation Create } | Should -Throw
      Should -Invoke Get-Item -Times 0 -Exactly
      Should -Invoke New-Item -Times 0 -Exactly
      Should -Invoke Remove-Item -Times 0 -Exactly
    }
  }

  Context 'Family4 confinement, collision and foreign ownership' {
    It 'rejects anchor, run parent, sibling-prefix and other-case paths' {
      Mock New-Item { throw 'No unconfined creation.' }
      foreach ($invalid in @($script:parityFixtureRoot,
          (Split-Path $casePath -Parent),
          ($script:parityFixtureRoot + '-sibling\' + $script:parityRunId + '\' + $caseId),
          (Join-Path (Split-Path $casePath -Parent) ([guid]::NewGuid().ToString('N'))))) {
        $fixture.StatePath = $invalid
        { Invoke-OwnedParityTestFixture @fixture -Operation Create } | Should -Throw '*exact fixed generated fixture*'
      }
      Should -Invoke New-Item -Times 0 -Exactly
    }

    It 'rejects a foreign repository binding before creation' {
      $fixture.RepositoryRoot = 'C:\OtherRepository'
      Mock New-Item { throw 'No foreign creation.' }
      { Invoke-OwnedParityTestFixture @fixture -Operation Create } | Should -Throw '*fixed Utilities150 helper owner*'
      Should -Invoke New-Item -Times 0 -Exactly
    }

    It 'does not adopt an existing case directory' {
      New-Item -ItemType Directory -Path $casePath -Force | Out-Null
      Mock New-Item { throw 'Collision must not create anything.' }
      { Invoke-OwnedParityTestFixture @fixture -Operation Create } | Should -Throw '*collision cannot be adopted*'
      Should -Invoke New-Item -Times 0 -Exactly
      Test-Path -LiteralPath $casePath | Should -BeTrue
      Test-Path -LiteralPath $markerPath | Should -BeFalse
    }

    It 'rejects an incorrect owner or run without deleting the owned case' {
      Invoke-OwnedParityTestFixture @fixture -Operation Create | Out-Null
      $foreign = $fixture.Clone()
      $foreign.OwnerToken = [guid]::NewGuid().ToString('N')
      Mock Remove-Item { throw 'Foreign owner cannot delete.' }
      { Invoke-OwnedParityTestFixture @foreign -Operation Validate } | Should -Throw '*Process registry identity*'
      { Invoke-OwnedParityTestFixture @foreign -Operation Remove } | Should -Throw '*Process registry identity*'
      $foreign = $fixture.Clone()
      $foreign.RunId = [guid]::NewGuid().ToString('N')
      { Invoke-OwnedParityTestFixture @foreign -Operation Remove } | Should -Throw '*exact fixed generated fixture*'
      Should -Invoke Remove-Item -Times 0 -Exactly
    }
  }

  Context 'Family5 metadata uncertainty and operator-approved ancestors' {
    It 'PF01 inspects a literal <Location> link even when Test-Path would be false' -ForEach @(
      @{ Location = 'sink' }, @{ Location = 'ancestor' }
    ) {
      Invoke-OwnedParityTestFixture @fixture -Operation Create | Out-Null
      $script:pf01Entry = Join-Path $casePath 'redirected'
      $script:pf01IsDirectory = $Location -eq 'ancestor'
      $sink = if ($script:pf01IsDirectory) { Join-Path $script:pf01Entry 'snapshot.json' } else { $script:pf01Entry }
      Mock Test-Path { $false }
      Mock Get-Item {
        if ($LiteralPath -eq $script:pf01Entry) {
          return [pscustomobject]@{
            PSIsContainer = $script:pf01IsDirectory; LinkType = 'SymbolicLink'
            Attributes = if ($script:pf01IsDirectory) {
              [IO.FileAttributes]::Directory -bor [IO.FileAttributes]::ReparsePoint
            } else { [IO.FileAttributes]::ReparsePoint }
            CreationTimeUtc = [datetime]::UtcNow
          }
        }
        & $script:fixtureGetItem -LiteralPath $LiteralPath -Force -ErrorAction Stop
      }
      Mock Get-ChildItem { throw 'Must not enumerate or follow the redirected entry.' }
      Mock New-Item { throw 'No create during uncertain validation.' }
      Mock Remove-Item { throw 'No delete during uncertain validation.' }
      { Invoke-OwnedParityTestFixture @fixture -Operation Validate -Paths @{ OutputPath = $sink } } |
        Should -Throw '*link*'
      Should -Invoke Test-Path -Times 0 -Exactly
      Should -Invoke Get-ChildItem -Times 0 -Exactly
      Should -Invoke New-Item -Times 0 -Exactly
      Should -Invoke Remove-Item -Times 0 -Exactly
    }

    It 'PF01 retains unresolved <Location> entries on typed missing metadata plus a parent entry' -ForEach @(
      @{ Location = 'sink' }, @{ Location = 'ancestor' }
    ) {
      Invoke-OwnedParityTestFixture @fixture -Operation Create | Out-Null
      $script:pf01Entry = Join-Path $casePath 'unresolved'
      $script:pf01Parent = $casePath
      $sink = if ($Location -eq 'ancestor') { Join-Path $script:pf01Entry 'snapshot.json' } else { $script:pf01Entry }
      Mock Test-Path { $false }
      Mock Get-Item {
        if ($LiteralPath -eq $script:pf01Entry) {
          throw [System.Management.Automation.ItemNotFoundException]::new('Simulated unresolved literal metadata.')
        }
        & $script:fixtureGetItem -LiteralPath $LiteralPath -Force -ErrorAction Stop
      }
      Mock Get-ChildItem {
        if ($LiteralPath -ne $script:pf01Parent) { throw 'No traversal of the unresolved target.' }
        [pscustomobject]@{ Name = 'unresolved'; LinkType = 'SymbolicLink' }
      }
      Mock New-Item { throw 'No create after unresolved metadata.' }
      Mock Remove-Item { throw 'No cleanup after unresolved metadata.' }
      { Invoke-OwnedParityTestFixture @fixture -Operation Validate -Paths @{ OutputPath = $sink } } |
        Should -Throw '*remains unresolved*'
      Should -Invoke Test-Path -Times 0 -Exactly
      Should -Invoke Get-ChildItem -Times 1 -Exactly
      Should -Invoke New-Item -Times 0 -Exactly
      Should -Invoke Remove-Item -Times 0 -Exactly
    }

    It 'PF01 permits definitely absent <Location> destinations without descending through missing parents' -ForEach @(
      @{ Location = 'sink' }, @{ Location = 'ancestor' }
    ) {
      Invoke-OwnedParityTestFixture @fixture -Operation Create | Out-Null
      $script:pf01Entry = Join-Path $casePath 'future'
      $script:pf01Parent = $casePath
      $sink = if ($Location -eq 'ancestor') { Join-Path $script:pf01Entry 'snapshot.json' } else { $script:pf01Entry }
      Mock Get-Item {
        if ($LiteralPath -eq $script:pf01Entry) {
          throw [System.Management.Automation.ItemNotFoundException]::new('Simulated missing ordinary entry.')
        }
        & $script:fixtureGetItem -LiteralPath $LiteralPath -Force -ErrorAction Stop
      }
      Mock Get-ChildItem {
        if ($LiteralPath -ne $script:pf01Parent) { throw 'Must not descend below definite absence.' }
        @()
      }
      Mock New-Item { throw 'Validation does not create future destinations.' }
      Mock Remove-Item { throw 'Validation does not clean future destinations.' }
      (Invoke-OwnedParityTestFixture @fixture -Operation Validate -Paths @{ OutputPath = $sink }).Status |
        Should -BeExactly 'Validated'
      Should -Invoke Get-ChildItem -Times 1 -Exactly
      Should -Invoke New-Item -Times 0 -Exactly
      Should -Invoke Remove-Item -Times 0 -Exactly
    }

    It 'PF01 rejects inaccessible <Location> metadata without converting access errors to absence' -ForEach @(
      @{ Location = 'sink' }, @{ Location = 'ancestor' }
    ) {
      Invoke-OwnedParityTestFixture @fixture -Operation Create | Out-Null
      $script:pf01Entry = Join-Path $casePath 'denied'
      $sink = if ($Location -eq 'ancestor') { Join-Path $script:pf01Entry 'snapshot.json' } else { $script:pf01Entry }
      Mock Get-Item {
        if ($LiteralPath -eq $script:pf01Entry) { throw [UnauthorizedAccessException]::new('Literal entry access denied.') }
        & $script:fixtureGetItem -LiteralPath $LiteralPath -Force -ErrorAction Stop
      }
      Mock Get-ChildItem { throw 'Access errors do not permit an absence fallback.' }
      Mock New-Item { throw 'No creation after access failure.' }
      Mock Remove-Item { throw 'No deletion after access failure.' }
      { Invoke-OwnedParityTestFixture @fixture -Operation Validate -Paths @{ OutputPath = $sink } } |
        Should -Throw '*access denied*'
      Should -Invoke Get-ChildItem -Times 0 -Exactly
      Should -Invoke New-Item -Times 0 -Exactly
      Should -Invoke Remove-Item -Times 0 -Exactly
    }

    It 'PF01 rejects provider failures and ambiguous literal results instead of guessing absence' {
      Invoke-OwnedParityTestFixture @fixture -Operation Create | Out-Null
      $script:pf01Entry = Join-Path $casePath 'uncertain'
      foreach ($fault in @('provider', 'empty', 'multiple', 'unknown-shape')) {
        $script:pf01Fault = $fault
        Mock Get-Item {
          if ($LiteralPath -eq $script:pf01Entry) {
            if ($script:pf01Fault -eq 'provider') {
              throw [System.Management.Automation.DriveNotFoundException]::new('Fixture provider unavailable.')
            }
            if ($script:pf01Fault -eq 'multiple') {
              [pscustomobject]@{ PSIsContainer = $false }
              [pscustomobject]@{ PSIsContainer = $false }
            }
            if ($script:pf01Fault -eq 'unknown-shape') { [pscustomobject]@{ Unknown = $true } }
            return
          }
          & $script:fixtureGetItem -LiteralPath $LiteralPath -Force -ErrorAction Stop
        }
        Mock Get-ChildItem { throw 'Unknown errors are not definite absence.' }
        Mock New-Item { throw 'No create during uncertain metadata.' }
        Mock Remove-Item { throw 'No removal during uncertain metadata.' }
        { Invoke-OwnedParityTestFixture @fixture -Operation Validate -Paths @{ OutputPath = $script:pf01Entry } } |
          Should -Throw
        Should -Invoke Get-ChildItem -Times 0 -Exactly
        Should -Invoke New-Item -Times 0 -Exactly
        Should -Invoke Remove-Item -Times 0 -Exactly
      }
    }

    It 'PF01 rejects ambiguous parent enumeration and parent access failure while proving absence' {
      Invoke-OwnedParityTestFixture @fixture -Operation Create | Out-Null
      $script:pf01Entry = Join-Path $casePath 'unresolved-parent-result'
      foreach ($fault in @('missing-name', 'empty-name', 'parent-denied')) {
        $script:pf01Fault = $fault
        Mock Get-Item {
          if ($LiteralPath -eq $script:pf01Entry) {
            throw [System.Management.Automation.ItemNotFoundException]::new('Missing literal result.')
          }
          & $script:fixtureGetItem -LiteralPath $LiteralPath -Force -ErrorAction Stop
        }
        Mock Get-ChildItem {
          if ($script:pf01Fault -eq 'parent-denied') { throw [UnauthorizedAccessException]::new('Parent entry access denied.') }
          if ($script:pf01Fault -eq 'empty-name') { return [pscustomobject]@{ Name = '' } }
          [pscustomobject]@{ Unknown = $true }
        }
        Mock New-Item { throw 'No write after ambiguous absence check.' }
        Mock Remove-Item { throw 'No deletion after ambiguous absence check.' }
        { Invoke-OwnedParityTestFixture @fixture -Operation Validate -Paths @{ OutputPath = $script:pf01Entry } } |
          Should -Throw
        Should -Invoke New-Item -Times 0 -Exactly
        Should -Invoke Remove-Item -Times 0 -Exactly
      }
    }

    It 'PF01 rejects malformed metadata values at <Location> before mutation' -ForEach @(
      @{ Location = 'sink' }, @{ Location = 'ancestor' }, @{ Location = 'Create collision' }
    ) {
      if ($Location -eq 'Create collision') {
        & $script:fixtureNewItem -ItemType Directory -Path (Split-Path $casePath -Parent) -Force | Out-Null
        $script:shapeEntry = $casePath
      } else {
        Invoke-OwnedParityTestFixture @fixture -Operation Create | Out-Null
        $script:shapeEntry = Join-Path $casePath 'metadata-shape'
      }
      foreach ($fault in @(
          'container-null', 'container-string', 'container-number', 'container-array',
          'attributes-null', 'attributes-string', 'attributes-number', 'attributes-negative', 'attributes-array',
          'container-attributes-conflict', 'creation-missing', 'creation-null',
          'creation-string', 'creation-number', 'creation-array', 'creation-min', 'creation-max', 'creation-local', 'creation-unspecified'
        )) {
        $directory = $Location -ne 'sink' -or $fault -like 'creation-*'
        $script:shapeMetadata = [pscustomobject]@{
          PSIsContainer = $directory
          Attributes = if ($directory) { [IO.FileAttributes]::Directory } else { [IO.FileAttributes]::Normal }
          CreationTimeUtc = [datetime]::UtcNow
        }
        switch ($fault) {
          'container-null' { $script:shapeMetadata.PSIsContainer = $null }
          'container-string' { $script:shapeMetadata.PSIsContainer = 'false' }
          'container-number' { $script:shapeMetadata.PSIsContainer = 1 }
          'container-array' { $script:shapeMetadata.PSIsContainer = [bool[]]@($true) }
          'attributes-null' { $script:shapeMetadata.Attributes = $null }
          'attributes-string' { $script:shapeMetadata.Attributes = 'Directory' }
          'attributes-number' { $script:shapeMetadata.Attributes = 16 }
          'attributes-negative' { $script:shapeMetadata.Attributes = [Enum]::ToObject([IO.FileAttributes], -1) }
          'attributes-array' { $script:shapeMetadata.Attributes = [IO.FileAttributes[]]@([IO.FileAttributes]::Directory) }
          'container-attributes-conflict' {
            $script:shapeMetadata.Attributes = if ($directory) { [IO.FileAttributes]::Normal } else { [IO.FileAttributes]::Directory }
          }
          'creation-missing' { $script:shapeMetadata.PSObject.Properties.Remove('CreationTimeUtc') }
          'creation-null' { $script:shapeMetadata.CreationTimeUtc = $null }
          'creation-string' { $script:shapeMetadata.CreationTimeUtc = '2026-01-01T00:00:00Z' }
          'creation-number' { $script:shapeMetadata.CreationTimeUtc = 1 }
          'creation-array' { $script:shapeMetadata.CreationTimeUtc = [datetime[]]@([datetime]::UtcNow) }
          'creation-min' { $script:shapeMetadata.CreationTimeUtc = [datetime]::SpecifyKind([datetime]::MinValue, [DateTimeKind]::Utc) }
          'creation-max' { $script:shapeMetadata.CreationTimeUtc = [datetime]::SpecifyKind([datetime]::MaxValue, [DateTimeKind]::Utc) }
          'creation-local' { $script:shapeMetadata.CreationTimeUtc = [datetime]::Now }
          'creation-unspecified' { $script:shapeMetadata.CreationTimeUtc = [datetime]::new(2026, 1, 1) }
        }
        Mock Get-Item {
          if ($LiteralPath -eq $script:shapeEntry) { return $script:shapeMetadata }
          & $script:fixtureGetItem -LiteralPath $LiteralPath -Force -ErrorAction Stop
        }
        Mock New-Item { throw 'Malformed metadata cannot create a fixture.' }
        Mock Remove-Item { throw 'Malformed metadata cannot authorize deletion.' }
        Mock Get-ChildItem { throw 'Malformed metadata cannot authorize enumeration.' }
        if ($Location -eq 'Create collision') {
          { Invoke-OwnedParityTestFixture @fixture -Operation Create } | Should -Throw '*metadata*'
        } else {
          $sink = if ($Location -eq 'ancestor') { Join-Path $script:shapeEntry 'snapshot.json' } else { $script:shapeEntry }
          { Invoke-OwnedParityTestFixture @fixture -Operation Validate -Paths @{ OutputPath = $sink } } |
            Should -Throw '*metadata*'
        }
        Should -Invoke New-Item -Times 0 -Exactly
        Should -Invoke Remove-Item -Times 0 -Exactly
        Should -Invoke Get-ChildItem -Times 0 -Exactly
        Should -Invoke Get-Item -Times 0 -Exactly -ParameterFilter {
          $LiteralPath -like ($script:shapeEntry + '\*')
        }
      }
    }

    It 'PF01 accepts typed coherent <Location> metadata without creating future sinks' -ForEach @(
      @{ Location = 'sink' }, @{ Location = 'ancestor' }
    ) {
      Invoke-OwnedParityTestFixture @fixture -Operation Create | Out-Null
      $script:shapeEntry = Join-Path $casePath 'typed-metadata'
      $script:shapeIsDirectory = $Location -eq 'ancestor'
      $script:shapeCreationUtc = [datetime]::UtcNow
      $sink = if ($script:shapeIsDirectory) { Join-Path $script:shapeEntry 'snapshot.json' } else { $script:shapeEntry }
      Mock Get-Item {
        if ($LiteralPath -eq $script:shapeEntry) {
          return [pscustomobject]@{
            PSIsContainer = $script:shapeIsDirectory
            Attributes = if ($script:shapeIsDirectory) { [IO.FileAttributes]::Directory } else { [IO.FileAttributes]::Normal }
            CreationTimeUtc = $script:shapeCreationUtc
          }
        }
        & $script:fixtureGetItem -LiteralPath $LiteralPath -Force -ErrorAction Stop
      }
      Mock Get-ChildItem {
        if ($LiteralPath -ne $script:shapeEntry) { throw 'Unexpected typed-metadata enumeration.' }
        @()
      }
      Mock New-Item { throw 'Validation cannot create future sinks.' }
      Mock Remove-Item { throw 'Validation cannot delete typed metadata.' }
      (Invoke-OwnedParityTestFixture @fixture -Operation Validate -Paths @{ OutputPath = $sink }).Status |
        Should -BeExactly 'Validated'
      Should -Invoke New-Item -Times 0 -Exactly
      Should -Invoke Remove-Item -Times 0 -Exactly
    }

    It 'fails closed on inaccessible ancestor metadata before creation' {
      $script:deniedFixturePath = $script:parityRepoRoot
      Mock Get-Item {
        if ($LiteralPath -eq $script:deniedFixturePath) { throw [UnauthorizedAccessException]::new('Fixture metadata denied.') }
        & $script:fixtureGetItem -LiteralPath $LiteralPath -Force -ErrorAction Stop
      }
      Mock New-Item { throw 'No creation after inaccessible metadata.' }
      { Invoke-OwnedParityTestFixture @fixture -Operation Create } | Should -Throw '*Fixture metadata denied*'
      Should -Invoke New-Item -Times 0 -Exactly
    }

    It 'permits a ReparsePoint ancestor without changing its metadata' {
      $script:reparseFixtureAncestor = $script:parityRepoRoot
      Mock Get-Item {
        $item = & $script:fixtureGetItem -LiteralPath $LiteralPath -Force -ErrorAction Stop
        if ($LiteralPath -eq $script:reparseFixtureAncestor) {
          return [pscustomobject]@{
            PSIsContainer = $true; CreationTimeUtc = $item.CreationTimeUtc
            Attributes = ($item.Attributes -bor [IO.FileAttributes]::ReparsePoint)
          }
        }
        $item
      }
      $created = Invoke-OwnedParityTestFixture @fixture -Operation Create
      $created.Status | Should -BeExactly 'Created'
      (Invoke-OwnedParityTestFixture @fixture -Operation Validate).Status | Should -BeExactly 'Validated'
    }

    It 'refuses an unexpected child link without following or removing it' {
      Invoke-OwnedParityTestFixture @fixture -Operation Create | Out-Null
      $script:cleanupFixturePath = $casePath
      Mock Get-ChildItem {
        if ($LiteralPath -ne $script:cleanupFixturePath) { throw 'Unexpected child traversal.' }
        [pscustomobject]@{
          FullName = (Join-Path $script:cleanupFixturePath 'unexpected-link')
          PSIsContainer = $true
          Attributes = ([IO.FileAttributes]::Directory -bor [IO.FileAttributes]::ReparsePoint)
          CreationTimeUtc = [datetime]::UtcNow
        }
      }
      Mock Remove-Item { throw 'No deletion after unexpected link.' }
      { Invoke-OwnedParityTestFixture @fixture -Operation Remove } | Should -Throw '*unexpected child link*'
      Should -Invoke Get-ChildItem -Times 1 -Exactly
      Should -Invoke Remove-Item -Times 0 -Exactly
      Test-Path -LiteralPath $markerPath | Should -BeTrue
    }

    It 'retains the whole fixture if child enumeration is inaccessible' {
      Invoke-OwnedParityTestFixture @fixture -Operation Create | Out-Null
      Mock Get-ChildItem { throw [UnauthorizedAccessException]::new('Child metadata denied.') }
      Mock Remove-Item { throw 'No partial preflight deletion.' }
      { Invoke-OwnedParityTestFixture @fixture -Operation Remove } | Should -Throw '*Child metadata denied*'
      Should -Invoke Remove-Item -Times 0 -Exactly
    }
  }

  Context 'Family6 positive create, validate and exact removal' {
    It 'creates a usable case and normalizes every selected sink and host argument' {
      $paths = @{}
      foreach ($name in @('LocalStatePath', 'PeerStatePath', 'LeftStatePath', 'RightStatePath',
          'OutputPath', 'ReportPath', 'SnapshotPath', 'LeftSnapshotPath', 'RightSnapshotPath', 'WhitelistPath')) {
        $paths[$name] = Join-Path $casePath $name
      }
      $hosts = @{
        HostName = 'fixture-left'; PeerHostName = 'fixture-right'; LocalHostName = 'fixture-left'
        LeftHostName = 'fixture-left'; RightHostName = 'fixture-right'
      }
      $created = Invoke-OwnedParityTestFixture @fixture -Operation Create -Paths $paths -HostNames $hosts
      $created.Status | Should -BeExactly 'Created'
      $created.StatePath | Should -Be $casePath
      Test-Path -LiteralPath $markerPath | Should -BeTrue
      $validated = Invoke-OwnedParityTestFixture @fixture -Operation Validate -Paths $paths -HostNames $hosts
      $validated.Status | Should -BeExactly 'Validated'
      $validated.Paths.Count | Should -Be 10
      $validated.HostNames.Count | Should -Be 5
    }

    It 'accepts equivalent mixed-case slash spelling with exact GUID identity' {
      $fixture.StatePath = $casePath.Replace('\', '/').ToUpperInvariant()
      (Invoke-OwnedParityTestFixture @fixture -Operation Create).Status | Should -BeExactly 'Created'
      $fixture.StatePath = $casePath
      (Invoke-OwnedParityTestFixture @fixture -Operation Validate).Status | Should -BeExactly 'Validated'
    }

    It 'removes only its exact marked case and preserves a foreign sibling and run parent' {
      Invoke-OwnedParityTestFixture @fixture -Operation Create | Out-Null
      $sibling = Join-Path (Split-Path $casePath -Parent) ([guid]::NewGuid().ToString('N'))
      New-Item -ItemType Directory -Path $sibling | Out-Null
      $sentinel = Join-Path $sibling 'retain.txt'
      Set-Content -LiteralPath $sentinel -Value 'foreign evidence' -Encoding utf8
      $before = (Get-FileHash -LiteralPath $sentinel -Algorithm SHA256).Hash
      $child = Join-Path $casePath 'nested'
      New-Item -ItemType Directory -Path $child | Out-Null
      Set-Content -LiteralPath (Join-Path $child 'fixture.txt') -Value 'owned' -Encoding utf8

      (Invoke-OwnedParityTestFixture @fixture -Operation Remove -Confirm:$false).Status | Should -BeExactly 'Removed'

      Test-Path -LiteralPath $casePath | Should -BeFalse
      Test-Path -LiteralPath (Split-Path $casePath -Parent) | Should -BeTrue
      (Get-FileHash -LiteralPath $sentinel -Algorithm SHA256).Hash | Should -BeExactly $before
      $global:ATAPOwnedParityTestFixtures.ContainsKey($casePath) | Should -BeFalse
    }
  }

  Context 'Family7 marker, process registry and ancestor identity' {
    It 'does not delete after marker <Variant>' -ForEach @(
      @{ Variant = 'missing' }, @{ Variant = 'tampered' }
    ) {
      Invoke-OwnedParityTestFixture @fixture -Operation Create | Out-Null
      if ($Variant -eq 'missing') { Remove-Item -LiteralPath $markerPath } else {
        Set-Content -LiteralPath $markerPath -Value '{"foreign":true}' -Encoding utf8
      }
      Mock Remove-Item { throw 'No cleanup with invalid marker.' }
      { Invoke-OwnedParityTestFixture @fixture -Operation Remove } | Should -Throw
      Should -Invoke Remove-Item -Times 0 -Exactly
      Test-Path -LiteralPath $casePath | Should -BeTrue
    }

    It 'does not adopt a disk marker after process-registry ownership is lost' {
      Invoke-OwnedParityTestFixture @fixture -Operation Create | Out-Null
      [void]$global:ATAPOwnedParityTestFixtures.Remove($casePath)
      Mock Remove-Item { throw 'Disk marker alone cannot authorize removal.' }
      { Invoke-OwnedParityTestFixture @fixture -Operation Validate } | Should -Throw '*No process registry ownership*'
      { Invoke-OwnedParityTestFixture @fixture -Operation Remove } | Should -Throw '*No process registry ownership*'
      Should -Invoke Remove-Item -Times 0 -Exactly
      Test-Path -LiteralPath $markerPath | Should -BeTrue
    }

    It 'rejects a valid marker copied from another registered case' {
      Invoke-OwnedParityTestFixture @fixture -Operation Create | Out-Null
      $other = $fixture.Clone()
      $other.CaseId = [guid]::NewGuid().ToString('N')
      $other.StatePath = Join-Path (Split-Path $casePath -Parent) $other.CaseId
      Invoke-OwnedParityTestFixture @other -Operation Create | Out-Null
      Copy-Item -LiteralPath $markerPath -Destination (Join-Path $other.StatePath '.owned-parity-fixture.json') -Force
      Mock Remove-Item { throw 'No cross-case cleanup.' }
      { Invoke-OwnedParityTestFixture @other -Operation Remove } | Should -Throw '*foreign or tampered*'
      Should -Invoke Remove-Item -Times 0 -Exactly
      (Invoke-OwnedParityTestFixture @fixture -Operation Validate).Status | Should -BeExactly 'Validated'
    }

    It 'fails closed if case directory creation identity changes' {
      Invoke-OwnedParityTestFixture @fixture -Operation Create | Out-Null
      $script:changedFixturePath = $casePath
      Mock Get-Item {
        $item = & $script:fixtureGetItem -LiteralPath $LiteralPath -Force -ErrorAction Stop
        if ($LiteralPath -eq $script:changedFixturePath) {
          return [pscustomobject]@{
            PSIsContainer = $true; CreationTimeUtc = $item.CreationTimeUtc.AddTicks(1)
            Attributes = $item.Attributes
          }
        }
        $item
      }
      Mock Remove-Item { throw 'No cleanup after identity change.' }
      { Invoke-OwnedParityTestFixture @fixture -Operation Remove } | Should -Throw '*ancestor identity changed*'
      Should -Invoke Remove-Item -Times 0 -Exactly
    }
  }

  Context 'Family8 all secondary sinks and host names are guarded' {
    It 'rejects escaped <Argument> despite valid StatePath' -ForEach @(
      @{ Argument = 'LocalStatePath' }, @{ Argument = 'PeerStatePath' },
      @{ Argument = 'LeftStatePath' }, @{ Argument = 'RightStatePath' },
      @{ Argument = 'OutputPath' }, @{ Argument = 'ReportPath' },
      @{ Argument = 'SnapshotPath' }, @{ Argument = 'LeftSnapshotPath' },
      @{ Argument = 'RightSnapshotPath' }, @{ Argument = 'WhitelistPath' }
    ) {
      Mock New-Item { throw 'No creation before complete destination validation.' }
      $paths = @{ $Argument = (Join-Path (Split-Path $casePath -Parent) 'escaped') }
      { Invoke-OwnedParityTestFixture @fixture -Operation Create -Paths $paths } | Should -Throw '*strict descendant*'
      Should -Invoke New-Item -Times 0 -Exactly
    }

    It 'rejects unsafe <Argument> before any fixture write' -ForEach @(
      @{ Argument = 'HostName' }, @{ Argument = 'PeerHostName' },
      @{ Argument = 'LocalHostName' }, @{ Argument = 'LeftHostName' }, @{ Argument = 'RightHostName' }
    ) {
      Mock New-Item { throw 'No creation before host validation.' }
      $hosts = @{ $Argument = '../production' }
      { Invoke-OwnedParityTestFixture @fixture -Operation Create -HostNames $hosts } | Should -Throw '*fixed fixture identifiers*'
      Should -Invoke New-Item -Times 0 -Exactly
    }

    It 'rejects marker overwrite, unknown keys, null maps and case-root output' {
      Mock New-Item { throw 'No creation for invalid invocation.' }
      { Invoke-OwnedParityTestFixture @fixture -Operation Create -Paths @{ OutputPath = $markerPath } } | Should -Throw '*ownership marker*'
      { Invoke-OwnedParityTestFixture @fixture -Operation Create -Paths @{ OutputPath = (Join-Path $markerPath 'child') } } | Should -Throw '*ownership marker*'
      { Invoke-OwnedParityTestFixture @fixture -Operation Create -Paths @{ OutputPath = $casePath } } | Should -Throw '*strict descendant*'
      { Invoke-OwnedParityTestFixture @fixture -Operation Create -Paths @{ UnknownPath = (Join-Path $casePath 'child') } } | Should -Throw '*Unknown or invalid*'
      { Invoke-OwnedParityTestFixture @fixture -Operation Create -Paths $null } | Should -Throw '*cannot be null*'
      { Invoke-OwnedParityTestFixture @fixture -Operation Create -HostNames $null } | Should -Throw '*cannot be null*'
      Should -Invoke New-Item -Times 0 -Exactly
    }
  }

  Context 'Family9 partial setup, primary failure and explicit planning' {
    It 'retains the parent and never cleans up after a case-creation exception' {
      $script:failedFixturePath = $casePath
      Mock New-Item {
        if ($Path -eq $script:failedFixturePath) { throw 'Injected case creation failure.' }
        & $script:fixtureNewItem -ItemType Directory -Path $Path -Force -ErrorAction Stop
      }
      Mock Remove-Item { throw 'No fallback cleanup.' }
      { Invoke-OwnedParityTestFixture @fixture -Operation Create } | Should -Throw '*Injected case creation failure*'
      Should -Invoke Remove-Item -Times 0 -Exactly
      Test-Path -LiteralPath (Split-Path $casePath -Parent) | Should -BeTrue
      Test-Path -LiteralPath $casePath | Should -BeFalse
      $global:ATAPOwnedParityTestFixtures.ContainsKey($casePath) | Should -BeFalse
    }

    It 'uses exclusive marker creation and retains partial setup on collision' {
      $script:markerCollisionCase = $casePath
      Mock New-Item {
        $created = & $script:fixtureNewItem -ItemType Directory -Path $Path -ErrorAction Stop -Force:([bool]$Force)
        if ($Path -eq $script:markerCollisionCase) {
          [IO.File]::WriteAllText((Join-Path $Path '.owned-parity-fixture.json'), 'foreign')
        }
        $created
      }
      Mock Remove-Item { throw 'No cleanup of unregistered partial case.' }
      { Invoke-OwnedParityTestFixture @fixture -Operation Create } | Should -Throw
      Should -Invoke Remove-Item -Times 0 -Exactly
      (Get-Content -LiteralPath $markerPath -Raw) | Should -BeExactly 'foreign'
      $global:ATAPOwnedParityTestFixtures.ContainsKey($casePath) | Should -BeFalse
    }

    It 'keeps assertion failure separate from a failed ownership cleanup' {
      Invoke-OwnedParityTestFixture @fixture -Operation Create | Out-Null
      $foreign = $fixture.Clone()
      $foreign.OwnerToken = [guid]::NewGuid().ToString('N')
      $primary = $null
      $cleanup = $null
      try { throw 'Primary assertion failure.' } catch {
        $primary = $_
        try { Invoke-OwnedParityTestFixture @foreign -Operation Remove -Confirm:$false } catch { $cleanup = $_ }
      }
      $primary.Exception.Message | Should -BeExactly 'Primary assertion failure.'
      $cleanup.Exception.Message | Should -Match 'Process registry identity'
      Test-Path -LiteralPath $markerPath | Should -BeTrue
    }

    It 'records incomplete cleanup and refuses an implicit retry' {
      Invoke-OwnedParityTestFixture @fixture -Operation Create | Out-Null
      Mock Remove-Item { throw 'Injected deletion failure.' }
      { Invoke-OwnedParityTestFixture @fixture -Operation Remove -Confirm:$false } | Should -Throw '*Injected deletion failure*'
      $global:ATAPOwnedParityTestFixtures[$casePath].Status | Should -BeExactly 'CleanupIncomplete'
      { Invoke-OwnedParityTestFixture @fixture -Operation Remove -Confirm:$false } | Should -Throw '*Process registry identity or fixture state*'
      Should -Invoke Remove-Item -Times 1 -Exactly
      Test-Path -LiteralPath $markerPath | Should -BeTrue
    }

    It 'performs no create or delete under WhatIf' {
      Mock New-Item { throw 'No WhatIf creation.' }
      Mock Remove-Item { throw 'No WhatIf deletion.' }
      (Invoke-OwnedParityTestFixture @fixture -Operation Create -WhatIf).Status | Should -BeExactly 'Planned'
      Should -Invoke New-Item -Times 0 -Exactly
      Should -Invoke Remove-Item -Times 0 -Exactly
      Test-Path -LiteralPath $casePath | Should -BeFalse
    }
  }
}
