BeforeAll {
  $script:manifestPath = Join-Path $PSScriptRoot '..' '..' 'ATAP.Utilities.BuildTooling.PowerShell.psd1'
  Import-Module $script:manifestPath -Force
}

Describe 'Initialize-SprintAIAdapters settings integration' {
  BeforeEach {
    $script:source = Join-Path $TestDrive 'SharedVSCode'
    $script:tools = Join-Path $script:source '.ai/tools'
    $script:manifests = Join-Path $script:source '.ai/manifests'
    $script:target = Join-Path $TestDrive 'target'
    New-Item -ItemType Directory -Path $script:tools, $script:manifests, $script:target -Force | Out-Null
    [IO.File]::WriteAllText(
      (Join-Path $script:manifests 'instruction-map.json'),
      '{"records":[]}',
      [Text.UTF8Encoding]::new($false))
    $fakeRenderer = @(
      'function Render-AIAdapters {'
      '  [CmdletBinding(SupportsShouldProcess)]'
      '  param($ManifestPath, $TargetRoot, $UpdateManifest, $Force)'
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
      '  [pscustomobject]@{ Boundary = $Boundary; TargetRoot = $TargetRoot; DriftClean = $true }'
      '}'
    ) -join "`n"
    [IO.File]::WriteAllText(
      (Join-Path $script:tools 'Invoke-AIAdapterLifecycle.ps1'),
      $fakeLifecycle,
      [Text.UTF8Encoding]::new($false))
  }

  It 'materializes canonical project settings after adapters' {
    $result = Initialize-SprintAIAdapters `
      -TargetRoot $script:target `
      -SharedVSCodeWorktreePath $script:source `
      -Confirm:$false

    $result.AdapterLifecycle.Boundary | Should -Be 'Start'
    $result.AdapterLifecycle.TargetRoot | Should -Be ([IO.Path]::GetFullPath($script:target))
    $result.SettingsLifecycle | Should -Be $result.AdapterLifecycle
  }

  It 'supports a narrowly scoped settings skip' {
    $result = Initialize-SprintAIAdapters `
      -TargetRoot $script:target `
      -SharedVSCodeWorktreePath $script:source `
      -SkipAIAdapterLifecycle `
      -Confirm:$false

    $result.AdapterLifecycle | Should -BeNullOrEmpty
  }
}
