#Requires -Version 7.0

$adminFunctions = @(
  'List-ProGetFeeds',
  'List-ProGetConnectors',
  'List-ProGetApiKeys',
  'New-ProGetFeedSet',
  'New-ProGetConnector',
  'New-ProGetApiKey',
  'Remove-ProGetFeeds',
  'Remove-ProGetApiKeys',
  'Rename-ProGetFeed'
)

BeforeAll {
  $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $publicDir = Join-Path $moduleRoot 'public'
  foreach ($functionName in $adminFunctions) {
    . (Join-Path $publicDir "$functionName.ps1")
  }
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
  }
  if (-not (Get-Command Get-SecretATAP -ErrorAction SilentlyContinue)) {
    function global:Get-SecretATAP { param([string]$SecretName, [string]$SecretStoreType) 'unit-test-admin-key' }
  }
}

Describe 'ProGet administration SecretName contracts' -Tag 'Unit' {
  It '<_> exposes only the canonical ProGet API-key SecretName boundary' -ForEach $adminFunctions {
    $source = Get-Content -Raw (Join-Path $publicDir "$_.ps1")
    $source | Should -Match '\[string\]\$ProGetApiKeySecretName'
    $source | Should -Match '\[ValidateNotNullOrEmpty\(\)\]'
    $source | Should -Not -Match '\[string\]\$ApiKey\b'
  }

  It '<_> contains no active API-key environment or raw-value fallback' -ForEach $adminFunctions {
    $source = Get-Content -Raw (Join-Path $publicDir "$_.ps1")
    $source | Should -Not -Match 'ProGetAdminApiKeyConfigRootKey'
    $source | Should -Not -Match 'PROGET_(ADMIN_)?API_KEY'
    $source | Should -Not -Match 'GetEnvironmentVariable\([^\r\n]*(ApiKey|API_KEY)'
    $source | Should -Match 'Get-SecretATAP\s+-SecretName\s+\$ProGetApiKeySecretName'
  }

  It 'uses the canonical admin SecretName as the default for every administration cmdlet' {
    foreach ($functionName in $adminFunctions) {
      (Get-Content -Raw (Join-Path $publicDir "$functionName.ps1")) |
        Should -Match "ProGetApiKeySecretName\s*=\s*'ProGet\.Admin\.API\.Key'"
    }
  }

  It 'does not persist or return a newly generated API-key value' {
    . (Join-Path $publicDir 'New-ProGetApiKey.ps1')
    Mock Write-PSFMessage { }
    Mock Get-SecretATAP { 'admin-auth-value' }
    Mock Invoke-RestMethod { [PSCustomObject]@{ key = 'generated-sensitive-value'; id = 42 } }

    $result = New-ProGetApiKey -ApiKeyName 'feed-key-name' -FeedName 'feed' -PackagePermissions view -proGetBaseScheme http -proGetBaseHost localhost -proGetBasePort 50000

    ($result | ConvertTo-Json -Compress) | Should -Not -Match 'generated-sensitive-value|admin-auth-value'
    $result.Created | Should -BeTrue
  }

  It 'fails closed when SecretName resolution returns no value' {
    . (Join-Path $publicDir 'List-ProGetFeeds.ps1')
    Mock Write-PSFMessage { }
    Mock Get-SecretATAP { $null }
    Mock Invoke-RestMethod { @() }

    { List-ProGetFeeds -proGetBaseScheme http -proGetBaseHost localhost -proGetBasePort 50000 } |
      Should -Throw
    Should -Invoke Invoke-RestMethod -Times 0
  }

  It 'performs no discovery, secret resolution, or REST calls for list and connector WhatIf paths' {
    foreach ($functionName in @('List-ProGetFeeds', 'List-ProGetConnectors', 'List-ProGetApiKeys', 'New-ProGetConnector')) {
      . (Join-Path $publicDir "$functionName.ps1")
    }
    Mock Write-PSFMessage { }
    Mock Get-SecretATAP { 'must-not-resolve' }
    Mock Invoke-RestMethod { throw 'must-not-call-rest' }

    List-ProGetFeeds -proGetBaseScheme http -proGetBaseHost localhost -proGetBasePort 50000 -WhatIf | Out-Null
    List-ProGetConnectors -proGetBaseScheme http -proGetBaseHost localhost -proGetBasePort 50000 -WhatIf | Out-Null
    List-ProGetApiKeys -proGetBaseScheme http -proGetBaseHost localhost -proGetBasePort 50000 -WhatIf | Out-Null
    New-ProGetConnector -connector @{ name = 'upstream'; feedType = 'NuGet'; url = 'https://example.invalid'; enabled = $true; description = 'test' } -proGetBaseScheme http -proGetBaseHost localhost -proGetBasePort 50000 -WhatIf

    Should -Invoke Get-SecretATAP -Times 0
    Should -Invoke Invoke-RestMethod -Times 0
  }
}
