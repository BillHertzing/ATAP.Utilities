#Requires -Version 7.0

BeforeAll {
  Import-Module PSFramework -ErrorAction SilentlyContinue
  $script:publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
  . (Join-Path $script:publicDir 'Test-SprintPrerequisites.ps1')
}

Describe 'Test-SprintPrerequisites' -Tag 'Unit' {

  Context 'Result shape' {
    BeforeAll {
      $script:result = Test-SprintPrerequisites `
        -RequiredRepoWorktrees @() `
        -ProGetBaseUrl '' `
        -BuildMasterBaseUrl ''
    }

    It 'Returns a PSCustomObject with the top-level contract' {
      $script:result | Should -BeOfType ([System.Management.Automation.PSCustomObject])
      $script:result.PSObject.Properties.Name | Should -Contain 'AllOk'
      $script:result.PSObject.Properties.Name | Should -Contain 'Checks'
      $script:result.PSObject.Properties.Name | Should -Contain 'Failures'
      $script:result.PSObject.Properties.Name | Should -Contain 'Timestamp'
    }

    It 'Populates every documented check' {
      $names = @('PwshVersion', 'GhAuth', 'Bitwarden', 'GitRepoState', 'BuildToolingImport', 'ProGetReachable', 'BuildMasterReachable')
      foreach ($n in $names) {
        $script:result.Checks.PSObject.Properties.Name | Should -Contain $n
      }
    }

    It 'AllOk is consistent with Failures count' {
      if ($script:result.AllOk) {
        $script:result.Failures.Count | Should -Be 0
      } else {
        $script:result.Failures.Count | Should -BeGreaterThan 0
      }
    }
  }

  Context 'PwshVersion' {
    It 'Passes when MinimumPwshVersion is below the running version' {
      $r = Test-SprintPrerequisites -MinimumPwshVersion '1.0' -RequiredRepoWorktrees @() -ProGetBaseUrl '' -BuildMasterBaseUrl ''
      $r.Checks.PwshVersion.Ok | Should -BeTrue
    }

    It 'Fails when MinimumPwshVersion is above the running version' {
      $r = Test-SprintPrerequisites -MinimumPwshVersion '99.0' -RequiredRepoWorktrees @() -ProGetBaseUrl '' -BuildMasterBaseUrl ''
      $r.Checks.PwshVersion.Ok | Should -BeFalse
      $r.Failures | Should -Contain 'PwshVersion'
      $r.AllOk | Should -BeFalse
    }
  }

  Context 'GitRepoState' {
    It 'Reports Ok with empty repo list' {
      $r = Test-SprintPrerequisites -RequiredRepoWorktrees @() -ProGetBaseUrl '' -BuildMasterBaseUrl ''
      $r.Checks.GitRepoState.Ok | Should -BeTrue
      $r.Checks.GitRepoState.Detail | Should -Match 'No sprint worktrees'
    }

    It 'Detects an in-progress merge via MERGE_HEAD' {
      $tmpRepo = Join-Path ([System.IO.Path]::GetTempPath()) ("a07test-" + [Guid]::NewGuid())
      try {
        $gitSub = Join-Path $tmpRepo '.git'
        $null = New-Item -ItemType Directory -Path $gitSub -Force
        $null = New-Item -ItemType File -Path (Join-Path $gitSub 'MERGE_HEAD') -Force

        $r = Test-SprintPrerequisites -RequiredRepoWorktrees @($tmpRepo) -ProGetBaseUrl '' -BuildMasterBaseUrl ''
        $r.Checks.GitRepoState.Ok | Should -BeFalse
        $r.Checks.GitRepoState.PerRepo[0].InProgress | Should -Contain 'MERGE_HEAD'
        $r.Failures | Should -Contain 'GitRepoState'
      } finally {
        if (Test-Path $tmpRepo) { Remove-Item -Recurse -Force -LiteralPath $tmpRepo }
      }
    }

    It 'Reports Ok when no in-progress markers are present' {
      $tmpRepo = Join-Path ([System.IO.Path]::GetTempPath()) ("a07test-clean-" + [Guid]::NewGuid())
      try {
        $null = New-Item -ItemType Directory -Path (Join-Path $tmpRepo '.git') -Force
        $r = Test-SprintPrerequisites -RequiredRepoWorktrees @($tmpRepo) -ProGetBaseUrl '' -BuildMasterBaseUrl ''
        $r.Checks.GitRepoState.PerRepo[0].Ok | Should -BeTrue
      } finally {
        if (Test-Path $tmpRepo) { Remove-Item -Recurse -Force -LiteralPath $tmpRepo }
      }
    }
  }

  Context 'URL reachability skip semantics' {
    It 'Marks ProGet check Skipped/Ok when no URL is supplied' {
      $r = Test-SprintPrerequisites -RequiredRepoWorktrees @() -ProGetBaseUrl '' -BuildMasterBaseUrl ''
      $r.Checks.ProGetReachable.Skipped | Should -BeTrue
      $r.Checks.ProGetReachable.Ok | Should -BeTrue
    }

    It 'Marks BuildMaster check Skipped/Ok when no URL is supplied' {
      $r = Test-SprintPrerequisites -RequiredRepoWorktrees @() -ProGetBaseUrl '' -BuildMasterBaseUrl ''
      $r.Checks.BuildMasterReachable.Skipped | Should -BeTrue
      $r.Checks.BuildMasterReachable.Ok | Should -BeTrue
    }
  }

  Context '-ThrowOnFailure switch' {
    It 'Throws with the expected FullyQualifiedErrorId when a check fails' {
      try {
        Test-SprintPrerequisites -MinimumPwshVersion '99.0' -RequiredRepoWorktrees @() -ProGetBaseUrl '' -BuildMasterBaseUrl '' -ThrowOnFailure
        throw 'Expected Test-SprintPrerequisites to throw a terminating error.'
      } catch {
        $_.FullyQualifiedErrorId | Should -Match '^SprintPrerequisitesFailedException'
      }
    }
  }
}
