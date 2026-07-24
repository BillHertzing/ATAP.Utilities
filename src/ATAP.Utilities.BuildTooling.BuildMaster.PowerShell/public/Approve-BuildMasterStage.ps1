#Requires -Version 7.0
function Approve-BuildMasterStage {
  <#
.SYNOPSIS
    Approves a BuildMaster manual gate for a specific stage of a specific
    build.

.DESCRIPTION
    Calls BuildMaster's Native API
    `POST /api/releases/builds/manual-approval` to record a manual
    approval for the named stage of the specified
    `(Application, ReleaseNumber, BuildNumber)` triple. The optional
    `-Comment` is forwarded to BuildMaster's audit trail.

    Idempotency: re-approving a stage that is already approved returns
    success with `ResponseSummary = 'idempotent: stage already approved'`
    rather than throwing. BuildMaster typically returns HTTP 409 or a
    "already approved" error body in that case; both are handled.

    The base URL is resolved from `-BuildMasterBaseUrl` →
    `$global:settings['BuildMasterBaseUrl']` → env var `BUILDMASTER_BASE_URL`.

    The BuildMaster admin API key secret name is resolved via `Get-PVal`
    (`-BuildMasterAdminApiKeySecretName` → env var → `$global:settings` →
    default `BuildMaster.Admin.API.Key.utat01`). The actual key value is then
    retrieved through `Get-SecretATAP` using that secret name.

    The API key value is never logged. Every external call is logged
    via PSFramework at the `Debug` level.

.PARAMETER Application
    The BuildMaster application name.

.PARAMETER ReleaseNumber
    The release number that the build belongs to.

.PARAMETER BuildNumber
    The build number whose stage is being approved.

.PARAMETER Stage
    The name of the stage whose manual gate is being approved (e.g.,
    `Integration`, `QA`, `Production`).

.PARAMETER Comment
    Optional comment recorded with the approval.

.PARAMETER BuildMasterBaseUrl
    The BuildMaster base URL. Falls back to `$global:settings` then to
    the `BUILDMASTER_BASE_URL` User env var.

.PARAMETER BuildMasterAdminApiKeySecretName
    The ATAP secret name containing the BuildMaster admin API key. Resolved
    via `Get-PVal` (parameter → env var → `$global:settings` → default
    `BuildMaster.Admin.API.Key.utat01`); the value is read with `Get-SecretATAP`.

.INPUTS
    None.

.OUTPUTS
    [PSCustomObject] with fields:
      - `OperationName`     — `'Approve-BuildMasterStage'`.
      - `Succeeded`         — `[bool]`.
      - `Application`       — pass-through.
      - `ReleaseNumber`     — pass-through.
      - `BuildNumber`       — pass-through.
      - `Stage`             — pass-through.
      - `ResponseSummary`   — short human-readable summary; for the
        idempotent path, `'idempotent: stage already approved'`.

.EXAMPLE
    PS> Approve-BuildMasterStage -Application 'AceCommander' `
                                -ReleaseNumber '0.1.0-Sprint.42' `
                                -BuildNumber '17' `
                                -Stage 'Integration' `
                                -Comment 'INT-PASS for build #17'

.NOTES
    AI assisted using Powershell.instructions.md as guidelines.
    Implements task H5 of Plan-DocsUpdateForImmutablePackages_V3.md.

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

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$BuildNumber,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Stage,

    [Parameter(Mandatory = $false)]
    [string]$Comment,

    [Parameter(Mandatory = $false)]
    [string]$BuildMasterBaseUrl,

    [Parameter(Mandatory = $false)]
    [string]$BuildMasterAdminApiKeySecretName = 'BuildMaster.Admin.API.Key'
  )

  begin {
    # SC-0288 / Task 13.66.b: the SecretName host suffix is derived from the service placement
    # host, never hard-coded. Resolution order is the authoritative host setting,
    # then the placement map; an unknown placement host fails closed.
    if (-not $PSBoundParameters.ContainsKey('BuildMasterAdminApiKeySecretName')) {
      if (-not (Get-Command -Name 'Resolve-HostSuffixedSecretName' -ErrorAction SilentlyContinue)) {
        . (Join-Path $PSScriptRoot '..' '..' 'ATAP.Utilities.BuildTooling.Common.PowerShell' 'public' 'Resolve-HostSuffixedSecretName.ps1')
      }
      $BuildMasterAdminApiKeySecretName = Resolve-HostSuffixedSecretName `
        -BaseName $BuildMasterAdminApiKeySecretName -ServiceName 'BuildMaster' -SettingName 'BuildMasterAdminApiKeySecretName'
    }

    $fn = 'Approve-BuildMasterStage'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn (Application='$Application' Release='$ReleaseNumber' Build='$BuildNumber' Stage='$Stage')" -Tag 'Trace'

    $BuildMasterAdminApiKeySecretName = Get-PVal -ParameterName 'BuildMasterAdminApiKeySecretName' -originalPSBoundParameters $PSBoundParameters -DefaultValue $BuildMasterAdminApiKeySecretName
  }

  process {
    # ---------------------------------------------------------------------
    # 1. Resolve BaseUrl.
    # ---------------------------------------------------------------------
    $resolvedBaseUrl = $BuildMasterBaseUrl
    if ([string]::IsNullOrWhiteSpace($resolvedBaseUrl)) {
      if ($null -ne $global:settings) {
        $key = $null
        if ($null -ne $global:configRootKeys) {
          $key = $global:configRootKeys['BuildMasterBaseUrlConfigRootKey']
        }
        if ([string]::IsNullOrWhiteSpace($key)) { $key = 'BuildMasterBaseUrl' }
        $resolvedBaseUrl = [string]$global:settings[$key]
      }
    }
    if ([string]::IsNullOrWhiteSpace($resolvedBaseUrl)) {
      $resolvedBaseUrl = [Environment]::GetEnvironmentVariable('BUILDMASTER_BASE_URL', 'Process')
      if ([string]::IsNullOrWhiteSpace($resolvedBaseUrl)) {
        $resolvedBaseUrl = [Environment]::GetEnvironmentVariable('BUILDMASTER_BASE_URL', 'User')
      }
    }
    if ([string]::IsNullOrWhiteSpace($resolvedBaseUrl)) {
      $msg = "Unable to resolve BuildMaster base URL. Pass -BuildMasterBaseUrl, set `$global:settings.BuildMasterBaseUrl, or define the BUILDMASTER_BASE_URL User env var."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }
    $resolvedBaseUrl = $resolvedBaseUrl.TrimEnd('/')

    # ---------------------------------------------------------------------
    # 2. Retrieve the API key value via Get-SecretATAP, using the resolved
    #    secret name. The key value is never logged.
    # ---------------------------------------------------------------------
    $resolvedApiKey = $null
    $secretErrors = [System.Collections.Generic.List[string]]::new()
    foreach ($fieldName in @($null, 'token', 'key', 'password')) {
      try {
        $candidate = if ($null -eq $fieldName) {
          Get-SecretATAP -SecretName $BuildMasterAdminApiKeySecretName -SecretStoreType 'BitwardenSecretsManager' -ErrorAction Stop
        } else {
          Get-SecretATAP -SecretName $BuildMasterAdminApiKeySecretName -SecretField $fieldName -SecretStoreType 'BitwardenSecretsManager' -ErrorAction Stop
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
      $msg = "Unable to resolve the BuildMaster admin API key value from secret '$BuildMasterAdminApiKeySecretName' via Get-SecretATAP.$detail"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }

    $uri = '{0}/api/releases/builds/manual-approval' -f $resolvedBaseUrl
    $headers = @{ 'X-ApiKey' = $resolvedApiKey }
    $payload = @{
      ApplicationName = $Application
      ReleaseNumber   = $ReleaseNumber
      BuildNumber     = $BuildNumber
      Stage           = $Stage
    }
    if (-not [string]::IsNullOrWhiteSpace($Comment)) {
      $payload['Comment'] = $Comment
    }
    $body = $payload | ConvertTo-Json -Depth 5

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "POST $uri (ApiKey='***')" -Tag 'RestCall'

    # ---------------------------------------------------------------------
    # 3. -WhatIf short-circuit.
    # ---------------------------------------------------------------------
    $target = "stage '$Stage' on build '$BuildNumber' of '$Application'/'$ReleaseNumber'"
    if (-not $PSCmdlet.ShouldProcess($target, 'Approve')) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "WhatIf: would POST to $uri"
      return [PSCustomObject]@{
        OperationName   = 'Approve-BuildMasterStage'
        Succeeded       = $false
        Application     = $Application
        ReleaseNumber   = $ReleaseNumber
        BuildNumber     = $BuildNumber
        Stage           = $Stage
        ResponseSummary = "WhatIf: planned approval of $target"
      }
    }

    # ---------------------------------------------------------------------
    # 4. Invoke; treat "already approved" as success (idempotent).
    # ---------------------------------------------------------------------
    $summary = $null
    try {
      Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType 'application/json' -Body $body | Out-Null
      $summary = "approved: stage '$Stage' on build '$BuildNumber'"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message $summary -Tag 'RestCall'
    } catch {
      $statusCode = $null
      try {
        if ($null -ne $_.Exception.Response) {
          $statusCode = [int]$_.Exception.Response.StatusCode
        }
      } catch {
        $statusCode = $null
      }
      $errMsg = [string]$_.Exception.Message
      $looksAlreadyApproved = ($statusCode -eq 409) -or ($errMsg -match 'already\s*approved')

      if ($statusCode -eq 401 -or $statusCode -eq 403) {
        $msg = "BuildMaster authentication failed (HTTP $statusCode) for $uri. Check the secret named by BuildMasterAdminApiKeySecretName ('$BuildMasterAdminApiKeySecretName')."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'RestCall'
        throw $msg
      } elseif ($looksAlreadyApproved) {
        $summary = 'idempotent: stage already approved'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Stage '$Stage' on build '$BuildNumber' was already approved; treating as success." -Tag 'RestCall'
      } else {
        $msg = "POST $uri failed: $errMsg"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'RestCall'
        throw $msg
      }
    }

    return [PSCustomObject]@{
      OperationName   = 'Approve-BuildMasterStage'
      Succeeded       = $true
      Application     = $Application
      ReleaseNumber   = $ReleaseNumber
      BuildNumber     = $BuildNumber
      Stage           = $Stage
      ResponseSummary = $summary
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving $fn" -Tag 'Trace'
  }
}
