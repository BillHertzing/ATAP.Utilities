BeforeAll {
  $script:manifestPath = Join-Path $PSScriptRoot '..' '..' 'ATAP.Utilities.BuildTooling.PowerShell.psd1'
  Import-Module $script:manifestPath -Force
}

Describe 'Invoke-SprintAISettingsLifecycle [public]' {
  BeforeEach {
    $script:root = Join-Path $TestDrive 'SharedVSCode'
    $script:tools = Join-Path $script:root '.ai/tools'
    New-Item -ItemType Directory -Path $script:tools -Force | Out-Null
    $fakeLifecycle = @(
      'function Invoke-AISettingsLifecycle {'
      '  [CmdletBinding(SupportsShouldProcess)]'
      '  param($Boundary, $TargetRoot, $SourceRoot, [switch]$FixtureMode, [switch]$AllowUserGlobalWrite, $EvidenceRoot)'
      '  [pscustomobject]@{'
      '    Boundary = $Boundary'
      '    TargetRoot = $TargetRoot'
      '    SourceRoot = $SourceRoot'
      '    FixtureMode = [bool]$FixtureMode'
      '    AllowUserGlobalWrite = [bool]$AllowUserGlobalWrite'
      '    EvidenceRoot = $EvidenceRoot'
      '    DriftClean = $true'
      '  }'
      '}'
    ) -join "`n"
    [IO.File]::WriteAllText(
      (Join-Path $script:tools 'Invoke-AISettingsLifecycle.ps1'),
      $fakeLifecycle,
      [Text.UTF8Encoding]::new($false))
  }

  It 'loads the canonical lifecycle from the selected SharedVSCode worktree' {
    $target = Join-Path $TestDrive 'target'
    $result = Invoke-SprintAISettingsLifecycle `
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

  It 'fails clearly when the canonical lifecycle tool is absent' {
    Remove-Item -LiteralPath (Join-Path $script:tools 'Invoke-AISettingsLifecycle.ps1') -Force

    { Invoke-SprintAISettingsLifecycle `
        -Boundary End `
        -TargetRoot (Join-Path $TestDrive 'target') `
        -SharedVSCodeWorktreePath $script:root `
        -Confirm:$false } | Should -Throw '*Invoke-AISettingsLifecycle.ps1 not found*'
  }

  It 'performs no lifecycle call under WhatIf' {
    $target = Join-Path $TestDrive 'whatif-target'
    $result = Invoke-SprintAISettingsLifecycle `
      -Boundary Start `
      -TargetRoot $target `
      -SharedVSCodeWorktreePath $script:root `
      -WhatIf

    $result | Should -BeNullOrEmpty
  }
}