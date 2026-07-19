<#
.SYNOPSIS
Publishes a PowerShell module .nupkg to the correct ProGet PowerShellGet feed
for a given 5-Tier tier.

.DESCRIPTION
Maps a canonical tier name (Experimental/Development/Integration/QA/Production)
to a PowerShellGet feed
name and endpoint from $global:Settings using the ProGet feed collection
defined by ATAP.Utilities.ConfigRootKeys.PowerShell and host settings,
resolves the API key named by -ProGetApiKeySecretName via Get-SecretATAP,
ensures a matching
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

.PARAMETER ProGetApiKeySecretName
Bitwarden Secrets Manager SecretName for the ProGet publishing key. Raw key
parameters and environment-variable fallbacks are intentionally unsupported.

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

    [switch]$AllowTierOverride,

    [ValidateNotNullOrEmpty()]
    [string]$ProGetApiKeySecretName = 'ProGet.BuildMaster.API.Key'
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

    # 3. WhatIf short-circuit before secret lookup, repository mutation, or publish.
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

    # 4. Ensure the PSResourceRepository is registered with the right URI.
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

    # 5. Resolve the key only at the authenticated-operation boundary.
    try {
      $apiKey = [string](Get-SecretATAP -SecretName $ProGetApiKeySecretName -SecretStoreType 'BitwardenSecretsManager' -ErrorAction Stop)
    } catch {
      throw "Unable to resolve the ProGet API key from SecretName '$ProGetApiKeySecretName'."
    }
    if ([string]::IsNullOrWhiteSpace($apiKey)) {
      throw "The ProGet secret named '$ProGetApiKeySecretName' resolved to an empty value."
    }

    # 6. Publish.
    $published = $false
    $summary = $null
    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling Publish-PSResource for '$feedName'"
      $result = Publish-PSResource -NupkgPath $resolvedNupkg -Repository $feedName -ApiKey $apiKey
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from Publish-PSResource for '$feedName'"
      $published = $true
      if ($null -ne $result) {
        $summary = ("Publish-PSResource returned: $($result | Out-String)".Trim()).Replace($apiKey, '***')
      } else {
        $summary = 'Publish-PSResource completed without returning an object.'
      }
    } catch {
      $exceptionMessage = ([string]$_.Exception.Message).Replace($apiKey, '***')
      $msg = "Publish-PSResource failed for '$resolvedNupkg' to '$feedName': $exceptionMessage"
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
