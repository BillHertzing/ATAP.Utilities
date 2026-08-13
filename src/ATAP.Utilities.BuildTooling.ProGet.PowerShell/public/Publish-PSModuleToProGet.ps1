#Requires -Version 7.0
<#
.SYNOPSIS
    Publishes a pre-built PowerShell module .nupkg to the
    powershellget-experimental ProGet feed.

.DESCRIPTION
    Publish-PSModuleToProGet is the "push" half of the pack/push split for
    PowerShell modules under the immutable-build strategy. It takes a
    pre-built .nupkg file (produced by New-PSModuleNupkg) and uploads it
    to the powershellget-experimental feed via Publish-PSResource.

    The Experimental feed is the only target. There is no -Tier parameter;
    every module starts at Experimental and is later moved upward through
    the tiers by Promote-ProGetPackage. This eliminates the audit risk of
    a pack/push cmdlet that could target arbitrary tiers.

    The cmdlet is idempotent against re-push of the same .nupkg: ProGet
    rejects duplicate versions, but Publish-PSResource may surface that
    as a non-fatal "already present" response which this cmdlet reports as
    a no-op success.

    The feed metadata is resolved from `$global:Settings` via
    `Resolve-ProGetFeedFromSettings -FeedType 'powershellget' -Tier 'Experimental'`.
    The API key named by -ProGetApiKeySecretName is resolved through
    Get-SecretATAP immediately before Publish-PSResource is invoked.

    -WhatIf short-circuits before calling Publish-PSResource. The returned
    object still carries the resolved feed name + URI so callers can
    inspect the publish plan.

.PARAMETER NupkgPath
    Absolute or relative path to the .nupkg file to publish. Must exist
    and have a .nupkg extension.

.PARAMETER CeilingTier
    Optional promotion ceiling recorded in the returned object for BuildMaster
    evidence. The publish target remains Experimental; later stages enforce
    the ceiling with Promote-ProGetPackage -CeilingTier.

.PARAMETER ProGetApiKeySecretName
    Bitwarden Secrets Manager SecretName for the publishing key. Raw keys and
    environment-variable fallbacks are intentionally unsupported.

.OUTPUTS
    [PSCustomObject] per PowerShell-Modules-Pack-and-Publish.md S8:
      - NupkgPath        : Absolute path to the .nupkg.
      - FeedName         : 'powershellget-experimental' (or whatever the
                           settings collection maps Experimental to).
      - FeedUri          : Resolved feed URI.
      - Published        : $true only if Publish-PSResource was invoked
                           and returned without throwing.
      - CeilingTier      : Optional promotion ceiling supplied by caller.
      - ResponseSummary  : Short string summary of the publish result, the
                           idempotent no-op detection, or the WhatIf plan.

.EXAMPLE
    Publish-PSModuleToProGet -NupkgPath 'C:/out/MyModule.1.0.0-Sprint042.nupkg'

.EXAMPLE
    Publish-PSModuleToProGet -NupkgPath ./out/Foo.0.1.0.nupkg -WhatIf

.NOTES
    AI assisted using Powershell.instructions.md as guidelines.
    Stream G2 of V3 plan. Replaces the multi-tier
    Publish-PSModuleToProGetFeed for the new pack/push pipeline.

.LINK
    https://github.com/whertzing/ATAP.Utilities
#>
function Publish-PSModuleToProGet {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$NupkgPath,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$CeilingTier,

        [ValidateNotNullOrEmpty()]
        [string]$ProGetApiKeySecretName = 'ProGet.BuildMaster.API.Key'
    )

    begin {
      # SC-0288 / Task 13.66.b: the SecretName host suffix is derived from the service placement
      # host, never hard-coded. Resolution order is the authoritative host setting,
      # then the placement map; an unknown placement host fails closed.
      if (-not $PSBoundParameters.ContainsKey('ProGetApiKeySecretName')) {
        if (-not (Get-Command -Name 'Resolve-HostSuffixedSecretName' -ErrorAction SilentlyContinue)) {
          . (Join-Path $PSScriptRoot '..' '..' 'ATAP.Utilities.BuildTooling.Common.PowerShell' 'public' 'Resolve-HostSuffixedSecretName.ps1')
        }
        $ProGetApiKeySecretName = Resolve-HostSuffixedSecretName `
          -BaseName $ProGetApiKeySecretName -ServiceName 'ProGet' -SettingName 'ProGetBuildMasterApiKeySecretName'
      }

        $fn = 'Publish-PSModuleToProGet'
        $mn = 'ATAP.Utilities.BuildTooling.ProGet.PowerShell'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn with NupkgPath='$NupkgPath'" -Tag 'Trace'

        # Dot-source the feed-resolver if it isn't already loaded (matches the
        # pattern used by the legacy Publish-PSModuleToProGetFeed.ps1).
        $helperPath = Join-Path $PSScriptRoot 'Resolve-ProGetFeedFromSettings.ps1'
        if (-not (Get-Command -Name 'Resolve-ProGetFeedFromSettings' -CommandType Function -ErrorAction SilentlyContinue)) {
            if (Test-Path -LiteralPath $helperPath -PathType Leaf) {
                . $helperPath
            }
        }
        if (-not (Get-Command -Name 'Test-PSModulePackageSignature' -CommandType Function -ErrorAction SilentlyContinue)) {
            . (Join-Path $PSScriptRoot 'Test-PSModulePackageSignature.ps1')
        }
    }

    process {
        # 1. Validate -NupkgPath: must exist as a file with .nupkg extension.
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
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Resolved NupkgPath to '$resolvedNupkg'"

        # Verify the immutable artifact before feed resolution, repository mutation, or secret lookup.
        $signatureVerification = Test-PSModulePackageSignature -NupkgPath $resolvedNupkg -RequireTimestamp

        # 2. Resolve the experimental PowerShellGet feed from $global:Settings.
        $feed = Resolve-ProGetFeedFromSettings -FeedType 'powershellget' -Tier 'Experimental'
        $feedName = $feed.FeedName
        $feedUri = $feed.EndpointUri
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Resolved experimental feed '$feedName' at '$feedUri' from global settings"

        # 3. Ensure the PSResourceRepository is registered with the right URI.
        $existingRepo = Get-PSResourceRepository -Name $feedName -ErrorAction SilentlyContinue
        if ($null -eq $existingRepo) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Registering PSResourceRepository '$feedName' at '$feedUri'"
            Register-PSResourceRepository -Name $feedName -Uri $feedUri -Trusted
        } else {
            $existingUri = [string]$existingRepo.Uri
            if ($existingUri -ne $feedUri) {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Updating PSResourceRepository '$feedName' URI from '$existingUri' to '$feedUri'"
                Set-PSResourceRepository -Name $feedName -Uri $feedUri -Trusted
            }
        }

        # 5. WhatIf short-circuit.
        $target = $resolvedNupkg
        $action = "Publish to '$feedName' ($feedUri)"
        if (-not $PSCmdlet.ShouldProcess($target, $action)) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "WhatIf: would publish '$resolvedNupkg' to '$feedName'"
            return [PSCustomObject]@{
                NupkgPath       = $resolvedNupkg
                FeedName        = $feedName
                FeedUri         = $feedUri
                Published       = $false
                CeilingTier     = $CeilingTier
                SignatureVerified = $signatureVerification.Valid
                ResponseSummary = "WhatIf: planned publish of '$resolvedNupkg' to '$feedName'"
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

        # 6. Publish via Publish-PSResource -NupkgPath (per S8 of the pack/publish doc).
        $published = $false
        $summary = $null
        try {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling Publish-PSResource for '$feedName'" -Tag 'RestCall'
            $result = Publish-PSResource -NupkgPath $resolvedNupkg -Repository $feedName -ApiKey $apiKey
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from Publish-PSResource for '$feedName'" -Tag 'RestCall'
            $published = $true
            if ($null -ne $result) {
                $summary = ("Publish-PSResource returned: $($result | Out-String)".Trim()).Replace($apiKey, '***')
            } else {
                $summary = "Published '$resolvedNupkg' to '$feedName'."
            }
        } catch {
            $exceptionMessage = ([string]$_.Exception.Message).Replace($apiKey, '***')
            # Idempotent re-publish: ProGet rejects duplicate versions but
            # Publish-PSResource may surface that as a recoverable error.
            if ($exceptionMessage -match '(?i)already exists|already present|duplicate version|409') {
                $summary = "already present: '$resolvedNupkg' is already in '$feedName' ($exceptionMessage)"
                $published = $true
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message $summary
            } else {
                $msg = "Publish-PSResource failed for '$resolvedNupkg' to '$feedName': $exceptionMessage"
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
                throw $msg
            }
        }

        return [PSCustomObject]@{
            NupkgPath       = $resolvedNupkg
            FeedName        = $feedName
            FeedUri         = $feedUri
            Published       = $published
            CeilingTier     = $CeilingTier
            SignatureVerified = $signatureVerification.Valid
            ResponseSummary = $summary
        }
    }

    end {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving $fn" -Tag 'Trace'
    }
}
