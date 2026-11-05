#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.2.0' }

BeforeAll {
  $script:moduleRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
  foreach ($name in @('CoordProducerJson', 'CoordProducer', 'Save-CoordOperation')) {
    . (Join-Path $moduleRoot "private/$name.ps1")
  }
  . (Join-Path $moduleRoot 'public/Update-CoordWitness.ps1')
  function Write-PSFMessage { param($FunctionName, $ModuleName, $Level, $Message) }
  $script:realIo = (Get-Command Invoke-CoordOperationFileIo).ScriptBlock
  $script:realAtomic = (Get-Command Write-CoordAtomicBytes).ScriptBlock
  $script:fixtureBase = [IO.Path]::GetFullPath((Join-Path $moduleRoot '../../_generated/Sprint0017/C1938/Fixtures'))
  function New-TestLease {
    $lease = [pscustomobject]@{ Disposed = $false }
    $lease | Add-Member ScriptMethod Dispose { $this.Disposed = $true }
    return $lease
  }
  function Refresh-TestContext {
    $script:context.RecordBytes = [IO.File]::ReadAllBytes($script:witnessPath)
    $script:context.Record = ConvertFrom-CoordElement (Read-CoordJsonBytes $script:context.RecordBytes)
    $script:context.StateBytes = [IO.File]::ReadAllBytes($script:statePath)
    $script:context.State = Read-CoordJsonBytes $script:context.StateBytes
  }
  function Set-TestCandidate([string]$Kind = 'authorizations', $Entry = $null) {
    if ($null -eq $Entry) { $Entry = [ordered]@{ reference = 'approval-2'; requestId = 'request-2'; digest = ('b' * 64); claimId = 'claim-2' } }
    $text = [Text.Encoding]::UTF8.GetString($script:context.RecordBytes)
    $array = (Read-CoordJsonBytes $script:context.RecordBytes).GetProperty($Kind).GetRawText()
    $separator = if ($array -ceq '[]') { '' } else { ',' }
    $replacement = $array.Substring(0, $array.Length - 1) + $separator + (ConvertTo-Json -InputObject $Entry -Compress -Depth 20) + ']'
    $script:proposed = [Text.Encoding]::UTF8.GetBytes($text.Replace('"' + $Kind + '":' + $array, '"' + $Kind + '":' + $replacement))
  }
  function Invoke-TestUpdate([byte[]]$Expected = $script:context.RecordBytes, [switch]$PreviewOnly) {
    Update-CoordWitness -HolderId 'coordinator' -SessionId 'session-1' -ExpectedWitnessBytes $Expected -ProposedWitnessBytes $script:proposed -UpdateId $script:updateId -ApprovalReference 'actual-approval-reference' -WhatIf:$PreviewOnly -Confirm:$false
  }
}

Describe 'Established witness single-append update' -Tag 'Unit', 'C1938' {
  BeforeEach {
    $script:fixture = Join-Path $fixtureBase ([guid]::NewGuid().ToString('N'))
    $null = [IO.Directory]::CreateDirectory($fixture)
    $script:witnessPath = Join-Path $fixture 'custody.json'
    $script:statePath = Join-Path $fixture 'state.json'
    $script:updateId = [guid]::NewGuid()
    $script:fault = ''; $script:atomicCalls = 0; $script:stages = [Collections.Generic.List[string]]::new()
    $script:stateValue = [ordered]@{ mutationAdmission = @{ status = 'Admitted' }; requests = @(); preparedOperations = @() }
    $stateBytes = [Text.Encoding]::UTF8.GetBytes(($stateValue | ConvertTo-Json -Depth 20 -Compress))
    [IO.File]::WriteAllBytes($statePath, $stateBytes)
    $script:record = [ordered]@{
      schemaVersion = 'Coordination-custody-v1'; admissionMode = 'Established'; custodianSid = 'synthetic-sid'
      coordinatorId = 'coordinator'; resourceId = 'resource-1'; lineageId = 'lineage-1'; generation = 'epoch-1'
      statePath = $statePath; stateSha256 = Get-CoordHash $stateBytes; pendingWrite = $null
      package = @{ moduleVersion = 'synthetic'; files = @() }
      actors = @([ordered]@{ holderId = 'coordinator'; sessionId = 'session-1'; windowsSid = 'synthetic-sid'; role = 'Coordinator' })
      authorizations = @([ordered]@{ reference = 'approval-1'; requestId = 'request-1'; digest = ('a' * 64) })
      future = @{ text = 'preserved'; number = 1 }
    }
    [IO.File]::WriteAllText($witnessPath, ($record | ConvertTo-Json -Depth 20 -Compress))
    $script:context = [pscustomobject]@{
      RecordPath = $witnessPath; StatePath = $statePath; Record = $null; RecordBytes = $null; State = $null; StateBytes = $null
      Actor = $record.actors[0]; Lease = New-TestLease; BoardLease = New-TestLease
    }
    Refresh-TestContext
    Set-TestCandidate
    Mock Read-CoordProducerContext {
      if ($Role -cne 'Export' -or $AllowPending -or $HolderId -cne 'coordinator' -or $SessionId -cne 'session-1') { throw 'UnexpectedContextAdmission' }
      if ($script:fault -in @('WitnessLock', 'BoardLock')) { throw 'SyntheticLockUnavailable' }
      return $script:context
    }
    Mock Assert-CoordOrdinaryPath {
      if (-not [IO.Path]::GetFullPath($Path).StartsWith($script:fixture + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'OutsideOwnedFixture' }
      if ($script:fault -eq 'UnsafePath') { throw 'RedirectedPath' }
      return $Path
    }
    Mock Assert-CoordProtection {
      if ($script:fault -eq 'Protection') { throw 'UnprotectedCustody' }
    }
    Mock Invoke-CoordOperationFileIo {
      if (-not [IO.Path]::GetFullPath($StatePath).StartsWith($script:fixture + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'OutsideOwnedFixture' }
      if ($Phase -eq 'Stage') {
        $script:stages.Add($StatePath)
        if ($script:fault -eq 'AuditStage' -or ($script:fault -eq 'ReceiptStage' -and $StatePath.EndsWith('.receipt.json'))) { throw 'SyntheticStageFailure' }
      }
      if ($Phase -eq 'ReadBack') {
        if ($script:fault -eq 'AuditReadback' -and $StatePath.EndsWith('.after.bin')) { return ,([byte[]]@(1)) }
        if ($script:fault -eq 'ReceiptReadback' -and $StatePath.EndsWith('.receipt.json')) { return ,([byte[]]@(1)) }
        if ($script:fault -eq 'WitnessReadback' -and $script:atomicCalls -gt 0 -and $StatePath -ceq $script:witnessPath) { return ,([byte[]]@(1)) }
        if ($script:fault -eq 'StateReadback' -and $script:atomicCalls -gt 0 -and $StatePath -ceq $script:statePath) { return ,([byte[]]@(1)) }
      }
      & $script:realIo -Phase $Phase -StatePath $StatePath -StagePath $StagePath -Bytes $Bytes
    }
    Mock Write-CoordAtomicBytes {
      $script:atomicCalls++
      if ($context.Lease.Disposed -or $context.BoardLease.Disposed) { throw 'LeaseReleasedBeforeReplace' }
      if ($script:fault -in @('AtomicStage', 'AtomicReplace')) { throw 'SyntheticAtomicFailure' }
      & $script:realAtomic -Path $Path -ExpectedBytes $ExpectedBytes -Bytes $Bytes
      if ($script:fault -eq 'AtomicReadback') { throw 'PersistenceFailed' }
    }
    Mock Write-PSFMessage {}
  }

  It 'appends one <Kind> entry, retains exact images and preserves state/history' -ForEach @(
    @{ Kind = 'authorizations' }; @{ Kind = 'actors' }
  ) {
    if ($Kind -eq 'actors') { Set-TestCandidate actors ([ordered]@{ holderId = 'worker'; sessionId = 'session-2'; windowsSid = 'synthetic-sid'; role = 'Worker' }) }
    $before = $context.RecordBytes.Clone(); $stateBefore = $context.StateBytes.Clone(); $candidate = $proposed.Clone()
    $result = Invoke-TestUpdate
    $result.Status | Should -BeExactly 'Updated'
    [Convert]::ToBase64String([IO.File]::ReadAllBytes($witnessPath)) | Should -BeExactly ([Convert]::ToBase64String($candidate))
    [Convert]::ToBase64String([IO.File]::ReadAllBytes($statePath)) | Should -BeExactly ([Convert]::ToBase64String($stateBefore))
    [Convert]::ToBase64String([IO.File]::ReadAllBytes($result.EvidencePaths.Before)) | Should -BeExactly ([Convert]::ToBase64String($before))
    [Convert]::ToBase64String([IO.File]::ReadAllBytes($result.EvidencePaths.After)) | Should -BeExactly ([Convert]::ToBase64String($candidate))
    (Get-Content -LiteralPath $result.EvidencePaths.Receipt -Raw | ConvertFrom-Json).status | Should -BeExactly 'Updated'
    (Get-Content -LiteralPath $result.EvidencePaths.Intent -Raw | ConvertFrom-Json).approvalReference | Should -BeExactly 'actual-approval-reference'
    $context.Lease.Disposed | Should -BeTrue
    $context.BoardLease.Disposed | Should -BeTrue
    Should -Invoke Read-CoordProducerContext -Times 1 -Exactly -Scope It
    Should -Invoke Write-CoordAtomicBytes -Times 1 -Exactly -Scope It
    Should -Invoke Assert-CoordProtection -Times 6 -Exactly -Scope It
  }

  It 'refuses a stale expected image or a second invocation after success' {
    $expected = $context.RecordBytes.Clone()
    $null = Invoke-TestUpdate
    $context.Lease = New-TestLease; $context.BoardLease = New-TestLease
    Refresh-TestContext
    { Invoke-TestUpdate -Expected $expected } | Should -Throw '*SnapshotMismatch*'
    Should -Invoke Write-CoordAtomicBytes -Times 1 -Exactly -Scope It
  }

  It 'propagates the held <Fault> refusal without persistence' -ForEach @(
    @{ Fault = 'WitnessLock' }; @{ Fault = 'BoardLock' }
  ) {
    $script:fault = $Fault
    { Invoke-TestUpdate } | Should -Throw '*SyntheticLockUnavailable*'
    Should -Invoke Write-CoordAtomicBytes -Times 0 -Exactly -Scope It
    $stages.Count | Should -Be 0
  }

  It 'refuses non-null pendingWrite <Value>' -ForEach @(
    @{ Value = @{ kind = 'State' } }; @{ Value = @{ kind = 'Prepare' } }; @{ Value = @{ kind = 'Complete' } }
    @{ Value = $false }; @{ Value = @{} }; @{ Value = '' }
  ) {
    $record.pendingWrite = $Value
    [IO.File]::WriteAllText($witnessPath, ($record | ConvertTo-Json -Depth 20 -Compress))
    Refresh-TestContext; Set-TestCandidate
    { Invoke-TestUpdate } | Should -Throw '*NeedsRecovery*'
    $stages.Count | Should -Be 0
    $context.Lease.Disposed | Should -BeTrue
    $context.BoardLease.Disposed | Should -BeTrue
  }

  It 'refuses unsettled <Collection> status <Status>' -ForEach @(
    @{ Collection = 'requests'; Status = 'Pending' }; @{ Collection = 'requests'; Status = 'Prepared' }
    @{ Collection = 'requests'; Status = 'NeedsRecovery' }; @{ Collection = 'preparedOperations'; Status = 'Prepared' }
    @{ Collection = 'preparedOperations'; Status = 'NeedsRecovery' }
  ) {
    $stateValue[$Collection] = @(@{ status = $Status })
    [IO.File]::WriteAllText($statePath, ($stateValue | ConvertTo-Json -Depth 20 -Compress))
    $record.stateSha256 = Get-CoordHash ([IO.File]::ReadAllBytes($statePath))
    [IO.File]::WriteAllText($witnessPath, ($record | ConvertTo-Json -Depth 20 -Compress))
    Refresh-TestContext; Set-TestCandidate
    { Invoke-TestUpdate } | Should -Throw '*WitnessWorkPending*'
    Should -Invoke Write-CoordAtomicBytes -Times 0 -Exactly -Scope It
  }

  It 'allows retained terminal history without rewriting it' {
    $stateValue.requests = @(@{ status = 'Applied' }, @{ status = 'Rejected' })
    $stateValue.preparedOperations = @(@{ status = 'Applied' })
    [IO.File]::WriteAllText($statePath, ($stateValue | ConvertTo-Json -Depth 20 -Compress))
    $record.stateSha256 = Get-CoordHash ([IO.File]::ReadAllBytes($statePath))
    [IO.File]::WriteAllText($witnessPath, ($record | ConvertTo-Json -Depth 20 -Compress))
    Refresh-TestContext; Set-TestCandidate
    (Invoke-TestUpdate).Status | Should -BeExactly 'Updated'
  }

  It 'refuses changed frozen field <Field>' -ForEach @(
    @{ Field = 'package' }; @{ Field = 'statePath' }; @{ Field = 'stateSha256' }
    @{ Field = 'lineageId' }; @{ Field = 'generation' }; @{ Field = 'future' }; @{ Field = 'coordinatorId' }
  ) {
    $candidate = [Text.Encoding]::UTF8.GetString($proposed) | ConvertFrom-Json -AsHashtable
    $candidate[$Field] = 'changed'
    $script:proposed = [Text.Encoding]::UTF8.GetBytes(($candidate | ConvertTo-Json -Depth 20 -Compress))
    { Invoke-TestUpdate } | Should -Throw '*InvalidWitnessDelta*'
    $stages.Count | Should -Be 0
  }

  It 'refuses duplicate or malformed grant <Fault>' -ForEach @(
    @{ Fault = 'ReferenceReuse' }; @{ Fault = 'RequestReuse' }; @{ Fault = 'UpperDigest' }
    @{ Fault = 'EmptyClaim' }; @{ Fault = 'UnknownMember' }; @{ Fault = 'ExactDuplicate' }
  ) {
    $entry = [ordered]@{ reference = 'approval-2'; requestId = 'request-2'; digest = ('b' * 64) }
    switch ($Fault) {
      ExactDuplicate { $entry.reference = 'approval-1'; $entry.requestId = 'request-1'; $entry.digest = 'a' * 64 }
      ReferenceReuse { $entry.reference = 'approval-1' }
      RequestReuse { $entry.requestId = 'request-1' }
      UpperDigest { $entry.digest = 'B' * 64 }
      EmptyClaim { $entry.claimId = '' }
      UnknownMember { $entry.extra = 'unexpected' }
    }
    Set-TestCandidate authorizations $entry
    { Invoke-TestUpdate } | Should -Throw '*InvalidWitnessDelta*'
    $stages.Count | Should -Be 0
  }

  It 'refuses duplicate actor, changed SID or role <Fault>' -ForEach @(
    @{ Fault = 'Duplicate' }; @{ Fault = 'WrongSid' }; @{ Fault = 'WrongRole' }
  ) {
    $entry = [ordered]@{ holderId = 'worker'; sessionId = 'session-2'; windowsSid = 'synthetic-sid'; role = 'Worker' }
    switch ($Fault) {
      Duplicate { $entry.holderId = 'coordinator'; $entry.sessionId = 'session-1' }
      WrongSid { $entry.windowsSid = 'another-sid' }
      WrongRole { $entry.role = 'Admin' }
    }
    Set-TestCandidate actors $entry
    { Invoke-TestUpdate } | Should -Throw '*InvalidWitnessDelta*'
    $stages.Count | Should -Be 0
  }

  It 'refuses nonappend edit <Fault>' -ForEach @(
    @{ Fault = 'Remove' }; @{ Fault = 'RoleChange' }; @{ Fault = 'MultiAppend' }; @{ Fault = 'BothArrays' }
    @{ Fault = 'UnknownTop' }; @{ Fault = 'NoOp' }; @{ Fault = 'DuplicateJson' }; @{ Fault = 'RawSubtreeChange' }
  ) {
    $candidate = [Text.Encoding]::UTF8.GetString($proposed) | ConvertFrom-Json -AsHashtable
    switch ($Fault) {
      Remove { $candidate.authorizations = @($candidate.authorizations[1]) }
      RoleChange { $candidate.actors[0].role = 'Worker' }
      MultiAppend { $candidate.authorizations += @{ reference = 'approval-3'; requestId = 'request-3'; digest = ('c' * 64) } }
      BothArrays { $candidate.actors += @{ holderId = 'worker'; sessionId = 's2'; windowsSid = 'synthetic-sid'; role = 'Worker' } }
      UnknownTop { $candidate.newField = 'not frozen' }
    }
    $text = $candidate | ConvertTo-Json -Depth 20 -Compress
    if ($Fault -eq 'NoOp') { $text = [Text.Encoding]::UTF8.GetString($context.RecordBytes) }
    if ($Fault -eq 'DuplicateJson') { $text = $text.Substring(0, $text.Length - 1) + ',"generation":"epoch-1"}' }
    if ($Fault -eq 'RawSubtreeChange') { $text = $text.Replace('"number":1', '"number":1.0') }
    $script:proposed = [Text.Encoding]::UTF8.GetBytes($text)
    { Invoke-TestUpdate } | Should -Throw
    $stages.Count | Should -Be 0
    Should -Invoke Write-CoordAtomicBytes -Times 0 -Exactly -Scope It
  }

  It 'requires the designated registered Coordinator despite an approval label: <Fault>' -ForEach @(
    @{ Fault = 'Role' }; @{ Fault = 'Holder' }; @{ Fault = 'Session' }; @{ Fault = 'Sid' }; @{ Fault = 'Designation' }
  ) {
    $context.Actor = @{ holderId = 'coordinator'; sessionId = 'session-1'; windowsSid = 'synthetic-sid'; role = 'Coordinator' }
    switch ($Fault) {
      Role { $context.Actor.role = 'Worker' }
      Holder { $context.Actor.holderId = 'other' }
      Session { $context.Actor.sessionId = 'other' }
      Sid { $context.Actor.windowsSid = 'other' }
      Designation { $context.Record.coordinatorId = 'other' }
    }
    { Invoke-TestUpdate } | Should -Throw '*ActorNotAuthorized*'
    $stages.Count | Should -Be 0
  }

  It 'refuses <Fault> before entering the atomic writer' -ForEach @(
    @{ Fault = 'AuditStage' }; @{ Fault = 'AuditReadback' }; @{ Fault = 'UnsafePath' }; @{ Fault = 'Protection' }
  ) {
    $script:fault = $Fault
    $before = [IO.File]::ReadAllBytes($witnessPath)
    { Invoke-TestUpdate } | Should -Throw
    [Convert]::ToBase64String([IO.File]::ReadAllBytes($witnessPath)) | Should -BeExactly ([Convert]::ToBase64String($before))
    Should -Invoke Write-CoordAtomicBytes -Times 0 -Exactly -Scope It
    $context.Lease.Disposed | Should -BeTrue
    $context.BoardLease.Disposed | Should -BeTrue
  }

  It 'never overwrites a retained audit file' {
    $audit = $witnessPath + '.update-' + $updateId.ToString('D') + '.receipt.json'
    [IO.File]::WriteAllText($audit, 'retain')
    { Invoke-TestUpdate } | Should -Throw '*WitnessAuditExists*'
    [IO.File]::ReadAllText($audit) | Should -BeExactly 'retain'
    $stages.Count | Should -Be 0
  }

  It 'reports <Fault> as uncertain, retains images and never retries the writer' -ForEach @(
    @{ Fault = 'AtomicStage' }; @{ Fault = 'AtomicReplace' }; @{ Fault = 'AtomicReadback' }
    @{ Fault = 'WitnessReadback' }; @{ Fault = 'StateReadback' }; @{ Fault = 'ReceiptStage' }; @{ Fault = 'ReceiptReadback' }
  ) {
    $script:fault = $Fault
    $before = $context.RecordBytes.Clone()
    { Invoke-TestUpdate } | Should -Throw '*WitnessUpdateOutcomeUncertain*'
    [IO.File]::Exists($witnessPath + '.update-' + $updateId.ToString('D') + '.before.bin') | Should -BeTrue
    [IO.File]::Exists($witnessPath + '.update-' + $updateId.ToString('D') + '.after.bin') | Should -BeTrue
    $context.Lease.Disposed | Should -BeTrue
    $context.BoardLease.Disposed | Should -BeTrue
    Should -Invoke Write-CoordAtomicBytes -Times 1 -Exactly -Scope It
    $expected = if ($Fault -in @('AtomicStage', 'AtomicReplace')) { $before } else { $proposed }
    [Convert]::ToBase64String([IO.File]::ReadAllBytes($witnessPath)) | Should -BeExactly ([Convert]::ToBase64String($expected))
  }

  It 'refuses a changed state preimage before retaining audit files' {
    [IO.File]::WriteAllText($statePath, 'changed after context admission')
    { Invoke-TestUpdate } | Should -Throw '*SnapshotMismatch*'
    $stages.Count | Should -Be 0
    Should -Invoke Write-CoordAtomicBytes -Times 0 -Exactly -Scope It
  }

  It 'refuses a held mutation admission before persistence' {
    $stateValue.mutationAdmission.status = 'Held'
    [IO.File]::WriteAllText($statePath, ($stateValue | ConvertTo-Json -Depth 20 -Compress))
    $record.stateSha256 = Get-CoordHash ([IO.File]::ReadAllBytes($statePath))
    [IO.File]::WriteAllText($witnessPath, ($record | ConvertTo-Json -Depth 20 -Compress))
    Refresh-TestContext; Set-TestCandidate
    { Invoke-TestUpdate } | Should -Throw '*ResourceHeld*'
    $stages.Count | Should -Be 0
  }

  It 'preserves uncertain <Fault> and the primary cause when failure logging throws' -Tag 'C1945' -ForEach @(
    @{ Fault = 'AtomicReadback'; Primary = 'PersistenceFailed' }
    @{ Fault = 'WitnessReadback'; Primary = 'WitnessReadbackFailed' }
    @{ Fault = 'ReceiptStage'; Primary = 'SyntheticStageFailure' }
    @{ Fault = 'TypedPersistence'; Primary = 'typed-primary' }
  ) {
    $script:fault = $Fault
    if ($Fault -eq 'TypedPersistence') {
      $script:primaryException = [IO.IOException]::new('typed-primary')
      Mock Write-CoordAtomicBytes {
        if ($context.Lease.Disposed -or $context.BoardLease.Disposed) { throw 'LeaseReleasedBeforeReplace' }
        & $script:realAtomic -Path $Path -ExpectedBytes $ExpectedBytes -Bytes $Bytes
        throw $script:primaryException
      }
    }
    Mock Write-PSFMessage { throw 'SyntheticLoggerFailure' }
    $before = $context.RecordBytes.Clone(); $stateBefore = $context.StateBytes.Clone()
    $caught = $null; $output = @()
    try { $output = @(Invoke-TestUpdate) } catch { $caught = $_ }
    $caught | Should -Not -BeNullOrEmpty
    $caught.Exception.Message | Should -BeExactly 'WitnessUpdateOutcomeUncertain'
    $caught.Exception.GetBaseException().Message | Should -BeExactly $Primary
    if ($Fault -eq 'TypedPersistence') {
      [object]::ReferenceEquals($caught.Exception.InnerException, $script:primaryException) | Should -BeTrue
    }
    $output.Count | Should -Be 0
    [Convert]::ToBase64String([IO.File]::ReadAllBytes($witnessPath)) | Should -BeExactly ([Convert]::ToBase64String($proposed))
    [Convert]::ToBase64String([IO.File]::ReadAllBytes($statePath)) | Should -BeExactly ([Convert]::ToBase64String($stateBefore))
    $prefix = $witnessPath + '.update-' + $updateId.ToString('D')
    [Convert]::ToBase64String([IO.File]::ReadAllBytes($prefix + '.before.bin')) | Should -BeExactly ([Convert]::ToBase64String($before))
    [Convert]::ToBase64String([IO.File]::ReadAllBytes($prefix + '.after.bin')) | Should -BeExactly ([Convert]::ToBase64String($proposed))
    $context.Lease.Disposed | Should -BeTrue
    $context.BoardLease.Disposed | Should -BeTrue
    Should -Invoke Write-CoordAtomicBytes -Times 1 -Exactly -Scope It
    Should -Invoke Write-PSFMessage -Times 1 -Exactly -Scope It
  }

  It 'preserves the original prewriter refusal and disposal when failure logging throws' -Tag 'C1945' {
    Mock Write-PSFMessage { throw 'SyntheticLoggerFailure' }
    $before = $context.RecordBytes.Clone()
    $caught = $null; $output = @()
    try { $output = @(Invoke-TestUpdate -Expected ([Text.Encoding]::UTF8.GetBytes('stale'))) } catch { $caught = $_ }
    $caught | Should -Not -BeNullOrEmpty
    $caught.Exception.Message | Should -BeExactly 'SnapshotMismatch'
    $output.Count | Should -Be 0
    [Convert]::ToBase64String([IO.File]::ReadAllBytes($witnessPath)) | Should -BeExactly ([Convert]::ToBase64String($before))
    $stages.Count | Should -Be 0
    $context.Lease.Disposed | Should -BeTrue
    $context.BoardLease.Disposed | Should -BeTrue
    Should -Invoke Write-CoordAtomicBytes -Times 0 -Exactly -Scope It
    Should -Invoke Write-PSFMessage -Times 1 -Exactly -Scope It
  }

  It 'WhatIf performs no admission or file I/O and asserts only a proposal' {
    (Invoke-TestUpdate -PreviewOnly).Status | Should -BeExactly 'ProposedOnly'
    Should -Invoke Read-CoordProducerContext -Times 0 -Exactly -Scope It
    Should -Invoke Invoke-CoordOperationFileIo -Times 0 -Exactly -Scope It
    Should -Invoke Write-CoordAtomicBytes -Times 0 -Exactly -Scope It
    Should -Invoke Assert-CoordProtection -Times 0 -Exactly -Scope It
    Should -Invoke Assert-CoordOrdinaryPath -Times 0 -Exactly -Scope It
  }
}
