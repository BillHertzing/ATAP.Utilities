<#
.SYNOPSIS
Runs a redacted Bitwarden Secrets Manager inventory probe.

.DESCRIPTION
This script is intended to run from a Windows Scheduled Task under the
SvcBuildmaster account. It reads the DPAPI-protected BWS access token through
the BuildTooling helper, runs bws, and writes redacted evidence to _generated.

Secret values and access tokens are never written. Evidence records secret
names, project IDs, field names, field types, value presence, and value lengths.
#>
[CmdletBinding()]
param(
  [Parameter()]
  [ValidateNotNullOrEmpty()]
  [string]$OutputDirectory = (Join-Path ([System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\..'))) '_generated'),

  [Parameter()]
  [string]$CredentialDirectory,

  [Parameter()]
  [ValidateNotNullOrEmpty()]
  [string]$ResultPrefix = 'SA-02-SA-03-SA-04-SvcBuildmaster-BWS-Inventory'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-RedactedSecretInventory {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [object[]]$Secrets
  )

  foreach ($secret in $Secrets) {
    $secretName = if ($secret.PSObject.Properties.Name -contains 'key') {
      [string]$secret.key
    } else {
      [string]$secret.name
    }

    $value = if ($secret.PSObject.Properties.Name -contains 'value') {
      [string]$secret.value
    } else {
      $null
    }

    $fields = @()
    if (-not [string]::IsNullOrWhiteSpace($value)) {
      try {
        $parsed = $value | ConvertFrom-Json -ErrorAction Stop
        if ($parsed -is [psobject]) {
          foreach ($property in $parsed.PSObject.Properties) {
            $propertyValue = $property.Value
            $fields += [pscustomobject]@{
              name         = $property.Name
              type         = if ($null -eq $propertyValue) { 'null' } else { $propertyValue.GetType().FullName }
              valuePresent = $null -ne $propertyValue
              valueLength  = if ($null -eq $propertyValue) { 0 } else { ([string]$propertyValue).Length }
            }
          }
        }
      } catch {
        $fields += [pscustomobject]@{
          name         = '<raw>'
          type         = 'System.String'
          valuePresent = $true
          valueLength  = $value.Length
        }
      }
    }

    [pscustomobject]@{
      id             = if ($secret.PSObject.Properties.Name -contains 'id') { $secret.id } else { $null }
      key            = $secretName
      projectId      = if ($secret.PSObject.Properties.Name -contains 'projectId') { $secret.projectId } else { $null }
      organizationId = if ($secret.PSObject.Properties.Name -contains 'organizationId') { $secret.organizationId } else { $null }
      fields         = $fields
    }
  }
}

function Get-BwsProbeAccessTokenCredential {
  [CmdletBinding()]
  param(
    [Parameter()]
    [string]$CredentialDirectory
  )

  $currentSamName = ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name -split '\\')[-1]
  if ([string]::IsNullOrWhiteSpace($CredentialDirectory)) {
    $CredentialDirectory = Join-Path 'C:\ProgramData\ATAP\BitwardenCredentials' $currentSamName
  }

  $tokenFileName = "$env:COMPUTERNAME`_$currentSamName`_BWS_AccessToken.xml"
  $tokenPath = Join-Path $CredentialDirectory $tokenFileName
  if (-not (Test-Path -LiteralPath $tokenPath)) {
    throw "BWS access-token file was not found at '$tokenPath'."
  }

  [pscustomobject]@{
    Credential = Import-Clixml -LiteralPath $tokenPath -ErrorAction Stop
    TokenPath  = $tokenPath
  }
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$basePath = Join-Path $OutputDirectory "$ResultPrefix-$timestamp"
$jsonPath = "$basePath.json"
$csvPath = "$basePath.fields.csv"
$logPath = "$basePath.log"

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

try {
  $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
  $bwsCommand = Get-Command -Name 'bws' -CommandType Application -ErrorAction Stop
  $tokenCredentialResult = Get-BwsProbeAccessTokenCredential -CredentialDirectory $CredentialDirectory
  $env:BWS_ACCESS_TOKEN = $tokenCredentialResult.Credential.GetNetworkCredential().Password

  $versionOutput = & $bwsCommand.Source --version
  if ($LASTEXITCODE -ne 0) {
    throw "bws --version failed with exit code $LASTEXITCODE."
  }

  $secretListOutput = & $bwsCommand.Source secret list --output json
  if ($LASTEXITCODE -ne 0) {
    throw "bws secret list failed with exit code $LASTEXITCODE."
  }

  $secrets = @($secretListOutput | ConvertFrom-Json -ErrorAction Stop)
  $inventory = @(ConvertTo-RedactedSecretInventory -Secrets $secrets)
  $projects = @($inventory | ForEach-Object { $_.projectId } | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | Sort-Object -Unique)

  $fieldRows = foreach ($secret in $inventory) {
    if ($secret.fields.Count -eq 0) {
      [pscustomobject]@{
        SecretName   = $secret.key
        SecretId     = $secret.id
        ProjectId    = $secret.projectId
        FieldName    = '<none>'
        FieldType    = ''
        ValuePresent = $false
        ValueLength  = 0
      }
      continue
    }

    foreach ($field in $secret.fields) {
      [pscustomobject]@{
        SecretName   = $secret.key
        SecretId     = $secret.id
        ProjectId    = $secret.projectId
        FieldName    = $field.name
        FieldType    = $field.type
        ValuePresent = $field.valuePresent
        ValueLength  = $field.valueLength
      }
    }
  }

  $result = [pscustomobject]@{
    success             = $true
    timestampUtc        = (Get-Date).ToUniversalTime().ToString('o')
    computerName        = $env:COMPUTERNAME
    identityName        = $identity.Name
    userNameEnvironment = $env:USERNAME
    bwsPath             = $bwsCommand.Source
    bwsVersion          = [string]$versionOutput
    credentialDirectory = $CredentialDirectory
    tokenPath           = $tokenCredentialResult.TokenPath
    secretCount         = $inventory.Count
    projectIds          = $projects
    inventory           = $inventory
    outputFiles         = [pscustomobject]@{
      json = $jsonPath
      csv  = $csvPath
      log  = $logPath
    }
  }

  $result | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
  $fieldRows | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8
  @(
    'SUCCESS'
    "TimestampUtc=$($result.timestampUtc)"
    "Identity=$($result.identityName)"
    "BwsPath=$($result.bwsPath)"
    "BwsVersion=$($result.bwsVersion)"
    "SecretCount=$($result.secretCount)"
    "ProjectIds=$($projects -join ',')"
    "Json=$jsonPath"
    "Csv=$csvPath"
  ) | Set-Content -LiteralPath $logPath -Encoding UTF8

  exit 0
} catch {
  $identityName = try {
    [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
  } catch {
    '<unknown>'
  }

  $failure = [pscustomobject]@{
    success      = $false
    timestampUtc = (Get-Date).ToUniversalTime().ToString('o')
    computerName = $env:COMPUTERNAME
    identityName = $identityName
    error        = $_.Exception.Message
    outputFiles  = [pscustomobject]@{
      json = $jsonPath
      csv  = $csvPath
      log  = $logPath
    }
  }

  $failure | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
  "FAILED`r`nIdentity=$identityName`r`nError=$($_.Exception.Message)`r`nJson=$jsonPath" | Set-Content -LiteralPath $logPath -Encoding UTF8
  exit 1
} finally {
  Remove-Item -LiteralPath Env:BWS_ACCESS_TOKEN -ErrorAction SilentlyContinue
}
