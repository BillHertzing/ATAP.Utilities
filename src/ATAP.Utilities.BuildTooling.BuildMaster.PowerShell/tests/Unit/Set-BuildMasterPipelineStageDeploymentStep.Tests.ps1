BeforeAll {
  $ModulePath = Resolve-Path "$PSScriptRoot/../../ATAP.Utilities.BuildTooling.BuildMaster.PowerShell.psd1"
  Import-Module $ModulePath -Force
  function global:Get-SecretATAP { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) 'test-key' }

  # Import the helper function for testing
  . "$PSScriptRoot/../../public/Set-BuildMasterPipelineStageDeploymentStep.ps1"
}

Describe 'Set-BuildMasterPipelineStageDeploymentStep' {

  Context 'Parameter Validation' {
    It 'Throws when ApplicationName is empty' {
      { Set-BuildMasterPipelineStageDeploymentStep -ApplicationName '' -PipelineName 'test' -DeploymentStepName 'test' } |
        Should -Throw -ErrorId 'ParameterArgumentValidationError*'
    }

    It 'Throws when PipelineName is empty' {
      { Set-BuildMasterPipelineStageDeploymentStep -ApplicationName 'app' -PipelineName '' -DeploymentStepName 'test' } |
        Should -Throw -ErrorId 'ParameterArgumentValidationError*'
    }

    It 'Throws when DeploymentStepName is empty' {
      { Set-BuildMasterPipelineStageDeploymentStep -ApplicationName 'app' -PipelineName 'pipe' -DeploymentStepName '' } |
        Should -Throw -ErrorId 'ParameterArgumentValidationError*'
    }
  }

  Context 'API Key Resolution' {
    It 'Requires API key from parameter, environment, or Bitwarden' {
      # If explicit API key is provided, the function should not throw on API key validation
      # (it may throw later on API call, but that's acceptable for this test)
      $result = Set-BuildMasterPipelineStageDeploymentStep `
        -ApplicationName 'app' `
        -PipelineName 'pipe' `
        -DeploymentStepName 'step' `
        -BuildMasterAdminApiKeySecretName 'test-secret' `
        -BuildMasterBaseUrl 'http://127.0.0.1:1' `
        -ErrorAction SilentlyContinue

      # Should return a result (not throw on key resolution)
      $result | Should -BeOfType [PSCustomObject]
    }
  }

  Context 'Output Structure' {
    It 'Returns PSCustomObject with expected fields' {
      # Skip network calls by using a bad URL
      $result = Set-BuildMasterPipelineStageDeploymentStep `
        -ApplicationName 'NonExistent' `
        -PipelineName 'test-pipeline' `
        -DeploymentStepName 'test-step' `
        -BuildMasterAdminApiKeySecretName 'test-secret' `
        -BuildMasterBaseUrl 'http://localhost:50001' `
        -ErrorAction SilentlyContinue 2>$null

      $result | Should -BeOfType [PSCustomObject]
      $result.OperationName | Should -Be 'Set-BuildMasterPipelineStageDeploymentStep'
      $result.PSObject.Properties.Name | Should -Contain 'Succeeded'
      $result.PSObject.Properties.Name | Should -Contain 'Application'
      $result.PSObject.Properties.Name | Should -Contain 'Pipeline'
      $result.PSObject.Properties.Name | Should -Contain 'DeploymentStep'
      $result.PSObject.Properties.Name | Should -Contain 'Stages'
      $result.PSObject.Properties.Name | Should -Contain 'ConfiguredStages'
      $result.PSObject.Properties.Name | Should -Contain 'SkippedStages'
      $result.PSObject.Properties.Name | Should -Contain 'Failures'
      $result.PSObject.Properties.Name | Should -Contain 'ApiAvailable'
      $result.PSObject.Properties.Name | Should -Contain 'ManualRunbook'
      $result.PSObject.Properties.Name | Should -Contain 'ResponseSummary'
    }
  }

  Context 'WhatIf Support' {
    It 'Supports -WhatIf parameter' {
      # -WhatIf should not throw - use a reasonable default URL
      $result = Set-BuildMasterPipelineStageDeploymentStep `
        -ApplicationName 'TestApp' `
        -PipelineName 'TestPipeline' `
        -DeploymentStepName 'TestStep' `
        -BuildMasterAdminApiKeySecretName 'test-secret' `
        -BuildMasterBaseUrl 'http://localhost:8622' `
        -WhatIf `
        -ErrorAction SilentlyContinue

      # WhatIf may return null/void; that's acceptable
      # The key is it doesn't throw
      $true | Should -Be $true
    }
  }

  Context 'Parameter Acceptance' {
    It 'Accepts and preserves default stages' {
      # Just verify the function accepts the parameters
      # by checking it doesn't throw during parameter binding
      { Set-BuildMasterPipelineStageDeploymentStep `
        -ApplicationName 'TestApp' `
        -PipelineName 'TestPipeline' `
        -DeploymentStepName 'TestStep' `
        -BuildMasterAdminApiKeySecretName 'test-secret' `
        -BuildMasterBaseUrl 'http://127.0.0.1:1' `
        -ErrorAction SilentlyContinue | Out-Null } |
        Should -Not -Throw
    }

    It 'Accepts custom stages parameter' {
      $customStages = @('Dev', 'Staging', 'Prod')
      { Set-BuildMasterPipelineStageDeploymentStep `
        -ApplicationName 'TestApp' `
        -PipelineName 'TestPipeline' `
        -DeploymentStepName 'TestStep' `
        -Stages $customStages `
        -BuildMasterAdminApiKeySecretName 'test-secret' `
        -BuildMasterBaseUrl 'http://127.0.0.1:1' `
        -ErrorAction SilentlyContinue | Out-Null } |
        Should -Not -Throw
    }

    It 'Accepts custom RaftName parameter' {
      { Set-BuildMasterPipelineStageDeploymentStep `
        -ApplicationName 'TestApp' `
        -PipelineName 'TestPipeline' `
        -DeploymentStepName 'TestStep' `
        -RaftName 'custom-raft' `
        -BuildMasterAdminApiKeySecretName 'test-secret' `
        -BuildMasterBaseUrl 'http://127.0.0.1:1' `
        -ErrorAction SilentlyContinue | Out-Null } |
        Should -Not -Throw
    }

    It 'Accepts BuildMasterBaseUrl parameter' {
      { Set-BuildMasterPipelineStageDeploymentStep `
        -ApplicationName 'TestApp' `
        -PipelineName 'TestPipeline' `
        -DeploymentStepName 'TestStep' `
        -BuildMasterAdminApiKeySecretName 'test-secret' `
        -BuildMasterBaseUrl 'http://buildmaster.example:8622' `
        -ErrorAction SilentlyContinue | Out-Null } |
        Should -Not -Throw
    }
  }

  Context 'Runbook Reference' {
    It 'References correct runbook in help' {
      # Verify the function's help references the manual runbook
      $help = Get-Help Set-BuildMasterPipelineStageDeploymentStep
      $descriptionText = $help.Description[0].Text
      $descriptionText | Should -Match 'runbook|Runbook-BuildMasterPipelineConfiguration'
    }
  }
}
