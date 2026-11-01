# Fake-only privacy regression tests. Root admits execution separately.
# Every command-discovery/token/native/logging route has a local fail-closed shim
# and an unconditional mock. No module import, vault, DPAPI file or native CLI.
BeforeAll {
  $publicDirectory = Join-Path $PSScriptRoot '../../public'
  . (Join-Path $publicDirectory 'Get-SecretATAP.ps1')
  . (Join-Path $publicDirectory 'Get-SecretATAPBitwardenSecretsManager.ps1')

  function Write-PSFMessage {
    param($FunctionName, $ModuleName, $Level, $Message, $ErrorRecord, $Tag)
    throw 'Unmocked test logger route'
  }
  function Get-BWSAccessToken {
    [CmdletBinding()]
    param([string]$TokenPurpose)
    throw 'Unmocked test token route'
  }
  function bws {
    param([Parameter(ValueFromRemainingArguments = $true)]$NativeArguments)
    throw 'Unmocked test native route'
  }
  function Get-SecretATAPBitwarden {
    param($SecretName, $SecretField)
    throw 'Personal vault route forbidden in privacy tests'
  }

  function Invoke-PrivacyProbe {
    param([scriptblock]$Action)
    $caught = $null
    try { & $Action | Out-Null } catch { $caught = $_ }
    $caught | Should -Not -BeNullOrEmpty
    $caught.Exception.Message | Should -Not -Match 'SYNTHETIC_PRIVATE_'
    $caught.ToString() | Should -Not -Match 'SYNTHETIC_PRIVATE_'
    $caught.TargetObject | Should -BeNullOrEmpty
    $caught.Exception.InnerException | Should -BeNullOrEmpty
    if ($null -ne $caught.ErrorDetails) {
      $caught.ErrorDetails.Message | Should -Not -Match 'SYNTHETIC_PRIVATE_'
    }
    $errorLogs = @($script:privacyLogs | Where-Object Level -EQ 'Error')
    $errorLogs.Count | Should -BeGreaterThan 0
    foreach ($entry in $script:privacyLogs) {
      $entry.Message | Should -Not -Match 'SYNTHETIC_PRIVATE_'
      if ($null -ne $entry.ErrorRecord) {
        $entry.ErrorRecord.Exception.Message | Should -Not -Match 'SYNTHETIC_PRIVATE_'
        $entry.ErrorRecord.TargetObject | Should -BeNullOrEmpty
        $entry.ErrorRecord.Exception.InnerException | Should -BeNullOrEmpty
      }
    }
    return $caught
  }
}

Describe 'Secret-read public error privacy' -Tag 'Unit', 'FakeOnly' {
  BeforeEach {
    $script:previousToken = [Environment]::GetEnvironmentVariable('BWS_ACCESS_TOKEN', 'Process')
    $script:previousExitCode = $global:LASTEXITCODE
    $env:BWS_ACCESS_TOKEN = 'SYNTHETIC_PRIVATE_EXISTING_TOKEN'
    $script:privacyLogs = [Collections.Generic.List[object]]::new()
    $script:nativeOutput = '[]'
    $script:nativeExit = 0
    $script:tokenSeenByNative = $null

    Mock Write-PSFMessage {
      $script:privacyLogs.Add([pscustomobject]@{
        Level = [string]$Level; Message = [string]$Message; ErrorRecord = $ErrorRecord
      })
    }
    Mock Get-Command {
      if ($Name -notin @('Get-BWSAccessToken', 'bws', 'Get-SecretATAPBitwardenSecretsManager', 'Get-SecretATAPBitwarden')) {
        throw 'Unexpected discovery route in fake-only test'
      }
      [pscustomobject]@{ Name = $Name }
    }
    Mock Get-BWSAccessToken {
      if ($TokenPurpose -cne 'ReadOnly') { throw 'Unexpected token purpose' }
      $secure = ConvertTo-SecureString 'SYNTHETIC_PRIVATE_DPAPI_TOKEN' -AsPlainText -Force
      [Management.Automation.PSCredential]::new('BWS_ACCESS_TOKEN', $secure)
    }
    Mock bws {
      $script:tokenSeenByNative = $env:BWS_ACCESS_TOKEN
      $global:LASTEXITCODE = $script:nativeExit
      $script:nativeOutput
    }
    Mock Get-SecretATAPBitwarden { throw 'Personal vault route forbidden in privacy tests' }
    Mock Test-Path { throw 'Filesystem/source fallback forbidden in privacy tests' }
    Mock Import-Clixml { throw 'Credential-file reads forbidden in privacy tests' }
    Mock Remove-Item {
      if ($Path -cne 'Env:BWS_ACCESS_TOKEN') { throw 'Unexpected removal route' }
      [Environment]::SetEnvironmentVariable('BWS_ACCESS_TOKEN', $null, 'Process')
    }
  }

  AfterEach {
    [Environment]::SetEnvironmentVariable('BWS_ACCESS_TOKEN', $script:previousToken, 'Process')
    $global:LASTEXITCODE = $script:previousExitCode
  }

  It 'replaces nonzero native output with a fixed public failure' {
    $script:nativeExit = 7
    $script:nativeOutput = 'SYNTHETIC_PRIVATE_NATIVE_OUTPUT and granted-project secret values'
    $caught = Invoke-PrivacyProbe { Get-SecretATAPBitwardenSecretsManager -SecretName 'Fake.Key' }
    $caught.Exception.Message | Should -BeExactly 'Secret read failed [ATAP.SecretRead.Bws.NativeRead].'
    Should -Invoke bws -Exactly -Times 1 -Scope It
    Should -Invoke Get-BWSAccessToken -Exactly -Times 0 -Scope It
    $env:BWS_ACCESS_TOKEN | Should -BeExactly 'SYNTHETIC_PRIVATE_EXISTING_TOKEN'
  }

  It 'does not forward malformed list JSON or parser exception details' {
    $script:nativeOutput = '{"SYNTHETIC_PRIVATE_JSON": invalid-json'
    $caught = Invoke-PrivacyProbe { Get-SecretATAPBitwardenSecretsManager -SecretName 'Fake.Key' }
    $caught.Exception.Message | Should -BeExactly 'Secret read failed [ATAP.SecretRead.Bws.ParseResponse].'
    Should -Invoke bws -Exactly -Times 1 -Scope It
  }

  It 'replaces a nested provider error including its target and inner exception' {
    Mock Get-SecretATAPBitwardenSecretsManager {
      $inner = [Exception]::new('SYNTHETIC_PRIVATE_INNER')
      $exception = [InvalidOperationException]::new('SYNTHETIC_PRIVATE_PROVIDER', $inner)
      $record = [Management.Automation.ErrorRecord]::new(
        $exception, 'FakeProviderFailure', [Management.Automation.ErrorCategory]::InvalidData,
        'SYNTHETIC_PRIVATE_TARGET')
      Write-Error -ErrorRecord $record -ErrorAction Stop
    }
    $caught = Invoke-PrivacyProbe {
      Get-SecretATAP -SecretName 'Fake.Key' -SecretStoreType BitwardenSecretsManager
    }
    $caught.Exception.Message | Should -BeExactly 'Secret read failed [ATAP.SecretRead.Wrapper.ReadProvider].'
    Should -Invoke Get-SecretATAPBitwardenSecretsManager -Exactly -Times 1 -Scope It -ParameterFilter {
      $SecretName -ceq 'Fake.Key' -and $SecretField -ceq 'password'
    }
    Should -Invoke bws -Exactly -Times 0 -Scope It
  }

  It 'keeps both wrapper and real source-provider error logs free of native output' {
    $script:nativeExit = 9
    $script:nativeOutput = 'SYNTHETIC_PRIVATE_NESTED_NATIVE'
    $caught = Invoke-PrivacyProbe {
      Get-SecretATAP -SecretName 'Fake.Key' -SecretStoreType BitwardenSecretsManager
    }
    $caught.Exception.Message | Should -BeExactly 'Secret read failed [ATAP.SecretRead.Wrapper.ReadProvider].'
    @($script:privacyLogs | Where-Object Level -EQ 'Error').Count | Should -Be 2
    Should -Invoke bws -Exactly -Times 1 -Scope It
  }

  It 'sanitizes a token-reader exception before reaching the native route' {
    [Environment]::SetEnvironmentVariable('BWS_ACCESS_TOKEN', $null, 'Process')
    Mock Get-BWSAccessToken {
      throw [InvalidOperationException]::new('SYNTHETIC_PRIVATE_TOKEN_READER')
    }
    $caught = Invoke-PrivacyProbe { Get-SecretATAPBitwardenSecretsManager -SecretName 'Fake.Key' }
    $caught.Exception.Message | Should -BeExactly 'Secret read failed [ATAP.SecretRead.Bws.ReadToken].'
    Should -Invoke bws -Exactly -Times 0 -Scope It
    Should -Invoke Remove-Item -Exactly -Times 0 -Scope It
    $env:BWS_ACCESS_TOKEN | Should -BeNullOrEmpty
  }

  It 'does not interpolate caller metadata into unsupported-store failure logs' {
    $caught = Invoke-PrivacyProbe {
      Get-SecretATAP -SecretName 'SYNTHETIC_PRIVATE_NAME' -SecretField 'SYNTHETIC_PRIVATE_FIELD' -SecretStoreType 'SYNTHETIC_PRIVATE_STORE'
    }
    $caught.Exception.Message | Should -BeExactly 'Secret read failed [ATAP.SecretRead.Wrapper.UnsupportedStore].'
    Should -Invoke bws -Exactly -Times 0 -Scope It
    Should -Invoke Get-BWSAccessToken -Exactly -Times 0 -Scope It
  }

  It 'returns the same raw value and keeps it out of logs' {
    $script:nativeOutput = '[{"key":"Fake.Key","value":"SYNTHETIC_PRIVATE_RAW_VALUE"}]'
    Get-SecretATAP -SecretName 'fake.key' -SecretStoreType BitwardenSecretsManager |
      Should -BeExactly 'SYNTHETIC_PRIVATE_RAW_VALUE'
    ($script:privacyLogs.Message -join '|') | Should -Not -Match 'SYNTHETIC_PRIVATE_'
    Should -Invoke bws -Exactly -Times 1 -Scope It
    Should -Invoke Get-SecretATAPBitwarden -Exactly -Times 0 -Scope It
  }

  It 'preserves default password extraction and raw JSON when a field is absent' {
    $script:nativeOutput = '[{"key":"Fake.Key","value":"{\"password\":\"SYNTHETIC_PRIVATE_PASSWORD\"}"}]'
    Get-SecretATAPBitwardenSecretsManager -SecretName 'Fake.Key' |
      Should -BeExactly 'SYNTHETIC_PRIVATE_PASSWORD'
    $script:nativeOutput = '[{"key":"Fake.Key","value":"{\"username\":\"SYNTHETIC_PRIVATE_USER\"}"}]'
    Get-SecretATAPBitwardenSecretsManager -SecretName 'Fake.Key' |
      Should -BeExactly '{"username":"SYNTHETIC_PRIVATE_USER"}'
    ($script:privacyLogs.Message -join '|') | Should -Not -Match 'SYNTHETIC_PRIVATE_'
  }

  It 'cleans up a token acquired here after <Label>' -ForEach @(
    @{ Label = 'success'; NativeExit = 0 },
    @{ Label = 'native failure'; NativeExit = 11 },
    @{ Label = 'parse failure'; NativeExit = 0 }
  ) {
    [Environment]::SetEnvironmentVariable('BWS_ACCESS_TOKEN', $null, 'Process')
    $script:nativeExit = $NativeExit
    $script:nativeOutput = if ($Label -eq 'parse failure') {
      '{SYNTHETIC_PRIVATE_BAD_JSON'
    } else {
      '[{"key":"Fake.Key","value":"SYNTHETIC_PRIVATE_RETURN"}]'
    }
    if ($Label -eq 'success') {
      Get-SecretATAPBitwardenSecretsManager -SecretName 'Fake.Key' |
        Should -BeExactly 'SYNTHETIC_PRIVATE_RETURN'
    } else {
      $null = Invoke-PrivacyProbe { Get-SecretATAPBitwardenSecretsManager -SecretName 'Fake.Key' }
    }
    $script:tokenSeenByNative | Should -BeExactly 'SYNTHETIC_PRIVATE_DPAPI_TOKEN'
    $env:BWS_ACCESS_TOKEN | Should -BeNullOrEmpty
    Should -Invoke Get-BWSAccessToken -Exactly -Times 1 -Scope It -ParameterFilter { $TokenPurpose -ceq 'ReadOnly' }
    Should -Invoke Remove-Item -Exactly -Times 1 -Scope It -ParameterFilter { $Path -ceq 'Env:BWS_ACCESS_TOKEN' }
    Should -Invoke bws -Exactly -Times 1 -Scope It
  }
}
