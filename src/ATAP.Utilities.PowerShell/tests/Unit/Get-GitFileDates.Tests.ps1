Describe 'Get-GitFileDates' -Tag 'Unit' {
  BeforeAll {
    Import-Module PSFramework -ErrorAction SilentlyContinue
    . (Join-Path $PSScriptRoot '..\..\public\Get-GitFileDates.ps1')

    $script:repoRoot = Join-Path ([System.IO.Path]::GetTempPath()) "GitDatesFixture_$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $script:repoRoot -Force | Out-Null
    & git -C $script:repoRoot init --quiet
    & git -C $script:repoRoot config user.email 'fixture@example.test'
    & git -C $script:repoRoot config user.name 'Fixture'

    # Commit 1 (2024-01-15): create both files
    Set-Content -Path (Join-Path $script:repoRoot 'ReadMe.md') -Value 'v1'
    New-Item -ItemType Directory -Path (Join-Path $script:repoRoot 'docs') -Force | Out-Null
    Set-Content -Path (Join-Path $script:repoRoot 'docs\setup.md') -Value 'v1'
    & git -C $script:repoRoot add -A
    $env:GIT_AUTHOR_DATE = '2024-01-15T10:00:00-06:00'
    $env:GIT_COMMITTER_DATE = '2024-01-15T10:00:00-06:00'
    & git -C $script:repoRoot commit --quiet -m 'initial'

    # Commit 2 (2025-06-01): modify only ReadMe.md
    Set-Content -Path (Join-Path $script:repoRoot 'ReadMe.md') -Value 'v2'
    & git -C $script:repoRoot add -A
    $env:GIT_AUTHOR_DATE = '2025-06-01T09:30:00-06:00'
    $env:GIT_COMMITTER_DATE = '2025-06-01T09:30:00-06:00'
    & git -C $script:repoRoot commit --quiet -m 'update readme'

    Remove-Item Env:\GIT_AUTHOR_DATE, Env:\GIT_COMMITTER_DATE -ErrorAction SilentlyContinue

    # Untracked doc file: present on disk, absent from history
    Set-Content -Path (Join-Path $script:repoRoot 'docs\untracked.md') -Value 'never committed'
  }

  AfterAll {
    if ($script:repoRoot -and (Test-Path $script:repoRoot)) {
      Remove-Item -LiteralPath $script:repoRoot -Recurse -Force -Confirm:$false
    }
  }

  Context 'Full-repo batch walk (no -RelativePath)' {
    BeforeAll {
      $script:all = @(Get-GitFileDates -RepositoryRoot $script:repoRoot)
    }

    It 'emits one record per path in history' {
      $script:all | Should -HaveCount 2
    }

    It 'reports FirstCommitDate = oldest and LastCommitDate = newest for a twice-committed file' {
      $readme = $script:all | Where-Object RelativePath -eq 'ReadMe.md'
      $readme.FirstCommitDate.Date | Should -Be ([datetime]'2024-01-15')
      $readme.LastCommitDate.Date | Should -Be ([datetime]'2025-06-01')
      $readme.CommitCount | Should -Be 2
      $readme.IsTracked | Should -BeTrue
    }

    It 'reports equal first/last dates for a once-committed file' {
      $setup = $script:all | Where-Object RelativePath -eq 'docs\setup.md'
      $setup.FirstCommitDate | Should -Be $setup.LastCommitDate
      $setup.CommitCount | Should -Be 1
    }

    It 'normalizes paths to backslashes' {
      $script:all.RelativePath | Should -Contain 'docs\setup.md'
    }
  }

  Context 'Targeted lookups (-RelativePath, pipeline join)' {
    It 'returns IsTracked=$false with null dates for an untracked file' {
      $r = Get-GitFileDates -RepositoryRoot $script:repoRoot -RelativePath 'docs\untracked.md'
      $r.IsTracked | Should -BeFalse
      $r.FirstCommitDate | Should -BeNullOrEmpty
      $r.CommitCount | Should -Be 0
    }

    It 'accepts forward-slash input' {
      $r = Get-GitFileDates -RepositoryRoot $script:repoRoot -RelativePath 'docs/setup.md'
      $r.IsTracked | Should -BeTrue
      $r.RelativePath | Should -Be 'docs\setup.md'
    }

    It 'joins from the pipeline by RelativePath property' {
      $inventoryLike = @(
        [PSCustomObject]@{ RelativePath = 'ReadMe.md' },
        [PSCustomObject]@{ RelativePath = 'docs\untracked.md' }
      )
      $r = @($inventoryLike | Get-GitFileDates -RepositoryRoot $script:repoRoot)
      $r | Should -HaveCount 2
      ($r | Where-Object RelativePath -eq 'ReadMe.md').IsTracked | Should -BeTrue
      ($r | Where-Object RelativePath -eq 'docs\untracked.md').IsTracked | Should -BeFalse
    }
  }

  Context 'Error handling' {
    It 'throws when the root is not a git work tree' {
      $notARepo = Join-Path ([System.IO.Path]::GetTempPath()) "NotARepo_$([guid]::NewGuid().ToString('N'))"
      New-Item -ItemType Directory -Path $notARepo -Force | Out-Null
      try {
        { Get-GitFileDates -RepositoryRoot $notARepo } | Should -Throw '*not inside a git work tree*'
      } finally {
        Remove-Item -LiteralPath $notARepo -Recurse -Force -Confirm:$false
      }
    }
  }
}
