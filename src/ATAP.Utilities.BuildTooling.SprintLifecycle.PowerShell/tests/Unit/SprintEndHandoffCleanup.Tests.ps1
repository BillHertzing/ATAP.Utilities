BeforeAll {
  $moduleRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
  . (Join-Path $moduleRoot 'public/New-SprintEndHandoff.ps1')
  $repoRoot = Split-Path (Split-Path $moduleRoot -Parent) -Parent
  $script:evidenceRoot = Join-Path $repoRoot '_generated/Sprint0015/SprintEnd-ContractCorrections-20261014/handoff'
  New-Item -ItemType Directory -Path $script:evidenceRoot -Force | Out-Null
  function Get-GeneratedHandoffScript {
    param([hashtable]$Extra = @{})
    $parameters = @{
      GitRoot = $script:evidenceRoot
      WorktreePaths = @((Join-Path $script:evidenceRoot 'Ace-wt-45-Sprint-0015-work-items'))
      OutputPath = Join-Path $script:evidenceRoot 'HANDOFF.Sprint0015.md'
      Confirm = $false
    }
    foreach ($key in $Extra.Keys) { $parameters[$key] = $Extra[$key] }
    $result = New-SprintEndHandoff @parameters
    $content = Get-Content -LiteralPath $result.Path -Raw
    $code = [regex]::Match($content, '(?s)```powershell\r?\n(.*?)\r?\n```').Groups[1].Value
    [IO.File]::WriteAllText((Join-Path $script:evidenceRoot 'generated-handoff-script.ps1'), $code)
    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($code, [ref]$tokens, [ref]$parseErrors)
    return @{ Code = $code; Ast = $ast; Errors = @($parseErrors); Path = $result.Path }
  }
  function Invoke-SprintEndInfrastructureCleanup { param($GitRoot, $DeveloperNames, $Apply, $Confirm, $ProfiledRemotingPolicy, $DatabaseCleanupTargets) }
  function Test-SprintEndBoundaryState { param($GitRoot, $TestFreshShell, $ThrowOnFailure) }
}

Describe 'Generated SprintEnd handoff cleanup contract' -Tag 'Unit' {
  BeforeEach {
    Mock Write-PSFMessage {}
  }

  It 'parses default commands and invokes only the typed infrastructure cleanup wrapper' {
    $generated = Get-GeneratedHandoffScript
    $generated.Errors.Count | Should -Be 0
    $commands = @($generated.Ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true) | ForEach-Object { $_.GetCommandName() })
    @($commands | Where-Object { $_ -eq 'Invoke-SprintEndInfrastructureCleanup' }).Count | Should -Be 1
    $commands | Should -Not -Contain 'Remove-SprintDatabases'
    $commands | Should -Not -Contain 'Clear-BuildMasterSprintVariables'
    $generated.Code | Should -Not -Match 'DatabaseCleanupTargets'
    $generated.Code | Should -Match 'Import-Module ATAP.Utilities.BuildTooling.PowerShell -Force\r?\nImport-Module ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell -Force'
  }

  It 'preserves exact target names including quotes as arrays in executable generated syntax' {
    $targets = @(
      @{ InstanceName = 'EXPWHERTZING'; Databases = @("owner's db", 'ATAPUtilities') }
      @{ InstanceName = 'QA'; Databases = @('one') }
    )
    $generated = Get-GeneratedHandoffScript -Extra @{ DatabaseCleanupTargets = $targets }
    $generated.Errors.Count | Should -Be 0
    $parameterCode = [regex]::Match($generated.Code, '(?s)\$cleanupParams = @\{.*?\r?\n\}').Value
    $actual = & ([scriptblock]::Create($parameterCode + [Environment]::NewLine + '$cleanupParams'))
    $actual.DatabaseCleanupTargets.Count | Should -Be 2
    $actual.DatabaseCleanupTargets[0].InstanceName | Should -BeExactly 'EXPWHERTZING'
    $actual.DatabaseCleanupTargets[0].Databases | Should -Be $targets[0].Databases
    $actual.DatabaseCleanupTargets[1].Databases.Count | Should -Be 1
    $actual.Apply | Should -BeTrue
    $actual.Confirm | Should -BeFalse
  }

  It 'rejects explicit empty or invalid targets instead of turning them into defaults' {
    { Get-GeneratedHandoffScript -Extra @{ DatabaseCleanupTargets = @() } } | Should -Throw '*at least one*'
    { Get-GeneratedHandoffScript -Extra @{ DatabaseCleanupTargets = $null } } | Should -Throw '*at least one*'
    { Get-GeneratedHandoffScript -Extra @{ DatabaseCleanupTargets = @(@{ InstanceName = 'QA'; Databases = @('') }) } } | Should -Throw '*nonempty exact*'
  }

  It 'retains the handoff and skips boundary verification when acceptance fails' -ForEach @(
    @{ Cleanup = $null }
    @{ Cleanup = @{ Ok = $false; Applied = $false; Failures = @('database failure') } }
    @{ Cleanup = @{ Ok = $true; Applied = $false; Failures = @() } }
    @{ Cleanup = @{ Ok = $true; Applied = $true; Failures = @('nested failure') } }
  ) {
    $script:cleanupResponse = $Cleanup
    Mock Invoke-SprintEndInfrastructureCleanup { $script:cleanupResponse }
    Mock Test-SprintEndBoundaryState {}
    $generated = Get-GeneratedHandoffScript
    $cleanupCode = $generated.Code.Substring($generated.Code.IndexOf('$cleanupParams ='))
    { & ([scriptblock]::Create($cleanupCode)) } | Should -Throw '*retain this handoff*'
    Test-Path -LiteralPath $generated.Path | Should -BeTrue
    Should -Invoke Test-SprintEndBoundaryState -Times 0 -Exactly
  }

  It 'removes the handoff only after applied cleanup acceptance and boundary verification' {
    Mock Invoke-SprintEndInfrastructureCleanup { @{ Ok = $true; Applied = $true; Failures = @() } }
    Mock Test-SprintEndBoundaryState {}
    $generated = Get-GeneratedHandoffScript
    $cleanupCode = $generated.Code.Substring($generated.Code.IndexOf('$cleanupParams ='))
    & ([scriptblock]::Create($cleanupCode))
    Should -Invoke Test-SprintEndBoundaryState -Times 1 -Exactly
    Test-Path -LiteralPath $generated.Path | Should -BeFalse
  }

  It 'retains the handoff if boundary verification throws after successful cleanup' {
    Mock Invoke-SprintEndInfrastructureCleanup { @{ Ok = $true; Applied = $true; Failures = @() } }
    Mock Test-SprintEndBoundaryState { throw 'boundary verification failed' }
    $generated = Get-GeneratedHandoffScript
    $cleanupCode = $generated.Code.Substring($generated.Code.IndexOf('$cleanupParams ='))
    { & ([scriptblock]::Create($cleanupCode)) } | Should -Throw '*boundary verification failed*'
    Test-Path -LiteralPath $generated.Path | Should -BeTrue
  }
}
