[CmdletBinding()]
param(
  [string]$LeftStatePath = 'C:\ProgramData\ATAP\ParityState',

  [string]$RightStatePath = '\\utat01\ParityState',

  [string]$LeftHostName = $env:COMPUTERNAME,

  [string]$RightHostName = 'utat01',

  [double]$ExpectedCadenceDays = 1,

  [double]$StaleMultiplier = 1.5,

  [string]$ResultDirectory,

  [string]$CredentialDirectory,

  [ValidateSet('ReadOnly', 'ReadWrite')]
  [string]$TokenPurpose = 'ReadOnly',

  [string]$EventLogName = 'Application',

  [string]$EventSource = 'ATAP.SystemParityMonitor'
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
  $probe = Invoke-ParityScheduledTaskBwsProbe -CredentialDirectory $CredentialDirectory -TokenPurpose $TokenPurpose
  $comparison = Compare-ParityAudits `
    -LeftStatePath $LeftStatePath `
    -RightStatePath $RightStatePath `
    -LeftHostName $LeftHostName `
    -RightHostName $RightHostName `
    -ExpectedCadence (New-TimeSpan -Days $ExpectedCadenceDays) `
    -StaleMultiplier $StaleMultiplier

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
    StaleSnapshotCount = @($comparison.StaleSnapshots).Count
    StaleSnapshots = @($comparison.StaleSnapshots)
    EventLog = $null
    BwsProbe = $probe
  } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resultPath -Encoding utf8
} catch {
  $identityName = try {
    [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
  } catch {
    '<unknown>'
  }

  $eventLogResult = Write-ParityScheduledTaskEvent `
    -EntryType Error `
    -EventId 12381 `
    -Message "Parity compare scheduled task failed for '$LeftHostName' versus '$RightHostName'. $($_.Exception.Message)" `
    -LogName $EventLogName `
    -Source $EventSource

  [pscustomobject]@{
    Success = $false
    Task = 'ParityCompare'
    LeftHostName = $LeftHostName.ToLowerInvariant()
    RightHostName = $RightHostName.ToLowerInvariant()
    IdentityName = $identityName
    GeneratedAtUtc = $timestampUtc.ToString('o', [Globalization.CultureInfo]::InvariantCulture)
    EventLog = $eventLogResult
    Error = $_.Exception.Message
  } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $resultPath -Encoding utf8
  throw
}
