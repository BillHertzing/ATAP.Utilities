param([string]$FixtureRoot)

BeforeDiscovery {
  $sourceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
  $moduleName = 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell'
  $promoted = [Environment]::GetEnvironmentVariable('ATAP_PROMOTED_MODULE_MANIFEST', 'Process')
  $manifestPath = Join-Path $sourceRoot ($moduleName + '.psd1')
  if ($null -ne $promoted) {
    if ([string]::IsNullOrWhiteSpace($promoted) -or $promoted -notmatch '^[A-Za-z]:[\\/]' -or
        $promoted.Substring(2).Contains(':') -or
        -not [string]::Equals([IO.Path]::GetFullPath($promoted), $promoted.Replace('/', '\'), [StringComparison]::OrdinalIgnoreCase)) {
      throw 'PromotedTestManifestMustBeCanonical'
    }
    $manifestPath = [IO.Path]::GetFullPath($promoted)
  }
  if ($null -ne $promoted -and [string]::Equals($manifestPath, (Join-Path $sourceRoot ($moduleName + '.psd1')), [StringComparison]::OrdinalIgnoreCase)) { throw 'PromotedManifestCannotBeDevelopmentSource' }
  $fixtureArgument = if (Get-Variable -Name FixtureRoot -ErrorAction SilentlyContinue) { $FixtureRoot } else { $null }
  if ([Management.Automation.WildcardPattern]::ContainsWildcardCharacters($manifestPath)) { throw 'SelectedTestManifestCannotContainWildcards' }
  if ($null -ne $promoted) {
    $ancestor = $manifestPath
    while ($ancestor) {
      $metadata = Get-Item -LiteralPath $ancestor -Force -ErrorAction Stop
      if ($metadata.LinkType) { throw 'PromotedTestManifestCannotTraverseLinks' }
      $ancestor = [IO.Path]::GetDirectoryName($ancestor)
    }
  }
  $item = Get-Item -LiteralPath $manifestPath -Force -ErrorAction Stop
  if ($item.PSIsContainer -or $item.Name -cne ($moduleName + '.psd1') -or $item.LinkType) { throw 'InvalidSelectedTestManifest' }
  $data = Import-PowerShellDataFile -LiteralPath $manifestPath
  $moduleBase = [IO.Path]::GetDirectoryName($manifestPath)
  if ($data.RootModule -cne ($moduleName + '.psm1')) { throw 'InvalidSelectedTestRootModule' }
  $expectedModulePath = Join-Path $moduleBase $data.RootModule
  $loaded = @(Get-Module -Name $moduleName -All)
  if (@($loaded | Where-Object { -not [string]::Equals([IO.Path]::GetFullPath($_.Path), $expectedModulePath, [StringComparison]::OrdinalIgnoreCase) -or $_.Version -ne [version]$data.ModuleVersion }).Count) {
    throw 'ConflictingLoadedTestModule'
  }
  $selected = if ($loaded.Count -eq 1) { $loaded[0] } elseif ($loaded.Count -eq 0) {
    Import-Module -Name $manifestPath -PassThru -ErrorAction Stop
  } else { throw 'AmbiguousSelectedTestModule' }
  if ($selected.Name -cne $moduleName -or $selected.Version -ne [version]$data.ModuleVersion -or
      -not [string]::Equals([IO.Path]::GetFullPath($selected.ModuleBase), $moduleBase, [StringComparison]::OrdinalIgnoreCase) -or
      -not [string]::Equals([IO.Path]::GetFullPath($selected.Path), $expectedModulePath, [StringComparison]::OrdinalIgnoreCase)) { throw 'SelectedTestModuleIdentityMismatch' }
  # Resolve genuine module-owned functions before installing any test mocks. A
  # compiled package need not contain private/*.ps1; definitions must already exist.
  & $selected {
    param($binding)
    foreach ($name in @('Update-CoordWitness', 'Read-CoordProducerContext', 'Write-CoordAtomicBytes',
        'Invoke-CoordOperationFileIo', 'Get-CoordHash', 'Read-CoordJsonBytes', 'ConvertFrom-CoordElement',
        'Export-CoordState', 'Assert-CoordPackageInventory')) {
      $command = Get-Command -Name $name -CommandType Function -ErrorAction Stop
      if ($null -eq $command.Module -or $command.Module.Name -cne $binding.Module.Name -or
          -not [string]::Equals($command.Module.Path, $binding.Module.Path, [StringComparison]::OrdinalIgnoreCase) -or
          [string]::IsNullOrWhiteSpace($command.ScriptBlock.File) -or
          -not [IO.Path]::GetFullPath($command.ScriptBlock.File).StartsWith($binding.ModuleBase + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'SelectedTestFunctionIdentityMismatch' }
    }
    $script:C1956Binding = $binding
  } ([pscustomobject]@{ SourceRoot = $sourceRoot; ManifestPath = $manifestPath; ModuleBase = $moduleBase
      Module = $selected; Promoted = ($null -ne $promoted); FixtureRoot = $fixtureArgument })
  $script:C1956ModuleName = $selected.Name
}

InModuleScope -ModuleName $script:C1956ModuleName {
BeforeAll {
    $currentModule = @(Get-Module -Name $script:C1956Binding.Module.Name -All)
    if ($currentModule.Count -ne 1 -or -not [object]::ReferenceEquals($currentModule[0], $script:C1956Binding.Module)) { throw 'SelectedTestModuleChangedAfterDiscovery' }
  $moduleRoot = $script:C1956Binding.SourceRoot
  $FixtureRoot = $script:C1956Binding.FixtureRoot
  $script:testModuleName = $script:C1956Binding.Module.Name
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
    $currentModule = @(Get-Module -Name $script:C1956Binding.Module.Name -All)
    if ($currentModule.Count -ne 1 -or -not [object]::ReferenceEquals($currentModule[0], $script:C1956Binding.Module)) { throw 'SelectedTestModuleChangedAfterDiscovery' }
    $script:backupRoot = 'C:\SyntheticCoord\Backup'
    Mock -ModuleName $script:testModuleName Read-CoordProducerContext {
      $lease = [pscustomobject]@{}
      $lease | Add-Member -MemberType ScriptMethod -Name Dispose -Value {}
      [pscustomobject]@{
        StatePath = 'C:\SyntheticCoord\State\state.json'; RecordPath = 'C:\SyntheticCoord\Custody\custody.json'
        Record = @{ custodianSid = 'synthetic-only' }; Lease = $lease; BoardLease = $lease
      }
    }
    Mock -ModuleName $script:testModuleName Get-CoordSetting { $script:backupRoot }
    Mock -ModuleName $script:testModuleName Assert-CoordProtection { throw 'BackupProtectionReached' }
    Mock -ModuleName $script:testModuleName Assert-CoordOrdinaryPath { throw 'UnexpectedPathIO' }
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
    Should -Invoke Assert-CoordProtection -Times 0 -Exactly -Scope It -ModuleName $script:testModuleName
    Should -Invoke Assert-CoordOrdinaryPath -Times 0 -Exactly -Scope It -ModuleName $script:testModuleName
  }

  It 'allows separate or prefix-sibling backup <Backup> to reach existing protection gate' -ForEach @(
    @{ Backup = 'C:\SyntheticCoord\Backup' }
    @{ Backup = 'C:\SyntheticCoord\StateBackup' }
    @{ Backup = 'C:\SyntheticCoord\CustodyBackup\' }
  ) {
    $script:backupRoot = $Backup
    { Export-CoordState -HolderId fixture -SessionId fixture -DestinationPath (Join-Path $Backup 'export.json') -Confirm:$false } |
      Should -Throw '*BackupProtectionReached*'
    Should -Invoke Assert-CoordProtection -Times 1 -Exactly -Scope It -ModuleName $script:testModuleName
    Should -Invoke Assert-CoordOrdinaryPath -Times 0 -Exactly -Scope It -ModuleName $script:testModuleName
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

}
