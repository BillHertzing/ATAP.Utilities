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
    The API key is resolved per the same chain used by the legacy
    Publish-PSModuleToProGetFeed (Bitwarden -> configured env var ->
    PROGET_ADMIN_API_KEY admin fallback).

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
        [string]$CeilingTier
    )

    begin {
        $fn = 'Publish-PSModuleToProGet'
        $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn with NupkgPath='$NupkgPath'" -Tag 'Trace'

        # Dot-source the feed-resolver if it isn't already loaded (matches the
        # pattern used by the legacy Publish-PSModuleToProGetFeed.ps1).
        $helperPath = Join-Path $PSScriptRoot '..\private\Resolve-ProGetFeedFromSettings.ps1'
        if (-not (Get-Command -Name 'Resolve-ProGetFeedFromSettings' -CommandType Function -ErrorAction SilentlyContinue)) {
            if (Test-Path -LiteralPath $helperPath -PathType Leaf) {
                . $helperPath
            }
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

        # 2. Resolve the experimental PowerShellGet feed from $global:Settings.
        $feed = Resolve-ProGetFeedFromSettings -FeedType 'powershellget' -Tier 'Experimental'
        $feedName = $feed.FeedName
        $feedUri = $feed.EndpointUri
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Resolved experimental feed '$feedName' at '$feedUri' from global settings"

        # 3. Resolve API key: Bitwarden -> configured env var -> admin fallback.
        $apiKey = $null
        $apiKeySource = $null
        $bwCmd = Get-Command -Name 'Get-BitWardenSecret' -ErrorAction SilentlyContinue
        if ($null -ne $bwCmd) {
            try {
                $secretName = 'ProGet_PowerShellGet_Experimental_ApiKey'
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
            $envName = if (-not [string]::IsNullOrWhiteSpace($feed.ApiKeyName)) { $feed.ApiKeyName } else { 'PROGET_APIKEY_POWERSHELLGET_EXPERIMENTAL' }
            $apiKey = [Environment]::GetEnvironmentVariable($envName, 'Process')
            if ([string]::IsNullOrWhiteSpace([string]$apiKey)) {
                $apiKey = [Environment]::GetEnvironmentVariable($envName, 'User')
            }
            if (-not [string]::IsNullOrWhiteSpace([string]$apiKey)) {
                $apiKeySource = "env var '$envName'"
            }
        }
        if ([string]::IsNullOrWhiteSpace([string]$apiKey)) {
            # TEMPORARY admin-key fallback. Same scope-creep note as the
            # legacy Publish-PSModuleToProGetFeed: remove when per-tier keys
            # are minted and stored in Bitwarden.
            $apiKey = [Environment]::GetEnvironmentVariable('PROGET_ADMIN_API_KEY', 'User')
            if (-not [string]::IsNullOrWhiteSpace([string]$apiKey)) {
                $apiKeySource = "User env var 'PROGET_ADMIN_API_KEY' (admin fallback)"
            }
        }
        if ([string]::IsNullOrWhiteSpace([string]$apiKey)) {
            $msg = "Unable to resolve ProGet API key for Experimental feed. Expected Get-BitWardenSecret -SecretName 'ProGet_PowerShellGet_Experimental_ApiKey', configured env var '$($feed.ApiKeyName)', or admin fallback 'PROGET_ADMIN_API_KEY'."
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
            throw $msg
        }
        # NOTE: the API key value is never logged; only the source.
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "API key resolved for Experimental from $apiKeySource (value redacted)"

        # 4. Ensure the PSResourceRepository is registered with the right URI.
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
                ResponseSummary = "WhatIf: planned publish of '$resolvedNupkg' to '$feedName'"
            }
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
                $summary = "Publish-PSResource returned: $($result | Out-String)".Trim()
            } else {
                $summary = "Published '$resolvedNupkg' to '$feedName'."
            }
        } catch {
            $exceptionMessage = [string]$_.Exception.Message
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
            ResponseSummary = $summary
        }
    }

    end {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving $fn" -Tag 'Trace'
    }
}
