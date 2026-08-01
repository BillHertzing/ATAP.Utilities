#Requires -Version 7.0

Describe 'Test-SprintPrerequisites' -Tag 'Unit', 'PromotedModuleHostSensitive' {
  BeforeAll {
    Import-Module PSFramework -ErrorAction SilentlyContinue
    if (-not (Get-Module -Name 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell')) {
      Import-Module "$PSScriptRoot\..\..\ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell.psd1" -Force
    }

    Mock -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell `
      -CommandName Initialize-ATAPConfigurationGlobals `
      -MockWith {
        [PSCustomObject]@{
          Initialized         = $false
          ConfigRootKeysCount = 200
          SettingsCount       = 40
        }
      }
  }

  Context 'Result shape' {
    BeforeAll {
      $script:result = Test-SprintPrerequisites `
        -RequiredRepoWorktrees @() `
        -ProGetBaseUrl '' `
        -BuildMasterBaseUrl '' `
        -SkipSqlServerInstanceCheck
    }

    It 'Returns a PSCustomObject with the top-level contract' {
      $script:result | Should -BeOfType ([System.Management.Automation.PSCustomObject])
      $script:result.PSObject.Properties.Name | Should -Contain 'AllOk'
      $script:result.PSObject.Properties.Name | Should -Contain 'Checks'
      $script:result.PSObject.Properties.Name | Should -Contain 'Failures'
      $script:result.PSObject.Properties.Name | Should -Contain 'Timestamp'
    }

    It 'Populates every documented check' {
      $names = @('ConfigurationGlobals', 'PwshVersion', 'GhAuth', 'Bitwarden', 'GitRepoState', 'LockFilesClean', 'SqlServerInstances', 'BuildToolingImport', 'BuildToolingVersionIntegrity', 'ProGetReachable', 'BuildMasterReachable', 'ModulePromotionDeploy')
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

  Context 'Configuration globals bootstrap (Task 10.5)' {
    It 'runs the bootstrap and records a successful readiness check' {
      $r = Test-SprintPrerequisites `
        -RequiredRepoWorktrees @() `
        -ProGetBaseUrl '' `
        -BuildMasterBaseUrl '' `
        -SkipSqlServerInstanceCheck

      $r.Checks.ConfigurationGlobals.Ok | Should -BeTrue
      $r.Checks.ConfigurationGlobals.Initialized | Should -BeFalse
      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell `
        -CommandName Initialize-ATAPConfigurationGlobals `
        -Times 1 `
        -Exactly
    }

    It 'returns a structured failure when configuration bootstrap fails' {
      Mock -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell `
        -CommandName Initialize-ATAPConfigurationGlobals `
        -MockWith { throw 'Host settings unavailable' }

      $r = Test-SprintPrerequisites `
        -RequiredRepoWorktrees @() `
        -ProGetBaseUrl '' `
        -BuildMasterBaseUrl '' `
        -SkipSqlServerInstanceCheck

      $r.Checks.ConfigurationGlobals.Ok | Should -BeFalse
      $r.Checks.ConfigurationGlobals.Detail | Should -Match 'Host settings unavailable'
      $r.Failures | Should -Contain 'ConfigurationGlobals'
      $r.AllOk | Should -BeFalse
    }
  }

  Context 'PwshVersion' {
    It 'Passes when MinimumPwshVersion is below the running version' {
      $r = Test-SprintPrerequisites -MinimumPwshVersion '1.0' -RequiredRepoWorktrees @() -ProGetBaseUrl '' -BuildMasterBaseUrl '' -SkipSqlServerInstanceCheck
      $r.Checks.PwshVersion.Ok | Should -BeTrue
    }

    It 'Fails when MinimumPwshVersion is above the running version' {
      $r = Test-SprintPrerequisites -MinimumPwshVersion '99.0' -RequiredRepoWorktrees @() -ProGetBaseUrl '' -BuildMasterBaseUrl '' -SkipSqlServerInstanceCheck
      $r.Checks.PwshVersion.Ok | Should -BeFalse
      $r.Failures | Should -Contain 'PwshVersion'
      $r.AllOk | Should -BeFalse
    }
  }

  Context 'GitRepoState' {
    It 'Reports Ok with empty repo list' {
      $r = Test-SprintPrerequisites -RequiredRepoWorktrees @() -ProGetBaseUrl '' -BuildMasterBaseUrl '' -SkipSqlServerInstanceCheck
      $r.Checks.GitRepoState.Ok | Should -BeTrue
      $r.Checks.GitRepoState.Detail | Should -Match 'No requested worktrees'
    }

    It 'Skips worktree checks when RequiredRepoWorktrees is omitted' {
      $r = Test-SprintPrerequisites -ProGetBaseUrl '' -BuildMasterBaseUrl '' -SkipSqlServerInstanceCheck
      $r.Checks.GitRepoState.Ok | Should -BeTrue
      $r.Checks.GitRepoState.Skipped | Should -BeTrue
      $r.Checks.LockFilesClean.Ok | Should -BeTrue
      $r.Checks.LockFilesClean.Skipped | Should -BeTrue
    }

    It 'Detects an in-progress merge via MERGE_HEAD' {
      $tmpRepo = Join-Path ([System.IO.Path]::GetTempPath()) ("a07test-" + [Guid]::NewGuid())
      try {
        $gitSub = Join-Path $tmpRepo '.git'
        $null = New-Item -ItemType Directory -Path $gitSub -Force
        $null = New-Item -ItemType File -Path (Join-Path $gitSub 'MERGE_HEAD') -Force

        $r = Test-SprintPrerequisites -RequiredRepoWorktrees @($tmpRepo) -ProGetBaseUrl '' -BuildMasterBaseUrl '' -SkipLockFileGuard -SkipSqlServerInstanceCheck
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
        $r = Test-SprintPrerequisites -RequiredRepoWorktrees @($tmpRepo) -ProGetBaseUrl '' -BuildMasterBaseUrl '' -SkipLockFileGuard -SkipSqlServerInstanceCheck
        $r.Checks.GitRepoState.PerRepo[0].Ok | Should -BeTrue
      } finally {
        if (Test-Path $tmpRepo) { Remove-Item -Recurse -Force -LiteralPath $tmpRepo }
      }
    }
  }

  Context 'LockFilesClean' {
    It 'Reports dirty lock files from required worktrees' {
      $tmpRepo = Join-Path ([System.IO.Path]::GetTempPath()) ("a07-locktest-" + [Guid]::NewGuid())
      try {
        $null = New-Item -ItemType Directory -Path (Join-Path $tmpRepo 'src\App') -Force
        & git -C $tmpRepo init | Out-Null
        & git -C $tmpRepo config user.email 'test@example.invalid' | Out-Null
        & git -C $tmpRepo config user.name 'Sprint Prereq Test' | Out-Null
        Set-Content -LiteralPath (Join-Path $tmpRepo 'src\App\packages.lock.json') -Value '{"version":1}'
        & git -C $tmpRepo add . | Out-Null
        & git -C $tmpRepo commit -m 'seed lock file' | Out-Null
        Add-Content -LiteralPath (Join-Path $tmpRepo 'src\App\packages.lock.json') -Value "`n"

        $r = Test-SprintPrerequisites -RequiredRepoWorktrees @($tmpRepo) -ProGetBaseUrl '' -BuildMasterBaseUrl '' -SkipSqlServerInstanceCheck

        $r.Checks.LockFilesClean.Ok | Should -BeFalse
        $r.Checks.LockFilesClean.PerRepo[0].DirtyLockFiles | Should -Contain 'src/App/packages.lock.json'
        $r.Failures | Should -Contain 'LockFilesClean'
      } finally {
        if (Test-Path $tmpRepo) { Remove-Item -Recurse -Force -LiteralPath $tmpRepo }
      }
    }

    It 'Records an explicit bypass when SkipLockFileGuard is supplied' {
      $r = Test-SprintPrerequisites -RequiredRepoWorktrees @() -ProGetBaseUrl '' -BuildMasterBaseUrl '' -SkipLockFileGuard -SkipSqlServerInstanceCheck

      $r.Checks.LockFilesClean.Ok | Should -BeTrue
      $r.Checks.LockFilesClean.Skipped | Should -BeTrue
    }
  }

  Context 'SqlServerInstances' {
    It 'Records an explicit bypass when SkipSqlServerInstanceCheck is supplied' {
      $r = Test-SprintPrerequisites -RequiredRepoWorktrees @() -ProGetBaseUrl '' -BuildMasterBaseUrl '' -SkipSqlServerInstanceCheck

      $r.Checks.SqlServerInstances.Ok | Should -BeTrue
      $r.Checks.SqlServerInstances.Skipped | Should -BeTrue
    }

    It 'Passes when all requested SQL Server instance services exist' {
      Mock -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell -CommandName Get-Service -MockWith {
        [PSCustomObject]@{ Name = $Name; Status = 'Running' }
      } -ParameterFilter { $Name -like 'MSSQL$*' }

      $r = Test-SprintPrerequisites `
        -RequiredRepoWorktrees @() `
        -ProGetBaseUrl '' `
        -BuildMasterBaseUrl '' `
        -SqlServerInstanceNames @('Devtester', 'Exptester') `
        -SkipLockFileGuard

      $r.Checks.SqlServerInstances.Ok | Should -BeTrue
      $r.Checks.SqlServerInstances.PerInstance.Count | Should -Be 2
      $r.Failures | Should -Not -Contain 'SqlServerInstances'
    }

    It 'Fails when a required SQL Server instance service is missing' {
      Mock -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell -CommandName Get-Service -MockWith {
        if ($Name -eq 'MSSQL$Devtester') {
          [PSCustomObject]@{ Name = $Name; Status = 'Running' }
        }
      } -ParameterFilter { $Name -like 'MSSQL$*' }

      $r = Test-SprintPrerequisites `
        -RequiredRepoWorktrees @() `
        -ProGetBaseUrl '' `
        -BuildMasterBaseUrl '' `
        -SqlServerInstanceNames @('Devtester', 'Exptester') `
        -SkipLockFileGuard

      $r.Checks.SqlServerInstances.Ok | Should -BeFalse
      $r.Checks.SqlServerInstances.PerInstance |
        Where-Object { $_.InstanceName -eq 'Exptester' } |
        Select-Object -ExpandProperty Ok |
        Should -BeFalse
      $r.Failures | Should -Contain 'SqlServerInstances'
    }
  }

  Context 'URL reachability skip semantics' {
    It 'Marks ProGet check Skipped/Ok when no URL is supplied' {
      $r = Test-SprintPrerequisites -RequiredRepoWorktrees @() -ProGetBaseUrl '' -BuildMasterBaseUrl '' -SkipSqlServerInstanceCheck
      $r.Checks.ProGetReachable.Skipped | Should -BeTrue
      $r.Checks.ProGetReachable.Ok | Should -BeTrue
    }

    It 'Marks BuildMaster check Skipped/Ok when no URL is supplied' {
      $r = Test-SprintPrerequisites -RequiredRepoWorktrees @() -ProGetBaseUrl '' -BuildMasterBaseUrl '' -SkipSqlServerInstanceCheck
      $r.Checks.BuildMasterReachable.Skipped | Should -BeTrue
      $r.Checks.BuildMasterReachable.Ok | Should -BeTrue
    }
  }

  Context 'ModulePromotionDeploy gate (Task 9.7)' {
    It 'Is Skipped/Ok when no built modules are declared' {
      $r = Test-SprintPrerequisites -RequiredRepoWorktrees @() -ProGetBaseUrl '' -BuildMasterBaseUrl '' -SkipSqlServerInstanceCheck
      $r.Checks.ModulePromotionDeploy.Skipped | Should -BeTrue
      $r.Checks.ModulePromotionDeploy.Ok | Should -BeTrue
      $r.Failures | Should -Not -Contain 'ModulePromotionDeploy'
    }

    It 'Records an explicit bypass when SkipModulePromotionDeployCheck is supplied' {
      $r = Test-SprintPrerequisites `
        -RequiredRepoWorktrees @() -ProGetBaseUrl '' -BuildMasterBaseUrl '' `
        -SkipSqlServerInstanceCheck `
        -BuiltModule @(@{ Name = 'ATAP.Utilities.Powershell'; Version = '0.1.4' }) `
        -SkipModulePromotionDeployCheck
      $r.Checks.ModulePromotionDeploy.Skipped | Should -BeTrue
      $r.Checks.ModulePromotionDeploy.Ok | Should -BeTrue
    }

    It 'Passes when a built module is in the *-stable feed AND installed' {
      Mock -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell -CommandName Find-Module -MockWith {
        [PSCustomObject]@{ Name = $Name; Version = $RequiredVersion; Repository = $Repository }
      }
      Mock -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell -CommandName Get-Module -MockWith {
        [PSCustomObject]@{ Name = $Name; Version = [Version]'0.1.4' }
      } -ParameterFilter { $ListAvailable -and $Name -eq 'ATAP.Utilities.Powershell' }

      $r = Test-SprintPrerequisites `
        -RequiredRepoWorktrees @() -ProGetBaseUrl '' -BuildMasterBaseUrl '' `
        -SkipSqlServerInstanceCheck -SkipLockFileGuard `
        -BuiltModule @(@{ Name = 'ATAP.Utilities.Powershell'; Version = '0.1.4' })

      $r.Checks.ModulePromotionDeploy.Ok | Should -BeTrue
      $r.Checks.ModulePromotionDeploy.PerModule[0].InStableFeed | Should -BeTrue
      $r.Checks.ModulePromotionDeploy.PerModule[0].Installed | Should -BeTrue
      $r.Failures | Should -Not -Contain 'ModulePromotionDeploy'
    }

    It 'Fails with remediation when the version is in the feed but NOT installed' {
      Mock -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell -CommandName Find-Module -MockWith {
        [PSCustomObject]@{ Name = $Name; Version = $RequiredVersion; Repository = $Repository }
      }
      Mock -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell -CommandName Get-Module -MockWith {
        # No version matches 0.1.4 locally
        @()
      } -ParameterFilter { $ListAvailable -and $Name -eq 'ATAP.Utilities.Powershell' }

      $r = Test-SprintPrerequisites `
        -RequiredRepoWorktrees @() -ProGetBaseUrl '' -BuildMasterBaseUrl '' `
        -SkipSqlServerInstanceCheck -SkipLockFileGuard `
        -BuiltModule @(@{ Name = 'ATAP.Utilities.Powershell'; Version = '0.1.4' })

      $r.Checks.ModulePromotionDeploy.Ok | Should -BeFalse
      $r.Checks.ModulePromotionDeploy.PerModule[0].InStableFeed | Should -BeTrue
      $r.Checks.ModulePromotionDeploy.PerModule[0].Installed | Should -BeFalse
      $r.Checks.ModulePromotionDeploy.PerModule[0].Remediation | Should -Match 'Install-Module'
      $r.Failures | Should -Contain 'ModulePromotionDeploy'
      $r.AllOk | Should -BeFalse
    }

    It 'Fails with remediation when the version is installed but NOT in the *-stable feed' {
      Mock -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell -CommandName Find-Module -MockWith {
        throw 'No match was found for the specified search criteria.'
      }
      Mock -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell -CommandName Get-Module -MockWith {
        [PSCustomObject]@{ Name = $Name; Version = [Version]'0.1.4' }
      } -ParameterFilter { $ListAvailable -and $Name -eq 'ATAP.Utilities.Powershell' }

      $r = Test-SprintPrerequisites `
        -RequiredRepoWorktrees @() -ProGetBaseUrl '' -BuildMasterBaseUrl '' `
        -SkipSqlServerInstanceCheck -SkipLockFileGuard `
        -BuiltModule @(@{ Name = 'ATAP.Utilities.Powershell'; Version = '0.1.4' })

      $r.Checks.ModulePromotionDeploy.Ok | Should -BeFalse
      $r.Checks.ModulePromotionDeploy.PerModule[0].InStableFeed | Should -BeFalse
      $r.Checks.ModulePromotionDeploy.PerModule[0].Installed | Should -BeTrue
      $r.Checks.ModulePromotionDeploy.PerModule[0].Remediation | Should -Match 'powershellget-stable'
      $r.Failures | Should -Contain 'ModulePromotionDeploy'
    }

    It 'Fails an entry that is missing Name or Version' {
      $r = Test-SprintPrerequisites `
        -RequiredRepoWorktrees @() -ProGetBaseUrl '' -BuildMasterBaseUrl '' `
        -SkipSqlServerInstanceCheck -SkipLockFileGuard `
        -BuiltModule @(@{ Name = 'ATAP.Utilities.Powershell' })

      $r.Checks.ModulePromotionDeploy.Ok | Should -BeFalse
      $r.Checks.ModulePromotionDeploy.PerModule[0].Detail | Should -Match 'missing a Name'
      $r.Failures | Should -Contain 'ModulePromotionDeploy'
    }
  }

  Context 'BuildToolingVersionIntegrity' {
    BeforeAll {
      $script:tempRepo = Join-Path ([System.IO.Path]::GetTempPath()) ("bt-integrity-test-" + [Guid]::NewGuid())
      $null = New-Item -ItemType Directory -Path (Join-Path $script:tempRepo 'src\ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell') -Force
    }
    AfterAll {
      if (Test-Path $script:tempRepo) { Remove-Item -Recurse -Force -LiteralPath $script:tempRepo }
    }
    It 'Passes when active version matches source version' {
      $activeVersion = (Get-Module -Name 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell' -ErrorAction SilentlyContinue).Version.ToString()
      if (-not $activeVersion) { $activeVersion = '0.1.16' }
      
      $versionJsonPath = Join-Path $script:tempRepo 'src\ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell\version.json'
      $null = Set-Content -LiteralPath $versionJsonPath -Value "{`"version`": `"$activeVersion`"}" -Force
      
      Mock -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell -CommandName Get-RepositoryRoot -MockWith {
        return $script:tempRepo
      }
      
      $r = Test-SprintPrerequisites -RequiredRepoWorktrees @() -ProGetBaseUrl '' -BuildMasterBaseUrl '' -SkipSqlServerInstanceCheck
      $r.Checks.BuildToolingVersionIntegrity.Ok | Should -BeTrue
    }
    
    It 'Fails when active version mismatches source version' {
      $versionJsonPath = Join-Path $script:tempRepo 'src\ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell\version.json'
      $null = Set-Content -LiteralPath $versionJsonPath -Value "{`"version`": `"99.9.9`"}" -Force
      
      Mock -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell -CommandName Get-RepositoryRoot -MockWith {
        return $script:tempRepo
      }
      
      $r = Test-SprintPrerequisites -RequiredRepoWorktrees @() -ProGetBaseUrl '' -BuildMasterBaseUrl '' -SkipSqlServerInstanceCheck
      $r.Checks.BuildToolingVersionIntegrity.Ok | Should -BeFalse
      $r.Failures | Should -Contain 'BuildToolingVersionIntegrity'
    }
  }

  Context 'BWS token purpose routing' {
    It 'source requests the ReadOnly BWS token purpose for readiness checks' {
      $source = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\..\public\Test-SprintPrerequisites.ps1') -Raw
      $source | Should -Match 'Get-BWSAccessToken\s+-TokenPurpose\s+ReadOnly'
      $source | Should -Match 'CommonCIForBitwardenReadOnly'
    }
  }
  Context 'BWS token purpose routing' {
    It 'source requests the ReadOnly BWS token purpose for readiness checks' {
      $source = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\..\public\Test-SprintPrerequisites.ps1') -Raw
      $source | Should -Match 'Get-BWSAccessToken\s+-TokenPurpose\s+ReadOnly'
      $source | Should -Match 'CommonCIForBitwardenReadOnly'
    }
  }
  Context '-ThrowOnFailure switch' {
    It 'Throws with the expected FullyQualifiedErrorId when a check fails' {
      try {
        Test-SprintPrerequisites -MinimumPwshVersion '99.0' -RequiredRepoWorktrees @() -ProGetBaseUrl '' -BuildMasterBaseUrl '' -SkipSqlServerInstanceCheck -ThrowOnFailure
        throw 'Expected Test-SprintPrerequisites to throw a terminating error.'
      } catch {
        $_.FullyQualifiedErrorId | Should -Match '^SprintPrerequisitesFailedException'
      }
    }
  }
}

