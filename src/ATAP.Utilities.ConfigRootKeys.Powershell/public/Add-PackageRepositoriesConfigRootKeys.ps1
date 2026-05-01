# AI assisted using Powershell.instructions.md as guidelines

<#
.SYNOPSIS
Adds ProGet / NuGet / PowerShellGet package-repository key constants to $global:configRootKeys.

.DESCRIPTION
Single source of truth for all ProGet package-repository ConfigRootKeys. Appends the
complete set of package-repository configuration key constants to the
$global:configRootKeys hashtable in one pass; no sub-fragment files are loaded.

The keys cover:

  - ProGet server endpoint components (scheme, host, port, base URL, service paths)
  - ProGet API keys
  - ProGet upstream connector names (nuget.org, PSGallery, Chocolatey)
  - Feed Collection / Promotion Tier Order
  - NuGet feed per-tier keys for the canonical five-tier pipeline
      (Experimental / Development / Integration / QA / Stable)
  - PowerShellGet feed per-tier keys for the same five tiers

Per the ProGet Feed Tier Dependency Build Report (Explainer 0111), the canonical
tier set is exactly five tiers. Earlier "Testing" and standalone "Production"
tier constants are intentionally not defined here.

The actual ProGet feed name VALUES (e.g. 'powershellget-experimental',
'nuget-experimental') are stored later in $global:settings using the keys defined
here. ProGet feed names are lowercase to match the actual feed names on the
ProGet server.

Tier-to-feed mapping:
  Experimental ← NBGV label -Sprint-  → nuget-experimental / powershellget-experimental
  Development  ← NBGV label -Alpha-   → nuget-development  / powershellget-development
  Integration  ← NBGV label -Beta-    → nuget-integration  / powershellget-integration
  QA           ← NBGV label -QA-      → nuget-qa           / powershellget-qa
  Stable       ← NBGV label (stable)  → nuget-stable       / powershellget-stable

Requires $global:configRootKeys to already exist (initialized by Set-CoreConfigRootKeys
via Set-GlobalConfigRootKeys).

.OUTPUTS
None. Populates $global:configRootKeys as a side effect.

.EXAMPLE
Add-PackageRepositoriesConfigRootKeys

Adds all package-repository key constants to $global:configRootKeys.

.EXAMPLE
Add-PackageRepositoriesConfigRootKeys -WhatIf

Shows which operations would be performed without modifying $global:configRootKeys.

.NOTES
AI assisted using Powershell.instructions.md as guidelines

.LINK
https://github.com/BillHertzing/ATAP.Utilities
#>

function Add-PackageRepositoriesConfigRootKeys {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
  [Alias()]
  [OutputType([void])]
  param ()

  begin {
    $fn = 'Add-PackageRepositoriesConfigRootKeys'
    $mn = 'ATAP.Utilities.ConfigRootKeys.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    if ($null -eq $global:configRootKeys) {
      $errorMessage = '$global:configRootKeys is not initialized. Run Set-GlobalConfigRootKeys (which loads Set-CoreConfigRootKeys.ps1 first).'
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw $errorMessage
    }
  }

  process {
    try {
      if ($PSCmdlet.ShouldProcess('$global:configRootKeys', 'Add package-repository key constants')) {

        # ── ProGet Server ─────────────────────────────────────────────────────
        $global:configRootKeys.Add('ProGetHostConfigRootKey', 'ProGetHost')
        $global:configRootKeys.Add('ProGetServiceExePathConfigRootKey', 'ProGetServiceExePath')
        $global:configRootKeys.Add('ProGetServiceConfigPathConfigRootKey', 'ProGetServiceConfigPath')
        $global:configRootKeys.Add('ProGetAdminUriSchemeConfigRootKey', 'ProGetAdminUriScheme')
        $global:configRootKeys.Add('ProGetAdminUriHostConfigRootKey', 'ProGetAdminUriHost')
        $global:configRootKeys.Add('ProGetAdminUriPortConfigRootKey', 'ProGetAdminUriPort')
        $global:configRootKeys.Add('ProGetBaseUrlConfigRootKey', 'ProGetBaseUrl')

        # ── ProGet API Keys ───────────────────────────────────────────────────
        $global:configRootKeys.Add('ProGetAdminApiKeyConfigRootKey', 'PROGET_ADMIN_API_KEY')
        $global:configRootKeys.Add('ProGetBuildMasterApiKeyConfigRootKey', 'PROGET_BUILDMASTER_API_KEY')

        # ── ProGet Connectors (upstream) ──────────────────────────────────────
        $global:configRootKeys.Add('ProGetConnectorNuGetOrgConfigRootKey', 'ProGetConnectorNuGetOrg')
        $global:configRootKeys.Add('ProGetConnectorPSGalleryConfigRootKey', 'ProGetConnectorPSGallery')
        $global:configRootKeys.Add('ProGetConnectorChocolateyOrgConfigRootKey', 'ProGetConnectorChocolateyOrg')

        # ── Feed Collection / Promotion Tier Order ────────────────────────────
        $global:configRootKeys.Add('ProGetFeedCollectionConfigRootKey', 'ProGetFeedCollection')
        $global:configRootKeys.Add('ProGetPromotionTierOrderConfigRootKey', 'ProGetPromotionTierOrder')

        # ══════════════════════════════════════════════════════════════════════
        #  NuGet feeds — five-tier canonical set
        #  Feed name values stored in $global:settings are lowercase:
        #    nuget-experimental, nuget-development, nuget-integration,
        #    nuget-qa, nuget-stable
        # ══════════════════════════════════════════════════════════════════════

        # ── nuget-experimental ────────────────────────────────────────────────
        $global:configRootKeys.Add('ProGetFeedNuGetExperimentalUriSchemeConfigRootKey', 'ProGetFeedNuGetExperimentalUriScheme')
        $global:configRootKeys.Add('ProGetFeedNuGetExperimentalUriHostConfigRootKey', 'ProGetFeedNuGetExperimentalUriHost')
        $global:configRootKeys.Add('ProGetFeedNuGetExperimentalUriPortConfigRootKey', 'ProGetFeedNuGetExperimentalUriPort')
        $global:configRootKeys.Add('ProGetFeedNuGetExperimentalUriPathConfigRootKey', 'ProGetFeedNuGetExperimentalUriPath')
        $global:configRootKeys.Add('ProGetFeedNuGetExperimentalUriQueryStringConfigRootKey', 'ProGetFeedNuGetExperimentalUriQueryString')
        $global:configRootKeys.Add('ProGetFeedNuGetExperimentalUriConfigRootKey', 'ProGetFeedNuGetExperimentalUri')
        $global:configRootKeys.Add('ProGetFeedNuGetExperimentalFeedNameConfigRootKey', 'ProGetFeedNuGetExperimentalFeedName')
        $global:configRootKeys.Add('ProGetFeedNuGetExperimentalFeedTypeConfigRootKey', 'ProGetFeedNuGetExperimentalFeedType')
        $global:configRootKeys.Add('ProGetFeedNuGetExperimentalApiKeyNameConfigRootKey', 'ProGetFeedNuGetExperimentalApiKeyName')
        $global:configRootKeys.Add('ProGetFeedNuGetExperimentalFeedConfigRootKey', 'ProGetFeedNuGetExperimental')

        # ── nuget-development ─────────────────────────────────────────────────
        $global:configRootKeys.Add('ProGetFeedNuGetDevelopmentUriSchemeConfigRootKey', 'ProGetFeedNuGetDevelopmentUriScheme')
        $global:configRootKeys.Add('ProGetFeedNuGetDevelopmentUriHostConfigRootKey', 'ProGetFeedNuGetDevelopmentUriHost')
        $global:configRootKeys.Add('ProGetFeedNuGetDevelopmentUriPortConfigRootKey', 'ProGetFeedNuGetDevelopmentUriPort')
        $global:configRootKeys.Add('ProGetFeedNuGetDevelopmentUriPathConfigRootKey', 'ProGetFeedNuGetDevelopmentUriPath')
        $global:configRootKeys.Add('ProGetFeedNuGetDevelopmentUriQueryStringConfigRootKey', 'ProGetFeedNuGetDevelopmentUriQueryString')
        $global:configRootKeys.Add('ProGetFeedNuGetDevelopmentUriConfigRootKey', 'ProGetFeedNuGetDevelopmentUri')
        $global:configRootKeys.Add('ProGetFeedNuGetDevelopmentFeedNameConfigRootKey', 'ProGetFeedNuGetDevelopmentFeedName')
        $global:configRootKeys.Add('ProGetFeedNuGetDevelopmentFeedTypeConfigRootKey', 'ProGetFeedNuGetDevelopmentFeedType')
        $global:configRootKeys.Add('ProGetFeedNuGetDevelopmentApiKeyNameConfigRootKey', 'ProGetFeedNuGetDevelopmentApiKeyName')
        $global:configRootKeys.Add('ProGetFeedNuGetDevelopmentFeedConfigRootKey', 'ProGetFeedNuGetDevelopment')

        # ── nuget-integration ─────────────────────────────────────────────────
        $global:configRootKeys.Add('ProGetFeedNuGetIntegrationUriSchemeConfigRootKey', 'ProGetFeedNuGetIntegrationUriScheme')
        $global:configRootKeys.Add('ProGetFeedNuGetIntegrationUriHostConfigRootKey', 'ProGetFeedNuGetIntegrationUriHost')
        $global:configRootKeys.Add('ProGetFeedNuGetIntegrationUriPortConfigRootKey', 'ProGetFeedNuGetIntegrationUriPort')
        $global:configRootKeys.Add('ProGetFeedNuGetIntegrationUriPathConfigRootKey', 'ProGetFeedNuGetIntegrationUriPath')
        $global:configRootKeys.Add('ProGetFeedNuGetIntegrationUriQueryStringConfigRootKey', 'ProGetFeedNuGetIntegrationUriQueryString')
        $global:configRootKeys.Add('ProGetFeedNuGetIntegrationUriConfigRootKey', 'ProGetFeedNuGetIntegrationUri')
        $global:configRootKeys.Add('ProGetFeedNuGetIntegrationFeedNameConfigRootKey', 'ProGetFeedNuGetIntegrationFeedName')
        $global:configRootKeys.Add('ProGetFeedNuGetIntegrationFeedTypeConfigRootKey', 'ProGetFeedNuGetIntegrationFeedType')
        $global:configRootKeys.Add('ProGetFeedNuGetIntegrationApiKeyNameConfigRootKey', 'ProGetFeedNuGetIntegrationApiKeyName')
        $global:configRootKeys.Add('ProGetFeedNuGetIntegrationFeedConfigRootKey', 'ProGetFeedNuGetIntegration')

        # ── nuget-qa ──────────────────────────────────────────────────────────
        $global:configRootKeys.Add('ProGetFeedNuGetQAUriSchemeConfigRootKey', 'ProGetFeedNuGetQAUriScheme')
        $global:configRootKeys.Add('ProGetFeedNuGetQAUriHostConfigRootKey', 'ProGetFeedNuGetQAUriHost')
        $global:configRootKeys.Add('ProGetFeedNuGetQAUriPortConfigRootKey', 'ProGetFeedNuGetQAUriPort')
        $global:configRootKeys.Add('ProGetFeedNuGetQAUriPathConfigRootKey', 'ProGetFeedNuGetQAUriPath')
        $global:configRootKeys.Add('ProGetFeedNuGetQAUriQueryStringConfigRootKey', 'ProGetFeedNuGetQAUriQueryString')
        $global:configRootKeys.Add('ProGetFeedNuGetQAUriConfigRootKey', 'ProGetFeedNuGetQAUri')
        $global:configRootKeys.Add('ProGetFeedNuGetQAFeedNameConfigRootKey', 'ProGetFeedNuGetQAFeedName')
        $global:configRootKeys.Add('ProGetFeedNuGetQAFeedTypeConfigRootKey', 'ProGetFeedNuGetQAFeedType')
        $global:configRootKeys.Add('ProGetFeedNuGetQAApiKeyNameConfigRootKey', 'ProGetFeedNuGetQAApiKeyName')
        $global:configRootKeys.Add('ProGetFeedNuGetQAFeedConfigRootKey', 'ProGetFeedNuGetQA')

        # ── nuget-stable ──────────────────────────────────────────────────────
        $global:configRootKeys.Add('ProGetFeedNuGetStableUriSchemeConfigRootKey', 'ProGetFeedNuGetStableUriScheme')
        $global:configRootKeys.Add('ProGetFeedNuGetStableUriHostConfigRootKey', 'ProGetFeedNuGetStableUriHost')
        $global:configRootKeys.Add('ProGetFeedNuGetStableUriPortConfigRootKey', 'ProGetFeedNuGetStableUriPort')
        $global:configRootKeys.Add('ProGetFeedNuGetStableUriPathConfigRootKey', 'ProGetFeedNuGetStableUriPath')
        $global:configRootKeys.Add('ProGetFeedNuGetStableUriQueryStringConfigRootKey', 'ProGetFeedNuGetStableUriQueryString')
        $global:configRootKeys.Add('ProGetFeedNuGetStableUriConfigRootKey', 'ProGetFeedNuGetStableUri')
        $global:configRootKeys.Add('ProGetFeedNuGetStableFeedNameConfigRootKey', 'ProGetFeedNuGetStableFeedName')
        $global:configRootKeys.Add('ProGetFeedNuGetStableFeedTypeConfigRootKey', 'ProGetFeedNuGetStableFeedType')
        $global:configRootKeys.Add('ProGetFeedNuGetStableApiKeyNameConfigRootKey', 'ProGetFeedNuGetStableApiKeyName')
        $global:configRootKeys.Add('ProGetFeedNuGetStableFeedConfigRootKey', 'ProGetFeedNuGetStable')

        # ══════════════════════════════════════════════════════════════════════
        #  PowerShellGet feeds — five-tier canonical set
        #  Feed name values stored in $global:settings are lowercase:
        #    powershellget-experimental, powershellget-development,
        #    powershellget-integration, powershellget-qa, powershellget-stable
        # ══════════════════════════════════════════════════════════════════════

        # ── powershellget-experimental ────────────────────────────────────────
        $global:configRootKeys.Add('ProGetFeedPowerShellExperimentalUriSchemeConfigRootKey', 'ProGetFeedPowerShellExperimentalUriScheme')
        $global:configRootKeys.Add('ProGetFeedPowerShellExperimentalUriHostConfigRootKey', 'ProGetFeedPowerShellExperimentalUriHost')
        $global:configRootKeys.Add('ProGetFeedPowerShellExperimentalUriPortConfigRootKey', 'ProGetFeedPowerShellExperimentalUriPort')
        $global:configRootKeys.Add('ProGetFeedPowerShellExperimentalUriPathConfigRootKey', 'ProGetFeedPowerShellExperimentalUriPath')
        $global:configRootKeys.Add('ProGetFeedPowerShellExperimentalUriQueryStringConfigRootKey', 'ProGetFeedPowerShellExperimentalUriQueryString')
        $global:configRootKeys.Add('ProGetFeedPowerShellExperimentalUriConfigRootKey', 'ProGetFeedPowerShellExperimentalUri')
        $global:configRootKeys.Add('ProGetFeedPowerShellExperimentalFeedNameConfigRootKey', 'ProGetFeedPowerShellExperimentalFeedName')
        $global:configRootKeys.Add('ProGetFeedPowerShellExperimentalFeedTypeConfigRootKey', 'ProGetFeedPowerShellExperimentalFeedType')
        $global:configRootKeys.Add('ProGetFeedPowerShellExperimentalApiKeyNameConfigRootKey', 'ProGetFeedPowerShellExperimentalApiKeyName')
        $global:configRootKeys.Add('ProGetFeedPowerShellExperimentalFeedConfigRootKey', 'ProGetFeedPowerShellExperimental')

        # ── powershellget-development ─────────────────────────────────────────
        $global:configRootKeys.Add('ProGetFeedPowerShellDevelopmentUriSchemeConfigRootKey', 'ProGetFeedPowerShellDevelopmentUriScheme')
        $global:configRootKeys.Add('ProGetFeedPowerShellDevelopmentUriHostConfigRootKey', 'ProGetFeedPowerShellDevelopmentUriHost')
        $global:configRootKeys.Add('ProGetFeedPowerShellDevelopmentUriPortConfigRootKey', 'ProGetFeedPowerShellDevelopmentUriPort')
        $global:configRootKeys.Add('ProGetFeedPowerShellDevelopmentUriPathConfigRootKey', 'ProGetFeedPowerShellDevelopmentUriPath')
        $global:configRootKeys.Add('ProGetFeedPowerShellDevelopmentUriQueryStringConfigRootKey', 'ProGetFeedPowerShellDevelopmentUriQueryString')
        $global:configRootKeys.Add('ProGetFeedPowerShellDevelopmentUriConfigRootKey', 'ProGetFeedPowerShellDevelopmentUri')
        $global:configRootKeys.Add('ProGetFeedPowerShellDevelopmentFeedNameConfigRootKey', 'ProGetFeedPowerShellDevelopmentFeedName')
        $global:configRootKeys.Add('ProGetFeedPowerShellDevelopmentFeedTypeConfigRootKey', 'ProGetFeedPowerShellDevelopmentFeedType')
        $global:configRootKeys.Add('ProGetFeedPowerShellDevelopmentApiKeyNameConfigRootKey', 'ProGetFeedPowerShellDevelopmentApiKeyName')
        $global:configRootKeys.Add('ProGetFeedPowerShellDevelopmentFeedConfigRootKey', 'ProGetFeedPowerShellDevelopment')

        # ── powershellget-integration ─────────────────────────────────────────
        $global:configRootKeys.Add('ProGetFeedPowerShellIntegrationUriSchemeConfigRootKey', 'ProGetFeedPowerShellIntegrationUriScheme')
        $global:configRootKeys.Add('ProGetFeedPowerShellIntegrationUriHostConfigRootKey', 'ProGetFeedPowerShellIntegrationUriHost')
        $global:configRootKeys.Add('ProGetFeedPowerShellIntegrationUriPortConfigRootKey', 'ProGetFeedPowerShellIntegrationUriPort')
        $global:configRootKeys.Add('ProGetFeedPowerShellIntegrationUriPathConfigRootKey', 'ProGetFeedPowerShellIntegrationUriPath')
        $global:configRootKeys.Add('ProGetFeedPowerShellIntegrationUriQueryStringConfigRootKey', 'ProGetFeedPowerShellIntegrationUriQueryString')
        $global:configRootKeys.Add('ProGetFeedPowerShellIntegrationUriConfigRootKey', 'ProGetFeedPowerShellIntegrationUri')
        $global:configRootKeys.Add('ProGetFeedPowerShellIntegrationFeedNameConfigRootKey', 'ProGetFeedPowerShellIntegrationFeedName')
        $global:configRootKeys.Add('ProGetFeedPowerShellIntegrationFeedTypeConfigRootKey', 'ProGetFeedPowerShellIntegrationFeedType')
        $global:configRootKeys.Add('ProGetFeedPowerShellIntegrationApiKeyNameConfigRootKey', 'ProGetFeedPowerShellIntegrationApiKeyName')
        $global:configRootKeys.Add('ProGetFeedPowerShellIntegrationFeedConfigRootKey', 'ProGetFeedPowerShellIntegration')

        # ── powershellget-qa ──────────────────────────────────────────────────
        $global:configRootKeys.Add('ProGetFeedPowerShellQAUriSchemeConfigRootKey', 'ProGetFeedPowerShellQAUriScheme')
        $global:configRootKeys.Add('ProGetFeedPowerShellQAUriHostConfigRootKey', 'ProGetFeedPowerShellQAUriHost')
        $global:configRootKeys.Add('ProGetFeedPowerShellQAUriPortConfigRootKey', 'ProGetFeedPowerShellQAUriPort')
        $global:configRootKeys.Add('ProGetFeedPowerShellQAUriPathConfigRootKey', 'ProGetFeedPowerShellQAUriPath')
        $global:configRootKeys.Add('ProGetFeedPowerShellQAUriQueryStringConfigRootKey', 'ProGetFeedPowerShellQAUriQueryString')
        $global:configRootKeys.Add('ProGetFeedPowerShellQAUriConfigRootKey', 'ProGetFeedPowerShellQAUri')
        $global:configRootKeys.Add('ProGetFeedPowerShellQAFeedNameConfigRootKey', 'ProGetFeedPowerShellQAFeedName')
        $global:configRootKeys.Add('ProGetFeedPowerShellQAFeedTypeConfigRootKey', 'ProGetFeedPowerShellQAFeedType')
        $global:configRootKeys.Add('ProGetFeedPowerShellQAApiKeyNameConfigRootKey', 'ProGetFeedPowerShellQAApiKeyName')
        $global:configRootKeys.Add('ProGetFeedPowerShellQAFeedConfigRootKey', 'ProGetFeedPowerShellQA')

        # ── powershellget-stable ──────────────────────────────────────────────
        $global:configRootKeys.Add('ProGetFeedPowerShellStableUriSchemeConfigRootKey', 'ProGetFeedPowerShellStableUriScheme')
        $global:configRootKeys.Add('ProGetFeedPowerShellStableUriHostConfigRootKey', 'ProGetFeedPowerShellStableUriHost')
        $global:configRootKeys.Add('ProGetFeedPowerShellStableUriPortConfigRootKey', 'ProGetFeedPowerShellStableUriPort')
        $global:configRootKeys.Add('ProGetFeedPowerShellStableUriPathConfigRootKey', 'ProGetFeedPowerShellStableUriPath')
        $global:configRootKeys.Add('ProGetFeedPowerShellStableUriQueryStringConfigRootKey', 'ProGetFeedPowerShellStableUriQueryString')
        $global:configRootKeys.Add('ProGetFeedPowerShellStableUriConfigRootKey', 'ProGetFeedPowerShellStableUri')
        $global:configRootKeys.Add('ProGetFeedPowerShellStableFeedNameConfigRootKey', 'ProGetFeedPowerShellStableFeedName')
        $global:configRootKeys.Add('ProGetFeedPowerShellStableFeedTypeConfigRootKey', 'ProGetFeedPowerShellStableFeedType')
        $global:configRootKeys.Add('ProGetFeedPowerShellStableApiKeyNameConfigRootKey', 'ProGetFeedPowerShellStableApiKeyName')
        $global:configRootKeys.Add('ProGetFeedPowerShellStableFeedConfigRootKey', 'ProGetFeedPowerShellStable')

        # ── PackageRepositories Collection ────────────────────────────────────
        $global:configRootKeys.Add('PackageRepositoriesCollectionConfigRootKey', 'PackageRepositoriesCollection')

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Added package-repository key constants.'
      }
    } catch {
      $errorMessage = "Unhandled error in $fn. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    } finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving process block in $fn"
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
