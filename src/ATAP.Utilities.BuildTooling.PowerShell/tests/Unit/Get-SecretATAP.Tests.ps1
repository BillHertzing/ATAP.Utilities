#Requires -Version 7.0
# Pester 5+ tests for Get-SecretATAP dispatch behavior.

BeforeAll {
  $publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
  . (Join-Path $publicDir 'Get-SecretATAP.ps1')

  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
  }
  function Get-SecretATAPBitwarden {
    param(
      [string]$SecretName,
      [string]$SecretField
    )
    "bw:${SecretName}:${SecretField}"
  }
  function Get-SecretATAPBitwardenSecretsManager {
    param(
      [string]$SecretName,
      [string]$SecretField
    )
    "bws:${SecretName}:${SecretField}"
  }

  $script:oldConfigRootKeys = $global:configRootKeys
  $script:oldSettings = $global:settings
}

AfterAll {
  $global:configRootKeys = $script:oldConfigRootKeys
  $global:settings = $script:oldSettings
}

Describe 'Get-SecretATAP' -Tag 'Unit', 'PromotedModuleHostSensitive' {
  BeforeEach {
    Mock Write-PSFMessage { }
    $global:configRootKeys = @{
      SecretStoreTypeConfigRootKey = 'SecretStoreType'
    }
    $global:settings = @{
      SecretStoreType = 'Bitwarden'
    }
  }

  It 'Dispatches to Bitwarden Password Manager when configured' {
    Mock Get-SecretATAPBitwarden { "bw:${SecretName}:${SecretField}" }
    Mock Get-SecretATAPBitwardenSecretsManager { throw 'BWS should not be called' }

    $result = Get-SecretATAP -SecretName 'BuildMaster.Admin.API.Key' -SecretField 'key'

    $result | Should -Be 'bw:BuildMaster.Admin.API.Key:key'
    Should -Invoke Get-SecretATAPBitwarden -Times 1 -Exactly -Scope It
    Should -Invoke Get-SecretATAPBitwardenSecretsManager -Times 0 -Exactly -Scope It
  }

  It 'Dispatches to Bitwarden Secrets Manager when configured' {
    $global:settings.SecretStoreType = 'BitwardenSecretsManager'
    Mock Get-SecretATAPBitwarden { throw 'Bitwarden should not be called' }
    Mock Get-SecretATAPBitwardenSecretsManager { "bws:${SecretName}:${SecretField}" }

    $result = Get-SecretATAP -SecretName 'BuildMaster.Admin.API.Key' -SecretField 'token'

    $result | Should -Be 'bws:BuildMaster.Admin.API.Key:token'
    Should -Invoke Get-SecretATAPBitwarden -Times 0 -Exactly -Scope It
    Should -Invoke Get-SecretATAPBitwardenSecretsManager -Times 1 -Exactly -Scope It
  }

  It 'Rejects the retired -BuildMasterAdminApiKeySecretName alias (Task 8.9: callers must pass -SecretName)' {
    Mock Get-SecretATAPBitwarden { "bw:${SecretName}:${SecretField}" }

    { Get-SecretATAP -BuildMasterAdminApiKeySecretName 'BuildMaster.Admin.API.Key' } |
      Should -Throw -ExceptionType ([System.Management.Automation.ParameterBindingException])
  }

  It 'Explicit -SecretStoreType overrides the configured store (SC-0175)' {
    # $global:settings says Bitwarden, but the parameter forces BWS
    Mock Get-SecretATAPBitwarden { throw 'Bitwarden should not be called' }
    Mock Get-SecretATAPBitwardenSecretsManager { "bws:${SecretName}:${SecretField}" }

    $result = Get-SecretATAP -SecretName 'dbConnectionString-master-localhost-Dev-tester' -SecretStoreType 'BitwardenSecretsManager'

    $result | Should -Be 'bws:dbConnectionString-master-localhost-Dev-tester:password'
    Should -Invoke Get-SecretATAPBitwarden -Times 0 -Exactly -Scope It
    Should -Invoke Get-SecretATAPBitwardenSecretsManager -Times 1 -Exactly -Scope It
  }
}
