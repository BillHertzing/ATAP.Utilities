#Requires -Version 7.0

BeforeAll {
  Import-Module PSFramework -ErrorAction SilentlyContinue
  $script:publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
  . (Join-Path $script:publicDir 'Assert-BuildMasterReady.ps1')
  function Get-SecretATAP {
    param(
      [string]$SecretName,
      [string]$SecretField,
      [string]$SecretStoreType,
      [System.Management.Automation.ActionPreference]$ErrorAction
    )
    'fake-test-key'
  }
  function Get-ParameterValueFromNeoConfigurationRoot {
    param($ParameterName, $originalPSBoundParameters, $DefaultValue)
    $script:getPValCallCount++
    return $DefaultValue
  }
  Set-Alias -Name Get-PVal -Value Get-ParameterValueFromNeoConfigurationRoot -Scope Script -Force
  # Port 1 is reserved and closed; a TCP HEAD here is refused fast on Windows.
  $script:unreachableUrl = 'http://127.0.0.1:1'
}

Describe 'Assert-BuildMasterReady' -Tag 'Unit' {
  BeforeEach {
    $script:getPValCallCount = 0
    Mock Get-SecretATAP { 'fake-test-key' }

    # SC-0288 / Task 13.66.b: the cmdlet derives its SecretName host suffix from
    # the service placement map, so a suite that leaves the parameter unbound must
    # declare placement. Contexts that need a different state override this.
    $script:oldConfigRootKeys = $global:configRootKeys
    $script:oldSettings = $global:Settings
    $global:configRootKeys = @{ ServicePlacementMapConfigRootKey = 'ServicePlacementMap' }
    $global:Settings = @{ ServicePlacementMap = @{ BuildMaster = 'utat022'; ProGet = 'utat022' } }
  }

  AfterEach {
    $global:configRootKeys = $script:oldConfigRootKeys
    $global:Settings = $script:oldSettings
  }

  Context 'Placement-derived SecretName' {
    It 'suffixes the default SecretName with the BuildMaster placement host' {
      # SC-0288: this used to be the hard-coded literal
      # 'BuildMaster.Admin.API.Key.utat01', which broke whenever the instance
      # under test was not utat01.
      $result = Assert-BuildMasterReady -BuildMasterBaseUrl $script:unreachableUrl -TimeoutSeconds 1

      $result.Checks.ApiKeyResolvable.Ok | Should -BeTrue
      $script:getPValCallCount | Should -Be 0
      Should -Invoke Get-SecretATAP -ParameterFilter { $SecretName -eq 'BuildMaster.Admin.API.Key.utat022' }
    }

    It 'follows the placement map to the other host without a code change' {
      $global:Settings['ServicePlacementMap']['BuildMaster'] = 'utat01'

      $result = Assert-BuildMasterReady -BuildMasterBaseUrl $script:unreachableUrl -TimeoutSeconds 1

      $result.Checks.ApiKeyResolvable.Ok | Should -BeTrue
      Should -Invoke Get-SecretATAP -ParameterFilter { $SecretName -eq 'BuildMaster.Admin.API.Key.utat01' }
    }

    It 'fails closed when configuration is loaded but placement is unknown' {
      $global:Settings = @{ Unrelated = 'value' }

      { Assert-BuildMasterReady -BuildMasterBaseUrl $script:unreachableUrl -TimeoutSeconds 1 } |
        Should -Throw -ExpectedMessage '*placement host*could not be determined*'
    }

    It 'honours an explicitly bound SecretName without consulting placement' {
      $global:Settings = @{ Unrelated = 'value' }

      $result = Assert-BuildMasterReady -BuildMasterBaseUrl $script:unreachableUrl `
        -BuildMasterAdminApiKeySecretName 'BuildMaster.Admin.API.Key.utat01' -TimeoutSeconds 1

      $result.Checks.ApiKeyResolvable.Ok | Should -BeTrue
      $script:getPValCallCount | Should -Be 0
      Should -Invoke Get-SecretATAP -ParameterFilter { $SecretName -eq 'BuildMaster.Admin.API.Key.utat01' }
    }
  }

  Context 'No-profile BuildMaster host' {
    It 'uses the unsuffixed base name when no ATAP configuration is loaded at all' {
      # A profileless shell has no BuildMaster endpoint configured either, so
      # there is no host to suffix against and nothing to authenticate to.
      $global:configRootKeys = $null
      $global:Settings = $null

      $result = Assert-BuildMasterReady -BuildMasterBaseUrl $script:unreachableUrl -TimeoutSeconds 1

      $result.Checks.ApiKeyResolvable.Ok | Should -BeTrue
      $script:getPValCallCount | Should -Be 0
      Should -Invoke Get-SecretATAP -ParameterFilter { $SecretName -eq 'BuildMaster.Admin.API.Key' }
    }
  }

  Context 'Result shape with forced ApiReachable failure' {
    BeforeAll {
      $script:result = Assert-BuildMasterReady `
        -BuildMasterBaseUrl $script:unreachableUrl `
        -TimeoutSeconds 1
    }

    It 'Returns a PSCustomObject with the top-level contract' {
      $script:result | Should -BeOfType ([System.Management.Automation.PSCustomObject])
      $script:result.PSObject.Properties.Name | Should -Contain 'AllOk'
      $script:result.PSObject.Properties.Name | Should -Contain 'Checks'
      $script:result.PSObject.Properties.Name | Should -Contain 'Failures'
      $script:result.PSObject.Properties.Name | Should -Contain 'Timestamp'
    }

    It 'Populates every documented check' {
      $names = @('ApiKeyResolvable', 'ApiReachable', 'ApplicationExistence', 'PipelineExistence', 'RequiredVariables', 'MonitorsDeployed')
      foreach ($n in $names) {
        $script:result.Checks.PSObject.Properties.Name | Should -Contain $n
      }
    }

    It 'AllOk is false when BuildMaster is unreachable' {
      $script:result.AllOk | Should -BeFalse
    }

    It 'ApiKeyResolvable passes when Get-SecretATAP resolves the configured secret' {
      $script:result.Checks.ApiKeyResolvable.Ok | Should -BeTrue
      $script:result.Checks.ApiKeyResolvable.Source | Should -Be 'Get-SecretATAP'
    }

    It 'ApiReachable fails when URL is unreachable' {
      $script:result.Checks.ApiReachable.Ok | Should -BeFalse
      $script:result.Failures | Should -Contain 'ApiReachable'
    }

    It 'ApplicationExistence is Skipped when ApiReachable fails' {
      $script:result.Checks.ApplicationExistence.PerApp[0].Detail | Should -Match 'Skipped'
    }

    It 'RequiredVariables is Skipped when ApiReachable fails' {
      $script:result.Checks.RequiredVariables.PerApp[0].Detail | Should -Match 'Skipped'
    }

    It 'MonitorsDeployed is always Skipped and Ok' {
      $script:result.Checks.MonitorsDeployed.Skipped | Should -BeTrue
      $script:result.Checks.MonitorsDeployed.Ok | Should -BeTrue
    }

    It 'Defaults to two ATAP.Utilities applications' {
      $script:result.Checks.ApplicationExistence.PerApp.Count | Should -Be 2
      $names = $script:result.Checks.ApplicationExistence.PerApp.ApplicationName
      $names | Should -Contain 'ATAP.Utilities-CSharp'
      $names | Should -Contain 'ATAP.Utilities-PowerShell'
    }
  }

  Context 'Custom ApplicationNames' {
    It 'Respects a custom application list and produces one PerApp entry per name' {
      $r = Assert-BuildMasterReady `
        -BuildMasterBaseUrl $script:unreachableUrl `
        -TimeoutSeconds 1 `
        -ApplicationNames @('OnlyApp')
      $r.Checks.ApplicationExistence.PerApp.Count | Should -Be 1
      $r.Checks.ApplicationExistence.PerApp[0].ApplicationName | Should -Be 'OnlyApp'
    }
  }

  Context '-ThrowOnFailure switch' {
    It 'Throws with the expected FullyQualifiedErrorId when AllOk is false' {
      try {
        Assert-BuildMasterReady `
          -BuildMasterBaseUrl $script:unreachableUrl `
          -TimeoutSeconds 1 `
          -ThrowOnFailure | Out-Null
        throw 'Expected Assert-BuildMasterReady to throw a terminating error.'
      } catch {
        $_.FullyQualifiedErrorId | Should -Match '^BuildMasterNotReadyException'
      }
    }
  }
}
