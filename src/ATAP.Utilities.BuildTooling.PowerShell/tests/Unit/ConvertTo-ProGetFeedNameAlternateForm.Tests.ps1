#Requires -Version 7.0
# Pester 5+ unit tests for ConvertTo-ProGetFeedNameAlternateForm.
# Covers the 5-tier expansion added in Area 2B (Integration/Intg support).
# AI assisted using Powershell.instructions.md as guidelines

BeforeAll {
  $privateDir = Join-Path $PSScriptRoot '..\..\private' | Resolve-Path

  # Dot-source the dependencies first.
  . (Join-Path $privateDir 'Convert-ProgetFeedType.ps1')
  . (Join-Path $privateDir 'ConvertTo-ProGetFeedNameAlternateForm.ps1')

  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
  }
}

Describe 'ConvertTo-ProGetFeedNameAlternateForm' -Tag 'Unit' {

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
