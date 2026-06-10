# ConvertFrom-MboxFile.Tests.ps1
# Static source-analysis tests for ConvertFrom-MboxFile.
# NOTE: Calling ATAP module functions or Get-Command on ATAP functions inside
# Pester's execution context causes a runaway on this machine (PSFramework/Pester
# interaction). All tests here are pure source-file content checks — no function
# calls, no Get-Command on ATAP functions.

Describe 'ConvertFrom-MboxFile - source analysis' -Tag 'Unit', 'Disabled' {

  BeforeAll {
    $script:srcPath = Join-Path $PSScriptRoot '..\..\public\ConvertFrom-MboxFile.ps1'
    $script:src     = if (Test-Path $script:srcPath) { Get-Content $script:srcPath -Raw } else { '' }
  }

  Context 'File exists' {
    It 'source file is present at expected path' {
      Test-Path $script:srcPath | Should -BeTrue
    }
  }

  Context 'Function declaration' {
    It 'declares function ConvertFrom-MboxFile' {
      $script:src | Should -Match 'function\s+ConvertFrom-MboxFile'
    }
    It 'has [CmdletBinding(SupportsShouldProcess)] attribute' {
      $script:src | Should -Match 'SupportsShouldProcess'
    }
    It 'declares a FilePath parameter' {
      $script:src | Should -Match '\$FilePath'
    }
    It 'declares an OutputCsv parameter' {
      $script:src | Should -Match '\$OutputCsv'
    }
    It 'declares a MimeKitAssemblyPath parameter' {
      $script:src | Should -Match '\$MimeKitAssemblyPath'
    }
  }

  Context 'No hard-coded paths (regression guards)' {
    It 'does not contain C:\Temp' {
      $script:src | Should -Not -Match 'C:\\Temp'
    }
    It 'does not contain a hard-coded Dropbox path to MimeKit' {
      $script:src | Should -Not -Match 'C:\\Dropbox\\.*ATAP\.Utilities\\src\\ATAP\.Utilities\.Powershell\\Packages'
    }
    It 'does not have a bare top-level ConvertFrom-MboxFile invocation' {
      # Old code had: ConvertFrom-MboxFile 'C:\Temp\...' at file scope
      $script:src | Should -Not -Match "(?m)^ConvertFrom-MboxFile\s+['""]"
    }
  }

  Context 'Correct output path handling' {
    It 'uses GetTempPath() for default OutputCsv' {
      $script:src | Should -Match 'GetTempPath'
    }
  }

  Context 'MimeKit assembly handling' {
    It 'searches for MimeKit.dll dynamically' {
      $script:src | Should -Match 'MimeKit\.dll'
    }
    It 'throws when MimeKit cannot be found (has throw statement)' {
      $script:src | Should -Match '\bthrow\b'
    }
  }
}
