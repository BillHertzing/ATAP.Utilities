BeforeAll {
  $script:manifestPath = Join-Path $PSScriptRoot '..' '..' 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell.psd1'
  Import-Module $script:manifestPath -Force
}

Describe 'Invoke-SprintAIAdapterLifecycle [public]' {
  BeforeEach {
    $script:root = Join-Path $TestDrive 'SharedVSCode'
    $script:tools = Join-Path $script:root '.ai/tools'
    New-Item -ItemType Directory -Path $script:tools -Force | Out-Null
    $fakeLifecycle = @(
      'function Invoke-AIAdapterLifecycle {'
      '  [CmdletBinding(SupportsShouldProcess)]'
      '  param($Boundary, $TargetRoot, $SourceRoot, [switch]$FixtureMode, [switch]$AllowUserGlobalWrite, [switch]$CheckpointConfirmed, $EvidenceRoot, [switch]$OmitSprintWorktrees)'
      '  [pscustomobject]@{'
      '    Boundary = $Boundary'
      '    TargetRoot = $TargetRoot'
      '    SourceRoot = $SourceRoot'
      '    FixtureMode = [bool]$FixtureMode'
      '    AllowUserGlobalWrite = [bool]$AllowUserGlobalWrite'
      '    CheckpointConfirmed = [bool]$CheckpointConfirmed'
      '    EvidenceRoot = $EvidenceRoot'
      '    OmitSprintWorktrees = [bool]$OmitSprintWorktrees'
      '    DriftClean = $true'
      '  }'
      '}'
    ) -join "`n"
    [IO.File]::WriteAllText(
      (Join-Path $script:tools 'Invoke-AIAdapterLifecycle.ps1'),
      $fakeLifecycle,
      [Text.UTF8Encoding]::new($false))
  }

  It 'loads the canonical adapter lifecycle from the selected SharedVSCode worktree' {
    $target = Join-Path $TestDrive 'target'
    $result = Invoke-SprintAIAdapterLifecycle `
      -Boundary Start `
      -TargetRoot $target `
      -SharedVSCodeWorktreePath $script:root `
      -FixtureMode `
      -Confirm:$false

    $result.Boundary | Should -Be 'Start'
    $result.TargetRoot | Should -Be ([IO.Path]::GetFullPath($target))
    $result.SourceRoot | Should -Be ([IO.Path]::GetFullPath($script:root))
    $result.FixtureMode | Should -BeTrue
    $result.AllowUserGlobalWrite | Should -BeFalse
  }

  It 'forwards both gates to the canonical Start registration lifecycle' {
    $result = Invoke-SprintAIAdapterLifecycle `
      -Boundary Start `
      -TargetRoot (Join-Path $TestDrive 'live-target') `
      -SharedVSCodeWorktreePath $script:root `
      -AllowUserGlobalWrite `
      -CheckpointConfirmed `
      -Confirm:$false

    $result.AllowUserGlobalWrite | Should -BeTrue
    $result.CheckpointConfirmed | Should -BeTrue
  }

  It 'renders to convergence, hash-ledgers user-global intent, and records the clean final pass' {
    $fakeLifecycleWithoutSwitch = @(
      'function Invoke-AIAdapterLifecycle {'
      '  [CmdletBinding(SupportsShouldProcess)]'
      '  param($Boundary, $TargetRoot, $SourceRoot, [switch]$FixtureMode, [switch]$AllowUserGlobalWrite, [switch]$CheckpointConfirmed, $EvidenceRoot)'
      '  [pscustomobject]@{ Boundary = $Boundary; DriftClean = $true }'
      '}'
    ) -join "`n"
    [IO.File]::WriteAllText(
      (Join-Path $script:tools 'Invoke-AIAdapterLifecycle.ps1'),
      $fakeLifecycleWithoutSwitch,
      [Text.UTF8Encoding]::new($false))

    $fakeRenderer = @(
      'function Render-AIAdapters {'
      '  [CmdletBinding(SupportsShouldProcess)]'
      '  param($RegistryPath, [string[]]$Domain, $TargetRoot, $BackupRoot, [switch]$FixtureMode, [switch]$AllowUserGlobalWrite, [switch]$OmitSprintWorktrees, [switch]$Force)'
      '  $script:renderCallCount++'
      "  `$changed = `$script:renderCallCount -eq 1"
      "  [pscustomobject]@{ Results = @([pscustomobject]@{ Tool = 'Codex'; Path = '~/.codex/AGENTS.md'; Scope = 'user'; Action = (`$changed ? 'written' : 'unchanged'); Changed = `$changed; Sha256 = 'abc123'; OmitSprintWorktrees = [bool]`$OmitSprintWorktrees }); ChangedCount = (`$changed ? 1 : 0); SkippedUserScopeCount = 0; ErrorCount = 0; SecondRunWouldBeClean = `$true }"
      '}'
    ) -join "`n"
    [IO.File]::WriteAllText(
      (Join-Path $script:tools 'Render-AIAdapters.ps1'),
      $fakeRenderer,
      [Text.UTF8Encoding]::new($false))

    $manifestRoot = Join-Path $script:root '.ai/manifests'
    New-Item -ItemType Directory -Path $manifestRoot -Force | Out-Null
    '{}' | Set-Content -Path (Join-Path $manifestRoot 'adapter-registry.json') -Encoding UTF8
    $script:renderCallCount = 0

    $evidenceRoot = Join-Path $TestDrive 'evidence'
    $result = Invoke-SprintAIAdapterLifecycle `
      -Boundary Start `
      -TargetRoot (Join-Path $TestDrive 'stable-target-fallback') `
      -SharedVSCodeWorktreePath $script:root `
      -EvidenceRoot $evidenceRoot `
      -OmitSprintWorktrees `
      -Confirm:$false

    $result.OmitSprintWorktrees | Should -BeTrue
    $result.RenderResult.Results[0].OmitSprintWorktrees | Should -BeTrue
    $result.SecondPassChangedCount | Should -Be 0
    $result.RenderPassCount | Should -Be 2
    $result.FinalPassChangedCount | Should -Be 0
    $result.Idempotent | Should -BeTrue
    $result.UserGlobalIntent | Should -HaveCount 1
    $result.UserGlobalIntent[0].FirstSha256 | Should -Be 'abc123'
    $result.UserGlobalIntent[0].SecondSha256 | Should -Be 'abc123'
    $result.UserGlobalIntentLedgerPath | Should -Exist
    $ledger = Get-Content -LiteralPath $result.UserGlobalIntentLedgerPath -Raw | ConvertFrom-Json
    $ledger.RenderPassCount | Should -Be 2
    $ledger.SecondPassChangedCount | Should -Be 0
    $ledger.FinalPassChangedCount | Should -Be 0
    $ledger.UserGlobalIntent[0].Path | Should -Be '~/.codex/AGENTS.md'
  }

  It 'allows a third pass when the second render still changes a target' {
    $fakeRenderer = @(
      'function Render-AIAdapters {'
      '  [CmdletBinding(SupportsShouldProcess)]'
      '  param($RegistryPath, [string[]]$Domain, $TargetRoot, $BackupRoot, [switch]$FixtureMode, [switch]$AllowUserGlobalWrite, [switch]$OmitSprintWorktrees, [switch]$Force)'
      '  $global:threePassRenderCallCount++'
      '  $changed = $global:threePassRenderCallCount -lt 3'
      '  [pscustomobject]@{ Results = @(); ChangedCount = ($changed ? 1 : 0); SkippedUserScopeCount = 0; ErrorCount = 0; SecondRunWouldBeClean = $true }'
      '}'
    ) -join "`n"
    [IO.File]::WriteAllText(
      (Join-Path $script:tools 'Render-AIAdapters.ps1'),
      $fakeRenderer,
      [Text.UTF8Encoding]::new($false))
    $manifestRoot = Join-Path $script:root '.ai/manifests'
    New-Item -ItemType Directory -Path $manifestRoot -Force | Out-Null
    '{}' | Set-Content -Path (Join-Path $manifestRoot 'adapter-registry.json') -Encoding UTF8
    $global:threePassRenderCallCount = 0

    $result = Invoke-SprintAIAdapterLifecycle `
      -Boundary Start `
      -TargetRoot (Join-Path $TestDrive 'three-pass-target') `
      -SharedVSCodeWorktreePath $script:root `
      -OmitSprintWorktrees `
      -Confirm:$false

    $result.Idempotent | Should -BeTrue
    $result.RenderPassCount | Should -Be 3
    $result.SecondPassChangedCount | Should -Be 1
    $result.FinalPassChangedCount | Should -Be 0
    Remove-Variable -Name threePassRenderCallCount -Scope Global -ErrorAction SilentlyContinue
  }

  It 'fails closed when the stable-only render does not converge within five passes' {
    $fakeRenderer = @(
      'function Render-AIAdapters {'
      '  [CmdletBinding(SupportsShouldProcess)]'
      '  param($RegistryPath, [string[]]$Domain, $TargetRoot, $BackupRoot, [switch]$FixtureMode, [switch]$AllowUserGlobalWrite, [switch]$OmitSprintWorktrees, [switch]$Force)'
      '  [pscustomobject]@{ Results = @(); ChangedCount = 1; SkippedUserScopeCount = 0; ErrorCount = 0; SecondRunWouldBeClean = $true }'
      '}'
    ) -join "`n"
    [IO.File]::WriteAllText(
      (Join-Path $script:tools 'Render-AIAdapters.ps1'),
      $fakeRenderer,
      [Text.UTF8Encoding]::new($false))
    $manifestRoot = Join-Path $script:root '.ai/manifests'
    New-Item -ItemType Directory -Path $manifestRoot -Force | Out-Null
    '{}' | Set-Content -Path (Join-Path $manifestRoot 'adapter-registry.json') -Encoding UTF8

    {
      Invoke-SprintAIAdapterLifecycle `
        -Boundary Start `
        -TargetRoot (Join-Path $TestDrive 'unstable-target') `
        -SharedVSCodeWorktreePath $script:root `
        -OmitSprintWorktrees `
        -Confirm:$false
    } | Should -Throw '*did not converge within 5 passes*final pass changed 1*'
  }

  It 'requires a confirmed checkpoint before a live stable-only user-global render' {
    {
      Invoke-SprintAIAdapterLifecycle `
        -Boundary Start `
        -TargetRoot (Join-Path $TestDrive 'live-stable-target') `
        -SharedVSCodeWorktreePath $script:root `
        -AllowUserGlobalWrite `
        -OmitSprintWorktrees `
        -Confirm:$false
    } | Should -Throw '*requires -CheckpointConfirmed*'
  }

  It 'fails clearly when the canonical adapter lifecycle tool is absent' {
    Remove-Item -LiteralPath (Join-Path $script:tools 'Invoke-AIAdapterLifecycle.ps1') -Force

    {
      Invoke-SprintAIAdapterLifecycle `
        -Boundary End `
        -TargetRoot (Join-Path $TestDrive 'target') `
        -SharedVSCodeWorktreePath $script:root `
        -Confirm:$false
    } | Should -Throw '*Invoke-AIAdapterLifecycle.ps1 not found*'
  }

  It 'performs no lifecycle call under WhatIf' {
    $result = Invoke-SprintAIAdapterLifecycle `
      -Boundary Start `
      -TargetRoot (Join-Path $TestDrive 'whatif-target') `
      -SharedVSCodeWorktreePath $script:root `
      -WhatIf

    $result | Should -BeNullOrEmpty
  }
}
