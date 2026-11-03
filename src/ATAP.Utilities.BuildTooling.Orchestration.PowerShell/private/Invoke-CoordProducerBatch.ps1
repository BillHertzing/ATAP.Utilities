function Invoke-CoordProducerBatch {
  param($Context, [long]$MaximumRequests)
  Assert-CoordPublishedHead $Context
  $pending = @($Context.State.GetProperty('requests').EnumerateArray() |
    Where-Object { $_.GetProperty('status').GetString() -ceq 'Pending' } |
    Sort-Object { [long]$_.GetProperty('queueOrdinal').GetString() })
  $selected = [Collections.Generic.List[object]]::new()
  $rejected = @{}
  $working = $Context.State.Clone()
  $preview = $null
  $boardPath = $Context.State.GetProperty('committedOutputManifest').GetProperty('markdown').GetProperty('path').GetString()
  $snapshot = Read-CoordBoard -PlanningRoot ([IO.Path]::GetDirectoryName($boardPath)) -SprintNumber ([int]$Context.Record.sprintId)
  $registryIds = @($Context.Record.existingTasks | ForEach-Object { $_.taskId })
  if ($snapshot.Path -ine $boardPath -or $snapshot.Tasks.Count -ne $registryIds.Count) { throw 'TaskRegistryChanged' }
  foreach ($task in $snapshot.Tasks) { if ($task.Id -cnotin $registryIds) { throw 'TaskRegistryChanged' } }
  $considered = [long]0; $batchBytes = [long]0
  foreach ($record in $pending) {
    if ($considered -ge $MaximumRequests -or $selected.Count -ge $Context.Limits.MaxBatchRequests) { break }
    $considered++
    $request = $record.GetProperty('request')
    $id = $request.GetProperty('requestId').GetString()
    try {
      $envelope = ConvertTo-CoordElement @{ request = $request; digest = $record.GetProperty('digest').GetString() }
      $canonical = ConvertTo-CoordCanonicalRequest -EnvelopeBytes (ConvertTo-CoordStateBytes $envelope) -MaxRequestBytes $Context.Limits.MaxRequestBytes
      $grant = Get-CoordRequestGrant $Context $request $canonical.Digest
      if ($request.GetProperty('generation').GetString() -cne $Context.Record.generation -or
          $request.GetProperty('expectedRevision').GetString() -cne $Context.State.GetProperty('committedRevision').GetString()) { throw 'RevisionConflict' }
      if ($request.GetProperty('taskId').GetString() -cnotin $registryIds) { throw 'UnknownTask' }
      $null = Resolve-CoordScopeBindings $Context.State $request.GetProperty('scope')
      Assert-CoordReservationScope $Context $request
      $causal = Test-CoordRequestCausality -Request $request -ExpectedResourceId $Context.Record.resourceId -RetainedRecords $Context.State.GetProperty('requests')
      if ($causal.Decision -ceq 'WaitingForPredecessor') { continue }
      if ($causal.Decision -cne 'NeedsFurtherValidation') { throw $causal.Decision }
      foreach ($other in $selected) { if (Test-CoordFootprintOverlap $Context $request $other.Request) { throw 'BatchConflict' } }
      if ($canonical.CanonicalBytes.LongLength -gt $Context.Limits.MaxBatchBytes - $batchBytes) {
        if ($selected.Count -eq 0) { throw 'BatchByteLimit' }
        break
      }
      $category = $request.GetProperty('category').GetString()
      switch ($category) {
        'Claim' {
          if ([string]::IsNullOrWhiteSpace($grant.claimId)) { throw 'MissingClaimId' }
          foreach ($old in $Context.State.GetProperty('requests').EnumerateArray()) {
            $oldRequest = $old.GetProperty('request')
            if ($oldRequest.GetProperty('category').GetString() -ceq 'Release' -and
                $oldRequest.GetProperty('payload').GetProperty('claimId').GetString() -ceq $grant.claimId) { throw 'ClaimConflict' }
          }
          $binding = Get-CoordClaimContext $Context $request $working
          $proposed = Update-CoordClaim -State $working -Request $request -Context $binding -ClaimId $grant.claimId -Confirm:$false
          $working = $proposed.ProposedState
        }
        'Release' {
          $binding = Get-CoordClaimContext $Context $request $working
          $proposed = Update-CoordClaim -State $working -Request $request -Context $binding -Confirm:$false
          $working = $proposed.ProposedState
        }
        'ReportResult' {
          $null = Get-CoordOwnedClaim $Context $request $working
          Assert-CoordEvidence $Context $request.GetProperty('payload').GetProperty('evidence')
        }
        'AcceptChange' {
          $payload = $request.GetProperty('payload')
          Assert-CoordEvidence $Context $payload.GetProperty('evidence')
          $reportId = $payload.GetProperty('reportRequestId').GetString()
          $reports = @($Context.State.GetProperty('requests').EnumerateArray() | Where-Object {
            $_.GetProperty('request').GetProperty('requestId').GetString() -ceq $reportId -and $_.GetProperty('status').GetString() -ceq 'Applied' })
          if ($reports.Count -ne 1) { throw 'ResultConflict' }
          $report = $reports[0]
          $binding = ConvertTo-CoordElement @{
            coordinatorId = $Context.Record.coordinatorId; resourceId = $Context.Record.resourceId; sprintId = $Context.Record.sprintId
            generation = $Context.Record.generation; committedRevision = $Context.State.GetProperty('committedRevision').GetString()
            taskId = $request.GetProperty('taskId').GetString(); authorizationReference = $request.GetProperty('authorizationReference').GetString()
            holder = $request.GetProperty('holder'); scope = $request.GetProperty('scope')
            claimId = $report.GetProperty('request').GetProperty('payload').GetProperty('claimId').GetString()
            reportRequestId = $reportId; reportDigest = $report.GetProperty('digest').GetString()
            evidence = $payload.GetProperty('evidence'); snapshotSha256 = $snapshot.Sha256
            snapshotParserSha256 = (Get-FileHash (Join-Path $Context.ModuleRoot 'private/Read-CoordBoard.ps1') -Algorithm SHA256).Hash.ToLowerInvariant()
          }
          $next = New-CoordBoardChange -Snapshot $snapshot -Request $request -AppliedReport $report -Context $binding -Reservations $Context.State.GetProperty('reservations') -Confirm:$false
          if ($null -eq $preview) { $preview = $next } else {
            $preview.AfterBytes = $next.AfterBytes; $preview.AfterText = $next.AfterText; $preview.AfterSha256 = $next.AfterSha256
          }
          # Reuse the real parser for the next independent annotation, never a second grammar.
          if ($pending.Count -gt 1) {
            $folder = Join-Path $Context.Record.scratchRoot ('preview-' + [guid]::NewGuid().ToString('N'))
            $null = [IO.Directory]::CreateDirectory($folder)
            [IO.File]::WriteAllBytes((Join-Path $folder ([IO.Path]::GetFileName($boardPath))), $preview.AfterBytes)
            $snapshot = Read-CoordBoard -PlanningRoot $folder -SprintNumber ([int]$Context.Record.sprintId)
          }
        }
      }
      $selected.Add([pscustomobject]@{ Request = $request.Clone(); Record = $record.Clone(); Digest = $canonical.Digest })
      $batchBytes += $canonical.CanonicalBytes.LongLength
    } catch {
      if ($_.Exception -is [IO.IOException] -or $_.Exception -is [UnauthorizedAccessException]) { throw 'ProducerStorageUnavailable' }
      $reason = $_.Exception.Message
      if ($reason -match '(ClaimConflict|BindingConflict|AuthorityConflict|RevisionConflict|UnknownTask|ResourceHeld|UnsupportedChange|UnsupportedAnnotation|ReportMismatch|SnapshotMismatch)') { $reason = $Matches[1] }
      $known = @('ClaimConflict', 'BindingConflict', 'AuthorityConflict', 'RevisionConflict', 'UnknownTask', 'ResourceHeld',
        'UnsupportedChange', 'UnsupportedAnnotation', 'ReportMismatch', 'SnapshotMismatch', 'ResultConflict', 'EvidenceMismatch',
        'UnsupportedEvidenceReference', 'EvidenceScopeConflict', 'ScopeConflict', 'ScopeEscape', 'ReservationConflict',
        'MissingClaimId', 'CausalCycle', 'MissingPredecessor', 'ForeignPredecessor', 'PredecessorFailed', 'BatchConflict', 'BatchByteLimit')
      if ($reason -cnotin $known) { $reason = 'ValidationFailed' }
      $rejected[$id] = Set-CoordRequestOutcome -Record $record -Status Rejected -Reason $reason -Receipt $Context.State.GetProperty('custodyEvidence')
    }
  }
  if ($rejected.Count) {
    $state = Get-CoordMembers $Context.State
    $state.requests = @(foreach ($record in $Context.State.GetProperty('requests').EnumerateArray()) {
      $id = $record.GetProperty('request').GetProperty('requestId').GetString()
      if ($rejected.ContainsKey($id)) { $rejected[$id] } else { $record.Clone() }
    })
    Save-CoordProducerState $Context (ConvertTo-CoordElement $state)
  }
  if ($selected.Count) {
    $operationId = 'operation-' + [guid]::NewGuid().ToString('N')
    $after = Get-CoordMembers $Context.State
    $after.claims = $working.GetProperty('claims')
    $after.committedRevision = 'revision-' + [guid]::NewGuid().ToString('N')
    $ids = @($selected | ForEach-Object { $_.Request.GetProperty('requestId').GetString() })
    $after.requests = @(foreach ($record in $Context.State.GetProperty('requests').EnumerateArray()) {
      if ($record.GetProperty('request').GetProperty('requestId').GetString() -cin $ids) {
        Set-CoordRequestOutcome -Record $record -Status Applied -Reason 'Applied authorized existing-task operation' -Receipt $Context.State.GetProperty('custodyEvidence') -OperationId $operationId
      } else { $record.Clone() }
    })
    $beforeOutputs = Get-CoordQuartetImages $Context
    $afterOutputs = $beforeOutputs.Clone()
    if ($preview) {
      $scratch = Join-Path $Context.Record.scratchRoot ('quartet-' + [guid]::NewGuid().ToString('N'))
      $candidate = New-CoordQuartetCandidate -Preview $preview -BeforeImages $beforeOutputs -ScratchRoot $scratch -Confirm:$false
      $afterOutputs = $candidate.AfterOutputs
    }
    $operation = New-CoordProducerOperation $Context (ConvertTo-CoordElement $after) $beforeOutputs $afterOutputs $ids $operationId
    Invoke-CoordDurableOperation -Context $Context -Phase Prepare -Operation $operation
    Invoke-CoordDurableOperation -Context $Context -Phase Complete -OperationId $operationId
  }
  [pscustomobject]@{ Considered = $considered; Applied = $selected.Count; Rejected = $rejected.Count
    Progress = ($selected.Count -gt 0 -or $rejected.Count -gt 0) }
}
