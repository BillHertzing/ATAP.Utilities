# AI assisted using ./claude/Rules/Powershell.md as guidelines
# Pester 5+ tests for Update-OverviewWorkspaceStableInfo

BeforeAll {
  $functionName = 'Update-OverviewWorkspaceStableInfo'
  if (-not (Get-Command -Name $functionName -CommandType Function -ErrorAction SilentlyContinue)) {
    $functionPath = Join-Path $PSScriptRoot -ChildPath "../../public/$functionName.ps1"
    if (Test-Path $functionPath) { . $functionPath } else { throw "Function file not found: $functionPath" }
  }

  if (-not (Get-Module -Name PSFramework -ErrorAction SilentlyContinue)) {
    Import-Module PSFramework -ErrorAction SilentlyContinue
  }

  # Build an isolated GitRoot containing fake stable repo folders, a source
  # OverviewSprint0007.code-workspace, and (in some tests) a pre-existing root
  # Overview.code-workspace to be merged into.
  $script:gitRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('uowsi-test-' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $script:gitRoot -Force | Out-Null

  # Stable repo folders (bare names). One folder ('MissingRepo') is intentionally
  # absent on disk to exercise the prune-missing behaviour.
  $script:stableRepos = @('AceCommander', 'ATAP.Utilities', 'ATAP.IAC', 'SharedVSCode', '_Planning')
  foreach ($r in $script:stableRepos) {
    New-Item -ItemType Directory -Path (Join-Path $script:gitRoot $r) -Force | Out-Null
  }

  # Sprint workspace contents: folder paths use the sprint-worktree naming
  # convention, plus one entry pointing at a directory that does not exist
  # on disk to verify it is dropped by default.
  $sprintWorkspaceObj = [ordered]@{
    folders = @(
      @{ path = 'AceCommander-wt-41-Sprint-0007-work-items' },
      @{ path = 'ATAP.Utilities-wt-100-Sprint-0007-work-items' },
      @{ path = 'ATAP.IAC-wt-9-Sprint-0007-work-items' },
      @{ path = 'SharedVSCode-wt-42-Sprint-0007-work-items' },
      @{ path = '_Planning-wt-14-Sprint-0007-work-items' },
      @{ path = 'MissingRepo-wt-99-Sprint-0007-work-items' }
    )
    settings = @{ 'powershell.cwd' = '_Planning-wt-14-Sprint-0007-work-items' }
    progetFeeds = @(
      @{ name = 'nuget-experimental'; url = 'http://proget.local/nuget-experimental' },
      @{ name = 'powershellget-development'; url = 'http://proget.local/powershellget-development' }
    )
    sprintEphemeral = @{
      sprintNumber = '0007'
      developerUsername = 'whertzing'
    }
    generatedBy = 'New-OverviewSprintWorkspace'
    generatedAt = '2026-04-15T08:00:00Z'
  }
  $script:sprintWorkspacePath = Join-Path $script:gitRoot 'OverviewSprint0007.code-workspace'
  ($sprintWorkspaceObj | ConvertTo-Json -Depth 20) |
    Set-Content -LiteralPath $script:sprintWorkspacePath -Encoding UTF8

  # Pre-existing root Overview.code-workspace - missing one repo on disk
  # (the new 'ATAP.IAC' will appear via the merge), has a stale ProGet feed
  # list, and carries leftover sprint-ephemeral debris that must be stripped.
  $rootWorkspaceObj = [ordered]@{
    folders = @(
      @{ path = 'AceCommander' },
      @{ path = 'ATAP.Utilities' },
      @{ path = 'SharedVSCode' },
      @{ path = '_Planning' }
    )
    settings = @{
      'editor.formatOnSave' = $true
      'powershell.cwd' = 'SharedVSCode'
    }
    progetFeeds = @(
      @{ name = 'nuget-experimental'; url = 'http://stale.local/nuget-experimental' }
    )
    extensions = @{ recommendations = @('ms-vscode.powershell') }
    sprintEphemeral = @{ sprintNumber = '0006' }
    generatedBy = 'New-OverviewSprintWorkspace'
    generatedAt = '2026-03-01T00:00:00Z'
  }
  $script:rootWorkspacePath = Join-Path $script:gitRoot 'Overview.code-workspace'
  ($rootWorkspaceObj | ConvertTo-Json -Depth 20) |
    Set-Content -LiteralPath $script:rootWorkspacePath -Encoding UTF8
}

AfterAll {
  if (Test-Path $script:gitRoot) {
    Remove-Item -Recurse -Force $script:gitRoot -ErrorAction SilentlyContinue
  }
}

Describe 'Update-OverviewWorkspaceStableInfo' {

  It 'function is loaded' {
    Get-Command -Name 'Update-OverviewWorkspaceStableInfo' -CommandType Function |
      Should -Not -BeNullOrEmpty
  }

  It 'returns a structured result object describing the merge under -WhatIf' {
    $result = Update-OverviewWorkspaceStableInfo `
      -GitRoot $script:gitRoot `
      -RootWorkspacePath $script:rootWorkspacePath `
      -SourceWorkspacePath $script:sprintWorkspacePath `
      -WhatIf

    $result | Should -Not -BeNullOrEmpty
    $result.rootWorkspacePath   | Should -Be $script:rootWorkspacePath
    $result.sourceWorkspacePath | Should -Be $script:sprintWorkspacePath
    $result.wasChanged          | Should -BeTrue
    $result.progetFeedCount     | Should -Be 2
    # 5 of 6 sprint folders are real on disk - 'MissingRepo' is dropped.
    $result.stableFolders.Count | Should -Be 5
    $result.stableFolders       | Should -Contain 'ATAP.IAC'
    $result.stableFolders       | Should -Not -Contain 'MissingRepo'
    # WhatIf must NOT touch the file.
    $result.backupPath          | Should -BeNullOrEmpty
  }

  It 'does NOT modify the root workspace under -WhatIf' {
    $before = (Get-FileHash -LiteralPath $script:rootWorkspacePath -Algorithm SHA256).Hash
    Update-OverviewWorkspaceStableInfo `
      -GitRoot $script:gitRoot `
      -RootWorkspacePath $script:rootWorkspacePath `
      -SourceWorkspacePath $script:sprintWorkspacePath `
      -WhatIf | Out-Null
    $after = (Get-FileHash -LiteralPath $script:rootWorkspacePath -Algorithm SHA256).Hash
    $after | Should -Be $before
  }

  It 'writes the merged root workspace and creates a timestamped backup' {
    $result = Update-OverviewWorkspaceStableInfo `
      -GitRoot $script:gitRoot `
      -RootWorkspacePath $script:rootWorkspacePath `
      -SourceWorkspacePath $script:sprintWorkspacePath

    $result.wasChanged        | Should -BeTrue
    $result.backupPath        | Should -Not -BeNullOrEmpty
    Test-Path -LiteralPath $result.backupPath | Should -BeTrue

    $reloaded = Get-Content -LiteralPath $script:rootWorkspacePath -Raw | ConvertFrom-Json

    # folders: derived stable list, in source order, missing-on-disk dropped.
    $folderPaths = @($reloaded.folders | ForEach-Object { $_.path })
    $folderPaths.Count   | Should -Be 5
    $folderPaths[0]      | Should -Be 'AceCommander'
    $folderPaths         | Should -Contain 'ATAP.IAC'
    $folderPaths         | Should -Not -Contain 'MissingRepo'
    # No worktree suffixes survived the merge.
    foreach ($p in $folderPaths) { $p | Should -Not -Match '-wt-\d+-Sprint-\d{4}-work-items$' }

    # progetFeeds: refreshed from source.
    $reloaded.progetFeeds.Count             | Should -Be 2
    @($reloaded.progetFeeds | Where-Object { $_.name -eq 'nuget-experimental' })[0].url |
      Should -Be 'http://proget.local/nuget-experimental'

    # settings: existing editor.formatOnSave preserved; powershell.cwd retargeted.
    $reloaded.settings.'editor.formatOnSave' | Should -BeTrue
    $reloaded.settings.'powershell.cwd'      | Should -Be '_Planning'

    # extensions: preserved unchanged.
    $reloaded.extensions.recommendations     | Should -Contain 'ms-vscode.powershell'

    # Sprint-ephemeral debris stripped.
    $reloaded.PSObject.Properties['sprintEphemeral'] | Should -BeNullOrEmpty
    $reloaded.PSObject.Properties['generatedBy']     | Should -BeNullOrEmpty
    $reloaded.PSObject.Properties['generatedAt']     | Should -BeNullOrEmpty
  }

  It 'is idempotent: a second run reports wasChanged=$false and writes nothing' {
    # First run already ran in the previous It block. Re-run on the same files.
    $hashBefore = (Get-FileHash -LiteralPath $script:rootWorkspacePath -Algorithm SHA256).Hash
    $result = Update-OverviewWorkspaceStableInfo `
      -GitRoot $script:gitRoot `
      -RootWorkspacePath $script:rootWorkspacePath `
      -SourceWorkspacePath $script:sprintWorkspacePath
    $hashAfter = (Get-FileHash -LiteralPath $script:rootWorkspacePath -Algorithm SHA256).Hash

    $result.wasChanged | Should -BeFalse
    $result.changes.Count | Should -Be 0
    $result.backupPath | Should -BeNullOrEmpty
    $hashAfter | Should -Be $hashBefore
  }

  It '-KeepMissing retains derived folders even when not present on disk' {
    # Use a fresh root path so the previous merge's pruning does not influence this assertion.
    $altRoot = Join-Path $script:gitRoot 'Overview-KeepMissing.code-workspace'
    $result = Update-OverviewWorkspaceStableInfo `
      -GitRoot $script:gitRoot `
      -RootWorkspacePath $altRoot `
      -SourceWorkspacePath $script:sprintWorkspacePath `
      -KeepMissing

    $result.stableFolders.Count | Should -Be 6
    $result.stableFolders       | Should -Contain 'MissingRepo'
    Test-Path -LiteralPath $altRoot | Should -BeTrue
    $reloaded = Get-Content -LiteralPath $altRoot -Raw | ConvertFrom-Json
    @($reloaded.folders | ForEach-Object { $_.path }) | Should -Contain 'MissingRepo'
  }

  It 'auto-discovers the most recent OverviewSprint*.code-workspace when -SourceWorkspacePath is omitted' {
    # Seed an additional, older sprint workspace alongside the current 0007 one
    # and ensure the newer 0007 (LastWriteTimeUtc-wise) is chosen.
    $olderPath = Join-Path $script:gitRoot 'OverviewSprint0006.code-workspace'
    '{ "folders": [{ "path": "AceCommander" }] }' | Set-Content -LiteralPath $olderPath -Encoding UTF8
    (Get-Item -LiteralPath $olderPath).LastWriteTimeUtc = (Get-Date).ToUniversalTime().AddDays(-30)

    $autoRoot = Join-Path $script:gitRoot 'Overview-AutoDiscover.code-workspace'
    $result = Update-OverviewWorkspaceStableInfo `
      -GitRoot $script:gitRoot `
      -RootWorkspacePath $autoRoot `
      -WhatIf

    $result.sourceWorkspacePath | Should -Be $script:sprintWorkspacePath
    $result.progetFeedCount     | Should -Be 2
  }

  It 'throws when GitRoot does not exist' {
    {
      Update-OverviewWorkspaceStableInfo `
        -GitRoot (Join-Path ([System.IO.Path]::GetTempPath()) ('missing-' + [guid]::NewGuid().ToString('N')))
    } | Should -Throw
  }

  It 'throws when the source sprint workspace cannot be located' {
    $emptyRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('empty-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $emptyRoot -Force | Out-Null
    try {
      {
        Update-OverviewWorkspaceStableInfo -GitRoot $emptyRoot
      } | Should -Throw
    } finally {
      Remove-Item -Recurse -Force $emptyRoot -ErrorAction SilentlyContinue
    }
  }

  It 'seeds a new root workspace when the target file does not yet exist' {
    $freshRoot = Join-Path $script:gitRoot 'Overview-Fresh.code-workspace'
    Test-Path -LiteralPath $freshRoot | Should -BeFalse
    $result = Update-OverviewWorkspaceStableInfo `
      -GitRoot $script:gitRoot `
      -RootWorkspacePath $freshRoot `
      -SourceWorkspacePath $script:sprintWorkspacePath

    $result.wasChanged | Should -BeTrue
    $result.backupPath | Should -BeNullOrEmpty   # no prior file to back up
    Test-Path -LiteralPath $freshRoot | Should -BeTrue
    $reloaded = Get-Content -LiteralPath $freshRoot -Raw | ConvertFrom-Json
    $reloaded.folders.Count | Should -Be 5
    $reloaded.progetFeeds.Count | Should -Be 2
  }
}
