BeforeAll {
  # Task 14.60: the combiner now builds the core body through this helper instead of
  # reading <Carrier>-base.md directly, so the unit fixture must load it too.
  . "$PSScriptRoot\..\..\private\Get-AICoreInstructionBody.ps1"
  . "$PSScriptRoot\..\..\public\Build-CLAUDEPerRepository.ps1"
}

Describe 'Build-CLAUDEPerRepository [public]' {
  BeforeEach {
    $script:gitRoot = Join-Path ([System.IO.Path]::GetTempPath()) "claude_build_$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $script:gitRoot -Force | Out-Null

    # Stable worktrees (no -wt-...-Sprint-...-work-items suffix)
    $script:aceStable = New-Item -ItemType Directory -Path (Join-Path $script:gitRoot 'AceCommander') -Force
    $script:sharedStable = New-Item -ItemType Directory -Path (Join-Path $script:gitRoot 'SharedVSCode') -Force
    $script:planningStable = New-Item -ItemType Directory -Path (Join-Path $script:gitRoot '_Planning') -Force

    # Sprint worktrees
    $script:sharedSprint = New-Item -ItemType Directory -Path (Join-Path $script:gitRoot 'SharedVSCode-wt-48-Sprint-0010-work-items') -Force
    $script:planningSprint = New-Item -ItemType Directory -Path (Join-Path $script:gitRoot '_Planning-wt-20-Sprint-0010-work-items') -Force

    # CLAUDE-base.md must exist in whichever SharedVSCode folder the workspace references
    Set-Content -LiteralPath (Join-Path $script:sharedStable 'CLAUDE-base.md') -Value "# base (stable)`n" -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $script:sharedSprint 'CLAUDE-base.md') -Value "# base (sprint)`n" -Encoding UTF8
  }

  AfterEach {
    Remove-Item -LiteralPath $script:gitRoot -Recurse -Force -ErrorAction SilentlyContinue
  }

  It 'skips a stable worktree in a sprint context and leaves its CLAUDE.md untouched' {
    $workspace = Join-Path $script:gitRoot 'OverviewSprint0010.code-workspace'
    $json = @{
      folders        = @(
        @{ path = 'AceCommander' }
        @{ path = 'SharedVSCode-wt-48-Sprint-0010-work-items' }
        @{ path = '_Planning-wt-20-Sprint-0010-work-items' }
      )
      sprintEphemeral = @{ sprintNumber = '0010' }
    } | ConvertTo-Json -Depth 10
    Set-Content -LiteralPath $workspace -Value $json -Encoding UTF8

    $result = Build-CLAUDEPerRepository -WorktreeRoot $script:planningSprint.FullName

    $result.Success | Should -BeTrue
    $result.Errors | Should -BeNullOrEmpty

    $ace = $result.RepositoryResults | Where-Object { $_.Repository -eq 'AceCommander' }
    $ace.Skipped | Should -BeTrue
    $ace.Success | Should -BeFalse
    Test-Path (Join-Path $script:aceStable 'CLAUDE.md') | Should -BeFalse

    $planning = $result.RepositoryResults | Where-Object { $_.Repository -eq '_Planning-wt-20-Sprint-0010-work-items' }
    $planning.Skipped | Should -BeFalse
    $planning.Success | Should -BeTrue
    Test-Path (Join-Path $script:planningSprint.FullName 'CLAUDE.md') | Should -BeTrue
  }

  It 'reports WrittenPath and ClaudeMdLinkType in RepositoryResults (task 10.14.c - Wrong CLAUDE.md)' {
    $workspace = Join-Path $script:gitRoot 'OverviewSprint0010.code-workspace'
    $json = @{
      folders        = @(
        @{ path = 'SharedVSCode-wt-48-Sprint-0010-work-items' }
        @{ path = '_Planning-wt-20-Sprint-0010-work-items' }
      )
      sprintEphemeral = @{ sprintNumber = '0010' }
    } | ConvertTo-Json -Depth 10
    Set-Content -LiteralPath $workspace -Value $json -Encoding UTF8

    $result = Build-CLAUDEPerRepository -WorktreeRoot $script:planningSprint.FullName

    $result.Success | Should -BeTrue

    # Every processed (non-skipped) repo must report the exact CLAUDE.md path it wrote to.
    $written = $result.RepositoryResults | Where-Object { -not $_.Skipped -and $_.Success }
    $written | Should -Not -BeNullOrEmpty

    foreach ($repo in $written) {
      $repo.WrittenPath | Should -Not -BeNullOrEmpty
      $repo.WrittenPath | Should -Match 'CLAUDE\.md$'
      # The written path must end inside the repo's own folder, not inside a .claude junction.
      $repo.WrittenPath | Should -Not -Match '\.claude'
      # A plain file has no link type; it must be null or empty.
      $repo.ClaudeMdLinkType | Should -BeNullOrEmpty
      # The file must actually exist at the reported path.
      Test-Path -LiteralPath $repo.WrittenPath | Should -BeTrue
    }
  }

  It 'writes CLAUDE.md for every repo in a stable (non-sprint) context' {
    $workspace = Join-Path $script:gitRoot 'Overview.code-workspace'
    $json = @{
      folders = @(
        @{ path = 'AceCommander' }
        @{ path = 'SharedVSCode' }
        @{ path = '_Planning' }
      )
    } | ConvertTo-Json -Depth 10
    Set-Content -LiteralPath $workspace -Value $json -Encoding UTF8

    $result = Build-CLAUDEPerRepository -WorktreeRoot $script:planningStable.FullName -WorkspacePath $workspace

    $result.Success | Should -BeTrue
    $ace = $result.RepositoryResults | Where-Object { $_.Repository -eq 'AceCommander' }
    $ace.Skipped | Should -BeFalse
    $ace.Success | Should -BeTrue
    Test-Path (Join-Path $script:aceStable 'CLAUDE.md') | Should -BeTrue
  }
}
