BeforeAll {
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
  }

  . "$PSScriptRoot\..\..\public\Convert-StableWorktreeToConcreteAdapters.ps1"

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
}

Describe 'Convert-StableWorktreeToConcreteAdapters' -Tag 'Unit' {

  It 'converts a junctioned folder to concrete tracked content and preserves the junction target' {
    $fx = New-JunctionFixtureRepo
    try {
      (Get-Item -LiteralPath $fx.Claude -Force).LinkType | Should -Be 'Junction'

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
