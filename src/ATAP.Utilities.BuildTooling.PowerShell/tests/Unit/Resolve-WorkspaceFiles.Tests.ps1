BeforeAll {
  Import-Module ATAP.Utilities.BuildTooling.Common.PowerShell -Force
}

Describe 'Resolve-WorkspaceFiles [public]' {
  It 'resolves from the Common child module' {
    (Get-Command -Name 'Resolve-WorkspaceFiles').Source |
      Should -Be 'ATAP.Utilities.BuildTooling.Common.PowerShell'
  }

  BeforeAll {
    $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "rws_test_$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $script:tempDir -Force | Out-Null
  }

  AfterAll {
    Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
  }

  Context 'When all files exist' {
    It 'Returns fully resolved provider paths' {
      $wsFile = Join-Path $script:tempDir 'Test.code-workspace'
      Set-Content -Path $wsFile -Value '{}' -Encoding UTF8

      $result = Resolve-WorkspaceFiles -WorkspaceFiles @($wsFile)
      $result.Count | Should -Be 1
      @($result)[0] | Should -Be (Resolve-Path $wsFile).ProviderPath
    }

    It 'Resolves multiple files' {
      $ws1 = Join-Path $script:tempDir 'One.code-workspace'
      $ws2 = Join-Path $script:tempDir 'Two.code-workspace'
      Set-Content -Path $ws1 -Value '{}' -Encoding UTF8
      Set-Content -Path $ws2 -Value '{}' -Encoding UTF8

      $result = Resolve-WorkspaceFiles -WorkspaceFiles @($ws1, $ws2)
      $result.Count | Should -Be 2
    }
  }

  Context 'When a file does not exist' {
    It 'Throws an error' {
      { Resolve-WorkspaceFiles -WorkspaceFiles @('C:\nonexistent\fake.code-workspace') } |
        Should -Throw
    }
  }
}
