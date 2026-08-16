#Requires -Version 7.0
# Pester 5+ unit tests for ConvertTo-ProGetFeedNameAlternateForm.
# Covers the 5-tier expansion added in Area 2B (Integration/Intg support).
# AI assisted using Powershell.instructions.md as guidelines

BeforeAll {
  $privateDir = Join-Path $PSScriptRoot '..\..\private' | Resolve-Path

  # Dot-source the dependencies first.
  . (Join-Path $privateDir 'Build-ProGetFeedEndpointURL.ps1')
  . (Join-Path $privateDir 'Convert-ProgetFeedType.ps1')
  . (Join-Path $PSScriptRoot '..\..\public\Resolve-ProGetFeedFromSettings.ps1')
  . (Join-Path $PSScriptRoot '..\..\public\ConvertTo-ProGetFeedNameAlternateForm.ps1')

  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
  }

  $script:hadSettings = Test-Path Variable:\global:Settings
  $script:hadConfigRootKeys = Test-Path Variable:\global:configRootKeys
  $script:originalSettings = $global:Settings
  $script:originalConfigRootKeys = $global:configRootKeys
}

AfterAll {
  if ($script:hadSettings) {
    $global:Settings = $script:originalSettings
  } else {
    Remove-Variable -Name Settings -Scope Global -ErrorAction SilentlyContinue
  }

  if ($script:hadConfigRootKeys) {
    $global:configRootKeys = $script:originalConfigRootKeys
  } else {
    Remove-Variable -Name configRootKeys -Scope Global -ErrorAction SilentlyContinue
  }
}

Describe 'ConvertTo-ProGetFeedNameAlternateForm' -Tag 'Unit' {
  BeforeEach {
    Mock Write-PSFMessage { }
  }

  Context 'FromIndividual — 4-tier legacy values still work' {

    $cases = @(
      @{EI = 'Internal'; V = 'Released'; P = 'NuGet'; PQ = 'Production'; PP = 'Pull'; Expected = 'IntRelNugProdPull' }
      @{EI = 'Internal'; V = 'Released'; P = 'NuGet'; PQ = 'QualityAssurance'; PP = 'Pull'; Expected = 'IntRelNugQAPull' }
      @{EI = 'External'; V = 'Prerelease'; P = 'PSResourceGet'; PQ = 'Production'; PP = 'Push'; Expected = 'ExtPrePSRProdPush' }
    )

    It "Converts EI=<EI> V=<V> P=<P> PQ=<PQ> PP=<PP> to '<Expected>'" -TestCases $cases {
      param($EI, $V, $P, $PQ, $PP, $Expected)
      $result = ConvertTo-ProGetFeedNameAlternateForm -ExternalInternal $EI -ReleasedPrerelease $V -PackageType $P -ProductionQualityAssurance $PQ -PullPush $PP
      $result | Should -Be $Expected
    }
  }

  Context 'FromIndividual — new Integration tier' {

    $cases = @(
      @{EI = 'Internal'; V = 'Released'; P = 'NuGet'; PQ = 'Integration'; PP = 'Pull'; Expected = 'IntRelNugIntgPull' }
      @{EI = 'Internal'; V = 'Released'; P = 'NuGet'; PQ = 'Integration'; PP = 'Push'; Expected = 'IntRelNugIntgPush' }
      @{EI = 'Internal'; V = 'Prerelease'; P = 'PSResourceGet'; PQ = 'Integration'; PP = 'Pull'; Expected = 'IntPrePSRIntgPull' }
      @{EI = 'External'; V = 'Released'; P = 'ChocolateyGet'; PQ = 'Integration'; PP = 'Push'; Expected = 'ExtRelChoIntgPush' }
    )

    It "Integration: EI=<EI> V=<V> P=<P> PP=<PP> produces '<Expected>'" -TestCases $cases {
      param($EI, $V, $P, $PQ, $PP, $Expected)
      $result = ConvertTo-ProGetFeedNameAlternateForm -ExternalInternal $EI -ReleasedPrerelease $V -PackageType $P -ProductionQualityAssurance $PQ -PullPush $PP
      $result | Should -Be $Expected
    }
  }

  Context 'FromShort — round-trip for Integration short form' {

    $cases = @(
      @{Short = 'IntRelNugIntgPull'; ExpectedPQ = 'Integration'; ExpectedPP = 'Pull' }
      @{Short = 'IntRelNugIntgPush'; ExpectedPQ = 'Integration'; ExpectedPP = 'Push' }
    )

    It "Round-trips short name '<Short>' back to full objects" -TestCases $cases {
      param($Short, $ExpectedPQ, $ExpectedPP)
      $result = ConvertTo-ProGetFeedNameAlternateForm -ShortName $Short
      $result.ProductionQualityAssurance | Should -Be $ExpectedPQ
      $result.PullPush | Should -Be $ExpectedPP
    }
  }

  Context 'LongName — regex accepts Integration' {

    $cases = @(
      @{LongName = 'PackageRepositoryInternalReleasedNuGetIntegrationPullFeed'; ExpectedPQ = 'Integration' }
      @{LongName = 'PackageRepositoryInternalReleasedNuGetIntegrationPushFeed'; ExpectedPQ = 'Integration' }
      @{LongName = 'PackageRepositoryExternalPrereleaseNuGetProductionPullFeed'; ExpectedPQ = 'Production' }
      @{LongName = 'PackageRepositoryInternalReleasedNuGetQualityAssurancePullFeed'; ExpectedPQ = 'QualityAssurance' }
    )

    It "Parses long name '<LongName>' with PQ='<ExpectedPQ>'" -TestCases $cases {
      param($LongName, $ExpectedPQ)
      $result = ConvertTo-ProGetFeedNameAlternateForm -LongName $LongName
      $result.ProductionQualityAssurance | Should -Be $ExpectedPQ
    }
  }

  Context 'Error cases' {

    It 'Throws on invalid ProductionQualityAssurance value' {
      { ConvertTo-ProGetFeedNameAlternateForm -ExternalInternal Internal -ReleasedPrerelease Released -PackageType NuGet -ProductionQualityAssurance Testing -PullPush Pull } |
        Should -Throw -ExpectedMessage '*Invalid ProductionQualityAssurance*'
    }

    It 'Throws on short name that is too short' {
      { ConvertTo-ProGetFeedNameAlternateForm -ShortName 'Short' } |
        Should -Throw
    }

    It 'Throws on LongName that does not match pattern' {
      { ConvertTo-ProGetFeedNameAlternateForm -LongName 'PackageRepositoryBadFormat' } |
        Should -Throw
    }
  }
}

Describe 'ProGet feed helpers and settings resolution' -Tag 'Unit' {
  BeforeEach {
    Mock Write-PSFMessage { }
  }

  Context 'Feed type conversion' {
    $cases = @(
      @{ FeedType = 'NuGet'; Expected = 'nuget' }
      @{ FeedType = 'ChocolateyGet'; Expected = 'chocolatey' }
      @{ FeedType = 'PSResourceGet'; Expected = 'powershell' }
      @{ FeedType = 'UPack'; Expected = 'universal' }
    )

    It "Converts '<FeedType>' to '<Expected>'" -TestCases $cases {
      param($FeedType, $Expected)
      Convert-ProGetFeedType -FeedType $FeedType | Should -BeExactly $Expected
    }

    It 'Rejects an unknown feed type' {
      { Convert-ProGetFeedType -FeedType 'Container' } | Should -Throw -ExpectedMessage '*Unknown feed type*'
    }
  }

  Context 'Endpoint URL construction' {
    It 'Builds a NuGet endpoint URL from explicit components' {
      Build-ProGetFeedEndpointURL -Scheme https -HostName proget.example.test -Port 443 -Page 'nuget/powershellget-stable/index.json' |
        Should -BeExactly 'https://proget.example.test:443/nuget/powershellget-stable/index.json'
    }

    It 'Rejects an unsupported page feed type' {
      { Build-ProGetFeedEndpointURL -Scheme https -HostName proget.example.test -Port 443 -Page 'container/images' } |
        Should -Throw -ExpectedMessage '*Unknown feed type*'
    }
  }

  Context 'Settings-backed feed resolution' {
    BeforeEach {
      $global:configRootKeys = @{
        ProGetFeedCollectionConfigRootKey = 'ProGetFeeds'
        ProGetBaseUrlConfigRootKey        = 'ProGetBaseUrl'
      }
      $global:Settings = @{
        ProGetBaseUrl = 'https://proget.example.test/'
        ProGetFeeds   = [ordered]@{
          PowerShellStable = [PSCustomObject]@{
            FeedName        = 'powershellget-stable'
            FeedType        = 'powershellget'
            Tier            = 'stable'
            Uri             = [Uri]'https://proget.example.test/nuget/powershellget-stable/'
            NuGetV3Uri      = 'https://proget.example.test/nuget/powershellget-stable/index.json'
            ApiKeyName      = 'ProGet.ApiKey'
            Connectors      = @('PowerShellGallery')
            RetentionPolicy = 'Stable'
          }
        }
      }
    }

    It 'Resolves aliases to the canonical feed entry and prefers its NuGet v3 endpoint' {
      $result = Resolve-ProGetFeedFromSettings -FeedType PowerShell -Tier Production

      $result.FeedName | Should -BeExactly 'powershellget-stable'
      $result.FeedType | Should -BeExactly 'powershellget'
      $result.Tier | Should -BeExactly 'stable'
      $result.EndpointUri | Should -BeExactly 'https://proget.example.test/nuget/powershellget-stable/index.json'
      $result.ApiKeyName | Should -BeExactly 'ProGet.ApiKey'
    }

    It 'Resolves and trims the configured ProGet base URL' {
      Resolve-ProGetBaseUrlFromSettings | Should -BeExactly 'https://proget.example.test'
    }

    It 'Supports dictionary feed entries and falls back to Uri when NuGetV3Uri is absent' {
      $global:Settings.ProGetFeeds = [ordered]@{
        NuGetStable = @{
          FeedName        = 'nuget-stable'
          FeedType        = 'nuget'
          Tier            = 'production'
          Uri             = [Uri]'https://proget.example.test/nuget/nuget-stable/'
          NuGetV3Uri      = ''
          ApiKeyName      = 'ProGet.ApiKey'
          Connectors      = @()
          RetentionPolicy = 'Stable'
        }
      }

      $result = Resolve-ProGetFeedFromSettings -FeedType NuGet -Tier Stable

      $result.FeedName | Should -BeExactly 'nuget-stable'
      $result.EndpointUri | Should -BeExactly 'https://proget.example.test/nuget/nuget-stable/'
    }

    It 'Distinguishes NuGet and database feed families that share the NuGet transport type' {
      $global:Settings.ProGetFeeds = [ordered]@{
        DatabaseExperimental = [PSCustomObject]@{
          FeedName = 'database-experimental'
          FeedType = 'nuget'
          Tier = 'experimental'
          NuGetV3Uri = 'https://proget.example.test/nuget/database-experimental/v3/index.json'
        }
        NuGetExperimental = [PSCustomObject]@{
          FeedName = 'nuget-experimental'
          FeedType = 'nuget'
          Tier = 'experimental'
          NuGetV3Uri = 'https://proget.example.test/nuget/nuget-experimental/v3/index.json'
        }
      }

      (Resolve-ProGetFeedFromSettings -FeedType NuGet -Tier Experimental).FeedName |
        Should -BeExactly 'nuget-experimental'
      (Resolve-ProGetFeedFromSettings -FeedType Database -Tier Experimental).FeedName |
        Should -BeExactly 'database-experimental'
    }
    It 'Builds the ProGet base URL from scheme, host, and port settings as a fallback' {
      $global:configRootKeys.ProGetAdminUriSchemeConfigRootKey = 'ProGetScheme'
      $global:configRootKeys.ProGetAdminUriHostConfigRootKey = 'ProGetHost'
      $global:configRootKeys.ProGetAdminUriPortConfigRootKey = 'ProGetPort'
      $global:Settings.ProGetBaseUrl = ''
      $global:Settings.ProGetScheme = 'https'
      $global:Settings.ProGetHost = 'proget.example.test'
      $global:Settings.ProGetPort = 8443

      Resolve-ProGetBaseUrlFromSettings | Should -BeExactly 'https://proget.example.test:8443'
    }

    It 'Rejects an unknown tier before searching settings' {
      { Resolve-ProGetFeedFromSettings -FeedType PowerShell -Tier Canary } |
        Should -Throw -ExpectedMessage '*Unknown ProGet tier*'
    }

    It 'Throws clearly when no matching feed exists' {
      { Resolve-ProGetFeedFromSettings -FeedType NuGet -Tier Production } |
        Should -Throw -ExpectedMessage '*No ProGet feed entry found*'
    }

    It 'Throws clearly when host settings are not initialized' {
      $global:Settings = $null
      { Get-ProGetFeedCollectionFromSettings } |
        Should -Throw -ExpectedMessage '*Settings is not initialized*'
    }
  }
}
