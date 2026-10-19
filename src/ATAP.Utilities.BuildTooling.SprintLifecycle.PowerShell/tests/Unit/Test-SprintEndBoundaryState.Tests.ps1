#Requires -Version 7.0

BeforeAll {
  # Settings behavior is covered by SettingsLinkLifecycle.Sprint0016.Tests.ps1;
  # keep this suite isolated from the host settings entry.
  function Set-UserSettingsSymlink {
    [CmdletBinding(SupportsShouldProcess)]
    param([string]$SharedVSCodeWorktreePath, [switch]$CheckOnly, [string[]]$WorktreePaths)
    [PSCustomObject]@{ Ok = $true; Planned = $false; Changed = $false }
  }
  # Task 15.208: isolate login maintenance from the host Task Scheduler.
  function Set-SprintLoginScheduledTaskTarget {
    [CmdletBinding(SupportsShouldProcess)]
    param([string]$Boundary, [string]$ATAPUtilitiesRoot, [string]$GitRoot,
      [string]$LoginScriptPath, [string[]]$WorktreePaths, [switch]$CheckOnly)
    [PSCustomObject]@{ Ok = $true; Boundary = $Boundary; SelectionMode = 'SprintDefault';
      TargetPath = $LoginScriptPath; TargetHash = 'fixture'; Planned = [bool]$WhatIfPreference;
      Changed = $false; Tasks = @(); Rollback = @{ Attempted = $false; Succeeded = $true; Failures = @() }; Failures = @() }
  }
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
  }

  $moduleRoot = Join-Path $PSScriptRoot '..\..'
  . (Join-Path $moduleRoot 'public\Test-SprintEndBoundaryState.ps1')
  $script:physicalEnumerationCommand = Get-Command Get-ChildItem -CommandType Cmdlet
  $script:physicalSearchCommand = Get-Command Select-String -CommandType Cmdlet
  function Install-LogicalAuditProjection {
    # Physical fixtures stay under SC-0033 evidence. Project their scan identities
    # outside that ancestor so these two cases actually exercise live descendants.
    # Production classification remains unchanged; content reads use the real files.
    $script:logicalProjectionRoot = 'C:\LifecycleFixture'
    $script:logicalToPhysical = @{}
    Mock Get-ChildItem -ParameterFilter { $File -and $Recurse } {
      foreach ($physicalFile in & $script:physicalEnumerationCommand -LiteralPath $LiteralPath -Filter $Filter -File -Recurse) {
        $logicalPath = Join-Path $script:logicalProjectionRoot ([IO.Path]::GetRelativePath($TestDrive, $physicalFile.FullName))
        $script:logicalToPhysical[$logicalPath] = $physicalFile.FullName
        [PSCustomObject]@{ FullName = $logicalPath }
      }
    }
    Mock Select-String -ParameterFilter { $script:logicalToPhysical.ContainsKey([string]$LiteralPath) } {
      & $script:physicalSearchCommand -LiteralPath $script:logicalToPhysical[[string]$LiteralPath] -Pattern $Pattern -AllMatches
    }
  }
}

Describe 'Test-SprintEndBoundaryState stale-reference scope split' -Tag 'Unit' {
  BeforeEach {
    Mock Set-SprintLoginScheduledTaskTarget { [PSCustomObject]@{ Ok = $true; Planned = $false; Changed = $false; Tasks = @(); Failures = @() } }
  }
  Context 'live configuration vs historical evidence' {
    It 'fails the gate when a stale sprint path appears in a live adapter/settings/workspace fixture' {
      $gitRoot = Join-Path $TestDrive 'live-only'
      New-Item -ItemType Directory -Path $gitRoot -Force | Out-Null
      Set-Content -LiteralPath (Join-Path $gitRoot 'Overview.code-workspace') `
        -Value '{"folders":[{"path":"SharedVSCode-wt-48-Sprint-0010-work-items"}]}'

      Install-LogicalAuditProjection

      $result = Test-SprintEndBoundaryState `
        -GitRoot $gitRoot `
        -SearchRoots @($gitRoot) `
        -ProfilePaths @() `
        -ProhibitedEnvironmentVariableNames @()

      $result.Ok | Should -BeFalse
      $result.Failures | Should -Contain 'StaleSprintReferences'
      $result.LiveStaleReferences.Count | Should -Be 1
      $result.HistoricalStaleReferences.Count | Should -Be 0
      $result.StaleReferences.Count | Should -Be 1
      $result.StaleReferences[0].Classification | Should -Be 'LiveConfiguration'
    }

    It 'reports but does not fail the gate for a stale sprint path under a SprintHistory archive fixture' {
      $gitRoot = Join-Path $TestDrive 'history-only'
      $historyDir = Join-Path $gitRoot 'SprintHistory'
      New-Item -ItemType Directory -Path $historyDir -Force | Out-Null
      Set-Content -LiteralPath (Join-Path $historyDir 'Overview.Sprint0010.code-workspace') `
        -Value '{"folders":[{"path":"SharedVSCode-wt-48-Sprint-0010-work-items"}]}'

      $result = Test-SprintEndBoundaryState `
        -GitRoot $gitRoot `
        -SearchRoots @($gitRoot) `
        -ProfilePaths @() `
        -ProhibitedEnvironmentVariableNames @()

      $result.Ok | Should -BeTrue
      $result.Failures | Should -Not -Contain 'StaleSprintReferences'
      $result.LiveStaleReferences.Count | Should -Be 0
      $result.HistoricalStaleReferences.Count | Should -Be 1
      $result.StaleReferences.Count | Should -Be 1
      $result.StaleReferences[0].Classification | Should -Be 'HistoricalEvidence'
    }

    It 'fails the gate for a stale reference under the search root _generated folder (Task 16.91.d)' {
      $gitRoot = Join-Path $TestDrive 'generated-variant'
      $dir = Join-Path $gitRoot '_generated\Evidence'
      New-Item -ItemType Directory -Path $dir -Force | Out-Null
      Set-Content -LiteralPath (Join-Path $dir 'stale.json') `
        -Value '{"path":"SharedVSCode-wt-48-Sprint-0010-work-items"}'

      $result = Test-SprintEndBoundaryState `
        -GitRoot $gitRoot `
        -SearchRoots @($gitRoot) `
        -ProfilePaths @() `
        -ProhibitedEnvironmentVariableNames @()

      $result.Ok | Should -BeFalse
      $result.Failures | Should -Contain 'GeneratedArtifactReferences'
      $result.GeneratedArtifactReferences.Count | Should -Be 1
      $result.StaleReferences[0].Classification | Should -Be 'GeneratedArtifact'
    }

    It 'does not classify by a _generated folder above the search root' {
      $gitRoot = Join-Path $TestDrive '_generated\nested-root'
      $dir = Join-Path $gitRoot 'Archived'
      New-Item -ItemType Directory -Path $dir -Force | Out-Null
      Set-Content -LiteralPath (Join-Path $dir 'stale.json') `
        -Value '{"path":"SharedVSCode-wt-48-Sprint-0010-work-items"}'

      $result = Test-SprintEndBoundaryState `
        -GitRoot $gitRoot `
        -SearchRoots @($gitRoot) `
        -ProfilePaths @() `
        -ProhibitedEnvironmentVariableNames @()

      $result.Failures | Should -Not -Contain 'GeneratedArtifactReferences'
      $result.HistoricalStaleReferences.Count | Should -Be 1
    }

    It 'still searches SprintRetrospective WorkspaceArchive, Archived, and Samples evidence folders without failing the gate' {
      $gitRoot = Join-Path $TestDrive 'history-variants'
      $folders = @(
        'SprintRetrospective\WorkspaceArchive',
        'Archived',
        'Samples'
      )
      foreach ($folder in $folders) {
        $dir = Join-Path $gitRoot $folder
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $dir 'stale.json') `
          -Value '{"path":"SharedVSCode-wt-48-Sprint-0010-work-items"}'
      }

      $result = Test-SprintEndBoundaryState `
        -GitRoot $gitRoot `
        -SearchRoots @($gitRoot) `
        -ProfilePaths @() `
        -ProhibitedEnvironmentVariableNames @()

      $result.Ok | Should -BeTrue
      $result.Failures | Should -Not -Contain 'StaleSprintReferences'
      $result.LiveStaleReferences.Count | Should -Be 0
      $result.HistoricalStaleReferences.Count | Should -Be $folders.Count
    }

    It 'classifies committed Task before and after summary JSON as historical evidence' {
      $gitRoot = Join-Path $TestDrive 'committed-task-evidence'
      $documentationRoot = Join-Path $gitRoot 'SharedVSCode\SolutionDocumentation'
      New-Item -ItemType Directory -Path $documentationRoot -Force | Out-Null
      foreach ($phase in @('before', 'after')) {
        Set-Content -LiteralPath (Join-Path $documentationRoot "AI-Instruction-Inventory-Task-8.20.$phase.summary.json") `
          -Value '{"path":"SharedVSCode-wt-44-Sprint-0008-work-items"}'
      }

      $result = Test-SprintEndBoundaryState `
        -GitRoot $gitRoot `
        -SearchRoots @($gitRoot) `
        -ProfilePaths @() `
        -ProhibitedEnvironmentVariableNames @()

      $result.Ok | Should -BeTrue
      $result.LiveStaleReferences.Count | Should -Be 0
      $result.HistoricalStaleReferences.Count | Should -Be 2
      @($result.HistoricalStaleReferences | Select-Object -ExpandProperty Classification -Unique) |
        Should -Be @('HistoricalEvidence')
    }

    It 'fails with only the live finding as the cause when both live and historical stale paths exist' {
      $gitRoot = Join-Path $TestDrive 'mixed'
      $historyDir = Join-Path $gitRoot 'SprintHistory'
      New-Item -ItemType Directory -Path $gitRoot, $historyDir -Force | Out-Null
      Set-Content -LiteralPath (Join-Path $gitRoot 'Overview.code-workspace') `
        -Value '{"folders":[{"path":"SharedVSCode-wt-48-Sprint-0010-work-items"}]}'
      Set-Content -LiteralPath (Join-Path $historyDir 'Overview.Sprint0010.code-workspace') `
        -Value '{"folders":[{"path":"SharedVSCode-wt-48-Sprint-0010-work-items"}]}'

      Install-LogicalAuditProjection
      $result = Test-SprintEndBoundaryState `
        -GitRoot $gitRoot `
        -SearchRoots @($gitRoot) `
        -ProfilePaths @() `
        -ProhibitedEnvironmentVariableNames @()

      $result.Ok | Should -BeFalse
      $result.Failures | Should -Be @('StaleSprintReferences')
      $result.LiveStaleReferences.Count | Should -Be 1
      $result.HistoricalStaleReferences.Count | Should -Be 1
      $result.StaleReferences.Count | Should -Be 2
      $result.LiveStaleReferences[0].Path | Should -Be (Join-Path $script:logicalProjectionRoot 'mixed/Overview.code-workspace')
    }

    It 'does not fail the gate when no stale references exist anywhere' {
      $gitRoot = Join-Path $TestDrive 'clean'
      New-Item -ItemType Directory -Path $gitRoot -Force | Out-Null
      Set-Content -LiteralPath (Join-Path $gitRoot 'Overview.code-workspace') -Value '{"folders":[]}'

      $result = Test-SprintEndBoundaryState `
        -GitRoot $gitRoot `
        -SearchRoots @($gitRoot) `
        -ProfilePaths @() `
        -ProhibitedEnvironmentVariableNames @()

      $result.Ok | Should -BeTrue
      $result.StaleReferences.Count | Should -Be 0
      $result.LiveStaleReferences.Count | Should -Be 0
      $result.HistoricalStaleReferences.Count | Should -Be 0
    }
  }
}
