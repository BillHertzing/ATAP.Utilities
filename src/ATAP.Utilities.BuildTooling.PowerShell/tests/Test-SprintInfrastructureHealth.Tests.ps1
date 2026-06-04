# AI assisted using Powershell.instructions.md as guidelines
# Pester 5+ tests for Test-SprintInfrastructureHealth

BeforeAll {
  Import-Module PSFramework -ErrorAction SilentlyContinue

  # Stubs satisfy the begin-block dot-source guard so the function does not
  # attempt to load helpers from disk during tests.
  if (-not (Get-Command -Name 'Get-ParameterValueFromNeoConfigurationRoot' -CommandType Function -ErrorAction SilentlyContinue)) {
    function Get-ParameterValueFromNeoConfigurationRoot {
      param([string]$ParameterName, $originalPSBoundParameters, [AllowNull()]$DefaultValue = $null, [string]$dottedPath, [hashtable]$Settings)
      if ($originalPSBoundParameters -and $originalPSBoundParameters.ContainsKey($ParameterName)) { return $originalPSBoundParameters[$ParameterName] }
      return $DefaultValue
    }
  }
  Set-Alias -Name Get-PVal -Value Get-ParameterValueFromNeoConfigurationRoot -Scope Global -Force
  if (-not (Get-Command -Name 'Get-RepositoryRoot' -CommandType Function -ErrorAction SilentlyContinue)) {
    function Get-RepositoryRoot { return $null }
  }
  # Stub the secret store so the function resolves the BuildMaster admin API key
  # without contacting Bitwarden.
  function global:Get-SecretATAP {
    param([Parameter(ValueFromPipelineByPropertyName = $true)][Alias('BuildMasterAdminApiKeySecretName')][string]$SecretName, [string]$SecretField = 'password')
    'unit-test-key'
  }

  # Dot-source both functions in the file (Test-InfraUrlReachable + Test-SprintInfrastructureHealth)
  $functionPath = Join-Path $PSScriptRoot '../public/Test-SprintInfrastructureHealth.ps1'
  if (-not (Test-Path $functionPath)) {
    throw "Function file not found: $functionPath"
  }
  . $functionPath

  # Required env var names the function checks
  $script:requiredVars = @(
    'PROGET_ADMIN_API_KEY',
    'BW_SESSION',
    'BUILDMASTER_GH_WEBHOOK_SECRET'
  )
}

Describe 'Test-SprintInfrastructureHealth' {

  It 'function is loaded and discoverable' {
    Get-Command -Name 'Test-SprintInfrastructureHealth' -CommandType Function |
      Should -Not -BeNullOrEmpty
  }

  It 'returns a PSCustomObject with AllOk, Checks, Failures, and Timestamp' {
    $result = Test-SprintInfrastructureHealth -SqlInstancePaths @() -ProGetBaseUrl '' -BuildMasterBaseUrl '' -BuildMasterAdminApiKeySecretName 'BuildMaster.Admin.API.Key'
    $result | Should -Not -BeNullOrEmpty
    $result.PSObject.Properties.Name | Should -Contain 'AllOk'
    $result.PSObject.Properties.Name | Should -Contain 'Checks'
    $result.PSObject.Properties.Name | Should -Contain 'Failures'
    $result.PSObject.Properties.Name | Should -Contain 'Timestamp'
  }

  It 'Timestamp is a DateTime within the last 60 seconds' {
    $result = Test-SprintInfrastructureHealth -SqlInstancePaths @() -ProGetBaseUrl '' -BuildMasterBaseUrl '' -BuildMasterAdminApiKeySecretName 'BuildMaster.Admin.API.Key'
    $result.Timestamp | Should -BeOfType [DateTime]
    $result.Timestamp | Should -BeGreaterThan (Get-Date).AddSeconds(-60)
  }

  Context 'SqlInstances check' {
    It 'is Skipped and Ok when SqlInstancePaths is empty' {
      $result = Test-SprintInfrastructureHealth -SqlInstancePaths @() -ProGetBaseUrl '' -BuildMasterBaseUrl '' -BuildMasterAdminApiKeySecretName 'BuildMaster.Admin.API.Key'
      $result.Checks.SqlInstances.Skipped | Should -BeTrue
      $result.Checks.SqlInstances.Ok | Should -BeTrue
    }
  }

  Context 'ProGetReachable check' {
    It 'is Skipped and Ok when ProGetBaseUrl is empty' {
      $result = Test-SprintInfrastructureHealth -SqlInstancePaths @() -ProGetBaseUrl '' -BuildMasterBaseUrl '' -BuildMasterAdminApiKeySecretName 'BuildMaster.Admin.API.Key'
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
      $result = Test-SprintInfrastructureHealth -SqlInstancePaths @() -ProGetBaseUrl '' -BuildMasterBaseUrl '' -BuildMasterAdminApiKeySecretName 'BuildMaster.Admin.API.Key'
      $result.Checks.BitwardenEnvVars.Ok | Should -BeTrue
    }

    It 'BitwardenEnvVars.Missing is empty when all required vars are set' {
      $result = Test-SprintInfrastructureHealth -SqlInstancePaths @() -ProGetBaseUrl '' -BuildMasterBaseUrl '' -BuildMasterAdminApiKeySecretName 'BuildMaster.Admin.API.Key'
      $result.Checks.BitwardenEnvVars.Missing | Should -BeNullOrEmpty
    }
  }

  Context 'FlywayAvailable and NbgvAvailable checks' {
    It 'FlywayAvailable.Ok is true (found or skipped)' {
      $result = Test-SprintInfrastructureHealth -SqlInstancePaths @() -ProGetBaseUrl '' -BuildMasterBaseUrl '' -BuildMasterAdminApiKeySecretName 'BuildMaster.Admin.API.Key'
      $result.Checks.FlywayAvailable.Ok | Should -BeTrue
    }

    It 'NbgvAvailable.Ok is true (found or skipped)' {
      $result = Test-SprintInfrastructureHealth -SqlInstancePaths @() -ProGetBaseUrl '' -BuildMasterBaseUrl '' -BuildMasterAdminApiKeySecretName 'BuildMaster.Admin.API.Key'
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
          -BuildMasterAdminApiKeySecretName 'BuildMaster.Admin.API.Key' `
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
        -BuildMasterAdminApiKeySecretName 'BuildMaster.Admin.API.Key' `
        -ProGetBaseUrl '' `
        -SqlInstancePaths @()
      $result.Checks.BuildMasterApps.Skipped | Should -BeTrue
      $result.Checks.BuildMasterApps.Ok | Should -BeTrue
    }
  }
}
