# Requires -Version 7.0
# Pester 5+ tests for Publish-PSModuleToProGetFeed (task T-19).
# All external I/O, secret stores, and PSResourceGet cmdlets are mocked.

BeforeAll {
  # Dot-source the function under test.
  $publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
  . (Join-Path $publicDir 'Resolve-ProGetFeedFromSettings.ps1')
  . (Join-Path $publicDir 'Test-PSModulePackageSignature.ps1')
  . (Join-Path $publicDir 'Publish-PSModuleToProGetFeed.ps1')

  # Suppress PSFramework noise in tests.
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
  }

  # Ensure stand-in definitions exist for PSResourceGet cmdlets so Mock can replace them.
  foreach ($cmd in @('Get-PSResourceRepository', 'Register-PSResourceRepository', 'Set-PSResourceRepository', 'Publish-PSResource')) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
      $scriptBody = "function global:$cmd { param([Parameter(ValueFromRemainingArguments=`$true)]`$args) }"
      Invoke-Expression $scriptBody
    }
  }

  # Create a fake .nupkg file we can point the cmdlet at.
  $script:tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('PubPSModTest_' + [Guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $script:tempRoot -Force | Out-Null
  $script:fakeNupkg = Join-Path $script:tempRoot 'FakeModule.1.0.0.nupkg'
  Set-Content -LiteralPath $script:fakeNupkg -Value 'not a real nupkg' -Encoding Ascii

  $script:oldConfigRootKeys = $global:configRootKeys
  $script:oldSettings = $global:Settings
  $script:savedAdminApiKey = [Environment]::GetEnvironmentVariable('PROGET_ADMIN_API_KEY', 'User')
  [Environment]::SetEnvironmentVariable('PROGET_ADMIN_API_KEY', $null, 'User')
  $global:configRootKeys = @{
    # SC-0288 / Task 13.66.b: SecretName host suffixes come from the placement map.
    ServicePlacementMapConfigRootKey = 'ServicePlacementMap'
    ProGetFeedCollectionConfigRootKey = 'ProGetFeedCollection'
  }
  $global:Settings = @{
    ServicePlacementMap = @{ ProGet = 'utat022'; BuildMaster = 'utat022' }
    ProGetFeedCollection = @{
      ProGetFeedPowerShellExperimental = @{
        FeedName   = 'powershellget-experimental'
        FeedType   = 'powershellget'
        Tier       = 'experimental'
        NuGetV3Uri = 'https://proget.example.test/nuget/powershellget-experimental/v2'
        ApiKeyName = 'PROGET_APIKEY_POWERSHELLGET_EXPERIMENTAL'
      }
      ProGetFeedPowerShellDevelopment = @{
        FeedName   = 'powershellget-development'
        FeedType   = 'powershellget'
        Tier       = 'development'
        NuGetV3Uri = 'https://proget.example.test/nuget/powershellget-development/v2'
        ApiKeyName = 'PROGET_APIKEY_POWERSHELLGET_DEVELOPMENT'
      }
      ProGetFeedPowerShellIntegration = @{
        FeedName   = 'powershellget-integration'
        FeedType   = 'powershellget'
        Tier       = 'integration'
        NuGetV3Uri = 'https://proget.example.test/nuget/powershellget-integration/v2'
        ApiKeyName = 'PROGET_APIKEY_POWERSHELLGET_INTEGRATION'
      }
      ProGetFeedPowerShellQA = @{
        FeedName   = 'powershellget-qa'
        FeedType   = 'powershellget'
        Tier       = 'qa'
        NuGetV3Uri = 'https://proget.example.test/nuget/powershellget-qa/v2'
        ApiKeyName = 'PROGET_APIKEY_POWERSHELLGET_QA'
      }
      ProGetFeedPowerShellStable = @{
        FeedName   = 'powershellget-stable'
        FeedType   = 'powershellget'
        Tier       = 'stable'
        NuGetV3Uri = 'https://proget.example.test/nuget/powershellget-stable/v2'
        ApiKeyName = 'PROGET_APIKEY_POWERSHELLGET_STABLE'
      }
    }
  }
}

AfterAll {
  if ($script:tempRoot -and (Test-Path -LiteralPath $script:tempRoot)) {
    Remove-Item -LiteralPath $script:tempRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
  $global:configRootKeys = $script:oldConfigRootKeys
  $global:Settings = $script:oldSettings
  [Environment]::SetEnvironmentVariable('PROGET_ADMIN_API_KEY', $script:savedAdminApiKey, 'User')
}

Describe 'Publish-PSModuleToProGetFeed' {

  BeforeEach {
    Mock Test-PSModulePackageSignature { [PSCustomObject]@{ Valid = $true } }
    Mock Get-PSResourceRepository { $null }
    Mock Register-PSResourceRepository { }
    Mock Set-PSResourceRepository { }
    Mock Publish-PSResource { [PSCustomObject]@{ Status = 'OK' } }
  }

  Context 'Tier-to-feed mapping' {
    $tierCases = @(
      @{ Tier = 'Experimental'; Expected = 'powershellget-experimental' }
      @{ Tier = 'Development'; Expected = 'powershellget-development' }
      @{ Tier = 'Integration'; Expected = 'powershellget-integration' }
      @{ Tier = 'QA'; Expected = 'powershellget-qa' }
      @{ Tier = 'Production'; Expected = 'powershellget-stable' }
      @{ Tier = 'Sprint'; Expected = 'powershellget-experimental' }
      @{ Tier = 'Alpha'; Expected = 'powershellget-development' }
      @{ Tier = 'Beta'; Expected = 'powershellget-integration' }
    )

    It "Resolves tier '<Tier>' to feed name '<Expected>'" -TestCases $tierCases {
      param($Tier, $Expected)

      # Inject API key via Bitwarden helper override (function-scope; visible through Get-Command).
      function global:Get-SecretATAP { [CmdletBinding()] param([string]$SecretName, [string]$SecretStoreType) return 'dummy-key' }
      try {
        $result = Publish-PSModuleToProGetFeed -NupkgPath $script:fakeNupkg -Tier $Tier
        $result.FeedName | Should -Be $Expected
        $result.Published | Should -BeTrue
        Assert-MockCalled Publish-PSResource -Times 1 -Exactly -Scope It
      } finally {
        Remove-Item Function:\Get-SecretATAP -ErrorAction SilentlyContinue
      }
    }
  }

  Context 'API key sourcing' {
    It 'Uses Get-SecretATAP when available' {
      $script:bwCalls = 0
      function global:Get-SecretATAP {
        [CmdletBinding()]
        param([string]$SecretName, [string]$SecretStoreType)
        $script:bwCalls++
        return 'bw-secret-value'
      }
      try {
        $result = Publish-PSModuleToProGetFeed -NupkgPath $script:fakeNupkg -Tier Alpha
        $result.Published | Should -BeTrue
        $script:bwCalls | Should -BeGreaterOrEqual 1
      } finally {
        Remove-Item Function:\Get-SecretATAP -ErrorAction SilentlyContinue
      }
    }

    It 'Does not fall back to an environment variable when secret resolution fails' {
      $envName = 'PROGET_APIKEY_POWERSHELLGET_INTEGRATION'
      [Environment]::SetEnvironmentVariable($envName, 'env-api-key', 'User')
      function global:Get-SecretATAP { [CmdletBinding()] param([string]$SecretName, [string]$SecretStoreType) throw 'secret unavailable' }
      try {
        { Publish-PSModuleToProGetFeed -NupkgPath $script:fakeNupkg -Tier Beta } |
          Should -Throw -ExpectedMessage '*ProGet.BuildMaster.API.Key*'
      } finally {
        [Environment]::SetEnvironmentVariable($envName, $null, 'User')
        Remove-Item Function:\Get-SecretATAP -ErrorAction SilentlyContinue
      }
    }

    It 'Fails closed when the named secret resolves empty' {
      function global:Get-SecretATAP { [CmdletBinding()] param([string]$SecretName, [string]$SecretStoreType) return '' }
      try {
        { Publish-PSModuleToProGetFeed -NupkgPath $script:fakeNupkg -Tier QA } |
          Should -Throw -ExpectedMessage '*resolved to an empty value*'
      } finally {
        Remove-Item Function:\Get-SecretATAP -ErrorAction SilentlyContinue
      }
    }
  }

  Context 'Signature gate' {
    It 'verifies the package before publishing' {
      function global:Get-SecretATAP { [CmdletBinding()] param([string]$SecretName, [string]$SecretStoreType) return 'dummy' }
      try {
        $result = Publish-PSModuleToProGetFeed -NupkgPath $script:fakeNupkg -Tier Alpha
        $result.SignatureVerified | Should -BeTrue
        Assert-MockCalled Test-PSModulePackageSignature -Times 1 -Exactly -Scope It -ParameterFilter { $RequireTimestamp }
      } finally {
        Remove-Item Function:\Get-SecretATAP -ErrorAction SilentlyContinue
      }
    }

    It 'rejects an unsigned package before secret lookup or publish' {
      Mock Test-PSModulePackageSignature { throw 'unsigned package' }
      function global:Get-SecretATAP { throw 'must not be called' }
      try {
        { Publish-PSModuleToProGetFeed -NupkgPath $script:fakeNupkg -Tier Alpha } | Should -Throw '*unsigned package*'
        Assert-MockCalled Publish-PSResource -Times 0 -Exactly -Scope It
      } finally {
        Remove-Item Function:\Get-SecretATAP -ErrorAction SilentlyContinue
      }
    }
  }

  Context 'WhatIf short-circuit' {
    It 'Performs no secret lookup, repository mutation, or publish under -WhatIf' {
      Mock Get-SecretATAP { throw 'must not be called' }
      try {
        $result = Publish-PSModuleToProGetFeed -NupkgPath $script:fakeNupkg -Tier Sprint -WhatIf
        $result.Published | Should -BeFalse
        $result.FeedName | Should -Be 'powershellget-experimental'
        $result.ResponseSummary | Should -Match 'WhatIf'
        Assert-MockCalled Publish-PSResource -Times 0 -Exactly -Scope It
        Assert-MockCalled Get-SecretATAP -Times 0 -Exactly -Scope It
        Assert-MockCalled Get-PSResourceRepository -Times 0 -Exactly -Scope It
        Assert-MockCalled Register-PSResourceRepository -Times 0 -Exactly -Scope It
        Assert-MockCalled Set-PSResourceRepository -Times 0 -Exactly -Scope It
      } finally {
        Remove-Item Function:\Get-SecretATAP -ErrorAction SilentlyContinue
      }
    }
  }

  Context 'PSResourceRepository registration' {
    It 'Registers the repository when missing' {
      function global:Get-SecretATAP { [CmdletBinding()] param([string]$SecretName, [string]$SecretStoreType) return 'dummy' }
      Mock Get-PSResourceRepository { $null }
      try {
        Publish-PSModuleToProGetFeed -NupkgPath $script:fakeNupkg -Tier Alpha | Out-Null
        Assert-MockCalled Register-PSResourceRepository -Times 1 -Exactly -Scope It
        Assert-MockCalled Set-PSResourceRepository -Times 0 -Exactly -Scope It
      } finally {
        Remove-Item Function:\Get-SecretATAP -ErrorAction SilentlyContinue
      }
    }

    It 'Updates the repository when URI differs' {
      function global:Get-SecretATAP { [CmdletBinding()] param([string]$SecretName, [string]$SecretStoreType) return 'dummy' }
      Mock Get-PSResourceRepository { [PSCustomObject]@{ Name = 'powershellget-development'; Uri = 'https://old.example/' } }
      try {
        Publish-PSModuleToProGetFeed -NupkgPath $script:fakeNupkg -Tier Alpha | Out-Null
        Assert-MockCalled Set-PSResourceRepository -Times 1 -Exactly -Scope It
        Assert-MockCalled Register-PSResourceRepository -Times 0 -Exactly -Scope It
      } finally {
        Remove-Item Function:\Get-SecretATAP -ErrorAction SilentlyContinue
      }
    }
  }

  Context 'Validation' {
    It 'Throws when NupkgPath does not exist' {
      function global:Get-SecretATAP { [CmdletBinding()] param([string]$SecretName, [string]$SecretStoreType) return 'dummy' }
      try {
        { Publish-PSModuleToProGetFeed -NupkgPath 'C:/does/not/exist.nupkg' -Tier Alpha } |
          Should -Throw -ExpectedMessage '*does not exist*'
      } finally {
        Remove-Item Function:\Get-SecretATAP -ErrorAction SilentlyContinue
      }
    }

    It 'Throws when NupkgPath is not a .nupkg' {
      function global:Get-SecretATAP { [CmdletBinding()] param([string]$SecretName, [string]$SecretStoreType) return 'dummy' }
      $wrongExt = Join-Path $script:tempRoot 'NotANupkg.zip'
      Set-Content -LiteralPath $wrongExt -Value 'x' -Encoding Ascii
      try {
        { Publish-PSModuleToProGetFeed -NupkgPath $wrongExt -Tier Alpha } |
          Should -Throw -ExpectedMessage '*.nupkg extension*'
      } finally {
        Remove-Item Function:\Get-SecretATAP -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $wrongExt -Force -ErrorAction SilentlyContinue
      }
    }
  }
}
