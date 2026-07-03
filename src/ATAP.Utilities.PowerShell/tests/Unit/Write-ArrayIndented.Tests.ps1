BeforeAll {
  # Always load from sprint worktree source to override any stale profile-loaded definitions.
  # Pester 5 requires function loading in BeforeAll to make them visible inside It blocks.
  if (-not (Get-Command -Name 'Write-PSFMessage' -ErrorAction SilentlyContinue)) {
    function Write-PSFMessage { param([string]$FunctionName, [string]$ModuleName, [string]$Level, [string]$Message, [string[]]$Tag) }
  }
  $publicDir = Join-Path $PSScriptRoot '..\..\public'
  foreach ($helper in @('Write-KVPIndented', 'Write-HashIndented', 'Write-ArrayIndented')) {
    $helperPath = Join-Path $publicDir "$helper.ps1"
    if (Test-Path $helperPath) { . $helperPath } else { throw "Helper file not found: $helperPath" }
  }
}

Describe 'Write-ArrayIndented' -Tag 'Unit' {
  BeforeAll {
    Write-PSFMessage -FunctionName 'Write-ArrayIndented.Tests' -ModuleName 'ATAP.Utilities.PowerShell' -Level Debug -Message 'Starting Write-ArrayIndented tests'
  }

  Context 'Function availability' {
    It 'should be available as a function after dot-sourcing' {
      # Arrange / Act / Assert
      Get-Command -Name 'Write-ArrayIndented' -CommandType Function | Should -Not -BeNullOrEmpty
    }
  }

  Context 'Basic output shape' {
    It 'should return a string for a simple string array' {
      # Arrange
      $testArr = @('alpha', 'beta')
      # Act
      $result = Write-ArrayIndented -Array $testArr -Indent 0 -IndentIncrement 2
      # Assert
      $result | Should -BeOfType [string]
    }

    It 'should include array elements in the output' {
      # Arrange
      $testArr = @('hello', 'world')
      # Act
      $result = Write-ArrayIndented -Array $testArr -Indent 0 -IndentIncrement 2
      # Assert
      $result | Should -Match 'hello'
      $result | Should -Match 'world'
    }

    It 'should apply the specified indentation to output' {
      # Arrange
      $testArr = @('item')
      # Act
      $result = Write-ArrayIndented -Array $testArr -Indent 4 -IndentIncrement 2
      # Assert
      $result | Should -Match '^ {4}'
    }
  }

  Context 'Edge cases' {
    It 'should not throw on an empty array' {
      # Arrange / Act / Assert
      { Write-ArrayIndented -Array @() -Indent 0 -IndentIncrement 2 } | Should -Not -Throw
    }

    It 'should not throw on a null array' {
      # Arrange / Act / Assert
      { Write-ArrayIndented -Array $null -Indent 0 -IndentIncrement 2 } | Should -Not -Throw
    }

    It 'should handle a boolean element without throwing' {
      # Arrange / Act / Assert
      { Write-ArrayIndented -Array @($true, $false) -Indent 0 -IndentIncrement 2 } | Should -Not -Throw
    }

    It 'should handle a nested hashtable without throwing' {
      # Arrange / Act / Assert
      { Write-ArrayIndented -Array @(@{Key = 'Value' }) -Indent 0 -IndentIncrement 2 } | Should -Not -Throw
    }
  }
}
