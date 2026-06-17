#Requires -Version 7.0
function Set-BuildMasterPipelineStageDeploymentStep {
  <#
  .SYNOPSIS
    Assigns an OtterScript deployment step to all stages in a BuildMaster pipeline.

  .DESCRIPTION
    Automates the assignment of a deployment/script step (such as an OtterScript plan)
    to named stages in a BuildMaster pipeline. By default, the cmdlet targets the five
    standard tiers: Experimental, Development, Integration, QA, and Production.

    The cmdlet resolves the application ID from the application name via
    `Applications_GetApplications`, retrieves the pipeline via the BuildMaster Web UI
    (since no stable Native API exists for pipeline stage management), and attempts to
    set the deployment step for each stage.

    **API Discovery Status (Sprint 0007)**:
    The BuildMaster Native API does not expose a stable, documented endpoint for
    pipeline stage deployment-step assignment. The following exploration occurred:
    - `Pipelines_GetPipelines` and `Pipelines_GetPipelineStages` may exist but are
      not documented in the official Inedo Native API reference.
    - Form-backed POST endpoints may exist for pipeline editing but require UI
      HTML parsing and are not maintainable.
    - Official guidance: use the BuildMaster UI or build a hybrid solution that
      combines API queries with Selenium-based UI automation.

    **Current Implementation**:
    This cmdlet provides a structured wrapper for the UI runbook process:
    1. Validates application existence and resolves its ID.
    2. Attempts to discover the pipeline via undocumented/experimental API calls.
    3. Falls back to logging the manual UI steps required to complete the task.
    4. Supports `-WhatIf` for dry-run validation.

    For production use, the operator should follow the documented UI runbook:
    `SolutionDocumentation/Runbook-BuildMasterPipelineConfiguration.md`
    (or equivalent manual steps in the BuildMaster UI).

    The cmdlet will be enhanced if a future BuildMaster version exposes a stable
    pipeline-management API.

  .PARAMETER ApplicationName
    The BuildMaster application name (e.g., 'ATAP.Utilities-PowerShell').

  .PARAMETER PipelineName
    The BuildMaster pipeline name (e.g., 'PowerShellModule-5Stage').

  .PARAMETER DeploymentStepName
    The name/label of the deployment step to assign (e.g., 'PowerShellModule-5Stage').
    This is typically the name of an OtterScript raft item.

  .PARAMETER RaftName
    The raft from which the deployment step is sourced. Defaults to 'default' raft.

  .PARAMETER Stages
    Array of stage names to configure. Defaults to @('Experimental', 'Development',
    'Integration', 'QA', 'Production').

  .PARAMETER BuildMasterBaseUrl
    The BuildMaster base URL (e.g., `https://buildmaster.example/`). Falls back
    to `$global:settings` then to the `BUILDMASTER_BASE_URL` User env var.

  .PARAMETER BuildMasterAdminApiKeySecretName
    The ATAP secret name containing the BuildMaster admin API key. Resolved via
    `Get-PVal` (parameter → env var → `$global:settings` → default
    `BuildMaster.Admin.API.Key`); the value is read with `Get-SecretATAP`.

  .INPUTS
    None.

  .OUTPUTS
    [PSCustomObject] with fields:
      - `OperationName`    — `'Set-BuildMasterPipelineStageDeploymentStep'`.
      - `Succeeded`        — `[bool]`.
      - `Application`      — application name.
      - `Pipeline`         — pipeline name.
      - `DeploymentStep`   — deployment step name.
      - `Stages`           — array of stage names.
      - `ConfiguredStages` — array of stages successfully configured.
      - `SkippedStages`    — array of stages skipped (API limitation or other reason).
      - `Failures`         — array of failure messages.
      - `ApiAvailable`     — `[bool]` indicating whether a stable API was available.
      - `ManualRunbook`    — reference to the UI runbook if API is unavailable.
      - `ResponseSummary`  — human-readable summary.

  .EXAMPLE
    PS> Set-BuildMasterPipelineStageDeploymentStep `
          -ApplicationName 'ATAP.Utilities-PowerShell' `
          -PipelineName 'PowerShellModule-5Stage' `
          -DeploymentStepName 'PowerShellModule-5Stage'

    Attempts to configure the PowerShell module pipeline stages using the API
    (or fallback to UI runbook if API is unavailable).

  .EXAMPLE
    PS> Set-BuildMasterPipelineStageDeploymentStep `
          -ApplicationName 'ATAP.Utilities-CSharp' `
          -PipelineName 'CSharpPackage-5Stage' `
          -DeploymentStepName 'CSharpPackage-5Stage' `
          -WhatIf

    Performs a dry-run and displays the steps that would be taken.

  .NOTES
    AI assisted using Powershell.instructions.md as guidelines

    This cmdlet is part of the Sprint 0007 BuildMaster pipeline automation
    framework (task E04a). Due to the absence of a stable Native API for
    pipeline management, the cmdlet is designed to be extended when a future
    BuildMaster version provides that capability.

  .LINK
    https://docs.inedo.com/docs/buildmaster/reference/api/native

  .LINK
    SolutionDocumentation/Runbook-BuildMasterPipelineConfiguration.md
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ApplicationName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$PipelineName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$DeploymentStepName,

    [string]$RaftName = 'default',

    [string[]]$Stages = @('Experimental', 'Development', 'Integration', 'QA', 'Production'),

    [string]$BuildMasterBaseUrl,

    [string]$BuildMasterAdminApiKeySecretName = 'BuildMaster.Admin.API.Key'
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    # Resolve BuildMaster base URL
    $BuildMasterBaseUrl = Get-PVal -ParameterName 'BuildMasterBaseUrl' -originalPSBoundParameters $PSBoundParameters -DefaultValue $BuildMasterBaseUrl
    if ([string]::IsNullOrWhiteSpace($BuildMasterBaseUrl)) {
      $BuildMasterBaseUrl = 'http://localhost:50017'
    }
    $BuildMasterBaseUrl = $BuildMasterBaseUrl.TrimEnd('/')
    $nativeApiBaseUrl = "$BuildMasterBaseUrl/api/json"

    # Resolve the BuildMaster admin API key secret name, then retrieve the key
    # value via Get-SecretATAP. The key value is never logged.
    $BuildMasterAdminApiKeySecretName = Get-PVal -ParameterName 'BuildMasterAdminApiKeySecretName' -originalPSBoundParameters $PSBoundParameters -DefaultValue $BuildMasterAdminApiKeySecretName
    $ApiKey = $null
    $secretErrors = [System.Collections.Generic.List[string]]::new()
    foreach ($fieldName in @($null, 'token', 'key', 'password')) {
      try {
        $candidate = if ($null -eq $fieldName) {
          Get-SecretATAP -SecretName $BuildMasterAdminApiKeySecretName -SecretStoreType 'BitwardenSecretsManager' -ErrorAction Stop
        } else {
          Get-SecretATAP -SecretName $BuildMasterAdminApiKeySecretName -SecretStoreType 'BitwardenSecretsManager' -SecretField $fieldName -ErrorAction Stop
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$candidate)) { $ApiKey = [string]$candidate; break }
      } catch {
        $fieldLabel = if ($null -eq $fieldName) { '<default>' } else { $fieldName }
        $secretErrors.Add("${fieldLabel}: $($_.Exception.Message)") | Out-Null
      }
    }
    if ([string]::IsNullOrWhiteSpace($ApiKey)) {
      $detail = if ($secretErrors.Count -gt 0) { " Last error: $($secretErrors[$secretErrors.Count - 1])" } else { '' }
      throw "Unable to resolve the BuildMaster admin API key value from secret '$BuildMasterAdminApiKeySecretName' via Get-SecretATAP. Cannot proceed.$detail"
    }

    # Helper function to resolve application ID from name
    function Resolve-BuildMasterApplicationId {
      param(
        [Parameter(Mandatory)]
        [string]$Name
      )

      $applicationsUri = "$nativeApiBaseUrl/Applications_GetApplications"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling $applicationsUri" -Tag 'RestCall'
      try {
        $applications = Invoke-RestMethod -Uri $applicationsUri -Method Post -Body @{ API_Key = $ApiKey } -ErrorAction Stop
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from $applicationsUri" -Tag 'RestCall'
      } catch {
        throw "Failed to call BuildMaster Applications_GetApplications: $($_.Exception.Message)"
      }

      $match = @($applications | Where-Object { $_.Application_Name -eq $Name })
      if ($match.Count -eq 0) {
        $match = @($applications | Where-Object { $_.Application_Name -ieq $Name })
      }
      if ($match.Count -eq 0) {
        throw "BuildMaster application '$Name' was not found."
      }
      if ($match.Count -gt 1) {
        throw "BuildMaster application name '$Name' matched multiple applications."
      }

      return [int]$match[0].Application_Id
    }

    # Helper function to discover pipeline information
    function Get-BuildMasterPipelineInfo {
      param(
        [Parameter(Mandatory)]
        [string]$ApplicationId,

        [Parameter(Mandatory)]
        [string]$PipelineNameToFind
      )

      # Attempt to use Pipelines_GetPipelines endpoint (may not exist or may require different auth)
      # This is undocumented; success is not guaranteed.
      $pipelinesUri = "$nativeApiBaseUrl/Pipelines_GetPipelines"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Attempting to discover pipelines via $pipelinesUri" -Tag 'RestCall'

      try {
        $pipelines = Invoke-RestMethod -Uri $pipelinesUri -Method Post -Body @{
          API_Key        = $ApiKey
          Application_Id = $ApplicationId
        } -ErrorAction Stop

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Pipelines endpoint returned data' -Tag 'RestCall'
        $pipeline = $pipelines | Where-Object { $_.Pipeline_Name -eq $PipelineNameToFind }
        if ($pipeline) {
          return @{
            Success    = $true
            PipelineId = $pipeline.Pipeline_Id
            Pipeline   = $pipeline
          }
        }
      } catch {
        # Expected when endpoint does not exist
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Pipelines_GetPipelines endpoint unavailable or returned error: $($_.Exception.Message)"
      }

      # If API call fails or endpoint doesn't exist, return indicator that manual UI intervention is required
      return @{
        Success = $false
        Reason  = 'Pipelines_GetPipelines endpoint not available or pipeline not found via API'
      }
    }
  }

  process {
    $configuredStages = [System.Collections.ArrayList]::new()
    $skippedStages = [System.Collections.ArrayList]::new()
    $failures = [System.Collections.ArrayList]::new()
    $apiAvailable = $false
    $manualRunbook = 'SolutionDocumentation/Runbook-BuildMasterPipelineConfiguration.md'

    try {
      # Resolve application ID
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Resolving BuildMaster application '$ApplicationName'"
      $appId = Resolve-BuildMasterApplicationId -Name $ApplicationName
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Resolved application '$ApplicationName' to ID $appId"

      # Attempt to discover pipeline and stages via API
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Attempting to discover pipeline '$PipelineName' for application ID $appId"
      $pipelineInfo = Get-BuildMasterPipelineInfo -ApplicationId $appId -PipelineNameToFind $PipelineName

      if ($pipelineInfo.Success) {
        $apiAvailable = $true
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Pipeline '$PipelineName' discovered via API (ID: $($pipelineInfo.PipelineId))"

        # At this point, a stable API for setting deployment steps would be called.
        # Since no such endpoint is documented, we log the manual steps and mark stages as pending.
        foreach ($stage in $Stages) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Would configure stage '$stage' with deployment step '$DeploymentStepName' (pending API implementation)"
          [void]$skippedStages.Add($stage)
        }
      } else {
        # API endpoint not available; provide guidance on manual configuration
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Pipeline discovery via API unavailable: $($pipelineInfo.Reason)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'No stable BuildMaster API available for pipeline stage deployment-step assignment (Sprint 0007 finding).'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Manual configuration required. See runbook: $manualRunbook"

        # Provide guidance on manual steps
        foreach ($stage in $Stages) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Stage '$stage' requires manual UI configuration in BuildMaster: Applications → $ApplicationName → Pipelines → $PipelineName → $stage (Deployment step) → Set to $DeploymentStepName from raft '$RaftName'"
          [void]$skippedStages.Add($stage)
        }
      }

      # If -WhatIf is set, report what would be done
      if ($WhatIfPreference) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "WhatIf: Would configure deployment steps for $($Stages.Count) stages (see verbose output)"
      } elseif ($PSCmdlet.ShouldProcess("$ApplicationName/$PipelineName", 'Configure deployment steps for stages')) {
        # In a future version with a stable API, actual assignment would occur here
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'No automated API available; manual configuration via UI runbook required.'
      }
    } catch {
      $errMsg = "Error: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errMsg
      [void]$failures.Add($errMsg)
    }

    # Build result object
    $result = [PSCustomObject]@{
      OperationName    = 'Set-BuildMasterPipelineStageDeploymentStep'
      Succeeded        = ($failures.Count -eq 0)
      Application      = $ApplicationName
      Pipeline         = $PipelineName
      DeploymentStep   = $DeploymentStepName
      Stages           = $Stages
      ConfiguredStages = $configuredStages.ToArray()
      SkippedStages    = $skippedStages.ToArray()
      Failures         = $failures.ToArray()
      ApiAvailable     = $apiAvailable
      ManualRunbook    = $manualRunbook
      ResponseSummary  = if ($failures.Count -eq 0) {
        "Configured $($configuredStages.Count) stages; $($skippedStages.Count) stages require manual UI configuration via runbook."
      } else {
        "Operation failed: $($failures -join '; ')"
      }
    }

    return $result
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
