#Requires -Version 7.0
# Pester 5+ tests for Set-GlobalConfigRootKeys orchestration and in-module sibling resolution.

BeforeAll {
  $script:moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $script:publicDir = Join-Path $script:moduleRoot 'public'

  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
    $script:createdWritePSFMessageStub = $true
  }

  # Preserve any globals the surrounding session may already hold.
  $script:savedConfigRootKeys = $global:configRootKeys

  # Dot-source ONLY the orchestrator. The section functions must be resolved by the
  # orchestrator's in-module sibling-resolution block, not pre-loaded here.
  . (Join-Path $script:publicDir 'Set-GlobalConfigRootKeys.ps1')
}

AfterAll {
  $global:configRootKeys = $script:savedConfigRootKeys
  if ($script:createdWritePSFMessageStub) {
    Remove-Item -LiteralPath 'Function:\Write-PSFMessage' -ErrorAction SilentlyContinue
  }
}

Describe 'Set-GlobalConfigRootKeys population' -Tag 'Unit' {
  BeforeEach {
    $global:configRootKeys = $null
  }

  It 'creates and fully populates $global:configRootKeys with keys from every section' {
    Set-GlobalConfigRootKeys -Confirm:$false

    $global:configRootKeys | Should -BeOfType ([hashtable])
    $global:configRootKeys.Count | Should -BeGreaterThan 100

    # one representative key from each section function
    $global:configRootKeys.ContainsKey('SYSTEMDRIVEConfigRootKey') | Should -BeTrue                       # Set-CoreConfigRootKeys
    $global:configRootKeys.ContainsKey('DatabaseHostConfigRootKey') | Should -BeTrue                      # Add-DatabasesConfigRootKeys
    $global:configRootKeys.ContainsKey('DatabaseATAPUtilitiesNameConfigRootKey') | Should -BeTrue         # Set-DatabasesATAPUtilitiesConfigRootKeys
    $global:configRootKeys.ContainsKey('DatabaseAceCommanderNameConfigRootKey') | Should -BeTrue          # Set-DatabasesAceCommanderConfigRootKeys
    $global:configRootKeys.ContainsKey('SqlInstanceTopologyConfigRootKey') | Should -BeTrue               # Set-SqlInstanceTopologyConfigRootKeys
    $global:configRootKeys.ContainsKey('SqlInstanceTopologyTcpPortConfigRootKey') | Should -BeTrue        # Set-SqlInstanceTopologyConfigRootKeys
    $global:configRootKeys.ContainsKey('BuildMasterBaseUrlConfigRootKey') | Should -BeTrue                # Set-BuildMasterConfigRootKeys
    $global:configRootKeys.ContainsKey('BuildMasterApplicationByModuleConfigRootKey') | Should -BeTrue    # Set-BuildMasterConfigRootKeys (module->application map)
    $global:configRootKeys.ContainsKey('RulesManagementDatabaseHostConfigRootKey') | Should -BeTrue       # Set-RulesManagementConfigRootKeys
    $global:configRootKeys.ContainsKey('ProGetFeedNuGetExperimentalFeedNameConfigRootKey') | Should -BeTrue # Add-PackageRepositoriesConfigRootKeys
  }

  It 'does not populate $global:configRootKeys under -WhatIf' {
    $global:configRootKeys = $null
    Set-GlobalConfigRootKeys -WhatIf
    $global:configRootKeys | Should -BeNullOrEmpty
  }
}

Describe 'Set-GlobalConfigRootKeys in-module sibling resolution' -Tag 'Unit' {
  AfterEach {
    Remove-Item -LiteralPath 'Function:\Set-RulesManagementConfigRootKeys' -ErrorAction SilentlyContinue
    Remove-Variable -Name 'RM_STUB_RAN' -Scope Global -ErrorAction SilentlyContinue
  }

  It 'invokes the co-located section source, not a pre-existing (installed-style) global function of the same name' {
    $global:configRootKeys = $null

    # Simulate an INSTALLED production module having autoloaded a stale version of a
    # section function into the session before the orchestrator runs. The stub adds
    # NO real keys and records that it ran.
    function global:Set-RulesManagementConfigRootKeys { $global:RM_STUB_RAN = $true }

    Set-GlobalConfigRootKeys -Confirm:$false

    # The co-located sprint-worktree source must win: real RulesManagement keys present
    # and the stub must NOT have executed.
    $global:configRootKeys.ContainsKey('RulesManagementDatabaseHostConfigRootKey') | Should -BeTrue
    $global:configRootKeys.ContainsKey('OtterScriptRulesGrammarPathConfigRootKey') | Should -BeTrue
    (Test-Path Variable:\Global:RM_STUB_RAN) | Should -BeFalse
  }

  It 'throws an actionable error when a section function has neither a co-located source nor a loaded definition' {
    $global:configRootKeys = $null
    $emptyDir = Join-Path ([System.IO.Path]::GetTempPath()) ('crk-empty-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $emptyDir -Force | Out-Null
    $stagedFunctions = @(
      'Set-CoreConfigRootKeys'
      'Add-DatabasesConfigRootKeys'
      'Set-SqlInstanceTopologyConfigRootKeys'
      'Set-BuildMasterConfigRootKeys'
      'Set-RulesManagementConfigRootKeys'
      'Add-PackageRepositoriesConfigRootKeys'
    )
    Mock Get-Command {
      param($Name, $CommandType, $ErrorAction)
      if ($Name -in $stagedFunctions) {
        return $null
      }
      Microsoft.PowerShell.Core\Get-Command -Name $Name -CommandType $CommandType -ErrorAction $ErrorAction
    }
    try {
      { Set-GlobalConfigRootKeys -Path $emptyDir -Confirm:$false } |
        Should -Throw -ExpectedMessage '*is not defined and its source file was not found*'
    } finally {
      Remove-Item -LiteralPath $emptyDir -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
}

Describe 'ConfigRootKeys section functions precondition guard' -Tag 'Unit' {
  BeforeAll {
    . (Join-Path $script:publicDir 'Set-BuildMasterConfigRootKeys.ps1')
    . (Join-Path $script:publicDir 'Add-DatabasesConfigRootKeys.ps1')
    . (Join-Path $script:publicDir 'Set-SqlInstanceTopologyConfigRootKeys.ps1')
  }

  It 'Set-BuildMasterConfigRootKeys throws when $global:configRootKeys is null' {
    $global:configRootKeys = $null
    { Set-BuildMasterConfigRootKeys -Confirm:$false } | Should -Throw -ExpectedMessage '*not initialized*'
  }

  It 'Add-DatabasesConfigRootKeys throws when $global:configRootKeys is null' {
    $global:configRootKeys = $null
    { Add-DatabasesConfigRootKeys -Confirm:$false } | Should -Throw -ExpectedMessage '*not initialized*'
  }

  It 'Set-SqlInstanceTopologyConfigRootKeys throws when $global:configRootKeys is null' {
    $global:configRootKeys = $null
    { Set-SqlInstanceTopologyConfigRootKeys -Confirm:$false } | Should -Throw -ExpectedMessage '*not initialized*'
  }
}
