param([string]$FixtureRoot)

BeforeAll {
  $moduleRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
  . (Join-Path $moduleRoot 'private/CoordProducerJson.ps1')
  . (Join-Path $moduleRoot 'private/CoordProducer.ps1')
  . (Join-Path $moduleRoot 'public/Export-CoordState.ps1')
  if ([string]::IsNullOrWhiteSpace($FixtureRoot)) {
    $FixtureRoot = Join-Path ([IO.Path]::GetFullPath((Join-Path $moduleRoot '../..'))) '_generated/Sprint0017/C1935'
  }
  $script:fixtureBase = [IO.Path]::GetFullPath($FixtureRoot)
  New-Item -ItemType Directory -Path $script:fixtureBase -Force | Out-Null

  function New-InventoryFixture {
    $root = Join-Path $script:fixtureBase ([guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path (Join-Path $root 'private') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $root 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell.psd1') -Value "@{ ModuleVersion = '1.0.0' }"
    Set-Content -LiteralPath (Join-Path $root 'private/Example.ps1') -Value 'function Example {}'
    $pins = @(Get-ChildItem -LiteralPath $root -File -Recurse | ForEach-Object {
      @{ path = [IO.Path]::GetRelativePath($root, $_.FullName).Replace('\', '/'); digest = Get-CoordHash ([IO.File]::ReadAllBytes($_.FullName)) }
    })
    [pscustomobject]@{ Root = $root; Package = @{ moduleVersion = '1.0.0'; files = $pins } }
  }
}

Describe 'Export backup separation guards' -Tag 'Unit' {
  BeforeEach {
    $script:backupRoot = 'C:\SyntheticCoord\Backup'
    Mock Read-CoordProducerContext {
      $lease = [pscustomobject]@{}
      $lease | Add-Member -MemberType ScriptMethod -Name Dispose -Value {}
      [pscustomobject]@{
        StatePath = 'C:\SyntheticCoord\State\state.json'; RecordPath = 'C:\SyntheticCoord\Custody\custody.json'
        Record = @{ custodianSid = 'synthetic-only' }; Lease = $lease; BoardLease = $lease
      }
    }
    Mock Get-CoordSetting { $script:backupRoot }
    Mock Assert-CoordProtection { throw 'BackupProtectionReached' }
    Mock Assert-CoordOrdinaryPath { throw 'UnexpectedPathIO' }
  }

  It 'refuses backup <Backup> without protection or output IO' -ForEach @(
    @{ Backup = 'C:\SyntheticCoord\State' }
    @{ Backup = 'C:\SyntheticCoord\State\Nested' }
    @{ Backup = 'C:\SyntheticCoord\Custody' }
    @{ Backup = 'C:\SyntheticCoord\Custody\Nested' }
    @{ Backup = 'c:\syntheticcoord\STATE\' }
    @{ Backup = 'C:\SyntheticCoord\Backup\..\Custody' }
  ) {
    $script:backupRoot = $Backup
    { Export-CoordState -HolderId fixture -SessionId fixture -DestinationPath (Join-Path $Backup 'export.json') -Confirm:$false } |
      Should -Throw '*BackupLocationConflict*'
    Should -Invoke Assert-CoordProtection -Times 0 -Exactly -Scope It
    Should -Invoke Assert-CoordOrdinaryPath -Times 0 -Exactly -Scope It
  }

  It 'allows separate or prefix-sibling backup <Backup> to reach existing protection gate' -ForEach @(
    @{ Backup = 'C:\SyntheticCoord\Backup' }
    @{ Backup = 'C:\SyntheticCoord\StateBackup' }
    @{ Backup = 'C:\SyntheticCoord\CustodyBackup\' }
  ) {
    $script:backupRoot = $Backup
    { Export-CoordState -HolderId fixture -SessionId fixture -DestinationPath (Join-Path $Backup 'export.json') -Confirm:$false } |
      Should -Throw '*BackupProtectionReached*'
    Should -Invoke Assert-CoordProtection -Times 1 -Exactly -Scope It
    Should -Invoke Assert-CoordOrdinaryPath -Times 0 -Exactly -Scope It
  }
}

Describe 'Accepted package inventory is exact' -Tag 'Unit' {
  It 'accepts an unchanged pinned package and ignores nonshipping test files' {
    $f = New-InventoryFixture
    New-Item -ItemType Directory -Path (Join-Path $f.Root 'tests') | Out-Null
    Set-Content -LiteralPath (Join-Path $f.Root 'tests/Fixture.Tests.ps1') -Value 'test stand-in'
    { Assert-CoordPackageInventory -ModuleRoot $f.Root -Package $f.Package } | Should -Not -Throw
  }

  It 'rejects deletion of an accepted pinned file' {
    $f = New-InventoryFixture
    Remove-Item -LiteralPath (Join-Path $f.Root 'private/Example.ps1')
    { Assert-CoordPackageInventory -ModuleRoot $f.Root -Package $f.Package } | Should -Throw '*IncompatiblePackage*'
  }

  It 'rejects <Fault> while preserving exact relative-path and digest semantics' -ForEach @(
    @{ Fault = 'unpinned-current-file' }
    @{ Fault = 'duplicate-pin' }
    @{ Fault = 'case-alias' }
    @{ Fault = 'traversal-alias' }
    @{ Fault = 'absolute-pin' }
    @{ Fault = 'backslash-alias' }
    @{ Fault = 'changed-digest' }
    @{ Fault = 'wrong-version' }
  ) {
    $f = New-InventoryFixture
    $pin = @($f.Package.files | Where-Object path -CEQ 'private/Example.ps1')[0]
    switch ($Fault) {
      'unpinned-current-file' { Set-Content -LiteralPath (Join-Path $f.Root 'extra.json') -Value '{}' }
      'duplicate-pin' { $f.Package.files += @{ path = $pin.path; digest = $pin.digest } }
      'case-alias' { $pin.path = 'private/example.ps1' }
      'traversal-alias' { $pin.path = 'private/../private/Example.ps1' }
      'absolute-pin' { $pin.path = Join-Path $f.Root 'private/Example.ps1' }
      'backslash-alias' { $pin.path = 'private\Example.ps1' }
      'changed-digest' { $pin.digest = '0' * 64 }
      'wrong-version' { $f.Package.moduleVersion = '2.0.0' }
    }
    { Assert-CoordPackageInventory -ModuleRoot $f.Root -Package $f.Package } | Should -Throw '*IncompatiblePackage*'
  }
}
