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

    The script detects the package type (nuget, powershellget, database, chocolatey)
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

.PARAMETER ProGetApiKeySecretName
    Bitwarden Secrets Manager SecretName for the ProGet promotion key. Raw
    API-key values and environment-variable fallbacks are unsupported.

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

        $fn = 'Move-ProGetPackageInterTier'
        $mn = 'ATAP.Utilities.BuildTooling.ProGet.PowerShell'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

        # Mandatory parameters are already resolved by the PowerShell binder. Do not
        # route explicit values through Get-PVal: BuildMaster deliberately launches
        # this function in a no-profile process where $global:settings is absent.
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Name is $Name"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Version is $Version"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "FromFeed is $FromFeed"
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
        $knownPrefixes = @('nuget', 'powershellget', 'powershell', 'database', 'chocolatey')

        # ── Parse source feed name ───────────────────────────────────────────
        # Feed names follow the pattern: {packageType}-{tier}[-push]
        # Examples: nuget-experimental, powershellget-development-push, database-qa, chocolatey-qa

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
            'Expected format: {nuget|powershellget|database|chocolatey}-{experimental|development|integration|qa|stable}[-push]. Legacy prefix powershell and tiers testing/production are normalized.'
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

        # Reason is optional and has a local computed default. Resolving it through
        # global settings makes an otherwise self-contained promotion host-sensitive.
        if ([string]::IsNullOrWhiteSpace($Reason)) {
            $Reason = "Inter-tier move: $parsedTier → next tier ($(Get-Date -Format 'yyyy-MM-dd HH:mm'))"
        }
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Reason is $Reason"

        # An explicit URL must work in the no-profile BuildMaster host. Only load and
        # invoke the configuration resolver when the caller did not provide a URL.
        if ([string]::IsNullOrWhiteSpace($ProGetBaseUrl)) {
            $globalProGetBaseUrl = Get-Variable -Name ProGetBaseUrl -Scope Global -ErrorAction SilentlyContinue
            if ($null -ne $globalProGetBaseUrl) {
                $ProGetBaseUrl = [string]$globalProGetBaseUrl.Value
            }
        }
        if ([string]::IsNullOrWhiteSpace($ProGetBaseUrl)) {
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
            $ProGetBaseUrl = Get-PVal -ParameterName 'ProGetBaseUrl' -originalPSBoundParameters $PSBoundParameters -dottedPath 'ProGetBaseUrl' -DefaultValue $null -AllowMissing
        }
        if ([string]::IsNullOrWhiteSpace($ProGetBaseUrl)) {
            $errorMessage = 'ProGetBaseUrl could not be resolved. Pass it explicitly, set $global:ProGetBaseUrl, or ensure configRootKeys are loaded.'
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
            throw $errorMessage
        }
        $ProGetBaseUrl = $ProGetBaseUrl.TrimEnd('/')
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "ProGetBaseUrl is $ProGetBaseUrl"

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Package:     $Name"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Version:     $Version"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Source:      $FromFeed (tier: $parsedTier)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Destination: $ToFeed"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Push feed:   $($UsePushFeed ? 'Yes (Phase 2)' : 'No (Phase 1 / combined)')"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'All parameters validated successfully'
    }

    process {
        if ($WhatIfPreference) {
            return [PSCustomObject]@{
                PackageName = $Name; Version = $Version; SourceFeed = $FromFeed
                SourceTier = $parsedTier; DestinationFeed = $ToFeed
                DestinationTier = if ($ToFeed -match '-(\w+?)(-push)?$') { $matches[1] } else { '(custom)' }
                PackageType = $parsedPrefix; Phase2Mode = [bool]$UsePushFeed
                Promoted = $false; Response = $null
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
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Verifying '$Name' v$Version exists in '$FromFeed'"

        $checkUrl = "$ProGetBaseUrl/api/packages/$FromFeed/versions" +
        "?name=$([uri]::EscapeDataString($Name))&version=$([uri]::EscapeDataString($Version))"

        $packageCheck = $null
        $sourceCheckAvailable = $false
        try {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling $checkUrl" -Tag 'RestCall'
            $packageCheck = Invoke-RestMethod -Uri $checkUrl -Headers $headers -Method Get -TimeoutSec 15 -ErrorAction Stop
            $sourceCheckAvailable = $true
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from $checkUrl" -Tag 'RestCall'
        } catch {
            # ProGet versions endpoint may not be available on all editions;
            # proceed anyway and let the promotion API validate
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Could not verify via API — ProGet will validate during move'
        }
        if ($sourceCheckAvailable) {
            if (@($packageCheck).Count -lt 1) {
                $errorMessage = "Package '$Name' v$Version was not found in source feed '$FromFeed'; promotion cannot continue."
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
                throw $errorMessage
            }
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Package verified in source feed'
        }

        # ── Step 2: Move to next tier ─────────────────────────────────────────
        $promoteUrl = "$ProGetBaseUrl/api/promotions/promote"
        $body = @{
            # ProGet's documented promotion endpoint accepts form-encoded
            # PromotePackageInput fields. In practice, JSON bodies can return
            # a success-shaped response without materializing the package in
            # the target feed on some ProGet versions.
            name     = $Name
            version  = $Version
            fromFeed = $FromFeed
            toFeed   = $ToFeed
            comments = $Reason
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
                    -Body $body -ContentType 'application/x-www-form-urlencoded' -ErrorAction Stop
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from $promoteUrl" -Tag 'RestCall'
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Move successful'
                $promoted = $true
            } catch {
                $safeException = ([string]$_.Exception.Message).Replace($apiKey, '***')
                $errorMessage = "Failed to move '$Name' v$Version from '$FromFeed' to '$ToFeed'. Exception: $safeException"
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
                throw $errorMessage
            }

            $destinationCheckUrl = "$ProGetBaseUrl/api/packages/$ToFeed/versions" +
            "?name=$([uri]::EscapeDataString($Name))&version=$([uri]::EscapeDataString($Version))"
            $destinationVerified = $false
            for ($attempt = 1; $attempt -le 6; $attempt++) {
                try {
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling $destinationCheckUrl" -Tag 'RestCall'
                    $destinationCheck = Invoke-RestMethod -Uri $destinationCheckUrl -Headers $headers -Method Get -TimeoutSec 15 -ErrorAction Stop
                    if (@($destinationCheck).Count -gt 0) {
                        $destinationVerified = $true
                        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Package verified in destination feed'
                        break
                    }
                } catch {
                    $safeException = ([string]$_.Exception.Message).Replace($apiKey, '***')
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Could not verify destination feed on attempt $attempt/6: $safeException"
                }

                if ($attempt -lt 6) {
                    Start-Sleep -Seconds 2
                }
            }

            if (-not $destinationVerified) {
                $errorMessage = "Promotion API returned successfully, but '$Name' v$Version was not visible in destination feed '$ToFeed' after verification. Check ProGet promotion permissions/feed configuration."
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
                throw $errorMessage
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
            Response        = if ($null -eq $response) { $null } else { (($response | Out-String).Trim()).Replace($apiKey, '***') }
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
