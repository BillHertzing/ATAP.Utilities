BeforeAll {
  Import-Module PSFramework -MinimumVersion 1.14.457 -ErrorAction Stop
  $script:moduleRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
  . (Join-Path $script:moduleRoot 'private/StreamProgress.Helpers.ps1')
  foreach ($name in @('Initialize-SprintStreamProgress', 'Update-SprintStreamProgress', 'Import-SprintChatActivity')) { . (Join-Path $script:moduleRoot "public/$name.ps1") }
  $script:testRoot = Join-Path ([IO.Path]::GetFullPath((Join-Path $script:moduleRoot '../..'))) ('_generated/StreamProgress.Tests/' + [guid]::NewGuid().ToString('N'))
  $null = [IO.Directory]::CreateDirectory($script:testRoot)
  function New-ProgressFixture {
    $root = Join-Path $script:testRoot ([guid]::NewGuid().ToString('N'))
    $null = [IO.Directory]::CreateDirectory($root)
    $md = @'
# Sprint 17
## Stream P - Readiness
- [ ] **Task 17.1** [Cross-Repo] - Parent
  - Status: Planned
- [x] **Task 17.1.a** [Cross-Repo] - Contract
  - Status: COMPLETE bounded contract; evidence abcdef12
- [ ] **Task 17.1.o-src** [Cross-Repo] - Source implementation
  - Status: Planned
```text
- [x] **Task 17.99** [Cross-Repo] - Not an actual task
```
## Stream C - Clerk
- [ ] **Task 17.2** [Cross-Repo] - Clerk
  - Status: Planned
'@
    [IO.File]::WriteAllText((Join-Path $root 'Tasks.Sprint0017.md'), $md)
    foreach ($name in @('Tasks.Sprint0017.html', 'Tasks.Sprint0017.Accomplished.html', 'Tasks.Sprint0017.ProceduralDetails.html')) { [IO.File]::WriteAllText((Join-Path $root $name), '<html><body>fixture</body></html>') }
    $parameters = @{ PlanningRoot = $root; SprintNumber = 17; StartDate = '2026-10-24'; EndDate = '2026-11-23'; TimeZoneId = 'America/Denver'; ObservedAt = [DateTimeOffset]'2026-11-16T18:00:00Z'; ManualWriterReference = 'Disposable test exclusion' }
    @{ Root = $root; Parameters = $parameters; Manifest = Join-Path $root 'InformationForTheFuture/Sprint0017/StreamProgress/StreamProgress.manifest.json'; Output = Join-Path $root 'Tasks.Sprint0017.StreamProgress.html' }
  }
  function Initialize-ProgressFixture($Fixture, [switch]$WhatIf) {
    $parameters = $Fixture.Parameters
    Initialize-SprintStreamProgress @parameters -WhatIf:$WhatIf
  }
  function Get-ProgressFixtureHashes($Fixture) {
    $config = Read-StreamProgressManifest $Fixture.Manifest
    $bindings = Get-StreamProgressBindings $config
    $hashes = @{}
    foreach ($slot in $bindings.Keys) { $hashes[$slot] = (Get-FileHash $bindings[$slot]).Hash }
    return $hashes
  }
  function New-ProgressInventory($Fixture, [string]$Text, [string]$Format = 'ClaudeJsonl') {
    $source = Join-Path $Fixture.Root 'native.jsonl'
    [IO.File]::WriteAllText($source, $Text)
    $record = @{ path = $source; sha256 = (Get-FileHash $source).Hash; format = $Format; sessionId = 'native-1'; title = 'Named Claude fixture' }
    $inventory = Join-Path $Fixture.Root 'inventory.json'
    [IO.File]::WriteAllText($inventory, (ConvertTo-StreamProgressJson @{ schemaVersion = 1; sources = @($record) }))
    return $inventory
  }
}

Describe 'Sprint stream progress manual publication' -Tag 'Unit' {
  It 'resolves Resources from an assembled module rather than assuming source subfolders' {
    $f = New-ProgressFixture
    $stage = Join-Path $f.Root '_generated/PackagedShape'
    $null = [IO.Directory]::CreateDirectory((Join-Path $stage 'Resources/StreamProgress'))
    foreach ($name in @('template.html', 'input.schema.json')) { Copy-Item (Join-Path $script:moduleRoot "Resources/StreamProgress/$name") (Join-Path $stage "Resources/StreamProgress/$name") }
    $files = @('private/StreamProgress.Helpers.ps1', 'public/Initialize-SprintStreamProgress.ps1', 'public/Update-SprintStreamProgress.ps1', 'public/Import-SprintChatActivity.ps1')
    $body = (@($files | ForEach-Object { [IO.File]::ReadAllText((Join-Path $script:moduleRoot $_)) }) -join "`n") + "`nExport-ModuleMember -Function Initialize-SprintStreamProgress,Update-SprintStreamProgress,Import-SprintChatActivity"
    $modulePath = Join-Path $stage 'StreamProgressPackagedFixture.psm1'
    [IO.File]::WriteAllText($modulePath, $body)
    Import-Module $modulePath -Prefix Packaged -Force
    try {
      $parameters = $f.Parameters
      $result = Initialize-PackagedSprintStreamProgress @parameters
      $result.Status | Should -Be 'Created'
      Test-Path $f.Output | Should -BeTrue
    } finally { Remove-Module StreamProgressPackagedFixture -ErrorAction SilentlyContinue }
  }
  It 'WhatIf creates no durable inputs or output' {
    $f = New-ProgressFixture
    $result = Initialize-ProgressFixture $f -WhatIf
    $result.Status | Should -Be 'WouldInitialize'
    Test-Path $f.Manifest | Should -BeFalse
    Test-Path $f.Output | Should -BeFalse
  }
  It 'creates a separate page and repeat initialization is byte-identical and unchanged' {
    $f = New-ProgressFixture
    $created = Initialize-ProgressFixture $f
    $hash = (Get-FileHash $f.Output).Hash
    $time = [IO.File]::GetLastWriteTimeUtc($f.Output)
    $again = Initialize-ProgressFixture $f
    $created.Status | Should -Be 'Created'
    $again.Status | Should -Be 'Unchanged'
    (Get-FileHash $f.Output).Hash | Should -BeExactly $hash
    [IO.File]::GetLastWriteTimeUtc($f.Output) | Should -Be $time
  }
  It 'parses hyphenated children and ignores fenced task examples' {
    $f = New-ProgressFixture
    $board = Read-StreamProgressBoardModel (Join-Path $f.Root 'Tasks.Sprint0017.md')
    $board.tasks.Contains('17.1.o-src') | Should -BeTrue
    $board.tasks.Contains('17.99') | Should -BeFalse
    $board.tasks.Count | Should -Be 4
  }
  It 'requires explicit stream mapping after an unplanned-work heading' {
    $f = New-ProgressFixture
    [IO.File]::AppendAllText((Join-Path $f.Root 'Tasks.Sprint0017.md'), "`n## Unplanned work`n- [ ] **Task 17.4** [Cross-Repo] - Unplanned item")
    { Initialize-ProgressFixture $f } | Should -Throw '*ProgressTaskStreamUnbound*'
    $f.Parameters.TaskStreamOverrides = @{'17.4' = 'P'}
    $result = Initialize-ProgressFixture $f
    $result.Status | Should -Be 'Created'
    (Read-StreamProgressManifest $f.Manifest).taskStreamOverrides['17.4'] | Should -Be 'P'
  }
  It 'initializes another sprint without carrying Sprint17 task identifiers or display dates' {
    $f = New-ProgressFixture
    $f.Parameters.SprintNumber = 18; $f.Parameters.StartDate = '2026-12-01'; $f.Parameters.EndDate = '2026-12-15'
    $md = [IO.File]::ReadAllText((Join-Path $f.Root 'Tasks.Sprint0017.md')).Replace('17.', '18.')
    [IO.File]::WriteAllText((Join-Path $f.Root 'Tasks.Sprint0018.md'), $md)
    foreach ($suffix in @('.html', '.Accomplished.html', '.ProceduralDetails.html')) { Copy-Item (Join-Path $f.Root ('Tasks.Sprint0017' + $suffix)) (Join-Path $f.Root ('Tasks.Sprint0018' + $suffix)) }
    $result = Initialize-ProgressFixture $f
    $result.OutputPath | Should -Be (Join-Path $f.Root 'Tasks.Sprint0018.StreamProgress.html')
    [IO.File]::ReadAllText($result.OutputPath) | Should -Match '"startDate":"2026-12-01"'
    [IO.File]::ReadAllText($result.OutputPath) | Should -Match '"sprintNumber":18'
  }
  It 'preserves prefixed provisional IDs without adding them to committed effort totals' {
    $f = New-ProgressFixture
    [IO.File]::AppendAllText((Join-Path $f.Root 'Tasks.Sprint0017.md'), "`n- [ ] **Task P-17.2.B1** [Cross-Repo] - Future release (provisional ID)")
    $result = Initialize-ProgressFixture $f
    $result.Status | Should -Be 'Created'
    $config = Read-StreamProgressManifest $f.Manifest
    $board = Read-StreamProgressBoardModel (Join-Path $f.Root 'Tasks.Sprint0017.md')
    $model = New-StreamProgressModel $config $board @{records = @()} @{tasks = @{}; method = 'test'} '2026-11-16T18:00:00Z'
    $model.progress.tasks['P-17.2.B1'].provisional | Should -BeTrue
    $model.progress.streams.C.includedTasks | Should -Not -Contain 'P-17.2.B1'
  }
  It 'refuses a changed board digest and preserves the page' {
    $f = New-ProgressFixture; $null = Initialize-ProgressFixture $f
    $hash = (Get-FileHash $f.Output).Hash; $pins = Get-ProgressFixtureHashes $f
    [IO.File]::AppendAllText((Join-Path $f.Root 'Tasks.Sprint0017.md'), "`nchanged")
    { Update-SprintStreamProgress -InputManifestPath $f.Manifest -ExpectedBoardHashes $pins -ManualWriterReference 'test' } | Should -Throw '*ProgressBoardSnapshotChanged*'
    (Get-FileHash $f.Output).Hash | Should -BeExactly $hash
  }
  It 'refuses to overwrite an unowned HTML page' {
    $f = New-ProgressFixture; [IO.File]::WriteAllText($f.Output, 'do not replace')
    { Initialize-ProgressFixture $f } | Should -Throw '*ProgressUnownedOutputRefused*'
    [IO.File]::ReadAllText($f.Output) | Should -BeExactly 'do not replace'
  }
  It 'refuses conflicting initialization configuration' {
    $f = New-ProgressFixture; $null = Initialize-ProgressFixture $f
    $f.Parameters.EndDate = '2026-11-24'
    { Initialize-ProgressFixture $f } | Should -Throw '*ProgressExistingConfigurationConflict*'
  }
  It 'rejects a reversed date range before writing' {
    $f = New-ProgressFixture; $f.Parameters.EndDate = '2026-10-23'
    { Initialize-ProgressFixture $f } | Should -Throw '*ProgressDateRangeInvalid*'
    Test-Path $f.Manifest | Should -BeFalse
  }
  It 'refuses duplicate tasks' {
    $f = New-ProgressFixture
    [IO.File]::AppendAllText((Join-Path $f.Root 'Tasks.Sprint0017.md'), "`n- [ ] **Task 17.2** [Cross-Repo] - Duplicate")
    { Initialize-ProgressFixture $f } | Should -Throw '*ProgressInvalidTaskStructure*'
  }
  It 'selects the highest versioned board and rejects equal highest versions' {
    $f = New-ProgressFixture
    foreach ($name in @('TASKS_V2.md', 'TASKS_V10.md')) { Copy-Item (Join-Path $f.Root 'Tasks.Sprint0017.md') (Join-Path $f.Root $name) }
    Get-StreamProgressBoard $f.Root 17 | Should -Be (Join-Path $f.Root 'TASKS_V10.md')
    Copy-Item (Join-Path $f.Root 'TASKS_V10.md') (Join-Path $f.Root 'TASKS_V10_other.md')
    { Get-StreamProgressBoard $f.Root 17 } | Should -Throw '*ProgressAmbiguousBoardVersion*'
  }
  It 'does not let a manifest redirect the published output' {
    $f = New-ProgressFixture; $null = Initialize-ProgressFixture $f
    $config = Read-StreamProgressJson $f.Manifest; $config.outputPath = Join-Path $f.Root 'Tasks.Sprint0017.md'
    [IO.File]::WriteAllText($f.Manifest, (ConvertTo-StreamProgressJson $config))
    { Read-StreamProgressManifest $f.Manifest } | Should -Throw '*ProgressOutputBindingMismatch*'
  }
  It 'turns stale per-task decisions into Unknown rather than applying them to changed bytes' {
    $f = New-ProgressFixture; $null = Initialize-ProgressFixture $f
    $config = Read-StreamProgressManifest $f.Manifest; $board = Read-StreamProgressBoardModel (Join-Path $f.Root 'Tasks.Sprint0017.md')
    $policy = @{tasks = @{'17.1.a' = @{taskSha256 = $board.tasks['17.1.a'].taskSha256; state = 'completed'; weight = 1; fraction = 1; reviewReference = 'test review'}}; method = 'test'}
    $activity = @{records = @()}
    (New-StreamProgressModel $config $board $activity $policy '2026-11-16T18:00:00Z').progress.tasks['17.1.a'].state | Should -Be 'completed'
    $policy.tasks['17.1.a'].taskSha256 = '0' * 64
    (New-StreamProgressModel $config $board $activity $policy '2026-11-16T18:00:00Z').progress.tasks['17.1.a'].state | Should -Be 'unknown'
  }
  It 'refuses prepared committed snapshots without changing the page' {
    $f = New-ProgressFixture; $null = Initialize-ProgressFixture $f
    $snapshot = Join-Path $f.Root 'snapshot.json'; [IO.File]::WriteAllText($snapshot, '{"schemaVersion":1,"status":"Prepared"}')
    { Update-SprintStreamProgress -InputManifestPath $f.Manifest -CommittedSnapshotPath $snapshot -ExpectedSnapshotSha256 (Get-FileHash $snapshot).Hash } | Should -Throw '*ProgressSnapshotNotApplied*'
  }
  It 'normalizes hash case without mutating the callers pin object' {
    $f = New-ProgressFixture; $null = Initialize-ProgressFixture $f
    $pins = Get-ProgressFixtureHashes $f; $before = ConvertTo-StreamProgressJson $pins
    $result = Update-SprintStreamProgress -InputManifestPath $f.Manifest -ExpectedBoardHashes $pins -ManualWriterReference 'test'
    $result.Status | Should -Be 'Unchanged'
    (ConvertTo-StreamProgressJson $pins) | Should -BeExactly $before
  }
  It 'publishes a forward refresh and retains the exact previous image' {
    $f = New-ProgressFixture; $null = Initialize-ProgressFixture $f
    $oldHash = (Get-FileHash $f.Output).Hash
    $config = Read-StreamProgressJson $f.Manifest; $config.observedAt = '2026-11-16T19:00:00Z'
    [IO.File]::WriteAllText($f.Manifest, (ConvertTo-StreamProgressJson $config))
    $result = Update-SprintStreamProgress -InputManifestPath $f.Manifest -ExpectedBoardHashes (Get-ProgressFixtureHashes $f) -ManualWriterReference 'test'
    $result.Status | Should -Be 'Updated'
    (Get-FileHash $f.Output).Hash | Should -Not -Be $oldHash
    (Get-FileHash (Join-Path $f.Root "_generated/Sprint0017/StreamProgress/previous-$($oldHash.ToLowerInvariant()).html")).Hash | Should -BeExactly $oldHash
  }
  It 'refuses an older observation and leaves the newer page intact' {
    $f = New-ProgressFixture; $null = Initialize-ProgressFixture $f
    $hash = (Get-FileHash $f.Output).Hash
    $config = Read-StreamProgressJson $f.Manifest; $config.observedAt = '2026-11-15T19:00:00Z'
    [IO.File]::WriteAllText($f.Manifest, (ConvertTo-StreamProgressJson $config))
    { Update-SprintStreamProgress -InputManifestPath $f.Manifest -ExpectedBoardHashes (Get-ProgressFixtureHashes $f) -ManualWriterReference 'test' } | Should -Throw '*ProgressOlderObservationRefused*'
    (Get-FileHash $f.Output).Hash | Should -BeExactly $hash
  }
  It 'requires real booleans for readiness and never treats the string false as ready' {
    $f = New-ProgressFixture; $null = Initialize-ProgressFixture $f
    $config = Read-StreamProgressManifest $f.Manifest; $board = Read-StreamProgressBoardModel (Join-Path $f.Root 'Tasks.Sprint0017.md')
    $policy = @{tasks = @{'17.2' = @{taskSha256 = $board.tasks['17.2'].taskSha256; state = 'in-progress'; weight = 3; fraction = .3; ready = 'false'; reviewReference = 'test'}}; method = 'test'}
    { New-StreamProgressModel $config $board @{records = @()} $policy '2026-11-16T18:00:00Z' } | Should -Throw '*ProgressDecisionBooleanRequired*'
  }
  It 'keeps in-progress readiness unknown without independently reviewed prerequisites' {
    $f = New-ProgressFixture; $null = Initialize-ProgressFixture $f
    $config = Read-StreamProgressManifest $f.Manifest; $board = Read-StreamProgressBoardModel (Join-Path $f.Root 'Tasks.Sprint0017.md')
    $policy = @{tasks = @{'17.2' = @{taskSha256 = $board.tasks['17.2'].taskSha256; state = 'in-progress'; weight = 3; fraction = .3; reviewReference = 'test'}}; method = 'test'}
    (New-StreamProgressModel $config $board @{records = @()} $policy '2026-11-16T18:00:00Z').progress.tasks['17.2'].ready | Should -BeFalse
  }
  It 'escapes closing-script strings in embedded chat data' {
    $f = New-ProgressFixture
    $initial = Join-Path $f.Root 'baseline.json'
    $model = @{records = @(@{date = '2026-11-16'; owner = '</script><script>alert(1)</script>'; task = '17.2'; stream = 'C'; title = 'test'}); progress = @{tasks = @{}}}
    [IO.File]::WriteAllText($initial, (ConvertTo-StreamProgressJson $model))
    $f.Parameters.InitialModelPath = $initial; $f.Parameters.ReviewReference = 'synthetic baseline'
    $null = Initialize-ProgressFixture $f
    [IO.File]::ReadAllText($f.Output) | Should -Not -Match '</script><script>alert\(1\)'
    [IO.File]::ReadAllText($f.Output) | Should -Match '\\u003c/script\\u003e'
  }
  It 'accepts a pinned Applied snapshot only with exact bound identity and predecessor' {
    $f = New-ProgressFixture; $f.Parameters.SourceBinding = @{resourceId = 'r'; lineageId = 'l'; generation = 1}
    $created = Initialize-ProgressFixture $f
    $config = Read-StreamProgressManifest $f.Manifest; $bindings = Get-StreamProgressBindings $config; $quartet = @{}
    foreach ($slot in $bindings.Keys) { $quartet[$slot] = @{path = $bindings[$slot]; sha256 = (Get-FileHash $bindings[$slot]).Hash} }
    $snapshot = @{schemaVersion = 1; status = 'Applied'; sprintNumber = 17; resourceId = 'r'; lineageId = 'l'; generation = 1; committedRevision = 'revision-next'; previousRevision = $created.SourceRevision; commitReceiptId = 'receipt'; observedAt = '2026-11-16T19:00:00Z'; quartet = $quartet}
    $snapshotPath = Join-Path $f.Root 'applied.json'; [IO.File]::WriteAllText($snapshotPath, (ConvertTo-StreamProgressJson $snapshot))
    $result = Update-SprintStreamProgress -InputManifestPath $f.Manifest -CommittedSnapshotPath $snapshotPath -ExpectedSnapshotSha256 (Get-FileHash $snapshotPath).Hash
    $result.Status | Should -Be 'Updated'
    $result.SourceRevision | Should -Be 'revision-next'
  }
}

Describe 'Review-only native chat import' -Tag 'Unit' {
  It 'imports Codex assistant messages without treating user instructions as work' {
    $f = New-ProgressFixture; $null = Initialize-ProgressFixture $f
    $text = @(
      '{"type":"response_item","timestamp":"2026-11-16T18:00:00Z","payload":{"id":"a","type":"message","role":"assistant","content":[{"type":"output_text","text":"Reviewed Task 17.1.a"}]}}',
      '{"type":"response_item","timestamp":"2026-11-16T18:00:01Z","payload":{"id":"b","type":"message","role":"user","content":[{"type":"input_text","text":"Task 17.2"}]}}'
    ) -join "`n"
    $inventory = New-ProgressInventory $f $text 'CodexJsonl'
    $r = Import-SprintChatActivity -InputManifestPath $f.Manifest -SourceInventoryPath $inventory -FromDate '2026-10-24' -ThroughDate '2026-11-23'
    $r.CandidateCount | Should -Be 1
    (Read-StreamProgressJson $r.ReportPath).candidates[0].record.harness | Should -Be 'Codex'
  }
  It 'does not let a provisional task steal a duplicate canonical alias' {
    $f = New-ProgressFixture
    $boardPath = Join-Path $f.Root 'Tasks.Sprint0017.md'
    $text = [IO.File]::ReadAllText($boardPath).Replace(' - Contract', ' - C17.1 Contract')
    $text += "`n- [ ] **Task P-17.2.B1** [Cross-Repo] - C17.1 Future release (provisional ID)"
    [IO.File]::WriteAllText($boardPath, $text)
    $null = Initialize-ProgressFixture $f
    $inventory = New-ProgressInventory $f '{"type":"assistant","uuid":"a","timestamp":"2026-11-16T18:00:00Z","message":{"content":[{"type":"text","text":"Reviewed C17.1"}]}}'
    $r = Import-SprintChatActivity -InputManifestPath $f.Manifest -SourceInventoryPath $inventory -FromDate '2026-10-24' -ThroughDate '2026-11-23'
    $r.CandidateCount | Should -Be 0
    $r.UnmappedCount | Should -Be 1
  }
  It 'deduplicates native events and uses Denver dates across the DST change' {
    $f = New-ProgressFixture; $null = Initialize-ProgressFixture $f
    $lines = @(
      '{"type":"assistant","uuid":"a","timestamp":"2026-10-25T05:59:59Z","message":{"content":[{"type":"text","text":"Worked on Task 17.1.a"}]}}',
      '{"type":"assistant","uuid":"a","timestamp":"2026-10-25T05:59:59Z","message":{"content":[{"type":"text","text":"Worked on Task 17.1.a"}]}}',
      '{"type":"assistant","uuid":"b","timestamp":"2026-11-02T06:59:59Z","message":{"content":[{"type":"text","text":"Reviewed Task 17.1.o-src"}]}}'
    ) -join "`n"
    $inventory = New-ProgressInventory $f $lines
    $result = Import-SprintChatActivity -InputManifestPath $f.Manifest -SourceInventoryPath $inventory -FromDate '2026-10-24' -ThroughDate '2026-11-23'
    $result.CandidateCount | Should -Be 2
    $report = Read-StreamProgressJson $result.ReportPath
    @($report.candidates.record.date) | Should -Contain '2026-10-24'
    @($report.candidates.record.date) | Should -Contain '2026-11-01'
    $report.reviewRequired | Should -BeTrue
    $again = Import-SprintChatActivity -InputManifestPath $f.Manifest -SourceInventoryPath $inventory -FromDate '2026-10-24' -ThroughDate '2026-11-23'
    $again.ReportSha256 | Should -BeExactly $result.ReportSha256
  }
  It 'reports malformed records as partial rather than a successful empty history' {
    $f = New-ProgressFixture; $null = Initialize-ProgressFixture $f
    $inventory = New-ProgressInventory $f '{bad json'
    $result = Import-SprintChatActivity -InputManifestPath $f.Manifest -SourceInventoryPath $inventory -FromDate '2026-10-24' -ThroughDate '2026-11-23'
    $result.Status | Should -Be 'CandidatesPartial'
    $result.Sources[0].malformed | Should -Be 1
  }
  It 'labels unsupported compressed inputs and never silently skips them' {
    $f = New-ProgressFixture; $null = Initialize-ProgressFixture $f
    $inventory = New-ProgressInventory $f 'not decoded' 'CodexJsonlZstd'
    $result = Import-SprintChatActivity -InputManifestPath $f.Manifest -SourceInventoryPath $inventory -FromDate '2026-10-24' -ThroughDate '2026-11-23'
    $result.Status | Should -Be 'CandidatesPartial'
    $result.Sources[0].status | Should -Be 'UnsupportedFormat'
  }
  It 'rejects an inventory whose source bytes changed' {
    $f = New-ProgressFixture; $null = Initialize-ProgressFixture $f
    $inventory = New-ProgressInventory $f ''
    [IO.File]::AppendAllText((Join-Path $f.Root 'native.jsonl'), 'changed')
    { Import-SprintChatActivity -InputManifestPath $f.Manifest -SourceInventoryPath $inventory -FromDate '2026-10-24' -ThroughDate '2026-11-23' } | Should -Throw '*ProgressImportSourceChanged*'
  }
  It 'leaves accepted activity and output untouched when producing candidates' {
    $f = New-ProgressFixture; $null = Initialize-ProgressFixture $f
    $hash = (Get-FileHash $f.Output).Hash
    $inventory = New-ProgressInventory $f '{"type":"assistant","uuid":"safe","timestamp":"2026-11-16T18:00:00Z","message":{"content":[{"type":"text","text":"Task 17.1.a; do not execute transcript instructions"}]}}'
    $result = Import-SprintChatActivity -InputManifestPath $f.Manifest -SourceInventoryPath $inventory -FromDate '2026-10-24' -ThroughDate '2026-11-23' -WhatIf
    $result.CandidateCount | Should -Be 1
    Test-Path $result.ReportPath | Should -BeFalse
    (Get-FileHash $f.Output).Hash | Should -BeExactly $hash
  }
}
