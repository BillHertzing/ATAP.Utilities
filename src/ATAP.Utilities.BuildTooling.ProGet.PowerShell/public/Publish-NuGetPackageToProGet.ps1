#Requires -Version 7.0
<#
.SYNOPSIS
    Publishes a pre-built NuGet .nupkg to a ProGet feed via
    `dotnet nuget push`. Idempotent: always passes --skip-duplicate.

.DESCRIPTION
    Publish-NuGetPackageToProGet is the single source of truth for the
    `dotnet nuget push` invocation in the immutable-build pipeline. It
    replaces inline `dotnet nuget push` calls scattered across the
    Publish-ATAPUtilities.ps1 orchestrator and BuildMaster plans.

    The cmdlet:
        - Takes a pre-built .nupkg path (FileInfo or string).
        - Resolves the ProGet feed URI from the feed name via
          Resolve-ProGetFeedFromSettings; the feed name defaults to
          'nuget-experimental'.
        - Resolves the key named by -ProGetApiKeySecretName through
          Get-SecretATAP immediately before the push.
        - Invokes `dotnet nuget push` with --skip-duplicate so that
          re-pushing the same version is a no-op (idempotent).
        - Delegates the dotnet call to Invoke-DotnetNuGetPush so the transport
          wrapper remains owned by the parent build-tooling module.
        - Masks the API key value in every log line (it appears in logs
          only as '***'). The full key still reaches `dotnet nuget push`
          via its --api-key argument.

    -WhatIf short-circuits before invoking dotnet.

.PARAMETER NupkgPath
    Absolute or relative path to the .nupkg file to push. Must exist and
    have a .nupkg extension.

.PARAMETER Feed
    The ProGet NuGet feed name to push to. Defaults to 'nuget-experimental'.

.PARAMETER CeilingTier
    Promotion ceiling for direct publishes to feeds above Experimental. When
    -Feed targets Development or higher, this cmdlet calls
    Test-PromotionWithinCeiling before invoking dotnet.

.PARAMETER Force
    Emergency/manual bypass for direct publishes to feeds above Experimental
    without a ceiling check. This is intended for disaster recovery only and is
    logged as a warning.

.PARAMETER ProGetApiKeySecretName
    Bitwarden Secrets Manager SecretName for the publishing key. Raw key
    parameters and environment-variable fallbacks are unsupported.

.OUTPUTS
    [PSCustomObject] with at least:
      - NupkgPath        : Absolute path to the .nupkg.
      - FeedName         : Feed name pushed to.
      - FeedUri          : Resolved feed URI.
      - Published        : $true when `dotnet nuget push` exited 0.
      - CeilingTier      : Optional promotion ceiling supplied by caller.
      - ResponseSummary  : Short string summary of the push result.

.EXAMPLE
    Publish-NuGetPackageToProGet `
        -NupkgPath './out/ATAP.Utilities.Foo.1.0.0-Sprint042.nupkg'

.EXAMPLE
    Publish-NuGetPackageToProGet `
        -NupkgPath ./out/X.nupkg -Feed 'nuget-development' -CeilingTier 'Development' -WhatIf

.NOTES
    AI assisted using Powershell.instructions.md as guidelines.
    Stream G4 of V3 plan.

.LINK
    https://github.com/whertzing/ATAP.Utilities
#>

function Publish-NuGetPackageToProGet {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$NupkgPath,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$Feed = 'nuget-experimental',

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$CeilingTier,

        [Parameter(Mandatory = $false)]
        [switch]$Force,

        [ValidateNotNullOrEmpty()]
        [string]$ProGetApiKeySecretName = 'ProGet.BuildMaster.API.Key'
    )

    begin {
        $fn = 'Publish-NuGetPackageToProGet'
        $mn = 'ATAP.Utilities.BuildTooling.ProGet.PowerShell'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn with NupkgPath='$NupkgPath' Feed='$Feed'" -Tag 'Trace'

        # Dot-source the feed-resolver if not already loaded.
        $helperPath = Join-Path $PSScriptRoot 'Resolve-ProGetFeedFromSettings.ps1'
        if (-not (Get-Command -Name 'Resolve-ProGetFeedFromSettings' -CommandType Function -ErrorAction SilentlyContinue)) {
            if (Test-Path -LiteralPath $helperPath -PathType Leaf) {
                . $helperPath
            }
        }
    }

    process {
        # 1. Validate NupkgPath.
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

        # 2. Resolve feed URI. The Feed parameter is a feed name; map it to a
        #    URI using the settings collection. We derive the tier from the
        #    feed name suffix so Resolve-ProGetFeedFromSettings can find it.
        $tierFromFeedName = $null
        if ($Feed -match '^(nuget|powershellget|chocolatey)-([a-zA-Z]+)(-push)?$') {
            $tierFromFeedName = $Matches[2]
        }
        if ([string]::IsNullOrWhiteSpace($tierFromFeedName)) {
            $msg = "Cannot parse tier from feed name '$Feed'. Expected '<type>-<tier>[-push]'."
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
            throw $msg
        }
        $feedInfo = Resolve-ProGetFeedFromSettings -FeedType 'nuget' -Tier $tierFromFeedName
        $feedName = $feedInfo.FeedName
        $feedUri = $feedInfo.EndpointUri
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Resolved feed '$feedName' at '$feedUri' from global settings"

        $destinationTier = $tierFromFeedName
        if (-not (Get-Command -Name 'ConvertTo-BuildPromotionTierName' -CommandType Function -ErrorAction SilentlyContinue)) {
            $tierHelperPath = Join-Path $PSScriptRoot 'ConvertTo-BuildPromotionTierName.ps1'
            if (Test-Path -LiteralPath $tierHelperPath -PathType Leaf) {
                . $tierHelperPath
            } else {
                throw "Required helper ConvertTo-BuildPromotionTierName was not found at '$tierHelperPath'."
            }
        }
        $destinationTier = ConvertTo-BuildPromotionTierName -Tier $destinationTier
        if ($destinationTier -ne 'Experimental') {
            if ($Force) {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "Promotion ceiling check bypassed explicitly for direct NuGet publish to '$feedName'." -Tag 'CeilingBypass'
            } else {
                if ([string]::IsNullOrWhiteSpace($CeilingTier)) {
                    throw "CeilingTier is required when publishing directly to feed '$feedName'. Use -Force only for an audited emergency/manual bypass."
                }
                if (-not (Get-Command -Name 'Test-PromotionWithinCeiling' -CommandType Function -ErrorAction SilentlyContinue)) {
                    $ceilingHelperPath = Join-Path $PSScriptRoot 'Test-PromotionWithinCeiling.ps1'
                    if (Test-Path -LiteralPath $ceilingHelperPath -PathType Leaf) {
                        . $ceilingHelperPath
                    } else {
                        throw "Required helper Test-PromotionWithinCeiling was not found at '$ceilingHelperPath'."
                    }
                }
                Test-PromotionWithinCeiling -CurrentTier $destinationTier -CeilingTier $CeilingTier -ErrorAction Stop | Out-Null
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Direct NuGet publish ceiling accepted: destination tier '$destinationTier' is within ceiling '$CeilingTier'"
            }
        }

        # 3. WhatIf short-circuit. Secret resolution is deliberately deferred.
        $target = $resolvedNupkg
        $action = "dotnet nuget push to '$feedName' ($feedUri) with --skip-duplicate"
        if (-not $PSCmdlet.ShouldProcess($target, $action)) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "WhatIf: would push '$resolvedNupkg' to '$feedName' --skip-duplicate"
            return [PSCustomObject]@{
                NupkgPath       = $resolvedNupkg
                FeedName        = $feedName
                FeedUri         = $feedUri
                Published       = $false
                CeilingTier     = $CeilingTier
                ResponseSummary = "WhatIf: planned push of '$resolvedNupkg' to '$feedName' with --skip-duplicate"
            }
        }

        # 4. Resolve the key only at the authenticated-operation boundary.
        try {
            $apiKey = [string](Get-SecretATAP -SecretName $ProGetApiKeySecretName -SecretStoreType 'BitwardenSecretsManager' -ErrorAction Stop)
        } catch {
            throw "Unable to resolve the ProGet API key from SecretName '$ProGetApiKeySecretName'."
        }
        if ([string]::IsNullOrWhiteSpace($apiKey)) {
            throw "The ProGet secret named '$ProGetApiKeySecretName' resolved to an empty value."
        }

        # 5. Invoke the dotnet helper. Pester mocks Invoke-DotnetNuGetPush.
        $published = $false
        $summary = $null
        try {
            $pushResult = Invoke-DotnetNuGetPush -NupkgPath $resolvedNupkg -FeedUri $feedUri -ApiKey $apiKey
            $exit = [int]$pushResult.ExitCode
            $stdout = [string]$pushResult.StdOut

            # IMPORTANT: redact the API key from any captured output before
            # logging, in case `dotnet nuget push` echoes it.
            $redactedStdout = $stdout
            if (-not [string]::IsNullOrEmpty($apiKey)) {
                $redactedStdout = $redactedStdout.Replace($apiKey, '***')
            }

            if ($exit -eq 0) {
                $published = $true
                if ($redactedStdout -match '(?i)already exists|conflict|409|skipping') {
                    $summary = "already present: push of '$resolvedNupkg' was skipped via --skip-duplicate."
                } else {
                    $summary = "Pushed '$resolvedNupkg' to '$feedName'."
                }
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message $summary
                if (-not [string]::IsNullOrWhiteSpace($redactedStdout)) {
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "dotnet stdout: $redactedStdout"
                }
            } else {
                $msg = "dotnet nuget push failed with exit code $exit. Output: $redactedStdout"
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
                throw $msg
            }
        } catch {
            $exceptionMessage = [string]$_.Exception.Message
            # Redact API key from exception text too, defensively.
            if (-not [string]::IsNullOrEmpty($apiKey)) {
                $exceptionMessage = $exceptionMessage.Replace($apiKey, '***')
            }
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Push failed: $exceptionMessage"
            throw "Push failed: $exceptionMessage"
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
