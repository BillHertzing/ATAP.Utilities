#Requires -Version 7.0

BeforeAll {
  Import-Module PSFramework -ErrorAction SilentlyContinue
  $script:publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
  . (Join-Path $script:publicDir 'Test-SprintInfrastructureHealth.ps1')

  # Stub the secret store so the health check resolves the BuildMaster admin API
  # key without contacting Bitwarden. Records SecretField and SecretStoreType.
  $script:lastSecretField = $null
  $script:lastSecretStoreType = $null
  function global:Get-SecretATAP {
    param([string]$SecretName, [string]$SecretField = 'password', [string]$SecretStoreType)
    $script:lastSecretField = $SecretField
    $script:lastSecretStoreType = $SecretStoreType
    'unit-test-key'
  }
}

Describe 'Test-SprintInfrastructureHealth' -Tag 'Unit' {

  Context 'Result shape' {
    BeforeAll {
      $script:result = Test-SprintInfrastructureHealth `
        -ProGetBaseUrl '' `
        -BuildMasterBaseUrl '' `
        -SqlInstancePaths @()
    }

    It 'Returns a PSCustomObject with the top-level contract' {
      $script:result | Should -BeOfType ([System.Management.Automation.PSCustomObject])
      $script:result.PSObject.Properties.Name | Should -Contain 'AllOk'
      $script:result.PSObject.Properties.Name | Should -Contain 'Checks'
      $script:result.PSObject.Properties.Name | Should -Contain 'Failures'
      $script:result.PSObject.Properties.Name | Should -Contain 'Timestamp'
    }

    It 'Populates every documented check key' {
      $expected = @(
        'SecretEnvironmentVariables', 'BuildMasterAdminApiKeyResolvable', 'SqlInstances', 'FlywayAvailable',
        'NbgvAvailable', 'GitSafeDirectory', 'BuildMasterApps', 'ProGetReachable', 'BuildMasterReachable'
      )
      foreach ($key in $expected) {
        $script:result.Checks.PSObject.Properties.Name | Should -Contain $key -Because "check key '$key' must always be present"
      }
    }

    It 'AllOk is consistent with Failures count' {
      if ($script:result.AllOk) {
        $script:result.Failures.Count | Should -Be 0
      } else {
        $script:result.Failures.Count | Should -BeGreaterThan 0
      }
    }
  }

  Context 'BuildMaster admin API key — Bitwarden notes field' {
    It 'calls Get-SecretATAP with SecretField notes' {
      $script:lastSecretField = $null
      Test-SprintInfrastructureHealth -SqlInstancePaths @() -ProGetBaseUrl '' -BuildMasterBaseUrl '' | Out-Null
      $script:lastSecretField | Should -Be 'notes'
    }

    It 'source documents CommonCIForBitwardenReadOnly for the BWS-backed provider path' {
      $source = Get-Content -LiteralPath (Join-Path $script:publicDir 'Test-SprintInfrastructureHealth.ps1') -Raw
      $source | Should -Match 'CommonCIForBitwardenReadOnly'
      $source | Should -Match "SecretStoreType 'BitwardenSecretsManager'"
    }

    It 'forces the BitwardenSecretsManager provider so no BW_SESSION is needed (SC-0175)' {
      $script:lastSecretStoreType = $null
      Test-SprintInfrastructureHealth -SqlInstancePaths @() -ProGetBaseUrl '' -BuildMasterBaseUrl '' | Out-Null
      $script:lastSecretStoreType | Should -Be 'BitwardenSecretsManager'
    }

    It 'BuildMasterAdminApiKeyResolvable.Ok is true when stub returns a value' {
      $r = Test-SprintInfrastructureHealth -SqlInstancePaths @() -ProGetBaseUrl '' -BuildMasterBaseUrl ''
      $r.Checks.BuildMasterAdminApiKeyResolvable.Ok | Should -BeTrue
    }
  }

  Context 'SqlInstances — skip semantics' {
    It 'Marks SqlInstances Skipped/Ok when SqlInstancePaths is empty' {
      $r = Test-SprintInfrastructureHealth -SqlInstancePaths @() -ProGetBaseUrl '' -BuildMasterBaseUrl ''
      $r.Checks.SqlInstances.Ok | Should -BeTrue
      $r.Checks.SqlInstances.Skipped | Should -BeTrue
    }
  }

  Context 'URL reachability skip semantics' {
    It 'Marks ProGet check Skipped/Ok when ProGetBaseUrl is empty' {
      $r = Test-SprintInfrastructureHealth -ProGetBaseUrl '' -BuildMasterBaseUrl '' -SqlInstancePaths @()
      $r.Checks.ProGetReachable.Skipped | Should -BeTrue
      $r.Checks.ProGetReachable.Ok | Should -BeTrue
    }

    It 'Marks BuildMaster check Skipped/Ok when BuildMasterBaseUrl is empty' {
      $r = Test-SprintInfrastructureHealth -ProGetBaseUrl '' -BuildMasterBaseUrl '' -SqlInstancePaths @()
      $r.Checks.BuildMasterReachable.Skipped | Should -BeTrue
      $r.Checks.BuildMasterReachable.Ok | Should -BeTrue
    }

    It 'Marks BuildMasterApps Skipped/Ok when BuildMasterBaseUrl is empty' {
      $r = Test-SprintInfrastructureHealth -ProGetBaseUrl '' -BuildMasterBaseUrl '' -SqlInstancePaths @()
      $r.Checks.BuildMasterApps.Skipped | Should -BeTrue
      $r.Checks.BuildMasterApps.Ok | Should -BeTrue
    }
  }

  Context 'SecretEnvironmentVariables — prohibited variable detection' {
    BeforeAll {
      $script:savedWebhookProc = [System.Environment]::GetEnvironmentVariable('BUILDMASTER_GH_WEBHOOK_SECRET', 'Process')
      [System.Environment]::SetEnvironmentVariable('BUILDMASTER_GH_WEBHOOK_SECRET', 'unit-test-secret', 'Process')
    }
    AfterAll {
      [System.Environment]::SetEnvironmentVariable('BUILDMASTER_GH_WEBHOOK_SECRET', $script:savedWebhookProc, 'Process')
    }

    It 'fails when a prohibited secret variable is present' {
      $r = Test-SprintInfrastructureHealth -ProGetBaseUrl '' -BuildMasterBaseUrl '' -SqlInstancePaths @()
      $r.Checks.SecretEnvironmentVariables.Ok | Should -BeFalse
      $r.Checks.SecretEnvironmentVariables.Present.Count | Should -BeGreaterThan 0
      $r.Failures | Should -Contain 'SecretEnvironmentVariables'
      $r.AllOk | Should -BeFalse
    }

    It 'reports names and scopes without returning secret values' {
      $r = Test-SprintInfrastructureHealth -ProGetBaseUrl '' -BuildMasterBaseUrl '' -SqlInstancePaths @()
      $entry = $r.Checks.SecretEnvironmentVariables.Present |
        Where-Object Name -eq 'BUILDMASTER_GH_WEBHOOK_SECRET' |
        Select-Object -First 1
      $entry.Scope | Should -Be 'Process'
      ($r | ConvertTo-Json -Depth 6) | Should -Not -Match 'unit-test-secret'
    }
  }

  Context '-ThrowOnFailure switch' {
    BeforeAll {
      $script:savedAdminKey = [System.Environment]::GetEnvironmentVariable('BUILDMASTER_ADMIN_API_KEY', 'Process')
      [System.Environment]::SetEnvironmentVariable('BUILDMASTER_ADMIN_API_KEY', 'unit-test-secret', 'Process')
    }
    AfterAll {
      [System.Environment]::SetEnvironmentVariable('BUILDMASTER_ADMIN_API_KEY', $script:savedAdminKey, 'Process')
    }

    It 'Throws with FullyQualifiedErrorId InfrastructureHealthFailedException when a check fails' {
      try {
        Test-SprintInfrastructureHealth `
          -ProGetBaseUrl '' `
          -BuildMasterBaseUrl '' `
          -SqlInstancePaths @() `
          -ThrowOnFailure
        throw 'Expected Test-SprintInfrastructureHealth to throw a terminating error.'
      } catch {
        $_.FullyQualifiedErrorId | Should -Match '^InfrastructureHealthFailedException'
      }
    }
  }
}

