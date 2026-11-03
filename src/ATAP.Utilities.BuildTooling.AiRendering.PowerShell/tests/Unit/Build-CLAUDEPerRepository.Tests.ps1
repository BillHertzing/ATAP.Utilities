BeforeAll {
  # Task 14.60: the combiner now builds the core body through this helper instead of
  # reading <Carrier>-base.md directly, so the unit fixture must load it too.
  . "$PSScriptRoot\..\..\private\Get-AICoreInstructionBody.ps1"
  . "$PSScriptRoot\..\..\public\Build-CLAUDEPerRepository.ps1"
}

Describe 'Build-CLAUDEPerRepository [public]' {
  BeforeEach {
    $script:evidenceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../_generated/Sprint0017/17.9.b/CLAUDELF/fixtures'))
    $script:gitRoot = Join-Path $script:evidenceRoot ([guid]::NewGuid().ToString('N'))
    if (-not $script:gitRoot.StartsWith($script:evidenceRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
      throw 'CLAUDE fixture escaped its owning evidence directory.'
    }
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

  # Retain each unique generated fixture for later evidence inspection.

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

  Context 'LF section composition (SC-0472)' {
    BeforeEach {
      $script:localPath = Join-Path $script:planningSprint.FullName 'ai-local.md'
      $script:basePath = Join-Path $script:sharedSprint.FullName 'CLAUDE-base.md'
      $script:context = [pscustomobject]@{
        WorkspacePath = Join-Path $script:gitRoot 'OverviewSprint0010.code-workspace'
        SharedVSCodePath = $script:sharedSprint.FullName
        SprintWorktreePattern = '-wt-\d+-Sprint-\d{4}-work-items$'
        Repositories = @(
          [pscustomobject]@{
            Repository = '_Planning-wt-20-Sprint-0010-work-items'
            Path = $script:planningSprint.FullName
            Skipped = $false
            ResolutionError = $null
          }
        )
      }
      Mock Get-Date { [datetime]::new(2026, 1, 2, 3, 4, 5) }
      $script:expectedContent = @(
        '# Local rules'
        'local café  '
        'local end'
        ''
        '---'
        ''
        '<!-- CLAUDE.md provenance - generated by Build-CLAUDEPerRepository -->'
        ''
        '| Source File    | Last Modified            |'
        '| -------------- | ------------------------ |'
        '| CLAUDE-base.md | 2001-01-01 00:00:00 |'
        '| ai-local.md | 2001-01-01 00:00:00 |'
        '| CLAUDE.md (combined) | 2026-01-02 03:04:05 |'
        ''
        '---'
        ''
        '# Shared core'
        'core λ  '
        'core end'
        ''
      ) -join "`n"
    }

    It 'normalizes <Name> sections and keeps the second run byte-stable' -ForEach @(
      @{
        Name = 'CRLF'
        Prefix = "# Claude-Base md file start (remove as part of conatenation)`r`n`r`n"
        Local = "# Local rules`r`nlocal café  `r`nlocal end`r`n"
        Core = "# Shared core`r`ncore λ  `r`ncore end`r`n"
        RepairExisting = $false
      }
      @{
        Name = 'LF'
        Prefix = "# Claude-Base md file start (remove as part of conatenation)`n`n"
        Local = "# Local rules`nlocal café  `nlocal end`n"
        Core = "# Shared core`ncore λ  `ncore end`n"
        RepairExisting = $false
      }
      @{
        Name = 'mixed CRLF, LF and lone CR'
        Prefix = "# Claude-Base md file start (remove as part of conatenation)`r`r"
        Local = "# Local rules`r`nlocal café  `rlocal end`n"
        Core = "# Shared core`ncore λ  `r`ncore end`r"
        RepairExisting = $false
      }
      @{
        Name = 'existing mixed-output repair'
        Prefix = "# Claude-Base md file start (remove as part of conatenation)`r`n`r`n"
        Local = "# Local rules`r`nlocal café  `rlocal end`n"
        Core = "# Shared core`ncore λ  `r`ncore end`r"
        RepairExisting = $true
      }
    ) {
      param($Name, $Prefix, $Local, $Core, $RepairExisting)

      $encoding = [Text.UTF8Encoding]::new($false)
      [IO.File]::WriteAllText($script:localPath, $Local, $encoding)
      [IO.File]::WriteAllText($script:basePath, ($Prefix + $Core), $encoding)
      $inputTime = [datetime]::new(2001, 1, 1, 0, 0, 0)
      [IO.File]::SetLastWriteTime($script:localPath, $inputTime)
      [IO.File]::SetLastWriteTime($script:basePath, $inputTime)
      $inputPaths = @($script:localPath, $script:basePath)
      $inputHashes = @($inputPaths | ForEach-Object { (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash })
      $outputPath = Join-Path $script:planningSprint.FullName 'CLAUDE.md'
      if ($RepairExisting) {
        # The old composer kept raw body newlines around its LF provenance table.
        $oldContent = $script:expectedContent.Replace("# Local rules`nlocal café  `nlocal end", $Local.TrimEnd()).Replace("# Shared core`ncore λ  `ncore end", $Core.TrimEnd())
        [IO.File]::WriteAllText($outputPath, $oldContent, $encoding)
      }

      $first = Build-CLAUDEPerRepository -RepositoryContext $script:context -Confirm:$false
      $bytes = [IO.File]::ReadAllBytes($outputPath)

      $first.Success | Should -BeTrue
      $first.RepositoryResults[0].Action | Should -Be 'written'
      $bytes | Should -Not -Contain ([byte]13)
      ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) | Should -BeFalse
      [Text.Encoding]::UTF8.GetString($bytes) | Should -BeExactly $script:expectedContent
      [Text.Encoding]::UTF8.GetString($bytes) | Should -Not -Match 'Claude-Base md file start'
      [Convert]::ToBase64String($bytes) | Should -BeExactly ([Convert]::ToBase64String($encoding.GetBytes($script:expectedContent)))

      $unchangedTime = [datetime]::new(2001, 1, 2, 0, 0, 0, [DateTimeKind]::Utc)
      [IO.File]::SetLastWriteTimeUtc($outputPath, $unchangedTime)
      $second = Build-CLAUDEPerRepository -RepositoryContext $script:context -Confirm:$false

      $second.Success | Should -BeTrue
      $second.RepositoryResults[0].Action | Should -Be 'unchanged'
      [IO.File]::GetLastWriteTimeUtc($outputPath) | Should -Be $unchangedTime
      [Convert]::ToBase64String([IO.File]::ReadAllBytes($outputPath)) | Should -BeExactly ([Convert]::ToBase64String($bytes))
      @($inputPaths | ForEach-Object { (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash }) | Should -Be $inputHashes
    }
  }
}
