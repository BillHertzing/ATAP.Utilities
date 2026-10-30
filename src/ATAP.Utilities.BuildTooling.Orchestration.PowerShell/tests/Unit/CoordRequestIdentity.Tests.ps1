BeforeAll {
  $null = Get-Command -Name 'Write-PSFMessage' -ErrorAction Stop
  . (Join-Path $PSScriptRoot '../../private/ConvertTo-CoordCanonicalRequest.ps1')
  . (Join-Path $PSScriptRoot '../../private/Test-CoordRequest.ps1')
  $script:retryUtf8 = [Text.UTF8Encoding]::new($false, $true)
  $script:retryCanonical = '{"authorizationReference":"grant-A","category":"Claim","expectedRevision":"head-A","generation":"epoch-A","holder":{"holderId":"Senior3","sessionId":"session-A"},"payload":{},"predecessors":["P1","P2"],"protocolVersion":"Coordination-v1","requestId":"R-Claim","resourceId":"board-S17","scope":[{"path":"src/Owned.ps1","registeredRootId":"utilities-sprint"}],"sprintId":"0017","taskId":"17.23"}'
  $script:retryDigest = '9bcbe221b756441e947bbcf1f42e1ba04c24e194e724ff0d649e390b9d0fbc61'
  $script:retryLegacy = '{"authorizationReference":"grant-A","category":"Claim","expectedRevision":"obsolete-head","generation":"retired-epoch","holder":{"holderId":"Senior3","sessionId":"old-session"},"payload":{},"predecessors":["P1","P2"],"protocolVersion":"Coordination-v1","requestId":"R-Claim","resourceId":"board-S17","scope":[{"path":"src/Owned.ps1","registeredRootId":"utilities-sprint"}],"sprintId":"0017","taskId":"17.23"}'
  $script:retryLegacyDigest = '599ead008b78b07d4db81abd67e0ab8f20be80b877d3632a451b9dad73bc2d53'
  $script:retryLower = '{"authorizationReference":"grant-A","category":"Claim","expectedRevision":"head-A","generation":"epoch-A","holder":{"holderId":"Senior3","sessionId":"session-A"},"payload":{},"predecessors":["P1","P2"],"protocolVersion":"Coordination-v1","requestId":"r-claim","resourceId":"board-S17","scope":[{"path":"src/Owned.ps1","registeredRootId":"utilities-sprint"}],"sprintId":"0017","taskId":"17.23"}'
  $script:retryLowerDigest = '41f5ef3dfdf03f79f30b04c1deb8a087172764f8d3a825889a5050090042c967'
  $script:retryForeign = '{"authorizationReference":"grant-A","category":"Claim","expectedRevision":"head-A","generation":"epoch-A","holder":{"holderId":"Senior3","sessionId":"session-A"},"payload":{},"predecessors":["P1","P2"],"protocolVersion":"Coordination-v1","requestId":"R-Claim","resourceId":"board-OTHER","scope":[{"path":"src/Owned.ps1","registeredRootId":"utilities-sprint"}],"sprintId":"0017","taskId":"17.23"}'
  $script:retryForeignDigest = '75c340e1f29d76f9903702a9d7928bf47fbf5f4e876fdb063a8f72e12373bb48'
  $script:retryHistorical = '{"requestId":"R-Claim","resourceId":"board-S17","unknown":"preserved"}'
  $script:retryHistoricalDigest = 'c1a96df9413919bdfd2f6bd96300c2eaab1d8e1b157dfef14cc7d30b0a1df009'

  function New-RetryEnvelopeBytes {
    param([string]$RequestText, [string]$Digest)
    ,$script:retryUtf8.GetBytes('{"request":' + $RequestText + ',"digest":"' + $Digest + '"}')
  }

  function ConvertTo-RetryRecordsElement {
    param([string]$Json)
    $document = [Text.Json.JsonDocument]::Parse($Json, [Text.Json.JsonDocumentOptions]::new())
    try { $document.RootElement.Clone() } finally { $document.Dispose() }
  }

  function New-RetryRecordJson {
    param(
      [string]$RequestText = $script:retryCanonical,
      [string]$Digest = $script:retryDigest,
      [string]$Status = 'Pending',
      [string]$OriginalText = $RequestText
    )
    $requestObject = $RequestText | ConvertFrom-Json -AsHashtable
    $record = [ordered]@{
      request = $requestObject
      digest = $Digest
      originalRequestJson = $OriginalText
      queueOrdinal = '7'
      status = $Status
    }
    switch ($Status) {
      'Pending' { $record.pendingEvidence = @{ reason = 'WaitingForPredecessor' } }
      'Prepared' { $record.preparedOperationId = 'operation-fixture' }
      'NeedsRecovery' {
        $record.preparedOperationId = 'operation-fixture'
        $record.recoveryEvidence = @{ reason = 'Fixture interruption'; observedOutputs = @() }
      }
    }
    if ($Status -ceq 'Applied' -or $Status -ceq 'Rejected') {
      if ($Status -ceq 'Applied') { $record.preparedOperationId = 'operation-fixture' }
      # Synthetic caller-provenance fixture only: no actual receipt/grant authenticated.
      $record.terminalEvidence = [ordered]@{
        resourceId = $requestObject.resourceId
        requestId = $requestObject.requestId
        digest = $Digest
        status = $Status
        reason = 'Historical fixture outcome'
        receipt = @{ reference = 'fixture-only:original-outcome'; digest = $Digest }
      }
    }
    $record | ConvertTo-Json -Depth 40 -Compress
  }
}

Describe 'Test-CoordRequest retained identity-first classification' -Tag 'Unit' {
  BeforeEach {
    Mock Write-PSFMessage {}
    $bytes = New-RetryEnvelopeBytes -RequestText $script:retryCanonical -Digest $script:retryDigest
    $empty = ConvertTo-RetryRecordsElement -Json '[]'
  }

  It 'returns only further-validation stage for a new identity with <Kind> digest' -ForEach @(
    @{ Kind = 'matching'; Supplied = '9bcbe221b756441e947bbcf1f42e1ba04c24e194e724ff0d649e390b9d0fbc61'; Matches = $true },
    @{ Kind = 'wrong'; Supplied = '0000000000000000000000000000000000000000000000000000000000000000'; Matches = $false }
  ) {
    $bytes = New-RetryEnvelopeBytes -RequestText $script:retryCanonical -Digest $Supplied
    $result = Test-CoordRequest -EnvelopeBytes $bytes -MaxRequestBytes $bytes.Length -ExpectedResourceId 'board-S17' -RetainedRecords $empty
    $result.Stage | Should -BeExactly 'RetryClassifiedNotAdmitted'
    $result.Decision | Should -BeExactly 'NewRequestNeedsFurtherValidation'
    $result.CanonicalRequest.DigestMatches | Should -Be $Matches
    $result.CanonicalRequest.SuppliedDigest | Should -BeExactly $Supplied
    $result.RetainedStatus | Should -BeNullOrEmpty
    $result.RetainedRecord | Should -BeNullOrEmpty
    foreach ($forbidden in @('Accepted', 'Durable', 'Granted')) {
      $result.PSObject.Properties.Name | Should -Not -Contain $forbidden
    }
  }

  It 'returns the exact retained <Status> record despite historical epoch/session/head tokens' -ForEach @(
    @{ Status = 'Pending' }, @{ Status = 'Prepared' }, @{ Status = 'Applied' },
    @{ Status = 'Rejected' }, @{ Status = 'NeedsRecovery' }
  ) {
    $record = New-RetryRecordJson -RequestText $script:retryLegacy -Digest $script:retryLegacyDigest -Status $Status
    $snapshot = ConvertTo-RetryRecordsElement -Json ('[' + $record + ']')
    $before = $snapshot.GetRawText()
    $bytes = New-RetryEnvelopeBytes -RequestText $script:retryLegacy -Digest $script:retryLegacyDigest
    $result = Test-CoordRequest -EnvelopeBytes $bytes -MaxRequestBytes $bytes.Length -ExpectedResourceId 'board-S17' -RetainedRecords $snapshot

    $result.Decision | Should -BeExactly 'Retained'
    $result.RetainedStatus | Should -BeExactly $Status
    $result.RetainedRecord.GetRawText() | Should -BeExactly $record
    $result.CanonicalRequest.DigestMatches | Should -BeTrue
    $snapshot.GetRawText() | Should -BeExactly $before
    $result.RetainedRecord.GetProperty('request').GetProperty('generation').GetString() | Should -BeExactly 'retired-epoch'
  }

  It 'returns IdentityConflict before wrong supplied digest for changed <Field>' -ForEach @(
    @{ Field = 'scope'; Old = 'src/Owned.ps1'; New = 'src/Different.ps1' },
    @{ Field = 'task'; Old = '17.23'; New = '17.24' },
    @{ Field = 'session'; Old = 'session-A'; New = 'wrong-session' },
    @{ Field = 'authorization'; Old = 'grant-A'; New = 'wrong-grant' },
    @{ Field = 'generation'; Old = 'epoch-A'; New = 'retired-epoch' },
    @{ Field = 'revision'; Old = 'head-A'; New = 'stale-head' },
    @{ Field = 'predecessor order'; Old = '["P1","P2"]'; New = '["P2","P1"]' }
  ) {
    $record = New-RetryRecordJson -Status 'Applied'
    $snapshot = ConvertTo-RetryRecordsElement -Json ('[' + $record + ']')
    $changed = $script:retryCanonical.Replace($Old, $New)
    $bytes = New-RetryEnvelopeBytes -RequestText $changed -Digest ('0' * 64)
    $result = Test-CoordRequest -EnvelopeBytes $bytes -MaxRequestBytes $bytes.Length -ExpectedResourceId 'board-S17' -RetainedRecords $snapshot
    $result.Decision | Should -BeExactly 'IdentityConflict'
    $result.CanonicalRequest.DigestMatches | Should -BeFalse
    $result.RetainedStatus | Should -BeNullOrEmpty
    $result.RetainedRecord | Should -BeNullOrEmpty
    $snapshot.GetRawText() | Should -BeExactly ('[' + $record + ']')
  }

  It 'prioritizes changed bytes when session, epoch and revision are all stale together' {
    $record = New-RetryRecordJson -Status 'Rejected'
    $snapshot = ConvertTo-RetryRecordsElement -Json ('[' + $record + ']')
    $changed = $script:retryCanonical.Replace('session-A', 'old-session').Replace('epoch-A', 'old-epoch').Replace('head-A', 'old-head')
    $bytes = New-RetryEnvelopeBytes -RequestText $changed -Digest ('0' * 64)
    (Test-CoordRequest -EnvelopeBytes $bytes -MaxRequestBytes $bytes.Length -ExpectedResourceId 'board-S17' -RetainedRecords $snapshot).Decision |
      Should -BeExactly 'IdentityConflict'
  }

  It 'returns DigestMismatch for same canonical bytes with a bad supplied digest' {
    $record = New-RetryRecordJson -Status 'Applied'
    $snapshot = ConvertTo-RetryRecordsElement -Json ('[' + $record + ']')
    $bytes = New-RetryEnvelopeBytes -RequestText $script:retryCanonical -Digest ('0' * 64)
    $result = Test-CoordRequest -EnvelopeBytes $bytes -MaxRequestBytes $bytes.Length -ExpectedResourceId 'board-S17' -RetainedRecords $snapshot
    $result.Decision | Should -BeExactly 'DigestMismatch'
    $result.RetainedRecord | Should -BeNullOrEmpty
    $result.RetainedStatus | Should -BeNullOrEmpty
    $snapshot.GetRawText() | Should -BeExactly ('[' + $record + ']')
  }

  It 'matches equivalent JSON formatting without rewriting retained original text or applying the incoming byte limit to history' {
    $original = $script:retryCanonical.Replace(',', ',' + [char]10 + (' ' * 40))
    $record = New-RetryRecordJson -OriginalText $original
    $snapshot = ConvertTo-RetryRecordsElement -Json ('[' + $record + ']')
    $wire = $script:retryCanonical.Replace('src/Owned.ps1', 'src\/Owned.ps1')
    $bytes = New-RetryEnvelopeBytes -RequestText $wire -Digest $script:retryDigest
    $script:retryUtf8.GetByteCount($original) | Should -BeGreaterThan $bytes.Length
    $result = Test-CoordRequest -EnvelopeBytes $bytes -MaxRequestBytes $bytes.Length -ExpectedResourceId 'board-S17' -RetainedRecords $snapshot
    $result.Decision | Should -BeExactly 'Retained'
    $result.RetainedRecord.GetProperty('originalRequestJson').GetString() | Should -BeExactly $original
  }

  It 'uses ordinal request IDs and never folds a case-distinct identity into a retry' {
    $record = New-RetryRecordJson -RequestText $script:retryLower -Digest $script:retryLowerDigest
    $snapshot = ConvertTo-RetryRecordsElement -Json ('[' + $record + ']')
    $result = Test-CoordRequest -EnvelopeBytes $bytes -MaxRequestBytes $bytes.Length -ExpectedResourceId 'board-S17' -RetainedRecords $snapshot
    $result.Decision | Should -BeExactly 'NewRequestNeedsFurtherValidation'
    $result.RetainedRecord | Should -BeNullOrEmpty
  }

  It 'does not match or disclose a foreign-resource record with the same request ID' {
    $record = New-RetryRecordJson -RequestText $script:retryForeign -Digest $script:retryForeignDigest
    $snapshot = ConvertTo-RetryRecordsElement -Json ('[' + $record + ']')
    $result = Test-CoordRequest -EnvelopeBytes $bytes -MaxRequestBytes $bytes.Length -ExpectedResourceId 'board-S17' -RetainedRecords $snapshot
    $result.Decision | Should -BeExactly 'NewRequestNeedsFurtherValidation'
    $result.RetainedRecord | Should -BeNullOrEmpty
  }

  It 'checks wrong expected resource <Expected> before inspecting an invalid records container' -ForEach @(
    @{ Expected = 'board-OTHER' }, @{ Expected = 'board-s17' }
  ) {
    $invalid = ConvertTo-RetryRecordsElement -Json '"not-an-array"'
    $result = Test-CoordRequest -EnvelopeBytes $bytes -MaxRequestBytes $bytes.Length -ExpectedResourceId $Expected -RetainedRecords $invalid
    $result.Decision | Should -BeExactly 'ResourceMismatch'
    $result.RetainedRecord | Should -BeNullOrEmpty
    $result.RetainedStatus | Should -BeNullOrEmpty
  }

  It 'rejects unsafe incoming syntax before lookup and returns no retained data' {
    $invalid = ConvertTo-RetryRecordsElement -Json '"not-an-array"'
    [byte[]]$broken = @(0xC3, 0x28)
    $result = Test-CoordRequest -EnvelopeBytes $broken -MaxRequestBytes 2 -ExpectedResourceId 'board-S17' -RetainedRecords $invalid
    $result.Decision | Should -BeExactly 'InvalidRequest'
    $result.CanonicalRequest | Should -BeNullOrEmpty
    $result.RetainedRecord | Should -BeNullOrEmpty
  }

  It 'holds corrupt retained evidence <Corruption> without inventing new work or disclosing a result' -ForEach @(
    @{ Corruption = 'digest' }, @{ Corruption = 'original request' }, @{ Corruption = 'stored request' },
    @{ Corruption = 'missing status evidence' }, @{ Corruption = 'unsupported status' },
    @{ Corruption = 'duplicate record member' }, @{ Corruption = 'duplicate identities' },
    @{ Corruption = 'original trailing transport' }, @{ Corruption = 'original trailing JSON' }
  ) {
    $record = New-RetryRecordJson
    $value = $record | ConvertFrom-Json -AsHashtable
    switch ($Corruption) {
      'digest' { $value.digest = '0' * 64 }
      'original request' { $value.originalRequestJson = $value.originalRequestJson.Replace('17.23', '17.24') }
      'stored request' { $value.request.taskId = '17.24' }
      'missing status evidence' { $value.Remove('pendingEvidence') }
      'unsupported status' { $value.status = 'Deleted' }
      'original trailing transport' { $value.originalRequestJson += ',"transport":{}' }
      'original trailing JSON' { $value.originalRequestJson += ' {"extra":true}' }
    }
    $record = $value | ConvertTo-Json -Depth 40 -Compress
    if ($Corruption -eq 'duplicate record member') { $record = $record.Replace('"status":"Pending"', '"status":"Pending","status":"Pending"') }
    $json = '[' + $record + ']'
    if ($Corruption -eq 'duplicate identities') { $json = '[' + $record + ',' + $record + ']' }
    $snapshot = ConvertTo-RetryRecordsElement -Json $json
    $result = Test-CoordRequest -EnvelopeBytes $bytes -MaxRequestBytes $bytes.Length -ExpectedResourceId 'board-S17' -RetainedRecords $snapshot
    $result.Decision | Should -BeExactly 'NeedsRecovery'
    $result.RetainedStatus | Should -BeNullOrEmpty
    $result.RetainedRecord | Should -BeNullOrEmpty
    $snapshot.GetRawText() | Should -BeExactly $json
  }

  It 'holds mismatched terminal <Binding> evidence rather than returning an authentic-looking result' -ForEach @(
    @{ Binding = 'resourceId' }, @{ Binding = 'requestId' }, @{ Binding = 'digest' }, @{ Binding = 'status' }
  ) {
    $value = (New-RetryRecordJson -Status 'Applied') | ConvertFrom-Json -AsHashtable
    switch ($Binding) {
      'resourceId' { $value.terminalEvidence.resourceId = 'foreign' }
      'requestId' { $value.terminalEvidence.requestId = 'other' }
      'digest' { $value.terminalEvidence.digest = '0' * 64 }
      'status' { $value.terminalEvidence.status = 'Rejected' }
    }
    $record = $value | ConvertTo-Json -Depth 40 -Compress
    $snapshot = ConvertTo-RetryRecordsElement -Json ('[' + $record + ']')
    $result = Test-CoordRequest -EnvelopeBytes $bytes -MaxRequestBytes $bytes.Length -ExpectedResourceId 'board-S17' -RetainedRecords $snapshot
    $result.Decision | Should -BeExactly 'NeedsRecovery'
    $result.RetainedRecord | Should -BeNullOrEmpty
  }

  It 'holds unsupported historical Rejected grammar and preserves its original evidence' {
    $record = New-RetryRecordJson -RequestText $script:retryHistorical -Digest $script:retryHistoricalDigest -Status 'Rejected'
    $snapshot = ConvertTo-RetryRecordsElement -Json ('[' + $record + ']')
    $result = Test-CoordRequest -EnvelopeBytes $bytes -MaxRequestBytes $bytes.Length -ExpectedResourceId 'board-S17' -RetainedRecords $snapshot
    $result.Decision | Should -BeExactly 'NeedsRecovery'
    $result.Reason | Should -BeExactly 'RetainedRequestUnsupportedOrCorrupt'
    $result.RetainedRecord | Should -BeNullOrEmpty
    $snapshot.GetRawText() | Should -BeExactly ('[' + $record + ']')
  }

  It 'holds later unrelated current-root corruption instead of returning an earlier matching record' {
    $good = New-RetryRecordJson -Status 'Applied'
    $value = (New-RetryRecordJson) | ConvertFrom-Json -AsHashtable
    $value.request.requestId = 'another'
    $bad = $value | ConvertTo-Json -Depth 40 -Compress
    $snapshot = ConvertTo-RetryRecordsElement -Json ('[' + $good + ',' + $bad + ']')
    (Test-CoordRequest -EnvelopeBytes $bytes -MaxRequestBytes $bytes.Length -ExpectedResourceId 'board-S17' -RetainedRecords $snapshot).Decision |
      Should -BeExactly 'NeedsRecovery'
  }

  It 'returns an independent retained record clone usable after the caller document is disposed' {
    $record = New-RetryRecordJson -Status 'Applied'
    $document = [Text.Json.JsonDocument]::Parse(('[' + $record + ']'), [Text.Json.JsonDocumentOptions]::new())
    try {
      $result = Test-CoordRequest -EnvelopeBytes $bytes -MaxRequestBytes $bytes.Length -ExpectedResourceId 'board-S17' -RetainedRecords $document.RootElement
    } finally { $document.Dispose() }
    $result.Decision | Should -BeExactly 'Retained'
    $result.RetainedRecord.GetRawText() | Should -BeExactly $record
  }
}
