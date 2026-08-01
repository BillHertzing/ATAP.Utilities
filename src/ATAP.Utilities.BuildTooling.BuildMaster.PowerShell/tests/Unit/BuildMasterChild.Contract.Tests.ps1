Describe 'BuildMaster child module loader contract' -Tag 'Unit' {
  BeforeAll {
    $script:moduleRoot = Split-Path -Path $PSScriptRoot -Parent | Split-Path -Parent
    $script:manifestPath = Join-Path $script:moduleRoot 'ATAP.Utilities.BuildTooling.BuildMaster.PowerShell.psd1'
  }

  It 'imports under ErrorActionPreference Stop when the optional private directory is absent' {
    Test-Path -LiteralPath (Join-Path $script:moduleRoot 'private') | Should -BeFalse

    $previousPreference = $ErrorActionPreference
    try {
      $ErrorActionPreference = 'Stop'
      { Import-Module $script:manifestPath -Force -ErrorAction Stop } | Should -Not -Throw
    } finally {
      $ErrorActionPreference = $previousPreference
      Remove-Module ATAP.Utilities.BuildTooling.BuildMaster.PowerShell -Force -ErrorAction SilentlyContinue
    }
  }
}
