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

    # Stub out REST calls.
    function global:Invoke-RestMethod { param([Parameter(ValueFromRemainingArguments = $true)]$rest) return @{} }

    # Stub Get-PVal to pass through values unchanged.
    function global:Get-PVal {
        param($ParameterName, $originalPSBoundParameters, $dottedPath, $DefaultValue)
        return $DefaultValue
    }

    # Wrapper function so tests can call Move-ProGetPackageInterTier as a command
    # (the .ps1 uses bare param() at script level, not a named function).
    function global:Move-ProGetPackageInterTier {
        param(
            [Parameter(Mandatory)][string]$PackageName,
            [Parameter(Mandatory)][string]$Version,
            [Parameter(Mandatory)][string]$SourceFeed,
            [string]$DestinationFeed,
            [switch]$UsePushFeed,
            [string]$Comments,
            [string]$ProGetBaseUrl,
            [string]$ApiKey
        )
        & $script:scriptPath @PSBoundParameters

  $script:baseUrl = 'http://proget.test:50000'
  $script:apiKey = 'test-api-key'
}

Describe 'Move-ProGetPackageInterTier' -Tag 'Unit' {

  Context 'Auto-destination: Phase 1 (combined feeds)' {

    $cases = @(
      @{ Source = 'nuget-experimental'; ExpectedDest = 'nuget-development' }
      @{ Source = 'nuget-development'; ExpectedDest = 'nuget-integration' }
      @{ Source = 'nuget-integration'; ExpectedDest = 'nuget-qa' }
      @{ Source = 'nuget-qa'; ExpectedDest = 'nuget-stable' }
      @{ Source = 'powershell-experimental'; ExpectedDest = 'powershell-development' }
      @{ Source = 'powershell-integration'; ExpectedDest = 'powershell-qa' }
      @{ Source = 'chocolatey-qa'; ExpectedDest = 'chocolatey-stable' }
    )

    It "Routes '<Source>' -> '<ExpectedDest>' (Phase 1)" -TestCases $cases {
      param($Source, $ExpectedDest)
      $result = Move-ProGetPackageInterTier `
        -PackageName 'Test.Package' -Version '1.0.0' `
        -SourceFeed $Source `
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
        -PackageName 'Test.Package' -Version '1.0.0' `
        -SourceFeed $Source -UsePushFeed `
        -ProGetBaseUrl $script:baseUrl -ApiKey $script:apiKey
      $result.DestinationFeed | Should -Be $ExpectedDest
    }
  }

  Context 'Legacy tier name normalization' {

    It "Normalizes 'testing' -> 'qa' tier and routes to nuget-stable" {
      $result = Move-ProGetPackageInterTier `
        -PackageName 'Test.Package' -Version '1.0.0' `
        -SourceFeed 'nuget-testing' `
        -ProGetBaseUrl $script:baseUrl -ApiKey $script:apiKey
      $result.SourceTier | Should -Be 'qa'
      $result.DestinationFeed | Should -Be 'nuget-stable'
    }

    It "Normalizes 'production' -> 'stable' tier and throws (already at top)" {
      { Move-ProGetPackageInterTier `
          -PackageName 'Test.Package' -Version '1.0.0' `
          -SourceFeed 'nuget-production' `
          -ProGetBaseUrl $script:baseUrl -ApiKey $script:apiKey
      } | Should -Throw -ExpectedMessage '*highest tier*'
    }
  }

  Context 'Push feed as source is tolerated (strip -push and treat as pull)' {

    It 'Accepts nuget-experimental-push and routes to nuget-development' {
      $result = Move-ProGetPackageInterTier `
        -PackageName 'Test.Package' -Version '1.0.0' `
        -SourceFeed 'nuget-experimental-push' `
        -ProGetBaseUrl $script:baseUrl -ApiKey $script:apiKey
      $result.SourceTier | Should -Be 'experimental'
      $result.DestinationFeed | Should -Be 'nuget-development'
    }
  }

  Context 'Explicit destination override' {

    It 'Uses supplied -DestinationFeed and does not auto-compute' {
      $result = Move-ProGetPackageInterTier `
        -PackageName 'Test.Package' -Version '1.0.0' `
        -SourceFeed 'nuget-experimental' -DestinationFeed 'nuget-qa' `
        -ProGetBaseUrl $script:baseUrl -ApiKey $script:apiKey
      $result.DestinationFeed | Should -Be 'nuget-qa'
    }
  }

  Context 'Already at highest tier' {

    It 'Throws when SourceFeed is nuget-stable' {
      { Move-ProGetPackageInterTier `
          -PackageName 'Test.Package' -Version '1.0.0' `
          -SourceFeed 'nuget-stable' `
          -ProGetBaseUrl $script:baseUrl -ApiKey $script:apiKey
      } | Should -Throw -ExpectedMessage '*highest tier*'
    }
  }

  Context 'Bad feed name' {

    It 'Throws on an unrecognised feed prefix' {
      { Move-ProGetPackageInterTier `
          -PackageName 'Test.Package' -Version '1.0.0' `
          -SourceFeed 'helm-experimental' `
          -ProGetBaseUrl $script:baseUrl -ApiKey $script:apiKey
      } | Should -Throw -ExpectedMessage '*Cannot parse source feed name*'
    }

    It 'Throws on an unknown tier name' {
      { Move-ProGetPackageInterTier `
          -PackageName 'Test.Package' -Version '1.0.0' `
          -SourceFeed 'nuget-staging' `
          -ProGetBaseUrl $script:baseUrl -ApiKey $script:apiKey
      } | Should -Throw -ExpectedMessage '*Cannot parse source feed name*'
    }
  }

  Context 'WhatIf skips REST promote call' {

    It 'Does not set Promoted=true under -WhatIf' {
      $result = Move-ProGetPackageInterTier `
        -PackageName 'Test.Package' -Version '1.0.0' `
        -SourceFeed 'nuget-experimental' `
        -ProGetBaseUrl $script:baseUrl -ApiKey $script:apiKey `
        -WhatIf
      $result | Should -BeNullOrEmpty
    }
  }

  Context 'Output object shape' {

    It 'Returns PSCustomObject with all expected properties' {
      $result = Move-ProGetPackageInterTier `
        -PackageName 'Test.Package' -Version '1.0.0' `
        -SourceFeed 'nuget-development' `
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
}
