BeforeAll {
  Import-Module ATAP.Utilities.BuildTooling.Common.PowerShell -Force
}

Describe 'Get-WorkspaceJson [public]' {
  It 'resolves from the Common child module' {
    (Get-Command -Name 'Get-WorkspaceJson').Source |
      Should -Be 'ATAP.Utilities.BuildTooling.Common.PowerShell'
  }

  BeforeAll {
    $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "gwj_test_$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $script:tempDir -Force | Out-Null
  }

  AfterAll {
    Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
  }

  Context 'When the file contains valid JSON' {
    It 'Returns a PSCustomObject with expected properties' {
      $wsFile = Join-Path $script:tempDir 'Valid.code-workspace'
      $json = @{
        folders  = @(@{ path = '.' })
        settings = @{ 'atap.sharedVSCode.templateRef' = 'main' }
      } | ConvertTo-Json -Depth 10
      Set-Content -Path $wsFile -Value $json -Encoding UTF8

      $result = Get-WorkspaceJson -WorkspaceFile $wsFile
      $result.settings.'atap.sharedVSCode.templateRef' | Should -Be 'main'
      $result.folders | Should -Not -BeNullOrEmpty
    }
  }

  Context 'When the file does not exist' {
    It 'Throws with file-not-found message' {
      { Get-WorkspaceJson -WorkspaceFile 'C:\nonexistent\fake.code-workspace' } |
        Should -Throw '*not found*'
    }
  }

  Context 'When the file contains invalid JSON' {
    It 'Throws a JSON parse error' {
      $badFile = Join-Path $script:tempDir 'Bad.code-workspace'
      Set-Content -Path $badFile -Value 'NOT JSON' -Encoding UTF8

      { Get-WorkspaceJson -WorkspaceFile $badFile } | Should -Throw
    }
  }
}
