#Requires -Version 7.0

BeforeAll {
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
  }
  . "$PSScriptRoot\..\..\public\Get-SprintEndContext.ps1"
}

Describe 'Get-SprintEndContext [public]' -Tag 'Unit' {

  It 'function exists and is loaded' {
    Get-Command -Name 'Get-SprintEndContext' -CommandType Function |
      Should -Not -BeNullOrEmpty
  }

  Context 'Result shape' {
    It 'Returns a PSCustomObject with the expected contract fields' {
      $r = Get-SprintEndContext -CurrentPath 'C:\GitHub\ATAP.Utilities-wt-107-Sprint-0007-work-items'
      $r | Should -BeOfType ([System.Management.Automation.PSCustomObject])
      $r.PSObject.Properties.Name | Should -Contain 'Ok'
      $r.PSObject.Properties.Name | Should -Contain 'ClosedSprintNumber'
      $r.PSObject.Properties.Name | Should -Contain 'NextSprintNumber'
      $r.PSObject.Properties.Name | Should -Contain 'Detail'
    }
  }

  Context 'Sprint number detection from CurrentPath' {
    It 'Parses the sprint number from a standard sprint worktree path' {
      $r = Get-SprintEndContext -CurrentPath 'C:\GitHub\ATAP.Utilities-wt-107-Sprint-0007-work-items'
      $r.Ok | Should -BeTrue
      $r.ClosedSprintNumber | Should -Be '0007'
    }

    It 'Computes NextSprintNumber as ClosedSprintNumber + 1 — not off by one (Bug 1 fix)' {
      # Regression: old VersionControlSprintEndSubagent computed
      # $nextSprintNumber = ([int]$sprintNumber + 1) where $sprintNumber was
      # already the next sprint (0008). This returned 0009 instead of 0008.
      # The correct derivation is: closedSprintNumber + 1 = 0007 + 1 = 0008.
      $r = Get-SprintEndContext -CurrentPath 'C:\GitHub\ATAP.Utilities-wt-107-Sprint-0007-work-items'
      $r.NextSprintNumber | Should -Be '0008'
    }

    It 'Works with the Sprint-0008 close context — produces 0009 not 0010' {
      $r = Get-SprintEndContext -CurrentPath 'C:\GitHub\ATAP.Utilities-wt-107-Sprint-0008-work-items'
      $r.ClosedSprintNumber | Should -Be '0008'
      $r.NextSprintNumber | Should -Be '0009'
    }

    It 'Handles lowercase sprint pattern (sprint-0006 naming convention)' {
      $r = Get-SprintEndContext -CurrentPath 'C:\GitHub\ATAP.Utilities-wt-72-sprint-0006-work-items'
      $r.Ok | Should -BeTrue
      $r.ClosedSprintNumber | Should -Be '0006'
      $r.NextSprintNumber | Should -Be '0007'
    }

    It 'Returns Ok=false when the path contains no sprint pattern' {
      $r = Get-SprintEndContext `
        -CurrentPath 'C:\GitHub\ATAP.Utilities' `
        -GitRoot ([System.IO.Path]::GetTempPath())
      $r.Ok | Should -BeFalse
      $r.ClosedSprintNumber | Should -BeNullOrEmpty
      $r.NextSprintNumber | Should -BeNullOrEmpty
      $r.Detail | Should -Not -BeNullOrEmpty
    }
  }

  Context 'Fallback: worktree scan under GitRoot' {
    BeforeAll {
      $script:tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('sec-test-' + [guid]::NewGuid().ToString('N'))
      # Create two sprint-0005 worktrees and one sprint-0004 worktree so 0005 wins
      New-Item -ItemType Directory -Path (Join-Path $script:tmpRoot 'Repo1-wt-10-Sprint-0005-work-items') -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $script:tmpRoot 'Repo2-wt-11-Sprint-0005-work-items') -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $script:tmpRoot 'Repo3-wt-9-Sprint-0004-work-items') -Force | Out-Null
    }

    AfterAll {
      Remove-Item -LiteralPath $script:tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Falls back to worktree scan when CurrentPath has no sprint pattern' {
      $r = Get-SprintEndContext -CurrentPath 'C:\NoMatch\plain-repo' -GitRoot $script:tmpRoot
      $r.Ok | Should -BeTrue
      $r.ClosedSprintNumber | Should -Be '0005'
      $r.NextSprintNumber | Should -Be '0006'
    }
  }

  Context 'NextSprintNumber arithmetic' {
    It 'Formats single-digit base sprint correctly (0001 -> 0002)' {
      $r = Get-SprintEndContext -CurrentPath 'C:\GitHub\Repo-wt-1-Sprint-0001-work-items'
      $r.ClosedSprintNumber | Should -Be '0001'
      $r.NextSprintNumber | Should -Be '0002'
    }

    It 'Formats sprint rollover correctly (0099 -> 0100)' {
      $r = Get-SprintEndContext -CurrentPath 'C:\GitHub\Repo-wt-55-Sprint-0099-work-items'
      $r.ClosedSprintNumber | Should -Be '0099'
      $r.NextSprintNumber | Should -Be '0100'
    }
  }
}
