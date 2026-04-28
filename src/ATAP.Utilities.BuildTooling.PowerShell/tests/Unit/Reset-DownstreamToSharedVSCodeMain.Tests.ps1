BeforeAll {
  . "$PSScriptRoot\..\Import-SharedVSCodeFunctions.ps1"
}

Describe 'Reset-DownstreamToSharedVSCodeMain [public]' {
  BeforeAll {
    $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "rdm_test_$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $script:tempDir -Force | Out-Null
  }

  AfterAll {
    Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
  }

  BeforeEach {
    # Fresh workspace file for each test — starts on a sprint ref
    $script:wsFile = Join-Path $script:tempDir "Reset_$([guid]::NewGuid().ToString('N')).code-workspace"
    @{
      folders  = @(@{ path = '.' })
      settings = @{
        'atap.sharedVSCode.templateRef' = 'SharedVSCode-wt-5-sprint-0003-work-items'
        'atap.sharedVSCode.profile'     = 'sprint-0003'
      }
    } | ConvertTo-Json -Depth 10 | Set-Content -Path $script:wsFile -Encoding UTF8

    Mock Set-DownstreamSharedVSCodeContext { }
  }

  It 'Resets templateRef to "main"' {
    Reset-DownstreamToSharedVSCodeMain -WorkspaceFiles @($script:wsFile)

    $result = Get-WorkspaceJson -WorkspaceFile $script:wsFile
    $result.settings.'atap.sharedVSCode.templateRef' | Should -Be 'main'
  }

  It 'Resets profile to "default"' {
    Reset-DownstreamToSharedVSCodeMain -WorkspaceFiles @($script:wsFile)

    $result = Get-WorkspaceJson -WorkspaceFile $script:wsFile
    $result.settings.'atap.sharedVSCode.profile' | Should -Be 'default'
  }

  It 'Calls Set-DownstreamSharedVSCodeContext to refresh plumbing' {
    Reset-DownstreamToSharedVSCodeMain -WorkspaceFiles @($script:wsFile)

    Should -Invoke Set-DownstreamSharedVSCodeContext -Times 1 -Exactly -Scope It
  }

  It 'Delegates pointer update to Set-WorkspaceSharedVSCodeReference (public)' {
    Mock Set-WorkspaceSharedVSCodeReference { }

    Reset-DownstreamToSharedVSCodeMain -WorkspaceFiles @($script:wsFile)

    Should -Invoke Set-WorkspaceSharedVSCodeReference -Times 1 -Exactly -Scope It `
      -ParameterFilter { $TemplateRef -eq 'main' -and $Profile -eq 'default' }
  }
}
