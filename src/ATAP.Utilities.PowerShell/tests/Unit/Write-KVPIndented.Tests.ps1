BeforeAll {
  # Always load from sprint worktree source to override any stale profile-loaded definitions.
  # Pester 5 requires function loading in BeforeAll to make them visible inside It blocks.
  if (-not (Get-Command -Name 'Write-PSFMessage' -ErrorAction SilentlyContinue)) {
    function Write-PSFMessage { param([string]$FunctionName, [string]$ModuleName, [string]$Level, [string]$Message, [string[]]$Tag) }
  }
  $publicDir = Join-Path $PSScriptRoot '..\..\public'
  foreach ($helper in @('Write-ArrayIndented', 'Write-HashIndented', 'Write-KVPIndented')) {
    $helperPath = Join-Path $publicDir "$helper.ps1"
    if (Test-Path $helperPath) { . $helperPath } else { throw "Helper file not found: $helperPath" }
  }
}

Describe 'Write-KVPIndented' -Tag 'Unit' {
  BeforeAll {
    Write-PSFMessage -FunctionName 'Write-KVPIndented.Tests' -ModuleName 'ATAP.Utilities.PowerShell' -Level Debug -Message 'Starting Write-KVPIndented tests'
  }

  Context 'Function availability' {
    It 'should be available as a function after dot-sourcing' {
      Get-Command -Name 'Write-KVPIndented' -CommandType Function | Should -Not -BeNullOrEmpty
    }
  }

  Context 'Basic output shape' {
    It 'should return a string for a string-valued KVP' {
      # Arrange — simulate a DictionaryEntry
      $ht = @{Color = 'Red' }
      $kvp = $ht.GetEnumerator() | Select-Object -First 1
      # Act
      $result = Write-KVPIndented -KVP $kvp -Indent 0 -IndentIncrement 2
      # Assert
      $result | Should -BeOfType [string]
    }

    It 'should include the key in the output' {
      # Arrange
      $ht = @{MyKey = 'MyValue' }
      $kvp = $ht.GetEnumerator() | Select-Object -First 1
      # Act
      $result = Write-KVPIndented -KVP $kvp -Indent 0 -IndentIncrement 2
      # Assert
      $result | Should -Match 'MyKey'
    }

    It 'should include the value in the output for a string value' {
      # Arrange
      $ht = @{Greeting = 'Hello' }
      $kvp = $ht.GetEnumerator() | Select-Object -First 1
      # Act
      $result = Write-KVPIndented -KVP $kvp -Indent 0 -IndentIncrement 2
      # Assert
      $result | Should -Match 'Hello'
    }

    It 'should apply the specified indentation' {
      # Arrange
      $ht = @{Item = 'Value' }
      $kvp = $ht.GetEnumerator() | Select-Object -First 1
      # Act
      $result = Write-KVPIndented -KVP $kvp -Indent 6 -IndentIncrement 2
      # Assert
      $result | Should -Match '^ {6}'
    }

    It 'should end with a newline' {
      # Arrange
      $ht = @{X = 'Y' }
      $kvp = $ht.GetEnumerator() | Select-Object -First 1
      # Act
      $result = Write-KVPIndented -KVP $kvp -Indent 0 -IndentIncrement 2
      # Assert — result ends with a newline character
      $result[-1] | Should -BeIn @("`n", "`r")
    }
  }

  Context 'Edge cases' {
    It 'should handle a boolean value without throwing' {
      $ht = @{Flag = $true }
      $kvp = $ht.GetEnumerator() | Select-Object -First 1
      { Write-KVPIndented -KVP $kvp -Indent 0 -IndentIncrement 2 } | Should -Not -Throw
    }

    It 'should handle a nested array value without throwing' {
      $ht = @{Items = @('a', 'b') }
      $kvp = $ht.GetEnumerator() | Select-Object -First 1
      { Write-KVPIndented -KVP $kvp -Indent 0 -IndentIncrement 2 } | Should -Not -Throw
    }

    It 'should handle a nested hashtable value without throwing' {
      $ht = @{Nested = @{Inner = 'val' } }
      $kvp = $ht.GetEnumerator() | Select-Object -First 1
      { Write-KVPIndented -KVP $kvp -Indent 0 -IndentIncrement 2 } | Should -Not -Throw
    }
  }
}
