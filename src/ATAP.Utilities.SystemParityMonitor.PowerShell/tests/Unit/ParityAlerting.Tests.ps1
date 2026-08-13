Describe 'SystemParityMonitor scheduled alerting' -Tag 'Unit' {
  BeforeAll {
    $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $scriptsRoot = Join-Path $moduleRoot 'scripts'
    . (Join-Path $scriptsRoot 'ParityScheduledTask.Common.ps1')
    . (Join-Path $scriptsRoot 'Invoke-ParityScheduledAuditTask.ps1')
    . (Join-Path $scriptsRoot 'Invoke-ParityScheduledCompareTask.ps1')
  }

  BeforeEach {
    $fixtureRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    $statePath = Join-Path $fixtureRoot 'ParityState'
    $resultPath = Join-Path $fixtureRoot 'TaskResults'
    New-Item -ItemType Directory -Path $statePath, $resultPath -Force | Out-Null

    Mock -CommandName Import-Module
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
  }

  It 'emits no event for the first thrown audit failure and emits on the second' {
    Mock -CommandName Invoke-ParityAudit -MockWith {
      throw [InvalidOperationException]::new('primary audit fixture failure')
    }

    { Invoke-ParityScheduledAuditTask -StatePath $statePath -HostName 'utat022' -ResultDirectory $resultPath } |
      Should -Throw '*primary audit fixture failure*'
    Should -Invoke -CommandName Write-ParityScheduledTaskEvent -Times 0

    { Invoke-ParityScheduledAuditTask -StatePath $statePath -HostName 'utat022' -ResultDirectory $resultPath } |
      Should -Throw '*primary audit fixture failure*'
    Should -Invoke -CommandName Write-ParityScheduledTaskEvent -ParameterFilter {
      $EventId -eq 12380 -and $EntryType -eq 'Error' -and
      $Message -notmatch 'fixture failure'
    } -Times 1

    $state = Read-ParityScheduledTaskFailureState -StatePath $statePath -TaskName 'ParityAudit'
    $state.ConsecutiveFailureCount | Should -Be 2
  }

  It 'resets the audit failure sequence after a genuine success' {
    Set-ParityScheduledTaskOutcome -StatePath $statePath -TaskName 'ParityAudit' -Succeeded $false | Out-Null
    Mock -CommandName Invoke-ParityAudit -MockWith {
      [pscustomobject]@{
        SnapshotPath = 'C:\ProgramData\ATAP\ParityState\snapshot.json'
        CapturedAtUtc = '2026-08-09T00:00:00Z'
      }
    }

    Invoke-ParityScheduledAuditTask -StatePath $statePath -HostName 'utat022' -ResultDirectory $resultPath

    $state = Read-ParityScheduledTaskFailureState -StatePath $statePath -TaskName 'ParityAudit'
    $state.ConsecutiveFailureCount | Should -Be 0
    Should -Invoke -CommandName Write-ParityScheduledTaskEvent -Times 0
    $result = Get-ChildItem -LiteralPath $resultPath -Filter 'ParityAuditTaskResult.*.json' |
      Select-Object -First 1 | Get-Content -Raw | ConvertFrom-Json
    $result.Success | Should -BeTrue
    $result.FailureState.ConsecutiveFailureCount | Should -Be 0
  }

  It 'recovers missing and corrupt state as a new failure sequence' {
    $missing = Set-ParityScheduledTaskOutcome -StatePath $statePath -TaskName 'ParityCompare' -Succeeded $false
    $missing.ConsecutiveFailureCount | Should -Be 1
    $missing.RecoveredFromCorruptState | Should -BeFalse

    $failureStatePath = Get-ParityScheduledTaskFailureStatePath -StatePath $statePath -TaskName 'ParityCompare'
    Set-Content -LiteralPath $failureStatePath -Value '{not-json' -Encoding utf8

    $recovered = Set-ParityScheduledTaskOutcome -StatePath $statePath -TaskName 'ParityCompare' -Succeeded $false
    $recovered.ConsecutiveFailureCount | Should -Be 1
    $recovered.RecoveredFromCorruptState | Should -BeTrue
    $recovered.RecoveryErrorType | Should -Not -BeNullOrEmpty
    (Read-ParityScheduledTaskFailureState -StatePath $statePath -TaskName 'ParityCompare').ConsecutiveFailureCount |
      Should -Be 1
  }

  It 'keeps audit and compare failure state in isolated files' {
    Set-ParityScheduledTaskOutcome -StatePath $statePath -TaskName 'ParityAudit' -Succeeded $false | Out-Null
    Set-ParityScheduledTaskOutcome -StatePath $statePath -TaskName 'ParityCompare' -Succeeded $false | Out-Null
    Set-ParityScheduledTaskOutcome -StatePath $statePath -TaskName 'ParityCompare' -Succeeded $false | Out-Null

    $auditPath = Get-ParityScheduledTaskFailureStatePath -StatePath $statePath -TaskName 'ParityAudit'
    $comparePath = Get-ParityScheduledTaskFailureStatePath -StatePath $statePath -TaskName 'ParityCompare'
    $auditPath | Should -Not -Be $comparePath
    $auditPath | Should -BeLike "$statePath*"
    $comparePath | Should -BeLike "$statePath*"
    (Read-ParityScheduledTaskFailureState -StatePath $statePath -TaskName 'ParityAudit').ConsecutiveFailureCount |
      Should -Be 1
    (Read-ParityScheduledTaskFailureState -StatePath $statePath -TaskName 'ParityCompare').ConsecutiveFailureCount |
      Should -Be 2
  }

  It 'emits an immediate warning for stale comparison snapshots' {
    Mock -CommandName Compare-ParityAudits -MockWith {
      [pscustomobject]@{
        ReportPath = 'C:\ProgramData\ATAP\ParityState\drift.md'
        UndeclaredDrift = @()
        DeclaredDrift = @()
        WhitelistedDrift = @()
        StaleSnapshots = @([pscustomobject]@{ HostName = 'utat01'; IsStale = $true })
        HasSurfaceCoverageFailure = $false
        SurfaceCoverageFailures = @()
      }
    }

    Invoke-ParityScheduledCompareTask -LeftStatePath $statePath -RightStatePath 'C:\peer' `
      -LeftHostName 'utat022' -RightHostName 'utat01' -ResultDirectory $resultPath

    Should -Invoke -CommandName Write-ParityScheduledTaskEvent -ParameterFilter {
      $EventId -eq 12382 -and $EntryType -eq 'Warning' -and
      $Message -match 'Reason=StaleSnapshot' -and
      $Message -notmatch [regex]::Escape('C:\ProgramData')
    } -Times 1
    $result = Get-ChildItem -LiteralPath $resultPath -Filter 'ParityCompareTaskResult.*.json' |
      Select-Object -First 1 | Get-Content -Raw | ConvertFrom-Json
    $result.AlertReason | Should -Be 'StaleSnapshot'
    $result.Success | Should -BeTrue
  }

  It 'emits an immediate warning for missing or thin comparison coverage' {
    Mock -CommandName Compare-ParityAudits -MockWith {
      [pscustomobject]@{
        ReportPath = 'C:\ProgramData\ATAP\ParityState\drift.md'
        UndeclaredDrift = @()
        DeclaredDrift = @()
        WhitelistedDrift = @()
        StaleSnapshots = @()
        HasSurfaceCoverageFailure = $true
        SurfaceCoverageFailures = @(
          [pscustomobject]@{ HostName = 'utat01'; Category = 'SQL'; Classification = 'Missing' }
        )
      }
    }

    Invoke-ParityScheduledCompareTask -LeftStatePath $statePath -RightStatePath 'C:\peer' `
      -LeftHostName 'utat022' -RightHostName 'utat01' -ResultDirectory $resultPath

    Should -Invoke -CommandName Write-ParityScheduledTaskEvent -ParameterFilter {
      $EventId -eq 12382 -and $Message -match 'Reason=SurfaceCoverageFailure' -and
      $Message -match 'SurfaceCoverageFailureCount=1'
    } -Times 1
  }

  It 'does not let event-write failure hide the primary compare failure' {
    Mock -CommandName Compare-ParityAudits -MockWith {
      throw [InvalidOperationException]::new('primary compare fixture failure')
    }
    Mock -CommandName Write-ParityScheduledTaskEvent -MockWith {
      [pscustomobject]@{
        Success = $false
        EventId = 12381
        ErrorType = 'System.UnauthorizedAccessException'
      }
    }

    { Invoke-ParityScheduledCompareTask -LeftStatePath $statePath -RightStatePath 'C:\peer' `
        -LeftHostName 'utat022' -RightHostName 'utat01' -ResultDirectory $resultPath } |
      Should -Throw '*primary compare fixture failure*'
    { Invoke-ParityScheduledCompareTask -LeftStatePath $statePath -RightStatePath 'C:\peer' `
        -LeftHostName 'utat022' -RightHostName 'utat01' -ResultDirectory $resultPath } |
      Should -Throw '*primary compare fixture failure*'

    Should -Invoke -CommandName Write-ParityScheduledTaskEvent -Times 1
    $latestResult = Get-ChildItem -LiteralPath $resultPath -Filter 'ParityCompareTaskResult.*.json' |
      Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1 |
      Get-Content -Raw | ConvertFrom-Json
    $latestResult.Success | Should -BeFalse
    $latestResult.ErrorType | Should -Be 'System.InvalidOperationException'
    $latestResult.EventLog.Success | Should -BeFalse
  }

  It 'retries failure notification after count two until one event write succeeds' {
    Mock -CommandName Invoke-ParityAudit -MockWith {
      throw [InvalidOperationException]::new('primary audit fixture failure')
    }
    $script:eventAttempt = 0
    Mock -CommandName Write-ParityScheduledTaskEvent -MockWith {
      $script:eventAttempt++
      [pscustomobject]@{
        Success = $script:eventAttempt -ge 2
        EventId = 12380
        ErrorType = if ($script:eventAttempt -ge 2) { $null } else { 'System.UnauthorizedAccessException' }
      }
    }

    1..4 | ForEach-Object {
      { Invoke-ParityScheduledAuditTask -StatePath $statePath -HostName 'utat022' -ResultDirectory $resultPath } |
        Should -Throw '*primary audit fixture failure*'
    }

    Should -Invoke -CommandName Write-ParityScheduledTaskEvent -Times 2
    $state = Read-ParityScheduledTaskFailureState -StatePath $statePath -TaskName 'ParityAudit'
    $state.ConsecutiveFailureCount | Should -Be 4
    $state.FailureNotificationSucceeded | Should -BeTrue
  }

  It 'preserves the old valid state and removes temporary files when the replacement write fails' {
    Set-ParityScheduledTaskOutcome -StatePath $statePath -TaskName 'ParityAudit' -Succeeded $false | Out-Null
    $stateFile = Get-ParityScheduledTaskFailureStatePath -StatePath $statePath -TaskName 'ParityAudit'
    $before = Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json
    Mock -CommandName Set-Content -ParameterFilter { $LiteralPath -like '*.tmp' } -MockWith {
      throw [IO.IOException]::new('simulated temporary write failure')
    }

    $write = Write-ParityScheduledTaskFailureState -StatePath $statePath -TaskName 'ParityAudit' `
      -ConsecutiveFailureCount 2

    $write.Success | Should -BeFalse
    (Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json).ConsecutiveFailureCount |
      Should -Be $before.ConsecutiveFailureCount
    @(Get-ChildItem -LiteralPath (Split-Path -Parent $stateFile) -File |
        Where-Object Extension -In '.tmp', '.bak') | Should -HaveCount 0
  }

  It 'does not turn a successful stale comparison into failure when its warning event cannot be written' {
    Mock -CommandName Compare-ParityAudits -MockWith {
      [pscustomobject]@{
        ReportPath = 'C:\ProgramData\ATAP\ParityState\drift.md'
        UndeclaredDrift = @()
        DeclaredDrift = @()
        WhitelistedDrift = @()
        StaleSnapshots = @([pscustomobject]@{ HostName = 'utat01'; IsStale = $true })
        HasSurfaceCoverageFailure = $false
        SurfaceCoverageFailures = @()
      }
    }
    Mock -CommandName Write-ParityScheduledTaskEvent -MockWith {
      [pscustomobject]@{
        Success = $false
        EventId = 12382
        ErrorType = 'System.UnauthorizedAccessException'
      }
    }

    { Invoke-ParityScheduledCompareTask -LeftStatePath $statePath -RightStatePath 'C:\peer' `
        -LeftHostName 'utat022' -RightHostName 'utat01' -ResultDirectory $resultPath } |
      Should -Not -Throw

    $result = Get-ChildItem -LiteralPath $resultPath -Filter 'ParityCompareTaskResult.*.json' |
      Select-Object -First 1 | Get-Content -Raw | ConvertFrom-Json
    $result.Success | Should -BeTrue
    $result.AlertReason | Should -Be 'StaleSnapshot'
    $result.EventLog.Success | Should -BeFalse
  }

  It 'keeps scheduled wrapper source token-free and remoting-free' {
    $source = @(
      Get-Content -LiteralPath (Join-Path $scriptsRoot 'ParityScheduledTask.Common.ps1') -Raw
      Get-Content -LiteralPath (Join-Path $scriptsRoot 'Invoke-ParityScheduledAuditTask.ps1') -Raw
      Get-Content -LiteralPath (Join-Path $scriptsRoot 'Invoke-ParityScheduledCompareTask.ps1') -Raw
    ) -join [Environment]::NewLine

    $source | Should -Not -Match 'Get-BWSAccessToken|BW_SESSION|CommonCIForBitwardenReadOnly|CredentialDirectory|Invoke-Command'
  }
}
