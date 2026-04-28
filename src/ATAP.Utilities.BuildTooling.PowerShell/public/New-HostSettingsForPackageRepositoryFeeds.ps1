#Requires -Version 7.0
<#
.SYNOPSIS
    Writes a machine-scope settings file recording all known feed → URL → API-key
    mappings for the ten permanent ProGet feeds.

.DESCRIPTION
    Generates (or overwrites) a machine-scope PowerShell data file that records
    every permanent ProGet feed name, its URI, and its API-key name. This file is
    consumed by `Get-ATAPIACConstant` and by any automation that needs feed
    coordinates without requiring an interactive session.

    The ten permanent feeds (reverted naming scheme, sprint-0007 onward):

        nuget-experimental          powershellget-experimental
        nuget-development           powershellget-development
        nuget-integration           powershellget-integration
        nuget-qa                    powershellget-qa
        nuget-stable                powershellget-stable

    There are no per-sprint feeds. All five tiers share these permanent feeds.
    Per-developer isolation at Experimental/Development is enforced via
    NBGV-derived prerelease-version suffixes, not via separate feed instances.

    Feed metadata is read from `$global:settings` via `$global:configRootKeys`
    (key: `ProGetFeedCollectionConfigRootKey`). If `$global:settings` is not
    loaded, the caller must pass explicit values via -FeedBaseUrl and -ApiKey.

    The output file is a `.psd1` hashtable understood by `Import-PowerShellDataFile`.

.PARAMETER OutputPath
    Path to the machine-scope settings file to write. Defaults to:
        $env:ProgramData\ATAP\HostSettings.PackageRepositoryFeeds.psd1
    The parent directory is created automatically if absent.

.PARAMETER FeedBaseUrl
    Override the ProGet base URL (scheme + host + port, e.g.
    'http://proget-host:50000'). If omitted, resolved from
    `$global:settings[$global:configRootKeys['ProGetAdminUriConfigRootKey']]`.

.PARAMETER ApiKey
    Override the ProGet API key used for all feeds. If omitted, resolved from
    `$env:PROGET_BUILDMASTER_API_KEY`.

.PARAMETER Force
    Overwrite the output file if it already exists without prompting.

.INPUTS
    None. This cmdlet does not accept pipeline input.

.OUTPUTS
    PSCustomObject with properties:
        OutputPath   [string]  — absolute path of the written file
        FeedsWritten [string[]] — ordered list of feed names recorded
        Written      [bool]    — $true if the file was created/overwritten

.EXAMPLE
    # Write using $global:settings and env var API key:
    New-HostSettingsForPackageRepositoryFeeds

.EXAMPLE
    # Explicit values (useful in a BuildMaster agent shell with no profile):
    New-HostSettingsForPackageRepositoryFeeds `
        -FeedBaseUrl 'http://proget.corp:50000' `
        -ApiKey $env:PROGET_BUILDMASTER_API_KEY `
        -OutputPath 'C:\ProgramData\ATAP\HostSettings.PackageRepositoryFeeds.psd1'

.EXAMPLE
    # Dry run to preview without writing:
    New-HostSettingsForPackageRepositoryFeeds -WhatIf

.NOTES
    AI assisted using Powershell.instructions.md as guidelines

.LINK
    https://github.com/whertzing/ATAP.Utilities
#>
function New-HostSettingsForPackageRepositoryFeeds {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath,

        [Parameter(Mandatory = $false)]
        [string]$FeedBaseUrl,

        [Parameter(Mandatory = $false)]
        [string]$ApiKey,

        [switch]$Force
    )

    begin {
        $fn = $MyInvocation.MyCommand.Name
        $mn = $MyInvocation.MyCommand.ModuleName
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

        # ── OutputPath ────────────────────────────────────────────────────
        if ([string]::IsNullOrWhiteSpace($OutputPath)) {
            $OutputPath = Join-Path $env:ProgramData 'ATAP' 'HostSettings.PackageRepositoryFeeds.psd1'
        }
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "OutputPath is '$OutputPath'"

        # ── FeedBaseUrl ───────────────────────────────────────────────────
        if ([string]::IsNullOrWhiteSpace($FeedBaseUrl)) {
            $FeedBaseUrl = $global:settings[$global:configRootKeys['ProGetAdminUriConfigRootKey']]
        }
        if ([string]::IsNullOrWhiteSpace($FeedBaseUrl)) {
            $errorMessage = "FeedBaseUrl could not be resolved. Pass it explicitly or ensure `$global:settings is loaded with 'ProGetAdminUriConfigRootKey'."
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
            throw $errorMessage
        }
        $FeedBaseUrl = $FeedBaseUrl.TrimEnd('/')
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "FeedBaseUrl is '$FeedBaseUrl'"

        # ── ApiKey ────────────────────────────────────────────────────────
        if ([string]::IsNullOrWhiteSpace($ApiKey)) {
            $ApiKey = $env:PROGET_BUILDMASTER_API_KEY
        }
        if ([string]::IsNullOrWhiteSpace($ApiKey)) {
            $errorMessage = "ApiKey could not be resolved. Pass it explicitly or set `$env:PROGET_BUILDMASTER_API_KEY."
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
            throw $errorMessage
        }

        # ── Permanent feed definitions ─────────────────────────────────
        # Ten permanent feeds: five NuGet + five PowerShellGet, one per tier.
        # Ordered from lowest to highest tier (matches the inter-tier promotion chain).
        $tierOrder = @('experimental', 'development', 'integration', 'qa', 'stable')
        $packageTypes = @(
            @{ Prefix = 'nuget';         ProGetType = 'nuget';         FeedUrlSegment = 'nuget'     }
            @{ Prefix = 'powershellget'; ProGetType = 'powershellget'; FeedUrlSegment = 'psget'     }
        )

        # Build the canonical feed list. Keys are feed names; values are hashtables
        # with Uri, ApiKeyName, FeedType, and Tier.
        $feedMap = [ordered]@{}
        foreach ($pt in $packageTypes) {
            foreach ($tier in $tierOrder) {
                $feedName   = "$($pt.Prefix)-$tier"
                $feedUri    = "$FeedBaseUrl/$($pt.FeedUrlSegment)/$feedName/"
                $apiKeyName = "ApiKey-$feedName"
                $feedMap[$feedName] = [ordered]@{
                    FeedName   = $feedName
                    FeedType   = $pt.ProGetType
                    Tier       = $tier
                    Uri        = $feedUri
                    ApiKeyName = $apiKeyName
                }
            }
        }

        # Overlay any per-feed overrides from $global:settings if present.
        $proGetFeedCollectionKey = $global:configRootKeys['ProGetFeedCollectionConfigRootKey']
        if (-not [string]::IsNullOrWhiteSpace($proGetFeedCollectionKey) -and
            $null -ne $global:settings[$proGetFeedCollectionKey]) {
            $settingsFeedCollection = $global:settings[$proGetFeedCollectionKey]
            foreach ($feedName in $feedMap.Keys) {
                if ($settingsFeedCollection.ContainsKey($feedName)) {
                    $overrides = $settingsFeedCollection[$feedName]
                    if (-not [string]::IsNullOrWhiteSpace($overrides['Uri'])) {
                        $feedMap[$feedName]['Uri'] = $overrides['Uri']
                        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Overriding URI for feed '$feedName' from `$global:settings"
                    }
                    if (-not [string]::IsNullOrWhiteSpace($overrides['ApiKeyName'])) {
                        $feedMap[$feedName]['ApiKeyName'] = $overrides['ApiKeyName']
                        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Overriding ApiKeyName for feed '$feedName' from `$global:settings"
                    }
                }
            }
        }

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Prepared $($feedMap.Count) permanent feed entries for output"
    }

    process {
        # ── Guard: file already exists ────────────────────────────────────
        if ((Test-Path -Path $OutputPath) -and -not $Force) {
            $errorMessage = "Output file '$OutputPath' already exists. Use -Force to overwrite."
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
            throw $errorMessage
        }

        $targetMessage  = "machine-scope feed settings file '$OutputPath'"
        $actionMessage  = "Write $($feedMap.Count) permanent ProGet feed entries"

        if (-not $PSCmdlet.ShouldProcess($targetMessage, $actionMessage)) {
            return [PSCustomObject]@{
                OutputPath   = $OutputPath
                FeedsWritten = @($feedMap.Keys)
                Written      = $false
            }
        }

        # ── Ensure output directory exists ────────────────────────────────
        $outputDir = Split-Path -Parent $OutputPath
        if (-not (Test-Path -Path $outputDir)) {
            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Created directory '$outputDir'"
        }

        # ── Build .psd1 content ───────────────────────────────────────────
        $lines = [System.Collections.Generic.List[string]]::new()
        $lines.Add('# HostSettings.PackageRepositoryFeeds.psd1')
        $lines.Add('# Auto-generated by New-HostSettingsForPackageRepositoryFeeds.')
        $lines.Add("# Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
        $lines.Add('# Ten permanent ProGet feeds (reverted naming scheme).')
        $lines.Add('# DO NOT EDIT MANUALLY — re-run New-HostSettingsForPackageRepositoryFeeds to regenerate.')
        $lines.Add('')
        $lines.Add('@{')
        $lines.Add("    GeneratedAt = '$(Get-Date -Format 'o')'")
        $lines.Add("    FeedBaseUrl = '$FeedBaseUrl'")
        $lines.Add('    Feeds = @{')

        foreach ($feedName in $feedMap.Keys) {
            $entry = $feedMap[$feedName]
            $lines.Add("        '$feedName' = @{")
            $lines.Add("            FeedName   = '$($entry.FeedName)'")
            $lines.Add("            FeedType   = '$($entry.FeedType)'")
            $lines.Add("            Tier       = '$($entry.Tier)'")
            $lines.Add("            Uri        = '$($entry.Uri)'")
            $lines.Add("            ApiKeyName = '$($entry.ApiKeyName)'")
            $lines.Add('        }')
        }

        $lines.Add('    }')
        $lines.Add('}')

        $psdContent = $lines -join [System.Environment]::NewLine

        try {
            Set-Content -Path $OutputPath -Value $psdContent -Encoding UTF8 -Force
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Wrote $($feedMap.Count) feed entries to '$OutputPath'"
        }
        catch {
            $errorMessage = "Failed to write '$OutputPath'. Exception: $($_.Exception.Message)"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
            throw
        }

        [PSCustomObject]@{
            OutputPath   = $OutputPath
            FeedsWritten = @($feedMap.Keys)
            Written      = $true
        }
    }

    end {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function complete'
    }
}
