# Pure planner candidate for C2062. Caller supplies the reviewed JSON/hash
# helpers and the pure Assert-CoordActorRetirement from the producer source.
# All inputs are byte images or data. No settings, paths, locks or writes are opened.

function Get-SuccessorPlanText {
  param([Text.Json.JsonElement]$Record, [string]$Name)
  $value = [Text.Json.JsonElement]::new()
  if ($Record.ValueKind -ne [Text.Json.JsonValueKind]::Object -or
      -not $Record.TryGetProperty($Name, [ref]$value) -or
      $value.ValueKind -ne [Text.Json.JsonValueKind]::String -or
      [string]::IsNullOrWhiteSpace($value.GetString())) { throw "InvalidSuccessorField:$Name" }
  $value.GetString()
}

function ConvertTo-SuccessorPlanBytes {
  param($Members)
  return ,([Text.Encoding]::UTF8.GetBytes((ConvertTo-CoordElement $Members).GetRawText()))
}


function Assert-SuccessorPlanObject {
  param([Text.Json.JsonElement]$Value, [string[]]$Members, [string]$ErrorCode)
  if ($Value.ValueKind -ne [Text.Json.JsonValueKind]::Object -or
      @($Value.EnumerateObject()).Count -ne $Members.Count) { throw $ErrorCode }
  foreach ($name in $Members) {
    $property = [Text.Json.JsonElement]::new()
    if (-not $Value.TryGetProperty($name, [ref]$property)) { throw $ErrorCode }
  }
}

function Assert-SuccessorPackageInventory {
  param([Text.Json.JsonElement]$Package, [string]$ReviewedStateSchema)
  Assert-SuccessorPlanObject $Package @('moduleVersion', 'files') 'InvalidSuccessorPackage'
  $version = Get-SuccessorPlanText $Package 'moduleVersion'
  $parsedVersion = $null
  if (-not [version]::TryParse($version, [ref]$parsedVersion) -or
      -not [StringComparer]::Ordinal.Equals($version, $parsedVersion.ToString())) { throw 'InvalidSuccessorPackage' }

  $files = $Package.GetProperty('files')
  if ($files.ValueKind -ne [Text.Json.JsonValueKind]::Array -or $files.GetArrayLength() -eq 0) {
    throw 'InvalidSuccessorPackage'
  }
  $physicalNames = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  $consumerNames = [Collections.Generic.HashSet[string]]::new([StringComparer]::InvariantCulture)
  $schemaPinned = $false
  foreach ($file in $files.EnumerateArray()) {
    Assert-SuccessorPlanObject $file @('path', 'digest') 'InvalidSuccessorPackage'
    $path = Get-SuccessorPlanText $file 'path'
    $digest = Get-SuccessorPlanText $file 'digest'
    # Match the producer's slash-normalized relative inventory grammar without opening paths.
    if ($digest -cnotmatch '\A[0-9a-f]{64}\z' -or $path -match '[\\:<>"|?*~\p{C}]' -or
        $path -match '\Atests/' -or $path -notmatch '\.(?:ps1|psm1|psd1|json)\z') { throw 'InvalidSuccessorPackage' }
    foreach ($segment in $path.Split('/')) {
      if ([string]::IsNullOrWhiteSpace($segment) -or $segment -cne $segment.Trim() -or
          $segment.EndsWith('.') -or $segment -match '\A(?:CON|PRN|AUX|NUL|COM[1-9¹²³]|LPT[1-9¹²³])(?:\.|\z)') {
        throw 'InvalidSuccessorPackage'
      }
    }
    if (-not $physicalNames.Add($path) -or -not $consumerNames.Add($path)) { throw 'InvalidSuccessorPackage' }
    if ([StringComparer]::Ordinal.Equals($path, 'schemas/state-v1.schema.json')) {
      $schemaPinned = [StringComparer]::Ordinal.Equals($digest, $ReviewedStateSchema)
    }
  }
  if (-not $schemaPinned) { throw 'SuccessorPackageSchemaMismatch' }
}

function Get-SuccessorPlanIntentKind {
  param([Text.Json.JsonElement]$Intent)
  $kind = Get-SuccessorPlanText $Intent 'kind'
  $ordinal = [StringComparer]::Ordinal
  $retirements = [Text.Json.JsonElement]::new()
  if ($ordinal.Equals($kind, 'SuccessorCustodyPlan-v1')) {
    if ($Intent.TryGetProperty('retiredActors', [ref]$retirements)) { throw 'UnexpectedRetirementBindings' }
  } elseif ($ordinal.Equals($kind, 'SuccessorCustodyPlan-v2')) {
    if (-not $Intent.TryGetProperty('retiredActors', [ref]$retirements) -or
        $retirements.ValueKind -ne [Text.Json.JsonValueKind]::Array -or
        $retirements.GetArrayLength() -ne 2) { throw 'InvalidRetirementBindings' }
  } else {
    throw 'UnsupportedSuccessorIntent'
  }
  $kind
}

function New-CoordSuccessorCustodyPlan {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][byte[]]$IntentBytes,
    [Parameter(Mandatory)][string]$ExpectedIntentSha256,
    [Parameter(Mandatory)][byte[]]$StateBytes,
    [Parameter(Mandatory)][byte[]]$WitnessBytes,
    [Parameter(Mandatory)][byte[]]$TargetPackageBytes,
    [Parameter(Mandatory)][byte[]]$StateSchemaBytes,
    [Parameter(Mandatory)][System.Collections.IDictionary]$Quartet,
    [Parameter(Mandatory)][string]$ObservedSid
  )

  # Hash and parse the same private snapshots. Do not retain caller-owned arrays.
  $IntentBytes = [byte[]]$IntentBytes.Clone()
  $StateBytes = [byte[]]$StateBytes.Clone()
  $WitnessBytes = [byte[]]$WitnessBytes.Clone()
  $TargetPackageBytes = [byte[]]$TargetPackageBytes.Clone()
  $StateSchemaBytes = [byte[]]$StateSchemaBytes.Clone()
  $ordinal = [StringComparer]::Ordinal
  $sessionComparer = [StringComparer]::OrdinalIgnoreCase
  if (-not $ordinal.Equals((Get-CoordHash $IntentBytes), $ExpectedIntentSha256)) { throw 'IntentPinMismatch' }
  $intent = Read-CoordJsonBytes $IntentBytes
  $intentKind = Get-SuccessorPlanIntentKind $intent
  $stateDigest = Get-CoordHash $StateBytes
  $witnessDigest = Get-CoordHash $WitnessBytes
  if (-not $ordinal.Equals($stateDigest, (Get-SuccessorPlanText $intent 'beforeStateSha256')) -or
      -not $ordinal.Equals($witnessDigest, (Get-SuccessorPlanText $intent 'beforeWitnessSha256'))) { throw 'SnapshotMismatch' }
  # Independent review pin. An intent naming a different schema cannot authorize it.
  $reviewedStateSchema = '4f148321844e3f2970c7190d79fb4371e609a62bef093e43a7adb855c9bb9bfa'
  if (-not $ordinal.Equals((Get-CoordHash $StateSchemaBytes), $reviewedStateSchema) -or
      -not $ordinal.Equals((Get-SuccessorPlanText $intent 'stateSchemaSha256'), $reviewedStateSchema)) {
    throw 'StateSchemaPinMismatch'
  }
  if (-not $ordinal.Equals((Get-CoordHash $TargetPackageBytes), (Get-SuccessorPlanText $intent 'targetPackageSha256'))) { throw 'TargetPackagePinMismatch' }

  $schema = [Text.UTF8Encoding]::new($false, $true).GetString($StateSchemaBytes)
  $state = Read-CoordJsonBytes $StateBytes
  $witness = Read-CoordJsonBytes $WitnessBytes
  $package = Read-CoordJsonBytes $TargetPackageBytes
  if (-not $ordinal.Equals((Get-CoordHash ([Text.Encoding]::UTF8.GetBytes($package.GetRawText()))),
      (Get-SuccessorPlanText $intent 'targetPackageSha256'))) { throw 'TargetPackageImageMismatch' }
  if (-not (Test-Json -Json $state.GetRawText() -Schema $schema -ErrorAction SilentlyContinue)) { throw 'InvalidBeforeState' }

  $operationId = Get-SuccessorPlanText $intent 'operationId'
  $custodianSid = Get-SuccessorPlanText $intent 'custodianSid'
  if (-not $ordinal.Equals($ObservedSid, $custodianSid) -or
      -not $ordinal.Equals((Get-SuccessorPlanText $witness 'custodianSid'), $custodianSid)) { throw 'CustodianSidMismatch' }
  foreach ($name in 'resourceId', 'lineageId', 'generation') {
    $expected = Get-SuccessorPlanText $intent $name
    if (-not $ordinal.Equals((Get-SuccessorPlanText $state $name), $expected) -or
        -not $ordinal.Equals((Get-SuccessorPlanText $witness $name), $expected)) { throw "SuccessorBindingMismatch:$name" }
  }
  foreach ($name in 'statePath', 'boardLockPath') {
    if (-not $ordinal.Equals((Get-SuccessorPlanText $witness $name), (Get-SuccessorPlanText $intent $name))) {
      throw "SuccessorBindingMismatch:$name"
    }
  }
  if (-not $ordinal.Equals((Get-SuccessorPlanText $state 'committedRevision'), (Get-SuccessorPlanText $intent 'committedRevision'))) {
    throw 'SuccessorBindingMismatch:committedRevision'
  }
  if (-not $ordinal.Equals((Get-SuccessorPlanText $witness 'schemaVersion'), 'Coordination-custody-v1') -or
      -not $ordinal.Equals((Get-SuccessorPlanText $witness 'admissionMode'), 'Established') -or
      -not $ordinal.Equals((Get-SuccessorPlanText $witness 'stateSha256'), $stateDigest)) { throw 'CustodyBindingConflict' }
  if ($witness.GetProperty('pendingWrite').ValueKind -ne [Text.Json.JsonValueKind]::Null -or
      -not $ordinal.Equals($state.GetProperty('mutationAdmission').GetProperty('status').GetString(), 'Admitted') -or
      $state.GetProperty('claims').GetArrayLength() -ne 0 -or $state.GetProperty('reservations').GetArrayLength() -ne 0) {
    throw 'SuccessorWorkPending'
  }
  foreach ($collection in 'requests', 'preparedOperations') {
    foreach ($entry in $state.GetProperty($collection).EnumerateArray()) {
      $status = $entry.GetProperty('status').GetString()
      if (-not $ordinal.Equals($status, 'Applied') -and -not $ordinal.Equals($status, 'Rejected')) { throw 'SuccessorWorkPending' }
    }
  }
  $oldPackage = $witness.GetProperty('package')
  if (-not $ordinal.Equals((Get-CoordHash ([Text.Encoding]::UTF8.GetBytes($oldPackage.GetRawText()))), (Get-SuccessorPlanText $intent 'oldPackageSha256'))) {
    throw 'OldPackagePinMismatch'
  }
  Assert-SuccessorPackageInventory $package $reviewedStateSchema
  if ((Get-SuccessorPlanText $oldPackage 'moduleVersion') -ceq (Get-SuccessorPlanText $package 'moduleVersion')) {
    throw 'InvalidSuccessorPackage'
  }

  $manifest = $state.GetProperty('committedOutputManifest')
  $slots = @('markdown', 'boardHtml', 'proceduralDetailsHtml', 'accomplishedHtml')
  if ($Quartet.Count -ne $slots.Count) { throw 'QuartetPinMismatch' }
  foreach ($slot in $slots) {
    $image = $Quartet[$slot]
    if ([Array]::IndexOf([string[]]@($Quartet.Keys), $slot) -lt 0 -or $image -isnot [byte[]] -or
        -not $ordinal.Equals((Get-CoordHash ([byte[]]$image.Clone())), $manifest.GetProperty($slot).GetProperty('digest').GetString())) {
      throw "QuartetPinMismatch:$slot"
    }
  }

  $generation = Get-SuccessorPlanText $intent 'generation'
  $nextGeneration = Get-SuccessorPlanText $intent 'nextGeneration'
  $usedGenerations = [Collections.Generic.HashSet[string]]::new($ordinal)
  $null = $usedGenerations.Add($generation)
  foreach ($entry in $state.GetProperty('requests').EnumerateArray()) {
    $request = $entry.GetProperty('request')
    $oldGeneration = [Text.Json.JsonElement]::new()
    if ($request.TryGetProperty('generation', [ref]$oldGeneration) -and $oldGeneration.ValueKind -eq [Text.Json.JsonValueKind]::String) {
      $null = $usedGenerations.Add($oldGeneration.GetString())
    }
  }
  foreach ($entry in $state.GetProperty('preparedOperations').EnumerateArray()) {
    $null = $usedGenerations.Add($entry.GetProperty('baseHead').GetProperty('generation').GetString())
  }
  foreach ($entry in $state.GetProperty('commitReceipts').EnumerateArray()) {
    $null = $usedGenerations.Add($entry.GetProperty('generation').GetString())
  }
  # This is caller-supplied history carried by the pinned intent. Authenticity
  # and completeness of the external custody receipt chain belong to the caller.
  $priorCustodyGenerations = $intent.GetProperty('priorCustodyGenerations')
  if ($priorCustodyGenerations.ValueKind -ne [Text.Json.JsonValueKind]::Array) { throw 'InvalidPriorCustodyGenerations' }
  foreach ($entry in $priorCustodyGenerations.EnumerateArray()) {
    if ($entry.ValueKind -ne [Text.Json.JsonValueKind]::String -or [string]::IsNullOrWhiteSpace($entry.GetString())) {
      throw 'InvalidPriorCustodyGenerations'
    }
    $null = $usedGenerations.Add($entry.GetString())
  }
  foreach ($used in $usedGenerations) {
    # Submit and Clerk currently use linguistic -cne, including ignorable characters.
    if ($ordinal.Equals($used, $nextGeneration) -or $used -ceq $nextGeneration) { throw 'GenerationNotFresh' }
  }
  if ($nextGeneration -cnotmatch '\Aepoch-[0-9a-f]{32}\z' -or
      $ordinal.Equals($nextGeneration, 'epoch-00000000000000000000000000000000')) { throw 'InvalidNextGeneration' }

  # Reject legacy lookalike keys before adding a canonical retiredActors member.
  # Linguistic equality is used only to deny ambiguous names, never to admit them.
  foreach ($property in $witness.EnumerateObject()) {
    if (-not $ordinal.Equals($property.Name, 'retiredActors') -and
        [Globalization.CultureInfo]::InvariantCulture.CompareInfo.Compare(
          $property.Name, 'retiredActors', [Globalization.CompareOptions]::IgnoreCase) -eq 0) {
      throw 'AmbiguousRetirementProperty'
    }
  }
  Assert-CoordActorRetirement $witness $custodianSid
  $holder = Get-SuccessorPlanText $intent 'holderId'
  $oldSession = Get-SuccessorPlanText $intent 'outgoingSessionId'
  $nextSession = Get-SuccessorPlanText $intent 'successorSessionId'
  if (-not $ordinal.Equals((Get-SuccessorPlanText $witness 'coordinatorId'), $holder) -or
      $sessionComparer.Equals($oldSession, $nextSession)) { throw 'SuccessorActorMismatch' }

  # V2 binds one outgoing Coordinator and one Worker in the pinned intent.
  $actorFields = @('holderId', 'sessionId', 'windowsSid', 'role')
  $requiredRetirements = [Collections.Generic.Dictionary[string, Text.Json.JsonElement]]::new($ordinal)
  if ($ordinal.Equals($intentKind, 'SuccessorCustodyPlan-v2')) {
    $requiredRoles = [Collections.Generic.HashSet[string]]::new($ordinal)
    foreach ($entry in $intent.GetProperty('retiredActors').EnumerateArray()) {
      Assert-SuccessorPlanObject $entry $actorFields 'InvalidRetirementBindings'
      $entryHolder = Get-SuccessorPlanText $entry 'holderId'
      $entrySession = Get-SuccessorPlanText $entry 'sessionId'
      $entrySid = Get-SuccessorPlanText $entry 'windowsSid'
      $entryRole = Get-SuccessorPlanText $entry 'role'
      if ((-not $ordinal.Equals($entryRole, 'Coordinator') -and -not $ordinal.Equals($entryRole, 'Worker')) -or
          -not $requiredRoles.Add($entryRole) -or -not $ordinal.Equals($entrySid, $custodianSid) -or
          $sessionComparer.Equals($entrySession, $nextSession) -or
          -not $requiredRetirements.TryAdd($entrySession, $entry)) { throw 'InvalidRetirementBindings' }
      if ($ordinal.Equals($entryRole, 'Coordinator') -and
          (-not $ordinal.Equals($entryHolder, $holder) -or -not $ordinal.Equals($entrySession, $oldSession))) {
        throw 'RetirementBindingMismatch'
      }
    }
  }

  $actors = $witness.GetProperty('actors')
  $active = [Collections.Generic.List[object]]::new()
  $activeSessions = [Collections.Generic.HashSet[string]]::new($sessionComparer)
  $outgoing = $null
  $retiredWorkers = [Collections.Generic.List[object]]::new()
  foreach ($actor in $actors.EnumerateArray()) {
    $actorHolder = Get-SuccessorPlanText $actor 'holderId'
    $actorSession = Get-SuccessorPlanText $actor 'sessionId'
    $actorSid = Get-SuccessorPlanText $actor 'windowsSid'
    $role = Get-SuccessorPlanText $actor 'role'
    if (@($actor.EnumerateObject()).Count -ne 4 -or -not $ordinal.Equals($actorSid, $custodianSid) -or
        -not $activeSessions.Add($actorSession) -or $sessionComparer.Equals($actorSession, $nextSession)) { throw 'SuccessorActorMismatch' }
    $retirement = [Text.Json.JsonElement]::new()
    $retireActor = $requiredRetirements.TryGetValue($actorSession, [ref]$retirement)
    if ($retireActor) {
      foreach ($field in $actorFields) {
        if (-not $ordinal.Equals((Get-SuccessorPlanText $actor $field), (Get-SuccessorPlanText $retirement $field))) {
          throw 'RetirementBindingMismatch'
        }
      }
      $null = $requiredRetirements.Remove($actorSession)
    }
    if ($ordinal.Equals($role, 'Coordinator')) {
      if ($null -ne $outgoing -or -not $ordinal.Equals($actorHolder, $holder) -or
          -not $ordinal.Equals($actorSession, $oldSession)) { throw 'SuccessorActorMismatch' }
      $outgoing = $actor.Clone()
      $active.Add([ordered]@{ holderId = $holder; sessionId = $nextSession; windowsSid = $custodianSid; role = 'Coordinator' })
    } elseif ($ordinal.Equals($role, 'Worker')) {
      if ($retireActor) { $retiredWorkers.Add($actor.Clone()) }
      else { $active.Add($actor.Clone()) }
    } else { throw 'SuccessorActorMismatch' }
  }
  if ($null -eq $outgoing) { throw 'SuccessorActorMismatch' }
  if ($requiredRetirements.Count -ne 0) { throw 'RetirementBindingMismatch' }

  $stateTarget = Get-CoordMembers $state
  $stateTarget.generation = $nextGeneration
  $targetState = ConvertTo-SuccessorPlanBytes $stateTarget
  $targetStateDigest = Get-CoordHash $targetState
  if (-not (Test-Json -Json (Read-CoordJsonBytes $targetState).GetRawText() -Schema $schema -ErrorAction SilentlyContinue)) {
    throw 'InvalidTargetState'
  }
  $witnessTarget = Get-CoordMembers $witness
  $witnessTarget.actors = $active
  $retired = @()
  if ($witnessTarget.Contains('retiredActors')) { $retired = @($witnessTarget.retiredActors.EnumerateArray()) }
  $witnessTarget.retiredActors = $retired + @($outgoing) + $retiredWorkers.ToArray()
  $witnessTarget.generation = $nextGeneration
  $witnessTarget.stateSha256 = $targetStateDigest
  $witnessTarget.package = $package
  $targetWitness = ConvertTo-SuccessorPlanBytes $witnessTarget
  Assert-CoordActorRetirement (Read-CoordJsonBytes $targetWitness) $custodianSid
  $targetWitnessDigest = Get-CoordHash $targetWitness

  $fence = Get-CoordMembers $witness
  $fence.actors = @()
  $fence.pendingWrite = [ordered]@{
    kind = 'SuccessorCustody'; operationId = $operationId; intentDigest = $ExpectedIntentSha256
    targetStateDigest = $targetStateDigest; targetWitnessDigest = $targetWitnessDigest
  }
  $fencedWitness = ConvertTo-SuccessorPlanBytes $fence
  $fenceDigest = Get-CoordHash $fencedWitness
  [pscustomobject]@{
    Status = 'PlannedOnly'; ManualQuartetHold = 'ALL_TASKS'; FreshPilotAuthorized = $false
    FencedWitness = $fencedWitness; TargetState = $targetState; TargetWitness = $targetWitness
    Pairs = [ordered]@{
      Before = @{ State = $stateDigest; Witness = $witnessDigest }
      FencedBeforeState = @{ State = $stateDigest; Witness = $fenceDigest }
      FencedAfterState = @{ State = $targetStateDigest; Witness = $fenceDigest }
      Target = @{ State = $targetStateDigest; Witness = $targetWitnessDigest }
    }
  }
}


function Get-CoordSuccessorCheckpoint {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]$Plan,
    [Parameter(Mandatory)][byte[]]$IntentBytes,
    [Parameter(Mandatory)][string]$ExpectedIntentSha256,
    [Parameter(Mandatory)][byte[]]$BeforeStateBytes,
    [Parameter(Mandatory)][byte[]]$BeforeWitnessBytes,
    [Parameter(Mandatory)][byte[]]$ExpectedPairPinsBytes,
    [Parameter(Mandatory)][string]$ExpectedPairPinsSha256,
    [Parameter(Mandatory)][AllowEmptyCollection()][byte[]]$StateBytes,
    [Parameter(Mandatory)][AllowEmptyCollection()][byte[]]$WitnessBytes
  )

  $ordinal = [StringComparer]::Ordinal
  $stateDigest = Get-CoordHash ([byte[]]$StateBytes.Clone())
  $witnessDigest = Get-CoordHash ([byte[]]$WitnessBytes.Clone())
  $intentSnapshot = [byte[]]$IntentBytes.Clone()
  $pinSnapshot = [byte[]]$ExpectedPairPinsBytes.Clone()
  if (-not $ordinal.Equals((Get-CoordHash $intentSnapshot), $ExpectedIntentSha256)) { throw 'IntentPinMismatch' }
  if (-not $ordinal.Equals((Get-CoordHash $pinSnapshot), $ExpectedPairPinsSha256)) { throw 'PairPinsDigestMismatch' }

  $intent = Read-CoordJsonBytes $intentSnapshot
  $null = Get-SuccessorPlanIntentKind $intent
  $beforeStateDigest = Get-CoordHash ([byte[]]$BeforeStateBytes.Clone())
  $beforeWitnessDigest = Get-CoordHash ([byte[]]$BeforeWitnessBytes.Clone())
  if (-not $ordinal.Equals($beforeStateDigest, (Get-SuccessorPlanText $intent 'beforeStateSha256')) -or
      -not $ordinal.Equals($beforeWitnessDigest, (Get-SuccessorPlanText $intent 'beforeWitnessSha256'))) { throw 'SnapshotMismatch' }

  $fence = $Plan.FencedWitness
  $targetState = $Plan.TargetState
  $targetWitness = $Plan.TargetWitness
  $metadata = $Plan.Pairs
  if ($fence -isnot [byte[]] -or $targetState -isnot [byte[]] -or $targetWitness -isnot [byte[]] -or
      $metadata -isnot [System.Collections.IDictionary]) { throw 'InvalidSuccessorPairPins' }
  $fence = [byte[]]$fence.Clone()
  $targetState = [byte[]]$targetState.Clone()
  $targetWitness = [byte[]]$targetWitness.Clone()
  $targetStateDigest = Get-CoordHash $targetState
  $targetWitnessDigest = Get-CoordHash $targetWitness
  $fenceDigest = Get-CoordHash $fence

  # A valid graph has exactly two distinct state digests and three distinct
  # witness digests. That makes the four allowed ordered pairs unambiguous.
  if ($ordinal.Equals($beforeStateDigest, $targetStateDigest) -or
      $ordinal.Equals($beforeWitnessDigest, $fenceDigest) -or
      $ordinal.Equals($beforeWitnessDigest, $targetWitnessDigest) -or
      $ordinal.Equals($fenceDigest, $targetWitnessDigest)) { throw 'AmbiguousSuccessorPairGraph' }

  $actual = [ordered]@{
    Before = @{ State = $beforeStateDigest; Witness = $beforeWitnessDigest }
    FencedBeforeState = @{ State = $beforeStateDigest; Witness = $fenceDigest }
    FencedAfterState = @{ State = $targetStateDigest; Witness = $fenceDigest }
    Target = @{ State = $targetStateDigest; Witness = $targetWitnessDigest }
  }
  $pins = Read-CoordJsonBytes $pinSnapshot
  $metadata = ConvertTo-CoordElement $metadata
  Assert-SuccessorPlanObject $pins @($actual.Keys) 'InvalidSuccessorPairPins'
  Assert-SuccessorPlanObject $metadata @($actual.Keys) 'InvalidSuccessorPairPins'
  foreach ($name in $actual.Keys) {
    $pin = $pins.GetProperty($name)
    $declared = $metadata.GetProperty($name)
    Assert-SuccessorPlanObject $pin @('State', 'Witness') 'InvalidSuccessorPairPins'
    Assert-SuccessorPlanObject $declared @('State', 'Witness') 'InvalidSuccessorPairPins'
    foreach ($component in 'State', 'Witness') {
      $digest = $actual[$name][$component]
      if (-not $ordinal.Equals($digest, (Get-SuccessorPlanText $pin $component)) -or
          -not $ordinal.Equals($digest, (Get-SuccessorPlanText $declared $component))) {
        throw "SuccessorPairPinMismatch:$name/$component"
      }
    }
  }

  # Bind the verified images to this intent, not merely to a self-consistent table.
  $fencedWitness = Read-CoordJsonBytes $fence
  $marker = $fencedWitness.GetProperty('pendingWrite')
  $actors = $fencedWitness.GetProperty('actors')
  Assert-SuccessorPlanObject $marker @('kind', 'operationId', 'intentDigest', 'targetStateDigest', 'targetWitnessDigest') 'SuccessorFenceBindingMismatch'
  if ($actors.ValueKind -ne [Text.Json.JsonValueKind]::Array -or $actors.GetArrayLength() -ne 0 -or
      -not $ordinal.Equals((Get-SuccessorPlanText $fencedWitness 'generation'), (Get-SuccessorPlanText $intent 'generation')) -or
      -not $ordinal.Equals((Get-SuccessorPlanText $fencedWitness 'stateSha256'), $beforeStateDigest) -or
      -not $ordinal.Equals((Get-SuccessorPlanText $marker 'kind'), 'SuccessorCustody') -or
      -not $ordinal.Equals((Get-SuccessorPlanText $marker 'operationId'), (Get-SuccessorPlanText $intent 'operationId')) -or
      -not $ordinal.Equals((Get-SuccessorPlanText $marker 'intentDigest'), $ExpectedIntentSha256) -or
      -not $ordinal.Equals((Get-SuccessorPlanText $marker 'targetStateDigest'), $targetStateDigest) -or
      -not $ordinal.Equals((Get-SuccessorPlanText $marker 'targetWitnessDigest'), $targetWitnessDigest)) {
    throw 'SuccessorFenceBindingMismatch'
  }

  $targetState = Read-CoordJsonBytes $targetState
  $targetWitness = Read-CoordJsonBytes $targetWitness
  $nextGeneration = Get-SuccessorPlanText $intent 'nextGeneration'
  if (-not $ordinal.Equals((Get-SuccessorPlanText $targetState 'generation'), $nextGeneration) -or
      -not $ordinal.Equals((Get-SuccessorPlanText $targetWitness 'generation'), $nextGeneration) -or
      -not $ordinal.Equals((Get-SuccessorPlanText $targetWitness 'stateSha256'), $targetStateDigest) -or
      $targetWitness.GetProperty('pendingWrite').ValueKind -ne [Text.Json.JsonValueKind]::Null) {
    throw 'SuccessorTargetBindingMismatch'
  }

  # Only the strict, cloned pin document is consulted after validation.
  foreach ($name in $actual.Keys) {
    $pair = $pins.GetProperty($name)
    if ($ordinal.Equals($stateDigest, $pair.GetProperty('State').GetString()) -and
        $ordinal.Equals($witnessDigest, $pair.GetProperty('Witness').GetString())) { return $name }
  }
  'ThirdState'
}

