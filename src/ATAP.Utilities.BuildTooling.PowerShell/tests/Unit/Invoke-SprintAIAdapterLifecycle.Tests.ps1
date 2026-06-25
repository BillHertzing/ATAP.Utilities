BeforeAll {
  $script:manifestPath = Join-Path $PSScriptRoot '..' '..' 'ATAP.Utilities.BuildTooling.PowerShell.psd1'
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
      '  param($Boundary, $TargetRoot, $SourceRoot, [switch]$FixtureMode, [switch]$AllowUserGlobalWrite, [switch]$CheckpointConfirmed, $EvidenceRoot)'
      '  [pscustomobject]@{'
      '    Boundary = $Boundary'
      '    TargetRoot = $TargetRoot'
      '    SourceRoot = $SourceRoot'
      '    FixtureMode = [bool]$FixtureMode'
      '    AllowUserGlobalWrite = [bool]$AllowUserGlobalWrite'
      '    CheckpointConfirmed = [bool]$CheckpointConfirmed'
      '    EvidenceRoot = $EvidenceRoot'
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

  It 'forwards live replacement checkpoint confirmation' {
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
