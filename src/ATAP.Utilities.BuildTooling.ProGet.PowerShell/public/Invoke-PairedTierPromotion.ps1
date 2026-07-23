#Requires -Version 7.0
<#
.SYNOPSIS
    Promotes a PowerShell module release and a database change package into the
    same tier together, then runs an escalating per-tier validation suite,
    so the module version and the database-data version advance in lock-step.

.DESCRIPTION
    Invoke-PairedTierPromotion is the Stream-DB orchestrator (Task 9.13) that
    pairs the two halves of a tier promotion that must move together:

        1. The RulesManagement (or any) PowerShell module release, advanced one
           tier in the 5-tier powershellget feed ladder via Promote-ProGetPackage.
        2. The database change package that carries the rules-table / AgentText
           data, advanced one tier in the parallel database-* feed ladder via
           Promote-DatabaseChangePackage.

    The two promotions are coupled so a tier can never end up with a newer module
    than its database data (or vice versa):

        * The module is promoted first. If that promotion fails, the database
          package is NOT promoted, so the database never gets ahead of the module.
        * The database package is promoted only after the module promotion
          succeeded. If the database promotion then fails, the result reports
          PairedAdvance = $false with remediation (the module is one tier ahead;
          both promotions are idempotent, so re-running after the fix is safe).
        * Validation runs only once BOTH halves reached the destination tier.

    Escalating per-tier validation. Higher tiers run a superset of the suites run
    at lower tiers (see Get-PairedTierValidationPlan):

        Development : VersionAlignment, PromotedModuleTests
        Integration : + DatabaseDataPresence
        QA          : + AgentTextRoundTrip
        Production   : all of the above

    Each suite reports Passed / Failed / Skipped. A suite whose inputs are not
    supplied (e.g. no -DatabaseConnectionString for the database-data suites) is
    Skipped, not Failed - mirroring the backward-compatible "no secret -> skip"
    policy in Invoke-DatabasePackageBuildMasterStage. Overall validation passes
    when no applicable suite Failed. Rehearsal-before-promotion of the database
    package remains the responsibility of Invoke-DatabasePackageBuildMasterStage
    (Task 9.10); this cmdlet sits above it and confirms the paired advance.

    -WhatIf short-circuits before any promotion or validation. The returned object
    still carries the resolved promotion plan so callers can inspect it.

.PARAMETER ModuleName
    The module package id to promote, e.g.
    'ATAP.Utilities.RulesManagement.PowerShell'. Defaults to RulesManagement,
    the module this pairing was built for.

.PARAMETER ModuleVersion
    The exact module version to promote, e.g. '0.1.4'.

.PARAMETER DatabasePackageId
    The database change package id, e.g. 'ATAPUtilities.Database'.

.PARAMETER DatabasePackageVersion
    The exact database change package version to promote.

.PARAMETER Tier
    The destination tier to promote BOTH artifacts INTO. One of Development,
    Integration, QA, Production. (Experimental is the build tier, not a paired
    promotion destination.) The source tier is the immediately preceding tier.

.PARAMETER ModuleFeedPrefix
    Feed-name prefix for the module ladder. Defaults to 'powershellget'
    (feeds powershellget-experimental .. powershellget-stable).

.PARAMETER DatabaseFeedPrefix
    Feed-name prefix for the database ladder. Defaults to 'database'
    (feeds database-experimental .. database-stable).

.PARAMETER DatabaseApplication
    The database application used by Promote-DatabaseChangePackage for the
    file-based ceiling lookup. Defaults to 'ATAPUtilities'.

.PARAMETER CeilingTier
    Highest tier this run may reach. Forwarded to both Promote-ProGetPackage and
    Promote-DatabaseChangePackage. Defaults to 'Production'.

.PARAMETER ModuleSourceRoot
    Optional source-tree module folder containing the tests/ directory, forwarded
    to Invoke-PromotedModuleTests. Defaults inside that cmdlet to src/<ModuleName>.

.PARAMETER ResultsPath
    Directory the PromotedModuleTests results are written to. Defaults to
    _generated/PairedTierPromotion/<Tier> under -WorkingDirectory.

.PARAMETER ProGetBaseUrl
    Optional ProGet base URL forwarded to Invoke-PromotedModuleTests so the
    promoted module is restored from ProGet's direct package endpoint
    (/nuget/<feed>/package/<name>/<version>) instead of PSResourceGet's OData
    query path. Supply this when the feed's v2 OData FindPackagesById endpoint
    is unavailable (the documented Sprint-0009 ProGet 404). Resolve it from
    $global:settings / Resolve-ProGetBaseUrlFromSettings at the call site.

.PARAMETER ProGetApiKeySecretName
    Bitwarden Secrets Manager SecretName forwarded to each ProGet leaf cmdlet.
    Raw API-key values and environment-variable fallbacks are unsupported.

.PARAMETER WorkingDirectory
    Directory paths are resolved against. Defaults to the current location.

.PARAMETER DatabaseConnectionString
    Optional SQL connection string for the destination tier's ATAPUtilities
    database. When supplied, the database-data validation suites
    (DatabaseDataPresence at Integration+, AgentTextRoundTrip at QA+) run; when
    absent they are Skipped. Resolve the value from Bitwarden (Get-SecretATAP) at
    the call site; never embed a literal credential.

.PARAMETER AgentTextSourceId
    The AgentText manifest SourceId checked by the database-data suites. Defaults
    to 'ai.agent.claude.version-control-commit.v1' (the canonical round-trip
    sentinel from Tasks 9.11/9.12).

.PARAMETER Reason
    Human-readable reason recorded in ProGet's audit log for both promotions.
    Defaults to "Paired tier promotion to <Tier>".

.PARAMETER SkipValidation
    Audited bypass: skip every validation suite (each recorded Skipped). The
    promotions still run. Logged as a warning.

.PARAMETER SkipModuleTests
    Skip only the PromotedModuleTests suite (e.g. when the module's promoted-tier
    Pester run is owned by the BuildMaster pipeline). The database-data suites
    still run when their inputs are present.

.OUTPUTS
    [PSCustomObject] with at least:
      - OperationName          : Always 'Invoke-PairedTierPromotion'.
      - Succeeded              : $true when both promotions advanced and all
                                 applicable validation suites passed.
      - PairedAdvance          : $true when BOTH the module and the database
                                 package reached the destination tier.
      - Tier                   : Destination tier (echoed).
      - ModuleName / ModuleVersion / ModuleFromFeed / ModuleToFeed
      - DatabasePackageId / DatabasePackageVersion / DatabaseFromFeed / DatabaseToFeed
      - ModulePromotion        : Promote-ProGetPackage result (or $null).
      - DatabasePromotion      : Promote-DatabaseChangePackage result (or $null).
      - ValidationPlan         : Suite names that applied at this tier.
      - Validations            : Array of @{ Name; Status; Detail }.
      - ValidationPassed       : $true when no applicable suite Failed.
      - ResponseSummary        : Short human-readable summary.

.EXAMPLE
    Invoke-PairedTierPromotion `
        -ModuleVersion '0.1.4' `
        -DatabasePackageId 'ATAPUtilities.Database' `
        -DatabasePackageVersion '00.02.000040' `
        -Tier 'Development'

    Promotes RulesManagement 0.1.4 and the database package to Development,
    then runs VersionAlignment + PromotedModuleTests.

.EXAMPLE
    Invoke-PairedTierPromotion -ModuleVersion '0.1.4' `
        -DatabasePackageVersion '00.02.000040' -Tier 'QA' `
        -DatabaseConnectionString $cs -WhatIf

    Returns the planned paired promotion (module + database to QA, with the QA
    validation plan) without calling any promotion or validation cmdlet.

.NOTES
    AI assisted using Powershell.instructions.md as guidelines.
    Stream DB Task 9.13. Pairs Promote-ProGetPackage (module) with
    Promote-DatabaseChangePackage (database) and escalating per-tier validation.

.LINK
    https://github.com/whertzing/ATAP.Utilities
#>

# Helper: resolve a tier ordinal in the canonical 5-tier order. Defined at file
# scope (function definition only, no top-level execution) so importing this file
# DEFINES functions and runs nothing.
function Get-PairedTierIndex {
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Tier
    )

    begin {
        $tierOrder = @('Experimental', 'Development', 'Integration', 'QA', 'Production')
    }

    process {
        $index = $tierOrder.IndexOf($Tier)
        if ($index -lt 0) {
            throw "Tier '$Tier' is not one of: $($tierOrder -join ', ')."
        }
        return $index
    }
}
# Helper: resolve the canonical feed name for a tier given a ladder prefix.
# Production maps to the '-stable' feed for both ladders (powershellget-stable,
# database-stable); the other tiers use the lowercased tier name.
function Resolve-PairedTierFeedName {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Prefix,
        [Parameter(Mandatory)]
        [ValidateSet('Experimental', 'Development', 'Integration', 'QA', 'Production')]
        [string]$Tier
    )

    process {
        $suffix = switch ($Tier) {
            'Experimental' { 'experimental' }
            'Development'  { 'development' }
            'Integration'  { 'integration' }
            'QA'           { 'qa' }
            'Production'   { 'stable' }
        }
        return "$Prefix-$suffix"
    }
}

# Helper: ordered, escalating validation plan for a destination tier. Each suite
# carries the lowest tier at which it activates; the plan for a tier is every
# suite whose MinTier index is <= the destination tier index, in declaration
# order. Higher tiers therefore run a superset of lower tiers.
function Get-PairedTierValidationPlan {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Development', 'Integration', 'QA', 'Production')]
        [string]$Tier
    )

    begin {
        $suites = @(
            [PSCustomObject]@{ Name = 'VersionAlignment';     MinTier = 'Development' }
            [PSCustomObject]@{ Name = 'PromotedModuleTests';  MinTier = 'Development' }
            [PSCustomObject]@{ Name = 'DatabaseDataPresence'; MinTier = 'Integration' }
            [PSCustomObject]@{ Name = 'AgentTextRoundTrip';   MinTier = 'QA' }
        )
    }

    process {
        $tierIndex = Get-PairedTierIndex -Tier $Tier
        $plan = foreach ($suite in $suites) {
            if ((Get-PairedTierIndex -Tier $suite.MinTier) -le $tierIndex) {
                $suite.Name
            }
        }
        return [string[]]$plan
    }
}

function Invoke-PairedTierPromotion {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ModuleName = 'ATAP.Utilities.RulesManagement.PowerShell',

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ModuleVersion,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$DatabasePackageId = 'ATAPUtilities.Database',

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DatabasePackageVersion,

        [Parameter(Mandatory)]
        [ValidateSet('Development', 'Integration', 'QA', 'Production')]
        [string]$Tier,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ModuleFeedPrefix = 'powershellget',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$DatabaseFeedPrefix = 'database',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$DatabaseApplication = 'ATAPUtilities',

        [Parameter()]
        [ValidateSet('Experimental', 'Development', 'Integration', 'QA', 'Production')]
        [string]$CeilingTier = 'Production',

        [Parameter()]
        [string]$ModuleSourceRoot,

        [Parameter()]
        [string]$ResultsPath,

        [Parameter()]
        [AllowEmptyString()]
        [string]$ProGetBaseUrl = '',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ProGetApiKeySecretName = 'ProGet.BuildMaster.API.Key',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$WorkingDirectory = (Get-Location).Path,

        [Parameter()]
        [AllowEmptyString()]
        [string]$DatabaseConnectionString = '',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$AgentTextSourceId = 'ai.agent.claude.version-control-commit.v1',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Reason,

        [Parameter()]
        [switch]$SkipValidation,

        [Parameter()]
        [switch]$SkipModuleTests
    )

    begin {
        $fn = 'Invoke-PairedTierPromotion'
        $mn = 'ATAP.Utilities.BuildTooling.ProGet.PowerShell'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
            -Message "Entering $fn with ModuleName='$ModuleName' ModuleVersion='$ModuleVersion' DatabasePackageId='$DatabasePackageId' DatabasePackageVersion='$DatabasePackageVersion' Tier='$Tier'" `
            -Tag 'Trace'

        # Lazily load the sibling promotion cmdlets when running from source (in an
        # imported module they are already defined). Tests can stub these first.
        $siblingCmdlets = @('Promote-ProGetPackage', 'Promote-DatabaseChangePackage', 'Invoke-PromotedModuleTests')
        foreach ($cmd in $siblingCmdlets) {
            if (-not (Get-Command -Name $cmd -CommandType Function -ErrorAction SilentlyContinue)) {
                $siblingPath = Join-Path $PSScriptRoot "$cmd.ps1"
                if (Test-Path -LiteralPath $siblingPath -PathType Leaf) { . $siblingPath }
            }
        }
    }

    process {
        if ([string]::IsNullOrWhiteSpace($Reason)) {
            $Reason = "Paired tier promotion to $Tier"
        }

        $moduleFromFeed = Resolve-PairedTierFeedName -Prefix $ModuleFeedPrefix -Tier (Get-PairedPreviousTierName -Tier $Tier)
        $moduleToFeed = Resolve-PairedTierFeedName -Prefix $ModuleFeedPrefix -Tier $Tier
        $dbFromFeed = Resolve-PairedTierFeedName -Prefix $DatabaseFeedPrefix -Tier (Get-PairedPreviousTierName -Tier $Tier)
        $dbToFeed = Resolve-PairedTierFeedName -Prefix $DatabaseFeedPrefix -Tier $Tier

        $validationPlan = Get-PairedTierValidationPlan -Tier $Tier

        # ---- WhatIf short-circuit: report the plan, touch nothing ----
        $target = "$ModuleName $ModuleVersion + $DatabasePackageId $DatabasePackageVersion"
        $action = "Promote both to '$Tier' and run [$($validationPlan -join ', ')]"
        if (-not $PSCmdlet.ShouldProcess($target, $action)) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
                -Message "WhatIf: would $action"
            return [PSCustomObject]@{
                OperationName          = 'Invoke-PairedTierPromotion'
                Succeeded              = $true
                PairedAdvance          = $true
                Tier                   = $Tier
                ModuleName             = $ModuleName
                ModuleVersion          = $ModuleVersion
                ModuleFromFeed         = $moduleFromFeed
                ModuleToFeed           = $moduleToFeed
                DatabasePackageId      = $DatabasePackageId
                DatabasePackageVersion = $DatabasePackageVersion
                DatabaseFromFeed       = $dbFromFeed
                DatabaseToFeed         = $dbToFeed
                ModulePromotion        = $null
                DatabasePromotion      = $null
                ValidationPlan         = $validationPlan
                Validations            = @()
                ValidationPassed       = $true
                ResponseSummary        = "WhatIf: would $action"
            }
        }

        # ---- Step 1: promote the module (first, so the database never leads) ----
        $modulePromotion = $null
        $moduleSucceeded = $false
        try {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
                -Message "Promoting module '$ModuleName' '$ModuleVersion' from '$moduleFromFeed' to '$moduleToFeed'."
            $modulePromotion = Promote-ProGetPackage `
                -Name $ModuleName `
                -Version $ModuleVersion `
                -FromFeed $moduleFromFeed `
                -ToFeed $moduleToFeed `
                -Reason $Reason `
                -CeilingTier $CeilingTier `
                -ProGetApiKeySecretName $ProGetApiKeySecretName
            $moduleSucceeded = [bool]$modulePromotion.Succeeded
        } catch {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error `
                -Message "Module promotion threw for '$ModuleName' '$ModuleVersion': $($_.Exception.Message)"
            $moduleSucceeded = $false
        }

        if (-not $moduleSucceeded) {
            $summary = "Module promotion of '$ModuleName' '$ModuleVersion' to '$Tier' failed; database package '$DatabasePackageId' was NOT promoted (kept from leading the module). Fix the module promotion and re-run (idempotent)."
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $summary
            return [PSCustomObject]@{
                OperationName          = 'Invoke-PairedTierPromotion'
                Succeeded              = $false
                PairedAdvance          = $false
                Tier                   = $Tier
                ModuleName             = $ModuleName
                ModuleVersion          = $ModuleVersion
                ModuleFromFeed         = $moduleFromFeed
                ModuleToFeed           = $moduleToFeed
                DatabasePackageId      = $DatabasePackageId
                DatabasePackageVersion = $DatabasePackageVersion
                DatabaseFromFeed       = $dbFromFeed
                DatabaseToFeed         = $dbToFeed
                ModulePromotion        = $modulePromotion
                DatabasePromotion      = $null
                ValidationPlan         = $validationPlan
                Validations            = @()
                ValidationPassed       = $false
                ResponseSummary        = $summary
            }
        }

        # ---- Step 2: promote the database change package ----
        $databasePromotion = $null
        $databaseSucceeded = $false
        try {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
                -Message "Promoting database package '$DatabasePackageId' '$DatabasePackageVersion' from '$dbFromFeed' to '$dbToFeed'."
            $databasePromotion = Promote-DatabaseChangePackage `
                -PackageId $DatabasePackageId `
                -Version $DatabasePackageVersion `
                -FromFeed $dbFromFeed `
                -ToFeed $dbToFeed `
                -Reason $Reason `
                -Application $DatabaseApplication `
                -CeilingTier $CeilingTier `
                -ProGetApiKeySecretName $ProGetApiKeySecretName
            $databaseSucceeded = [bool]$databasePromotion.Succeeded
        } catch {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error `
                -Message "Database promotion threw for '$DatabasePackageId' '$DatabasePackageVersion': $($_.Exception.Message)"
            $databaseSucceeded = $false
        }

        $pairedAdvance = $moduleSucceeded -and $databaseSucceeded

        if (-not $pairedAdvance) {
            $summary = "PARTIAL ADVANCE: module '$ModuleName' '$ModuleVersion' reached '$Tier' but database package '$DatabasePackageId' '$DatabasePackageVersion' did not. Tier now has a module ahead of its data; re-run after fixing the database promotion (both promotions are idempotent)."
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $summary
            return [PSCustomObject]@{
                OperationName          = 'Invoke-PairedTierPromotion'
                Succeeded              = $false
                PairedAdvance          = $false
                Tier                   = $Tier
                ModuleName             = $ModuleName
                ModuleVersion          = $ModuleVersion
                ModuleFromFeed         = $moduleFromFeed
                ModuleToFeed           = $moduleToFeed
                DatabasePackageId      = $DatabasePackageId
                DatabasePackageVersion = $DatabasePackageVersion
                DatabaseFromFeed       = $dbFromFeed
                DatabaseToFeed         = $dbToFeed
                ModulePromotion        = $modulePromotion
                DatabasePromotion      = $databasePromotion
                ValidationPlan         = $validationPlan
                Validations            = @()
                ValidationPassed       = $false
                ResponseSummary        = $summary
            }
        }

        # ---- Step 3: escalating per-tier validation (paired advance confirmed) ----
        $validations = [System.Collections.Generic.List[object]]::new()

        if ($SkipValidation) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning `
                -Message "Validation BYPASSED (-SkipValidation) for paired promotion to '$Tier'."
            foreach ($suiteName in $validationPlan) {
                $validations.Add([PSCustomObject]@{ Name = $suiteName; Status = 'Skipped'; Detail = '-SkipValidation supplied.' })
            }
        }
        else {
            if (-not $ResultsPath) {
                $ResultsPath = Join-Path $WorkingDirectory (Join-Path '_generated' (Join-Path 'PairedTierPromotion' $Tier))
            }

            foreach ($suiteName in $validationPlan) {
                $suiteResult = switch ($suiteName) {
                    'VersionAlignment' {
                        # Structural gate: both halves reached the same tier. This
                        # is the codified "module version and DB-data version
                        # advance together per tier" acceptance.
                        [PSCustomObject]@{
                            Name   = 'VersionAlignment'
                            Status = 'Passed'
                            Detail = "Module '$ModuleVersion' and database '$DatabasePackageVersion' advanced together to '$Tier'."
                        }
                    }
                    'PromotedModuleTests' {
                        if ($SkipModuleTests) {
                            [PSCustomObject]@{ Name = 'PromotedModuleTests'; Status = 'Skipped'; Detail = '-SkipModuleTests supplied.' }
                        }
                        else {
                            $moduleTestParameters = @{
                                Name        = $ModuleName
                                Version     = $ModuleVersion
                                Feed        = $moduleToFeed
                                Tier        = $Tier
                                ResultsPath = $ResultsPath
                                WorkingDirectory = $WorkingDirectory
                            }
                            if ($ModuleSourceRoot) { $moduleTestParameters['ModuleSourceRoot'] = $ModuleSourceRoot }
                            # Forward ProGet direct-endpoint inputs so the promoted-module
                            # restore bypasses the feed's v2 OData path (Sprint-0009 404).
                            if (-not [string]::IsNullOrWhiteSpace($ProGetBaseUrl)) { $moduleTestParameters['ProGetBaseUrl'] = $ProGetBaseUrl }
                            $moduleTestParameters['ProGetApiKeySecretName'] = $ProGetApiKeySecretName
                            try {
                                $testResult = Invoke-PromotedModuleTests @moduleTestParameters
                                $status = if ([bool]$testResult.GatePass) { 'Passed' } else { 'Failed' }
                                [PSCustomObject]@{
                                    Name   = 'PromotedModuleTests'
                                    Status = $status
                                    Detail = [string]$testResult.ResponseSummary
                                }
                            } catch {
                                [PSCustomObject]@{ Name = 'PromotedModuleTests'; Status = 'Failed'; Detail = $_.Exception.Message }
                            }
                        }
                    }
                    'DatabaseDataPresence' {
                        Test-PairedAgentTextSuite -SuiteName 'DatabaseDataPresence' `
                            -ConnectionString $DatabaseConnectionString -SourceId $AgentTextSourceId -Tier $Tier
                    }
                    'AgentTextRoundTrip' {
                        Test-PairedAgentTextSuite -SuiteName 'AgentTextRoundTrip' `
                            -ConnectionString $DatabaseConnectionString -SourceId $AgentTextSourceId -Tier $Tier
                    }
                }
                $validations.Add($suiteResult)
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
                    -Message "Validation suite '$($suiteResult.Name)' at '$Tier': $($suiteResult.Status). $($suiteResult.Detail)"
            }
        }

        $failedSuites = @($validations | Where-Object { $_.Status -eq 'Failed' })
        $validationPassed = ($failedSuites.Count -eq 0)
        $succeeded = $pairedAdvance -and $validationPassed

        $summary = if ($succeeded) {
            "Paired promotion to '$Tier' succeeded: '$ModuleName' '$ModuleVersion' and '$DatabasePackageId' '$DatabasePackageVersion' advanced together; validation [$($validationPlan -join ', ')] passed."
        } else {
            "Paired promotion to '$Tier' advanced both artifacts but validation FAILED: $(@($failedSuites | ForEach-Object { $_.Name }) -join ', ')."
        }
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message $summary

        return [PSCustomObject]@{
            OperationName          = 'Invoke-PairedTierPromotion'
            Succeeded              = $succeeded
            PairedAdvance          = $pairedAdvance
            Tier                   = $Tier
            ModuleName             = $ModuleName
            ModuleVersion          = $ModuleVersion
            ModuleFromFeed         = $moduleFromFeed
            ModuleToFeed           = $moduleToFeed
            DatabasePackageId      = $DatabasePackageId
            DatabasePackageVersion = $DatabasePackageVersion
            DatabaseFromFeed       = $dbFromFeed
            DatabaseToFeed         = $dbToFeed
            ModulePromotion        = $modulePromotion
            DatabasePromotion      = $databasePromotion
            ValidationPlan         = $validationPlan
            Validations            = $validations.ToArray()
            ValidationPassed       = $validationPassed
            ResponseSummary        = $summary
        }
    }

    end {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving $fn" -Tag 'Trace'
    }
}

# Helper: previous tier name in the canonical order. Defined at file scope.
function Get-PairedPreviousTierName {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Development', 'Integration', 'QA', 'Production')]
        [string]$Tier
    )

    begin {
        $tierOrder = @('Experimental', 'Development', 'Integration', 'QA', 'Production')
    }

    process {
        $index = $tierOrder.IndexOf($Tier)
        return $tierOrder[$index - 1]
    }
}
