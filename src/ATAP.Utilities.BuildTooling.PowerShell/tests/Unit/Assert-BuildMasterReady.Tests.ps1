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
  }

  Context 'No-profile BuildMaster host' {
    It 'uses the local secret-name default when global settings is absent' {
      $savedSettings = Get-Variable -Name settings -Scope Global -ErrorAction SilentlyContinue
      try {
        Remove-Variable -Name settings -Scope Global -ErrorAction SilentlyContinue
        $result = Assert-BuildMasterReady -BuildMasterBaseUrl $script:unreachableUrl -TimeoutSeconds 1
        $result.Checks.ApiKeyResolvable.Ok | Should -BeTrue
        $script:getPValCallCount | Should -Be 0
        Should -Invoke Get-SecretATAP -ParameterFilter { $SecretName -eq 'BuildMaster.Admin.API.Key.utat01' }
      } finally {
        if ($null -ne $savedSettings) { Set-Variable -Name settings -Scope Global -Value $savedSettings.Value }
      }
    }

    It 'uses an explicit secret name when global settings lacks the key' {
      $savedSettings = Get-Variable -Name settings -Scope Global -ErrorAction SilentlyContinue
      try {
        Set-Variable -Name settings -Scope Global -Value @{ Unrelated = 'value' }
        $result = Assert-BuildMasterReady -BuildMasterBaseUrl $script:unreachableUrl `
          -BuildMasterAdminApiKeySecretName 'BuildMaster.Admin.API.Key.utat01' -TimeoutSeconds 1
        $result.Checks.ApiKeyResolvable.Ok | Should -BeTrue
        $script:getPValCallCount | Should -Be 0
        Should -Invoke Get-SecretATAP -ParameterFilter { $SecretName -eq 'BuildMaster.Admin.API.Key.utat01' }
      } finally {
        if ($null -ne $savedSettings) {
          Set-Variable -Name settings -Scope Global -Value $savedSettings.Value
        } else {
          Remove-Variable -Name settings -Scope Global -ErrorAction SilentlyContinue
        }
      }
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
