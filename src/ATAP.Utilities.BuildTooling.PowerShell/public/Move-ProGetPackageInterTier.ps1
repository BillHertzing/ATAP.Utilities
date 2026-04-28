#Requires -Version 7.0
function Move-ProGetPackageInterTier {
    <#
.SYNOPSIS
    Moves a package from a lower tier's pull feed to the next higher tier's
    push feed (Phase 2) or combined feed (Phase 1).

.DESCRIPTION
    Inter-tier movement advances a validated package upward through the
    environment tiers: Experimental → Development → Integration → QA → Stable.

    The script knows the tier ordering and can automatically determine the
    destination feed from the source feed name. In Phase 1, the destination
    is the next tier's combined feed. In Phase 2, the destination is the
    next tier's push feed (the caller then runs the intra-tier script to
    move it from push to pull within that tier).

    The tier chain is:
        experimental → development → integration → qa → stable

    The script detects the package type (nuget, powershell, chocolatey)
    from the source feed name prefix.

.PARAMETER PackageName
    The package ID (e.g., 'ATAP.Utilities.Configuration.Extensions').

.PARAMETER Version
    The exact package version to move (e.g., '1.2.0-experimental.42').

.PARAMETER SourceFeed
    The current tier's pull feed (e.g., 'nuget-experimental').
    The script parses this to determine the package type and current tier.

.PARAMETER DestinationFeed
    Optional. Override the automatic destination. If not specified, the
    script computes the next tier's feed based on the source feed name
    and the -UsePushFeed switch.

.PARAMETER UsePushFeed
    If set, the auto-computed destination targets the next tier's push feed
    (e.g., 'nuget-development-push'). This is the Phase 2 behavior.
    If not set, the destination targets the next tier's combined feed
    (e.g., 'nuget-development'). This is the Phase 1 behavior.

.PARAMETER Comments
    Optional movement comment recorded in ProGet's audit log.

.PARAMETER ProGetBaseUrl
    The ProGet base URL. Falls back to $global:settings via configRootKeys →
    $global:ProGetBaseUrl.

.PARAMETER ApiKey
    The API key for ProGet. Falls back to $env:PROGET_BUILDMASTER_API_KEY →
    env var via configRootKeys.

.OUTPUTS
    PSCustomObject with properties: PackageName, Version, SourceFeed,
    SourceTier, DestinationFeed, DestinationTier, PackageType, Phase2Mode,
    Promoted, Response.

.EXAMPLE
    # Phase 1: Move from experimental to development (combined feeds)
    Move-ProGetPackageInterTier `
        -PackageName 'ATAP.Utilities.Configuration.Extensions' `
        -Version '1.2.0-experimental.42' `
        -SourceFeed 'nuget-experimental'
    # Auto-destination: nuget-development

.EXAMPLE
    # Phase 2: Move from experimental pull to development push
    Move-ProGetPackageInterTier `
        -PackageName 'ATAP.Utilities.Configuration.Extensions' `
        -Version '1.2.0-experimental.42' `
        -SourceFeed 'nuget-experimental' `
        -UsePushFeed
    # Auto-destination: nuget-development-push

.EXAMPLE
    # Explicit destination override
    Move-ProGetPackageInterTier `
        -PackageName 'MyModule' -Version '2.0.0-dev.5' `
        -SourceFeed 'powershell-development' `
        -DestinationFeed 'powershell-qa-push'

.EXAMPLE
    # Dry run
    Move-ProGetPackageInterTier `
        -PackageName 'MyPackage' -Version '1.0.0' `
        -SourceFeed 'nuget-qa' -WhatIf
    # Auto-destination: nuget-stable

.NOTES
    AI assisted using Powershell.instructions.md as guidelines

.LINK
    https://github.com/whertzing/ATAP.Utilities
#>

    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory)]
        [string]$PackageName,

        [Parameter(Mandatory)]
        [string]$Version,

        [Parameter(Mandatory)]
        [string]$SourceFeed,

        [Parameter(Mandatory = $false)]
        [string]$DestinationFeed,

        [switch]$UsePushFeed,

        [string]$Comments,

        [string]$ProGetBaseUrl,

        [string]$ApiKey
    )

    begin {
        $fn = 'Move-ProGetPackageInterTier'
        $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

        # Check and populate simple parameter: PackageName
        $PackageName = Get-PVal -ParameterName 'PackageName' -originalPSBoundParameters $PSBoundParameters -dottedPath 'PackageName' -DefaultValue $PackageName
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "PackageName is $PackageName"

        # Check and populate simple parameter: Version
        $Version = Get-PVal -ParameterName 'Version' -originalPSBoundParameters $PSBoundParameters -dottedPath 'Version' -DefaultValue $Version
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Version is $Version"

        # Check and populate simple parameter: SourceFeed
        $SourceFeed = Get-PVal -ParameterName 'SourceFeed' -originalPSBoundParameters $PSBoundParameters -dottedPath 'SourceFeed' -DefaultValue $SourceFeed
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "SourceFeed is $SourceFeed"

        # Check and populate simple parameter: DestinationFeed
        $DestinationFeed = Get-PVal -ParameterName 'DestinationFeed' -originalPSBoundParameters $PSBoundParameters -dottedPath 'DestinationFeed' -DefaultValue $DestinationFeed
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "DestinationFeed is $DestinationFeed"

        # ── Tier definitions ─────────────────────────────────────────────────
        # Ordered list of tiers. Index determines movement direction (lower → higher).
        $tierOrder = @('experimental', 'development', 'integration', 'qa', 'stable')
        $tierAliases = @{
            testing    = 'qa'
            production = 'stable'
        }

        # Known package type prefixes in feed names
        $knownPrefixes = @('nuget', 'powershell', 'chocolatey')

        # ── Parse source feed name ───────────────────────────────────────────
        # Feed names follow the pattern: {packageType}-{tier}[-push]
        # Examples: nuget-experimental, powershell-development-push, chocolatey-qa

        $parsedPrefix = $null
        $parsedTier = $null

        foreach ($prefix in $knownPrefixes) {
            if ($SourceFeed.StartsWith("$prefix-", [System.StringComparison]::OrdinalIgnoreCase)) {
                $parsedPrefix = $prefix
                $remainder = $SourceFeed.Substring($prefix.Length + 1)  # skip "{prefix}-"
                # Strip any -push suffix (inter-tier should start from a pull feed,
                # but be lenient if user passes a push feed name)
                $remainder = $remainder -replace '-push$', ''
                $remainder = $remainder.ToLowerInvariant()
                if ($tierAliases.ContainsKey($remainder)) {
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Normalizing legacy tier name '$remainder' to '$($tierAliases[$remainder])'"
                    $remainder = $tierAliases[$remainder]
                }
                if ($tierOrder -contains $remainder) {
                    $parsedTier = $remainder
                }
                break
            }
        }

        if (-not $parsedPrefix -or -not $parsedTier) {
            $errorMessage = "Cannot parse source feed name '$SourceFeed'. " +
            'Expected format: {nuget|powershell|chocolatey}-{experimental|development|integration|qa|stable}[-push]. Legacy tiers testing/production are normalized to qa/stable.'
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
            throw $errorMessage
        }

        $currentTierIndex = $tierOrder.IndexOf($parsedTier)

        # ── Determine destination feed ───────────────────────────────────────
        if ([string]::IsNullOrWhiteSpace($DestinationFeed)) {
            if ($currentTierIndex -ge ($tierOrder.Count - 1)) {
                $errorMessage = "Source feed '$SourceFeed' is already at the highest tier ('$parsedTier'). Cannot move further."
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
                throw $errorMessage
            }

            $nextTier = $tierOrder[$currentTierIndex + 1]
            $pushSuffix = if ($UsePushFeed) { '-push' } else { '' }
            $DestinationFeed = "$parsedPrefix-$nextTier$pushSuffix"
        }

        # Check and populate simple parameter: Comments (with computed default)
        $Comments = Get-PVal -ParameterName 'Comments' -originalPSBoundParameters $PSBoundParameters -dottedPath 'Comments' -DefaultValue $Comments
        if ([string]::IsNullOrWhiteSpace($Comments)) {
            $Comments = "Inter-tier move: $parsedTier → next tier ($(Get-Date -Format 'yyyy-MM-dd HH:mm'))"
        }
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Comments is $Comments"

        # Check and populate simple parameter: ProGetBaseUrl
        $ProGetBaseUrl = Get-PVal -ParameterName 'ProGetBaseUrl' -originalPSBoundParameters $PSBoundParameters -dottedPath 'ProGetBaseUrl' -DefaultValue $ProGetBaseUrl
        if ([string]::IsNullOrWhiteSpace($ProGetBaseUrl)) {
            $ProGetBaseUrl = $global:ProGetBaseUrl
        }
        if ([string]::IsNullOrWhiteSpace($ProGetBaseUrl)) {
            $errorMessage = 'ProGetBaseUrl could not be resolved. Pass it explicitly, set $global:ProGetBaseUrl, or ensure configRootKeys are loaded.'
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
            throw $errorMessage
        }
        $ProGetBaseUrl = $ProGetBaseUrl.TrimEnd('/')
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "ProGetBaseUrl is $ProGetBaseUrl"

        # Check and populate simple parameter: ApiKey
        $ApiKey = Get-PVal -ParameterName 'ApiKey' -originalPSBoundParameters $PSBoundParameters -dottedPath 'ApiKey' -DefaultValue $ApiKey
        if ([string]::IsNullOrWhiteSpace($ApiKey)) {
            $ApiKey = $env:PROGET_BUILDMASTER_API_KEY
        }
        if ([string]::IsNullOrWhiteSpace($ApiKey)) {
            $errorMessage = 'ApiKey could not be resolved. Pass it explicitly or set $env:PROGET_BUILDMASTER_API_KEY.'
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
            throw $errorMessage
        }

        $headers = @{
            'Accept'   = 'application/json'
            'X-ApiKey' = $ApiKey
        }

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Package:     $PackageName"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Version:     $Version"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Source:      $SourceFeed (tier: $parsedTier)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Destination: $DestinationFeed"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Push feed:   $($UsePushFeed ? 'Yes (Phase 2)' : 'No (Phase 1 / combined)')"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'All parameters validated successfully'
    }

    process {
        # ── Step 1: Verify package exists in source feed ─────────────────────
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Verifying '$PackageName' v$Version exists in '$SourceFeed'"

        $checkUrl = "$ProGetBaseUrl/api/packages/$SourceFeed/versions" +
        "?name=$([uri]::EscapeDataString($PackageName))&version=$([uri]::EscapeDataString($Version))"

        try {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling $checkUrl" -Tag 'RestCall'
            $packageCheck = Invoke-RestMethod -Uri $checkUrl -Headers $headers -Method Get -ErrorAction Stop
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from $checkUrl" -Tag 'RestCall'
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Package verified in source feed'
        } catch {
            # ProGet versions endpoint may not be available on all editions;
            # proceed anyway and let the promotion API validate
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Could not verify via API — ProGet will validate during move'
        }

        # ── Step 2: Move to next tier ─────────────────────────────────────────
        $promoteUrl = "$ProGetBaseUrl/api/promotions/promote"
        $body = @{
            packageName = $PackageName
            version     = $Version
            fromFeed    = $SourceFeed
            toFeed      = $DestinationFeed
            comments    = $Comments
        }

        $response = $null
        $targetMessage = "'{0}' v{1}" -f $PackageName, $Version
        $actionMessage = "Move from '{0}' to '{1}'" -f $SourceFeed, $DestinationFeed
        if ($PSCmdlet.ShouldProcess($targetMessage, $actionMessage)) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message ("Moving '{0}' v{1}: '{2}' -> '{3}'" -f $PackageName, $Version, $SourceFeed, $DestinationFeed)
            try {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling $promoteUrl" -Tag 'RestCall'
                $response = Invoke-RestMethod -Uri $promoteUrl -Method POST -Headers $headers `
                    -Body ($body | ConvertTo-Json -Depth 3) -ContentType 'application/json' -ErrorAction Stop
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from $promoteUrl" -Tag 'RestCall'
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Move successful'
            } catch {
                $errorMessage = "Failed to move '$PackageName' v$Version from '$SourceFeed' to '$DestinationFeed'. Exception: $($_.Exception.Message)"
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
                throw
            }
        }

        [PSCustomObject]@{
            PackageName     = $PackageName
            Version         = $Version
            SourceFeed      = $SourceFeed
            SourceTier      = $parsedTier
            DestinationFeed = $DestinationFeed
            DestinationTier = if ($DestinationFeed -match '-(\w+?)(-push)?$') { $matches[1] } else { '(custom)' }
            PackageType     = $parsedPrefix
            Phase2Mode      = [bool]$UsePushFeed
            Promoted        = $true
            Response        = $response
        }
    }

    end {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Done. Next step:'
        if ($UsePushFeed) {
            $pullFeedName = $DestinationFeed -replace '-push$', ''
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "  Run Move-ProGetPackageIntraTier to scan and move from '$DestinationFeed' to '$pullFeedName'"
        } else {
            $nextTierIndex = $currentTierIndex + 1
            if ($nextTierIndex -lt ($tierOrder.Count - 1)) {
                $nextNextTier = $tierOrder[$nextTierIndex + 1]
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "  When ready, run this script again with -SourceFeed '$DestinationFeed' to move to '$parsedPrefix-$nextNextTier'"
            } else {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "  Package is now in the '$($tierOrder[$nextTierIndex])' tier. No further movement available."
            }
        }
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
    }
}
