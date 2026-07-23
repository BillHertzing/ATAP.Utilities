# AI assisted using Powershell.instructions.md as guidelines
# Pester 5+ tests for Test-SprintInfrastructureHealth

BeforeAll {
  Import-Module PSFramework -ErrorAction SilentlyContinue

  if (-not (Get-Command -Name 'Get-RepositoryRoot' -CommandType Function -ErrorAction SilentlyContinue)) {
    function Get-RepositoryRoot { return $null }
  }
  # Stub the secret store so the function retrieves the BuildMaster admin API key
  # without contacting Bitwarden. Records the SecretField and SecretStoreType
  # passed by the caller.
  $script:lastSecretField = $null
  $script:lastSecretStoreType = $null
  function global:Get-SecretATAP {
    param([string]$SecretName, [string]$SecretField = 'password', [string]$SecretStoreType)
    $script:lastSecretField = $SecretField
    $script:lastSecretStoreType = $SecretStoreType
    'unit-test-key'
  }

  # Dot-source both functions in the file (Test-InfraUrlReachable + Test-SprintInfrastructureHealth)
  $functionPath = Join-Path $PSScriptRoot '../public/Test-SprintInfrastructureHealth.ps1'
  if (-not (Test-Path $functionPath)) {
    throw "Function file not found: $functionPath"
  }
  . $functionPath

  # Required env var names the function checks. BW_SESSION is deliberately
  # absent (SC-0175): sprint automation uses bws + machine access token.
  $script:requiredVars = @(
    'PROGET_ADMIN_API_KEY',
    'BUILDMASTER_GH_WEBHOOK_SECRET'
  )
}

Describe 'Test-SprintInfrastructureHealth' {

  It 'function is loaded and discoverable' {
    Get-Command -Name 'Test-SprintInfrastructureHealth' -CommandType Function |
      Should -Not -BeNullOrEmpty
  }

  It 'returns a PSCustomObject with AllOk, Checks, Failures, and Timestamp' {
    $result = Test-SprintInfrastructureHealth -SqlInstancePaths @() -ProGetBaseUrl '' -BuildMasterBaseUrl '' -BuildMasterAdminApiKeySecretName 'BuildMaster.Admin.API.Key.utat01'
    $result | Should -Not -BeNullOrEmpty
    $result.PSObject.Properties.Name | Should -Contain 'AllOk'
    $result.PSObject.Properties.Name | Should -Contain 'Checks'
    $result.PSObject.Properties.Name | Should -Contain 'Failures'
    $result.PSObject.Properties.Name | Should -Contain 'Timestamp'
  }

  It 'Timestamp is a DateTime within the last 60 seconds' {
    $result = Test-SprintInfrastructureHealth -SqlInstancePaths @() -ProGetBaseUrl '' -BuildMasterBaseUrl '' -BuildMasterAdminApiKeySecretName 'BuildMaster.Admin.API.Key.utat01'
    $result.Timestamp | Should -BeOfType [DateTime]
    $result.Timestamp | Should -BeGreaterThan (Get-Date).AddSeconds(-60)
  }

  Context 'SqlInstances check' {
    It 'is Skipped and Ok when SqlInstancePaths is empty' {
      $result = Test-SprintInfrastructureHealth -SqlInstancePaths @() -ProGetBaseUrl '' -BuildMasterBaseUrl '' -BuildMasterAdminApiKeySecretName 'BuildMaster.Admin.API.Key.utat01'
      $result.Checks.SqlInstances.Skipped | Should -BeTrue
      $result.Checks.SqlInstances.Ok | Should -BeTrue
    }
  }

  Context 'ProGetReachable check' {
    It 'is Skipped and Ok when ProGetBaseUrl is empty' {
      $result = Test-SprintInfrastructureHealth -SqlInstancePaths @() -ProGetBaseUrl '' -BuildMasterBaseUrl '' -BuildMasterAdminApiKeySecretName 'BuildMaster.Admin.API.Key.utat01'
      $result.Checks.ProGetReachable.Skipped | Should -BeTrue
      $result.Checks.ProGetReachable.Ok | Should -BeTrue
    }
  }

  Context 'BitwardenEnvVars check — env vars present at Process scope' {
    BeforeEach {
      $script:savedVars = @{}
      foreach ($v in $script:requiredVars) {
        $script:savedVars[$v] = [System.Environment]::GetEnvironmentVariable($v, 'Process')
        [System.Environment]::SetEnvironmentVariable($v, "test-value-$v", 'Process')
      }
    }

    AfterEach {
      foreach ($v in $script:requiredVars) {
        [System.Environment]::SetEnvironmentVariable($v, $script:savedVars[$v], 'Process')
      }
    }

    It 'BitwardenEnvVars.Ok is true when all required vars are set' {
      $result = Test-SprintInfrastructureHealth -SqlInstancePaths @() -ProGetBaseUrl '' -BuildMasterBaseUrl '' -BuildMasterAdminApiKeySecretName 'BuildMaster.Admin.API.Key.utat01'
      $result.Checks.BitwardenEnvVars.Ok | Should -BeTrue
    }

    It 'BitwardenEnvVars.Missing is empty when all required vars are set' {
      $result = Test-SprintInfrastructureHealth -SqlInstancePaths @() -ProGetBaseUrl '' -BuildMasterBaseUrl '' -BuildMasterAdminApiKeySecretName 'BuildMaster.Admin.API.Key.utat01'
      $result.Checks.BitwardenEnvVars.Missing | Should -BeNullOrEmpty
    }
  }

  Context 'FlywayAvailable and NbgvAvailable checks' {
    It 'FlywayAvailable.Ok is true (found or skipped)' {
      $result = Test-SprintInfrastructureHealth -SqlInstancePaths @() -ProGetBaseUrl '' -BuildMasterBaseUrl '' -BuildMasterAdminApiKeySecretName 'BuildMaster.Admin.API.Key.utat01'
      $result.Checks.FlywayAvailable.Ok | Should -BeTrue
    }

    It 'NbgvAvailable.Ok is true (found or skipped)' {
      $result = Test-SprintInfrastructureHealth -SqlInstancePaths @() -ProGetBaseUrl '' -BuildMasterBaseUrl '' -BuildMasterAdminApiKeySecretName 'BuildMaster.Admin.API.Key.utat01'
      $result.Checks.NbgvAvailable.Ok | Should -BeTrue
    }
  }

  Context 'ThrowOnFailure' {
    It 'throws a terminating error with InfrastructureHealthFailedException when AllOk is false' {
      # Port 1 on loopback is reserved and connection-refused almost instantly.
      # BuildMasterApps (REST call) and BuildMasterReachable (HTTP HEAD) both fail,
      # ensuring AllOk=$false regardless of env var state.
      $threw = $false
      $errorId = $null
      try {
        Test-SprintInfrastructureHealth `
          -BuildMasterBaseUrl 'http://127.0.0.1:1' `
          -BuildMasterAdminApiKeySecretName 'BuildMaster.Admin.API.Key.utat01' `
          -ProGetBaseUrl '' `
          -SqlInstancePaths @() `
          -ReachabilityTimeoutSeconds 1 `
          -ThrowOnFailure
      } catch {
        $threw = $true
        $errorId = $_.FullyQualifiedErrorId
      }
      $threw | Should -BeTrue
      $errorId | Should -Match 'InfrastructureHealthFailedException'
    }
  }

  Context 'BuildMasterApps check' {
    It 'BuildMasterApps is Skipped and Ok when BuildMasterBaseUrl is empty' {
      $result = Test-SprintInfrastructureHealth `
        -BuildMasterBaseUrl '' `
        -BuildMasterAdminApiKeySecretName 'BuildMaster.Admin.API.Key.utat01' `
        -ProGetBaseUrl '' `
        -SqlInstancePaths @()
      $result.Checks.BuildMasterApps.Skipped | Should -BeTrue
      $result.Checks.BuildMasterApps.Ok | Should -BeTrue
    }
  }

  Context 'BuildMaster admin API key resolution' {
    It 'calls Get-SecretATAP with SecretField notes to retrieve the BuildMaster admin API key' {
      $script:lastSecretField = $null
      Test-SprintInfrastructureHealth `
        -BuildMasterBaseUrl '' `
        -BuildMasterAdminApiKeySecretName 'BuildMaster.Admin.API.Key.utat01' `
        -ProGetBaseUrl '' `
        -SqlInstancePaths @() | Out-Null
      $script:lastSecretField | Should -Be 'notes'
    }

    It 'calls Get-SecretATAP with SecretStoreType BitwardenSecretsManager (no BW_SESSION dependency, SC-0175)' {
      $script:lastSecretStoreType = $null
      Test-SprintInfrastructureHealth `
        -BuildMasterBaseUrl '' `
        -BuildMasterAdminApiKeySecretName 'BuildMaster.Admin.API.Key.utat01' `
        -ProGetBaseUrl '' `
        -SqlInstancePaths @() | Out-Null
      $script:lastSecretStoreType | Should -Be 'BitwardenSecretsManager'
    }

    It 'does not require BW_SESSION in the BitwardenEnvVars check' {
      $result = Test-SprintInfrastructureHealth `
        -BuildMasterBaseUrl '' `
        -BuildMasterAdminApiKeySecretName 'BuildMaster.Admin.API.Key.utat01' `
        -ProGetBaseUrl '' `
        -SqlInstancePaths @()
      $result.Checks.BitwardenEnvVars.Missing | Should -Not -Contain 'BW_SESSION'
    }

    It 'BuildMasterAdminApiKeyResolvable.Ok is true when Get-SecretATAP returns a value' {
      $result = Test-SprintInfrastructureHealth `
        -BuildMasterBaseUrl '' `
        -BuildMasterAdminApiKeySecretName 'BuildMaster.Admin.API.Key.utat01' `
        -ProGetBaseUrl '' `
        -SqlInstancePaths @()
      $result.Checks.BuildMasterAdminApiKeyResolvable.Ok | Should -BeTrue
    }
  }

  Context 'GitSafeDirectory check (Task 12.35)' {
    # safe.directory is multi-valued and stored with forward slashes on Windows.
    # These tests mock git so the assertions do not depend on the machine's real
    # global git config, and mock Get-RepositoryRoot so we control the compared root.
    It 'Ok is true when the (absolute) repo root is present in safe.directory' {
      Mock -CommandName git -MockWith {
        'C:/repos/RepoA'
        'C:/repos/RepoB-wt-1'
      } -ParameterFilter { $args -contains 'safe.directory' }
      Mock -CommandName Get-RepositoryRoot -MockWith { 'C:/repos/RepoB-wt-1' }

      $result = Test-SprintInfrastructureHealth -SqlInstancePaths @() -ProGetBaseUrl '' -BuildMasterBaseUrl ''
      $result.Checks.GitSafeDirectory.Ok | Should -BeTrue
      $result.Checks.GitSafeDirectory.Detail | Should -Match 'contains repo root'
    }

    It 'regression: an absolute worktree root still matches (no false failure like the pre-fix relative path)' {
      # Pre-fix, Get-RepositoryRoot returned a relative '..\RepoB-wt-1' that never
      # matched the absolute safe.directory entries. The fix returns the absolute root.
      Mock -CommandName git -MockWith {
        'C:/repos/RepoA'
        'C:/repos/RepoB-wt-1'
      } -ParameterFilter { $args -contains 'safe.directory' }
      Mock -CommandName Get-RepositoryRoot -MockWith { 'C:\repos\RepoB-wt-1' }

      $result = Test-SprintInfrastructureHealth -SqlInstancePaths @() -ProGetBaseUrl '' -BuildMasterBaseUrl ''
      $result.Checks.GitSafeDirectory.Ok | Should -BeTrue
    }

    It 'Ok is false when the repo root is NOT present in safe.directory' {
      Mock -CommandName git -MockWith {
        'C:/repos/RepoA'
      } -ParameterFilter { $args -contains 'safe.directory' }
      Mock -CommandName Get-RepositoryRoot -MockWith { 'C:/repos/RepoUnregistered' }

      $result = Test-SprintInfrastructureHealth -SqlInstancePaths @() -ProGetBaseUrl '' -BuildMasterBaseUrl ''
      $result.Checks.GitSafeDirectory.Ok | Should -BeFalse
      $result.Checks.GitSafeDirectory.Detail | Should -Match 'does not include repo root'
    }
  }
}


