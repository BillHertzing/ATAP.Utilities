BeforeAll {
  . "$PSScriptRoot\..\Import-SharedVSCodeFunctions.ps1"
}

Describe 'Set-WorkspaceSharedVSCodeReference [public]' {
  BeforeAll {
    $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "swsvr_test_$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $script:tempDir -Force | Out-Null
  }

  AfterAll {
    Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
  }

  It 'Updates templateRef and profile in an existing workspace file' {
    $wsFile = Join-Path $script:tempDir 'Update.code-workspace'
    @{
      folders  = @(@{ path = '.' })
      settings = @{
        'atap.sharedVSCode.templateRef' = 'main'
        'atap.sharedVSCode.profile'     = 'default'
      }
    } | ConvertTo-Json -Depth 10 | Set-Content -Path $wsFile -Encoding UTF8

    Set-WorkspaceSharedVSCodeReference `
      -WorkspaceFiles @($wsFile) `
      -TemplateRef 'SharedVSCode-wt-5-sprint-0003-work-items' `
      -Profile 'sprint-0003'

    $result = Get-WorkspaceJson -WorkspaceFile $wsFile
    $result.settings.'atap.sharedVSCode.templateRef' | Should -Be 'SharedVSCode-wt-5-sprint-0003-work-items'
    $result.settings.'atap.sharedVSCode.profile' | Should -Be 'sprint-0003'
  }

  It 'Creates the settings object if it is missing' {
    $wsFile = Join-Path $script:tempDir 'NoSettings.code-workspace'
    Set-Content -Path $wsFile -Value '{"folders":[{"path":"."}]}' -Encoding UTF8

    Set-WorkspaceSharedVSCodeReference `
      -WorkspaceFiles @($wsFile) `
      -TemplateRef 'main'

    $result = Get-WorkspaceJson -WorkspaceFile $wsFile
    $result.settings.'atap.sharedVSCode.templateRef' | Should -Be 'main'
    $result.settings.'atap.sharedVSCode.profile' | Should -Be 'default'
  }

  It 'Defaults profile to "default" when not specified' {
    $wsFile = Join-Path $script:tempDir 'DefaultProfile.code-workspace'
    @{
      folders  = @(@{ path = '.' })
      settings = @{ 'atap.sharedVSCode.templateRef' = 'old' }
    } | ConvertTo-Json -Depth 10 | Set-Content -Path $wsFile -Encoding UTF8

    Set-WorkspaceSharedVSCodeReference `
      -WorkspaceFiles @($wsFile) `
      -TemplateRef 'main'

    $result = Get-WorkspaceJson -WorkspaceFile $wsFile
    $result.settings.'atap.sharedVSCode.profile' | Should -Be 'default'
  }

  It 'Preserves existing non-SharedVSCode settings' {
    $wsFile = Join-Path $script:tempDir 'Preserve.code-workspace'
    @{
      folders  = @(@{ path = '.' })
      settings = @{
        'atap.sharedVSCode.templateRef' = 'old'
        'editor.fontSize'               = 14
      }
    } | ConvertTo-Json -Depth 10 | Set-Content -Path $wsFile -Encoding UTF8

    Set-WorkspaceSharedVSCodeReference `
      -WorkspaceFiles @($wsFile) `
      -TemplateRef 'main'

    $result = Get-WorkspaceJson -WorkspaceFile $wsFile
    $result.settings.'editor.fontSize' | Should -Be 14
  }

  It 'Updates multiple workspace files in one call' {
    $ws1 = Join-Path $script:tempDir 'Multi1.code-workspace'
    $ws2 = Join-Path $script:tempDir 'Multi2.code-workspace'
    $json = '{"folders":[{"path":"."}],"settings":{}}'
    Set-Content -Path $ws1 -Value $json -Encoding UTF8
    Set-Content -Path $ws2 -Value $json -Encoding UTF8

    Set-WorkspaceSharedVSCodeReference `
      -WorkspaceFiles @($ws1, $ws2) `
      -TemplateRef 'sprint-ref'

    (Get-WorkspaceJson -WorkspaceFile $ws1).settings.'atap.sharedVSCode.templateRef' | Should -Be 'sprint-ref'
    (Get-WorkspaceJson -WorkspaceFile $ws2).settings.'atap.sharedVSCode.templateRef' | Should -Be 'sprint-ref'
  }
}
