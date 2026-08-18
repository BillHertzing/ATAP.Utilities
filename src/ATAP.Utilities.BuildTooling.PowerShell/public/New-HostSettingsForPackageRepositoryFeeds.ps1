#Requires -Version 7.0
<#
.SYNOPSIS
    Writes a machine-scope settings file recording all known feed → URL → API-key
    mappings for the ten permanent ProGet feeds.

.DESCRIPTION
    Generates (or overwrites) a machine-scope PowerShell data file that records
    every permanent ProGet feed name, its URI, and its API-key SecretName.
    Feed metadata is resolved from `$global:Settings`; the
    generated file is a compatibility export for automation that cannot load
    the full host settings session.

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
    loaded, the caller must pass an explicit value via -FeedBaseUrl.

    The output file is a `.psd1` hashtable understood by `Import-PowerShellDataFile`.

.PARAMETER OutputPath
    Path to the machine-scope settings file to write. Defaults to:
        $env:ProgramData\ATAP\HostSettings.PackageRepositoryFeeds.psd1
    The parent directory is created automatically if absent.

.PARAMETER FeedBaseUrl
    Override the ProGet base URL (scheme + host + port, e.g.
    'http://proget-host:50000'). If omitted, resolved from
    `$global:settings[$global:configRootKeys['ProGetBaseUrlConfigRootKey']]`.

.PARAMETER ProGetApiKeySecretName
    Bitwarden Secrets Manager SecretName recorded for all feeds. The cmdlet
    never resolves or persists the secret value.

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
    # Write using $global:settings and the canonical SecretName:
    New-HostSettingsForPackageRepositoryFeeds

.EXAMPLE
    # Explicit values (useful in a BuildMaster agent shell with no profile).
    # This function RECORDS the SecretName into the generated host-settings file,
    # so it must be the host-suffixed vault name, not the bare base name (SC-0288).
    # With no profile loaded there is no ServicePlacementMap for
    # Resolve-HostSuffixedSecretName to derive from, so pass the suffixed name —
    # e.g. from the BuildMaster $ProGetApiKeySecretName application variable.
    # Recording a suffixless name here is the original SC-0288 defect.
    New-HostSettingsForPackageRepositoryFeeds `
        -FeedBaseUrl 'http://proget.corp:50000' `
        -ProGetApiKeySecretName $proGetApiKeySecretName `
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
        [ValidateNotNullOrEmpty()]
        [string]$ProGetApiKeySecretName = 'ProGet.BuildMaster.API.Key',

        [switch]$Force
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
        $mn = $MyInvocation.MyCommand.ModuleName
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

        # ── OutputPath ────────────────────────────────────────────────────
        if ([string]::IsNullOrWhiteSpace($OutputPath)) {
            $OutputPath = Join-Path $env:ProgramData 'ATAP' 'HostSettings.PackageRepositoryFeeds.psd1'
        }
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "OutputPath is '$OutputPath'"

        # ── FeedBaseUrl ───────────────────────────────────────────────────
        if ([string]::IsNullOrWhiteSpace($FeedBaseUrl)) {
            $FeedBaseUrl = $global:settings[$global:configRootKeys['ProGetBaseUrlConfigRootKey']]
        }
        if ([string]::IsNullOrWhiteSpace($FeedBaseUrl)) {
            $errorMessage = "FeedBaseUrl could not be resolved. Pass it explicitly or ensure `$global:settings is loaded with 'ProGetBaseUrlConfigRootKey'."
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
            throw $errorMessage
        }
        $FeedBaseUrl = $FeedBaseUrl.TrimEnd('/')
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "FeedBaseUrl is '$FeedBaseUrl'"

        # ── Permanent feed definitions ─────────────────────────────────
        # Ten permanent feeds: five NuGet + five PowerShellGet, one per tier.
        # Ordered from lowest to highest tier (matches the inter-tier promotion chain).
        $tierOrder = @('experimental', 'development', 'integration', 'qa', 'stable')
        $packageTypes = @(
            @{ Prefix = 'nuget';         ProGetType = 'nuget';         FeedUrlSegment = 'nuget'     }
            @{ Prefix = 'powershellget'; ProGetType = 'powershellget'; FeedUrlSegment = 'nuget'     }
        )

        # Build the canonical feed list. Keys are feed names; values are hashtables
        # with Uri, ApiKeySecretName, FeedType, and Tier.
        $feedMap = [ordered]@{}
        foreach ($pt in $packageTypes) {
            foreach ($tier in $tierOrder) {
                $feedName   = "$($pt.Prefix)-$tier"
                $feedUri    = "$FeedBaseUrl/$($pt.FeedUrlSegment)/$feedName/"
                $feedMap[$feedName] = [ordered]@{
                    FeedName   = $feedName
                    FeedType   = $pt.ProGetType
                    Tier       = $tier
                    Uri        = $feedUri
                    ApiKeySecretName = $ProGetApiKeySecretName
                }
            }
        }

        # Overlay any per-feed overrides from $global:settings if present.
        $proGetFeedCollectionKey = $global:configRootKeys['ProGetFeedCollectionConfigRootKey']
        if (-not [string]::IsNullOrWhiteSpace($proGetFeedCollectionKey) -and
            $null -ne $global:settings[$proGetFeedCollectionKey]) {
            $settingsFeedCollection = $global:settings[$proGetFeedCollectionKey]
            foreach ($settingsFeedKey in $settingsFeedCollection.Keys) {
                $overrides = $settingsFeedCollection[$settingsFeedKey]
                $feedName = if ($overrides -is [System.Collections.IDictionary]) {
                    $overrides['FeedName']
                } else {
                    $overrides.FeedName
                }
                if (-not [string]::IsNullOrWhiteSpace($feedName) -and $feedMap.Contains($feedName)) {
                    $settingsUri = if ($overrides -is [System.Collections.IDictionary]) { $overrides['NuGetV3Uri'] } else { $overrides.NuGetV3Uri }
                    if ([string]::IsNullOrWhiteSpace([string]$settingsUri)) {
                        $settingsUri = if ($overrides -is [System.Collections.IDictionary]) { $overrides['Uri'] } else { $overrides.Uri }
                    }
                    $settingsApiKeySecretName = if ($overrides -is [System.Collections.IDictionary]) { $overrides['ApiKeySecretName'] } else { $overrides.ApiKeySecretName }
                    if (-not [string]::IsNullOrWhiteSpace([string]$settingsUri)) {
                        $feedMap[$feedName]['Uri'] = [string]$settingsUri
                        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Overriding URI for feed '$feedName' from `$global:settings"
                    }
                    if (-not [string]::IsNullOrWhiteSpace([string]$settingsApiKeySecretName)) {
                        $feedMap[$feedName]['ApiKeySecretName'] = [string]$settingsApiKeySecretName
                        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Overriding ApiKeySecretName for feed '$feedName' from `$global:settings"
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
            $lines.Add("            ApiKeySecretName = '$($entry.ApiKeySecretName)'")
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
