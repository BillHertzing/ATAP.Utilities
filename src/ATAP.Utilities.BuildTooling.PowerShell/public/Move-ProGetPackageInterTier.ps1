#Requires -Version 7.0
function Move-ProGetPackageInterTier {
    <#
.SYNOPSIS
    Moves a package between permanent ProGet feeds per the immutable promotion
    model. See `BuildMaster-Pipeline-Topology.md`.

.DESCRIPTION
    Inter-tier movement advances a validated package upward through the
    environment tiers: Experimental → Development → Integration → QA → Stable.

    The script knows the tier ordering and can automatically determine the
    destination feed from the source feed name.

    The tier chain is:
        experimental → development → integration → qa → stable

    The script detects the package type (nuget, powershellget, chocolatey)
    from the source feed name prefix.

.PARAMETER Name
    The package ID (e.g., 'ATAP.Utilities.Configuration.Extensions').
    Alias: PackageName (legacy).

.PARAMETER Version
    The exact package version to move (e.g., '1.2.0-experimental.42').
    Alias: PackageVersion (legacy).

.PARAMETER FromFeed
    The current tier's pull feed (e.g., 'nuget-experimental').
    The script parses this to determine the package type and current tier.
    Alias: SourceFeed (legacy).

.PARAMETER ToFeed
    Optional. Override the automatic destination. If not specified, the
    script computes the next tier's feed based on the source feed name
    and the -UsePushFeed switch.
    Alias: DestinationFeed (legacy).

.PARAMETER UsePushFeed
    If set, the auto-computed destination targets the next tier's push feed
    (e.g., 'nuget-development-push'). Used when the destination tier
    separates push and pull feeds.
    If not set, the destination targets the next tier's combined feed
    (e.g., 'nuget-development').

.PARAMETER Reason
    Optional movement comment recorded in ProGet's audit log.
    Alias: Comments (legacy).

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
        -Name 'ATAP.Utilities.Configuration.Extensions' `
        -Version '1.2.0-experimental.42' `
        -FromFeed 'nuget-experimental'
    # Auto-destination: nuget-development

.EXAMPLE
    # Phase 2: Move from experimental pull to development push
    Move-ProGetPackageInterTier `
        -Name 'ATAP.Utilities.Configuration.Extensions' `
        -Version '1.2.0-experimental.42' `
        -FromFeed 'nuget-experimental' `
        -UsePushFeed
    # Auto-destination: nuget-development-push

.EXAMPLE
    # Explicit destination override
    Move-ProGetPackageInterTier `
        -Name 'MyModule' -Version '2.0.0-dev.5' `
        -FromFeed 'powershellget-development' `
        -ToFeed 'powershellget-qa-push'

.EXAMPLE
    # Dry run
    Move-ProGetPackageInterTier `
        -Name 'MyPackage' -Version '1.0.0' `
        -FromFeed 'nuget-qa' -WhatIf
    # Auto-destination: nuget-stable

.NOTES
    AI assisted using Powershell.instructions.md as guidelines

.LINK
    https://github.com/whertzing/ATAP.Utilities
#>

    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory)]
        [Alias('PackageName')]
        [string]$Name,

        [Parameter(Mandatory)]
        [Alias('PackageVersion')]
        [string]$Version,

        [Parameter(Mandatory)]
        [Alias('SourceFeed')]
        [string]$FromFeed,

        [Parameter(Mandatory = $false)]
        [Alias('DestinationFeed')]
        [string]$ToFeed,

        [switch]$UsePushFeed,

        [Alias('Comments')]
        [string]$Reason,

        [string]$ProGetBaseUrl,

        [string]$ApiKey
    )

    begin {
        $fn = 'Move-ProGetPackageInterTier'
        $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

        # Check and populate simple parameter: Name
        $Name = Get-PVal -ParameterName 'Name' -originalPSBoundParameters $PSBoundParameters -dottedPath 'Name' -DefaultValue $Name
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Name is $Name"

        # Check and populate simple parameter: Version
        $Version = Get-PVal -ParameterName 'Version' -originalPSBoundParameters $PSBoundParameters -dottedPath 'Version' -DefaultValue $Version
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Version is $Version"

        # Check and populate simple parameter: FromFeed
        $FromFeed = Get-PVal -ParameterName 'FromFeed' -originalPSBoundParameters $PSBoundParameters -dottedPath 'FromFeed' -DefaultValue $FromFeed
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "FromFeed is $FromFeed"

        # Check and populate simple parameter: ToFeed
        $ToFeed = Get-PVal -ParameterName 'ToFeed' -originalPSBoundParameters $PSBoundParameters -dottedPath 'ToFeed' -DefaultValue $ToFeed
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "ToFeed is $ToFeed"

        # ── Tier definitions ─────────────────────────────────────────────────
        # Ordered list of tiers. Index determines movement direction (lower → higher).
        $tierOrder = @('experimental', 'development', 'integration', 'qa', 'stable')
        $tierAliases = @{
            testing    = 'qa'
            production = 'stable'
        }

        # Known package type prefixes in feed names.
        # 'powershell' is accepted as a deprecated alias, but new feed names use
        # canonical 'powershellget-*' per Explainer 0111.
        $knownPrefixes = @('nuget', 'powershellget', 'powershell', 'chocolatey')

        # ── Parse source feed name ───────────────────────────────────────────
        # Feed names follow the pattern: {packageType}-{tier}[-push]
        # Examples: nuget-experimental, powershellget-development-push, chocolatey-qa

        $parsedPrefix = $null
        $parsedTier = $null

        foreach ($prefix in $knownPrefixes) {
            if ($FromFeed.StartsWith("$prefix-", [System.StringComparison]::OrdinalIgnoreCase)) {
                $parsedPrefix = $prefix
                $remainder = $FromFeed.Substring($prefix.Length + 1)  # skip "{prefix}-"
                # Strip any -push suffix (inter-tier should start from a pull feed,
                # but be lenient if user passes a push feed name)
                $remainder = $remainder -replace '-push$', ''
                $remainder = $remainder.ToLowerInvariant()
                if ($tierAliases.ContainsKey($remainder)) {
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Normalizing legacy tier name '$remainder' to '$($tierAliases[$remainder])'"
                    $remainder = $tierAliases[$remainder]
                }
                if ($parsedPrefix -eq 'powershell') {
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Normalizing deprecated feed prefix 'powershell' to 'powershellget'"
                    $parsedPrefix = 'powershellget'
                }
                if ($tierOrder -contains $remainder) {
                    $parsedTier = $remainder
                }
                break
            }
        }

        if (-not $parsedPrefix -or -not $parsedTier) {
            $errorMessage = "Cannot parse source feed name '$FromFeed'. " +
            'Expected format: {nuget|powershellget|chocolatey}-{experimental|development|integration|qa|stable}[-push]. Legacy prefix powershell and tiers testing/production are normalized.'
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
            throw $errorMessage
        }

        $currentTierIndex = $tierOrder.IndexOf($parsedTier)

        # ── Determine destination feed ───────────────────────────────────────
        if ([string]::IsNullOrWhiteSpace($ToFeed)) {
            if ($currentTierIndex -ge ($tierOrder.Count - 1)) {
                $errorMessage = "Source feed '$FromFeed' is already at the highest tier ('$parsedTier'). Cannot move further."
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
                throw $errorMessage
            }

            $nextTier = $tierOrder[$currentTierIndex + 1]
            $pushSuffix = if ($UsePushFeed) { '-push' } else { '' }
            $ToFeed = "$parsedPrefix-$nextTier$pushSuffix"
        }

        # Check and populate simple parameter: Reason (with computed default)
        $Reason = Get-PVal -ParameterName 'Reason' -originalPSBoundParameters $PSBoundParameters -dottedPath 'Reason' -DefaultValue $Reason
        if ([string]::IsNullOrWhiteSpace($Reason)) {
            $Reason = "Inter-tier move: $parsedTier → next tier ($(Get-Date -Format 'yyyy-MM-dd HH:mm'))"
        }
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Reason is $Reason"

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

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Package:     $Name"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Version:     $Version"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Source:      $FromFeed (tier: $parsedTier)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Destination: $ToFeed"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Push feed:   $($UsePushFeed ? 'Yes (Phase 2)' : 'No (Phase 1 / combined)')"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'All parameters validated successfully'
    }

    process {
        # ── Step 1: Verify package exists in source feed ─────────────────────
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Verifying '$Name' v$Version exists in '$FromFeed'"

        $checkUrl = "$ProGetBaseUrl/api/packages/$FromFeed/versions" +
        "?name=$([uri]::EscapeDataString($Name))&version=$([uri]::EscapeDataString($Version))"

        try {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling $checkUrl" -Tag 'RestCall'
            $packageCheck = Invoke-RestMethod -Uri $checkUrl -Headers $headers -Method Get -TimeoutSec 15 -ErrorAction Stop
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
            packageName = $Name
            version     = $Version
            fromFeed    = $FromFeed
            toFeed      = $ToFeed
            comments    = $Reason
        }

        $response = $null
        $promoted = $false
        $targetMessage = "'{0}' v{1}" -f $Name, $Version
        $actionMessage = "Move from '{0}' to '{1}'" -f $FromFeed, $ToFeed
        if ($PSCmdlet.ShouldProcess($targetMessage, $actionMessage)) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message ("Moving '{0}' v{1}: '{2}' -> '{3}'" -f $Name, $Version, $FromFeed, $ToFeed)
            try {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling $promoteUrl" -Tag 'RestCall'
                $response = Invoke-RestMethod -Uri $promoteUrl -Method POST -Headers $headers -TimeoutSec 60 `
                    -Body ($body | ConvertTo-Json -Depth 3) -ContentType 'application/json' -ErrorAction Stop
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from $promoteUrl" -Tag 'RestCall'
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Move successful'
                $promoted = $true
            } catch {
                $errorMessage = "Failed to move '$Name' v$Version from '$FromFeed' to '$ToFeed'. Exception: $($_.Exception.Message)"
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
                throw
            }
        }

        [PSCustomObject]@{
            PackageName     = $Name
            Version         = $Version
            SourceFeed      = $FromFeed
            SourceTier      = $parsedTier
            DestinationFeed = $ToFeed
            DestinationTier = if ($ToFeed -match '-(\w+?)(-push)?$') { $matches[1] } else { '(custom)' }
            PackageType     = $parsedPrefix
            Phase2Mode      = [bool]$UsePushFeed
            Promoted        = $promoted
            Response        = $response
        }
    }

    end {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Done. Next step:'
        if ($UsePushFeed) {
            $pullFeedName = $ToFeed -replace '-push$', ''
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "  Run Move-ProGetPackageIntraTier to scan and move from '$ToFeed' to '$pullFeedName'"
        } else {
            $nextTierIndex = $currentTierIndex + 1
            if ($nextTierIndex -lt ($tierOrder.Count - 1)) {
                $nextNextTier = $tierOrder[$nextTierIndex + 1]
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "  When ready, run this script again with -FromFeed '$ToFeed' to move to '$parsedPrefix-$nextNextTier'"
            } else {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "  Package is now in the '$($tierOrder[$nextTierIndex])' tier. No further movement available."
            }
        }
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
    }
}
