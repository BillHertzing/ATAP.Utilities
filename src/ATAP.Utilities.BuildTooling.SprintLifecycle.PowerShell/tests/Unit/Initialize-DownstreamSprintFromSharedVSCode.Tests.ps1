BeforeAll {
  $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  . (Join-Path $moduleRoot 'private\Get-WorkspaceJson.ps1')
  . (Join-Path $moduleRoot 'private\Save-WorkspaceJson.ps1')
  . (Join-Path $moduleRoot 'private\Resolve-WorkspaceFiles.ps1')
  . (Join-Path $moduleRoot 'public\Set-WorkspaceSharedVSCodeReference.ps1')
  . (Join-Path $moduleRoot 'public\Initialize-DownstreamSprintFromSharedVSCode.ps1')
}

Describe 'Initialize-DownstreamSprintFromSharedVSCode [public]' {
  BeforeAll {
    $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "ids_test_$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $script:tempDir -Force | Out-Null

    $script:wsFile = Join-Path $script:tempDir 'Test.code-workspace'
    @{
      folders  = @(@{ path = '.' })
      settings = @{
        'atap.sharedVSCode.templateRef' = 'main'
        'atap.sharedVSCode.profile'     = 'default'
      }
    } | ConvertTo-Json -Depth 10 | Set-Content -Path $script:wsFile -Encoding UTF8
  }

  AfterAll {
    Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
  }

  BeforeEach {
    Mock Set-DownstreamSharedVSCodeContext { }
  }

  It 'Writes the sprint templateRef into the workspace file' {
    $sprintRef = 'SharedVSCode-wt-5-sprint-0003-work-items'

    Initialize-DownstreamSprintFromSharedVSCode `
      -WorkspaceFiles @($script:wsFile) `
      -TemplateRef $sprintRef `
      -Profile 'sprint-0003'

    $result = Get-WorkspaceJson -WorkspaceFile $script:wsFile
    $result.settings.'atap.sharedVSCode.templateRef' | Should -Be $sprintRef
    $result.settings.'atap.sharedVSCode.profile' | Should -Be 'sprint-0003'
  }

  It 'Delegates to Set-WorkspaceSharedVSCodeReference (public) for the pointer update' {
    Mock Set-WorkspaceSharedVSCodeReference { }

    Initialize-DownstreamSprintFromSharedVSCode `
      -WorkspaceFiles @($script:wsFile) `
      -TemplateRef 'SharedVSCode-wt-5-sprint-0003-work-items'

    Should -Invoke Set-WorkspaceSharedVSCodeReference -Times 1 -Exactly -Scope It
  }

  It 'Delegates to Set-DownstreamSharedVSCodeContext (public) for plumbing' {
    Initialize-DownstreamSprintFromSharedVSCode `
      -WorkspaceFiles @($script:wsFile) `
      -TemplateRef 'SharedVSCode-wt-5-sprint-0003-work-items'

    Should -Invoke Set-DownstreamSharedVSCodeContext -Times 1 -Exactly -Scope It
  }

  It 'Defaults Profile to "default" when not specified' {
    Initialize-DownstreamSprintFromSharedVSCode `
      -WorkspaceFiles @($script:wsFile) `
      -TemplateRef 'SharedVSCode-wt-5-sprint-0003-work-items'

    $result = Get-WorkspaceJson -WorkspaceFile $script:wsFile
    $result.settings.'atap.sharedVSCode.profile' | Should -Be 'default'
  }
}
