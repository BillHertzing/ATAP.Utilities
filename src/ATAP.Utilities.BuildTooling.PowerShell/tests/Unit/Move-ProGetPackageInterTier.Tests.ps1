#Requires -Version 7.0
# Pester 5+ unit tests for Move-ProGetPackageInterTier.
# All ProGet REST calls are mocked. Validates tier ordering, legacy alias
# normalization (testing->qa, production->stable), and 5-tier auto-routing.
# AI assisted using Powershell.instructions.md as guidelines

BeforeAll {
    $publicDir      = Join-Path $PSScriptRoot '..\..\public' | Resolve-Path
    $script:scriptPath = Join-Path $publicDir 'Move-ProGetPackageInterTier.ps1'

    if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
        function Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
    }

    # Provide a container-local resolver and alias. The production resolver remains
    # opaque to this unit test and the stub cannot escape into later build steps.
    function Get-ParameterValueFromNeoConfigurationRoot {
        param($ParameterName, $originalPSBoundParameters, $dottedPath, $DefaultValue)
        return $DefaultValue
    }
    Set-Alias -Name Get-PVal -Value Get-ParameterValueFromNeoConfigurationRoot -Scope Script -Force

    # Dot-source the autoloaded function for testing.
    . $script:scriptPath

    $script:baseUrl = 'http://proget.test:50000'
    $script:apiKey = 'test-api-key'
    function Get-SecretATAP { [CmdletBinding()] param($SecretName, $SecretStoreType) $script:apiKey }
}

Describe 'Move-ProGetPackageInterTier' -Tag 'Unit', 'PromotedModuleHostSensitive' {
  BeforeEach {
    Mock Write-PSFMessage { }
    Mock Invoke-RestMethod {
      if ($Method -eq 'Get') {
        return , [PSCustomObject]@{ name = 'Test.Package'; version = '1.0.0' }
      }
      return ''
    }
  }

  Context 'Auto-destination: Phase 1 (combined feeds)' {

    $cases = @(
      @{ Source = 'nuget-experimental'; ExpectedDest = 'nuget-development' }
      @{ Source = 'nuget-development'; ExpectedDest = 'nuget-integration' }
      @{ Source = 'nuget-integration'; ExpectedDest = 'nuget-qa' }
      @{ Source = 'nuget-qa'; ExpectedDest = 'nuget-stable' }
      @{ Source = 'powershellget-experimental'; ExpectedDest = 'powershellget-development' }
      @{ Source = 'powershellget-integration'; ExpectedDest = 'powershellget-qa' }
      @{ Source = 'database-experimental'; ExpectedDest = 'database-development' }
      @{ Source = 'database-development'; ExpectedDest = 'database-integration' }
      @{ Source = 'database-integration'; ExpectedDest = 'database-qa' }
      @{ Source = 'database-qa'; ExpectedDest = 'database-stable' }
      @{ Source = 'chocolatey-qa'; ExpectedDest = 'chocolatey-stable' }
    )

    It "Routes '<Source>' -> '<ExpectedDest>' (Phase 1)" -TestCases $cases {
      param($Source, $ExpectedDest)
      $result = Move-ProGetPackageInterTier `
        -Name 'Test.Package' -Version '1.0.0' `
        -FromFeed $Source `
        -ProGetBaseUrl $script:baseUrl -ProGetApiKeySecretName 'Test.ProGet.API.Key'
      $result.DestinationFeed | Should -Be $ExpectedDest
      $result.Promoted | Should -BeTrue
    }
  }

  Context 'Auto-destination: Phase 2 (push feeds)' {

    $cases = @(
      @{ Source = 'nuget-experimental'; ExpectedDest = 'nuget-development-push' }
      @{ Source = 'nuget-integration'; ExpectedDest = 'nuget-qa-push' }
      @{ Source = 'database-experimental'; ExpectedDest = 'database-development-push' }
    )

    It "Routes '<Source>' -> '<ExpectedDest>' (Phase 2 / -UsePushFeed)" -TestCases $cases {
      param($Source, $ExpectedDest)
      $result = Move-ProGetPackageInterTier `
        -Name 'Test.Package' -Version '1.0.0' `
        -FromFeed $Source -UsePushFeed `
        -ProGetBaseUrl $script:baseUrl -ProGetApiKeySecretName 'Test.ProGet.API.Key'
      $result.DestinationFeed | Should -Be $ExpectedDest
    }
  }

  Context 'Legacy tier name normalization' {

    It "Normalizes 'testing' -> 'qa' tier and routes to nuget-stable" {
      $result = Move-ProGetPackageInterTier `
        -Name 'Test.Package' -Version '1.0.0' `
        -FromFeed 'nuget-testing' `
        -ProGetBaseUrl $script:baseUrl -ProGetApiKeySecretName 'Test.ProGet.API.Key'
      $result.SourceTier | Should -Be 'qa'
      $result.DestinationFeed | Should -Be 'nuget-stable'
    }

    It "Normalizes 'production' -> 'stable' tier and throws (already at top)" {
      { Move-ProGetPackageInterTier `
          -Name 'Test.Package' -Version '1.0.0' `
          -FromFeed 'nuget-production' `
          -ProGetBaseUrl $script:baseUrl -ProGetApiKeySecretName 'Test.ProGet.API.Key'
      } | Should -Throw -ExpectedMessage '*highest tier*'
    }
  }

  Context 'Push feed as source is tolerated (strip -push and treat as pull)' {

    It 'Accepts nuget-experimental-push and routes to nuget-development' {
      $result = Move-ProGetPackageInterTier `
        -Name 'Test.Package' -Version '1.0.0' `
        -FromFeed 'nuget-experimental-push' `
        -ProGetBaseUrl $script:baseUrl -ProGetApiKeySecretName 'Test.ProGet.API.Key'
      $result.SourceTier | Should -Be 'experimental'
      $result.DestinationFeed | Should -Be 'nuget-development'
    }
  }

  Context 'Explicit destination override' {

    It 'Uses supplied -ToFeed and does not auto-compute' {
      $result = Move-ProGetPackageInterTier `
        -Name 'Test.Package' -Version '1.0.0' `
        -FromFeed 'nuget-experimental' -ToFeed 'nuget-qa' `
        -ProGetBaseUrl $script:baseUrl -ProGetApiKeySecretName 'Test.ProGet.API.Key'
      $result.DestinationFeed | Should -Be 'nuget-qa'
    }
  }

  Context 'Legacy parameter-name aliases (C2.3 backward compatibility)' {

    It 'Accepts -PackageName / -SourceFeed / -DestinationFeed / -Comments aliases' {
      $result = Move-ProGetPackageInterTier `
        -PackageName 'Test.Package' -Version '1.0.0' `
        -SourceFeed 'nuget-experimental' -DestinationFeed 'nuget-qa' `
        -Comments 'legacy alias call' `
        -ProGetBaseUrl $script:baseUrl -ProGetApiKeySecretName 'Test.ProGet.API.Key'
      $result.DestinationFeed | Should -Be 'nuget-qa'
      $result.Promoted | Should -BeTrue
    }
  }

  Context 'Already at highest tier' {

    It 'Throws when SourceFeed is nuget-stable' {
      { Move-ProGetPackageInterTier `
          -Name 'Test.Package' -Version '1.0.0' `
          -FromFeed 'nuget-stable' `
          -ProGetBaseUrl $script:baseUrl -ProGetApiKeySecretName 'Test.ProGet.API.Key'
      } | Should -Throw -ExpectedMessage '*highest tier*'
    }
  }

  Context 'Bad feed name' {

    It 'Throws on an unrecognised feed prefix' {
      { Move-ProGetPackageInterTier `
          -Name 'Test.Package' -Version '1.0.0' `
          -FromFeed 'helm-experimental' `
          -ProGetBaseUrl $script:baseUrl -ProGetApiKeySecretName 'Test.ProGet.API.Key'
      } | Should -Throw -ExpectedMessage '*Cannot parse source feed name*'
    }

    It 'Throws on an unknown tier name' {
      { Move-ProGetPackageInterTier `
          -Name 'Test.Package' -Version '1.0.0' `
          -FromFeed 'nuget-staging' `
          -ProGetBaseUrl $script:baseUrl -ProGetApiKeySecretName 'Test.ProGet.API.Key'
      } | Should -Throw -ExpectedMessage '*Cannot parse source feed name*'
    }
  }

  Context 'WhatIf skips REST promote call' -Tag 'BuildTranscriptNoise' {

    It 'Returns Promoted=false under -WhatIf' {
      Mock Get-SecretATAP { throw 'must not be called' }
      $result = Move-ProGetPackageInterTier `
        -Name 'Test.Package' -Version '1.0.0' `
        -FromFeed 'nuget-experimental' `
        -ProGetBaseUrl $script:baseUrl -ProGetApiKeySecretName 'Test.ProGet.API.Key' `
        -WhatIf 6>$null
      $result.Promoted | Should -BeFalse
      Assert-MockCalled Get-SecretATAP -Times 0 -Exactly -Scope It
      Assert-MockCalled Invoke-RestMethod -Times 0 -Exactly -Scope It
    }
  }

  Context 'Secret leakage resistance' {
    It 'redacts a secret echoed by a promotion failure before throwing' {
      Mock Invoke-RestMethod { throw $script:apiKey }
      try {
        Move-ProGetPackageInterTier -Name 'Test.Package' -Version '1.0.0' -FromFeed 'nuget-experimental' `
          -ProGetBaseUrl $script:baseUrl -ProGetApiKeySecretName 'Test.ProGet.API.Key'
        throw 'Expected promotion failure.'
      } catch {
        $_.Exception.Message | Should -Not -Match ([regex]::Escape($script:apiKey))
      }
    }
  }

  Context 'Output object shape' {

    It 'Returns PSCustomObject with all expected properties' {
      $result = Move-ProGetPackageInterTier `
        -Name 'Test.Package' -Version '1.0.0' `
        -FromFeed 'nuget-development' `
        -ProGetBaseUrl $script:baseUrl -ProGetApiKeySecretName 'Test.ProGet.API.Key'
      $result.PSObject.Properties.Name | Should -Contain 'PackageName'
      $result.PSObject.Properties.Name | Should -Contain 'SourceTier'
      $result.PSObject.Properties.Name | Should -Contain 'DestinationTier'
      $result.PSObject.Properties.Name | Should -Contain 'PackageType'
      $result.PSObject.Properties.Name | Should -Contain 'Phase2Mode'
      $result.PackageType | Should -Be 'nuget'
      $result.Phase2Mode | Should -BeFalse
    }

    It 'Returns database as PackageType for database feed family moves' {
      $result = Move-ProGetPackageInterTier `
        -Name 'ATAPUtilities.Database' -Version '1.0.0' `
        -FromFeed 'database-experimental' `
        -ProGetBaseUrl $script:baseUrl -ProGetApiKeySecretName 'Test.ProGet.API.Key'
      $result.PackageType | Should -Be 'database'
      $result.DestinationFeed | Should -Be 'database-development'
    }
  }

  Context 'REST call bounds' {
    It 'Applies finite timeouts to ProGet verification, promotion, and destination verification calls' {
      Move-ProGetPackageInterTier `
        -Name 'Test.Package' -Version '1.0.0' `
        -FromFeed 'nuget-development' `
        -ProGetBaseUrl $script:baseUrl -ProGetApiKeySecretName 'Test.ProGet.API.Key' | Out-Null

      Should -Invoke Invoke-RestMethod -Times 2 -Exactly -ParameterFilter {
        $Method -eq 'Get' -and $TimeoutSec -eq 15
      }
      Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
        $Method -eq 'POST' -and $TimeoutSec -eq 60
      }
    }

    It 'Sends the current ProGet promote form contract' {
      Move-ProGetPackageInterTier `
        -Name 'Test.Package' -Version '1.0.0' `
        -FromFeed 'powershellget-development' -ToFeed 'powershellget-integration' `
        -Reason 'unit promotion' `
        -ProGetBaseUrl $script:baseUrl -ProGetApiKeySecretName 'Test.ProGet.API.Key' | Out-Null

      Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
        if ($Method -ne 'POST') { return $false }

        $ContentType -eq 'application/x-www-form-urlencoded' -and
          $Body.ContainsKey('name') -and
          -not $Body.ContainsKey('packageName') -and
          $Body['name'] -eq 'Test.Package' -and
          $Body['version'] -eq '1.0.0' -and
          $Body['fromFeed'] -eq 'powershellget-development' -and
          $Body['toFeed'] -eq 'powershellget-integration' -and
          $Body['comments'] -eq 'unit promotion'
      }
    }

    It 'Throws when source verification returns no package rows' {
      Mock Invoke-RestMethod {
        if ($Method -eq 'Get') {
          return @()
        }
        return ''
      }

      {
        Move-ProGetPackageInterTier `
          -Name 'Missing.Package' -Version '1.0.0' `
          -FromFeed 'powershellget-development' -ToFeed 'powershellget-integration' `
          -ProGetBaseUrl $script:baseUrl -ProGetApiKeySecretName 'Test.ProGet.API.Key'
      } | Should -Throw -ExpectedMessage "*was not found in source feed 'powershellget-development'*"
    }

    It 'Throws when promotion returns but the destination feed never exposes the package' {
      $script:verificationCall = 0
      Mock Start-Sleep { }
      Mock Invoke-RestMethod {
        if ($Method -eq 'Get') {
          $script:verificationCall++
          if ($script:verificationCall -eq 1) {
            return , [PSCustomObject]@{ name = 'Test.Package'; version = '1.0.0' }
          }
          return @()
        }
        return ''
      }

      {
        Move-ProGetPackageInterTier `
          -Name 'Test.Package' -Version '1.0.0' `
          -FromFeed 'powershellget-development' -ToFeed 'powershellget-integration' `
          -ProGetBaseUrl $script:baseUrl -ProGetApiKeySecretName 'Test.ProGet.API.Key'
      } | Should -Throw -ExpectedMessage "*was not visible in destination feed 'powershellget-integration'*"
    }
  }
}
