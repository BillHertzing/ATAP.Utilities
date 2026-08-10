function Read-ParityScheduledPackageManagerProfilesConfiguration {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string] $Path
  )

  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw [IO.FileNotFoundException]::new("Package-manager profile configuration was not found at '$Path'.", $Path)
  }

  try {
    $configuration = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
  } catch {
    throw [InvalidOperationException]::new(
      "Package-manager profile configuration at '$Path' is unreadable or malformed. ErrorType=$($_.Exception.GetType().FullName)",
      $_.Exception
    )
  }

  if ([int] $configuration.SchemaVersion -ne 1) {
    throw "Package-manager profile configuration at '$Path' has unsupported SchemaVersion '$($configuration.SchemaVersion)'; expected 1."
  }
  if (-not $configuration.PSObject.Properties['Profiles']) {
    throw "Package-manager profile configuration at '$Path' must contain a Profiles array."
  }
  if ($configuration.Profiles -isnot [array]) {
    throw "Package-manager profile configuration at '$Path' must contain Profiles as an array."
  }

  return @($configuration.Profiles)
}

function Invoke-ParityScheduledAuditTask {
  [CmdletBinding()]
  param(
    [string] $StatePath = 'C:\ProgramData\ATAP\ParityState',

    [string] $HostName = $env:COMPUTERNAME,

    [string] $ResultDirectory,

    [string] $PackageManagerProfilesPath,

    [string] $EventLogName = 'Application',

    [string] $EventSource = 'ATAP.SystemParityMonitor'
  )

  Set-StrictMode -Version Latest
  $ErrorActionPreference = 'Stop'

  . (Join-Path $PSScriptRoot 'ParityScheduledTask.Common.ps1')
  $modulePath = Join-Path $PSScriptRoot '..\ATAP.Utilities.SystemParityMonitor.PowerShell.psd1'
  Import-Module -Name $modulePath -Force

  if ([string]::IsNullOrWhiteSpace($ResultDirectory)) {
    $ResultDirectory = Join-Path $StatePath 'TaskResults'
  }

  New-Item -ItemType Directory -Path $ResultDirectory -Force | Out-Null
  $timestampUtc = (Get-Date).ToUniversalTime()
  $stamp = $timestampUtc.ToString('yyyyMMddTHHmmssZ', [Globalization.CultureInfo]::InvariantCulture)
  $resultPath = Join-Path $ResultDirectory "ParityAuditTaskResult.$($HostName.ToLowerInvariant()).$stamp.json"

  try {
    $auditParameters = @{
      StatePath = $StatePath
      HostName = $HostName
    }
    if (-not [string]::IsNullOrWhiteSpace($PackageManagerProfilesPath)) {
      $configuration = Read-ParityScheduledConfiguration -Path $PackageManagerProfilesPath
      $auditParameters['PackageManagerProfiles'] = @($configuration.Profiles)
      $auditParameters['ExpectedSurfaceMinimumCounts'] = $configuration.ExpectedSurfaceMinimumCounts
    }
    $snapshot = Invoke-ParityAudit @auditParameters
    $failureState = Set-ParityScheduledTaskOutcome -StatePath $StatePath -TaskName 'ParityAudit' -Succeeded $true

    [pscustomobject]@{
      Success = $true
      Task = 'ParityAudit'
      HostName = $HostName.ToLowerInvariant()
      IdentityName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
      GeneratedAtUtc = $timestampUtc.ToString('o', [Globalization.CultureInfo]::InvariantCulture)
      SnapshotPath = $snapshot.SnapshotPath
      CapturedAtUtc = $snapshot.CapturedAtUtc
      SecretAccessRequired = $false
      AlertReason = $null
      EventLog = $null
      FailureState = $failureState
    } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resultPath -Encoding utf8
  } catch {
    $primaryError = $_
    $identityName = try {
      [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    } catch {
      '<unknown>'
    }
    $failureState = Set-ParityScheduledTaskOutcome -StatePath $StatePath -TaskName 'ParityAudit' -Succeeded $false
    $alertReason = if ($failureState.PersistenceSucceeded -and $failureState.ConsecutiveFailureCount -ge 2 -and
      -not $failureState.FailureNotificationSucceeded) {
      'SecondConsecutiveTaskFailure'
    } else {
      $null
    }
    $eventLogResult = if ($alertReason) {
      Write-ParityScheduledTaskEvent `
        -EntryType Error `
        -EventId 12380 `
        -Message "ParityAudit reached its second consecutive scheduled-task failure on host '$($HostName.ToLowerInvariant())'." `
        -LogName $EventLogName `
        -Source $EventSource
    } else {
      $null
    }
    if ($null -ne $eventLogResult) {
      $failureState = Set-ParityScheduledTaskNotificationOutcome -StatePath $StatePath -TaskName 'ParityAudit' `
        -Succeeded ([bool]$eventLogResult.Success)
    }

    try {
      [pscustomobject]@{
        Success = $false
        Task = 'ParityAudit'
        HostName = $HostName.ToLowerInvariant()
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
      # Preserve the audit failure as the primary scheduled-task outcome.
    }
    throw $primaryError
  }
}

if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.InvocationName -ne '&') {
  Invoke-ParityScheduledAuditTask @args
}
