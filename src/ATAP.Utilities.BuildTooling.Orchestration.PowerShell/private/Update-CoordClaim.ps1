function Update-CoordClaim {
  <#
  .SYNOPSIS
    Proposes a Claim or Release on an independent state clone without applying it.
  .DESCRIPTION
    Private pure transition boundary. State and Request must already have passed
    accepted schema/strict canonical validation, retained-retry, authority,
    resource/board/sprint, revision, causality, reservation and batch validation.
    The trusted caller must bind current custody/exclusion and resolved containment
    immediately before preparation. Neither Context nor recorded Admitted status
    establishes those facts. This function cannot validate a self-declared grant.

    Context is a closed PRIVATE object, not a wire/schema extension. Required keys:
    coordinatorId, resourceId, lineageId, sprintId, generation, committedRevision,
    taskId, holder, authorizationReference, existingTasks, requestScopeBindings,
    activeClaimScopeBindings. Holder has holderId/sessionId. ExistingTasks entries
    have taskId/ancestorTaskIds: complete caller-validated, transitive task ancestry.
    Task IDs are opaque; no textual prefix or invented delimiter infers ancestry.

    Each ordered scope binding has registeredRootId/path (exact original strings),
    registeredRootPath (exact registered state path), identityDomain, segments and
    comparison. The caller resolves segments from a GLOBAL physical namespace in
    identityDomain, not relative to each registered root, proving containment,
    alias resolution and comparison policy separately. Comparison is Ordinal or
    OrdinalIgnoreCase, consistent within a domain. This permits overlapping aliases
    and nested registered roots to conflict without filesystem calls or rewriting
    identity-bearing scope strings. ActiveClaimScopeBindings entries have claimId
    and scopeBindings, exactly once for every active claim; no missing/extra entry.

    ClaimId is an explicit coordinator-assigned private input for Claim only;
    uniqueness beyond the active inventory is a caller precondition. It is never
    generated or derived from requestId. Release uses only payload.claimId and
    requires exact active task/scope/holder/session/epoch custody. All active claims
    conflict regardless of time; there is no expiry input or takeover.

    Only the claims property changes in ProposedState. No task/result/reservation,
    revision, epoch, admission, journal or receipt is updated. Input JsonElements
    remain untouched, including historical rejected input and opaque JSON numbers.
    Errors are local fixed diagnostics, not persisted request outcomes.
  .PARAMETER State
    Caller-validated Coordination-state-v1 JsonElement snapshot.
  .PARAMETER Request
    Caller-validated Coordination-v1 request object (not transport envelope).
  .PARAMETER Context
    Trusted-caller bindings described above, supplied as a JsonElement.
  .PARAMETER ClaimId
    Explicit nonempty assigned claim identity. Mandatory for Claim, forbidden for
    Release. No default, GUID minting or wire payload addition.
  .OUTPUTS
    PSCustomObject: Stage=ProposedNotApplied, Category, ClaimId, ProposedState
    (independent JsonElement). This is neither a grant nor a durable result.
  .NOTES
    No dependency on ConvertTo-CoordCanonicalRequest or another unfinished validator.
    The boundary requires their validation semantics upstream; it does not implement
    full S3 precedence, scheduler retries, persistence or authority admission.
    WhatIf/Confirm are available by convention; proposal generation has no mutation.
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [System.Text.Json.JsonElement]$State,

    [Parameter(Mandatory)]
    [System.Text.Json.JsonElement]$Request,

    [Parameter(Mandatory)]
    [System.Text.Json.JsonElement]$Context,

    [ValidateNotNullOrEmpty()]
    [string]$ClaimId
  )

  begin {
    $fn = 'Update-CoordClaim'
    $mn = 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell'
    $null = Get-Command -Name 'Write-PSFMessage' -ErrorAction Stop

    function assertMembers {
      param([System.Text.Json.JsonElement]$Element, [AllowEmptyCollection()][string[]]$Names)
      if ($Element.ValueKind -ne [System.Text.Json.JsonValueKind]::Object) { throw 'BindingConflict' }
      $expected = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
      foreach ($name in $Names) { $null = $expected.Add($name) }
      $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
      foreach ($property in $Element.EnumerateObject()) {
        if (-not $expected.Contains($property.Name) -or -not $seen.Add($property.Name)) { throw 'BindingConflict' }
      }
      if ($seen.Count -ne $expected.Count) { throw 'BindingConflict' }
    }

    function sameText {
      param([string]$Left, [string]$Right)
      return [string]::Equals($Left, $Right, [System.StringComparison]::Ordinal)
    }

    function isOneOf {
      param([string]$Value, [string[]]$Allowed)
      foreach ($item in $Allowed) {
        if (sameText $Value $item) { return $true }
      }
      return $false
    }

    function getText {
      param([System.Text.Json.JsonElement]$Element)
      if ($Element.ValueKind -ne [System.Text.Json.JsonValueKind]::String) { throw 'BindingConflict' }
      $value = $Element.GetString()
      if ($value.Length -eq 0) { throw 'BindingConflict' }
      return $value
    }

    function getTexts {
      param([System.Text.Json.JsonElement]$Element, [switch]$Nonempty)
      if ($Element.ValueKind -ne [System.Text.Json.JsonValueKind]::Array) { throw 'BindingConflict' }
      $values = [System.Collections.Generic.List[string]]::new()
      foreach ($item in $Element.EnumerateArray()) { $values.Add((getText $item)) }
      if ($Nonempty -and $values.Count -eq 0) { throw 'BindingConflict' }
      return ,$values.ToArray()
    }

    function sameHolder {
      param([System.Text.Json.JsonElement]$Left, [System.Text.Json.JsonElement]$Right)
      assertMembers $Left @('holderId', 'sessionId')
      assertMembers $Right @('holderId', 'sessionId')
      return (sameText (getText $Left.GetProperty('holderId')) (getText $Right.GetProperty('holderId'))) -and
        (sameText (getText $Left.GetProperty('sessionId')) (getText $Right.GetProperty('sessionId')))
    }

    function sameScope {
      param([System.Text.Json.JsonElement]$Left, [System.Text.Json.JsonElement]$Right)
      if ($Left.ValueKind -ne [System.Text.Json.JsonValueKind]::Array -or
          $Right.ValueKind -ne [System.Text.Json.JsonValueKind]::Array -or
          $Left.GetArrayLength() -ne $Right.GetArrayLength()) { return $false }
      for ($i = 0; $i -lt $Left.GetArrayLength(); $i++) {
        if (-not (sameText $Left[$i].GetProperty('registeredRootId').GetString() $Right[$i].GetProperty('registeredRootId').GetString()) -or
            -not (sameText $Left[$i].GetProperty('path').GetString() $Right[$i].GetProperty('path').GetString())) { return $false }
      }
      return $true
    }

    function bindScopes {
      param(
        [System.Text.Json.JsonElement]$Scope,
        [System.Text.Json.JsonElement]$Bindings,
        [System.Collections.Generic.Dictionary[string, string]]$Roots,
        [System.Collections.Generic.Dictionary[string, string]]$Policies
      )
      if ($Scope.ValueKind -ne [System.Text.Json.JsonValueKind]::Array -or $Scope.GetArrayLength() -eq 0 -or
          $Bindings.ValueKind -ne [System.Text.Json.JsonValueKind]::Array -or
          $Scope.GetArrayLength() -ne $Bindings.GetArrayLength()) { throw 'BindingConflict' }
      $bound = [System.Collections.Generic.List[object]]::new()
      for ($i = 0; $i -lt $Scope.GetArrayLength(); $i++) {
        $entry = $Scope[$i]
        $binding = $Bindings[$i]
        assertMembers $entry @('registeredRootId', 'path')
        assertMembers $binding @('registeredRootId', 'path', 'registeredRootPath', 'identityDomain', 'segments', 'comparison')
        $rootId = getText $entry.GetProperty('registeredRootId')
        $path = getText $entry.GetProperty('path')
        if (-not (sameText $rootId (getText $binding.GetProperty('registeredRootId'))) -or
            -not (sameText $path (getText $binding.GetProperty('path'))) -or -not $Roots.ContainsKey($rootId) -or
            -not (sameText $Roots[$rootId] (getText $binding.GetProperty('registeredRootPath')))) { throw 'BindingConflict' }
        $domain = getText $binding.GetProperty('identityDomain')
        $comparison = getText $binding.GetProperty('comparison')
        if (-not (isOneOf $comparison @('Ordinal', 'OrdinalIgnoreCase'))) { throw 'BindingConflict' }
        if ($Policies.ContainsKey($domain) -and -not (sameText $Policies[$domain] $comparison)) { throw 'BindingConflict' }
        $Policies[$domain] = $comparison
        $segments = getTexts $binding.GetProperty('segments') -Nonempty
        if (@($segments | Where-Object { (sameText $_ '.') -or (sameText $_ '..') }).Count -gt 0) { throw 'BindingConflict' }
        $bound.Add([PSCustomObject]@{ Domain = $domain; Segments = $segments; Comparison = $comparison })
      }
      return ,$bound.ToArray()
    }

    function overlaps {
      param([object[]]$Left, [object[]]$Right)
      foreach ($a in $Left) {
        foreach ($b in $Right) {
          if (-not (sameText $a.Domain $b.Domain)) { continue }
          $comparison = if (sameText $a.Comparison 'Ordinal') {
            [System.StringComparison]::Ordinal
          } else { [System.StringComparison]::OrdinalIgnoreCase }
          $common = [System.Math]::Min($a.Segments.Count, $b.Segments.Count)
          $equal = $true
          for ($i = 0; $i -lt $common; $i++) {
            if (-not [string]::Equals($a.Segments[$i], $b.Segments[$i], $comparison)) { $equal = $false; break }
          }
          if ($equal) { return $true }
        }
      }
      return $false
    }
  }

  process {
    $stream = $null
    $writer = $null
    $document = $null
    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Preparing a non-applied claim proposal'
      assertMembers $State @('schemaVersion', 'resourceId', 'lineageId', 'registeredRoots', 'generation',
        'committedRevision', 'committedOutputManifest', 'custodyEvidence', 'compatibilityEvidence',
        'admissionEvidence', 'requests', 'claims', 'reservations', 'preparedOperations', 'commitReceipts', 'mutationAdmission')
      assertMembers $Request @('protocolVersion', 'resourceId', 'sprintId', 'requestId', 'category', 'taskId',
        'scope', 'holder', 'authorizationReference', 'generation', 'expectedRevision', 'predecessors', 'payload')
      assertMembers $Context @('coordinatorId', 'resourceId', 'lineageId', 'sprintId', 'generation', 'committedRevision',
        'taskId', 'holder', 'authorizationReference', 'existingTasks', 'requestScopeBindings', 'activeClaimScopeBindings')
      if (-not (sameText (getText $State.GetProperty('schemaVersion')) 'Coordination-state-v1') -or
          -not (sameText (getText $Request.GetProperty('protocolVersion')) 'Coordination-v1')) { throw 'InvalidInput' }
      $category = getText $Request.GetProperty('category')
      if (-not (isOneOf $category @('Claim', 'Release'))) { throw 'InvalidInput' }
      $payload = $Request.GetProperty('payload')
      if (sameText $category 'Claim') {
        assertMembers -Element $payload -Names @()
        if (-not $PSBoundParameters.ContainsKey('ClaimId') -or $ClaimId.Length -eq 0) { throw 'MissingClaimId' }
        $selectedClaimId = $ClaimId
      } else {
        assertMembers $payload @('claimId', 'releaseReason')
        if ($PSBoundParameters.ContainsKey('ClaimId')) { throw 'InvalidInput' }
        $selectedClaimId = getText $payload.GetProperty('claimId')
        $null = getText $payload.GetProperty('releaseReason')
      }
      $null = getText $Context.GetProperty('coordinatorId')
      foreach ($key in @('resourceId', 'generation')) {
        $value = getText $State.GetProperty($key)
        if (-not (sameText $value (getText $Context.GetProperty($key))) -or
            -not (sameText $value (getText $Request.GetProperty($key)))) { throw 'AuthorityConflict' }
      }
      if (-not (sameText (getText $State.GetProperty('lineageId')) (getText $Context.GetProperty('lineageId'))) -or
          -not (sameText (getText $Request.GetProperty('sprintId')) (getText $Context.GetProperty('sprintId'))) -or
          -not (sameText (getText $Request.GetProperty('authorizationReference')) (getText $Context.GetProperty('authorizationReference'))) -or
          -not (sameHolder $Request.GetProperty('holder') $Context.GetProperty('holder'))) { throw 'AuthorityConflict' }
      if (-not (sameText (getText $State.GetProperty('committedRevision')) (getText $Context.GetProperty('committedRevision'))) -or
          -not (sameText (getText $Request.GetProperty('expectedRevision')) (getText $State.GetProperty('committedRevision')))) { throw 'RevisionConflict' }
      $taskId = getText $Request.GetProperty('taskId')
      if (-not (sameText $taskId (getText $Context.GetProperty('taskId')))) { throw 'BindingConflict' }
      $requestId = getText $Request.GetProperty('requestId')

      $tasks = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::Ordinal)
      $taskInventory = $Context.GetProperty('existingTasks')
      if ($taskInventory.ValueKind -ne [System.Text.Json.JsonValueKind]::Array) { throw 'BindingConflict' }
      foreach ($task in $taskInventory.EnumerateArray()) {
        assertMembers $task @('taskId', 'ancestorTaskIds')
        $id = getText $task.GetProperty('taskId')
        if ($tasks.ContainsKey($id)) { throw 'BindingConflict' }
        $ancestors = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        foreach ($ancestor in (getTexts $task.GetProperty('ancestorTaskIds'))) {
          if ((sameText $ancestor $id) -or -not $ancestors.Add($ancestor)) { throw 'BindingConflict' }
        }
        $tasks.Add($id, $ancestors)
      }
      if (-not $tasks.ContainsKey($taskId)) { throw 'UnknownTask' }
      foreach ($id in $tasks.Keys) {
        foreach ($ancestor in $tasks[$id]) {
          if (-not $tasks.ContainsKey($ancestor) -or $tasks[$ancestor].Contains($id)) { throw 'BindingConflict' }
          foreach ($transitive in $tasks[$ancestor]) {
            if (-not $tasks[$id].Contains($transitive)) { throw 'BindingConflict' }
          }
        }
      }

      $roots = [System.Collections.Generic.Dictionary[string, string]]::new([System.StringComparer]::Ordinal)
      foreach ($root in $State.GetProperty('registeredRoots').EnumerateArray()) {
        assertMembers $root @('registeredRootId', 'path')
        $id = getText $root.GetProperty('registeredRootId')
        if ($roots.ContainsKey($id)) { throw 'BindingConflict' }
        $roots.Add($id, (getText $root.GetProperty('path')))
      }
      $policies = [System.Collections.Generic.Dictionary[string, string]]::new([System.StringComparer]::Ordinal)
      $requestScope = $Request.GetProperty('scope')
      $resolvedRequest = bindScopes $requestScope $Context.GetProperty('requestScopeBindings') $roots $policies
      $claimBindings = [System.Collections.Generic.Dictionary[string, System.Text.Json.JsonElement]]::new([System.StringComparer]::Ordinal)
      foreach ($binding in $Context.GetProperty('activeClaimScopeBindings').EnumerateArray()) {
        assertMembers $binding @('claimId', 'scopeBindings')
        $id = getText $binding.GetProperty('claimId')
        if ($claimBindings.ContainsKey($id)) { throw 'BindingConflict' }
        $claimBindings.Add($id, $binding.GetProperty('scopeBindings'))
      }
      $claims = @($State.GetProperty('claims').EnumerateArray())
      if ($claimBindings.Count -ne $claims.Count) { throw 'BindingConflict' }
      $seenClaims = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
      $seenClaimRequests = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
      $matchingClaim = $null
      foreach ($claim in $claims) {
        assertMembers $claim @('claimId', 'resourceId', 'taskId', 'scope', 'holder', 'generation', 'claimRequestId')
        $id = getText $claim.GetProperty('claimId')
        $claimRequestId = getText $claim.GetProperty('claimRequestId')
        if (-not $seenClaims.Add($id) -or -not $seenClaimRequests.Add($claimRequestId) -or
            -not $claimBindings.ContainsKey($id)) { throw 'BindingConflict' }
        if (-not (sameText (getText $claim.GetProperty('resourceId')) (getText $State.GetProperty('resourceId'))) -or
            -not (sameText (getText $claim.GetProperty('generation')) (getText $State.GetProperty('generation')))) { throw 'AuthorityConflict' }
        $claimTaskId = getText $claim.GetProperty('taskId')
        if (-not $tasks.ContainsKey($claimTaskId)) { throw 'BindingConflict' }
        $resolvedClaim = bindScopes $claim.GetProperty('scope') $claimBindings[$id] $roots $policies
        if (sameText $category 'Claim') {
          if ((sameText $id $selectedClaimId) -or (sameText $claimRequestId $requestId) -or (sameText $claimTaskId $taskId) -or
              $tasks[$taskId].Contains($claimTaskId) -or $tasks[$claimTaskId].Contains($taskId) -or
              (overlaps $resolvedRequest $resolvedClaim)) { throw 'ClaimConflict' }
        } elseif ((sameText $id $selectedClaimId)) {
          $matchingClaim = $claim
        }
      }
      if (sameText $category 'Release') {
        if ($null -eq $matchingClaim -or
            -not (sameText (getText $matchingClaim.GetProperty('taskId')) $taskId) -or
            -not (sameHolder $matchingClaim.GetProperty('holder') $Request.GetProperty('holder')) -or
            -not (sameScope $matchingClaim.GetProperty('scope') $requestScope)) { throw 'ClaimConflict' }
      }
      if (-not (sameText $State.GetProperty('mutationAdmission').GetProperty('status').GetString() 'Admitted')) { throw 'ResourceHeld' }
      foreach ($operation in $State.GetProperty('preparedOperations').EnumerateArray()) {
        if (-not (sameText $operation.GetProperty('status').GetString() 'Applied')) { throw 'ResourceHeld' }
      }
      foreach ($record in $State.GetProperty('requests').EnumerateArray()) {
        if (isOneOf $record.GetProperty('status').GetString() @('Prepared', 'NeedsRecovery')) { throw 'ResourceHeld' }
      }

      $stream = [System.IO.MemoryStream]::new()
      # Resource/depth admission belongs upstream; do not impose a new default
      # JSON depth cutoff on already validated historical rejected evidence.
      $writerOptions = [System.Text.Json.JsonWriterOptions]::new()
      $writerOptions.MaxDepth = [int]::MaxValue
      $writer = [System.Text.Json.Utf8JsonWriter]::new($stream, $writerOptions)
      $writer.WriteStartObject()
      foreach ($property in $State.EnumerateObject()) {
        $writer.WritePropertyName($property.Name)
        if (-not (sameText $property.Name 'claims')) { $writer.WriteRawValue($property.Value.GetRawText(), $false); continue }
        $writer.WriteStartArray()
        foreach ($claim in $claims) {
          if ((sameText $category 'Release') -and (sameText $claim.GetProperty('claimId').GetString() $selectedClaimId)) { continue }
          $writer.WriteRawValue($claim.GetRawText(), $false)
        }
        if (sameText $category 'Claim') {
          $writer.WriteStartObject()
          $writer.WriteString('claimId', $selectedClaimId)
          foreach ($key in @('resourceId', 'taskId', 'scope', 'holder', 'generation')) {
            $writer.WritePropertyName($key)
            $writer.WriteRawValue($Request.GetProperty($key).GetRawText(), $false)
          }
          $writer.WriteString('claimRequestId', $requestId)
          $writer.WriteEndObject()
        }
        $writer.WriteEndArray()
      }
      $writer.WriteEndObject()
      $writer.Flush()
      $documentOptions = [System.Text.Json.JsonDocumentOptions]::new()
      $documentOptions.MaxDepth = [int]::MaxValue
      $document = [System.Text.Json.JsonDocument]::Parse([System.Text.Encoding]::UTF8.GetString($stream.ToArray()), $documentOptions)
      [PSCustomObject]@{
        Stage = 'ProposedNotApplied'
        Category = $category
        ClaimId = $selectedClaimId
        ProposedState = $document.RootElement.Clone()
      }
    } catch {
      $code = $_.Exception.Message
      if (-not (isOneOf $code @('BindingConflict', 'InvalidInput', 'MissingClaimId', 'AuthorityConflict',
          'RevisionConflict', 'UnknownTask', 'ClaimConflict', 'ResourceHeld'))) { $code = 'InvalidInput' }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message 'Claim proposal rejected without mutation'
      throw [System.InvalidOperationException]::new("Update-CoordClaim: $code.")
    } finally {
      if ($null -ne $document) { $document.Dispose() }
      if ($null -ne $writer) { $writer.Dispose() }
      if ($null -ne $stream) { $stream.Dispose() }
    }
  }

  end {}
}

