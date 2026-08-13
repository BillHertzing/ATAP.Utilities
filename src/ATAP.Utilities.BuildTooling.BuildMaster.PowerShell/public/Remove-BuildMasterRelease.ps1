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
  Application names are matched exactly and must identify at most one application.
  Release numbers are matched exactly against the Native API `Release_Number` field.
  If zero or multiple releases match, the operation fails. When `-ExpectedReleaseId`
  is supplied, the cmdlet also fails closed if the selected release ID has drifted.

  **Cancel** (default): marks the release as canceled; BuildMaster retains the release
  record and history. The release no longer appears in active lists.

  **Purge** (`-Purge`): permanently deletes the release and all associated data.
  This action requires explicit confirmation via `-Confirm:$false` or user approval
  of the ShouldProcess prompt.

  Missing releases are treated as successful no-ops so the cmdlet is safe to re-run.

  The BuildMaster admin API key secret name is resolved via `Get-PVal`
  (`-BuildMasterAdminApiKeySecretName` → env var → `$global:settings` →
  default `BuildMaster.Admin.API.Key.utat01`). The actual key value is then retrieved
  through `Get-SecretATAP` using that secret name.

  The base URL is resolved in the same order from `-BuildMasterBaseUrl`
  → `$global:settings['BuildMasterBaseUrl']` → env var `BUILDMASTER_BASE_URL`.

  The API key value is never logged. Every external call is logged via PSFramework
  at the `Debug` level.

.PARAMETER Application
  The BuildMaster application name.

.PARAMETER ReleaseNumber
  The release number to cancel or purge (e.g., `0.1.0-Sprint.42`, `Placeholder`,
  `0.0.0`). The cmdlet matches this string exactly against `Release_Number` in
  the BuildMaster releases table.

.PARAMETER ExpectedReleaseId
  Optional BuildMaster release ID safety binding. When supplied, the release selected
  by `ReleaseNumber` must have this exact `Release_Id`; otherwise the cmdlet throws
  before `ShouldProcess` and before any cancel or purge request.

.PARAMETER Purge
  Purge (permanently delete) the release instead of canceling it. Requires
  explicit confirmation via `-Confirm:$false` or user approval.

.PARAMETER BuildMasterBaseUrl
  The BuildMaster base URL (e.g., `https://buildmaster.example/`). Falls back
  to `$global:settings` then to the `BUILDMASTER_BASE_URL` User env var.

.PARAMETER BuildMasterAdminApiKeySecretName
  The ATAP secret name containing the BuildMaster admin API key. Resolved via
  `Get-PVal` (parameter → env var → `$global:settings` → default
  `BuildMaster.Admin.API.Key.utat01`); the value is read with `Get-SecretATAP`.

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
                                -ExpectedReleaseId 1004 `
                                -Purge -Confirm:$false

  Purges release number `0.0.0` only if it still has release ID 1004.

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

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, [int]::MaxValue)]
    [int]$ExpectedReleaseId,

    [switch]$Purge,

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

    $fn = 'Remove-BuildMasterRelease'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn (Application='$Application' ReleaseNumber='$ReleaseNumber' Purge=$Purge)" -Tag 'Trace'

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

    $BuildMasterAdminApiKeySecretName = Get-PVal -ParameterName 'BuildMasterAdminApiKeySecretName' -originalPSBoundParameters $PSBoundParameters -DefaultValue $BuildMasterAdminApiKeySecretName
  }

  process {
    # ---------------------------------------------------------------------
    # 1. Retrieve the API key value via Get-SecretATAP, using the resolved
    #    secret name. Never log the key value. Mask with '***' in surface logging.
    # ---------------------------------------------------------------------
    $resolvedApiKey = $null
    $secretErrors = [System.Collections.Generic.List[string]]::new()
    foreach ($fieldName in @($null, 'token', 'key', 'password')) {
      try {
        $candidate = if ($null -eq $fieldName) {
          Get-SecretATAP -SecretName $BuildMasterAdminApiKeySecretName -SecretStoreType 'BitwardenSecretsManager' -ErrorAction Stop
        } else {
          Get-SecretATAP -SecretName $BuildMasterAdminApiKeySecretName -SecretStoreType 'BitwardenSecretsManager' -SecretField $fieldName -ErrorAction Stop
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

    $matchedApplications = @($appsResponse | Where-Object { $_.Application_Name -ceq $Application })
    if ($matchedApplications.Count -eq 0) {
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

    if ($matchedApplications.Count -gt 1) {
      $msg = "Ambiguous application match: found $($matchedApplications.Count) applications with Application_Name='$Application'. Cannot proceed."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }

    $matchedApp = $matchedApplications[0]
    $applicationId = $matchedApp.Application_Id

    # ---------------------------------------------------------------------
    # 3. Look up release by Application_Id and Release_Number.
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

    $matchedReleases = @($releasesResponse | Where-Object { $_.Release_Number -ceq $ReleaseNumber })

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
      $msg = "Ambiguous match: found $($matchedReleases.Count) releases with Release_Number='$ReleaseNumber' in application '$Application'. Cannot proceed."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }

    $release = $matchedReleases[0]
    $releaseId = $release.Release_Id

    if ($PSBoundParameters.ContainsKey('ExpectedReleaseId') -and [int]$releaseId -ne $ExpectedReleaseId) {
      $msg = "Release ID drift: release number '$ReleaseNumber' in application '$Application' resolved to Release_Id=$releaseId, but ExpectedReleaseId=$ExpectedReleaseId. Cannot proceed."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }

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
      $purgeBody = @{
        Application_Id = $applicationId
        Release_Number = $ReleaseNumber
      } | ConvertTo-Json -Depth 5
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling $purgeUri for Application_Id=$applicationId Release_Number='$ReleaseNumber' (verified Release_Id=$releaseId; ApiKey='***')" -Tag 'RestCall'

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
