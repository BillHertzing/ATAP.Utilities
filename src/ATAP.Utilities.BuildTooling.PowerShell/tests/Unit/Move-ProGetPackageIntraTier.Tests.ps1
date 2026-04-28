#Requires -Version 7.0
# Pester 5+ unit tests for Move-ProGetPackageIntraTier.
# Validates Phase 2 push->pull enforcement, integration tier support,
# legacy tier-name normalization (testing->qa, production->stable),
# same-feed Phase 1 mode (-ScanOnly), and the stub malware scan.
# AI assisted using Powershell.instructions.md as guidelines

BeforeAll {
    $publicDir         = Join-Path $PSScriptRoot '..\..\public' | Resolve-Path
    $script:scriptPath = Join-Path $publicDir 'Move-ProGetPackageIntraTier.ps1'

    if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
        function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
    }

    # Stub REST calls globally.
    function global:Invoke-RestMethod { param([Parameter(ValueFromRemainingArguments = $true)]$rest) return @{} }

    # Stub Get-PVal.
    function global:Get-PVal {
        param($ParameterName, $originalPSBoundParameters, $dottedPath, $DefaultValue)
        return $DefaultValue
    }

    # Dot-source the file to load the Move-ProGetPackageIntraTier function.
    . $script:scriptPath

    $script:baseUrl = 'http://proget.test:50000'
    $script:apiKey  = 'test-api-key'
}

Describe 'Move-ProGetPackageIntraTier' -Tag 'Unit' {

  Context 'Phase 2: valid push -> pull moves' {

    $cases = @(
      @{ Source = 'nuget-experimental-push'; Dest = 'nuget-experimental' }
      @{ Source = 'nuget-development-push'; Dest = 'nuget-development' }
      @{ Source = 'nuget-integration-push'; Dest = 'nuget-integration' }
      @{ Source = 'nuget-qa-push'; Dest = 'nuget-qa' }
      @{ Source = 'nuget-stable-push'; Dest = 'nuget-stable' }
      @{ Source = 'powershell-integration-push'; Dest = 'powershell-integration' }
    )

    It "Phase 2: '<Source>' -> '<Dest>' succeeds" -TestCases $cases {
      param($Source, $Dest)
      $result = Move-ProGetPackageIntraTier `
        -PackageName 'Test.Package' -Version '1.0.0' `
        -SourceFeed $Source -DestinationFeed $Dest `
        -ProGetBaseUrl $script:baseUrl -ApiKey $script:apiKey
      $result.Promoted | Should -BeTrue
      $result.ScanPassed | Should -BeTrue
      $result.SourceFeed | Should -Be $Source
      $result.DestinationFeed | Should -Be $Dest
    }
  }

  Context 'Phase 1: ScanOnly (same feed)' {

    It 'Returns Promoted=$false, ScanPassed=$true with -ScanOnly' {
      $result = Move-ProGetPackageIntraTier `
        -PackageName 'Test.Package' -Version '1.0.0' `
        -SourceFeed 'nuget-experimental' -DestinationFeed 'nuget-experimental' `
        -ScanOnly `
        -ProGetBaseUrl $script:baseUrl -ApiKey $script:apiKey
      $result.Promoted | Should -BeFalse
      $result.ScanPassed | Should -BeTrue
      $result.Reason | Should -Be 'ScanOnly mode'
    }

    It 'Returns Promoted=$false, ScanPassed=$true when source=dest (Phase 1 same-feed)' {
      $result = Move-ProGetPackageIntraTier `
        -PackageName 'Test.Package' -Version '1.0.0' `
        -SourceFeed 'nuget-experimental' -DestinationFeed 'nuget-experimental' `
        -ProGetBaseUrl $script:baseUrl -ApiKey $script:apiKey
      $result.Promoted | Should -BeFalse
      $result.Reason | Should -Be 'Same feed (Phase 1)'
    }
  }

  Context 'Legacy tier alias normalization — validation accepts normalized names' {

    It 'Accepts source=nuget-testing-push and dest=nuget-testing (normalized to qa)' {
      # Both normalize to qa, same tier, push->pull: valid
      $result = Move-ProGetPackageIntraTier `
        -PackageName 'Test.Package' -Version '1.0.0' `
        -SourceFeed 'nuget-testing-push' -DestinationFeed 'nuget-testing' `
        -ProGetBaseUrl $script:baseUrl -ApiKey $script:apiKey
      $result.Promoted | Should -BeTrue
    }

    It 'Accepts source=nuget-production-push and dest=nuget-production (normalized to stable)' {
      $result = Move-ProGetPackageIntraTier `
        -PackageName 'Test.Package' -Version '1.0.0' `
        -SourceFeed 'nuget-production-push' -DestinationFeed 'nuget-production' `
        -ProGetBaseUrl $script:baseUrl -ApiKey $script:apiKey
      $result.Promoted | Should -BeTrue
    }
  }

  Context 'Phase 2 validation: mismatched tiers' {

    It 'Throws when source and destination belong to different tiers' {
      { Move-ProGetPackageIntraTier `
          -PackageName 'Test.Package' -Version '1.0.0' `
          -SourceFeed 'nuget-experimental-push' -DestinationFeed 'nuget-development' `
          -ProGetBaseUrl $script:baseUrl -ApiKey $script:apiKey
      } | Should -Throw -ExpectedMessage '*same tier*'
    }
  }

  Context 'Phase 2 validation: source must be push feed' {

    It 'Throws when source is a pull feed in Phase 2 mode' {
      { Move-ProGetPackageIntraTier `
          -PackageName 'Test.Package' -Version '1.0.0' `
          -SourceFeed 'nuget-development' -DestinationFeed 'nuget-development' `
          -ProGetBaseUrl $script:baseUrl -ApiKey $script:apiKey
      } | Should -Throw -ExpectedMessage '*push feed*'
    }
  }

  Context 'Phase 2 validation: destination must be pull feed' {

    It 'Throws when destination is a push feed in Phase 2 mode' {
      { Move-ProGetPackageIntraTier `
          -PackageName 'Test.Package' -Version '1.0.0' `
          -SourceFeed 'nuget-development-push' -DestinationFeed 'nuget-development-push' `
          -ProGetBaseUrl $script:baseUrl -ApiKey $script:apiKey
      } | Should -Throw -ExpectedMessage '*pull feed*'
    }
  }

  Context 'Phase 2 validation: package type prefix must match' {

    It 'Throws when source is nuget and destination is powershell' {
      { Move-ProGetPackageIntraTier `
          -PackageName 'Test.Package' -Version '1.0.0' `
          -SourceFeed 'nuget-development-push' -DestinationFeed 'powershell-development' `
          -ProGetBaseUrl $script:baseUrl -ApiKey $script:apiKey
      } | Should -Throw -ExpectedMessage '*package type*'
    }
  }

  Context 'Unknown tier name' {

    It 'Throws on an unknown tier in SourceFeed' {
      { Move-ProGetPackageIntraTier `
          -PackageName 'Test.Package' -Version '1.0.0' `
          -SourceFeed 'nuget-staging-push' -DestinationFeed 'nuget-staging' `
          -ProGetBaseUrl $script:baseUrl -ApiKey $script:apiKey
      } | Should -Throw -ExpectedMessage '*tiers must be one of*'
    }
  }

  Context 'Output object shape' {

    It 'Returns PSCustomObject with expected properties' {
      $result = Move-ProGetPackageIntraTier `
        -PackageName 'Test.Package' -Version '2.0.0' `
        -SourceFeed 'nuget-integration-push' -DestinationFeed 'nuget-integration' `
        -ProGetBaseUrl $script:baseUrl -ApiKey $script:apiKey
      $result.PSObject.Properties.Name | Should -Contain 'ScanPassed'
      $result.PSObject.Properties.Name | Should -Contain 'Promoted'
      $result.PSObject.Properties.Name | Should -Contain 'Reason'
      $result.PackageName | Should -Be 'Test.Package'
      $result.Version | Should -Be '2.0.0'
    }
  }
}
