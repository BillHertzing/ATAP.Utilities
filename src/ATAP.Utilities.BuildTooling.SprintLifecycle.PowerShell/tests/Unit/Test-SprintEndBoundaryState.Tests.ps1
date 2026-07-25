#Requires -Version 7.0

BeforeAll {
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
  }

  $moduleRoot = Join-Path $PSScriptRoot '..\..'
  . (Join-Path $moduleRoot 'public\Test-SprintEndBoundaryState.ps1')
}

Describe 'Test-SprintEndBoundaryState stale-reference scope split' -Tag 'Unit' {
  Context 'live configuration vs historical evidence' {
    It 'fails the gate when a stale sprint path appears in a live adapter/settings/workspace fixture' {
      $gitRoot = Join-Path $TestDrive 'live-only'
      New-Item -ItemType Directory -Path $gitRoot -Force | Out-Null
      Set-Content -LiteralPath (Join-Path $gitRoot 'Overview.code-workspace') `
        -Value '{"folders":[{"path":"SharedVSCode-wt-48-Sprint-0010-work-items"}]}'

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

    It 'still searches SprintRetrospective WorkspaceArchive, Archived, Samples, and _generated evidence folders without failing the gate' {
      $gitRoot = Join-Path $TestDrive 'history-variants'
      $folders = @(
        'SprintRetrospective\WorkspaceArchive',
        'Archived',
        'Samples',
        '_generated\Evidence'
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

    It 'fails with only the live finding as the cause when both live and historical stale paths exist' {
      $gitRoot = Join-Path $TestDrive 'mixed'
      $historyDir = Join-Path $gitRoot 'SprintHistory'
      New-Item -ItemType Directory -Path $gitRoot, $historyDir -Force | Out-Null
      Set-Content -LiteralPath (Join-Path $gitRoot 'Overview.code-workspace') `
        -Value '{"folders":[{"path":"SharedVSCode-wt-48-Sprint-0010-work-items"}]}'
      Set-Content -LiteralPath (Join-Path $historyDir 'Overview.Sprint0010.code-workspace') `
        -Value '{"folders":[{"path":"SharedVSCode-wt-48-Sprint-0010-work-items"}]}'

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
      $result.LiveStaleReferences[0].Path | Should -Be (Join-Path $gitRoot 'Overview.code-workspace')
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
