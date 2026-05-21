#Requires -Version 7.0
# Pester 5+ unit tests for Move-ProGetPackageInterTier.
# All ProGet REST calls are mocked. Validates tier ordering, legacy alias
# normalization (testing->qa, production->stable), and 5-tier auto-routing.
# AI assisted using Powershell.instructions.md as guidelines

BeforeAll {
    $publicDir      = Join-Path $PSScriptRoot '..\..\public' | Resolve-Path
    $script:scriptPath = Join-Path $publicDir 'Move-ProGetPackageInterTier.ps1'

    if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
        function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
    }

    $script:hadGlobalGetPValFunction = Test-Path -Path 'Function:\global:Get-PVal'
    $script:originalGlobalGetPValFunction = if ($script:hadGlobalGetPValFunction) {
        (Get-Item -Path 'Function:\global:Get-PVal').ScriptBlock
    } else {
        $null
    }

    # Stub Get-PVal to pass through values unchanged.
    function global:Get-PVal {
        param($ParameterName, $originalPSBoundParameters, $dottedPath, $DefaultValue)
        return $DefaultValue
    }

    # Dot-source the autoloaded function for testing.
    . $script:scriptPath

    $script:baseUrl = 'http://proget.test:50000'
    $script:apiKey = 'test-api-key'
}

AfterAll {
    if ($script:hadGlobalGetPValFunction) {
        Set-Item -Path 'Function:\global:Get-PVal' -Value $script:originalGlobalGetPValFunction
    } else {
        Remove-Item -Path 'Function:\global:Get-PVal' -ErrorAction SilentlyContinue
    }
}

Describe 'Move-ProGetPackageInterTier' -Tag 'Unit' {
  BeforeEach {
    Mock Write-PSFMessage { }
    Mock Invoke-RestMethod { @{} }
  }

  Context 'Auto-destination: Phase 1 (combined feeds)' {

    $cases = @(
      @{ Source = 'nuget-experimental'; ExpectedDest = 'nuget-development' }
      @{ Source = 'nuget-development'; ExpectedDest = 'nuget-integration' }
      @{ Source = 'nuget-integration'; ExpectedDest = 'nuget-qa' }
      @{ Source = 'nuget-qa'; ExpectedDest = 'nuget-stable' }
      @{ Source = 'powershellget-experimental'; ExpectedDest = 'powershellget-development' }
      @{ Source = 'powershellget-integration'; ExpectedDest = 'powershellget-qa' }
      @{ Source = 'chocolatey-qa'; ExpectedDest = 'chocolatey-stable' }
    )

    It "Routes '<Source>' -> '<ExpectedDest>' (Phase 1)" -TestCases $cases {
      param($Source, $ExpectedDest)
      $result = Move-ProGetPackageInterTier `
        -Name 'Test.Package' -Version '1.0.0' `
        -FromFeed $Source `
        -ProGetBaseUrl $script:baseUrl -ApiKey $script:apiKey
      $result.DestinationFeed | Should -Be $ExpectedDest
      $result.Promoted | Should -BeTrue
    }
  }

  Context 'Auto-destination: Phase 2 (push feeds)' {

    $cases = @(
      @{ Source = 'nuget-experimental'; ExpectedDest = 'nuget-development-push' }
      @{ Source = 'nuget-integration'; ExpectedDest = 'nuget-qa-push' }
    )

    It "Routes '<Source>' -> '<ExpectedDest>' (Phase 2 / -UsePushFeed)" -TestCases $cases {
      param($Source, $ExpectedDest)
      $result = Move-ProGetPackageInterTier `
        -Name 'Test.Package' -Version '1.0.0' `
        -FromFeed $Source -UsePushFeed `
        -ProGetBaseUrl $script:baseUrl -ApiKey $script:apiKey
      $result.DestinationFeed | Should -Be $ExpectedDest
    }
  }

  Context 'Legacy tier name normalization' {

    It "Normalizes 'testing' -> 'qa' tier and routes to nuget-stable" {
      $result = Move-ProGetPackageInterTier `
        -Name 'Test.Package' -Version '1.0.0' `
        -FromFeed 'nuget-testing' `
        -ProGetBaseUrl $script:baseUrl -ApiKey $script:apiKey
      $result.SourceTier | Should -Be 'qa'
      $result.DestinationFeed | Should -Be 'nuget-stable'
    }

    It "Normalizes 'production' -> 'stable' tier and throws (already at top)" {
      { Move-ProGetPackageInterTier `
          -Name 'Test.Package' -Version '1.0.0' `
          -FromFeed 'nuget-production' `
          -ProGetBaseUrl $script:baseUrl -ApiKey $script:apiKey
      } | Should -Throw -ExpectedMessage '*highest tier*'
    }
  }

  Context 'Push feed as source is tolerated (strip -push and treat as pull)' {

    It 'Accepts nuget-experimental-push and routes to nuget-development' {
      $result = Move-ProGetPackageInterTier `
        -Name 'Test.Package' -Version '1.0.0' `
        -FromFeed 'nuget-experimental-push' `
        -ProGetBaseUrl $script:baseUrl -ApiKey $script:apiKey
      $result.SourceTier | Should -Be 'experimental'
      $result.DestinationFeed | Should -Be 'nuget-development'
    }
  }

  Context 'Explicit destination override' {

    It 'Uses supplied -ToFeed and does not auto-compute' {
      $result = Move-ProGetPackageInterTier `
        -Name 'Test.Package' -Version '1.0.0' `
        -FromFeed 'nuget-experimental' -ToFeed 'nuget-qa' `
        -ProGetBaseUrl $script:baseUrl -ApiKey $script:apiKey
      $result.DestinationFeed | Should -Be 'nuget-qa'
    }
  }

  Context 'Legacy parameter-name aliases (C2.3 backward compatibility)' {

    It 'Accepts -PackageName / -SourceFeed / -DestinationFeed / -Comments aliases' {
      $result = Move-ProGetPackageInterTier `
        -PackageName 'Test.Package' -Version '1.0.0' `
        -SourceFeed 'nuget-experimental' -DestinationFeed 'nuget-qa' `
        -Comments 'legacy alias call' `
        -ProGetBaseUrl $script:baseUrl -ApiKey $script:apiKey
      $result.DestinationFeed | Should -Be 'nuget-qa'
      $result.Promoted | Should -BeTrue
    }
  }

  Context 'Already at highest tier' {

    It 'Throws when SourceFeed is nuget-stable' {
      { Move-ProGetPackageInterTier `
          -Name 'Test.Package' -Version '1.0.0' `
          -FromFeed 'nuget-stable' `
          -ProGetBaseUrl $script:baseUrl -ApiKey $script:apiKey
      } | Should -Throw -ExpectedMessage '*highest tier*'
    }
  }

  Context 'Bad feed name' {

    It 'Throws on an unrecognised feed prefix' {
      { Move-ProGetPackageInterTier `
          -Name 'Test.Package' -Version '1.0.0' `
          -FromFeed 'helm-experimental' `
          -ProGetBaseUrl $script:baseUrl -ApiKey $script:apiKey
      } | Should -Throw -ExpectedMessage '*Cannot parse source feed name*'
    }

    It 'Throws on an unknown tier name' {
      { Move-ProGetPackageInterTier `
          -Name 'Test.Package' -Version '1.0.0' `
          -FromFeed 'nuget-staging' `
          -ProGetBaseUrl $script:baseUrl -ApiKey $script:apiKey
      } | Should -Throw -ExpectedMessage '*Cannot parse source feed name*'
    }
  }

  Context 'WhatIf skips REST promote call' -Tag 'BuildTranscriptNoise' {

    It 'Returns Promoted=false under -WhatIf' {
      $result = Move-ProGetPackageInterTier `
        -Name 'Test.Package' -Version '1.0.0' `
        -FromFeed 'nuget-experimental' `
        -ProGetBaseUrl $script:baseUrl -ApiKey $script:apiKey `
        -WhatIf 6>$null
      $result.Promoted | Should -BeFalse
    }
  }

  Context 'Output object shape' {

    It 'Returns PSCustomObject with all expected properties' {
      $result = Move-ProGetPackageInterTier `
        -Name 'Test.Package' -Version '1.0.0' `
        -FromFeed 'nuget-development' `
        -ProGetBaseUrl $script:baseUrl -ApiKey $script:apiKey
      $result.PSObject.Properties.Name | Should -Contain 'PackageName'
      $result.PSObject.Properties.Name | Should -Contain 'SourceTier'
      $result.PSObject.Properties.Name | Should -Contain 'DestinationTier'
      $result.PSObject.Properties.Name | Should -Contain 'PackageType'
      $result.PSObject.Properties.Name | Should -Contain 'Phase2Mode'
      $result.PackageType | Should -Be 'nuget'
      $result.Phase2Mode | Should -BeFalse
    }
  }

  Context 'REST call bounds' {
    It 'Applies finite timeouts to ProGet verification and promotion calls' {
      Move-ProGetPackageInterTier `
        -Name 'Test.Package' -Version '1.0.0' `
        -FromFeed 'nuget-development' `
        -ProGetBaseUrl $script:baseUrl -ApiKey $script:apiKey | Out-Null

      Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
        $Method -eq 'Get' -and $TimeoutSec -eq 15
      }
      Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
        $Method -eq 'POST' -and $TimeoutSec -eq 60
      }
    }
  }
}
