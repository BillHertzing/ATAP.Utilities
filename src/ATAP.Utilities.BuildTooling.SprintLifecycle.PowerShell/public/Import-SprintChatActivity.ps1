function Import-SprintChatActivity {
  <#
  .SYNOPSIS
    Produces review candidates from a pinned inventory of local chat histories.
  .DESCRIPTION
    Supports Claude JSONL, Codex JSONL and normalized activity JSON. Compressed
    histories are explicitly UnsupportedFormat. Does not install a decoder,
    invoke an LLM, promote candidates, change the page or execute transcript text.
    Rereading unchanged input is deterministic; source checkpoints are digest-bound
    whole-file snapshots in v1, not append-offset continuation.
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [Parameter(Mandatory)][string]$InputManifestPath,
    [Parameter(Mandatory)][string]$SourceInventoryPath,
    [Parameter(Mandatory)][string]$FromDate,
    [Parameter(Mandatory)][string]$ThroughDate
  )
  begin {
    $fn = 'Import-SprintChatActivity'; $mn = 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell'
    $null = Get-Command Write-PSFMessage -ErrorAction Stop
    if (-not (Get-Command Read-StreamProgressManifest -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot '../private/StreamProgress.Helpers.ps1') }
  }
  process {
    try {
      $config = Read-StreamProgressManifest $InputManifestPath
      $from = [DateOnly]::ParseExact($FromDate, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
      $through = [DateOnly]::ParseExact($ThroughDate, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
      if ($through -lt $from -or $through.DayNumber - $from.DayNumber -gt 366) { throw 'ProgressImportRangeInvalid' }
      $zone = [TimeZoneInfo]::FindSystemTimeZoneById($config.timeZoneId)
      $inventory = Read-StreamProgressJson $SourceInventoryPath
      if ($inventory.schemaVersion -ne 1 -or $inventory.sources -isnot [array]) { throw 'ProgressInventoryInvalid' }
      $board = Read-StreamProgressBoardModel (Get-StreamProgressBoard $config.planningRoot ([int]$config.sprintNumber)) $config.taskStreamOverrides
      $aliases = @{}
      foreach ($task in $board.tasks.Values) {
        if ($task.title -match '^([A-Z]+[0-9]+\.[\w.-]+)\s') {
          $alias = $Matches[1]
          if ($aliases.ContainsKey($alias) -and $aliases[$alias] -cne $task.id) { $aliases[$alias] = $null }
          elseif (-not $aliases.ContainsKey($alias)) { $aliases[$alias] = $task.id }
        }
      }
      $candidates = [Collections.Generic.List[object]]::new()
      $unmapped = [Collections.Generic.List[object]]::new()
      $coverage = [Collections.Generic.List[object]]::new()
      $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
      foreach ($source in $inventory.sources) {
        if (-not [IO.Path]::IsPathFullyQualified([string]$source.path) -or -not $source.sessionId -or -not $source.title -or $source.sha256 -notmatch '^[a-fA-F0-9]{64}$') { throw 'ProgressInventorySourceInvalid' }
        if ((Get-FileHash -LiteralPath $source.path -Algorithm SHA256 -ErrorAction Stop).Hash -ine $source.sha256) { throw 'ProgressImportSourceChanged' }
        $sourceCoverage = @{ path = $source.path; sha256 = $source.sha256; sessionId = $source.sessionId; status = 'Read'; lines = 0; malformed = 0; candidateCount = 0 }
        if ($source.path.EndsWith('.zst', [StringComparison]::OrdinalIgnoreCase) -or $source.format -notin @('ClaudeJsonl', 'CodexJsonl', 'Normalized')) {
          $sourceCoverage.status = 'UnsupportedFormat'; $coverage.Add($sourceCoverage); continue
        }
        if ($source.format -eq 'Normalized') {
          $normalized = Read-StreamProgressJson $source.path
          $rows = if ($normalized -is [array]) { $normalized } else { $normalized.records }
          if ($rows -isnot [array]) { throw 'ProgressNormalizedSourceInvalid' }
          foreach ($row in $rows) {
            if (-not $row.date -or -not $row.task -or -not $row.owner) { throw 'ProgressNormalizedRecordInvalid' }
            $date = [DateOnly]::ParseExact([string]$row.date, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
            if ($date -lt $from -or $date -gt $through) { continue }
            $eventId = Get-StreamProgressHash ([Text.Encoding]::UTF8.GetBytes((ConvertTo-StreamProgressJson $row)))
            if ($seen.Add($eventId)) {
              $candidates.Add(@{ eventId = $eventId; reviewState = 'Candidate'; dateKind = 'ImportedRecord'; record = $row; source = $source.path; sourceSha256 = $source.sha256 })
              $sourceCoverage.candidateCount++
            }
          }
        } else {
          $stream = [IO.File]::Open($source.path, 'Open', 'Read', 'Read')
          try {
            $reader = [IO.StreamReader]::new($stream, [Text.UTF8Encoding]::new($false, $true), $true, 65536, $true)
            try {
              while ($null -ne ($line = $reader.ReadLine())) {
                $sourceCoverage.lines++
                try {
                  $parameters = @{ InputObject = $line; AsHashtable = $true; Depth = 100; ErrorAction = 'Stop' }
                  if ((Get-Command ConvertFrom-Json).Parameters.ContainsKey('DateKind')) { $parameters.DateKind = 'String' }
                  $entry = ConvertFrom-Json @parameters
                } catch { $sourceCoverage.malformed++; continue }
                $message = $null; $timestamp = $entry.timestamp; $nativeId = $entry.uuid
                if ($source.format -eq 'ClaudeJsonl' -and $entry.type -ceq 'assistant') { $message = $entry.message }
                if ($source.format -eq 'CodexJsonl' -and $entry.type -ceq 'response_item' -and $entry.payload.type -ceq 'message' -and $entry.payload.role -ceq 'assistant') { $message = $entry.payload }
                if (-not $message) { continue }
                if ([string]$timestamp -notmatch '(?:Z|[+-][0-9]{2}:[0-9]{2})$') { $sourceCoverage.malformed++; continue }
                try { $stamp = [DateTimeOffset]::Parse([string]$timestamp, [Globalization.CultureInfo]::InvariantCulture) } catch { $sourceCoverage.malformed++; continue }
                $date = [TimeZoneInfo]::ConvertTime($stamp, $zone).ToString('yyyy-MM-dd')
                if ($date -clt $FromDate -or $date -cgt $ThroughDate) { continue }
                $text = if ($message.content -is [string]) { $message.content } else { @($message.content | Where-Object { $_.type -in @('text', 'output_text') } | ForEach-Object { $_.text }) -join "`n" }
                if (-not $nativeId) { $nativeId = $message.id }
                if (-not $nativeId) { $nativeId = Get-StreamProgressHash ([Text.Encoding]::UTF8.GetBytes([string]$timestamp + '|' + [string]$text)) }
                $ids = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
                foreach ($match in [regex]::Matches([string]$text, '(?<![A-Za-z0-9])(?:Task\s*)?((?:P-)?[0-9]+\.[a-zA-Z0-9.-]+)')) {
                  $id = $match.Groups[1].Value.TrimEnd('.', ',')
                  if ($board.tasks.Contains($id)) { $null = $ids.Add($id) }
                }
                foreach ($alias in $aliases.Keys) { if ($aliases[$alias] -and [regex]::IsMatch([string]$text, '\b' + [regex]::Escape($alias) + '(?![\w.-])')) { $null = $ids.Add($aliases[$alias]) } }
                if (-not $ids.Count) { $unmapped.Add(@{ sessionId = $source.sessionId; date = $date; source = $source.path; line = $sourceCoverage.lines; reason = 'NoExplicitTaskId' }); continue }
                foreach ($id in $ids) {
                  $eventId = Get-StreamProgressHash ([Text.Encoding]::UTF8.GetBytes($source.sessionId + '|' + $nativeId + '|' + $id))
                  if ($seen.Add($eventId)) {
                    $candidates.Add(@{
                      eventId = $eventId; reviewState = 'Candidate'; source = $source.path; sourceSha256 = $source.sha256; line = $sourceCoverage.lines
                      record = @{ date = $date; task = $id; stream = $board.tasks[$id].stream; title = $board.tasks[$id].title; owner = $source.title; session = $source.sessionId; harness = if ($source.format -eq 'ClaudeJsonl') { 'Claude' } else { 'Codex' }; timestamp = [string]$timestamp }
                      dateKind = 'NativeAssistantMessage'; mapping = 'ExplicitIdCandidate'; nativeEventId = $nativeId
                    })
                    $sourceCoverage.candidateCount++
                  }
                }
              }
            } finally { $reader.Dispose() }
          } finally { $stream.Dispose() }
        }
        if ((Get-FileHash -LiteralPath $source.path -Algorithm SHA256).Hash -ine $source.sha256) { throw 'ProgressImportSourceChanged' }
        if ($sourceCoverage.malformed) { $sourceCoverage.status = 'Partial' }
        $coverage.Add($sourceCoverage)
      }
      $report = @{ schemaVersion = 1; fromDate = $FromDate; throughDate = $ThroughDate; timeZoneId = $config.timeZoneId; candidates = @($candidates.ToArray()); unmapped = @($unmapped.ToArray()); sources = @($coverage.ToArray()); reviewRequired = $true }
      $json = ConvertTo-StreamProgressJson $report
      $hash = Get-StreamProgressHash ([Text.Encoding]::UTF8.GetBytes($json))
      $output = Join-Path $config.planningRoot ('_generated/Sprint{0:D4}/StreamProgress/import-{1}.json' -f [int]$config.sprintNumber, $hash)
      $null = Assert-StreamProgressPath $output $config.planningRoot
      if ($PSCmdlet.ShouldProcess($output, 'Write review candidates; leave accepted activity and page unchanged')) {
        $null = [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($output))
        if (-not [IO.File]::Exists($output)) { [IO.File]::WriteAllText($output, $json, [Text.UTF8Encoding]::new($false)) }
      }
      $status = if (@($coverage | Where-Object status -NE 'Read').Count) { 'CandidatesPartial' } else { 'CandidatesReady' }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Produced review-only chat activity candidates'
      [pscustomobject]@{ Status = $status; CandidateCount = $candidates.Count; UnmappedCount = $unmapped.Count; ReviewRequired = $true; ReportPath = $output; ReportSha256 = $hash; Sources = @($coverage.ToArray()) }
    } catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message ('Chat import refused: ' + $_.Exception.Message)
      throw
    }
  }
}
