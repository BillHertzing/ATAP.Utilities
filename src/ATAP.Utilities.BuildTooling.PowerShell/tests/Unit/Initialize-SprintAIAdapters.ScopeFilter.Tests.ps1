BeforeAll {
  $script:manifestPath = Join-Path $PSScriptRoot '..' '..' 'ATAP.Utilities.BuildTooling.PowerShell.psd1'
  Import-Module $script:manifestPath -Force
}

Describe 'Initialize-SprintAIAdapters manifest scope filter (Task 10.3.f)' {
  BeforeEach {
    $script:source = Join-Path $TestDrive 'SharedVSCode'
    $script:tools = Join-Path $script:source '.ai/tools'
    $script:manifests = Join-Path $script:source '.ai/manifests'
    $script:target = Join-Path $TestDrive 'target'
    $script:capture = Join-Path $TestDrive 'captured-filtered-manifest.json'
    New-Item -ItemType Directory -Path $script:tools, $script:manifests, $script:target -Force | Out-Null

    # Fake renderer that captures the filtered manifest it is handed, so the test can
    # assert which targets survived the scope filter.
    $fakeRenderer = @(
      'function Render-AIAdapters {'
      '  [CmdletBinding(SupportsShouldProcess)]'
      '  param($ManifestPath, $TargetRoot, $UpdateManifest, $Force)'
      "  Copy-Item -LiteralPath `$ManifestPath -Destination '$script:capture' -Force"
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

    # Manifest mixing all three cases: outside-junction (keep), unscoped/no 'scope'
    # property (keep, backwards compat), and a junctioned scope (filter out).
    $mixedManifest = [ordered]@{
      records = @(
        [ordered]@{
          id      = 'rec-1'
          targets = @(
            [ordered]@{ path = 'keep-outside.md'; scope = 'outside-junction' }
            [ordered]@{ path = 'keep-unscoped.md' }
            [ordered]@{ path = 'drop-junctioned.md'; scope = 'inside-junction' }
          )
        }
      )
    } | ConvertTo-Json -Depth 8
    [IO.File]::WriteAllText(
      (Join-Path $script:manifests 'instruction-map.json'),
      $mixedManifest,
      [Text.UTF8Encoding]::new($false))
  }

  It 'does not throw on unscoped targets under Set-StrictMode -Version Latest' {
    {
      Set-StrictMode -Version Latest
      Initialize-SprintAIAdapters `
        -TargetRoot $script:target `
        -SharedVSCodeWorktreePath $script:source `
        -SkipAIAdapterLifecycle `
        -Confirm:$false | Out-Null
    } | Should -Not -Throw
  }

  It 'keeps outside-junction and unscoped targets and filters junctioned targets' {
    Set-StrictMode -Version Latest
    Initialize-SprintAIAdapters `
      -TargetRoot $script:target `
      -SharedVSCodeWorktreePath $script:source `
      -SkipAIAdapterLifecycle `
      -Confirm:$false | Out-Null

    Test-Path -LiteralPath $script:capture | Should -BeTrue
    $filtered = Get-Content -LiteralPath $script:capture -Raw | ConvertFrom-Json
    $keptPaths = @(
      $filtered.records |
        ForEach-Object { $_.targets } |
        Where-Object { $_ } |
        ForEach-Object { $_.path }
    )

    $keptPaths | Should -Contain 'keep-outside.md'
    $keptPaths | Should -Contain 'keep-unscoped.md'
    $keptPaths | Should -Not -Contain 'drop-junctioned.md'
  }
}
