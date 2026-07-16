function Convert-TasksMdToSprintBoard {
  <#
  .SYNOPSIS
    Generates a sprint TASKS.html board from the authoritative TASKS.md file.
  .DESCRIPTION
    Parses the sprint markdown task file used in the _Planning worktree and emits
    a browser-friendly HTML board containing the same stream/task structure. The
    cmdlet preserves `**Task N.M** [Repo]` markers in the markdown source while
    generating `const STREAMS` data for the board.
  .PARAMETER TasksFilePath
    Path to the authoritative sprint TASKS.md file.
  .PARAMETER OutputPath
    Optional path for the generated TASKS.html file. Defaults to a sibling
    `TASKS.html` next to `TasksFilePath`.
  .OUTPUTS
    System.Management.Automation.PSCustomObject
  .EXAMPLE
    Convert-TasksMdToSprintBoard -TasksFilePath 'C:\Dropbox\whertzing\GitHub\_Planning-wt-16-Sprint-0008-work-items\TASKS.md'
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$TasksFilePath,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$OutputPath
  )

  begin {
    $fn = 'Convert-TasksMdToSprintBoard'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    function Convert-TasksMdToSprintBoardInlineText {
      param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text
      )

      $normalized = ($Text -replace '\s+', ' ').Trim()
      $normalized = $normalized -replace '\*\*(.+?)\*\*', '$1'
      $normalized = $normalized -replace '`(.+?)`', '$1'
      return $normalized
    }

    function Convert-TasksMdToSprintBoardInlineHtml {
      param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text
      )

      $encoded = [System.Net.WebUtility]::HtmlEncode(($Text -replace '\s+', ' ').Trim())
      $encoded = [regex]::Replace($encoded, '\*\*(.+?)\*\*', '<b>$1</b>')
      $encoded = [regex]::Replace($encoded, '`(.+?)`', '<code>$1</code>')
      return $encoded
    }

    function Convert-TasksMdToSprintBoardMarkdownBlockToHtml {
      param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$Lines
      )

      $htmlLines = [System.Collections.Generic.List[string]]::new()
      $paragraph = [System.Collections.Generic.List[string]]::new()
      $listType = $null

      function Flush-Paragraph {
        if ($paragraph.Count -gt 0) {
          $htmlLines.Add('<p>' + (Convert-TasksMdToSprintBoardInlineHtml -Text ($paragraph -join ' ')) + '</p>')
          $paragraph.Clear()
        }
      }

      function Close-List {
        if ($listType) {
          $htmlLines.Add("</$listType>")
          Set-Variable -Name listType -Value $null -Scope 1
        }
      }

      foreach ($line in $Lines) {
        $trimmed = $line.Trim()

        if (-not $trimmed) {
          Flush-Paragraph
          Close-List
          continue
        }

        if ($trimmed -match '^\d+\.\s+(?<content>.+)$') {
          Flush-Paragraph
          if ($listType -ne 'ol') {
            Close-List
            $htmlLines.Add('<ol>')
            $listType = 'ol'
          }
          $htmlLines.Add('<li>' + (Convert-TasksMdToSprintBoardInlineHtml -Text $Matches['content']) + '</li>')
          continue
        }

        if ($trimmed -match '^- (?<content>.+)$') {
          Flush-Paragraph
          if ($listType -ne 'ul') {
            Close-List
            $htmlLines.Add('<ul>')
            $listType = 'ul'
          }
          $htmlLines.Add('<li>' + (Convert-TasksMdToSprintBoardInlineHtml -Text $Matches['content']) + '</li>')
          continue
        }

        Close-List
        $paragraph.Add($trimmed)
      }

      Flush-Paragraph
      Close-List

      return ($htmlLines -join [Environment]::NewLine)
    }

    function Get-TasksMdToSprintBoardTaskFields {
      param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$Lines,

        [Parameter()]
        [AllowEmptyString()]
        [string]$TaskId
      )

      $fields = [ordered]@{}
      $currentLabel = $null
      $currentDisplayLabel = $null
      $currentValue = [System.Collections.Generic.List[string]]::new()

      function Save-CurrentTaskField {
        if ($currentLabel) {
          $fields[$currentLabel] = (Convert-TasksMdToSprintBoardInlineText -Text ($currentValue -join ' '))
          if ($currentLabel -eq 'Evidence' -and $currentDisplayLabel) {
            $fields['EvidenceLabel'] = $currentDisplayLabel
          }
        }
      }

      foreach ($line in $Lines) {
        if ($line -match '^\s{2,}-\s+(?<label>Files|Do|Acceptance|Status):\s*(?<value>.*)$') {
          Save-CurrentTaskField
          $currentLabel = $Matches['label']
          $currentDisplayLabel = "$($Matches['label']):"
          $currentValue.Clear()
          if ($Matches['value']) {
            $currentValue.Add($Matches['value'].Trim())
          }
          continue
        }

        if ($line -match '^\s{2,}-\s+Evidence(?<suffix>\s+(?:\([^)]+\)|[^:]+))?:\s*(?<value>.*)$') {
          Save-CurrentTaskField
          $currentLabel = 'Evidence'
          $currentDisplayLabel = ('Evidence' + ($Matches['suffix'] ?? '') + ':').Trim()
          $currentValue.Clear()
          if ($Matches['value']) {
            $currentValue.Add($Matches['value'].Trim())
          }
          continue
        }

        if ($line -match '^\s{2,}-\s+Evidence\b') {
          $taskPrefix = if ([string]::IsNullOrWhiteSpace($TaskId)) { 'task with unknown id' } else { "task $TaskId" }
          Write-Warning "Could not parse Evidence-like bullet for ${taskPrefix}: $($line.Trim())"
          continue
        }

        # A continuation is a wrapped line of the current field's value, never a new
        # list item. Excluding bullet lines (`- `) stops unrecognized bullets such as
        # `Symptom:`, `Evidence (<date>):`, or `See:` from bleeding into the prior
        # field — important now that indented subtasks carry such bullets.
        if ($currentLabel -and $line -notmatch '^\s*-\s' -and $line -match '^\s{4,}(?<value>\S.*)$') {
          $currentValue.Add($Matches['value'].Trim())
        }
      }

      Save-CurrentTaskField

      return [PSCustomObject]$fields
    }

    function Get-TasksMdToSprintBoardExistingTaskMap {
      param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ExistingOutputPath
      )

      $taskMap = @{}
      if (-not (Test-Path -LiteralPath $ExistingOutputPath -PathType Leaf)) {
        return $taskMap
      }

      try {
        $existingHtml = Get-Content -LiteralPath $ExistingOutputPath -Raw -Encoding UTF8
        $jsonMatch = [regex]::Match(
          $existingHtml,
          'const STREAMS=(?<json>.*?);\r?\nfunction esc',
          [System.Text.RegularExpressions.RegexOptions]::Singleline)
        if (-not $jsonMatch.Success) {
          Write-Warning "Could not inspect existing sprint board for resolution reconciliation: '$ExistingOutputPath' does not contain a recognizable STREAMS block."
          return $taskMap
        }

        $existingStreams = $jsonMatch.Groups['json'].Value | ConvertFrom-Json
        foreach ($existingStream in @($existingStreams)) {
          foreach ($existingTask in @($existingStream.tasks)) {
            if ($null -ne $existingTask -and -not [string]::IsNullOrWhiteSpace($existingTask.id)) {
              $taskMap[[string]$existingTask.id] = $existingTask
            }
          }
        }
      } catch {
        Write-Warning "Could not inspect existing sprint board for resolution reconciliation: $($_.Exception.Message)"
      }

      return $taskMap
    }

    function New-TasksMdToSprintBoardReconciliationReportPath {
      param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$GeneratedBoardPath
      )

      $boardDirectory = Split-Path -Path $GeneratedBoardPath -Parent
      $generatedDirectory = Join-Path $boardDirectory '_generated'
      $baseName = [System.IO.Path]::GetFileNameWithoutExtension($GeneratedBoardPath)
      return (Join-Path $generatedDirectory "$baseName.EvidenceReconciliation.json")
    }

    function Get-TasksMdToSprintBoardSlice {
      param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$Lines,

        [Parameter(Mandatory)]
        [int]$StartIndex,

        [Parameter(Mandatory)]
        [int]$EndIndex
      )

      if (-not $Lines -or $Lines.Count -eq 0) {
        return @()
      }

      $safeStart = [Math]::Max(0, $StartIndex)
      $safeEnd = [Math]::Min($Lines.Count - 1, $EndIndex)
      if ($safeStart -gt $safeEnd) {
        return @()
      }

      return @($Lines[$safeStart..$safeEnd])
    }
  }

  process {
    try {
      $resolvedTasksFilePath = (Resolve-Path -LiteralPath $TasksFilePath -ErrorAction Stop).ProviderPath
      if (-not $PSBoundParameters.ContainsKey('OutputPath') -or [string]::IsNullOrWhiteSpace($OutputPath)) {
        $OutputPath = Join-Path (Split-Path -Path $resolvedTasksFilePath -Parent) 'TASKS.html'
      }
      $resolvedOutputPath = [System.IO.Path]::GetFullPath($OutputPath)
      $tasksFileName = [System.IO.Path]::GetFileName($resolvedTasksFilePath)
      $outputFileName = [System.IO.Path]::GetFileName($resolvedOutputPath)

      $rawText = Get-Content -LiteralPath $resolvedTasksFilePath -Raw -Encoding UTF8
      $lines = Get-Content -LiteralPath $resolvedTasksFilePath -Encoding UTF8

      $titleLine = $lines | Where-Object { $_ -match '^# Current Sprint:\s+' } | Select-Object -First 1
      if (-not $titleLine) {
        throw "Could not find '# Current Sprint:' heading in '$resolvedTasksFilePath'."
      }
      $pageTitle = ($titleLine -replace '^# Current Sprint:\s*', '').Trim()

      $sourceLine = $lines | Where-Object { $_ -match '^Source:\s+' } | Select-Object -First 1
      $lastUpdatedLine = $lines | Where-Object { $_ -match '^Last updated:\s+' } | Select-Object -First 1

      $goalStart = [Array]::IndexOf($lines, '## Goal')
      if ($goalStart -lt 0) {
        throw "Could not find '## Goal' section in '$resolvedTasksFilePath'."
      }

      $firstStreamStart = -1
      for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^## Stream ') {
          $firstStreamStart = $i
          break
        }
      }
      if ($firstStreamStart -lt 0) {
        throw "Could not find any '## Stream' sections in '$resolvedTasksFilePath'."
      }

      $goalLines = Get-TasksMdToSprintBoardSlice -Lines $lines -StartIndex ($goalStart + 1) -EndIndex ($firstStreamStart - 1)
      $missionHtml = Convert-TasksMdToSprintBoardMarkdownBlockToHtml -Lines $goalLines

      $streamStarts = for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^## Stream ') { $i }
      }

      $streams = [System.Collections.Generic.List[object]]::new()
      $allTasks = [System.Collections.Generic.List[object]]::new()

      for ($streamIndex = 0; $streamIndex -lt $streamStarts.Count; $streamIndex++) {
        $startIndex = $streamStarts[$streamIndex]
        $endIndex = if ($streamIndex + 1 -lt $streamStarts.Count) { $streamStarts[$streamIndex + 1] - 1 } else { $lines.Count - 1 }
        $streamLines = Get-TasksMdToSprintBoardSlice -Lines $lines -StartIndex $startIndex -EndIndex $endIndex

        $streamHeader = $streamLines[0]
        if ($streamHeader -notmatch '^## Stream (?<id>[A-Za-z0-9]+)\s+[–-]\s+(?<name>.+?)(?:\s+\[(?<tag>[^\]]+)\])?$') {
          throw "Could not parse stream header '$streamHeader'."
        }

        $streamId = $Matches['id']
        $streamName = $Matches['name'].Trim()
        $streamTag = $Matches['tag']

        # Match both top-level task lines (column 0) and indented lettered subtask
        # lines (e.g. `  - [x] **Task 10.14.a**`). Allowing optional leading whitespace
        # ensures nested subtasks become their own board entries instead of being
        # absorbed into the umbrella task's detail block.
        $taskLineIndices = for ($i = 1; $i -lt $streamLines.Count; $i++) {
          if ($streamLines[$i] -match '^\s*- \[[ x~]\] \*\*Task ') { $i }
        }

        $purposeLines = if ($taskLineIndices.Count -gt 0) {
          @(Get-TasksMdToSprintBoardSlice -Lines $streamLines -StartIndex 1 -EndIndex ($taskLineIndices[0] - 1) | Where-Object { $_.Trim() })
        } else {
          @(Get-TasksMdToSprintBoardSlice -Lines $streamLines -StartIndex 1 -EndIndex ($streamLines.Count - 1) | Where-Object { $_.Trim() })
        }
        $purposeText = Convert-TasksMdToSprintBoardInlineText -Text ($purposeLines -join ' ')

        $streamTasks = [System.Collections.Generic.List[object]]::new()

        # Remember the most recent umbrella (top-level) task's repo so lettered
        # subtasks, which omit the [Repo] tag, can inherit it.
        $umbrellaRepo = ''

        for ($taskIndex = 0; $taskIndex -lt $taskLineIndices.Count; $taskIndex++) {
          $taskStart = $taskLineIndices[$taskIndex]
          $taskEnd = if ($taskIndex + 1 -lt $taskLineIndices.Count) { $taskLineIndices[$taskIndex + 1] - 1 } else { $streamLines.Count - 1 }
          $taskLines = @(Get-TasksMdToSprintBoardSlice -Lines $streamLines -StartIndex $taskStart -EndIndex $taskEnd)

          $taskHeader = $taskLines[0]
          # Leading whitespace is optional (indented subtasks); the [Repo] tag is
          # optional because lettered subtasks omit it and inherit the umbrella's repo.
          # extraTags allows optional **bold** wrapping (e.g. **[HITL]**) in addition to
          # plain [tag] — the board convention bolds human-in-the-loop gate markers.
          if ($taskHeader -notmatch '^\s*- \[(?<checked>[ x~])\] \*\*Task (?<id>[^*]+)\*\*(?:\s+\[(?<repo>[^\]]+)\])?(?<extraTags>(?:\s+\*{0,2}\[[^\]]+\]\*{0,2})*)\s+[–-]\s+(?<title>.+)$') {
            throw "Could not parse task header '$taskHeader'."
          }

          $taskId = $Matches['id'].Trim()
          if ($Matches['repo']) {
            $taskRepo = $Matches['repo'].Trim()
            $umbrellaRepo = $taskRepo
          } else {
            $taskRepo = $umbrellaRepo
          }
          $taskTitle = $Matches['title'].Trim()
          if ($Matches['extraTags']) {
            $taskTitle = ($taskTitle + $Matches['extraTags']).Trim()
          }

          # @() wrapper required: a task with zero detail lines makes the slice's empty
          # pipeline output collapse to $null on assignment, and $null fails to bind to
          # the next call's mandatory -Lines parameter (Task 12.34).
          $taskDetailLines = @(Get-TasksMdToSprintBoardSlice -Lines $taskLines -StartIndex 1 -EndIndex ($taskLines.Count - 1))
          $taskFields = Get-TasksMdToSprintBoardTaskFields -Lines $taskDetailLines -TaskId $taskId

          $taskStatus = if ($Matches['checked'] -eq 'x') {
            'closed'
          } elseif ($Matches['checked'] -eq '~') {
            'partial'
          } elseif ($taskFields.PSObject.Properties.Name -contains 'Status' -and $taskFields.Status -match 'partial|blocked|in-progress') {
            'partial'
          } else {
            'open'
          }

          $resolution = $null
          if ($taskFields.PSObject.Properties.Name -contains 'Status') {
            $resolution = $taskFields.Status
          }
          if ($taskFields.PSObject.Properties.Name -contains 'Evidence') {
            $evidenceLabel = if ($taskFields.PSObject.Properties.Name -contains 'EvidenceLabel') { $taskFields.EvidenceLabel } else { 'Evidence:' }
            $evidenceText = "$evidenceLabel $($taskFields.Evidence)"
            $resolution = if ($resolution) { "$resolution $evidenceText" } else { $evidenceText }
          }

          $task = [PSCustomObject]@{
            id = $taskId
            status = $taskStatus
            title = $taskTitle
            repo = $taskRepo
            scope = if ($taskFields.PSObject.Properties.Name -contains 'Files') { $taskFields.Files } else { $null }
            acc = if ($taskFields.PSObject.Properties.Name -contains 'Acceptance') { $taskFields.Acceptance } else { $null }
            res = $resolution
          }

          $streamTasks.Add($task)
          $allTasks.Add($task)
        }

        $streams.Add([PSCustomObject]@{
            id = $streamId
            name = $streamName
            tag = $streamTag
            purpose = $purposeText
            tasks = @($streamTasks)
          })
      }

      $lostResolutionRecords = [System.Collections.Generic.List[object]]::new()
      $existingTaskMap = Get-TasksMdToSprintBoardExistingTaskMap -ExistingOutputPath $resolvedOutputPath
      foreach ($task in $allTasks) {
        if (-not $existingTaskMap.ContainsKey($task.id)) {
          continue
        }

        $existingTask = $existingTaskMap[$task.id]
        $existingResolution = if ($null -ne $existingTask.PSObject.Properties['res']) { [string]$existingTask.res } else { $null }
        if (-not [string]::IsNullOrWhiteSpace($existingResolution) -and [string]::IsNullOrWhiteSpace([string]$task.res)) {
          $lostResolutionRecords.Add([PSCustomObject]@{
              TaskId = $task.id
              ExistingRes = $existingResolution
              GeneratedRes = $task.res
            })
        }
      }

      $reconciliationReportPath = $null
      if ($lostResolutionRecords.Count -gt 0) {
        $reconciliationReportPath = New-TasksMdToSprintBoardReconciliationReportPath -GeneratedBoardPath $resolvedOutputPath
        Write-Warning "Existing sprint board resolution text would be lost for $($lostResolutionRecords.Count) task(s). Reconciliation report: $reconciliationReportPath"
      }

      $streamsJson = $streams | ConvertTo-Json -Depth 8
      $generatedDate = Get-Date -Format 'yyyy-MM-dd'
      $sourceText = if ($sourceLine) { Convert-TasksMdToSprintBoardInlineHtml -Text ($sourceLine -replace '^Source:\s*', '') } else { 'Unknown source' }
      $lastUpdatedText = if ($lastUpdatedLine) { Convert-TasksMdToSprintBoardInlineHtml -Text ($lastUpdatedLine -replace '^Last updated:\s*', '') } else { 'No last-updated line recorded' }
      $subtitle = "$sourceText · $lastUpdatedText · <span class=""mono"">$([System.Net.WebUtility]::HtmlEncode($outputFileName))</span> generated from authoritative <span class=""mono"">$([System.Net.WebUtility]::HtmlEncode($tasksFileName))</span>"

      $htmlTemplate = @'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>@@PAGE_TITLE@@</title>
<style>
  :root{
    --bg:#0f1419; --panel:#1a2230; --panel2:#222c3c; --line:#2f3c50;
    --ink:#e7edf5; --muted:#9fb0c4; --accent:#4ea1ff;
    --open:#e0564a; --open-bg:#3a1f1d;
    --partial:#e2a83b; --partial-bg:#3a2f17;
    --closed:#46c073; --closed-bg:#16331f;
    --chip:#2b3a4f;
  }
  *{box-sizing:border-box}
  html{scroll-behavior:smooth}
  body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.55 -apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif}
  a{color:var(--accent);text-decoration:none} a:hover{text-decoration:underline}
  header.top{position:sticky;top:0;z-index:20;background:linear-gradient(180deg,#10171f,#0f1419);border-bottom:1px solid var(--line);padding:14px 24px}
  header.top h1{margin:0 0 4px;font-size:20px}
  header.top .sub{color:var(--muted);font-size:13px}
  .wrap{max-width:1180px;margin:0 auto;padding:24px}
  .toolbar{display:flex;flex-wrap:wrap;gap:10px;align-items:center;margin-top:10px}
  .toolbar input[type=search]{flex:1 1 240px;min-width:180px;background:var(--panel);border:1px solid var(--line);color:var(--ink);border-radius:8px;padding:8px 12px;font-size:14px}
  .filterbtn{cursor:pointer;user-select:none;border:1px solid var(--line);background:var(--panel);color:var(--ink);border-radius:20px;padding:6px 14px;font-size:13px;font-weight:600}
  .filterbtn.active{background:var(--accent);border-color:var(--accent);color:#06121f}
  .summary{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:12px;margin:18px 0 6px}
  .stat{background:var(--panel);border:1px solid var(--line);border-radius:10px;padding:14px 16px}
  .stat .n{font-size:26px;font-weight:700}
  .stat .l{font-size:12px;color:var(--muted);text-transform:uppercase;letter-spacing:.05em}
  .stat.open .n{color:var(--open)} .stat.partial .n{color:var(--partial)} .stat.closed .n{color:var(--closed)}
  .mission{background:var(--panel);border:1px solid var(--line);border-radius:12px;padding:18px 22px;margin:18px 0}
  .mission h2{margin:0 0 10px;font-size:16px}
  .mission ol,.mission ul{margin:6px 0;padding-left:20px}
  .stream{margin:30px 0 0}
  .stream > h2{font-size:18px;margin:0 0 4px;padding-bottom:8px;border-bottom:2px solid var(--line);display:flex;align-items:baseline;gap:10px}
  .stream > h2 .tag{font-size:12px;background:var(--chip);color:var(--muted);border-radius:6px;padding:2px 8px}
  .stream > .purpose{color:var(--muted);font-size:13px;margin:6px 0 14px}
  .card{background:var(--panel);border:1px solid var(--line);border-left-width:5px;border-radius:10px;padding:14px 16px;margin:12px 0}
  .card.open{border-left-color:var(--open)}
  .card.partial{border-left-color:var(--partial)}
  .card.closed{border-left-color:var(--closed)}
  .card .head{display:flex;align-items:baseline;gap:10px;flex-wrap:wrap}
  .card .id{font-weight:700;color:var(--accent);font-family:Consolas,monospace}
  .card .statusbox{font-size:11px;font-weight:700;border-radius:5px;padding:2px 8px;text-transform:uppercase;letter-spacing:.04em}
  .statusbox.open{background:var(--open-bg);color:var(--open)}
  .statusbox.partial{background:var(--partial-bg);color:var(--partial)}
  .statusbox.closed{background:var(--closed-bg);color:var(--closed)}
  .card .title{font-weight:600}
  .card .meta{margin-top:8px;font-size:13.5px}
  .card .row{margin:3px 0;color:var(--muted)}
  .card .row .k{display:inline-block;min-width:96px;color:var(--ink);font-weight:600;font-size:12px;text-transform:uppercase;letter-spacing:.04em}
  .card .resolution{margin-top:8px;background:var(--panel2);border-radius:8px;padding:8px 12px;font-size:13.5px;color:var(--muted)}
  .card .resolution .k{color:var(--closed);font-weight:700;font-size:12px;text-transform:uppercase;margin-right:8px}
  code,.mono{font-family:Consolas,Menlo,monospace;font-size:13px;background:var(--panel2);border-radius:4px;padding:1px 5px}
  footer{margin:40px 0 20px;color:var(--muted);font-size:12.5px;text-align:center}
</style>
</head>
<body>
<header class="top">
  <h1>@@PAGE_TITLE@@</h1>
  <div class="sub">@@SUBTITLE@@</div>
  <div class="toolbar">
    <input id="q" type="search" placeholder="Filter tasks...">
    <span class="filterbtn active" data-f="all">All</span>
    <span class="filterbtn" data-f="open">Open</span>
    <span class="filterbtn" data-f="partial">Partial</span>
    <span class="filterbtn" data-f="closed">Closed</span>
  </div>
</header>
<div class="wrap">
  <div class="summary" id="summary"></div>
  <div class="mission">
    <h2>Mission</h2>
    @@MISSION_HTML@@
  </div>
  <div id="root"></div>
  <footer>Sprint board generated @@GENERATED_DATE@@ from authoritative <span class="mono">@@TASKS_FILE_NAME@@</span> via <span class="mono">Convert-TasksMdToSprintBoard</span>.</footer>
</div>
<script>
const STATUS_LABEL={open:"Open",partial:"Partial",closed:"Closed"};
const STREAMS=@@STREAMS_JSON@@;
function esc(s){return (s??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));}
function summarize(tasks){
  return {
    all: tasks.length,
    open: tasks.filter(t=>t.status==="open").length,
    partial: tasks.filter(t=>t.status==="partial").length,
    closed: tasks.filter(t=>t.status==="closed").length
  };
}
function renderSummary(tasks){
  const counts=summarize(tasks);
  document.getElementById("summary").innerHTML=[
    ["all","All",counts.all],
    ["open","Open",counts.open],
    ["partial","Partial",counts.partial],
    ["closed","Closed",counts.closed]
  ].map(([cls,label,value])=>`<div class="stat ${cls}"><div class="n">${value}</div><div class="l">${label}</div></div>`).join("");
}
function render(){
  const q=document.getElementById("q").value.trim().toLowerCase();
  const filter=document.querySelector(".filterbtn.active").dataset.f;
  const allTasks=STREAMS.flatMap(s=>s.tasks);
  renderSummary(allTasks);
  let html="";
  for(const stream of STREAMS){
    const filtered=(stream.tasks||[]).filter(task=>{
      const matchesFilter=filter==="all" || task.status===filter;
      const haystack=[task.id,task.title,task.repo,task.scope,task.acc,task.res].join(" ").toLowerCase();
      return matchesFilter && (!q || haystack.includes(q));
    });
    if(!filtered.length){ continue; }
    html+=`<section class="stream"><h2>Stream ${esc(stream.id)} - ${esc(stream.name)}${stream.tag?` <span class="tag">${esc(stream.tag)}</span>`:""}</h2><div class="purpose">${esc(stream.purpose||"")}</div>`;
    for(const task of filtered){
      html+=`<article class="card ${esc(task.status)}"><div class="head"><span class="id">${esc(task.id)}</span><span class="statusbox ${esc(task.status)}">${esc(STATUS_LABEL[task.status]||task.status)}</span><span class="title">${esc(task.title)}</span></div><div class="meta">`;
      if(task.repo){ html+=`<div class="row"><span class="k">Repo</span>${esc(task.repo)}</div>`; }
      if(task.scope){ html+=`<div class="row"><span class="k">Files</span>${esc(task.scope)}</div>`; }
      if(task.acc){ html+=`<div class="row"><span class="k">Acceptance</span>${esc(task.acc)}</div>`; }
      html+=`</div>`;
      if(task.res){ html+=`<div class="resolution"><span class="k">Status</span>${esc(task.res)}</div>`; }
      html+=`</article>`;
    }
    html+=`</section>`;
  }
  document.getElementById("root").innerHTML=html;
}
document.querySelectorAll(".filterbtn").forEach(btn=>{
  btn.addEventListener("click",()=>{
    document.querySelectorAll(".filterbtn").forEach(x=>x.classList.remove("active"));
    btn.classList.add("active");
    render();
  });
});
document.getElementById("q").addEventListener("input",render);
render();
</script>
</body>
</html>
'@

      $html = $htmlTemplate.Replace('@@PAGE_TITLE@@', [System.Net.WebUtility]::HtmlEncode($pageTitle))
      $html = $html.Replace('@@SUBTITLE@@', $subtitle)
      $html = $html.Replace('@@MISSION_HTML@@', $missionHtml)
      $html = $html.Replace('@@GENERATED_DATE@@', $generatedDate)
      $html = $html.Replace('@@TASKS_FILE_NAME@@', [System.Net.WebUtility]::HtmlEncode($tasksFileName))
      $html = $html.Replace('@@STREAMS_JSON@@', $streamsJson)

      if ($PSCmdlet.ShouldProcess($resolvedOutputPath, 'Write generated sprint board HTML')) {
        Set-Content -LiteralPath $resolvedOutputPath -Value $html -Encoding UTF8 -NoNewline
        if ($reconciliationReportPath) {
          $reconciliationReportDirectory = Split-Path -Path $reconciliationReportPath -Parent
          if (-not (Test-Path -LiteralPath $reconciliationReportDirectory -PathType Container)) {
            New-Item -ItemType Directory -Path $reconciliationReportDirectory -Force | Out-Null
          }
          $lostResolutionRecords |
            ConvertTo-Json -Depth 4 |
            Set-Content -LiteralPath $reconciliationReportPath -Encoding UTF8
        }
      }

      $statusCounts = [ordered]@{
        open = @($allTasks | Where-Object { $_.status -eq 'open' }).Count
        partial = @($allTasks | Where-Object { $_.status -eq 'partial' }).Count
        closed = @($allTasks | Where-Object { $_.status -eq 'closed' }).Count
      }

      [PSCustomObject]@{
        TasksFilePath = $resolvedTasksFilePath
        OutputPath = $resolvedOutputPath
        StreamCount = $streams.Count
        TaskCount = $allTasks.Count
        StatusCounts = [PSCustomObject]$statusCounts
        ReconciliationReportPath = $reconciliationReportPath
        LostResolutionCount = $lostResolutionRecords.Count
      }
    } catch {
      $errorMessage = "Failed to generate sprint board from '$TasksFilePath': $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw $errorMessage
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
