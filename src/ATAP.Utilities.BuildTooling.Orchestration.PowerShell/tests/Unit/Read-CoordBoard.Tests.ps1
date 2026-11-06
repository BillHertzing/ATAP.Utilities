param(
  [Parameter()]
  [ValidateNotNullOrEmpty()]
  [string]$FixtureRoot = $(if ([Environment]::MachineName -ieq 'UTAT022') { 'D:\ATAPArtifacts\Sprint0017\Task17.21\PackageTests' } else { throw 'FixtureRoot must be supplied explicitly on this host.' })
)

BeforeAll {
  if (-not [System.IO.Path]::IsPathFullyQualified($FixtureRoot)) {
    throw 'FixtureRoot must be an explicit absolute disposable artifact directory.'
  }
  $script:readBoardFixtureBase = Join-Path $FixtureRoot ([guid]::NewGuid().ToString('N'))
  $null = New-Item -ItemType Directory -Path $script:readBoardFixtureBase -Force
  $readerPath = Join-Path $PSScriptRoot '../../private/Read-CoordBoard.ps1'
  . $readerPath

  function New-BoardFixture {
    $directory = Join-Path $script:readBoardFixtureBase ([guid]::NewGuid().ToString('N'))
    $null = New-Item -ItemType Directory -Path $directory
    $directory
  }

  function Write-BoardFixture {
    param([string]$Directory, [string]$Name = 'Tasks.Sprint0017.md', [string]$Text, [switch]$Bom)
    $path = Join-Path $Directory $Name
    $encoding = [System.Text.UTF8Encoding]::new([bool]$Bom)
    $bytes = $encoding.GetBytes($Text)
    if ($Bom) { $bytes = [byte[]]($encoding.GetPreamble() + $bytes) }
    [System.IO.File]::WriteAllBytes($path, $bytes)
    $path
  }
}

Describe 'Read-CoordBoard private snapshot' -Tag 'Unit' {
  It 'preserves <Kind> bytes, exact blocks and checkbox spellings' -ForEach @(
    @{ Kind = 'LF'; Eol = [string][char]10 },
    @{ Kind = 'CRLF'; Eol = [string][char]13 + [char]10 }
  ) {
    $directory = New-BoardFixture
    $content = @(
      '# Current Sprint: Sprint 17 - Fixture'
      'Preamble remains untouched.'
      '## Stream C - Clerk [INITIAL]'
      '- [ ] **Task 17.21** [ATAP.Utilities] - Read board'
      '  - Dependencies: exact required dependency text.'
      '  - Risk: preserve every word.'
      ''
      '  - [x] **Task 17.21.ab** - Nested letters'
      '    - Status: source-ready.'
      '- [~] **Task 17.21.12** - Numeric suffix'
      '- [X] **Task 17.21AA** - Attached multi-letter suffix'
    ) -join $Eol
    $path = Write-BoardFixture -Directory $directory -Text $content
    $before = [System.IO.File]::ReadAllBytes($path)
    $snapshots = @(Read-CoordBoard -PlanningRoot $directory -SprintNumber 17)

    $snapshots.Count | Should -Be 1
    $snapshot = $snapshots[0]
    $snapshot.Path | Should -Be $path
    $snapshot.Version | Should -BeNullOrEmpty
    $snapshot.Text | Should -BeExactly $content
    [Convert]::ToHexString($snapshot.RawBytes) | Should -BeExactly ([Convert]::ToHexString($before))
    $snapshot.Sha256 | Should -BeExactly ([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($before)).ToLowerInvariant())
    ($snapshot.Tasks.Id -join ',') | Should -BeExactly '17.21,17.21.ab,17.21.12,17.21AA'
    ($snapshot.Tasks.Checkbox -join ',') | Should -BeExactly ' ,x,~,X'
    $snapshot.Tasks[0].Checked | Should -BeFalse
    $snapshot.Tasks[1].Checked | Should -BeTrue
    $snapshot.Tasks[2].Checked | Should -BeFalse
    $snapshot.Tasks[3].Checked | Should -BeTrue
    ($snapshot.NewLineKinds -join ',') | Should -BeExactly $Kind
    $snapshot.HasFinalNewLine | Should -BeFalse
    foreach ($task in $snapshot.Tasks) {
      $task.Text | Should -BeExactly ($snapshot.Text.Substring($task.StartOffset, $task.EndOffset - $task.StartOffset))
    }
    $snapshot.Tasks[0].Text | Should -BeExactly (($content.Substring($snapshot.Tasks[0].StartOffset, $snapshot.Tasks[1].StartOffset - $snapshot.Tasks[0].StartOffset)))
    [Convert]::ToHexString([IO.File]::ReadAllBytes($path)) | Should -BeExactly ([Convert]::ToHexString($before))
    @(Get-ChildItem -LiteralPath $directory -Force).Count | Should -Be 1
  }

  It 'recognizes a BOM-first-line task and preserves BOM-inclusive offsets and Unicode' {
    $directory = New-BoardFixture
    $emoji = [char]::ConvertFromUtf32(0x1F680)
    $content = '- [ ] **Task 17.21** - First task ' + $emoji + [char]13 + [char]10 + '  - Risk: JoAnn' + [char]0x2019 + 's full text.'
    $path = Write-BoardFixture -Directory $directory -Text $content -Bom
    $snapshot = Read-CoordBoard -PlanningRoot $directory -SprintNumber 17

    $snapshot.HasUtf8Bom | Should -BeTrue
    $snapshot.Text[0] | Should -Be ([char]0xFEFF)
    $snapshot.Tasks.Count | Should -Be 1
    $snapshot.Tasks[0].Id | Should -BeExactly '17.21'
    $snapshot.Tasks[0].StartOffset | Should -Be 0
    $snapshot.Tasks[0].EndOffset | Should -Be $snapshot.Text.Length
    $snapshot.Tasks[0].Text | Should -BeExactly $snapshot.Text
    $snapshot.Tasks[0].Heading | Should -BeExactly ([string][char]0xFEFF + $content.Split([char]13)[0])
    [Convert]::ToHexString($snapshot.RawBytes) | Should -BeExactly ([Convert]::ToHexString([IO.File]::ReadAllBytes($path)))
  }

  It 'retains mixed line terminators and the exact final newline' {
    $directory = New-BoardFixture
    $content = '# Fixture' + [char]13 + [char]10 + '- [ ] **Task 17.21** - Read' + [char]10 + '  - Risk: full' + [char]13
    $null = Write-BoardFixture -Directory $directory -Text $content
    $snapshot = Read-CoordBoard -PlanningRoot $directory -SprintNumber 17
    $snapshot.Text | Should -BeExactly $content
    ($snapshot.NewLineKinds -join ',') | Should -BeExactly 'CRLF,LF,CR'
    $snapshot.HasFinalNewLine | Should -BeTrue
    $snapshot.Tasks[0].Text.EndsWith([string][char]13) | Should -BeTrue
  }

  It 'keeps task risk headings and nested headings but excludes real stream boundaries' {
    $directory = New-BoardFixture
    $content = @(
      '# Current Sprint: Sprint 17'
      '## Stream C - Clerk'
      '- [ ] **Task 17.21** - Reader'
      '### Risk'
      'Every risk paragraph survives.'
      '  ## Dependencies'
      '  Required dependency and recovery instructions survive.'
      '#### More detail'
      'Exact final task detail.'
      ''
      '## Stream D - Next stream'
      'New stream introduction is outside the preceding task.'
      '- [ ] **Task 17.22** - Consumer'
    ) -join [char]10
    $null = Write-BoardFixture -Directory $directory -Text $content
    $snapshot = Read-CoordBoard -PlanningRoot $directory -SprintNumber 17
    $snapshot.Tasks[0].Text | Should -Match '### Risk'
    $snapshot.Tasks[0].Text | Should -Match '  ## Dependencies'
    $snapshot.Tasks[0].Text | Should -Match 'Required dependency and recovery instructions survive\.'
    $snapshot.Tasks[0].Text | Should -Match 'Exact final task detail\.'
    $snapshot.Tasks[0].Text | Should -Not -Match 'Stream D|New stream introduction'
    $snapshot.Tasks[0].EndOffset | Should -Be ($content.IndexOf('## Stream D', [StringComparison]::Ordinal))
  }

  It 'ignores prose, quotes and task-like lines in backtick and tilde fences' {
    $directory = New-BoardFixture
    $ticks = [string][char]0x60
    $content = @(
      'A reference to **Task 17.99** is prose.'
      '- Discuss [ ] **Task 17.99** - prose'
      '> - [ ] **Task 17.99** - quotation'
      ($ticks * 4 + 'markdown')
      '- [ ] **Task 17.99** - code'
      ($ticks * 3)
      '- [ ] **Task 17.99** - still inside longer fence'
      ($ticks * 4)
      '  ~~~text'
      '- [ ] **Task 17.99** - tilde code'
      '  ~~~~'
      '- [ ] **Task 17.21** - Actual task'
      '  - Risk: inline task prose stays in its block.'
    ) -join [char]10
    $null = Write-BoardFixture -Directory $directory -Text $content
    $snapshot = Read-CoordBoard -PlanningRoot $directory -SprintNumber 17
    $snapshot.Tasks.Count | Should -Be 1
    $snapshot.Tasks[0].Id | Should -BeExactly '17.21'
    $snapshot.Tasks[0].Text | Should -Match 'inline task prose'
  }

  It 'keeps task-body fenced headings as text and ignores an unclosed fence through EOF' {
    $directory = New-BoardFixture
    $content = @(
      '- [ ] **Task 17.21** - Real'
      '~~~'
      '## Stream fake'
      '- [ ] **Task 17.21** - duplicate-looking code'
    ) -join [char]10
    $null = Write-BoardFixture -Directory $directory -Text $content
    $snapshot = Read-CoordBoard -PlanningRoot $directory -SprintNumber 17
    $snapshot.Tasks.Count | Should -Be 1
    $snapshot.Tasks[0].Text | Should -BeExactly $content
  }

  It 'rejects duplicate canonical task IDs before returning any snapshot' {
    $directory = New-BoardFixture
    $content = '- [ ] **Task 17.21.ab** - First' + [char]10 + '  - [x] **Task 17.21.ab** - Duplicate'
    $null = Write-BoardFixture -Directory $directory -Text $content
    { Read-CoordBoard -PlanningRoot $directory -SprintNumber 17 } | Should -Throw '*Duplicate task ID*'
  }

  It 'preserves case-distinct ID spellings without folding' {
    $directory = New-BoardFixture
    $content = '- [ ] **Task 17.21.ab** - Lower' + [char]10 + '- [ ] **Task 17.21.AB** - Upper'
    $null = Write-BoardFixture -Directory $directory -Text $content
    $snapshot = Read-CoordBoard -PlanningRoot $directory -SprintNumber 17
    ($snapshot.Tasks.Id -join ',') | Should -BeExactly '17.21.ab,17.21.AB'
  }

  It 'selects the numeric highest direct-root version rather than lexical order or sprint fallback' {
    $directory = New-BoardFixture
    $null = Write-BoardFixture -Directory $directory -Text 'fallback'
    $null = Write-BoardFixture -Directory $directory -Name 'TASKS_V2.md' -Text 'older'
    $expected = Write-BoardFixture -Directory $directory -Name 'TASKS_V10GPT5.5.md' -Text '- [ ] **Task 17.21** - Highest'
    $snapshot = Read-CoordBoard -PlanningRoot $directory -SprintNumber 17
    $snapshot.Version | Should -Be 10
    $snapshot.Path | Should -Be $expected
    $snapshot.Tasks[0].Id | Should -BeExactly '17.21'
  }

  It 'rejects equal highest numeric versions even when spelling or suffix differs' {
    $directory = New-BoardFixture
    $null = Write-BoardFixture -Directory $directory -Name 'TASKS_V10.md' -Text 'one'
    $null = Write-BoardFixture -Directory $directory -Name 'TASKS_V010-DBA1.md' -Text 'two'
    { Read-CoordBoard -PlanningRoot $directory -SprintNumber 17 } | Should -Throw '*Ambiguous highest*'
  }

  It 'does not mistake a lower-version tie for a highest-version ambiguity' {
    $directory = New-BoardFixture
    $null = Write-BoardFixture -Directory $directory -Name 'TASKS_V2.md' -Text 'one'
    $null = Write-BoardFixture -Directory $directory -Name 'TASKS_V02-DBA1.md' -Text 'two'
    $null = Write-BoardFixture -Directory $directory -Name 'TASKS_V3.md' -Text '- [ ] **Task 17.21** - Current'
    (Read-CoordBoard -PlanningRoot $directory -SprintNumber 17).Version | Should -Be 3
  }

  It 'ignores archived/history descendants and non-markdown version companions' {
    $directory = New-BoardFixture
    $expected = Write-BoardFixture -Directory $directory -Text '- [ ] **Task 17.21** - Current'
    foreach ($folder in @('Archived', 'SprintHistory')) {
      $child = Join-Path $directory $folder
      $null = New-Item -ItemType Directory -Path $child
      $null = Write-BoardFixture -Directory $child -Name 'TASKS_V999.md' -Text 'historical'
    }
    $null = Write-BoardFixture -Directory $directory -Name 'TASKS_V999.html' -Text 'companion'
    (Read-CoordBoard -PlanningRoot $directory -SprintNumber 17).Path | Should -Be $expected
  }

  It 'rejects malformed or overflowing version numbers instead of guessing fallback' -ForEach @(
    @{ Name = 'TASKS_Vdraft.md' },
    @{ Name = 'TASKS_V999999999999999999999999999999.md' }
  ) {
    $directory = New-BoardFixture
    $null = Write-BoardFixture -Directory $directory -Text '- [ ] **Task 17.21** - Fallback'
    $null = Write-BoardFixture -Directory $directory -Name $Name -Text 'invalid version'
    { Read-CoordBoard -PlanningRoot $directory -SprintNumber 17 } | Should -Throw '*Invalid TASKS_V numeric version*'
  }

  It 'uses the explicitly requested sprint filename with no other-sprint or ancestor fallback' {
    $directory = New-BoardFixture
    $null = Write-BoardFixture -Directory $directory -Name 'Tasks.Sprint0018.md' -Text 'other sprint'
    { Read-CoordBoard -PlanningRoot $directory -SprintNumber 17 } | Should -Throw '*Expected exactly one top-level board*'
    $null = Write-BoardFixture -Directory $directory -Text 'parent board'
    $child = Join-Path $directory 'child'
    $null = New-Item -ItemType Directory -Path $child
    { Read-CoordBoard -PlanningRoot $child -SprintNumber 17 } | Should -Throw '*Expected exactly one top-level board*'
  }

  It 'rejects relative or nonexistent planning roots' {
    { Read-CoordBoard -PlanningRoot '.' -SprintNumber 17 } | Should -Throw '*absolute filesystem directory*'
    { Read-CoordBoard -PlanningRoot (Join-Path $script:readBoardFixtureBase 'missing') -SprintNumber 17 } | Should -Throw '*must exist*'
  }

  It 'rejects malformed UTF-8 without changing the input bytes' {
    $directory = New-BoardFixture
    $path = Join-Path $directory 'Tasks.Sprint0017.md'
    [byte[]]$bytes = @(0xC3, 0x28)
    [IO.File]::WriteAllBytes($path, $bytes)
    { Read-CoordBoard -PlanningRoot $directory -SprintNumber 17 } | Should -Throw
    [Convert]::ToHexString([IO.File]::ReadAllBytes($path)) | Should -BeExactly 'C328'
  }

  It 'returns an explicit empty task array for a board with no canonical tasks' {
    $directory = New-BoardFixture
    $null = Write-BoardFixture -Directory $directory -Text '# Fixture with prose only'
    $snapshot = Read-CoordBoard -PlanningRoot $directory -SprintNumber 17
    $snapshot.Tasks.Count | Should -Be 0
    $snapshot.Text | Should -BeExactly '# Fixture with prose only'
  }

  It 'supports WhatIf without creating output or changing the source' {
    $directory = New-BoardFixture
    $path = Write-BoardFixture -Directory $directory -Text '- [ ] **Task 17.21** - Read only'
    $before = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    $snapshot = Read-CoordBoard -PlanningRoot $directory -SprintNumber 17 -WhatIf
    $snapshot.Tasks.Count | Should -Be 1
    (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash | Should -BeExactly $before
    @(Get-ChildItem -LiteralPath $directory -Force).Count | Should -Be 1
  }

  It 'round-trips a representative existing-task claim/status annotation through the installed renderer' -Tag 'RendererSmoke' {
    $directory = New-BoardFixture
    $content = @(
      '# Current Sprint: Sprint 17 - Disposable reader smoke'
      ''
      'Source: DISPOSABLE-READER-SMOKE'
      'Last updated: fixture'
      ''
      '## Goal'
      ''
      'Read and annotate an existing task only.'
      ''
      '## Stream C - Clerk [INITIAL]'
      ''
      '- [ ] **Task 17.21** [ATAP.Utilities] - Read the board'
      '  - Files: private/Read-CoordBoard.ps1'
      '  - Acceptance: Existing task stays open.'
      '  - Status: Planned.'
      ''
      '- [x] **Task 17.22.ab** [ATAP.Utilities] - Preserve unrelated task'
      '  - Status: Historical completed fixture.'
    ) -join [char]10
    $path = Write-BoardFixture -Directory $directory -Text $content
    $before = Read-CoordBoard -PlanningRoot $directory -SprintNumber 17
    $target = $before.Tasks[0]
    $annotation = '  - Status: CLAIMED / source-ready; holder=disposable-senior; claim=fixture-155.'
    $newBlock = $target.Text.Replace('  - Status: Planned.', $annotation)
    $afterText = $before.Text.Substring(0, $target.StartOffset) + $newBlock + $before.Text.Substring($target.EndOffset)
    [IO.File]::WriteAllText($path, $afterText, [Text.UTF8Encoding]::new($false))
    $after = Read-CoordBoard -PlanningRoot $directory -SprintNumber 17
    ($after.Tasks.Id -join ',') | Should -BeExactly ($before.Tasks.Id -join ',')
    $after.Tasks[0].Checkbox | Should -BeExactly $target.Checkbox
    $after.Tasks[1].Text | Should -BeExactly $before.Tasks[1].Text
    $after.Tasks[0].Text | Should -Match 'CLAIMED / source-ready'

    # The BuildTooling facade also exports this command. Select the same exact
    # installed child module as the production candidate renderer, not ambient lookup.
    Import-Module -FullyQualifiedName @{
      ModuleName = 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell'; RequiredVersion = '0.1.61'
    } -ErrorAction Stop
    $renderer = Get-Command -Name 'Convert-TasksMdToSprintBoard' -FullyQualifiedModule @{
      ModuleName = 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell'; RequiredVersion = '0.1.61'
    } -CommandType Function -ErrorAction Stop
    $renderer.ModuleName | Should -BeExactly 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell'
    $renderer.Module.Version | Should -Be ([version]'0.1.61')
    $renderer.Module.Path | Should -BeExactly 'C:\Program Files\PowerShell\Modules\ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell\0.1.61\ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell.psm1'
    $renderer.Module.ModuleBase | Should -Not -Match '-wt-'
    $htmlPath = Join-Path $directory 'Disposable.Sprint0017.html'
    $beforeRenderHash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    $result = & $renderer -TasksFilePath $path -OutputPath $htmlPath -Confirm:$false -WhatIf:$false
    $result.TaskCount | Should -Be 2
    $result.StatusCounts.open | Should -Be 1
    $result.StatusCounts.closed | Should -Be 1
    $html = [IO.File]::ReadAllText($htmlPath)
    $html | Should -Match 'CLAIMED / source-ready'
    $html | Should -Match '17\.21'
    $html | Should -Match '17\.22\.ab'
    (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash | Should -BeExactly $beforeRenderHash
  }
}

Describe 'Read-CoordBoard verified cloud metadata boundary' -Tag 'Unit', 'ReparseMetadata' {
  BeforeEach {
    $script:coordCloudSavedExitCode = $global:LASTEXITCODE
    $script:coordCloudDirectory = New-BoardFixture
    $script:coordCloudBoard = Write-BoardFixture -Directory $script:coordCloudDirectory -Text '- [ ] **Task 17.21** - Mocked cloud board'
    $script:coordCloudFile = [PSCustomObject]@{
      Name = 'Tasks.Sprint0017.md'
      Extension = '.md'
      FullName = $script:coordCloudBoard
      Attributes = [IO.FileAttributes]::Archive -bor [IO.FileAttributes]::ReparsePoint
      LinkTarget = $null
    }
    $script:coordCloudExit = 0
    $script:coordCloudOutput = @('Reparse Tag Value : 0x9000601a')
    Mock Get-ChildItem { $script:coordCloudFile } -ParameterFilter {
      $LiteralPath -eq $script:coordCloudDirectory -and $File -and $Force
    }
    # Pester 6 filtered mocks are strict: handle the logger lookup explicitly.
    Mock Get-Command {
      if (@($Name).Count -eq 1 -and @($Name)[0] -ceq 'Write-PSFMessage') {
        [PSCustomObject]@{ Name = 'Write-PSFMessage'; CommandType = 'Function' }
      } else {
        throw 'Unexpected command lookup in reparse metadata fixture.'
      }
    }
    # Every native-command lookup is intercepted; no test launches fsutil.
    Mock Get-Command {
      {
        if ($args.Count -ne 3 -or $args[0] -cne 'reparsepoint' -or $args[1] -cne 'query') {
          throw 'Unexpected metadata operation.'
        }
        $global:LASTEXITCODE = $script:coordCloudExit
        $script:coordCloudOutput
      }
    } -ParameterFilter { $CommandType -eq 'Application' }
    Mock Write-PSFMessage {}
  }

  AfterEach {
    $global:LASTEXITCODE = $script:coordCloudSavedExitCode
  }

  It 'accepts cloud-family tag <Tag> with no link target and preserves source bytes' -ForEach @(
    @{ Tag = '0x9000001a' },
    @{ Tag = '0x9000601a' },
    @{ Tag = '0x9000f01a' }
  ) {
    $script:coordCloudOutput = @('Reparse Tag Value : ' + $Tag)
    $before = [IO.File]::ReadAllBytes($script:coordCloudBoard)
    $snapshot = Read-CoordBoard -PlanningRoot $script:coordCloudDirectory -SprintNumber 17

    $snapshot.Tasks[0].Id | Should -BeExactly '17.21'
    [Convert]::ToHexString($snapshot.RawBytes) | Should -BeExactly ([Convert]::ToHexString($before))
    $snapshot.Sha256 | Should -BeExactly ([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($before)).ToLowerInvariant())
    [Convert]::ToHexString([IO.File]::ReadAllBytes($script:coordCloudBoard)) | Should -BeExactly ([Convert]::ToHexString($before))
    @([IO.Directory]::GetFiles($script:coordCloudDirectory)).Count | Should -Be 1
    $snapshot.PSObject.Properties.Name | Should -Not -Contain 'ReparseTag'
    $snapshot.PSObject.Properties.Name | Should -Not -Contain 'QueryOutput'
    Should -Invoke Get-Command -Exactly -Times 1 -ParameterFilter {
      $CommandType -eq 'Application' -and $Name -eq (Join-Path ([Environment]::SystemDirectory) 'fsutil.exe')
    }
  }

  It 'rejects any non-null link target before the native lookup, including <Label>' -ForEach @(
    @{ Target = 'elsewhere'; Label = 'symbolic or junction target' },
    @{ Target = ''; Label = 'empty but non-null target' }
  ) {
    $script:coordCloudFile.LinkTarget = $Target
    { Read-CoordBoard -PlanningRoot $script:coordCloudDirectory -SprintNumber 17 } |
      Should -Throw '*not a verified Windows cloud placeholder*'
    Should -Invoke Get-Command -Exactly -Times 0 -ParameterFilter { $CommandType -eq 'Application' }
  }

  It 'rejects name-surrogate or unknown tag <Tag> even when LinkTarget is null' -ForEach @(
    @{ Tag = '0xa000000c' },
    @{ Tag = '0xa0000003' },
    @{ Tag = '0x80000042' },
    @{ Tag = '0x9000001b' }
  ) {
    $script:coordCloudOutput = @('Reparse Tag Value : ' + $Tag)
    { Read-CoordBoard -PlanningRoot $script:coordCloudDirectory -SprintNumber 17 } |
      Should -Throw '*not a verified Windows cloud placeholder*'
    Should -Invoke Get-Command -Exactly -Times 1 -ParameterFilter { $CommandType -eq 'Application' }
  }

  It 'rejects <Failure> without returning or logging opaque query output' -ForEach @(
    @{ Failure = 'nonzero exit'; Exit = 5; Lines = @('Reparse Tag Value : 0x9000601a', 'OPAQUE-METADATA-NEVER-EMIT') },
    @{ Failure = 'missing tag'; Exit = 0; Lines = @('OPAQUE-METADATA-NEVER-EMIT') },
    @{ Failure = 'ambiguous tags'; Exit = 0; Lines = @('Reparse Tag Value : 0x9000601a', 'Reparse Tag Value : 0x9000601a', 'OPAQUE-METADATA-NEVER-EMIT') },
    @{ Failure = 'unexpected tag format'; Exit = 0; Lines = @('Reparse Tag Value : 0x9000601a junk', 'OPAQUE-METADATA-NEVER-EMIT') }
  ) {
    $script:coordCloudExit = $Exit
    $script:coordCloudOutput = $Lines
    $captured = @()
    $failureRecord = $null
    try {
      $captured = @(Read-CoordBoard -PlanningRoot $script:coordCloudDirectory -SprintNumber 17)
    } catch {
      $failureRecord = $_
    }

    $failureRecord | Should -Not -BeNullOrEmpty
    $failureRecord.Exception.Message | Should -BeExactly 'Selected board reparse metadata is not a verified Windows cloud placeholder.'
    $failureRecord.Exception.Message | Should -Not -Match 'OPAQUE'
    $captured.Count | Should -Be 0
    Should -Invoke Write-PSFMessage -Exactly -Times 0 -ParameterFilter { $Message -like '*OPAQUE*' }
    Should -Invoke Get-Command -Exactly -Times 1 -ParameterFilter { $CommandType -eq 'Application' }
  }

  It 'rejects unavailable native metadata tooling with a safe error' {
    Mock Get-Command { throw 'OPAQUE-METADATA-NEVER-EMIT' } -ParameterFilter { $CommandType -eq 'Application' }
    { Read-CoordBoard -PlanningRoot $script:coordCloudDirectory -SprintNumber 17 } |
      Should -Throw '*not a verified Windows cloud placeholder*'
    Should -Invoke Write-PSFMessage -Exactly -Times 0 -ParameterFilter { $Message -like '*OPAQUE*' }
  }

  It 'rejects missing link-target metadata instead of treating missing as null' {
    $script:coordCloudFile.PSObject.Properties.Remove('LinkTarget')
    { Read-CoordBoard -PlanningRoot $script:coordCloudDirectory -SprintNumber 17 } |
      Should -Throw '*not a verified Windows cloud placeholder*'
    Should -Invoke Get-Command -Exactly -Times 0 -ParameterFilter { $CommandType -eq 'Application' }
  }

  It 'does not query native metadata for an ordinary file' {
    $script:coordCloudFile.Attributes = [IO.FileAttributes]::Archive
    $snapshot = Read-CoordBoard -PlanningRoot $script:coordCloudDirectory -SprintNumber 17
    $snapshot.Tasks.Count | Should -Be 1
    Should -Invoke Get-Command -Exactly -Times 0 -ParameterFilter { $CommandType -eq 'Application' }
  }
}
