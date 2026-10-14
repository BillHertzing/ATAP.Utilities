#Requires -Version 7.0
function Move-ProGetPackageIntraTier {
    <#
.SYNOPSIS
    Moves a package from a push feed to a pull feed within the same tier,
    after running a malware/quality scan (currently stubbed).

.DESCRIPTION
    Intra-tier movement is the gated step between a push feed and its
    corresponding pull feed within one environment tier (e.g.,
    nuget-experimental-push → nuget-experimental).

    The five permanent tier names (reverted naming scheme, sprint-0007 onward)
    are: experimental, development, integration, qa, stable. There are no
    per-sprint feeds — all tiers use these shared permanent feeds. Per-developer
    isolation at experimental/development tiers is enforced via NBGV-derived
    version suffixes, not via separate feeds.

    In Phase 1 (combined feeds), this script can be used as a validate-only
    step by passing the same feed name for both -FromFeed and
    -ToFeed, or by using the -ScanOnly switch.

    In Phase 2 (split push/pull feeds), this script performs the actual
    movement from the push feed to the pull feed after the scan passes.
    Example: nuget-experimental-push → nuget-experimental.

    The malware scan is currently a STUB that always passes. Replace the
    Invoke-MalwareScan function with a real implementation when available
    (e.g., ProGet vulnerability scanning, ClamAV, or a commercial scanner).

.PARAMETER Name
    The package ID (e.g., 'ATAP.Utilities.Configuration.Extensions').
    Alias: PackageName (legacy).

.PARAMETER Version
    The exact package version to move (e.g., '1.2.0-experimental.42').
    Alias: PackageVersion (legacy).

.PARAMETER FromFeed
    The push feed name (e.g., 'nuget-experimental-push').
    In Phase 1, this is the combined feed name (e.g., 'nuget-experimental').
    Alias: SourceFeed (legacy).

.PARAMETER ToFeed
    The pull feed name (e.g., 'nuget-experimental').
    In Phase 1, pass the same name as FromFeed, or use -ScanOnly.
    Alias: DestinationFeed (legacy).

.PARAMETER ScanOnly
    If set, only runs the malware scan without moving. Useful in Phase 1
    where push and pull are the same feed.

.PARAMETER Reason
    Optional movement comment recorded in ProGet's audit log.
    Alias: Comments (legacy).

.PARAMETER ProGetBaseUrl
    The ProGet base URL (e.g., 'https://utat022:50000').
    Falls back to: $global:settings via configRootKeys → $global:ProGetBaseUrl.

.PARAMETER ProGetApiKeySecretName
    Bitwarden Secrets Manager SecretName for the ProGet promotion key. Raw
    API-key values and environment-variable fallbacks are unsupported.

.OUTPUTS
    PSCustomObject with properties: PackageName, Version, SourceFeed,
    DestinationFeed, ScanPassed, Promoted, Reason, Response.

.EXAMPLE
    # Phase 2: Move from push to pull within experimental tier
    Move-ProGetPackageIntraTier `
        -Name 'ATAP.Utilities.Configuration.Extensions' `
        -Version '1.2.0-experimental.42' `
        -FromFeed 'nuget-experimental-push' `
        -ToFeed 'nuget-experimental'

.EXAMPLE
    # Phase 1: Scan only (push and pull are the same feed)
    Move-ProGetPackageIntraTier `
        -Name 'ATAP.Utilities.Configuration.Extensions' `
        -Version '1.2.0-experimental.42' `
        -FromFeed 'nuget-experimental' `
        -ToFeed 'nuget-experimental' `
        -ScanOnly

.EXAMPLE
    # Dry run
    Move-ProGetPackageIntraTier `
        -Name 'MyPackage' -Version '1.0.0' `
        -FromFeed 'nuget-experimental-push' `
        -ToFeed 'nuget-experimental' -WhatIf

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

        [Parameter(Mandatory)]
        [Alias('DestinationFeed')]
        [string]$ToFeed,

        [switch]$ScanOnly,

        [Alias('Comments')]
        [string]$Reason,

        [string]$ProGetBaseUrl,

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

        $fn = $MyInvocation.MyCommand.Name
        $mn = 'ATAP.Utilities.BuildTooling.ProGet.PowerShell'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

        if (-not (Get-Command -Name 'Get-ParameterValueFromNeoConfigurationRoot' -CommandType Function -ErrorAction SilentlyContinue)) {
            $helperCandidates = @(
                (Join-Path -Path $PSScriptRoot -ChildPath 'Get-ParameterValueFromNeoConfigurationRoot.ps1'),
                ([System.IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath '..\..\ATAP.Utilities.PowerShell\public\Get-ParameterValueFromNeoConfigurationRoot.ps1'))),
                ([System.IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath '..\..\ATAP.Utilities.Powershell\public\Get-ParameterValueFromNeoConfigurationRoot.ps1'))),
                'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\Get-ParameterValueFromNeoConfigurationRoot.ps1'
            )
            $helperPath = $helperCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
            if (-not $helperPath) {
                throw "Could not locate Get-ParameterValueFromNeoConfigurationRoot.ps1. Checked: $($helperCandidates -join ', ')"
            }
            . $helperPath
        }
        Set-Alias -Name Get-PVal -Value Get-ParameterValueFromNeoConfigurationRoot -Scope Local -Force

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

        # Check and populate simple parameter: Reason (with computed default)
        $Reason = Get-PVal -ParameterName 'Reason' -originalPSBoundParameters $PSBoundParameters -dottedPath 'Reason' -DefaultValue $Reason
        if ([string]::IsNullOrWhiteSpace($Reason)) {
            $Reason = "Intra-tier move after scan ($(Get-Date -Format 'yyyy-MM-dd HH:mm'))"
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

        # Validate that source/destination follow expected Phase 2 push/pull feed pair naming.
        # Also support the legacy testing -> qa alias. The retired physical
        # production feed name fails closed; stable is the canonical top tier.
        # 'powershell' is accepted as a deprecated alias. Canonical ProGet
        # PowerShell feed names use the powershellget-* prefix.
        $knownPrefixes = @('nuget', 'powershellget', 'powershell', 'chocolatey')
        $tierOrder = @('experimental', 'development', 'integration', 'qa', 'stable')
        $tierAliases = @{
            testing = 'qa'
        }

        foreach ($feedName in @($FromFeed, $ToFeed)) {
            if ($feedName -match '-production(?:-push)?$') {
                $stableFeedName = $feedName -replace '-production(?=-push$|$)', '-stable'
                $errorMessage = "Feed '$feedName' uses the retired physical tier name 'production'. Use '$stableFeedName'."
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
                throw $errorMessage
            }
        }

        $feedPattern = "^(?<prefix>$($knownPrefixes -join '|'))-(?<tier>[a-z]+?)(?<push>-push)?$"

        if ($FromFeed -match $feedPattern) {
            $sourcePrefix = $matches['prefix'].ToLowerInvariant()
            if ($sourcePrefix -eq 'powershell') {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Normalizing deprecated source prefix 'powershell' to 'powershellget'"
                $sourcePrefix = 'powershellget'
            }
            $sourceTier = $matches['tier'].ToLowerInvariant()
            $sourceIsPush = -not [string]::IsNullOrWhiteSpace($matches['push'])
            if ($tierAliases.ContainsKey($sourceTier)) {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Normalizing legacy source tier '$sourceTier' to '$($tierAliases[$sourceTier])'"
                $sourceTier = $tierAliases[$sourceTier]
            }
        } else {
            $errorMessage = "FromFeed '$FromFeed' does not match expected format '{nuget|powershellget|chocolatey}-{tier}[-push]'"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
            throw $errorMessage
        }

        if ($ToFeed -match $feedPattern) {
            $destinationPrefix = $matches['prefix'].ToLowerInvariant()
            if ($destinationPrefix -eq 'powershell') {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Normalizing deprecated destination prefix 'powershell' to 'powershellget'"
                $destinationPrefix = 'powershellget'
            }
            $destinationTier = $matches['tier'].ToLowerInvariant()
            $destinationIsPush = -not [string]::IsNullOrWhiteSpace($matches['push'])
            if ($tierAliases.ContainsKey($destinationTier)) {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Normalizing legacy destination tier '$destinationTier' to '$($tierAliases[$destinationTier])'"
                $destinationTier = $tierAliases[$destinationTier]
            }
        } else {
            $errorMessage = "ToFeed '$ToFeed' does not match expected format '{nuget|powershellget|chocolatey}-{tier}[-push]'"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
            throw $errorMessage
        }

        if (($tierOrder -notcontains $sourceTier) -or ($tierOrder -notcontains $destinationTier)) {
            $errorMessage = "Feed tiers must be one of: $($tierOrder -join ', '). Source '$sourceTier', destination '$destinationTier'"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
            throw $errorMessage
        }

        if (-not $ScanOnly -and ($FromFeed -ne $ToFeed)) {
            if (-not $sourceIsPush) {
                $errorMessage = "FromFeed '$FromFeed' must be a push feed ('-push') in Phase 2 intra-tier movement."
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
                throw $errorMessage
            }
            if ($destinationIsPush) {
                $errorMessage = "ToFeed '$ToFeed' must be a pull feed (no '-push') in Phase 2 intra-tier movement."
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
        if ($WhatIfPreference) {
            return [PSCustomObject]@{
                PackageName = $Name; Version = $Version; SourceFeed = $FromFeed
                DestinationFeed = $ToFeed; ScanPassed = $false
                Promoted = $false; Reason = 'WhatIf'
            }
        }

        try {
            $apiKey = [string](Get-SecretATAP -SecretName $ProGetApiKeySecretName -SecretStoreType 'BitwardenSecretsManager' -ErrorAction Stop)
        } catch {
            throw "Unable to resolve the ProGet API key from SecretName '$ProGetApiKeySecretName'."
        }
        if ([string]::IsNullOrWhiteSpace($apiKey)) {
            throw "The ProGet secret named '$ProGetApiKeySecretName' resolved to an empty value."
        }
        $headers = @{ 'Accept' = 'application/json'; 'X-ApiKey' = $apiKey }

        # ── Step 1: Verify package exists in source feed ─────────────────────
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Verifying '$Name' v$Version exists in feed '$FromFeed'"

        $packageInfoUrl = "$ProGetBaseUrl/api/packages/$FromFeed/versions" +
        "?name=$([uri]::EscapeDataString($Name))&version=$([uri]::EscapeDataString($Version))"

        $packageInfo = $null
        try {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling $packageInfoUrl" -Tag 'RestCall'
            $packageInfo = Invoke-RestMethod -Uri $packageInfoUrl -Headers $headers -Method Get -ErrorAction Stop
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from $packageInfoUrl" -Tag 'RestCall'
        } catch {
            # Versions endpoint may not be available on all ProGet editions; proceed and let promotion API validate
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Versions endpoint not available — ProGet will validate during move'
        }

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Package found in '$FromFeed'"

        # ── Step 2: Malware / quality scan ───────────────────────────────────
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Running malware scan on '$Name' v$Version"

        $scanResult = Invoke-MalwareScan -PackageName $Name -Version $Version `
            -FeedName $FromFeed -ProGetBaseUrl $ProGetBaseUrl

        if (-not $scanResult.Passed) {
            $errorMessage = "MALWARE SCAN FAILED for '$Name' v$Version in '$FromFeed'. " +
            "Reason: $($scanResult.Reason). Move aborted."
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
            throw $errorMessage
        }

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Scan passed: $($scanResult.Reason)"

        # ── Step 3: Move (unless ScanOnly or same-feed) ───────────────────────
        if ($ScanOnly) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'ScanOnly mode — skipping move'
            [PSCustomObject]@{
                PackageName     = $Name
                Version         = $Version
                SourceFeed      = $FromFeed
                DestinationFeed = $ToFeed
                ScanPassed      = $true
                Promoted        = $false
                Reason          = 'ScanOnly mode'
            }
            return
        }

        if ($FromFeed -eq $ToFeed) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Source and destination are the same feed ('$FromFeed'). Scan completed, no move needed (Phase 1 mode)"
            [PSCustomObject]@{
                PackageName     = $Name
                Version         = $Version
                SourceFeed      = $FromFeed
                DestinationFeed = $ToFeed
                ScanPassed      = $true
                Promoted        = $false
                Reason          = 'Same feed (Phase 1)'
            }
            return
        }

        $promoteUrl = "$ProGetBaseUrl/api/promotions/promote"
        $body = @{
            # ProGet's PromotePackageInput JSON contract uses "name".
            name     = $Name
            version  = $Version
            fromFeed = $FromFeed
            toFeed   = $ToFeed
            comments = $Reason
        }

        $response = $null
        if ($PSCmdlet.ShouldProcess("'$Name' v$Version", "Move from '$FromFeed' to '$ToFeed'")) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Moving '$Name' v$Version : '$FromFeed' → '$ToFeed'"
            try {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling $promoteUrl" -Tag 'RestCall'
                $response = Invoke-RestMethod -Uri $promoteUrl -Method POST -Headers $headers `
                    -Body ($body | ConvertTo-Json -Depth 3) -ContentType 'application/json' -ErrorAction Stop
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from $promoteUrl" -Tag 'RestCall'
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Move successful'
            } catch {
                $safeException = ([string]$_.Exception.Message).Replace($apiKey, '***')
                $errorMessage = "Failed to move '$Name' v$Version from '$FromFeed' to '$ToFeed'. Exception: $safeException"
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
                throw $errorMessage
            }
        }

        [PSCustomObject]@{
            PackageName     = $Name
            Version         = $Version
            SourceFeed      = $FromFeed
            DestinationFeed = $ToFeed
            ScanPassed      = $true
            Promoted        = $true
            Reason          = 'Intra-tier move after scan'
            Response        = if ($null -eq $response) { $null } else { (($response | Out-String).Trim()).Replace($apiKey, '***') }
        }
    }

    end {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
    }
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
        $mn = 'ATAP.Utilities.BuildTooling.ProGet.PowerShell'
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

