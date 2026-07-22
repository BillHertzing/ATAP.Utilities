BeforeAll {
  $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $manifestPath = Join-Path $moduleRoot 'ATAP.Utilities.BuildTooling.Common.PowerShell.psd1'
  $script:Manifest = Import-PowerShellDataFile -LiteralPath $manifestPath

  $promotedManifest = [System.Environment]::GetEnvironmentVariable('ATAP_PROMOTED_MODULE_MANIFEST', 'Process')
  Remove-Module -Name 'ATAP.Utilities.BuildTooling.Common.PowerShell' -Force -ErrorAction SilentlyContinue
  $moduleToTest = if ([string]::IsNullOrWhiteSpace($promotedManifest)) { $manifestPath } else { $promotedManifest }
  $script:ImportedModule = Import-Module -Name $moduleToTest -Force -PassThru -ErrorAction Stop
}

Describe 'ATAP.Utilities.BuildTooling.Common.PowerShell scaffold contract' -Tag 'Unit' {
  It 'declares the expected PowerShell platform policy' {
    $script:Manifest.PowerShellVersion | Should -Be '7.0'
    $script:Manifest.CompatiblePSEditions | Should -Be @('Core')
  }

  It 'uses the approved explicit function exports' {
    @($script:Manifest.FunctionsToExport) | Should -Be @(
      'Assert-GitAvailable',
      'Get-RepositoryRoot',
      'Get-WorkspaceJson',
      'Initialize-ATAPConfigurationGlobals',
      'Resolve-WorkspaceFiles'
    )
    @($script:Manifest.CmdletsToExport).Count | Should -Be 0
    @($script:Manifest.VariablesToExport).Count | Should -Be 0
    @($script:Manifest.AliasesToExport).Count | Should -Be 0
  }

  It 'keeps the first batch free of shared types and assemblies' {
    $script:Manifest.ContainsKey('RequiredAssemblies') | Should -BeFalse
    @(Get-ChildItem -LiteralPath $moduleRoot -Filter '*.dll' -File -Recurse).Count | Should -Be 0
    @(Get-ChildItem -LiteralPath (Join-Path $moduleRoot 'lib') -Filter '*.types.ps1' -File -ErrorAction SilentlyContinue).Count | Should -Be 0
  }

  It 'imports from its manifest and exposes the approved commands' {
    $script:ImportedModule | Should -Not -BeNullOrEmpty
    @($script:ImportedModule.ExportedCommands.Keys | Sort-Object) | Should -Be @(
      'Assert-GitAvailable',
      'Get-RepositoryRoot',
      'Get-WorkspaceJson',
      'Initialize-ATAPConfigurationGlobals',
      'Resolve-WorkspaceFiles'
    )
  }
}
