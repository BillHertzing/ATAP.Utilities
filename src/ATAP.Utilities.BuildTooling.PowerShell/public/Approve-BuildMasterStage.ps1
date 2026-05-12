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

    The base URL and API key are resolved with the same precedence as
    the other Stream-H BuildMaster cmdlets:

      1. Explicit parameter.
      2. `$global:settings[$global:configRootKeys['…ConfigRootKey']]`.
      3. Process / User-scope env var (`BUILDMASTER_BASE_URL`,
         `BUILDMASTER_ADMIN_API_KEY`).

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

.PARAMETER ApiKey
    The BuildMaster admin API key. Falls back to `$global:settings` then
    to the `BUILDMASTER_ADMIN_API_KEY` User env var.

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
    [string]$ApiKey
  )

  begin {
    $fn = 'Approve-BuildMasterStage'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn (Application='$Application' Release='$ReleaseNumber' Build='$BuildNumber' Stage='$Stage')" -Tag 'Trace'
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
    # 2. Resolve API key.
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
        $msg = "BuildMaster authentication failed (HTTP $statusCode) for $uri. Check BUILDMASTER_ADMIN_API_KEY."
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
