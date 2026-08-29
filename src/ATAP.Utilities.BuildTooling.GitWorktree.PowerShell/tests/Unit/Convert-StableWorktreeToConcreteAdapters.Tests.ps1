BeforeAll {
  $moduleRoot = Join-Path $PSScriptRoot '..\..'
  Import-Module (Join-Path $moduleRoot 'ATAP.Utilities.BuildTooling.GitWorktree.PowerShell.psd1') -Force
  # The installed BuildTooling module can lag this source slice; bind the gate under test directly.
  . (Join-Path $moduleRoot '..\ATAP.Utilities.BuildTooling.PowerShell\public\Get-AllFilesChangedByCommit.ps1')

  # Build a throwaway git repo whose '.claude' folder is tracked concrete content but
  # is currently occupied by an NTFS junction (the stable-worktree drift this function
  # repairs). Returns the repo root plus the junction target so tests can assert the
  # target's contents survive de-junctioning. Junctions (mklink /J) need no elevation.
  function global:New-JunctionFixtureRepo {
    param([switch]$StageDeletions)

    $root = Join-Path ([System.IO.Path]::GetTempPath()) ("cvt-" + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $root -Force | Out-Null

    git -C $root init -q | Out-Null
    git -C $root config user.email 'test@atap.local' | Out-Null
    git -C $root config user.name  'ATAP Test'       | Out-Null
    git -C $root config commit.gpgsign false         | Out-Null

    # Commit concrete .claude content so HEAD carries real tracked files.
    $claude = Join-Path $root '.claude'
    New-Item -ItemType Directory -Path $claude -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $claude 'marker.txt') -Value 'tracked-concrete' -NoNewline
    git -C $root add -A          | Out-Null
    git -C $root commit -q -m 'seed concrete .claude' | Out-Null

    # Replace the concrete dir with a junction to a separate target dir.
    $target = Join-Path ([System.IO.Path]::GetTempPath()) ("cvt-tgt-" + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $target 'target-only.txt') -Value 'do-not-delete' -NoNewline

    Remove-Item -LiteralPath $claude -Recurse -Force
    cmd /c mklink /J "$claude" "$target" | Out-Null

    if ($StageDeletions) {
      # Stage the tracked-file deletions git now sees under .claude (index column 'D').
      git -C $root add -A '.claude' | Out-Null
    }

    [pscustomobject]@{ Root = $root; Claude = $claude; Target = $target }
  }

  function global:New-HistoryFreezeFixtureRepo {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ("history-freeze-" + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    git -C $root init -q | Out-Null
    git -C $root config user.email 'test@atap.local' | Out-Null
    git -C $root config user.name 'ATAP Test' | Out-Null
    git -C $root config commit.gpgsign false | Out-Null
    git -C $root config core.autocrlf true | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $root 'tracked.txt'), "line-one`nline-two`n")
    git -C $root add -A | Out-Null
    git -C $root commit -q -m 'seed history fixture' | Out-Null
    [pscustomobject]@{
      Root = $root
      Temp = Join-Path $root 'ignored-output'
      OriginalLocation = (Get-Location).Path
    }
  }
}

Describe 'Convert-StableWorktreeToConcreteAdapters' -Tag 'Unit' {

  It 'converts a junctioned folder to concrete tracked content and preserves the junction target' {
    $fx = New-JunctionFixtureRepo
    try {
      (Get-Item -LiteralPath $fx.Claude -Force).LinkType | Should -Be 'Junction'
      git -C $fx.Root diff --quiet -- '.claude'
      $LASTEXITCODE | Should -Be 1 -Because 'the fixture carries an unstaged tracked deletion'
      $untracked = @(git -C $fx.Root ls-files --others --exclude-standard -- '.claude')
      $untracked | Should -Contain '.claude/target-only.txt'

      $res = Convert-StableWorktreeToConcreteAdapters -RepoRoot $fx.Root -FolderNames '.claude' -Confirm:$false

      $entry = $res.Results | Where-Object Folder -eq '.claude'
      $entry.WasJunction | Should -BeTrue
      $entry.Removed     | Should -BeTrue
      $entry.Restored    | Should -BeTrue
      $res.Errors.Count  | Should -Be 0

      # Path is now a real directory (LinkType empty), tracked content restored...
      (Get-Item -LiteralPath $fx.Claude -Force).LinkType | Should -BeNullOrEmpty
      (Get-Content -LiteralPath (Join-Path $fx.Claude 'marker.txt') -Raw) | Should -Be 'tracked-concrete'
      # ...and the junction TARGET's own contents were NOT deleted.
      Test-Path -LiteralPath (Join-Path $fx.Target 'target-only.txt') | Should -BeTrue
    } finally {
      cmd /c rmdir "$($fx.Claude)" 2>$null | Out-Null
      Remove-Item -LiteralPath $fx.Root, $fx.Target -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  It '-WhatIf mutates nothing (junction stays, no restore)' {
    $fx = New-JunctionFixtureRepo
    try {
      $res = Convert-StableWorktreeToConcreteAdapters -RepoRoot $fx.Root -FolderNames '.claude' -WhatIf

      $entry = $res.Results | Where-Object Folder -eq '.claude'
      $entry.WasJunction | Should -BeTrue
      $entry.Removed     | Should -BeFalse
      $entry.Restored    | Should -BeFalse
      # The junction is untouched.
      (Get-Item -LiteralPath $fx.Claude -Force).LinkType | Should -Be 'Junction'
    } finally {
      cmd /c rmdir "$($fx.Claude)" 2>$null | Out-Null
      Remove-Item -LiteralPath $fx.Root, $fx.Target -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  It 'skips a folder that is a real directory (not a junction)' {
    $fx = New-JunctionFixtureRepo
    try {
      # Restore concrete first so '.github' scenario: use a plain concrete folder.
      $plain = Join-Path $fx.Root '.github'
      New-Item -ItemType Directory -Path $plain -Force | Out-Null

      $res = Convert-StableWorktreeToConcreteAdapters -RepoRoot $fx.Root -FolderNames '.github' -Confirm:$false

      $entry = $res.Results | Where-Object Folder -eq '.github'
      $entry.Skipped    | Should -BeTrue
      $entry.WasJunction| Should -BeFalse
      $entry.SkipReason | Should -Match 'Not a junction'
      $res.Errors.Count | Should -Be 0
    } finally {
      cmd /c rmdir "$($fx.Claude)" 2>$null | Out-Null
      Remove-Item -LiteralPath $fx.Root, $fx.Target -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  It 'skips a folder that does not exist' {
    $fx = New-JunctionFixtureRepo
    try {
      $res = Convert-StableWorktreeToConcreteAdapters -RepoRoot $fx.Root -FolderNames '.nonexistent' -Confirm:$false
      $entry = $res.Results | Where-Object Folder -eq '.nonexistent'
      $entry.Skipped    | Should -BeTrue
      $entry.SkipReason | Should -Match 'does not exist'
    } finally {
      cmd /c rmdir "$($fx.Claude)" 2>$null | Out-Null
      Remove-Item -LiteralPath $fx.Root, $fx.Target -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  It 'refuses to convert when staged changes are present under the folder' {
    $fx = New-JunctionFixtureRepo -StageDeletions
    try {
      $res = Convert-StableWorktreeToConcreteAdapters -RepoRoot $fx.Root -FolderNames '.claude' -Confirm:$false

      $entry = $res.Results | Where-Object Folder -eq '.claude'
      $entry.StagedChangesBlocked | Should -BeTrue
      $entry.Removed              | Should -BeFalse
      $res.Errors.Count           | Should -BeGreaterThan 0
      # Junction left intact because we refused.
      (Get-Item -LiteralPath $fx.Claude -Force).LinkType | Should -Be 'Junction'
    } finally {
      cmd /c rmdir "$($fx.Claude)" 2>$null | Out-Null
      Remove-Item -LiteralPath $fx.Root, $fx.Target -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
}

Describe 'Get-AllFilesChangedByCommit content freeze' -Tag 'Unit' {
  It 'passes a clean repository through to commit validation' {
    $fx = New-HistoryFreezeFixtureRepo
    try {
      { Get-AllFilesChangedByCommit -CommitSHA 'not-a-commit' -TempPath $fx.Temp -currentRepositoryPath $fx.Root } |
        Should -Throw '*CommitSHA is not valid*'
    } finally {
      Set-Location -LiteralPath $fx.OriginalLocation
      Remove-Item -LiteralPath $fx.Root -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  It 'passes an EOL-only worktree representation through to commit validation' {
    $fx = New-HistoryFreezeFixtureRepo
    try {
      [System.IO.File]::WriteAllText((Join-Path $fx.Root 'tracked.txt'), "line-one`r`nline-two`r`n")
      git -C $fx.Root diff --quiet --
      $LASTEXITCODE | Should -Be 0
      { Get-AllFilesChangedByCommit -CommitSHA 'not-a-commit' -TempPath $fx.Temp -currentRepositoryPath $fx.Root } |
        Should -Throw '*CommitSHA is not valid*'
    } finally {
      Set-Location -LiteralPath $fx.OriginalLocation
      Remove-Item -LiteralPath $fx.Root -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  It 'rejects a staged content modification' {
    $fx = New-HistoryFreezeFixtureRepo
    try {
      Set-Content -LiteralPath (Join-Path $fx.Root 'tracked.txt') -Value 'staged-content' -NoNewline
      git -C $fx.Root add -- 'tracked.txt' | Out-Null
      { Get-AllFilesChangedByCommit -CommitSHA 'not-a-commit' -TempPath $fx.Temp -currentRepositoryPath $fx.Root } |
        Should -Throw '*content changes*Staged: M*tracked.txt*'
    } finally {
      Set-Location -LiteralPath $fx.OriginalLocation
      Remove-Item -LiteralPath $fx.Root -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  It 'rejects an unstaged content modification' {
    $fx = New-HistoryFreezeFixtureRepo
    try {
      Set-Content -LiteralPath (Join-Path $fx.Root 'tracked.txt') -Value 'unstaged-content' -NoNewline
      { Get-AllFilesChangedByCommit -CommitSHA 'not-a-commit' -TempPath $fx.Temp -currentRepositoryPath $fx.Root } |
        Should -Throw '*content changes*Unstaged: M*tracked.txt*'
    } finally {
      Set-Location -LiteralPath $fx.OriginalLocation
      Remove-Item -LiteralPath $fx.Root -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  It 'rejects a deleted tracked path' {
    $fx = New-HistoryFreezeFixtureRepo
    try {
      Remove-Item -LiteralPath (Join-Path $fx.Root 'tracked.txt') -Force
      { Get-AllFilesChangedByCommit -CommitSHA 'not-a-commit' -TempPath $fx.Temp -currentRepositoryPath $fx.Root } |
        Should -Throw '*content changes*Unstaged: D*tracked.txt*'
    } finally {
      Set-Location -LiteralPath $fx.OriginalLocation
      Remove-Item -LiteralPath $fx.Root -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  It 'rejects a staged rename' {
    $fx = New-HistoryFreezeFixtureRepo
    try {
      git -C $fx.Root mv -- 'tracked.txt' 'renamed.txt' | Out-Null
      { Get-AllFilesChangedByCommit -CommitSHA 'not-a-commit' -TempPath $fx.Temp -currentRepositoryPath $fx.Root } |
        Should -Throw '*content changes*Staged: R*tracked.txt*renamed.txt*'
    } finally {
      Set-Location -LiteralPath $fx.OriginalLocation
      Remove-Item -LiteralPath $fx.Root -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  It 'rejects an untracked path through the explicit untracked policy' {
    $fx = New-HistoryFreezeFixtureRepo
    try {
      Set-Content -LiteralPath (Join-Path $fx.Root 'untracked.txt') -Value 'untracked-content' -NoNewline
      { Get-AllFilesChangedByCommit -CommitSHA 'not-a-commit' -TempPath $fx.Temp -currentRepositoryPath $fx.Root } |
        Should -Throw '*content changes*Untracked: untracked.txt*'
    } finally {
      Set-Location -LiteralPath $fx.OriginalLocation
      Remove-Item -LiteralPath $fx.Root -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
}
