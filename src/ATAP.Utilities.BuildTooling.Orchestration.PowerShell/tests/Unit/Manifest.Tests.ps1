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
Describe 'Orchestration selected module manifest' -Tag 'Unit' {
  BeforeAll {
    $currentModule = @(Get-Module -Name $script:C1956Binding.Module.Name -All)
    if ($currentModule.Count -ne 1 -or -not [object]::ReferenceEquals($currentModule[0], $script:C1956Binding.Module)) { throw 'SelectedTestModuleChangedAfterDiscovery' }
    $script:moduleRoot = $script:C1956Binding.ModuleBase
    $script:manifestPath = $script:C1956Binding.ManifestPath
    $script:manifest = Import-PowerShellDataFile -LiteralPath $script:manifestPath
    # Source version.json supplies expectation data only; shipped artifacts need
    # not contain that file, and no source implementation is loaded here.
    $script:version = Get-Content -LiteralPath (Join-Path $script:C1956Binding.SourceRoot 'version.json') -Raw | ConvertFrom-Json
    $script:expectedExports = @('Export-CoordState', 'Get-CoordClaims', 'Get-CoordResult', 'Get-CoordTask', 'Invoke-CoordClerk', 'Stop-CoordClerk', 'Submit-CoordRequest', 'Update-CoordWitness')
  }
  It 'pins the module identity and PowerShell platform' {
    $script:manifest.RootModule | Should -BeExactly 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell.psm1'
    $script:manifest.ModuleVersion | Should -BeExactly '0.1.7'
    $script:manifest.GUID | Should -BeExactly '01131809-7fd2-4b6d-8a34-f584b55ad4fa'
    $script:manifest.PowerShellVersion | Should -BeExactly '7.4'
    @($script:manifest.CompatiblePSEditions).Count | Should -Be 1
    @($script:manifest.CompatiblePSEditions)[0] | Should -BeExactly 'Core'
    $script:version.version | Should -BeExactly $script:manifest.ModuleVersion
    $script:manifest.CompanyName | Should -BeExactly 'ATAP'
    $script:manifest.Copyright | Should -BeExactly '(c) Bill Hertzing for ATAPUtilities.org. All rights reserved.'
  }
  It 'declares only the required PSFramework minimum' {
    @($script:manifest.RequiredModules).Count | Should -Be 1
    $script:manifest.RequiredModules[0].ModuleName | Should -BeExactly 'PSFramework'
    $script:manifest.RequiredModules[0].ModuleVersion | Should -BeExactly '1.14.457'
  }
  It 'declares the bounded producer, drain, export and read/control commands' {
    $actual = [string[]]@($script:manifest.FunctionsToExport)
    [Array]::Sort($actual, [StringComparer]::Ordinal)
    $actual.Count | Should -Be $script:expectedExports.Count
    for ($index = 0; $index -lt $script:expectedExports.Count; $index++) {
      $actual[$index] | Should -BeExactly $script:expectedExports[$index]
    }
  }
  It 'exports the declared commands from the genuine selected module' {
    $sourceModule = $script:C1956Binding.Module
    & {
      $expectedPath = Join-Path $script:moduleRoot $script:manifest.RootModule
      [StringComparer]::OrdinalIgnoreCase.Equals([IO.Path]::GetFullPath($sourceModule.Path), $expectedPath) | Should -BeTrue
      $actual = [string[]]@($sourceModule.ExportedFunctions.Keys)
      [Array]::Sort($actual, [StringComparer]::Ordinal)
      $actual.Count | Should -Be $script:expectedExports.Count
      for ($index = 0; $index -lt $script:expectedExports.Count; $index++) {
        $actual[$index] | Should -BeExactly $script:expectedExports[$index]
      }
      @($sourceModule.ExportedCommands.Keys).Count | Should -Be $script:expectedExports.Count
      @($sourceModule.ExportedAliases.Keys).Count | Should -Be 0
      @($sourceModule.ExportedCmdlets.Keys).Count | Should -Be 0
      @($sourceModule.ExportedVariables.Keys).Count | Should -Be 0
    }
  }
  It 'explicitly exports no extra command types or variables' -ForEach @(
    @{ Key = 'CmdletsToExport' },
    @{ Key = 'VariablesToExport' }, @{ Key = 'AliasesToExport' }
  ) {
    $script:manifest.ContainsKey($Key) | Should -BeTrue
    # Accept empty-array/empty-string encodings, never wildcard declarations.
    # The imported module's zero actual exports are checked independently above.
    @($script:manifest[$Key] | Where-Object { $null -ne $_ -and $_ -cne '' }).Count | Should -Be 0
  }
}

}
