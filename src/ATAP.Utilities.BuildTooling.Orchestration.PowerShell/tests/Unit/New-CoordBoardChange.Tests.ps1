BeforeAll {
  $null = Get-Command -Name 'Write-PSFMessage' -ErrorAction Stop
  $script:sourceReader1618 = Join-Path $PSScriptRoot '../../private/Read-CoordBoard.ps1'
  $script:identityRoot1618 = Join-Path ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))) ('_generated/Sprint0017/CloseStreams/C1618/Unit-' + [guid]::NewGuid().ToString('N'))
  $private1618 = Join-Path $script:identityRoot1618 'private'
  $null = New-Item -ItemType Directory -Path $private1618 -Force
  $script:readerCopy1618 = Join-Path $private1618 'Read-CoordBoard.ps1'
  Copy-Item -LiteralPath $script:sourceReader1618 -Destination $script:readerCopy1618
  Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../../private/New-CoordBoardChange.ps1') -Destination $private1618
  . (Join-Path $private1618 'New-CoordBoardChange.ps1')
  $script:utf8 = [System.Text.UTF8Encoding]::new($false, $true)
  $script:headings = @(
    '- [ ] **Task 17.26** [ATAP.Utilities] - Parent fixture',
    '- [ ] **Task 17.26.a** - Child stays open',
    '- [x] **Task 17.27** - Historical completed fixture'
  )
  $script:boardText = @(
    '# Sprint fixture'
    ''
    '## Stream C'
    ''
    $script:headings[0]
    '  - Risk: preserve café and dependency wording exactly.'
    '### Risk detail'
    'Keep this note.'
    '  - Dependency: parent/child order must survive.'
    '  - Status: Planned.'
    ''
    $script:headings[1]
    '  - Status: Child open.'
    ''
    $script:headings[2]
    '  - Status: Historical completed fixture.'
    ''
  ) -join [char]10

  function ConvertTo-BoardElement {
    param($Value)
    $document = [System.Text.Json.JsonDocument]::Parse((ConvertTo-Json -InputObject $Value -Depth 100 -Compress))
    try { $document.RootElement.Clone() } finally { $document.Dispose() }
  }

  function New-TestBoardSnapshot {
    param([string]$Text = $script:boardText)
    $tasks = @()
    $ids = @('17.26', '17.26.a', '17.27')
    for ($index = 0; $index -lt $script:headings.Count; $index++) {
      $start = $Text.IndexOf($script:headings[$index], [System.StringComparison]::Ordinal)
      if ($index -eq 0 -and $start -eq 1 -and $Text.StartsWith([string][char]0xFEFF, [System.StringComparison]::Ordinal)) { $start = 0 }
      $end = if ($index + 1 -lt $script:headings.Count) {
        $Text.IndexOf($script:headings[$index + 1], [System.StringComparison]::Ordinal)
      } else { $Text.Length }
      $heading = $script:headings[$index]
      if ($start -eq 0 -and $Text[0] -eq [char]0xFEFF) { $heading = [string][char]0xFEFF + $heading }
      $tasks += [PSCustomObject]@{
        Id = $ids[$index]; Checked = $index -eq 2; Checkbox = $(if ($index -eq 2) { 'x' } else { ' ' })
        Heading = $heading; Text = $Text.Substring($start, $end - $start); StartOffset = [int]$start; EndOffset = [int]$end
      }
    }
    $bytes = $script:utf8.GetBytes($Text)
    [PSCustomObject]@{
      Path = 'C:\Synthetic\Tasks.Sprint0017.md'; Version = $null; SprintNumber = 17
      Text = $Text; RawBytes = $bytes; Sha256 = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
      Tasks = [object[]]$tasks; HasUtf8Bom = $Text.StartsWith([string][char]0xFEFF, [System.StringComparison]::Ordinal)
      NewLineKinds = @('LF'); HasFinalNewLine = $Text.EndsWith([string][char]10)
    }
  }

  function Set-TestBoardText {
    param([string]$Text)
    $script:snapshot = New-TestBoardSnapshot -Text $Text
    $script:context.snapshotSha256 = $script:snapshot.Sha256
  }

  function Invoke-TestBoardPreview {
    New-CoordBoardChange -Snapshot $script:snapshot -Request (ConvertTo-BoardElement $script:request) -AppliedReport (ConvertTo-BoardElement $script:report) -Context (ConvertTo-BoardElement $script:context) -Reservations (ConvertTo-BoardElement $script:reservations)
  }
}

Describe 'New-CoordBoardChange annotation-only source boundary' -Tag 'Unit' {
  BeforeEach {
    Mock Write-PSFMessage {}
    Copy-Item -LiteralPath $script:sourceReader1618 -Destination $script:readerCopy1618 -Force
    $script:snapshot = New-TestBoardSnapshot
    $evidence = @(
      [ordered]@{ reference = 'synthetic-evidence-A'; digest = [ordered]@{ algorithm = 'SHA256'; value = '0' * 64 } },
      [ordered]@{ reference = 'synthetic-evidence-B'; digest = [ordered]@{ algorithm = 'SHA256'; value = '1' * 64 } }
    )
    $scope = @([ordered]@{ registeredRootId = 'root-u'; path = 'src/Owned.ps1' })
    $holder = [ordered]@{ holderId = 'Senior1'; sessionId = 'session-A' }
    $script:annotation = 'CLAIMED / source-ready; holder=Senior1; claim=C-one.'
    $script:request = [ordered]@{
      protocolVersion = 'Coordination-v1'; resourceId = 'board-S17'; sprintId = '0017'
      requestId = 'A-one'; category = 'AcceptChange'; taskId = '17.26'
      scope = $scope; holder = $holder; authorizationReference = 'synthetic-coordinator-approval'
      generation = 'epoch-A'; expectedRevision = 'head-current'; predecessors = @('R-one')
      payload = [ordered]@{ reportRequestId = 'R-one'; evidence = $evidence; approvedChange = [ordered]@{ annotation = $script:annotation } }
    }
    $reportRequest = [ordered]@{
      protocolVersion = 'Coordination-v1'; resourceId = 'board-S17'; sprintId = '0017'
      requestId = 'R-one'; category = 'ReportResult'; taskId = '17.26'
      scope = $scope; holder = $holder; authorizationReference = 'synthetic-prior-report-approval'
      generation = 'epoch-A'; expectedRevision = 'head-historical'; predecessors = @()
      payload = [ordered]@{ claimId = 'C-one'; outcome = 'source-ready'; evidence = $evidence; statedLimits = 'Synthetic source evidence only.' }
    }
    # Shape fixtures are not authentic receipts, grants, evidence or live admission.
    $script:report = [ordered]@{
      request = $reportRequest; digest = '2' * 64; originalRequestJson = (ConvertTo-Json -InputObject $reportRequest -Depth 20 -Compress)
      queueOrdinal = '1'; status = 'Applied'; preparedOperationId = 'synthetic-operation'
      terminalEvidence = [ordered]@{
        resourceId = 'board-S17'; requestId = 'R-one'; digest = '2' * 64
        status = 'Applied'; reason = 'Synthetic'
        receipt = [ordered]@{ reference = 'synthetic-receipt'; digest = '3' * 64 }
      }
    }
    $script:context = [ordered]@{
      coordinatorId = 'coordinator-fixture'; resourceId = 'board-S17'; sprintId = '0017'
      generation = 'epoch-A'; committedRevision = 'head-current'; taskId = '17.26'
      authorizationReference = 'synthetic-coordinator-approval'; holder = $holder; scope = $scope
      claimId = 'C-one'; reportRequestId = 'R-one'; reportDigest = '2' * 64; evidence = $evidence
      snapshotSha256 = $script:snapshot.Sha256
      snapshotParserSha256 = (Get-FileHash -LiteralPath $script:readerCopy1618 -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    # An older unpublished reservation survives even though its task is not visible.
    $script:reservations = @([ordered]@{
      reservationId = 'older-reservation'; resourceId = 'board-S17'; requestId = 'older-request'
      taskId = '99.1'; scope = $scope; generation = 'epoch-older'
    })
  }

  It 'previews exactly one annotation and preserves risk/dependency, child/parent checkboxes, IDs and order' {
    $beforeText = $script:snapshot.Text
    $beforeBytes = [byte[]]$script:snapshot.RawBytes.Clone()
    $beforeTasks = ConvertTo-Json -InputObject $script:snapshot.Tasks -Depth 5 -Compress
    $reservationJson = (ConvertTo-BoardElement $script:reservations).GetRawText()
    $preview = Invoke-TestBoardPreview
    $expected = $script:boardText.Replace('  - Status: Planned.', '  - Status: ' + $script:annotation)
    $preview.Stage | Should -BeExactly 'ProposedNotPrepared'
    $preview.AfterText | Should -BeExactly $expected
    $script:utf8.GetString($preview.AfterBytes) | Should -BeExactly $expected
    $preview.BeforeSha256 | Should -BeExactly $script:snapshot.Sha256
    $preview.AfterSha256 | Should -BeExactly ([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($script:utf8.GetBytes($expected))).ToLowerInvariant())
    $preview.Reservations.GetRawText() | Should -BeExactly $reservationJson
    $preview.RequestId | Should -BeExactly 'A-one'
    $preview.BaseRevision | Should -BeExactly 'head-current'
    $script:snapshot.Text | Should -BeExactly $beforeText
    [Convert]::ToHexString($script:snapshot.RawBytes) | Should -BeExactly ([Convert]::ToHexString($beforeBytes))
    (ConvertTo-Json -InputObject $script:snapshot.Tasks -Depth 5 -Compress) | Should -BeExactly $beforeTasks
    $preview.BeforeBytes[0] = 0
    $script:snapshot.RawBytes[0] | Should -Be $beforeBytes[0]
  }

  It 'preserves in-memory existing line endings, BOM and final-newline absence without normalizing' -ForEach @(
    @{ Variant = 'CRLF' }, @{ Variant = 'BOM' }, @{ Variant = 'BOM-first-task' }, @{ Variant = 'no-final-LF' }
  ) {
    $text = switch ($Variant) {
      'CRLF' { $script:boardText.Replace([string][char]10, [string][char]13 + [char]10) }
      'BOM' { [string][char]0xFEFF + $script:boardText }
      'BOM-first-task' { [string][char]0xFEFF + $script:boardText.Substring($script:boardText.IndexOf($script:headings[0], [System.StringComparison]::Ordinal)) }
      'no-final-LF' { $script:boardText.TrimEnd([char]10) }
    }
    Set-TestBoardText $text
    $preview = Invoke-TestBoardPreview
    $preview.AfterText | Should -BeExactly $text.Replace('  - Status: Planned.', '  - Status: ' + $script:annotation)
  }

  It 'allows failed or blocked report annotations without checking off a task' -ForEach @(
    @{ Outcome = 'failed' }, @{ Outcome = 'blocked' }
  ) {
    $script:report.request.payload.outcome = $Outcome
    $script:request.payload.approvedChange.annotation = 'Reviewed evidence and limits.'
    $preview = Invoke-TestBoardPreview
    $preview.AfterText | Should -Match '\- \[ \] \*\*Task 17\.26\*\*'
    $preview.AfterText | Should -Match '  - Status: Reviewed evidence and limits\.'
  }

  It 'refuses a derived status category change <Label>' -ForEach @(
    @{ Label = 'open-to-blocked'; Before = 'Planned.'; Annotation = 'Blocked; awaiting evidence.' },
    @{ Label = 'unblocked-substring'; Before = 'Planned.'; Annotation = 'Unblocked; ready for review.' },
    @{ Label = 'in-progress'; Before = 'Planned.'; Annotation = 'In-progress; awaiting evidence.' },
    @{ Label = 'formatted-blocked'; Before = 'bl**oc**ked'; Annotation = 'Ready for review.' },
    @{ Label = 'backtick-blocked'; Before = 'bl`oc`ked'; Annotation = 'Ready for review.' },
    @{ Label = 'partial-to-open'; Before = 'Partial; work started.'; Annotation = 'Ready for review.' }
  ) {
    Set-TestBoardText $script:boardText.Replace('  - Status: Planned.', ('  - Status: ' + $Before))
    $script:request.payload.approvedChange.annotation = $Annotation
    $beforeBytes = [Convert]::ToHexString($script:snapshot.RawBytes)
    { Invoke-TestBoardPreview } | Should -Throw '*UnsupportedChange*'
    [Convert]::ToHexString($script:snapshot.RawBytes) | Should -BeExactly $beforeBytes
  }

  It 'allows a same-category annotation <Label>' -ForEach @(
    @{ Label = 'partial-stays-partial'; Before = 'Partial; work started.'; Annotation = 'Blocked; awaiting evidence.' },
    @{ Label = 'formatted-open'; Before = 'Rea**dy** for review.'; Annotation = 'Reviewed evidence and limits.' },
    @{ Label = 'open-stays-open'; Before = 'Planned.'; Annotation = 'Reviewed evidence and limits.' }
  ) {
    Set-TestBoardText $script:boardText.Replace('  - Status: Planned.', ('  - Status: ' + $Before))
    $script:request.payload.approvedChange.annotation = $Annotation
    $preview = Invoke-TestBoardPreview
    $preview.Stage | Should -BeExactly 'ProposedNotPrepared'
    $preview.AfterText | Should -BeExactly $script:boardText.Replace('  - Status: Planned.', ('  - Status: ' + $Annotation))
  }

  It 'refuses a continued Status field without truncating the consumer value' {
    $text = $script:boardText.Replace('  - Status: Planned.', ('  - Status: Planned.' + [char]10 + '    Blocked; awaiting evidence.'))
    Set-TestBoardText $text
    $script:request.payload.approvedChange.annotation = 'Ready for review.'
    { Invoke-TestBoardPreview } | Should -Throw '*UnsupportedChange*'
    $script:snapshot.Text | Should -BeExactly $text
  }

  It 'does not treat a later Files continuation as part of Status' {
    $text = $script:boardText.Replace('  - Status: Planned.', ('  - Status: Planned.' + [char]10 + '  - Files: Synthetic.ps1' + [char]10 + '    Blocked text belongs to Files.'))
    Set-TestBoardText $text
    $script:request.payload.approvedChange.annotation = 'Ready for review.'
    $preview = Invoke-TestBoardPreview
    $preview.AfterText | Should -BeExactly $text.Replace('  - Status: Planned.', '  - Status: Ready for review.')
  }

  It 'does not rebase or require the Applied report historical revision to equal the current head' {
    $preview = Invoke-TestBoardPreview
    $preview.BaseRevision | Should -BeExactly 'head-current'
    $script:report.request.expectedRevision | Should -BeExactly 'head-historical'
  }

  It 'refuses status, checkbox or completion payload operations instead of inventing mappings' -ForEach @(
    @{ Change = @{ status = 'Done' } },
    @{ Change = @{ status = 'Planned'; annotation = 'Source-only note.' } },
    @{ Change = @{ checkbox = 'x' } }
  ) {
    $script:request.payload.approvedChange = $Change
    { Invoke-TestBoardPreview } | Should -Throw '*UnsupportedChange*'
  }

  It 'refuses non-AcceptChange categories and never infers approval from a report or release' -ForEach @(
    @{ Category = 'ReportResult' }, @{ Category = 'Release' }, @{ Category = 'Claim' }, @{ Category = 'Allocate' }
  ) {
    $script:request.category = $Category
    { Invoke-TestBoardPreview } | Should -Throw '*UnsupportedChange*'
  }

  It 'refuses annotation injection or unsupported plain-text grammar <Label>' -ForEach @(
    @{ Label = 'new task'; Text = "note\n- [x] **Task 17.99** - injected" },
    @{ Label = 'CR'; Text = "note\rStatus: Done" },
    @{ Label = 'LF'; Text = "note\nStatus: Done" },
    @{ Label = 'HTML'; Text = '<script>alert(1)</script>' },
    @{ Label = 'HTML entity'; Text = '&lt;script&gt;' },
    @{ Label = 'section'; Text = '## Stream injected' },
    @{ Label = 'fence'; Text = '``` injected' },
    @{ Label = 'checkbox'; Text = '[x] completed' },
    @{ Label = 'reserved status'; Text = 'Status: hidden' },
    @{ Label = 'reserved task'; Text = 'Task: injected' },
    @{ Label = 'completion'; Text = 'Completed' },
    @{ Label = 'unicode separator'; Text = ('note' + [char]0x2028 + 'other') },
    @{ Label = 'tab'; Text = ("note" + [char]9 + "other") },
    @{ Label = 'format control'; Text = ('note' + [char]0x200D + 'other') }
  ) {
    # Include actual CR/LF controls; literal backslash forms are also unsupported.
    $script:request.payload.approvedChange.annotation = $Text.Replace('\n', [string][char]10).Replace('\r', [string][char]13)
    { Invoke-TestBoardPreview } | Should -Throw '*UnsupportedAnnotation*'
    $script:snapshot.Text | Should -BeExactly $script:boardText
  }

  It 'refuses unknown, duplicate or stale snapshot task metadata' -ForEach @(
    @{ Variant = 'unknown' }, @{ Variant = 'duplicate' }, @{ Variant = 'offset' }, @{ Variant = 'wrong-heading-ID' }
  ) {
    switch ($Variant) {
      'unknown' {
        $script:request.taskId = '17.999'; $script:context.taskId = '17.999'; $script:report.request.taskId = '17.999'
      }
      'duplicate' { $script:snapshot.Tasks[1].Id = '17.26' }
      'offset' { $script:snapshot.Tasks[0].EndOffset-- }
      'wrong-heading-ID' { $script:snapshot.Tasks[0].Id = '17.999' }
    }
    if ($Variant -eq 'unknown') { { Invoke-TestBoardPreview } | Should -Throw '*UnknownTask*' }
    else { { Invoke-TestBoardPreview } | Should -Throw '*SnapshotMismatch*' }
  }

  It 'refuses stale text, raw bytes, SHA or reader binding' -ForEach @(
    @{ Variant = 'text' }, @{ Variant = 'bytes' }, @{ Variant = 'sha' }, @{ Variant = 'context-sha' }, @{ Variant = 'reader' }
  ) {
    switch ($Variant) {
      'text' { $script:snapshot.Text += 'changed' }
      'bytes' { $script:snapshot.RawBytes[0] = 0 }
      'sha' { $script:snapshot.Sha256 = '0' * 64 }
      'context-sha' { $script:context.snapshotSha256 = '0' * 64 }
      'reader' { $script:context.snapshotParserSha256 = '0' * 64 }
    }
    { Invoke-TestBoardPreview } | Should -Throw '*SnapshotMismatch*'
  }

  It 'refuses missing, duplicate, differently indented, fenced or HTML status grammar' -ForEach @(
    @{ Variant = 'missing'; Replacement = '  - Note: Planned.' },
    @{ Variant = 'duplicate'; Replacement = ("  - Status: Planned." + [char]10 + "  - Status: Other.") },
    @{ Variant = 'indent'; Replacement = '    - Status: Planned.' },
    @{ Variant = 'fence'; Replacement = ('```' + [char]10 + '  - Status: Planned.' + [char]10 + '```') },
    @{ Variant = 'HTML'; Replacement = ('<!--' + [char]10 + '  - Status: Planned.' + [char]10 + '-->') }
  ) {
    Set-TestBoardText $script:boardText.Replace('  - Status: Planned.', $Replacement)
    { Invoke-TestBoardPreview } | Should -Throw '*UnsupportedGrammar*'
  }

  It 'refuses wrong request/context <Field> bindings ordinally' -ForEach @(
    @{ Field = 'resourceId' }, @{ Field = 'sprintId' }, @{ Field = 'generation' },
    @{ Field = 'taskId' }, @{ Field = 'authorizationReference' }
  ) {
    $script:context[$Field] += '-other'
    { Invoke-TestBoardPreview } | Should -Throw '*BindingMismatch*'
  }

  It 'refuses a stale current revision instead of rebasing' {
    $script:context.committedRevision = 'head-other'
    { Invoke-TestBoardPreview } | Should -Throw '*BindingMismatch*'
  }

  It 'refuses wrong holder or session on request or report' -ForEach @(
    @{ Side = 'request'; Field = 'holderId' }, @{ Side = 'request'; Field = 'sessionId' },
    @{ Side = 'report'; Field = 'holderId' }, @{ Side = 'report'; Field = 'sessionId' }
  ) {
    # Give the changed object independent data; fixtures otherwise share exact values.
    if ($Side -eq 'request') {
      $script:request.holder = @{ holderId = 'Senior1'; sessionId = 'session-A' }
      $script:request.holder[$Field] += '-other'
    } else {
      $script:report.request.holder = @{ holderId = 'Senior1'; sessionId = 'session-A' }
      $script:report.request.holder[$Field] += '-other'
    }
    { Invoke-TestBoardPreview } | Should -Throw '*BindingMismatch*'
  }

  It 'refuses a non-Applied report or mismatched terminal/digest/claim identity' -ForEach @(
    @{ Variant = 'status' }, @{ Variant = 'terminal-status' }, @{ Variant = 'digest' },
    @{ Variant = 'claim' }, @{ Variant = 'report-id' }, @{ Variant = 'terminal-resource' }
  ) {
    switch ($Variant) {
      'status' { $script:report.status = 'Pending' }
      'terminal-status' { $script:report.terminalEvidence.status = 'Rejected' }
      'digest' { $script:report.digest = '4' * 64 }
      'claim' { $script:context.claimId = 'C-other' }
      'report-id' { $script:request.payload.reportRequestId = 'R-other' }
      'terminal-resource' { $script:report.terminalEvidence.resourceId = 'other-resource' }
    }
    { Invoke-TestBoardPreview } | Should -Throw '*ReportMismatch*'
  }

  It 'requires the exact report as an Applied predecessor' {
    $script:request.predecessors = @()
    { Invoke-TestBoardPreview } | Should -Throw '*ReportMismatch*'
  }

  It 'refuses mismatched scope or evidence values/order' -ForEach @(
    @{ Variant = 'scope' }, @{ Variant = 'evidence-value' }, @{ Variant = 'evidence-order' }
  ) {
    switch ($Variant) {
      'scope' { $script:request.scope = @(@{ registeredRootId = 'root-u'; path = 'src/Other.ps1' }) }
      'evidence-value' { $script:request.payload.evidence = @(@{ reference = 'other'; digest = @{ algorithm = 'SHA256'; value = '0' * 64 } }) }
      'evidence-order' { $script:request.payload.evidence = @($script:request.payload.evidence[1], $script:request.payload.evidence[0]) }
    }
    { Invoke-TestBoardPreview } | Should -Throw '*ReportMismatch*'
  }

  It 'uses ordinal Unicode identity comparison rather than normalization' {
    $script:request.authorizationReference = [string][char]0xE9
    $script:context.authorizationReference = 'e' + [char]0x301
    { Invoke-TestBoardPreview } | Should -Throw '*BindingMismatch*'
  }

  It 'refuses missing or extra private context members rather than admitting defaults' -ForEach @(
    @{ Variant = 'missing' }, @{ Variant = 'extra' }
  ) {
    if ($Variant -eq 'missing') { $script:context.Remove('coordinatorId') }
    else { $script:context['grant'] = $true }
    { Invoke-TestBoardPreview } | Should -Throw '*InvalidInput*'
  }

  It 'binds parser identity for <Variant> without executing reader file code' -Tag 'ParserIdentity1618' -ForEach @(
    @{ Variant = 'source'; Allowed = $true },
    @{ Variant = 'signed014'; Allowed = $true },
    @{ Variant = 'changed-function'; Allowed = $false },
    @{ Variant = 'unknown-function'; Allowed = $false },
    @{ Variant = 'extra-statement'; Allowed = $false },
    @{ Variant = 'script-parameter'; Allowed = $false },
    @{ Variant = 'using-statement'; Allowed = $false },
    @{ Variant = 'script-requirement'; Allowed = $false },
    @{ Variant = 'stale-whole-file-hash'; Allowed = $false }
  ) {
    $sentinel = Join-Path $script:identityRoot1618 'must-not-execute.txt'
    if ($Variant -in @('signed014', 'stale-whole-file-hash')) {
      $signed = 'C:/Program Files/PowerShell/Modules/ATAP.Utilities.BuildTooling.Orchestration.PowerShell/0.1.4/private/Read-CoordBoard.ps1'
      Copy-Item -LiteralPath $signed -Destination $script:readerCopy1618 -Force
    } else {
      $text = [IO.File]::ReadAllText($script:readerCopy1618, $script:utf8)
      $text = switch ($Variant) {
        'changed-function' { $text.Replace('Duplicate task ID:', 'Changed task ID:') }
        'unknown-function' { 'function Read-CoordBoard { param() }' }
        'extra-statement' { $text + [char]10 + "Set-Content -LiteralPath '$sentinel' -Value Executed" }
        'script-parameter' { 'param()' + [char]10 + $text }
        'using-statement' { 'using namespace System' + [char]10 + $text }
        'script-requirement' { '#Requires -Version 7.0' + [char]10 + $text }
        default { $text }
      }
      [IO.File]::WriteAllText($script:readerCopy1618, $text, $script:utf8)
    }
    $actual = (Get-FileHash -LiteralPath $script:readerCopy1618 -Algorithm SHA256).Hash.ToLowerInvariant()
    $script:context.snapshotParserSha256 = $actual
    if ($Variant -eq 'stale-whole-file-hash') {
      $script:context.snapshotParserSha256 = (Get-FileHash -LiteralPath $script:sourceReader1618 -Algorithm SHA256).Hash.ToLowerInvariant()
      $script:context.snapshotParserSha256 | Should -Not -BeExactly $actual
    }
    if ($Allowed) {
      (Invoke-TestBoardPreview).Stage | Should -BeExactly 'ProposedNotPrepared'
      $script:context.snapshotParserSha256 | Should -BeExactly $actual
      if ($Variant -eq 'signed014') { $actual | Should -BeExactly '345a33e5816f559a53b704f81d0e6fb3aa27baf74c310f7d60a90e79498c73e1' }
    } else { { Invoke-TestBoardPreview } | Should -Throw '*SnapshotMismatch*' }
    Test-Path -LiteralPath $sentinel | Should -BeFalse
  }

  It 'does not use a scalar reservation value as an empty inventory' {
    $script:reservations = @{ taskId = 'not-an-array' }
    { Invoke-TestBoardPreview } | Should -Throw '*InvalidInput*'
  }
}

