Set-StrictMode -Version Latest

function Resolve-BuildMasterRunContextPath {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$SourcePath,

    [Parameter(Mandatory)]
    [string]$BuildMasterBuildId
  )

  if ([string]::IsNullOrWhiteSpace($BuildMasterBuildId)) {
    throw 'BuildMasterBuildId is required. Pass $BuildMasterId(build) from the Otter plan.'
  }

  $safeBuildId = ($BuildMasterBuildId.Trim() -replace '[^A-Za-z0-9._-]', '-').Trim('.-_')
  if ([string]::IsNullOrWhiteSpace($safeBuildId)) {
    throw "BuildMasterBuildId '$BuildMasterBuildId' cannot be converted to a run-context folder name."
  }

  $root = Join-Path -Path $SourcePath -ChildPath '_generated/buildmaster'
  return [System.IO.Path]::GetFullPath((Join-Path -Path $root -ChildPath $safeBuildId))
}

function Clear-OldBuildMasterRunContexts {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$SourcePath,

    [Parameter(Mandatory)]
    [string]$ActiveBuildMasterBuildId,

    [int]$RetentionDays = 14
  )

  if ($RetentionDays -lt 1) {
    return
  }

  $root = [System.IO.Path]::GetFullPath((Join-Path -Path $SourcePath -ChildPath '_generated/buildmaster'))
  if (-not (Test-Path -LiteralPath $root)) {
    return
  }

  $activePath = Resolve-BuildMasterRunContextPath -SourcePath $SourcePath -BuildMasterBuildId $ActiveBuildMasterBuildId
  $cutoff = [DateTime]::UtcNow.AddDays(-1 * $RetentionDays)

  Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
    Where-Object { [System.IO.Path]::GetFullPath($_.FullName) -ne $activePath } |
    Where-Object { $_.LastWriteTimeUtc -lt $cutoff } |
    ForEach-Object {
      Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction Stop
    }
}

function Initialize-BuildMasterRunContextDirectory {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$SourcePath,

    [Parameter(Mandatory)]
    [string]$BuildMasterBuildId,

    [int]$RetentionDays = 14
  )

  $contextDirectory = Resolve-BuildMasterRunContextPath -SourcePath $SourcePath -BuildMasterBuildId $BuildMasterBuildId
  New-Item -ItemType Directory -Path $contextDirectory -Force | Out-Null
  Clear-OldBuildMasterRunContexts -SourcePath $SourcePath -ActiveBuildMasterBuildId $BuildMasterBuildId -RetentionDays $RetentionDays
  return $contextDirectory
}

function Get-BuildMasterAllowDecisions {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$CeilingTier
  )

  $decisions = [ordered]@{}
  foreach ($tierName in @('Experimental', 'Development', 'Integration', 'QA', 'Production')) {
    $decisions[$tierName] = [bool](Test-PromotionWithinCeiling -CurrentTier $tierName -CeilingTier $CeilingTier -AsBoolean)
  }

  return $decisions
}

function Write-BuildMasterRunContextTextFile {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$Path,

    [AllowNull()]
    [object]$Value
  )

  $directory = Split-Path -Parent $Path
  if (-not [string]::IsNullOrWhiteSpace($directory)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
  }
  [string]$text = if ($null -eq $Value) { '' } else { [string]$Value }
  Set-Content -LiteralPath $Path -Value $text -Encoding utf8 -NoNewline
}

function ConvertTo-BuildMasterRunContextHashtable {
  [CmdletBinding()]
  param(
    [AllowNull()]
    [object]$InputObject
  )

  $result = [ordered]@{}
  if ($null -eq $InputObject) {
    return $result
  }

  foreach ($property in $InputObject.PSObject.Properties) {
    $result[$property.Name] = $property.Value
  }

  return $result
}

function Read-BuildMasterRunContextJson {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$ContextDirectory
  )

  $path = Join-Path -Path $ContextDirectory -ChildPath 'build-context.json'
  if (-not (Test-Path -LiteralPath $path)) {
    return $null
  }

  try {
    return Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -ErrorAction Stop
  }
  catch {
    throw "BuildMaster run context JSON is malformed at '$path': $($_.Exception.Message)"
  }
}

function Write-BuildMasterRunContextJson {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$ContextDirectory,

    [Parameter(Mandatory)]
    [string]$BuildMasterBuildId,

    [AllowEmptyString()]
    [string]$BuildNumber,

    [AllowEmptyString()]
    [string]$ExecutionId,

    [Parameter(Mandatory)]
    [string]$ApplicationName,

    [AllowEmptyString()]
    [string]$Branch,

    [Parameter(Mandatory)]
    [string]$SourcePath,

    [AllowEmptyString()]
    [string]$ProjectPath,

    [Parameter(Mandatory)]
    [string]$CurrentTier,

    [Parameter(Mandatory)]
    [string]$CeilingTier,

    [AllowEmptyString()]
    [string]$ResolvedVersion,

    [AllowEmptyString()]
    [string]$PrereleaseLabel,

    [Parameter(Mandatory)]
    [System.Collections.IDictionary]$AllowDecisions,

    [AllowNull()]
    [System.Collections.IDictionary]$StateFiles = $null,

    [AllowNull()]
    [System.Collections.IDictionary]$AdditionalData = $null,

    [int]$RetentionDays = 14
  )

  New-Item -ItemType Directory -Path $ContextDirectory -Force | Out-Null
  $existing = Read-BuildMasterRunContextJson -ContextDirectory $ContextDirectory

  if ($existing) {
    if ($existing.BuildMasterBuildId -and [string]$existing.BuildMasterBuildId -ne $BuildMasterBuildId) {
      throw "BuildMaster run context '$ContextDirectory' belongs to build id '$($existing.BuildMasterBuildId)', not '$BuildMasterBuildId'."
    }

    $existingResolved = [string]$existing.ResolvedVersion
    if (-not [string]::IsNullOrWhiteSpace($existingResolved) -and
      -not [string]::IsNullOrWhiteSpace($ResolvedVersion) -and
      $existingResolved -ne $ResolvedVersion) {
      throw "BuildMaster run context '$ContextDirectory' captured version '$existingResolved', but this run resolved '$ResolvedVersion'."
    }
  }

  $payload = ConvertTo-BuildMasterRunContextHashtable -InputObject $existing
  $payload['BuildMasterBuildId'] = $BuildMasterBuildId
  $payload['BuildNumber'] = $BuildNumber
  $payload['ExecutionId'] = $ExecutionId
  $payload['ApplicationName'] = $ApplicationName
  $payload['Branch'] = $Branch
  $payload['SourcePath'] = $SourcePath
  $payload['ProjectPath'] = $ProjectPath
  $payload['CurrentTier'] = $CurrentTier
  $payload['CeilingTier'] = $CeilingTier
  $payload['ResolvedVersion'] = $ResolvedVersion
  $payload['PrereleaseLabel'] = $PrereleaseLabel
  $payload['AllowDecisions'] = $AllowDecisions
  if ($null -ne $StateFiles -and $StateFiles.Count -gt 0) {
    $payload['StateFiles'] = $StateFiles
  }
  elseif (-not $payload.Contains('StateFiles')) {
    $payload['StateFiles'] = @{}
  }
  $payload['ContextDirectory'] = $ContextDirectory
  $payload['RetentionDays'] = $RetentionDays
  $payload['RetryPolicy'] = 'Refresh recomputable state; fail if an existing captured version conflicts.'
  $payload['StateContract'] = '_generated/buildmaster/<BuildMasterBuildId>/'
  $payload['TimestampUtc'] = [DateTime]::UtcNow.ToString('o')

  if ($null -ne $AdditionalData) {
    foreach ($key in $AdditionalData.Keys) {
      $payload[$key] = $AdditionalData[$key]
    }
  }

  $path = Join-Path -Path $ContextDirectory -ChildPath 'build-context.json'
  $payload | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $path -Encoding utf8
  return [PSCustomObject]$payload
}

function Write-BuildMasterRunStateFiles {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [System.Collections.IDictionary]$StateFiles,

    [Parameter(Mandatory)]
    [System.Collections.IDictionary]$Values
  )

  foreach ($key in $Values.Keys) {
    if (-not $StateFiles.ContainsKey($key)) {
      throw "State file map does not define key '$key'."
    }

    Write-BuildMasterRunContextTextFile -Path $StateFiles[$key] -Value $Values[$key]
  }
}
