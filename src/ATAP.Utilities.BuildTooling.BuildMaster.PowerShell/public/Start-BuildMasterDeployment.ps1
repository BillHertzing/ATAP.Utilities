#Requires -Version 7.0
function Start-BuildMasterDeployment {
  <#
.SYNOPSIS
    Starts a BuildMaster deployment for an existing build.

.DESCRIPTION
    Calls BuildMaster's Release & Build Deployment API
    `POST /api/releases/builds/deploy` to start deployment of an existing
    build. When `-ToStage` is omitted BuildMaster chooses the next stage in
    the release pipeline; the package pipeline wrapper supplies its starting
    tier so newly queued builds begin at the expected first stage.

.PARAMETER Application
    The BuildMaster application name.

.PARAMETER ReleaseNumber
    The release number containing the build.

.PARAMETER BuildNumber
    The BuildMaster build number to deploy.

.PARAMETER ToStage
    Optional target stage. If omitted, BuildMaster deploys to the next stage.

.PARAMETER Force
    Optional. Passes `force=true` to BuildMaster.

.PARAMETER Variables
    Optional deployment-scope variables. Keys may be supplied with or without
    a leading `$`; they are sent with the `$` prefix required by BuildMaster.

.PARAMETER BuildMasterBaseUrl
    The BuildMaster base URL. Falls back to `$global:settings` then to the
    `BUILDMASTER_BASE_URL` env var.

.PARAMETER BuildMasterAdminApiKeySecretName
    The ATAP secret name containing the BuildMaster admin API key. Falls back
    to the `BuildMasterAdminApiKeySecretName` environment variable, then to
    `$global:settings`.

.OUTPUTS
    [PSCustomObject] summarizing the deployment API result.
#>
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Application,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ReleaseNumber,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$BuildNumber,

    [Parameter(Mandatory = $false)]
    [string]$ToStage,

    [Parameter(Mandatory = $false)]
    [switch]$Force,

    [Parameter(Mandatory = $false)]
    [hashtable]$Variables,

    [Parameter(Mandatory = $false)]
    [string]$BuildMasterBaseUrl,

    [Parameter(Mandatory = $false)]
    [string]$BuildMasterAdminApiKeySecretName
  )

  begin {
    $fn = 'Start-BuildMasterDeployment'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn (Application='$Application' ReleaseNumber='$ReleaseNumber' BuildNumber='$BuildNumber' ToStage='$ToStage')" -Tag 'Trace'

    $BuildMasterBaseUrl = Get-PVal -ParameterName 'BuildMasterBaseUrl' -originalPSBoundParameters $PSBoundParameters -DefaultValue $BuildMasterBaseUrl
    if ([string]::IsNullOrWhiteSpace($BuildMasterBaseUrl)) {
      $BuildMasterBaseUrl = [System.Environment]::GetEnvironmentVariable('BUILDMASTER_BASE_URL', 'Process')
    }
    if ([string]::IsNullOrWhiteSpace($BuildMasterBaseUrl)) {
      $BuildMasterBaseUrl = [System.Environment]::GetEnvironmentVariable('BUILDMASTER_BASE_URL', 'User')
    }
    if ([string]::IsNullOrWhiteSpace($BuildMasterBaseUrl)) {
      $BuildMasterBaseUrl = 'https://utat022:50017'
    }
    $BuildMasterBaseUrl = $BuildMasterBaseUrl.TrimEnd('/')
  }

  process {
    $resolvedSecretName = $BuildMasterAdminApiKeySecretName
    if ([string]::IsNullOrWhiteSpace($resolvedSecretName)) {
      $resolvedSecretName = [Environment]::GetEnvironmentVariable('BuildMasterAdminApiKeySecretName', 'Process')
      if ([string]::IsNullOrWhiteSpace($resolvedSecretName)) {
        $resolvedSecretName = [Environment]::GetEnvironmentVariable('BuildMasterAdminApiKeySecretName', 'User')
      }
    }
    if ([string]::IsNullOrWhiteSpace($resolvedSecretName) -and $null -ne $global:settings) {
      $settingsKey = $null
      if ($null -ne $global:configRootKeys) {
        $settingsKey = $global:configRootKeys['BuildMasterAdminApiKeySecretNameConfigRootKey']
      }
      if ([string]::IsNullOrWhiteSpace($settingsKey)) { $settingsKey = 'BuildMasterAdminApiKeySecretName' }
      $resolvedSecretName = [string]$global:settings[$settingsKey]
    }
    if ([string]::IsNullOrWhiteSpace($resolvedSecretName)) {
      $msg = "Unable to resolve BuildMaster admin API key secret name. Pass -BuildMasterAdminApiKeySecretName, set the BuildMasterAdminApiKeySecretName environment variable, or set `$global:settings.BuildMasterAdminApiKeySecretName."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }

    $resolvedApiKey = $null
    $secretErrors = [System.Collections.Generic.List[string]]::new()
    foreach ($fieldName in @($null, 'token', 'key', 'password')) {
      try {
        $candidate = if ($null -eq $fieldName) {
          Get-SecretATAP -SecretName $resolvedSecretName -SecretStoreType 'BitwardenSecretsManager' -ErrorAction Stop
        } else {
          Get-SecretATAP -SecretName $resolvedSecretName -SecretStoreType 'BitwardenSecretsManager' -SecretField $fieldName -ErrorAction Stop
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$candidate)) {
          $resolvedApiKey = [string]$candidate
          break
        }
      } catch {
        $fieldLabel = if ($null -eq $fieldName) { '<default>' } else { $fieldName }
        $secretErrors.Add("${fieldLabel}: $($_.Exception.Message)") | Out-Null
      }
    }
    if ([string]::IsNullOrWhiteSpace($resolvedApiKey)) {
      $detail = if ($secretErrors.Count -gt 0) { " Last error: $($secretErrors[$secretErrors.Count - 1])" } else { '' }
      $msg = "Unable to resolve BuildMaster admin API key value from secret '$resolvedSecretName' via Get-SecretATAP.$detail"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }

    $uri = '{0}/api/releases/builds/deploy' -f $BuildMasterBaseUrl
    $headers = @{ 'X-ApiKey' = $resolvedApiKey }
    $payload = @{
      applicationName = $Application
      releaseNumber   = $ReleaseNumber
      buildNumber     = $BuildNumber
    }
    if (-not [string]::IsNullOrWhiteSpace($ToStage)) {
      $payload['toStage'] = $ToStage
    }
    if ($Force.IsPresent) {
      $payload['force'] = $true
    }
    if ($null -ne $Variables) {
      foreach ($key in $Variables.Keys) {
        $variableName = [string]$key
        if ([string]::IsNullOrWhiteSpace($variableName)) {
          throw 'BuildMaster deployment variable names must not be empty.'
        }
        if (-not $variableName.StartsWith('$')) {
          $variableName = '$' + $variableName
        }
        $payload[$variableName] = $Variables[$key]
      }
    }
    $body = $payload | ConvertTo-Json -Depth 5

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "POST $uri (ApiKey='***')" -Tag 'RestCall'

    $targetStageText = if ([string]::IsNullOrWhiteSpace($ToStage)) { 'next stage' } else { "stage '$ToStage'" }
    $target = "BuildMaster deployment of build '$BuildNumber' for '$Application'/'$ReleaseNumber' to $targetStageText"
    if (-not $PSCmdlet.ShouldProcess($target, 'Deploy')) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "WhatIf: would POST to $uri"
      return [PSCustomObject]@{
        OperationName   = 'Start-BuildMasterDeployment'
        Succeeded       = $false
        Application     = $Application
        ReleaseNumber   = $ReleaseNumber
        BuildNumber     = $BuildNumber
        ToStage         = $ToStage
        DeploymentId    = $null
        DeploymentState = $null
        ResponseSummary = "WhatIf: planned deployment of $target"
      }
    }

    $deploymentId = $null
    $deploymentState = $null
    try {
      $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType 'application/json' -Body $body -TimeoutSec 30
      if ($null -ne $response) {
        if ($null -ne $response.id)                 { $deploymentId = [string]$response.id }
        elseif ($null -ne $response.deploymentId)   { $deploymentId = [string]$response.deploymentId }
        elseif ($null -ne $response.DeploymentId)   { $deploymentId = [string]$response.DeploymentId }

        if ($null -ne $response.status)             { $deploymentState = [string]$response.status }
        elseif ($null -ne $response.state)          { $deploymentState = [string]$response.state }
        elseif ($null -ne $response.DeploymentState) { $deploymentState = [string]$response.DeploymentState }
      }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Started BuildMaster deployment id='$deploymentId' state='$deploymentState' for '$Application'/'$ReleaseNumber' build '$BuildNumber'" -Tag 'RestCall'
    } catch {
      $statusCode = $null
      try {
        if ($null -ne $_.Exception.Response) {
          $statusCode = [int]$_.Exception.Response.StatusCode
        }
      } catch {
        $statusCode = $null
      }
      if ($statusCode -eq 401 -or $statusCode -eq 403) {
        $msg = "BuildMaster authentication failed (HTTP $statusCode) for $uri. Check the secret named by BuildMasterAdminApiKeySecretName."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'RestCall'
        throw $msg
      }
      $msg = "POST $uri failed: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'RestCall'
      throw $msg
    }

    $summary = "deployment started"
    if (-not [string]::IsNullOrWhiteSpace($deploymentId)) {
      $summary += ": id='$deploymentId'"
    }
    if (-not [string]::IsNullOrWhiteSpace($deploymentState)) {
      $summary += " state='$deploymentState'"
    }

    return [PSCustomObject]@{
      OperationName   = 'Start-BuildMasterDeployment'
      Succeeded       = $true
      Application     = $Application
      ReleaseNumber   = $ReleaseNumber
      BuildNumber     = $BuildNumber
      ToStage         = $ToStage
      DeploymentId    = $deploymentId
      DeploymentState = $deploymentState
      ResponseSummary = $summary
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving $fn" -Tag 'Trace'
  }
}
