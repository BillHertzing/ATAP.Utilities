BeforeAll {
  . "$PSScriptRoot\..\..\public\New-OverviewSprintWorkspace.ps1"
}

Describe 'New-OverviewSprintWorkspace [public]' {
  BeforeEach {
    $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "overview_ws_$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $script:tempDir -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $script:tempDir 'ATAP.Utilities-wt-100-Sprint-0007-work-items') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $script:tempDir '_Planning-wt-14-Sprint-0007-work-items') -Force | Out-Null

    $script:sourceWorkspace = Join-Path $script:tempDir 'Overview.code-workspace'
    $workspaceJson = @(
      '{'
      '  "folders": ['
      '    { "path": "ATAP.Utilities" },'
      '    { "path": "_Planning" },'
      '  ],'
      '  "settings": {'
      '    "powershell.cwd": "_Planning",'
      '  },'
      '  "progetFeeds": {'
      '    "nuget": [ "nuget-development" ]'
      '  }'
      '}'
    ) -join "`n"
    Set-Content -LiteralPath $script:sourceWorkspace -Value $workspaceJson -Encoding UTF8
  }

  AfterEach {
    Remove-Item -LiteralPath $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
  }

  It 'creates a sprint workspace using discovered sprint worktree folders' {
    $outputWorkspace = Join-Path $script:tempDir 'OverviewSprint0007.code-workspace'

    $result = New-OverviewSprintWorkspace -SprintNumber 7 -GitRoot $script:tempDir -SourceWorkspacePath $script:sourceWorkspace -OutputWorkspacePath $outputWorkspace
    $workspace = Get-Content -LiteralPath $outputWorkspace -Raw | ConvertFrom-Json

    $result.FolderCount | Should -Be 2
    $workspace.folders.path | Should -Contain 'ATAP.Utilities-wt-100-Sprint-0007-work-items'
    $workspace.folders.path | Should -Contain '_Planning-wt-14-Sprint-0007-work-items'
    $workspace.settings.'powershell.cwd' | Should -Be '_Planning-wt-14-Sprint-0007-work-items'
    $workspace.sprintEphemeral.sprintNumber | Should -Be '0007'
  }
}