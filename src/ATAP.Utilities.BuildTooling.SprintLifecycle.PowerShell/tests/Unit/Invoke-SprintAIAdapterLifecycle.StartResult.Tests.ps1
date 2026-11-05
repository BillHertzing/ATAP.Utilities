# Source-only under S17-G3-C3-START-RESULT-SOURCE01. Execution requires a
# separate whole-file fixture admission; no module or real renderer is imported.
BeforeAll {
  $script:fixtureRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../_generated/Sprint0017/17.66/G3C3StartResult01/Fixtures'))
  $script:runRoot = Join-Path $script:fixtureRoot ([guid]::NewGuid().ToString('N'))
  if (Test-Path -LiteralPath $script:runRoot) {
    throw 'Fresh owned fixture root required; do not reuse retained artifacts.'
  }
  $script:sourceRoot = Join-Path $script:runRoot 'SyntheticSource'
  $script:targetRoot = Join-Path $script:runRoot 'SyntheticTarget'
  $toolsRoot = Join-Path $script:sourceRoot '.ai/tools'
  [IO.Directory]::CreateDirectory($toolsRoot) | Out-Null

  function Write-PSFMessage {
    param($FunctionName, $ModuleName, $Level, $Message)
  }
  function Get-G3C3StartResultResponse {
    param($Boundary)
    throw 'The focused lifecycle response must be mocked; no real delegate is permitted.'
  }
  $delegateSource = @'
function Invoke-AIAdapterLifecycle {
  [CmdletBinding(SupportsShouldProcess)]
  param($Boundary, $TargetRoot, $SourceRoot, [switch]$FixtureMode,
    [switch]$AllowUserGlobalWrite, [switch]$CheckpointConfirmed, $EvidenceRoot)
  Get-G3C3StartResultResponse -Boundary $Boundary
}
'@
  [IO.File]::WriteAllText(
    (Join-Path $toolsRoot 'Invoke-AIAdapterLifecycle.ps1'),
    $delegateSource,
    [Text.UTF8Encoding]::new($false))
  . (Join-Path $PSScriptRoot '../../public/Invoke-SprintAIAdapterLifecycle.ps1')
}

Describe 'Invoke-SprintAIAdapterLifecycle normal Start result evidence' {
  BeforeEach {
    $script:renderResult = [pscustomobject]@{
      ErrorCount = 0
      ChangedCount = 1
      SecondRunWouldBeClean = $true
      Results = @([pscustomobject]@{ Action = 'written'; Path = 'synthetic.adapter'; Sha256 = 'retained-metadata' })
    }
    $script:response = [pscustomobject]@{
      Boundary = 'Start'
      DriftClean = $true
      ChangedCount = 1
      SkippedUserScopeCount = 0
      Results = $script:renderResult.Results
      RenderResult = $script:renderResult
      DriftResult = $null
      PreservedMarker = 'original-delegate-object'
    }
    Mock Get-G3C3StartResultResponse { $script:response }
  }

  It 'returns the original valid result and preserves its raw renderer evidence after one delegate call' {
    $result = Invoke-SprintAIAdapterLifecycle -Boundary Start -TargetRoot $script:targetRoot -SharedVSCodeWorktreePath $script:sourceRoot -FixtureMode -Confirm:$false

    $result.PreservedMarker | Should -Be 'original-delegate-object'
    $result.DriftClean | Should -BeTrue
    $result.ChangedCount | Should -Be 1
    $result.RenderResult.Results[0].Sha256 | Should -Be 'retained-metadata'
    [object]::ReferenceEquals($result, $script:response) | Should -BeTrue
    Should -Invoke Get-G3C3StartResultResponse -Times 1 -Exactly -ParameterFilter { $Boundary -eq 'Start' }
  }

  It 'accepts explicit zero changes and an explicitly empty result array' {
    $script:renderResult.ChangedCount = 0
    $script:renderResult.Results = @()
    $script:response.ChangedCount = 0
    $script:response.Results = @()

    $result = Invoke-SprintAIAdapterLifecycle -Boundary Start -TargetRoot $script:targetRoot -SharedVSCodeWorktreePath $script:sourceRoot -FixtureMode -Confirm:$false

    $result.ChangedCount | Should -Be 0
    $result.RenderResult.Results | Should -HaveCount 0
    Should -Invoke Get-G3C3StartResultResponse -Times 1 -Exactly
  }

  It 'holds <Case> without discarding raw evidence or invoking the delegate twice' -ForEach @(
    @{ Case = 'reported renderer errors' }
    @{ Case = 'error row despite zero aggregate count' }
    @{ Case = 'missing delegate result' }
    @{ Case = 'multiple delegate results' }
    @{ Case = 'missing render result' }
    @{ Case = 'null render result' }
    @{ Case = 'missing error count' }
    @{ Case = 'string error count' }
    @{ Case = 'negative error count' }
    @{ Case = 'Boolean error count' }
    @{ Case = 'fractional error count' }
    @{ Case = 'missing changed count' }
    @{ Case = 'missing cleanliness' }
    @{ Case = 'false cleanliness' }
    @{ Case = 'string cleanliness' }
    @{ Case = 'missing result rows' }
    @{ Case = 'null result rows' }
    @{ Case = 'malformed result row' }
    @{ Case = 'missing delegate cleanliness' }
    @{ Case = 'false delegate cleanliness' }
  ) {
    param($Case)
    switch ($Case) {
      'reported renderer errors' { $script:renderResult.ErrorCount = 2 }
      'error row despite zero aggregate count' { $script:renderResult.Results[0].Action = 'error' }
      'missing delegate result' { $script:response = $null }
      'multiple delegate results' { $script:response = @($script:response, $script:response) }
      'missing render result' { $script:response.PSObject.Properties.Remove('RenderResult') }
      'null render result' { $script:response.RenderResult = $null }
      'missing error count' { $script:renderResult.PSObject.Properties.Remove('ErrorCount') }
      'string error count' { $script:renderResult.ErrorCount = '0' }
      'negative error count' { $script:renderResult.ErrorCount = -1 }
      'Boolean error count' { $script:renderResult.ErrorCount = $false }
      'fractional error count' { $script:renderResult.ErrorCount = 0.5 }
      'missing changed count' { $script:renderResult.PSObject.Properties.Remove('ChangedCount') }
      'missing cleanliness' { $script:renderResult.PSObject.Properties.Remove('SecondRunWouldBeClean') }
      'false cleanliness' { $script:renderResult.SecondRunWouldBeClean = $false }
      'string cleanliness' { $script:renderResult.SecondRunWouldBeClean = 'true' }
      'missing result rows' { $script:renderResult.PSObject.Properties.Remove('Results') }
      'null result rows' { $script:renderResult.Results = $null }
      'malformed result row' { $script:renderResult.Results = @([pscustomobject]@{ Path = 'attempted.adapter' }) }
      'missing delegate cleanliness' { $script:response.PSObject.Properties.Remove('DriftClean') }
      'false delegate cleanliness' { $script:response.DriftClean = $false }
      default { throw "Unbound test case: $Case" }
    }
    $caught = $null

    try {
      $null = Invoke-SprintAIAdapterLifecycle -Boundary Start -TargetRoot $script:targetRoot -SharedVSCodeWorktreePath $script:sourceRoot -FixtureMode -Confirm:$false
    } catch { $caught = $_ }

    $caught | Should -Not -BeNullOrEmpty
    $caught.FullyQualifiedErrorId | Should -Match '^SprintAIAdapterStartResultUnverified'
    $caught.TargetObject.Status | Should -Be 'HELD_RECOVERY'
    $caught.TargetObject.PSObject.Properties.Name | Should -Contain 'RawLifecycleResult'
    $caught.TargetObject.PSObject.Properties.Name | Should -Contain 'RawRenderResult'
    $caught.TargetObject.RollbackAttempted | Should -BeFalse
    $caught.TargetObject.Reasons.Count | Should -BeGreaterThan 0
    if ($Case -notin @('missing delegate result', 'multiple delegate results')) {
      $caught.TargetObject.RawLifecycleResult.PreservedMarker | Should -Be 'original-delegate-object'
    }
    if ($Case -eq 'reported renderer errors') {
      $caught.TargetObject.RawRenderResult.ErrorCount | Should -Be 2
      $caught.TargetObject.RawRenderResult.ChangedCount | Should -Be 1
      $caught.TargetObject.RawRenderResult.Results[0].Action | Should -Be 'written'
    }
    Should -Invoke Get-G3C3StartResultResponse -Times 1 -Exactly
  }

  It 'preserves normal End result behavior without requiring Start render evidence' {
    $script:response = [pscustomobject]@{ Boundary = 'End'; DriftClean = $false; PreservedMarker = 'end-audit' }

    $result = Invoke-SprintAIAdapterLifecycle -Boundary End -TargetRoot $script:targetRoot -SharedVSCodeWorktreePath $script:sourceRoot -FixtureMode -Confirm:$false

    $result.PreservedMarker | Should -Be 'end-audit'
    $result.DriftClean | Should -BeFalse
    Should -Invoke Get-G3C3StartResultResponse -Times 1 -Exactly -ParameterFilter { $Boundary -eq 'End' }
  }
}

# Intentionally retain the exact generated fixture subtree after any future run;
# no recursive cleanup, live settings, module import or real renderer fallback.
