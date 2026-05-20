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

  $script:oldConfigRootKeys = $global:configRootKeys
  $script:oldSettings = $global:Settings
  $script:savedAdminApiKey = [Environment]::GetEnvironmentVariable('PROGET_ADMIN_API_KEY', 'Process')
  $script:savedReleaseBundleApiKey = [Environment]::GetEnvironmentVariable('PROGET_APIKEY_RELEASEBUNDLE_EXPERIMENTAL', 'User')
}

AfterAll {
  $global:configRootKeys = $script:oldConfigRootKeys
  $global:Settings = $script:oldSettings
  [Environment]::SetEnvironmentVariable('PROGET_ADMIN_API_KEY', $script:savedAdminApiKey, 'Process')
  [Environment]::SetEnvironmentVariable('PROGET_APIKEY_RELEASEBUNDLE_EXPERIMENTAL', $script:savedReleaseBundleApiKey, 'User')
  Remove-Item Function:\Write-PSFMessage -ErrorAction SilentlyContinue
}

Describe 'New-ProGetFeedSet' -Tag 'Unit' {

  BeforeEach {
    Mock Write-PSFMessage { }

    $global:configRootKeys = @{
      ProGetAdminUriSchemeConfigRootKey = 'PROGET_ADMIN_URI_SCHEME'
      ProGetAdminUriHostConfigRootKey   = 'PROGET_ADMIN_URI_HOST'
      ProGetAdminUriPortConfigRootKey   = 'PROGET_ADMIN_URI_PORT'
      ProGetAdminApiKeyConfigRootKey    = 'PROGET_ADMIN_API_KEY'
      ProGetFeedCollectionConfigRootKey = 'ProGetFeedCollection'
    }
    $global:Settings = @{
      ProGetFeedCollection = [ordered]@{
        ReleaseBundleExperimental = @{
          FeedName        = 'releasebundle-experimental'
          FeedType        = 'universal'
          Tier            = 'experimental'
          ApiKeyName      = 'PROGET_APIKEY_RELEASEBUNDLE_EXPERIMENTAL'
          Uri             = 'http://localhost:50000/upack/releasebundle-experimental/'
          NuGetV3Uri      = $null
          Connectors      = @()
          RetentionPolicy = @{}
        }
        PowershellGetExperimental = @{
          FeedName        = 'powershellget-experimental'
          FeedType        = 'powershellget'
          Tier            = 'experimental'
          ApiKeyName      = 'PROGET_APIKEY_POWERSHELLGET_EXPERIMENTAL'
          Uri             = 'http://localhost:50000/nuget/powershellget-experimental/'
          NuGetV3Uri      = 'http://localhost:50000/nuget/powershellget-experimental/v3/index.json'
          Connectors      = @()
          RetentionPolicy = @{}
        }
      }
    }

    [Environment]::SetEnvironmentVariable('PROGET_ADMIN_API_KEY', 'admin-key', 'Process')
    [Environment]::SetEnvironmentVariable('PROGET_APIKEY_RELEASEBUNDLE_EXPERIMENTAL', $null, 'User')

    Mock Invoke-RestMethod {
      param($Uri, $Method, $Headers, $Body, $ContentType)
      if ($Method -eq 'Get' -and $Uri -like '*/api/management/feeds/list') {
        return @()
      }
      if ($Method -eq 'Post' -and $Uri -like '*/api/management/feeds/create') {
        return [PSCustomObject]@{ status = 'created' }
      }
      if ($Method -eq 'Post' -and $Uri -like '*/api/api-keys/create') {
        return [PSCustomObject]@{ key = 'feed-key' }
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
}
