BeforeAll {
  function Write-PSFMessage {
    param(
      [string] $FunctionName,
      [string] $ModuleName,
      [string] $Level,
      [string] $Message,
      [string] $Tag
    )

    $null = @($FunctionName, $ModuleName, $Level, $Message, $Tag)
  }

  function New-HistoryTestRepository {
    [CmdletBinding(SupportsShouldProcess)]
    param(
      [Parameter(Mandatory)]
      [string] $Root
    )

    if (-not $PSCmdlet.ShouldProcess($Root, 'Create temporary Git history repository')) {
      return
    }

    $null = New-Item -ItemType Directory -Path $Root -Force
    & git -C $Root init --quiet
    & git -C $Root config user.email 'restore-history-tests@example.invalid'
    & git -C $Root config user.name 'Restore History Tests'
    & git -C $Root config core.autocrlf false

    $null = New-Item -ItemType Directory -Path (Join-Path $Root 'one') -Force
    $null = New-Item -ItemType Directory -Path (Join-Path $Root 'two') -Force

    [System.IO.File]::WriteAllBytes(
      (Join-Path $Root 'TASKS.md'),
      [byte[]] @(0, 1, 2, 10, 13, 127, 128, 255)
    )
    [System.IO.File]::WriteAllBytes(
      (Join-Path $Root 'one\TASKS.md'),
      [System.Text.Encoding]::UTF8.GetBytes('first nested task')
    )
    [System.IO.File]::WriteAllBytes(
      (Join-Path $Root 'two\TASKS.md'),
      [System.Text.Encoding]::UTF8.GetBytes('second nested task')
    )

    & git -C $Root add --all
    & git -C $Root commit --quiet -m 'test history'
    if ($LASTEXITCODE -ne 0) {
      throw 'Unable to create test history commit.'
    }

    (& git -C $Root rev-parse HEAD).Trim()
  }

  $functionPath = Join-Path $PSScriptRoot '..\..\public\Restore-SprintHistoryArtifacts.ps1'
  . $functionPath
}

Describe 'Restore-SprintHistoryArtifacts' {
  BeforeEach {
    $script:testRoot = Join-Path (
      [System.IO.Path]::GetTempPath()
    ) "restore_sprint_history_$([System.Guid]::NewGuid().ToString('N'))"
    $script:sourceRef = New-HistoryTestRepository -Root $script:testRoot
  }

  AfterEach {
    Remove-Item -LiteralPath $script:testRoot -Recurse -Force -ErrorAction SilentlyContinue
  }

  It 'restores exact Git blob bytes while preserving repository-relative paths' {
    $result = Restore-SprintHistoryArtifacts `
      -PlanningRoot $script:testRoot `
      -SprintNumber 7 `
      -SourceRef $script:sourceRef `
      -SourcePath 'TASKS.md', 'one/TASKS.md', 'two/TASKS.md' `
      -NotebookPath 'SprintRetrospective/Notebook-SprintWorkSession-0007-End.md' `
      -Confirm:$false

    $historyRoot = Join-Path $script:testRoot 'SprintHistory\Sprint0007'
    $result.Ok | Should -BeTrue
    @($result.Files | Where-Object Status -eq 'Restored').Count | Should -Be 3

    foreach ($relativePath in 'TASKS.md', 'one\TASKS.md', 'two\TASKS.md') {
      $sourceBytes = [System.IO.File]::ReadAllBytes((Join-Path $script:testRoot $relativePath))
      $restoredBytes = [System.IO.File]::ReadAllBytes((Join-Path $historyRoot $relativePath))
      [System.Convert]::ToBase64String($restoredBytes) |
        Should -Be ([System.Convert]::ToBase64String($sourceBytes))
    }

    $manifest = Get-Content -LiteralPath (Join-Path $historyRoot 'Reconstruction.json') -Raw |
      ConvertFrom-Json
    $manifest.SprintNumber | Should -Be '0007'
    $manifest.SourceRef | Should -Be $script:sourceRef
    @($manifest.SourcePaths).Count | Should -Be 3

    $rerun = Restore-SprintHistoryArtifacts `
      -PlanningRoot $script:testRoot `
      -SprintNumber 7 `
      -SourceRef $script:sourceRef `
      -SourcePath 'TASKS.md', 'one/TASKS.md', 'two/TASKS.md' `
      -NotebookPath 'SprintRetrospective/Notebook-SprintWorkSession-0007-End.md' `
      -Confirm:$false

    $rerun.Ok | Should -BeTrue
    @($rerun.Files | Where-Object Status -eq 'Identical').Count | Should -Be 3
  }

  It 'preserves different destination content and reports a structured conflict' {
    $null = Restore-SprintHistoryArtifacts `
      -PlanningRoot $script:testRoot `
      -SprintNumber 8 `
      -SourceRef $script:sourceRef `
      -SourcePath 'TASKS.md' `
      -Confirm:$false

    $destination = Join-Path $script:testRoot 'SprintHistory\Sprint0008\TASKS.md'
    [System.IO.File]::WriteAllBytes(
      $destination,
      [System.Text.Encoding]::UTF8.GetBytes('reviewed replacement')
    )

    $result = Restore-SprintHistoryArtifacts `
      -PlanningRoot $script:testRoot `
      -SprintNumber 8 `
      -SourceRef $script:sourceRef `
      -SourcePath 'TASKS.md' `
      -Confirm:$false

    $result.Ok | Should -BeFalse
    $result.Files[0].Status | Should -Be 'PreservedConflict'
    $result.Failures[0].Kind | Should -Be 'ContentConflict'
    [System.Text.Encoding]::UTF8.GetString(
      [System.IO.File]::ReadAllBytes($destination)
    ) | Should -Be 'reviewed replacement'
  }

  It 'reports missing source paths without creating a reconstruction manifest' {
    $result = Restore-SprintHistoryArtifacts `
      -PlanningRoot $script:testRoot `
      -SprintNumber 9 `
      -SourceRef $script:sourceRef `
      -SourcePath 'missing/TASKS.md' `
      -Confirm:$false

    $result.Ok | Should -BeFalse
    $result.Files[0].Status | Should -Be 'MissingSource'
    $result.Failures[0].Kind | Should -Be 'MissingSource'
    Test-Path -LiteralPath $result.ManifestPath | Should -BeFalse
  }

  It 'preserves an existing manifest when provenance differs' {
    $null = Restore-SprintHistoryArtifacts `
      -PlanningRoot $script:testRoot `
      -SprintNumber 10 `
      -SourceRef $script:sourceRef `
      -SourcePath 'TASKS.md' `
      -NotebookPath 'Notebook-A.md' `
      -Confirm:$false
    $manifestPath = Join-Path $script:testRoot 'SprintHistory\Sprint0010\Reconstruction.json'
    $originalManifest = Get-Content -LiteralPath $manifestPath -Raw

    $result = Restore-SprintHistoryArtifacts `
      -PlanningRoot $script:testRoot `
      -SprintNumber 10 `
      -SourceRef $script:sourceRef `
      -SourcePath 'TASKS.md' `
      -NotebookPath 'Notebook-B.md' `
      -Confirm:$false

    $result.Ok | Should -BeFalse
    $result.Failures[0].Kind | Should -Be 'ProvenanceConflict'
    Get-Content -LiteralPath $manifestPath -Raw | Should -Be $originalManifest
  }

  It 'supports WhatIf without writing files or provenance' {
    $result = Restore-SprintHistoryArtifacts `
      -PlanningRoot $script:testRoot `
      -SprintNumber 11 `
      -SourceRef $script:sourceRef `
      -SourcePath 'TASKS.md' `
      -WhatIf

    $result.Ok | Should -BeTrue
    $result.Files[0].Status | Should -Be 'Planned'
    Test-Path -LiteralPath $result.HistoryRoot | Should -BeFalse
  }

  It 'rejects a source path that can escape the sprint-history directory' {
    {
      Restore-SprintHistoryArtifacts `
        -PlanningRoot $script:testRoot `
        -SprintNumber 12 `
        -SourceRef $script:sourceRef `
        -SourcePath '../TASKS.md' `
        -Confirm:$false
    } | Should -Throw '*invalid path segment*'
  }
}
