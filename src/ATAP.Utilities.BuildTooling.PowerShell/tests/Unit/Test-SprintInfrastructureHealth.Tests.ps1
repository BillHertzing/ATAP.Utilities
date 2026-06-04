#Requires -Version 7.0

BeforeAll {
  Import-Module PSFramework -ErrorAction SilentlyContinue
  $script:publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
  . (Join-Path $script:publicDir 'Test-SprintInfrastructureHealth.ps1')

  # Stub the secret store so the health check resolves the BuildMaster admin API
  # key without contacting Bitwarden.
  function global:Get-SecretATAP {
    param([Parameter(ValueFromPipelineByPropertyName = $true)][Alias('BuildMasterAdminApiKeySecretName')][string]$SecretName, [string]$SecretField = 'password')
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
        'BitwardenEnvVars', 'BuildMasterAdminApiKeyResolvable', 'SqlInstances', 'FlywayAvailable',
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

  Context 'BitwardenEnvVars — missing variable detection' {
    BeforeAll {
      # Clear one required var at BOTH User and Process scope (the check reads
      # User then Process) to deterministically trigger a BitwardenEnvVars
      # failure without disturbing the active BW_SESSION.
      $script:savedWebhookUser = [System.Environment]::GetEnvironmentVariable('BUILDMASTER_GH_WEBHOOK_SECRET', 'User')
      $script:savedWebhookProc = [System.Environment]::GetEnvironmentVariable('BUILDMASTER_GH_WEBHOOK_SECRET', 'Process')
      [System.Environment]::SetEnvironmentVariable('BUILDMASTER_GH_WEBHOOK_SECRET', $null, 'User')
      [System.Environment]::SetEnvironmentVariable('BUILDMASTER_GH_WEBHOOK_SECRET', $null, 'Process')
    }
    AfterAll {
      [System.Environment]::SetEnvironmentVariable('BUILDMASTER_GH_WEBHOOK_SECRET', $script:savedWebhookUser, 'User')
      [System.Environment]::SetEnvironmentVariable('BUILDMASTER_GH_WEBHOOK_SECRET', $script:savedWebhookProc, 'Process')
    }

    It 'Fails BitwardenEnvVars when a required env var is absent at both scopes' {
      $r = Test-SprintInfrastructureHealth -ProGetBaseUrl '' -BuildMasterBaseUrl '' -SqlInstancePaths @()
      # Only assert on BitwardenEnvVars check — other checks may pass or fail independently
      $r.Checks.BitwardenEnvVars.Ok | Should -BeFalse
      $r.Checks.BitwardenEnvVars.Missing.Count | Should -BeGreaterThan 0
      $r.Failures | Should -Contain 'BitwardenEnvVars'
      $r.AllOk | Should -BeFalse
    }

    It 'Reports missing var names in the Missing array' {
      $r = Test-SprintInfrastructureHealth -ProGetBaseUrl '' -BuildMasterBaseUrl '' -SqlInstancePaths @()
      $r.Checks.BitwardenEnvVars.Missing | Should -Not -BeNullOrEmpty
    }
  }

  Context '-ThrowOnFailure switch' {
    BeforeAll {
      # Ensure at least one env var is absent to guarantee a failure
      $script:savedProGet = [System.Environment]::GetEnvironmentVariable('PROGET_ADMIN_API_KEY', 'Process')
      [System.Environment]::SetEnvironmentVariable('PROGET_ADMIN_API_KEY', $null, 'Process')
      $script:savedBwSession = [System.Environment]::GetEnvironmentVariable('BW_SESSION', 'Process')
      [System.Environment]::SetEnvironmentVariable('BW_SESSION', $null, 'Process')
      $script:savedWebhook = [System.Environment]::GetEnvironmentVariable('BUILDMASTER_GH_WEBHOOK_SECRET', 'Process')
      [System.Environment]::SetEnvironmentVariable('BUILDMASTER_GH_WEBHOOK_SECRET', $null, 'Process')
    }
    AfterAll {
      [System.Environment]::SetEnvironmentVariable('PROGET_ADMIN_API_KEY', $script:savedProGet, 'Process')
      [System.Environment]::SetEnvironmentVariable('BW_SESSION', $script:savedBwSession, 'Process')
      [System.Environment]::SetEnvironmentVariable('BUILDMASTER_GH_WEBHOOK_SECRET', $script:savedWebhook, 'Process')
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
