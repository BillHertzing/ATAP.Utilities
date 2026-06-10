#Requires -Version 7.0

Describe 'module.build.ps1 package staging contract' {
  BeforeAll {
    $script:moduleBuildPath = Join-Path -Path (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))) -ChildPath 'module.build.ps1'
  }

  It 'does not mutate the source module manifest during BuildManifest' {
    $text = Get-Content -LiteralPath $script:moduleBuildPath -Raw

    $text | Should -Not -Match 'Update-ModuleManifest\s+@sourceManifestParams'
    $text | Should -Not -Match 'updated source'
    $text | Should -Match 'Build-PSModuleManifest'
  }

  It 'packages the generated module directory that contains the generated psm1' {
    $text = Get-Content -LiteralPath $script:moduleBuildPath -Raw

    $text | Should -Match '\$script:PackageSrcDir = Join-Path \$script:PackagesDir \$script:ModuleName'
    $text | Should -Match '\$script:GeneratedPsm1Path = Join-Path \$script:PackageSrcDir'
    $text | Should -Match 'Publish-PSResource\s+`\s+\r?\n\s+-Path \$script:PackageSrcDir'
  }

  It 'supports a caller-supplied OutputRoot override for isolated package staging' {
    $text = Get-Content -LiteralPath $script:moduleBuildPath -Raw

    $text | Should -Match '\[string\] \$OutputRoot'
    $text | Should -Match '\[string\]::IsNullOrWhiteSpace\(\$OutputRoot\)'
    $text | Should -Match '\$script:OutputRoot = \$script:meta.OutputRoot'
    $text | Should -Match '\$script:OutputRoot = \(\$resolvedOutputRoot'
  }
}
