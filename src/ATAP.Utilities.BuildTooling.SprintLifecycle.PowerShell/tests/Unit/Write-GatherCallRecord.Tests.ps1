#Requires -Version 7.0

<#
  Regression suite for Write-GatherCallRecord (Sprint 0015, Stream M, Task 15.183.b).

  Authority: gather-call-record.contract.v1.md, in
  _Planning/InformationForTheFuture/Sprint0015/StreamM/Task15.183/.
  Where this suite and the contract disagree, the contract wins and the
  disagreement is reported as a coverage finding rather than encoded here.

  Isolation: every fixture is created beneath $TestDrive. No test touches a real
  sprint worktree, a real _generated tree, git, a database, or the network.

  Implementation-coupling policy: behavioural tests splat only those parameters
  the command actually declares (see Invoke-Recorder), so an additional optional
  parameter on the implementation does not break this suite. The contract-critical
  parameter surface is asserted once, explicitly, in its own Context.
#>

BeforeAll {
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage {
      param(
        [string]$Level,
        [string]$Message,
        [Parameter(ValueFromRemainingArguments = $true)]$Rest
      )
    }
  }

  $script:moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $script:recorderPath = Join-Path $script:moduleRoot 'public\Write-GatherCallRecord.ps1'

  # Guarded dot-source. When Task 15.183.B01 has not yet landed the implementation
  # this leaves each It to fail on its own assertion rather than collapsing the
  # whole container into one opaque setup error.
  if (Test-Path -LiteralPath $script:recorderPath -PathType Leaf) {
    . $script:recorderPath
  }

  $script:fixtureRoot = Join-Path $TestDrive 'gather-call-record'
  New-Item -ItemType Directory -Path $script:fixtureRoot -Force | Out-Null

  # gather-call-record.contract.v1.md section 9: the complete required field set.
  $script:RequiredRecordFields = @(
    'recordVersion', 'invocationId', 'requestResponsePairId', 'ordinal', 'ordinalScope',
    'timestampUtc', 'agentName', 'agentModel', 'sessionId', 'taskId', 'worktreePath',
    'repositoryName', 'conversationId', 'conversationTitle', 'tags', 'tagsRaw',
    'depth', 'width', 'instance', 'prompt', 'outcome', 'responseStatus', 'stubMarker',
    'stubBlockedBy', 'itemCount', 'truncated', 'errorMessage', 'responseDigest',
    'redacted', 'redactionCount', 'retryOfInvocationId', 'supersedesInvocationId'
  )

  $script:UuidV4Pattern = '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
  $script:TimestampPattern = '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3}Z$'

  # Contract section 4: when items is [], the digest is over the canonical empty
  # array and is therefore a known constant. This is SHA-256 of the two bytes "[]".
  $script:EmptyItemsDigest = '4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945'

  function New-WorktreeFixture {
    param([string]$Name)
    $root = Join-Path $script:fixtureRoot ($Name + '-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    $root
  }

  function New-StubEnvelope {
    param(
      [string[]]$Tags = @('handoff'),
      [int]$Depth = 3,
      [int]$Width = 2,
      [string]$Instance = 'production'
    )
    [pscustomobject]@{
      agent  = 'gather-content-summary'
      status = 'NotImplemented'
      stub   = [pscustomobject]@{
        marker    = 'CONTENT_SUMMARY_RETRIEVAL_NOT_IMPLEMENTED'
        blockedBy = @('RDB-190', 'RDB-260', 'Stream D', 'Task 14.113')
        reason    = 'ContentSummary entity names are not settled.'
      }
      query  = [pscustomobject]@{ tags = $Tags; depth = $Depth; width = $Width; instance = $Instance }
      items  = @()
      truncated = $false
      error  = $null
    }
  }

  function New-OkEnvelope {
    param([object[]]$Items = @(), [bool]$Truncated = $false)
    [pscustomobject]@{
      agent     = 'gather-content-summary'
      status    = 'ok'
      query     = [pscustomobject]@{ tags = @('handoff'); depth = 3; width = 2; instance = 'production' }
      items     = $Items
      truncated = $Truncated
      error     = $null
    }
  }

  function New-RecorderArgument {
    param([string]$WorktreePath)
    @{
      AgentName             = 'junior-dev-coder-jm'
      AgentModel            = $null
      SessionId             = 'sess-fixture-0001'
      TaskId                = '15.183.b'
      WorktreeRoot          = $WorktreePath
      RepositoryName        = 'ATAP.Utilities'
      ConversationId        = 'conv-fixture-0001'
      ConversationTitle     = 'Sprint 0015 Stream M'
      Tags                  = @('handoff', 'contract')
      Depth                 = 3
      Width                 = 2
      Instance              = 'production'
      Prompt                = 'Context for the gather-call recorder regression suite.'
      Response              = (New-StubEnvelope)
      SprintNumber          = '0015'
      RequestResponsePairId = $null
    }
  }

  # Splat only what the implementation declares, so an extra optional parameter on
  # the implementation is not a false failure here. A MISSING contract-critical
  # parameter is caught by the dedicated parameter-surface Context instead.
  function Invoke-Recorder {
    [CmdletBinding()]
    param([hashtable]$Argument, [switch]$Raw)
    $command = Get-Command -Name 'Write-GatherCallRecord' -ErrorAction Stop
    $declared = $command.Parameters.Keys
    $splat = @{}
    foreach ($key in $Argument.Keys) {
      if ($declared -contains $key) { $splat[$key] = $Argument[$key] }
    }
    Write-GatherCallRecord @splat
  }

  function Get-RecordFile {
    param([string]$WorktreePath)
    $generated = Join-Path $WorktreePath '_generated'
    if (-not (Test-Path -LiteralPath $generated)) { return @() }
    @(Get-ChildItem -LiteralPath $generated -Recurse -File -Filter '*.jsonl' -ErrorAction SilentlyContinue)
  }

  function Get-RecordLine {
    param([string]$WorktreePath)
    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($file in (Get-RecordFile -WorktreePath $WorktreePath)) {
      $text = [System.IO.File]::ReadAllText($file.FullName)
      foreach ($line in ($text -split "`n")) {
        if ($line.Trim().Length -gt 0) { $lines.Add($line) }
      }
    }
    # Unary comma: a one-element result must stay an array, otherwise (...)[0]
    # would index the first CHARACTER of the single JSON line.
    , $lines.ToArray()
  }

  function Get-Record {
    param([string]$WorktreePath)
    @(Get-RecordLine -WorktreePath $WorktreePath | ForEach-Object { $_ | ConvertFrom-Json })
  }
}

AfterAll {
  if ($script:fixtureRoot -and (Test-Path -LiteralPath $script:fixtureRoot)) {
    Remove-Item -LiteralPath $script:fixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}

Describe 'Write-GatherCallRecord [public]' -Tag 'Unit' {

  Context 'Command surface' {

    It 'ships an implementation file in public/' {
      Test-Path -LiteralPath $script:recorderPath -PathType Leaf | Should -BeTrue
    }

    It 'defines the function' {
      Get-Command -Name 'Write-GatherCallRecord' -CommandType Function |
        Should -Not -BeNullOrEmpty
    }

    It 'is an advanced function supporting ShouldProcess' {
      $command = Get-Command -Name 'Write-GatherCallRecord' -CommandType Function
      $command.CmdletBinding | Should -BeTrue
      $command.Parameters.Keys | Should -Contain 'WhatIf'
      $command.Parameters.Keys | Should -Contain 'Confirm'
    }

    It 'declares the contract-critical caller-supplied parameters' {
      # Everything the caller must be able to state. Fields the recorder derives
      # itself (invocationId, timestampUtc, ordinal, digest, redaction) are
      # deliberately absent from this list - contract sections 3.1.1 and 5.
      $command = Get-Command -Name 'Write-GatherCallRecord' -CommandType Function
      $expected = @(
        'AgentName', 'SessionId', 'TaskId',
        'ConversationId', 'ConversationTitle',
        'Tags', 'Depth', 'Width', 'Instance', 'Prompt', 'Response'
      )
      foreach ($parameter in $expected) {
        $command.Parameters.Keys | Should -Contain $parameter -Because "the contract requires the caller to be able to state $parameter"
      }
      # The contract fixes the record FIELD name (worktreePath); the parameter
      # spelling is the implementation's choice, so accept either.
      @($command.Parameters.Keys | Where-Object { $_ -in @('WorktreeRoot', 'WorktreePath') }).Count |
        Should -BeGreaterThan 0 -Because 'the caller must be able to state which worktree root the call ran in'
    }

    It 'does not expose a parameter that would let a caller supply invocationId' {
      # Contract 3.1.1: recorder-generated so a caller can neither omit nor reuse one.
      $command = Get-Command -Name 'Write-GatherCallRecord' -CommandType Function
      $command.Parameters.Keys | Should -Not -Contain 'InvocationId'
    }

    It 'contains no top-level executable code beyond the function definition' {
      $tokens = $null
      $parseErrors = $null
      $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        $script:recorderPath, [ref]$tokens, [ref]$parseErrors)
      $parseErrors | Should -BeNullOrEmpty
      $topLevel = @($ast.EndBlock.Statements | Where-Object {
          $_ -isnot [System.Management.Automation.Language.FunctionDefinitionAst]
        })
      $topLevel | Should -BeNullOrEmpty
    }

    It 'logs through PSFramework and never through Write-Host' {
      $source = Get-Content -LiteralPath $script:recorderPath -Raw
      $source | Should -Not -Match 'Write-Host'
    }
  }

  Context 'Success - a single well-formed record' {

    BeforeAll {
      $script:successRoot = New-WorktreeFixture -Name 'success'
      Invoke-Recorder -Argument (New-RecorderArgument -WorktreePath $script:successRoot)
    }

    It 'appends exactly one record' {
      (Get-RecordLine -WorktreePath $script:successRoot).Count | Should -Be 1
    }

    It 'writes beneath the _generated gather-calls location the contract specifies' {
      $files = Get-RecordFile -WorktreePath $script:successRoot
      $files.Count | Should -BeGreaterThan 0
      $directory = ($files[0].DirectoryName -replace '\\', '/')
      $directory | Should -Match '/_generated/Sprint0015/StreamM/gather-calls$'
    }

    It 'emits every required field, present even when null' {
      $record = (Get-Record -WorktreePath $script:successRoot)[0]
      $names = $record.PSObject.Properties.Name
      foreach ($field in $script:RequiredRecordFields) {
        $names | Should -Contain $field -Because 'a required nullable field must be present and null, never absent'
      }
    }

    It 'pins recordVersion to the v1 contract' {
      (Get-Record -WorktreePath $script:successRoot)[0].recordVersion | Should -Be '1.0.0'
    }

    It 'stamps a lowercase hyphenated UUIDv4 invocationId' {
      (Get-Record -WorktreePath $script:successRoot)[0].invocationId | Should -Match $script:UuidV4Pattern
    }

    It 'stamps a UTC millisecond-precision timestamp' {
      # Asserted against the raw JSON text on purpose: ConvertFrom-Json coerces an
      # ISO-8601 string into [datetime], which would mask the on-disk precision.
      $line = (Get-RecordLine -WorktreePath $script:successRoot)[0]
      $line | Should -Match ('"timestampUtc"\s*:\s*"' + $script:TimestampPattern.Trim('^$') + '"')
    }

    It 'classifies a stubbed envelope as the stubbed outcome, not a failure' {
      $record = (Get-Record -WorktreePath $script:successRoot)[0]
      $record.outcome | Should -Be 'stubbed'
      $record.responseStatus | Should -Be 'NotImplemented'
      $record.stubMarker | Should -Be 'CONTENT_SUMMARY_RETRIEVAL_NOT_IMPLEMENTED'
      $record.stubBlockedBy | Should -Contain 'RDB-190'
    }

    It 'normalizes tags and retains the submitted form separately' {
      $root = New-WorktreeFixture -Name 'tags'
      $argument = New-RecorderArgument -WorktreePath $root
      $argument.Tags = @('  Zebra ', 'alpha', 'Alpha', 'two  words', '   ')
      Invoke-Recorder -Argument $argument

      $record = (Get-Record -WorktreePath $root)[0]
      # Contract 3.3.1: trim, invariant-lowercase, whitespace to hyphen,
      # drop empties, de-duplicate, ordinal sort.
      ($record.tags -join ',') | Should -Be 'alpha,two-words,zebra'
      ($record.tagsRaw -join '|') | Should -Be '  Zebra |alpha|Alpha|two  words|   '
    }

    It 'echoes the submitted query parameters verbatim' {
      $record = (Get-Record -WorktreePath $script:successRoot)[0]
      $record.depth | Should -Be 3
      $record.width | Should -Be 2
      $record.instance | Should -Be 'production'
    }
  }

  Context 'JSONL storage form' {

    BeforeAll {
      $script:formRoot = New-WorktreeFixture -Name 'form'
      1..3 | ForEach-Object {
        Invoke-Recorder -Argument (New-RecorderArgument -WorktreePath $script:formRoot)
      }
      $script:formFile = (Get-RecordFile -WorktreePath $script:formRoot)[0].FullName
      $script:formBytes = [System.IO.File]::ReadAllBytes($script:formFile)
    }

    It 'writes UTF-8 without a byte-order mark' {
      if ($script:formBytes.Length -ge 3) {
        @($script:formBytes[0], $script:formBytes[1], $script:formBytes[2]) -join ',' |
          Should -Not -Be '239,187,191'
      }
    }

    It 'uses LF line endings, never CRLF' {
      $text = [System.Text.Encoding]::UTF8.GetString($script:formBytes)
      $text | Should -Not -Match "`r"
    }

    It 'terminates every record with a newline' {
      $script:formBytes[-1] | Should -Be 10
    }

    It 'writes one record per line with no pretty-printing' {
      $lines = Get-RecordLine -WorktreePath $script:formRoot
      $lines.Count | Should -Be 3
      foreach ($line in $lines) {
        { $line | ConvertFrom-Json } | Should -Not -Throw
      }
    }

    It 'appends rather than truncating on each subsequent call' {
      Invoke-Recorder -Argument (New-RecorderArgument -WorktreePath $script:formRoot)
      (Get-RecordLine -WorktreePath $script:formRoot).Count | Should -Be 4
    }
  }

  Context 'Stable and non-colliding invocation identity' {

    It 'gives every call a distinct invocationId' {
      $root = New-WorktreeFixture -Name 'identity'
      1..50 | ForEach-Object {
        Invoke-Recorder -Argument (New-RecorderArgument -WorktreePath $root)
      }
      $ids = @((Get-Record -WorktreePath $root).invocationId)
      $ids.Count | Should -Be 50
      ($ids | Sort-Object -Unique).Count | Should -Be 50
    }

    It 'gives two byte-identical calls two distinct ids rather than collapsing them' {
      # Contract 3.1.1 is explicit: the id is NOT content-derived, because a retry
      # or two workers on one task are legitimately two calls. A content-derived id
      # would silently collapse them into one.
      $root = New-WorktreeFixture -Name 'identical'
      $argument = New-RecorderArgument -WorktreePath $root
      Invoke-Recorder -Argument $argument
      Invoke-Recorder -Argument $argument

      $records = Get-Record -WorktreePath $root
      $records.Count | Should -Be 2
      $records[0].invocationId | Should -Not -Be $records[1].invocationId
    }

    It 'keeps a written id stable across repeated reads' {
      $root = New-WorktreeFixture -Name 'stable'
      Invoke-Recorder -Argument (New-RecorderArgument -WorktreePath $root)
      $first = (Get-Record -WorktreePath $root)[0].invocationId
      $second = (Get-Record -WorktreePath $root)[0].invocationId
      $second | Should -Be $first
    }

    It 'counts ordinals per session and marks the scope as session' {
      $root = New-WorktreeFixture -Name 'ordinal-session'
      1..3 | ForEach-Object {
        Invoke-Recorder -Argument (New-RecorderArgument -WorktreePath $root)
      }
      $records = Get-Record -WorktreePath $root
      foreach ($record in $records) { $record.ordinalScope | Should -Be 'session' }
      (@($records.ordinal | Sort-Object) -join ',') | Should -Be '1,2,3'
    }

    It 'falls back to file-scoped ordinals when the harness exposes no session' {
      $root = New-WorktreeFixture -Name 'ordinal-file'
      $argument = New-RecorderArgument -WorktreePath $root
      $argument.SessionId = $null
      1..2 | ForEach-Object { Invoke-Recorder -Argument $argument }

      $records = Get-Record -WorktreePath $root
      foreach ($record in $records) {
        $record.sessionId | Should -BeNullOrEmpty
        $record.ordinalScope | Should -Be 'file'
      }
      (@($records.ordinal | Sort-Object) -join ',') | Should -Be '1,2'
    }
  }

  Context 'Concurrency - multiple writers appending at once' {

    It 'loses no record and corrupts no line when eight writers append concurrently' {
      $root = New-WorktreeFixture -Name 'concurrency'
      $recorderPath = $script:recorderPath

      1..8 | ForEach-Object -Parallel {
        $writerIndex = $_
        if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
          function global:Write-PSFMessage {
            param([string]$Level, [string]$Message,
              [Parameter(ValueFromRemainingArguments = $true)]$Rest)
          }
        }
        . $using:recorderPath
        $command = Get-Command -Name 'Write-GatherCallRecord'
        $declared = $command.Parameters.Keys
        1..5 | ForEach-Object {
          $argument = @{
            AgentName    = 'junior-dev-coder-jm'
            SessionId    = "sess-writer-$writerIndex"
            TaskId       = '15.183.b'
            WorktreeRoot = $using:root
            Tags         = @('concurrency')
            Depth        = 3
            Width        = 2
            Instance     = 'production'
            Prompt       = "writer $writerIndex call $_"
            SprintNumber = '0015'
            Response     = [pscustomobject]@{
              agent = 'gather-content-summary'; status = 'NotImplemented'
              stub  = [pscustomobject]@{
                marker    = 'CONTENT_SUMMARY_RETRIEVAL_NOT_IMPLEMENTED'
                blockedBy = @('RDB-190')
              }
              items = @(); truncated = $false; error = $null
            }
          }
          $splat = @{}
          foreach ($key in $argument.Keys) {
            if ($declared -contains $key) { $splat[$key] = $argument[$key] }
          }
          Write-GatherCallRecord @splat
        }
      } -ThrottleLimit 8

      $lines = Get-RecordLine -WorktreePath $root
      $lines.Count | Should -Be 40 -Because 'no append may overwrite or be lost'

      foreach ($line in $lines) {
        { $line | ConvertFrom-Json } | Should -Not -Throw -Because 'no line may be torn by an interleaved write'
      }

      $ids = @((Get-Record -WorktreePath $root).invocationId)
      ($ids | Sort-Object -Unique).Count | Should -Be 40
    }

    It 'keeps each concurrent session ordinal sequence complete and gap-free' {
      $root = New-WorktreeFixture -Name 'concurrency-ordinal'
      $recorderPath = $script:recorderPath

      1..4 | ForEach-Object -Parallel {
        $writerIndex = $_
        if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
          function global:Write-PSFMessage {
            param([string]$Level, [string]$Message,
              [Parameter(ValueFromRemainingArguments = $true)]$Rest)
          }
        }
        . $using:recorderPath
        $command = Get-Command -Name 'Write-GatherCallRecord'
        $declared = $command.Parameters.Keys
        1..3 | ForEach-Object {
          $argument = @{
            AgentName    = 'junior-dev-coder-jm'
            SessionId    = "sess-ord-$writerIndex"
            WorktreeRoot = $using:root
            Tags         = @('concurrency')
            Depth        = 3
            Width        = 2
            Instance     = 'production'
            Prompt       = 'ordinal integrity'
            SprintNumber = '0015'
            Response     = [pscustomobject]@{
              agent = 'gather-content-summary'; status = 'ok'
              items = @(); truncated = $false; error = $null
            }
          }
          $splat = @{}
          foreach ($key in $argument.Keys) {
            if ($declared -contains $key) { $splat[$key] = $argument[$key] }
          }
          Write-GatherCallRecord @splat
        }
      } -ThrottleLimit 4

      $records = Get-Record -WorktreePath $root
      $records.Count | Should -Be 12
      foreach ($group in ($records | Group-Object -Property sessionId)) {
        (@($group.Group.ordinal | Sort-Object) -join ',') | Should -Be '1,2,3' -Because "session $($group.Name) must own a contiguous 1-based ordinal run"
      }
    }
  }

  Context 'Retries and supersession' {

    It 'records a retry as its own record linked to the original, not as an amendment' {
      $root = New-WorktreeFixture -Name 'retry'
      $argument = New-RecorderArgument -WorktreePath $root
      Invoke-Recorder -Argument $argument
      $original = (Get-Record -WorktreePath $root)[0]

      $retryArgument = New-RecorderArgument -WorktreePath $root
      $retryArgument.RetryOfInvocationId = $original.invocationId
      Invoke-Recorder -Argument $retryArgument

      $records = @(Get-Record -WorktreePath $root)
      $records.Count | Should -Be 2 -Because 'a retry is a new call, never an edit of the prior record'
      $retry = @($records | Where-Object { $_.retryOfInvocationId })
      $retry.Count | Should -Be 1
      $retry[0].retryOfInvocationId | Should -Be $original.invocationId
      $retry[0].invocationId | Should -Not -Be $original.invocationId
    }

    It 'leaves the original record byte-identical after a retry is appended' {
      # This is what makes "retries do not double-count": the original is neither
      # rewritten nor duplicated, so a consumer counting distinct invocationIds
      # and excluding non-null retryOfInvocationId gets each logical call once.
      $root = New-WorktreeFixture -Name 'retry-immutable'
      Invoke-Recorder -Argument (New-RecorderArgument -WorktreePath $root)
      $before = (Get-RecordLine -WorktreePath $root)[0]

      $retryArgument = New-RecorderArgument -WorktreePath $root
      $retryArgument.RetryOfInvocationId = ($before | ConvertFrom-Json).invocationId
      Invoke-Recorder -Argument $retryArgument

      $after = Get-RecordLine -WorktreePath $root
      $after[0] | Should -Be $before
      @($after | Sort-Object -Unique).Count | Should -Be 2 -Because 'the two lines are distinct records, not a duplicated one'
    }

    It 'records a correcting record as superseding rather than removing the corrected one' {
      $root = New-WorktreeFixture -Name 'supersede'
      Invoke-Recorder -Argument (New-RecorderArgument -WorktreePath $root)
      $original = (Get-Record -WorktreePath $root)[0]

      $correction = New-RecorderArgument -WorktreePath $root
      $correction.SupersedesInvocationId = $original.invocationId
      Invoke-Recorder -Argument $correction

      $records = @(Get-Record -WorktreePath $root)
      $records.Count | Should -Be 2
      @($records | Where-Object { $_.invocationId -eq $original.invocationId }).Count |
        Should -Be 1 -Because 'a superseded record stays in the stream'
      @($records | Where-Object { $_.supersedesInvocationId -eq $original.invocationId }).Count |
        Should -Be 1
    }

    It 'defaults both supersession fields to a present null' {
      $root = New-WorktreeFixture -Name 'supersede-null'
      Invoke-Recorder -Argument (New-RecorderArgument -WorktreePath $root)
      $record = (Get-Record -WorktreePath $root)[0]
      $record.PSObject.Properties.Name | Should -Contain 'retryOfInvocationId'
      $record.PSObject.Properties.Name | Should -Contain 'supersedesInvocationId'
      $record.retryOfInvocationId | Should -BeNullOrEmpty
      $record.supersedesInvocationId | Should -BeNullOrEmpty
    }
  }

  Context 'Outcome classification' {

    It 'classifies an ok, untruncated, error-free envelope as success' {
      $root = New-WorktreeFixture -Name 'outcome-success'
      $argument = New-RecorderArgument -WorktreePath $root
      $argument.Response = New-OkEnvelope -Items @([pscustomobject]@{ path = 'a.ps1' })
      Invoke-Recorder -Argument $argument

      $record = (Get-Record -WorktreePath $root)[0]
      $record.outcome | Should -Be 'success'
      $record.responseStatus | Should -Be 'ok'
      $record.itemCount | Should -Be 1
      $record.truncated | Should -BeFalse
      $record.stubMarker | Should -BeNullOrEmpty
    }

    It 'classifies a truncated ok envelope as partial' {
      $root = New-WorktreeFixture -Name 'outcome-partial'
      $argument = New-RecorderArgument -WorktreePath $root
      $argument.Response = New-OkEnvelope -Items @([pscustomobject]@{ path = 'a.ps1' }) -Truncated $true
      Invoke-Recorder -Argument $argument

      (Get-Record -WorktreePath $root)[0].outcome | Should -Be 'partial'
    }

    It 'classifies an envelope carrying an error as failure' {
      $root = New-WorktreeFixture -Name 'outcome-failure'
      $argument = New-RecorderArgument -WorktreePath $root
      $envelope = New-OkEnvelope
      $envelope.error = 'entity allow-list rejected the request'
      $argument.Response = $envelope
      Invoke-Recorder -Argument $argument

      $record = (Get-Record -WorktreePath $root)[0]
      $record.outcome | Should -Be 'failure'
      $record.errorMessage | Should -Match 'entity allow-list'
    }

    It 'writes a failure record rather than nothing when no envelope was received' {
      # The case a silent recorder would lose entirely.
      $root = New-WorktreeFixture -Name 'outcome-noenvelope'
      $argument = New-RecorderArgument -WorktreePath $root
      $argument.Remove('Response')
      $argument.NoResponse = $true
      Invoke-Recorder -Argument $argument

      $records = @(Get-Record -WorktreePath $root)
      $records.Count | Should -Be 1
      $records[0].outcome | Should -Be 'failure'
      $records[0].responseStatus | Should -BeNullOrEmpty
      $records[0].itemCount | Should -BeNullOrEmpty
      $records[0].responseDigest | Should -BeNullOrEmpty
    }

    It 'distinguishes a genuinely empty ok result from a stubbed one' {
      $emptyRoot = New-WorktreeFixture -Name 'empty-ok'
      $emptyArgument = New-RecorderArgument -WorktreePath $emptyRoot
      $emptyArgument.Response = New-OkEnvelope
      Invoke-Recorder -Argument $emptyArgument

      $stubRoot = New-WorktreeFixture -Name 'empty-stub'
      Invoke-Recorder -Argument (New-RecorderArgument -WorktreePath $stubRoot)

      $empty = (Get-Record -WorktreePath $emptyRoot)[0]
      $stub = (Get-Record -WorktreePath $stubRoot)[0]

      $empty.outcome | Should -Be 'success'
      $stub.outcome | Should -Be 'stubbed'
      $empty.stubMarker | Should -BeNullOrEmpty
      $stub.stubMarker | Should -Be 'CONTENT_SUMMARY_RETRIEVAL_NOT_IMPLEMENTED'
      # Contract section 4: both digest identically. The discriminator is the
      # marker, never the digest.
      $empty.responseDigest.value | Should -Be $stub.responseDigest.value
    }
  }

  Context 'Write failure is surfaced explicitly, not swallowed' {

    It 'reports a write failure without throwing at the caller' {
      # Contract 6.3.4: a recorder failure must not fail the gather call, but the
      # pinned interface requires it be surfaced rather than silently dropped.
      $root = New-WorktreeFixture -Name 'writefail'
      $blockedDirectory = Join-Path $root '_generated\Sprint0015\StreamM\gather-calls\gather-calls.jsonl'
      New-Item -ItemType Directory -Path $blockedDirectory -Force | Out-Null

      $psfErrors = [System.Collections.Generic.List[string]]::new()
      Mock Write-PSFMessage -MockWith {
        if ($Level -eq 'Error') { $psfErrors.Add([string]$Message) }
      }

      $errorRecords = $null
      {
        Invoke-Recorder -Argument (New-RecorderArgument -WorktreePath $root) `
          -ErrorAction SilentlyContinue -ErrorVariable errorRecords
      } | Should -Not -Throw -Because 'a broken recorder must never fail the worker'

      (@($errorRecords).Count + $psfErrors.Count) |
        Should -BeGreaterThan 0 -Because 'the failure must be surfaced, not swallowed'
    }

    It 'does not leave a partially written line behind after a failed write' {
      $root = New-WorktreeFixture -Name 'writefail-partial'
      Invoke-Recorder -Argument (New-RecorderArgument -WorktreePath $root)
      $goodLineCount = (Get-RecordLine -WorktreePath $root).Count

      $file = (Get-RecordFile -WorktreePath $root)[0]
      $handle = [System.IO.File]::Open($file.FullName, 'Open', 'ReadWrite', 'None')
      try {
        Invoke-Recorder -Argument (New-RecorderArgument -WorktreePath $root) -ErrorAction SilentlyContinue
      } finally {
        $handle.Dispose()
      }

      foreach ($line in (Get-RecordLine -WorktreePath $root)) {
        { $line | ConvertFrom-Json } | Should -Not -Throw
      }
      (Get-RecordLine -WorktreePath $root).Count |
        Should -BeGreaterOrEqual $goodLineCount -Because 'an existing record is never lost by a later failure'
    }
  }

  Context 'Unavailable metadata is recorded as absent, never invented' {

    BeforeAll {
      $script:absentRoot = New-WorktreeFixture -Name 'absent'
      $argument = New-RecorderArgument -WorktreePath $script:absentRoot
      $argument.ConversationId = $null
      $argument.ConversationTitle = $null
      $argument.SessionId = $null
      $argument.TaskId = $null
      $argument.AgentModel = $null
      $argument.RepositoryName = $null
      $argument.RequestResponsePairId = $null
      Invoke-Recorder -Argument $argument
      $script:absentRecord = (Get-Record -WorktreePath $script:absentRoot)[0]
      $script:absentLine = (Get-RecordLine -WorktreePath $script:absentRoot)[0]
    }

    It 'keeps every unavailable field present and null' {
      foreach ($field in @('conversationId', 'conversationTitle', 'sessionId', 'taskId',
          'agentModel', 'repositoryName', 'requestResponsePairId')) {
        $script:absentRecord.PSObject.Properties.Name | Should -Contain $field
        $script:absentRecord.$field | Should -BeNullOrEmpty -Because "$field was unavailable and absence is recorded as absence"
      }
    }

    It 'never substitutes a placeholder string for an unavailable value' {
      foreach ($placeholder in @('"unknown"', '"n/a"', '"none"', '"null"', '""', '"undefined"', '"TBD"')) {
        $script:absentLine | Should -Not -Match ([regex]::Escape($placeholder))
      }
    }

    It 'never synthesizes requestResponsePairId from the invocationId' {
      $script:absentRecord.requestResponsePairId | Should -BeNullOrEmpty
      $script:absentRecord.requestResponsePairId | Should -Not -Be $script:absentRecord.invocationId
    }

    It 'never invents a conversation title when only an id is available' {
      $root = New-WorktreeFixture -Name 'conv-id-only'
      $argument = New-RecorderArgument -WorktreePath $root
      $argument.ConversationTitle = $null
      Invoke-Recorder -Argument $argument

      $record = (Get-Record -WorktreePath $root)[0]
      $record.conversationId | Should -Be 'conv-fixture-0001'
      $record.conversationTitle | Should -BeNullOrEmpty -Because 'the two conversation fields are independent'
    }

    It 'does not infer repositoryName from an unrecognizable worktree path' {
      $root = New-WorktreeFixture -Name 'norepo'
      $argument = New-RecorderArgument -WorktreePath $root
      $argument.RepositoryName = $null
      Invoke-Recorder -Argument $argument
      (Get-Record -WorktreePath $root)[0].repositoryName | Should -BeNullOrEmpty
    }
  }

  Context 'Redaction' {

    It 'redacts a connection string and marks the record redacted' {
      $root = New-WorktreeFixture -Name 'redact-conn'
      $argument = New-RecorderArgument -WorktreePath $root
      $argument.Prompt = 'Use Server=tcp:db01,1433;User Id=sa;Password=P@ssw0rd-FAKE-NOT-REAL; to connect.'
      Invoke-Recorder -Argument $argument

      $line = (Get-RecordLine -WorktreePath $root)[0]
      $record = $line | ConvertFrom-Json
      $line | Should -Not -Match 'P@ssw0rd-FAKE-NOT-REAL'
      $record.prompt | Should -Match '\[REDACTED:'
      $record.redacted | Should -BeTrue
      $record.redactionCount | Should -BeGreaterThan 0
    }

    It 'redacts a bearer or personal-access token' {
      $root = New-WorktreeFixture -Name 'redact-token'
      $argument = New-RecorderArgument -WorktreePath $root
      $argument.Prompt = 'Authorization: Bearer ghp_FAKE000000000000000000000000000000000000'
      Invoke-Recorder -Argument $argument

      $line = (Get-RecordLine -WorktreePath $root)[0]
      $line | Should -Not -Match 'ghp_FAKE0000'
      ($line | ConvertFrom-Json).redacted | Should -BeTrue
    }

    It 'redacts a private key body' {
      $root = New-WorktreeFixture -Name 'redact-key'
      $argument = New-RecorderArgument -WorktreePath $root
      $argument.Prompt = "-----BEGIN PRIVATE KEY-----`nFAKEKEYMATERIALNOTREAL`n-----END PRIVATE KEY-----"
      Invoke-Recorder -Argument $argument

      $line = (Get-RecordLine -WorktreePath $root)[0]
      $line | Should -Not -Match 'FAKEKEYMATERIALNOTREAL'
      ($line | ConvertFrom-Json).redacted | Should -BeTrue
    }

    It 'makes redaction visible rather than silently deleting text' {
      $root = New-WorktreeFixture -Name 'redact-visible'
      $argument = New-RecorderArgument -WorktreePath $root
      $argument.Prompt = 'prefix Password=P@ssw0rd-FAKE-NOT-REAL suffix'
      Invoke-Recorder -Argument $argument

      $record = (Get-Record -WorktreePath $root)[0]
      $record.prompt | Should -Match 'prefix'
      $record.prompt | Should -Match 'suffix'
      $record.prompt | Should -Match '\[REDACTED:(secret|connection-string|token|key|credential)\]'
    }

    It 'permits a SecretName while forbidding a secret value' {
      $root = New-WorktreeFixture -Name 'redact-secretname'
      $argument = New-RecorderArgument -WorktreePath $root
      $argument.Prompt = 'Resolve Windows.Remoting.Credential.UTAT01 through Get-SecretATAP.'
      Invoke-Recorder -Argument $argument

      $record = (Get-Record -WorktreePath $root)[0]
      $record.prompt | Should -Match 'Windows\.Remoting\.Credential\.UTAT01'
      $record.redacted | Should -BeFalse
      $record.redactionCount | Should -Be 0
    }

    It 'leaves a clean prompt unmodified and unflagged' {
      $root = New-WorktreeFixture -Name 'redact-clean'
      Invoke-Recorder -Argument (New-RecorderArgument -WorktreePath $root)
      $record = (Get-Record -WorktreePath $root)[0]
      $record.prompt | Should -Be 'Context for the gather-call recorder regression suite.'
      $record.redacted | Should -BeFalse
      $record.redactionCount | Should -Be 0
    }

    It 'redacts an error message as well as a prompt' {
      $root = New-WorktreeFixture -Name 'redact-error'
      $argument = New-RecorderArgument -WorktreePath $root
      $envelope = New-OkEnvelope
      $envelope.error = 'login failed for Password=P@ssw0rd-FAKE-NOT-REAL'
      $argument.Response = $envelope
      Invoke-Recorder -Argument $argument

      (Get-RecordLine -WorktreePath $root)[0] | Should -Not -Match 'P@ssw0rd-FAKE-NOT-REAL'
    }
  }

  Context 'Response digest only - the returned content is never persisted' {

    BeforeAll {
      $script:digestRoot = New-WorktreeFixture -Name 'digest'
      $argument = New-RecorderArgument -WorktreePath $script:digestRoot
      $argument.Response = New-OkEnvelope -Items @(
        [pscustomobject]@{
          path      = 'src/Example.ps1'
          kind      = 'code'
          component = 'Example'
          owner     = 'team'
          summary   = 'UNIQUE-RETRIEVED-BODY-TEXT-THAT-MUST-NOT-BE-PERSISTED'
          freshness = [pscustomobject]@{ asOf = '2026-08-25'; stale = $false }
        }
      )
      Invoke-Recorder -Argument $argument
      $script:digestLine = (Get-RecordLine -WorktreePath $script:digestRoot)[0]
      $script:digestRecord = $script:digestLine | ConvertFrom-Json
    }

    It 'does not persist any retrieved item body' {
      $script:digestLine | Should -Not -Match 'UNIQUE-RETRIEVED-BODY-TEXT-THAT-MUST-NOT-BE-PERSISTED'
      $script:digestLine | Should -Not -Match 'src/Example\.ps1'
    }

    It 'carries no items array on the record' {
      $script:digestRecord.PSObject.Properties.Name | Should -Not -Contain 'items'
    }

    It 'records only the count of returned items' {
      $script:digestRecord.itemCount | Should -Be 1
    }

    It 'names the digest algorithm, encoding, canonicalization, and input explicitly' {
      $digest = $script:digestRecord.responseDigest
      $digest.algorithm | Should -Be 'SHA-256'
      $digest.encoding | Should -Be 'base16-lower'
      $digest.canonicalization | Should -Be 'rfc8785-jcs'
      $digest.input | Should -Be 'items'
      $digest.value | Should -Match '^[0-9a-f]{64}$'
    }

    It 'produces the known constant digest for an empty items array' {
      $root = New-WorktreeFixture -Name 'digest-empty'
      $argument = New-RecorderArgument -WorktreePath $root
      $argument.Response = New-OkEnvelope
      Invoke-Recorder -Argument $argument
      (Get-Record -WorktreePath $root)[0].responseDigest.value | Should -Be $script:EmptyItemsDigest
    }

    It 'is insensitive to key ordering in the returned items' {
      $rootA = New-WorktreeFixture -Name 'digest-order-a'
      $argumentA = New-RecorderArgument -WorktreePath $rootA
      $argumentA.Response = New-OkEnvelope -Items @([pscustomobject][ordered]@{ path = 'a'; kind = 'code' })
      Invoke-Recorder -Argument $argumentA

      $rootB = New-WorktreeFixture -Name 'digest-order-b'
      $argumentB = New-RecorderArgument -WorktreePath $rootB
      $argumentB.Response = New-OkEnvelope -Items @([pscustomobject][ordered]@{ kind = 'code'; path = 'a' })
      Invoke-Recorder -Argument $argumentB

      (Get-Record -WorktreePath $rootA)[0].responseDigest.value |
        Should -Be (Get-Record -WorktreePath $rootB)[0].responseDigest.value
    }

    It 'computes the digest after redaction so it never reconstructs redacted material' {
      $root = New-WorktreeFixture -Name 'digest-after-redaction'
      $argument = New-RecorderArgument -WorktreePath $root
      $argument.Prompt = 'Password=P@ssw0rd-FAKE-NOT-REAL'
      Invoke-Recorder -Argument $argument
      $line = (Get-RecordLine -WorktreePath $root)[0]
      $line | Should -Not -Match 'P@ssw0rd-FAKE-NOT-REAL'
    }
  }

  Context 'Path discipline' {

    It 'records the worktree root as an absolute forward-slash path with no trailing slash' {
      $root = New-WorktreeFixture -Name 'paths'
      Invoke-Recorder -Argument (New-RecorderArgument -WorktreePath $root)
      $record = (Get-Record -WorktreePath $root)[0]
      $record.worktreePath | Should -Not -Match '\\'
      $record.worktreePath | Should -Not -Match '/$'
      $record.worktreePath | Should -Match '^[A-Za-z]:/'
    }

    It 'carries no absolute path in any field other than worktreePath' {
      $root = New-WorktreeFixture -Name 'paths-relative'
      $argument = New-RecorderArgument -WorktreePath $root
      $argument.Prompt = 'A prompt with no path in it at all.'
      Invoke-Recorder -Argument $argument

      $record = (Get-Record -WorktreePath $root)[0]
      $withoutWorktree = $record | Select-Object -Property * -ExcludeProperty 'worktreePath'
      ($withoutWorktree | ConvertTo-Json -Depth 10 -Compress) |
        Should -Not -Match '[A-Za-z]:[\\/]' -Because 'a repository-relative identity suffices everywhere else'
    }
  }

  Context 'Malformed input is rejected' {

    It 'rejects an empty tag set' {
      $root = New-WorktreeFixture -Name 'bad-tags'
      $argument = New-RecorderArgument -WorktreePath $root
      $argument.Tags = @()
      { Invoke-Recorder -Argument $argument } | Should -Throw
      (Get-RecordLine -WorktreePath $root).Count | Should -Be 0
    }

    It 'rejects a tag set that normalizes to empty' {
      $root = New-WorktreeFixture -Name 'bad-tags-blank'
      $argument = New-RecorderArgument -WorktreePath $root
      $argument.Tags = @('   ', '')
      { Invoke-Recorder -Argument $argument } | Should -Throw
      (Get-RecordLine -WorktreePath $root).Count | Should -Be 0
    }

    It 'rejects a non-positive depth' {
      $root = New-WorktreeFixture -Name 'bad-depth'
      $argument = New-RecorderArgument -WorktreePath $root
      $argument.Depth = 0
      { Invoke-Recorder -Argument $argument } | Should -Throw
      (Get-RecordLine -WorktreePath $root).Count | Should -Be 0
    }

    It 'rejects a non-positive width' {
      $root = New-WorktreeFixture -Name 'bad-width'
      $argument = New-RecorderArgument -WorktreePath $root
      $argument.Width = -1
      { Invoke-Recorder -Argument $argument } | Should -Throw
      (Get-RecordLine -WorktreePath $root).Count | Should -Be 0
    }

    It 'rejects an empty agent name' {
      $root = New-WorktreeFixture -Name 'bad-agent'
      $argument = New-RecorderArgument -WorktreePath $root
      $argument.AgentName = ''
      { Invoke-Recorder -Argument $argument } | Should -Throw
      (Get-RecordLine -WorktreePath $root).Count | Should -Be 0
    }

    It 'rejects an empty instance' {
      $root = New-WorktreeFixture -Name 'bad-instance'
      $argument = New-RecorderArgument -WorktreePath $root
      $argument.Instance = ''
      { Invoke-Recorder -Argument $argument } | Should -Throw
      (Get-RecordLine -WorktreePath $root).Count | Should -Be 0
    }

    It 'rejects a task id that does not match the board pattern' {
      $root = New-WorktreeFixture -Name 'bad-taskid'
      $argument = New-RecorderArgument -WorktreePath $root
      $argument.TaskId = 'not a task id'
      { Invoke-Recorder -Argument $argument } | Should -Throw
      (Get-RecordLine -WorktreePath $root).Count | Should -Be 0
    }
  }

  Context 'ShouldProcess' {

    It 'writes nothing under -WhatIf' {
      $root = New-WorktreeFixture -Name 'whatif'
      $argument = New-RecorderArgument -WorktreePath $root
      $argument['WhatIf'] = $true
      Invoke-Recorder -Argument $argument
      (Get-RecordLine -WorktreePath $root).Count | Should -Be 0
    }
  }
}
