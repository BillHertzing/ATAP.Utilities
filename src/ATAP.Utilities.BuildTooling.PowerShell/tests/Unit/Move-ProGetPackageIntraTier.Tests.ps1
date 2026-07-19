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
        function Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
    }

    # Stub REST calls within this Pester container and optionally capture calls
    # for payload assertions.
    function Invoke-RestMethod {
        param(
            [string]$Uri,
            [object]$Headers,
            [string]$Method,
            [object]$Body,
            [string]$ContentType,
            [Parameter(ValueFromRemainingArguments = $true)]$rest
        )
        if ($null -ne $script:MoveProGetIntraTierRestCalls) {
            $script:MoveProGetIntraTierRestCalls.Add([PSCustomObject]@{
                Uri         = $Uri
                Headers     = $Headers
                Method      = $Method
                Body        = $Body
                ContentType = $ContentType
            }) | Out-Null
        }
        return @{}
    }

    # Provide a container-local resolver and alias.
    function Get-ParameterValueFromNeoConfigurationRoot {
        param($ParameterName, $originalPSBoundParameters, $dottedPath, $DefaultValue)
        return $DefaultValue
    }
    Set-Alias -Name Get-PVal -Value Get-ParameterValueFromNeoConfigurationRoot -Scope Script -Force

    # Dot-source the file to load the Move-ProGetPackageIntraTier function.
    . $script:scriptPath

    $script:baseUrl = 'http://proget.test:50000'
    $script:apiKey  = 'test-api-key'
    function Get-SecretATAP { [CmdletBinding()] param($SecretName, $SecretStoreType) $script:apiKey }
}

Describe 'Move-ProGetPackageIntraTier' -Tag 'Unit', 'PromotedModuleHostSensitive' {
  BeforeEach {
    Mock Write-PSFMessage { }
    $script:MoveProGetIntraTierRestCalls = [System.Collections.Generic.List[object]]::new()
  }

  Context 'Secret boundary' {
    It 'performs no secret lookup or REST call under -WhatIf' {
      Mock Get-SecretATAP { throw 'must not be called' }
      Mock Invoke-RestMethod { throw 'must not be called' }
      $result = Move-ProGetPackageIntraTier -Name 'Test.Package' -Version '1.0.0' `
        -FromFeed 'nuget-experimental-push' -ToFeed 'nuget-experimental' `
        -ProGetBaseUrl $script:baseUrl -ProGetApiKeySecretName 'Test.ProGet.API.Key' -WhatIf
      $result.Promoted | Should -BeFalse
      Assert-MockCalled Get-SecretATAP -Times 0 -Exactly -Scope It
      Assert-MockCalled Invoke-RestMethod -Times 0 -Exactly -Scope It
    }

    It 'redacts a secret echoed by a promotion failure before throwing' {
      Mock Invoke-RestMethod { throw $script:apiKey }
      try {
        Move-ProGetPackageIntraTier -Name 'Test.Package' -Version '1.0.0' `
          -FromFeed 'nuget-experimental-push' -ToFeed 'nuget-experimental' `
          -ProGetBaseUrl $script:baseUrl -ProGetApiKeySecretName 'Test.ProGet.API.Key'
        throw 'Expected promotion failure.'
      } catch {
        $_.Exception.Message | Should -Not -Match ([regex]::Escape($script:apiKey))
      }
    }
  }

  Context 'Phase 2: valid push -> pull moves' {

    $cases = @(
      @{ Source = 'nuget-experimental-push'; Dest = 'nuget-experimental' }
      @{ Source = 'nuget-development-push'; Dest = 'nuget-development' }
      @{ Source = 'nuget-integration-push'; Dest = 'nuget-integration' }
      @{ Source = 'nuget-qa-push'; Dest = 'nuget-qa' }
      @{ Source = 'nuget-stable-push'; Dest = 'nuget-stable' }
      @{ Source = 'powershellget-integration-push'; Dest = 'powershellget-integration' }
    )

    It "Phase 2: '<Source>' -> '<Dest>' succeeds" -TestCases $cases {
      param($Source, $Dest)
      $result = Move-ProGetPackageIntraTier `
        -Name 'Test.Package' -Version '1.0.0' `
        -FromFeed $Source -ToFeed $Dest `
        -ProGetBaseUrl $script:baseUrl -ProGetApiKeySecretName 'Test.ProGet.API.Key'
      $result.Promoted | Should -BeTrue
      $result.ScanPassed | Should -BeTrue
      $result.SourceFeed | Should -Be $Source
      $result.DestinationFeed | Should -Be $Dest
    }
  }

  Context 'Phase 1: ScanOnly (same feed)' {

    It 'Returns Promoted=$false, ScanPassed=$true with -ScanOnly' {
      $result = Move-ProGetPackageIntraTier `
        -Name 'Test.Package' -Version '1.0.0' `
        -FromFeed 'nuget-experimental' -ToFeed 'nuget-experimental' `
        -ScanOnly `
        -ProGetBaseUrl $script:baseUrl -ProGetApiKeySecretName 'Test.ProGet.API.Key'
      $result.Promoted | Should -BeFalse
      $result.ScanPassed | Should -BeTrue
      $result.Reason | Should -Be 'ScanOnly mode'
    }

    It 'Returns Promoted=$false, ScanPassed=$true when source=dest (Phase 1 same-feed)' {
      $result = Move-ProGetPackageIntraTier `
        -Name 'Test.Package' -Version '1.0.0' `
        -FromFeed 'nuget-experimental' -ToFeed 'nuget-experimental' `
        -ProGetBaseUrl $script:baseUrl -ProGetApiKeySecretName 'Test.ProGet.API.Key'
      $result.Promoted | Should -BeFalse
      $result.Reason | Should -Be 'Same feed (Phase 1)'
    }
  }

  Context 'Legacy tier alias normalization — validation accepts normalized names' {

    It 'Accepts source=nuget-testing-push and dest=nuget-testing (normalized to qa)' {
      # Both normalize to qa, same tier, push->pull: valid
      $result = Move-ProGetPackageIntraTier `
        -Name 'Test.Package' -Version '1.0.0' `
        -FromFeed 'nuget-testing-push' -ToFeed 'nuget-testing' `
        -ProGetBaseUrl $script:baseUrl -ProGetApiKeySecretName 'Test.ProGet.API.Key'
      $result.Promoted | Should -BeTrue
    }

    It 'Accepts source=nuget-production-push and dest=nuget-production (normalized to stable)' {
      $result = Move-ProGetPackageIntraTier `
        -Name 'Test.Package' -Version '1.0.0' `
        -FromFeed 'nuget-production-push' -ToFeed 'nuget-production' `
        -ProGetBaseUrl $script:baseUrl -ProGetApiKeySecretName 'Test.ProGet.API.Key'
      $result.Promoted | Should -BeTrue
    }
  }

  Context 'Phase 2 validation: mismatched tiers' {

    It 'Throws when source and destination belong to different tiers' {
      { Move-ProGetPackageIntraTier `
          -Name 'Test.Package' -Version '1.0.0' `
          -FromFeed 'nuget-experimental-push' -ToFeed 'nuget-development' `
          -ProGetBaseUrl $script:baseUrl -ProGetApiKeySecretName 'Test.ProGet.API.Key'
      } | Should -Throw -ExpectedMessage '*same tier*'
    }
  }

  Context 'Phase 2 validation: source must be push feed' {

    It 'Throws when source is a pull feed in Phase 2 mode' {
      { Move-ProGetPackageIntraTier `
          -Name 'Test.Package' -Version '1.0.0' `
          -FromFeed 'nuget-development' -ToFeed 'nuget-qa' `
          -ProGetBaseUrl $script:baseUrl -ProGetApiKeySecretName 'Test.ProGet.API.Key'
      } | Should -Throw -ExpectedMessage '*push feed*'
    }
  }

  Context 'Phase 2 validation: destination must be pull feed' {

    It 'Throws when destination is a push feed in Phase 2 mode' {
      { Move-ProGetPackageIntraTier `
          -Name 'Test.Package' -Version '1.0.0' `
          -FromFeed 'nuget-development-push' -ToFeed 'nuget-qa-push' `
          -ProGetBaseUrl $script:baseUrl -ProGetApiKeySecretName 'Test.ProGet.API.Key'
      } | Should -Throw -ExpectedMessage '*pull feed*'
    }
  }

  Context 'Phase 2 validation: package type prefix must match' {

    It 'Throws when source is nuget and destination is powershellget' {
      { Move-ProGetPackageIntraTier `
          -Name 'Test.Package' -Version '1.0.0' `
          -FromFeed 'nuget-development-push' -ToFeed 'powershellget-development' `
          -ProGetBaseUrl $script:baseUrl -ProGetApiKeySecretName 'Test.ProGet.API.Key'
      } | Should -Throw -ExpectedMessage '*package type*'
    }
  }

  Context 'Unknown tier name' {

    It 'Throws on an unknown tier in SourceFeed' {
      { Move-ProGetPackageIntraTier `
          -Name 'Test.Package' -Version '1.0.0' `
          -FromFeed 'nuget-staging-push' -ToFeed 'nuget-staging' `
          -ProGetBaseUrl $script:baseUrl -ProGetApiKeySecretName 'Test.ProGet.API.Key'
      } | Should -Throw -ExpectedMessage '*tiers must be one of*'
    }
  }

  Context 'Output object shape' {

    It 'Returns PSCustomObject with expected properties' {
      $result = Move-ProGetPackageIntraTier `
        -Name 'Test.Package' -Version '2.0.0' `
        -FromFeed 'nuget-integration-push' -ToFeed 'nuget-integration' `
        -ProGetBaseUrl $script:baseUrl -ProGetApiKeySecretName 'Test.ProGet.API.Key'
      $result.PSObject.Properties.Name | Should -Contain 'ScanPassed'
      $result.PSObject.Properties.Name | Should -Contain 'Promoted'
      $result.PSObject.Properties.Name | Should -Contain 'Reason'
      $result.PackageName | Should -Be 'Test.Package'
      $result.Version | Should -Be '2.0.0'
    }
  }

  Context 'Legacy parameter-name aliases (C2.3 backward compatibility)' {

    It 'Accepts -PackageName / -SourceFeed / -DestinationFeed / -Comments aliases' {
      $result = Move-ProGetPackageIntraTier `
        -PackageName 'Test.Package' -Version '1.0.0' `
        -SourceFeed 'nuget-integration-push' -DestinationFeed 'nuget-integration' `
        -Comments 'legacy alias call' `
        -ProGetBaseUrl $script:baseUrl -ProGetApiKeySecretName 'Test.ProGet.API.Key'
      $result.Promoted | Should -BeTrue
      $result.ScanPassed | Should -BeTrue
    }
  }

  Context 'Promotion API payload' {
    It 'Sends the current ProGet promote JSON contract' {
      Move-ProGetPackageIntraTier `
        -Name 'Test.Package' -Version '1.0.0' `
        -FromFeed 'powershellget-integration-push' -ToFeed 'powershellget-integration' `
        -Reason 'unit intra-tier promotion' `
        -ProGetBaseUrl $script:baseUrl -ProGetApiKeySecretName 'Test.ProGet.API.Key' | Out-Null

      $postCall = @($script:MoveProGetIntraTierRestCalls | Where-Object { $_.Method -eq 'POST' })[0]
      $postCall | Should -Not -BeNullOrEmpty

      $payload = $postCall.Body | ConvertFrom-Json
      $propertyNames = @($payload.PSObject.Properties.Name)
      $propertyNames | Should -Contain 'name'
      $propertyNames | Should -Not -Contain 'packageName'
      $payload.name | Should -Be 'Test.Package'
      $payload.version | Should -Be '1.0.0'
      $payload.fromFeed | Should -Be 'powershellget-integration-push'
      $payload.toFeed | Should -Be 'powershellget-integration'
      $payload.comments | Should -Be 'unit intra-tier promotion'
    }
  }
}
