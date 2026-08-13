#Requires -Version 7.0
# Pester 5+ tests for New-ProGetFeedSet.
# Invoke-RestMethod is mocked; no real ProGet traffic is generated.

BeforeAll {
  $publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
  . (Join-Path $publicDir 'New-ProGetFeedSet.ps1')

  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage {
      param([Parameter(ValueFromRemainingArguments = $true)]$rest)
    }
  }

  if (-not (Get-Command Get-SecretATAP -ErrorAction SilentlyContinue)) {
    function global:Get-SecretATAP {
      param([string]$SecretName, [string]$SecretStoreType)
      'unit-test-admin-key'
    }
  }

  $script:oldConfigRootKeys = $global:configRootKeys
  $script:oldSettings = $global:Settings
}

AfterAll {
  $global:configRootKeys = $script:oldConfigRootKeys
  $global:Settings = $script:oldSettings
  Remove-Item Function:\Write-PSFMessage -ErrorAction SilentlyContinue
  Remove-Item Function:\Get-SecretATAP -ErrorAction SilentlyContinue
}

Describe 'New-ProGetFeedSet' -Tag 'Unit', 'PromotedModuleHostSensitive' {

  BeforeEach {
    Mock Write-PSFMessage { }

    $global:configRootKeys = @{
      # SC-0288 / Task 13.66.b: SecretName host suffixes come from the placement map.
      ServicePlacementMapConfigRootKey = 'ServicePlacementMap'
      ProGetAdminUriSchemeConfigRootKey = 'PROGET_ADMIN_URI_SCHEME'
      ProGetAdminUriHostConfigRootKey   = 'PROGET_ADMIN_URI_HOST'
      ProGetAdminUriPortConfigRootKey   = 'PROGET_ADMIN_URI_PORT'
      ProGetAdminApiKeySecretNameConfigRootKey = 'ProGetAdminApiKeySecretName'
      ProGetFeedCollectionConfigRootKey = 'ProGetFeedCollection'
    }
    $global:Settings = @{
      ServicePlacementMap = @{ ProGet = 'utat022'; BuildMaster = 'utat022' }
      ProGetFeedCollection = [ordered]@{
        ReleaseBundleExperimental = @{
          FeedName        = 'releasebundle-experimental'
          FeedType        = 'universal'
          Tier            = 'experimental'
          ApiKeyName      = 'PROGET_APIKEY_RELEASEBUNDLE_EXPERIMENTAL'
          Uri             = 'https://utat022:50000/upack/releasebundle-experimental/'
          NuGetV3Uri      = $null
          Connectors      = @()
          RetentionPolicy = @{}
        }
        PowershellGetExperimental = @{
          FeedName        = 'powershellget-experimental'
          FeedType        = 'powershellget'
          Tier            = 'experimental'
          ApiKeyName      = 'PROGET_APIKEY_POWERSHELLGET_EXPERIMENTAL'
          Uri             = 'https://utat022:50000/nuget/powershellget-experimental/'
          NuGetV3Uri      = 'https://utat022:50000/nuget/powershellget-experimental/v3/index.json'
          Connectors      = @()
          RetentionPolicy = @{}
        }
      }
    }

    Mock Get-SecretATAP { 'unit-test-admin-key' }

    Mock Invoke-RestMethod {
      param($Uri, $Method, $Headers, $Body, $ContentType)
      if ($Method -eq 'Get' -and $Uri -like '*/api/management/feeds/list') {
        return @()
      }
      if ($Method -eq 'Post' -and $Uri -like '*/api/management/feeds/create') {
        return [PSCustomObject]@{ status = 'created' }
      }
      if ($Method -eq 'Post' -and $Uri -like '*/api/api-keys/create') {
        return [PSCustomObject]@{ key = 'must-not-escape' }
      }
      throw "Unexpected REST call: $Method $Uri"
    }
  }

  It 'skips an existing feed instead of posting create or API-key requests' {
    Mock Invoke-RestMethod {
      @([PSCustomObject]@{ name = 'releasebundle-experimental' })
    } -ParameterFilter { $Method -eq 'Get' -and $Uri -like '*/api/management/feeds/list' }

    $result = New-ProGetFeedSet -proGetBaseScheme 'http' -proGetBaseHost 'localhost' -proGetBasePort 50000 -FeedNameFilter 'releasebundle-*'

    $result.FeedName | Should -Be 'releasebundle-experimental'
    $result.Created | Should -BeFalse
    $result.SkippedExisting | Should -BeTrue
    Assert-MockCalled Invoke-RestMethod -Times 0 -Exactly -Scope It -ParameterFilter { $Method -eq 'Post' -and $Uri -like '*/api/management/feeds/create' }
    Assert-MockCalled Invoke-RestMethod -Times 0 -Exactly -Scope It -ParameterFilter { $Method -eq 'Post' -and $Uri -like '*/api/api-keys/create' }
  }

  It 'honors FeedNameFilter so non-matching existing feeds are untouched' {
    $result = New-ProGetFeedSet -proGetBaseScheme 'http' -proGetBaseHost 'localhost' -proGetBasePort 50000 -FeedNameFilter 'releasebundle-*'

    @($result).Count | Should -Be 1
    $result.FeedName | Should -Be 'releasebundle-experimental'
    Assert-MockCalled Invoke-RestMethod -Times 1 -Exactly -Scope It -ParameterFilter {
      $Method -eq 'Post' -and
      $Uri -like '*/api/management/feeds/create' -and
      ($Body | ConvertFrom-Json).name -eq 'releasebundle-experimental'
    }
  }

  It 'creates ReleaseBundle feeds as Universal feeds' {
    $script:capturedFeedCreateBody = $null
    Mock Invoke-RestMethod {
      param($Uri, $Method, $Headers, $Body, $ContentType)
      $script:capturedFeedCreateBody = $Body
      [PSCustomObject]@{ status = 'created' }
    } -ParameterFilter { $Method -eq 'Post' -and $Uri -like '*/api/management/feeds/create' }

    New-ProGetFeedSet -proGetBaseScheme 'http' -proGetBaseHost 'localhost' -proGetBasePort 50000 -FeedNameFilter 'releasebundle-experimental' | Out-Null

    ($script:capturedFeedCreateBody | ConvertFrom-Json).feedType | Should -Be 'universal'
  }

  It 'passes only the SecretName boundary and does not persist or return generated key values' {
    $result = New-ProGetFeedSet -proGetBaseScheme 'http' -proGetBaseHost 'localhost' -proGetBasePort 50000 -FeedNameFilter 'releasebundle-*' -ProGetApiKeySecretName 'Custom.Admin.Secret'

    Should -Invoke Get-SecretATAP -ParameterFilter { $SecretName -eq 'Custom.Admin.Secret' }
    ($result | ConvertTo-Json -Depth 8) | Should -Not -Match 'must-not-escape'
    [Environment]::GetEnvironmentVariable('PROGET_APIKEY_RELEASEBUNDLE_EXPERIMENTAL', 'User') | Should -BeNullOrEmpty
  }

  It 'performs no discovery, secret resolution, REST call, or mutation under WhatIf' {
    $result = New-ProGetFeedSet -proGetBaseScheme 'http' -proGetBaseHost 'localhost' -proGetBasePort 50000 -FeedNameFilter 'releasebundle-*' -WhatIf

    Should -Invoke Get-SecretATAP -Times 0
    Should -Invoke Invoke-RestMethod -Times 0
    @($result | Where-Object Created).Count | Should -Be 0
  }
}