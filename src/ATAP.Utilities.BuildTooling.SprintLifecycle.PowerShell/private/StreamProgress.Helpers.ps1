function Get-StreamProgressModuleRoot {
  $module = $ExecutionContext.SessionState.Module
  $candidates = @($PSScriptRoot, [IO.Path]::GetDirectoryName($PSScriptRoot))
  if ($module) { $candidates = @($module.ModuleBase) + $candidates }
  foreach ($candidate in $candidates) {
    if ([IO.File]::Exists((Join-Path $candidate 'Resources/StreamProgress/input.schema.json'))) { return $candidate }
  }
  throw 'ProgressModuleResourcesMissing'
}

function Get-StreamProgressHash {
  param([Parameter(Mandatory)][AllowEmptyCollection()][byte[]]$Bytes)
  [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes)).ToLowerInvariant()
}

function Read-StreamProgressJson {
  param([Parameter(Mandatory)][string]$Path)
  $parameters = @{ InputObject = [IO.File]::ReadAllText($Path); AsHashtable = $true; Depth = 100; ErrorAction = 'Stop' }
  if ((Get-Command ConvertFrom-Json).Parameters.ContainsKey('DateKind')) { $parameters.DateKind = 'String' }
  ConvertFrom-Json @parameters
}

function ConvertTo-StreamProgressJson {
  param([Parameter(Mandatory)][AllowNull()]$Value)
  function Sort-StreamProgressValue($Item) {
    if ($Item -is [Collections.IDictionary]) {
      $result = [ordered]@{}
      [string[]]$keys = @($Item.Keys)
      [Array]::Sort($keys, [StringComparer]::Ordinal)
      foreach ($key in $keys) { $result[$key] = Sort-StreamProgressValue $Item[$key] }
      return $result
    }
    if ($Item -is [Collections.IEnumerable] -and $Item -isnot [string]) {
      return ,@(foreach ($part in $Item) { Sort-StreamProgressValue $part })
    }
    return $Item
  }
  ConvertTo-Json -InputObject (Sort-StreamProgressValue $Value) -Depth 100 -Compress
}

function Assert-StreamProgressPath {
  param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Root)
  if (-not [IO.Path]::IsPathFullyQualified($Path)) { throw 'ProgressPathMustBeAbsolute' }
  $full = [IO.Path]::GetFullPath($Path)
  $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
  if (-not $full.StartsWith($rootFull + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'ProgressPathOutsideRoot' }
  $ancestor = $full
  while ($ancestor) {
    if (Test-Path -LiteralPath $ancestor) {
      $item = Get-Item -LiteralPath $ancestor -Force -ErrorAction Stop
      if ($item.LinkType -in @('SymbolicLink', 'Junction', 'HardLink')) { throw 'ProgressLinkedPathRefused' }
    }
    $ancestor = [IO.Path]::GetDirectoryName($ancestor)
  }
  return $full
}

function Get-StreamProgressBoard {
  param([Parameter(Mandatory)][string]$PlanningRoot, [Parameter(Mandatory)][int]$SprintNumber)
  $versions = @(Get-ChildItem -LiteralPath $PlanningRoot -File -Filter '*.md' | Where-Object Name -Match '^TASKS_V' | ForEach-Object {
      if ($_.Name -notmatch '^TASKS_V([0-9]+).*\.md$') { throw 'ProgressInvalidBoardVersion' }
      [long]$version = 0
      if (-not [long]::TryParse($Matches[1], [ref]$version)) { throw 'ProgressInvalidBoardVersion' }
      [pscustomobject]@{ Path = $_.FullName; Version = $version }
    })
  if ($versions.Count) {
    $highest = ($versions | Measure-Object Version -Maximum).Maximum
    $selected = @($versions | Where-Object Version -EQ $highest)
    if ($selected.Count -ne 1) { throw 'ProgressAmbiguousBoardVersion' }
    return $selected[0].Path
  }
  $path = Join-Path $PlanningRoot ('Tasks.Sprint{0:D4}.md' -f $SprintNumber)
  if (-not [IO.File]::Exists($path)) { throw 'ProgressBoardMissing' }
  return $path
}

function Read-StreamProgressBoardModel {
  param([Parameter(Mandatory)][string]$Path, [Collections.IDictionary]$TaskStreamOverrides = @{})
  $tasks = [ordered]@{}; $streams = [Collections.Generic.List[object]]::new()
  $stream = $null; $task = $null; $fence = $null
  foreach ($line in ([IO.File]::ReadAllText($Path) -split '\r?\n')) {
    if ($line -match '^\s*(`{3,}|~{3,})(.*)$') {
      $marker = $Matches[1]; $suffix = $Matches[2]
      if (-not $fence) { $fence = $marker }
      elseif ($marker[0] -eq $fence[0] -and $marker.Length -ge $fence.Length -and -not $suffix.Trim()) { $fence = $null }
      continue
    }
    if ($fence) { continue }
    if ($line -match '^## Stream (\w+)\s*[-—]\s*(.+)$') {
      $stream = $Matches[1]; $task = $null
      if (@($streams | Where-Object id -CEQ $stream).Count) { throw 'ProgressDuplicateStream' }
      $streams.Add(@{ id = $stream; name = ($Matches[2] -replace '\s*\[.*$', '').Trim() })
      continue
    }
    if ($line -match '^#{1,2}\s') { $task = $null; $stream = $null }
    if ($line -match '^\s*- \[([ xX~])\] \*\*Task ([^*\s]+)\*\*\s*(?:\[[^\]]*\]\s*)?-\s*(.+)$') {
      $id = $Matches[2]
      if ($tasks.Contains($id)) { throw 'ProgressInvalidTaskStructure' }
      $taskStream = if ($stream) { $stream } else { $TaskStreamOverrides[$id] }
      if (-not $taskStream) { throw ('ProgressTaskStreamUnbound: ' + $id) }
      $task = @{ id = $id; stream = $taskStream; streamMappedBy = if ($stream) { 'Heading' } else { 'Override' }; title = $Matches[3]; checked = $Matches[1] -in @('x', 'X'); status = ''; text = $line }
      $tasks[$id] = $task
    }
    elseif ($task) {
      $task.text += "`n$line"
      if ($line -match '^\s+- Status:\s*(.+)$') { $task.status = $Matches[1] }
    }
  }
  foreach ($item in $tasks.Values) {
    if ($item.stream -cnotin $streams.id) { throw 'ProgressUnknownStreamOverride' }
    $item['taskSha256'] = Get-StreamProgressHash ([Text.Encoding]::UTF8.GetBytes($item.text))
  }
  @{ streams = @($streams.ToArray()); tasks = $tasks }
}

function Read-StreamProgressManifest {
  param([Parameter(Mandatory)][string]$Path)
  $config = Read-StreamProgressJson $Path
  $schema = Join-Path (Get-StreamProgressModuleRoot) 'Resources/StreamProgress/input.schema.json'
  if (-not (Test-Json -Json ([IO.File]::ReadAllText($Path)) -SchemaFile $schema -ErrorAction Stop)) { throw 'ProgressManifestInvalid' }
  $root = [IO.Path]::GetFullPath($config.planningRoot)
  $null = Assert-StreamProgressPath $Path $root
  $expected = Join-Path $root ('Tasks.Sprint{0:D4}.StreamProgress.html' -f [int]$config.sprintNumber)
  if (-not [string]::Equals($config.outputPath, $expected, [StringComparison]::OrdinalIgnoreCase)) { throw 'ProgressOutputBindingMismatch' }
  $null = Assert-StreamProgressPath $config.outputPath $root
  $durable = Join-Path $root ('InformationForTheFuture/Sprint{0:D4}/StreamProgress' -f [int]$config.sprintNumber)
  foreach ($key in @('activityPath', 'policyPath')) { $null = Assert-StreamProgressPath $config[$key] $durable }
  $null = [TimeZoneInfo]::FindSystemTimeZoneById($config.timeZoneId)
  $start = [DateOnly]::ParseExact($config.startDate, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
  $end = [DateOnly]::ParseExact($config.endDate, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
  if ($end -lt $start -or $end.DayNumber - $start.DayNumber -gt 366) { throw 'ProgressDateRangeInvalid' }
  return $config
}

function Get-StreamProgressBindings {
  param([Parameter(Mandatory)]$Config)
  $root = $Config.planningRoot; $n = [int]$Config.sprintNumber
  [ordered]@{
    markdown = Get-StreamProgressBoard $root $n
    boardHtml = Join-Path $root ('Tasks.Sprint{0:D4}.html' -f $n)
    accomplishedHtml = Join-Path $root ('Tasks.Sprint{0:D4}.Accomplished.html' -f $n)
    proceduralDetailsHtml = Join-Path $root ('Tasks.Sprint{0:D4}.ProceduralDetails.html' -f $n)
  }
}

function New-StreamProgressModel {
  param([Parameter(Mandatory)]$Config, [Parameter(Mandatory)]$Board, [Parameter(Mandatory)]$Activity,
    [Parameter(Mandatory)]$Policy, [Parameter(Mandatory)][string]$ObservedAt)
  $progressTasks = [ordered]@{}
  foreach ($task in $Board.tasks.Values) {
    if ($task.id -cnotmatch ('^(?:P-)?' + [regex]::Escape([string]$Config.sprintNumber) + '\.')) { throw 'ProgressTaskSprintMismatch' }
    $decision = $Policy.tasks[$task.id]
    $fresh = $decision -and $decision.taskSha256 -ceq $task.taskSha256
    $state = if ($fresh) { [string]$decision.state } else { 'unknown' }
    if ($state -notin @('completed', 'in-progress', 'blocked', 'unknown')) { throw 'ProgressInvalidStatusDecision' }
    if ($decision) {
      foreach ($field in @('deferred', 'ready', 'selected', 'prerequisitesSatisfied')) {
        if ($decision.Contains($field) -and $decision[$field] -isnot [bool]) { throw 'ProgressDecisionBooleanRequired' }
      }
      if ($fresh -and $state -ne 'unknown' -and -not $decision.reviewReference) { throw 'ProgressDecisionReviewRequired' }
    }
    $weight = if ($decision) { [double]$decision.weight } else { 3.0 }
    $fraction = if ($fresh) { [double]$decision.fraction } else { 0.0 }
    if ($weight -le 0 -or $weight -gt 100 -or $fraction -lt 0 -or $fraction -gt 1 -or [double]::IsNaN($fraction) -or [double]::IsNaN($weight)) { throw 'ProgressInvalidEstimate' }
    if ($state -eq 'completed' -and ($fraction -ne 1 -or -not $task.checked)) { throw 'ProgressCompletionConflict' }
    $progressTasks[$task.id] = @{
      id = $task.id; stream = $task.stream; title = $task.title; status = $task.status; state = $state
      weight = $weight; fraction = $fraction; totalPoints = $weight; donePoints = [math]::Round($weight * $fraction, 2)
      remainingPoints = [math]::Round($weight * (1 - $fraction), 2)
      deferred = [bool]($fresh -and $decision.deferred)
      provisional = [bool]($task.title -match '\bprovisional ID\b')
      ready = [bool]($fresh -and $decision.ready -and $decision.prerequisitesSatisfied -and $decision.selected -and $state -eq 'in-progress' -and -not $decision.deferred)
      basis = if ($fresh) { $decision.basis } else { 'No current reviewed decision for these exact task bytes. Status and readiness unknown.' }
      latestActivity = $null; taskSha256 = $task.taskSha256
    }
  }
  $records = @($Activity.records)
  foreach ($record in $records) {
    foreach ($field in @('date', 'owner', 'task', 'stream')) {
      if ($record[$field] -isnot [string] -or -not $record[$field]) { throw 'ProgressActivityInvalid' }
    }
    if ($record.Contains('evidence') -and $record.evidence -isnot [array]) { throw 'ProgressActivityEvidenceInvalid' }
    $null = [DateOnly]::ParseExact([string]$record.date, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
    if ($progressTasks.Contains($record.task)) {
      $current = $progressTasks[$record.task]
      if ($record.stream -cne $current.stream) { throw 'ProgressActivityStreamMismatch' }
      if (-not $current.latestActivity -or $record.date -gt $current.latestActivity) { $current.latestActivity = $record.date }
    }
  }
  $progressStreams = [ordered]@{}
  foreach ($stream in $Board.streams) {
    $all = @($progressTasks.Values | Where-Object stream -CEQ $stream.id)
    $leaves = @($all | Where-Object { $id = $_.id; -not @($all | Where-Object { $_.id.StartsWith($id + '.', [StringComparison]::Ordinal) }).Count })
    $selected = @($leaves | Where-Object { -not $_.deferred -and -not $_.provisional })
    $poolOnly = $selected.Count -eq 0
    if ($poolOnly) { $selected = $leaves }
    $total = [double](($selected | Measure-Object totalPoints -Sum).Sum)
    $done = [double](($selected | Measure-Object donePoints -Sum).Sum)
    $progressStreams[$stream.id] = @{
      percent = if ($total) { [int][math]::Round(100 * $done / $total) } else { 0 }
      totalPoints = $total; donePoints = [math]::Round($done, 1); remainingPoints = [math]::Round($total - $done, 1)
      poolOnly = $poolOnly; scope = if ($poolOnly) { 'Prospective pool scope; not a committed delivery target' } else { 'Selected leaf scope; deferred leaves excluded' }
      includedTasks = @($selected.id); excludedTasks = @($leaves | Where-Object { $_.id -notin $selected.id } | ForEach-Object id)
      note = $Policy.method
    }
  }
  @{
    streams = @($Board.streams); records = $records; generated = $ObservedAt
    metadata = @{ sprintNumber = $Config.sprintNumber; startDate = $Config.startDate; endDate = $Config.endDate; timeZoneId = $Config.timeZoneId }
    codexAudit = $Activity.codexAudit; claudeAudit = $Activity.claudeAudit
    streamInfo = $Policy.streamInfo
    progress = @{ asOf = $ObservedAt; tasks = $progressTasks; streams = $progressStreams; method = $Policy.method }
  }
}
