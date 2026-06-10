BeforeAll {
  Import-Module ATAP.Utilities.BuildTooling.PowerShell -Force
}

Describe 'Assert-GitAvailable [private]' {
  Context 'When git is on PATH' {
    BeforeAll {
      Mock Test-CommandExists { return $true } -ParameterFilter { $Name -eq 'git' }
    }

    It 'Does not throw' {
      { Assert-GitAvailable } | Should -Not -Throw
    }
  }

  Context 'When git is not on PATH' {
    BeforeAll {
      Mock Test-CommandExists { return $false } -ParameterFilter { $Name -eq 'git' }
    }

    It 'Throws with a descriptive message' {
      { Assert-GitAvailable } | Should -Throw "*'git' was not found*"
    }
  }
}
