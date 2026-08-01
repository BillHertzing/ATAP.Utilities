#Requires -Version 7.0

$movedFunctions = @(
  'List-ProGetFeeds',
  'List-ProGetConnectors',
  'List-ProGetApiKeys',
  'New-ProGetFeedSet',
  'New-ProGetConnector',
  'New-ProGetApiKey',
  'Remove-ProGetFeeds',
  'Remove-ProGetApiKeys',
  'Register-ProGetFeedSet',
  'Test-ProGetFeedSet'
)

$adminFunctions = @($movedFunctions | Where-Object { $_ -notin @('Register-ProGetFeedSet', 'Test-ProGetFeedSet') })

BeforeAll {
  $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $publicDir = Join-Path $moduleRoot 'public'
  foreach ($functionName in $movedFunctions) {
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
  It '<_> is available from its relocated public source file' -ForEach $movedFunctions {
    Get-Command -Name $_ -CommandType Function | Should -Not -BeNullOrEmpty
  }

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

  It 'removes feed and API-key metadata using only a resolved admin secret' {
    . (Join-Path $publicDir 'Remove-ProGetFeeds.ps1')
    . (Join-Path $publicDir 'Remove-ProGetApiKeys.ps1')
    Mock Write-PSFMessage { }
    $global:proGetSecretResolutionCount = 0
    $global:proGetRestCalls = @()
    Mock Get-SecretATAP {
      param([string]$SecretName, [string]$SecretStoreType)
      $global:proGetSecretResolutionCount++
      'admin-auth-value'
    }
    Mock Invoke-RestMethod {
      param($Uri, $Method, $Headers, $Body, $ContentType)
      $global:proGetRestCalls += [PSCustomObject]@{ Uri = $Uri; Method = $Method }
      [PSCustomObject]@{ status = 'deleted' }
    }

    try {
      $feedResult = Remove-ProGetFeeds -Name 'unit-feed' -ProGetBaseScheme http -ProGetBaseHost localhost -ProGetBasePort 50000 -Confirm:$false
      $apiKeyResult = Remove-ProGetApiKeys -iD 42 -proGetBaseScheme http -proGetBaseHost localhost -proGetBasePort 50000 -Confirm:$false

      $feedResult['unit-feed'] | Should -BeTrue
      $apiKeyResult[42] | Should -BeTrue
      $global:proGetSecretResolutionCount | Should -Be 2
      Should -Invoke Get-SecretATAP -Times 2 -Exactly
      Should -Invoke Invoke-RestMethod -Times 2 -Exactly
      @($global:proGetRestCalls | Where-Object { $_.Method -eq 'Post' -and $_.Uri -like '*/api/management/feeds/delete/unit-feed' }).Count | Should -Be 1
      @($global:proGetRestCalls | Where-Object { $_.Method -eq 'Delete' -and $_.Uri -like '*/api/api-keys/delete/*id=42' }).Count | Should -Be 1
    }
    finally {
      Remove-Variable proGetSecretResolutionCount -Scope Global -ErrorAction SilentlyContinue
      Remove-Variable proGetRestCalls -Scope Global -ErrorAction SilentlyContinue
    }
  }

  It 'validates configured feeds through List-ProGetFeeds without calling ProGet directly' {
    # Asserted from source, not by execution. The previous version dot-sourced
    # Test-ProGetFeedSet and shadowed List-ProGetFeeds with a global: function. That works only
    # when no module is imported: against the PROMOTED package the module's own
    # List-ProGetFeeds wins the name resolution, the real one runs, and it needs configuration
    # this fixture has no business supplying. The test then failed for reasons unrelated to the
    # contract it exists to protect -- first on the SC-0288 placement-host fail-closed path once
    # Common 0.1.8 deployed Resolve-HostSuffixedSecretName, then on a missing config key.
    #
    # The contract itself is structural, so check it structurally, the way every other test in
    # this file does. This runs identically in source and promoted contexts.
    $source = Get-Content -Raw (Join-Path $publicDir 'Test-ProGetFeedSet.ps1')

    # It must obtain feeds through the shared cmdlet ...
    $source | Should -Match 'List-ProGetFeeds'
    # ... and must never reach ProGet itself, which is what routing through List-ProGetFeeds buys:
    # one place resolves the admin SecretName and one place talks to the server.
    $source | Should -Not -Match 'Invoke-RestMethod'
    $source | Should -Not -Match 'Invoke-WebRequest'
    # And it must not resolve a secret of its own.
    $source | Should -Not -Match 'Get-SecretATAP'
  }
}
