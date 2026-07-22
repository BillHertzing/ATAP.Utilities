BeforeAll {
  $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $manifestPath = Join-Path $moduleRoot 'ATAP.Utilities.BuildTooling.Common.PowerShell.psd1'
  Import-Module -Name $manifestPath -Force
}

Describe 'Assert-GitAvailable' -Tag 'Unit' {
  Context 'When git is on PATH' {
    BeforeAll {
      Mock Get-Command -ModuleName ATAP.Utilities.BuildTooling.Common.PowerShell { [PSCustomObject]@{ Name = 'git' } } -ParameterFilter { $Name -eq 'git' }
    }

    It 'does not throw' {
      { Assert-GitAvailable } | Should -Not -Throw
    }
  }

  Context 'When git is not on PATH' {
    BeforeAll {
      Mock Get-Command -ModuleName ATAP.Utilities.BuildTooling.Common.PowerShell { $null } -ParameterFilter { $Name -eq 'git' }
    }

    It 'throws a descriptive error' {
      { Assert-GitAvailable } | Should -Throw "*'git' was not found*"
    }
  }
}
