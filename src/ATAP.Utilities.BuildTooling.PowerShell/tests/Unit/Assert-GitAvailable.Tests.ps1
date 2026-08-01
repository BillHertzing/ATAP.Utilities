BeforeAll {
  Import-Module ATAP.Utilities.BuildTooling.PowerShell -Force
}

InModuleScope ATAP.Utilities.BuildTooling.PowerShell {
  Describe 'Assert-GitAvailable [private]' {
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
