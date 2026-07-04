# AI assisted using Powershell.instructions.md as guidelines
# Pester 5+ tests for Get-RepositoryRoot -Absolute (Task 12.35 bug 2)

BeforeAll {
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
  }

  . "$PSScriptRoot\..\..\public\Get-RepositoryRoot.ps1"

  # Build a throwaway git repo plus a linked worktree. Inside a worktree the
  # worktree's '.git' is a FILE pointer ('gitdir: ...'), which is the condition
  # that made Get-RepositoryRoot's relative return (e.g. '..\repo-wt-...') fail
  # the absolute 'safe.directory' comparison in Test-SprintInfrastructureHealth.
  function global:New-WorktreeFixtureRepo {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ('grr-' + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $root -Force | Out-Null

    git -C $root init -q | Out-Null
    git -C $root config user.email 'test@atap.local' | Out-Null
    git -C $root config user.name 'ATAP Test' | Out-Null
    git -C $root config commit.gpgsign false | Out-Null

    Set-Content -LiteralPath (Join-Path $root 'seed.txt') -Value 'seed' -NoNewline
    git -C $root add -A | Out-Null
    git -C $root commit -q -m 'seed' | Out-Null

    $wt = Join-Path ([System.IO.Path]::GetTempPath()) ('grr-wt-' + [System.Guid]::NewGuid().ToString('N'))
    git -C $root worktree add -q -b grr-branch "$wt" | Out-Null

    [pscustomobject]@{ Root = $root; Worktree = $wt }
  }
}

Describe 'Get-RepositoryRoot' -Tag 'Unit' {

  It 'default (no -Absolute) returns a relative path' {
    $fx = New-WorktreeFixtureRepo
    Push-Location $fx.Root
    try {
      $relative = Get-RepositoryRoot
      $relative | Should -Not -BeNullOrEmpty
      # Relative results start with '.' (e.g. '.' or '..\name'); an absolute
      # Windows path (e.g. 'C:\...') or git's forward-slash 'C:/...' must NOT appear.
      $relative | Should -Not -Match '^[A-Za-z]:[\\/]'
    } finally {
      Pop-Location
      git -C $fx.Root worktree remove --force "$($fx.Worktree)" 2>$null | Out-Null
      Remove-Item -LiteralPath $fx.Root -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  It '-Absolute returns the absolute repository root matching git toplevel' {
    $fx = New-WorktreeFixtureRepo
    Push-Location $fx.Root
    try {
      $expected = (git -C $fx.Root rev-parse --show-toplevel).Trim().Replace('\', '/')
      $absolute = (Get-RepositoryRoot -Absolute).Replace('\', '/')
      $absolute | Should -Be $expected
      $absolute | Should -Match '^[A-Za-z]:/'
    } finally {
      Pop-Location
      git -C $fx.Root worktree remove --force "$($fx.Worktree)" 2>$null | Out-Null
      Remove-Item -LiteralPath $fx.Root -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  It '-Absolute inside a worktree returns the absolute worktree path (not a relative ..\ path)' {
    $fx = New-WorktreeFixtureRepo
    Push-Location $fx.Worktree
    try {
      $absolute = (Get-RepositoryRoot -Absolute).Replace('\', '/')
      $expected = (git -C $fx.Worktree rev-parse --show-toplevel).Trim().Replace('\', '/')
      $absolute | Should -Be $expected
      # The pre-fix defect returned a leading '..' relative segment here.
      $absolute | Should -Not -Match '\.\.'
      $absolute | Should -Match '^[A-Za-z]:/'
    } finally {
      Pop-Location
      git -C $fx.Root worktree remove --force "$($fx.Worktree)" 2>$null | Out-Null
      Remove-Item -LiteralPath $fx.Root -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
}
