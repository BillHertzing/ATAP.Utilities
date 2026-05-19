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
}
