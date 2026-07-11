#Requires -Version 7.0

Describe 'Invoke-ModuleBuildWithRetry retry policy' {
  BeforeAll {
    $script:functionPath = Join-Path -Path $PSScriptRoot -ChildPath '../../public/Invoke-ModuleBuildWithRetry.ps1'
  }

  It 'treats transient file-lock errors as retryable' {
    $text = Get-Content -LiteralPath $script:functionPath -Raw

    $text | Should -Match '\$fileLockErrorPattern'
    $text | Should -Match 'process cannot access the file'
    $text | Should -Match 'being used by another process'
    $text | Should -Match 'transient file lock'
  }

  It 'keeps retry messaging aligned with supported retry categories' {
    $text = Get-Content -LiteralPath $script:functionPath -Raw

    $text | Should -Match 'PSResourceGet/network/file-lock failures'
    $text | Should -Match 'PSResourceGet, network, or file-lock failure'
  }

  It 'passes OutputRoot through to module.build.ps1 when supplied' {
    $text = Get-Content -LiteralPath $script:functionPath -Raw

    $text | Should -Match '\[string\] \$OutputRoot'
    $text | Should -Match '\$invokeBuildParameters\[''OutputRoot''\] = \$OutputRoot'
    $text | Should -Match 'Invoke-Build \$Task @invokeBuildParameters'
  }

  It 'uses the imported configuration helper before attempting the source-tree fallback' {
    $text = Get-Content -LiteralPath $script:functionPath -Raw

    $guardIndex = $text.IndexOf("Get-Command -Name 'Get-ParameterValueFromNeoConfigurationRoot'")
    $fallbackIndex = $text.IndexOf("Source helper file not found: `$neoConfigurationPath")

    $guardIndex | Should -BeGreaterThan -1
    $fallbackIndex | Should -BeGreaterThan $guardIndex
    $text | Should -Match "if \(-not \(Get-Command -Name 'Get-ParameterValueFromNeoConfigurationRoot' -CommandType Function -ErrorAction SilentlyContinue\)\)"
  }
}
