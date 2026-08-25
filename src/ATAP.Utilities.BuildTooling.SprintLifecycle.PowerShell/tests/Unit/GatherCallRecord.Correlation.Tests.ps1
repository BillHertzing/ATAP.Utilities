#Requires -Version 7.0

<#
  Regression suite for the gather-call / changed-file correlation harvester
  (Sprint 0015, Stream M, Task 15.183.b).

  SKIP STATE
  ----------
  The harvester is Task 15.183.c and does not exist yet. Every block below is
  written in full against the ratified contracts and is marked -Skip so the suite
  stays green until .c lands. Un-skipping is a ONE-LINE change: delete the -Skip
  switch on the single Describe below. Nothing else in this file is a placeholder.

  Blocking task id: 15.183.c

  Authority (all in
  _Planning/InformationForTheFuture/Sprint0015/StreamM/Task15.183/):
    correlated-corpus.contract.v1.md            - keys, precedence, statuses,
                                                  ordering, idempotence, reconciliation
    gather-call-record.contract.v1.md           - the input record stream
    worker-handoff-changed-file.contract.v1.md  - changed-file normalization
    file-association-method.v1.md               - association method and status vocabulary

  SEAM: the harvester's command name and parameter names are owned by Task
  15.183.c and are NOT ratified. They are declared once, below, so that
  reconciling this suite with .c's actual surface is a single edit rather than a
  rewrite. This is recorded as a coverage finding in the handoff for 15.183.b.

  Isolation: every fixture is created beneath $TestDrive. No test reads or writes
  a real worktree, a real _generated tree, git, a database, or the network.
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

  # ---- SEAM (owned by Task 15.183.c, unratified) -------------------------
  $script:HarvesterCommandName = 'Invoke-GatherCallCorrelation'
  $script:HarvesterFileName = 'Invoke-GatherCallCorrelation.ps1'
  # ------------------------------------------------------------------------

  $script:moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $script:harvesterPath = Join-Path $script:moduleRoot ('public\' + $script:HarvesterFileName)
  if (Test-Path -LiteralPath $script:harvesterPath -PathType Leaf) {
    . $script:harvesterPath
  }

  $script:fixtureRoot = Join-Path $TestDrive 'gather-correlation'
  New-Item -ItemType Directory -Path $script:fixtureRoot -Force | Out-Null

  $script:CorrelationStatusRank = @(
    'matched', 'no-changed-files', 'ambiguous-match', 'duplicate-gather-record',
    'unmatched-gather-call', 'unassociated-file', 'malformed-input'
  )

  function New-CorrelationFixture {
    param([string]$Name)
    $root = Join-Path $script:fixtureRoot ($Name + '-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    [pscustomobject]@{
      Root       = $root
      Worktrees  = (New-Item -ItemType Directory -Path (Join-Path $root 'worktrees') -Force).FullName
      Durable    = (New-Item -ItemType Directory -Path (Join-Path $root 'durable') -Force).FullName
      Evidence   = (New-Item -ItemType Directory -Path (Join-Path $root 'evidence') -Force).FullName
    }
  }

  function New-FixtureWorktree {
    param(
      [Parameter(Mandatory)]$Fixture,
      [Parameter(Mandatory)][string]$RepositoryName,
      [string]$Sprint = 'Sprint0015'
    )
    $path = Join-Path $Fixture.Worktrees $RepositoryName
    New-Item -ItemType Directory -Path (Join-Path $path "_generated\$Sprint\StreamM\gather-calls") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $path "_generated\$Sprint\handoffs") -Force | Out-Null
    $path
  }

  function New-GatherRecord {
    param(
      [string]$InvocationId = ([guid]::NewGuid().ToString()),
      [string]$SessionId = 'sess-001',
      [object]$RequestResponsePairId = $null,
      [int]$Ordinal = 1,
      [string]$OrdinalScope = 'session',
      [string]$TaskId = '15.183.b',
      [string]$WorktreePath = 'C:/fixture/Repo',
      [string]$RepositoryName = 'ATAP.Utilities',
      [string[]]$Tags = @('handoff'),
      [string]$Outcome = 'stubbed',
      [string]$TimestampUtc = '2026-08-25T15:14:10.482Z'
    )
    [ordered]@{
      recordVersion          = '1.0.0'
      invocationId           = $InvocationId
      requestResponsePairId  = $RequestResponsePairId
      ordinal                = $Ordinal
      ordinalScope           = $OrdinalScope
      timestampUtc           = $TimestampUtc
      agentName              = 'junior-dev-coder-jm'
      agentModel             = $null
      sessionId              = $SessionId
      taskId                 = $TaskId
      worktreePath           = $WorktreePath
      repositoryName         = $RepositoryName
      conversationId         = $null
      conversationTitle      = $null
      tags                   = $Tags
      tagsRaw                = $Tags
      depth                  = 3
      width                  = 2
      instance               = 'production'
      prompt                 = 'fixture prompt'
      outcome                = $Outcome
      responseStatus         = 'NotImplemented'
      stubMarker             = 'CONTENT_SUMMARY_RETRIEVAL_NOT_IMPLEMENTED'
      stubBlockedBy          = @('RDB-190')
      itemCount              = 0
      truncated              = $false
      errorMessage           = $null
      responseDigest         = [ordered]@{
        algorithm        = 'SHA-256'
        encoding         = 'base16-lower'
        value            = '4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945'
        canonicalization = 'rfc8785-jcs'
        input            = 'items'
      }
      redacted               = $false
      redactionCount         = 0
      retryOfInvocationId    = $null
      supersedesInvocationId = $null
    }
  }

  function Add-GatherRecord {
    param(
      [Parameter(Mandatory)][string]$WorktreePath,
      [Parameter(Mandatory)][object[]]$Record,
      [string]$Sprint = 'Sprint0015',
      [string]$FileName = 'gather-calls.jsonl'
    )
    $directory = Join-Path $WorktreePath "_generated\$Sprint\StreamM\gather-calls"
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    $target = Join-Path $directory $FileName
    $builder = [System.Text.StringBuilder]::new()
    foreach ($entry in $Record) {
      if ($entry -is [string]) {
        [void]$builder.Append($entry).Append("`n")
      } else {
        [void]$builder.Append(($entry | ConvertTo-Json -Depth 10 -Compress)).Append("`n")
      }
    }
    $existing = if (Test-Path -LiteralPath $target) { [System.IO.File]::ReadAllText($target) } else { '' }
    [System.IO.File]::WriteAllText($target, $existing + $builder.ToString(),
      [System.Text.UTF8Encoding]::new($false))
    $target
  }

  function Add-Handoff {
    param(
      [Parameter(Mandatory)][string]$WorktreePath,
      [Parameter(Mandatory)][string]$Name,
      [string]$TaskId = '15.183.b',
      [string]$Agent = 'junior-dev-coder-jm',
      [object]$SessionId = 'sess-001',
      [object]$GatherCalls = $null,
      [object]$ChangedFiles = $null,
      [switch]$OmitChangedFiles,
      [string]$Sprint = 'Sprint0015',
      [string]$RawJson
    )
    $directory = Join-Path $WorktreePath "_generated\$Sprint\handoffs"
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    $target = Join-Path $directory $Name

    if ($PSBoundParameters.ContainsKey('RawJson')) {
      [System.IO.File]::WriteAllText($target, $RawJson, [System.Text.UTF8Encoding]::new($false))
      return $target
    }

    $handoff = [ordered]@{
      schemaVersion       = '1.1.0'
      taskId              = $TaskId
      agent               = $Agent
      completedOn         = '2026-08-25T16:00:00Z'
      commands            = @()
      evidencePath        = "_generated/$Sprint/StreamM/evidence"
      verified            = @()
      asserted            = @()
      stubbedDependencies = @()
      claimRelease        = [ordered]@{ claimId = 'claim-001'; released = $true }
    }
    if ($null -ne $SessionId) { $handoff['sessionId'] = $SessionId }
    if ($null -ne $GatherCalls) { $handoff['gatherCalls'] = @($GatherCalls) }
    if (-not $OmitChangedFiles) {
      $handoff['changedFiles'] = @(if ($null -ne $ChangedFiles) { $ChangedFiles } else { @() })
    }

    [System.IO.File]::WriteAllText($target,
      ($handoff | ConvertTo-Json -Depth 10), [System.Text.UTF8Encoding]::new($false))
    $target
  }

  function Invoke-Harvester {
    param(
      [Parameter(Mandatory)]$Fixture,
      [string[]]$WorktreeRoot,
      [string]$Sprint = 'Sprint0015',
      [hashtable]$Extra
    )
    $command = Get-Command -Name $script:HarvesterCommandName -ErrorAction Stop
    $declared = $command.Parameters.Keys

    $argument = @{
      WorktreeRoot      = @($WorktreeRoot)
      Sprint            = $Sprint
      DurableOutputPath = (Join-Path $Fixture.Durable 'correlated-corpus.v1.json')
      EvidencePath      = $Fixture.Evidence
    }
    if ($Extra) { foreach ($key in $Extra.Keys) { $argument[$key] = $Extra[$key] } }

    $splat = @{}
    foreach ($key in $argument.Keys) {
      if ($declared -contains $key) { $splat[$key] = $argument[$key] }
    }
    & $script:HarvesterCommandName @splat
  }

  function Get-Corpus {
    param([Parameter(Mandatory)]$Fixture)
    $path = Join-Path $Fixture.Durable 'correlated-corpus.v1.json'
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    [System.IO.File]::ReadAllText($path) | ConvertFrom-Json
  }

  function Get-CorpusText {
    param([Parameter(Mandatory)]$Fixture)
    [System.IO.File]::ReadAllText((Join-Path $Fixture.Durable 'correlated-corpus.v1.json'))
  }
}

AfterAll {
  if ($script:fixtureRoot -and (Test-Path -LiteralPath $script:fixtureRoot)) {
    Remove-Item -LiteralPath $script:fixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}

# Remove -Skip on the line below when Task 15.183.c lands the harvester.
Describe 'Gather-call correlation harvester [Blocked by Task 15.183.c - harvester not yet implemented]' -Tag 'Unit', 'Blocked-15.183.c' -Skip {

  Context 'Command surface' {

    It 'ships a harvester implementation in public/' {
      Test-Path -LiteralPath $script:harvesterPath -PathType Leaf | Should -BeTrue
    }

    It 'defines the harvester as an advanced function' {
      $command = Get-Command -Name $script:HarvesterCommandName -CommandType Function
      $command | Should -Not -BeNullOrEmpty
      $command.CmdletBinding | Should -BeTrue
    }

    It 'accepts resolved worktree roots and a durable output path' {
      $command = Get-Command -Name $script:HarvesterCommandName -CommandType Function
      $command.Parameters.Keys | Should -Contain 'WorktreeRoot'
      $command.Parameters.Keys | Should -Contain 'DurableOutputPath'
    }
  }

  Context 'Discovery - worktree count' {

    It 'produces a valid empty corpus when given zero worktrees' {
      $fixture = New-CorrelationFixture -Name 'discover-zero'
      Invoke-Harvester -Fixture $fixture -WorktreeRoot @()

      $corpus = Get-Corpus -Fixture $fixture
      $corpus | Should -Not -BeNullOrEmpty
      $corpus.corpusVersion | Should -Be '1.0.0'
      $corpus.reconciliation.gatherRecordsRead | Should -Be 0
      $corpus.reconciliation.handoffsRead | Should -Be 0
      $corpus.reconciliation.rowCount | Should -Be 0
      $corpus.reconciliation.balanced | Should -BeTrue
      @($corpus.rows).Count | Should -Be 0
    }

    It 'discovers records in a single worktree' {
      $fixture = New-CorrelationFixture -Name 'discover-one'
      $worktree = New-FixtureWorktree -Fixture $fixture -RepositoryName 'ATAP.Utilities'
      Add-GatherRecord -WorktreePath $worktree -Record @((New-GatherRecord)) | Out-Null
      Invoke-Harvester -Fixture $fixture -WorktreeRoot @($worktree)

      (Get-Corpus -Fixture $fixture).reconciliation.gatherRecordsRead | Should -Be 1
    }

    It 'merges records across many worktrees without collision' {
      $fixture = New-CorrelationFixture -Name 'discover-many'
      $roots = foreach ($repository in @('ATAP.Utilities', 'Ace', 'SharedVSCode', '_Planning')) {
        $worktree = New-FixtureWorktree -Fixture $fixture -RepositoryName $repository
        Add-GatherRecord -WorktreePath $worktree `
          -Record @((New-GatherRecord -SessionId "sess-$repository" -RepositoryName $repository)) | Out-Null
        $worktree
      }
      Invoke-Harvester -Fixture $fixture -WorktreeRoot @($roots)

      $corpus = Get-Corpus -Fixture $fixture
      $corpus.reconciliation.gatherRecordsRead | Should -Be 4
      @($corpus.rows.invocationId | Sort-Object -Unique).Count | Should -Be 4
    }

    It 'distinguishes a missing gather-calls directory from an empty one' {
      $fixture = New-CorrelationFixture -Name 'discover-absent'
      $withDirectory = New-FixtureWorktree -Fixture $fixture -RepositoryName 'WithDir'
      $withoutDirectory = Join-Path $fixture.Worktrees 'WithoutDir'
      New-Item -ItemType Directory -Path $withoutDirectory -Force | Out-Null

      $result = Invoke-Harvester -Fixture $fixture -WorktreeRoot @($withDirectory, $withoutDirectory)

      $present = @($result.WorktreeReport | Where-Object { $_.WorktreeRoot -eq $withDirectory })
      $missing = @($result.WorktreeReport | Where-Object { $_.WorktreeRoot -eq $withoutDirectory })
      $present[0].GatherCallRecordsPresent | Should -BeTrue
      $present[0].RecordCount | Should -Be 0
      $missing[0].GatherCallRecordsPresent | Should -BeFalse
    }

    It 'treats every jsonl file under gather-calls as one logical stream' {
      $fixture = New-CorrelationFixture -Name 'discover-sharded'
      $worktree = New-FixtureWorktree -Fixture $fixture -RepositoryName 'ATAP.Utilities'
      Add-GatherRecord -WorktreePath $worktree -FileName 'sess-a.jsonl' `
        -Record @((New-GatherRecord -SessionId 'sess-a')) | Out-Null
      Add-GatherRecord -WorktreePath $worktree -FileName 'sess-b.jsonl' `
        -Record @((New-GatherRecord -SessionId 'sess-b')) | Out-Null
      Add-GatherRecord -WorktreePath $worktree -FileName '_nosession-1234.jsonl' `
        -Record @((New-GatherRecord -SessionId $null -OrdinalScope 'file')) | Out-Null

      Invoke-Harvester -Fixture $fixture -WorktreeRoot @($worktree)
      (Get-Corpus -Fixture $fixture).reconciliation.gatherRecordsRead | Should -Be 3
    }
  }

  Context 'Discovery - record count' {

    It 'emits only file-only rows when there are zero gather records' {
      $fixture = New-CorrelationFixture -Name 'records-zero'
      $worktree = New-FixtureWorktree -Fixture $fixture -RepositoryName 'ATAP.Utilities'
      Add-Handoff -WorktreePath $worktree -Name 'h1.json' -ChangedFiles @(
        [ordered]@{ path = 'src/A.ps1'; change = 'modified' }
      ) | Out-Null

      Invoke-Harvester -Fixture $fixture -WorktreeRoot @($worktree)

      $corpus = Get-Corpus -Fixture $fixture
      $corpus.reconciliation.gatherRecordsRead | Should -Be 0
      @($corpus.rows).Count | Should -Be 1
      $corpus.rows[0].correlationStatus | Should -Be 'unassociated-file'
      $corpus.rows[0].matchedBy | Should -Be 'unmatched'
      $corpus.rows[0].invocationId | Should -BeNullOrEmpty
      $corpus.rows[0].tag | Should -BeNullOrEmpty
    }

    It 'fans a single record out to one row per tag per file' {
      $fixture = New-CorrelationFixture -Name 'records-fanout'
      $worktree = New-FixtureWorktree -Fixture $fixture -RepositoryName 'ATAP.Utilities'
      $record = New-GatherRecord -Tags @('alpha', 'beta', 'gamma')
      Add-GatherRecord -WorktreePath $worktree -Record @($record) | Out-Null
      Add-Handoff -WorktreePath $worktree -Name 'h1.json' `
        -GatherCalls @($record.invocationId) `
        -ChangedFiles @(
        [ordered]@{ path = 'src/A.ps1'; change = 'modified' },
        [ordered]@{ path = 'src/B.ps1'; change = 'created' }
      ) | Out-Null

      Invoke-Harvester -Fixture $fixture -WorktreeRoot @($worktree)

      $rows = @((Get-Corpus -Fixture $fixture).rows)
      $rows.Count | Should -Be 6 -Because '3 tags x 2 files'
      foreach ($row in $rows) {
        $row.tagCount | Should -Be 3
        $row.tagIndex | Should -BeGreaterOrEqual 0
        $row.tagIndex | Should -BeLessThan 3
      }
      , @($rows.tag | Sort-Object -Unique) | Should -Be @('alpha', 'beta', 'gamma')
    }

    It 'reads many records without dropping any' {
      $fixture = New-CorrelationFixture -Name 'records-many'
      $worktree = New-FixtureWorktree -Fixture $fixture -RepositoryName 'ATAP.Utilities'
      $records = 1..25 | ForEach-Object { New-GatherRecord -Ordinal $_ }
      Add-GatherRecord -WorktreePath $worktree -Record $records | Out-Null

      Invoke-Harvester -Fixture $fixture -WorktreeRoot @($worktree)

      $corpus = Get-Corpus -Fixture $fixture
      $corpus.reconciliation.gatherRecordsRead | Should -Be 25
      $corpus.reconciliation.balanced | Should -BeTrue
    }
  }

  Context 'Correlation precedence' {

    It 'matches on exact invocationId at rank 1' {
      $fixture = New-CorrelationFixture -Name 'match-exact'
      $worktree = New-FixtureWorktree -Fixture $fixture -RepositoryName 'ATAP.Utilities'
      $record = New-GatherRecord
      Add-GatherRecord -WorktreePath $worktree -Record @($record) | Out-Null
      Add-Handoff -WorktreePath $worktree -Name 'h1.json' `
        -GatherCalls @($record.invocationId) `
        -ChangedFiles @([ordered]@{ path = 'src/A.ps1'; change = 'modified' }) | Out-Null

      Invoke-Harvester -Fixture $fixture -WorktreeRoot @($worktree)

      $rows = @((Get-Corpus -Fixture $fixture).rows)
      $rows.Count | Should -Be 1
      $rows[0].matchedBy | Should -Be 'invocation-id'
      $rows[0].correlationStatus | Should -Be 'matched'
      $rows[0].changedFilePath | Should -Be 'src/A.ps1'
    }

    It 'matches on request/response pair id at rank 2 when the session agrees' {
      $fixture = New-CorrelationFixture -Name 'match-pair'
      $worktree = New-FixtureWorktree -Fixture $fixture -RepositoryName 'ATAP.Utilities'
      $record = New-GatherRecord -RequestResponsePairId 'pair-77' -SessionId 'sess-p'
      Add-GatherRecord -WorktreePath $worktree -Record @($record) | Out-Null
      Add-Handoff -WorktreePath $worktree -Name 'h1.json' -SessionId 'sess-p' `
        -GatherCalls @([ordered]@{ requestResponsePairId = 'pair-77' }) `
        -ChangedFiles @([ordered]@{ path = 'src/A.ps1'; change = 'modified' }) | Out-Null

      Invoke-Harvester -Fixture $fixture -WorktreeRoot @($worktree)
      (Get-Corpus -Fixture $fixture).rows[0].matchedBy | Should -Be 'pair-id'
    }

    It 'falls back to the ordinal key at rank 3' {
      $fixture = New-CorrelationFixture -Name 'match-ordinal'
      $worktree = New-FixtureWorktree -Fixture $fixture -RepositoryName 'ATAP.Utilities'
      $record = New-GatherRecord -SessionId 'sess-o' -Ordinal 2 -OrdinalScope 'session'
      Add-GatherRecord -WorktreePath $worktree -Record @($record) | Out-Null
      Add-Handoff -WorktreePath $worktree -Name 'h1.json' -SessionId 'sess-o' `
        -GatherCalls @([ordered]@{ ordinal = 2 }) `
        -ChangedFiles @([ordered]@{ path = 'src/A.ps1'; change = 'modified' }) | Out-Null

      Invoke-Harvester -Fixture $fixture -WorktreeRoot @($worktree)
      (Get-Corpus -Fixture $fixture).rows[0].matchedBy | Should -Be 'ordinal'
    }

    It 'stops at the first rule that matches and does not attempt a weaker key' {
      $fixture = New-CorrelationFixture -Name 'match-precedence'
      $worktree = New-FixtureWorktree -Fixture $fixture -RepositoryName 'ATAP.Utilities'
      $record = New-GatherRecord -RequestResponsePairId 'pair-9' -SessionId 'sess-x' -Ordinal 1
      Add-GatherRecord -WorktreePath $worktree -Record @($record) | Out-Null
      Add-Handoff -WorktreePath $worktree -Name 'h1.json' -SessionId 'sess-x' `
        -GatherCalls @($record.invocationId, [ordered]@{ requestResponsePairId = 'pair-9'; ordinal = 1 }) `
        -ChangedFiles @([ordered]@{ path = 'src/A.ps1'; change = 'modified' }) | Out-Null

      Invoke-Harvester -Fixture $fixture -WorktreeRoot @($worktree)
      (Get-Corpus -Fixture $fixture).rows[0].matchedBy |
        Should -Be 'invocation-id' -Because 'the strongest satisfied rank wins outright'
    }

    It 'disqualifies rank 2 when either side has a null session rather than wildcarding' {
      $fixture = New-CorrelationFixture -Name 'match-nullsession'
      $worktree = New-FixtureWorktree -Fixture $fixture -RepositoryName 'ATAP.Utilities'
      $record = New-GatherRecord -RequestResponsePairId 'pair-77' -SessionId $null -OrdinalScope 'file'
      Add-GatherRecord -WorktreePath $worktree -Record @($record) | Out-Null
      Add-Handoff -WorktreePath $worktree -Name 'h1.json' -SessionId $null `
        -GatherCalls @([ordered]@{ requestResponsePairId = 'pair-77' }) `
        -ChangedFiles @([ordered]@{ path = 'src/A.ps1'; change = 'modified' }) | Out-Null

      Invoke-Harvester -Fixture $fixture -WorktreeRoot @($worktree)

      $rows = @((Get-Corpus -Fixture $fixture).rows)
      @($rows | Where-Object { $_.matchedBy -eq 'pair-id' }).Count | Should -Be 0
      @($rows | Where-Object { $_.correlationStatus -eq 'unmatched-gather-call' }).Count | Should -BeGreaterThan 0
    }

    It 'disqualifies rank 3 when the record ordinal is file-scoped' {
      $fixture = New-CorrelationFixture -Name 'match-filescope'
      $worktree = New-FixtureWorktree -Fixture $fixture -RepositoryName 'ATAP.Utilities'
      $record = New-GatherRecord -SessionId 'sess-f' -Ordinal 1 -OrdinalScope 'file'
      Add-GatherRecord -WorktreePath $worktree -Record @($record) | Out-Null
      Add-Handoff -WorktreePath $worktree -Name 'h1.json' -SessionId 'sess-f' `
        -GatherCalls @([ordered]@{ ordinal = 1 }) `
        -ChangedFiles @([ordered]@{ path = 'src/A.ps1'; change = 'modified' }) | Out-Null

      Invoke-Harvester -Fixture $fixture -WorktreeRoot @($worktree)
      @((Get-Corpus -Fixture $fixture).rows | Where-Object { $_.matchedBy -eq 'ordinal' }).Count |
        Should -Be 0 -Because 'a file-scoped ordinal is not comparable to a session-scoped one'
    }

    It 'never applies a temporal-proximity or same-task heuristic' {
      $fixture = New-CorrelationFixture -Name 'match-notemporal'
      $worktree = New-FixtureWorktree -Fixture $fixture -RepositoryName 'ATAP.Utilities'
      Add-GatherRecord -WorktreePath $worktree -Record @(
        (New-GatherRecord -SessionId 'sess-a' -TaskId '15.183.b' -TimestampUtc '2026-08-25T16:00:00.000Z')
      ) | Out-Null
      Add-Handoff -WorktreePath $worktree -Name 'h1.json' -SessionId 'sess-b' -TaskId '15.183.b' `
        -ChangedFiles @([ordered]@{ path = 'src/A.ps1'; change = 'modified' }) | Out-Null

      Invoke-Harvester -Fixture $fixture -WorktreeRoot @($worktree)

      $rows = @((Get-Corpus -Fixture $fixture).rows)
      @($rows | Where-Object { $_.correlationStatus -eq 'matched' }).Count |
        Should -Be 0 -Because 'a shared taskId and a close timestamp are not correlation keys'
      @($rows | Where-Object { $_.correlationStatus -eq 'unmatched-gather-call' }).Count | Should -Be 1
      @($rows | Where-Object { $_.correlationStatus -eq 'unassociated-file' }).Count | Should -Be 1
    }
  }

  Context 'Unmatched, ambiguous, and duplicate outcomes' {

    It 'emits a gather-side row with a wholly null file side when nothing matches' {
      $fixture = New-CorrelationFixture -Name 'outcome-unmatched'
      $worktree = New-FixtureWorktree -Fixture $fixture -RepositoryName 'ATAP.Utilities'
      Add-GatherRecord -WorktreePath $worktree -Record @((New-GatherRecord)) | Out-Null

      Invoke-Harvester -Fixture $fixture -WorktreeRoot @($worktree)

      $row = (Get-Corpus -Fixture $fixture).rows[0]
      $row.correlationStatus | Should -Be 'unmatched-gather-call'
      $row.matchedBy | Should -Be 'unmatched'
      $row.changedFilePath | Should -BeNullOrEmpty
      $row.sourceHandoffPath | Should -BeNullOrEmpty
      $row.invocationId | Should -Not -BeNullOrEmpty
    }

    It 'reports ambiguity with every candidate rather than picking a winner' {
      $fixture = New-CorrelationFixture -Name 'outcome-ambiguous'
      $worktree = New-FixtureWorktree -Fixture $fixture -RepositoryName 'ATAP.Utilities'
      $record = New-GatherRecord -SessionId 'sess-amb' -Ordinal 1
      Add-GatherRecord -WorktreePath $worktree -Record @($record) | Out-Null
      Add-Handoff -WorktreePath $worktree -Name 'h1.json' -SessionId 'sess-amb' -TaskId '15.183.b' `
        -GatherCalls @([ordered]@{ ordinal = 1 }) `
        -ChangedFiles @([ordered]@{ path = 'src/A.ps1'; change = 'modified' }) | Out-Null
      Add-Handoff -WorktreePath $worktree -Name 'h2.json' -SessionId 'sess-amb' -TaskId '15.183.c' `
        -GatherCalls @([ordered]@{ ordinal = 1 }) `
        -ChangedFiles @([ordered]@{ path = 'src/B.ps1'; change = 'modified' }) | Out-Null

      Invoke-Harvester -Fixture $fixture -WorktreeRoot @($worktree)

      $ambiguous = @((Get-Corpus -Fixture $fixture).rows |
          Where-Object { $_.correlationStatus -eq 'ambiguous-match' })
      $ambiguous.Count | Should -BeGreaterThan 0
      $ambiguous[0].changedFilePath | Should -BeNullOrEmpty
      @($ambiguous[0].notes).Count | Should -BeGreaterOrEqual 2
      ($ambiguous[0].notes -join ' ') | Should -Match 'h1\.json'
      ($ambiguous[0].notes -join ' ') | Should -Match 'h2\.json'
    }

    It 'does not escape an ambiguity by falling to a weaker key' {
      $fixture = New-CorrelationFixture -Name 'outcome-ambiguous-noescape'
      $worktree = New-FixtureWorktree -Fixture $fixture -RepositoryName 'ATAP.Utilities'
      $record = New-GatherRecord -RequestResponsePairId 'pair-dup' -SessionId 'sess-amb2' -Ordinal 1
      Add-GatherRecord -WorktreePath $worktree -Record @($record) | Out-Null
      Add-Handoff -WorktreePath $worktree -Name 'h1.json' -SessionId 'sess-amb2' `
        -GatherCalls @([ordered]@{ requestResponsePairId = 'pair-dup' }) `
        -ChangedFiles @([ordered]@{ path = 'src/A.ps1'; change = 'modified' }) | Out-Null
      Add-Handoff -WorktreePath $worktree -Name 'h2.json' -SessionId 'sess-amb2' `
        -GatherCalls @([ordered]@{ requestResponsePairId = 'pair-dup'; ordinal = 99 }) `
        -ChangedFiles @([ordered]@{ path = 'src/B.ps1'; change = 'modified' }) | Out-Null

      Invoke-Harvester -Fixture $fixture -WorktreeRoot @($worktree)

      $rows = @((Get-Corpus -Fixture $fixture).rows)
      @($rows | Where-Object { $_.matchedBy -eq 'ordinal' }).Count | Should -Be 0
      @($rows | Where-Object { $_.correlationStatus -eq 'ambiguous-match' }).Count | Should -BeGreaterThan 0
    }

    It 'retains and flags both records of a duplicate invocationId' {
      $fixture = New-CorrelationFixture -Name 'outcome-duplicate'
      $worktree = New-FixtureWorktree -Fixture $fixture -RepositoryName 'ATAP.Utilities'
      $shared = [guid]::NewGuid().ToString()
      Add-GatherRecord -WorktreePath $worktree -Record @(
        (New-GatherRecord -InvocationId $shared -Ordinal 1),
        (New-GatherRecord -InvocationId $shared -Ordinal 2)
      ) | Out-Null

      Invoke-Harvester -Fixture $fixture -WorktreeRoot @($worktree)

      $corpus = Get-Corpus -Fixture $fixture
      $corpus.reconciliation.gatherRecordsDuplicate | Should -Be 2
      $duplicates = @($corpus.rows | Where-Object { $_.correlationStatus -eq 'duplicate-gather-record' })
      $duplicates.Count | Should -Be 2 -Because 'both records emit rows and neither is chosen'
      foreach ($row in $duplicates) { $row.invocationId | Should -Be $shared }
    }

    It 'reports a byte-identical duplicate line rather than collapsing it' {
      $fixture = New-CorrelationFixture -Name 'outcome-identical'
      $worktree = New-FixtureWorktree -Fixture $fixture -RepositoryName 'ATAP.Utilities'
      $record = New-GatherRecord
      Add-GatherRecord -WorktreePath $worktree -Record @($record, $record) | Out-Null

      Invoke-Harvester -Fixture $fixture -WorktreeRoot @($worktree)

      $corpus = Get-Corpus -Fixture $fixture
      $corpus.reconciliation.gatherRecordsRead | Should -Be 2
      $corpus.reconciliation.gatherRecordsDuplicate | Should -Be 2
    }

    It 'distinguishes an empty changedFiles array from an absent one' {
      $fixture = New-CorrelationFixture -Name 'outcome-nofiles'
      $worktree = New-FixtureWorktree -Fixture $fixture -RepositoryName 'ATAP.Utilities'
      $emptyRecord = New-GatherRecord -SessionId 'sess-empty'
      $absentRecord = New-GatherRecord -SessionId 'sess-absent'
      Add-GatherRecord -WorktreePath $worktree -Record @($emptyRecord, $absentRecord) | Out-Null
      Add-Handoff -WorktreePath $worktree -Name 'empty.json' -SessionId 'sess-empty' `
        -GatherCalls @($emptyRecord.invocationId) -ChangedFiles @() | Out-Null
      Add-Handoff -WorktreePath $worktree -Name 'absent.json' -SessionId 'sess-absent' `
        -GatherCalls @($absentRecord.invocationId) -OmitChangedFiles | Out-Null

      Invoke-Harvester -Fixture $fixture -WorktreeRoot @($worktree)

      $rows = @((Get-Corpus -Fixture $fixture).rows |
          Where-Object { $_.correlationStatus -eq 'no-changed-files' })
      $rows.Count | Should -Be 2
      ($rows.notes | ForEach-Object { $_ }) -join ' ' | Should -Match 'empty'
      ($rows.notes | ForEach-Object { $_ }) -join ' ' | Should -Match 'absent'
    }
  }

  Context 'Changed-file normalization' {

    It 'maps the handoff change vocabulary onto the contract change kinds' {
      $fixture = New-CorrelationFixture -Name 'files-kinds'
      $worktree = New-FixtureWorktree -Fixture $fixture -RepositoryName 'ATAP.Utilities'
      Add-Handoff -WorktreePath $worktree -Name 'h1.json' -ChangedFiles @(
        [ordered]@{ path = 'src/Created.ps1'; change = 'created' },
        [ordered]@{ path = 'src/Modified.ps1'; change = 'modified' },
        [ordered]@{ path = 'src/Deleted.ps1'; change = 'deleted' }
      ) | Out-Null

      Invoke-Harvester -Fixture $fixture -WorktreeRoot @($worktree)

      $rows = @((Get-Corpus -Fixture $fixture).rows)
      ($rows | Where-Object { $_.changedFilePath -eq 'src/Created.ps1' }).changeKind | Should -Be 'added'
      ($rows | Where-Object { $_.changedFilePath -eq 'src/Modified.ps1' }).changeKind | Should -Be 'modified'
      ($rows | Where-Object { $_.changedFilePath -eq 'src/Deleted.ps1' }).changeKind | Should -Be 'deleted'
      foreach ($row in $rows) { $row.changeKindSource | Should -Be 'handoff' }
    }

    It 'carries an explicitly stated rename through as renamed' {
      $fixture = New-CorrelationFixture -Name 'files-renamed'
      $worktree = New-FixtureWorktree -Fixture $fixture -RepositoryName 'ATAP.Utilities'
      Add-Handoff -WorktreePath $worktree -Name 'h1.json' -ChangedFiles @(
        [ordered]@{
          path               = 'src/New.ps1'
          change             = 'renamed'
          previousPath       = 'src/Old.ps1'
          previousRepository = 'ATAP.Utilities'
        }
      ) | Out-Null

      Invoke-Harvester -Fixture $fixture -WorktreeRoot @($worktree)

      $row = (Get-Corpus -Fixture $fixture).rows[0]
      $row.changeKind | Should -Be 'renamed'
      $row.changedFilePath | Should -Be 'src/New.ps1'
    }

    It 'never infers a rename from a coincident delete and add' {
      $fixture = New-CorrelationFixture -Name 'files-norename'
      $worktree = New-FixtureWorktree -Fixture $fixture -RepositoryName 'ATAP.Utilities'
      Add-Handoff -WorktreePath $worktree -Name 'h1.json' -ChangedFiles @(
        [ordered]@{ path = 'src/Old.ps1'; change = 'deleted' },
        [ordered]@{ path = 'src/New.ps1'; change = 'created' }
      ) | Out-Null

      Invoke-Harvester -Fixture $fixture -WorktreeRoot @($worktree)

      $rows = @((Get-Corpus -Fixture $fixture).rows)
      $rows.Count | Should -Be 2
      @($rows | Where-Object { $_.changeKind -eq 'renamed' }).Count | Should -Be 0
    }

    It 'retains an out-of-repository path and marks it as such' {
      $fixture = New-CorrelationFixture -Name 'files-outofrepo'
      $worktree = New-FixtureWorktree -Fixture $fixture -RepositoryName 'ATAP.Utilities'
      Add-Handoff -WorktreePath $worktree -Name 'h1.json' -ChangedFiles @(
        [ordered]@{ path = 'C:/Users/whertzing/AppData/Local/Temp/ATAP-fixture'; change = 'created' }
      ) | Out-Null

      Invoke-Harvester -Fixture $fixture -WorktreeRoot @($worktree)

      $row = (Get-Corpus -Fixture $fixture).rows[0]
      $row.outOfRepository | Should -BeTrue
      $row.repository | Should -BeNullOrEmpty
      $row.repositoryResolution | Should -Be 'unresolved'
    }

    It 'normalizes mixed separators and strips a repository-name prefix' {
      $fixture = New-CorrelationFixture -Name 'files-separators'
      $worktree = New-FixtureWorktree -Fixture $fixture -RepositoryName 'ATAP.Utilities'
      Add-Handoff -WorktreePath $worktree -Name 'h1.json' -ChangedFiles @(
        [ordered]@{ path = '_generated\Sprint0015\Task15.180/o/O4/worker-handoff.json'; change = 'created' },
        [ordered]@{ path = 'ATAP.Utilities/Directory.Packages.props'; change = 'modified' }
      ) | Out-Null

      Invoke-Harvester -Fixture $fixture -WorktreeRoot @($worktree)

      $paths = @((Get-Corpus -Fixture $fixture).rows.changedFilePath)
      $paths | Should -Contain '_generated/Sprint0015/Task15.180/o/O4/worker-handoff.json'
      $paths | Should -Contain 'Directory.Packages.props'
      foreach ($path in $paths) { $path | Should -Not -Match '\\' }
    }

    It 'keeps the same relative path in two repositories distinct' {
      $fixture = New-CorrelationFixture -Name 'files-multirepo'
      $utilities = New-FixtureWorktree -Fixture $fixture -RepositoryName 'ATAP.Utilities'
      $ace = New-FixtureWorktree -Fixture $fixture -RepositoryName 'Ace'
      Add-Handoff -WorktreePath $utilities -Name 'h1.json' -ChangedFiles @(
        [ordered]@{ path = 'Directory.Packages.props'; change = 'modified' }) | Out-Null
      Add-Handoff -WorktreePath $ace -Name 'h1.json' -ChangedFiles @(
        [ordered]@{ path = 'Directory.Packages.props'; change = 'modified' }) | Out-Null

      Invoke-Harvester -Fixture $fixture -WorktreeRoot @($utilities, $ace)

      $rows = @((Get-Corpus -Fixture $fixture).rows)
      $rows.Count | Should -Be 2
      @($rows.pathKey | Sort-Object -Unique).Count |
        Should -Be 2 -Because 'normalizedPath alone is not an identity'
    }

    It 'records a bare-string changed-file entry as unknown rather than guessing' {
      $fixture = New-CorrelationFixture -Name 'files-barestring'
      $worktree = New-FixtureWorktree -Fixture $fixture -RepositoryName 'ATAP.Utilities'
      Add-Handoff -WorktreePath $worktree -Name 'h1.json' -ChangedFiles @('src/Bare.ps1') | Out-Null

      Invoke-Harvester -Fixture $fixture -WorktreeRoot @($worktree)

      $row = (Get-Corpus -Fixture $fixture).rows[0]
      $row.changeKind | Should -Be 'unknown'
      $row.changeKindSource | Should -Be 'absent'
      $row.changeKind | Should -Not -Be 'modified' -Because 'defaulting an absent kind is fabrication'
    }

    It 'flags prose in a path field as malformed without parsing it into a path' {
      $fixture = New-CorrelationFixture -Name 'files-prose'
      $worktree = New-FixtureWorktree -Fixture $fixture -RepositoryName 'ATAP.Utilities'
      Add-Handoff -WorktreePath $worktree -Name 'h1.json' -ChangedFiles @(
        [ordered]@{ path = 'C:/Artifacts/run-01/ (1203 generated artifact files)'; change = 'created' }
      ) | Out-Null

      Invoke-Harvester -Fixture $fixture -WorktreeRoot @($worktree)

      $corpus = Get-Corpus -Fixture $fixture
      $corpus.reconciliation.changedFileEntriesMalformed | Should -Be 1
      @($corpus.rows | Where-Object { $_.correlationStatus -eq 'malformed-input' }).Count |
        Should -BeGreaterThan 0
    }
  }

  Context 'Malformed input' {

    It 'retains an unparseable line and completes the run' {
      $fixture = New-CorrelationFixture -Name 'malformed-json'
      $worktree = New-FixtureWorktree -Fixture $fixture -RepositoryName 'ATAP.Utilities'
      Add-GatherRecord -WorktreePath $worktree -Record @(
        (New-GatherRecord), '{ this is not json', (New-GatherRecord -Ordinal 2)
      ) | Out-Null

      { Invoke-Harvester -Fixture $fixture -WorktreeRoot @($worktree) } | Should -Not -Throw

      $corpus = Get-Corpus -Fixture $fixture
      $corpus.reconciliation.gatherRecordsMalformed | Should -Be 1
      $corpus.reconciliation.gatherRecordsRead | Should -Be 2
      @($corpus.rows | Where-Object { $_.correlationStatus -eq 'malformed-input' }).Count | Should -Be 1
    }

    It 'treats a record missing a required field as malformed rather than coercing it' {
      $fixture = New-CorrelationFixture -Name 'malformed-missing'
      $worktree = New-FixtureWorktree -Fixture $fixture -RepositoryName 'ATAP.Utilities'
      $record = New-GatherRecord
      $record.Remove('ordinalScope')
      Add-GatherRecord -WorktreePath $worktree -Record @($record) | Out-Null

      Invoke-Harvester -Fixture $fixture -WorktreeRoot @($worktree)
      (Get-Corpus -Fixture $fixture).reconciliation.gatherRecordsMalformed | Should -Be 1
    }

    It 'treats an unknown recordVersion major as malformed, not as silently skipped' {
      $fixture = New-CorrelationFixture -Name 'malformed-version'
      $worktree = New-FixtureWorktree -Fixture $fixture -RepositoryName 'ATAP.Utilities'
      $record = New-GatherRecord
      $record['recordVersion'] = '2.0.0'
      Add-GatherRecord -WorktreePath $worktree -Record @($record) | Out-Null

      Invoke-Harvester -Fixture $fixture -WorktreeRoot @($worktree)

      $corpus = Get-Corpus -Fixture $fixture
      $corpus.reconciliation.gatherRecordsMalformed | Should -Be 1
      @($corpus.rows | Where-Object { ($_.notes -join ' ') -match 'unsupported-version' }).Count |
        Should -BeGreaterThan 0
    }

    It 'reports a truncated final line' {
      $fixture = New-CorrelationFixture -Name 'malformed-truncated'
      $worktree = New-FixtureWorktree -Fixture $fixture -RepositoryName 'ATAP.Utilities'
      $target = Add-GatherRecord -WorktreePath $worktree -Record @((New-GatherRecord))
      $text = [System.IO.File]::ReadAllText($target)
      [System.IO.File]::WriteAllText($target, $text + '{"recordVersion":"1.0.0","invoc',
        [System.Text.UTF8Encoding]::new($false))

      Invoke-Harvester -Fixture $fixture -WorktreeRoot @($worktree)

      $corpus = Get-Corpus -Fixture $fixture
      $corpus.reconciliation.gatherRecordsMalformed | Should -Be 1
      @($corpus.rows | Where-Object { ($_.notes -join ' ') -match 'truncated-final-line' }).Count |
        Should -BeGreaterThan 0
    }

    It 'counts an unparseable handoff without aborting the harvest' {
      $fixture = New-CorrelationFixture -Name 'malformed-handoff'
      $worktree = New-FixtureWorktree -Fixture $fixture -RepositoryName 'ATAP.Utilities'
      Add-Handoff -WorktreePath $worktree -Name 'bad.json' -RawJson '{ not json at all' | Out-Null
      Add-Handoff -WorktreePath $worktree -Name 'good.json' -ChangedFiles @(
        [ordered]@{ path = 'src/A.ps1'; change = 'modified' }) | Out-Null

      { Invoke-Harvester -Fixture $fixture -WorktreeRoot @($worktree) } | Should -Not -Throw

      $corpus = Get-Corpus -Fixture $fixture
      $corpus.reconciliation.handoffsUnparseable | Should -Be 1
      $corpus.reconciliation.handoffsRead | Should -Be 1
    }
  }

  Context 'Sprint scoping' {

    It 'excludes gather records that belong to a different sprint' {
      $fixture = New-CorrelationFixture -Name 'sprint-scope'
      $worktree = New-FixtureWorktree -Fixture $fixture -RepositoryName 'ATAP.Utilities'
      Add-GatherRecord -WorktreePath $worktree -Sprint 'Sprint0015' -Record @((New-GatherRecord)) | Out-Null
      Add-GatherRecord -WorktreePath $worktree -Sprint 'Sprint0014' -Record @((New-GatherRecord -SessionId 'sess-old')) | Out-Null

      Invoke-Harvester -Fixture $fixture -WorktreeRoot @($worktree) -Sprint 'Sprint0015'

      $corpus = Get-Corpus -Fixture $fixture
      $corpus.runMetadata.sprint | Should -Be 'Sprint0015'
      $corpus.reconciliation.gatherRecordsRead | Should -Be 1
      ($corpus.runMetadata.gatherRecordSources -join ';') | Should -Not -Match 'Sprint0014'
    }

    It 'excludes handoffs that belong to a different sprint' {
      $fixture = New-CorrelationFixture -Name 'sprint-scope-handoff'
      $worktree = New-FixtureWorktree -Fixture $fixture -RepositoryName 'ATAP.Utilities'
      Add-Handoff -WorktreePath $worktree -Sprint 'Sprint0015' -Name 'current.json' -ChangedFiles @(
        [ordered]@{ path = 'src/Current.ps1'; change = 'modified' }) | Out-Null
      Add-Handoff -WorktreePath $worktree -Sprint 'Sprint0014' -Name 'old.json' -ChangedFiles @(
        [ordered]@{ path = 'src/Old.ps1'; change = 'modified' }) | Out-Null

      Invoke-Harvester -Fixture $fixture -WorktreeRoot @($worktree) -Sprint 'Sprint0015'

      $paths = @((Get-Corpus -Fixture $fixture).rows.changedFilePath)
      $paths | Should -Contain 'src/Current.ps1'
      $paths | Should -Not -Contain 'src/Old.ps1'
    }
  }

  Context 'Association method is supplied, never invented' {

    It 'records not-determined on every row when the A01 method is unavailable' {
      $fixture = New-CorrelationFixture -Name 'assoc-notdetermined'
      $worktree = New-FixtureWorktree -Fixture $fixture -RepositoryName 'ATAP.Utilities'
      Add-Handoff -WorktreePath $worktree -Name 'h1.json' -ChangedFiles @(
        [ordered]@{ path = 'src/A.ps1'; change = 'modified' }) | Out-Null

      Invoke-Harvester -Fixture $fixture -WorktreeRoot @($worktree) `
        -Extra @{ AssociationMethod = 'not-determined' }

      $corpus = Get-Corpus -Fixture $fixture
      $corpus.runMetadata.associationMethod | Should -Be 'not-determined'
      foreach ($row in $corpus.rows) {
        $row.associationMethod | Should -Be 'not-determined'
        $row.associationStatus | Should -Be 'not-determined'
        $row.associationEvidence | Should -BeNullOrEmpty
      }
    }

    It 'never emits a softened association status' {
      $fixture = New-CorrelationFixture -Name 'assoc-nosoftening'
      $worktree = New-FixtureWorktree -Fixture $fixture -RepositoryName 'ATAP.Utilities'
      Add-Handoff -WorktreePath $worktree -Name 'h1.json' -ChangedFiles @(
        [ordered]@{ path = 'src/A.ps1'; change = 'modified' }) | Out-Null

      Invoke-Harvester -Fixture $fixture -WorktreeRoot @($worktree)

      foreach ($row in (Get-Corpus -Fixture $fixture).rows) {
        $row.associationStatus | Should -Not -BeIn @('probable', 'inferred', 'best-effort', 'assumed')
      }
    }
  }

  Context 'Deterministic ordering' {

    It 'orders rows by the fixed correlationStatus rank, not alphabetically' {
      $fixture = New-CorrelationFixture -Name 'order-rank'
      $worktree = New-FixtureWorktree -Fixture $fixture -RepositoryName 'ATAP.Utilities'
      $matchedRecord = New-GatherRecord -SessionId 'sess-m'
      Add-GatherRecord -WorktreePath $worktree -Record @(
        $matchedRecord, (New-GatherRecord -SessionId 'sess-u')
      ) | Out-Null
      Add-Handoff -WorktreePath $worktree -Name 'h1.json' -SessionId 'sess-m' `
        -GatherCalls @($matchedRecord.invocationId) `
        -ChangedFiles @([ordered]@{ path = 'src/A.ps1'; change = 'modified' }) | Out-Null
      Add-Handoff -WorktreePath $worktree -Name 'h2.json' -SessionId 'sess-orphan' `
        -ChangedFiles @([ordered]@{ path = 'src/B.ps1'; change = 'modified' }) | Out-Null

      Invoke-Harvester -Fixture $fixture -WorktreeRoot @($worktree)

      $statuses = @((Get-Corpus -Fixture $fixture).rows.correlationStatus)
      $ranks = @($statuses | ForEach-Object { $script:CorrelationStatusRank.IndexOf($_) })
      , $ranks | Should -Be @($ranks | Sort-Object)
    }

    It 'sorts null keys last in a single bucket' {
      $fixture = New-CorrelationFixture -Name 'order-nulls'
      $worktree = New-FixtureWorktree -Fixture $fixture -RepositoryName 'ATAP.Utilities'
      Add-GatherRecord -WorktreePath $worktree -Record @(
        (New-GatherRecord -SessionId $null -OrdinalScope 'file' -Ordinal 1),
        (New-GatherRecord -SessionId 'sess-aaa' -Ordinal 1),
        (New-GatherRecord -SessionId 'sess-bbb' -Ordinal 1)
      ) | Out-Null

      Invoke-Harvester -Fixture $fixture -WorktreeRoot @($worktree)

      $sessions = @((Get-Corpus -Fixture $fixture).rows.gatherSessionId)
      $sessions[-1] | Should -BeNullOrEmpty
      $sessions[0] | Should -Be 'sess-aaa'
    }

    It 'produces a total order with rowId as the final tiebreaker' {
      $fixture = New-CorrelationFixture -Name 'order-total'
      $worktree = New-FixtureWorktree -Fixture $fixture -RepositoryName 'ATAP.Utilities'
      Add-GatherRecord -WorktreePath $worktree -Record @(
        1..10 | ForEach-Object { New-GatherRecord -SessionId 'sess-tie' -Ordinal $_ }
      ) | Out-Null

      Invoke-Harvester -Fixture $fixture -WorktreeRoot @($worktree)

      $rowIds = @((Get-Corpus -Fixture $fixture).rows.rowId)
      @($rowIds | Sort-Object -Unique).Count | Should -Be $rowIds.Count
      foreach ($rowId in $rowIds) { $rowId | Should -Match '^[0-9a-f]{32}$' }
    }

    It 'never orders on a timestamp' {
      $fixture = New-CorrelationFixture -Name 'order-notimestamp'
      $worktree = New-FixtureWorktree -Fixture $fixture -RepositoryName 'ATAP.Utilities'
      Add-GatherRecord -WorktreePath $worktree -Record @(
        (New-GatherRecord -SessionId 'sess-a' -Ordinal 1 -TimestampUtc '2026-08-25T23:59:59.999Z'),
        (New-GatherRecord -SessionId 'sess-b' -Ordinal 1 -TimestampUtc '2026-08-25T00:00:00.001Z')
      ) | Out-Null

      Invoke-Harvester -Fixture $fixture -WorktreeRoot @($worktree)

      $sessions = @((Get-Corpus -Fixture $fixture).rows.gatherSessionId)
      $sessions[0] | Should -Be 'sess-a' -Because 'session ordering precedes and excludes timestamps'
    }
  }

  Context 'Idempotent rerun' {

    It 'produces an identical contentDigest over unchanged inputs' {
      $fixture = New-CorrelationFixture -Name 'idempotent-digest'
      $worktree = New-FixtureWorktree -Fixture $fixture -RepositoryName 'ATAP.Utilities'
      $record = New-GatherRecord
      Add-GatherRecord -WorktreePath $worktree -Record @($record) | Out-Null
      Add-Handoff -WorktreePath $worktree -Name 'h1.json' -GatherCalls @($record.invocationId) `
        -ChangedFiles @([ordered]@{ path = 'src/A.ps1'; change = 'modified' }) | Out-Null

      Invoke-Harvester -Fixture $fixture -WorktreeRoot @($worktree)
      $first = Get-Corpus -Fixture $fixture
      Invoke-Harvester -Fixture $fixture -WorktreeRoot @($worktree)
      $second = Get-Corpus -Fixture $fixture

      $second.runMetadata.contentDigest | Should -Be $first.runMetadata.contentDigest
      $second.runMetadata.contentDigest | Should -Match '^[0-9a-f]{64}$'
    }

    It 'keeps every row byte-stable across a rerun, varying only the header timestamp' {
      $fixture = New-CorrelationFixture -Name 'idempotent-bytes'
      $worktree = New-FixtureWorktree -Fixture $fixture -RepositoryName 'ATAP.Utilities'
      Add-GatherRecord -WorktreePath $worktree -Record @(
        1..5 | ForEach-Object { New-GatherRecord -Ordinal $_ }
      ) | Out-Null

      Invoke-Harvester -Fixture $fixture -WorktreeRoot @($worktree)
      $firstRows = ((Get-Corpus -Fixture $fixture).rows | ConvertTo-Json -Depth 20)
      Invoke-Harvester -Fixture $fixture -WorktreeRoot @($worktree)
      $secondRows = ((Get-Corpus -Fixture $fixture).rows | ConvertTo-Json -Depth 20)

      $secondRows | Should -Be $firstRows
    }

    It 'overwrites the durable artifact in place rather than accumulating copies' {
      $fixture = New-CorrelationFixture -Name 'idempotent-overwrite'
      $worktree = New-FixtureWorktree -Fixture $fixture -RepositoryName 'ATAP.Utilities'
      Add-GatherRecord -WorktreePath $worktree -Record @((New-GatherRecord)) | Out-Null

      Invoke-Harvester -Fixture $fixture -WorktreeRoot @($worktree)
      Invoke-Harvester -Fixture $fixture -WorktreeRoot @($worktree)

      @(Get-ChildItem -LiteralPath $fixture.Durable -Filter 'correlated-corpus.v1.*').Count |
        Should -Be 2 -Because 'exactly one json and one md, overwritten in place'
    }

    It 'serializes without a byte-order mark and with LF endings' {
      $fixture = New-CorrelationFixture -Name 'idempotent-encoding'
      $worktree = New-FixtureWorktree -Fixture $fixture -RepositoryName 'ATAP.Utilities'
      Add-GatherRecord -WorktreePath $worktree -Record @((New-GatherRecord)) | Out-Null
      Invoke-Harvester -Fixture $fixture -WorktreeRoot @($worktree)

      $bytes = [System.IO.File]::ReadAllBytes((Join-Path $fixture.Durable 'correlated-corpus.v1.json'))
      @($bytes[0], $bytes[1], $bytes[2]) -join ',' | Should -Not -Be '239,187,191'
      (Get-CorpusText -Fixture $fixture) | Should -Not -Match "`r"
    }

    It 'never mutates its inputs' {
      $fixture = New-CorrelationFixture -Name 'idempotent-readonly'
      $worktree = New-FixtureWorktree -Fixture $fixture -RepositoryName 'ATAP.Utilities'
      $target = Add-GatherRecord -WorktreePath $worktree -Record @((New-GatherRecord))
      $before = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash

      Invoke-Harvester -Fixture $fixture -WorktreeRoot @($worktree)

      (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash | Should -Be $before
    }
  }

  Context 'Reconciliation' {

    It 'accounts for every input record and reports balanced' {
      $fixture = New-CorrelationFixture -Name 'reconcile'
      $worktree = New-FixtureWorktree -Fixture $fixture -RepositoryName 'ATAP.Utilities'
      Add-GatherRecord -WorktreePath $worktree -Record @(
        1..3 | ForEach-Object { New-GatherRecord -Ordinal $_ -Tags @('t1', 't2') }
      ) | Out-Null
      Add-Handoff -WorktreePath $worktree -Name 'h1.json' -ChangedFiles @(
        [ordered]@{ path = 'src/A.ps1'; change = 'modified' },
        [ordered]@{ path = 'src/B.ps1'; change = 'created' }
      ) | Out-Null

      Invoke-Harvester -Fixture $fixture -WorktreeRoot @($worktree)

      $corpus = Get-Corpus -Fixture $fixture
      $corpus.reconciliation.gatherRecordsRead | Should -Be 3
      $corpus.reconciliation.changedFileEntriesRead | Should -Be 2
      $corpus.reconciliation.rowCount | Should -Be @($corpus.rows).Count
      $corpus.reconciliation.balanced | Should -BeTrue
    }

    It 'writes the point-in-time evidence tree alongside the durable corpus' {
      $fixture = New-CorrelationFixture -Name 'reconcile-evidence'
      $worktree = New-FixtureWorktree -Fixture $fixture -RepositoryName 'ATAP.Utilities'
      Add-GatherRecord -WorktreePath $worktree -Record @((New-GatherRecord)) | Out-Null

      Invoke-Harvester -Fixture $fixture -WorktreeRoot @($worktree)

      $files = @(Get-ChildItem -LiteralPath $fixture.Evidence -Recurse -File).Name
      $files | Should -Contain 'input-inventory.json'
      $files | Should -Contain 'reconciliation.json'
      $files | Should -Contain 'malformed-records.json'
      $files | Should -Contain 'content-digest.txt'
    }
  }

  Context 'Markdown rendering' {

    It 'always emits every section, with an explicit None when empty' {
      $fixture = New-CorrelationFixture -Name 'render-sections'
      $worktree = New-FixtureWorktree -Fixture $fixture -RepositoryName 'ATAP.Utilities'
      Add-GatherRecord -WorktreePath $worktree -Record @((New-GatherRecord)) | Out-Null

      Invoke-Harvester -Fixture $fixture -WorktreeRoot @($worktree)

      $markdown = [System.IO.File]::ReadAllText((Join-Path $fixture.Durable 'correlated-corpus.v1.md'))
      foreach ($heading in @('## Reconciliation', '## Correlation summary', '## Matched rows',
          '## Unmatched gather calls', '## Unassociated changed files',
          '## Ambiguous matches', '## Duplicates and malformed input')) {
        $markdown | Should -Match ([regex]::Escape($heading))
      }
      $markdown | Should -Match 'None\.'
    }

    It 'renders a null as the literal absent marker rather than a blank cell' {
      $fixture = New-CorrelationFixture -Name 'render-absent'
      $worktree = New-FixtureWorktree -Fixture $fixture -RepositoryName 'ATAP.Utilities'
      Add-GatherRecord -WorktreePath $worktree -Record @((New-GatherRecord)) | Out-Null

      Invoke-Harvester -Fixture $fixture -WorktreeRoot @($worktree)

      $markdown = [System.IO.File]::ReadAllText((Join-Path $fixture.Durable 'correlated-corpus.v1.md'))
      $markdown | Should -Match '\*\(absent\)\*'
    }

    It 'never renders the pathKey' {
      $fixture = New-CorrelationFixture -Name 'render-nopathkey'
      $worktree = New-FixtureWorktree -Fixture $fixture -RepositoryName 'ATAP.Utilities'
      Add-Handoff -WorktreePath $worktree -Name 'h1.json' -ChangedFiles @(
        [ordered]@{ path = 'src/A.ps1'; change = 'modified' }) | Out-Null

      Invoke-Harvester -Fixture $fixture -WorktreeRoot @($worktree)

      $markdown = [System.IO.File]::ReadAllText((Join-Path $fixture.Durable 'correlated-corpus.v1.md'))
      $markdown | Should -Not -Match 'pathKey'
    }
  }
}
