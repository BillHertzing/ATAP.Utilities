#Requires -Module Pester

BeforeAll {
  $sourcePath = Join-Path $PSScriptRoot '..\..\public\Invoke-Flyway.ps1'
  $sourceText = Get-Content -LiteralPath $sourcePath -Raw
}

Describe 'Invoke-Flyway command argument safety' {
  It 'does not enable Flyway debug output by default' {
    $sourceText | Should -Match '(?s)\$flywayParams\s*=\s*@\(\s*"-configFiles=\$FlywayTomlPath"\s*,\s*"-environment=\$environmentKey"\s*\)'
    $sourceText | Should -Not -Match '(?s)\$flywayParams\s*=\s*@\([^\)]*[''\"]-X[''\"]'
  }

  It 'keeps debug flags available only through explicit additional arguments' {
    $sourceText | Should -Match 'if \(\$FlywayAdditionalArgs\) \{ \$flywayParams \+= \$FlywayAdditionalArgs \}'
  }
}
