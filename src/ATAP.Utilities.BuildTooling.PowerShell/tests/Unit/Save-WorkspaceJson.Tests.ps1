BeforeAll {
  . "$PSScriptRoot\..\Import-SharedVSCodeFunctions.ps1"
}

Describe 'Save-WorkspaceJson [private]' {
  BeforeAll {
    $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "swj_test_$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $script:tempDir -Force | Out-Null
  }

  AfterAll {
    Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
  }

  It 'Writes valid JSON that round-trips through Get-WorkspaceJson' {
    $wsFile = Join-Path $script:tempDir 'RoundTrip.code-workspace'
    $obj = [PSCustomObject]@{
      folders  = @([PSCustomObject]@{ path = '.' })
      settings = [PSCustomObject]@{ 'atap.sharedVSCode.templateRef' = 'main' }
    }

    Save-WorkspaceJson -WorkspaceFile $wsFile -Json $obj

    $parsed = Get-WorkspaceJson -WorkspaceFile $wsFile
    $parsed.settings.'atap.sharedVSCode.templateRef' | Should -Be 'main'
  }

  It 'Overwrites existing file content completely' {
    $wsFile = Join-Path $script:tempDir 'Overwrite.code-workspace'
    Set-Content -Path $wsFile -Value '{"old": true}' -Encoding UTF8

    $obj = [PSCustomObject]@{ replaced = $true }
    Save-WorkspaceJson -WorkspaceFile $wsFile -Json $obj

    $raw = Get-Content -Path $wsFile -Raw -Encoding UTF8
    $raw | Should -Not -Match '"old"'
    ($raw | ConvertFrom-Json).replaced | Should -BeTrue
  }

  It 'Preserves deeply nested structures' {
    $wsFile = Join-Path $script:tempDir 'Deep.code-workspace'
    $obj = [PSCustomObject]@{
      level1 = [PSCustomObject]@{
        level2 = [PSCustomObject]@{
          level3 = 'deep-value'
        }
      }
    }

    Save-WorkspaceJson -WorkspaceFile $wsFile -Json $obj

    $parsed = Get-WorkspaceJson -WorkspaceFile $wsFile
    $parsed.level1.level2.level3 | Should -Be 'deep-value'
  }
}
