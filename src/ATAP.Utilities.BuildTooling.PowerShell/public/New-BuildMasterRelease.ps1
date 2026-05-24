#Requires -Version 7.0
function New-BuildMasterRelease {
  <#
.SYNOPSIS
    Creates a BuildMaster release for an Application + ReleaseNumber +
    Pipeline triple via the Native API, idempotently.

.DESCRIPTION
    Calls BuildMaster's Native API `POST /api/releases/create` with a JSON
    body of `ApplicationName`, `ReleaseNumber`, and `PipelineName`, plus
    optional `ReleaseName`, using the `X-ApiKey` header for authentication.
    The API key value is read in this order:

      1. `-ApiKey` parameter (explicit).
      2. `$global:settings[$global:configRootKeys['BuildMasterAdminApiKey']]`
         (Explainer-0111 settings model).
      3. The Process or User-scope env var `BUILDMASTER_ADMIN_API_KEY`
         (per R-27 in `CLAUDE.md`: `ALL_UPPERCASE_WITH_UNDERSCORES`).

    The base URL is resolved in the same order from `-BuildMasterBaseUrl`
    → `$global:settings['BuildMasterBaseUrl']` → env var
    `BUILDMASTER_BASE_URL`.

    Idempotency: if BuildMaster returns an "already exists" error (HTTP
    409 in current versions; some BuildMaster versions surface this as
    400 with a message body containing "already exists"), the cmdlet
    calls `GET /api/releases?applicationName=...&releaseNumber=...` and
    returns the existing record. The output's `ResponseSummary` is set
    to `'idempotent: release already exists'` in that case.

    The API key value is never logged. Every external call is logged
    via PSFramework at the `Debug` level.

.PARAMETER Application
    The BuildMaster application name.

.PARAMETER ReleaseNumber
    The release number (commonly the full SemVer string), e.g.
    `0.1.0-Sprint.42`.

.PARAMETER PipelineName
    One of the three durable BuildMaster pipelines (e.g.,
    `CSharp-Package-Pipeline`, `PowerShell-Module-Pipeline`,
    `Release-Bundle-Pipeline`).

.PARAMETER ReleaseName
    Optional display name for the release. For package-triggered builds,
    pass a human-readable package identity such as
    `ATAP.Utilities.BuildTooling.PowerShell 0.1.0-Alpha025` so BuildMaster
    build lists do not show a generic placeholder release.

.PARAMETER BuildMasterBaseUrl
    The BuildMaster base URL (e.g., `https://buildmaster.example/`).
    Falls back to `$global:settings` then to the
    `BUILDMASTER_BASE_URL` User env var.

.PARAMETER ApiKey
    The BuildMaster admin API key. Falls back to `$global:settings`
    then to the `BUILDMASTER_ADMIN_API_KEY` User env var.

.INPUTS
    None.

.OUTPUTS
    [PSCustomObject] with fields:
      - `OperationName`     — `'New-BuildMasterRelease'`.
      - `Succeeded`         — `[bool]`.
      - `Application`       — pass-through.
      - `ReleaseNumber`     — pass-through.
      - `ReleaseName`       — pass-through.
      - `PipelineName`      — pass-through.
      - `ReleaseId`         — the BuildMaster release ID (new or existing).
      - `ResponseSummary`   — short human-readable summary; for the
        idempotent path, `'idempotent: release already exists'`.

.EXAMPLE
    PS> New-BuildMasterRelease -Application 'AceCommander' `
                               -ReleaseNumber '0.1.0-Sprint.42' `
                               -PipelineName 'CSharp-Package-Pipeline'

.NOTES
    AI assisted using Powershell.instructions.md as guidelines.
    Implements task H3 of Plan-DocsUpdateForImmutablePackages_V3.md.

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
    [string]$PipelineName,

    [Parameter(Mandatory = $false)]
    [string]$ReleaseName,

    [Parameter(Mandatory = $false)]
    [string]$BuildMasterBaseUrl,

    [Parameter(Mandatory = $false)]
    [string]$ApiKey
  )

  begin {
    $fn = 'New-BuildMasterRelease'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn (Application='$Application' ReleaseNumber='$ReleaseNumber' ReleaseName='$ReleaseName' PipelineName='$PipelineName')" -Tag 'Trace'

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
      $BuildMasterBaseUrl = [System.Environment]::GetEnvironmentVariable('BUILDMASTER_BASE_URL', 'Process')
    }
    if ([string]::IsNullOrWhiteSpace($BuildMasterBaseUrl)) {
      $BuildMasterBaseUrl = [System.Environment]::GetEnvironmentVariable('BUILDMASTER_BASE_URL', 'User')
    }
    if ([string]::IsNullOrWhiteSpace($BuildMasterBaseUrl)) {
      $BuildMasterBaseUrl = 'http://localhost:50017'
    }
    $BuildMasterBaseUrl = $BuildMasterBaseUrl.TrimEnd('/')
  }

  process {
    # ---------------------------------------------------------------------
    # 1. Resolve API key: parameter -> $global:settings -> env var.
    #    Never log the key value. Mask with '***' in surface logging.
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

    $createUri = '{0}/api/releases/create' -f $BuildMasterBaseUrl
    $getUri = '{0}/api/releases?applicationName={1}&releaseNumber={2}' -f $BuildMasterBaseUrl, [Uri]::EscapeDataString($Application), [Uri]::EscapeDataString($ReleaseNumber)
    $headers = @{ 'X-ApiKey' = $resolvedApiKey }
    $body = @{
      ApplicationName = $Application
      ReleaseNumber   = $ReleaseNumber
      PipelineName    = $PipelineName
    }
    if (-not [string]::IsNullOrWhiteSpace($ReleaseName)) {
      $body['ReleaseName'] = $ReleaseName
    }
    $body = $body | ConvertTo-Json -Depth 5

    function Select-BuildMasterReleaseRecord {
      param(
        [Parameter(Mandatory = $false)][AllowNull()][object]$InputObject,
        [Parameter(Mandatory = $true)][string]$ExpectedReleaseNumber
      )

      if ($null -eq $InputObject) { return $null }
      $records = if ($InputObject -is [System.Collections.IEnumerable] -and -not ($InputObject -is [string])) {
        @($InputObject)
      } else {
        @($InputObject)
      }

      $matched = @(
        $records | Where-Object {
          $propertyNames = @($_.PSObject.Properties.Name)
          ($propertyNames -contains 'Release_Name' -and [string]$_.Release_Name -eq $ExpectedReleaseNumber) -or
          ($propertyNames -contains 'Release_Number' -and [string]$_.Release_Number -eq $ExpectedReleaseNumber) -or
          ($propertyNames -contains 'releaseNumber' -and [string]$_.releaseNumber -eq $ExpectedReleaseNumber) -or
          ($propertyNames -contains 'ReleaseNumber' -and [string]$_.ReleaseNumber -eq $ExpectedReleaseNumber)
        }
      )
      if ($matched.Count -gt 0) { return $matched[0] }
      return ($records | Select-Object -First 1)
    }

    function Resolve-BuildMasterReleaseId {
      param(
        [Parameter(Mandatory = $false)][AllowNull()][object]$Record
      )

      if ($null -eq $Record) { return $null }
      if ($null -ne $Record.id) { return [string]$Record.id }
      if ($null -ne $Record.releaseId) { return [string]$Record.releaseId }
      if ($null -ne $Record.ReleaseId) { return [string]$Record.ReleaseId }
      if ($null -ne $Record.Release_Id) { return [string]$Record.Release_Id }
      return $null
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "POST $createUri (ApiKey='***')" -Tag 'RestCall'

    # ---------------------------------------------------------------------
    # 2. -WhatIf short-circuit before any side effect.
    # ---------------------------------------------------------------------
    $target = "BuildMaster release '$Application' / '$ReleaseNumber' on pipeline '$PipelineName'"
    if (-not $PSCmdlet.ShouldProcess($target, 'Create')) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "WhatIf: would POST to $createUri"
      return [PSCustomObject]@{
        OperationName   = 'New-BuildMasterRelease'
        Succeeded       = $false
        Application     = $Application
        ReleaseNumber   = $ReleaseNumber
        ReleaseName     = $ReleaseName
        PipelineName    = $PipelineName
        ReleaseId       = $null
        ResponseSummary = "WhatIf: planned create of $target"
      }
    }

    # ---------------------------------------------------------------------
    # 3. Create the release; fall through to idempotent fetch on conflict.
    # ---------------------------------------------------------------------
    $releaseId = $null
    $summary = $null
    try {
      $response = Invoke-RestMethod -Method Post -Uri $createUri -Headers $headers -ContentType 'application/json' -Body $body -TimeoutSec 30
      $releaseId = [string]$response.id
      if ([string]::IsNullOrWhiteSpace($releaseId)) {
        # Some BuildMaster responses use 'releaseId' or 'ReleaseId'.
        if ($null -ne $response.releaseId) { $releaseId = [string]$response.releaseId }
        elseif ($null -ne $response.ReleaseId) { $releaseId = [string]$response.ReleaseId }
      }
      $summary = "created: release id $releaseId"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Created BuildMaster release '$Application'/'$ReleaseNumber' as id '$releaseId'" -Tag 'RestCall'
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
      $looksLikeConflict = ($statusCode -eq 409) -or ($statusCode -eq 400 -and ($errMsg -match 'already\s*exists')) -or ($errMsg -match 'already\s*exists')
      $shouldProbeExistingRelease = $looksLikeConflict -or ($statusCode -eq 400)

      if ($statusCode -eq 401 -or $statusCode -eq 403) {
        $msg = "BuildMaster authentication failed (HTTP $statusCode) for $createUri. Check BUILDMASTER_ADMIN_API_KEY."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'RestCall'
        throw $msg
      } elseif ($shouldProbeExistingRelease) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Release create failed with HTTP $statusCode. Probing existing release with GET $getUri" -Tag 'RestCall'
        $lookupErrors = [System.Collections.Generic.List[string]]::new()
        $record = $null
        try {
          $existing = Invoke-RestMethod -Method Get -Uri $getUri -Headers $headers -TimeoutSec 30
          $record = Select-BuildMasterReleaseRecord -InputObject $existing -ExpectedReleaseNumber $ReleaseNumber
        } catch {
          $lookupErrors.Add("REST lookup failed: $($_.Exception.Message)") | Out-Null
        }

        if ($null -eq $record) {
          $getAppsUri = '{0}/api/json/Applications_GetApplications' -f $BuildMasterBaseUrl
          $getReleasesUri = '{0}/api/json/Releases_GetReleases' -f $BuildMasterBaseUrl
          try {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Falling back to native release lookup via $getAppsUri and $getReleasesUri" -Tag 'RestCall'
            $appsResponse = Invoke-RestMethod -Method Post -Uri $getAppsUri -Headers $headers -ContentType 'application/json' -Body '{}' -TimeoutSec 30
            $matchedApp = $appsResponse | Where-Object { $_.Application_Name -eq $Application } | Select-Object -First 1
            if ($null -ne $matchedApp) {
              $releasesBody = @{ Application_Id = $matchedApp.Application_Id } | ConvertTo-Json -Depth 5
              $releasesResponse = Invoke-RestMethod -Method Post -Uri $getReleasesUri -Headers $headers -ContentType 'application/json' -Body $releasesBody -TimeoutSec 30
              $record = Select-BuildMasterReleaseRecord -InputObject $releasesResponse -ExpectedReleaseNumber $ReleaseNumber
            }
          } catch {
            $lookupErrors.Add("native lookup failed: $($_.Exception.Message)") | Out-Null
          }
        }

        $releaseId = Resolve-BuildMasterReleaseId -Record $record
        if ($null -eq $record -or [string]::IsNullOrWhiteSpace($releaseId)) {
          $lookupSummary = if ($lookupErrors.Count -gt 0) { '; ' + ($lookupErrors -join '; ') } else { '' }
          $msg = "POST $createUri failed: $errMsg$lookupSummary"
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'RestCall'
          throw $msg
        }
        $summary = 'idempotent: release already exists'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Returned existing BuildMaster release id '$releaseId' for '$Application'/'$ReleaseNumber'" -Tag 'RestCall'
      } else {
        $msg = "POST $createUri failed: $errMsg"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'RestCall'
        throw $msg
      }
    }

    return [PSCustomObject]@{
      OperationName   = 'New-BuildMasterRelease'
      Succeeded       = $true
      Application     = $Application
      ReleaseNumber   = $ReleaseNumber
      ReleaseName     = $ReleaseName
      PipelineName    = $PipelineName
      ReleaseId       = $releaseId
      ResponseSummary = $summary
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving $fn" -Tag 'Trace'
  }
}
