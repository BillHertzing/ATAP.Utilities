function Invoke-CoordCustodyHandoff {
  <#
  .SYNOPSIS
    Plans or performs one explicitly approved, history-protected custody handoff.
  .DESCRIPTION
    Uses the unchanged reviewed two-retirement planner. Plan and Inspect return
    metadata only. Apply consumes one real authority before backup/history writes.
    Recover needs fresh authority for one exact observed boundary. ALL_TASKS and
    pilot holds remain external; the planner preserves mutationAdmission=Admitted.
  .PARAMETER Mode
    Plan, Inspect, Apply, or an explicitly approved Recover continuation. ApplyPackage and
    RecoverPackage are the package-only transition (Package parameter set): they change only
    custody.package plus one history entry under the standing custody.autoPackageAdmission
    policy. They never write state.json or any board file, need no operator approval window,
    planner intent, Worker update or two-host Dropbox exclusion, and any failure or
    uncertainty disables the policy when that write is itself safe, otherwise holds fenced.
  .PARAMETER OperationId
    Package set. Fresh GUID naming one package admission. RecoverPackage takes only this.
  .PARAMETER AttestationPath
    Package set, ApplyPackage only. The Coordination-package-attestation-v1 file.
  .PARAMETER ExpectedAttestationSha256
    Package set, ApplyPackage only. Mandatory independently supplied digest of that file.
    Busy collisions (PendingWritePresent, OperationInFlight, MutationNotAdmitted, quartet
    changed before the attempt) refuse without disabling the policy; every trust or
    uncertainty failure still disables it when that write is safe.
  .PARAMETER NupkgPath
    Package set, ApplyPackage only. The nupkg whose SHA-256 must equal the attested archive.
  .PARAMETER CandidateModuleRoot
    Package set, ApplyPackage only, MANDATORY. The installed root of the NEW package to admit.
    This command, which must be running from the currently admitted module and never the
    candidate, verifies and inventories that root and reads its schema from it; no code of the
    candidate is imported or run. It must exist and differ from the running module's root, so
    the running code can never vouch for itself. RecoverPackage reads the root recorded in the
    once file and refuses an attempt that has none.
  .PARAMETER PacketPath
    Pinned protected snapshot/intent/target-package and designated-Worker packet.
  .PARAMETER ExpectedPacketSha256
    Independently reviewed digest of the exact packet bytes.
  .PARAMETER ApprovalPath
    Real operator authority receipt for Apply or Recover, never a synthetic grant.
  .PARAMETER ExpectedApprovalSha256
    Independently reviewed digest of that authority receipt.
  .PARAMETER ExclusionPath
    Current coordinator-bound two-host writer exclusion receipt.
  .PARAMETER ExpectedExclusionSha256
    Exact exclusion receipt digest, also named by the authority.
  .OUTPUTS
    Metadata, immutable receipt paths and digests. Never protected raw images.
  .EXAMPLE
    Invoke-CoordCustodyHandoff -Mode Plan -PacketPath $packet -ExpectedPacketSha256 $pin
  .NOTES
    Approval provenance and exclusion are external cooperative authority. This
    command cannot authenticate a human or exclude a hostile same-SID process.
    Use the reviewed bounded operator launcher for live execution. A failed or
    uncertain attempt is consumed. Backup retention is not restore authority.
  .LINK
    ../Documentation/Coordination-v1.md
  #>
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'Handoff')]
  param(
    [Parameter(Mandatory, ParameterSetName = 'Handoff')]
    [Parameter(Mandatory, ParameterSetName = 'Package')]
    [Parameter(Mandatory, ParameterSetName = 'PackageRecover')]
    [ValidateSet('Plan','Inspect','Apply','Recover','ApplyPackage','RecoverPackage', IgnoreCase=$false)][string]$Mode,
    [Parameter(Mandatory, ParameterSetName = 'Handoff')][string]$PacketPath,
    [Parameter(Mandatory, ParameterSetName = 'Handoff')][ValidatePattern('\A[0-9a-fA-F]{64}\z')][string]$ExpectedPacketSha256,
    [Parameter(ParameterSetName = 'Handoff')][string]$ApprovalPath,
    [Parameter(ParameterSetName = 'Handoff')][ValidatePattern('\A[0-9a-fA-F]{64}\z')][string]$ExpectedApprovalSha256,
    [Parameter(ParameterSetName = 'Handoff')][string]$ExclusionPath,
    [Parameter(ParameterSetName = 'Handoff')][ValidatePattern('\A[0-9a-fA-F]{64}\z')][string]$ExpectedExclusionSha256,
    [Parameter(Mandatory, ParameterSetName = 'Package')]
    [Parameter(Mandatory, ParameterSetName = 'PackageRecover')][string]$OperationId,
    [Parameter(Mandatory, ParameterSetName = 'Package')][string]$AttestationPath,
    [Parameter(Mandatory, ParameterSetName = 'Package')][ValidatePattern('\A[0-9a-fA-F]{64}\z')][string]$ExpectedAttestationSha256,
    [Parameter(Mandatory, ParameterSetName = 'Package')][string]$NupkgPath,
    [Parameter(Mandatory, ParameterSetName = 'Package')][string]$CandidateModuleRoot
  )
  begin {
    $fn = 'Invoke-CoordCustodyHandoff'
    $mn = 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell'
    $ordinal = [StringComparer]::Ordinal
    function handoffBytes($Value) { return ,(ConvertTo-CoordStateBytes (ConvertTo-CoordElement $Value)) }
    function handoffSame($Left, $Right) {
      $ordinal.Equals((Get-CoordHash (handoffBytes $Left)), (Get-CoordHash (handoffBytes $Right)))
    }
    function handoffRead([string]$Path, [string]$Digest, [int]$Limit = 67108864) {
      $null = Assert-CoordOrdinaryPath $Path -MustExist
      if ([IO.FileInfo]::new($Path).Length -gt $Limit) { throw 'HandoffInputLimitExceeded' }
      $image = [IO.File]::ReadAllBytes($Path)
      if ($Digest -and (Get-CoordHash $image) -cne $Digest.ToLowerInvariant()) { throw 'HandoffInputPinMismatch' }
      return ,$image
    }
    function handoffGuid([string]$Value) {
      $id = [guid]::Empty
      if (-not [guid]::TryParseExact($Value,'D',[ref]$id) -or $id -eq [guid]::Empty -or
          $id.ToString('D') -cne $Value) { throw 'HandoffIdentifierInvalid' }
      $Value
    }
    function handoffBase64([string]$Value) {
      try { $bytes = [Convert]::FromBase64String($Value) } catch { throw 'HandoffBase64Invalid' }
      if ([Convert]::ToBase64String($bytes) -cne $Value) { throw 'HandoffBase64Invalid' }
      return ,$bytes
    }
    function handoffNew([string]$Path, [byte[]]$Bytes) {
      $null = Assert-CoordOrdinaryPath $Path
      $stream = [IO.File]::Open($Path,'CreateNew','Write','None')
      try { $stream.Write($Bytes); $stream.Flush($true) } finally { $stream.Dispose() }
      if ((Get-CoordHash (handoffRead $Path)) -cne (Get-CoordHash $Bytes)) { throw 'HandoffRetainedReadbackFailed' }
      Assert-CoordProtection $Path $sid
    }
    function handoffPair {
      [ordered]@{ state = Get-CoordHash (handoffRead $statePath); witness = Get-CoordHash (handoffRead $recordPath) }
    }
    function handoffCreateProtectedDirectory([string]$Path) {
      $null = Assert-CoordOrdinaryPath $Path
      if (Test-Path -LiteralPath $Path) { throw 'HandoffNewDirectoryAlreadyExists' }
      $null = [IO.Directory]::CreateDirectory($Path)
      $acl = Get-Acl -LiteralPath $Path
      $acl.SetOwner([Security.Principal.SecurityIdentifier]::new($sid))
      $acl.SetAccessRuleProtection($true,$false)
      foreach ($rule in @($acl.GetAccessRules($true,$false,[Security.Principal.SecurityIdentifier]))) { $acl.RemoveAccessRuleSpecific($rule) }
      foreach ($who in $sid,'S-1-5-18','S-1-5-32-544') {
        $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.SecurityIdentifier]::new($who),'FullControl','ContainerInherit,ObjectInherit','None','Allow'))
      }
      Set-Acl -LiteralPath $Path -AclObject $acl
      Assert-CoordProtection $Path $sid
    }
    function handoffHistory {
      if ([IO.File]::Exists($historyRoot)) { throw 'HandoffHistoryRootMustBeDirectory' }
      if (-not [IO.Directory]::Exists($historyRoot)) {
        return [ordered]@{condition='Absent';bindingDigest='none';headDigest='none';ordinal=0L;pendingDigest='none'}
      }
      $null = Get-CoordRecoveryHistoryRoot
      if (-not [IO.File]::Exists((Join-Path $historyRoot 'binding.json'))) {
        $children = @(Get-ChildItem -LiteralPath $historyRoot -Force -ErrorAction Stop)
        if (@($children | Where-Object Name -ne 'history.lock').Count) { throw 'HandoffMalformedHistoryRequiresCustodian' }
        return [ordered]@{condition=$(if($children.Count){'LockOnly'}else{'Empty'});bindingDigest='none';headDigest='none';ordinal=0L;pendingDigest='none'}
      }
      $view = Read-CoordRecoveryHistory $historyRoot
      [ordered]@{condition=$(if($view.Pending){'Pending'}else{'Ready'})
        bindingDigest=Get-CoordHash (handoffRead (Join-Path $historyRoot 'binding.json'))
        headDigest=$view.Digest;ordinal=[long]$view.Ordinal
        pendingDigest=$(if($view.Pending){$view.Pending.Digest}else{'none'})}
    }
    function handoffCheckpoint {
      $s = handoffRead $statePath; $w = handoffRead $recordPath
      if ((Get-CoordHash $s) -ceq $plan.Pairs.Target.State -and
          (Get-CoordHash $w) -ceq $finalWitnessDigest) { return 'FinalPair' }
      Get-CoordSuccessorCheckpoint -Plan $plan -IntentBytes $plannerBytes -ExpectedIntentSha256 $p.plannerIntentSha256 `
        -BeforeStateBytes $beforeState -BeforeWitnessBytes $beforeWitness -ExpectedPairPinsBytes $pairBytes `
        -ExpectedPairPinsSha256 (Get-CoordHash $pairBytes) -StateBytes $s -WitnessBytes $w
    }
    function handoffWindow($Grant, $Exclusion) {
      $now = [DateTimeOffset]::UtcNow
      $start = [DateTimeOffset]::Parse([string]$Grant.notBeforeUtc,[Globalization.CultureInfo]::InvariantCulture)
      $end = [DateTimeOffset]::Parse([string]$Grant.notAfterUtc,[Globalization.CultureInfo]::InvariantCulture)
      if ($start.Offset -ne [TimeSpan]::Zero -or $end.Offset -ne [TimeSpan]::Zero -or
          $end -le $start -or ($end-$start).TotalMinutes -gt 15 -or $now -lt $start -or $now -ge $end) { throw 'HandoffOutsideApprovedWindow' }
      $es = [DateTimeOffset]::Parse([string]$Exclusion.notBeforeUtc,[Globalization.CultureInfo]::InvariantCulture)
      $ee = [DateTimeOffset]::Parse([string]$Exclusion.notAfterUtc,[Globalization.CultureInfo]::InvariantCulture)
      if ($es -gt $start -or $ee -lt $end) { throw 'HandoffExclusionWindowMismatch' }
    }
    function handoffWorkers {
      $workers = @($targetRecord.actors | Where-Object { $_.role -ceq 'Worker' })
      if ($workers.Count -gt 1 -or ($workers.Count -eq 1 -and -not (handoffSame $workers[0] $p.finalWorker))) { throw 'HandoffUnboundWorker' }
      if ($workers.Count) { return ,$plan.TargetWitness }
      # Update-CoordWitness requires each frozen property's raw JSON, including
      # each retained actor, to remain exact. Canonicalizing the whole object
      # would reorder the planner's new Coordinator tuple.
      $members = foreach ($property in (Read-CoordJsonBytes $plan.TargetWitness).EnumerateObject()) {
        $value = $property.Value.GetRawText()
        if ($property.Name -ceq 'actors') {
          $actors = @($property.Value.EnumerateArray() | ForEach-Object { $_.GetRawText() })
          $actors += (ConvertTo-CoordElement $p.finalWorker).GetRawText()
          $value = '[' + ($actors -join ',') + ']'
        }
        (ConvertTo-Json -InputObject $property.Name -Compress) + ':' + $value
      }
      $bytes = [Text.Encoding]::UTF8.GetBytes('{' + ($members -join ',') + '}')
      Assert-CoordActorRetirement (Read-CoordJsonBytes $bytes) $sid
      return ,$bytes
    }
    function handoffWorkerEvidence([string]$UpdateId, [string]$Reference) {
      $prefix = $recordPath + '.update-' + $UpdateId
      $expected = [ordered]@{
        'before.bin'=$plan.TargetWitness; 'after.bin'=$finalWitness
        'intent.json'=(handoffBytes ([ordered]@{updateId=$UpdateId;approvalReference=$Reference
          resourceId=$targetRecord.resourceId;lineageId=$targetRecord.lineageId;generation=$targetRecord.generation
          beforeDigest=$plan.Pairs.Target.Witness;afterDigest=$finalWitnessDigest}))
        'receipt.json'=(handoffBytes ([ordered]@{updateId=$UpdateId;status='Updated'
          beforeDigest=$plan.Pairs.Target.Witness;afterDigest=$finalWitnessDigest;stateDigest=$plan.Pairs.Target.State}))
      }
      $found = @{}
      foreach ($suffix in $expected.Keys) {
        $path = $prefix + '.' + $suffix
        $found[$suffix] = [IO.File]::Exists($path)
        if ($found[$suffix] -and (Get-CoordHash (handoffRead $path)) -cne (Get-CoordHash $expected[$suffix])) { throw 'HandoffWorkerAuditCorrupt' }
      }
      if ($found['receipt.json'] -and @($found.Keys | Where-Object { -not $found[$_] }).Count) { throw 'HandoffWorkerAuditIncomplete' }
      if ($found['receipt.json']) { return 'OrdinaryReceiptComplete' }
      if ($found['before.bin'] -and $found['after.bin'] -and $found['intent.json'] -and
          (handoffCheckpoint) -ceq 'FinalPair') { return 'OrdinaryReceiptMissing' }
      'BeforeOrPartialAudit'
    }
    function handoffLastWorker {
      if (-not [IO.Directory]::Exists($auditRoot)) { return $null }
      $files = @(Get-ChildItem -LiteralPath $auditRoot -Filter 'worker-*.once.json' -File -ErrorAction Stop)
      if ($files.Count -gt 16) { throw 'HandoffWorkerAttemptLimit' }
      $rows = @(foreach ($file in $files) {
        $bytes = handoffRead $file.FullName
        $row = ConvertFrom-CoordElement (Read-CoordJsonBytes $bytes)
        if ($row.kind -cne 'Coordination-handoff-worker-attempt-v1' -or $row.packetDigest -cne $packetDigest -or
            $row.beforeWitnessDigest -cne $plan.Pairs.Target.Witness -or $row.afterWitnessDigest -cne $finalWitnessDigest -or
            $row.stateDigest -cne $plan.Pairs.Target.State -or $row.ordinal -isnot [long] -or $row.ordinal -lt 1) { throw 'HandoffWorkerAttemptInvalid' }
        $null = handoffGuid $row.updateId
        if ($file.Name -cne ('worker-'+$row.updateId+'.once.json')) { throw 'HandoffWorkerAttemptInvalid' }
        [pscustomobject]@{Record=$row;Digest=Get-CoordHash $bytes}
      })
      $rows = @($rows | Sort-Object { $_.Record.ordinal })
      for($i=0;$i -lt $rows.Count;$i++){if($rows[$i].Record.ordinal -ne $i+1){throw 'HandoffWorkerAttemptInvalid'}}
      if($rows.Count){$rows[-1]}else{$null}
    }
    function handoffTakeLeases {
      $null = Assert-CoordOrdinaryPath (Join-Path $recordDirectory 'resource.lock') -MustExist
      $null = Assert-CoordOrdinaryPath $boardLockPath -MustExist
      $resource = Enter-CoordResourceLease -StateDirectory $recordDirectory
      try { $board = [IO.File]::Open($boardLockPath,'Open','ReadWrite','None') }
      catch { $resource.Dispose(); throw }
      [pscustomobject]@{Resource=$resource;Board=$board}
    }
    function handoffRelease($Leases) {
      if($Leases){try{$Leases.Board.Dispose()}finally{$Leases.Resource.Dispose()}}
    }
    function handoffAuthorityKnown([string]$Digest) {
      if(-not [IO.File]::Exists($attemptPath)){return $false}
      $originBytes=handoffRead $attemptPath
      $origin=ConvertFrom-CoordElement (Read-CoordJsonBytes $originBytes)
      if($origin.kind -cne 'Coordination-handoff-attempt-v1' -or $origin.packetDigest -cne $packetDigest -or
          $origin.planDigest -cne $planDigest -or $origin.codeDigest -cne $codeDigest){throw 'HandoffAttemptBindingInvalid'}
      $originalGrantBytes=handoffBase64 $origin.approvalBase64
      $originalGrant=ConvertFrom-CoordElement (Read-CoordJsonBytes $originalGrantBytes)
      if((Get-CoordHash $originalGrantBytes) -cne $origin.approvalDigest -or
          $originalGrant.kind -cne 'Coordination-custody-handoff-approval-v1' -or $originalGrant.mode -cne 'Apply' -or
          $originalGrant.packetDigest -cne $packetDigest -or $originalGrant.planDigest -cne $planDigest -or
          $originalGrant.codeDigest -cne $codeDigest){throw 'HandoffAttemptAuthorityInvalid'}
      if($Digest -ceq $origin.approvalDigest){return $originalGrant}
      $files=@(Get-ChildItem -LiteralPath $recordDirectory -Filter ('handoff-'+$id+'.recover-*.once.json') -File -ErrorAction Stop)
      if($files.Count -gt 16){throw 'HandoffRecoveryAttemptLimit'}
      foreach($file in $files){
        $row=ConvertFrom-CoordElement (Read-CoordJsonBytes (handoffRead $file.FullName))
        $bytes=handoffBase64 $row.approvalBase64
        $authority=ConvertFrom-CoordElement (Read-CoordJsonBytes $bytes)
        if($row.packetDigest -cne $packetDigest -or $row.originDigest -cne (Get-CoordHash $originBytes) -or
            $row.approvalDigest -cne (Get-CoordHash $bytes) -or
            $authority.kind -cne 'Coordination-custody-handoff-approval-v1' -or $authority.mode -cne 'Recover' -or
            $authority.packetDigest -cne $packetDigest -or $authority.planDigest -cne $planDigest -or
            $authority.codeDigest -cne $codeDigest -or $authority.custodianSid -cne $sid -or
            $file.Name -cne ('handoff-'+$id+'.recover-'+$authority.approvalId+'.once.json')){throw 'HandoffRecoveryAuthorityInvalid'}
        if($row.approvalDigest -ceq $Digest){return $authority}
      }
      $false
    }
    function handoffValidateRecovery {
      $recoveryElement=$approvalElement.GetProperty('recovery')
      Assert-SuccessorPlanObject $recoveryElement @('priorAttemptDigest','checkpoint','action','historyPendingDigest',
        'historyOutcome','workerAttemptDigest','workerUpdateId') 'HandoffRecoveryInvalid'
      foreach($field in 'priorAttemptDigest','checkpoint','action','historyPendingDigest','historyOutcome','workerAttemptDigest','workerUpdateId'){
        $null=Get-SuccessorPlanText $recoveryElement $field
      }
      $recovery=$grant.recovery
      if($recovery.action -cnotin @('ContinueInitialization','ContinuePlanner','RetryWorkerBefore','AcknowledgeWorkerAfter','Finalize')){
        throw 'HandoffRecoveryActionInvalid'
      }
      if($recovery.checkpoint -cne $current -or $current -ceq 'ThirdState'){throw 'HandoffRecoveryCheckpointMismatch'}
      if($lastWorker -and $current -cnotin @('Target','FinalPair')){throw 'HandoffWorkerAttemptCheckpointMismatch'}
      switch -CaseSensitive ($recovery.action) {
        'ContinueInitialization' {
          if($current -cne 'Before' -or $history.condition -cnotin @('Absent','Empty','LockOnly') -or -not $p.initializeHistory){
            throw 'HandoffRecoveryActionMismatch'
          }
        }
        'ContinuePlanner' {
          if($current -cnotin @('Before','FencedBeforeState','FencedAfterState','Target') -or
              $history.condition -cnotin @('Ready','Pending') -or $lastWorker){throw 'HandoffRecoveryActionMismatch'}
        }
        'RetryWorkerBefore' {
          if(-not $needsWorker -or $current -cne 'Target' -or -not $lastWorker -or
              $recovery.workerAttemptDigest -cne $lastWorker.Digest -or
              (handoffWorkerEvidence $lastWorker.Record.updateId $lastWorker.Record.approvalReference) -ceq 'OrdinaryReceiptComplete'){
            throw 'HandoffRecoveryWorkerBindingMismatch'
          }
        }
        'AcknowledgeWorkerAfter' {
          if(-not $needsWorker -or $current -cne 'FinalPair' -or -not $lastWorker -or
              $recovery.workerAttemptDigest -cne $lastWorker.Digest -or $recovery.workerUpdateId -cne $lastWorker.Record.updateId -or
              (handoffWorkerEvidence $lastWorker.Record.updateId $lastWorker.Record.approvalReference) -cne 'OrdinaryReceiptMissing'){
            throw 'HandoffRecoveryWorkerBindingMismatch'
          }
        }
        'Finalize' {
          if($current -cne 'FinalPair' -or ($needsWorker -and (-not $lastWorker -or
              $recovery.workerAttemptDigest -cne $lastWorker.Digest -or
              (handoffWorkerEvidence $lastWorker.Record.updateId $lastWorker.Record.approvalReference) -cne 'OrdinaryReceiptComplete'))){
            throw 'HandoffRecoveryActionMismatch'
          }
        }
      }
      if($needsWorker -and $current -cne 'FinalPair'){
        $nextId=handoffGuid $recovery.workerUpdateId
        if([IO.File]::Exists((Join-Path $auditRoot ('worker-'+$nextId+'.once.json'))) -or
            @(Get-ChildItem -LiteralPath $recordDirectory -Filter (([IO.Path]::GetFileName($recordPath))+'.update-'+$nextId+'.*') -File).Count){
          throw 'HandoffRecoveryWorkerIdConsumed'
        }
      }
      if($history.condition -ceq 'Pending'){
        if($recovery.historyPendingDigest -cne $history.pendingDigest -or $recovery.historyOutcome -cnotin @('Committed','Aborted')){
          throw 'HandoffPendingHistoryNeedsExactRecovery'
        }
        $pending=(Read-CoordRecoveryHistory $historyRoot).Pending.Record
        $known=$false
        foreach($edge in @(
          @($plan.Pairs.Before,$plan.Pairs.FencedBeforeState),
          @($plan.Pairs.FencedBeforeState,$plan.Pairs.FencedAfterState),
          @($plan.Pairs.FencedAfterState,$plan.Pairs.Target),
          @($plan.Pairs.Target,@{State=$plan.Pairs.Target.State;Witness=$finalWitnessDigest}))){
          if((handoffSame $pending.before @{state=$edge[0].State;custody=$edge[0].Witness}) -and
              (handoffSame $pending.after @{state=$edge[1].State;custody=$edge[1].Witness})){$known=$true}
        }
        $expected=if($recovery.historyOutcome -ceq 'Committed'){$pending.after}else{$pending.before}
        $actual=handoffPair
        if(-not $known -or -not (handoffSame $expected @{state=$actual.state;custody=$actual.witness})){
          throw 'HandoffPendingHistoryPairMismatch'
        }
      } elseif($recovery.historyPendingDigest -cne 'none' -or $recovery.historyOutcome -cne 'none'){
        throw 'HandoffUnexpectedHistoryResolution'
      }
    }
    function handoffRequireAcknowledgement($Authority) {
      if (-not $Authority -or $Authority.mode -cne 'Recover' -or
          $Authority.recovery.action -cne 'AcknowledgeWorkerAfter' -or
          $Authority.recovery.checkpoint -cne 'FinalPair' -or -not $lastWorker -or
          $Authority.recovery.workerAttemptDigest -cne $lastWorker.Digest -or
          $Authority.recovery.workerUpdateId -cne $lastWorker.Record.updateId -or
          $Authority.recovery.priorAttemptDigest -cne (Get-CoordHash (handoffRead $attemptPath))) {
        throw 'HandoffFinalReceiptAcknowledgementMismatch'
      }
    }
    # ---- Package-only custody transition helpers (ApplyPackage / RecoverPackage) ----
    function pkgUtc { [DateTimeOffset]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ',[Globalization.CultureInfo]::InvariantCulture) }
    function pkgDisabledImage([byte[]]$Witness) {
      # The same witness with only the policy switched off and any pendingWrite cleared.
      $members = Get-CoordMembers (Read-CoordJsonBytes $Witness)
      $policy = $members['autoPackageAdmission']
      if ($null -eq $policy -or $policy.ValueKind -ne [Text.Json.JsonValueKind]::Object) { throw 'PackagePolicyAbsent' }
      $policyMembers = Get-CoordMembers $policy
      $policyMembers['enabled'] = $false
      $members['autoPackageAdmission'] = $policyMembers
      $members['pendingWrite'] = $null
      return ,(ConvertTo-SuccessorPlanBytes $members)
    }
    function pkgCheckpoint {
      $stateDigest = Get-CoordHash (handoffRead $statePath)
      $witnessDigest = Get-CoordHash (handoffRead $recordPath)
      if ($stateDigest -cne $pkgPlan.Pairs.Before.State) { return 'ThirdState' }
      if ($witnessDigest -ceq $pkgPlan.Pairs.Before.Witness) { return 'Before' }
      if ($witnessDigest -ceq $pkgPlan.Pairs.Fenced.Witness) { return 'Fenced' }
      if ($witnessDigest -ceq $pkgPlan.Pairs.Target.Witness) { return 'Target' }
      foreach ($pair in @(@('Before',$pkgBeforeWitness),@('Fenced',$pkgPlan.FencedWitness),@('Target',$pkgPlan.TargetWitness))) {
        if ((Get-CoordHash (pkgDisabledImage $pair[1])) -ceq $witnessDigest) { return ('Disabled' + $pair[0]) }
      }
      'ThirdState'
    }
    function pkgQuartet($StateElement, $Expected, [string]$Failure = 'PackageQuartetChanged') {
      # Reads every board file under the held lease and compares it to the published head
      # recorded in state.json and, when supplied, to the digests captured earlier.
      $outputs = [ordered]@{}
      foreach ($slot in 'markdown','boardHtml','proceduralDetailsHtml','accomplishedHtml') {
        $entry = $StateElement.GetProperty('committedOutputManifest').GetProperty($slot)
        $path = Get-SuccessorPlanText $entry 'path'
        $digest = Get-CoordHash (handoffRead $path)
        if ($digest -cne (Get-SuccessorPlanText $entry 'digest')) { throw $Failure }
        if ($Expected -and $digest -cne $Expected[$slot].digest) { throw $Failure }
        $outputs[$slot] = [ordered]@{ path = $path; digest = $digest }
      }
      $outputs
    }
    function pkgTryDisable([string]$Reason) {
      # Switches custody.autoPackageAdmission.enabled off, but only when that single custody
      # write is itself safe: the witness is one of this operation's known images, state.json
      # still matches it, any pendingWrite is this operation's own fence, and recovery history
      # is complete and coherent. Otherwise nothing is written and the record is left as found.
      try {
        $current = handoffRead $recordPath
        if ($pkgKnown -cnotcontains (Get-CoordHash $current)) { return 'DisableUnsafe_UnknownWitness_HeldAsFound' }
        $element = Read-CoordJsonBytes $current
        if ($element.GetProperty('custodianSid').GetString() -cne $sid) { return 'DisableUnsafe_CustodianMismatch_HeldAsFound' }
        if ((Get-CoordHash (handoffRead $statePath)) -cne $element.GetProperty('stateSha256').GetString()) { return 'DisableUnsafe_StateMismatch_HeldAsFound' }
        $pending = $element.GetProperty('pendingWrite')
        if ($pending.ValueKind -ne [Text.Json.JsonValueKind]::Null -and
            ($pending.ValueKind -ne [Text.Json.JsonValueKind]::Object -or
             (Get-SuccessorPlanText $pending 'kind') -cne 'PackageAdmission' -or
             (Get-SuccessorPlanText $pending 'operationId') -cne $id)) { return 'DisableUnsafe_ForeignPendingWrite_HeldAsFound' }
        $policy = [Text.Json.JsonElement]::new()
        if (-not $element.TryGetProperty('autoPackageAdmission',[ref]$policy) -or $policy.ValueKind -ne [Text.Json.JsonValueKind]::Object) { return 'DisableNotApplicable_PolicyAbsent' }
        if ($policy.GetProperty('enabled').ValueKind -eq [Text.Json.JsonValueKind]::False) { return 'AlreadyDisabled' }
        Assert-CoordRecoveryPair (Read-CoordRecoveryHistory $historyRoot)
        $disabled = pkgDisabledImage $current
        Write-CoordAtomicBytes -Path $recordPath -ExpectedBytes $current -Bytes $disabled
        if ((Get-CoordHash (handoffRead $recordPath)) -cne (Get-CoordHash $disabled)) { return 'DisableReadbackFailed_Held' }
        try {
          handoffNew ($pkgPrefix + '.disabled.json') (handoffBytes ([ordered]@{kind='Coordination-package-admission-disabled-v1';operationId=$id
            reason=$Reason;disabledAtUtc=(pkgUtc);beforeWitnessDigest=(Get-CoordHash $current);afterWitnessDigest=(Get-CoordHash $disabled)}))
        } catch {}
        'Disabled'
      } catch { 'DisableUnsafeOrFailed_Held' }
    }
    $pkgNotNowCodes = @('PendingWritePresent','OperationInFlight','MutationNotAdmitted','PackageQuartetChangedBeforeAttempt')
    $pkgDisableConfirmed = @('Disabled','AlreadyDisabled','NotDisabled_NotNowRefusal')
    function pkgHeld { [IO.File]::Exists($holdPath) -or [IO.Directory]::Exists($holdPath) }
    function pkgWriteHold([string]$Code,[string]$DisableOutcome) {
      # When the policy could not be switched off safely, a durable custodian-side marker makes every
      # later ApplyPackage refuse until a human reviews and removes it. Never silently skipped:
      # the outcome (Written, AlreadyHeld, WriteFailed) is reported in the thrown error's structured data.
      try {
        if (pkgHeld) { return 'AlreadyHeld' }
        handoffNew $holdPath (handoffBytes ([ordered]@{kind='Coordination-package-admission-hold-v1';operationId=$id;code=$Code
          policyDisable=$DisableOutcome;heldAtUtc=(pkgUtc)}))
        'Written'
      } catch { 'WriteFailed' }
    }
  }
  process {
    $expectedSet = switch -CaseSensitive ($Mode) { 'ApplyPackage' { 'Package' } 'RecoverPackage' { 'PackageRecover' } default { 'Handoff' } }
    if ($PSCmdlet.ParameterSetName -cne $expectedSet) { throw 'HandoffPackageModeParameterSetMismatch' }
    if ($Mode -cin @('ApplyPackage','RecoverPackage')) {
      $pkgApply = $Mode -ceq 'ApplyPackage'
      foreach ($value in $AttestationPath,$NupkgPath) { if ($pkgApply -and [string]::IsNullOrWhiteSpace($value)) { throw 'PackageApplyRequiresAttestationAndNupkgPaths' } }
      if (-not $PSCmdlet.ShouldProcess($OperationId,"$Mode one package-only custody admission")) {
        return [pscustomobject]@{Status='ProposedOnly';LiveAdmission=$false}
      }
      $ErrorActionPreference='Stop'
      $null=Get-Command Write-PSFMessage -ErrorAction Stop
      $module=$MyInvocation.MyCommand.Module
      if(-not $module){throw 'HandoffRequiresSelectedModule'}
      $moduleRoot=$module.ModuleBase
      $codeDigest=Get-CoordHash (handoffRead $module.Path)
      # The root whose bytes are verified and admitted: always a separate root (mandatory for ApplyPackage), so the
      # running module can never be the thing that vouches for itself. RecoverPackage reads it from the once file.
      $candidateRoot=$null
      if($pkgApply){
        if([string]::IsNullOrWhiteSpace($CandidateModuleRoot) -or -not [IO.Directory]::Exists($CandidateModuleRoot)){throw 'PackageCandidateModuleRootMissing'}
        $candidateFull=[IO.Path]::GetFullPath($CandidateModuleRoot).TrimEnd('\')
        if($candidateFull -ieq [IO.Path]::GetFullPath($moduleRoot).TrimEnd('\')){throw 'PackageCandidateMustDifferFromRunningModule'}
        $null=Assert-CoordOrdinaryPath $candidateFull -MustExist
        $candidateRoot=$candidateFull
      }
      $id=handoffGuid $OperationId
      $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
      try{$sid=$identity.User.Value}finally{$identity.Dispose()}
      $stateRoot=[IO.Path]::GetFullPath((Get-CoordSetting 'OrchestrationStateRootPath'))
      $statePath=Join-Path $stateRoot 'state.json'
      $recordPath=[IO.Path]::GetFullPath((Get-CoordSetting 'OrchestrationCustodyRecordPath'))
      $recordDirectory=[IO.Path]::GetDirectoryName($recordPath)
      $programData=Get-CoordProgramDataPath
      $firstWitness=Read-CoordJsonBytes (handoffRead $recordPath)
      if(-not (Test-CoordDescendant $stateRoot $programData) -or -not (Test-CoordDescendant $recordPath $programData) -or
          (Test-CoordDescendant $recordPath $stateRoot) -or $firstWitness.GetProperty('statePath').GetString() -ine $statePath){throw 'HandoffProtectedLocationMismatch'}
      if($firstWitness.GetProperty('custodianSid').GetString() -cne $sid){throw 'HandoffCustodianMismatch'}
      foreach($path in $stateRoot,$recordDirectory,$statePath,$recordPath){$null=Assert-CoordOrdinaryPath $path -MustExist;Assert-CoordProtection $path $sid}
      $boardLockPath=[IO.Path]::GetFullPath($firstWitness.GetProperty('boardLockPath').GetString())
      $historyRoot=[IO.Path]::GetFullPath((Get-CoordSetting 'OrchestrationRecoveryHistoryRootPath'))
      if(-not (Test-CoordDescendant $historyRoot $programData) -or
          $historyRoot -ieq $stateRoot -or (Test-CoordDescendant $historyRoot $stateRoot) -or (Test-CoordDescendant $stateRoot $historyRoot) -or
          $historyRoot -ieq $recordDirectory -or (Test-CoordDescendant $historyRoot $recordDirectory) -or
          (Test-CoordDescendant $recordDirectory $historyRoot)){throw 'HandoffHistoryLocationMismatch'}
      $null=Assert-CoordOrdinaryPath $historyRoot
      Assert-CoordProtection ([IO.Path]::GetDirectoryName($historyRoot)) $sid
      $pkgPrefix=Join-Path $recordDirectory ('package-'+$id)
      $holdPath=Join-Path $recordDirectory 'package-admission.hold.json'
      $oncePath=$pkgPrefix+'.once.json'
      $auditRoot=$pkgPrefix
      $receiptPath=Join-Path $auditRoot 'final.receipt.json'
      $leases=$null;$consumed=$false;$disableEligible=$false
      $pkgPlan=$null;$pkgBeforeWitness=$null
      $pkgKnown=[Collections.Generic.List[string]]::new()
      try {
        $leases=handoffTakeLeases
        $pkgBeforeWitness=handoffRead $recordPath
        $beforeState=handoffRead $statePath
        $witnessElement=Read-CoordJsonBytes $pkgBeforeWitness
        $stateElement=Read-CoordJsonBytes $beforeState
        if($witnessElement.GetProperty('custodianSid').GetString() -cne $sid){throw 'HandoffCustodianMismatch'}
        if((Get-CoordHash $beforeState) -cne $witnessElement.GetProperty('stateSha256').GetString()){throw 'CustodyBindingConflict'}
        $pkgKnown.Add((Get-CoordHash $pkgBeforeWitness))
        $policyElement=[Text.Json.JsonElement]::new()
        if(-not $witnessElement.TryGetProperty('autoPackageAdmission',[ref]$policyElement) -or
            $policyElement.ValueKind -eq [Text.Json.JsonValueKind]::Null){throw 'PackagePolicyAbsent'}
        if($policyElement.ValueKind -ne [Text.Json.JsonValueKind]::Object -or
            ($policyElement.GetProperty('enabled').ValueKind -ne [Text.Json.JsonValueKind]::True -and
             $policyElement.GetProperty('enabled').ValueKind -ne [Text.Json.JsonValueKind]::False)){throw 'InvalidPackagePolicy'}
        if($policyElement.GetProperty('enabled').ValueKind -eq [Text.Json.JsonValueKind]::False){throw 'PackagePolicyDisabled'}
        # A hold marker means an earlier failure could not switch the policy off safely: only a human clears it.
        if($pkgApply -and (pkgHeld)){throw 'PackageAdmissionHeldUnsafeDisable'}
        # An already consumed or unknown operation is a plain refusal, not an attestation failure.
        if($pkgApply){
          if([IO.File]::Exists($oncePath) -or [IO.Directory]::Exists($auditRoot)){throw 'PackageApplyNotFresh'}
        } elseif(-not [IO.File]::Exists($oncePath)){throw 'PackageRecoveryHasNoKnownOrigin'}
        $disableEligible=$true
        $custodyVersion=Get-SuccessorPlanText ($witnessElement.GetProperty('package')) 'moduleVersion'
        # Hash the board quartet under the held leases before anything is consumed.
        $outputs=pkgQuartet $stateElement $null 'PackageQuartetChangedBeforeAttempt'
        if($pkgApply){
          $history=handoffHistory
          if($history.condition -cne 'Ready'){throw 'PackageRequiresReadyRecoveryHistory'}
          Assert-CoordRecoveryPair (Read-CoordRecoveryHistory $historyRoot)
          $attBytes=handoffRead $AttestationPath $ExpectedAttestationSha256 4194304
          $attFileDigest=Get-CoordHash $attBytes
          $attestation=ConvertFrom-CoordElement (Read-CoordJsonBytes $attBytes)
          $nupkgFull=Assert-CoordOrdinaryPath $NupkgPath -MustExist
          $verdict=Test-CoordPackageAttestation -ModuleRoot $candidateRoot -AttestationPath $AttestationPath `
            -Policy ([pscustomobject](ConvertFrom-CoordElement $policyElement)) -NupkgPath $nupkgFull -CurrentVersion $custodyVersion
          if(-not $verdict.Valid){throw ('PackageAttestationRejected:'+$verdict.ReasonCode)}
          if((Get-CoordHash (handoffRead $AttestationPath)) -cne $attFileDigest){throw 'PackageAttestationChangedDuringVerification'}
          # Read only after verification: the verified inventory covers this file.
          $schema=handoffRead (Join-Path $candidateRoot 'schemas/state-v1.schema.json')
          $admittedAtUtc=pkgUtc
          $pkgPlan=New-CoordPackageAdmissionPlan -StateBytes $beforeState -WitnessBytes $pkgBeforeWitness -StateSchemaBytes $schema `
            -Attestation $attestation -ObservedSid $sid -OperationId $id -AdmittedAtUtc $admittedAtUtc
        } else {
          $onceBytes=handoffRead $oncePath
          $once=ConvertFrom-CoordElement (Read-CoordJsonBytes $onceBytes)
          if($once.kind -cne 'Coordination-package-admission-attempt-v1' -or $once.operationId -cne $id -or
              $once.codeDigest -cne $codeDigest){throw 'PackageRecoveryBindingMismatch'}
          $attBytes=handoffBase64 $once.attestationBase64
          $attFileDigest=Get-CoordHash $attBytes
          if($attFileDigest -cne $once.attestationFileSha256){throw 'PackageRecoveryAttestationMismatch'}
          $attestation=ConvertFrom-CoordElement (Read-CoordJsonBytes $attBytes)
          $originalWitness=handoffBase64 $once.beforeWitnessBase64
          if((Get-CoordHash $originalWitness) -cne $once.pairs.before.witness -or
              (Get-CoordHash $beforeState) -cne $once.pairs.before.state){throw 'PackageRecoveryThirdState'}
          # Recovery re-verifies the same candidate the apply attempt recorded; an attempt without one is not recoverable.
          if(-not $once.Contains('candidateModuleRoot') -or [string]::IsNullOrWhiteSpace([string]$once.candidateModuleRoot)){throw 'PackageRecoveryCandidateRootMissing'}
          $candidateRoot=[IO.Path]::GetFullPath([string]$once.candidateModuleRoot).TrimEnd('\')
          if($candidateRoot -ieq [IO.Path]::GetFullPath($moduleRoot).TrimEnd('\')){throw 'PackageCandidateMustDifferFromRunningModule'}
          $null=Assert-CoordOrdinaryPath $candidateRoot -MustExist
          $schema=handoffRead (Join-Path $candidateRoot 'schemas/state-v1.schema.json')
          $admittedAtUtc=[string]$once.admittedAtUtc
          $pkgPlan=New-CoordPackageAdmissionPlan -StateBytes $beforeState -WitnessBytes $originalWitness -StateSchemaBytes $schema `
            -Attestation $attestation -ObservedSid $sid -OperationId $id -AdmittedAtUtc $admittedAtUtc
          $pkgBeforeWitness=$originalWitness
        }
        $pairs=[ordered]@{
          before=[ordered]@{state=$pkgPlan.Pairs.Before.State;witness=$pkgPlan.Pairs.Before.Witness}
          fenced=[ordered]@{state=$pkgPlan.Pairs.Fenced.State;witness=$pkgPlan.Pairs.Fenced.Witness}
          target=[ordered]@{state=$pkgPlan.Pairs.Target.State;witness=$pkgPlan.Pairs.Target.Witness}}
        $planDigest=Get-CoordHash (handoffBytes ([ordered]@{kind='Coordination-package-admission-plan-v1';operationId=$id;admittedAtUtc=$admittedAtUtc
          fromVersion=$pkgPlan.FromVersion;toVersion=$pkgPlan.ToVersion;attestationSha256=$pkgPlan.AttestationSha256;pairs=$pairs}))
        foreach($digest in $pairs.fenced.witness,$pairs.target.witness){if($pkgKnown -cnotcontains $digest){$pkgKnown.Add($digest)}}
        if($pkgApply){
          $once=[ordered]@{kind='Coordination-package-admission-attempt-v1';operationId=$id;admittedAtUtc=$admittedAtUtc;codeDigest=$codeDigest
            attestationFileSha256=$attFileDigest;attestationBase64=[Convert]::ToBase64String($attBytes);nupkgPath=$nupkgFull;candidateModuleRoot=$candidateRoot
            fromVersion=$pkgPlan.FromVersion;toVersion=$pkgPlan.ToVersion;beforeWitnessBase64=[Convert]::ToBase64String($pkgBeforeWitness)
            pairs=$pairs;planDigest=$planDigest;quartet=$outputs;history=$history}
          handoffNew $oncePath (handoffBytes $once)
          $consumed=$true
        } else {
          if($once.planDigest -cne $planDigest -or $once.pairs.fenced.witness -cne $pairs.fenced.witness -or
              $once.pairs.target.witness -cne $pairs.target.witness){throw 'PackageRecoveryPlanDrift'}
          $outputs=pkgQuartet $stateElement $once.quartet 'PackageQuartetChangedBeforeAttempt'
          $markers=@(Get-ChildItem -LiteralPath $recordDirectory -Filter ('package-'+$id+'.recover-*.once.json') -File -ErrorAction Stop)
          if($markers.Count -ge 16){throw 'PackageRecoveryAttemptLimit'}
          # Resolve an interrupted custody write's pending history only against exact observed bytes.
          $history=handoffHistory
          if($history.condition -ceq 'Pending'){
            $pending=(Read-CoordRecoveryHistory $historyRoot).Pending.Record
            $images=@($pkgBeforeWitness,$pkgPlan.FencedWitness,$pkgPlan.TargetWitness)
            $edges=@(
              ,@($pairs.before.witness,$pairs.fenced.witness)
              ,@($pairs.fenced.witness,$pairs.target.witness))
            foreach($image in $images){$edges+=,@((Get-CoordHash $image),(Get-CoordHash (pkgDisabledImage $image)))}
            $known=$false
            foreach($edge in $edges){
              if($pending.before.state -ceq $pairs.before.state -and $pending.after.state -ceq $pairs.before.state -and
                  $pending.before.custody -ceq $edge[0] -and $pending.after.custody -ceq $edge[1]){$known=$true}
            }
            if(-not $known){throw 'PackageRecoveryUnrelatedPendingHistory'}
            $observed=handoffPair
            $outcome=if($observed.witness -ceq $pending.after.custody -and $observed.state -ceq $pending.after.state){'Committed'}
              elseif($observed.witness -ceq $pending.before.custody -and $observed.state -ceq $pending.before.state){'Aborted'}
              else{throw 'PackageRecoveryPendingHistoryPairMismatch'}
            $null=Write-CoordRecoveryHistory -Action Resolve -ExpectedIntentDigest $history.pendingDigest -Outcome $outcome -Confirm:$false
            $history=handoffHistory
          }
          if($history.condition -cne 'Ready'){throw 'PackageRequiresReadyRecoveryHistory'}
          $nupkgFull=Assert-CoordOrdinaryPath ([string]$once.nupkgPath) -MustExist
          $pending=$null
          $marker=[ordered]@{kind='Coordination-package-admission-recovery-v1';operationId=$id;originDigest=(Get-CoordHash $onceBytes);codeDigest=$codeDigest}
          $current=pkgCheckpoint
          if($current -cin @('DisabledBefore','DisabledFenced','DisabledTarget')){throw 'PackageAdmissionTerminalPolicyDisabled'}
          if($current -ceq 'ThirdState'){throw 'PackageRecoveryThirdState'}
          handoffNew ($pkgPrefix+'.recover-'+[guid]::NewGuid().ToString('D')+'.once.json') (handoffBytes $marker)
          $consumed=$true
        }
        Assert-CoordRecoveryPair (Read-CoordRecoveryHistory $historyRoot)
        if(-not [IO.Directory]::Exists($auditRoot)){handoffCreateProtectedDirectory $auditRoot}
        Assert-CoordProtection $auditRoot $sid
        foreach($item in @(@('before.witness.bin',$pkgBeforeWitness),@('before.state.bin',$beforeState),@('attestation.json',$attBytes))){
          $path=Join-Path $auditRoot $item[0]
          if([IO.File]::Exists($path)){
            if((Get-CoordHash (handoffRead $path)) -cne (Get-CoordHash $item[1])){throw 'PackageRetainedImageMismatch'}
          }else{handoffNew $path $item[1]}
        }
        if(-not $pkgApply){
          # Re-verify the retained attestation against the installed package before completing.
          $verdict=Test-CoordPackageAttestation -ModuleRoot $candidateRoot -AttestationPath (Join-Path $auditRoot 'attestation.json') `
            -Policy ([pscustomobject](ConvertFrom-CoordElement ((Read-CoordJsonBytes $pkgBeforeWitness).GetProperty('autoPackageAdmission')))) `
            -NupkgPath $nupkgFull -CurrentVersion ([string]$once.fromVersion)
          if(-not $verdict.Valid){throw ('PackageAttestationRejected:'+$verdict.ReasonCode)}
        }
        $current=pkgCheckpoint
        foreach($step in @(
          @{Before='Before';After='Fenced';Expected=$pkgBeforeWitness;Bytes=$pkgPlan.FencedWitness},
          @{Before='Fenced';After='Target';Expected=$pkgPlan.FencedWitness;Bytes=$pkgPlan.TargetWitness})){
          if($current -cne $step.Before){continue}
          Write-CoordAtomicBytes -Path $recordPath -ExpectedBytes $step.Expected -Bytes $step.Bytes
          $current=pkgCheckpoint
          if($current -cne $step.After){throw 'PackageCheckpointReadbackFailed'}
        }
        if($current -cne 'Target'){throw 'PackageUnknownCheckpoint'}
        # Fail closed on any change after the write: state, quartet, history and package.
        if((Get-CoordHash (handoffRead $statePath)) -cne $pkgPlan.Pairs.Before.State){throw 'PackageStateChanged'}
        $null=pkgQuartet (Read-CoordJsonBytes (handoffRead $statePath)) $outputs
        Assert-CoordRecoveryPair (Read-CoordRecoveryHistory $historyRoot)
        $finalWitnessBytes=handoffRead $recordPath
        $targetElement=Read-CoordJsonBytes $finalWitnessBytes
        $targetPackage=ConvertFrom-CoordElement ($targetElement.GetProperty('package'))
        Assert-CoordPackageInventory -ModuleRoot $candidateRoot -Package $targetPackage
        if((Get-CoordHash (handoffRead $module.Path)) -cne $codeDigest){throw 'PackageCodeChanged'}
        $afterPath=Join-Path $auditRoot 'after.witness.bin'
        if([IO.File]::Exists($afterPath)){
          if((Get-CoordHash (handoffRead $afterPath)) -cne (Get-CoordHash $finalWitnessBytes)){throw 'PackageRetainedImageMismatch'}
        }else{handoffNew $afterPath $finalWitnessBytes}
        $history=handoffHistory
        if($history.condition -cne 'Ready'){throw 'PackageRequiresReadyRecoveryHistory'}
        $receipt=[ordered]@{kind='Coordination-package-admission-receipt-v1';status='PackageAdmitted';operationId=$id
          fromVersion=$pkgPlan.FromVersion;toVersion=$pkgPlan.ToVersion;attestationSha256=$pkgPlan.AttestationSha256
          attestationFileSha256=$attFileDigest;planDigest=$planDigest;codeDigest=$codeDigest
          generation=$targetElement.GetProperty('generation').GetString();stateChanged=$false;generationChanged=$false
          finalPair=handoffPair;quartet=$outputs;history=$history}
        if([IO.File]::Exists($receiptPath)){
          $existing=ConvertFrom-CoordElement (Read-CoordJsonBytes (handoffRead $receiptPath))
          if($existing.kind -cne $receipt.kind -or $existing.operationId -cne $id -or $existing.planDigest -cne $planDigest -or
              $existing.finalPair.state -cne $receipt.finalPair.state -or $existing.finalPair.witness -cne $receipt.finalPair.witness){throw 'PackageFinalReceiptMismatch'}
        }else{handoffNew $receiptPath (handoffBytes $receipt)}
        # An exact, completed recovery of the very operation that left the hold marker reconciles it.
        $holdCleared=$false
        if(-not $pkgApply -and [IO.File]::Exists($holdPath)){
          try{
            $hold=ConvertFrom-CoordElement (Read-CoordJsonBytes (handoffRead $holdPath))
            if($hold.kind -ceq 'Coordination-package-admission-hold-v1' -and $hold.operationId -ceq $id){[IO.File]::Delete($holdPath);$holdCleared=$true}
          }catch{}
        }
        return [pscustomobject]@{Status='PackageAdmitted';Recovered=(-not $pkgApply);OperationId=$id;FromVersion=$pkgPlan.FromVersion;ToVersion=$pkgPlan.ToVersion
          ReceiptPath=$receiptPath;ReceiptSha256=(Get-CoordHash (handoffRead $receiptPath));PlanDigest=$planDigest
          FinalPair=handoffPair;StateChanged=$false;GenerationChanged=$false;History=$history;HoldCleared=$holdCleared}
      } catch {
        $primaryFailure=$_
        $disableOutcome='NotAttempted'
        # Busy collisions are ordinary concurrent activity: refuse without disabling the standing policy.
        $failureCode=([regex]::Match($primaryFailure.Exception.Message,'\A[A-Za-z][A-Za-z0-9_]*')).Value
        if(-not $failureCode){$failureCode='UnclassifiedApplyFailure'}
        $notNow=$primaryFailure.Exception.Message -cin $pkgNotNowCodes
        if($disableEligible -and $notNow){$disableOutcome='NotDisabled_NotNowRefusal'}
        elseif($disableEligible){$disableOutcome=pkgTryDisable $primaryFailure.Exception.Message}
        # M6: a disable that did not provably happen is never silent. It leaves a durable hold marker
        # that every later ApplyPackage refuses on, and the outcome travels in the error's structured data.
        $holdMarker='NotRequired'
        if($disableEligible -and $disableOutcome -cnotin $pkgDisableConfirmed){$holdMarker=pkgWriteHold $failureCode $disableOutcome}
        try{Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Package-only custody admission refused or held (policyDisable=$disableOutcome; holdMarker=$holdMarker); preserve consumed records and reconcile exact images/history before continuation."}catch{}
        $text=$primaryFailure.Exception.Message+' [policyDisable='+$disableOutcome+']'
        if($holdMarker -cne 'NotRequired'){$text+=' [holdMarker='+$holdMarker+']'}
        $thrown=if($consumed){[InvalidOperationException]::new('PackageAdmissionAttemptConsumed_HeldForExactReconciliation: '+$text,$primaryFailure.Exception)}
          else{[InvalidOperationException]::new($text,$primaryFailure.Exception)}
        # L4: callers classify by these structured values, never by parsing the message text.
        $thrown.Data['CoordPackageCode']=$failureCode
        $thrown.Data['CoordPackageClass']=$(if($notNow -and -not $consumed){'NotNow'}else{'Held'})
        $thrown.Data['CoordPackageConsumed']=[bool]$consumed
        $thrown.Data['CoordPackagePolicyDisable']=$disableOutcome
        $thrown.Data['CoordPackageHoldMarker']=$holdMarker
        throw $thrown
      } finally {handoffRelease $leases}
    }
    if($Mode -cin @('Apply','Recover') -and -not $PSCmdlet.ShouldProcess($PacketPath,"$Mode one approved custody handoff")) {
      return [pscustomobject]@{Status='ProposedOnly';LiveAdmission=$false}
    }
    if($Mode -cin @('Apply','Recover')){
      foreach($value in $ApprovalPath,$ExpectedApprovalSha256,$ExclusionPath,$ExpectedExclusionSha256){
        if([string]::IsNullOrWhiteSpace($value)){throw 'HandoffIndependentlySuppliedAuthorityPinsRequired'}
      }
    }
    $ErrorActionPreference='Stop'
    $null=Get-Command Write-PSFMessage -ErrorAction Stop
    $module=$MyInvocation.MyCommand.Module
    if(-not $module){throw 'HandoffRequiresSelectedModule'}
    $moduleRoot=$module.ModuleBase
    $codeDigest=Get-CoordHash (handoffRead $module.Path)
    $packetBytes=handoffRead $PacketPath $ExpectedPacketSha256 4194304
    $packetDigest=Get-CoordHash $packetBytes
    $packetElement=Read-CoordJsonBytes $packetBytes
    Assert-SuccessorPlanObject $packetElement @('kind','transitionId','beforeStateBase64','beforeWitnessBase64','plannerIntentBase64',
      'plannerIntentSha256','targetPackageBase64','targetPackageSha256','oldModuleRoot','codeDigest','finalWorker',
      'workerUpdateId','workerApprovalReference','initializeHistory') 'HandoffPacketInvalid'
    $p=ConvertFrom-CoordElement $packetElement
    if($p.kind -cne 'Coordination-custody-handoff-v1' -or $p.codeDigest -cne $codeDigest -or $p.initializeHistory -isnot [bool]){throw 'HandoffPacketBindingMismatch'}
    $id=handoffGuid $p.transitionId
    $null=handoffGuid $p.workerUpdateId
    if([string]::IsNullOrWhiteSpace($p.workerApprovalReference)){throw 'HandoffWorkerApprovalMissing'}
    $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
    try{$sid=$identity.User.Value}finally{$identity.Dispose()}
    $beforeState=handoffBase64 $p.beforeStateBase64
    $beforeWitness=handoffBase64 $p.beforeWitnessBase64
    $plannerBytes=handoffBase64 $p.plannerIntentBase64
    $targetBytes=handoffBase64 $p.targetPackageBase64
    if((Get-CoordHash $targetBytes) -cne $p.targetPackageSha256){throw 'HandoffTargetPackagePinMismatch'}
    $intent=Read-CoordJsonBytes $plannerBytes
    if((Get-SuccessorPlanIntentKind $intent) -cne 'SuccessorCustodyPlan-v2' -or
        (Get-SuccessorPlanText $intent 'operationId') -cne $id){throw 'HandoffRequiresTwoRetirementIntent'}
    $r=ConvertFrom-CoordElement (Read-CoordJsonBytes $beforeWitness)
    $s=Read-CoordJsonBytes $beforeState
    if($r.custodianSid -cne $sid){throw 'HandoffCustodianMismatch'}
    $stateRoot=[IO.Path]::GetFullPath((Get-CoordSetting 'OrchestrationStateRootPath'))
    $statePath=Join-Path $stateRoot 'state.json'
    $recordPath=[IO.Path]::GetFullPath((Get-CoordSetting 'OrchestrationCustodyRecordPath'))
    $recordDirectory=[IO.Path]::GetDirectoryName($recordPath)
    $programData=Get-CoordProgramDataPath
    if(-not (Test-CoordDescendant $stateRoot $programData) -or -not (Test-CoordDescendant $recordPath $programData) -or
        (Test-CoordDescendant $recordPath $stateRoot) -or $r.statePath -ine $statePath){throw 'HandoffProtectedLocationMismatch'}
    foreach($path in $stateRoot,$recordDirectory,$statePath,$recordPath){$null=Assert-CoordOrdinaryPath $path -MustExist;Assert-CoordProtection $path $sid}
    $boardLockPath=[IO.Path]::GetFullPath($r.boardLockPath)
    $historyRoot=[IO.Path]::GetFullPath((Get-CoordSetting 'OrchestrationRecoveryHistoryRootPath'))
    if(-not (Test-CoordDescendant $historyRoot $programData) -or
        $historyRoot -ieq $stateRoot -or (Test-CoordDescendant $historyRoot $stateRoot) -or (Test-CoordDescendant $stateRoot $historyRoot) -or
        $historyRoot -ieq $recordDirectory -or (Test-CoordDescendant $historyRoot $recordDirectory) -or
        (Test-CoordDescendant $recordDirectory $historyRoot)){throw 'HandoffHistoryLocationMismatch'}
    $null=Assert-CoordOrdinaryPath $historyRoot
    Assert-CoordProtection ([IO.Path]::GetDirectoryName($historyRoot)) $sid
    $attemptPath=Join-Path $recordDirectory ('handoff-'+$id+'.once.json')
    $auditRoot=Join-Path $recordDirectory ('handoff-'+$id)
    $receiptPath=Join-Path $auditRoot 'final.receipt.json'
    $targetPackage=ConvertFrom-CoordElement (Read-CoordJsonBytes $targetBytes)
    Assert-CoordPackageInventory -ModuleRoot $moduleRoot -Package $targetPackage
    $oldRoot=Assert-CoordOrdinaryPath $p.oldModuleRoot -MustExist
    $oldData=Import-PowerShellDataFile -LiteralPath (Join-Path $oldRoot 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell.psd1')
    if($oldData.ModuleVersion -cne $r.package.moduleVersion){throw 'HandoffOldPackageVersionMismatch'}
    Assert-CoordPackageInventory -ModuleRoot $oldRoot -Package $r.package
    $schema=handoffRead (Join-Path $moduleRoot 'schemas/state-v1.schema.json')
    if((Get-CoordHash (handoffRead (Join-Path $oldRoot 'schemas/state-v1.schema.json'))) -cne (Get-CoordHash $schema)){throw 'HandoffSameSchemaRequired'}
    $quartet=[ordered]@{};$outputs=[ordered]@{}
    foreach($slot in 'markdown','boardHtml','proceduralDetailsHtml','accomplishedHtml'){
      $entry=$s.GetProperty('committedOutputManifest').GetProperty($slot)
      $path=Get-SuccessorPlanText $entry 'path';$image=handoffRead $path
      $quartet[$slot]=$image
      $outputs[$slot]=@{path=$path;digest=Get-CoordHash $image;bytesBase64=[Convert]::ToBase64String($image)}
    }
    $plan=New-CoordSuccessorCustodyPlan -IntentBytes $plannerBytes -ExpectedIntentSha256 $p.plannerIntentSha256 `
      -StateBytes $beforeState -WitnessBytes $beforeWitness -TargetPackageBytes $targetBytes -StateSchemaBytes $schema -Quartet $quartet -ObservedSid $sid
    $pairBytes=handoffBytes $plan.Pairs
    $targetRecord=ConvertFrom-CoordElement (Read-CoordJsonBytes $plan.TargetWitness)
    Assert-SuccessorPlanObject ($packetElement.GetProperty('finalWorker')) @('holderId','sessionId','windowsSid','role') 'HandoffWorkerInvalid'
    foreach($key in 'holderId','sessionId','windowsSid','role'){$null=Get-SuccessorPlanText ($packetElement.GetProperty('finalWorker')) $key}
    if($p.finalWorker.role -cne 'Worker' -or $p.finalWorker.windowsSid -cne $sid){throw 'HandoffWorkerInvalid'}
    $finalWitness=handoffWorkers
    $finalWitnessDigest=Get-CoordHash $finalWitness
    $needsWorker=$finalWitnessDigest -cne $plan.Pairs.Target.Witness
    $backup=New-CoordRecoverySnapshot -StateBytes $beforeState -CustodyBytes $beforeWitness -ObservedOutputs $outputs
    $g1=Test-CoordRestoreBundle -BundleBytes $backup -ExpectedSha256 (Get-CoordHash $backup) `
      -ExpectedResourceId $r.resourceId -ExpectedLineageId $r.lineageId -ExpectedGeneration $r.generation `
      -ExpectedCommittedRevision $s.GetProperty('committedRevision').GetString() -MaxBundleBytes 67108864 -StateSchemaBytes $schema
    $finalBackup=New-CoordRecoverySnapshot -StateBytes $plan.TargetState -CustodyBytes $finalWitness -ObservedOutputs $outputs
    $null=Test-CoordRestoreBundle -BundleBytes $finalBackup -ExpectedSha256 (Get-CoordHash $finalBackup) `
      -ExpectedResourceId $r.resourceId -ExpectedLineageId $r.lineageId -ExpectedGeneration $targetRecord.generation `
      -ExpectedCommittedRevision $s.GetProperty('committedRevision').GetString() -MaxBundleBytes 67108864 -StateSchemaBytes $schema
    $metadata=[ordered]@{kind='Coordination-handoff-plan-v1';packetDigest=$packetDigest;codeDigest=$codeDigest
      statePath=$statePath;custodyPath=$recordPath;boardLockPath=$boardLockPath;historyRoot=$historyRoot
      beforeGeneration=$r.generation;targetGeneration=$targetRecord.generation;plannerPairs=$plan.Pairs
      finalPair=@{state=$plan.Pairs.Target.State;witness=$finalWitnessDigest};workerAppendRequired=$needsWorker
      backupDigest=Get-CoordHash $backup;proposedFinalBackupDigest=Get-CoordHash $finalBackup;targetPackageDigest=$p.targetPackageSha256}
    # Visible only when the intent explicitly sets or clears the standing policy; without it the plan digest is unchanged.
    if($plan.PolicyAction -cne 'CarriedForward'){$metadata['policyAction']=$plan.PolicyAction}
    $planDigest=Get-CoordHash (handoffBytes $metadata)
    $current=handoffCheckpoint
    $history=handoffHistory
    $lastWorker=handoffLastWorker
    if($Mode -cin @('Plan','Inspect')){
      if($Mode -ceq 'Plan' -and $current -cne 'Before'){throw 'HandoffBeforePairChanged'}
      $workerState=if(-not $needsWorker){'RetainedDesignatedWorker'}elseif(-not $lastWorker){'NotAttempted'}else{
        handoffWorkerEvidence $lastWorker.Record.updateId $lastWorker.Record.approvalReference
      }
      if($needsWorker -and $current -ceq 'FinalPair' -and -not $lastWorker){$workerState='AfterWithoutAttempt_Held'}
      if($needsWorker -and $current -ceq 'Target' -and $workerState -ceq 'OrdinaryReceiptComplete'){$workerState='BeforeWithCompletedReceipt_Held'}
      $receiptState='Absent'
      if([IO.File]::Exists($receiptPath)){
        $receiptElement=Read-CoordJsonBytes (handoffRead $receiptPath)
        Assert-SuccessorPlanObject $receiptElement @('kind','status','packetDigest','planDigest','applyApprovalDigest',
          'completionApprovalDigest','finalPair','generation','history','workerOutcome','externalHolds') 'HandoffFinalReceiptInvalid'
        $receipt=ConvertFrom-CoordElement $receiptElement
        $origin=ConvertFrom-CoordElement (Read-CoordJsonBytes (handoffRead $attemptPath))
        if($current -cne 'FinalPair' -or $receipt.kind -cne 'Coordination-custody-handoff-receipt-v1' -or
            $receipt.status -cne 'HandoffHeld' -or $receipt.packetDigest -cne $packetDigest -or $receipt.planDigest -cne $planDigest -or
            $receipt.generation -cne $targetRecord.generation -or $receipt.applyApprovalDigest -cne $origin.approvalDigest -or
            -not (handoffSame $receipt.finalPair (handoffPair)) -or -not (handoffSame $receipt.history $history) -or
            -not (handoffSame $receipt.externalHolds @('ALL_TASKS','Pilot')) -or
            -not (handoffAuthorityKnown $receipt.completionApprovalDigest)){throw 'HandoffFinalReceiptMismatch'}
        $expectedWorker=if($workerState -ceq 'OrdinaryReceiptMissing'){'ReconciledObservedAfter_OrdinaryReceiptMissing'}else{$workerState}
        if($receipt.workerOutcome -cne $expectedWorker){throw 'HandoffFinalReceiptWorkerMismatch'}
        if($workerState -ceq 'OrdinaryReceiptMissing'){
          handoffRequireAcknowledgement (handoffAuthorityKnown $receipt.completionApprovalDigest)
        }
        $receiptState='VerifiedCurrent'
      }
      return [pscustomobject]@{Status=$($Mode+'Only');PlanDigest=$planDigest;Checkpoint=$current;History=$history
        LastWorkerAttemptDigest=$(if($lastWorker){$lastWorker.Digest}else{'none'})
        WorkerUpdateId=$(if($lastWorker){$lastWorker.Record.updateId}else{'none'});WorkerEvidence=$workerState;FinalReceipt=$receiptState
        Metadata=$metadata;LiveAdmission=$false;ExternalHolds=@('ALL_TASKS','Pilot')}
    }
    $approvalBytes=handoffRead $ApprovalPath $ExpectedApprovalSha256 1048576
    $approvalElement=Read-CoordJsonBytes $approvalBytes
    Assert-SuccessorPlanObject $approvalElement @('kind','mode','approvalId','reference','packetDigest','planDigest','codeDigest',
      'exclusionDigest','custodianSid','notBeforeUtc','notAfterUtc','expectedPair','expectedHistory','recovery') 'HandoffApprovalInvalid'
    $grant=ConvertFrom-CoordElement $approvalElement
    $grantDigest=Get-CoordHash $approvalBytes
    $null=handoffGuid $grant.approvalId
    if($grant.kind -cne 'Coordination-custody-handoff-approval-v1' -or $grant.mode -cne $Mode -or
        $grant.packetDigest -cne $packetDigest -or $grant.planDigest -cne $planDigest -or $grant.codeDigest -cne $codeDigest -or
        $grant.custodianSid -cne $sid -or [string]::IsNullOrWhiteSpace($grant.reference)){throw 'HandoffApprovalBindingMismatch'}
    $exclusionBytes=handoffRead $ExclusionPath $ExpectedExclusionSha256 1048576
    if((Get-CoordHash $exclusionBytes) -cne $grant.exclusionDigest){throw 'HandoffExclusionPinMismatch'}
    $exclusion=ConvertFrom-CoordElement (Read-CoordJsonBytes $exclusionBytes)
    if($exclusion.kind -cne 'Coordination-writer-exclusion-v1' -or
        $exclusion.allWritersHeld -isnot [bool] -or -not $exclusion.allWritersHeld -or
        $exclusion.bothDropboxClosed -isnot [bool] -or -not $exclusion.bothDropboxClosed -or
        @($exclusion.hosts).Count -ne 2 -or 'UTAT022' -cnotin $exclusion.hosts -or 'UTAT01' -cnotin $exclusion.hosts -or
        [string]::IsNullOrWhiteSpace($exclusion.reference)){throw 'HandoffWriterExclusionUnbound'}
    $boot=(Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).LastBootUpTime.ToUniversalTime().ToString('o')
    if($exclusion.hostBootUtc -cne $boot){throw 'HandoffExclusionPredatesBoot'}
    handoffWindow $grant $exclusion
    $leases=$null;$consumed=$false
    try {
      $leases=handoffTakeLeases
      $current=handoffCheckpoint;$history=handoffHistory
      $lastWorker=handoffLastWorker
      if(-not (handoffSame (handoffPair) $grant.expectedPair) -or -not (handoffSame $history $grant.expectedHistory)){throw 'HandoffObservedBindingMismatch'}
      foreach($slot in $outputs.Keys){
        if((Get-CoordHash (handoffRead $outputs[$slot].path)) -cne $outputs[$slot].digest){throw 'HandoffQuartetChangedBeforeAttempt'}
      }
      if((Get-CoordHash (handoffRead $module.Path)) -cne $codeDigest){throw 'HandoffCodeChangedBeforeAttempt'}
      Assert-CoordPackageInventory -ModuleRoot $moduleRoot -Package $targetPackage
      Assert-CoordPackageInventory -ModuleRoot $oldRoot -Package $r.package
      handoffWindow $grant $exclusion
      if($Mode -ceq 'Apply'){
        if($null -ne $grant.recovery -or $current -cne 'Before' -or [IO.Directory]::Exists($auditRoot)){throw 'HandoffApplyNotFresh'}
        $attempt=[ordered]@{kind='Coordination-handoff-attempt-v1';packetDigest=$packetDigest;planDigest=$planDigest;codeDigest=$codeDigest
          approvalDigest=$grantDigest;approvalBase64=[Convert]::ToBase64String($approvalBytes);beforePair=$grant.expectedPair;history=$history}
        handoffNew $attemptPath (handoffBytes $attempt)
        $consumed=$true
      } else {
        if(-not [IO.File]::Exists($attemptPath) -or $current -ceq 'ThirdState'){throw 'HandoffRecoveryHasNoKnownOrigin'}
        $attemptBytes=handoffRead $attemptPath
        $attempt=ConvertFrom-CoordElement (Read-CoordJsonBytes $attemptBytes)
        if($attempt.packetDigest -cne $packetDigest -or $attempt.planDigest -cne $planDigest -or
            $grant.recovery.priorAttemptDigest -cne (Get-CoordHash $attemptBytes) -or
            $grant.recovery.checkpoint -cne $current -or $grantDigest -ceq $attempt.approvalDigest){throw 'HandoffRecoveryBindingMismatch'}
        handoffValidateRecovery
        $recoverPath=Join-Path $recordDirectory ('handoff-'+$id+'.recover-'+$grant.approvalId+'.once.json')
        handoffNew $recoverPath (handoffBytes @{packetDigest=$packetDigest;approvalDigest=$grantDigest;approvalBase64=[Convert]::ToBase64String($approvalBytes);originDigest=Get-CoordHash $attemptBytes})
        $consumed=$true
      }
      if(-not [IO.Directory]::Exists($auditRoot)){handoffCreateProtectedDirectory $auditRoot}
      Assert-CoordProtection $auditRoot $sid
      foreach($item in @(@('before.bundle.json',$backup),@('before.state.bin',$beforeState),@('before.witness.bin',$beforeWitness))){
        $path=Join-Path $auditRoot $item[0]
        if([IO.File]::Exists($path)){
          if((Get-CoordHash (handoffRead $path)) -cne (Get-CoordHash $item[1])){throw 'HandoffRetainedImageMismatch'}
        }else{handoffNew $path $item[1]}
      }
      if($history.condition -cin @('Absent','Empty','LockOnly')){
        if(-not $p.initializeHistory -or $current -cne 'Before' -or
            ($Mode -ceq 'Recover' -and $grant.recovery.action -cne 'ContinueInitialization')){throw 'HandoffHistoryInitializationNotBound'}
        handoffWindow $grant $exclusion
        if($history.condition -ceq 'Absent'){
          handoffCreateProtectedDirectory $historyRoot
        }
        $null=Write-CoordRecoveryHistory -Action Initialize -Confirm:$false
        $history=handoffHistory
      } elseif($history.condition -ceq 'Pending') {
        if($Mode -cne 'Recover' -or $grant.recovery.historyPendingDigest -cne $history.pendingDigest -or
            $grant.recovery.historyOutcome -cnotin @('Committed','Aborted')){throw 'HandoffPendingHistoryNeedsExactRecovery'}
        $pending=(Read-CoordRecoveryHistory $historyRoot).Pending.Record
        $edges=@(
          @($plan.Pairs.Before,$plan.Pairs.FencedBeforeState),
          @($plan.Pairs.FencedBeforeState,$plan.Pairs.FencedAfterState),
          @($plan.Pairs.FencedAfterState,$plan.Pairs.Target),
          @($plan.Pairs.Target,@{State=$plan.Pairs.Target.State;Witness=$finalWitnessDigest}))
        $known=$false
        foreach($edge in $edges){
          $left=@{state=$edge[0].State;custody=$edge[0].Witness};$right=@{state=$edge[1].State;custody=$edge[1].Witness}
          if((handoffSame $pending.before $left) -and (handoffSame $pending.after $right)){$known=$true}
        }
        if(-not $known){throw 'HandoffUnrelatedPendingHistory'}
        handoffWindow $grant $exclusion
        $null=Write-CoordRecoveryHistory -Action Resolve -ExpectedIntentDigest $history.pendingDigest -Outcome $grant.recovery.historyOutcome -Confirm:$false
        $history=handoffHistory
      }
      Assert-CoordRecoveryPair (Read-CoordRecoveryHistory $historyRoot)
      $current=handoffCheckpoint
      if($Mode -ceq 'Recover' -and $grant.recovery.action -cnotin @('ContinueInitialization','ContinuePlanner','RetryWorkerBefore','AcknowledgeWorkerAfter','Finalize')){throw 'HandoffRecoveryActionInvalid'}
      foreach($step in @(
        @{Before='Before';After='FencedBeforeState';Path=$recordPath;Expected=$beforeWitness;Bytes=$plan.FencedWitness},
        @{Before='FencedBeforeState';After='FencedAfterState';Path=$statePath;Expected=$beforeState;Bytes=$plan.TargetState},
        @{Before='FencedAfterState';After='Target';Path=$recordPath;Expected=$plan.FencedWitness;Bytes=$plan.TargetWitness})){
        if($current -cne $step.Before){continue}
        if($Mode -ceq 'Recover' -and $grant.recovery.action -cnotin @('ContinueInitialization','ContinuePlanner')){throw 'HandoffRecoveryActionMismatch'}
        handoffWindow $grant $exclusion
        Write-CoordAtomicBytes -Path $step.Path -ExpectedBytes $step.Expected -Bytes $step.Bytes
        $current=handoffCheckpoint
        if($current -cne $step.After -and -not ($step.After -ceq 'Target' -and -not $needsWorker -and $current -ceq 'FinalPair')){throw 'HandoffCheckpointReadbackFailed'}
      }
      if($current -cnotin @('Target','FinalPair')){throw 'HandoffUnknownCheckpoint'}
      handoffRelease $leases;$leases=$null
      $workerOutcome='RetainedDesignatedWorker'
      if($needsWorker){
        $lastWorker=handoffLastWorker
        if($current -ceq 'Target'){
          if($lastWorker -and (handoffWorkerEvidence $lastWorker.Record.updateId $lastWorker.Record.approvalReference) -ceq 'OrdinaryReceiptComplete'){
            throw 'HandoffWorkerReceiptPairMismatch'
          }
          if($lastWorker -and ($Mode -cne 'Recover' -or $grant.recovery.action -cne 'RetryWorkerBefore' -or
              $grant.recovery.workerAttemptDigest -cne $lastWorker.Digest)){throw 'HandoffWorkerAttemptConsumed'}
          $updateId=if($Mode -ceq 'Apply'){$p.workerUpdateId}else{handoffGuid $grant.recovery.workerUpdateId}
          $reference=if($Mode -ceq 'Apply'){$p.workerApprovalReference}else{$grant.reference}
          $workerPath=Join-Path $auditRoot ('worker-'+$updateId+'.once.json')
          $h=handoffHistory
          handoffWindow $grant $exclusion
          handoffNew $workerPath (handoffBytes ([ordered]@{kind='Coordination-handoff-worker-attempt-v1';ordinal=$(if($lastWorker){[long]$lastWorker.Record.ordinal+1}else{1L})
            packetDigest=$packetDigest;updateId=$updateId;approvalReference=$reference;approvalDigest=$grantDigest
            stateDigest=$plan.Pairs.Target.State;beforeWitnessDigest=$plan.Pairs.Target.Witness;afterWitnessDigest=$finalWitnessDigest;historyBefore=$h}))
          $null=Update-CoordWitness -HolderId $targetRecord.coordinatorId -SessionId (Get-SuccessorPlanText $intent 'successorSessionId') `
            -ExpectedWitnessBytes $plan.TargetWitness -ProposedWitnessBytes $finalWitness -UpdateId ([guid]$updateId) -ApprovalReference $reference -Confirm:$false
          $lastWorker=handoffLastWorker
          $workerOutcome=handoffWorkerEvidence $updateId $reference
          if($workerOutcome -cne 'OrdinaryReceiptComplete'){throw 'HandoffWorkerReceiptRequired'}
        } else {
          if(-not $lastWorker){throw 'HandoffWorkerAfterWithoutAttempt'}
          $workerOutcome=handoffWorkerEvidence $lastWorker.Record.updateId $lastWorker.Record.approvalReference
          if($workerOutcome -ceq 'OrdinaryReceiptMissing'){
            if($Mode -cne 'Recover' -or $grant.recovery.action -cne 'AcknowledgeWorkerAfter' -or
                $grant.recovery.workerAttemptDigest -cne $lastWorker.Digest){throw 'HandoffWorkerAfterNeedsFreshAcknowledgement'}
            $workerOutcome='ReconciledObservedAfter_OrdinaryReceiptMissing'
          } elseif($workerOutcome -cne 'OrdinaryReceiptComplete'){throw 'HandoffWorkerAuditIncomplete'}
        }
      }
      $leases=handoffTakeLeases
      if((handoffCheckpoint) -cne 'FinalPair'){throw 'HandoffFinalPairMismatch'}
      Assert-CoordRecoveryPair (Read-CoordRecoveryHistory $historyRoot)
      foreach($slot in $outputs.Keys){if((Get-CoordHash (handoffRead $outputs[$slot].path)) -cne $outputs[$slot].digest){throw 'HandoffQuartetChanged'}}
      Assert-CoordPackageInventory -ModuleRoot $moduleRoot -Package $targetPackage
      handoffWindow $grant $exclusion
      $history=handoffHistory
      $receipt=[ordered]@{kind='Coordination-custody-handoff-receipt-v1';status='HandoffHeld';packetDigest=$packetDigest
        planDigest=$planDigest;applyApprovalDigest=$attempt.approvalDigest;completionApprovalDigest=$grantDigest
        finalPair=handoffPair;generation=$targetRecord.generation;history=$history;workerOutcome=$workerOutcome
        externalHolds=@('ALL_TASKS','Pilot')}
      if([IO.File]::Exists($receiptPath)){
        $existing=ConvertFrom-CoordElement (Read-CoordJsonBytes (handoffRead $receiptPath))
        if(-not (handoffAuthorityKnown $existing.completionApprovalDigest)){throw 'HandoffFinalReceiptAuthorityUnknown'}
        if($workerOutcome -ceq 'ReconciledObservedAfter_OrdinaryReceiptMissing'){
          handoffRequireAcknowledgement (handoffAuthorityKnown $existing.completionApprovalDigest)
        }
        $receipt.completionApprovalDigest=$existing.completionApprovalDigest
        if(-not (handoffSame $existing $receipt)){throw 'HandoffFinalReceiptMismatch'}
      }else{handoffNew $receiptPath (handoffBytes $receipt)}
      [pscustomobject]@{Status='HandoffHeld';ReceiptPath=$receiptPath;ReceiptSha256=Get-CoordHash (handoffRead $receiptPath)
        PacketSha256=$packetDigest;PlanDigest=$planDigest;Generation=$targetRecord.generation;FinalPair=handoffPair
        History=$history;WorkerOutcome=$workerOutcome;ExternalHolds=@('ALL_TASKS','Pilot');PilotAuthorized=$false}
    } catch {
      $primaryFailure=$_
      try{Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message 'Custody handoff refused or held; preserve consumed attempts and reconcile exact images/history before continuation.'}catch{}
      if($consumed){throw [InvalidOperationException]::new('HandoffAttemptConsumed_HeldForExactReconciliation',$primaryFailure.Exception)}
      throw $primaryFailure
    } finally {handoffRelease $leases}
  }
  end {}
}
