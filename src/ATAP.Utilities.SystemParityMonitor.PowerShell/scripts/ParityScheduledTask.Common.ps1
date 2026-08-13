function Read-ParityScheduledConfiguration {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string] $Path
  )

  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw [IO.FileNotFoundException]::new("Parity scheduled configuration was not found at '$Path'.", $Path)
  }

  try {
    $configuration = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
  } catch {
    throw [InvalidOperationException]::new(
      "Parity scheduled configuration at '$Path' is unreadable or malformed. ErrorType=$($_.Exception.GetType().FullName)",
      $_.Exception
    )
  }

  if ([int]$configuration.SchemaVersion -ne 1) {
    throw "Parity scheduled configuration at '$Path' has unsupported SchemaVersion '$($configuration.SchemaVersion)'; expected 1."
  }
  if (-not $configuration.PSObject.Properties['Profiles'] -or $configuration.Profiles -isnot [array]) {
    throw "Parity scheduled configuration at '$Path' must contain Profiles as an array."
  }
  $configuredIdentities = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  foreach ($profile in @($configuration.Profiles)) {
    $identity = [string]$profile.Identity
    if ([string]::IsNullOrWhiteSpace($identity) -or $identity -match '[/|]' -or
      -not $configuredIdentities.Add($identity.Trim())) {
      throw "Parity scheduled configuration at '$Path' contains an invalid or duplicate profile Identity."
    }
    foreach ($pathProperty in @('PipPath', 'NpmPrefix', 'NuGetToolPath')) {
      $profilePath = if ($profile.PSObject.Properties[$pathProperty]) { [string]$profile.$pathProperty } else { $null }
      if (-not [string]::IsNullOrWhiteSpace($profilePath) -and -not [IO.Path]::IsPathFullyQualified($profilePath)) {
        throw "Parity scheduled configuration at '$Path' contains a non-qualified $pathProperty."
      }
    }
  }
  if (-not $configuration.PSObject.Properties['ExpectedSurfaceMinimumCounts'] -or
    $null -eq $configuration.ExpectedSurfaceMinimumCounts) {
    throw "Parity scheduled configuration at '$Path' must contain ExpectedSurfaceMinimumCounts."
  }

  $minimumCounts = @{}
  foreach ($property in @($configuration.ExpectedSurfaceMinimumCounts.PSObject.Properties)) {
    if ([string]::IsNullOrWhiteSpace($property.Name)) {
      throw 'Expected surface minimum category keys must be non-empty.'
    }
    $minimumCount = 0
    if (-not [int]::TryParse([string]$property.Value, [ref]$minimumCount) -or $minimumCount -lt 1) {
      throw "Expected minimum count for category '$($property.Name)' must be an integer of at least one."
    }
    $minimumCounts[$property.Name] = $minimumCount
  }
  if ($minimumCounts.Count -eq 0) {
    throw 'ExpectedSurfaceMinimumCounts must contain at least one category.'
  }

  [pscustomobject]@{
    SchemaVersion = 1
    Profiles = @($configuration.Profiles)
    ExpectedSurfaceMinimumCounts = $minimumCounts
  }
}

function Write-ParityScheduledTaskEvent {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Error', 'Warning', 'Information')]
    [string] $EntryType,

    [Parameter(Mandatory = $true)]
    [int] $EventId,

    [Parameter(Mandatory = $true)]
    [string] $Message,

    [string] $LogName = 'Application',

    [string] $Source = 'ATAP.SystemParityMonitor'
  )

  $fn = 'Write-ParityScheduledTaskEvent'
  $mn = 'ATAP.Utilities.SystemParityMonitor.PowerShell'

  try {
    if (-not [System.Diagnostics.EventLog]::SourceExists($Source)) {
      New-EventLog -LogName $LogName -Source $Source -ErrorAction Stop
    }

    Write-EventLog -LogName $LogName -Source $Source -EntryType $EntryType -EventId $EventId -Message $Message -ErrorAction Stop
    [pscustomobject]@{
      Success = $true
      LogName = $LogName
      Source = $Source
      EventId = $EventId
      EntryType = $EntryType
      ErrorType = $null
    }
  } catch {
    [pscustomobject]@{
      Success = $false
      LogName = $LogName
      Source = $Source
      EventId = $EventId
      EntryType = $EntryType
      ErrorType = $_.Exception.GetType().FullName
    }
  }
}

function Get-ParityScheduledTaskFailureStatePath {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string] $StatePath,

    [Parameter(Mandatory = $true)]
    [ValidateSet('ParityAudit', 'ParityCompare')]
    [string] $TaskName
  )

  Join-Path (Join-Path $StatePath 'TaskState') "ScheduledTaskFailureState.$TaskName.json"
}

function Read-ParityScheduledTaskFailureState {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string] $StatePath,

    [Parameter(Mandatory = $true)]
    [ValidateSet('ParityAudit', 'ParityCompare')]
    [string] $TaskName
  )

  $path = Get-ParityScheduledTaskFailureStatePath -StatePath $StatePath -TaskName $TaskName
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    return [pscustomobject]@{
      StatePath = $path
      ConsecutiveFailureCount = 0
      FailureNotificationSucceeded = $false
      RecoveredFromCorruptState = $false
      RecoveryErrorType = $null
    }
  }

  try {
    $state = Get-Content -LiteralPath $path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    if ($state.SchemaVersion -ne 1 -or $state.TaskName -ne $TaskName -or
      $null -eq $state.ConsecutiveFailureCount -or [int]$state.ConsecutiveFailureCount -lt 0) {
      throw [FormatException]::new('Scheduled-task failure state did not satisfy schema version 1.')
    }

    [pscustomobject]@{
      StatePath = $path
      ConsecutiveFailureCount = [int]$state.ConsecutiveFailureCount
      FailureNotificationSucceeded = if ($state.PSObject.Properties['FailureNotificationSucceeded']) { [bool]$state.FailureNotificationSucceeded } else { $false }
      RecoveredFromCorruptState = $false
      RecoveryErrorType = $null
    }
  } catch {
    [pscustomobject]@{
      StatePath = $path
      ConsecutiveFailureCount = 0
      FailureNotificationSucceeded = $false
      RecoveredFromCorruptState = $true
      RecoveryErrorType = $_.Exception.GetType().FullName
    }
  }
}

function Write-ParityScheduledTaskFailureState {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string] $StatePath,

    [Parameter(Mandatory = $true)]
    [ValidateSet('ParityAudit', 'ParityCompare')]
    [string] $TaskName,

    [Parameter(Mandatory = $true)]
    [ValidateRange(0, [int]::MaxValue)]
    [int] $ConsecutiveFailureCount,

    [bool] $FailureNotificationSucceeded = $false
  )

  $path = Get-ParityScheduledTaskFailureStatePath -StatePath $StatePath -TaskName $TaskName
  $directory = Split-Path -Parent $path
  $temporaryPath = Join-Path $directory ('.{0}.{1}.tmp' -f [IO.Path]::GetFileName($path), [guid]::NewGuid().ToString('N'))
  $backupPath = Join-Path $directory ('.{0}.{1}.bak' -f [IO.Path]::GetFileName($path), [guid]::NewGuid().ToString('N'))

  try {
    New-Item -ItemType Directory -Path $directory -Force -ErrorAction Stop | Out-Null
    [pscustomobject]@{
      SchemaVersion = 1
      TaskName = $TaskName
      ConsecutiveFailureCount = $ConsecutiveFailureCount
      FailureNotificationSucceeded = $FailureNotificationSucceeded
      UpdatedAtUtc = (Get-Date).ToUniversalTime().ToString('o', [Globalization.CultureInfo]::InvariantCulture)
    } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $temporaryPath -Encoding utf8 -ErrorAction Stop
    if (Test-Path -LiteralPath $path -PathType Leaf) {
      [IO.File]::Replace($temporaryPath, $path, $backupPath)
    } else {
      [IO.File]::Move($temporaryPath, $path)
    }

    [pscustomobject]@{
      Success = $true
      StatePath = $path
      ErrorType = $null
    }
  } catch {
    [pscustomobject]@{
      Success = $false
      StatePath = $path
      ErrorType = $_.Exception.GetType().FullName
    }
  } finally {
    if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) {
      Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path -LiteralPath $backupPath -PathType Leaf) {
      Remove-Item -LiteralPath $backupPath -Force -ErrorAction SilentlyContinue
    }
  }
}

function Set-ParityScheduledTaskOutcome {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string] $StatePath,

    [Parameter(Mandatory = $true)]
    [ValidateSet('ParityAudit', 'ParityCompare')]
    [string] $TaskName,

    [Parameter(Mandatory = $true)]
    [bool] $Succeeded
  )

  $previous = Read-ParityScheduledTaskFailureState -StatePath $StatePath -TaskName $TaskName
  $count = if ($Succeeded) { 0 } else { $previous.ConsecutiveFailureCount + 1 }
  $notificationSucceeded = if ($Succeeded) { $false } else { [bool]$previous.FailureNotificationSucceeded }
  $write = Write-ParityScheduledTaskFailureState -StatePath $StatePath -TaskName $TaskName `
    -ConsecutiveFailureCount $count -FailureNotificationSucceeded $notificationSucceeded

  [pscustomobject]@{
    StatePath = $write.StatePath
    ConsecutiveFailureCount = $count
    FailureNotificationSucceeded = $notificationSucceeded
    PersistenceSucceeded = $write.Success
    PersistenceErrorType = $write.ErrorType
    RecoveredFromCorruptState = $previous.RecoveredFromCorruptState
    RecoveryErrorType = $previous.RecoveryErrorType
  }
}

function Set-ParityScheduledTaskNotificationOutcome {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string] $StatePath,

    [Parameter(Mandatory = $true)]
    [ValidateSet('ParityAudit', 'ParityCompare')]
    [string] $TaskName,

    [Parameter(Mandatory = $true)]
    [bool] $Succeeded
  )

  $current = Read-ParityScheduledTaskFailureState -StatePath $StatePath -TaskName $TaskName
  $write = Write-ParityScheduledTaskFailureState -StatePath $StatePath -TaskName $TaskName `
    -ConsecutiveFailureCount $current.ConsecutiveFailureCount `
    -FailureNotificationSucceeded $Succeeded

  [pscustomobject]@{
    StatePath = $write.StatePath
    ConsecutiveFailureCount = $current.ConsecutiveFailureCount
    FailureNotificationSucceeded = $Succeeded
    PersistenceSucceeded = $write.Success
    PersistenceErrorType = $write.ErrorType
    RecoveredFromCorruptState = $current.RecoveredFromCorruptState
    RecoveryErrorType = $current.RecoveryErrorType
  }
}
