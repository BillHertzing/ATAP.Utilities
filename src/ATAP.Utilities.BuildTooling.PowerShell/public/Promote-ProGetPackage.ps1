#Requires -Version 7.0
<#
.SYNOPSIS
    Promotes a package from one ProGet feed to another by wrapping
    Move-ProGetPackageInterTier with the canonical immutable-pipeline
    parameter names (Name, Version, FromFeed, ToFeed, Reason).

.DESCRIPTION
    Promote-ProGetPackage is the single entry point that BuildMaster plans
    and orchestrator scripts call to advance a package between environment
    tiers in the 5-tier ProGet topology
    (Experimental -> Development -> Integration -> QA -> Production).

    It is a thin wrapper over Move-ProGetPackageInterTier and exists so
    every caller in Streams F-N uses the same parameter vocabulary that
    matches BuildMaster-Pipeline-Topology.md S4. As of the C2.3 naming
    alignment, Move-ProGetPackageInterTier exposes the same canonical
    -Name / -Version / -FromFeed / -ToFeed / -Reason parameter set
    (with the legacy -PackageName / -SourceFeed / -DestinationFeed /
    -Comments names retained as aliases for backward compatibility), so
    this wrapper forwards each parameter under its canonical name.

    The wrapper is idempotent. If the inner cmdlet reports the package is
    already in the destination feed (or the move call returns "already
    promoted"), Promote-ProGetPackage surfaces that fact in the
    ResponseSummary string and returns Succeeded = $true without
    re-erroring.

    -WhatIf short-circuits before invoking the inner cmdlet. The returned
    object still carries the resolved input parameters so callers can
    inspect the promotion plan.

.PARAMETER Name
    The package ID, e.g. 'ATAP.Utilities.Configuration.Extensions'.
    Forwarded to the inner cmdlet's -Name.

.PARAMETER Version
    The exact package version to promote, e.g. '1.2.0-experimental.42'.
    Forwarded as-is.

.PARAMETER FromFeed
    The source feed name (e.g. 'nuget-experimental'). Forwarded to the
    inner cmdlet's -FromFeed.

.PARAMETER ToFeed
    The destination feed name (e.g. 'nuget-development'). Forwarded to
    the inner cmdlet's -ToFeed.

.PARAMETER Reason
    A short human-readable reason recorded in ProGet's audit log.
    Forwarded to the inner cmdlet's -Reason.

.OUTPUTS
    [PSCustomObject] with at least these properties (per V3 plan S2.1):
      - OperationName   : Always 'Promote-ProGetPackage'.
      - Succeeded       : $true when the move completed or was a no-op.
      - Name            : The package name (echoed input).
      - Version         : The package version (echoed input).
      - FromFeed        : Source feed (echoed input).
      - ToFeed          : Destination feed (echoed input).
      - ResponseSummary : Short string summary of the operation, the
                          no-op detection, or the WhatIf plan.
      - InnerResult     : The full PSCustomObject returned by
                          Move-ProGetPackageInterTier, or $null on WhatIf.

.EXAMPLE
    Promote-ProGetPackage -Name 'ATAP.Utilities.Foo' `
        -Version '1.2.0-experimental.42' `
        -FromFeed 'nuget-experimental' `
        -ToFeed 'nuget-development' `
        -Reason 'sprint-0007 promotion'

.EXAMPLE
    Promote-ProGetPackage -Name 'ATAP.Utilities.Foo' `
        -Version '1.2.0-experimental.42' `
        -FromFeed 'nuget-experimental' `
        -ToFeed 'nuget-development' `
        -Reason 'plan check' -WhatIf

    Returns the planned promotion object without calling
    Move-ProGetPackageInterTier.

.NOTES
    AI assisted using Powershell.instructions.md as guidelines.
    Wraps Move-ProGetPackageInterTier. Stream G1 of V3 plan.

.LINK
    https://github.com/whertzing/ATAP.Utilities
#>
function Promote-ProGetPackage {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

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
        [string]$Reason
    )

    begin {
        $fn = 'Promote-ProGetPackage'
        $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn with Name='$Name' Version='$Version' FromFeed='$FromFeed' ToFeed='$ToFeed'" -Tag 'Trace'
    }

    process {
        # WhatIf short-circuit BEFORE invoking the inner cmdlet, per V3 S2.1 rule 2.
        $target = "$Name $Version"
        $action = "Promote from '$FromFeed' to '$ToFeed'"
        if (-not $PSCmdlet.ShouldProcess($target, $action)) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "WhatIf: would promote $target from '$FromFeed' to '$ToFeed' (reason: $Reason)"
            return [PSCustomObject]@{
                OperationName   = 'Promote-ProGetPackage'
                Succeeded       = $true
                Name            = $Name
                Version         = $Version
                FromFeed        = $FromFeed
                ToFeed          = $ToFeed
                ResponseSummary = "WhatIf: would promote $target from '$FromFeed' to '$ToFeed'"
                InnerResult     = $null
            }
        }

        # Forward to the inner cmdlet using its parameter vocabulary.
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Promoting $target : '$FromFeed' -> '$ToFeed' (reason: $Reason)" -Tag 'RestCall'

        $innerResult = $null
        $succeeded = $false
        $summary = $null
        try {
            $innerResult = Move-ProGetPackageInterTier `
                -Name $Name `
                -Version $Version `
                -FromFeed $FromFeed `
                -ToFeed $ToFeed `
                -Reason $Reason `
                -ErrorAction Stop

            # Inner cmdlet returns a PSCustomObject with a Promoted property.
            # Idempotent re-runs: ProGet's promote endpoint accepts repeat
            # calls and returns a success-shaped response. Surface that as
            # ResponseSummary instead of treating it as an error.
            if ($null -ne $innerResult -and $innerResult.PSObject.Properties['Promoted']) {
                $succeeded = [bool]$innerResult.Promoted
            } else {
                # No explicit Promoted flag -> consider absence of exception success.
                $succeeded = $true
            }

            $responseText = if ($null -ne $innerResult -and $innerResult.PSObject.Properties['Response']) {
                ([string]$innerResult.Response).Trim()
            } else {
                ''
            }

            if (-not [string]::IsNullOrWhiteSpace($responseText) -and $responseText -match '(?i)already|exists|no-op|duplicate') {
                $summary = "No-op: $target already promoted to '$ToFeed' ($responseText)"
                $succeeded = $true
            } elseif ($succeeded) {
                $summary = "Promoted $target from '$FromFeed' to '$ToFeed'."
            } else {
                $summary = "Move-ProGetPackageInterTier returned Promoted=false for $target ($FromFeed -> $ToFeed)."
            }

            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message $summary
        } catch {
            # Best-effort idempotency: ProGet's promote endpoint sometimes
            # returns a 409/Conflict when the package is already at the
            # destination. Detect that text shape and surface it as no-op.
            $exceptionMessage = [string]$_.Exception.Message
            if ($exceptionMessage -match '(?i)already in feed|already promoted|already exists|409') {
                $summary = "No-op: $target already present in '$ToFeed' (inner exception: $exceptionMessage)"
                $succeeded = $true
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message $summary
            } else {
                $errMsg = "Failed to promote $target from '$FromFeed' to '$ToFeed': $exceptionMessage"
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errMsg
                throw
            }
        }

        return [PSCustomObject]@{
            OperationName   = 'Promote-ProGetPackage'
            Succeeded       = $succeeded
            Name            = $Name
            Version         = $Version
            FromFeed        = $FromFeed
            ToFeed          = $ToFeed
            ResponseSummary = $summary
            InnerResult     = $innerResult
        }
    }

    end {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving $fn" -Tag 'Trace'
    }
}
