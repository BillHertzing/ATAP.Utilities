Describe 'Orchestration module source manifest' -Tag 'Unit' {
  BeforeAll {
    $script:moduleRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
    $script:manifestPath = Join-Path $script:moduleRoot 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell.psd1'
    $script:manifest = Import-PowerShellDataFile -LiteralPath $script:manifestPath
    $script:version = Get-Content -LiteralPath (Join-Path $script:moduleRoot 'version.json') -Raw | ConvertFrom-Json
    $script:expectedExports = @('Get-CoordClaims', 'Get-CoordResult', 'Get-CoordTask', 'Stop-CoordClerk')
  }
  It 'pins the module identity and PowerShell platform' {
    $script:manifest.RootModule | Should -BeExactly 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell.psm1'
    $script:manifest.ModuleVersion | Should -BeExactly '0.1.3'
    $script:manifest.GUID | Should -BeExactly '01131809-7fd2-4b6d-8a34-f584b55ad4fa'
    $script:manifest.PowerShellVersion | Should -BeExactly '7.4'
    @($script:manifest.CompatiblePSEditions).Count | Should -Be 1
    $script:manifest.CompatiblePSEditions[0] | Should -BeExactly 'Core'
    $script:version.version | Should -BeExactly $script:manifest.ModuleVersion
    $script:manifest.CompanyName | Should -BeExactly 'ATAP'
    $script:manifest.Copyright | Should -BeExactly '(c) Bill Hertzing for ATAPUtilities.org. All rights reserved.'
  }
  It 'declares only the required PSFramework minimum' {
    @($script:manifest.RequiredModules).Count | Should -Be 1
    $script:manifest.RequiredModules[0].ModuleName | Should -BeExactly 'PSFramework'
    $script:manifest.RequiredModules[0].ModuleVersion | Should -BeExactly '1.14.457'
  }
  It 'declares exactly the three public queries and stop request' {
    $actual = [string[]]@($script:manifest.FunctionsToExport)
    [Array]::Sort($actual, [StringComparer]::Ordinal)
    $actual.Count | Should -Be 4
    for ($index = 0; $index -lt $script:expectedExports.Count; $index++) {
      $actual[$index] | Should -BeExactly $script:expectedExports[$index]
    }
  }
  It 'exports exactly the three public queries and stop request from the genuine source module' {
    $sourceModule = Import-Module -Name $script:manifestPath -Force -PassThru -ErrorAction Stop
    try {
      $expectedPath = Join-Path $script:moduleRoot $script:manifest.RootModule
      [StringComparer]::OrdinalIgnoreCase.Equals([IO.Path]::GetFullPath($sourceModule.Path), $expectedPath) | Should -BeTrue
      $actual = [string[]]@($sourceModule.ExportedFunctions.Keys)
      [Array]::Sort($actual, [StringComparer]::Ordinal)
      $actual.Count | Should -Be 4
      for ($index = 0; $index -lt $script:expectedExports.Count; $index++) {
        $actual[$index] | Should -BeExactly $script:expectedExports[$index]
      }
      @($sourceModule.ExportedCommands.Keys).Count | Should -Be 4
      @($sourceModule.ExportedAliases.Keys).Count | Should -Be 0
      @($sourceModule.ExportedCmdlets.Keys).Count | Should -Be 0
      @($sourceModule.ExportedVariables.Keys).Count | Should -Be 0
    } finally {
      Remove-Module -ModuleInfo $sourceModule -Force -ErrorAction Stop
    }
  }
  It 'explicitly exports no extra command types or variables' -ForEach @(
    @{ Key = 'CmdletsToExport' },
    @{ Key = 'VariablesToExport' }, @{ Key = 'AliasesToExport' }
  ) {
    $script:manifest.ContainsKey($Key) | Should -BeTrue
    @($script:manifest[$Key]).Count | Should -Be 0
  }
}
