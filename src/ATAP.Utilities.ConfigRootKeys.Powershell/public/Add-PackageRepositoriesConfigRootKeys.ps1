# AI assisted using Powershell.instructions.md as guidelines

<#
.SYNOPSIS
Adds ProGet / NuGet / PowerShellGet package-repository key constants to $global:configRootKeys.

.DESCRIPTION
Appends the standard set of package-repository configuration key constants to the
$global:configRootKeys hashtable. These keys cover:

  - ProGet server endpoint components (scheme, host, port, base URL)
  - ProGet API keys and connector names
  - NuGet feed per-tier keys (Experimental / Development / Testing / Production / Integration / QA / Stable)
  - PowerShellGet feed per-tier keys (same seven tiers)
  - Short-form canonical aliases used by Get-ATAPIACConstant and Publish-PSModuleToProGetFeed
    (PowerShellGetFeedName_*, PowerShellGetFeedUri_*, NuGetFeedName_*, NuGetFeedUri_*)

Also scans the same directory for sub-fragment files matching the pattern
'PackageRepositories.*.ConfigRootKeys.ps1' and dot-sources each one. Sub-fragments
add per-feed-set or per-host key overrides.

Requires $global:configRootKeys to already exist (initialized by Set-CoreConfigRootKeys
via Set-GlobalConfigRootKeys).

.OUTPUTS
None. Populates $global:configRootKeys as a side effect.

.EXAMPLE
Add-PackageRepositoriesConfigRootKeys

Adds all package-repository key constants and loads any PackageRepositories.* sub-fragments.
found alongside this script.

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

    $scriptFile = $MyInvocation.MyCommand.ScriptBlock.File
    $scriptDir = if (-not [string]::IsNullOrEmpty($scriptFile)) {
      [System.IO.Path]::GetDirectoryName($scriptFile)
    } else {
      $PWD.ProviderPath
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

        # ── ProGet Connectors ─────────────────────────────────────────────────
        $global:configRootKeys.Add('ProGetConnectorNuGetOrgConfigRootKey', 'ProGetConnectorNuGetOrg')
        $global:configRootKeys.Add('ProGetConnectorPSGalleryConfigRootKey', 'ProGetConnectorPSGallery')
        $global:configRootKeys.Add('ProGetConnectorChocolateyOrgConfigRootKey', 'ProGetConnectorChocolateyOrg')

        # ── Feed Collection ───────────────────────────────────────────────────
        $global:configRootKeys.Add('ProGetFeedCollectionConfigRootKey', 'ProGetFeedCollection')
        $global:configRootKeys.Add('ProGetPromotionTierOrderConfigRootKey', 'ProGetPromotionTierOrder')

        # ── Short-form canonical aliases for Get-ATAPIACConstant ──────────────
        # These map the canonical tier names used by Publish-PSModuleToProGetFeed and
        # Get-ATAPIACConstant to the full settings keys defined above.
        # Tier mapping: Sprint=Experimental, Alpha=Development, Beta=Integration, QA=QA, Stable=Stable
        $global:configRootKeys.Add('PowerShellGetFeedName_Experimental', 'ProGetFeedPowerShellExperimentalFeedName')
        $global:configRootKeys.Add('PowerShellGetFeedName_Development', 'ProGetFeedPowerShellDevelopmentFeedName')
        $global:configRootKeys.Add('PowerShellGetFeedName_Integration', 'ProGetFeedPowerShellIntegrationFeedName')
        $global:configRootKeys.Add('PowerShellGetFeedName_QA', 'ProGetFeedPowerShellQAFeedName')
        $global:configRootKeys.Add('PowerShellGetFeedName_Stable', 'ProGetFeedPowerShellStableFeedName')
        $global:configRootKeys.Add('PowerShellGetFeedUri_Experimental', 'ProGetFeedPowerShellExperimentalUri')
        $global:configRootKeys.Add('PowerShellGetFeedUri_Development', 'ProGetFeedPowerShellDevelopmentUri')
        $global:configRootKeys.Add('PowerShellGetFeedUri_Integration', 'ProGetFeedPowerShellIntegrationUri')
        $global:configRootKeys.Add('PowerShellGetFeedUri_QA', 'ProGetFeedPowerShellQAUri')
        $global:configRootKeys.Add('PowerShellGetFeedUri_Stable', 'ProGetFeedPowerShellStableUri')
        $global:configRootKeys.Add('NuGetFeedName_Experimental', 'ProGetFeedNuGetExperimentalFeedName')
        $global:configRootKeys.Add('NuGetFeedName_Development', 'ProGetFeedNuGetDevelopmentFeedName')
        $global:configRootKeys.Add('NuGetFeedName_Integration', 'ProGetFeedNuGetIntegrationFeedName')
        $global:configRootKeys.Add('NuGetFeedName_QA', 'ProGetFeedNuGetQAFeedName')
        $global:configRootKeys.Add('NuGetFeedName_Stable', 'ProGetFeedNuGetStableFeedName')
        $global:configRootKeys.Add('NuGetFeedUri_Experimental', 'ProGetFeedNuGetExperimentalUri')
        $global:configRootKeys.Add('NuGetFeedUri_Development', 'ProGetFeedNuGetDevelopmentUri')
        $global:configRootKeys.Add('NuGetFeedUri_Integration', 'ProGetFeedNuGetIntegrationUri')
        $global:configRootKeys.Add('NuGetFeedUri_QA', 'ProGetFeedNuGetQAUri')
        $global:configRootKeys.Add('NuGetFeedUri_Stable', 'ProGetFeedNuGetStableUri')

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Added package-repository key constants.'
      }

      # Discover and load per-feed-set sub-fragment files
      $subFragments = @(
        Get-ChildItem -LiteralPath $scriptDir -Filter 'PackageRepositories.*.ConfigRootKeys.ps1' -File -ErrorAction SilentlyContinue |
          Sort-Object Name
      )

      if ($subFragments.Count -eq 0) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "No PackageRepositories.*.ConfigRootKeys.ps1 sub-fragments found in '$scriptDir'."
      } else {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Found $($subFragments.Count) package-repository sub-fragment(s) to load."

        # The collection that lists all powershell package repositories
        if ($PSCmdlet.ShouldProcess('$global:configRootKeys', 'Add DatabasesCollection key and load sub-fragments')) {
          $global:configRootKeys.Add('PackageRepositoriesCollectionConfigRootKey', 'PackageRepositoriesCollection')
        }

        foreach ($subFragment in $subFragments) {
          if ($PSCmdlet.ShouldProcess($subFragment.FullName, 'Dot-source package-repository sub-fragment')) {
            try {
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Dot-sourcing '$($subFragment.FullName)'" -Tag 'ConfigRootKeys'
              . $subFragment.FullName
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Loaded '$($subFragment.Name)'"
            } catch {
              $errorMessage = "Failed to dot-source '$($subFragment.FullName)'. Exception: $($_.Exception.Message)"
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
              throw
            }
          }
        }
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
