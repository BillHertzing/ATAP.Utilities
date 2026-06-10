<#
.SYNOPSIS
Unit tests for Get-SecretATAPBitwardenSecretsManager (Bitwarden Secrets Manager provider).

.NOTES
AI assisted using Powershell.instructions.md as guidelines
The `bws` CLI is replaced by an in-scope function shim returning canned JSON, so these
tests do not touch a real Bitwarden Secrets Manager account.
#>

BeforeAll {
  . "$PSScriptRoot\..\..\public\Get-SecretATAPBitwardenSecretsManager.ps1"

  # No-op logging shim if PSFramework is not loaded in the test host.
  if (-not (Get-Command -Name 'Write-PSFMessage' -ErrorAction SilentlyContinue)) {
    function Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Args) }
  }

  # Canned output for the `bws` CLI, controlled per-test via $script:bwsJson.
  $script:bwsJson = '[]'
  function bws {
    param([Parameter(ValueFromRemainingArguments = $true)]$Args)
    $script:bwsJson
    $global:LASTEXITCODE = 0
  }

  # Skip the DPAPI token path by supplying a process-scope token.
  $env:BWS_ACCESS_TOKEN = '0.test.token'
}

AfterAll {
  Remove-Item Env:BWS_ACCESS_TOKEN -ErrorAction SilentlyContinue
}

Describe 'Get-SecretATAPBitwardenSecretsManager' {

  It 'returns the raw value for a non-JSON secret' {
    $script:bwsJson = '[{"id":"1","key":"BuildMaster.Admin.API.Key","value":"abc123","projectId":"p1"}]'
    Get-SecretATAPBitwardenSecretsManager -BuildMasterAdminApiKeySecretName 'BuildMaster.Admin.API.Key' | Should -BeExactly 'abc123'
  }

  It 'matches the key case-insensitively' {
    $script:bwsJson = '[{"id":"1","key":"BuildMaster.Admin.API.Key","value":"abc123","projectId":"p1"}]'
    Get-SecretATAPBitwardenSecretsManager -SecretName 'buildmaster.admin.api.key' | Should -BeExactly 'abc123'
  }

  It 'extracts a field from a JSON-structured value' {
    $script:bwsJson = '[{"id":"2","key":"Windows.ServiceAccount.BuildMaster","value":"{\"username\":\"SvcBuildmaster\",\"password\":\"p@ss\"}","projectId":"p1"}]'
    Get-SecretATAPBitwardenSecretsManager -SecretName 'Windows.ServiceAccount.BuildMaster' -SecretField 'username' | Should -BeExactly 'SvcBuildmaster'
    Get-SecretATAPBitwardenSecretsManager -SecretName 'Windows.ServiceAccount.BuildMaster' -SecretField 'password' | Should -BeExactly 'p@ss'
  }

  It 'returns the raw JSON string when the requested field is absent' {
    $script:bwsJson = '[{"id":"2","key":"Some.Json","value":"{\"username\":\"u\"}","projectId":"p1"}]'
    Get-SecretATAPBitwardenSecretsManager -SecretName 'Some.Json' -SecretField 'password' | Should -BeExactly '{"username":"u"}'
  }

  It 'throws when the secret key is not found' {
    $script:bwsJson = '[{"id":"1","key":"Other.Key","value":"x","projectId":"p1"}]'
    { Get-SecretATAPBitwardenSecretsManager -SecretName 'Missing.Key' } | Should -Throw '*No Bitwarden Secrets Manager secret found*'
  }
}
