Describe 'ATAP.Utilities.SystemParityMonitor.PowerShell module' -Tag 'Unit', 'ParityCore' {
  BeforeAll {
    if (-not (Get-Module -Name 'ATAP.Utilities.SystemParityMonitor.PowerShell')) {
      $modulePath = Join-Path $PSScriptRoot '..\..\ATAP.Utilities.SystemParityMonitor.PowerShell.psd1'
      Import-Module -Name $modulePath -Force
    }
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
    Mock -CommandName Get-SqlParitySurfaces -ModuleName 'ATAP.Utilities.SystemParityMonitor.PowerShell' -MockWith {
      [pscustomobject]@{ Category = 'SQL'; Item = 'Instance/PRODUCTION/Paths'; Value = 'FilesConform=True'; Source = 'fixture' }
    }
    Mock -CommandName Get-PackageManagerParitySurfaces -ModuleName 'ATAP.Utilities.SystemParityMonitor.PowerShell' -MockWith {
      [pscustomobject]@{ Category = 'PackageManager'; Item = 'Chocolatey/git'; Value = '2.46.0'; Source = 'fixture' }
    }

    $snapshot = Invoke-ParityAudit -StatePath $leftState -HostName 'utat022' -OutputPath $snapshotPath

    Test-Path -LiteralPath $snapshotPath | Should -BeTrue
    $snapshot.HostName | Should -Be 'utat022'
    @($snapshot.Surfaces).Count | Should -BeGreaterThan 0
    @($snapshot.Surfaces | Where-Object Category -eq 'SQL') | Should -HaveCount 1
    @($snapshot.Surfaces | Where-Object Category -eq 'PackageManager') | Should -HaveCount 1
    $snapshot.SnapshotPath | Should -Be $snapshotPath
  }

  It 'collects package versions and flags normalized cross-manager ownership conflicts' {
    InModuleScope 'ATAP.Utilities.SystemParityMonitor.PowerShell' {
      Mock -CommandName Get-Command -ParameterFilter {
        $Name -in @('choco', 'python', 'npm', 'dotnet')
      } -MockWith {
        [pscustomobject]@{ Source = "$Name.exe" }
      }
      Mock -CommandName Invoke-ParityNativeCommand -MockWith {
        param($Command, $ArgumentList)

        $output = switch ([IO.Path]::GetFileNameWithoutExtension($Command)) {
          'choco' { @('git|2.46.0', 'requests|1.0.0') }
          'python' { @('[{"name":"requests","version":"2.32.0"},{"name":"httpx","version":"0.28.0"}]') }
          'npm' { @('{"dependencies":{"requests":{"version":"9.0.0"}}}') }
          'dotnet' { @('Package Id      Version      Commands', '------------------------------------------', 'dotnet-ef       10.0.0       dotnet-ef') }
        }

        [pscustomobject]@{ ExitCode = 0; Output = $output }
      }

      $profiles = @(
        [pscustomobject]@{
          Identity = 'ATAP\Developer'
          PipPath = 'C:\Profiles\Developer\pip-site-packages'
          NpmPrefix = 'C:\Profiles\Developer\npm'
          NuGetToolPath = 'C:\Profiles\Developer\.dotnet\tools'
        }
      )
      $surfaces = @(Get-PackageManagerParitySurfaces -HostName 'utat022' -PackageManagerProfiles $profiles)

      @($surfaces | Where-Object Category -eq 'PackageManager') | Should -HaveCount 6
      @($surfaces | Where-Object Category -eq 'PackageManagerStatus') | Should -HaveCount 4
      @($surfaces | Where-Object Item -eq 'ATAP\Developer/pip/requests') | Should -HaveCount 1
      @($surfaces | Where-Object Item -eq 'ATAP\Developer/npm/requests') | Should -HaveCount 1
      @($surfaces | Where-Object Item -eq 'ATAP\Developer/NuGet/dotnet-ef') | Should -HaveCount 1
      Should -Invoke -CommandName Invoke-ParityNativeCommand -ParameterFilter {
        $ArgumentList -contains 'C:\Profiles\Developer\pip-site-packages'
      } -Times 1
      Should -Invoke -CommandName Invoke-ParityNativeCommand -ParameterFilter {
        $ArgumentList -contains 'C:\Profiles\Developer\npm'
      } -Times 1
      Should -Invoke -CommandName Invoke-ParityNativeCommand -ParameterFilter {
        $ArgumentList -contains 'C:\Profiles\Developer\.dotnet\tools'
      } -Times 1
      $conflicts = @($surfaces | Where-Object Category -eq 'PackageManagerConflict')
      $conflicts | Should -HaveCount 1
      $conflicts[0].Item | Should -Be 'utat022/ATAP\Developer/requests'
      $conflicts[0].Value | Should -Match 'ACTION REQUIRED.*npm:requests@9.0.0.*pip:requests@2.32.0'
    }
  }

  It 'does not infer pip npm or NuGet paths from the audit process identity' {
    InModuleScope 'ATAP.Utilities.SystemParityMonitor.PowerShell' {
      Mock -CommandName Get-Command -ParameterFilter { $Name -eq 'choco' } -MockWith {
        [pscustomobject]@{ Source = 'choco.exe' }
      }
      Mock -CommandName Invoke-ParityNativeCommand -MockWith {
        [pscustomobject]@{ ExitCode = 0; Output = @() }
      }

      $surfaces = @(Get-PackageManagerParitySurfaces -HostName 'utat022')

      @($surfaces | Where-Object Value -eq '<profile-paths-not-configured>') | Should -HaveCount 3
      @($surfaces | Where-Object Category -eq 'PackageManagerStatus') | Should -HaveCount 4
      Should -Invoke -CommandName Get-Command -ParameterFilter {
        $Name -in @('python', 'npm', 'dotnet')
      } -Times 0
    }
  }

  It 'reports an omitted path independently for each configured identity and manager' {
    InModuleScope 'ATAP.Utilities.SystemParityMonitor.PowerShell' {
      Mock -CommandName Get-Command -MockWith { $null }

      $surfaces = @(Get-PackageManagerParitySurfaces -HostName 'utat022' -PackageManagerProfiles @(
          [pscustomobject]@{ Identity = 'ATAP\Developer'; PipPath = 'C:\pip'; NpmPrefix = ''; NuGetToolPath = $null }
        ))

      @($surfaces | Where-Object Item -eq 'ATAP\Developer/npm' | Where-Object Value -eq '<profile-path-not-configured>') | Should -HaveCount 1
      @($surfaces | Where-Object Item -eq 'ATAP\Developer/NuGet' | Where-Object Value -eq '<profile-path-not-configured>') | Should -HaveCount 1
      @($surfaces | Where-Object Item -eq 'ATAP\Developer/pip' | Where-Object Value -eq '<not-installed>') | Should -HaveCount 1
    }
  }

  It 'rejects a configured package-manager profile without an explicit identity' {
    InModuleScope 'ATAP.Utilities.SystemParityMonitor.PowerShell' {
      { Get-PackageManagerParitySurfaces -HostName 'utat022' -PackageManagerProfiles @([pscustomobject]@{ PipPath = 'C:\pip' }) } |
        Should -Throw '*must specify a non-empty Identity*'
    }
  }

  It 'rejects ambiguous duplicate identities and relative profile paths' {
    InModuleScope 'ATAP.Utilities.SystemParityMonitor.PowerShell' {
      { Get-PackageManagerParitySurfaces -HostName 'utat022' -PackageManagerProfiles @(
          [pscustomobject]@{ Identity = 'ATAP\Developer'; PipPath = 'C:\pip' },
          [pscustomobject]@{ Identity = 'atap\developer'; PipPath = 'D:\pip' }
        ) } | Should -Throw '*configured more than once*'

      { Get-PackageManagerParitySurfaces -HostName 'utat022' -PackageManagerProfiles @(
          [pscustomobject]@{ Identity = 'ATAP\Developer'; PipPath = '.\pip' }
        ) } | Should -Throw '*must be a fully qualified path*'

      { Get-PackageManagerParitySurfaces -HostName 'utat022' -PackageManagerProfiles @(
          [pscustomobject]@{ Identity = 'ATAP/Developer'; PipPath = 'C:\pip' }
        ) } | Should -Throw "*cannot contain '/' or '|'*"
    }
  }

  It 'does not report a cross-manager conflict when the managers belong to different identities' {
    InModuleScope 'ATAP.Utilities.SystemParityMonitor.PowerShell' {
      Mock -CommandName Get-Command -ParameterFilter { $Name -in @('choco', 'python', 'npm') } -MockWith {
        [pscustomobject]@{ Source = "$Name.exe" }
      }
      Mock -CommandName Invoke-ParityNativeCommand -MockWith {
        param($Command, $ArgumentList)
        $output = if ([IO.Path]::GetFileNameWithoutExtension($Command) -eq 'python') {
          @('[{"name":"requests","version":"2.32.0"}]')
        } elseif ([IO.Path]::GetFileNameWithoutExtension($Command) -eq 'npm') {
          @('{"dependencies":{"requests":{"version":"9.0.0"}}}')
        } else {
          @()
        }
        [pscustomobject]@{ ExitCode = 0; Output = $output }
      }

      $surfaces = @(Get-PackageManagerParitySurfaces -HostName 'utat022' -PackageManagerProfiles @(
          [pscustomobject]@{ Identity = 'ATAP\PythonUser'; PipPath = 'C:\Profiles\Python\site-packages' },
          [pscustomobject]@{ Identity = 'ATAP\NodeUser'; NpmPrefix = 'C:\Profiles\Node\npm' }
        ))

      @($surfaces | Where-Object Category -eq 'PackageManagerConflict') | Should -HaveCount 0
      @($surfaces | Where-Object Item -eq 'ATAP\PythonUser/pip/requests') | Should -HaveCount 1
      @($surfaces | Where-Object Item -eq 'ATAP\NodeUser/npm/requests') | Should -HaveCount 1
    }
  }

  It 'Invoke-ParityAudit writes missing SQL and PackageManager findings before failing loudly' {
    $snapshotPath = Join-Path $leftState 'ParityAudit.utat022.missing-coverage.fixture.json'
    $moduleName = 'ATAP.Utilities.SystemParityMonitor.PowerShell'
    Mock -CommandName Get-SqlParitySurfaces -ModuleName $moduleName -MockWith { @() }
    Mock -CommandName Get-PackageManagerParitySurfaces -ModuleName $moduleName -MockWith { @() }

    { Invoke-ParityAudit -StatePath $leftState -HostName 'utat022' -OutputPath $snapshotPath } |
      Should -Throw '*surface coverage is inadequate*'

    Test-Path -LiteralPath $snapshotPath | Should -BeTrue
    $snapshot = Get-Content -LiteralPath $snapshotPath -Raw | ConvertFrom-Json
    $findings = @($snapshot.Surfaces | Where-Object Category -eq 'AuditCoverageFinding')
    $findings | Should -HaveCount 2
    @($findings | Where-Object Item -eq 'SQL' | Where-Object Value -Like 'Missing;*') | Should -HaveCount 1
    @($findings | Where-Object Item -eq 'PackageManager' | Where-Object Value -Like 'Missing;*') | Should -HaveCount 1
  }

  It 'Invoke-ParityAudit honors configurable minimums and preserves a thin finding' {
    $snapshotPath = Join-Path $leftState 'ParityAudit.utat022.thin-coverage.fixture.json'
    $moduleName = 'ATAP.Utilities.SystemParityMonitor.PowerShell'
    Mock -CommandName Get-SqlParitySurfaces -ModuleName $moduleName -MockWith {
      [pscustomobject]@{ Category = 'SQL'; Item = 'InstanceNames'; Value = 'PRODUCTION'; Source = 'fixture' }
    }
    Mock -CommandName Get-PackageManagerParitySurfaces -ModuleName $moduleName -MockWith {
      [pscustomobject]@{ Category = 'PackageManager'; Item = 'Machine/Chocolatey/git'; Value = '2.46'; Source = 'fixture' }
    }

    { Invoke-ParityAudit `
        -StatePath $leftState `
        -HostName 'utat022' `
        -OutputPath $snapshotPath `
        -ExpectedSurfaceMinimumCounts @{ SQL = 2; PackageManager = 1 } } |
      Should -Throw '*SQL=Thin;ActualCount=1;ExpectedMinimumCount=2*'

    $snapshot = Get-Content -LiteralPath $snapshotPath -Raw | ConvertFrom-Json
    $finding = @($snapshot.Surfaces | Where-Object Category -eq 'AuditCoverageFinding')
    $finding | Should -HaveCount 1
    $finding[0].Value | Should -Be 'Thin;ActualCount=1;ExpectedMinimumCount=2'
  }

  It 'surfaces package-manager conflicts in the drift report even when both hosts share the conflict' {
    $leftSnapshotPath = Join-Path $leftState 'ParityAudit.utat022.package-conflict.fixture.json'
    $rightSnapshotPath = Join-Path $rightState 'ParityAudit.utat01.package-conflict.fixture.json'
    $reportPath = Join-Path $leftState 'DriftReport.package-conflict.fixture.md'
    $nowUtc = (Get-Date).ToUniversalTime().ToString('o')

    [pscustomobject]@{
      SchemaVersion = 1
      HostName = 'utat022'
      CapturedAtUtc = $nowUtc
      Surfaces = @(
        [pscustomobject]@{ Category = 'PackageManagerConflict'; Item = 'utat022/requests'; Value = 'ACTION REQUIRED: resolve package ownership conflict (Chocolatey:requests@1.0; pip:requests@2.0)' }
      )
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $leftSnapshotPath -Encoding utf8

    [pscustomobject]@{
      SchemaVersion = 1
      HostName = 'utat01'
      CapturedAtUtc = $nowUtc
      Surfaces = @(
        [pscustomobject]@{ Category = 'PackageManagerConflict'; Item = 'utat01/requests'; Value = 'ACTION REQUIRED: resolve package ownership conflict (Chocolatey:requests@1.0; pip:requests@2.0)' }
      )
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $rightSnapshotPath -Encoding utf8

    $comparison = Compare-ParityAudits `
      -LeftStatePath $leftState `
      -RightStatePath $rightState `
      -LeftHostName 'utat022' `
      -RightHostName 'utat01' `
      -LeftSnapshotPath $leftSnapshotPath `
      -RightSnapshotPath $rightSnapshotPath `
      -ReportPath $reportPath

    @($comparison.UndeclaredDrift) | Should -HaveCount 2
    (Get-Content -LiteralPath $reportPath -Raw) | Should -Match 'ACTION REQUIRED: resolve package ownership conflict'
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

  It 'Compare-ParityAudits preserves deserialized UTC DateTime offsets when calculating freshness' {
    $leftSnapshotPath = Join-Path $leftState 'ParityAudit.utat022.fixture.json'
    $rightSnapshotPath = Join-Path $rightState 'ParityAudit.utat01.fixture.json'
    $reportPath = Join-Path $leftState 'DriftReport.utc.fixture.md'
    $nowUtc = (Get-Date).ToUniversalTime()

    [pscustomobject]@{
      SchemaVersion = 1
      HostName = 'utat022'
      CapturedAtUtc = $nowUtc.AddMinutes(-15)
      Surfaces = @(
        [pscustomobject] @{ Category = 'OS'; Item = 'Version'; Value = 'Windows 11' }
      )
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $leftSnapshotPath -Encoding utf8

    [pscustomobject]@{
      SchemaVersion = 1
      HostName = 'utat01'
      CapturedAtUtc = $nowUtc.AddMinutes(-10)
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

    @($comparison.SnapshotFreshness).Count | Should -Be 2
    foreach ($freshness in $comparison.SnapshotFreshness) {
      $freshness.Age | Should -BeGreaterOrEqual ([TimeSpan]::Zero)
      $freshness.IsStale | Should -BeFalse
    }
  }

  It 'Compare-ParityAudits treats a missing whitelist as an empty whitelist' {
    $leftSnapshotPath = Join-Path $leftState 'ParityAudit.utat022.fixture.json'
    $rightSnapshotPath = Join-Path $rightState 'ParityAudit.utat01.fixture.json'
    $reportPath = Join-Path $leftState 'DriftReport.no-whitelist.fixture.md'
    $nowUtc = (Get-Date).ToUniversalTime().ToString('o')

    [pscustomobject]@{
      SchemaVersion = 1
      HostName = 'utat022'
      CapturedAtUtc = $nowUtc
      Surfaces = @(
        [pscustomobject] @{ Category = 'OS'; Item = 'Version'; Value = 'Windows 11' }
      )
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $leftSnapshotPath -Encoding utf8

    [pscustomobject]@{
      SchemaVersion = 1
      HostName = 'utat01'
      CapturedAtUtc = $nowUtc
      Surfaces = @(
        [pscustomobject] @{ Category = 'OS'; Item = 'Version'; Value = 'Windows 10' }
      )
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $rightSnapshotPath -Encoding utf8

    $comparison = Compare-ParityAudits `
      -LeftStatePath $leftState `
      -RightStatePath $rightState `
      -LeftHostName 'utat022' `
      -RightHostName 'utat01' `
      -LeftSnapshotPath $leftSnapshotPath `
      -RightSnapshotPath $rightSnapshotPath `
      -ReportPath $reportPath

    @($comparison.WhitelistedDrift) | Should -HaveCount 0
    @($comparison.UndeclaredDrift) | Should -HaveCount 1
  }

  It 'Compare-ParityAudits distinguishes wholly missing and thin expected categories' {
    $leftSnapshotPath = Join-Path $leftState 'ParityAudit.utat022.coverage.fixture.json'
    $rightSnapshotPath = Join-Path $rightState 'ParityAudit.utat01.coverage.fixture.json'
    $reportPath = Join-Path $leftState 'DriftReport.coverage.fixture.md'
    $nowUtc = (Get-Date).ToUniversalTime().ToString('o')

    [pscustomobject]@{
      SchemaVersion = 1
      HostName = 'utat022'
      CapturedAtUtc = $nowUtc
      Surfaces = @(
        [pscustomobject]@{ Category = 'Services'; Item = 'W32Time'; Value = 'Running' }
      )
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $leftSnapshotPath -Encoding utf8

    [pscustomobject]@{
      SchemaVersion = 1
      HostName = 'utat01'
      CapturedAtUtc = $nowUtc
      Surfaces = @(
        [pscustomobject]@{ Category = 'PackageManagerStatus'; Item = 'Machine/Chocolatey'; Value = 'Available;PackageCount=1' },
        [pscustomobject]@{ Category = 'PackageManagerStatus'; Item = 'ATAP\Developer/pip'; Value = 'Available;PackageCount=1' }
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
      -ExpectedSurfaceMinimumCounts @{ Services = 3; PackageManagerStatus = 4 }

    $comparison.HasSurfaceCoverageFailure | Should -BeTrue
    @($comparison.SurfaceCoverageFailures | Where-Object Classification -eq 'Missing') | Should -HaveCount 2
    @($comparison.SurfaceCoverageFailures | Where-Object Classification -eq 'Thin') | Should -HaveCount 2
    (Get-Content -LiteralPath $reportPath -Raw) | Should -Match 'Surface Coverage Failures'
    (Get-Content -LiteralPath $reportPath -Raw) | Should -Match 'utat022/Services: Thin'
    (Get-Content -LiteralPath $reportPath -Raw) | Should -Match 'utat01/Services: Missing'
  }

  It 'Invoke-ParityAudit falls back to Win32_Share when Get-SmbShare is unavailable' {
    $snapshotPath = Join-Path $leftState 'ParityAudit.utat022.win32-share.fixture.json'
    $moduleName = 'ATAP.Utilities.SystemParityMonitor.PowerShell'
    Mock -CommandName Get-SqlParitySurfaces -ModuleName $moduleName -MockWith {
      [pscustomobject]@{ Category = 'SQL'; Item = 'InstanceNames'; Value = 'PRODUCTION'; Source = 'fixture' }
    }
    Mock -CommandName Get-PackageManagerParitySurfaces -ModuleName $moduleName -MockWith {
      [pscustomobject]@{ Category = 'PackageManager'; Item = 'Machine/Chocolatey/git'; Value = '2.46'; Source = 'fixture' }
    }

    Mock -CommandName Get-Command -ModuleName $moduleName -ParameterFilter { $Name -eq 'Get-SmbShare' } -MockWith {
      $null
    }
    Mock -CommandName Get-CimInstance -ModuleName $moduleName -MockWith {
      param($ClassName)
      if ($ClassName -eq 'Win32_OperatingSystem') {
        [pscustomobject]@{ Caption = 'Windows 10'; Version = '10.0'; BuildNumber = '19045' }
      } elseif ($ClassName -eq 'Win32_Share') {
        @(
          [pscustomobject]@{ Name = 'ParityState' },
          [pscustomobject]@{ Name = 'Public' }
        )
      }
    }

    $snapshot = Invoke-ParityAudit -StatePath $leftState -HostName 'utat022' -OutputPath $snapshotPath
    $shares = $snapshot.Surfaces | Where-Object { $_.Category -eq 'Shares' -and $_.Item -eq 'SmbShareNames' }

    $shares.Source | Should -Be 'Win32_Share'
    $shares.Value | Should -Be 'ParityState;Public'
  }
}

Describe 'ATAP.Utilities.SystemParityMonitor.PowerShell scheduled task scripts' -Tag 'Unit' {
  BeforeAll {
    $moduleRoot = (Get-Module -Name 'ATAP.Utilities.SystemParityMonitor.PowerShell').ModuleBase
    if (-not $moduleRoot) {
      throw 'ATAP.Utilities.SystemParityMonitor.PowerShell must be imported before scheduled-task tests run.'
    }
    $scriptsRoot = Join-Path $moduleRoot 'scripts'
    $registerScriptPath = Join-Path $scriptsRoot 'Register-ParityScheduledTasks.ps1'
    $commonScriptPath = Join-Path $scriptsRoot 'ParityScheduledTask.Common.ps1'
    . $registerScriptPath
    . $commonScriptPath
  }

  BeforeEach {
    $script:scheduledTaskRegistrations = @()
    $script:s4uRegistrations = @()

    Mock -CommandName Get-Command -ParameterFilter { $Name -eq 'pwsh' } -MockWith {
      [pscustomobject]@{ Source = 'C:\Program Files\PowerShell\7\pwsh.exe' }
    }

    Mock -CommandName Register-ScheduledTask -MockWith {
      param($TaskName, $TaskPath, $Action, $Trigger, $Settings, $Principal, $InputObject, $User, $Password, [switch] $Force, $ErrorAction)
      $script:scheduledTaskRegistrations += [pscustomobject]@{
        TaskName = $TaskName
        TaskPath = $TaskPath
        Action = $Action
        Trigger = $Trigger
        Settings = $Settings
        Principal = $Principal
        InputObject = $InputObject
        User = $User
        Password = $Password
        Force = $Force.IsPresent
        ErrorAction = $ErrorAction
      }
    }

    Mock -CommandName Register-ParityScheduledTaskS4U -MockWith {
      param($TaskName, $TaskPath, $PwshPath, $Arguments, $Cadence, $At, $BiWeeklyDaysOfWeek, $UserId, $Credential, $RunLevel)
      $script:s4uRegistrations += [pscustomobject]@{
        TaskName = $TaskName
        TaskPath = $TaskPath
        PwshPath = $PwshPath
        Arguments = $Arguments
        Cadence = $Cadence
        At = $At
        BiWeeklyDaysOfWeek = $BiWeeklyDaysOfWeek
        UserId = $UserId
        Credential = $Credential
        RunLevel = $RunLevel
      }
    }
  }

  It 'Register-ParityScheduledTasks creates only the local audit task for AuditOnly' {
    Register-ParityScheduledTasks `
      -TaskSet AuditOnly `
      -StatePath 'C:\ProgramData\ATAP\ParityState' `
      -HostName 'utat01' `
      -TaskPath '\ATAP-Test\' `
      -UserId 'UTAT01\SvcParityAudit' `
      -Confirm:$false

    $script:scheduledTaskRegistrations | Should -HaveCount 1
    $script:scheduledTaskRegistrations[0].TaskName | Should -Be 'ATAP-ParityAudit'
    $script:scheduledTaskRegistrations[0].Principal.UserId | Should -Be 'UTAT01\SvcParityAudit'
    $script:scheduledTaskRegistrations[0].Principal.LogonType | Should -Be 'S4U'
    $script:scheduledTaskRegistrations[0].Principal.RunLevel | Should -Be 'Limited'
    $script:scheduledTaskRegistrations[0].ErrorAction | Should -Be 'Stop'
    $script:scheduledTaskRegistrations[0].Action.Arguments | Should -Match 'Invoke-ParityScheduledAuditTask\.ps1'
    $script:scheduledTaskRegistrations[0].Action.Arguments |
      Should -Not -Match 'TokenPurpose|CredentialDirectory|Get-BWSAccessToken|\bbws\b|Invoke-Command'
    $script:scheduledTaskRegistrations[0].Settings.DisallowStartIfOnBatteries | Should -BeFalse
    $script:scheduledTaskRegistrations[0].Settings.StopIfGoingOnBatteries | Should -BeFalse
    $script:scheduledTaskRegistrations[0].Settings.StartWhenAvailable | Should -BeTrue
  }

  It 'Register-ParityScheduledTasks creates weekly biweekly audit and compare tasks for the primary task set' {
    Register-ParityScheduledTasks `
      -TaskSet AuditAndCompare `
      -Cadence BiWeekly `
      -BiWeeklyDaysOfWeek Wednesday `
      -StatePath 'C:\ProgramData\ATAP\ParityState' `
      -RightStatePath '\\utat01\ParityState' `
      -HostName 'utat022' `
      -RightHostName 'utat01' `
      -TaskPath '\ATAP-Test\' `
      -UserId 'UTAT022\SvcParityAudit' `
      -Confirm:$false

    $script:scheduledTaskRegistrations | Should -HaveCount 2
    @($script:scheduledTaskRegistrations.TaskName) | Should -Contain 'ATAP-ParityAudit'
    @($script:scheduledTaskRegistrations.TaskName) | Should -Contain 'ATAP-ParityCompare'
    foreach ($registration in $script:scheduledTaskRegistrations) {
      $registration.Trigger.CimClass.CimClassName | Should -Be 'MSFT_TaskWeeklyTrigger'
      $registration.Trigger.WeeksInterval | Should -Be 2
      $registration.Trigger.DaysOfWeek | Should -Be 8
      $registration.Principal.UserId | Should -Be 'UTAT022\SvcParityAudit'
      $registration.Principal.RunLevel | Should -Be 'Highest'
      $registration.ErrorAction | Should -Be 'Stop'
    }

    $compareRegistration = $script:scheduledTaskRegistrations |
      Where-Object TaskName -eq 'ATAP-ParityCompare' |
      Select-Object -First 1
    $compareRegistration.Action.Arguments | Should -Match '-ExpectedCadenceDays 14'
    $compareRegistration.Action.Arguments | Should -Match '-StaleMultiplier 1.5'
    $compareRegistration.Action.Arguments | Should -Match '-RightStatePath "\\\\utat01\\ParityState"'
    foreach ($registration in $script:scheduledTaskRegistrations) {
      $registration.Action.Arguments |
        Should -Not -Match 'TokenPurpose|CredentialDirectory|Get-BWSAccessToken|\bbws\b'
    }
  }

  It 'Register-ParityScheduledTasks supports Password logon registration for peer-share access' {
    $credential = [pscredential]::new(
      'UTAT022\SvcParityAudit',
      (ConvertTo-SecureString 'not-a-real-password' -AsPlainText -Force)
    )

    Register-ParityScheduledTasks `
      -TaskSet AuditAndCompare `
      -StatePath 'C:\ProgramData\ATAP\ParityState' `
      -RightStatePath '\\utat01\ParityState' `
      -HostName 'utat022' `
      -RightHostName 'utat01' `
      -TaskPath '\ATAP-Test\' `
      -UserId 'UTAT022\SvcParityAudit' `
      -LogonType Password `
      -Credential $credential `
      -Confirm:$false

    $script:scheduledTaskRegistrations | Should -HaveCount 2
    foreach ($registration in $script:scheduledTaskRegistrations) {
      $registration.InputObject | Should -Not -BeNullOrEmpty
      $registration.User | Should -Be 'UTAT022\SvcParityAudit'
      $registration.Password | Should -Be 'not-a-real-password'
      $registration.Action | Should -BeNullOrEmpty
      $registration.InputObject.Principal.RunLevel | Should -Be 'Highest'
      $registration.ErrorAction | Should -Be 'Stop'
    }
  }

  It 'Register-ParityScheduledTasks supplies a credential for S4U registration without changing the S4U principal' {
    $credential = [pscredential]::new(
      'UTAT01\SvcParityAudit',
      (ConvertTo-SecureString 'not-a-real-password' -AsPlainText -Force)
    )

    Register-ParityScheduledTasks `
      -TaskSet AuditOnly `
      -StatePath 'C:\ProgramData\ATAP\ParityState' `
      -HostName 'utat01' `
      -TaskPath '\ATAP-Test\' `
      -LogonType S4U `
      -Credential $credential `
      -Confirm:$false

    $script:scheduledTaskRegistrations | Should -HaveCount 0
    $script:s4uRegistrations | Should -HaveCount 1
    $registration = $script:s4uRegistrations[0]
    $registration.TaskName | Should -Be 'ATAP-ParityAudit'
    $registration.UserId | Should -Be 'UTAT01\SvcParityAudit'
    $registration.Credential.UserName | Should -Be 'UTAT01\SvcParityAudit'
    $registration.Credential.GetNetworkCredential().Password | Should -Be 'not-a-real-password'
    $registration.RunLevel | Should -Be 'Limited'
    $registration.Arguments | Should -Match 'Invoke-ParityScheduledAuditTask\.ps1'
  }

  It 'scheduled task wrappers require no vault command token or credential directory' {
    $auditSource = Get-Content -LiteralPath (Join-Path $scriptsRoot 'Invoke-ParityScheduledAuditTask.ps1') -Raw
    $compareSource = Get-Content -LiteralPath (Join-Path $scriptsRoot 'Invoke-ParityScheduledCompareTask.ps1') -Raw
    $commonSource = Get-Content -LiteralPath (Join-Path $scriptsRoot 'ParityScheduledTask.Common.ps1') -Raw
    $registrationSource = Get-Content -LiteralPath (Join-Path $scriptsRoot 'Register-ParityScheduledTasks.ps1') -Raw
    $executionSource = $auditSource + $compareSource + $commonSource

    $executionSource |
      Should -Not -Match 'Get-BWSAccessToken|Invoke-ParityScheduledTaskBwsProbe|\bbws\b|BWS_ACCESS_TOKEN|_BWS_AccessToken\.xml'
    $executionSource | Should -Not -Match 'CredentialDirectory|TokenPurpose|Invoke-Command|BW_SESSION|bw login|bw unlock'
    $auditSource | Should -Match 'SecretAccessRequired\s*=\s*\$false'
    $compareSource | Should -Match 'SecretAccessRequired\s*=\s*\$false'
    $registrationSource | Should -Not -Match '\[string\]\s+\$CredentialDirectory|\[string\]\s+\$TokenPurpose'
  }

  It 'scheduled task wrappers parse successfully' {
    foreach ($scriptName in @(
      'Invoke-ParityScheduledAuditTask.ps1',
      'Invoke-ParityScheduledCompareTask.ps1',
      'Invoke-ParityTaskAndWait.ps1'
    )) {
      $tokens = $null
      $errors = $null
      [System.Management.Automation.Language.Parser]::ParseFile(
        (Join-Path $scriptsRoot $scriptName),
        [ref] $tokens,
        [ref] $errors
      ) | Out-Null

      $errors | Should -BeNullOrEmpty
    }
  }
}
