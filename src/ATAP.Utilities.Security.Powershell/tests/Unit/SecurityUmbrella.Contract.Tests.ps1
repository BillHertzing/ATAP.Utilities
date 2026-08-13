#Requires -Module Pester

Describe 'ATAP.Utilities.Security.Powershell umbrella contract' -Tag 'Unit' {
  BeforeAll {
    $script:ModuleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $sourceManifest = Join-Path $script:ModuleRoot 'ATAP.Utilities.Security.Powershell.psd1'
    $promotedManifest = [Environment]::GetEnvironmentVariable('ATAP_PROMOTED_MODULE_MANIFEST', 'Process')
    $script:ManifestPath = if ([string]::IsNullOrWhiteSpace($promotedManifest)) { $sourceManifest } else { $promotedManifest }
    $script:Manifest = Import-PowerShellDataFile -LiteralPath $script:ManifestPath
  }

  It 'depends on the PKI and Secrets child modules' {
    $requiredNames = @($script:Manifest.RequiredModules | ForEach-Object {
        if ($_ -is [string]) { $_ } else { $_.ModuleName }
      })
    $requiredNames | Should -Contain 'ATAP.Utilities.Security.PKI.PowerShell'
    $requiredNames | Should -Contain 'ATAP.Utilities.Security.Secrets.PowerShell'
  }

  It 'declares an explicit non-wildcard public surface' {
    @($script:Manifest.FunctionsToExport).Count | Should -BeGreaterThan 0
    @($script:Manifest.FunctionsToExport | Where-Object { $_ -match '[*?]' }).Count | Should -Be 0
  }
}
