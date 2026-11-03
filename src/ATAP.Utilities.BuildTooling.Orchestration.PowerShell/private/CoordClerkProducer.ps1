function Resume-CoordProducerWrite {
  param($Context)
  $pending = $Context.Record.pendingWrite
  if (-not $pending) { return }
  $current = [IO.File]::ReadAllBytes($Context.StatePath)
  switch ($pending.kind) {
    'State' {
      $after = [Convert]::FromBase64String($pending.afterBytesBase64)
      if ((Get-CoordHash $after) -cne $pending.afterDigest) { throw 'InvalidRecoveryImage' }
      $actual = Get-CoordHash $current
      if ($actual -ceq $pending.beforeDigest) {
        Write-CoordAtomicBytes $Context.StatePath $current $after
      } elseif ($actual -cne $pending.afterDigest) { throw 'StateRecoveryConflict' }
    }
    'Prepare' {
      $operation = Read-CoordJsonBytes ([Text.Encoding]::UTF8.GetBytes($pending.operationJson))
      $null = Save-CoordOperation -StatePath $Context.StatePath -ExpectedStateBytes $current -Operation $operation -Confirm:$false
    }
    'Complete' {
      $null = Complete-CoordOperation -StatePath $Context.StatePath -ExpectedStateBytes $current -OperationId $pending.operationId -Resume -Confirm:$false
    }
    default { throw 'UnknownRecoveryPhase' }
  }
  $raw = [IO.File]::ReadAllBytes($Context.StatePath)
  $state = Read-CoordJsonBytes $raw
  if (-not (Test-Json -Json $state.GetRawText() -SchemaFile (Join-Path $Context.ModuleRoot 'schemas/state-v1.schema.json') -ErrorAction SilentlyContinue)) { throw 'InvalidState' }
  $Context.Record.stateSha256 = Get-CoordHash $raw
  $Context.Record.pendingWrite = $null
  $witness = ConvertTo-CoordStateBytes (ConvertTo-CoordElement $Context.Record)
  Write-CoordAtomicBytes $Context.RecordPath $Context.RecordBytes $witness
  $Context.RecordBytes = $witness; $Context.StateBytes = $raw; $Context.State = $state
}

function Invoke-CoordDurableOperation {
  param($Context, [ValidateSet('Prepare', 'Complete')][string]$Phase,
    [Text.Json.JsonElement]$Operation, [string]$OperationId)
  if ($Context.Record.pendingWrite) { throw 'NeedsRecovery' }
  $Context.Record.pendingWrite = if ($Phase -eq 'Prepare') {
    @{ kind = 'Prepare'; operationJson = $Operation.GetRawText() }
  } else { @{ kind = 'Complete'; operationId = $OperationId } }
  $bytes = ConvertTo-CoordStateBytes (ConvertTo-CoordElement $Context.Record)
  Write-CoordAtomicBytes $Context.RecordPath $Context.RecordBytes $bytes
  $Context.RecordBytes = $bytes
  Resume-CoordProducerWrite $Context
}

function Get-CoordQuartetImages {
  param($Context)
  $images = [ordered]@{}
  foreach ($slot in @('markdown', 'boardHtml', 'proceduralDetailsHtml', 'accomplishedHtml')) {
    $manifest = $Context.State.GetProperty('committedOutputManifest').GetProperty($slot)
    $path = $manifest.GetProperty('path').GetString()
    $bytes = [IO.File]::ReadAllBytes($path)
    if ((Get-CoordHash $bytes) -cne $manifest.GetProperty('digest').GetString()) { throw 'ExternalBoardChange' }
    $images[$slot] = @{ path = $path; digest = Get-CoordHash $bytes; bytesBase64 = [Convert]::ToBase64String($bytes) }
  }
  ConvertTo-CoordElement $images
}

function Get-CoordClaimContext {
  param($Context, [Text.Json.JsonElement]$Request, [Text.Json.JsonElement]$State)
  $active = @(foreach ($claim in $State.GetProperty('claims').EnumerateArray()) {
    @{ claimId = $claim.GetProperty('claimId').GetString(); scopeBindings = Resolve-CoordScopeBindings $State $claim.GetProperty('scope') }
  })
  ConvertTo-CoordElement @{
    coordinatorId = $Context.Record.coordinatorId; resourceId = $Context.Record.resourceId
    lineageId = $Context.Record.lineageId; sprintId = $Context.Record.sprintId
    generation = $Context.Record.generation; committedRevision = $State.GetProperty('committedRevision').GetString()
    taskId = $Request.GetProperty('taskId').GetString(); holder = $Request.GetProperty('holder')
    authorizationReference = $Request.GetProperty('authorizationReference').GetString()
    existingTasks = $Context.Record.existingTasks; requestScopeBindings = Resolve-CoordScopeBindings $State $Request.GetProperty('scope')
    activeClaimScopeBindings = $active
  }
}

function Test-CoordFootprintOverlap {
  param($Context, [Text.Json.JsonElement]$Left, [Text.Json.JsonElement]$Right)
  $leftTask = $Left.GetProperty('taskId').GetString()
  $rightTask = $Right.GetProperty('taskId').GetString()
  $leftMetadata = @($Context.Record.existingTasks | Where-Object { $_.taskId -ceq $leftTask })
  $rightMetadata = @($Context.Record.existingTasks | Where-Object { $_.taskId -ceq $rightTask })
  if ($leftMetadata.Count -ne 1 -or $rightMetadata.Count -ne 1) { throw 'UnknownTask' }
  if ($leftTask -ceq $rightTask -or $rightTask -cin $leftMetadata[0].ancestorTaskIds -or $leftTask -cin $rightMetadata[0].ancestorTaskIds) { return $true }
  $leftScopes = Resolve-CoordScopeBindings $Context.State $Left.GetProperty('scope')
  $rightScopes = Resolve-CoordScopeBindings $Context.State $Right.GetProperty('scope')
  foreach ($a in $leftScopes) {
    foreach ($b in $rightScopes) {
      if ($a.identityDomain -ine $b.identityDomain) { continue }
      $short = [Math]::Min($a.segments.Count, $b.segments.Count)
      $same = $true
      for ($i = 0; $i -lt $short; $i++) { if ($a.segments[$i] -ine $b.segments[$i]) { $same = $false; break } }
      if ($same) { return $true }
    }
  }
  return $false
}

function Assert-CoordEvidence {
  param($Context, [Text.Json.JsonElement]$Evidence)
  foreach ($item in $Evidence.EnumerateArray()) {
    if ($item.GetProperty('digest').GetProperty('algorithm').GetString() -cne 'SHA256') { throw 'EvidenceMismatch' }
    $path = $item.GetProperty('reference').GetString()
    if (-not [IO.Path]::IsPathFullyQualified($path)) { throw 'UnsupportedEvidenceReference' }
    $null = Assert-CoordOrdinaryPath $path -MustExist
    $registered = @($Context.State.GetProperty('registeredRoots').EnumerateArray() | Where-Object {
      Test-CoordDescendant $path $_.GetProperty('path').GetString() })
    if ($registered.Count -eq 0) { throw 'EvidenceScopeConflict' }
    $stream = [IO.File]::Open($path, 'Open', 'Read', 'Read')
    try { $hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($stream)).ToLowerInvariant() } finally { $stream.Dispose() }
    if ($hash -cne $item.GetProperty('digest').GetProperty('value').GetString()) { throw 'EvidenceMismatch' }
  }
}

function Get-CoordOwnedClaim {
  param($Context, [Text.Json.JsonElement]$Request, [Text.Json.JsonElement]$State)
  $claimId = $Request.GetProperty('payload').GetProperty('claimId').GetString()
  $claims = @($State.GetProperty('claims').EnumerateArray() | Where-Object { $_.GetProperty('claimId').GetString() -ceq $claimId })
  if ($claims.Count -ne 1) { throw 'ClaimConflict' }
  $claim = $claims[0]
  if ($claim.GetProperty('taskId').GetString() -cne $Request.GetProperty('taskId').GetString() -or
      $claim.GetProperty('generation').GetString() -cne $Context.Record.generation -or
      (Get-CoordHash (ConvertTo-CoordStateBytes $claim.GetProperty('holder'))) -cne
        (Get-CoordHash (ConvertTo-CoordStateBytes $Request.GetProperty('holder'))) -or
      (Get-CoordHash (ConvertTo-CoordStateBytes $claim.GetProperty('scope'))) -cne
        (Get-CoordHash (ConvertTo-CoordStateBytes $Request.GetProperty('scope')))) { throw 'ClaimConflict' }
  $claim
}

function Set-CoordRequestOutcome {
  param([Text.Json.JsonElement]$Record, [string]$Status, [string]$Reason, $Receipt, [string]$OperationId)
  $value = Get-CoordMembers $Record
  $value.Remove('pendingEvidence')
  $value.status = $Status
  if ($OperationId) { $value.preparedOperationId = $OperationId }
  $value.terminalEvidence = @{
    resourceId = $Record.GetProperty('request').GetProperty('resourceId').GetString()
    requestId = $Record.GetProperty('request').GetProperty('requestId').GetString()
    digest = $Record.GetProperty('digest').GetString(); status = $Status; reason = $Reason; receipt = $Receipt
  }
  ConvertTo-CoordElement $value
}

function New-CoordProducerOperation {
  param($Context, [Text.Json.JsonElement]$After, [Text.Json.JsonElement]$BeforeOutputs,
    [Text.Json.JsonElement]$AfterOutputs, [string[]]$RequestIds, [string]$OperationId)
  function image([byte[]]$bytes) { @{ bytesBase64 = [Convert]::ToBase64String($bytes); digest = Get-CoordHash $bytes } }
  $manifest = [ordered]@{}
  foreach ($slot in @('markdown', 'boardHtml', 'proceduralDetailsHtml', 'accomplishedHtml')) {
    $output = $AfterOutputs.GetProperty($slot)
    $manifest[$slot] = @{ path = $output.GetProperty('path').GetString(); digest = $output.GetProperty('digest').GetString() }
  }
  $afterMembers = Get-CoordMembers $After
  $afterMembers.committedOutputManifest = $manifest
  $after = ConvertTo-CoordElement $afterMembers
  ConvertTo-CoordElement @{
    operationId = $OperationId; resourceId = $Context.Record.resourceId; status = 'Prepared'
    baseHead = @{ generation = $Context.Record.generation; committedRevision = $Context.State.GetProperty('committedRevision').GetString()
      outputManifest = $Context.State.GetProperty('committedOutputManifest') }
    nextRevision = $After.GetProperty('committedRevision').GetString(); requestIds = $RequestIds
    beforeStateImage = image (ConvertTo-CoordStateBytes $Context.State -Logical)
    afterStateImage = image (ConvertTo-CoordStateBytes $after -Logical)
    beforeOutputs = $BeforeOutputs; afterOutputs = $AfterOutputs; outputManifest = $manifest
    reservations = $After.GetProperty('reservations')
  }
}
function Assert-CoordReservationScope {
  param($Context, [Text.Json.JsonElement]$Request)
  $incoming = Resolve-CoordScopeBindings $Context.State $Request.GetProperty('scope')
  foreach ($reservation in $Context.State.GetProperty('reservations').EnumerateArray()) {
    if ($reservation.GetProperty('requestId').GetString() -ceq $Request.GetProperty('requestId').GetString()) { continue }
    if ($reservation.GetProperty('taskId').GetString() -ceq $Request.GetProperty('taskId').GetString()) { throw 'ReservationConflict' }
    $reserved = Resolve-CoordScopeBindings $Context.State $reservation.GetProperty('scope')
    foreach ($left in $incoming) {
      foreach ($right in $reserved) {
        if ($left.identityDomain -ine $right.identityDomain) { continue }
        $same = $true
        for ($i = 0; $i -lt [Math]::Min($left.segments.Count, $right.segments.Count); $i++) {
          if ($left.segments[$i] -ine $right.segments[$i]) { $same = $false; break }
        }
        if ($same) { throw 'ReservationConflict' }
      }
    }
  }
}
