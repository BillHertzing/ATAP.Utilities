BeforeAll {
  $functionFile = Join-Path $PSScriptRoot '..\..\public\Set-AceOutpostProxyEnvironment.ps1'
  . $functionFile
  if (Get-Module -ListAvailable -Name PSFramework) {
    Import-Module PSFramework -ErrorAction SilentlyContinue
  }

  $script:variableNames = @('HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY', 'NO_PROXY', 'NODE_EXTRA_CA_CERTS', 'SSL_CERT_FILE')
  $script:originalValues = @{}
  foreach ($name in $script:variableNames) {
    $script:originalValues[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
  }
  $script:stateDirectory = Join-Path $TestDrive 'AceOutpostState'
  New-Item -ItemType Directory -Path $script:stateDirectory -Force | Out-Null
  Set-Content -LiteralPath (Join-Path $script:stateDirectory 'AceOutpost-Interception-Root.pem') -Value 'public-root-placeholder'

  function Get-SecretATAP {
    param([string]$SecretName)
    'test-user:test-secret'
  }
}

Describe 'Set-AceOutpostProxyEnvironment' -Tag 'Unit' {
  BeforeEach {
    foreach ($name in $script:variableNames) {
      [Environment]::SetEnvironmentVariable($name, $null, 'Process')
    }
  }

  AfterAll {
    foreach ($name in $script:variableNames) {
      [Environment]::SetEnvironmentVariable($name, $script:originalValues[$name], 'Process')
    }
    Remove-Item -LiteralPath Function:\Get-SecretATAP -ErrorAction SilentlyContinue
  }

  It 'supports WhatIf' {
    (Get-Command Set-AceOutpostProxyEnvironment).Parameters.ContainsKey('WhatIf') | Should -BeTrue
  }

  It 'enables Codex with the documented proxy and OpenSSL trust settings' {
    $result = Set-AceOutpostProxyEnvironment -State Enabled -Client Codex -StateDirectory $script:stateDirectory -Confirm:$false

    [Environment]::GetEnvironmentVariable('HTTP_PROXY', 'Process') | Should -Be 'http://test-user:test-secret@127.0.0.1:50055'
    [Environment]::GetEnvironmentVariable('HTTPS_PROXY', 'Process') | Should -Be 'http://test-user:test-secret@127.0.0.1:50055'
    [Environment]::GetEnvironmentVariable('NO_PROXY', 'Process') | Should -Be 'localhost,127.0.0.1,::1'
    [Environment]::GetEnvironmentVariable('SSL_CERT_FILE', 'Process') | Should -Be (Join-Path $script:stateDirectory 'AceOutpost-Interception-Root.pem')
    [Environment]::GetEnvironmentVariable('NODE_EXTRA_CA_CERTS', 'Process') | Should -BeNullOrEmpty
    $result.ProxyEndpoint | Should -Be 'http://127.0.0.1:50055'
    $result.PersistentCredential | Should -BeFalse
  }

  It 'enables Claude Code with the documented Node trust setting' {
    $null = Set-AceOutpostProxyEnvironment -State Enabled -Client ClaudeCode -StateDirectory $script:stateDirectory -Confirm:$false

    [Environment]::GetEnvironmentVariable('NODE_EXTRA_CA_CERTS', 'Process') | Should -Be (Join-Path $script:stateDirectory 'AceOutpost-Interception-Root.pem')
    [Environment]::GetEnvironmentVariable('SSL_CERT_FILE', 'Process') | Should -BeNullOrEmpty
  }

  It 'removes proxy and Codex trust settings when disabled' {
    $null = Set-AceOutpostProxyEnvironment -State Enabled -Client Codex -StateDirectory $script:stateDirectory -Confirm:$false
    $result = Set-AceOutpostProxyEnvironment -State Disabled -Client Codex -Confirm:$false

    foreach ($name in @('HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY', 'NO_PROXY', 'SSL_CERT_FILE')) {
      [Environment]::GetEnvironmentVariable($name, 'Process') | Should -BeNullOrEmpty
    }
    $result.State | Should -Be 'Disabled'
  }

  It 'does not persist credentials without explicit acknowledgement' {
    {
      Set-AceOutpostProxyEnvironment -State Enabled -Client Codex -Scope User -StateDirectory $script:stateDirectory -Confirm:$false
    } | Should -Throw '*AllowPersistentCredential*'
  }

  It 'does not change the environment under WhatIf' {
    $result = Set-AceOutpostProxyEnvironment -State Enabled -Client Codex -StateDirectory $script:stateDirectory -WhatIf

    [Environment]::GetEnvironmentVariable('HTTPS_PROXY', 'Process') | Should -BeNullOrEmpty
    $result.ChangedVariables | Should -BeNullOrEmpty
  }
}
