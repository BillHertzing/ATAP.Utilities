#Requires -Version 7.0
<#
.SYNOPSIS
    Moves a package from a push feed to a pull feed within the same tier,
    after running a malware/quality scan (currently stubbed).

.DESCRIPTION
    Intra-tier movement is the gated step between a push feed and its
    corresponding pull feed within one environment tier (e.g.,
    nuget-experimental-push → nuget-experimental).

    In Phase 1 (combined feeds), this script can be used as a validate-only
    step by passing the same feed name for both -SourceFeed and
    -DestinationFeed, or by using the -ScanOnly switch.

    In Phase 2 (split push/pull feeds), this script performs the actual
    movement from the push feed to the pull feed after the scan passes.

    The malware scan is currently a STUB that always passes. Replace the
    Invoke-MalwareScan function with a real implementation when available
    (e.g., ProGet vulnerability scanning, ClamAV, or a commercial scanner).

.PARAMETER PackageName
    The package ID (e.g., 'ATAP.Utilities.Configuration.Extensions').

.PARAMETER Version
    The exact package version to move (e.g., '1.2.0-experimental.42').

.PARAMETER SourceFeed
    The push feed name (e.g., 'nuget-experimental-push').
    In Phase 1, this is the combined feed name (e.g., 'nuget-experimental').

.PARAMETER DestinationFeed
    The pull feed name (e.g., 'nuget-experimental').
    In Phase 1, pass the same name as SourceFeed, or use -ScanOnly.

.PARAMETER ScanOnly
    If set, only runs the malware scan without moving. Useful in Phase 1
    where push and pull are the same feed.

.PARAMETER Comments
    Optional movement comment recorded in ProGet's audit log.

.PARAMETER ProGetBaseUrl
    The ProGet base URL (e.g., 'http://localhost:50000').
    Falls back to: $global:settings via configRootKeys → $global:ProGetBaseUrl.

.PARAMETER ApiKey
    The API key for ProGet. Falls back to: $env:PROGET_BUILDMASTER_API_KEY →
    env var via configRootKeys.

.OUTPUTS
    PSCustomObject with properties: PackageName, Version, SourceFeed,
    DestinationFeed, ScanPassed, Promoted, Reason, Response.

.EXAMPLE
    # Phase 2: Move from push to pull within experimental tier
    Move-ProGetPackageIntraTier.ps1 `
        -PackageName 'ATAP.Utilities.Configuration.Extensions' `
        -Version '1.2.0-experimental.42' `
        -SourceFeed 'nuget-experimental-push' `
        -DestinationFeed 'nuget-experimental'

.EXAMPLE
    # Phase 1: Scan only (push and pull are the same feed)
    Move-ProGetPackageIntraTier.ps1 `
        -PackageName 'ATAP.Utilities.Configuration.Extensions' `
        -Version '1.2.0-experimental.42' `
        -SourceFeed 'nuget-experimental' `
        -DestinationFeed 'nuget-experimental' `
        -ScanOnly

.EXAMPLE
    # Dry run
    Move-ProGetPackageIntraTier.ps1 `
        -PackageName 'MyPackage' -Version '1.0.0' `
        -SourceFeed 'nuget-experimental-push' `
        -DestinationFeed 'nuget-experimental' -WhatIf

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

    [Parameter(Mandatory)]
    [string]$DestinationFeed,

    [switch]$ScanOnly,

    [string]$Comments,

    [string]$ProGetBaseUrl,

    [string]$ApiKey
)

begin {
    $fn = 'Move-ProGetPackageIntraTier'
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

    # Check and populate simple parameter: Comments (with computed default)
    $Comments = Get-PVal -ParameterName 'Comments' -originalPSBoundParameters $PSBoundParameters -dottedPath 'Comments' -DefaultValue $Comments
    if ([string]::IsNullOrWhiteSpace($Comments)) {
        $Comments = "Intra-tier move after scan ($(Get-Date -Format 'yyyy-MM-dd HH:mm'))"
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

    # Validate that source/destination follow expected Phase 2 push/pull feed pair naming.
    # Also support legacy tier aliases (testing -> qa, production -> stable).
    $knownPrefixes = @('nuget', 'powershell', 'chocolatey')
    $tierOrder = @('experimental', 'development', 'integration', 'qa', 'stable')
    $tierAliases = @{
        testing   = 'qa'
        production = 'stable'
    }

    $feedPattern = "^(?<prefix>$($knownPrefixes -join '|'))-(?<tier>[a-z]+?)(?<push>-push)?$"

    if ($SourceFeed -match $feedPattern) {
        $sourcePrefix = $matches['prefix'].ToLowerInvariant()
        $sourceTier = $matches['tier'].ToLowerInvariant()
        $sourceIsPush = -not [string]::IsNullOrWhiteSpace($matches['push'])
        if ($tierAliases.ContainsKey($sourceTier)) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Normalizing legacy source tier '$sourceTier' to '$($tierAliases[$sourceTier])'"
            $sourceTier = $tierAliases[$sourceTier]
        }
    }
    else {
        $errorMessage = "SourceFeed '$SourceFeed' does not match expected format '{nuget|powershell|chocolatey}-{tier}[-push]'"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        throw $errorMessage
    }

    if ($DestinationFeed -match $feedPattern) {
        $destinationPrefix = $matches['prefix'].ToLowerInvariant()
        $destinationTier = $matches['tier'].ToLowerInvariant()
        $destinationIsPush = -not [string]::IsNullOrWhiteSpace($matches['push'])
        if ($tierAliases.ContainsKey($destinationTier)) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Normalizing legacy destination tier '$destinationTier' to '$($tierAliases[$destinationTier])'"
            $destinationTier = $tierAliases[$destinationTier]
        }
    }
    else {
        $errorMessage = "DestinationFeed '$DestinationFeed' does not match expected format '{nuget|powershell|chocolatey}-{tier}[-push]'"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        throw $errorMessage
    }

    if (($tierOrder -notcontains $sourceTier) -or ($tierOrder -notcontains $destinationTier)) {
        $errorMessage = "Feed tiers must be one of: $($tierOrder -join ', '). Source '$sourceTier', destination '$destinationTier'"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        throw $errorMessage
    }

    if (-not $ScanOnly -and ($SourceFeed -ne $DestinationFeed)) {
        if (-not $sourceIsPush) {
            $errorMessage = "SourceFeed '$SourceFeed' must be a push feed ('-push') in Phase 2 intra-tier movement."
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
            throw $errorMessage
        }
        if ($destinationIsPush) {
            $errorMessage = "DestinationFeed '$DestinationFeed' must be a pull feed (no '-push') in Phase 2 intra-tier movement."
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
            throw $errorMessage
        }
        if ($sourcePrefix -ne $destinationPrefix) {
            $errorMessage = "Feed package type must match. Source prefix '$sourcePrefix' and destination prefix '$destinationPrefix' differ."
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
            throw $errorMessage
        }
        if ($sourceTier -ne $destinationTier) {
            $errorMessage = "Intra-tier movement requires the same tier. Source tier '$sourceTier' and destination tier '$destinationTier' differ."
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
            throw $errorMessage
        }
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'All parameters validated successfully'
}

process {
    # ── Step 1: Verify package exists in source feed ─────────────────────
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Verifying '$PackageName' v$Version exists in feed '$SourceFeed'"

    $packageInfoUrl = "$ProGetBaseUrl/api/packages/$SourceFeed/versions" +
    "?name=$([uri]::EscapeDataString($PackageName))&version=$([uri]::EscapeDataString($Version))"

    $packageInfo = $null
    try {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling $packageInfoUrl" -Tag 'RestCall'
        $packageInfo = Invoke-RestMethod -Uri $packageInfoUrl -Headers $headers -Method Get -ErrorAction Stop
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from $packageInfoUrl" -Tag 'RestCall'
    }
    catch {
        # Versions endpoint may not be available on all ProGet editions; proceed and let promotion API validate
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Versions endpoint not available — ProGet will validate during move'
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Package found in '$SourceFeed'"

    # ── Step 2: Malware / quality scan ───────────────────────────────────
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Running malware scan on '$PackageName' v$Version"

    $scanResult = Invoke-MalwareScan -PackageName $PackageName -Version $Version `
        -FeedName $SourceFeed -ProGetBaseUrl $ProGetBaseUrl

    if (-not $scanResult.Passed) {
        $errorMessage = "MALWARE SCAN FAILED for '$PackageName' v$Version in '$SourceFeed'. " +
        "Reason: $($scanResult.Reason). Move aborted."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        throw $errorMessage
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Scan passed: $($scanResult.Reason)"

    # ── Step 3: Move (unless ScanOnly or same-feed) ───────────────────────
    if ($ScanOnly) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'ScanOnly mode — skipping move'
        [PSCustomObject]@{
            PackageName     = $PackageName
            Version         = $Version
            SourceFeed      = $SourceFeed
            DestinationFeed = $DestinationFeed
            ScanPassed      = $true
            Promoted        = $false
            Reason          = 'ScanOnly mode'
        }
        return
    }

    if ($SourceFeed -eq $DestinationFeed) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Source and destination are the same feed ('$SourceFeed'). Scan completed, no move needed (Phase 1 mode)"
        [PSCustomObject]@{
            PackageName     = $PackageName
            Version         = $Version
            SourceFeed      = $SourceFeed
            DestinationFeed = $DestinationFeed
            ScanPassed      = $true
            Promoted        = $false
            Reason          = 'Same feed (Phase 1)'
        }
        return
    }

    $promoteUrl = "$ProGetBaseUrl/api/promotions/promote"
    $body = @{
        packageName = $PackageName
        version     = $Version
        fromFeed    = $SourceFeed
        toFeed      = $DestinationFeed
        comments    = $Comments
    }

    $response = $null
    if ($PSCmdlet.ShouldProcess("'$PackageName' v$Version", "Move from '$SourceFeed' to '$DestinationFeed'")) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Moving '$PackageName' v$Version: '$SourceFeed' → '$DestinationFeed'"
        try {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling $promoteUrl" -Tag 'RestCall'
            $response = Invoke-RestMethod -Uri $promoteUrl -Method POST -Headers $headers `
                -Body ($body | ConvertTo-Json -Depth 3) -ContentType 'application/json' -ErrorAction Stop
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from $promoteUrl" -Tag 'RestCall'
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Move successful'
        }
        catch {
            $errorMessage = "Failed to move '$PackageName' v$Version from '$SourceFeed' to '$DestinationFeed'. Exception: $($_.Exception.Message)"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
            throw
        }
    }

    [PSCustomObject]@{
        PackageName     = $PackageName
        Version         = $Version
        SourceFeed      = $SourceFeed
        DestinationFeed = $DestinationFeed
        ScanPassed      = $true
        Promoted        = $true
        Reason          = 'Intra-tier move after scan'
        Response        = $response
    }
}

end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
}

# ═══════════════════════════════════════════════════════════════════════════
#  MALWARE SCAN — STUB IMPLEMENTATION
# ═══════════════════════════════════════════════════════════════════════════
#
#  Replace this function with a real implementation. Candidates:
#
#  1. ProGet vulnerability scanning (requires ProGet paid license)
#     - Enable vulnerabilities on the feed, query the API after push
#
#  2. ClamAV (open source)
#     - Download the .nupkg to a temp folder
#     - Run: clamscan --no-summary <file>
#     - Parse exit code (0 = clean, 1 = infected)
#
#  3. Windows Defender CLI
#     - Start-MpScan -ScanPath <temp-folder> -ScanType CustomScan
#
#  4. Commercial API (VirusTotal, etc.)
#     - Upload hash, check results
#
# ═══════════════════════════════════════════════════════════════════════════

function Invoke-MalwareScan {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$PackageName,

        [Parameter(Mandatory)]
        [string]$Version,

        [Parameter(Mandatory)]
        [string]$FeedName,

        [Parameter(Mandatory)]
        [string]$ProGetBaseUrl
    )

    begin {
        $fn = 'Invoke-MalwareScan'
        $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

        # Check and populate simple parameter: PackageName
        $PackageName = Get-PVal -ParameterName 'PackageName' -originalPSBoundParameters $PSBoundParameters -dottedPath 'PackageName' -DefaultValue $PackageName

        # Check and populate simple parameter: Version
        $Version = Get-PVal -ParameterName 'Version' -originalPSBoundParameters $PSBoundParameters -dottedPath 'Version' -DefaultValue $Version

        # Check and populate simple parameter: FeedName
        $FeedName = Get-PVal -ParameterName 'FeedName' -originalPSBoundParameters $PSBoundParameters -dottedPath 'FeedName' -DefaultValue $FeedName

        # Check and populate simple parameter: ProGetBaseUrl
        $ProGetBaseUrl = Get-PVal -ParameterName 'ProGetBaseUrl' -originalPSBoundParameters $PSBoundParameters -dottedPath 'ProGetBaseUrl' -DefaultValue $ProGetBaseUrl
    }

    process {
        # ── STUB: Always passes ──────────────────────────────────────────────
        # ToDo: Replace with real scanning logic
        # ToDo: File scope-creep item SC-NNNN for real malware scanning
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "[STUB] Malware scan for '$PackageName' v$Version — always passes"

        [PSCustomObject]@{
            Passed      = $true
            Reason      = 'Stub scan — no real scanning implemented yet'
            PackageName = $PackageName
            Version     = $Version
            FeedName    = $FeedName
            ScanDate    = (Get-Date).ToString('o')
        }
    }

    end {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
    }
}
