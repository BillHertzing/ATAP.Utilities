param(
  [Parameter(Mandatory = $true)][string] $ManifestPath,
  [Parameter(Mandatory = $true)][string] $InventoryPath,
  [Parameter(Mandatory = $true)][string] $InventorySha,
  [Parameter(Mandatory = $true)][string] $ResultPath,
  [Parameter(Mandatory = $true)][string] $FunctionListPath
)

$ErrorActionPreference = 'Stop'
Import-Module -Name $ManifestPath -Force -ErrorAction Stop
$module = Get-Module -Name 'ATAP.Utilities.BuildTooling.ContentSummary.PowerShell'
if ($null -eq $module -or
  [IO.Path]::GetFullPath($module.ModuleBase) -cne [IO.Path]::GetFullPath((Split-Path $ManifestPath -Parent))) {
  throw 'Package-only module did not import from the expanded artifact.'
}

$privateFunctionNames = @([IO.File]::ReadAllText($FunctionListPath) | ConvertFrom-Json)
foreach ($functionName in $privateFunctionNames) {
  $internalCommand = & $module {
    param($Name)
    Get-Command -Name $Name -CommandType Function -ErrorAction Stop
  } $functionName
  if ($null -eq $internalCommand -or $internalCommand.ModuleName -cne $module.Name) {
    throw "Private package function '$functionName' is unavailable from the expanded artifact."
  }
}

if ($null -eq ('Microsoft.Data.SqlClient.SqlParameter' -as [type])) {
  $sqlClientRoot = Join-Path $HOME '.nuget\packages\microsoft.data.sqlclient'
  $sqlClientAssembly = Get-ChildItem -LiteralPath $sqlClientRoot -Filter 'Microsoft.Data.SqlClient.dll' -File -Recurse |
    Where-Object FullName -Like '*\runtimes\win\lib\net8.0\*' |
    Sort-Object FullName -Descending |
    Select-Object -First 1 -ExpandProperty FullName
  if ([string]::IsNullOrWhiteSpace($sqlClientAssembly)) {
    throw 'Microsoft.Data.SqlClient.dll was not found for the package-only parameter boundary test.'
  }
  Add-Type -Path $sqlClientAssembly
}
$setParameterValue = & $module {
  Get-Command -Name 'Set-ContentSummarySqlParameterValue' -CommandType Function -ErrorAction Stop
}
$storedProcedureInvoker = {
  param($SqlConnection,$ProcedureName,$Parameters,$ResultPropertyOrder,$AllowedStatusCodes,$StatusPropertyName,$CommandTimeoutSeconds)
  $finalParameterValues = [ordered]@{}
  foreach ($entry in $Parameters.GetEnumerator()) {
    $definition = $entry.Value
    $parameter = [Microsoft.Data.SqlClient.SqlParameter]::new()
    $parameter.ParameterName = "@$($entry.Key)"
    $parameter.SqlDbType = [System.Data.SqlDbType]::$($definition.SqlDbType)
    if ($null -ne $definition.Size) { $parameter.Size = [int]$definition.Size }
    if ($null -ne $definition.TypeName) { $parameter.TypeName = [string]$definition.TypeName }
    [void](& $setParameterValue -Parameter $parameter -Value $definition.Value)
    $finalParameterValues[$entry.Key] = $parameter.Value
    if ($definition.SqlDbType -eq 'Binary') {
      if ($null -eq $definition.Value) {
        if ($parameter.Value -isnot [DBNull]) { throw "Null Binary parameter '$($entry.Key)' did not reach the DBNull boundary." }
      } elseif ($parameter.Value -isnot [byte[]] -or $parameter.Value.Length -ne 32) {
        throw "Final SqlParameter '$($entry.Key)' is not an exact 32-byte array."
      }
    }
  }
  switch ($ProcedureName) {
    'ATAPUtilities.ProvisionContentSummaryRepositoryV1' {
      $canonicalRoot = ([string]$Parameters.CanonicalRoot.Value).Replace('/','\').ToLowerInvariant()
      [pscustomobject][ordered]@{
        RepositoryId = $Parameters.RepositoryId.Value
        RepositoryRootRegistrationId = $Parameters.RepositoryRootRegistrationId.Value
        CanonicalRepositoryName = $Parameters.CanonicalRepositoryName.Value
        OriginUri = $Parameters.OriginUri.Value
        CanonicalRoot = $canonicalRoot
        RootKindCode = $Parameters.RootKindCode.Value
        StatusCode = 'Created'
        ErrorCode = $null
      }
    }
    'ATAPUtilities.CaptureContentSummaryObservationV1' {
      $hasSummaryText = $finalParameterValues.SafeSummaryText -isnot [DBNull]
      $hasLocator = $finalParameterValues.SafeLocator -isnot [DBNull]
      if ($hasSummaryText -eq $hasLocator) { throw 'Final safe summary payload must contain exactly one SQL value.' }
      foreach ($hashName in @('CanonicalRequestSha256','ByteSha256','NormalizedContentSha256','DerivationFingerprint')) {
        $hashValue = $Parameters[$hashName].Value
        if ($hashValue -isnot [byte[]] -or $hashValue.Length -ne 32) {
          throw "Capture parameter '$hashName' is not an exact 32-byte array."
        }
      }
      $summaryHash = $Parameters.SummaryContentSha256.Value
      if ($null -ne $summaryHash -and ($summaryHash -isnot [byte[]] -or $summaryHash.Length -ne 32)) {
        throw "Capture parameter 'SummaryContentSha256' is neither null nor an exact 32-byte array."
      }
      [pscustomobject][ordered]@{
        ReplayStatus = 'Created'
        IdempotencyKey = $Parameters.IdempotencyKey.Value
        SourceArtifactId = $Parameters.SourceArtifactId.Value
        SourceArtifactVersionId = $Parameters.SourceArtifactVersionId.Value
        ContentSummaryId = $Parameters.ContentSummaryId.Value
        ContentSummaryVersionId = $Parameters.ContentSummaryVersionId.Value
        SourceArtifactVersionSequence = 1
        ContentSummaryVersionSequence = 1
        LifecycleCode = 'active'
        ErrorCode = $null
      }
    }
    default { throw "Unexpected procedure '$ProcedureName'." }
  }
}
$sqlAdapterSet = & $module {
  param($Invoker)
  New-ContentSummarySqlAdapterSetCore `
    -SqlConnection ([pscustomobject]@{ Kind = 'package-only-test-connection' }) `
    -CommandTimeoutSeconds 30 `
    -StoredProcedureInvoker $Invoker
} $storedProcedureInvoker
$repositoryId = [guid]'72000000-0000-0000-0000-000000000001'
$rootRegistrationId = [guid]'72000000-0000-0000-0000-000000000002'
$provisioned = & $sqlAdapterSet.ProvisionRepository `
  -RepositoryId $repositoryId `
  -RepositoryRootRegistrationId $rootRegistrationId `
  -CanonicalRepositoryName 'ATAP.Utilities' `
  -OriginUri 'HTTPS://GitHub.com/BillHertzing/ATAP.Utilities.git' `
  -CanonicalRoot 'C:\PackageOnly\Repository' `
  -RootKindCode 'sprint' `
  -OrganizationId ([guid]'72000000-0000-0000-0000-000000000003') `
  -ClassificationPolicyId ([guid]'72000000-0000-0000-0000-000000000004') `
  -PrincipalId ([guid]'72000000-0000-0000-0000-000000000005') `
  -EvidenceEntityId ([guid]'72000000-0000-0000-0000-000000000006') `
  -RecordedAtUtc ([datetimeoffset]'2026-09-05T12:00:00Z')
if ($provisioned.RepositoryId -ne $repositoryId -or $provisioned.OriginUri -cne 'https://github.com/BillHertzing/ATAP.Utilities.git') {
  throw 'Package-only repository adapter returned an unexpected acknowledgement.'
}
$idempotencyKey = [guid]'73000000-0000-0000-0000-000000000001'
$sourceArtifactId = [guid]'73000000-0000-0000-0000-000000000002'
$sourceArtifactVersionId = [guid]'73000000-0000-0000-0000-000000000003'
$contentSummaryId = [guid]'73000000-0000-0000-0000-000000000004'
$contentSummaryVersionId = [guid]'73000000-0000-0000-0000-000000000005'
$hashArguments = @{
  CanonicalRequestSha256 = [object[]](0..31)
  ByteSha256 = [byte[]](1..32)
  NormalizedContentSha256 = [object[]](2..33)
  SummaryContentSha256 = [byte[]](3..34)
  DerivationFingerprint = [object[]](4..35)
}
$captured = & $sqlAdapterSet.Capture `
  -IdempotencyKey $idempotencyKey `
  -SourceArtifactId $sourceArtifactId `
  -SourceArtifactVersionId $sourceArtifactVersionId `
  -ContentSummaryId $contentSummaryId `
  -ContentSummaryVersionId $contentSummaryVersionId `
  -LifecycleCode 'summarized' `
  -SafeSummaryText 'package-only summary' `
  -SafeLocator $null `
  -Dependencies @() `
  @hashArguments
if ($captured.IdempotencyKey -ne $idempotencyKey -or $captured.ContentSummaryVersionId -ne $contentSummaryVersionId) {
  throw 'Package-only capture adapter returned an unexpected acknowledgement.'
}
$hashArguments.SummaryContentSha256 = $null
& $sqlAdapterSet.Capture `
  -IdempotencyKey $idempotencyKey `
  -SourceArtifactId $sourceArtifactId `
  -SourceArtifactVersionId $sourceArtifactVersionId `
  -ContentSummaryId $contentSummaryId `
  -ContentSummaryVersionId $contentSummaryVersionId `
  -LifecycleCode 'summarized' `
  -SafeSummaryText 'package-only summary' `
  -SafeLocator $null `
  -Dependencies @() `
  @hashArguments | Out-Null
if ($null -ne $hashArguments.SummaryContentSha256) {
  throw 'Package-only nullable binary fixture changed unexpectedly.'
}
$hashArguments.SummaryContentSha256 = [byte[]](3..34)
& $sqlAdapterSet.Capture `
  -IdempotencyKey $idempotencyKey `
  -SourceArtifactId $sourceArtifactId `
  -SourceArtifactVersionId $sourceArtifactVersionId `
  -ContentSummaryId $contentSummaryId `
  -ContentSummaryVersionId $contentSummaryVersionId `
  -LifecycleCode 'summarized' `
  -SafeSummaryText $null `
  -SafeLocator 'https://example.test/summaries/package-only' `
  -Dependencies @() `
  @hashArguments | Out-Null
$validated = Read-ContentSummaryRepositoryInventory -Path $InventoryPath -ExpectedSha256 $InventorySha
$adapterSet = [pscustomobject][ordered]@{
  SchemaVersion = 1
  Capture = { throw 'Capture must not run during inventory WhatIf.' }
  ProvisionRepository = { throw 'ProvisionRepository must not run during inventory WhatIf.' }
  AssignContentSummaryVersionTag = { throw 'AssignContentSummaryVersionTag must not run during inventory WhatIf.' }
  AuthorizeRepository = { throw 'AuthorizeRepository must not run during inventory WhatIf.' }
}
$planned = Invoke-ContentSummaryRepositoryInventory `
  -Path $InventoryPath `
  -ExpectedSha256 $InventorySha `
  -AdapterSet $adapterSet `
  -WhatIf
if ($validated.Repositories.Count -ne 1 -or
  $planned.Status -cne 'WhatIf' -or
  $planned.PlannedRepositoryCount -ne 1 -or
  $planned.PlannedAuthorizationCount -ne 1) {
  throw 'Package-only inventory execution returned an unexpected result.'
}

$result = [ordered]@{
  ModuleBase = $module.ModuleBase
  InventorySha256 = $validated.InventorySha256
  Status = $planned.Status
  PrivateFunctionCount = $privateFunctionNames.Count
}
[IO.File]::WriteAllText(
  $ResultPath,
  ($result | ConvertTo-Json -Compress),
  [Text.UTF8Encoding]::new($false)
)