# AI assisted using ./claude/Rules/Powershell.md as guidelines
# Pester 5+ tests for Save-SprintRetrospectiveSnapshot

BeforeAll {
  $functionName = 'Save-SprintRetrospectiveSnapshot'
  if (-not (Get-Command -Name $functionName -CommandType Function -ErrorAction SilentlyContinue)) {
    $functionPath = Join-Path $PSScriptRoot -ChildPath "../../public/$functionName.ps1"
    if (Test-Path $functionPath) { . $functionPath } else { throw "Function file not found: $functionPath" }
  }

  # Tests run cross-platform inside the coding sandbox. PSFramework is required
  # by the function under test but not by the test logic itself - import if
  # available so Write-PSFMessage no-ops cleanly.
  if (-not (Get-Module -Name PSFramework -ErrorAction SilentlyContinue)) {
    Import-Module PSFramework -ErrorAction SilentlyContinue
  }

  # Build an isolated GitRoot containing two fake sprint worktrees and a
  # _Planning sibling. Initialise tiny git repos so the function's `git log`
  # calls return real (but empty) data.
  $script:gitRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('srs-test-' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $script:gitRoot -Force | Out-Null

  $script:sprintNumber = '0007'
  $script:wtA = Join-Path $script:gitRoot "ATAP.Utilities-wt-100-sprint-$($script:sprintNumber)-work-items"
  $script:wtB = Join-Path $script:gitRoot "AceCommander-wt-101-sprint-$($script:sprintNumber)-work-items"
  $script:planning = Join-Path $script:gitRoot "_Planning-wt-102-sprint-$($script:sprintNumber)-work-items"
  New-Item -ItemType Directory -Path $script:wtA, $script:wtB, $script:planning -Force | Out-Null

  foreach ($wt in @($script:wtA, $script:wtB)) {
    & git -C $wt init --quiet --initial-branch=main 2>$null
    & git -C $wt config user.email 'test@example.com'
    & git -C $wt config user.name 'Pester Tester'
    Set-Content -LiteralPath (Join-Path $wt 'README.md') -Value 'seed' -Encoding UTF8
    & git -C $wt add . 2>$null | Out-Null
    & git -C $wt commit --quiet -m 'seed' 2>$null | Out-Null
  }

  # Seed promotion + test-result artefacts in worktree A's _generated tree.
  $auditA = Join-Path $script:wtA '_generated' 'audit'
  New-Item -ItemType Directory -Path $auditA -Force | Out-Null
  @{
    package = 'Foo.PSModule'; version = '1.2.3'; from = 'Experimental'; to = 'Development'
  } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $auditA 'promotion-001.json')
  @{
    package = 'Bar.NuGet'; version = '0.4.0'; from = 'Development'; to = 'Testing'
  } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $auditA 'promotion-002.json')

  $resultsA = Join-Path $script:wtA '_generated' 'pester'
  New-Item -ItemType Directory -Path $resultsA -Force | Out-Null
  $junit = @'
<?xml version="1.0" encoding="utf-8"?>
<testsuites tests="10" failures="1" skipped="2">
  <testsuite name="Sample" tests="10" failures="1" skipped="2"/>
</testsuites>
'@
  Set-Content -LiteralPath (Join-Path $resultsA 'pester-results.xml') -Value $junit -Encoding UTF8
}

AfterAll {
  if (Test-Path $script:gitRoot) {
    Remove-Item -Recurse -Force $script:gitRoot -ErrorAction SilentlyContinue
  }
}

Describe 'Save-SprintRetrospectiveSnapshot' {

  It 'function is loaded' {
    Get-Command -Name 'Save-SprintRetrospectiveSnapshot' -CommandType Function |
      Should -Not -BeNullOrEmpty
  }

  It 'returns a structured object with all documented fields populated' {
    $snap = Save-SprintRetrospectiveSnapshot `
      -SprintNumber $script:sprintNumber `
      -GitRoot $script:gitRoot `
      -PlanningRoot $script:planning `
      -SprintStart ((Get-Date).ToUniversalTime().AddDays(-30))

    $snap | Should -Not -BeNullOrEmpty
    $snap.sprintNumber          | Should -Be $script:sprintNumber
    # GitRoot contains two downstream worktrees plus _Planning, all matching
    # the `*-wt-*-sprint-NNNN-work-items` pattern (the same convention
    # Clear-SprintGeneratedArtifacts uses).
    $snap.workTreesScanned      | Should -Be 3
    $snap.snapshotPath          | Should -Match 'SprintRetrospectiveSnapshot-0007-\d{8}T\d{6}Z\.json$'
    $snap.elapsedDays           | Should -BeGreaterThan 0
    $snap.packagePromotionCount | Should -Be 2
    $snap.testStats.totalTests  | Should -Be 10
    $snap.testStats.failed      | Should -Be 1
    $snap.testStats.skipped     | Should -Be 2
    $snap.testStats.passed      | Should -Be 7
    $snap.testStats.resultFiles | Should -Be 1
    $snap.impressions           | Should -BeNullOrEmpty
  }

  It 'writes a JSON snapshot file to the expected location' {
    $snap = Save-SprintRetrospectiveSnapshot `
      -SprintNumber $script:sprintNumber `
      -GitRoot $script:gitRoot `
      -PlanningRoot $script:planning `
      -SprintStart ((Get-Date).ToUniversalTime().AddDays(-30))

    Test-Path -LiteralPath $snap.snapshotPath | Should -BeTrue
    $reloaded = Get-Content -LiteralPath $snap.snapshotPath -Raw | ConvertFrom-Json
    $reloaded.sprintNumber          | Should -Be $script:sprintNumber
    $reloaded.packagePromotionCount | Should -Be 2
    $reloaded.testStats.totalTests  | Should -Be 10
  }

  It 'does NOT write a new snapshot file when -WhatIf is supplied' {
    # Use a dedicated PlanningRoot so previous-test snapshots don't pollute the
    # file-count comparison.
    $isolated = Join-Path $script:gitRoot ("_Planning-whatif-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $isolated -Force | Out-Null
    $countBefore = (Get-ChildItem -Path $isolated -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count

    $snap = Save-SprintRetrospectiveSnapshot `
      -SprintNumber $script:sprintNumber `
      -GitRoot $script:gitRoot `
      -PlanningRoot $isolated `
      -SprintStart ((Get-Date).ToUniversalTime().AddDays(-30)) `
      -WhatIf

    $snap | Should -Not -BeNullOrEmpty
    Test-Path -LiteralPath $snap.snapshotPath | Should -BeFalse

    $countAfter = (Get-ChildItem -Path $isolated -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count
    $countAfter | Should -Be $countBefore
  }

  It 'captures supplied impressions verbatim and skips prompting' {
    $snap = Save-SprintRetrospectiveSnapshot `
      -SprintNumber $script:sprintNumber `
      -GitRoot $script:gitRoot `
      -PlanningRoot $script:planning `
      -SprintStart ((Get-Date).ToUniversalTime().AddDays(-30)) `
      -Impressions @('Promotion smoother this sprint', 'Flyway re-import still flaky')

    $snap.impressions.Count   | Should -Be 2
    $snap.impressions[0]      | Should -Be 'Promotion smoother this sprint'
    $snap.impressions[1]      | Should -Be 'Flyway re-import still flaky'
  }

  It 'throws when GitRoot does not exist' {
    {
      Save-SprintRetrospectiveSnapshot `
        -SprintNumber $script:sprintNumber `
        -GitRoot (Join-Path ([System.IO.Path]::GetTempPath()) ('missing-' + [guid]::NewGuid().ToString('N'))) `
        -PlanningRoot $script:planning
    } | Should -Throw
  }

  It 'validates SprintNumber pattern (rejects non-4-digit input)' {
    {
      Save-SprintRetrospectiveSnapshot `
        -SprintNumber '7' `
        -GitRoot $script:gitRoot `
        -PlanningRoot $script:planning
    } | Should -Throw
  }

  It 'returns zero PR count and zero promotions when nothing matches the sprint window' {
    # Force start time into the far future so no commits/files qualify.
    $snap = Save-SprintRetrospectiveSnapshot `
      -SprintNumber $script:sprintNumber `
      -GitRoot $script:gitRoot `
      -PlanningRoot $script:planning `
      -SprintStart ((Get-Date).ToUniversalTime().AddYears(50)) `
      -WhatIf

    $snap.prCount               | Should -Be 0
    $snap.packagePromotionCount | Should -Be 0
    $snap.testStats.resultFiles | Should -Be 0
  }
}
