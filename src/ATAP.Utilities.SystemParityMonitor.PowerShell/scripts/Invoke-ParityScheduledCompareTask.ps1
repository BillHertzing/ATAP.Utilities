[CmdletBinding()]
param(
  [string]$LeftStatePath = 'C:\ProgramData\ATAP\ParityState',

  [string]$RightStatePath = '\\utat01\ParityState',

  [string]$LeftHostName = $env:COMPUTERNAME,

  [string]$RightHostName = 'utat01',

  [double]$ExpectedCadenceDays = 1,

  [double]$StaleMultiplier = 1.5,

  [string]$ResultDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-ParityTaskTokenCredential {
  [CmdletBinding()]
  param()

  $currentSamName = ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name -split '\\')[-1]
  $credentialDirectory = Join-Path 'C:\ProgramData\ATAP\BitwardenCredentials' $currentSamName
  $tokenPath = Join-Path $credentialDirectory "$env:COMPUTERNAME`_$currentSamName`_BWS_AccessToken.xml"
  if (-not (Test-Path -LiteralPath $tokenPath)) {
    throw "BWS access-token file was not found at '$tokenPath'."
  }

  [pscustomobject]@{
    CredentialDirectory = $credentialDirectory
    TokenPath = $tokenPath
    Credential = Import-Clixml -LiteralPath $tokenPath -ErrorAction Stop
  }
}

function Invoke-ParityTaskBwsProbe {
  [CmdletBinding()]
  param()

  $tokenResult = Get-ParityTaskTokenCredential
  $bwsCommand = Get-Command -Name 'bws' -CommandType Application -ErrorAction Stop
  $env:BWS_ACCESS_TOKEN = $tokenResult.Credential.GetNetworkCredential().Password

  try {
    $secretListOutput = & $bwsCommand.Source secret list --output json --color no 2>&1
    if ($LASTEXITCODE -ne 0) {
      throw "bws secret list failed with exit code $LASTEXITCODE. Output: $($secretListOutput -join [Environment]::NewLine)"
    }

    $secretCount = @($secretListOutput | ConvertFrom-Json -ErrorAction Stop).Count
    [pscustomobject]@{
      Success = $true
      CredentialDirectory = $tokenResult.CredentialDirectory
      TokenPath = $tokenResult.TokenPath
      BwsPath = $bwsCommand.Source
      SecretCount = $secretCount
    }
  } finally {
    Remove-Item -LiteralPath Env:BWS_ACCESS_TOKEN -ErrorAction SilentlyContinue
  }
}

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
  $probe = Invoke-ParityTaskBwsProbe
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
    BwsProbe = $probe
  } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resultPath -Encoding utf8
} catch {
  [pscustomobject]@{
    Success = $false
    Task = 'ParityCompare'
    LeftHostName = $LeftHostName.ToLowerInvariant()
    RightHostName = $RightHostName.ToLowerInvariant()
    IdentityName = try { [System.Security.Principal.WindowsIdentity]::GetCurrent().Name } catch { '<unknown>' }
    GeneratedAtUtc = $timestampUtc.ToString('o', [Globalization.CultureInfo]::InvariantCulture)
    Error = $_.Exception.Message
  } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $resultPath -Encoding utf8
  throw
}
