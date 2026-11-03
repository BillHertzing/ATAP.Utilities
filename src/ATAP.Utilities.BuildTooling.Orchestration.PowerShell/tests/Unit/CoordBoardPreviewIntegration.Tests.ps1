param(
  [Parameter()]
  [ValidateNotNullOrEmpty()]
  [string]$FixtureRoot = (Join-Path ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))) '_generated/Sprint0017/CloseStreams/C1618/PreviewIntegration')
)

# Integration test: a GENUINE Read-CoordBoard snapshot is passed straight into the
# GENUINE New-CoordBoardChange, and the genuine output bytes are read back through
# Read-CoordBoard. Neither helper is mocked; only PSFramework logging is mocked.
# FixtureRoot stays beneath this repository's _generated directory.

BeforeAll {
  $null = Get-Command -Name 'Write-PSFMessage' -ErrorAction Stop
  $allowedRoot = Join-Path ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))) '_generated'
  if (-not [System.IO.Path]::IsPathFullyQualified($FixtureRoot)) {
    throw 'FixtureRoot must be an explicit absolute repository-generated directory.'
  }
  $resolvedRoot = [System.IO.Path]::GetFullPath($FixtureRoot).TrimEnd('\')
  if (-not ($resolvedRoot.Equals($allowedRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
      $resolvedRoot.StartsWith($allowedRoot + '\', [System.StringComparison]::OrdinalIgnoreCase))) {
    throw "FixtureRoot must be $allowedRoot or beneath it."
  }
  $script:fixtureBase = Join-Path $resolvedRoot ([guid]::NewGuid().ToString('N'))
  $null = New-Item -ItemType Directory -Path $script:fixtureBase -Force

  $script:sourceReader1618 = Join-Path $PSScriptRoot '../../private/Read-CoordBoard.ps1'
  $private1618 = Join-Path $script:fixtureBase 'ModuleCopy/private'
  $null = New-Item -ItemType Directory -Path $private1618 -Force
  $script:readerCopy1618 = Join-Path $private1618 'Read-CoordBoard.ps1'
  Copy-Item -LiteralPath $script:sourceReader1618 -Destination $script:readerCopy1618
  Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../../private/New-CoordBoardChange.ps1') -Destination $private1618
  . $script:readerCopy1618
  . (Join-Path $private1618 'New-CoordBoardChange.ps1')

  $script:utf8 = [System.Text.UTF8Encoding]::new($false, $true)
  $script:oldStatus = 'Planned.'
  $script:annotation = 'CLAIMED / source-ready; holder=Senior1; claim=C-one.'
  $script:headings = @(
    '- [ ] **Task 17.26** [ATAP.Utilities] - Parent fixture',
    '- [ ] **Task 17.26.a** - Child stays open',
    '- [x] **Task 17.27** - Historical completed fixture'
  )
  $script:boardTextLf = @(
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

  function New-IntegrationDirectory {
    $directory = Join-Path $script:fixtureBase ([guid]::NewGuid().ToString('N'))
    $null = New-Item -ItemType Directory -Path $directory
    $directory
  }

  function Write-IntegrationBoard {
    param([string]$Directory, [byte[]]$Bytes)
    $path = Join-Path $Directory 'Tasks.Sprint0017.md'
    [System.IO.File]::WriteAllBytes($path, $Bytes)
    $path
  }

  function ConvertTo-BoardElement {
    param($Value)
    $document = [System.Text.Json.JsonDocument]::Parse((ConvertTo-Json -InputObject $Value -Depth 100 -Compress))
    try { $document.RootElement.Clone() } finally { $document.Dispose() }
  }

  function Get-HexSlice {
    param([byte[]]$Bytes, [int]$Offset, [int]$Count)
    [System.Convert]::ToHexString($Bytes, $Offset, $Count)
  }

  # TRUSTED-CALLER ASSUMPTIONS, NOT AUTHORITY PROOF. These synthetic request, Applied
  # report and private context values are shaped the way a trusted caller would bind
  # them (reused from the New-CoordBoardChange unit test). They are not authentic
  # receipts, grants, evidence or live admission; only the snapshot is genuine.
  function New-TrustedCallerInputs {
    param([PSCustomObject]$Snapshot, [hashtable]$ApprovedChange)
    $evidence = @(
      [ordered]@{ reference = 'synthetic-evidence-A'; digest = [ordered]@{ algorithm = 'SHA256'; value = '0' * 64 } },
      [ordered]@{ reference = 'synthetic-evidence-B'; digest = [ordered]@{ algorithm = 'SHA256'; value = '1' * 64 } }
    )
    $scope = @([ordered]@{ registeredRootId = 'root-u'; path = 'src/Owned.ps1' })
    $holder = [ordered]@{ holderId = 'Senior1'; sessionId = 'session-A' }
    $request = [ordered]@{
      protocolVersion = 'Coordination-v1'; resourceId = 'board-S17'; sprintId = '0017'
      requestId = 'A-one'; category = 'AcceptChange'; taskId = '17.26'
      scope = $scope; holder = $holder; authorizationReference = 'synthetic-coordinator-approval'
      generation = 'epoch-A'; expectedRevision = 'head-current'; predecessors = @('R-one')
      payload = [ordered]@{ reportRequestId = 'R-one'; evidence = $evidence; approvedChange = $ApprovedChange }
    }
    $reportRequest = [ordered]@{
      protocolVersion = 'Coordination-v1'; resourceId = 'board-S17'; sprintId = '0017'
      requestId = 'R-one'; category = 'ReportResult'; taskId = '17.26'
      scope = $scope; holder = $holder; authorizationReference = 'synthetic-prior-report-approval'
      generation = 'epoch-A'; expectedRevision = 'head-historical'; predecessors = @()
      payload = [ordered]@{ claimId = 'C-one'; outcome = 'source-ready'; evidence = $evidence; statedLimits = 'Synthetic source evidence only.' }
    }
    $report = [ordered]@{
      request = $reportRequest; digest = '2' * 64; originalRequestJson = (ConvertTo-Json -InputObject $reportRequest -Depth 20 -Compress)
      queueOrdinal = '1'; status = 'Applied'; preparedOperationId = 'synthetic-operation'
      terminalEvidence = [ordered]@{
        resourceId = 'board-S17'; requestId = 'R-one'; digest = '2' * 64
        status = 'Applied'; reason = 'Synthetic'
        receipt = [ordered]@{ reference = 'synthetic-receipt'; digest = '3' * 64 }
      }
    }
    $context = [ordered]@{
      coordinatorId = 'coordinator-fixture'; resourceId = 'board-S17'; sprintId = '0017'
      generation = 'epoch-A'; committedRevision = 'head-current'; taskId = '17.26'
      authorizationReference = 'synthetic-coordinator-approval'; holder = $holder; scope = $scope
      claimId = 'C-one'; reportRequestId = 'R-one'; reportDigest = '2' * 64; evidence = $evidence
      snapshotSha256 = $Snapshot.Sha256
      snapshotParserSha256 = (Get-FileHash -LiteralPath $script:readerCopy1618 -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    # An older unpublished reservation survives even though its task is not on the board.
    $reservations = @([ordered]@{
      reservationId = 'older-reservation'; resourceId = 'board-S17'; requestId = 'older-request'
      taskId = '99.1'; scope = $scope; generation = 'epoch-older'
    })
    @{ Request = $request; Report = $report; Context = $context; Reservations = $reservations }
  }

  function Invoke-IntegrationPreview {
    param([PSCustomObject]$Snapshot, [hashtable]$Inputs)
    New-CoordBoardChange -Snapshot $Snapshot `
      -Request (ConvertTo-BoardElement $Inputs.Request) `
      -AppliedReport (ConvertTo-BoardElement $Inputs.Report) `
      -Context (ConvertTo-BoardElement $Inputs.Context) `
      -Reservations (ConvertTo-BoardElement $Inputs.Reservations)
  }

  function Test-PositiveRoundTrip {
    param([string]$Text, [bool]$Bom)
    $inputBytes = $script:utf8.GetBytes($(if ($Bom) { [string][char]0xFEFF + $Text } else { $Text }))
    $inputDirectory = New-IntegrationDirectory
    $inputPath = Write-IntegrationBoard -Directory $inputDirectory -Bytes $inputBytes

    # Genuine snapshot straight from the genuine reader; nothing is fabricated.
    $snapshot = Read-CoordBoard -PlanningRoot $inputDirectory -SprintNumber 17
    $snapshot.HasUtf8Bom | Should -Be $Bom
    $beforeBytes = [byte[]]$snapshot.RawBytes.Clone()
    $beforeText = $snapshot.Text
    $beforeSha = $snapshot.Sha256
    $beforeTasksJson = ConvertTo-Json -InputObject $snapshot.Tasks -Depth 5 -Compress

    $inputs = New-TrustedCallerInputs -Snapshot $snapshot -ApprovedChange @{ annotation = $script:annotation }
    $reservationJson = (ConvertTo-BoardElement $inputs.Reservations).GetRawText()
    $preview = Invoke-IntegrationPreview -Snapshot $snapshot -Inputs $inputs

    # Genuine output bytes go to a separate generated directory and back through the genuine reader.
    $outputDirectory = New-IntegrationDirectory
    $null = Write-IntegrationBoard -Directory $outputDirectory -Bytes $preview.AfterBytes
    $after = Read-CoordBoard -PlanningRoot $outputDirectory -SprintNumber 17

    $preview.Stage | Should -BeExactly 'ProposedNotPrepared'
    $preview.BeforeSha256 | Should -BeExactly $beforeSha
    $after.Sha256 | Should -BeExactly $preview.AfterSha256
    [System.Convert]::ToHexString($after.RawBytes) | Should -BeExactly ([System.Convert]::ToHexString($preview.AfterBytes))

    # IDs, their order, checkboxes, BOM and line-ending kinds are preserved.
    (($after.Tasks | ForEach-Object { $_.Id }) -join ',') | Should -BeExactly '17.26,17.26.a,17.27'
    (($after.Tasks | ForEach-Object { $_.Id }) -join ',') | Should -BeExactly (($snapshot.Tasks | ForEach-Object { $_.Id }) -join ',')
    (($after.Tasks | ForEach-Object { $_.Checkbox }) -join '|') | Should -BeExactly ' | |x'
    (($after.Tasks | ForEach-Object { $_.Checkbox }) -join '|') | Should -BeExactly (($snapshot.Tasks | ForEach-Object { $_.Checkbox }) -join '|')
    $after.HasUtf8Bom | Should -Be $Bom
    ($after.NewLineKinds -join ',') | Should -BeExactly ($snapshot.NewLineKinds -join ',')
    $after.HasFinalNewLine | Should -Be $snapshot.HasFinalNewLine
    $after.Tasks[2].Text | Should -BeExactly $snapshot.Tasks[2].Text
    $after.Tasks[1].Text | Should -BeExactly $snapshot.Tasks[1].Text
    $after.Tasks[0].Heading | Should -BeExactly $snapshot.Tasks[0].Heading

    # Only the Status value changes: bytes before and after the annotation are identical.
    $prefix = '  - Status: '
    $start = $beforeText.IndexOf($prefix + $script:oldStatus, [System.StringComparison]::Ordinal) + $prefix.Length
    $start | Should -BeGreaterThan 0
    $startBytes = $script:utf8.GetByteCount($beforeText.Substring(0, $start))
    $oldBytes = $script:utf8.GetByteCount($script:oldStatus)
    $newBytes = $script:utf8.GetByteCount($script:annotation)
    $after.Text.Substring($start, $script:annotation.Length) | Should -BeExactly $script:annotation
    (Get-HexSlice $after.RawBytes 0 $startBytes) | Should -BeExactly (Get-HexSlice $beforeBytes 0 $startBytes)
    $tailLength = $beforeBytes.Length - $startBytes - $oldBytes
    (Get-HexSlice $after.RawBytes ($startBytes + $newBytes) $tailLength) | Should -BeExactly (Get-HexSlice $beforeBytes ($startBytes + $oldBytes) $tailLength)
    $after.RawBytes.Length | Should -Be ($beforeBytes.Length - $oldBytes + $newBytes)

    # Original snapshot, input file and reservations are unchanged.
    $snapshot.Text | Should -BeExactly $beforeText
    $snapshot.Sha256 | Should -BeExactly $beforeSha
    [System.Convert]::ToHexString($snapshot.RawBytes) | Should -BeExactly ([System.Convert]::ToHexString($beforeBytes))
    (ConvertTo-Json -InputObject $snapshot.Tasks -Depth 5 -Compress) | Should -BeExactly $beforeTasksJson
    [System.Convert]::ToHexString([System.IO.File]::ReadAllBytes($inputPath)) | Should -BeExactly ([System.Convert]::ToHexString($beforeBytes))
    $preview.Reservations.GetRawText() | Should -BeExactly $reservationJson
    (ConvertTo-BoardElement $inputs.Reservations).GetRawText() | Should -BeExactly $reservationJson
  }

  function Assert-GenuineConsumerStatus292 {
    param([string]$Path, [string]$ExpectedTarget)
    # Explicit frozen consumer contract, not a shared production classifier.
    $modulePath = 'C:/Program Files/PowerShell/Modules/ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell/0.1.60/ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell.psm1'
    $manifestPath = [IO.Path]::ChangeExtension($modulePath, '.psd1')
    (Get-FileHash -LiteralPath $modulePath -Algorithm SHA256).Hash | Should -BeExactly '5DAED847D11AE6142C1D9FC8F8ABB0CB50618865EE827B9B8A122A6A570C3D3E'
    (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash | Should -BeExactly 'F4AD6EC0A3E1DFD73E77F4915F275CE4B5656AF39039ED349E7F0A30F56564F3'
    Import-Module -Name $manifestPath -RequiredVersion 0.1.60 -ErrorAction Stop
    $consumer = Get-Command -Name Convert-TasksMdToSprintBoard -Module ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell -CommandType Function -ErrorAction Stop
    $consumer.Module.Version.ToString() | Should -BeExactly '0.1.60'
    $consumer.Module.Path.Replace('\', '/') | Should -Be $modulePath
    $output = [IO.Path]::ChangeExtension($Path, '.html')
    $result = & $consumer -TasksFilePath $Path -OutputPath $output -WhatIf:$true -Confirm:$false
    $result.TaskCount | Should -Be 2
    foreach ($status in @('open', 'partial', 'closed')) {
      # Hand-declared target category plus the unchanged [x] control.
      $expected = $(if ($status -eq 'closed') { 1 } else { 0 }) + $(if ($status -eq $ExpectedTarget) { 1 } else { 0 })
      $result.StatusCounts.PSObject.Properties[$status].Value | Should -Be $expected
    }
    Test-Path -LiteralPath $output | Should -BeFalse
  }
}

Describe 'Read-CoordBoard to New-CoordBoardChange integration' -Tag 'Unit' {
  BeforeEach {
    Mock Write-PSFMessage {}
    Copy-Item -LiteralPath $script:sourceReader1618 -Destination $script:readerCopy1618 -Force
  }

  It 'round-trips annotation using adjacent <Reader> code and truthful file identity' -Tag 'ParserIdentity1618' -ForEach @(
    @{ Reader = 'source' }, @{ Reader = 'signed014' }
  ) {
    if ($Reader -eq 'signed014') {
      Copy-Item -LiteralPath 'C:/Program Files/PowerShell/Modules/ATAP.Utilities.BuildTooling.Orchestration.PowerShell/0.1.4/private/Read-CoordBoard.ps1' -Destination $script:readerCopy1618 -Force
    }
    . $script:readerCopy1618
    $directory = New-IntegrationDirectory
    $inputPath = Write-IntegrationBoard -Directory $directory -Bytes ($script:utf8.GetBytes($script:boardTextLf))
    $snapshot = Read-CoordBoard -PlanningRoot $directory -SprintNumber 17
    $inputs = New-TrustedCallerInputs -Snapshot $snapshot -ApprovedChange @{ annotation = $script:annotation }
    $actual = (Get-FileHash -LiteralPath $script:readerCopy1618 -Algorithm SHA256).Hash.ToLowerInvariant()
    $inputs.Context.snapshotParserSha256 | Should -BeExactly $actual
    if ($Reader -eq 'signed014') { $actual | Should -BeExactly '345a33e5816f559a53b704f81d0e6fb3aa27baf74c310f7d60a90e79498c73e1' }
    $preview = Invoke-IntegrationPreview -Snapshot $snapshot -Inputs $inputs
    $preview.Stage | Should -BeExactly 'ProposedNotPrepared'
    $outputDirectory = New-IntegrationDirectory
    $null = Write-IntegrationBoard -Directory $outputDirectory -Bytes $preview.AfterBytes
    $after = Read-CoordBoard -PlanningRoot $outputDirectory -SprintNumber 17
    $after.Text | Should -BeExactly $script:boardTextLf.Replace('  - Status: Planned.', '  - Status: ' + $script:annotation)
    ($after.Tasks.Id -join '|') | Should -BeExactly ($snapshot.Tasks.Id -join '|')
    ($after.Tasks.Checkbox -join '|') | Should -BeExactly ($snapshot.Tasks.Checkbox -join '|')
    [Convert]::ToBase64String([IO.File]::ReadAllBytes($inputPath)) | Should -BeExactly ([Convert]::ToBase64String($snapshot.RawBytes))
  }

  It 'CoordBoardPreviewIntegration_LfInput_RoundTripsAnnotationAndPreservesEverythingElse' {
    Test-PositiveRoundTrip -Text $script:boardTextLf -Bom $false
  }

  It 'CoordBoardPreviewIntegration_BomCrlfInput_RoundTripsAnnotationAndPreservesEverythingElse' {
    # BOM-first-task CRLF board: the first line is the task heading, preceded by U+FEFF.
    $firstTask = $script:boardTextLf.Substring($script:boardTextLf.IndexOf($script:headings[0], [System.StringComparison]::Ordinal))
    Test-PositiveRoundTrip -Text $firstTask.Replace([string][char]10, [string][char]13 + [char]10) -Bom $true
  }

  It 'CoordBoardPreviewIntegration_UnsupportedCheckboxOperation_IsRefusedWithoutMutation' {
    $inputDirectory = New-IntegrationDirectory
    $inputPath = Write-IntegrationBoard -Directory $inputDirectory -Bytes ($script:utf8.GetBytes($script:boardTextLf))
    $snapshot = Read-CoordBoard -PlanningRoot $inputDirectory -SprintNumber 17
    $beforeBytes = [byte[]]$snapshot.RawBytes.Clone()
    $beforeTasksJson = ConvertTo-Json -InputObject $snapshot.Tasks -Depth 5 -Compress
    $inputs = New-TrustedCallerInputs -Snapshot $snapshot -ApprovedChange @{ checkbox = 'x' }
    $reservationJson = (ConvertTo-BoardElement $inputs.Reservations).GetRawText()

    { Invoke-IntegrationPreview -Snapshot $snapshot -Inputs $inputs } | Should -Throw '*UnsupportedChange*'

    [System.Convert]::ToHexString($snapshot.RawBytes) | Should -BeExactly ([System.Convert]::ToHexString($beforeBytes))
    (ConvertTo-Json -InputObject $snapshot.Tasks -Depth 5 -Compress) | Should -BeExactly $beforeTasksJson
    [System.Convert]::ToHexString([System.IO.File]::ReadAllBytes($inputPath)) | Should -BeExactly ([System.Convert]::ToHexString($beforeBytes))
    @(Get-ChildItem -LiteralPath $inputDirectory -Force).Count | Should -Be 1
    (ConvertTo-BoardElement $inputs.Reservations).GetRawText() | Should -BeExactly $reservationJson
  }

  It 'preserves genuine consumer category or refuses the delta <Label>' -ForEach @(
    @{ Label = 'open-to-blocked'; Checkbox = ' '; Before = 'Planned.'; Annotation = 'Blocked; awaiting evidence.'; BeforeCategory = 'open'; AfterCategory = 'partial'; Allowed = $false },
    @{ Label = 'unblocked-substring'; Checkbox = ' '; Before = 'Planned.'; Annotation = 'Unblocked; ready for review.'; BeforeCategory = 'open'; AfterCategory = 'partial'; Allowed = $false },
    @{ Label = 'in-progress'; Checkbox = ' '; Before = 'Planned.'; Annotation = 'In-progress; awaiting evidence.'; BeforeCategory = 'open'; AfterCategory = 'partial'; Allowed = $false },
    @{ Label = 'formatted-blocked'; Checkbox = ' '; Before = 'bl**oc**ked'; Annotation = 'Ready for review.'; BeforeCategory = 'partial'; AfterCategory = 'open'; Allowed = $false },
    @{ Label = 'backtick-blocked'; Checkbox = ' '; Before = 'bl`oc`ked'; Annotation = 'Ready for review.'; BeforeCategory = 'partial'; AfterCategory = 'open'; Allowed = $false },
    @{ Label = 'partial-to-open'; Checkbox = ' '; Before = 'Partial; work started.'; Annotation = 'Ready for review.'; BeforeCategory = 'partial'; AfterCategory = 'open'; Allowed = $false },
    @{ Label = 'partial-stays-partial'; Checkbox = ' '; Before = 'Partial; work started.'; Annotation = 'Blocked; awaiting evidence.'; BeforeCategory = 'partial'; AfterCategory = 'partial'; Allowed = $true },
    @{ Label = 'open-stays-open'; Checkbox = ' '; Before = 'Planned.'; Annotation = 'Ready for review.'; BeforeCategory = 'open'; AfterCategory = 'open'; Allowed = $true },
    @{ Label = 'tilde-priority'; Checkbox = '~'; Before = 'Blocked; awaiting evidence.'; Annotation = 'Ready for review.'; BeforeCategory = 'partial'; AfterCategory = 'partial'; Allowed = $true },
    @{ Label = 'closed-priority'; Checkbox = 'x'; Before = 'Partial; work started.'; Annotation = 'Ready for review.'; BeforeCategory = 'closed'; AfterCategory = 'closed'; Allowed = $true },
    @{ Label = 'uppercase-closed-priority'; Checkbox = 'X'; Before = 'Planned.'; Annotation = 'Blocked; awaiting evidence.'; BeforeCategory = 'closed'; AfterCategory = 'closed'; Allowed = $true }
  ) {
    $text = (@('# Current Sprint: Sprint0017 category fixture', 'Source: synthetic D only', '',
      '## Goal', 'Preserve derived task categories.', '', '## Stream C - Coordination', '',
      ('- [' + $Checkbox + '] **Task 17.26** [ATAP.Utilities] - Target'),
      ('  - Status: ' + $Before), '', '- [x] **Task 17.27** [ATAP.Utilities] - Control',
      '  - Status: Historical control.', '') -join [char]10)
    $inputDirectory = New-IntegrationDirectory
    $inputPath = Write-IntegrationBoard -Directory $inputDirectory -Bytes ($script:utf8.GetBytes($text))
    $snapshot = Read-CoordBoard -PlanningRoot $inputDirectory -SprintNumber 17
    $beforeBytes = [Convert]::ToHexString($snapshot.RawBytes)
    $beforeTasks = ConvertTo-Json -InputObject $snapshot.Tasks -Depth 5 -Compress
    $inputs = New-TrustedCallerInputs -Snapshot $snapshot -ApprovedChange @{ annotation = $Annotation }
    $reservations = (ConvertTo-BoardElement $inputs.Reservations).GetRawText()
    Assert-GenuineConsumerStatus292 $inputPath $BeforeCategory
    $expectedText = $text.Replace(('  - Status: ' + $Before), ('  - Status: ' + $Annotation))
    $outputDirectory = New-IntegrationDirectory
    if ($Allowed) {
      $preview = Invoke-IntegrationPreview -Snapshot $snapshot -Inputs $inputs
      $preview.Stage | Should -BeExactly 'ProposedNotPrepared'
      $outputPath = Write-IntegrationBoard -Directory $outputDirectory -Bytes $preview.AfterBytes
      $after = Read-CoordBoard -PlanningRoot $outputDirectory -SprintNumber 17
      $after.Text | Should -BeExactly $expectedText
      ($after.Tasks.Id -join '|') | Should -BeExactly ($snapshot.Tasks.Id -join '|')
      ($after.Tasks.Checkbox -join '|') | Should -BeExactly ($snapshot.Tasks.Checkbox -join '|')
      $preview.Reservations.GetRawText() | Should -BeExactly $reservations
    } else {
      { Invoke-IntegrationPreview -Snapshot $snapshot -Inputs $inputs } | Should -Throw '*UnsupportedChange*'
      # Deliberate counterfactual input proves the attempted text changes the genuine
      # consumer category. These bytes are not output from the refused preview.
      $outputPath = Write-IntegrationBoard -Directory $outputDirectory -Bytes ($script:utf8.GetBytes($expectedText))
    }
    Assert-GenuineConsumerStatus292 $outputPath $AfterCategory
    [Convert]::ToHexString([IO.File]::ReadAllBytes($inputPath)) | Should -BeExactly $beforeBytes
    [Convert]::ToHexString($snapshot.RawBytes) | Should -BeExactly $beforeBytes
    $snapshot.Text | Should -BeExactly $text
    (ConvertTo-Json -InputObject $snapshot.Tasks -Depth 5 -Compress) | Should -BeExactly $beforeTasks
    (ConvertTo-BoardElement $inputs.Reservations).GetRawText() | Should -BeExactly $reservations
  }

  It 'refuses continued Status grammar while genuine consumer retains partial' {
    $text = (@('# Current Sprint: Sprint0017 continuation fixture', '', '## Goal', 'Bound continued fields.', '',
      '## Stream C - Coordination', '', '- [ ] **Task 17.26** [ATAP.Utilities] - Target',
      '  - Status: Planned.', '    Blocked; awaiting evidence.', '',
      '- [x] **Task 17.27** [ATAP.Utilities] - Control', '  - Status: Historical control.', '') -join [char]10)
    $directory = New-IntegrationDirectory
    $path = Write-IntegrationBoard -Directory $directory -Bytes ($script:utf8.GetBytes($text))
    $snapshot = Read-CoordBoard -PlanningRoot $directory -SprintNumber 17
    $inputs = New-TrustedCallerInputs -Snapshot $snapshot -ApprovedChange @{ annotation = 'Ready for review.' }
    Assert-GenuineConsumerStatus292 $path 'partial'
    { Invoke-IntegrationPreview -Snapshot $snapshot -Inputs $inputs } | Should -Throw '*UnsupportedChange*'
    $counterfactual = $text.Replace('  - Status: Planned.', '  - Status: Ready for review.')
    $other = Write-IntegrationBoard -Directory (New-IntegrationDirectory) -Bytes ($script:utf8.GetBytes($counterfactual))
    Assert-GenuineConsumerStatus292 $other 'partial'
    $snapshot.Text | Should -BeExactly $text
    [IO.File]::ReadAllText($path, $script:utf8) | Should -BeExactly $text
  }
}
