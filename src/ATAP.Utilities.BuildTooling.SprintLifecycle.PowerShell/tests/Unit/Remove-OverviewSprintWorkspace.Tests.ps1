BeforeAll {
  . "$PSScriptRoot\..\..\public\Remove-OverviewSprintWorkspace.ps1"
}

Describe 'Remove-OverviewSprintWorkspace [public]' {
  BeforeEach {
    $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "remove_overview_ws_$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $script:tempDir -Force | Out-Null

    $script:planningRoot = Join-Path $script:tempDir '_Planning'
    New-Item -ItemType Directory -Path $script:planningRoot -Force | Out-Null

    $script:sourceWorkspace = Join-Path $script:tempDir 'Overview.Sprint0007.code-workspace'
    @'
{
  "folders": [
    {
      "path": "ATAP.Utilities-wt-100-Sprint-0007-work-items"
    }
  ],
  "settings": {
    "powershell.cwd": "C:\\Dropbox\\whertzing\\GitHub\\ATAP.Utilities-wt-100-Sprint-0007-work-items"
  }
}
'@ | Set-Content -LiteralPath $script:sourceWorkspace -Encoding UTF8
  }

  AfterEach {
    if ($script:tempDir -and (Test-Path -LiteralPath $script:tempDir)) {
      Remove-Item -LiteralPath $script:tempDir -Recurse -Force
    }
  }

  It 'archives the default sprint workspace into the planning archive directory' {
    $result = Remove-OverviewSprintWorkspace -SprintNumber 7 -GitRoot $script:tempDir -Confirm:$false
    $archivePath = Join-Path $script:planningRoot 'SprintRetrospective\WorkspaceArchive\Overview.Sprint0007.code-workspace'

    $result.WasArchived | Should -BeTrue
    $result.SourceRemoved | Should -BeTrue
    $result.WasChanged | Should -BeTrue
    $result.ArchiveWorkspacePath | Should -Be $archivePath
    Test-Path -LiteralPath $script:sourceWorkspace | Should -BeFalse
    Test-Path -LiteralPath $archivePath | Should -BeTrue
  }

  It 'prefers the exact dotted closing-sprint workspace over a stale legacy artifact' {
    Remove-Item -LiteralPath $script:sourceWorkspace -Force
    $dottedSource = Join-Path $script:tempDir 'Overview.Sprint0007.code-workspace'
    @'
{
  "folders": [
    {
      "path": "ATAP.Utilities-wt-100-Sprint-0007-work-items"
    }
  ]
}
'@ | Set-Content -LiteralPath $dottedSource -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $script:tempDir 'OverviewSprint0008.code-workspace') -Value '{}' -Encoding UTF8

    $result = Remove-OverviewSprintWorkspace -SprintNumber 7 -GitRoot $script:tempDir -Confirm:$false
    $archivePath = Join-Path $script:planningRoot 'SprintRetrospective\WorkspaceArchive\Overview.Sprint0007.code-workspace'

    $result.SourceWorkspacePath | Should -Be $dottedSource
    $result.ArchiveWorkspacePath | Should -Be $archivePath
    Test-Path -LiteralPath $archivePath | Should -BeTrue
    Test-Path -LiteralPath (Join-Path $script:tempDir 'OverviewSprint0008.code-workspace') | Should -BeTrue
  }

  It 'supports WhatIf without moving the workspace or creating the archive directory' {
    $result = Remove-OverviewSprintWorkspace -SprintNumber 7 -GitRoot $script:tempDir -WhatIf
    $archiveDirectory = Join-Path $script:planningRoot 'SprintRetrospective\WorkspaceArchive'

    $result.WasArchived | Should -BeFalse
    $result.SourceRemoved | Should -BeFalse
    $result.WasChanged | Should -BeFalse
    Test-Path -LiteralPath $script:sourceWorkspace | Should -BeTrue
    Test-Path -LiteralPath $archiveDirectory | Should -BeFalse
  }

  It 'honors explicit source and archive paths' {
    $explicitSource = Join-Path $script:tempDir 'CustomSprintWorkspace.code-workspace'
    Move-Item -LiteralPath $script:sourceWorkspace -Destination $explicitSource
    $explicitArchiveDirectory = Join-Path $script:tempDir 'custom-archive'

    $result = Remove-OverviewSprintWorkspace `
      -SprintNumber 7 `
      -GitRoot $script:tempDir `
      -SourceWorkspacePath $explicitSource `
      -ArchiveDirectoryPath $explicitArchiveDirectory `
      -Confirm:$false

    $expectedArchivePath = Join-Path $explicitArchiveDirectory 'CustomSprintWorkspace.code-workspace'
    $result.ArchiveWorkspacePath | Should -Be $expectedArchivePath
    Test-Path -LiteralPath $explicitSource | Should -BeFalse
    Test-Path -LiteralPath $expectedArchivePath | Should -BeTrue
  }

  It 'throws when the sprint workspace cannot be found' {
    Remove-Item -LiteralPath $script:sourceWorkspace -Force

    { Remove-OverviewSprintWorkspace -SprintNumber 7 -GitRoot $script:tempDir -Confirm:$false } |
      Should -Throw "*Overview sprint workspace*does not exist*"
  }

  It 'removes the source when an identical archive target already exists' {
    $archiveDirectory = Join-Path $script:planningRoot 'SprintRetrospective\WorkspaceArchive'
    New-Item -ItemType Directory -Path $archiveDirectory -Force | Out-Null
    $archivePath = Join-Path $archiveDirectory 'Overview.Sprint0007.code-workspace'
    Copy-Item -LiteralPath $script:sourceWorkspace -Destination $archivePath

    $result = Remove-OverviewSprintWorkspace -SprintNumber 7 -GitRoot $script:tempDir -Confirm:$false

    $result.WasArchived | Should -BeFalse
    $result.AlreadyArchived | Should -BeTrue
    $result.SourceRemoved | Should -BeTrue
    $result.WasChanged | Should -BeTrue
    Test-Path -LiteralPath $script:sourceWorkspace | Should -BeFalse
    Test-Path -LiteralPath $archivePath | Should -BeTrue
  }

  It 'refuses to overwrite a different archived workspace' {
    $archiveDirectory = Join-Path $script:planningRoot 'SprintRetrospective\WorkspaceArchive'
    New-Item -ItemType Directory -Path $archiveDirectory -Force | Out-Null
    $archivePath = Join-Path $archiveDirectory 'Overview.Sprint0007.code-workspace'
    'different content' | Set-Content -LiteralPath $archivePath -Encoding UTF8

    { Remove-OverviewSprintWorkspace -SprintNumber 7 -GitRoot $script:tempDir -Confirm:$false } |
      Should -Throw "*already exists and differs*"
    Test-Path -LiteralPath $script:sourceWorkspace | Should -BeTrue
  }
}
