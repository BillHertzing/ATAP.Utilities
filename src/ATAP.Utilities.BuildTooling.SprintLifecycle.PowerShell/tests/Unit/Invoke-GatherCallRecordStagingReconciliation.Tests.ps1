#Requires -Version 7.0

BeforeAll {
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage {
      param([string]$FunctionName, [string]$ModuleName, [string]$Level,
        [string]$Message, [string]$Tag)
    }
    $script:CreatedWritePsfTestDouble = $true
  }
  if (-not (Get-Command Get-PVal -ErrorAction SilentlyContinue)) {
    function global:Get-PVal { throw 'Get-PVal test double was not configured.' }
    $script:CreatedGetPValTestDouble = $true
  }
  if (-not (Get-Command Complete-GatherCallRecordSegment -ErrorAction SilentlyContinue)) {
    function global:Complete-GatherCallRecordSegment {
      param(
        [string]$StagingFilePath,
        [object]$CorpusGatherRecordsStagingPath,
        [object]$CorpusGatherRecordsPath,
        [object]$SprintNumber,
        [switch]$QuarantineInvalidRemnant,
        [switch]$WhatIf,
        [switch]$Confirm
      )
      throw 'Sealer test double was not configured.'
    }
    $script:CreatedSealerTestDouble = $true
  }

  $script:moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $script:functionPath = Join-Path $script:moduleRoot 'private\Invoke-GatherCallRecordStagingReconciliation.ps1'
  . $script:functionPath
  $script:now = [datetime]::SpecifyKind([datetime]'2026-09-13T18:00:00', [DateTimeKind]::Utc)

  function New-ReconciliationFixture {
    param([string]$Name)
    $root = Join-Path $TestDrive "$Name-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    $staging = Join-Path $root 'CorpusGatherRecordsStaging'
    $corpus = Join-Path $root 'CorpusGatherRecords'
    New-Item -ItemType Directory -Path $staging, $corpus -Force | Out-Null
    [pscustomobject]@{ Root = $root; Staging = $staging; Corpus = $corpus }
  }

  function New-ReconciliationRecord {
    param([AllowNull()][object]$SessionId = 'session-a')
    [ordered]@{
      recordVersion = '1.0.0'
      invocationId = [guid]::NewGuid().ToString().ToLowerInvariant()
      requestResponsePairId = $null
      ordinal = 1
      ordinalScope = 'session'
      timestampUtc = '2026-09-13T17:00:00.000Z'
      agentName = 'junior-dev-coder-sh'
      agentModel = $null
      sessionId = $SessionId
      taskId = '15.191.c'
      worktreePath = 'C:/fixture/worktree'
      repositoryName = 'ATAP.Utilities'
      conversationId = $null
      conversationTitle = $null
    }
  }

  function New-SegmentFile {
    param(
      [object]$Fixture,
      [string]$Name = ('20260913T170000000Z-' + [guid]::NewGuid().ToString().ToLowerInvariant() + '.jsonl'),
      [object[]]$Records = @((New-ReconciliationRecord)),
      [timespan]$Age = ([timespan]::FromMinutes(1))
    )
    $path = Join-Path $Fixture.Staging $Name
    $text = (@($Records | ForEach-Object { $_ | ConvertTo-Json -Compress -Depth 8 }) -join "`n") + "`n"
    [System.IO.File]::WriteAllText($path, $text, [System.Text.UTF8Encoding]::new($false))
    (Get-Item -LiteralPath $path).LastWriteTimeUtc = $script:now - $Age
    $path
  }

  function Invoke-ReconciliationFixture {
    param(
      [object]$Fixture,
      [string[]]$ClosedSessionId = @(),
      [timespan]$MaximumSegmentAge = ([timespan]::FromHours(1)),
      [long]$MaximumSegmentBytes = 1000000,
      [timespan]$AbandonedRemnantAge = ([timespan]::FromHours(1)),
      [datetime]$NowUtc = $script:now,
      [switch]$WhatIf
    )
    $arguments = @{
      CorpusGatherRecordsStagingPath = $Fixture.Staging
      CorpusGatherRecordsPath = $Fixture.Corpus
      SprintNumber = '0015'
      ClosedSessionId = $ClosedSessionId
      MaximumSegmentAge = $MaximumSegmentAge
      MaximumSegmentBytes = $MaximumSegmentBytes
      AbandonedRemnantAge = $AbandonedRemnantAge
      NowUtc = $NowUtc
    }
    if ($WhatIf) { $arguments.WhatIf = $true }
    Invoke-GatherCallRecordStagingReconciliation @arguments
  }
}

AfterAll {
  if ($script:CreatedSealerTestDouble) {
    Microsoft.PowerShell.Management\Remove-Item -LiteralPath 'Function:\Complete-GatherCallRecordSegment' -ErrorAction SilentlyContinue
  }
  if ($script:CreatedGetPValTestDouble) {
    Microsoft.PowerShell.Management\Remove-Item -LiteralPath 'Function:\Get-PVal' -ErrorAction SilentlyContinue
  }
  if ($script:CreatedWritePsfTestDouble) {
    Microsoft.PowerShell.Management\Remove-Item -LiteralPath 'Function:\Write-PSFMessage' -ErrorAction SilentlyContinue
  }
}

Describe 'Invoke-GatherCallRecordStagingReconciliation [private]' -Tag 'Unit' {
  BeforeEach {
    Mock Complete-GatherCallRecordSegment {
      [pscustomobject]@{
        Ok = $true
        Action = if ($QuarantineInvalidRemnant) { 'Quarantine' } else { 'Seal' }
        Movement = [pscustomobject]@{ Planned = $true; Performed = -not [bool]$WhatIf }
        Failure = $null
      }
    }
  }

  It 'defines only the eponymous advanced function and supports ShouldProcess' {
    $command = Get-Command Invoke-GatherCallRecordStagingReconciliation -CommandType Function
    $command.CmdletBinding | Should -BeTrue
    $command.Parameters.Keys | Should -Contain 'WhatIf'
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
      $script:functionPath, [ref]$tokens, [ref]$errors)
    $errors | Should -BeNullOrEmpty
    @($ast.EndBlock.Statements | Where-Object {
        $_ -isnot [System.Management.Automation.Language.FunctionDefinitionAst]
      }) | Should -BeNullOrEmpty
  }

  It 'uses PSFramework and contains no direct movement or deletion primitive' {
    $source = Get-Content -LiteralPath $script:functionPath -Raw
    $source | Should -Match 'Write-PSFMessage'
    $source | Should -Not -Match '(?i)\b(Move-Item|Copy-Item|Remove-Item|robocopy|icacls)\b'
    $source | Should -Not -Match '(?i)\[System\.IO\.File\]::(Move|Copy|Delete)\s*\('
  }

  It 'resolves omitted roots through only the two exact Get-PVal keys' {
    $fixture = New-ReconciliationFixture 'getpval'
    Mock Get-PVal {
      if ($ParameterName -ne $dottedPath) { throw 'key mismatch' }
      if ($ParameterName -eq 'CorpusGatherRecordsStagingPath') { return $fixture.Staging }
      if ($ParameterName -eq 'CorpusGatherRecordsPath') { return $fixture.Corpus }
      throw "unexpected key $ParameterName"
    }
    $result = Invoke-GatherCallRecordStagingReconciliation -SprintNumber '0015' `
      -MaximumSegmentAge ([timespan]::FromHours(1)) -MaximumSegmentBytes 1000 `
      -AbandonedRemnantAge ([timespan]::FromHours(1)) -NowUtc $script:now
    $result.Ok | Should -BeTrue
    Should -Invoke Get-PVal -Exactly 1 -ParameterFilter {
      $ParameterName -eq 'CorpusGatherRecordsStagingPath' -and $dottedPath -eq $ParameterName
    }
    Should -Invoke Get-PVal -Exactly 1 -ParameterFilter {
      $ParameterName -eq 'CorpusGatherRecordsPath' -and $dottedPath -eq $ParameterName
    }
  }

  It 'fails explicit null or blank roots closed without setting fallback' -ForEach @(
    @{ Name = 'null'; Value = $null },
    @{ Name = 'blank'; Value = '   ' },
    @{ Name = 'relative'; Value = 'staging' },
    @{ Name = 'ambiguous'; Value = @('C:\a', 'C:\b') }
  ) {
    $fixture = New-ReconciliationFixture "root-$Name"
    Mock Get-PVal { throw 'must not be called' }
    $result = Invoke-GatherCallRecordStagingReconciliation `
      -CorpusGatherRecordsStagingPath $Value -CorpusGatherRecordsPath $fixture.Corpus `
      -SprintNumber '0015' -MaximumSegmentAge ([timespan]::FromHours(1)) `
      -MaximumSegmentBytes 1000 -AbandonedRemnantAge ([timespan]::FromHours(1)) -NowUtc $script:now
    $result.Ok | Should -BeFalse
    $result.Failure.Message | Should -Match 'Root resolution failed'
    Should -Invoke Get-PVal -Exactly 0
  }

  It 'requires an injected UTC NowUtc value' {
    $fixture = New-ReconciliationFixture 'not-utc'
    $localNow = [datetime]::SpecifyKind($script:now, [DateTimeKind]::Local)
    (Invoke-ReconciliationFixture -Fixture $fixture -NowUtc $localNow).Failure.Message |
      Should -Match 'DateTimeKind Utc'
  }

  It 'seals independently for a closed session' {
    $fixture = New-ReconciliationFixture 'session'
    $source = New-SegmentFile -Fixture $fixture -Records @((New-ReconciliationRecord -SessionId 'closed-a'))
    $result = Invoke-ReconciliationFixture -Fixture $fixture -ClosedSessionId @('closed-a')
    $result.Counts.Eligible | Should -Be 1
    $result.Files[0].Boundary | Should -Be @('closed-session')
    $result.Files[0].Path | Should -Be $source
    Should -Invoke Complete-GatherCallRecordSegment -Exactly 1
  }

  It 'seals independently at the exact size boundary' {
    $fixture = New-ReconciliationFixture 'size'
    $source = New-SegmentFile -Fixture $fixture
    $size = (Get-Item -LiteralPath $source).Length
    $result = Invoke-ReconciliationFixture -Fixture $fixture -MaximumSegmentBytes $size
    $result.Files[0].Boundary | Should -Contain 'maximum-bytes'
    $result.Counts.Invoked | Should -Be 1
  }

  It 'seals independently at the exact age boundary using injected UTC' {
    $fixture = New-ReconciliationFixture 'age'
    New-SegmentFile -Fixture $fixture -Age ([timespan]::FromMinutes(30)) | Out-Null
    $result = Invoke-ReconciliationFixture -Fixture $fixture `
      -MaximumSegmentAge ([timespan]::FromMinutes(30))
    $result.Files[0].Boundary | Should -Contain 'maximum-age'
  }

  It 'records all session size and age boundaries when met together' {
    $fixture = New-ReconciliationFixture 'combined'
    $source = New-SegmentFile -Fixture $fixture -Age ([timespan]::FromHours(2)) `
      -Records @((New-ReconciliationRecord -SessionId 'all'))
    $size = (Get-Item -LiteralPath $source).Length
    $result = Invoke-ReconciliationFixture -Fixture $fixture -ClosedSessionId @('all') `
      -MaximumSegmentAge ([timespan]::FromHours(1)) -MaximumSegmentBytes $size
    $result.Files[0].Boundary | Should -Be @('closed-session', 'maximum-bytes', 'maximum-age')
  }

  It 'leaves a segment untouched when no boundary is met' {
    $fixture = New-ReconciliationFixture 'no-boundary'
    New-SegmentFile -Fixture $fixture | Out-Null
    $result = Invoke-ReconciliationFixture -Fixture $fixture
    $result.Counts.Skipped | Should -Be 1
    $result.Files[0].Reason | Should -Be 'no-boundary-met'
    Should -Invoke Complete-GatherCallRecordSegment -Exactly 0
  }

  It 'skips mixed and null session identities without guessing intent' -ForEach @(
    @{ Name = 'mixed'; Reason = 'mixed-session-identity' },
    @{ Name = 'null'; Reason = 'null-session-identity' }
  ) {
    $fixture = New-ReconciliationFixture "identity-$Name"
    $Records = if ($Name -eq 'mixed') {
      @((New-ReconciliationRecord -SessionId 'a'), (New-ReconciliationRecord -SessionId 'b'))
    } else {
      @((New-ReconciliationRecord -SessionId $null))
    }
    New-SegmentFile -Fixture $fixture -Records $Records -Age ([timespan]::FromHours(2)) | Out-Null
    $result = Invoke-ReconciliationFixture -Fixture $fixture
    $result.Files[0].Reason | Should -Be $Reason
    Should -Invoke Complete-GatherCallRecordSegment -Exactly 0
  }

  It 'quarantines an overdue partial and leaves a recent partial untouched' {
    $fixture = New-ReconciliationFixture 'partials'
    $old = Join-Path $fixture.Staging ('_partial-' + [guid]::NewGuid().ToString('N') + '.tmp')
    $recent = Join-Path $fixture.Staging ('_partial-' + [guid]::NewGuid().ToString('N') + '.tmp')
    [System.IO.File]::WriteAllText($old, 'old')
    [System.IO.File]::WriteAllText($recent, 'recent')
    (Get-Item $old).LastWriteTimeUtc = $script:now - [timespan]::FromHours(2)
    (Get-Item $recent).LastWriteTimeUtc = $script:now - [timespan]::FromMinutes(5)
    $result = Invoke-ReconciliationFixture -Fixture $fixture
    $result.Counts.Eligible | Should -Be 1
    $result.Counts.Skipped | Should -Be 1
    ($result.Files | Where-Object Path -eq $old).Action | Should -Be 'Quarantine'
    ($result.Files | Where-Object Path -eq $recent).Reason | Should -Be 'recent-partial-remnant'
    ($result.Files | Where-Object Path -eq $old).Path | Should -Be $old
    Should -Invoke Complete-GatherCallRecordSegment -Exactly 1
  }

  It 'passes any valid non-32-hex partial name to the primitive at the exact age threshold' {
    $fixture = New-ReconciliationFixture 'partial-contract-name'
    $source = Join-Path $fixture.Staging '_partial-session-abc.tmp'
    [System.IO.File]::WriteAllText($source, 'abandoned')
    (Get-Item $source).LastWriteTimeUtc = $script:now - [timespan]::FromHours(1)

    $result = Invoke-ReconciliationFixture -Fixture $fixture

    $result.Counts.Eligible | Should -Be 1
    $result.Counts.Invoked | Should -Be 1
    $result.Files[0].Action | Should -Be 'Quarantine'
    $result.Files[0].Boundary | Should -Be @('abandoned-remnant-age')
    Should -Invoke Complete-GatherCallRecordSegment -Exactly 1 -ParameterFilter {
      $StagingFilePath -eq $source -and $QuarantineInvalidRemnant
    }
  }

  It 'skips unsupported JSONL names and ignores unrelated temporary names' {
    $fixture = New-ReconciliationFixture 'unsupported'
    New-SegmentFile -Fixture $fixture -Name 'segment.jsonl' -Age ([timespan]::FromHours(2)) | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $fixture.Staging 'not-partial.tmp'), 'x')
    $result = Invoke-ReconciliationFixture -Fixture $fixture
    $result.Counts.Discovered | Should -Be 1
    $result.Counts.Skipped | Should -Be 1
    @($result.Files.Reason | Select-Object -Unique) | Should -Be @('unsupported-filename')
  }

  It 'discovers direct children only and excludes quarantine contents' {
    $fixture = New-ReconciliationFixture 'direct'
    New-SegmentFile -Fixture $fixture -Age ([timespan]::FromHours(2)) | Out-Null
    $nested = Join-Path $fixture.Staging 'nested'
    $quarantine = Join-Path $fixture.Staging 'quarantine'
    New-Item -ItemType Directory -Path $nested, $quarantine | Out-Null
    $nestedFixture = [pscustomobject]@{ Staging = $nested }
    $quarantineFixture = [pscustomobject]@{ Staging = $quarantine }
    New-SegmentFile -Fixture $nestedFixture -Age ([timespan]::FromHours(2)) | Out-Null
    New-SegmentFile -Fixture $quarantineFixture -Age ([timespan]::FromHours(2)) | Out-Null
    $result = Invoke-ReconciliationFixture -Fixture $fixture
    $result.Counts.Discovered | Should -Be 1
    Should -Invoke Complete-GatherCallRecordSegment -Exactly 1
  }

  It 'returns files in deterministic ordinal path order' {
    $fixture = New-ReconciliationFixture 'order'
    $idA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
    $idB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
    New-SegmentFile -Fixture $fixture -Name "20260913T170000000Z-$idB.jsonl" | Out-Null
    New-SegmentFile -Fixture $fixture -Name "20260913T170000000Z-$idA.jsonl" | Out-Null
    $result = Invoke-ReconciliationFixture -Fixture $fixture
    $result.Files.Name | Should -Be @(
      "20260913T170000000Z-$idA.jsonl", "20260913T170000000Z-$idB.jsonl")
  }

  It 'skips a file whose length or timestamp changes before invocation' {
    $fixture = New-ReconciliationFixture 'changed'
    $source = New-SegmentFile -Fixture $fixture -Age ([timespan]::FromHours(2))
    Mock Get-Item {
      [System.IO.File]::AppendAllText($LiteralPath, " `n")
      [System.IO.File]::SetLastWriteTimeUtc($LiteralPath, $script:now)
      $changedItem = [System.IO.FileInfo]::new($LiteralPath)
      $changedItem.Refresh()
      $changedItem
    } -ParameterFilter { $LiteralPath -eq $source }
    $result = Invoke-ReconciliationFixture -Fixture $fixture
    $result.Files[0].Reason | Should -Be 'source-changed'
    Should -Invoke Complete-GatherCallRecordSegment -Exactly 0
  }

  It 'skips a file that disappears before the stable recheck' {
    $fixture = New-ReconciliationFixture 'disappeared'
    $source = New-SegmentFile -Fixture $fixture -Age ([timespan]::FromHours(2))
    Mock Test-Path { $false } -ParameterFilter {
      $LiteralPath -eq $source -and $PathType -eq 'Leaf'
    }
    $result = Invoke-ReconciliationFixture -Fixture $fixture
    $result.Files[0].Reason | Should -Be 'source-disappeared'
    Should -Invoke Complete-GatherCallRecordSegment -Exactly 0
  }

  It 'preserves a primitive refusal in the per-file result and failure count' {
    $fixture = New-ReconciliationFixture 'refusal'
    New-SegmentFile -Fixture $fixture -Age ([timespan]::FromHours(2)) | Out-Null
    Mock Complete-GatherCallRecordSegment {
      [pscustomobject]@{ Ok = $false; Movement = [pscustomobject]@{ Performed = $false }; Failure = [pscustomobject]@{ Code = 'validation-failed' } }
    }
    $result = Invoke-ReconciliationFixture -Fixture $fixture
    $result.Ok | Should -BeFalse
    $result.Counts.Failed | Should -Be 1
    $result.Files[0].Result.Failure.Code | Should -Be 'validation-failed'
  }

  It 'is deterministic across repeated non-mutating scans' {
    $fixture = New-ReconciliationFixture 'repeat'
    New-SegmentFile -Fixture $fixture | Out-Null
    $first = Invoke-ReconciliationFixture -Fixture $fixture
    $second = Invoke-ReconciliationFixture -Fixture $fixture
    ($first | ConvertTo-Json -Depth 12) | Should -Be ($second | ConvertTo-Json -Depth 12)
  }

  It 'propagates WhatIf to the primitive and reports no completed movement' {
    $fixture = New-ReconciliationFixture 'whatif'
    $source = New-SegmentFile -Fixture $fixture -Age ([timespan]::FromHours(2))
    $before = [System.IO.File]::ReadAllBytes($source)
    $result = Invoke-ReconciliationFixture -Fixture $fixture -WhatIf
    $result.Files[0].Status | Should -Be 'Planned'
    $result.Counts.Sealed | Should -Be 0
    [System.IO.File]::ReadAllBytes($source) | Should -Be $before
    Should -Invoke Complete-GatherCallRecordSegment -Exactly 1
  }

  It 'refuses staging and corpus reparse roots when symbolic links are available' -ForEach @(
    @{ RootName = 'Staging' }, @{ RootName = 'Corpus' }
  ) {
    $fixture = New-ReconciliationFixture "root-reparse-$RootName"
    $external = Join-Path $fixture.Root "external-$RootName"
    New-Item -ItemType Directory -Path $external | Out-Null
    $link = Join-Path $fixture.Root "link-$RootName"
    try {
      New-Item -ItemType SymbolicLink -Path $link -Target $external -ErrorAction Stop | Out-Null
    } catch {
      Set-ItResult -Skipped -Because "symbolic links unavailable: $($_.Exception.Message)"
      return
    }
    if ($RootName -eq 'Staging') { $fixture.Staging = $link } else { $fixture.Corpus = $link }
    $result = Invoke-ReconciliationFixture -Fixture $fixture
    $result.Ok | Should -BeFalse
    $result.Failure.Message | Should -Match 'reparse point'
    Should -Invoke Complete-GatherCallRecordSegment -Exactly 0
  }

  It 'refuses a direct-child source reparse point when symbolic links are available' {
    $fixture = New-ReconciliationFixture 'source-reparse'
    $target = Join-Path $fixture.Root 'target.jsonl'
    [System.IO.File]::WriteAllText($target, '{}')
    $link = Join-Path $fixture.Staging ('20260913T170000000Z-' + [guid]::NewGuid().ToString().ToLowerInvariant() + '.jsonl')
    try {
      New-Item -ItemType SymbolicLink -Path $link -Target $target -ErrorAction Stop | Out-Null
    } catch {
      Set-ItResult -Skipped -Because "symbolic links unavailable: $($_.Exception.Message)"
      return
    }
    $result = Invoke-ReconciliationFixture -Fixture $fixture
    $result.Files[0].Reason | Should -Be 'reparse-point'
    Should -Invoke Complete-GatherCallRecordSegment -Exactly 0
  }
}
