Describe 'Task 15.167 shared .NET tool parity contract' -Tag 'Unit' {
  BeforeAll {
    $modulePath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'ATAP.Utilities.SystemParityMonitor.PowerShell.psd1'
    Import-Module -Name $modulePath -Force
  }

  It 'collects the exact shared version and verifies the current logical identity' {
    $sharedPath = Join-Path $TestDrive 'shared-tools'
    New-Item -ItemType Directory -Path (Join-Path $sharedPath '.store\dotnet-trace\10.0.731102') -Force | Out-Null
    New-Item -ItemType File -Path (Join-Path $sharedPath 'dotnet-trace.exe') -Force | Out-Null
    $policy = [pscustomobject]@{
      SchemaVersion = 1
      SharedPath = $sharedPath
      EvidenceMaxAgeHours = 24
      Tools = @([pscustomobject]@{ PackageId = 'dotnet-trace'; CommandName = 'dotnet-trace.exe'; ExpectedVersion = '10.0.731102' })
      Consumers = @([pscustomobject]@{ LogicalIdentity = 'ParityAudit'; ActualIdentity = 'UTAT022\SvcParityAudit'; EvidenceMode = 'CurrentProcess' })
    }

    InModuleScope ATAP.Utilities.SystemParityMonitor.PowerShell -Parameters @{ Policy = $policy; SharedPath = $sharedPath } {
      Mock Invoke-ParityNativeCommand {
        param($Command, $ArgumentList)
        if ($ArgumentList -contains '--version') { return [pscustomobject]@{ ExitCode = 0; Output = @('10.0.731102+fixture') } }
        [pscustomobject]@{ ExitCode = 0; Output = @('help') }
      }
      $surfaces = @(Get-SharedDotNetToolParitySurfaces -HostName utat022 -StatePath $TestDrive -Policy $Policy -CurrentIdentityName 'UTAT022\SvcParityAudit')
      ($surfaces | Where-Object Category -eq 'SharedDotNetTool').Value |
        Should -Be 'Available;Version=10.0.731102;Path=<shared>'
      ($surfaces | Where-Object Category -eq 'SharedDotNetToolConsumer').Value |
        Should -Be 'Verified;Version=10.0.731102;Path=<shared>'
    }
  }

  It 'reports a user-scoped-only installation as actionable audit error' {
    $sharedPath = Join-Path $TestDrive 'shared-empty'
    $userPath = Join-Path $TestDrive 'user-tools'
    New-Item -ItemType Directory -Path $sharedPath -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $userPath '.store\dotnet-trace\10.0.731102') -Force | Out-Null
    $policy = [pscustomobject]@{
      SchemaVersion = 1
      SharedPath = $sharedPath
      Tools = @([pscustomobject]@{ PackageId = 'dotnet-trace'; CommandName = 'dotnet-trace.exe'; ExpectedVersion = '10.0.731102' })
      Consumers = @([pscustomobject]@{ LogicalIdentity = 'ParityAudit'; ActualIdentity = 'UTAT022\SvcParityAudit'; EvidenceMode = 'CurrentProcess' })
    }

    InModuleScope ATAP.Utilities.SystemParityMonitor.PowerShell -Parameters @{ Policy = $policy; UserPath = $userPath } {
      $surfaces = @(Get-SharedDotNetToolParitySurfaces -HostName utat022 -StatePath $TestDrive -Policy $Policy -PackageManagerProfiles @([pscustomobject]@{ Identity = 'UTAT022\whertzing'; NuGetToolPath = $UserPath }) -CurrentIdentityName 'UTAT022\SvcParityAudit')
      ($surfaces | Where-Object Category -eq 'SharedDotNetTool').Value | Should -Match '^AuditError=UserScopedOnly'
    }
  }

  It 'rejects stale and wrong-identity consumer evidence instead of treating a label as impersonation' {
    $sharedPath = Join-Path $TestDrive 'shared-evidence'
    $evidencePath = Join-Path $TestDrive 'consumer.json'
    New-Item -ItemType Directory -Path (Join-Path $sharedPath '.store\dotnet-trace\10.0.731102') -Force | Out-Null
    New-Item -ItemType File -Path (Join-Path $sharedPath 'dotnet-trace.exe') -Force | Out-Null
    [pscustomobject]@{
      SchemaVersion = 1
      HostName = 'utat022'
      LogicalIdentity = 'BuildMaster'
      ActualIdentity = 'UTAT022\Administrator'
      CapturedAtUtc = (Get-Date).ToUniversalTime().AddDays(-2).ToString('o')
      Tools = @()
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $evidencePath -Encoding utf8
    $policy = [pscustomobject]@{
      SchemaVersion = 1
      SharedPath = $sharedPath
      EvidenceMaxAgeHours = 24
      Tools = @([pscustomobject]@{ PackageId = 'dotnet-trace'; CommandName = 'dotnet-trace.exe'; ExpectedVersion = '10.0.731102' })
      Consumers = @([pscustomobject]@{ LogicalIdentity = 'BuildMaster'; ActualIdentity = 'UTAT022\SvcBuildmaster'; EvidenceMode = 'EvidenceFile'; EvidencePath = $evidencePath })
    }

    InModuleScope ATAP.Utilities.SystemParityMonitor.PowerShell -Parameters @{ Policy = $policy } {
      Mock Invoke-ParityNativeCommand {
        param($Command, $ArgumentList)
        [pscustomobject]@{ ExitCode = 0; Output = if ($ArgumentList -contains '--version') { @('10.0.731102') } else { @('help') } }
      }
      $surfaces = @(Get-SharedDotNetToolParitySurfaces -HostName utat022 -StatePath $TestDrive -Policy $Policy -CurrentIdentityName 'UTAT022\SvcParityAudit')
      ($surfaces | Where-Object Category -eq 'SharedDotNetToolConsumer').Value | Should -Be 'AuditError=WrongIdentity'
    }
  }

  It 'requires exact Task 15.167 journals and Verified peer acknowledgements' {
    $leftPath = Join-Path $TestDrive 'left'
    $rightPath = Join-Path $TestDrive 'right'
    New-Item -ItemType Directory -Path $leftPath, $rightPath -Force | Out-Null
    $entryId = [guid]::NewGuid().ToString()
    [pscustomobject]@{
      Id = $entryId
      SourceHostName = 'utat022'
      PeerHostName = 'utat01'
      Category = 'Packages'
      Item = 'dotnet-trace/shared'
    } | ConvertTo-Json -Compress | Set-Content -LiteralPath (Join-Path $leftPath 'ChangeJournal.utat022.jsonl') -Encoding utf8
    [pscustomobject]@{
      JournalEntryId = $entryId
      AckHostName = 'utat01'
      JournalHostName = 'utat022'
      Status = 'Applied'
      RecordedAtUtc = '2026-09-09T00:00:00Z'
    } | ConvertTo-Json -Compress | Set-Content -LiteralPath (Join-Path $rightPath 'ChangeAck.utat01.jsonl') -Encoding utf8
    $required = @([pscustomobject]@{
        LogicalChangeId = 'utat022-dotnet-trace-shared'
        EntryId = $entryId
        JournalHostName = 'utat022'
        AckHostName = 'utat01'
        Category = 'Packages'
        Item = 'dotnet-trace/shared'
        MinimumAckStatus = 'Verified'
      })

    InModuleScope ATAP.Utilities.SystemParityMonitor.PowerShell -Parameters @{ Required = $required; LeftPath = $leftPath; RightPath = $rightPath } {
      $findings = @(Get-ParityRequiredChangeEvidenceFindings -RequiredChanges $Required -LeftStatePath $LeftPath -RightStatePath $RightPath -LeftHostName utat022 -RightHostName utat01)
      $findings | Should -HaveCount 1
      $findings[0].Classification | Should -Be 'AcknowledgementInsufficient'
      $findings[0].Actual | Should -Be 'Applied'
    }
  }

  It 'surfaces insufficient Task 15.167 acknowledgements through the public comparison result and report' {
    $leftPath = Join-Path $TestDrive 'compare-left'
    $rightPath = Join-Path $TestDrive 'compare-right'
    $reportPath = Join-Path $leftPath 'DriftReport.fixture.md'
    New-Item -ItemType Directory -Path $leftPath, $rightPath -Force | Out-Null
    $capturedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    $leftSnapshotPath = Join-Path $leftPath 'ParityAudit.utat022.fixture.json'
    $rightSnapshotPath = Join-Path $rightPath 'ParityAudit.utat01.fixture.json'
    foreach ($snapshot in @(
        [pscustomobject]@{ Path = $leftSnapshotPath; HostName = 'utat022' },
        [pscustomobject]@{ Path = $rightSnapshotPath; HostName = 'utat01' }
      )) {
      [pscustomobject]@{
        SchemaVersion = 1
        HostName = $snapshot.HostName
        CapturedAtUtc = $capturedAtUtc
        Surfaces = @([pscustomobject]@{ Category = 'OS'; Item = 'Version'; Value = 'fixture' })
      } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $snapshot.Path -Encoding utf8
    }

    $entryId = [guid]::NewGuid().ToString()
    [pscustomobject]@{
      Id = $entryId
      SourceHostName = 'utat022'
      PeerHostName = 'utat01'
      Category = 'Packages'
      Item = 'dotnet-trace/shared'
    } | ConvertTo-Json -Compress | Set-Content -LiteralPath (Join-Path $leftPath 'ChangeJournal.utat022.jsonl') -Encoding utf8
    [pscustomobject]@{
      JournalEntryId = $entryId
      AckHostName = 'utat01'
      JournalHostName = 'utat022'
      Status = 'Applied'
      RecordedAtUtc = $capturedAtUtc
    } | ConvertTo-Json -Compress | Set-Content -LiteralPath (Join-Path $rightPath 'ChangeAck.utat01.jsonl') -Encoding utf8
    $policy = [pscustomobject]@{
      RequiredChanges = @([pscustomobject]@{
          LogicalChangeId = 'utat022-dotnet-trace-shared'
          EntryId = $entryId
          JournalHostName = 'utat022'
          AckHostName = 'utat01'
          Category = 'Packages'
          Item = 'dotnet-trace/shared'
          MinimumAckStatus = 'Verified'
        })
    }
    $comparisonParameters = @{
      LeftStatePath = $leftPath
      RightStatePath = $rightPath
      LeftHostName = 'utat022'
      RightHostName = 'utat01'
      LeftSnapshotPath = $leftSnapshotPath
      RightSnapshotPath = $rightSnapshotPath
      ReportPath = $reportPath
      SharedDotNetToolPolicy = $policy
      ExpectedSurfaceMinimumCounts = @{ OS = 1 }
    }

    $comparison = Compare-ParityAudits @comparisonParameters

    $comparison.HasRequiredChangeEvidenceFailure | Should -BeTrue
    @($comparison.RequiredChangeEvidenceFailures) | Should -HaveCount 1
    $comparison.RequiredChangeEvidenceFailures[0].Classification | Should -Be 'AcknowledgementInsufficient'
    (Get-Content -LiteralPath $reportPath -Raw) | Should -Match 'Required Change Evidence Failures'
  }

  It 'exports an evidence probe and refuses to write for the wrong current identity' {
    Get-Command -Module ATAP.Utilities.SystemParityMonitor.PowerShell -Name Invoke-SharedDotNetToolConsumerProbe |
      Should -Not -BeNullOrEmpty
    $policy = [pscustomobject]@{
      SchemaVersion = 1
      SharedPath = 'C:\ProgramData\dotnet\tools'
      Tools = @([pscustomobject]@{ PackageId = 'dotnet-trace'; CommandName = 'dotnet-trace.exe'; ExpectedVersion = '10.0.731102' })
      Consumers = @([pscustomobject]@{ LogicalIdentity = 'BuildMaster'; ActualIdentity = 'SOMEOTHERHOST\NoSuchIdentity'; EvidenceMode = 'EvidenceFile'; EvidencePath = (Join-Path $TestDrive 'should-not-exist.json') })
    }
    { Invoke-SharedDotNetToolConsumerProbe -Policy $policy -LogicalIdentity BuildMaster -Confirm:$false } |
      Should -Throw '*does not match configured identity*'
    Test-Path -LiteralPath $policy.Consumers[0].EvidencePath | Should -BeFalse
  }
}

Describe 'Task 15.167 scheduled required-change alerting' -Tag 'Unit' {
  BeforeAll {
    $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $scriptsRoot = Join-Path $moduleRoot 'scripts'
    . (Join-Path $scriptsRoot 'ParityScheduledTask.Common.ps1')
    . (Join-Path $scriptsRoot 'Invoke-ParityScheduledCompareTask.ps1')
  }

  It 'emits an immediate actionable warning when required rollout evidence is insufficient' {
    $statePath = Join-Path $TestDrive 'scheduled-state'
    $resultPath = Join-Path $TestDrive 'scheduled-results'
    New-Item -ItemType Directory -Path $statePath, $resultPath -Force | Out-Null
    Mock -CommandName Import-Module
    Mock -CommandName Compare-ParityAudits -MockWith {
      [pscustomobject]@{
        ReportPath = 'C:\ProgramData\ATAP\ParityState\DriftReport.md'
        UndeclaredDrift = @()
        DeclaredDrift = @()
        WhitelistedDrift = @()
        StaleSnapshots = @()
        HasSurfaceCoverageFailure = $false
        SurfaceCoverageFailures = @()
        HasRequiredChangeEvidenceFailure = $true
        RequiredChangeEvidenceFailures = @(
          [pscustomobject]@{ Classification = 'AcknowledgementInsufficient' }
        )
      }
    }
    Mock -CommandName Write-ParityScheduledTaskEvent -MockWith {
      param($EntryType, $EventId, $Message, $LogName, $Source)
      [pscustomobject]@{
        Success = $true
        EntryType = $EntryType
        EventId = $EventId
        Message = $Message
        LogName = $LogName
        Source = $Source
        ErrorType = $null
      }
    }
    $parameters = @{
      LeftStatePath = $statePath
      RightStatePath = 'C:\peer'
      LeftHostName = 'utat022'
      RightHostName = 'utat01'
      ResultDirectory = $resultPath
    }

    Invoke-ParityScheduledCompareTask @parameters

    Should -Invoke -CommandName Write-ParityScheduledTaskEvent -Times 1 -ParameterFilter {
      $EventId -eq 12382 -and
      $EntryType -eq 'Warning' -and
      $Message -match 'Reason=RequiredChangeEvidenceFailure' -and
      $Message -match 'RequiredChangeEvidenceFailureCount=1'
    }
    $result = Get-ChildItem -LiteralPath $resultPath -Filter 'ParityCompareTaskResult.*.json' |
      Select-Object -First 1 | Get-Content -Raw | ConvertFrom-Json
    $result.AlertReason | Should -Be 'RequiredChangeEvidenceFailure'
    $result.RequiredChangeEvidenceFailureCount | Should -Be 1
  }
}
