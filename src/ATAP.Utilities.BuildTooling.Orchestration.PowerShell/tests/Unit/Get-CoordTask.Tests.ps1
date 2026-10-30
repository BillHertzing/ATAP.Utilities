param([Parameter()][ValidateNotNullOrEmpty()][string] $FixtureRoot = $(if ([Environment]::MachineName -ieq 'UTAT022') { 'D:\ATAPArtifacts\Sprint0017\Task17.22\PackageTests' } else { throw 'FixtureRoot must be supplied explicitly on this host.' }))

BeforeAll {
  if (-not [IO.Path]::IsPathFullyQualified($FixtureRoot)) { throw 'FixtureRoot must be absolute.' }
  $script:fixtureBase = Join-Path $FixtureRoot ([guid]::NewGuid().ToString('N'))
  $null = New-Item -ItemType Directory -Path $script:fixtureBase -Force
  . (Join-Path $PSScriptRoot '../../public/Get-CoordTask.ps1')
  function New-TaskBoard {
    $dir = Join-Path $script:fixtureBase ([guid]::NewGuid().ToString('N'))
    $null = New-Item -ItemType Directory -Path $dir
    $dir
  }
}

Describe 'Get-CoordTask compact board projection' -Tag 'Unit' {
  It 'returns compact and exact optional task text without changing input' {
    $dir = New-TaskBoard
    $text = "- [x] **Task 17.22** - Read`r`n  - Risk: exact.`r`n  - Dependency: exact.`r`n- [ ] **Task 17.23** - Other`r`n"
    $path = Join-Path $dir 'Tasks.Sprint0017.md'
    [IO.File]::WriteAllText($path, $text, [Text.UTF8Encoding]::new($false))
    $before = (Get-FileHash $path).Hash
    $compact = @(Get-CoordTask -PlanningRoot $dir -SprintNumber 17 -TaskId '17.22')
    $compact.Count | Should -Be 1
    $compact[0].Outcome | Should -BeExactly 'Found'
    $compact[0].Checked | Should -BeTrue
    $compact[0].FullTextIncluded | Should -BeFalse
    $compact[0].FullText | Should -BeNullOrEmpty
    $compact[0].PSObject.Properties.Name | Should -Not -Contain 'RawBytes'
    $full = Get-CoordTask -PlanningRoot $dir -SprintNumber 17 -TaskId '17.22' -IncludeFullText
    $full.FullTextIncluded | Should -BeTrue
    $full.FullText | Should -BeExactly ($text.Substring(0, $text.IndexOf('- [ ] **Task 17.23**', [StringComparison]::Ordinal)))
    (Get-FileHash $path).Hash | Should -BeExactly $before
    @(Get-ChildItem $dir -Force).Count | Should -Be 1
  }
  It 'returns NotFound for unknown, wildcard and differently cased IDs' -ForEach @(
    @{ Id = '17.99' }, @{ Id = '17.22.*' }, @{ Id = '17.22.A' }
  ) {
    $dir = New-TaskBoard
    [IO.File]::WriteAllText((Join-Path $dir 'Tasks.Sprint0017.md'), '- [ ] **Task 17.22.a** - Lowercase')
    $result = @(Get-CoordTask -PlanningRoot $dir -SprintNumber 17 -TaskId $Id -IncludeFullText)
    $result.Count | Should -Be 1
    $result[0].Outcome | Should -BeExactly 'NotFound'
    $result[0].Checked | Should -BeNullOrEmpty
    $result[0].Heading | Should -BeNullOrEmpty
    $result[0].FullText | Should -BeNullOrEmpty
    $result[0].FullTextIncluded | Should -BeFalse
  }
  It 'uses the highest versioned board and propagates ambiguous selection errors' {
    $dir = New-TaskBoard
    [IO.File]::WriteAllText((Join-Path $dir 'TASKS_V1.md'), '- [ ] **Task 17.22** - Old')
    [IO.File]::WriteAllText((Join-Path $dir 'TASKS_V2.md'), '- [x] **Task 17.22** - New')
    $result = Get-CoordTask -PlanningRoot $dir -SprintNumber 17 -TaskId '17.22'
    $result.Heading | Should -Match 'New$'
    [IO.File]::WriteAllText((Join-Path $dir 'TASKS_V2-other.md'), '- [ ] **Task 17.22** - Ambiguous')
    { Get-CoordTask -PlanningRoot $dir -SprintNumber 17 -TaskId '17.22' } | Should -Throw
  }
}
