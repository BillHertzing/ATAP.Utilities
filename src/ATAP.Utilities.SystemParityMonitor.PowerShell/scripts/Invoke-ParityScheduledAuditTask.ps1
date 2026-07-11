[CmdletBinding()]
param(
  [string]$StatePath = 'C:\ProgramData\ATAP\ParityState',

  [string]$HostName = $env:COMPUTERNAME,

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
  $ResultDirectory = Join-Path $StatePath 'TaskResults'
}

New-Item -ItemType Directory -Path $ResultDirectory -Force | Out-Null
$timestampUtc = (Get-Date).ToUniversalTime()
$stamp = $timestampUtc.ToString('yyyyMMddTHHmmssZ', [Globalization.CultureInfo]::InvariantCulture)
$resultPath = Join-Path $ResultDirectory "ParityAuditTaskResult.$($HostName.ToLowerInvariant()).$stamp.json"

try {
  $probe = Invoke-ParityScheduledTaskBwsProbe -CredentialDirectory $CredentialDirectory -TokenPurpose $TokenPurpose
  $snapshot = Invoke-ParityAudit -StatePath $StatePath -HostName $HostName

  [pscustomobject]@{
    Success = $true
    Task = 'ParityAudit'
    HostName = $HostName.ToLowerInvariant()
    IdentityName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    GeneratedAtUtc = $timestampUtc.ToString('o', [Globalization.CultureInfo]::InvariantCulture)
    SnapshotPath = $snapshot.SnapshotPath
    CapturedAtUtc = $snapshot.CapturedAtUtc
    EventLog = $null
    BwsProbe = $probe
  } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resultPath -Encoding utf8
} catch {
  $eventLogResult = Write-ParityScheduledTaskEvent `
    -EntryType Error `
    -EventId 12380 `
    -Message "Parity audit scheduled task failed for host '$HostName'. $($_.Exception.Message)" `
    -LogName $EventLogName `
    -Source $EventSource

  [pscustomobject]@{
    Success = $false
    Task = 'ParityAudit'
    HostName = $HostName.ToLowerInvariant()
    IdentityName = try { [System.Security.Principal.WindowsIdentity]::GetCurrent().Name } catch { '<unknown>' }
    GeneratedAtUtc = $timestampUtc.ToString('o', [Globalization.CultureInfo]::InvariantCulture)
    EventLog = $eventLogResult
    Error = $_.Exception.Message
  } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $resultPath -Encoding utf8
  throw
}
