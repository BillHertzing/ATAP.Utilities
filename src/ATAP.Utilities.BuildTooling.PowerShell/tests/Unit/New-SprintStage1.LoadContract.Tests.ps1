#Requires -Version 7.0
# K03 — Verifies that dot-sourcing New-SprintStage1.ps1 defines the function
# command without executing any side-effecting code at the file level.
# Each test in this file is a sentinel: if top-level execution is reintroduced
# into New-SprintStage1.ps1, these tests will begin to fail.
# AI assisted using Powershell.instructions.md as guidelines

BeforeAll {
  $script:ps1Path = Join-Path $PSScriptRoot '..\..\public\New-SprintStage1.ps1'

  # PSFramework stub — ensures dot-source does not error when PSFramework is absent.
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
  }
}

Describe 'New-SprintStage1 load-contract (K03)' -Tag 'Unit' {

  BeforeEach {
    # Remove any prior definition so each test starts with a known-absent function.
    Remove-Item Function:\New-SprintStage1 -ErrorAction SilentlyContinue

    # Global list used by all canary stubs below.
    $global:K03SideEffectCalls = [System.Collections.Generic.List[string]]::new()

    # Canary stubs — each records its name if invoked; a triggered canary means
    # the dot-source executed top-level code instead of just defining the function.
    function global:Assert-GitAvailable { $global:K03SideEffectCalls.Add('Assert-GitAvailable') }
    function global:gh                  { $global:K03SideEffectCalls.Add('gh') }
    function global:git                 { $global:K03SideEffectCalls.Add('git') }
    function global:Set-WorktreeJunctions {
      $global:K03SideEffectCalls.Add('Set-WorktreeJunctions')
    }
    function global:Initialize-DownstreamSprintFromSharedVSCode {
      $global:K03SideEffectCalls.Add('Initialize-DownstreamSprintFromSharedVSCode')
    }
    function global:New-DeveloperSqlServerInstances {
      $global:K03SideEffectCalls.Add('New-DeveloperSqlServerInstances')
    }
    function global:Set-BuildMasterSprintVariables {
      $global:K03SideEffectCalls.Add('Set-BuildMasterSprintVariables')
    }
    function global:New-SprintBitwardenSecrets {
      $global:K03SideEffectCalls.Add('New-SprintBitwardenSecrets')
    }
  }

  AfterEach {
    # Remove all canary stubs to avoid polluting subsequent tests or test runs.
    'Assert-GitAvailable', 'gh', 'git', 'Set-WorktreeJunctions',
    'Initialize-DownstreamSprintFromSharedVSCode', 'New-DeveloperSqlServerInstances',
    'Set-BuildMasterSprintVariables', 'New-SprintBitwardenSecrets' |
      ForEach-Object { Remove-Item "Function:\$_" -ErrorAction SilentlyContinue }

    Remove-Variable -Name K03SideEffectCalls -Scope Global -ErrorAction SilentlyContinue
    Remove-Item Function:\New-SprintStage1 -ErrorAction SilentlyContinue
  }

  It 'defines New-SprintStage1 as a Function command after dot-source' {
    . $script:ps1Path

    $cmd = Get-Command New-SprintStage1 -CommandType Function -ErrorAction SilentlyContinue
    $cmd             | Should -Not -BeNullOrEmpty
    $cmd.CommandType | Should -Be ([System.Management.Automation.CommandTypes]::Function)
  }

  It 'dot-source does not invoke any side-effecting external commands' {
    . $script:ps1Path

    $global:K03SideEffectCalls | Should -BeNullOrEmpty -Because (
      'loading the function definition must not call external tools. ' +
      "Commands triggered during dot-source: $($global:K03SideEffectCalls -join ', ')"
    )
  }

  It 'exposes the expected public parameter contract after dot-source' {
    . $script:ps1Path

    $params = (Get-Command New-SprintStage1 -CommandType Function).Parameters.Keys
    $params | Should -Contain 'GitRoot'
    $params | Should -Contain 'Owner'
    $params | Should -Contain 'SprintNumber'
    $params | Should -Contain 'DryRun'
    $params | Should -Contain 'ProGetBaseUrl'
  }

  It 'dot-source is idempotent — sourcing twice leaves no side effects and keeps the function defined' {
    . $script:ps1Path
    . $script:ps1Path  # second dot-source must also be safe

    $global:K03SideEffectCalls | Should -BeNullOrEmpty -Because (
      'repeated dot-source must remain side-effect free'
    )
    Get-Command New-SprintStage1 -CommandType Function -ErrorAction SilentlyContinue |
      Should -Not -BeNullOrEmpty
  }
}
