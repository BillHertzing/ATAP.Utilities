#Requires -Version 7.0

BeforeAll {
  $publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
  . (Join-Path $publicDir 'Rename-ProGetFeed.ps1')

  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
  }
  if (-not (Get-Command Get-SecretATAP -ErrorAction SilentlyContinue)) {
    function global:Get-SecretATAP { param([string]$SecretName, [string]$SecretStoreType) 'unit-test-admin-key' }
  }
}

Describe 'Rename-ProGetFeed SecretName boundary' -Tag 'Unit' {
  BeforeEach {
    Mock Write-PSFMessage { }
    Mock Get-SecretATAP { 'unit-test-admin-key' }
    Mock Invoke-RestMethod { [PSCustomObject]@{ feedName = 'new-feed' } }
  }

  It 'exposes a SecretName parameter and rejects the removed raw ApiKey parameter' {
    (Get-Command Rename-ProGetFeed).Parameters.Keys | Should -Contain 'ProGetApiKeySecretName'
    (Get-Command Rename-ProGetFeed).Parameters.Keys | Should -Not -Contain 'ApiKey'
    { Rename-ProGetFeed -OldFeedName old -NewFeedName new -ProGetBaseUrl 'http://proget.test' -ApiKey 'raw-value' } | Should -Throw
  }

  It 'resolves the requested secret immediately for the authenticated call' {
    $result = Rename-ProGetFeed -OldFeedName 'old-feed' -NewFeedName 'new-feed' -ProGetBaseUrl 'http://proget.test/' -ProGetApiKeySecretName 'Custom.Admin.Secret'

    $result.Success | Should -BeTrue
    Should -Invoke Get-SecretATAP -Times 1 -Exactly -ParameterFilter {
      $SecretName -eq 'Custom.Admin.Secret' -and $SecretStoreType -eq 'BitwardenSecretsManager'
    }
    Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
      $Uri -eq 'http://proget.test/api/management/feeds/update/old-feed' -and
      $Headers['X-ApiKey'] -eq 'unit-test-admin-key'
    }
  }

  It 'does not resolve a secret or call ProGet under WhatIf' {
    $result = Rename-ProGetFeed -OldFeedName old -NewFeedName new -ProGetBaseUrl 'http://proget.test' -WhatIf

    $result.Success | Should -BeFalse
    Should -Invoke Get-SecretATAP -Times 0
    Should -Invoke Invoke-RestMethod -Times 0
  }

  It 'fails closed without leaking a resolved value in the error' {
    Mock Get-SecretATAP { 'sensitive-unit-test-value' }
    Mock Invoke-RestMethod { throw 'remote failure sensitive-unit-test-value' }

    $errorText = $null
    try {
      Rename-ProGetFeed -OldFeedName old -NewFeedName new -ProGetBaseUrl 'http://proget.test'
    } catch {
      $errorText = $_.Exception.Message
    }
    $errorText | Should -Not -Match 'sensitive-unit-test-value'
    $errorText | Should -Match 'ProGet.Admin.API.Key'
  }
}
