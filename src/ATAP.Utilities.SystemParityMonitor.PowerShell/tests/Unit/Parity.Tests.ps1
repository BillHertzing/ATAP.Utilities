Describe 'ATAP.Utilities.SystemParityMonitor.PowerShell module' {
  BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..\..\ATAP.Utilities.SystemParityMonitor.PowerShell.psd1'
    Import-Module -Name $modulePath -Force
  }

  BeforeEach {
    $testRoot = Join-Path ([IO.Path]::GetTempPath()) "ATAP-Parity-$([guid]::NewGuid())"
    $leftState = Join-Path $testRoot 'utat022'
    $rightState = Join-Path $testRoot 'utat01'
    New-Item -ItemType Directory -Path $leftState, $rightState -Force | Out-Null
  }

  AfterEach {
    if (Test-Path -LiteralPath $testRoot) {
      Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
  }

  It 'Add/Get/Confirm round-trips a peer change through JSONL files' {
    $entry = Add-ParityChangeEntry -StatePath $leftState -HostName 'utat022' -PeerHostName 'utat01' -Category 'Packages' -Item 'git' -OldValue '2.45' -NewValue '2.46' -PeerActionKind 'Manual' -PeerAction 'Review git package parity'

    $pendingBeforeAck = Get-PeerPendingChanges -LocalStatePath $rightState -PeerStatePath $leftState -LocalHostName 'utat01' -PeerHostName 'utat022'
    $pendingBeforeAck | Should -HaveCount 1
    $pendingBeforeAck[0].Id | Should -Be $entry.Id
    $pendingBeforeAck[0].PeerAction | Should -Be 'Review git package parity'

    Confirm-ParityChangeApplied -StatePath $rightState -LocalHostName 'utat01' -PeerHostName 'utat022' -EntryId $entry.Id -Status 'Applied' -Note 'Fixture applied' | Out-Null

    $pendingAfterAck = Get-PeerPendingChanges -LocalStatePath $rightState -PeerStatePath $leftState -LocalHostName 'utat01' -PeerHostName 'utat022'
    $pendingAfterAck | Should -HaveCount 0
  }

  It 'Invoke-ParityAudit writes a JSON snapshot with surfaces' {
    $snapshotPath = Join-Path $leftState 'ParityAudit.utat022.fixture.json'

    $snapshot = Invoke-ParityAudit -StatePath $leftState -HostName 'utat022' -OutputPath $snapshotPath

    Test-Path -LiteralPath $snapshotPath | Should -BeTrue
    $snapshot.HostName | Should -Be 'utat022'
    @($snapshot.Surfaces).Count | Should -BeGreaterThan 0
    $snapshot.SnapshotPath | Should -Be $snapshotPath
  }

  It 'Compare-ParityAudits classifies whitelisted, declared, undeclared, and conflicted-copy drift' {
    $leftSnapshotPath = Join-Path $leftState 'ParityAudit.utat022.fixture.json'
    $rightSnapshotPath = Join-Path $rightState 'ParityAudit.utat01.fixture.json'
    $whitelistPath = Join-Path $leftState 'ParityWhitelist.json'
    $reportPath = Join-Path $leftState 'DriftReport.fixture.md'
    Set-Content -LiteralPath (Join-Path $rightState 'example conflicted copy.txt') -Value 'conflict' -Encoding utf8

    [pscustomobject] @{
      SchemaVersion = 1
      HostName = 'utat022'
      CapturedAtUtc = '2026-07-05T00:00:00.0000000Z'
      Surfaces = @(
        [pscustomobject] @{ Category = 'OS'; Item = 'Version'; Value = 'Windows 11' },
        [pscustomobject] @{ Category = 'Packages'; Item = 'git'; Value = '2.46' },
        [pscustomobject] @{ Category = 'Services'; Item = 'W32Time'; Value = 'Running' }
      )
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $leftSnapshotPath -Encoding utf8

    [pscustomobject] @{
      SchemaVersion = 1
      HostName = 'utat01'
      CapturedAtUtc = '2026-07-05T00:00:00.0000000Z'
      Surfaces = @(
        [pscustomobject] @{ Category = 'OS'; Item = 'Version'; Value = 'Windows 10' },
        [pscustomobject] @{ Category = 'Packages'; Item = 'git'; Value = '2.45' },
        [pscustomobject] @{ Category = 'Services'; Item = 'W32Time'; Value = 'Stopped' }
      )
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $rightSnapshotPath -Encoding utf8

    @(
      [pscustomobject] @{
        category = 'OS'
        item = 'Version'
        sourceHost = 'utat022'
        targetHost = 'utat01'
        expectedOnSource = 'Windows 11'
        acceptedOnTarget = 'Windows 10'
        disposition = 'risk_accepted'
      }
    ) | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $whitelistPath -Encoding utf8

    Add-ParityChangeEntry -StatePath $leftState -HostName 'utat022' -PeerHostName 'utat01' -Category 'Packages' -Item 'git' -OldValue '2.45' -NewValue '2.46' -PeerActionKind 'Manual' | Out-Null

    $comparison = Compare-ParityAudits -LeftStatePath $leftState -RightStatePath $rightState -LeftHostName 'utat022' -RightHostName 'utat01' -LeftSnapshotPath $leftSnapshotPath -RightSnapshotPath $rightSnapshotPath -WhitelistPath $whitelistPath -ReportPath $reportPath

    @($comparison.WhitelistedDrift) | Should -HaveCount 1
    @($comparison.DeclaredDrift) | Should -HaveCount 1
    @($comparison.UndeclaredDrift) | Should -HaveCount 1
    @($comparison.ConflictedCopies) | Should -HaveCount 1
    Test-Path -LiteralPath $reportPath | Should -BeTrue
  }

  It 'Compare-ParityAudits flags stale snapshots when cadence is exceeded' {
    $leftSnapshotPath = Join-Path $leftState 'ParityAudit.utat022.fixture.json'
    $rightSnapshotPath = Join-Path $rightState 'ParityAudit.utat01.fixture.json'
    $reportPath = Join-Path $leftState 'DriftReport.stale.fixture.md'
    $nowUtc = (Get-Date).ToUniversalTime()

    [pscustomobject]@{
      SchemaVersion = 1
      HostName = 'utat022'
      CapturedAtUtc = $nowUtc.AddMinutes(-30).ToString('o')
      Surfaces = @(
        [pscustomobject] @{ Category = 'OS'; Item = 'Version'; Value = 'Windows 11' }
      )
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $leftSnapshotPath -Encoding utf8

    [pscustomobject]@{
      SchemaVersion = 1
      HostName = 'utat01'
      CapturedAtUtc = $nowUtc.AddDays(-2).ToString('o')
      Surfaces = @(
        [pscustomobject] @{ Category = 'OS'; Item = 'Version'; Value = 'Windows 11' }
      )
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $rightSnapshotPath -Encoding utf8

    $comparison = Compare-ParityAudits `
      -LeftStatePath $leftState `
      -RightStatePath $rightState `
      -LeftHostName 'utat022' `
      -RightHostName 'utat01' `
      -LeftSnapshotPath $leftSnapshotPath `
      -RightSnapshotPath $rightSnapshotPath `
      -ReportPath $reportPath `
      -ExpectedCadence (New-TimeSpan -Days 1)

    @($comparison.StaleSnapshots) | Should -HaveCount 1
    $comparison.StaleSnapshots[0].HostName | Should -Be 'utat01'
    $comparison.StaleThreshold | Should -Not -BeNullOrEmpty
    Test-Path -LiteralPath $reportPath | Should -BeTrue
  }
}
