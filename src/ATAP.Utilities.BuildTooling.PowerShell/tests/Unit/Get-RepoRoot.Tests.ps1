BeforeAll {
  . "$PSScriptRoot\..\Import-SharedVSCodeFunctions.ps1"
}

Describe 'Get-RepoRoot [private]' {
  Context 'When inside a Git working tree' {
    BeforeAll {
      Mock Assert-GitAvailable { }
      Mock git { return '/fake/repo/root' } -ParameterFilter {
        $args[0] -eq 'rev-parse' -and $args[1] -eq '--show-toplevel'
      }
    }

    It 'Returns the trimmed repo root path' {
      Get-RepoRoot | Should -Be '/fake/repo/root'
    }
  }

  Context 'When not inside a Git working tree' {
    BeforeAll {
      Mock Assert-GitAvailable { }
      Mock git { return $null } -ParameterFilter {
        $args[0] -eq 'rev-parse' -and $args[1] -eq '--show-toplevel'
      }
    }

    It 'Throws with a descriptive message' {
      { Get-RepoRoot } | Should -Throw '*not inside a Git working tree*'
    }
  }

  It 'Calls Assert-GitAvailable before invoking git' {
    Mock Assert-GitAvailable { throw 'no git' }
    { Get-RepoRoot } | Should -Throw '*no git*'
    Should -Invoke Assert-GitAvailable -Times 1 -Exactly -Scope It
  }
}
