function Compare-ParityAudits {
<#
.SYNOPSIS
Compares two parity audit snapshots and writes a drift report.

.DESCRIPTION
Loads the newest or explicitly supplied JSON audit snapshots, filters accepted
divergences through ParityWhitelist.json, correlates remaining differences with
open journal entries, scans for conflicted-copy files, and emits an undeclared
drift report.

.PARAMETER LeftStatePath
ParityState path for the first host.

.PARAMETER RightStatePath
ParityState path for the peer host.

.PARAMETER LeftHostName
First host name.

.PARAMETER RightHostName
Peer host name.

.PARAMETER LeftSnapshotPath
Optional explicit snapshot path for the first host.

.PARAMETER RightSnapshotPath
Optional explicit snapshot path for the peer host.

.PARAMETER WhitelistPath
Optional ParityWhitelist.json path.

.PARAMETER ReportPath
Optional markdown report path.

.PARAMETER ExpectedCadence
Expected cadence between snapshot captures. When supplied, snapshots older than
ExpectedCadence multiplied by StaleMultiplier are flagged as stale.

.PARAMETER StaleMultiplier
Multiplier applied to ExpectedCadence to determine the stale threshold.

.PARAMETER ExpectedSurfaceMinimumCounts
Expected minimum row count by surface category. A category with no rows is
reported as Missing; a category below its minimum is reported as Thin. Any
collector surface whose value begins with AuditError, or whose item ends in
/AuditError, is reported as a coverage failure even when the category minimum is
satisfied.

.OUTPUTS
PSCustomObject.

.EXAMPLE
Compare-ParityAudits -LeftHostName utat022 -RightHostName utat01

.NOTES
Differences not whitelisted and not correlated to an open journal entry are
reported as undeclared drift for human escalation.
#>
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [string] $LeftStatePath = 'C:\ProgramData\ATAP\ParityState',

    [Parameter(Mandatory = $true)]
    [string] $RightStatePath,

    [string] $LeftHostName = $env:COMPUTERNAME,

    [Parameter(Mandatory = $true)]
    [string] $RightHostName,

    [string] $LeftSnapshotPath,

    [string] $RightSnapshotPath,

    [string] $WhitelistPath,

    [string] $ReportPath,

    [TimeSpan] $ExpectedCadence,

    [double] $StaleMultiplier = 1.5,

    [hashtable] $ExpectedSurfaceMinimumCounts = @{
      OS = 1
      PowerShell = 1
      Services = 3
      SQL = 1
      PackageManager = 1
      Shares = 1
      ParityState = 1
    }
  )

  begin {
    $fn = 'Compare-ParityAudits'
    $mn = 'ATAP.Utilities.SystemParityMonitor.PowerShell'
    Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Starting parity audit comparison.'
  }

  process {
    try {
      if (-not $LeftSnapshotPath) {
        $LeftSnapshotPath = (Get-ParityLatestAuditSnapshot -StatePath $LeftStatePath -HostName $LeftHostName).FullName
      }

      if (-not $RightSnapshotPath) {
        $RightSnapshotPath = (Get-ParityLatestAuditSnapshot -StatePath $RightStatePath -HostName $RightHostName).FullName
      }

      if (-not $LeftSnapshotPath -or -not $RightSnapshotPath) {
        throw 'Both parity audit snapshots must be available before comparison.'
      }

      if (-not $WhitelistPath) {
        $candidate = Join-Path $LeftStatePath 'ParityWhitelist.json'
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
          $WhitelistPath = $candidate
        }
      }

      $leftSnapshot = Read-ParityJsonFile -Path $LeftSnapshotPath
      $rightSnapshot = Read-ParityJsonFile -Path $RightSnapshotPath
      if ($null -eq $ExpectedSurfaceMinimumCounts) {
        throw 'ExpectedSurfaceMinimumCounts cannot be null.'
      }
      if ($ExpectedSurfaceMinimumCounts.Count -eq 0) {
        throw 'ExpectedSurfaceMinimumCounts must contain at least one category.'
      }
      $whitelist = @(
        if ($WhitelistPath) {
          Read-ParityJsonFile -Path $WhitelistPath | Where-Object { $null -ne $_ }
        }
      )
      $journalEntries = @(
        Read-ParityJsonLines -Path (Get-ParityJournalPath -StatePath $LeftStatePath -HostName $LeftHostName)
        Read-ParityJsonLines -Path (Get-ParityJournalPath -StatePath $RightStatePath -HostName $RightHostName)
      )

      $leftMap = Get-ParitySurfaceMap -Surfaces @($leftSnapshot.Surfaces)
      $rightMap = Get-ParitySurfaceMap -Surfaces @($rightSnapshot.Surfaces)
      $coverageFailures = [System.Collections.Generic.List[object]]::new()
      foreach ($snapshotCandidate in @(
          [pscustomobject]@{ HostName = $LeftHostName.ToLowerInvariant(); Surfaces = @($leftSnapshot.Surfaces) },
          [pscustomobject]@{ HostName = $RightHostName.ToLowerInvariant(); Surfaces = @($rightSnapshot.Surfaces) }
        )) {
        foreach ($coverageFailure in @(Get-ParitySurfaceCoverageFindings `
            -Surfaces $snapshotCandidate.Surfaces `
            -ExpectedSurfaceMinimumCounts $ExpectedSurfaceMinimumCounts `
            -HostName $snapshotCandidate.HostName)) {
          $coverageFailures.Add($coverageFailure)
        }
      }
      $allKeys = @($leftMap.Keys + $rightMap.Keys) | Sort-Object -Unique
      $differences = foreach ($key in $allKeys) {
        $leftSurface = $leftMap[$key]
        $rightSurface = $rightMap[$key]
        $category, $item = $key -split '\|', 2
        $leftValue = if ($leftSurface) { [string] $leftSurface.Value } else { '<missing>' }
        $rightValue = if ($rightSurface) { [string] $rightSurface.Value } else { '<missing>' }

        if ($leftValue -eq $rightValue) {
          continue
        }

        $whitelistEntry = Get-ParityWhitelistEntry -Whitelist $whitelist -Category $category -Item $item -LeftHostName $LeftHostName -LeftValue $leftValue -RightHostName $RightHostName -RightValue $rightValue
        $journalEntry = Test-ParityJournalCorrelation -JournalEntries $journalEntries -Category $category -Item $item
        $classification = if ($whitelistEntry) {
          'Whitelisted'
        } elseif ($journalEntry) {
          'DeclaredDrift'
        } else {
          'UndeclaredDrift'
        }

        [pscustomobject] @{
          Category = $category
          Item = $item
          LeftHostName = $LeftHostName.ToLowerInvariant()
          LeftValue = $leftValue
          RightHostName = $RightHostName.ToLowerInvariant()
          RightValue = $rightValue
          Classification = $classification
          JournalEntryId = if ($journalEntry) { $journalEntry.Id } else { $null }
          WhitelistDisposition = if ($whitelistEntry) { $whitelistEntry.disposition } else { $null }
        }
      }

      $conflictedCopies = Get-ChildItem -LiteralPath $LeftStatePath, $RightStatePath -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object {
          $_.Name -match '(?i)(conflicted copy|sync conflict|conflict|~RF)'
        } |
        Select-Object FullName, Length, LastWriteTimeUtc

      $timestampUtc = (Get-Date).ToUniversalTime()
      if (-not $ReportPath) {
        $stamp = $timestampUtc.ToString('yyyyMMddTHHmmssZ', [Globalization.CultureInfo]::InvariantCulture)
        $ReportPath = Join-Path $LeftStatePath "DriftReport.$($LeftHostName.ToLowerInvariant()).$($RightHostName.ToLowerInvariant()).$stamp.md"
      }

      $staleThreshold = $null
      if ($PSBoundParameters.ContainsKey('ExpectedCadence')) {
        if ($ExpectedCadence.Ticks -le 0) {
          throw 'ExpectedCadence must be greater than zero when supplied.'
        }

        if ($StaleMultiplier -le 0) {
          throw 'StaleMultiplier must be greater than zero.'
        }

        $staleThreshold = [TimeSpan]::FromTicks([long] [Math]::Ceiling($ExpectedCadence.Ticks * $StaleMultiplier))
      }

      $snapshotFreshness = foreach ($candidate in @(
          [pscustomobject]@{
            HostName = $LeftHostName.ToLowerInvariant()
            SnapshotPath = $LeftSnapshotPath
            CapturedAtUtc = $leftSnapshot.CapturedAtUtc
          },
          [pscustomobject]@{
            HostName = $RightHostName.ToLowerInvariant()
            SnapshotPath = $RightSnapshotPath
            CapturedAtUtc = $rightSnapshot.CapturedAtUtc
          }
        )) {
        $capturedAtValue = $candidate.CapturedAtUtc
        $capturedAt = if ($capturedAtValue -is [DateTimeOffset]) {
          $capturedAtValue.ToUniversalTime()
        } elseif ($capturedAtValue -is [DateTime]) {
          $capturedAtDateTime = [DateTime]$capturedAtValue
          if ($capturedAtDateTime.Kind -eq [DateTimeKind]::Unspecified) {
            $capturedAtDateTime = [DateTime]::SpecifyKind($capturedAtDateTime, [DateTimeKind]::Utc)
          }

          ([DateTimeOffset]$capturedAtDateTime).ToUniversalTime()
        } else {
          [DateTimeOffset]::Parse(
            [string]$capturedAtValue,
            [Globalization.CultureInfo]::InvariantCulture,
            [Globalization.DateTimeStyles]::RoundtripKind
          ).ToUniversalTime()
        }
        $age = $timestampUtc - $capturedAt.UtcDateTime

        [pscustomobject]@{
          HostName = $candidate.HostName
          SnapshotPath = $candidate.SnapshotPath
          CapturedAtUtc = $capturedAt.ToString('o', [Globalization.CultureInfo]::InvariantCulture)
          Age = $age
          IsStale = if ($staleThreshold) { $age -gt $staleThreshold } else { $false }
        }
      }

      $undeclared = @($differences | Where-Object Classification -eq 'UndeclaredDrift')
      $declared = @($differences | Where-Object Classification -eq 'DeclaredDrift')
      $accepted = @($differences | Where-Object Classification -eq 'Whitelisted')
      $staleSnapshots = @($snapshotFreshness | Where-Object IsStale)

      $reportLines = @(
        "# Parity Drift Report: $LeftHostName vs $RightHostName",
        '',
        "- GeneratedUtc: $($timestampUtc.ToString('o', [Globalization.CultureInfo]::InvariantCulture))",
        "- LeftSnapshot: $LeftSnapshotPath",
        "- RightSnapshot: $RightSnapshotPath",
        "- UndeclaredDriftCount: $($undeclared.Count)",
        "- DeclaredDriftCount: $($declared.Count)",
        "- WhitelistedDriftCount: $($accepted.Count)",
        "- StaleSnapshotCount: $($staleSnapshots.Count)",
        "- SurfaceCoverageFailureCount: $($coverageFailures.Count)",
        "- ConflictedCopyCount: $(@($conflictedCopies).Count)",
        '',
        '## Snapshot Freshness',
        ''
      )

      if ($staleThreshold) {
        $reportLines += "- ExpectedCadence: $ExpectedCadence"
        $reportLines += "- StaleThreshold: $staleThreshold"
      } else {
        $reportLines += '- Not evaluated (ExpectedCadence was not supplied)'
      }

      foreach ($freshness in $snapshotFreshness) {
        $status = if ($freshness.IsStale) { 'STALE' } else { 'Fresh' }
        $reportLines += "- $($freshness.HostName): $status; CapturedAtUtc=$($freshness.CapturedAtUtc); Age=$($freshness.Age); Snapshot=$($freshness.SnapshotPath)"
      }

      $reportLines += @('', '## Surface Coverage Failures', '')
      if ($coverageFailures.Count -eq 0) {
        $reportLines += '- None'
      } else {
        foreach ($failure in $coverageFailures) {
          $failurePath = if ($failure.Classification -eq 'AuditError') {
            "$($failure.HostName)/$($failure.Category)/$($failure.Item)"
          } else {
            "$($failure.HostName)/$($failure.Category)"
          }
          $reportLines += "- $failurePath`: $($failure.Classification); ActualCount=$($failure.ActualCount); ExpectedMinimumCount=$($failure.ExpectedMinimumCount)"
        }
      }

      $reportLines += @(
        '',
        '## Undeclared Drift',
        ''
      )

      if ($undeclared.Count -eq 0) {
        $reportLines += '- None'
      } else {
        foreach ($drift in $undeclared) {
          $reportLines += "- $($drift.Category)/$($drift.Item): $($drift.LeftHostName)='$($drift.LeftValue)' vs $($drift.RightHostName)='$($drift.RightValue)'"
        }
      }

      $reportLines += @('', '## Declared Drift', '')
      if ($declared.Count -eq 0) {
        $reportLines += '- None'
      } else {
        foreach ($drift in $declared) {
          $reportLines += "- $($drift.Category)/$($drift.Item): correlated with journal entry $($drift.JournalEntryId)"
        }
      }

      $reportLines += @('', '## Whitelisted Drift', '')
      if ($accepted.Count -eq 0) {
        $reportLines += '- None'
      } else {
        foreach ($drift in $accepted) {
          $reportLines += "- $($drift.Category)/$($drift.Item): $($drift.WhitelistDisposition)"
        }
      }

      $reportLines += @('', '## Conflicted Copies', '')
      if (@($conflictedCopies).Count -eq 0) {
        $reportLines += '- None'
      } else {
        foreach ($copy in $conflictedCopies) {
          $reportLines += "- $($copy.FullName)"
        }
      }

      if ($PSCmdlet.ShouldProcess($ReportPath, 'Write parity drift report')) {
        Set-Content -LiteralPath $ReportPath -Value $reportLines -Encoding utf8
      }

      [pscustomobject] @{
        GeneratedAtUtc = $timestampUtc.ToString('o', [Globalization.CultureInfo]::InvariantCulture)
        LeftSnapshotPath = $LeftSnapshotPath
        RightSnapshotPath = $RightSnapshotPath
        ReportPath = $ReportPath
        Differences = @($differences)
        UndeclaredDrift = $undeclared
        DeclaredDrift = $declared
        WhitelistedDrift = $accepted
        SnapshotFreshness = @($snapshotFreshness)
        StaleSnapshots = $staleSnapshots
        ExpectedCadence = $ExpectedCadence
        StaleThreshold = $staleThreshold
        SurfaceCoverageFailures = @($coverageFailures)
        HasSurfaceCoverageFailure = $coverageFailures.Count -gt 0
        ConflictedCopies = @($conflictedCopies)
      }
    } catch {
      Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failed to compare parity audits. Exception: $($_.Exception.Message)"
      throw
    }
  }

  end {
    Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Completed parity audit comparison.'
  }
}
