BeforeAll {
  Get-Module -Name 'ATAP.Utilities.BuildTooling.PowerShell' -All |
    Remove-Module -Force -ErrorAction SilentlyContinue
  Get-Module -Name 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell' -All |
    Remove-Module -Force -ErrorAction SilentlyContinue
  $script:parentModuleRoot = Join-Path $PSScriptRoot '..' '..' '..' 'ATAP.Utilities.BuildTooling.PowerShell'
  . (Join-Path $script:parentModuleRoot 'private\Set-UserSettingsSymlink.ps1')
  . (Join-Path $script:parentModuleRoot 'public\Set-PowerShell7ProfileSymlink.ps1')
  Set-Item -LiteralPath 'Function:\global:Set-UserSettingsSymlink' -Value ${function:Set-UserSettingsSymlink}
  Set-Item -LiteralPath 'Function:\global:Set-PowerShell7ProfileSymlink' -Value ${function:Set-PowerShell7ProfileSymlink}
  # Import the module from THIS worktree (tests/Unit -> module root) so the test
  # exercises the worktree's source rather than a stable-repo copy on PSModulePath.
  $script:rootModulePath = Join-Path $PSScriptRoot '..' '..' 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell.psm1'
  Import-Module $script:rootModulePath -Force
}

Describe 'Set-SprintBoundaryContext [public]' {
  BeforeAll {
    $script:gitRoot = Join-Path ([System.IO.Path]::GetTempPath()) "sbc_test_$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $script:gitRoot -Force | Out-Null

    # Stable repo + sprint worktree + a workspace file inside the worktree.
    $script:repoName  = 'ATAP.Utilities'
    $script:stableRepo = Join-Path $script:gitRoot $script:repoName
    New-Item -ItemType Directory -Path $script:stableRepo -Force | Out-Null

    $script:worktree = Join-Path $script:gitRoot "$($script:repoName)-wt-100-Sprint-0007-work-items"
    New-Item -ItemType Directory -Path $script:worktree -Force | Out-Null
    $script:wsFile = Join-Path $script:worktree 'Test.code-workspace'
    @{ folders = @(@{ path = '.' }) } | ConvertTo-Json | Set-Content -Path $script:wsFile -Encoding UTF8

    $script:svSprint = Join-Path $script:gitRoot 'SharedVSCode-wt-42-Sprint-0007-work-items'
    New-Item -ItemType Directory -Path $script:svSprint -Force | Out-Null
    $script:svStable = Join-Path $script:gitRoot 'SharedVSCode'
    New-Item -ItemType Directory -Path $script:svStable -Force | Out-Null
  }

  AfterAll {
    Remove-Item -Path $script:gitRoot -Recurse -Force -ErrorAction SilentlyContinue
  }

  BeforeEach {
    Mock -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Set-WorktreeJunctions { [PSCustomObject]@{ Success = $true; Errors = @() } }
    Mock -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Initialize-DownstreamSprintFromSharedVSCode { }
    Mock -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Reset-DownstreamToSharedVSCodeMain { }
    Mock -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Set-UserSettingsSymlink { }
    Mock -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Set-ClaudeSettingsSymlink { }
    Mock -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Invoke-SprintAIAdapterLifecycle {
      [PSCustomObject]@{ DriftClean = $true; Results = @(); ChangedCount = 0; Idempotent = $true; UserGlobalIntentLedgerPath = 'intent.json' }
    }
    Mock -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Set-PowerShell7ProfileSymlink {
      [PSCustomObject]@{ Ok = $true; Failures = @(); Links = @(); DryRun = $false }
    }
    Mock -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Set-SprintBoundaryUserProfiles {
      [PSCustomObject]@{
        Ok = $true
        Profiles = @(
          [PSCustomObject]@{ Kind = 'Developer'; Identity = 'alice'; Succeeded = $true; Error = $null; Warning = $null; ProfilePath = 'C:\Users\alice\Documents\PowerShell\profile.ps1'; SourcePath = 'C:\Profiles\CurrentUserAllHostsV7CoreProfile.ps1' },
          [PSCustomObject]@{ Kind = 'ServiceAccount'; Identity = 'SvcBuildmaster'; Succeeded = $true; Error = $null; Warning = $null; ProfilePath = 'C:\Users\SvcBuildmaster\Documents\PowerShell\profile.ps1'; SourcePath = 'C:\Profiles\ProfileForServiceAccountUsers.ps1' }
        )
        Warnings = @()
        Failures = @()
      }
    }
    Mock -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Get-ProfiledRemotingBoundaryState {
      [PSCustomObject]@{
        ConfigurationName = 'ATAP.PS7.Profiled'
        CommandAvailable = $true
        ProbeSucceeded = $true
        ConfigurationCount = 0
        RemotingSurfacePresent = $false
        ManagedConfigurationPresent = $false
        ManagedRegistryPresent = $false
        ManagedMarkerPresent = $false
        ManagedEndpointStatePresent = $false
        ManagedMarkerPath = $null
        ProbeError = $null
      }
    }
    Mock -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Register-ProfiledRemotingEndpoint {
      [PSCustomObject]@{ Ok = $true; Action = 'AlreadyCurrent'; Failures = @() }
    }
    Mock -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Sync-SprintBoundaryPrimaryRoleMarker {
      [PSCustomObject]@{
        Boundary = $Boundary
        Action = 'SharedVerified'
        Succeeded = $true
        SharedStatePath = $SharedStatePath
      }
    }
  }

  Context 'Parameter validation' {
    It 'Rejects an invalid Boundary value' {
      { Set-SprintBoundaryContext -Boundary 'Sideways' -SharedVSCodeWorktreePath $script:svSprint } |
        Should -Throw
    }

    It 'Requires a non-empty SharedVSCodeWorktreePath' {
      { Set-SprintBoundaryContext -Boundary 'Start' -SharedVSCodeWorktreePath '' } | Should -Throw
    }

    It 'Rejects an invalid ProfiledRemotingPolicy value' {
      { Set-SprintBoundaryContext -Boundary Start -SharedVSCodeWorktreePath $script:svSprint -ProfiledRemotingPolicy Sometimes } |
        Should -Throw
    }
  }

  Context 'Profiled remoting boundary policy' {
    It 'Auto reports an absent remoting surface as nonfatal and not applicable' {
      $result = Set-SprintBoundaryContext -Boundary End `
        -SharedVSCodeWorktreePath $script:svStable `
        -GitRoot $script:gitRoot `
        -ProfiledRemotingPolicy Auto

      $concern = $result.Concerns | Where-Object Concern -EQ 'ProfiledRemotingEndpoint'
      $concern.Action | Should -Be 'NotApplicable'
      $concern.Succeeded | Should -BeTrue
      $concern.Policy | Should -Be 'Auto'
      $concern.Reason | Should -Match 'no PowerShell session configurations'
      $result.Errors | Should -BeNullOrEmpty
      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Register-ProfiledRemotingEndpoint -Times 0 -Exactly -Scope It
    }

    It 'Auto treats a broken registration as fatal when remoting exists' {
      Mock -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Get-ProfiledRemotingBoundaryState {
        [PSCustomObject]@{
          RemotingSurfacePresent = $true
          ManagedEndpointStatePresent = $false
          ProbeError = $null
        }
      }
      Mock -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Register-ProfiledRemotingEndpoint {
        [PSCustomObject]@{ Ok = $false; Failures = @('registration broke') }
      }

      $result = Set-SprintBoundaryContext -Boundary End `
        -SharedVSCodeWorktreePath $script:svStable `
        -GitRoot $script:gitRoot `
        -ProfiledRemotingPolicy Auto

      ($result.Errors -join '; ') | Should -Match 'registration broke'
      ($result.Concerns | Where-Object Concern -EQ 'ProfiledRemotingEndpoint').Succeeded | Should -BeFalse
      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Register-ProfiledRemotingEndpoint -Times 1 -Exactly -Scope It
    }

    It 'Auto blocks on enabled PowerShell 7 configurations whose plug-in file is missing' {
      Mock -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Get-ProfiledRemotingBoundaryState {
        [PSCustomObject]@{
          RemotingSurfacePresent = $true
          ManagedEndpointStatePresent = $false
          BrokenPowerShell7ConfigurationCount = 1
          BrokenPowerShell7Configurations = @([PSCustomObject]@{ Name = 'PowerShell.7' })
          CanonicalPluginPath = 'C:\Program Files\PowerShell\7\pwrshplugin.dll'
          RepairGuidance = @(
            "Set-Item -LiteralPath 'WSMan:\localhost\Plugin\PowerShell.7\Filename' -Value 'C:\Program Files\PowerShell\7\pwrshplugin.dll' -Force",
            'Restart-Service -Name WinRM -Force'
          )
          ProbeError = $null
        }
      }

      $result = Set-SprintBoundaryContext -Boundary End `
        -SharedVSCodeWorktreePath $script:svStable `
        -GitRoot $script:gitRoot `
        -ProfiledRemotingPolicy Auto

      $concern = $result.Concerns | Where-Object Concern -EQ 'ProfiledRemotingEndpoint'
      $concern.Action | Should -Be 'RepairRequired'
      $concern.Succeeded | Should -BeFalse
      $concern.Error | Should -Match ([regex]::Escape('C:\Program Files\PowerShell\7\pwrshplugin.dll'))
      $concern.Error | Should -Not -Match 'Enable-PSRemoting'
      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Register-ProfiledRemotingEndpoint -Times 0 -Exactly -Scope It
    }

    It 'Required treats an absent remoting surface as fatal with remediation' {
      $result = Set-SprintBoundaryContext -Boundary End `
        -SharedVSCodeWorktreePath $script:svStable `
        -GitRoot $script:gitRoot `
        -ProfiledRemotingPolicy Required

      $concern = $result.Concerns | Where-Object Concern -EQ 'ProfiledRemotingEndpoint'
      $concern.Action | Should -Be 'RequiredUnavailable'
      $concern.Succeeded | Should -BeFalse
      $concern.Error | Should -Match 'Enable PowerShell remoting explicitly outside SprintEnd'
      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Register-ProfiledRemotingEndpoint -Times 0 -Exactly -Scope It
    }

    It 'Disabled neither probes nor invokes registration' {
      $result = Set-SprintBoundaryContext -Boundary End `
        -SharedVSCodeWorktreePath $script:svStable `
        -GitRoot $script:gitRoot `
        -ProfiledRemotingPolicy Disabled

      $concern = $result.Concerns | Where-Object Concern -EQ 'ProfiledRemotingEndpoint'
      $concern.Action | Should -Be 'NotApplicable'
      $concern.Succeeded | Should -BeTrue
      $concern.Reason | Should -Match 'Disabled'
      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Get-ProfiledRemotingBoundaryState -Times 0 -Exactly -Scope It
      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Register-ProfiledRemotingEndpoint -Times 0 -Exactly -Scope It
    }

    It 'WhatIf records the planned refresh without mutating registration' {
      Mock -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Get-ProfiledRemotingBoundaryState {
        [PSCustomObject]@{
          RemotingSurfacePresent = $true
          ManagedEndpointStatePresent = $true
          ProbeError = $null
        }
      }

      $result = Set-SprintBoundaryContext -Boundary End `
        -SharedVSCodeWorktreePath $script:svStable `
        -GitRoot $script:gitRoot `
        -ProfiledRemotingPolicy Auto `
        -WhatIf

      $concern = $result.Concerns | Where-Object Concern -EQ 'ProfiledRemotingEndpoint'
      $concern.Action | Should -Be 'WouldRefresh'
      $concern.Succeeded | Should -BeTrue
      $concern.State.ManagedEndpointStatePresent | Should -BeTrue
      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Register-ProfiledRemotingEndpoint -Times 0 -Exactly -Scope It
    }

    It 'Auto preserves the current successful refresh behavior when managed state exists' {
      Mock -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Get-ProfiledRemotingBoundaryState {
        [PSCustomObject]@{
          RemotingSurfacePresent = $false
          ManagedEndpointStatePresent = $true
          ProbeError = 'No configurations enumerated.'
        }
      }

      $result = Set-SprintBoundaryContext -Boundary End `
        -SharedVSCodeWorktreePath $script:svStable `
        -GitRoot $script:gitRoot

      $result.Errors | Should -BeNullOrEmpty
      ($result.Concerns | Where-Object Concern -EQ 'ProfiledRemotingEndpoint').Succeeded | Should -BeTrue
      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Register-ProfiledRemotingEndpoint -Times 1 -Exactly -Scope It
    }
  }

  Context 'Start boundary' {
    It 'Retargets junctions with a dev-redirect to the SharedVSCode sprint worktree' {
      Set-SprintBoundaryContext -Boundary Start `
        -WorktreePaths @($script:worktree) `
        -SharedVSCodeWorktreePath $script:svSprint `
        -GitRoot $script:gitRoot

      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Set-WorktreeJunctions -Times 1 -Exactly -Scope It `
        -ParameterFilter { $DevSourceRepoPath -eq $script:svSprint }
    }

    It 'Applies downstream context via Initialize-DownstreamSprintFromSharedVSCode' {
      Set-SprintBoundaryContext -Boundary Start `
        -WorktreePaths @($script:worktree) `
        -SharedVSCodeWorktreePath $script:svSprint `
        -GitRoot $script:gitRoot

      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Initialize-DownstreamSprintFromSharedVSCode -Times 1 -Exactly -Scope It
      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Reset-DownstreamToSharedVSCodeMain -Times 0 -Exactly -Scope It
    }

    It 'uses one authoritative shared lifecycle for user-global registration and preserves the gates' {
      Set-SprintBoundaryContext -Boundary Start `
        -WorktreePaths @($script:worktree) `
        -SharedVSCodeWorktreePath $script:svSprint `
        -GitRoot $script:gitRoot `
        -AllowUserGlobalWrite `
        -CheckpointConfirmed

      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Set-UserSettingsSymlink -Times 1 -Exactly -Scope It `
        -ParameterFilter { $SharedVSCodeWorktreePath -eq $script:svSprint }
      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Set-ClaudeSettingsSymlink -Times 0 -Exactly -Scope It
      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Invoke-SprintAIAdapterLifecycle -Times 1 -Exactly -Scope It `
        -ParameterFilter {
          $Boundary -eq 'Start' -and $TargetRoot -eq $script:svSprint -and
          [bool]$AllowUserGlobalWrite -and [bool]$CheckpointConfirmed -and
          -not [bool]$OmitSprintWorktrees
        }
      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Invoke-SprintAIAdapterLifecycle -Times 1 -Exactly -Scope It `
        -ParameterFilter {
          $Boundary -eq 'Start' -and $TargetRoot -eq $script:worktree -and
          -not [bool]$AllowUserGlobalWrite -and -not [bool]$CheckpointConfirmed
        }
      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Invoke-SprintAIAdapterLifecycle -Times 0 -Exactly -Scope It `
        -ParameterFilter { [bool]$OmitSprintWorktrees }
    }
  }

  Context 'Concrete-adapter regression (SC-0231): .claude/.github are never junctioned' {
    It 'Start never dev-redirects .claude or .github (default JunctionFolderNames is .vscode only)' {
      Set-SprintBoundaryContext -Boundary Start `
        -WorktreePaths @($script:worktree) `
        -SharedVSCodeWorktreePath $script:svSprint `
        -GitRoot $script:gitRoot

      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Set-WorktreeJunctions -Times 1 -Exactly -Scope It `
        -ParameterFilter {
          @($DevSourceRepoFolderNames) -notcontains '.claude' -and
          @($DevSourceRepoFolderNames) -notcontains '.github' -and
          (@($DevSourceRepoFolderNames) -join ',') -eq '.vscode'
        }
    }

    It 'End never sources .claude or .github back as junctions (StableJunctionFolderNames is .vscode only)' {
      Set-SprintBoundaryContext -Boundary End `
        -WorktreePaths @($script:worktree) `
        -SharedVSCodeWorktreePath $script:svStable `
        -GitRoot $script:gitRoot

      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Set-WorktreeJunctions -Times 1 -Exactly -Scope It `
        -ParameterFilter {
          @($SourceRepoFolderNames) -notcontains '.claude' -and
          @($SourceRepoFolderNames) -notcontains '.github'
        }
    }

    It 'An explicit legacy three-folder request is the ONLY way .claude/.github get dev-redirected (guards the default, not the capability)' {
      Set-SprintBoundaryContext -Boundary Start `
        -WorktreePaths @($script:worktree) `
        -SharedVSCodeWorktreePath $script:svSprint `
        -GitRoot $script:gitRoot `
        -JunctionFolderNames @('.claude', '.github', '.vscode')

      # Proves the assertion above is about the DEFAULT: when a caller explicitly opts
      # in, the names flow through - so a regression to the old default would be caught
      # by the default-only tests, not masked by the parameter being ignored.
      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Set-WorktreeJunctions -Times 1 -Exactly -Scope It `
        -ParameterFilter { @($DevSourceRepoFolderNames) -contains '.claude' }
    }
  }

  Context 'SC-0236 regression: Start filters the junction SOURCE SCAN, not just the dev-redirect' {
    It 'Passes -SourceRepoFolderNames matching JunctionFolderNames on Start (default .vscode only)' {
      Set-SprintBoundaryContext -Boundary Start `
        -WorktreePaths @($script:worktree) `
        -SharedVSCodeWorktreePath $script:svSprint `
        -GitRoot $script:gitRoot

      # Before the SC-0236 fix, Start never bound -SourceRepoFolderNames at all, so
      # Set-WorktreeJunctions' scan was unfiltered and would recreate ANY junction
      # physically present in the stable repo (e.g. a stale .claude/.github junction),
      # independent of DevSourceRepoFolderNames. This asserts the scan filter itself.
      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Set-WorktreeJunctions -Times 1 -Exactly -Scope It `
        -ParameterFilter {
          (@($SourceRepoFolderNames) -join ',') -eq '.vscode'
        }
    }

    It 'An explicit legacy three-folder request also widens the source scan (guards the default, not the capability)' {
      Set-SprintBoundaryContext -Boundary Start `
        -WorktreePaths @($script:worktree) `
        -SharedVSCodeWorktreePath $script:svSprint `
        -GitRoot $script:gitRoot `
        -JunctionFolderNames @('.claude', '.github', '.vscode')

      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Set-WorktreeJunctions -Times 1 -Exactly -Scope It `
        -ParameterFilter { @($SourceRepoFolderNames) -contains '.claude' }
    }
  }

  Context 'Single-entry Start ordering (Task 12.2.b): junctions -> context -> adapter render' {
    BeforeEach {
      $global:sbcCallOrder = [System.Collections.Generic.List[string]]::new()
      Mock -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Set-WorktreeJunctions {
        $global:sbcCallOrder.Add('junctions')
        [PSCustomObject]@{ Success = $true; Errors = @() }
      }
      Mock -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Initialize-DownstreamSprintFromSharedVSCode {
        $global:sbcCallOrder.Add('context')
      }
      Mock -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Invoke-SprintAIAdapterLifecycle {
        $global:sbcCallOrder.Add('render')
        [PSCustomObject]@{ DriftClean = $true; Results = @(); ChangedCount = 0 }
      }
    }

    AfterEach {
      Remove-Variable -Name sbcCallOrder -Scope Global -Force -ErrorAction SilentlyContinue
    }

    It 'Renders adapters only AFTER junction setup and downstream context (junctions-before-render)' {
      Set-SprintBoundaryContext -Boundary Start `
        -WorktreePaths @($script:worktree) `
        -SharedVSCodeWorktreePath $script:svSprint `
        -GitRoot $script:gitRoot `
        -SkipSharedVSCodeSettings `
        -SkipProfileSymlinks

      @($global:sbcCallOrder) | Should -Be @('junctions', 'context', 'render')
    }

    It 'A junction failure prevents the adapter render for that worktree (render can never precede junctions)' {
      Mock -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Set-WorktreeJunctions {
        $global:sbcCallOrder.Add('junctions')
        [PSCustomObject]@{ Success = $false; Errors = @('boom') }
      }

      $result = Set-SprintBoundaryContext -Boundary Start `
        -WorktreePaths @($script:worktree) `
        -SharedVSCodeWorktreePath $script:svSprint `
        -GitRoot $script:gitRoot `
        -SkipSharedVSCodeSettings `
        -SkipProfileSymlinks

      @($global:sbcCallOrder) | Should -Be @('junctions')
      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Invoke-SprintAIAdapterLifecycle -Times 0 -Exactly -Scope It
      $result.PerWorktree[0].JunctionError | Should -Match 'Junction retarget failed'
    }

    It 'Reports granular per-concern errors so delegating Stage callers can map severities' {
      Mock -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Invoke-SprintAIAdapterLifecycle {
        $global:sbcCallOrder.Add('render')
        throw 'render exploded'
      }

      $result = Set-SprintBoundaryContext -Boundary Start `
        -WorktreePaths @($script:worktree) `
        -SharedVSCodeWorktreePath $script:svSprint `
        -GitRoot $script:gitRoot `
        -SkipSharedVSCodeSettings `
        -SkipProfileSymlinks

      $result.PerWorktree[0].JunctionsRetargeted | Should -BeTrue
      $result.PerWorktree[0].JunctionError | Should -BeNullOrEmpty
      $result.PerWorktree[0].ContextError | Should -BeNullOrEmpty
      $result.PerWorktree[0].AdapterError | Should -Match 'render exploded'
    }
  }

  Context 'SkipSharedVSCodeSettings (Task 12.2.b): Stage callers own the machine-global settings concern' {
    It 'Skips the shared-settings render and both settings symlinks' {
      $result = Set-SprintBoundaryContext -Boundary Start `
        -WorktreePaths @($script:worktree) `
        -SharedVSCodeWorktreePath $script:svSprint `
        -GitRoot $script:gitRoot `
        -SkipSharedVSCodeSettings

      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Set-UserSettingsSymlink -Times 0 -Exactly -Scope It
      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Set-ClaudeSettingsSymlink -Times 0 -Exactly -Scope It
      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Invoke-SprintAIAdapterLifecycle -Times 0 -Exactly -Scope It `
        -ParameterFilter { $TargetRoot -eq $script:svSprint }
      ($result.Concerns | Where-Object Concern -EQ 'SharedVSCodeSettings').Action | Should -Be 'Skipped'
      # The per-worktree adapter materialization still runs — only the machine-global concern is skipped.
      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Invoke-SprintAIAdapterLifecycle -Times 1 -Exactly -Scope It `
        -ParameterFilter { $Boundary -eq 'Start' -and $TargetRoot -eq $script:worktree }
    }
  }

  Context 'End boundary' {
    It 'recovers detected drift by projecting stable-only adapters onto the sprint branch and continues teardown' {
      Mock -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Invoke-SprintAIAdapterLifecycle {
        if ($Boundary -eq 'End') {
          [PSCustomObject]@{ DriftClean = $false; Results = @(); ChangedCount = 0 }
        } else {
          [PSCustomObject]@{ DriftClean = $true; Results = @(); ChangedCount = 0; Idempotent = $true; UserGlobalIntentLedgerPath = 'intent.json' }
        }
      }

      $result = Set-SprintBoundaryContext -Boundary End `
        -WorktreePaths @($script:worktree) `
        -SharedVSCodeWorktreePath $script:svStable `
        -GitRoot $script:gitRoot

      ($result.Errors -join '; ') | Should -Not -Match 'AI adapter lifecycle failed|promote-or-regenerate review'
      $result.PerWorktree[0].AISettingsDriftClean | Should -BeFalse
      $result.PerWorktree[0].StableAdaptersRegenerated | Should -BeTrue
      $result.PerWorktree[0].StableAdapterProjectionApplied | Should -BeTrue
      $result.PerWorktree[0].StableAdapterConverged | Should -BeTrue
      $result.PerWorktree[0].StableAdapterRenderPassCount | Should -Be 2
      $result.PerWorktree[0].StableAdapterSecondPassClean | Should -BeTrue
      $result.PerWorktree[0].StableAdapterIntentLedgerPath | Should -Be 'intent.json'
      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Invoke-SprintAIAdapterLifecycle -Times 1 -Exactly -Scope It `
        -ParameterFilter { $Boundary -eq 'Start' -and $TargetRoot -eq $script:worktree -and [bool]$OmitSprintWorktrees }
      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Invoke-SprintAIAdapterLifecycle -Times 0 -Exactly -Scope It `
        -ParameterFilter { $TargetRoot -eq $script:stableRepo }
      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Set-WorktreeJunctions -Times 1 -Exactly -Scope It
      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Reset-DownstreamToSharedVSCodeMain -Times 1 -Exactly -Scope It
    }

    It 'Retargets junctions without a dev-redirect (back to stable)' {
      Set-SprintBoundaryContext -Boundary End `
        -WorktreePaths @($script:worktree) `
        -SharedVSCodeWorktreePath $script:svStable `
        -GitRoot $script:gitRoot

      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Set-WorktreeJunctions -Times 1 -Exactly -Scope It `
        -ParameterFilter {
          [string]::IsNullOrEmpty($DevSourceRepoPath) -and
          (@($SourceRepoFolderNames) -join ',') -eq '.vscode'
        }
    }

    It 'Resets downstream context via Reset-DownstreamToSharedVSCodeMain' {
      Set-SprintBoundaryContext -Boundary End `
        -WorktreePaths @($script:worktree) `
        -SharedVSCodeWorktreePath $script:svStable `
        -GitRoot $script:gitRoot

      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Reset-DownstreamToSharedVSCodeMain -Times 1 -Exactly -Scope It
      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Initialize-DownstreamSprintFromSharedVSCode -Times 0 -Exactly -Scope It
    }

    It 'Refuses to retarget junctions when the supplied worktree path is identical to the derived stable repo path (CP06-D02, Task 13.20.a regression)' {
      # Regression for the Sprint 0012 close incident (CP06-D02): a stable
      # repository root was substituted for a missing sprint worktree, which
      # made the derived "stable" path identical to the supplied "worktree"
      # path. Previously this only surfaced as an opaque throw deep inside
      # Set-WorktreeJunctions. It must now be rejected explicitly, before any
      # external helper (Set-WorktreeJunctions, adapter lifecycle) is invoked,
      # with a clear message -- and must not abort the whole call: other,
      # valid worktrees still get processed.
      $stableRootAsWorktree = $script:stableRepo

      $result = Set-SprintBoundaryContext -Boundary End `
        -WorktreePaths @($stableRootAsWorktree, $script:worktree) `
        -SharedVSCodeWorktreePath $script:svStable `
        -GitRoot $script:gitRoot

      # Joined match (not a per-element pipeline match): this environment's
      # Set-SprintBoundaryContext may also record an unrelated, unmocked
      # Register-ProfiledRemotingEndpoint failure in the same Errors array
      # (a pre-existing local-machine condition, reproducible even on a clean
      # checkout with no code changes); the assertion must not depend on
      # every array element matching this specific message.
      ($result.Errors -join '; ') | Should -Match 'identical to the supplied worktree path'
      $badEntry = $result.PerWorktree | Where-Object { $_.WorktreePath -eq $stableRootAsWorktree }
      $badEntry.JunctionError | Should -Match 'identical to the supplied worktree path'
      $badEntry.JunctionsRetargeted | Should -BeFalse

      # Set-WorktreeJunctions must never be invoked for the offending path.
      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Set-WorktreeJunctions -Times 0 -Exactly -Scope It `
        -ParameterFilter { $WorktreePath -eq $stableRootAsWorktree }

      # The other, legitimate worktree in the same call still gets retargeted.
      $goodEntry = $result.PerWorktree | Where-Object { $_.WorktreePath -eq $script:worktree }
      $goodEntry.JunctionsRetargeted | Should -BeTrue
      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Set-WorktreeJunctions -Times 1 -Exactly -Scope It `
        -ParameterFilter { $WorktreePath -eq $script:worktree }
    }

    It 'uses End deregistration plus one authoritative gated shared lifecycle, while stable projections remain user-global-free' {
      Set-SprintBoundaryContext -Boundary End `
        -WorktreePaths @($script:worktree) `
        -SharedVSCodeWorktreePath $script:svStable `
        -GitRoot $script:gitRoot `
        -AllowUserGlobalWrite `
        -CheckpointConfirmed

      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Invoke-SprintAIAdapterLifecycle -Times 1 -Exactly -Scope It `
        -ParameterFilter { $Boundary -eq 'End' -and $TargetRoot -eq $script:worktree -and -not [bool]$OmitSprintWorktrees }
      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Invoke-SprintAIAdapterLifecycle -Times 1 -Exactly -Scope It `
        -ParameterFilter {
          $Boundary -eq 'Start' -and $TargetRoot -eq $script:worktree -and
          [bool]$OmitSprintWorktrees -and -not [bool]$AllowUserGlobalWrite -and
          -not [bool]$CheckpointConfirmed
        }
      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Invoke-SprintAIAdapterLifecycle -Times 0 -Exactly -Scope It `
        -ParameterFilter { $TargetRoot -eq $script:stableRepo }
      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Invoke-SprintAIAdapterLifecycle -Times 1 -Exactly -Scope It `
        -ParameterFilter {
          $Boundary -eq 'Start' -and $TargetRoot -eq $script:svStable -and
          [bool]$OmitSprintWorktrees -and [bool]$AllowUserGlobalWrite -and
          [bool]$CheckpointConfirmed
        }
      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Set-ClaudeSettingsSymlink -Times 0 -Exactly -Scope It
    }
  }

  Context 'Return contract' {
    It 'Covers the boundary concerns; profile symlinks are active, ConfigRootKeys stable-by-design' {
      $result = Set-SprintBoundaryContext -Boundary Start `
        -WorktreePaths @($script:worktree) `
        -SharedVSCodeWorktreePath $script:svSprint `
        -GitRoot $script:gitRoot

      $names = $result.Concerns.Concern
      $names | Should -Contain 'MachineLinks'
      $names | Should -Contain 'SharedVSCodeSettings'
      $names | Should -Contain 'DownstreamContexts'
      $names | Should -Contain 'AIAdapterLifecycle'
      $names | Should -Contain 'PowerShell7ProfileSymlinks'
      $names | Should -Contain 'DeveloperPowerShellProfiles'
      $names | Should -Contain 'ServiceAccountPowerShellProfiles'
      $names | Should -Contain 'SharedPrimaryRoleMarker'
      $names | Should -Contain 'ConfigRootKeys'

      ($result.Concerns | Where-Object Concern -EQ 'PowerShell7ProfileSymlinks').StableByDesign | Should -BeFalse
      ($result.Concerns | Where-Object Concern -EQ 'SharedPrimaryRoleMarker').StableByDesign | Should -BeTrue
      ($result.Concerns | Where-Object Concern -EQ 'ConfigRootKeys').StableByDesign | Should -BeTrue
    }

    It 'validates the stable shared primary-role marker at Start and End' {
      Set-SprintBoundaryContext -Boundary Start `
        -WorktreePaths @($script:worktree) `
        -SharedVSCodeWorktreePath $script:svSprint `
        -GitRoot $script:gitRoot

      Set-SprintBoundaryContext -Boundary End `
        -WorktreePaths @($script:worktree) `
        -SharedVSCodeWorktreePath $script:svStable `
        -GitRoot $script:gitRoot

      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Sync-SprintBoundaryPrimaryRoleMarker -Times 1 -Exactly -Scope It `
        -ParameterFilter { $Boundary -eq 'Start' }
      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Sync-SprintBoundaryPrimaryRoleMarker -Times 1 -Exactly -Scope It `
        -ParameterFilter { $Boundary -eq 'End' }
    }

    It 'Retargets the PowerShell 7 profile symlinks to the sprint worktree at Start' {
      Set-SprintBoundaryContext -Boundary Start `
        -WorktreePaths @($script:worktree) `
        -SharedVSCodeWorktreePath $script:svSprint `
        -GitRoot $script:gitRoot

      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Set-PowerShell7ProfileSymlink -Times 1 -Exactly -Scope It `
        -ParameterFilter { $ATAPUtilitiesRoot -eq $script:worktree }
    }

    It 'Resets the PowerShell 7 profile symlinks to stable repos at End' {
      Set-SprintBoundaryContext -Boundary End `
        -WorktreePaths @($script:worktree) `
        -SharedVSCodeWorktreePath $script:svStable `
        -GitRoot $script:gitRoot

      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Set-PowerShell7ProfileSymlink -Times 1 -Exactly -Scope It `
        -ParameterFilter { $ATAPUtilitiesRoot -eq (Join-Path $script:gitRoot 'ATAP.Utilities') -and $ATAPIACRoot -eq (Join-Path $script:gitRoot 'ATAP.IAC') }
    }

    It 'Skips the profile-symlink concern when -SkipProfileSymlinks is set' {
      $result = Set-SprintBoundaryContext -Boundary End `
        -WorktreePaths @($script:worktree) `
        -SharedVSCodeWorktreePath $script:svStable `
        -GitRoot $script:gitRoot `
        -SkipProfileSymlinks

      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Set-PowerShell7ProfileSymlink -Times 0 -Exactly -Scope It
      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Set-SprintBoundaryUserProfiles -Times 0 -Exactly -Scope It
      ($result.Concerns | Where-Object Concern -EQ 'PowerShell7ProfileSymlinks').Action | Should -Be 'Skipped'
    }

    It 'Deploys developer and service-account user profiles from the resolved ATAP roots' {
      Set-SprintBoundaryContext -Boundary End `
        -WorktreePaths @($script:worktree) `
        -SharedVSCodeWorktreePath $script:svStable `
        -GitRoot $script:gitRoot

      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Set-SprintBoundaryUserProfiles -Times 1 -Exactly -Scope It `
        -ParameterFilter { $ATAPUtilitiesRoot -eq (Join-Path $script:gitRoot 'ATAP.Utilities') -and $ATAPIACRoot -eq (Join-Path $script:gitRoot 'ATAP.IAC') }
    }

    It 'Reports a per-worktree breakdown with the derived stable repo path' {
      $result = Set-SprintBoundaryContext -Boundary Start `
        -WorktreePaths @($script:worktree) `
        -SharedVSCodeWorktreePath $script:svSprint `
        -GitRoot $script:gitRoot

      $result.PerWorktree | Should -HaveCount 1
      $result.PerWorktree[0].StableRepoPath | Should -Be $script:stableRepo
      $result.PerWorktree[0].JunctionsRetargeted | Should -BeTrue
      $result.PerWorktree[0].ContextRetargeted | Should -BeTrue
      $result.PerWorktree[0].AISettingsProcessed | Should -BeTrue
      $result.PerWorktree[0].AISettingsDriftClean | Should -BeTrue
    }

    It 'Records a missing worktree as an error and continues' {
      $missing = Join-Path $script:gitRoot 'Nope-wt-1-Sprint-0007-work-items'
      $result = Set-SprintBoundaryContext -Boundary Start `
        -WorktreePaths @($missing) `
        -SharedVSCodeWorktreePath $script:svSprint `
        -GitRoot $script:gitRoot

      $result.Errors.Count | Should -BeGreaterThan 0
      $result.PerWorktree[0].Error | Should -Match 'not found'
    }
  }

  Context 'Settings-only invocation' {
    It 'Retargets settings symlinks with no worktrees supplied' {
      Set-SprintBoundaryContext -Boundary End -SharedVSCodeWorktreePath $script:svStable -GitRoot $script:gitRoot

      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Set-UserSettingsSymlink -Times 1 -Exactly -Scope It
      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Set-WorktreeJunctions -Times 0 -Exactly -Scope It
      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Invoke-SprintAIAdapterLifecycle -Times 1 -Exactly -Scope It `
        -ParameterFilter { $Boundary -eq 'Start' -and $TargetRoot -eq $script:svStable -and [bool]$OmitSprintWorktrees }
    }
  }

  Context 'WhatIf' {
    It 'Performs no mutation under -WhatIf' {
      Set-SprintBoundaryContext -Boundary Start `
        -WorktreePaths @($script:worktree) `
        -SharedVSCodeWorktreePath $script:svSprint `
        -GitRoot $script:gitRoot `
        -WhatIf

      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Set-WorktreeJunctions -Times 0 -Exactly -Scope It
      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Initialize-DownstreamSprintFromSharedVSCode -Times 0 -Exactly -Scope It
      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Set-UserSettingsSymlink -Times 0 -Exactly -Scope It
      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Invoke-SprintAIAdapterLifecycle -Times 0 -Exactly -Scope It
      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Set-PowerShell7ProfileSymlink -Times 0 -Exactly -Scope It
      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Set-SprintBoundaryUserProfiles -Times 0 -Exactly -Scope It
      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Sync-SprintBoundaryPrimaryRoleMarker -Times 0 -Exactly -Scope It
    }
  }
}
