BeforeAll {
  Import-Module ATAP.Utilities.BuildTooling.PowerShell -Force
}

Describe 'Test-CommandExists [private]' {
  It 'Returns $true for a command that exists' {
    Test-CommandExists -Name 'Get-Command' | Should -BeTrue
  }

  It 'Returns $false for a command that does not exist' {
    Test-CommandExists -Name 'Invoke-CompletelyFakeCommand_12345' | Should -BeFalse
  }

  It 'Throws when Name is empty' {
    { Test-CommandExists -Name '' } | Should -Throw
  }

  It 'Handles alias names' {
    # 'dir' is a built-in alias for Get-ChildItem on Windows PowerShell
    # and 'gci' is an alias in both editions
    Test-CommandExists -Name 'gci' | Should -BeTrue
  }
}
