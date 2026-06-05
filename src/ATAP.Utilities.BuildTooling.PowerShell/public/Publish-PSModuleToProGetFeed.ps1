<#
.SYNOPSIS
Publishes a PowerShell module .nupkg to the correct ProGet PowerShellGet feed
for a given 5-Tier tier.

.DESCRIPTION
Maps a canonical tier name (Experimental/Development/Integration/QA/Production)
to a PowerShellGet feed
name and endpoint from $global:Settings using the ProGet feed collection
defined by ATAP.Utilities.ConfigRootKeys.PowerShell and host settings,
resolves the API key via Get-SecretATAP or the feed's configured
ApiKeyName environment variable, ensures a matching
PSResourceRepository is registered, and invokes Publish-PSResource.

All network and secret operations are mockable. The API key value is never
logged. If -WhatIf is supplied the cmdlet returns the planned object with
Published = $false and does not call Publish-PSResource.

.PARAMETER NupkgPath
Absolute or relative path to the .nupkg file to publish. Must exist.

.PARAMETER Tier
One of 'Experimental','Development','Integration','QA','Production'. Legacy
aliases 'Sprint','Alpha','Beta' are still accepted for compatibility.
using the canonical five-tier mapping from Explainer 0111.

.PARAMETER AllowTierOverride
Reserved for a future cross-check between an explicit tier and the tier NBGV
would derive from the branch label. Currently unused.

.PARAMETER WhatIf
If specified, short-circuits before calling Publish-PSResource. The returned
object still reflects the fully-resolved feed name and URI so callers can
inspect the publish plan.

.OUTPUTS
[PSCustomObject] with fields:
  - NupkgPath        : Absolute path to the .nupkg.
  - FeedName         : Resolved PowerShellGet feed name for the tier.
  - FeedUri          : Resolved feed URI.
  - Published        : $true only if Publish-PSResource was actually invoked.
  - ResponseSummary  : Short string summary of the publish result or plan.

.EXAMPLE
Publish-PSModuleToProGetFeed -NupkgPath 'C:/out/MyModule.1.2.3.nupkg' -Tier Development

Publishes the package to the powershellget-development feed.

.EXAMPLE
Publish-PSModuleToProGetFeed -NupkgPath 'C:/out/MyModule.1.2.3.nupkg' -Tier Experimental -WhatIf

Returns the planned publish object without contacting ProGet.

.NOTES
AI assisted using Powershell.instructions.md as guidelines

Feed names and endpoints are resolved from
$global:Settings[$global:configRootKeys['ProGetFeedCollectionConfigRootKey']].
This is the current Explainer 0111 path and replaces the older direct
ATAP.IAC constant lookup.
#>
function Publish-PSModuleToProGetFeed {
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [string]$NupkgPath,

    [Parameter(Mandatory)]
  [ValidateSet('Experimental', 'Development', 'Integration', 'QA', 'Production', 'Sprint', 'Alpha', 'Beta')]
    [string]$Tier,

    [switch]$AllowTierOverride
  )

  begin {
    $fn = 'Publish-PSModuleToProGetFeed'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'

    # Check and populate simple parameter: NupkgPath
    if ([string]::IsNullOrWhiteSpace($NupkgPath)) {
      $msg = "Parameter 'NupkgPath' is null or empty."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }

    # Check and populate simple parameter: Tier (validated by ValidateSet)
  if ([string]::IsNullOrWhiteSpace($Tier)) {
    $msg = "Parameter 'Tier' is null or empty."
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
    throw $msg
  }

  $canonicalTier = switch ($Tier) {
    'Sprint' { 'Experimental' }
    'Alpha' { 'Development' }
    'Beta' { 'Integration' }
    default { $Tier }
  }

  Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn with NupkgPath='$NupkgPath' Tier='$Tier'" -Tag 'Trace'

    $helperPath = Join-Path $PSScriptRoot '..\private\Resolve-ProGetFeedFromSettings.ps1'
    if (-not (Get-Command -Name 'Resolve-ProGetFeedFromSettings' -CommandType Function -ErrorAction SilentlyContinue)) {
      . $helperPath
    }
  }

  process {
    # 1. Validate nupkg path exists and has the right extension.
    if (-not (Test-Path -LiteralPath $NupkgPath -PathType Leaf)) {
      $msg = "NupkgPath does not exist or is not a file: '$NupkgPath'"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }
    if ([System.IO.Path]::GetExtension($NupkgPath) -ne '.nupkg') {
      $msg = "NupkgPath must have a .nupkg extension: '$NupkgPath'"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }
    $resolvedNupkg = (Resolve-Path -LiteralPath $NupkgPath).ProviderPath -replace '\\', '/'

    # 2. Map tier -> feed metadata from $global:Settings.
  $feed = Resolve-ProGetFeedFromSettings -FeedType 'powershellget' -Tier $canonicalTier
    $feedName = $feed.FeedName
    $feedUri = $feed.EndpointUri
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Resolved tier '$Tier' to feed '$feedName' at '$feedUri' from global settings"

    # 3. Resolve API key: per-tier ATAP secret store preferred, then configured
    #    User env var, then admin-key fallback (PROGET_ADMIN_API_KEY).
    #
    # SCOPE CREEP — REMOVE ADMIN-KEY FALLBACK ONCE PER-TIER KEYS EXIST
    # ----------------------------------------------------------------
    # The PROGET_ADMIN_API_KEY fallback below is a temporary bootstrap so local
    # builds and early sprint pipelines can publish before per-tier ProGet API
    # keys are minted, stored in the ATAP secret store, and documented. Once
    # every tier (Experimental/Development/Integration/QA/Production) has its own key in the
    # secret store under 'ProGet_PowerShellGet_<Tier>_ApiKey' and a documented
    # rotation plan exists, delete the fallback block and let this function
    # throw when the tier-specific key is missing.
    $apiKey = $null
    $apiKeySource = $null
    $secretCmd = Get-Command -Name 'Get-SecretATAP' -ErrorAction SilentlyContinue
    if ($null -ne $secretCmd) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Attempting Get-SecretATAP for tier '$Tier'"
      try {
      $secretName = "ProGet_PowerShellGet_${canonicalTier}_ApiKey"
        $apiKey = Get-SecretATAP -SecretName $secretName
        if (-not [string]::IsNullOrWhiteSpace([string]$apiKey)) {
          $apiKeySource = "ATAP secret store item '$secretName'"
        }
      } catch {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Get-SecretATAP threw; will fall back to env var'
        $apiKey = $null
      }
    }
    if ([string]::IsNullOrWhiteSpace([string]$apiKey)) {
      $envName = if (-not [string]::IsNullOrWhiteSpace($feed.ApiKeyName)) {
        $feed.ApiKeyName
      } else {
        "PROGET_POWERSHELLGET_APIKEY_$Tier"
      }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Falling back to configured env var '$envName' for API key"
      $apiKey = [Environment]::GetEnvironmentVariable($envName, 'Process')
      if ([string]::IsNullOrWhiteSpace([string]$apiKey)) {
        $apiKey = [Environment]::GetEnvironmentVariable($envName, 'User')
      }
      if (-not [string]::IsNullOrWhiteSpace([string]$apiKey)) {
        $apiKeySource = "env var '$envName'"
      }
    }
    if ([string]::IsNullOrWhiteSpace([string]$apiKey)) {
      # TEMPORARY admin-key fallback (see SCOPE CREEP note above).
      $adminEnvName = 'PROGET_ADMIN_API_KEY'
      $apiKey = [Environment]::GetEnvironmentVariable($adminEnvName, 'User')
      if (-not [string]::IsNullOrWhiteSpace([string]$apiKey)) {
        $apiKeySource = "User env var '$adminEnvName' (admin fallback)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message (
          "Using PROGET_ADMIN_API_KEY admin fallback for tier '$Tier' — provision " +
          "'ProGet_PowerShellGet_${Tier}_ApiKey' in the ATAP secret store to remove this fallback."
        )
      }
    }
    if ([string]::IsNullOrWhiteSpace([string]$apiKey)) {
      $msg = "Unable to resolve ProGet API key for tier '$Tier'. Expected Get-SecretATAP -SecretName 'ProGet_PowerShellGet_${Tier}_ApiKey', configured env var '$($feed.ApiKeyName)', or admin fallback 'PROGET_ADMIN_API_KEY'."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "API key resolved for tier '$Tier' from $apiKeySource (value redacted)"

    # 5. Ensure the PSResourceRepository is registered with the right URI.
    $existingRepo = Get-PSResourceRepository -Name $feedName -ErrorAction SilentlyContinue
    if ($null -eq $existingRepo) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Registering PSResourceRepository '$feedName'"
      Register-PSResourceRepository -Name $feedName -Uri $feedUri -Trusted
    } else {
      $existingUri = [string]$existingRepo.Uri
      if ($existingUri -ne $feedUri) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Updating PSResourceRepository '$feedName' URI"
        Set-PSResourceRepository -Name $feedName -Uri $feedUri -Trusted
      } else {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "PSResourceRepository '$feedName' already registered with matching URI"
      }
    }

    # 6. WhatIf short-circuit.
    if ($WhatIfPreference) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "WhatIf: would publish '$resolvedNupkg' to '$feedName'"
      return [PSCustomObject]@{
        NupkgPath       = $resolvedNupkg
        FeedName        = $feedName
        FeedUri         = $feedUri
        Published       = $false
        ResponseSummary = "WhatIf: planned publish of '$resolvedNupkg' to '$feedName'"
      }
    }

    # 7. Publish.
    $published = $false
    $summary = $null
    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling Publish-PSResource for '$feedName'"
      $result = Publish-PSResource -NupkgPath $resolvedNupkg -Repository $feedName -ApiKey $apiKey
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from Publish-PSResource for '$feedName'"
      $published = $true
      if ($null -ne $result) {
        $summary = "Publish-PSResource returned: $($result | Out-String)".Trim()
      } else {
        $summary = 'Publish-PSResource completed without returning an object.'
      }
    } catch {
      $msg = "Publish-PSResource failed for '$resolvedNupkg' to '$feedName': $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }

    [PSCustomObject]@{
      NupkgPath       = $resolvedNupkg
      FeedName        = $feedName
      FeedUri         = $feedUri
      Published       = $published
      ResponseSummary = $summary
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving $fn" -Tag 'Trace'
  }
}
