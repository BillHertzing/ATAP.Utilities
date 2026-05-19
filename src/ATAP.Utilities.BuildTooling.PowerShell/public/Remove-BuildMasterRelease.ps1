#Requires -Version 7.0
function Remove-BuildMasterRelease {
  <#
.SYNOPSIS
  Cancels or purges a BuildMaster release by application name and release number.

.DESCRIPTION
  Safely cancels or purges a duplicate or stale BuildMaster release using the Native
  API. By default, the cmdlet cancels the release (soft delete, preserves history).
  Use `-Purge` to permanently delete the release and all its data.

  The cmdlet resolves the Application ID from the application name via
  `Applications_GetApplications`, then looks up the release ID via `Releases_GetReleases`.
  If zero or multiple releases match, the operation fails.

  **Cancel** (default): marks the release as canceled; BuildMaster retains the release
  record and history. The release no longer appears in active lists.

  **Purge** (`-Purge`): permanently deletes the release and all associated data.
  This action requires explicit confirmation via `-Confirm:$false` or user approval
  of the ShouldProcess prompt.

  Missing releases are treated as successful no-ops so the cmdlet is safe to re-run.

  The API key value is read in this order:
    1. `-ApiKey` parameter (explicit).
    2. `$global:settings[$global:configRootKeys['BuildMasterAdminApiKey']]`
       (Explainer-0111 settings model).
    3. The Process or User-scope env var `BUILDMASTER_ADMIN_API_KEY`
       (per R-27 in `CLAUDE.md`: `ALL_UPPERCASE_WITH_UNDERSCORES`).

  The base URL is resolved in the same order from `-BuildMasterBaseUrl`
  → `$global:settings['BuildMasterBaseUrl']` → env var `BUILDMASTER_BASE_URL`.

  The API key value is never logged. Every external call is logged via PSFramework
  at the `Debug` level.

.PARAMETER Application
  The BuildMaster application name.

.PARAMETER ReleaseNumber
  The release number to cancel or purge (e.g., `0.1.0-Sprint.42`, `Placeholder`,
  `0.0.0`). The cmdlet matches this string exactly against `Release_Name` in
  the BuildMaster releases table.

.PARAMETER Purge
  Purge (permanently delete) the release instead of canceling it. Requires
  explicit confirmation via `-Confirm:$false` or user approval.

.PARAMETER BuildMasterBaseUrl
  The BuildMaster base URL (e.g., `https://buildmaster.example/`). Falls back
  to `$global:settings` then to the `BUILDMASTER_BASE_URL` User env var.

.PARAMETER ApiKey
  The BuildMaster admin API key. Falls back to `$global:settings` then to the
  `BUILDMASTER_ADMIN_API_KEY` User env var.

.INPUTS
  None.

.OUTPUTS
  [PSCustomObject] with fields:
    - `OperationName`   — `'Remove-BuildMasterRelease'`.
    - `Succeeded`       — `[bool]`.
    - `Application`     — pass-through.
    - `ReleaseNumber`   — pass-through.
    - `ReleaseId`       — the BuildMaster release ID (if found).
    - `Action`          — `'Canceled'`, `'Purged'`, `'WhatIf'`, `'NotFound'`, or `'Unchanged'`.
    - `ResponseSummary` — short human-readable summary.

.EXAMPLE
  PS> Remove-BuildMasterRelease -Application 'ATAP.Utilities-PowerShell' `
                                -ReleaseNumber '0.0.0' `
                                -Purge -Confirm:$false

  Purges the confusing `0.0.0` placeholder release from the live application.

.EXAMPLE
  PS> Remove-BuildMasterRelease -Application 'ATAP.Utilities-PowerShell' `
                                -ReleaseNumber 'Placeholder'

  Cancels (soft-deletes) the `Placeholder` release, preserving history.

.EXAMPLE
  PS> Remove-BuildMasterRelease -Application 'NonExistent' `
                                -ReleaseNumber '1.0.0' -WhatIf

  WhatIf: returns a summary of what would be done without making changes.

.NOTES
  AI assisted using Powershell.instructions.md as guidelines.
  Implements task E04b of TASKS_V3GPT5.5.md.

.LINK
  https://docs.inedo.com/docs/buildmaster-reference-api-native
#>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Application,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ReleaseNumber,

    [switch]$Purge,

    [Parameter(Mandatory = $false)]
    [string]$BuildMasterBaseUrl,

    [Parameter(Mandatory = $false)]
    [string]$ApiKey
  )

  begin {
    $fn = 'Remove-BuildMasterRelease'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn (Application='$Application' ReleaseNumber='$ReleaseNumber' Purge=$Purge)" -Tag 'Trace'

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

    $headers = @{ 'X-ApiKey' = $resolvedApiKey }

    # ---------------------------------------------------------------------
    # 2. Resolve Application_Id from application name.
    # ---------------------------------------------------------------------
    $getAppsUri = '{0}/api/json/Applications_GetApplications' -f $BuildMasterBaseUrl
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling $getAppsUri (ApiKey='***')" -Tag 'RestCall'

    try {
      $appsResponse = Invoke-RestMethod -Method Post -Uri $getAppsUri -Headers $headers -ContentType 'application/json' -Body '{}' -ErrorAction Stop
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from $getAppsUri" -Tag 'RestCall'
    } catch {
      $msg = "Failed to list BuildMaster applications: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'RestCall'
      throw $msg
    }

    $matchedApp = $appsResponse | Where-Object { $_.Application_Name -eq $Application } | Select-Object -First 1
    if ($null -eq $matchedApp) {
      return [PSCustomObject]@{
        OperationName   = $fn
        Succeeded       = $true
        Application     = $Application
        ReleaseNumber   = $ReleaseNumber
        ReleaseId       = $null
        Action          = 'NotFound'
        ResponseSummary = "application '$Application' not found"
      }
    }

    $applicationId = $matchedApp.Application_Id

    # ---------------------------------------------------------------------
    # 3. Look up release by Application_Id and Release_Name.
    # ---------------------------------------------------------------------
    $getReleasesUri = '{0}/api/json/Releases_GetReleases' -f $BuildMasterBaseUrl
    $releasesBody = @{ Application_Id = $applicationId } | ConvertTo-Json -Depth 5
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling $getReleasesUri for Application_Id=$applicationId (ApiKey='***')" -Tag 'RestCall'

    try {
      $releasesResponse = Invoke-RestMethod -Method Post -Uri $getReleasesUri -Headers $headers -ContentType 'application/json' -Body $releasesBody -ErrorAction Stop
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from $getReleasesUri" -Tag 'RestCall'
    } catch {
      $msg = "Failed to list releases for application '$Application': $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'RestCall'
      throw $msg
    }

    $matchedReleases = @($releasesResponse | Where-Object { $_.Release_Name -eq $ReleaseNumber })

    if ($matchedReleases.Count -eq 0) {
      return [PSCustomObject]@{
        OperationName   = $fn
        Succeeded       = $true
        Application     = $Application
        ReleaseNumber   = $ReleaseNumber
        ReleaseId       = $null
        Action          = 'Unchanged'
        ResponseSummary = "release '$ReleaseNumber' not found in application '$Application'"
      }
    }

    if ($matchedReleases.Count -gt 1) {
      $msg = "Ambiguous match: found $($matchedReleases.Count) releases with Release_Name='$ReleaseNumber' in application '$Application'. Cannot proceed."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }

    $release = $matchedReleases[0]
    $releaseId = $release.Release_Id

    # ---------------------------------------------------------------------
    # 4. -WhatIf short-circuit before any side effect.
    # ---------------------------------------------------------------------
    $action = if ($Purge) { 'Purge' } else { 'Cancel' }
    $target = "BuildMaster release '$Application' / '$ReleaseNumber' (Release_Id=$releaseId)"
    if (-not $PSCmdlet.ShouldProcess($target, $action)) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "WhatIf: would $action $target"
      return [PSCustomObject]@{
        OperationName   = $fn
        Succeeded       = $false
        Application     = $Application
        ReleaseNumber   = $ReleaseNumber
        ReleaseId       = $releaseId
        Action          = 'WhatIf'
        ResponseSummary = "WhatIf: planned $($action.ToLowerInvariant()) of $target"
      }
    }

    # ---------------------------------------------------------------------
    # 5. Execute cancel or purge.
    # ---------------------------------------------------------------------
    if ($Purge) {
      $purgeUri = '{0}/api/json/Releases_PurgeReleaseData' -f $BuildMasterBaseUrl
      $purgeBody = @{ Release_Id = $releaseId } | ConvertTo-Json -Depth 5
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling $purgeUri for Release_Id=$releaseId (ApiKey='***')" -Tag 'RestCall'

      try {
        Invoke-RestMethod -Method Post -Uri $purgeUri -Headers $headers -ContentType 'application/json' -Body $purgeBody -ErrorAction Stop | Out-Null
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from $purgeUri" -Tag 'RestCall'
      } catch {
        $msg = "Failed to purge release '$ReleaseNumber' (Release_Id=$releaseId): $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'RestCall'
        throw $msg
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Purged BuildMaster release '$Application'/'$ReleaseNumber' (Release_Id=$releaseId)" -Tag 'RestCall'
      return [PSCustomObject]@{
        OperationName   = $fn
        Succeeded       = $true
        Application     = $Application
        ReleaseNumber   = $ReleaseNumber
        ReleaseId       = $releaseId
        Action          = 'Purged'
        ResponseSummary = "purged release id $releaseId"
      }
    } else {
      $cancelUri = '{0}/api/json/Releases_CancelRelease' -f $BuildMasterBaseUrl
      $cancelBody = @{ Release_Id = $releaseId } | ConvertTo-Json -Depth 5
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling $cancelUri for Release_Id=$releaseId (ApiKey='***')" -Tag 'RestCall'

      try {
        Invoke-RestMethod -Method Post -Uri $cancelUri -Headers $headers -ContentType 'application/json' -Body $cancelBody -ErrorAction Stop | Out-Null
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from $cancelUri" -Tag 'RestCall'
      } catch {
        $msg = "Failed to cancel release '$ReleaseNumber' (Release_Id=$releaseId): $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'RestCall'
        throw $msg
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Canceled BuildMaster release '$Application'/'$ReleaseNumber' (Release_Id=$releaseId)" -Tag 'RestCall'
      return [PSCustomObject]@{
        OperationName   = $fn
        Succeeded       = $true
        Application     = $Application
        ReleaseNumber   = $ReleaseNumber
        ReleaseId       = $releaseId
        Action          = 'Canceled'
        ResponseSummary = "canceled release id $releaseId"
      }
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving $fn" -Tag 'Trace'
  }
}
