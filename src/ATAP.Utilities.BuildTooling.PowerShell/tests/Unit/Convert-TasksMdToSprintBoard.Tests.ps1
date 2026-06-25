BeforeAll {
  $script:moduleName = 'ATAP.Utilities.BuildTooling.PowerShell'
  $script:modulePath = Join-Path $PSScriptRoot '..\..\ATAP.Utilities.BuildTooling.PowerShell.psd1'
  Remove-Module $script:moduleName -Force -ErrorAction SilentlyContinue
  Import-Module $script:modulePath -Force
}

Describe 'Convert-TasksMdToSprintBoard [public]' {
  BeforeAll {
    $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "tasksboard_test_$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $script:tempDir -Force | Out-Null
  }

  AfterAll {
    Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
  }

  It 'Generates TASKS.html next to TASKS.md by default' {
    $tasksMdPath = Join-Path $script:tempDir 'TASKS.md'
    @'
# Current Sprint: Sprint 8 - Example Sprint

Source: TEST-0001 (2026-06-12)
Last updated: 2026-06-12
Active board: `TASKS.html` (generated from this file).

## Goal

**PRIMARY - Example goal.**

1. First objective.
2. Second objective.

## Stream X - Example Stream [PRIORITY 1]

Example purpose text.

- [x] **Task 8.13** [ATAP.Utilities] - Generate the board from markdown.
  - Files: `src/ATAP.Utilities.BuildTooling.PowerShell/public/Convert-TasksMdToSprintBoard.ps1`
  - Acceptance: One command regenerates `TASKS.html`.
  - Status: **Done** (2026-06-12) - Implemented the generator.
  - Evidence: Focused Pester coverage passed.
'@ | Set-Content -LiteralPath $tasksMdPath -Encoding UTF8

    $result = Convert-TasksMdToSprintBoard -TasksFilePath $tasksMdPath
    $htmlPath = Join-Path $script:tempDir 'TASKS.html'

    $result.OutputPath | Should -Be $htmlPath
    Test-Path -LiteralPath $htmlPath | Should -BeTrue
  }

  It 'Emits stream and task data from the markdown source' {
    $tasksMdPath = Join-Path $script:tempDir 'EmitData.TASKS.md'
    $outputPath = Join-Path $script:tempDir 'EmitData.TASKS.html'
    @'
# Current Sprint: Sprint 8 - Emission Check

Source: TEST-0002 (2026-06-12)
Last updated: 2026-06-12

## Goal

**PRIMARY - Example goal.**

## Stream Q - Shared AI Instructions [PRIORITY 2]

Keep the board readable.

- [ ] **Task 8.20C** [SharedVSCode] [Junior] - Add render validation.
  - Files: `Render-AIAdapters.ps1`
  - Acceptance: HTML board regenerates from markdown.

- [x] **Task 8.26** [SharedVSCode] - HTML board extraction recipe.
  - Files: `SKILL.md`
  - Acceptance: Extractor exists.
  - Status: **Done** (2026-06-12) - Added the extractor.
'@ | Set-Content -LiteralPath $tasksMdPath -Encoding UTF8

    $result = Convert-TasksMdToSprintBoard -TasksFilePath $tasksMdPath -OutputPath $outputPath
    $html = Get-Content -LiteralPath $outputPath -Raw -Encoding UTF8

    $result.StreamCount | Should -Be 1
    $result.TaskCount | Should -Be 2
    $result.StatusCounts.open | Should -Be 1
    $result.StatusCounts.closed | Should -Be 1
    $html | Should -Match 'const STREAMS='
    $html | Should -Match '8\.20C'
    $html | Should -Match '8\.26'
    $html | Should -Match 'SharedVSCode'
    $html | Should -Match 'EmitData\.TASKS\.html</span> generated from authoritative <span class="mono">EmitData\.TASKS\.md</span>'
  }

  It 'Renders lettered subtasks as separate entries that inherit the umbrella repo' {
    $tasksMdPath = Join-Path $script:tempDir 'Subtasks.TASKS.md'
    $outputPath = Join-Path $script:tempDir 'Subtasks.TASKS.html'
    @'
# Current Sprint: Sprint 10 - Subtask Check

Source: TEST-0003 (2026-06-20)
Last updated: 2026-06-20

## Goal

**PRIMARY - Example goal.**

## Stream G - Gap Log [PRIORITY 1]

Umbrella tasks collect lettered subtasks.

- [x] **Task 10.14** [ATAP.Utilities + SharedVSCode] - SprintStart gap log (umbrella)
  - Background: Gaps surface live and are collected as lettered subtasks.
  - Status: **Done** (2026-06-20) - all subtasks complete.

  - [x] **Task 10.14.a** - Generate the Overview workspace
    - Symptom: No workspace existed at sprint start.
    - Acceptance: A fresh sprint start produces the workspace.
    - Evidence (2026-06-18): verified via WhatIf run.
    - See: SC-0193 (logged gap).
    - Status: **Done** (2026-06-20) - wired into New-SprintStage2.

  - [ ] **Task 10.14.b** - Skip stable worktrees
    - Acceptance: stable worktree CLAUDE.md left untouched.
'@ | Set-Content -LiteralPath $tasksMdPath -Encoding UTF8

    $result = Convert-TasksMdToSprintBoard -TasksFilePath $tasksMdPath -OutputPath $outputPath
    $html = Get-Content -LiteralPath $outputPath -Raw -Encoding UTF8

    # Umbrella + two lettered subtasks = three distinct task entries.
    $result.TaskCount | Should -Be 3
    $result.StatusCounts.closed | Should -Be 2
    $result.StatusCounts.open | Should -Be 1
    $html | Should -Match '10\.14\.a'
    $html | Should -Match '10\.14\.b'

    # Subtasks omit the [Repo] tag and must inherit the umbrella's repo.
    $streamsJson = [regex]::Match(
      $html,
      'const STREAMS=(?<json>.*?);\r?\nfunction esc',
      [System.Text.RegularExpressions.RegexOptions]::Singleline).Groups['json'].Value
    $parsedStreams = $streamsJson | ConvertFrom-Json
    $allParsedTasks = @($parsedStreams) | ForEach-Object { $_.tasks }
    $subtaskA = $allParsedTasks | Where-Object { $_.id -eq '10.14.a' }
    $subtaskA | Should -Not -BeNullOrEmpty
    $subtaskA.repo | Should -Be 'ATAP.Utilities + SharedVSCode'
    # The Acceptance field must not absorb the Evidence/See/Status bullets that follow it.
    $subtaskA.acc | Should -Be 'A fresh sprint start produces the workspace.'
  }

  It 'Throws when the TASKS.md heading is missing' {
    $tasksMdPath = Join-Path $script:tempDir 'Broken.TASKS.md'
    'No current sprint heading here' | Set-Content -LiteralPath $tasksMdPath -Encoding UTF8

    { Convert-TasksMdToSprintBoard -TasksFilePath $tasksMdPath } |
      Should -Throw '*Current Sprint*'
  }
}
