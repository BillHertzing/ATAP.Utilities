BeforeAll {
  $script:moduleRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
  $script:manifest = Import-PowerShellDataFile -LiteralPath (Join-Path $script:moduleRoot 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell.psd1')
  $script:version = Get-Content -LiteralPath (Join-Path $script:moduleRoot 'version.json') -Raw | ConvertFrom-Json
}

Describe 'Orchestration module source manifest' -Tag 'Unit' {
  It 'pins the module identity and PowerShell platform' {
    $script:manifest.RootModule | Should -BeExactly 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell.psm1'
    $script:manifest.ModuleVersion | Should -BeExactly '0.1.0'
    $script:manifest.GUID | Should -BeExactly '01131809-7fd2-4b6d-8a34-f584b55ad4fa'
    $script:manifest.PowerShellVersion | Should -BeExactly '7.4'
    @($script:manifest.CompatiblePSEditions).Count | Should -Be 1
    $script:manifest.CompatiblePSEditions[0] | Should -BeExactly 'Core'
    $script:version.version | Should -BeExactly $script:manifest.ModuleVersion
  }
  It 'declares only the required PSFramework minimum' {
    @($script:manifest.RequiredModules).Count | Should -Be 1
    $script:manifest.RequiredModules[0].ModuleName | Should -BeExactly 'PSFramework'
    $script:manifest.RequiredModules[0].ModuleVersion | Should -BeExactly '1.14.457'
  }
  It 'exports only implemented Get-CoordTask' {
    @($script:manifest.FunctionsToExport).Count | Should -Be 1
    $script:manifest.FunctionsToExport[0] | Should -BeExactly 'Get-CoordTask'
  }
  It 'explicitly exports no extra command types or variables' -ForEach @(
    @{ Key = 'CmdletsToExport' },
    @{ Key = 'VariablesToExport' }, @{ Key = 'AliasesToExport' }
  ) {
    $script:manifest.ContainsKey($Key) | Should -BeTrue
    @($script:manifest[$Key]).Count | Should -Be 0
  }
}
