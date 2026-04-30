<#
.SYNOPSIS
Publishes a PowerShell module .nupkg to the correct ProGet PowerShellGet feed
for a given 5-Tier tier.

.DESCRIPTION
Maps a tier name (Sprint/Alpha/Beta/QA/Production) to a PowerShellGet feed
name, resolves the feed URI (via $global:settings or a User-scope environment
variable until T-30 Get-ATAPIACConstant lands), resolves the API key via
Get-BitWardenSecret or a User-scope environment variable, ensures a matching
PSResourceRepository is registered, and invokes Publish-PSResource.

All network and secret operations are mockable. The API key value is never
logged. If -WhatIf is supplied the cmdlet returns the planned object with
Published = $false and does not call Publish-PSResource.

.PARAMETER NupkgPath
Absolute or relative path to the .nupkg file to publish. Must exist.

.PARAMETER Tier
One of 'Sprint','Alpha','Beta','QA','Production'. Maps to a ProGet feed name
using the table defined in 5tier Implementation plan.md section 4.1.

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
Publish-PSModuleToProGetFeed -NupkgPath 'C:/out/MyModule.1.2.3.nupkg' -Tier Alpha

Publishes the package to the PowershellGet-development feed.

.EXAMPLE
Publish-PSModuleToProGetFeed -NupkgPath 'C:/out/MyModule.1.2.3.nupkg' -Tier Sprint -WhatIf

Returns the planned publish object without contacting ProGet.

.NOTES
AI assisted using Powershell.instructions.md as guidelines

Tier: T1 (Phase 1, task T-19). Depends on T-12 (Get-TierFromNBGVLabel) for the
tier-to-feed mapping which is inlined here until T-12 is merged, and on T-30
(Get-ATAPIACConstant) for feed URI resolution which is stubbed by
Get-PSModuleFeedUri below.
#>
function Get-PSModuleFeedUri {
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory)]
    [string]$FeedName,

    [Parameter(Mandatory)]
    [string]$Tier
  )

  $fn = 'Get-PSModuleFeedUri'
  $mn = 'ATAP.Utilities.BuildTooling.PowerShell'

  # Map old Sprint/Alpha/Beta/Production tier names to canonical Experimental/Development/.../Stable.
  # QA maps to QA (unchanged). All others follow the standard tier rename.
  $canonicalTierMap = @{
    'Sprint'     = 'Experimental'
    'Alpha'      = 'Development'
    'Beta'       = 'Integration'
    'QA'         = 'QA'
    'Production' = 'Stable'
  }
  $canonicalTier = if ($canonicalTierMap.ContainsKey($Tier)) { $canonicalTierMap[$Tier] } else { $Tier }

  # 1. Resolve feed URI via Get-ATAPIACConstant (T-31).
  try {
    $constantName = "PowerShellGetFeedUrl_$canonicalTier"
    $uri = Get-ATAPIACConstant -Name $constantName
    if (-not [string]::IsNullOrWhiteSpace($uri)) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Resolved feed URI for tier '$Tier' (canonical '$canonicalTier') from Get-ATAPIACConstant '$constantName'"
      return $uri
    }
  } catch {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Get-ATAPIACConstant lookup failed for tier '$Tier'; falling back to env var. Error: $_"
  }

  # 2. User-scope environment variable fallback.
  $envName = "PROGET_POWERSHELLGET_FEED_URI_$($Tier.ToUpperInvariant())"
  $fromEnv = [Environment]::GetEnvironmentVariable($envName, 'User')
  if (-not [string]::IsNullOrWhiteSpace($fromEnv)) {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Resolved feed URI for tier '$Tier' from User env var '$envName'"
    return $fromEnv
  }

  $msg = "feed URI for tier '$Tier' is not configured. Set ATAP.IAC constant 'PowerShellGetFeedUrl_$canonicalTier' or User env var '$envName'."
  Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
  throw $msg
}

function Publish-PSModuleToProGetFeed {
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [string]$NupkgPath,

    [Parameter(Mandatory)]
    [ValidateSet('Sprint', 'Alpha', 'Beta', 'QA', 'Production')]
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

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn with NupkgPath='$NupkgPath' Tier='$Tier'" -Tag 'Trace'
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

    # 2. Map tier -> feed name via Get-ATAPIACConstant (T-31).
    # Maps old Sprint/Alpha/Beta/Production tier names to canonical Experimental/Development/.../Stable.
    $canonicalTierMap = @{
      'Sprint'     = 'Experimental'
      'Alpha'      = 'Development'
      'Beta'       = 'Integration'
      'QA'         = 'QA'
      'Production' = 'Stable'
    }
    $canonicalTier = if ($canonicalTierMap.ContainsKey($Tier)) { $canonicalTierMap[$Tier] } else { $Tier }
    $constantName = "PowerShellGetFeedName_$canonicalTier"
    try {
      $feedName = Get-ATAPIACConstant -Name $constantName
    } catch {
      $msg = "Could not resolve PowerShellGet feed name for tier '$Tier' (constant '$constantName'): $_"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }
    if ([string]::IsNullOrWhiteSpace($feedName)) {
      $msg = "Get-ATAPIACConstant returned empty value for '$constantName' (tier '$Tier')."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Resolved tier '$Tier' (canonical '$canonicalTier') to feed name '$feedName' via Get-ATAPIACConstant"

    # 3. Resolve feed URI via helper.
    $feedUri = Get-PSModuleFeedUri -FeedName $feedName -Tier $Tier
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Resolved feed URI for '$feedName'"

    # 4. Resolve API key: per-tier Bitwarden preferred, then per-tier User env
    #    var, then admin-key fallback (PROGET_ADMIN_API_KEY).
    #
    # SCOPE CREEP — REMOVE ADMIN-KEY FALLBACK ONCE PER-TIER KEYS EXIST
    # ----------------------------------------------------------------
    # The PROGET_ADMIN_API_KEY fallback below is a temporary bootstrap so local
    # builds and early sprint pipelines can publish before per-tier ProGet API
    # keys are minted, stored in Bitwarden, and documented. Once every tier
    # (Sprint/Alpha/Beta/QA/Production) has its own key in Bitwarden under
    # 'ProGet_PowerShellGet_<Tier>_ApiKey' and a documented rotation plan
    # exists, delete the fallback block and let this function throw when the
    # tier-specific key is missing. See scope-creep idea filed against this
    # function for the full backlog.
    $apiKey = $null
    $apiKeySource = $null
    $bwCmd = Get-Command -Name 'Get-BitWardenSecret' -ErrorAction SilentlyContinue
    if ($null -ne $bwCmd) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Attempting Get-BitWardenSecret for tier '$Tier'"
      try {
        $secretName = "ProGet_PowerShellGet_${Tier}_ApiKey"
        $apiKey = Get-BitWardenSecret -SecretName $secretName
        if (-not [string]::IsNullOrWhiteSpace([string]$apiKey)) {
          $apiKeySource = "Bitwarden secret '$secretName'"
        }
      } catch {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Get-BitWardenSecret threw; will fall back to env var'
        $apiKey = $null
      }
    }
    if ([string]::IsNullOrWhiteSpace([string]$apiKey)) {
      $envName = "PROGET_POWERSHELLGET_APIKEY_$Tier"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Falling back to User env var '$envName' for API key"
      $apiKey = [Environment]::GetEnvironmentVariable($envName, 'User')
      if (-not [string]::IsNullOrWhiteSpace([string]$apiKey)) {
        $apiKeySource = "User env var '$envName'"
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
          "'ProGet_PowerShellGet_${Tier}_ApiKey' in Bitwarden to remove this fallback."
        )
      }
    }
    if ([string]::IsNullOrWhiteSpace([string]$apiKey)) {
      $msg = "Unable to resolve ProGet API key for tier '$Tier'. Expected Get-BitWardenSecret -SecretName 'ProGet_PowerShellGet_${Tier}_ApiKey', User env var 'PROGET_POWERSHELLGET_APIKEY_$Tier', or admin fallback 'PROGET_ADMIN_API_KEY'."
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
