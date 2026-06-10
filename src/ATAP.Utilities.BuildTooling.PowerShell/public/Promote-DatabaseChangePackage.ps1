#Requires -Version 7.0
<#
.SYNOPSIS
    Promotes a database change package from one ProGet database feed to the
    next tier in the 5-tier immutable pipeline.

.DESCRIPTION
    Promote-DatabaseChangePackage is the single entry point that BuildMaster
    plans and orchestrator scripts call to advance a database change package
    between environment tiers in the 5-tier ProGet database feed topology:

        database-experimental
          -> database-development
            -> database-integration
              -> database-qa
                -> database-stable

    The cmdlet:
        - Validates both -FromFeed and -ToFeed are canonical database feeds.
        - Enforces forward-only direction: -ToFeed must be one tier higher than
          -FromFeed. Reverse or skip-tier promotions are blocked with a
          clear error.
        - Optionally checks the version label against a per-application
          ceiling file (`Database/<App>/database-package-ceiling.json`) when
          -Application is supplied; blocks if the version's prerelease label
          exceeds the ceiling tier.
        - Resolves the API key from PROGET_BUILDMASTER_API_KEY first, then
          PROGET_ADMIN_API_KEY (User scope, per R-10).
        - Delegates the actual ProGet REST call to
          Move-ProGetPackageInterTier.
        - Returns a structured result with OperationName, Succeeded,
          package identity, feed names, and ResponseSummary.
        - -WhatIf short-circuits before invoking the inner cmdlet.

.PARAMETER PackageId
    The package ID (e.g. 'ATAPUtilities.Database').

.PARAMETER Version
    The exact version to promote (e.g. '1.0.0-experimental.42').

.PARAMETER FromFeed
    The source database feed (e.g. 'database-experimental').

.PARAMETER ToFeed
    The destination database feed (e.g. 'database-development').

.PARAMETER Reason
    A short human-readable reason recorded in ProGet's audit log.

.PARAMETER Application
    Optional. The application name used to locate a ceiling file at
    `Database/<Application>/database-package-ceiling.json` in the repo root.
    When supplied, the version label is checked against the ceiling before
    the promotion call is made.

.PARAMETER CeilingTier
    Promotion ceiling supplied by the caller (pipeline-level ceiling).
    If set, overrides the file-based ceiling check above.

.PARAMETER NoCeilingCheck
    Emergency/manual bypass for promotions that intentionally skip the
    ceiling policy. Mutually exclusive with -CeilingTier. Logged as a
    warning.

.OUTPUTS
    [PSCustomObject] with at least:
      - OperationName   : Always 'Promote-DatabaseChangePackage'.
      - Succeeded       : $true when the promotion completed or was a no-op.
      - PackageId       : The package ID (echoed input).
      - Version         : The package version (echoed input).
      - FromFeed        : Source feed (echoed input).
      - ToFeed          : Destination feed (echoed input).
      - CeilingTier     : Effective ceiling tier, or $null.
      - ResponseSummary : Short string summary of the operation.
      - InnerResult     : The full PSCustomObject returned by
                          Move-ProGetPackageInterTier, or $null on WhatIf.

.EXAMPLE
    Promote-DatabaseChangePackage `
        -PackageId 'ATAPUtilities.Database' `
        -Version '1.0.0-experimental.42' `
        -FromFeed 'database-experimental' `
        -ToFeed 'database-development' `
        -CeilingTier 'Development' `
        -Reason 'sprint-0007 database promotion'

.EXAMPLE
    Promote-DatabaseChangePackage `
        -PackageId 'ATAPUtilities.Database' `
        -Version '1.0.0-experimental.42' `
        -FromFeed 'database-development' `
        -ToFeed 'database-experimental' `
        -Reason 'wrong direction'
    # Throws: reverse promotion is blocked.

.NOTES
    AI assisted using Powershell.instructions.md as guidelines.
    Mirrors Promote-ProGetPackage.ps1 pattern for database feeds.
    DBA2-T02.

.LINK
    https://github.com/whertzing/ATAP.Utilities
#>

# Helper: resolve a tier ordinal from a database feed name.
# Throws if the feed name is not canonical.
function Resolve-DatabaseFeedTier {
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$FeedName
    )

    # Canonical ordered tier list for the database feed topology. Defined
    # function-local (not at script scope) so loading/dot-sourcing this file only
    # DEFINES functions and runs no top-level code.
    $dbFeedTierOrder = [ordered]@{
        'database-experimental' = 1
        'database-development'  = 2
        'database-integration'  = 3
        'database-qa'           = 4
        'database-stable'       = 5
    }

    if ($dbFeedTierOrder.Contains($FeedName)) {
        return $dbFeedTierOrder[$FeedName]
    }

    $valid = $dbFeedTierOrder.Keys -join ', '
    throw "Feed '$FeedName' is not a canonical database feed. Valid names: $valid."
}

function Promote-DatabaseChangePackage {
    [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'WithCeiling')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$PackageId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Version,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$FromFeed,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ToFeed,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Reason,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$Application,

        [Parameter(Mandatory, ParameterSetName = 'WithCeiling')]
        [ValidateNotNullOrEmpty()]
        [string]$CeilingTier,

        [Parameter(Mandatory, ParameterSetName = 'NoCeilingCheck')]
        [switch]$NoCeilingCheck
    )

    begin {
        $fn = 'Promote-DatabaseChangePackage'
        $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
            -Message "Entering $fn with PackageId='$PackageId' Version='$Version' FromFeed='$FromFeed' ToFeed='$ToFeed'" `
            -Tag 'Trace'
    }

    process {
        # 1. Validate that both feeds are canonical database feeds.
        $fromTier = Resolve-DatabaseFeedTier -FeedName $FromFeed  # throws on invalid
        $toTier   = Resolve-DatabaseFeedTier -FeedName $ToFeed

        # 2. Enforce forward-only direction (exactly one tier at a time).
        if ($toTier -le $fromTier) {
            $msg = "Reverse or same-tier promotion is not allowed: '$FromFeed' (tier $fromTier) -> '$ToFeed' (tier $toTier). Database packages must move toward 'database-stable'."
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
            throw $msg
        }
        if (($toTier - $fromTier) -ne 1) {
            $msg = "Skip-tier promotion is not allowed: '$FromFeed' (tier $fromTier) -> '$ToFeed' (tier $toTier). Each promotion must advance exactly one tier."
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
            throw $msg
        }

        # 3. Determine effective ceiling tier.
        $effectiveCeiling = $null
        if ($PSCmdlet.ParameterSetName -eq 'NoCeilingCheck') {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning `
                -Message "Promotion ceiling check bypassed (-NoCeilingCheck) for '$PackageId' '$Version' from '$FromFeed' to '$ToFeed'." `
                -Tag 'CeilingBypass'
        } else {
            # 3a. File-based ceiling check from Database/<App>/database-package-ceiling.json.
            if (-not [string]::IsNullOrWhiteSpace($Application)) {
                $repoRoot      = $PSScriptRoot
                # Walk up to the repo root (up from public/ -> module/ -> src/ -> repo).
                for ($i = 0; $i -lt 4; $i++) { $repoRoot = Split-Path $repoRoot -Parent }
                $ceilingFile   = Join-Path $repoRoot "Database/$Application/database-package-ceiling.json"
                if (Test-Path -LiteralPath $ceilingFile -PathType Leaf) {
                    $ceilingData = Get-Content -LiteralPath $ceilingFile -Raw | ConvertFrom-Json
                    if ($null -ne $ceilingData.ceiling) {
                        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
                            -Message "File-based ceiling for '$Application': '$($ceilingData.ceiling)'"
                        # Override explicit -CeilingTier with the file value if more restrictive.
                        if ([string]::IsNullOrWhiteSpace($CeilingTier)) {
                            $effectiveCeiling = $ceilingData.ceiling
                        } else {
                            # The lower of the two ceilings wins.
                            $fileTierOrd   = Resolve-DatabaseFeedTier -FeedName "database-$($ceilingData.ceiling.ToLowerInvariant())"
                            $callerTierOrd = Resolve-DatabaseFeedTier -FeedName "database-$($CeilingTier.ToLowerInvariant())"
                            $effectiveCeiling = if ($fileTierOrd -le $callerTierOrd) { $ceilingData.ceiling } else { $CeilingTier }
                        }
                    }
                }
            }
            if ($null -eq $effectiveCeiling) {
                $effectiveCeiling = $CeilingTier
            }

            # 3b. Ceiling-tier check via shared Test-PromotionWithinCeiling.
            if (-not [string]::IsNullOrWhiteSpace($effectiveCeiling)) {
                if (-not (Get-Command -Name 'Test-PromotionWithinCeiling' -CommandType Function -ErrorAction SilentlyContinue)) {
                    $ceilingPath = Join-Path $PSScriptRoot 'Test-PromotionWithinCeiling.ps1'
                    if (Test-Path -LiteralPath $ceilingPath -PathType Leaf) { . $ceilingPath }
                    else { throw "Required helper Test-PromotionWithinCeiling not found at '$ceilingPath'." }
                }
                # Convert database-<tier> suffix to a tier name Test-PromotionWithinCeiling understands.
                $destinationTierName = (Get-Culture).TextInfo.ToTitleCase(($ToFeed -replace '^database-', ''))
                Test-PromotionWithinCeiling -CurrentTier $destinationTierName -CeilingTier $effectiveCeiling -ErrorAction Stop | Out-Null
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
                    -Message "Database promotion ceiling accepted: destination tier '$destinationTierName' within ceiling '$effectiveCeiling'"
            }
        }

        # 4. WhatIf short-circuit.
        $target = "$PackageId $Version"
        $action = "Promote from '$FromFeed' to '$ToFeed'"
        if (-not $PSCmdlet.ShouldProcess($target, $action)) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
                -Message "WhatIf: would promote $target from '$FromFeed' to '$ToFeed' (reason: $Reason)"
            return [PSCustomObject]@{
                OperationName   = 'Promote-DatabaseChangePackage'
                Succeeded       = $true
                PackageId       = $PackageId
                Version         = $Version
                FromFeed        = $FromFeed
                ToFeed          = $ToFeed
                CeilingTier     = $effectiveCeiling
                ResponseSummary = "WhatIf: would promote $target from '$FromFeed' to '$ToFeed'"
                InnerResult     = $null
            }
        }

        # 5. Resolve API key (User scope, R-10).
        $apiKey = [System.Environment]::GetEnvironmentVariable('PROGET_BUILDMASTER_API_KEY', 'User')
        if ([string]::IsNullOrWhiteSpace($apiKey)) {
            $apiKey = [System.Environment]::GetEnvironmentVariable('PROGET_ADMIN_API_KEY', 'User')
        }
        if ([string]::IsNullOrWhiteSpace($apiKey)) {
            $msg = "Cannot resolve ProGet API key. Set PROGET_BUILDMASTER_API_KEY or PROGET_ADMIN_API_KEY in User-scope environment variables."
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
            throw $msg
        }

        # 6. Delegate to Move-ProGetPackageInterTier.
        if (-not (Get-Command -Name 'Move-ProGetPackageInterTier' -CommandType Function -ErrorAction SilentlyContinue)) {
            $innerPath = Join-Path $PSScriptRoot 'Move-ProGetPackageInterTier.ps1'
            if (Test-Path -LiteralPath $innerPath -PathType Leaf) { . $innerPath }
            else { throw "Required cmdlet Move-ProGetPackageInterTier not found at '$innerPath'." }
        }

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
            -Message "Promoting '$PackageId' '$Version' from '$FromFeed' to '$ToFeed' (reason: $Reason)"

        $innerResult = Move-ProGetPackageInterTier `
            -Name      $PackageId `
            -Version   $Version `
            -FromFeed  $FromFeed `
            -ToFeed    $ToFeed `
            -Reason    $Reason

        # Detect no-op (package already in destination).
        $succeeded = $innerResult.Succeeded -or ($innerResult.ResponseSummary -match 'already')
        $summary   = if ($succeeded) {
            "Promoted '$PackageId' '$Version' from '$FromFeed' to '$ToFeed' successfully."
        } else {
            "Promotion failed: $($innerResult.ResponseSummary)"
        }

        if (-not $succeeded) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $summary
        } else {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message $summary
        }

        return [PSCustomObject]@{
            OperationName   = 'Promote-DatabaseChangePackage'
            Succeeded       = $succeeded
            PackageId       = $PackageId
            Version         = $Version
            FromFeed        = $FromFeed
            ToFeed          = $ToFeed
            CeilingTier     = $effectiveCeiling
            ResponseSummary = $summary
            InnerResult     = $innerResult
        }
    }
}
