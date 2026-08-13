Import-Module ATAP.Utilities.BuildTooling.Common.PowerShell -Force

InModuleScope ATAP.Utilities.BuildTooling.Common.PowerShell {
  Describe 'Assert-GitAvailable [public]' {
    It 'resolves from the Common child module' {
      (Get-Command -Name 'Assert-GitAvailable').Source |
        Should -Be 'ATAP.Utilities.BuildTooling.Common.PowerShell'
    }

    Context 'When git is on PATH' {
      BeforeAll {
        Mock Get-Command { [PSCustomObject]@{ Name = 'git' } } -ParameterFilter { $Name -eq 'git' }
      }

      It 'Does not throw' {
        { Assert-GitAvailable } | Should -Not -Throw
      }
    }

    Context 'When git is not on PATH' {
      BeforeAll {
        Mock Get-Command { $null } -ParameterFilter { $Name -eq 'git' }
      }

      It 'Throws with a descriptive message' {
        { Assert-GitAvailable } | Should -Throw "*'git' was not found*"
      }
    }
  }
}
