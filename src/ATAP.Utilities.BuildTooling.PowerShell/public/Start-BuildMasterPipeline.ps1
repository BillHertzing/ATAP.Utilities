#Requires -Version 7.0
function Start-BuildMasterPipeline {
  <#
.SYNOPSIS
    Triggers a BuildMaster build for an existing Application + Release.

.DESCRIPTION
    Calls BuildMaster's Native API `POST /api/releases/builds/create` to
    queue a new build for the specified `(Application, ReleaseNumber)`
    pair. The pipeline used for the build is the release's currently
    configured pipeline unless `-Pipeline` overrides it. `-Reason` is
    forwarded to BuildMaster as the build's `Reason` field for audit
    purposes.

    The base URL and API key are resolved with the same precedence as
    `New-BuildMasterRelease`:

      1. Explicit parameter.
      2. `$global:settings[$global:configRootKeys['…ConfigRootKey']]`.
      3. Process / User-scope env var (`BUILDMASTER_BASE_URL`,
         `BUILDMASTER_ADMIN_API_KEY`).

    The API key value is never logged. Every external call is logged
    via PSFramework at the `Debug` level.

.PARAMETER Application
    The BuildMaster application name.

.PARAMETER ReleaseNumber
    The release number for which a build is to be triggered.

.PARAMETER Pipeline
    Optional. The pipeline name to run. If omitted, the release's
    configured pipeline is used.

.PARAMETER Reason
    Optional human-readable reason. Forwarded as the build's `Reason`
    field.

.PARAMETER BuildMasterBaseUrl
    The BuildMaster base URL. Falls back to `$global:settings` then to
    the `BUILDMASTER_BASE_URL` User env var.

.PARAMETER ApiKey
    The BuildMaster admin API key. Falls back to `$global:settings` then
    to the `BUILDMASTER_ADMIN_API_KEY` User env var.

.INPUTS
    None.

.OUTPUTS
    [PSCustomObject] with fields:
      - `OperationName`     — `'Start-BuildMasterPipeline'`.
      - `Succeeded`         — `[bool]`.
      - `Application`       — pass-through.
      - `ReleaseNumber`     — pass-through.
      - `Pipeline`          — pass-through.
      - `BuildId`           — the new BuildMaster build ID.
      - `BuildNumber`       — the new BuildMaster build number (when surfaced).
      - `ResponseSummary`   — short human-readable summary.

.EXAMPLE
    PS> Start-BuildMasterPipeline -Application 'AceCommander' `
                                 -ReleaseNumber '0.1.0-Sprint.42' `
                                 -Reason 'Manual trigger from sprint demo'

.NOTES
    AI assisted using Powershell.instructions.md as guidelines.
    Implements task H4 of Plan-DocsUpdateForImmutablePackages_V3.md.

.LINK
    https://docs.inedo.com/docs/buildmaster-reference-api
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

    [Parameter(Mandatory = $false)]
    [string]$Pipeline,

    [Parameter(Mandatory = $false)]
    [string]$Reason,

    [Parameter(Mandatory = $false)]
    [string]$BuildMasterBaseUrl,

    [Parameter(Mandatory = $false)]
    [string]$ApiKey
  )

  begin {
    $fn = 'Start-BuildMasterPipeline'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn (Application='$Application' ReleaseNumber='$ReleaseNumber' Pipeline='$Pipeline')" -Tag 'Trace'

    # Load Helpers
    try {
      # ToDo: Remove this when packaging works
      if (-not (Get-Command -Name 'Get-ParameterValueFromNeoConfigurationRoot' -CommandType Function -ErrorAction SilentlyContinue)) {
        . "C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\Get-ParameterValueFromNeoConfigurationRoot.ps1"
      }
    }
    catch {
      $errorMessage = "Failed to load Get-ParameterValueFromNeoConfigurationRoot function. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }

    $BuildMasterBaseUrl = Get-PVal -ParameterName 'BuildMasterBaseUrl' -originalPSBoundParameters $PSBoundParameters -DefaultValue $BuildMasterBaseUrl
    if ([string]::IsNullOrWhiteSpace($BuildMasterBaseUrl)) {
      throw "Unable to resolve BuildMaster base URL. Pass -BuildMasterBaseUrl or set BuildMasterBaseUrl in `$global:settings."
    }
    $BuildMasterBaseUrl = $BuildMasterBaseUrl.TrimEnd('/')
  }

  process {
    # ---------------------------------------------------------------------
    # 1. Resolve API key.
    # ---------------------------------------------------------------------
    $resolvedApiKey = $ApiKey
    if ([string]::IsNullOrWhiteSpace($resolvedApiKey)) {
      if ($null -ne $global:settings) {
        $key = $null
        if ($null -ne $global:configRootKeys) {
          $key = $global:configRootKeys['BuildMasterAdminApiKeyConfigRootKey']
        }
        if ([string]::IsNullOrWhiteSpace($key)) { $key = 'BuildMasterAdminApiKey' }
        $resolvedApiKey = [string]$global:settings[$key]
      }
    }
    if ([string]::IsNullOrWhiteSpace($resolvedApiKey)) {
      $resolvedApiKey = [Environment]::GetEnvironmentVariable('BUILDMASTER_ADMIN_API_KEY', 'Process')
      if ([string]::IsNullOrWhiteSpace($resolvedApiKey)) {
        $resolvedApiKey = [Environment]::GetEnvironmentVariable('BUILDMASTER_ADMIN_API_KEY', 'User')
      }
    }
    if ([string]::IsNullOrWhiteSpace($resolvedApiKey)) {
      $msg = "Unable to resolve BuildMaster admin API key. Pass -ApiKey, set `$global:settings.BuildMasterAdminApiKey, or define the BUILDMASTER_ADMIN_API_KEY User env var."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }

    $uri = '{0}/api/releases/builds/create' -f $BuildMasterBaseUrl
    $headers = @{ 'X-ApiKey' = $resolvedApiKey }
    $payload = @{
      ApplicationName = $Application
      ReleaseNumber   = $ReleaseNumber
    }
    if (-not [string]::IsNullOrWhiteSpace($Pipeline)) {
      $payload['PipelineName'] = $Pipeline
    }
    if (-not [string]::IsNullOrWhiteSpace($Reason)) {
      $payload['Reason'] = $Reason
    }
    $body = $payload | ConvertTo-Json -Depth 5

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "POST $uri (ApiKey='***')" -Tag 'RestCall'

    # ---------------------------------------------------------------------
    # 2. -WhatIf short-circuit.
    # ---------------------------------------------------------------------
    $target = "BuildMaster build for '$Application' / '$ReleaseNumber'"
    if (-not $PSCmdlet.ShouldProcess($target, 'Create')) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "WhatIf: would POST to $uri"
      return [PSCustomObject]@{
        OperationName   = 'Start-BuildMasterPipeline'
        Succeeded       = $false
        Application     = $Application
        ReleaseNumber   = $ReleaseNumber
        Pipeline        = $Pipeline
        BuildId         = $null
        BuildNumber     = $null
        ResponseSummary = "WhatIf: planned create of $target"
      }
    }

    # ---------------------------------------------------------------------
    # 3. Invoke.
    # ---------------------------------------------------------------------
    $buildId = $null
    $buildNumber = $null
    try {
      $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType 'application/json' -Body $body
      if ($null -ne $response) {
        if ($null -ne $response.id)               { $buildId = [string]$response.id }
        elseif ($null -ne $response.buildId)      { $buildId = [string]$response.buildId }
        elseif ($null -ne $response.BuildId)      { $buildId = [string]$response.BuildId }

        if ($null -ne $response.buildNumber)      { $buildNumber = [string]$response.buildNumber }
        elseif ($null -ne $response.BuildNumber)  { $buildNumber = [string]$response.BuildNumber }
        elseif ($null -ne $response.number)       { $buildNumber = [string]$response.number }
      }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Created BuildMaster build id='$buildId' number='$buildNumber' for '$Application'/'$ReleaseNumber'" -Tag 'RestCall'
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
        $msg = "BuildMaster authentication failed (HTTP $statusCode) for $uri. Check BUILDMASTER_ADMIN_API_KEY."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'RestCall'
        throw $msg
      }
      $msg = "POST $uri failed: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'RestCall'
      throw $msg
    }

    $summary = "build queued: id='$buildId'"
    if (-not [string]::IsNullOrWhiteSpace($buildNumber)) {
      $summary += " number='$buildNumber'"
    }

    return [PSCustomObject]@{
      OperationName   = 'Start-BuildMasterPipeline'
      Succeeded       = $true
      Application     = $Application
      ReleaseNumber   = $ReleaseNumber
      Pipeline        = $Pipeline
      BuildId         = $buildId
      BuildNumber     = $buildNumber
      ResponseSummary = $summary
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving $fn" -Tag 'Trace'
  }
}
