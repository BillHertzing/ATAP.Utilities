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
    $outputWorkspace = Join-Path $script:tempDir 'Overview.Sprint.0007.code-workspace'

    $result = New-OverviewSprintWorkspace -SprintNumber 7 -GitRoot $script:tempDir -SourceWorkspacePath $script:sourceWorkspace -OutputWorkspacePath $outputWorkspace
    $workspace = Get-Content -LiteralPath $outputWorkspace -Raw | ConvertFrom-Json

    $result.FolderCount | Should -Be 2
    $workspace.folders.path | Should -Contain 'ATAP.Utilities-wt-100-Sprint-0007-work-items'
    $workspace.folders.path | Should -Contain '_Planning-wt-14-Sprint-0007-work-items'
    $workspace.settings.'powershell.cwd' | Should -Be '_Planning-wt-14-Sprint-0007-work-items'
    $workspace.sprintEphemeral.sprintNumber | Should -Be '0007'
    $workspace.developers.Count | Should -Be 1
    $workspace.developers[0].username | Should -Be $env:USERNAME
    $workspace.developers[0].host | Should -Be $env:COMPUTERNAME.ToLowerInvariant()
  }

  It 'preserves one developer on multiple hosts in deterministic host-qualified order' {
    $outputWorkspace = Join-Path $script:tempDir 'Overview.Sprint.0007.code-workspace'
    $developerAssignments = @(
      @{ username = 'whertzing'; host = 'UTAT022' }
      @{ username = 'whertzing'; host = 'utat01' }
    )

    New-OverviewSprintWorkspace -SprintNumber 7 -GitRoot $script:tempDir `
      -SourceWorkspacePath $script:sourceWorkspace -OutputWorkspacePath $outputWorkspace `
      -DeveloperUsername 'whertzing' -DeveloperAssignments $developerAssignments
    $workspace = Get-Content -LiteralPath $outputWorkspace -Raw | ConvertFrom-Json

    $workspace.developers.Count | Should -Be 2
    $workspace.developers[0].username | Should -Be 'whertzing'
    $workspace.developers[0].host | Should -Be 'utat01'
    $workspace.developers[1].username | Should -Be 'whertzing'
    $workspace.developers[1].host | Should -Be 'utat022'
  }

  It 'preserves configured assignments from the latest earlier sprint workspace' {
    $priorWorkspace = Join-Path $script:tempDir 'Overview.Sprint.0006.code-workspace'
    $priorContent = [PSCustomObject]@{
      folders = @()
      developers = @(
        [PSCustomObject]@{ username = 'whertzing'; host = 'utat022' }
        [PSCustomObject]@{ username = 'whertzing'; host = 'utat01' }
      )
    }
    $priorContent | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $priorWorkspace -Encoding UTF8
    $outputWorkspace = Join-Path $script:tempDir 'Overview.Sprint.0007.code-workspace'

    New-OverviewSprintWorkspace -SprintNumber 7 -GitRoot $script:tempDir `
      -SourceWorkspacePath $script:sourceWorkspace -OutputWorkspacePath $outputWorkspace
    $workspace = Get-Content -LiteralPath $outputWorkspace -Raw | ConvertFrom-Json

    @($workspace.developers).Count | Should -Be 2
    @($workspace.developers.host) | Should -Be @('utat01', 'utat022')
  }

  It 'preserves an existing two-host output over a legacy one-host source' {
    $legacySource = Get-Content -LiteralPath $script:sourceWorkspace -Raw | ConvertFrom-Json
    Add-Member -InputObject $legacySource -MemberType NoteProperty -Name developers -Value @(
      [PSCustomObject]@{ username = 'whertzing'; host = 'utat022' })
    $legacySource | ConvertTo-Json -Depth 10 |
      Set-Content -LiteralPath $script:sourceWorkspace -Encoding UTF8

    $outputWorkspace = Join-Path $script:tempDir 'Overview.Sprint.0007.code-workspace'
    $existingOutput = [PSCustomObject]@{
      folders = @()
      developers = @(
        [PSCustomObject]@{ username = 'whertzing'; host = 'utat022' }
        [PSCustomObject]@{ username = 'whertzing'; host = 'utat01' }
      )
    }
    $existingOutput | ConvertTo-Json -Depth 10 |
      Set-Content -LiteralPath $outputWorkspace -Encoding UTF8

    New-OverviewSprintWorkspace -SprintNumber 7 -GitRoot $script:tempDir `
      -SourceWorkspacePath $script:sourceWorkspace -OutputWorkspacePath $outputWorkspace
    $workspace = Get-Content -LiteralPath $outputWorkspace -Raw | ConvertFrom-Json

    @($workspace.developers).Count | Should -Be 2
    @($workspace.developers.host) | Should -Be @('utat01', 'utat022')
  }

  It 'rejects duplicate composite developer assignments case-insensitively' {
    $outputWorkspace = Join-Path $script:tempDir 'Overview.Sprint.0007.code-workspace'
    $developerAssignments = @(
      @{ username = 'whertzing'; host = 'utat01' }
      @{ username = 'WHERTZING'; host = 'UTAT01' }
    )

    {
      New-OverviewSprintWorkspace -SprintNumber 7 -GitRoot $script:tempDir `
        -SourceWorkspacePath $script:sourceWorkspace -OutputWorkspacePath $outputWorkspace `
        -DeveloperAssignments $developerAssignments
    } | Should -Throw "*Duplicate developer assignment*"
  }
}
