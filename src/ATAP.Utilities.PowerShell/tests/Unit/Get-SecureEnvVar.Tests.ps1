# Get-SecureEnvVar.Tests.ps1
# Static source-analysis tests for Get-SecureEnvVar.
# NOTE: Calling ATAP module functions or Get-Command on ATAP functions inside
# Pester's execution context causes a runaway on this machine (PSFramework/Pester
# interaction). All tests here are pure source-file content checks — no function
# calls, no Get-Command on ATAP functions.

Describe 'Get-SecureEnvVar - source analysis' {

  BeforeAll {
    $script:srcPath = Join-Path $PSScriptRoot '..\..\public\Get-SecureEnvVar.ps1'
    $script:src = if (Test-Path $script:srcPath) { Get-Content $script:srcPath -Raw } else { '' }
  }

  Context 'File exists' {
    It 'source file is present at expected path' {
      Test-Path $script:srcPath | Should -BeTrue
    }
  }

  Context 'Function declaration' {
    It 'declares function Get-SecureEnvVar' {
      $script:src | Should -Match 'function\s+Get-SecureEnvVar'
    }
    It 'has [CmdletBinding()] attribute' {
      $script:src | Should -Match '\[CmdletBinding'
    }
    It 'declares Mandatory VarName parameter' {
      $script:src | Should -Match 'Mandatory'
      $script:src | Should -Match '\$VarName'
    }
    It 'declares Mandatory BitwardenItemId parameter' {
      $script:src | Should -Match '\$BitwardenItemId'
    }
    It 'has ValidateNotNullOrEmpty on parameters' {
      $script:src | Should -Match 'ValidateNotNullOrEmpty'
    }
  }

  Context 'R-10 compliance - User scope checked via GetEnvironmentVariable' {
    It 'calls GetEnvironmentVariable with User scope for VarName' {
      $script:src | Should -Match "GetEnvironmentVariable.*'User'"
    }
    It 'resolves BW_SESSION from User scope' {
      $script:src | Should -Match "GetEnvironmentVariable\('BW_SESSION'.*'User'"
    }
    It 'does NOT use dollar-env colon BW_SESSION shortcut' {
      $script:src | Should -Not -Match '\$env:BW_SESSION'
    }
  }

  Context 'Error handling' {
    It 'throws when BW_SESSION is absent (has throw statement)' {
      $script:src | Should -Match '\bthrow\b'
    }
    It 'error message references BW_SESSION' {
      $script:src | Should -Match 'BW_SESSION absent'
    }
  }

  Context 'No hard-coded credentials or paths' {
    It 'no hard-coded session token value' {
      $script:src | Should -Not -Match '--session\s+[''"]{1}[a-zA-Z0-9]'
    }
    It 'no hard-coded C:\\Temp path' {
      $script:src | Should -Not -Match 'C:\\Temp'
    }
  }
}
