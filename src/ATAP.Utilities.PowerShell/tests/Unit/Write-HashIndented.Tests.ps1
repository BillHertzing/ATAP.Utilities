BeforeAll {
  # Always load from sprint worktree source to override any stale profile-loaded definitions.
  # Pester 5 requires function loading in BeforeAll to make them visible inside It blocks.
  if (-not (Get-Command -Name 'Write-PSFMessage' -ErrorAction SilentlyContinue)) {
    function Write-PSFMessage { param([string]$FunctionName, [string]$ModuleName, [string]$Level, [string]$Message, [string[]]$Tag) }
  }
  $publicDir = Join-Path $PSScriptRoot '..\..\public'
  foreach ($helper in @('Write-ArrayIndented', 'Write-KVPIndented', 'Write-HashIndented')) {
    $helperPath = Join-Path $publicDir "$helper.ps1"
    if (Test-Path $helperPath) { . $helperPath } else { throw "Helper file not found: $helperPath" }
  }
}

Describe 'Write-HashIndented' -Tag 'Unit' {
  BeforeAll {
    Write-PSFMessage -FunctionName 'Write-HashIndented.Tests' -ModuleName 'ATAP.Utilities.PowerShell' -Level Debug -Message 'Starting Write-HashIndented tests'
  }

  Context 'Function availability' {
    It 'should be available as a function after dot-sourcing' {
      Get-Command -Name 'Write-HashIndented' -CommandType Function | Should -Not -BeNullOrEmpty
    }
  }

  Context 'Basic output shape' {
    It 'should return a string for a simple hashtable' {
      # Arrange
      $hash = @{Alpha = 'a'; Beta = 'b' }
      # Act
      $result = Write-HashIndented -Hash $hash -InitialIndent 0 -IndentIncrement 2
      # Assert
      $result | Should -BeOfType [string]
    }

    It 'should include all keys in the output' {
      # Arrange
      $hash = @{Color = 'Red'; Size = 'Large' }
      # Act
      $result = Write-HashIndented -Hash $hash -InitialIndent 0 -IndentIncrement 2
      # Assert
      $result | Should -Match 'Color'
      $result | Should -Match 'Size'
    }

    It 'should sort keys alphabetically' {
      # Arrange
      $hash = @{Zebra = 'z'; Apple = 'a' }
      # Act
      $result = Write-HashIndented -Hash $hash -InitialIndent 0 -IndentIncrement 2
      # Assert — Apple should appear before Zebra
      $applePos = $result.IndexOf('Apple')
      $zebraPos = $result.IndexOf('Zebra')
      $applePos | Should -BeLessThan $zebraPos
    }

    It 'should apply initial indentation' {
      # Arrange
      $hash = @{Key = 'Value' }
      # Act
      $result = Write-HashIndented -Hash $hash -InitialIndent 4 -IndentIncrement 2
      # Assert
      $result | Should -Match '^ {4}Key'
    }
  }

  Context 'Edge cases' {
    It 'should not throw on an empty hashtable' {
      { Write-HashIndented -Hash @{} -InitialIndent 0 -IndentIncrement 2 } | Should -Not -Throw
    }

    It 'should return an empty string for an empty hashtable' {
      $result = Write-HashIndented -Hash @{} -InitialIndent 0 -IndentIncrement 2
      $result | Should -BeNullOrEmpty
    }
  }
}
