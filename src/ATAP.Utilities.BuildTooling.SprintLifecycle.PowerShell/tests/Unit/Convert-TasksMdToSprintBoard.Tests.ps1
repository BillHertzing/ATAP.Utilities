BeforeAll {
  $script:moduleName = 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell'
  $script:modulePath = Join-Path $PSScriptRoot '..\..\ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell.psd1'
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
  - Files: `src/ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell/public/Convert-TasksMdToSprintBoard.ps1`
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
    $subtaskA.res | Should -Match 'Evidence \(2026-06-18\): verified via WhatIf run.'
  }

  It 'Warns when an evidence-like bullet cannot be parsed' {
    $tasksMdPath = Join-Path $script:tempDir 'MalformedEvidence.TASKS.md'
    $outputPath = Join-Path $script:tempDir 'MalformedEvidence.TASKS.html'
    @'
# Current Sprint: Sprint 12 - Malformed Evidence Check

Source: TEST-0006 (2026-07-04)
Last updated: 2026-07-04

## Goal

**PRIMARY - Example goal.**

## Stream E - Evidence Stream [DRAFT]

- [ ] **Task 12.36** [ATAP.Utilities] - Evidence warning check.
  - Acceptance: malformed evidence-like bullets warn.
  - Evidence (2026-07-04) missing colon and cannot be parsed.
'@ | Set-Content -LiteralPath $tasksMdPath -Encoding UTF8

    $warnings = @()
    $result = Convert-TasksMdToSprintBoard -TasksFilePath $tasksMdPath -OutputPath $outputPath -WarningVariable warnings

    $result.TaskCount | Should -Be 1
    $warnings | Should -Not -BeNullOrEmpty
    ($warnings | Select-Object -First 1).Message | Should -Match 'Could not parse Evidence-like bullet for task 12\.36'
  }

  It 'Reports existing HTML resolution text that regeneration would otherwise drop' {
    $tasksMdPath = Join-Path $script:tempDir 'LostResolution.TASKS.md'
    $outputPath = Join-Path $script:tempDir 'LostResolution.TASKS.html'
    @'
# Current Sprint: Sprint 12 - Lost Resolution Check

Source: TEST-0007 (2026-07-04)
Last updated: 2026-07-04

## Goal

**PRIMARY - Example goal.**

## Stream E - Evidence Stream [DRAFT]

- [ ] **Task 12.36** [ATAP.Utilities] - A task whose markdown has no resolution.
'@ | Set-Content -LiteralPath $tasksMdPath -Encoding UTF8

    @'
<!DOCTYPE html>
<html>
<body>
<script>
const STREAMS=[
  {
    "id": "E",
    "name": "Evidence Stream",
    "tasks": [
      {
        "id": "12.36",
        "status": "open",
        "title": "A task whose markdown has no resolution.",
        "repo": "ATAP.Utilities",
        "scope": null,
        "acc": null,
        "res": "Evidence: hand-edited browser-only evidence"
      }
    ]
  }
];
function esc(s){return s;}
</script>
</body>
</html>
'@ | Set-Content -LiteralPath $outputPath -Encoding UTF8

    $warnings = @()
    $result = Convert-TasksMdToSprintBoard -TasksFilePath $tasksMdPath -OutputPath $outputPath -WarningVariable warnings

    $result.LostResolutionCount | Should -Be 1
    $result.ReconciliationReportPath | Should -Not -BeNullOrEmpty
    Test-Path -LiteralPath $result.ReconciliationReportPath | Should -BeTrue
    $warnings | Should -Not -BeNullOrEmpty
    ($warnings | Select-Object -First 1).Message | Should -Match 'resolution text would be lost'

    $report = Get-Content -LiteralPath $result.ReconciliationReportPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $report.TaskId | Should -Be '12.36'
    $report.ExistingRes | Should -Be 'Evidence: hand-edited browser-only evidence'
  }

  It 'Parses tasks with no detail lines (detail-free)' {
    $tasksMdPath = Join-Path $script:tempDir 'DetailFree.TASKS.md'
    $outputPath = Join-Path $script:tempDir 'DetailFree.TASKS.html'
    @'
# Current Sprint: Sprint 12 - Detail Free Check

Source: TEST-0004 (2026-07-04)
Last updated: 2026-07-04

## Goal

**PRIMARY - Example goal.**

## Stream A - Detail-Free Stream [PRIORITY 1]

- [ ] **Task 12.32** [ATAP.Utilities] - A detail free task with no details
'@ | Set-Content -LiteralPath $tasksMdPath -Encoding UTF8

    $result = Convert-TasksMdToSprintBoard -TasksFilePath $tasksMdPath -OutputPath $outputPath
    $html = Get-Content -LiteralPath $outputPath -Raw -Encoding UTF8

    $result.TaskCount | Should -Be 1
    $html | Should -Match '12\.32'
  }

  It 'Throws when the TASKS.md heading is missing' {
    $tasksMdPath = Join-Path $script:tempDir 'Broken.TASKS.md'
    'No current sprint heading here' | Set-Content -LiteralPath $tasksMdPath -Encoding UTF8

    { Convert-TasksMdToSprintBoard -TasksFilePath $tasksMdPath } |
      Should -Throw '*Current Sprint*'
  }

  Context 'Task 14.14 - default OutputPath derives from the input file name' {
    BeforeAll {
      # Each case gets an isolated directory so "no TASKS.html was created" is meaningful;
      # the Describe-scope temp directory already contains a TASKS.html from an earlier test.
      function script:New-IsolatedBoardDir {
        $dir = Join-Path ([System.IO.Path]::GetTempPath()) "tasksboard_1414_$([guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        return $dir
      }

      function script:New-MinimalBoardMarkdown {
        param(
          [Parameter(Mandatory)][string]$Path,
          [string]$SprintTitle = 'Sprint 14 - Output Path Derivation'
        )
        @"
# Current Sprint: $SprintTitle

Source: TEST-1414 (2026-08-05)
Last updated: 2026-08-05

## Goal

**PRIMARY - Exercise the default output path.**

## Stream Z - Derivation Stream [PRIORITY 1]

- [ ] **Task 14.14** [ATAP.Utilities] - Derive the board name from the markdown name.
"@ | Set-Content -LiteralPath $Path -Encoding UTF8
      }

      $script:isolatedDirs = [System.Collections.Generic.List[string]]::new()
    }

    AfterAll {
      foreach ($d in $script:isolatedDirs) {
        Remove-Item -Path $d -Recurse -Force -ErrorAction SilentlyContinue
      }
    }

    It 'Derives Tasks.Sprint0014.html from Tasks.Sprint0014.md and creates no TASKS.html' {
      $dir = script:New-IsolatedBoardDir
      $script:isolatedDirs.Add($dir)
      $tasksMdPath = Join-Path $dir 'Tasks.Sprint0014.md'
      script:New-MinimalBoardMarkdown -Path $tasksMdPath

      $result = Convert-TasksMdToSprintBoard -TasksFilePath $tasksMdPath

      $expected = Join-Path $dir 'Tasks.Sprint0014.html'
      $result.OutputPath | Should -Be $expected
      Test-Path -LiteralPath $expected | Should -BeTrue
      # The whole point of the defect: a stray TASKS.html must not appear.
      Test-Path -LiteralPath (Join-Path $dir 'TASKS.html') | Should -BeFalse
    }

    It 'Still derives TASKS.html from a legacy TASKS.md (backward compatibility)' {
      $dir = script:New-IsolatedBoardDir
      $script:isolatedDirs.Add($dir)
      $tasksMdPath = Join-Path $dir 'TASKS.md'
      script:New-MinimalBoardMarkdown -Path $tasksMdPath

      $result = Convert-TasksMdToSprintBoard -TasksFilePath $tasksMdPath

      $expected = Join-Path $dir 'TASKS.html'
      $result.OutputPath | Should -Be $expected
      Test-Path -LiteralPath $expected | Should -BeTrue
    }

    It 'Honours an explicit -OutputPath over the derivation' {
      $dir = script:New-IsolatedBoardDir
      $script:isolatedDirs.Add($dir)
      $tasksMdPath = Join-Path $dir 'Tasks.Sprint0014.md'
      script:New-MinimalBoardMarkdown -Path $tasksMdPath
      $explicit = Join-Path $dir 'Explicit.Board.html'

      $result = Convert-TasksMdToSprintBoard -TasksFilePath $tasksMdPath -OutputPath $explicit

      $result.OutputPath | Should -Be $explicit
      Test-Path -LiteralPath $explicit | Should -BeTrue
      Test-Path -LiteralPath (Join-Path $dir 'Tasks.Sprint0014.html') | Should -BeFalse
    }

    It 'Falls back to the derivation for an empty or whitespace-only -OutputPath' -TestCases @(
      @{ Label = 'empty'; Value = '' }
      @{ Label = 'whitespace'; Value = '   ' }
    ) {
      param($Label, $Value)

      $dir = script:New-IsolatedBoardDir
      $script:isolatedDirs.Add($dir)
      $tasksMdPath = Join-Path $dir 'Tasks.Sprint0014.md'
      script:New-MinimalBoardMarkdown -Path $tasksMdPath

      $result = Convert-TasksMdToSprintBoard -TasksFilePath $tasksMdPath -OutputPath $Value

      $expected = Join-Path $dir 'Tasks.Sprint0014.html'
      $result.OutputPath | Should -Be $expected -Because "the $Label value must fall back to the derivation"
      Test-Path -LiteralPath $expected | Should -BeTrue
      Test-Path -LiteralPath (Join-Path $dir 'TASKS.html') | Should -BeFalse
    }

    Context 'Task 14.14.c - adversarial variants of the derivation' {
      It 'Derives from an uppercase .MD extension' {
        $dir = script:New-IsolatedBoardDir
        $script:isolatedDirs.Add($dir)
        $tasksMdPath = Join-Path $dir 'Tasks.Sprint0014.MD'
        script:New-MinimalBoardMarkdown -Path $tasksMdPath

        $result = Convert-TasksMdToSprintBoard -TasksFilePath $tasksMdPath

        $result.OutputPath | Should -Be (Join-Path $dir 'Tasks.Sprint0014.html')
        Test-Path -LiteralPath (Join-Path $dir 'TASKS.html') | Should -BeFalse
      }

      It 'Gives a sibling dotted artifact its own board and never the main board name' {
        $dir = script:New-IsolatedBoardDir
        $script:isolatedDirs.Add($dir)
        # The main board and a sibling companion artifact live in the same directory.
        $mainPath = Join-Path $dir 'Tasks.Sprint0014.md'
        $siblingPath = Join-Path $dir 'Tasks.Sprint0014.Accomplished.md'
        script:New-MinimalBoardMarkdown -Path $mainPath
        script:New-MinimalBoardMarkdown -Path $siblingPath -SprintTitle 'Sprint 14 - Accomplished'

        $siblingResult = Convert-TasksMdToSprintBoard -TasksFilePath $siblingPath

        $siblingResult.OutputPath | Should -Be (Join-Path $dir 'Tasks.Sprint0014.Accomplished.html')
        # Regenerating the companion must not touch or create the main board.
        Test-Path -LiteralPath (Join-Path $dir 'Tasks.Sprint0014.html') | Should -BeFalse
      }

      It 'Derives correctly when the directory path itself contains dots' {
        $parent = script:New-IsolatedBoardDir
        $script:isolatedDirs.Add($parent)
        $dir = Join-Path $parent 'ATAP.Utilities.Sprint.0014'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $tasksMdPath = Join-Path $dir 'Tasks.Sprint0014.md'
        script:New-MinimalBoardMarkdown -Path $tasksMdPath

        $result = Convert-TasksMdToSprintBoard -TasksFilePath $tasksMdPath

        $result.OutputPath | Should -Be (Join-Path $dir 'Tasks.Sprint0014.html')
      }

      It 'Derives from an input file with no extension at all' {
        $dir = script:New-IsolatedBoardDir
        $script:isolatedDirs.Add($dir)
        $tasksMdPath = Join-Path $dir 'TASKS'
        script:New-MinimalBoardMarkdown -Path $tasksMdPath

        $result = Convert-TasksMdToSprintBoard -TasksFilePath $tasksMdPath

        $result.OutputPath | Should -Be (Join-Path $dir 'TASKS.html')
        Test-Path -LiteralPath $result.OutputPath | Should -BeTrue
      }

      It 'Derives a usable name from an extension-only input such as .md' {
        $dir = script:New-IsolatedBoardDir
        $script:isolatedDirs.Add($dir)
        $tasksMdPath = Join-Path $dir '.md'
        script:New-MinimalBoardMarkdown -Path $tasksMdPath

        $result = Convert-TasksMdToSprintBoard -TasksFilePath $tasksMdPath

        # GetFileNameWithoutExtension('.md') is empty, so the guard falls back to the
        # full file name. The result is odd-looking but deterministic and never bare.
        $result.OutputPath | Should -Be (Join-Path $dir '.md.html')
        Test-Path -LiteralPath $result.OutputPath | Should -BeTrue
      }
    }
  }

  Context 'Task 15.181.f - closed tasks require closed explicit prerequisites' {
    BeforeAll {
      $script:prerequisiteInvariantDirs = [System.Collections.Generic.List[string]]::new()
      function script:New-PrerequisiteBoardFixture {
        param(
          [Parameter(Mandatory)]
          [string[]]$TaskLines
        )

        $dir = Join-Path ([System.IO.Path]::GetTempPath()) "tasksboard_15181f_$([guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $script:prerequisiteInvariantDirs.Add($dir)
        $tasksMdPath = Join-Path $dir 'Tasks.Sprint0015.md'
        $outputPath = Join-Path $dir 'Tasks.Sprint0015.html'
        $markdownLines = @(
          '# Current Sprint: Sprint 15 - Prerequisite Invariant'
          ''
          'Source: TEST-15181F (2026-08-21)'
          'Last updated: 2026-08-21'
          ''
          '## Goal'
          ''
          '**PRIMARY - Verify prerequisite declarations.**'
          ''
          '## Stream Z - Prerequisite Stream [PRIORITY 1]'
          ''
        ) + $TaskLines
        $markdownLines | Set-Content -LiteralPath $tasksMdPath -Encoding UTF8
        return [PSCustomObject]@{
          TasksFilePath = $tasksMdPath
          OutputPath = $outputPath
        }
      }
    }

    AfterAll {
      foreach ($dir in $script:prerequisiteInvariantDirs) {
        Remove-Item -Path $dir -Recurse -Force -ErrorAction SilentlyContinue
      }
    }

    It 'Returns zero violations when an explicit prerequisite is completed' {
      $fixture = script:New-PrerequisiteBoardFixture -TaskLines @(
        '- [x] **Task 15.181.a** [ATAP.Utilities] - Complete the prerequisite.'
        '- [x] **Task 15.181.b** [ATAP.Utilities] - Continue after Task 15.181.a.'
      )

      $result = Convert-TasksMdToSprintBoard -TasksFilePath $fixture.TasksFilePath -OutputPath $fixture.OutputPath

      $result.PrerequisiteViolationCount | Should -Be 0
      @($result.PrerequisiteViolations).Count | Should -Be 0
      Test-Path -LiteralPath $fixture.OutputPath | Should -BeTrue
    }

    It 'Resolves complete nested prerequisite <PrerequisiteId> while its parent stays open' -TestCases @(
      @{ PrerequisiteId = '15.140.c.T0' }
      @{ PrerequisiteId = '15.140.c.T0.deep' }
      @{ PrerequisiteId = '15.185.b.REST-DB02' }
    ) {
      param($PrerequisiteId)
      $parentId = $PrerequisiteId.Substring(0, $PrerequisiteId.LastIndexOf('.'))
      $fixture = script:New-PrerequisiteBoardFixture -TaskLines @(
        "- [ ] **Task $parentId** [ATAP.Utilities] - Keep unrelated parent work open."
        "- [x] **Task $PrerequisiteId** [ATAP.Utilities] - Complete the bounded prerequisite."
        "- [x] **Task 15.999** [ATAP.Utilities] - Continue after Task $PrerequisiteId."
      )
      $result = Convert-TasksMdToSprintBoard -TasksFilePath $fixture.TasksFilePath -OutputPath $fixture.OutputPath
      $result.PrerequisiteViolationCount | Should -Be 0
      Test-Path -LiteralPath $fixture.OutputPath | Should -BeTrue
    }

    It 'Does not substitute a closed parent for a nested prerequisite that is <ChildStatus>' -TestCases @(
      @{ ChildStatus = 'open'; ChildLine = '- [ ] **Task 15.140.c.T0** [ATAP.Utilities] - Pending.'; Kind = 'PrerequisiteNotClosed' }
      @{ ChildStatus = 'partial'; ChildLine = '- [~] **Task 15.140.c.T0** [ATAP.Utilities] - Partial.'; Kind = 'PrerequisiteNotClosed' }
      @{ ChildStatus = 'unknown'; ChildLine = ''; Kind = 'UnknownPrerequisite' }
    ) {
      param($ChildStatus, $ChildLine, $Kind)
      $fixture = script:New-PrerequisiteBoardFixture -TaskLines @(
        '- [x] **Task 15.140.c** [ATAP.Utilities] - Parent complete.'
        if ($ChildLine) { $ChildLine }
        '- [x] **Task 15.999** [ATAP.Utilities] - Continue after 15.140.c.T0.'
      )
      $caught = $null
      try {
        $null = Convert-TasksMdToSprintBoard -TasksFilePath $fixture.TasksFilePath -OutputPath $fixture.OutputPath
      } catch { $caught = $_ }
      $caught | Should -Not -BeNullOrEmpty
      $caught.Exception.Message | Should -Match $Kind
      $caught.Exception.Message | Should -Match '"PrerequisiteTaskId":"15\.140\.c\.T0"'
      Test-Path -LiteralPath $fixture.OutputPath | Should -BeFalse
    }

    It 'Rejects a nested self-reference without truncating its identity' {
      $fixture = script:New-PrerequisiteBoardFixture -TaskLines @(
        '- [x] **Task 15.140.c** [ATAP.Utilities] - Parent complete.'
        '- [x] **Task 15.140.c.T1** [ATAP.Utilities] - Continue after Task 15.140.c.T1.'
      )
      { Convert-TasksMdToSprintBoard -TasksFilePath $fixture.TasksFilePath -OutputPath $fixture.OutputPath } |
        Should -Throw '*SelfReference*'
      Test-Path -LiteralPath $fixture.OutputPath | Should -BeFalse
    }

    It 'Fails closed with an actionable record for <Label>' -TestCases @(
      @{
        Label = 'an open prerequisite using after-id syntax'
        TaskLines = @(
          '- [ ] **Task 15.181.a** [ATAP.Utilities] - Keep the prerequisite open.'
          '- [x] **Task 15.181.b** [ATAP.Utilities] - Continue after 15.181.a.'
        )
        ExpectedKind = 'PrerequisiteNotClosed'
        ExpectedTaskId = '15.181.b'
        ExpectedPrerequisiteId = '15.181.a'
        ExpectedStatus = 'open'
      }
      @{
        Label = 'a partial prerequisite using after-Task-id syntax'
        TaskLines = @(
          '- [~] **Task 15.181.a** [ATAP.Utilities] - Keep the prerequisite partial.'
          '- [x] **Task 15.181.b** [ATAP.Utilities] - Continue after Task 15.181.a.'
        )
        ExpectedKind = 'PrerequisiteNotClosed'
        ExpectedTaskId = '15.181.b'
        ExpectedPrerequisiteId = '15.181.a'
        ExpectedStatus = 'partial'
      }
      @{
        Label = 'an unknown prerequisite'
        TaskLines = @(
          '- [x] **Task 15.181.b** [ATAP.Utilities] - Continue after Task 15.181.unknown.'
        )
        ExpectedKind = 'UnknownPrerequisite'
        ExpectedTaskId = '15.181.b'
        ExpectedPrerequisiteId = '15.181.unknown'
        ExpectedStatus = 'unknown'
      }
      @{
        Label = 'a self-reference'
        TaskLines = @(
          '- [x] **Task 15.181.b** [ATAP.Utilities] - Continue after 15.181.b.'
        )
        ExpectedKind = 'SelfReference'
        ExpectedTaskId = '15.181.b'
        ExpectedPrerequisiteId = '15.181.b'
        ExpectedStatus = 'closed'
      }
    ) {
      param($Label, $TaskLines, $ExpectedKind, $ExpectedTaskId, $ExpectedPrerequisiteId, $ExpectedStatus)

      $fixture = script:New-PrerequisiteBoardFixture -TaskLines $TaskLines
      $caught = $null
      try {
        Convert-TasksMdToSprintBoard -TasksFilePath $fixture.TasksFilePath -OutputPath $fixture.OutputPath
      } catch {
        $caught = $_
      }

      $caught | Should -Not -BeNullOrEmpty
      $caught.Exception.Message | Should -Match ([regex]::Escape($ExpectedKind))
      $caught.Exception.Message | Should -Match ([regex]::Escape($ExpectedTaskId))
      $caught.Exception.Message | Should -Match ([regex]::Escape($ExpectedPrerequisiteId))
      $caught.Exception.Message | Should -Match ([regex]::Escape($ExpectedStatus))
      Test-Path -LiteralPath $fixture.OutputPath | Should -BeFalse
    }

    It 'Does not enforce declarations made by an open task' {
      $fixture = script:New-PrerequisiteBoardFixture -TaskLines @(
        '- [ ] **Task 15.181.b** [ATAP.Utilities] - Continue after Task 15.181.404.'
      )

      $result = Convert-TasksMdToSprintBoard -TasksFilePath $fixture.TasksFilePath -OutputPath $fixture.OutputPath

      $result.PrerequisiteViolationCount | Should -Be 0
      Test-Path -LiteralPath $fixture.OutputPath | Should -BeTrue
    }

    It 'Ignores prerequisite-like prose outside the task row title' {
      $fixture = script:New-PrerequisiteBoardFixture -TaskLines @(
        '- [ ] **Task 15.181.a** [ATAP.Utilities] - Keep the prerequisite open.'
        '- [x] **Task 15.181.b** [ATAP.Utilities] - Narrative remains non-declarative.'
        '  - Acceptance: run after Task 15.181.a is discussed here, not declared.'
        '  - Evidence: a note after 15.181.a is also non-declarative.'
      )

      $result = Convert-TasksMdToSprintBoard -TasksFilePath $fixture.TasksFilePath -OutputPath $fixture.OutputPath

      $result.PrerequisiteViolationCount | Should -Be 0
      Test-Path -LiteralPath $fixture.OutputPath | Should -BeTrue
    }

    It 'Ignores near-variant task-title prose that is not an explicit declaration' {
      $fixture = script:New-PrerequisiteBoardFixture -TaskLines @(
        '- [x] **Task 15.181.b** [ATAP.Utilities] - Document aftermath 15.181.404 and after-task 15.181.405.'
      )

      $result = Convert-TasksMdToSprintBoard -TasksFilePath $fixture.TasksFilePath -OutputPath $fixture.OutputPath

      $result.PrerequisiteViolationCount | Should -Be 0
      Test-Path -LiteralPath $fixture.OutputPath | Should -BeTrue
    }
  }
}

