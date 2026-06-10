###################################################
## GlobalConfigRootKeys.ps1 — ProGet Section (Phase 1)
##
## OBSOLETE — SUPERSEDED — DO NOT EDIT, DO NOT LOAD
##
## The single source of truth for ProGet / NuGet / PowerShellGet feed key
## constants is now:
##   src/ATAP.Utilities.ConfigRootKeys.Powershell/public/Add-PackageRepositoriesConfigRootKeys.ps1
## loaded by Set-GlobalConfigRootKeys (Phase 5). That file defines the canonical
## FIVE-tier set (Experimental / Development / Integration / QA / Stable) and the
## feed-name VALUES are assigned in ATAP.IAC
##   Windows/HostSettings.IAC.Fragments/HostSettings.IAC.Fragment.PackageRepositories.ps1
## using lowercase canonical names (powershellget-experimental … powershellget-stable).
##
## This fragment is no longer dot-sourced by any loader; it is retained on disk
## for diff/reference only and uses the OLD four-tier scheme
## (Experimental/Development/Testing/Production). It will be deleted in a future
## cleanup step.
##
## NOTE: An earlier comment below claimed the live feeds use a 'PowershellGallery-'
## prefix. That claim is INCORRECT and has been corrected — the canonical ProGet
## PowerShellGet feed names are lowercase 'powershellget-<tier>'.
##
## ──── ORIGINAL HEADER (kept for reference) ───────────────────────────────
## Drop-in replacement for the ProGet-related keys.
## This section defines string constants used as dictionary keys
## throughout the settings system. Values are assigned in HostSettings.ps1
## and the IAC Fragment files.
##
## Phase 1: 8 combined feeds (no push/pull split).
## Phase 2: Uncomment the -Push keys to add push feed entries.
##
## Feed naming: ProGetFeed{PackageType}{Tier}{Component}ConfigRootKey
## API key naming: ProGetApiKey{Scope}ConfigRootKey
## Connector naming: ProGetConnector{Name}ConfigRootKey
###################################################

# ── ProGet Server ────────────────────────────────────────────────────────
$global:configRootKeys['ProGetHostConfigRootKey'] = 'ProGetHost'
$global:configRootKeys['ProGetServiceExePathConfigRootKey'] = 'ProGetServiceExePath'
$global:configRootKeys['ProGetServiceConfigPathConfigRootKey'] = 'ProGetServiceConfigPath'
$global:configRootKeys['ProGetAdminUriSchemeConfigRootKey'] = 'ProGetAdminUriScheme'
$global:configRootKeys['ProGetAdminUriHostConfigRootKey'] = 'ProGetAdminUriHost'
$global:configRootKeys['ProGetAdminUriPortConfigRootKey'] = 'ProGetAdminUriPort'
$global:configRootKeys['ProGetBaseUrlConfigRootKey'] = 'ProGetBaseUrl'

# ── ProGet API Keys ──────────────────────────────────────────────────────
$global:configRootKeys['ProGetAdminApiKeyConfigRootKey'] = 'PROGET_ADMIN_API_KEY'
$global:configRootKeys['ProGetBuildMasterApiKeyConfigRootKey'] = 'PROGET_BUILDMASTER_API_KEY'
# Phase 2 per-feed API keys (uncomment when push/pull feeds are created):
# $global:configRootKeys['ProGetApiKeyNuGetExperimentalPushConfigRootKey']    = 'PROGET_APIKEY_NUGET_EXPERIMENTAL_PUSH'
# $global:configRootKeys['ProGetApiKeyNuGetExperimentalPullConfigRootKey']    = 'PROGET_APIKEY_NUGET_EXPERIMENTAL_PULL'
# $global:configRootKeys['ProGetApiKeyNuGetDevelopmentPushConfigRootKey']     = 'PROGET_APIKEY_NUGET_DEVELOPMENT_PUSH'
# $global:configRootKeys['ProGetApiKeyNuGetDevelopmentPullConfigRootKey']     = 'PROGET_APIKEY_NUGET_DEVELOPMENT_PULL'
# $global:configRootKeys['ProGetApiKeyNuGetTestingPushConfigRootKey']         = 'PROGET_APIKEY_NUGET_TESTING_PUSH'
# $global:configRootKeys['ProGetApiKeyNuGetTestingPullConfigRootKey']         = 'PROGET_APIKEY_NUGET_TESTING_PULL'
# $global:configRootKeys['ProGetApiKeyNuGetProductionPushConfigRootKey']      = 'PROGET_APIKEY_NUGET_PRODUCTION_PUSH'
# $global:configRootKeys['ProGetApiKeyNuGetProductionPullConfigRootKey']      = 'PROGET_APIKEY_NUGET_PRODUCTION_PULL'
# $global:configRootKeys['ProGetApiKeyPowerShellExperimentalPushConfigRootKey'] = 'PROGET_APIKEY_POWERSHELL_EXPERIMENTAL_PUSH'
# ... (same pattern for all PowerShell and Chocolatey feeds)

# ── ProGet Connectors ────────────────────────────────────────────────────
$global:configRootKeys['ProGetConnectorNuGetOrgConfigRootKey'] = 'ProGetConnectorNuGetOrg'
$global:configRootKeys['ProGetConnectorPSGalleryConfigRootKey'] = 'ProGetConnectorPSGallery'
$global:configRootKeys['ProGetConnectorChocolateyOrgConfigRootKey'] = 'ProGetConnectorChocolateyOrg'

# ── Feed Collection ──────────────────────────────────────────────────────
$global:configRootKeys['ProGetFeedCollectionConfigRootKey'] = 'ProGetFeedCollection'
# Promotion tier order (array of tier names, lowest to highest)
$global:configRootKeys['ProGetPromotionTierOrderConfigRootKey'] = 'ProGetPromotionTierOrder'

# ══════════════════════════════════════════════════════════════════════════
#  NuGet Feeds — Phase 1 (combined push/pull per tier)
# ══════════════════════════════════════════════════════════════════════════

# ── nuget-experimental ───────────────────────────────────────────────────
$global:configRootKeys['ProGetFeedNuGetExperimentalUriSchemeConfigRootKey'] = 'ProGetFeedNuGetExperimentalUriScheme'
$global:configRootKeys['ProGetFeedNuGetExperimentalUriHostConfigRootKey'] = 'ProGetFeedNuGetExperimentalUriHost'
$global:configRootKeys['ProGetFeedNuGetExperimentalUriPortConfigRootKey'] = 'ProGetFeedNuGetExperimentalUriPort'
$global:configRootKeys['ProGetFeedNuGetExperimentalUriPathConfigRootKey'] = 'ProGetFeedNuGetExperimentalUriPath'
$global:configRootKeys['ProGetFeedNuGetExperimentalUriQueryStringConfigRootKey'] = 'ProGetFeedNuGetExperimentalUriQueryString'
$global:configRootKeys['ProGetFeedNuGetExperimentalUriConfigRootKey'] = 'ProGetFeedNuGetExperimentalUri'
$global:configRootKeys['ProGetFeedNuGetExperimentalFeedNameConfigRootKey'] = 'ProGetFeedNuGetExperimentalFeedName'
$global:configRootKeys['ProGetFeedNuGetExperimentalFeedTypeConfigRootKey'] = 'ProGetFeedNuGetExperimentalFeedType'
$global:configRootKeys['ProGetFeedNuGetExperimentalApiKeyNameConfigRootKey'] = 'ProGetFeedNuGetExperimentalApiKeyName'
$global:configRootKeys['ProGetFeedNuGetExperimentalFeedConfigRootKey'] = 'ProGetFeedNuGetExperimental'

# ── nuget-development ────────────────────────────────────────────────────
$global:configRootKeys['ProGetFeedNuGetDevelopmentUriSchemeConfigRootKey'] = 'ProGetFeedNuGetDevelopmentUriScheme'
$global:configRootKeys['ProGetFeedNuGetDevelopmentUriHostConfigRootKey'] = 'ProGetFeedNuGetDevelopmentUriHost'
$global:configRootKeys['ProGetFeedNuGetDevelopmentUriPortConfigRootKey'] = 'ProGetFeedNuGetDevelopmentUriPort'
$global:configRootKeys['ProGetFeedNuGetDevelopmentUriPathConfigRootKey'] = 'ProGetFeedNuGetDevelopmentUriPath'
$global:configRootKeys['ProGetFeedNuGetDevelopmentUriQueryStringConfigRootKey'] = 'ProGetFeedNuGetDevelopmentUriQueryString'
$global:configRootKeys['ProGetFeedNuGetDevelopmentUriConfigRootKey'] = 'ProGetFeedNuGetDevelopmentUri'
$global:configRootKeys['ProGetFeedNuGetDevelopmentFeedNameConfigRootKey'] = 'ProGetFeedNuGetDevelopmentFeedName'
$global:configRootKeys['ProGetFeedNuGetDevelopmentFeedTypeConfigRootKey'] = 'ProGetFeedNuGetDevelopmentFeedType'
$global:configRootKeys['ProGetFeedNuGetDevelopmentApiKeyNameConfigRootKey'] = 'ProGetFeedNuGetDevelopmentApiKeyName'
$global:configRootKeys['ProGetFeedNuGetDevelopmentFeedConfigRootKey'] = 'ProGetFeedNuGetDevelopment'

# ── nuget-testing ────────────────────────────────────────────────────────
$global:configRootKeys['ProGetFeedNuGetTestingUriSchemeConfigRootKey'] = 'ProGetFeedNuGetTestingUriScheme'
$global:configRootKeys['ProGetFeedNuGetTestingUriHostConfigRootKey'] = 'ProGetFeedNuGetTestingUriHost'
$global:configRootKeys['ProGetFeedNuGetTestingUriPortConfigRootKey'] = 'ProGetFeedNuGetTestingUriPort'
$global:configRootKeys['ProGetFeedNuGetTestingUriPathConfigRootKey'] = 'ProGetFeedNuGetTestingUriPath'
$global:configRootKeys['ProGetFeedNuGetTestingUriQueryStringConfigRootKey'] = 'ProGetFeedNuGetTestingUriQueryString'
$global:configRootKeys['ProGetFeedNuGetTestingUriConfigRootKey'] = 'ProGetFeedNuGetTestingUri'
$global:configRootKeys['ProGetFeedNuGetTestingFeedNameConfigRootKey'] = 'ProGetFeedNuGetTestingFeedName'
$global:configRootKeys['ProGetFeedNuGetTestingFeedTypeConfigRootKey'] = 'ProGetFeedNuGetTestingFeedType'
$global:configRootKeys['ProGetFeedNuGetTestingApiKeyNameConfigRootKey'] = 'ProGetFeedNuGetTestingApiKeyName'
$global:configRootKeys['ProGetFeedNuGetTestingFeedConfigRootKey'] = 'ProGetFeedNuGetTesting'

# ── nuget-production ─────────────────────────────────────────────────────
$global:configRootKeys['ProGetFeedNuGetProductionUriSchemeConfigRootKey'] = 'ProGetFeedNuGetProductionUriScheme'
$global:configRootKeys['ProGetFeedNuGetProductionUriHostConfigRootKey'] = 'ProGetFeedNuGetProductionUriHost'
$global:configRootKeys['ProGetFeedNuGetProductionUriPortConfigRootKey'] = 'ProGetFeedNuGetProductionUriPort'
$global:configRootKeys['ProGetFeedNuGetProductionUriPathConfigRootKey'] = 'ProGetFeedNuGetProductionUriPath'
$global:configRootKeys['ProGetFeedNuGetProductionUriQueryStringConfigRootKey'] = 'ProGetFeedNuGetProductionUriQueryString'
$global:configRootKeys['ProGetFeedNuGetProductionUriConfigRootKey'] = 'ProGetFeedNuGetProductionUri'
$global:configRootKeys['ProGetFeedNuGetProductionFeedNameConfigRootKey'] = 'ProGetFeedNuGetProductionFeedName'
$global:configRootKeys['ProGetFeedNuGetProductionFeedTypeConfigRootKey'] = 'ProGetFeedNuGetProductionFeedType'
$global:configRootKeys['ProGetFeedNuGetProductionApiKeyNameConfigRootKey'] = 'ProGetFeedNuGetProductionApiKeyName'
$global:configRootKeys['ProGetFeedNuGetProductionFeedConfigRootKey'] = 'ProGetFeedNuGetProduction'

# ══════════════════════════════════════════════════════════════════════════
#  PowerShell Feeds — Phase 1 (combined push/pull per tier)
#  CORRECTED: the canonical ProGet PowerShellGet feed names are lowercase
#  'powershellget-<tier>' (e.g. powershellget-experimental). These keys hold
#  the feed name as a value set in HostSettings (ATAP.IAC). The earlier
#  'PowershellGallery-' claim was wrong and caused Install-PSResource 404s.
# ══════════════════════════════════════════════════════════════════════════

# ── powershellget-experimental ───────────────────────────────────────────
$global:configRootKeys['ProGetFeedPowerShellExperimentalUriSchemeConfigRootKey'] = 'ProGetFeedPowerShellExperimentalUriScheme'
$global:configRootKeys['ProGetFeedPowerShellExperimentalUriHostConfigRootKey'] = 'ProGetFeedPowerShellExperimentalUriHost'
$global:configRootKeys['ProGetFeedPowerShellExperimentalUriPortConfigRootKey'] = 'ProGetFeedPowerShellExperimentalUriPort'
$global:configRootKeys['ProGetFeedPowerShellExperimentalUriPathConfigRootKey'] = 'ProGetFeedPowerShellExperimentalUriPath'
$global:configRootKeys['ProGetFeedPowerShellExperimentalUriQueryStringConfigRootKey'] = 'ProGetFeedPowerShellExperimentalUriQueryString'
$global:configRootKeys['ProGetFeedPowerShellExperimentalUriConfigRootKey'] = 'ProGetFeedPowerShellExperimentalUri'
$global:configRootKeys['ProGetFeedPowerShellExperimentalFeedNameConfigRootKey'] = 'ProGetFeedPowerShellExperimentalFeedName'
$global:configRootKeys['ProGetFeedPowerShellExperimentalFeedTypeConfigRootKey'] = 'ProGetFeedPowerShellExperimentalFeedType'
$global:configRootKeys['ProGetFeedPowerShellExperimentalApiKeyNameConfigRootKey'] = 'ProGetFeedPowerShellExperimentalApiKeyName'
$global:configRootKeys['ProGetFeedPowerShellExperimentalFeedConfigRootKey'] = 'ProGetFeedPowerShellExperimental'

# ── powershellget-development ─────────────────────────────────────────────
$global:configRootKeys['ProGetFeedPowerShellDevelopmentUriSchemeConfigRootKey'] = 'ProGetFeedPowerShellDevelopmentUriScheme'
$global:configRootKeys['ProGetFeedPowerShellDevelopmentUriHostConfigRootKey'] = 'ProGetFeedPowerShellDevelopmentUriHost'
$global:configRootKeys['ProGetFeedPowerShellDevelopmentUriPortConfigRootKey'] = 'ProGetFeedPowerShellDevelopmentUriPort'
$global:configRootKeys['ProGetFeedPowerShellDevelopmentUriPathConfigRootKey'] = 'ProGetFeedPowerShellDevelopmentUriPath'
$global:configRootKeys['ProGetFeedPowerShellDevelopmentUriQueryStringConfigRootKey'] = 'ProGetFeedPowerShellDevelopmentUriQueryString'
$global:configRootKeys['ProGetFeedPowerShellDevelopmentUriConfigRootKey'] = 'ProGetFeedPowerShellDevelopmentUri'
$global:configRootKeys['ProGetFeedPowerShellDevelopmentFeedNameConfigRootKey'] = 'ProGetFeedPowerShellDevelopmentFeedName'
$global:configRootKeys['ProGetFeedPowerShellDevelopmentFeedTypeConfigRootKey'] = 'ProGetFeedPowerShellDevelopmentFeedType'
$global:configRootKeys['ProGetFeedPowerShellDevelopmentApiKeyNameConfigRootKey'] = 'ProGetFeedPowerShellDevelopmentApiKeyName'
$global:configRootKeys['ProGetFeedPowerShellDevelopmentFeedConfigRootKey'] = 'ProGetFeedPowerShellDevelopment'

# ── powershellget-testing (legacy 4-tier; superseded by integration/qa) ───
$global:configRootKeys['ProGetFeedPowerShellTestingUriSchemeConfigRootKey'] = 'ProGetFeedPowerShellTestingUriScheme'
$global:configRootKeys['ProGetFeedPowerShellTestingUriHostConfigRootKey'] = 'ProGetFeedPowerShellTestingUriHost'
$global:configRootKeys['ProGetFeedPowerShellTestingUriPortConfigRootKey'] = 'ProGetFeedPowerShellTestingUriPort'
$global:configRootKeys['ProGetFeedPowerShellTestingUriPathConfigRootKey'] = 'ProGetFeedPowerShellTestingUriPath'
$global:configRootKeys['ProGetFeedPowerShellTestingUriQueryStringConfigRootKey'] = 'ProGetFeedPowerShellTestingUriQueryString'
$global:configRootKeys['ProGetFeedPowerShellTestingUriConfigRootKey'] = 'ProGetFeedPowerShellTestingUri'
$global:configRootKeys['ProGetFeedPowerShellTestingFeedNameConfigRootKey'] = 'ProGetFeedPowerShellTestingFeedName'
$global:configRootKeys['ProGetFeedPowerShellTestingFeedTypeConfigRootKey'] = 'ProGetFeedPowerShellTestingFeedType'
$global:configRootKeys['ProGetFeedPowerShellTestingApiKeyNameConfigRootKey'] = 'ProGetFeedPowerShellTestingApiKeyName'
$global:configRootKeys['ProGetFeedPowerShellTestingFeedConfigRootKey'] = 'ProGetFeedPowerShellTesting'

# ── powershellget-production (legacy 4-tier; superseded by stable) ────────
$global:configRootKeys['ProGetFeedPowerShellProductionUriSchemeConfigRootKey'] = 'ProGetFeedPowerShellProductionUriScheme'
$global:configRootKeys['ProGetFeedPowerShellProductionUriHostConfigRootKey'] = 'ProGetFeedPowerShellProductionUriHost'
$global:configRootKeys['ProGetFeedPowerShellProductionUriPortConfigRootKey'] = 'ProGetFeedPowerShellProductionUriPort'
$global:configRootKeys['ProGetFeedPowerShellProductionUriPathConfigRootKey'] = 'ProGetFeedPowerShellProductionUriPath'
$global:configRootKeys['ProGetFeedPowerShellProductionUriQueryStringConfigRootKey'] = 'ProGetFeedPowerShellProductionUriQueryString'
$global:configRootKeys['ProGetFeedPowerShellProductionUriConfigRootKey'] = 'ProGetFeedPowerShellProductionUri'
$global:configRootKeys['ProGetFeedPowerShellProductionFeedNameConfigRootKey'] = 'ProGetFeedPowerShellProductionFeedName'
$global:configRootKeys['ProGetFeedPowerShellProductionFeedTypeConfigRootKey'] = 'ProGetFeedPowerShellProductionFeedType'
$global:configRootKeys['ProGetFeedPowerShellProductionApiKeyNameConfigRootKey'] = 'ProGetFeedPowerShellProductionApiKeyName'
$global:configRootKeys['ProGetFeedPowerShellProductionFeedConfigRootKey'] = 'ProGetFeedPowerShellProduction'

# ══════════════════════════════════════════════════════════════════════════
#  Chocolatey Feeds — DEFERRED (uncomment when Chocolatey packaging begins)
# ══════════════════════════════════════════════════════════════════════════
# Same pattern as NuGet: ProGetFeedChocolatey{Tier}{Component}ConfigRootKey
# $global:configRootKeys['ProGetFeedChocolateyExperimentalUriSchemeConfigRootKey']       = 'ProGetFeedChocolateyExperimentalUriScheme'
# ... (repeat pattern for all 4 tiers × 10 keys each)

###################################################
