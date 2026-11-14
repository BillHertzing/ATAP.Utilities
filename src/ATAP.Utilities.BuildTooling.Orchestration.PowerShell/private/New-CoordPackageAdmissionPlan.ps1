# Pure planner for PackageAdmissionPlan-v1 (0.1.17 design C2/C3, slice 1).
# Builds a deterministic package-only custody transition from byte images and data.
# No settings, paths, locks, clocks, signatures or writes are opened: the caller supplies
# the attestation as an object (slice 3 verifies it) and the admission timestamp.
# Reuses helpers from CoordProducerJson.ps1 and New-CoordSuccessorCustodyPlan.ps1.

function ConvertTo-PackageAdmissionSortedValue {
  # Canonical ordering so the same attestation always yields the same digest, whatever the
  # caller's hashtable enumeration order. Object members sort ordinally; arrays keep order.
  param([AllowNull()]$Value)
  if ($null -eq $Value) { return $null }
  if ($Value -is [Collections.IDictionary]) {
    $sorted = [ordered]@{}
    $keys = [string[]]@($Value.Keys | ForEach-Object { [string]$_ })
    [Array]::Sort($keys, [StringComparer]::Ordinal)
    foreach ($key in $keys) { $sorted[$key] = ConvertTo-PackageAdmissionSortedValue $Value[$key] }
    return $sorted
  }
  if ($Value -is [string]) { return $Value }
  if ($Value -is [Collections.IEnumerable]) {
    return ,@(foreach ($item in $Value) { ConvertTo-PackageAdmissionSortedValue $item })
  }
  if ($Value -is [pscustomobject]) {
    $table = [ordered]@{}
    foreach ($property in $Value.PSObject.Properties) { $table[$property.Name] = $property.Value }
    return ConvertTo-PackageAdmissionSortedValue $table
  }
  return $Value
}

function Get-PackageAdmissionVersion {
  param([string]$Text, [string]$ErrorCode)
  $parsed = $null
  if ([string]::IsNullOrWhiteSpace($Text) -or -not [version]::TryParse($Text, [ref]$parsed) -or
      -not [StringComparer]::Ordinal.Equals($Text, $parsed.ToString())) { throw $ErrorCode }
  $parsed
}

function New-CoordPackageAdmissionPlan {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][byte[]]$StateBytes,
    [Parameter(Mandatory)][byte[]]$WitnessBytes,
    [Parameter(Mandatory)][byte[]]$StateSchemaBytes,
    [Parameter(Mandatory)][System.Collections.IDictionary]$Attestation,
    [Parameter(Mandatory)][string]$ObservedSid,
    [Parameter(Mandatory)][string]$OperationId,
    [Parameter(Mandatory)][string]$AdmittedAtUtc
  )

  # Private snapshots: do not retain caller-owned arrays.
  $StateBytes = [byte[]]$StateBytes.Clone()
  $WitnessBytes = [byte[]]$WitnessBytes.Clone()
  $StateSchemaBytes = [byte[]]$StateSchemaBytes.Clone()
  $ordinal = [StringComparer]::Ordinal
  $hex64 = '\A[0-9a-f]{64}\z'

  $parsedOperationId = [guid]::Empty
  if (-not [guid]::TryParseExact($OperationId, 'D', [ref]$parsedOperationId) -or $parsedOperationId -eq [guid]::Empty) {
    throw 'InvalidPackageAdmissionOperationId'
  }
  $parsedTime = [DateTimeOffset]::MinValue
  if (-not [DateTimeOffset]::TryParseExact($AdmittedAtUtc, 'yyyy-MM-ddTHH:mm:ss.fffffffZ',
      [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal -bor [Globalization.DateTimeStyles]::AdjustToUniversal,
      [ref]$parsedTime)) { throw 'InvalidPackageAdmissionTimestamp' }

  $stateDigest = Get-CoordHash $StateBytes
  $witnessDigest = Get-CoordHash $WitnessBytes
  $schema = [Text.UTF8Encoding]::new($false, $true).GetString($StateSchemaBytes)
  $state = Read-CoordJsonBytes $StateBytes
  $witness = Read-CoordJsonBytes $WitnessBytes
  if (-not (Test-Json -Json $state.GetRawText() -Schema $schema -ErrorAction SilentlyContinue)) { throw 'InvalidBeforeState' }

  # Custody binding, same checks the successor planner makes on the current pair.
  if (-not $ordinal.Equals($ObservedSid, (Get-SuccessorPlanText $witness 'custodianSid'))) { throw 'CustodianSidMismatch' }
  if (-not $ordinal.Equals((Get-SuccessorPlanText $witness 'schemaVersion'), 'Coordination-custody-v1') -or
      -not $ordinal.Equals((Get-SuccessorPlanText $witness 'admissionMode'), 'Established') -or
      -not $ordinal.Equals((Get-SuccessorPlanText $witness 'stateSha256'), $stateDigest)) { throw 'CustodyBindingConflict' }
  foreach ($name in 'resourceId', 'lineageId', 'generation') {
    if (-not $ordinal.Equals((Get-SuccessorPlanText $state $name), (Get-SuccessorPlanText $witness $name))) {
      throw "CustodyBindingConflict"
    }
  }

  # In-flight work: only an unfinished write or operation blocks. Settled claims and
  # reservations survive a package-only swap because state.json is not touched.
  if ($witness.GetProperty('pendingWrite').ValueKind -ne [Text.Json.JsonValueKind]::Null) { throw 'PendingWritePresent' }
  foreach ($collection in 'requests', 'preparedOperations') {
    foreach ($entry in $state.GetProperty($collection).EnumerateArray()) {
      $status = $entry.GetProperty('status').GetString()
      if ($ordinal.Equals($status, 'Prepared') -or $ordinal.Equals($status, 'NeedsRecovery')) { throw 'OperationInFlight' }
    }
  }

  # A held or recovering resource waits: a package swap must not be looser than a full handoff.
  if (-not $ordinal.Equals($state.GetProperty('mutationAdmission').GetProperty('status').GetString(), 'Admitted')) { throw 'MutationNotAdmitted' }

  # Standing policy (custody.autoPackageAdmission).
  $policy = [Text.Json.JsonElement]::new()
  if (-not $witness.TryGetProperty('autoPackageAdmission', [ref]$policy) -or
      $policy.ValueKind -eq [Text.Json.JsonValueKind]::Null) { throw 'PackagePolicyAbsent' }
  Assert-SuccessorPlanObject $policy @('enabled', 'signer', 'minVersion', 'schemaHashes', 'semanticRevision') 'InvalidPackagePolicy'
  $enabled = $policy.GetProperty('enabled')
  if ($enabled.ValueKind -ne [Text.Json.JsonValueKind]::True -and $enabled.ValueKind -ne [Text.Json.JsonValueKind]::False) { throw 'InvalidPackagePolicy' }
  if ($enabled.ValueKind -eq [Text.Json.JsonValueKind]::False) { throw 'PackagePolicyDisabled' }
  $policySigner = Get-SuccessorPlanText $policy 'signer'
  $policyRevision = Get-SuccessorPlanText $policy 'semanticRevision'
  $policyMinVersion = Get-PackageAdmissionVersion (Get-SuccessorPlanText $policy 'minVersion') 'InvalidPackagePolicy'
  $policyHashes = $policy.GetProperty('schemaHashes')
  Assert-SuccessorPlanObject $policyHashes @('state', 'request', 'result') 'InvalidPackagePolicy'
  foreach ($name in 'state', 'request', 'result') {
    if ((Get-SuccessorPlanText $policyHashes $name) -cnotmatch $hex64) { throw 'InvalidPackagePolicy' }
  }

  # Attestation: caller-supplied object, canonically ordered so its digest is stable.
  $attestationBytes = ConvertTo-SuccessorPlanBytes (ConvertTo-PackageAdmissionSortedValue $Attestation)
  $attestationDigest = Get-CoordHash $attestationBytes
  $attestationElement = Read-CoordJsonBytes $attestationBytes
  # Member set matches schemas/package-attestation-v1.schema.json (slice 3). The planner does
  # not re-verify signatures or receipts; it consumes an attestation already verified there.
  Assert-SuccessorPlanObject $attestationElement @('kind', 'moduleName', 'moduleVersion', 'archiveSha256', 'files', 'signerThumbprint',
    'stateSchemaSha256', 'requestSchemaSha256', 'resultSchemaSha256', 'coordinationSemanticRevision', 'buildId', 'executionIds',
    'finalProductionTestReceiptSha256', 'tierReceiptSha256', 'createdUtc') 'InvalidPackageAttestation'
  if (-not $ordinal.Equals((Get-SuccessorPlanText $attestationElement 'kind'), 'Coordination-package-attestation-v1') -or
      -not $ordinal.Equals((Get-SuccessorPlanText $attestationElement 'moduleName'), 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell')) {
    throw 'InvalidPackageAttestation'
  }
  $hex64Any = '\A[0-9A-Fa-f]{64}\z'
  foreach ($name in 'archiveSha256', 'stateSchemaSha256', 'requestSchemaSha256', 'resultSchemaSha256', 'finalProductionTestReceiptSha256') {
    if ((Get-SuccessorPlanText $attestationElement $name) -cnotmatch $hex64Any) { throw 'InvalidPackageAttestation' }
  }
  if ((Get-SuccessorPlanText $attestationElement 'signerThumbprint') -cnotmatch '\A[0-9A-Fa-f]{40}\z') { throw 'InvalidPackageAttestation' }
  foreach ($name in 'coordinationSemanticRevision', 'buildId', 'createdUtc') { $null = Get-SuccessorPlanText $attestationElement $name }
  $executionIds = $attestationElement.GetProperty('executionIds')
  if ($executionIds.ValueKind -ne [Text.Json.JsonValueKind]::Array -or $executionIds.GetArrayLength() -eq 0) { throw 'InvalidPackageAttestation' }
  foreach ($id in $executionIds.EnumerateArray()) {
    if ($id.ValueKind -ne [Text.Json.JsonValueKind]::String -or [string]::IsNullOrWhiteSpace($id.GetString())) { throw 'InvalidPackageAttestation' }
  }
  $tiers = $attestationElement.GetProperty('tierReceiptSha256')
  if ($tiers.ValueKind -ne [Text.Json.JsonValueKind]::Object -or @($tiers.EnumerateObject()).Count -eq 0) { throw 'InvalidPackageAttestation' }
  foreach ($tier in $tiers.EnumerateObject()) {
    if ($tier.Value.ValueKind -ne [Text.Json.JsonValueKind]::String -or $tier.Value.GetString() -cnotmatch $hex64Any) { throw 'InvalidPackageAttestation' }
  }
  # Attestation files are {path, sha256, size}; custody inventories are {path, digest} with lowercase hex.
  $attestedFiles = $attestationElement.GetProperty('files')
  if ($attestedFiles.ValueKind -ne [Text.Json.JsonValueKind]::Array -or $attestedFiles.GetArrayLength() -eq 0) { throw 'InvalidPackageAttestation' }
  $inventoryFiles = [Collections.Generic.List[object]]::new()
  foreach ($file in $attestedFiles.EnumerateArray()) {
    Assert-SuccessorPlanObject $file @('path', 'sha256', 'size') 'InvalidPackageAttestation'
    if ($file.GetProperty('size').ValueKind -ne [Text.Json.JsonValueKind]::Number) { throw 'InvalidPackageAttestation' }
    $digest = (Get-SuccessorPlanText $file 'sha256')
    if ($digest -cnotmatch $hex64Any) { throw 'InvalidPackageAttestation' }
    $inventoryFiles.Add([ordered]@{ path = (Get-SuccessorPlanText $file 'path'); digest = $digest.ToLowerInvariant() })
  }
  # The schema bytes the caller used to validate state must be the policy's state schema.
  if (-not $ordinal.Equals((Get-CoordHash $StateSchemaBytes), (Get-SuccessorPlanText $policyHashes 'state')) -or
      -not $ordinal.Equals((Get-SuccessorPlanText $attestationElement 'stateSchemaSha256').ToLowerInvariant(), (Get-SuccessorPlanText $policyHashes 'state')) -or
      -not $ordinal.Equals((Get-SuccessorPlanText $attestationElement 'requestSchemaSha256').ToLowerInvariant(), (Get-SuccessorPlanText $policyHashes 'request')) -or
      -not $ordinal.Equals((Get-SuccessorPlanText $attestationElement 'resultSchemaSha256').ToLowerInvariant(), (Get-SuccessorPlanText $policyHashes 'result'))) {
    throw 'SchemaHashMismatch'
  }
  if (-not $ordinal.Equals((Get-SuccessorPlanText $attestationElement 'coordinationSemanticRevision'), $policyRevision)) {
    throw 'SemanticRevisionMismatch'
  }
  if (-not [StringComparer]::OrdinalIgnoreCase.Equals((Get-SuccessorPlanText $attestationElement 'signerThumbprint'), $policySigner)) { throw 'PackageSignerMismatch' }

  # Version ordering: strictly newer than current custody, and at least the policy minimum.
  $oldPackage = $witness.GetProperty('package')
  $oldVersion = Get-PackageAdmissionVersion (Get-SuccessorPlanText $oldPackage 'moduleVersion') 'InvalidCustodyPackage'
  $newVersion = Get-PackageAdmissionVersion (Get-SuccessorPlanText $attestationElement 'moduleVersion') 'InvalidPackageAttestation'
  if ($newVersion -le $oldVersion) { throw 'PackageNotNewer' }
  if ($newVersion -lt $policyMinVersion) { throw 'PackageBelowMinVersion' }

  # The new inventory is the attestation's, validated with the successor planner's grammar.
  $newPackage = [ordered]@{
    moduleVersion = (Get-SuccessorPlanText $attestationElement 'moduleVersion')
    files = $inventoryFiles.ToArray()
  }
  $newPackageElement = ConvertTo-CoordElement $newPackage
  try { Assert-SuccessorPackageInventory $newPackageElement (Get-SuccessorPlanText $policyHashes 'state') }
  catch { throw 'InvalidPackageAttestation' }
  $oldPackageDigest = Get-CoordHash ([Text.Encoding]::UTF8.GetBytes($oldPackage.GetRawText()))
  $newPackageDigest = Get-CoordHash ([Text.Encoding]::UTF8.GetBytes($newPackageElement.GetRawText()))

  # History: append-only, the only addition besides the package.
  $history = [Collections.Generic.List[object]]::new()
  $existing = [Text.Json.JsonElement]::new()
  if ($witness.TryGetProperty('history', [ref]$existing)) {
    if ($existing.ValueKind -ne [Text.Json.JsonValueKind]::Array) { throw 'InvalidCustodyHistory' }
    foreach ($item in $existing.EnumerateArray()) { $history.Add($item.Clone()) }
  }
  $history.Add([ordered]@{
    kind = 'PackageAdmission-v1'; operationId = $OperationId; admittedAtUtc = $AdmittedAtUtc
    generation = (Get-SuccessorPlanText $witness 'generation')
    fromVersion = (Get-SuccessorPlanText $oldPackage 'moduleVersion'); toVersion = (Get-SuccessorPlanText $attestationElement 'moduleVersion')
    fromPackageSha256 = $oldPackageDigest; toPackageSha256 = $newPackageDigest
    attestationSha256 = $attestationDigest; archiveSha256 = (Get-SuccessorPlanText $attestationElement 'archiveSha256').ToLowerInvariant()
    signer = $policySigner; semanticRevision = $policyRevision
    buildId = (Get-SuccessorPlanText $attestationElement 'buildId'); executionIds = @(foreach ($id in $executionIds.EnumerateArray()) { $id.GetString() })
    finalProductionTestReceiptSha256 = (Get-SuccessorPlanText $attestationElement 'finalProductionTestReceiptSha256').ToLowerInvariant()
  })

  $witnessTarget = Get-CoordMembers $witness
  $witnessTarget.package = $newPackageElement
  $witnessTarget.history = $history.ToArray()
  $targetWitness = ConvertTo-SuccessorPlanBytes $witnessTarget
  $targetWitnessDigest = Get-CoordHash $targetWitness

  # Fence: pendingWrite marker only, so a crash between writes is recoverable. Actors, state
  # and generation are untouched. State bytes are identical in every pair.
  $fence = Get-CoordMembers $witness
  $fence.pendingWrite = [ordered]@{
    kind = 'PackageAdmission'; operationId = $OperationId; attestationDigest = $attestationDigest
    targetStateDigest = $stateDigest; targetWitnessDigest = $targetWitnessDigest
  }
  $fencedWitness = ConvertTo-SuccessorPlanBytes $fence
  $fenceDigest = Get-CoordHash $fencedWitness
  [pscustomobject]@{
    Status = 'PlannedOnly'; Kind = 'PackageAdmissionPlan-v1'
    StateChanged = $false; GenerationChanged = $false
    FromVersion = (Get-SuccessorPlanText $oldPackage 'moduleVersion'); ToVersion = (Get-SuccessorPlanText $attestationElement 'moduleVersion')
    AttestationSha256 = $attestationDigest
    FencedWitness = $fencedWitness; TargetWitness = $targetWitness
    Pairs = [ordered]@{
      Before = @{ State = $stateDigest; Witness = $witnessDigest }
      Fenced = @{ State = $stateDigest; Witness = $fenceDigest }
      Target = @{ State = $stateDigest; Witness = $targetWitnessDigest }
    }
  }
}


