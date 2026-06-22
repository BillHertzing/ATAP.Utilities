#Requires -Version 7.0
# Pester 5+ tests for Start-BuildMasterModulePipelineBatch.
# The reused single-module entry points (Get-BuildContext,
# Start-BuildMasterPackagePipeline, Resolve-BuildMasterPackageProjectPath) are
# stubbed and mocked so no real BuildMaster, git, or nbgv contact occurs. The
# ceiling helpers (Test-PromotionWithinCeiling, Get-TierOrder) are the real
# implementations.

BeforeAll {
  $publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'

  . (Join-Path $publicDir 'Get-TierOrder.ps1')
  . (Join-Path $publicDir 'Test-PromotionWithinCeiling.ps1')
  . (Join-Path $publicDir 'Start-BuildMasterModulePipelineBatch.ps1')

  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
  }

  # Stubs so Pester can mock named commands with parameter filters.
  function Resolve-BuildMasterPackageProjectPath {
    param([string]$ModuleName, [string]$ProjectPath)
  }
  function Get-BuildContext {
    [CmdletBinding()]
    param([string]$Application, [string]$ProjectPath, [string]$Branch, [string]$Stage)
  }
  function Start-BuildMasterPackagePipeline {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
      [string]$Application,
      [string]$PipelineName,
      [string]$ModuleName,
      [string]$ProjectPath,
      [string]$ResolvedPackageVersion,
      [string]$Tier,
      [string]$Branch,
      [hashtable]$Variables,
      [string]$BuildMasterBaseUrl,
      [string]$BuildMasterAdminApiKeySecretName
    )
  }
}

Describe 'Start-BuildMasterModulePipelineBatch' -Tag 'Unit', 'PromotedModuleHostSensitive' {
  BeforeEach {
    Mock Write-PSFMessage { }
    Mock Write-Host { }

    # Per-module immutable version + version.json ceiling.
    $script:contexts = @{
      'ModuleAlpha' = @{ Version = '0.1.0-Alpha005'; Ceiling = 'Development' }
      'ModuleBeta'  = @{ Version = '0.2.0-Beta003'; Ceiling = 'Integration' }
      'ModuleGamma' = @{ Version = '0.3.0-QA002'; Ceiling = 'QA' }
    }
    $script:pipelineCalls = [System.Collections.Generic.List[object]]::new()
    $script:failingModule = $null

    Mock Resolve-BuildMasterPackageProjectPath {
      return ('C:/fake/src/{0}' -f $ModuleName)
    }

    Mock Get-BuildContext {
      $moduleLeaf = Split-Path -Leaf $ProjectPath
      $ctx = $script:contexts[$moduleLeaf]
      if ($null -eq $ctx) { throw "No fixture context for '$moduleLeaf'." }
      [PSCustomObject]@{
        Application            = $Application
        ProjectPath            = $ProjectPath
        Branch                 = $Branch
        CeilingTier            = $ctx.Ceiling
        CurrentTier            = 'Experimental'
        ResolvedPackageVersion = $ctx.Version
      }
    }

    Mock Start-BuildMasterPackagePipeline {
      $script:pipelineCalls.Add([PSCustomObject]@{
          Module  = $ModuleName
          Ceiling = $Variables['$CeilingTier']
          Version = $ResolvedPackageVersion
          Tier    = $Tier
          Branch  = $Branch
        })
      $succeeded = -not ($script:failingModule -and $ModuleName -eq $script:failingModule)
      [PSCustomObject]@{
        OperationName          = 'Start-BuildMasterPackagePipeline'
        Succeeded              = $succeeded
        Application            = $Application
        PipelineName           = $PipelineName
        ReleaseNumber          = ('{0}.{1}' -f $ResolvedPackageVersion, $ModuleName)
        ReleaseName            = ('{0} {1}' -f $ModuleName, $ResolvedPackageVersion)
        ModuleName             = $ModuleName
        ResolvedPackageVersion = $ResolvedPackageVersion
        ReleaseResult          = [PSCustomObject]@{ Succeeded = $succeeded; ReleaseId = ('R-{0}' -f $ModuleName) }
        BuildResult            = [PSCustomObject]@{ Succeeded = $succeeded; BuildId = ('B-{0}' -f $ModuleName); BuildNumber = '23' }
        DeploymentResult       = [PSCustomObject]@{ Succeeded = $succeeded; DeploymentId = ('D-{0}' -f $ModuleName) }
        ResponseSummary        = if ($succeeded) { 'queued and deployment started' } else { 'pipeline reported failure' }
      }
    }
  }

  It 'Drives a mixed-ceiling array so each module stops at its own version.json ceiling' {
    $result = Start-BuildMasterModulePipelineBatch `
      -ModuleName 'ModuleAlpha', 'ModuleBeta' `
      -ApplicationByModule @{ 'ModuleAlpha' = 'ATAP.Utilities-PowerShell'; 'ModuleBeta' = 'ATAP.Utilities-PowerShell' } `
      -Branch '115-Sprint-0010-work-items'

    $result.Succeeded | Should -BeTrue
    $result.Results.Count | Should -Be 2

    $alpha = $result.Results | Where-Object { $_.Module -eq 'ModuleAlpha' }
    $beta = $result.Results | Where-Object { $_.Module -eq 'ModuleBeta' }
    $alpha.Ceiling | Should -Be 'Development'
    $alpha.TerminalTier | Should -Be 'Development'
    $beta.Ceiling | Should -Be 'Integration'
    $beta.TerminalTier | Should -Be 'Integration'

    # The ceiling is passed to BuildMaster as a build variable, not decided locally.
    ($script:pipelineCalls | Where-Object { $_.Module -eq 'ModuleAlpha' }).Ceiling | Should -Be 'Development'
    ($script:pipelineCalls | Where-Object { $_.Module -eq 'ModuleBeta' }).Ceiling | Should -Be 'Integration'
    $script:pipelineCalls | ForEach-Object { $_.Tier | Should -Be 'Experimental' }
  }

  It 'Processes modules in deterministic caller order' {
    Start-BuildMasterModulePipelineBatch `
      -ModuleName 'ModuleGamma', 'ModuleAlpha', 'ModuleBeta' `
      -ApplicationByModule @{ 'ModuleGamma' = 'App'; 'ModuleAlpha' = 'App'; 'ModuleBeta' = 'App' } `
      -Branch 'main' | Out-Null

    $script:pipelineCalls.Count | Should -Be 3
    $script:pipelineCalls[0].Module | Should -Be 'ModuleGamma'
    $script:pipelineCalls[1].Module | Should -Be 'ModuleAlpha'
    $script:pipelineCalls[2].Module | Should -Be 'ModuleBeta'
  }

  It 'Normalizes duplicate module names while preserving first-seen order' {
    $result = Start-BuildMasterModulePipelineBatch `
      -ModuleName 'ModuleAlpha', 'ModuleBeta', 'modulealpha' `
      -ApplicationByModule @{ 'ModuleAlpha' = 'App'; 'ModuleBeta' = 'App' } `
      -Branch 'main'

    $result.RequestedModuleCount | Should -Be 2
    $result.DuplicatesRemoved | Should -Be 1
    $script:pipelineCalls.Count | Should -Be 2
    $script:pipelineCalls[0].Module | Should -Be 'ModuleAlpha'
    $script:pipelineCalls[1].Module | Should -Be 'ModuleBeta'
  }

  It 'Preflights every module before any BuildMaster mutation and fails fast on a missing application mapping' {
    { Start-BuildMasterModulePipelineBatch `
        -ModuleName 'ModuleAlpha', 'ModuleBeta' `
        -ApplicationByModule @{ 'ModuleAlpha' = 'App' } `
        -Branch 'main' } | Should -Throw

    Should -Invoke Start-BuildMasterPackagePipeline -Times 0 -Exactly -Scope It
  }

  It 'Fails fast before mutation when a module project/version.json cannot be resolved' {
    Mock Resolve-BuildMasterPackageProjectPath {
      if ($ModuleName -eq 'ModuleBeta') {
        throw "Could not resolve a project folder with project-adjacent version.json for module 'ModuleBeta'."
      }
      return ('C:/fake/src/{0}' -f $ModuleName)
    }

    { Start-BuildMasterModulePipelineBatch `
        -ModuleName 'ModuleAlpha', 'ModuleBeta' `
        -ApplicationByModule @{ 'ModuleAlpha' = 'App'; 'ModuleBeta' = 'App' } `
        -Branch 'main' } | Should -Throw

    Should -Invoke Start-BuildMasterPackagePipeline -Times 0 -Exactly -Scope It
  }

  It 'Invokes the single-module pipeline exactly once per unique module' {
    Start-BuildMasterModulePipelineBatch `
      -ModuleName 'ModuleAlpha', 'ModuleBeta', 'ModuleGamma' `
      -ApplicationByModule @{ 'ModuleAlpha' = 'App'; 'ModuleBeta' = 'App'; 'ModuleGamma' = 'App' } `
      -Branch 'main' | Out-Null

    Should -Invoke Start-BuildMasterPackagePipeline -Times 3 -Exactly -Scope It
    Should -Invoke Start-BuildMasterPackagePipeline -Times 1 -Exactly -Scope It -ParameterFilter { $ModuleName -eq 'ModuleAlpha' }
    Should -Invoke Start-BuildMasterPackagePipeline -Times 1 -Exactly -Scope It -ParameterFilter { $ModuleName -eq 'ModuleBeta' }
  }

  It 'Stops after the first pipeline failure when failing fast' {
    $script:failingModule = 'ModuleBeta'

    $result = Start-BuildMasterModulePipelineBatch `
      -ModuleName 'ModuleAlpha', 'ModuleBeta', 'ModuleGamma' `
      -ApplicationByModule @{ 'ModuleAlpha' = 'App'; 'ModuleBeta' = 'App'; 'ModuleGamma' = 'App' } `
      -Branch 'main'

    $result.Succeeded | Should -BeFalse
    $result.FailFastTriggered | Should -BeTrue
    $script:pipelineCalls.Count | Should -Be 2
    ($script:pipelineCalls | Where-Object { $_.Module -eq 'ModuleGamma' }) | Should -BeNullOrEmpty
  }

  It 'Continues through remaining modules when -ContinueOnError is supplied' {
    $script:failingModule = 'ModuleBeta'

    $result = Start-BuildMasterModulePipelineBatch `
      -ModuleName 'ModuleAlpha', 'ModuleBeta', 'ModuleGamma' `
      -ApplicationByModule @{ 'ModuleAlpha' = 'App'; 'ModuleBeta' = 'App'; 'ModuleGamma' = 'App' } `
      -Branch 'main' `
      -ContinueOnError

    $result.Succeeded | Should -BeFalse
    $result.SucceededCount | Should -Be 2
    $result.FailedCount | Should -Be 1
    $script:pipelineCalls.Count | Should -Be 3

    $betaRecord = $result.Results | Where-Object { $_.Module -eq 'ModuleBeta' }
    $betaRecord.Success | Should -BeFalse
    $betaRecord.FailureDetail | Should -Not -BeNullOrEmpty
  }

  It 'Continues past a preflight failure under -ContinueOnError and still starts the resolvable modules' {
    $result = Start-BuildMasterModulePipelineBatch `
      -ModuleName 'ModuleAlpha', 'ModuleBeta' `
      -ApplicationByModule @{ 'ModuleAlpha' = 'App' } `
      -Branch 'main' `
      -ContinueOnError

    $result.Succeeded | Should -BeFalse
    Should -Invoke Start-BuildMasterPackagePipeline -Times 1 -Exactly -Scope It -ParameterFilter { $ModuleName -eq 'ModuleAlpha' }
    $betaRecord = $result.Results | Where-Object { $_.Module -eq 'ModuleBeta' }
    $betaRecord.Success | Should -BeFalse
    $betaRecord.FailureDetail | Should -Match 'application'
  }

  It 'Performs no BuildMaster mutation under -WhatIf' {
    $result = Start-BuildMasterModulePipelineBatch `
      -ModuleName 'ModuleAlpha', 'ModuleBeta' `
      -ApplicationByModule @{ 'ModuleAlpha' = 'App'; 'ModuleBeta' = 'App' } `
      -Branch 'main' `
      -WhatIf

    Should -Invoke Start-BuildMasterPackagePipeline -Times 0 -Exactly -Scope It
    $result.Results.Count | Should -Be 2
    $result.Results | ForEach-Object { $_.ResponseSummary | Should -Match 'WhatIf' }
    $result.ResponseSummary | Should -Match 'WhatIf'
  }

  It 'Returns a structured aggregate with ordered per-module records carrying all required fields' {
    $result = Start-BuildMasterModulePipelineBatch `
      -ModuleName 'ModuleAlpha', 'ModuleBeta' `
      -ApplicationByModule @{ 'ModuleAlpha' = 'ATAP.Utilities-PowerShell'; 'ModuleBeta' = 'ATAP.Utilities-PowerShell' } `
      -Branch 'main' `
      -BuildMasterAdminApiKeySecretName 'BuildMaster.Admin.API.Key'

    $result.OperationName | Should -Be 'Start-BuildMasterModulePipelineBatch'
    $result.PipelineName | Should -Be 'global::PowerShellModule-5Stage'

    $record = $result.Results[0]
    foreach ($field in 'Module', 'Application', 'ProjectPath', 'PackageVersion', 'Ceiling', 'TerminalTier', 'ReleaseNumber', 'BuildNumber', 'ExecutionId', 'Success', 'FailureDetail', 'ResponseSummary') {
      $record.PSObject.Properties.Name | Should -Contain $field
    }
    $record.Module | Should -Be 'ModuleAlpha'
    $record.Application | Should -Be 'ATAP.Utilities-PowerShell'
    $record.PackageVersion | Should -Be '0.1.0-Alpha005'
    $record.ReleaseNumber | Should -Be '0.1.0-Alpha005.ModuleAlpha'
    $record.BuildNumber | Should -Be '23'
    $record.ExecutionId | Should -Be 'D-ModuleAlpha'
    $record.Success | Should -BeTrue
  }

  It 'Never reports a terminal tier above the resolved ceiling' {
    $result = Start-BuildMasterModulePipelineBatch `
      -ModuleName 'ModuleAlpha', 'ModuleBeta', 'ModuleGamma' `
      -ApplicationByModule @{ 'ModuleAlpha' = 'App'; 'ModuleBeta' = 'App'; 'ModuleGamma' = 'App' } `
      -Branch 'main'

    foreach ($record in $result.Results) {
      Test-PromotionWithinCeiling -CurrentTier $record.TerminalTier -CeilingTier $record.Ceiling -AsBoolean | Should -BeTrue
      Test-PromotionWithinCeiling -CurrentTier $record.RequestedTerminalTier -CeilingTier $record.Ceiling -AsBoolean | Should -BeTrue
    }
  }
}
