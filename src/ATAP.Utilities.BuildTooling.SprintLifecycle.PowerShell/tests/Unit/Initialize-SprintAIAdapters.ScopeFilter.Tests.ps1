BeforeAll {
  $script:manifestPath = Join-Path $PSScriptRoot '..' '..' 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell.psd1'
  Import-Module $script:manifestPath -Force
}

# Task 12.2.b (SC-0236): Initialize-SprintAIAdapters is a thin delegate over the
# single Invoke-SprintAIAdapterLifecycle code path. It must NOT perform its own
# direct instructions-domain render (the historical junction-scope-filtered
# Render-AIAdapters call) — that duplicated the instructions render through a
# second code path. These tests replace the former manifest scope-filter tests
# (Task 10.3.f), whose filtering behavior was removed with the duplicate render.
Describe 'Initialize-SprintAIAdapters delegates to the single lifecycle code path (Task 12.2.b)' {
  BeforeEach {
    $script:source = Join-Path $TestDrive 'SharedVSCode'
    $script:tools = Join-Path $script:source '.ai/tools'
    $script:manifests = Join-Path $script:source '.ai/manifests'
    $script:target = Join-Path $TestDrive 'target'
    $script:capture = Join-Path $TestDrive 'direct-render-was-called.json'
    New-Item -ItemType Directory -Path $script:tools, $script:manifests, $script:target -Force | Out-Null

    # Canary renderer: if the delegate ever regresses to a direct Render-AIAdapters
    # call, this writes the capture file and the assertion below fails.
    $fakeRenderer = @(
      'function Render-AIAdapters {'
      '  [CmdletBinding(SupportsShouldProcess)]'
      '  param($ManifestPath, $RegistryPath, $Domain, $TargetRoot, $BackupRoot, $UpdateManifest, $Force)'
      "  Set-Content -LiteralPath '$script:capture' -Value 'direct render invoked' -Encoding utf8"
      '  [pscustomobject]@{ ChangedCount = 0; ErrorCount = 0; Results = @() }'
      '}'
    ) -join "`n"
    [IO.File]::WriteAllText(
      (Join-Path $script:tools 'Render-AIAdapters.ps1'),
      $fakeRenderer,
      [Text.UTF8Encoding]::new($false))

    $fakeLifecycle = @(
      'function Invoke-AIAdapterLifecycle {'
      '  [CmdletBinding(SupportsShouldProcess)]'
      '  param($Boundary, $TargetRoot, $SourceRoot, [switch]$FixtureMode, [switch]$AllowUserGlobalWrite, [switch]$CheckpointConfirmed, $EvidenceRoot)'
      '  [pscustomobject]@{ Boundary = $Boundary; TargetRoot = $TargetRoot; DriftClean = $true; ChangedCount = 0; Results = @() }'
      '}'
    ) -join "`n"
    [IO.File]::WriteAllText(
      (Join-Path $script:tools 'Invoke-AIAdapterLifecycle.ps1'),
      $fakeLifecycle,
      [Text.UTF8Encoding]::new($false))

    # A junction-scoped instruction-map manifest: the retired scope filter used to
    # read this. The delegate must not touch it at all.
    [IO.File]::WriteAllText(
      (Join-Path $script:manifests 'instruction-map.json'),
      '{"records":[{"id":"rec-1","targets":[{"path":"drop-junctioned.md","scope":"inside-junction"}]}]}',
      [Text.UTF8Encoding]::new($false))
  }

  It 'does not throw under Set-StrictMode -Version Latest' {
    {
      Set-StrictMode -Version Latest
      Initialize-SprintAIAdapters `
        -TargetRoot $script:target `
        -SharedVSCodeWorktreePath $script:source `
        -Confirm:$false | Out-Null
    } | Should -Not -Throw
  }

  It 'performs NO direct Render-AIAdapters call and no filtered temp manifest render' {
    Initialize-SprintAIAdapters `
      -TargetRoot $script:target `
      -SharedVSCodeWorktreePath $script:source `
      -Confirm:$false | Out-Null

    Test-Path -LiteralPath $script:capture | Should -BeFalse
    @(Get-ChildItem -LiteralPath $script:manifests -Filter 'instruction-map-filtered-*.json' -File -ErrorAction SilentlyContinue) |
      Should -BeNullOrEmpty
  }

  It 'delegates to Invoke-SprintAIAdapterLifecycle -Boundary Start against the target root' {
    $result = Initialize-SprintAIAdapters `
      -TargetRoot $script:target `
      -SharedVSCodeWorktreePath $script:source `
      -Confirm:$false

    $result.AdapterLifecycle.Boundary | Should -Be 'Start'
    $result.AdapterLifecycle.TargetRoot | Should -Be ([IO.Path]::GetFullPath($script:target))
    $result.SettingsLifecycle | Should -Be $result.AdapterLifecycle
  }

  It 'returns a no-op result when -SkipAIAdapterLifecycle is requested' {
    $result = Initialize-SprintAIAdapters `
      -TargetRoot $script:target `
      -SharedVSCodeWorktreePath $script:source `
      -SkipAIAdapterLifecycle `
      -Confirm:$false

    $result.Skipped | Should -BeTrue
    $result.AdapterLifecycle | Should -BeNullOrEmpty
    Test-Path -LiteralPath $script:capture | Should -BeFalse
  }
}
