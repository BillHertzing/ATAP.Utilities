#Requires -Version 7.0

BeforeAll {
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
  }

  . "$PSScriptRoot\..\..\public\Get-SprintHistoryReconstruction.ps1"
}

Describe 'Get-SprintHistoryReconstruction' -Tag 'Unit' {
  BeforeEach {
    $script:planningRoot = Join-Path ([System.IO.Path]::GetTempPath()) "sprint_history_$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $script:planningRoot -Force | Out-Null
  }

  AfterEach {
    Remove-Item -LiteralPath $script:planningRoot -Recurse -Force -ErrorAction SilentlyContinue
  }

  It 'selects the highest sprint number across lifecycle evidence families' {
    New-Item -ItemType Directory -Path (Join-Path $script:planningRoot 'SprintRetrospective') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $script:planningRoot 'SprintHistory\Sprint0010') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $script:planningRoot 'Snapshots\0011') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $script:planningRoot 'SprintRetrospective\Notebook-SprintWorkSession-0010-End.md') -Value '# End'
    Set-Content -LiteralPath (Join-Path $script:planningRoot 'TASKS.Sprint0011.md') -Value '# Current Sprint'

    $result = Get-SprintHistoryReconstruction -PlanningRoot $script:planningRoot

    $result.LastCompletedSprintNumber | Should -Be 11
    $result.Evidence.Source | Should -Contain 'RetrospectiveNotebook'
    $result.Evidence.Source | Should -Contain 'SprintHistoryFolder'
    $result.Evidence.Source | Should -Contain 'SnapshotFolder'
    $result.Evidence.Source | Should -Contain 'TaskArtifact'
  }

  It 'reports structured warnings when evidence sources disagree' {
    New-Item -ItemType Directory -Path (Join-Path $script:planningRoot 'SprintRetrospective') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $script:planningRoot 'Snapshots\0011') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $script:planningRoot 'SprintRetrospective\Notebook-SprintWorkSession-0010-End.md') -Value '# End'

    $result = Get-SprintHistoryReconstruction -PlanningRoot $script:planningRoot

    $result.LastCompletedSprintNumber | Should -Be 11
    $result.Disagreements.Source | Should -Contain 'RetrospectiveNotebook'
    $result.Warnings.Code | Should -Contain 'SprintNumberDisagreement'
  }
}
