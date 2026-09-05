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

$storedProcedureInvoker = {
  param($SqlConnection,$ProcedureName,$Parameters,$ResultPropertyOrder,$AllowedStatusCodes,$StatusPropertyName,$CommandTimeoutSeconds)
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
$captured = & $sqlAdapterSet.Capture `
  -IdempotencyKey $idempotencyKey `
  -SourceArtifactId $sourceArtifactId `
  -SourceArtifactVersionId $sourceArtifactVersionId `
  -ContentSummaryId $contentSummaryId `
  -ContentSummaryVersionId $contentSummaryVersionId `
  -Dependencies @()
if ($captured.IdempotencyKey -ne $idempotencyKey -or $captured.ContentSummaryVersionId -ne $contentSummaryVersionId) {
  throw 'Package-only capture adapter returned an unexpected acknowledgement.'
}

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