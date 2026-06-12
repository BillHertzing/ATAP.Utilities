---
name: html-board-extraction
description: "Extract task subsets from planning HTML boards by parsing the const STREAMS JSON without loading the whole file into model context."
---

# HTML Board Extraction Skill

Use this skill when a task asks for open, partial, closed, or status-filtered work items from a planning HTML board such as `TASKS.html`, `TASKS_V5.html`, or a sprint board copy.

## Goal

Extract only the JavaScript `const STREAMS = ...;` payload, parse it locally, and return compact task summaries grouped by stream. Do not paste the full HTML file into chat context.

## Workflow

1. Identify the board file. Prefer the highest `TASKS_V*.html` in the planning worktree when one exists; otherwise use `TASKS.html`.
2. Read the file as text locally and locate `const STREAMS`, allowing whitespace around `=`.
3. Starting at the first `[` after that token, scan characters while tracking string literals, escapes, and bracket depth until the matching closing `]` is found.
4. Parse that slice as JSON. If the board uses a JavaScript object literal with unquoted keys, single-quoted strings, or archived escaped-terminator artifacts, normalize the extracted slice before `ConvertFrom-Json`.
5. Normalize task IDs as strings so expanded IDs such as `8.20A`, `8.20C`, and compact numeric IDs such as `8.26` sort predictably.
6. Filter by requested status or IDs. Treat unchecked/open tasks as `open`; checked/done tasks as `closed`; statuses containing `partial`, `blocked`, or `in-progress` as partial unless the board has an explicit status field.
7. Return a compact stream-grouped report with task id, title, status, owner/tag text, and evidence fields only when requested.

## PowerShell Extractor

```powershell
function Test-PlanningBoardEscapedStringTerminator {
  param(
    [Parameter(Mandatory = $true)]
    [string] $Text,

    [Parameter(Mandatory = $true)]
    [int] $BackslashIndex,

    [Parameter(Mandatory = $true)]
    [char] $Quote
  )

  if ($BackslashIndex + 1 -ge $Text.Length) { return $false }
  if ($Text[$BackslashIndex + 1] -ne $Quote) { return $false }

  $lookAhead = $BackslashIndex + 2
  while ($lookAhead -lt $Text.Length -and [char]::IsWhiteSpace($Text[$lookAhead])) {
    $lookAhead++
  }

  return $lookAhead -lt $Text.Length -and $Text[$lookAhead] -in @(',', '}', ']')
}
function Get-PlanningBoardStreamsJson {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string] $Path
  )

  $text = Get-Content -LiteralPath $Path -Raw
  $marker = 'const STREAMS'
  $markerIndex = $text.IndexOf($marker, [StringComparison]::Ordinal)
  if ($markerIndex -lt 0) { throw "STREAMS marker not found in $Path" }

  $equalsIndex = $text.IndexOf('=', $markerIndex)
  if ($equalsIndex -lt 0) { throw "STREAMS assignment not found in $Path" }

  $start = $text.IndexOf('[', $equalsIndex)
  if ($start -lt 0) { throw "STREAMS array start not found in $Path" }

  $depth = 0
  $stringQuote = [char]0
  $escape = $false
  for ($i = $start; $i -lt $text.Length; $i++) {
    $ch = $text[$i]
    if ($stringQuote -ne [char]0) {
      if ($escape) { $escape = $false; continue }
      if (Test-PlanningBoardEscapedStringTerminator -Text $text -BackslashIndex $i -Quote $stringQuote) {
        $stringQuote = [char]0
        $i++
        continue
      }
      if ($ch -eq '\') { $escape = $true; continue }
      if ($ch -eq $stringQuote) { $stringQuote = [char]0; continue }
      continue
    }

    if ($ch -eq '"' -or $ch -eq "'" -or $ch -eq '`') { $stringQuote = $ch; continue }
    if ($ch -eq '[' -or $ch -eq '{') { $depth++ }
    if ($ch -eq ']' -or $ch -eq '}') { $depth-- }
    if ($depth -eq 0) {
      return $text.Substring($start, $i - $start + 1)
    }
  }

  throw "STREAMS array did not terminate in $Path"
}

function ConvertTo-PlanningBoardJsonLiteral {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string] $StreamsLiteral
  )

  $builder = [System.Text.StringBuilder]::new()
  $stringBuffer = [System.Text.StringBuilder]::new()
  $stringQuote = [char]0
  $escape = $false

  for ($i = 0; $i -lt $StreamsLiteral.Length; $i++) {
    $ch = $StreamsLiteral[$i]
    if ($stringQuote -ne [char]0) {
      if ($escape) {
        switch ($ch) {
          '"' { [void] $stringBuffer.Append('\"') }
          '\' { [void] $stringBuffer.Append('\\') }
          '/' { [void] $stringBuffer.Append('\/') }
          'b' { [void] $stringBuffer.Append('\b') }
          'f' { [void] $stringBuffer.Append('\f') }
          'n' { [void] $stringBuffer.Append('\n') }
          'r' { [void] $stringBuffer.Append('\r') }
          't' { [void] $stringBuffer.Append('\t') }
          'u' {
            if ($i + 4 -lt $StreamsLiteral.Length) {
              [void] $stringBuffer.Append('\u')
              for ($j = 1; $j -le 4; $j++) {
                $i++
                [void] $stringBuffer.Append($StreamsLiteral[$i])
              }
            } else {
              [void] $stringBuffer.Append('u')
            }
          }
          default { [void] $stringBuffer.Append($ch) }
        }
        $escape = $false
        continue
      }

      if (Test-PlanningBoardEscapedStringTerminator -Text $StreamsLiteral -BackslashIndex $i -Quote $stringQuote) {
        [void] $builder.Append('"')
        [void] $builder.Append($stringBuffer.ToString())
        [void] $builder.Append('"')
        [void] $stringBuffer.Clear()
        $stringQuote = [char]0
        $i++
        continue
      }
      if ($ch -eq '\') { $escape = $true; continue }
      if ($ch -eq $stringQuote) {
        [void] $builder.Append('"')
        [void] $builder.Append($stringBuffer.ToString())
        [void] $builder.Append('"')
        [void] $stringBuffer.Clear()
        $stringQuote = [char]0
        continue
      }

      switch ([int][char] $ch) {
        8 { [void] $stringBuffer.Append('\b') }
        9 { [void] $stringBuffer.Append('\t') }
        10 { [void] $stringBuffer.Append('\n') }
        12 { [void] $stringBuffer.Append('\f') }
        13 { [void] $stringBuffer.Append('\r') }
        default {
          if ($ch -eq '"') { [void] $stringBuffer.Append('\"') }
          elseif ($ch -eq '\') { [void] $stringBuffer.Append('\\') }
          else { [void] $stringBuffer.Append($ch) }
        }
      }
      continue
    }

    if ($ch -eq '"' -or $ch -eq "'" -or $ch -eq '`') {
      $stringQuote = $ch
      [void] $stringBuffer.Clear()
      continue
    }

    [void] $builder.Append($ch)
  }

  if ($stringQuote -ne [char]0) { throw 'Unterminated string literal in STREAMS payload.' }
  return $builder.ToString()
}

function ConvertFrom-PlanningBoardStreamsLiteral {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string] $StreamsLiteral
  )

  try {
    return $StreamsLiteral | ConvertFrom-Json
  } catch {
    $json = ConvertTo-PlanningBoardJsonLiteral -StreamsLiteral $StreamsLiteral
    $json = [regex]::Replace($json, '(?<=[{,]\s*)([A-Za-z_][A-Za-z0-9_]*)\s*:', '"$1":')
    $json = [regex]::Replace($json, ',\s*([}\]])', '$1')
    return $json | ConvertFrom-Json
  }
}

function Get-PlanningBoardFirstValue {
  param(
    [Parameter(Mandatory = $true)]
    [object] $InputObject,

    [Parameter(Mandatory = $true)]
    [string[]] $PropertyName
  )

  foreach ($name in $PropertyName) {
    if ($InputObject.PSObject.Properties.Name -contains $name -and $null -ne $InputObject.$name) {
      return $InputObject.$name
    }
  }

  return $null
}

function Get-PlanningBoardTasks {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string] $Path,

    [string[]] $Id,

    [ValidateSet('open','partial','closed','all')]
    [string] $Status = 'all'
  )

  $streams = ConvertFrom-PlanningBoardStreamsLiteral -StreamsLiteral (Get-PlanningBoardStreamsJson -Path $Path)
  foreach ($stream in @($streams)) {
    foreach ($task in @($stream.tasks)) {
      $taskId = [string](Get-PlanningBoardFirstValue -InputObject $task -PropertyName @('id','taskId','number'))
      $rawStatus = [string](Get-PlanningBoardFirstValue -InputObject $task -PropertyName @('status','state'))
      $normalized = if ($rawStatus -match 'done|closed|complete|\[x\]') {
        'closed'
      } elseif ($rawStatus -match 'partial|blocked|progress') {
        'partial'
      } else {
        'open'
      }

      if ($Id -and $taskId -notin $Id) { continue }
      if ($Status -ne 'all' -and $normalized -ne $Status) { continue }

      [PSCustomObject]@{
        Stream = [string](Get-PlanningBoardFirstValue -InputObject $stream -PropertyName @('name','title','id'))
        Id = $taskId
        Title = [string](Get-PlanningBoardFirstValue -InputObject $task -PropertyName @('title','name','text'))
        Status = $normalized
        Tags = [string]((Get-PlanningBoardFirstValue -InputObject $task -PropertyName @('tags')) -join ', ')
      }
    }
  }
}
```

## Reporting Format

Group output by stream and keep each row one line:

```text
Stream Q - Shared AI Instructions
- 8.20C open: Idempotent adapter render PowerShell function
- 8.26 closed: HTML board extraction recipe/skill
```

For machine handoff, emit JSON from the filtered objects rather than the full board.
