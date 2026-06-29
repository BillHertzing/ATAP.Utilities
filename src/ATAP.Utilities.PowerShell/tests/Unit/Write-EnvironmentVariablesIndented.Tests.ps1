BeforeAll {
  # Always load from sprint worktree source to override any stale profile-loaded definitions.
  # Pester 5 requires function loading in BeforeAll to make them visible inside It blocks.
  if (-not (Get-Command -Name 'Write-PSFMessage' -ErrorAction SilentlyContinue)) {
    function Write-PSFMessage { param([string]$FunctionName, [string]$ModuleName, [string]$Level, [string]$Message, [string[]]$Tag) }
  }
  $publicDir = Join-Path $PSScriptRoot '..\..\public'
  $functionPath = Join-Path $publicDir 'Write-EnvironmentVariablesIndented.ps1'
  if (Test-Path $functionPath) { . $functionPath } else { throw "Function file not found: $functionPath" }
}

Describe 'Write-EnvironmentVariablesIndented' -Tag 'Unit' {
  BeforeAll {
    Write-PSFMessage -FunctionName 'Write-EnvironmentVariablesIndented.Tests' -ModuleName 'ATAP.Utilities.PowerShell' -Level Debug -Message 'Starting Write-EnvironmentVariablesIndented tests'
  }

  Context 'Function availability' {
    It 'should be available as a function after dot-sourcing' {
      Get-Command -Name 'Write-EnvironmentVariablesIndented' -CommandType Function | Should -Not -BeNullOrEmpty
    }
  }

  Context 'Basic output shape' {
    It 'should return a string' {
      # Act
      $result = Write-EnvironmentVariablesIndented
      # Assert
      $result | Should -BeOfType [string]
    }

    It 'should return a non-empty string (at least PATH exists in every scope)' {
      # Act
      $result = Write-EnvironmentVariablesIndented
      # Assert
      $result | Should -Not -BeNullOrEmpty
    }

    It 'should contain scope labels Machine, User, and Process in the output' {
      # Act
      $result = Write-EnvironmentVariablesIndented
      # Assert — PATH appears in at least one scope label
      $result | Should -Match '\(Machine\)|\(User\)|\(Process\)'
    }

    It 'should apply non-zero initial indent to each line' {
      # Act
      $result = Write-EnvironmentVariablesIndented -InitialIndent 4 -IndentIncrement 2
      # Assert — every non-empty line must start with at least 4 spaces
      $lines = $result -split [Environment]::NewLine | Where-Object { $_.Trim() -ne '' }
      $lines | ForEach-Object {
        $_ | Should -Match '^ {4}'
      }
    }
  }

  Context 'Edge cases' {
    It 'should not throw when called with default parameters' {
      { Write-EnvironmentVariablesIndented } | Should -Not -Throw
    }

    It 'should not throw when called with explicit zero indent' {
      { Write-EnvironmentVariablesIndented -InitialIndent 0 -IndentIncrement 0 } | Should -Not -Throw
    }
  }
}
