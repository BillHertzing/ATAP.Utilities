#Requires -Version 7.0
<#
.SYNOPSIS
    Publishes a pre-built database-change-package .nupkg to a ProGet
    database feed via `dotnet nuget push`. Idempotent: always passes
    --skip-duplicate.

.DESCRIPTION
    Publish-DatabaseChangePackageToProGet is the single source of truth for
    pushing a database change package into the immutable 5-tier ProGet
    database feed topology.

    The cmdlet:
        - Takes a pre-built .nupkg path (FileInfo or string).
        - Validates the target feed is one of the five canonical
          database-feed names:
              database-experimental  (default)
              database-development
              database-integration
              database-qa
              database-stable
        - Resolves the ProGet base URL from $global:settings via
          Resolve-ProGetFeedFromSettings (same key as the NuGet cmdlets,
          different feed-type query).
        - Resolves the API key from PROGET_BUILDMASTER_API_KEY first, then
          falls back to PROGET_ADMIN_API_KEY, both at User scope per R-10.
        - Invokes `dotnet nuget push` with --skip-duplicate (idempotent).
        - Wraps the dotnet call in a private helper
          Invoke-DotnetDatabaseNuGetPush so the call can be mocked in
          Pester without spawning a real process.
        - Masks the API key value in every log line (logged only as '***').
        - -WhatIf short-circuits before invoking dotnet.

.PARAMETER NupkgPath
    Absolute or relative path to the .nupkg file to push. Must exist and
    have a .nupkg extension.

.PARAMETER Feed
    The ProGet database feed name to push to. Must be one of:
      database-experimental (default), database-development,
      database-integration, database-qa, database-stable.

.PARAMETER CeilingTier
    Promotion ceiling for direct publishes to feeds above Experimental.
    When -Feed targets Development or higher, this cmdlet calls
    Test-PromotionWithinCeiling before invoking dotnet.

.PARAMETER Force
    Emergency/manual bypass for direct publishes to feeds above Experimental
    without a ceiling check. Intended for disaster-recovery only. Logged as
    a warning.

.OUTPUTS
    [PSCustomObject] with at least:
      - NupkgPath        : Absolute path to the .nupkg.
      - FeedName         : Feed name pushed to.
      - FeedUri          : Resolved feed URI.
      - Published        : $true when `dotnet nuget push` exited 0.
      - CeilingTier      : Optional promotion ceiling supplied by caller.
      - ResponseSummary  : Short string summary of the push result.

.EXAMPLE
    Publish-DatabaseChangePackageToProGet `
        -NupkgPath './out/ATAPUtilities.Database.1.0.0-Sprint042.nupkg'

.EXAMPLE
    Publish-DatabaseChangePackageToProGet `
        -NupkgPath ./out/X.nupkg `
        -Feed 'database-development' `
        -CeilingTier 'Development' `
        -WhatIf

.NOTES
    AI assisted using Powershell.instructions.md as guidelines.
    Mirrors Publish-NuGetPackageToProGet.ps1 pattern for database feeds.
    DBA2-T02.

.LINK
    https://github.com/whertzing/ATAP.Utilities
#>

# Private helper to wrap the actual `dotnet nuget push` invocation.
# Pester tests Mock this function so they never spawn a real process.
# Not exported; dot-sourced into the same scope as the public cmdlet.
function Invoke-DotnetDatabaseNuGetPush {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)][string]$NupkgPath,
        [Parameter(Mandatory)][string]$FeedUri,
        [Parameter(Mandatory)][string]$ApiKey
    )

    $fn = 'Invoke-DotnetDatabaseNuGetPush'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'

    $pushArgs = @(
        'nuget', 'push', $NupkgPath,
        '--source', $FeedUri,
        '--api-key', $ApiKey,
        '--skip-duplicate'
    )

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
        -Message "Invoking: dotnet nuget push '$NupkgPath' --source '$FeedUri' --api-key '***' --skip-duplicate" `
        -Tag 'RestCall'

    $stdout = & dotnet @pushArgs 2>&1
    $exit   = $LASTEXITCODE

    return [PSCustomObject]@{
        ExitCode = $exit
        StdOut   = ($stdout -join [Environment]::NewLine)
    }
}

function Publish-DatabaseChangePackageToProGet {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$NupkgPath,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$Feed = 'database-experimental',

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$CeilingTier,

        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    begin {
        $fn = 'Publish-DatabaseChangePackageToProGet'
        $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
            -Message "Entering $fn with NupkgPath='$NupkgPath' Feed='$Feed'" `
            -Tag 'Trace'

        # Canonical set of valid database feed names for the 5-tier topology.
        # Defined function-local (not at script scope) so loading/dot-sourcing this
        # file only DEFINES functions and runs no top-level code.
        $databaseFeedNames = @(
            'database-experimental',
            'database-development',
            'database-integration',
            'database-qa',
            'database-stable'
        )
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
        $resolvedNupkg = (Resolve-Path -LiteralPath $NupkgPath).ProviderPath

        # 2. Validate feed name against the canonical database feed list.
        if ($Feed -notin $databaseFeedNames) {
            $msg = "Feed '$Feed' is not a canonical database feed. Valid names: $($databaseFeedNames -join ', ')."
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
            throw $msg
        }

        # 3. Parse the tier suffix from the feed name.
        $tierSuffix = $Feed -replace '^database-', ''  # e.g. 'experimental'

        # 4. Load Resolve-ProGetFeedFromSettings helper if not already loaded.
        $helperPath = Join-Path $PSScriptRoot '..\private\Resolve-ProGetFeedFromSettings.ps1'
        if (-not (Get-Command -Name 'Resolve-ProGetFeedFromSettings' -CommandType Function -ErrorAction SilentlyContinue)) {
            if (Test-Path -LiteralPath $helperPath -PathType Leaf) {
                . $helperPath
            } else {
                # Fallback: derive URI from $global:settings directly if helper not found.
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
                    -Message "Resolve-ProGetFeedFromSettings not found; will resolve base URL from settings directly."
            }
        }

        # Resolve feed URI. Database feeds use the same NuGet protocol as nuget-*
        # feeds because the packages are .nupkg artifacts.
        if (Get-Command -Name 'Resolve-ProGetFeedFromSettings' -CommandType Function -ErrorAction SilentlyContinue) {
            $feedInfo = Resolve-ProGetFeedFromSettings -FeedType 'database' -Tier $tierSuffix
            $feedName = $feedInfo.FeedName
            $feedUri  = $feedInfo.EndpointUri
        } else {
            # Emergency fallback: construct URI from global settings base URL.
            $progetBase = $global:settings[$global:configRootKeys['ProGetBaseUrlConfigRootKey']]
            if ([string]::IsNullOrWhiteSpace($progetBase)) {
                throw "Cannot resolve ProGet base URL from global settings key 'ProGetBaseUrlConfigRootKey'."
            }
            $feedName = $Feed
            $feedUri  = "$($progetBase.TrimEnd('/'))/nuget/$Feed"
        }
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
            -Message "Resolved database feed '$feedName' at '$feedUri'"

        # 5. Ceiling check for non-Experimental direct publishes.
        $tierPascal = (Get-Culture).TextInfo.ToTitleCase($tierSuffix)
        if ($tierPascal -ne 'Experimental') {
            if ($Force) {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning `
                    -Message "Promotion ceiling check bypassed (-Force) for direct database publish to '$feedName'." `
                    -Tag 'CeilingBypass'
            } else {
                if ([string]::IsNullOrWhiteSpace($CeilingTier)) {
                    $msg = "CeilingTier is required when publishing directly to feed '$feedName'. Use -Force only for an audited emergency/manual bypass."
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
                    throw $msg
                }
                if (-not (Get-Command -Name 'Test-PromotionWithinCeiling' -CommandType Function -ErrorAction SilentlyContinue)) {
                    $ceilingPath = Join-Path $PSScriptRoot 'Test-PromotionWithinCeiling.ps1'
                    if (Test-Path -LiteralPath $ceilingPath -PathType Leaf) { . $ceilingPath }
                    else { throw "Required helper Test-PromotionWithinCeiling not found at '$ceilingPath'." }
                }
                Test-PromotionWithinCeiling -CurrentTier $tierPascal -CeilingTier $CeilingTier -ErrorAction Stop | Out-Null
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
                    -Message "Database ceiling accepted: destination tier '$tierPascal' is within ceiling '$CeilingTier'"
            }
        }

        # 6. Resolve API key: PROGET_BUILDMASTER_API_KEY first, then PROGET_ADMIN_API_KEY (User scope).
        $apiKey = [System.Environment]::GetEnvironmentVariable('PROGET_BUILDMASTER_API_KEY', 'User')
        if ([string]::IsNullOrWhiteSpace($apiKey)) {
            $apiKey = [System.Environment]::GetEnvironmentVariable('PROGET_ADMIN_API_KEY', 'User')
        }
        if ([string]::IsNullOrWhiteSpace($apiKey)) {
            $msg = "Cannot resolve ProGet API key. Set PROGET_BUILDMASTER_API_KEY or PROGET_ADMIN_API_KEY in User-scope environment variables."
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
            throw $msg
        }

        # 7. WhatIf short-circuit before invoking dotnet.
        $target = [System.IO.Path]::GetFileName($resolvedNupkg)
        $action = "Push '$target' to database feed '$feedName'"
        if (-not $PSCmdlet.ShouldProcess($target, $action)) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
                -Message "WhatIf: would push '$target' to '$feedUri'"
            return [PSCustomObject]@{
                NupkgPath       = $resolvedNupkg
                FeedName        = $feedName
                FeedUri         = $feedUri
                Published       = $true
                CeilingTier     = $CeilingTier
                ResponseSummary = "WhatIf: would push '$target' to '$feedUri'"
            }
        }

        # 8. Invoke the push helper.
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
            -Message "Pushing '$target' to database feed '$feedName' at '$feedUri'"
        $pushResult = Invoke-DotnetDatabaseNuGetPush -NupkgPath $resolvedNupkg -FeedUri $feedUri -ApiKey $apiKey

        $published = ($pushResult.ExitCode -eq 0)
        $summary   = if ($published) { "Pushed successfully to '$feedName'" } else { "Push failed (exit $($pushResult.ExitCode)): $($pushResult.StdOut)" }

        if (-not $published) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $summary
        } else {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message $summary
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
}
