function Invoke-ParityScheduledCompareTask {
  [CmdletBinding()]
  param(
    [string] $LeftStatePath = 'C:\ProgramData\ATAP\ParityState',

    [string] $RightStatePath = '\\utat01\ParityState',

    [string] $LeftHostName = $env:COMPUTERNAME,

    [string] $RightHostName = 'utat01',

    [double] $ExpectedCadenceDays = 1,

    [double] $StaleMultiplier = 1.5,

    [string] $PackageManagerProfilesPath,

    [string] $ResultDirectory,

    [string] $EventLogName = 'Application',

    [string] $EventSource = 'ATAP.SystemParityMonitor'
  )

  Set-StrictMode -Version Latest
  $ErrorActionPreference = 'Stop'

  . (Join-Path $PSScriptRoot 'ParityScheduledTask.Common.ps1')
  $modulePath = Join-Path $PSScriptRoot '..\ATAP.Utilities.SystemParityMonitor.PowerShell.psd1'
  Import-Module -Name $modulePath -Force

  if ([string]::IsNullOrWhiteSpace($ResultDirectory)) {
    $ResultDirectory = Join-Path $LeftStatePath 'TaskResults'
  }

  New-Item -ItemType Directory -Path $ResultDirectory -Force | Out-Null
  $timestampUtc = (Get-Date).ToUniversalTime()
  $stamp = $timestampUtc.ToString('yyyyMMddTHHmmssZ', [Globalization.CultureInfo]::InvariantCulture)
  $resultPath = Join-Path $ResultDirectory "ParityCompareTaskResult.$($LeftHostName.ToLowerInvariant()).$($RightHostName.ToLowerInvariant()).$stamp.json"

  try {
    $comparisonParameters = @{
      LeftStatePath = $LeftStatePath
      RightStatePath = $RightStatePath
      LeftHostName = $LeftHostName
      RightHostName = $RightHostName
      ExpectedCadence = New-TimeSpan -Days $ExpectedCadenceDays
      StaleMultiplier = $StaleMultiplier
    }
    if (-not [string]::IsNullOrWhiteSpace($PackageManagerProfilesPath)) {
      $configuration = Read-ParityScheduledConfiguration -Path $PackageManagerProfilesPath
      $comparisonParameters['ExpectedSurfaceMinimumCounts'] = $configuration.ExpectedSurfaceMinimumCounts
    }
    $comparison = Compare-ParityAudits @comparisonParameters

    $failureState = Set-ParityScheduledTaskOutcome -StatePath $LeftStatePath -TaskName 'ParityCompare' -Succeeded $true
    $staleSnapshotCount = @($comparison.StaleSnapshots).Count
    $hasSurfaceCoverageFailure = if ($comparison.PSObject.Properties['HasSurfaceCoverageFailure']) {
      [bool]$comparison.HasSurfaceCoverageFailure
    } else {
      $false
    }
    $surfaceCoverageFailureCount = if ($comparison.PSObject.Properties['SurfaceCoverageFailures']) {
      @($comparison.SurfaceCoverageFailures).Count
    } else {
      0
    }
    $alertReason = if ($staleSnapshotCount -gt 0 -and $hasSurfaceCoverageFailure) {
      'StaleAndSurfaceCoverageFailure'
    } elseif ($staleSnapshotCount -gt 0) {
      'StaleSnapshot'
    } elseif ($hasSurfaceCoverageFailure) {
      'SurfaceCoverageFailure'
    } else {
      $null
    }
    $eventLogResult = if ($alertReason) {
      Write-ParityScheduledTaskEvent `
        -EntryType Warning `
        -EventId 12382 `
        -Message "ParityCompare requires immediate review for '$($LeftHostName.ToLowerInvariant())' versus '$($RightHostName.ToLowerInvariant())'. Reason=$alertReason; StaleSnapshotCount=$staleSnapshotCount; SurfaceCoverageFailureCount=$surfaceCoverageFailureCount." `
        -LogName $EventLogName `
        -Source $EventSource
    } else {
      $null
    }

    [pscustomobject]@{
      Success = $true
      Task = 'ParityCompare'
      LeftHostName = $LeftHostName.ToLowerInvariant()
      RightHostName = $RightHostName.ToLowerInvariant()
      IdentityName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
      GeneratedAtUtc = $timestampUtc.ToString('o', [Globalization.CultureInfo]::InvariantCulture)
      ReportPath = $comparison.ReportPath
      UndeclaredDriftCount = @($comparison.UndeclaredDrift).Count
      DeclaredDriftCount = @($comparison.DeclaredDrift).Count
      WhitelistedDriftCount = @($comparison.WhitelistedDrift).Count
      StaleSnapshotCount = $staleSnapshotCount
      StaleSnapshots = @($comparison.StaleSnapshots)
      HasSurfaceCoverageFailure = $hasSurfaceCoverageFailure
      SurfaceCoverageFailureCount = $surfaceCoverageFailureCount
      SecretAccessRequired = $false
      AlertReason = $alertReason
      EventLog = $eventLogResult
      FailureState = $failureState
    } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resultPath -Encoding utf8
  } catch {
    $primaryError = $_
    $identityName = try {
      [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    } catch {
      '<unknown>'
    }
    $failureState = Set-ParityScheduledTaskOutcome -StatePath $LeftStatePath -TaskName 'ParityCompare' -Succeeded $false
    $alertReason = if ($failureState.PersistenceSucceeded -and $failureState.ConsecutiveFailureCount -ge 2 -and
      -not $failureState.FailureNotificationSucceeded) {
      'SecondConsecutiveTaskFailure'
    } else {
      $null
    }
    $eventLogResult = if ($alertReason) {
      Write-ParityScheduledTaskEvent `
        -EntryType Error `
        -EventId 12381 `
        -Message "ParityCompare reached its second consecutive scheduled-task failure for '$($LeftHostName.ToLowerInvariant())' versus '$($RightHostName.ToLowerInvariant())'." `
        -LogName $EventLogName `
        -Source $EventSource
    } else {
      $null
    }
    if ($null -ne $eventLogResult) {
      $failureState = Set-ParityScheduledTaskNotificationOutcome -StatePath $LeftStatePath -TaskName 'ParityCompare' `
        -Succeeded ([bool]$eventLogResult.Success)
    }

    try {
      [pscustomobject]@{
        Success = $false
        Task = 'ParityCompare'
        LeftHostName = $LeftHostName.ToLowerInvariant()
        RightHostName = $RightHostName.ToLowerInvariant()
        IdentityName = $identityName
        GeneratedAtUtc = $timestampUtc.ToString('o', [Globalization.CultureInfo]::InvariantCulture)
        SecretAccessRequired = $false
        AlertReason = $alertReason
        EventLog = $eventLogResult
        FailureState = $failureState
        ErrorType = $primaryError.Exception.GetType().FullName
        ErrorMessage = $primaryError.Exception.Message
        FullyQualifiedErrorId = $primaryError.FullyQualifiedErrorId
      } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resultPath -Encoding utf8
    } catch {
      # Preserve the comparison failure as the primary scheduled-task outcome.
    }
    throw $primaryError
  }
}

if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.InvocationName -ne '&') {
  Invoke-ParityScheduledCompareTask @args
}
