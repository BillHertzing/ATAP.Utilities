#Requires -Version 7.0
<#
.SYNOPSIS
    Publishes a Universal Package (.upack) to a ProGet Universal feed via
    HTTP PUT. Idempotent (server-side dedup of identical Group/Name/Version).

.DESCRIPTION
    Publish-UniversalPackageToProGet uploads a `.upack` file to ProGet's
    Universal Feed API. Universal feeds are NOT consumed by `dotnet nuget
    push` — they use the simpler `PUT /upack/<feed>/` REST endpoint with
    the package body and an `X-ApiKey` header.

    The cmdlet:
        - Takes a pre-built .upack file path.
        - Resolves the feed URI primarily via
          `Resolve-ProGetFeedFromSettings -FeedType 'Universal'`. If the
          settings collection does not yet know about ReleaseBundle feeds
          (Stream F is still landing), it falls back first to a tier-named
          environment variable and finally to a local default
          (http://localhost:50000/upack/<feed>/).
        - Resolves the API key named by -ProGetApiKeySecretName through
          Get-SecretATAP immediately before the authenticated request.
        - Invokes `Invoke-RestMethod -Method Put -Uri <feedUri>/<file>
          -InFile <upack> -Headers @{ 'X-ApiKey' = <key> }`.
        - The API key value is NEVER written to any PSFramework log line.

    -WhatIf short-circuits before invoking Invoke-RestMethod.

.PARAMETER Path
    Absolute or relative path to the .upack file to upload.

.PARAMETER Feed
    The ProGet Universal feed name to push to. Defaults to
    'releasebundle-experimental'.

.PARAMETER CeilingTier
    Promotion ceiling for direct publishes to feeds above Experimental. When
    -Feed targets Development or higher, this cmdlet calls
    Test-PromotionWithinCeiling before invoking the Universal Feed API.

.PARAMETER Force
    Emergency/manual bypass for direct publishes to feeds above Experimental
    without a ceiling check. This is intended for disaster recovery only and is
    logged as a warning.

.PARAMETER ProGetApiKeySecretName
    Bitwarden Secrets Manager SecretName for the ProGet key. Defaults to the
    BuildMaster publishing identity. Raw API-key values and environment-variable
    fallbacks are intentionally unsupported.

.OUTPUTS
    [PSCustomObject] with at least:
      - NupkgPath        : Absolute path to the .upack (named NupkgPath
                           for output-shape consistency with the other
                           Stream-G publish cmdlets).
      - FeedName         : Feed name pushed to.
      - FeedUri          : Resolved feed URI.
      - Published        : $true on HTTP 200/201/202.
      - CeilingTier      : Optional promotion ceiling supplied by caller.
      - ResponseSummary  : Short string summary of the upload result.

.EXAMPLE
    Publish-UniversalPackageToProGet `
        -Path './out/AceCommander.1.4.0+8f4b2c1.upack'

.EXAMPLE
    Publish-UniversalPackageToProGet `
        -Path ./bundle.upack -Feed 'releasebundle-development' -CeilingTier 'Development' -WhatIf

.NOTES
    AI assisted using Powershell.instructions.md as guidelines.
    Stream G5 of V3 plan.

.LINK
    https://docs.inedo.com/docs/proget/reference-api/universal-feed-api
#>
function Publish-UniversalPackageToProGet {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$Feed = 'releasebundle-experimental',

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$CeilingTier,

        [Parameter(Mandatory = $false)]
        [switch]$Force,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$ProGetApiKeySecretName = 'ProGet.BuildMaster.API.Key'
    )

    begin {
        $fn = 'Publish-UniversalPackageToProGet'
        $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn with Path='$Path' Feed='$Feed'" -Tag 'Trace'

        # Dot-source the feed-resolver if not already loaded.
        $helperPath = Join-Path $PSScriptRoot '..\private\Resolve-ProGetFeedFromSettings.ps1'
        if (-not (Get-Command -Name 'Resolve-ProGetFeedFromSettings' -CommandType Function -ErrorAction SilentlyContinue)) {
            if (Test-Path -LiteralPath $helperPath -PathType Leaf) {
                . $helperPath
            }
        }
    }

    process {
        # 1. Validate Path.
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
            $msg = "Path does not exist or is not a file: '$Path'"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
            throw $msg
        }
        if ([System.IO.Path]::GetExtension($Path) -ne '.upack') {
            $msg = "Path must have a .upack extension: '$Path'"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
            throw $msg
        }
        $resolvedUpack = (Resolve-Path -LiteralPath $Path).ProviderPath -replace '\\', '/'

        # 2. Parse tier from feed name: 'releasebundle-<tier>'.
        $tier = $null
        if ($Feed -match '^(?i:releasebundle)-([A-Za-z]+)$') {
            $tier = $Matches[1]
        }

        # 3. Resolve feed URI with a three-step fallback chain:
        #    (a) Resolve-ProGetFeedFromSettings -FeedType 'Universal' -Tier <Tier>
        #    (b) Env var PROGET_RELEASEBUNDLE_<TIER>_URI
        #    (c) Local default http://localhost:50000/upack/<feed>/
        $feedUri = $null
        $feedUriSource = $null
        if (-not [string]::IsNullOrWhiteSpace($tier)) {
            try {
                $feedInfo = Resolve-ProGetFeedFromSettings -FeedType 'Universal' -Tier $tier -ErrorAction Stop
                if ($null -ne $feedInfo -and -not [string]::IsNullOrWhiteSpace($feedInfo.EndpointUri)) {
                    $feedUri = ([string]$feedInfo.EndpointUri).TrimEnd('/') + '/'
                    $feedUriSource = "global settings (FeedType=Universal Tier=$tier)"
                }
            } catch {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Resolve-ProGetFeedFromSettings did not return a Universal feed for tier '$tier': $($_.Exception.Message)"
            }
        }
        if ([string]::IsNullOrWhiteSpace($feedUri) -and -not [string]::IsNullOrWhiteSpace($tier)) {
            $envName = "PROGET_RELEASEBUNDLE_$($tier.ToUpperInvariant())_URI"
            $envValue = [Environment]::GetEnvironmentVariable($envName, 'Process')
            if ([string]::IsNullOrWhiteSpace($envValue)) {
                $envValue = [Environment]::GetEnvironmentVariable($envName, 'User')
            }
            if (-not [string]::IsNullOrWhiteSpace($envValue)) {
                $feedUri = $envValue.TrimEnd('/') + '/'
                $feedUriSource = "env var '$envName'"
            }
        }
        if ([string]::IsNullOrWhiteSpace($feedUri)) {
            $feedUri = "http://localhost:50000/upack/$Feed/"
            $feedUriSource = 'local default (http://localhost:50000/upack/<feed>/)'
        }
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Resolved feed URI '$feedUri' from $feedUriSource"

        if (-not [string]::IsNullOrWhiteSpace($tier)) {
            if (-not (Get-Command -Name 'ConvertTo-BuildPromotionTierName' -CommandType Function -ErrorAction SilentlyContinue)) {
                $ceilingHelperPath = Join-Path $PSScriptRoot 'Test-PromotionWithinCeiling.ps1'
                if (Test-Path -LiteralPath $ceilingHelperPath -PathType Leaf) {
                    . $ceilingHelperPath
                } else {
                    throw "Required helper Test-PromotionWithinCeiling was not found at '$ceilingHelperPath'."
                }
            }
            $destinationTier = ConvertTo-BuildPromotionTierName -Tier $tier
            if ($destinationTier -ne 'Experimental') {
                if ($Force) {
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "Promotion ceiling check bypassed explicitly for direct Universal publish to '$Feed'." -Tag 'CeilingBypass'
                } else {
                    if ([string]::IsNullOrWhiteSpace($CeilingTier)) {
                        throw "CeilingTier is required when publishing directly to feed '$Feed'. Use -Force only for an audited emergency/manual bypass."
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
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Direct Universal publish ceiling accepted: destination tier '$destinationTier' is within ceiling '$CeilingTier'"
                }
            }
        }

        # 4. WhatIf short-circuit. Secret resolution is deliberately deferred.
        $target = $resolvedUpack
        $action = "PUT to '$feedUri' (Universal feed '$Feed')"
        if (-not $PSCmdlet.ShouldProcess($target, $action)) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "WhatIf: would upload '$resolvedUpack' to '$feedUri'"
            return [PSCustomObject]@{
                NupkgPath       = $resolvedUpack
                FeedName        = $Feed
                FeedUri         = $feedUri
                Published       = $false
                CeilingTier     = $CeilingTier
                ResponseSummary = "WhatIf: planned upload of '$resolvedUpack' to '$Feed'"
            }
        }

        # 5. Resolve the key only at the authenticated-operation boundary.
        $apiKey = $null
        try {
            $apiKey = [string](Get-SecretATAP -SecretName $ProGetApiKeySecretName -SecretStoreType 'BitwardenSecretsManager' -ErrorAction Stop)
        } catch {
            $msg = "Unable to resolve the ProGet API key from SecretName '$ProGetApiKeySecretName'."
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
            throw $msg
        }
        if ([string]::IsNullOrWhiteSpace($apiKey)) {
            throw "The ProGet secret named '$ProGetApiKeySecretName' resolved to an empty value."
        }

        # 6. Invoke the PUT.
        $headers = @{
            'X-ApiKey' = $apiKey
            'Accept'   = 'application/json'
        }
        $published = $false
        $summary = $null
        try {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Invoking PUT '$feedUri' with InFile '$resolvedUpack'" -Tag 'RestCall'
            $response = Invoke-RestMethod -Uri $feedUri -Method Put -InFile $resolvedUpack -Headers $headers -ContentType 'application/octet-stream' -ErrorAction Stop
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "PUT '$feedUri' returned successfully" -Tag 'RestCall'

            $published = $true
            $responseText = if ($null -ne $response) { ($response | Out-String).Trim() } else { '' }
            # Redact the API key from any echoed response text, defensively.
            if (-not [string]::IsNullOrEmpty($apiKey) -and -not [string]::IsNullOrEmpty($responseText)) {
                $responseText = $responseText.Replace($apiKey, '***')
            }
            $summary = if ([string]::IsNullOrWhiteSpace($responseText)) {
                "Uploaded '$resolvedUpack' to '$Feed'."
            } else {
                "Uploaded '$resolvedUpack' to '$Feed'. Response: $responseText"
            }
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message $summary
        } catch {
            $exceptionMessage = [string]$_.Exception.Message
            if (-not [string]::IsNullOrEmpty($apiKey)) {
                $exceptionMessage = $exceptionMessage.Replace($apiKey, '***')
            }
            # Idempotent re-upload: ProGet returns 409 when the same Group/Name/
            # Version is already present. Surface as no-op success.
            if ($exceptionMessage -match '(?i)already exists|already present|409|duplicate') {
                $summary = "already present: '$resolvedUpack' is already in '$Feed' ($exceptionMessage)"
                $published = $true
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message $summary
            } else {
                $msg = "PUT to '$feedUri' failed for '$resolvedUpack': $exceptionMessage"
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
                throw $msg
            }
        }

        return [PSCustomObject]@{
            NupkgPath       = $resolvedUpack
            FeedName        = $Feed
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
