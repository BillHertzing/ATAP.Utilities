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

  It 'stages optional scripts and Documentation folders before packaging' {
    $text = Get-Content -LiteralPath $script:moduleBuildPath -Raw

    $text | Should -Match "\$moduleContentDirectories = @\('scripts', 'Documentation'\)"
    $text | Should -Match 'Copy-Item -LiteralPath \$sourceContentDirectory -Destination \$script:PackageSrcDir'
  }

  It 'supports a caller-supplied OutputRoot override for isolated package staging' {
    $text = Get-Content -LiteralPath $script:moduleBuildPath -Raw

    $text | Should -Match '\[string\] \$OutputRoot'
    $text | Should -Match '\[string\]::IsNullOrWhiteSpace\(\$OutputRoot\)'
    $text | Should -Match '\$script:OutputRoot = \$script:meta.OutputRoot'
    $text | Should -Match '\$script:OutputRoot = \(\$resolvedOutputRoot'
  }

  It 'bootstraps the failure-acknowledgement gate from the AiRendering child source' {
    $text = Get-Content -LiteralPath $script:moduleBuildPath -Raw

    $text | Should -Match "'Test-FailureAcknowledgedGate'\s*=\s*'ATAP\.Utilities\.BuildTooling\.AiRendering\.PowerShell'"
    $text | Should -Match '\$bootstrapModuleName'
    $text | Should -Not -Match "\$script:_bootstrapPublicDir.+ATAP\.Utilities\.BuildTooling\.PowerShell"
  }

  It 'makes sibling source modules discoverable only for the build process' {
    $text = Get-Content -LiteralPath $script:moduleBuildPath -Raw

    $text | Should -Match '\$script:_originalPSModulePath = \$env:PSModulePath'
    $text | Should -Match '\$env:PSModulePath = \$resolvedModulePath'
    $text | Should -Match 'Exit-Build\s*\{\s*\$env:PSModulePath = \$script:_originalPSModulePath'
  }

  It 'derives exported aliases from the source manifest and public function Alias attributes only' {
    $text = Get-Content -LiteralPath $script:moduleBuildPath -Raw

    $text | Should -Match 'Import-PowerShellDataFile -LiteralPath \$script:meta\.ManifestPath'
    $text | Should -Match '\$functionAst\.Body\.ParamBlock\.Attributes'
    $text | Should -Match 'if \(\$null -eq \$functionAst\.Body\.ParamBlock\)'
    $text | Should -Not -Match "GetCommandName\(\) -in @\('Set-Alias', 'New-Alias'\)"
  }

  It 'declares the legacy BWS compatibility names as function Alias metadata that survives package flattening' {
    $moduleRoot = Split-Path -Parent $script:moduleBuildPath
    $getSource = Get-Content -LiteralPath (Join-Path $moduleRoot 'src\ATAP.Utilities.BuildTooling.Secrets.PowerShell\public\Get-BWSAccessToken.ps1') -Raw
    $initializeSource = Get-Content -LiteralPath (Join-Path $moduleRoot 'src\ATAP.Utilities.BuildTooling.Secrets.PowerShell\public\Initialize-BWSAccessToken.ps1') -Raw

    $getSource | Should -Match "\[Alias\('Get-ServiceAccountBWSAccessToken'\)\]"
    $initializeSource | Should -Match "\[Alias\('Initialize-ServiceAccountBWSAccessToken'\)\]"
  }
}
