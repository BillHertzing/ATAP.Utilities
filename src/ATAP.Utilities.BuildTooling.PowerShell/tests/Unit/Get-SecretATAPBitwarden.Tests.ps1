#Requires -Version 7.0

BeforeAll {
  . "$PSScriptRoot\..\..\public\Get-SecretATAPBitwarden.ps1"

  if (-not (Get-Command -Name 'Write-PSFMessage' -ErrorAction SilentlyContinue)) {
    function Write-PSFMessage {
      param([Parameter(ValueFromRemainingArguments = $true)]$Args)
      $null = $Args
    }
  }

  function bw {
    param([Parameter(ValueFromRemainingArguments = $true)]$Args)

    $script:bwObservedEnvironment += [PSCustomObject]@{
      Arguments    = ($Args -join ' ')
      OPENSSL_CONF = [System.Environment]::GetEnvironmentVariable('OPENSSL_CONF', 'Process')
      OPENSSL_HOME = [System.Environment]::GetEnvironmentVariable('OPENSSL_HOME', 'Process')
      RANDFILE     = [System.Environment]::GetEnvironmentVariable('RANDFILE', 'Process')
      NODE_EXTRA_CA_CERTS = [System.Environment]::GetEnvironmentVariable('NODE_EXTRA_CA_CERTS', 'Process')
    }

    if ($script:bwMode -eq 'FailStatus' -and $Args[0] -eq 'status') {
      $global:LASTEXITCODE = 1
      'status failed'
      return
    }

    switch ($Args[0]) {
      'status' {
        $global:LASTEXITCODE = 0
        '{"status":"unlocked"}'
      }
      'get' {
        $global:LASTEXITCODE = 0
        '{"type":2,"notes":"unit-secret-value"}'
      }
      default {
        $global:LASTEXITCODE = 1
        "unexpected bw call: $($Args -join ' ')"
      }
    }
  }
}

Describe 'Get-SecretATAPBitwarden [public]' -Tag 'Unit' {
  BeforeEach {
    $script:bwObservedEnvironment = @()
    $script:bwMode = 'Success'
    $script:originalEnv = @{}

    foreach ($name in @('BW_SESSION', 'OPENSSL_CONF', 'OPENSSL_HOME', 'RANDFILE', 'NODE_EXTRA_CA_CERTS', 'ATAP_BITWARDEN_NODE_EXTRA_CA_CERTS')) {
      $script:originalEnv[$name] = [System.Environment]::GetEnvironmentVariable($name, 'Process')
    }

    $script:testNodeCaPath = Join-Path -Path $TestDrive -ChildPath 'node-extra-ca.pem'
    Set-Content -LiteralPath $script:testNodeCaPath -Value @(
      '-----BEGIN CERTIFICATE-----'
      'ZmFrZS1jYS1mb3ItdW5pdC10ZXN0cw=='
      '-----END CERTIFICATE-----'
    ) -Encoding ascii

    $env:BW_SESSION = 'unit-session'
    $env:OPENSSL_CONF = 'C:\Dropbox\Security\OpenSSL\AUdefault.cnf'
    $env:OPENSSL_HOME = 'C:\Dropbox\Security\OpenSSL'
    $env:RANDFILE = 'C:\Dropbox\Security\OpenSSLRandomKeySeed'
    Remove-Item Env:NODE_EXTRA_CA_CERTS -ErrorAction SilentlyContinue
    $env:ATAP_BITWARDEN_NODE_EXTRA_CA_CERTS = $script:testNodeCaPath
  }

  AfterEach {
    foreach ($name in $script:originalEnv.Keys) {
      [System.Environment]::SetEnvironmentVariable($name, $script:originalEnv[$name], 'Process')
    }
  }

  It 'clears HostSettings OpenSSL variables while bw status and get run, then restores them' {
    $result = Get-SecretATAPBitwarden -SecretName 'unit-secret'

    $result | Should -BeExactly 'unit-secret-value'
    $script:bwObservedEnvironment.Count | Should -Be 2
    foreach ($observed in $script:bwObservedEnvironment) {
      $observed.OPENSSL_CONF | Should -BeNullOrEmpty
      $observed.OPENSSL_HOME | Should -BeNullOrEmpty
      $observed.RANDFILE | Should -BeNullOrEmpty
      $observed.NODE_EXTRA_CA_CERTS | Should -BeExactly $script:testNodeCaPath
    }

    [System.Environment]::GetEnvironmentVariable('OPENSSL_CONF', 'Process') | Should -BeExactly 'C:\Dropbox\Security\OpenSSL\AUdefault.cnf'
    [System.Environment]::GetEnvironmentVariable('OPENSSL_HOME', 'Process') | Should -BeExactly 'C:\Dropbox\Security\OpenSSL'
    [System.Environment]::GetEnvironmentVariable('RANDFILE', 'Process') | Should -BeExactly 'C:\Dropbox\Security\OpenSSLRandomKeySeed'
    $restoredNodeExtraCaCerts = [System.Environment]::GetEnvironmentVariable('NODE_EXTRA_CA_CERTS', 'Process')
    if ([string]::IsNullOrEmpty($script:originalEnv['NODE_EXTRA_CA_CERTS'])) {
      $restoredNodeExtraCaCerts | Should -BeNullOrEmpty
    }
    else {
      $restoredNodeExtraCaCerts | Should -BeExactly $script:originalEnv['NODE_EXTRA_CA_CERTS']
    }
  }

  It 'restores HostSettings OpenSSL variables when bw status fails' {
    $script:bwMode = 'FailStatus'

    { Get-SecretATAPBitwarden -SecretName 'unit-secret' } | Should -Throw '*bw status failed*'

    [System.Environment]::GetEnvironmentVariable('OPENSSL_CONF', 'Process') | Should -BeExactly 'C:\Dropbox\Security\OpenSSL\AUdefault.cnf'
    [System.Environment]::GetEnvironmentVariable('OPENSSL_HOME', 'Process') | Should -BeExactly 'C:\Dropbox\Security\OpenSSL'
    [System.Environment]::GetEnvironmentVariable('RANDFILE', 'Process') | Should -BeExactly 'C:\Dropbox\Security\OpenSSLRandomKeySeed'
    $restoredNodeExtraCaCerts = [System.Environment]::GetEnvironmentVariable('NODE_EXTRA_CA_CERTS', 'Process')
    if ([string]::IsNullOrEmpty($script:originalEnv['NODE_EXTRA_CA_CERTS'])) {
      $restoredNodeExtraCaCerts | Should -BeNullOrEmpty
    }
    else {
      $restoredNodeExtraCaCerts | Should -BeExactly $script:originalEnv['NODE_EXTRA_CA_CERTS']
    }
  }
}
