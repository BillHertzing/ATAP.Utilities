#Requires -Version 7.0
<#
.SYNOPSIS
    Runs tier-appropriate Pester tests against an already-promoted
    PowerShell module instead of a fresh from-source build.

.DESCRIPTION
    Invoke-PromotedModuleTests is the PowerShell-module counterpart of
    Invoke-PromotedPackageTests (Stream M2). Under the immutable-build
    strategy a module's .nupkg is packed once at the Experimental tier;
    every later tier (Development -> Integration -> QA -> Production)
    tests that already-promoted artifact rather than re-packing.

    The resolved design (PowerShell-Modules-Test-Process.md strategy
    note, BuildMaster Plans/PowerShellModule-5Stage.otter) splits the two
    halves of "test the promoted module" cleanly:

      * The MODULE UNDER TEST is the promoted .nupkg. This cmdlet
        restores it from the tier's PowerShellGet feed with
        Save-PSResource and imports it, so the commands exercised are the
        promoted artifact's.
      * The TESTS THEMSELVES come from the source tree's tests/ folder.
        Pester test files are never shipped inside the .nupkg
        (PowerShell-Modules-Build-Process.md S2), so they cannot be run
        from the restored package. They are run from
        <ModuleSourceRoot>/tests instead.

    The actual Pester run is delegated to the existing
    Invoke-PSModulePesterTests driver, which already owns the
    tier-to-tag filter matrix, JUnit-XML emission, and coverage
    configuration. The delegated run executes in a child scope with
    StrictMode disabled so BuildMaster's runner-level StrictMode does not
    leak into test containers that are designed for normal module-consumer
    semantics. This cmdlet's job is the restore + import + tier translation
    + test-scope isolation + result projection around that driver.

    BuildMaster tier names (Experimental/Development/Integration/QA/
    Production) are translated to the Invoke-PSModulePesterTests filter
    vocabulary (Sprint/Alpha/Beta/QA/Production) before delegation; the
    mapping is the canonical one from Get-TierFromNBGVLabel.

    -WhatIf short-circuits before restoring or testing. The returned
    object still carries the resolved inputs so callers can inspect the
    plan.

.PARAMETER Name
    The promoted module / package ID, e.g.
    'ATAP.Utilities.FileIO.PowerShell'.

.PARAMETER Version
    The exact promoted module version under test, e.g.
    '0.1.0-Sprint.142'.

.PARAMETER Feed
    The PowerShellGet feed the promoted module currently lives in, e.g.
    'powershellget-development'. The feed must be registered as a
    PSResourceRepository of the same name (the build pipeline registers
    the tier feeds); Save-PSResource restores from it by `-Repository`.
    When ProGetBaseUrl is supplied, the package is restored from ProGet's
    direct package endpoint instead of PSResourceGet's OData query path.

.PARAMETER Tier
    The current BuildMaster tier:
    Experimental / Development / Integration / QA / Production. It is
    translated internally to the Invoke-PSModulePesterTests filter tier
    (Sprint / Alpha / Beta / QA / Production).

.PARAMETER ResultsPath
    Directory the JUnit-XML test results and JaCoCo coverage are written
    to. Created if it does not exist.

.PARAMETER ModuleSourceRoot
    The source-tree module folder that contains the `tests/` directory.
    Defaults to `src/<Name>` under -WorkingDirectory. The promoted module
    supplies the code under test; this folder supplies the test files.

.PARAMETER WorkingDirectory
    Directory paths are resolved against and the restore folder is
    created under. Defaults to the current location (the repository
    worktree root in pipeline use).

.PARAMETER ProGetBaseUrl
    Optional ProGet base URL. When supplied, restore the promoted .nupkg
    directly from /nuget/<feed>/package/<name>/<version>.

.PARAMETER ApiKey
    Optional ProGet API key to send as X-ApiKey when restoring directly
    from ProGet.

.PARAMETER PesterOutputVerbosity
    Controls the delegated Pester console output. Defaults to Normal to keep
    BuildMaster deployment logs concise while retaining test totals. Use
    Detailed or Diagnostic for live troubleshooting.

.PARAMETER PesterProgressInterval
    When delegated Pester output is quiet, emits a compact time-based heartbeat
    every this many seconds while Pester is running. Defaults to 20; set to 0
    to disable.

.PARAMETER RestoreRetryCount
    Number of attempts to restore/download the promoted module package. This
    covers short ProGet feed/index availability delays immediately after a
    successful promotion. Defaults to 12.

.PARAMETER RestoreRetryDelaySeconds
    Delay between restore/download attempts. Defaults to 5 seconds.

.OUTPUTS
    [PSCustomObject] with:
      - OperationName    : Always 'Invoke-PromotedModuleTests'.
      - GatePass         : $true when the delegated Pester run had zero
                           failures.
      - Name             : Module ID (echoed input).
      - Version          : Promoted version under test (echoed input).
      - Feed             : Tier feed (echoed input).
      - Tier             : BuildMaster tier (echoed input).
      - PesterTier       : The translated Invoke-PSModulePesterTests tier.
      - ResultsPath      : Output directory (echoed input).
      - SavedModulePath  : Path the promoted module was restored to, or
                           $null on WhatIf.
      - OutputFile       : JUnit-XML results path, or $null on WhatIf.
      - CoverageFile     : JaCoCo coverage path, or $null on WhatIf.
      - Passed / Failed / SkippedCount / TotalCount : Pester counts, or 0.
      - ResponseSummary  : Short human-readable summary.
      - InnerResult      : The full object returned by
                           Invoke-PSModulePesterTests, or $null on WhatIf.

.EXAMPLE
    Invoke-PromotedModuleTests -Name 'ATAP.Utilities.FileIO.PowerShell' `
        -Version '0.1.0-Sprint.142' `
        -Feed 'powershellget-development' `
        -Tier 'Development' `
        -ResultsPath '_generated\testresults\Development'

.EXAMPLE
    Invoke-PromotedModuleTests -Name 'ATAP.Utilities.FileIO.PowerShell' `
        -Version '0.1.0-Sprint.142' -Feed 'powershellget-qa' `
        -Tier 'QA' -ResultsPath '_generated\testresults\QA' -WhatIf

    Returns the planned restore + test run without touching the feed.

.NOTES
    AI assisted using Powershell.instructions.md as guidelines.
    Stream M3 of the immutable-packages plan. The companion cmdlet for
    C# packages is Invoke-PromotedPackageTests (Stream M2).

.LINK
    https://github.com/whertzing/ATAP.Utilities
#>
function Invoke-PromotedModuleTests {
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
        [string]$Feed,

        [Parameter(Mandatory)]
        [ValidateSet('Experimental', 'Development', 'Integration', 'QA', 'Production')]
        [string]$Tier,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ResultsPath,

        [Parameter()]
        [string]$ModuleSourceRoot,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$WorkingDirectory = (Get-Location).Path,

        [Parameter()]
        [AllowEmptyString()]
        [string]$ProGetBaseUrl = $global:ProGetBaseUrl,

        [Parameter()]
        [AllowEmptyString()]
        [string]$ApiKey = $env:PROGET_BUILDMASTER_API_KEY,

        [Parameter()]
        [ValidateSet('None', 'Normal', 'Detailed', 'Diagnostic')]
        [string]$PesterOutputVerbosity = 'Normal',

        [Parameter()]
        [ValidateRange(0, [int]::MaxValue)]
        [int]$PesterProgressInterval = 20,

        [Parameter()]
        [ValidateRange(1, 60)]
        [int]$RestoreRetryCount = 12,

        [Parameter()]
        [ValidateRange(0, 300)]
        [int]$RestoreRetryDelaySeconds = 5
    )

    begin {
        $fn = 'Invoke-PromotedModuleTests'
        $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn with Name='$Name' Version='$Version' Feed='$Feed' Tier='$Tier'" -Tag 'Trace'

        # Canonical BuildMaster-tier -> Invoke-PSModulePesterTests-tier map.
        # Matches the label table in Get-TierFromNBGVLabel.
        $pesterTierMap = @{
            Experimental = 'Sprint'
            Development  = 'Alpha'
            Integration  = 'Beta'
            QA           = 'QA'
            Production   = 'Production'
        }
    }

    process {
        $target = "$Name $Version"
        $pesterTier = $pesterTierMap[$Tier]
        $testDescription = "$Tier-tier promoted-module tests using $pesterTier Pester filter"
        $action = "Restore from feed '$Feed' and run $testDescription"

        # WhatIf short-circuit BEFORE restoring or testing.
        if (-not $PSCmdlet.ShouldProcess($target, $action)) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "WhatIf: would restore $target from feed '$Feed' and run $testDescription"
            return [PSCustomObject]@{
                OperationName   = 'Invoke-PromotedModuleTests'
                GatePass        = $true
                Name            = $Name
                Version         = $Version
                Feed            = $Feed
                Tier            = $Tier
                PesterTier      = $pesterTier
                ResultsPath     = $ResultsPath
                SavedModulePath = $null
                OutputFile      = $null
                CoverageFile    = $null
                Passed          = 0
                Failed          = 0
                SkippedCount    = 0
                TotalCount      = 0
                ResponseSummary = "WhatIf: would restore $target from feed '$Feed' and run $testDescription"
                InnerResult     = $null
            }
        }

        Push-Location -Path $WorkingDirectory
        try {
            # Resolve the source-tree module folder (supplies the test files).
            if ([string]::IsNullOrWhiteSpace($ModuleSourceRoot)) {
                $ModuleSourceRoot = Join-Path $WorkingDirectory (Join-Path 'src' $Name)
            }
            if (-not (Test-Path -Path $ModuleSourceRoot)) {
                throw "ModuleSourceRoot '$ModuleSourceRoot' does not exist; cannot locate the tests/ folder for $Name."
            }

            if (-not (Test-Path -Path $ResultsPath)) {
                New-Item -ItemType Directory -Path $ResultsPath -Force | Out-Null
            }

            # ---- Step 1: restore the promoted module from the tier feed ----
            $restoreKey = ("$Name.$Version.$Feed" -replace '[^A-Za-z0-9._-]', '-')
            $restorePath = Join-Path $WorkingDirectory (Join-Path '_generated' (Join-Path '_promoted-modules' $restoreKey))
            if (-not (Test-Path -Path $restorePath)) {
                New-Item -ItemType Directory -Path $restorePath -Force | Out-Null
            }

            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Restoring promoted module $target from feed '$Feed' to '$restorePath'"
            if (-not [string]::IsNullOrWhiteSpace($ProGetBaseUrl)) {
                $trimmedBaseUrl = $ProGetBaseUrl.TrimEnd('/')
                $packageUri = '{0}/nuget/{1}/package/{2}/{3}' -f $trimmedBaseUrl, $Feed, [uri]::EscapeDataString($Name), [uri]::EscapeDataString($Version)
                $nupkgPath = Join-Path $restorePath "$Name.$Version.nupkg"
                $extractPath = Join-Path $restorePath 'package'
                $headers = @{
                    Accept = 'application/zip'
                }
                if (-not [string]::IsNullOrWhiteSpace($ApiKey)) {
                    $headers['X-ApiKey'] = $ApiKey
                }

                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Downloading promoted module package from '$packageUri'"
                for ($attempt = 1; $attempt -le $RestoreRetryCount; $attempt++) {
                    try {
                        Invoke-WebRequest -Uri $packageUri -Headers $headers -OutFile $nupkgPath -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop | Out-Null
                        break
                    } catch {
                        if ($attempt -ge $RestoreRetryCount) {
                            throw
                        }

                        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Tag 'Warning' -Message "Promoted module package download attempt $attempt/$RestoreRetryCount failed for '$packageUri': $($_.Exception.Message). Retrying in $RestoreRetryDelaySeconds second(s)."
                        if ($RestoreRetryDelaySeconds -gt 0) {
                            Start-Sleep -Seconds $RestoreRetryDelaySeconds
                        }
                    }
                }
                if (Test-Path -LiteralPath $extractPath) {
                    Remove-Item -LiteralPath $extractPath -Recurse -Force
                }
                Expand-Archive -LiteralPath $nupkgPath -DestinationPath $extractPath -Force
            } else {
                for ($attempt = 1; $attempt -le $RestoreRetryCount; $attempt++) {
                    try {
                        Save-PSResource -Name $Name -Version $Version -Repository $Feed -Path $restorePath -TrustRepository -ErrorAction Stop
                        break
                    } catch {
                        if ($attempt -ge $RestoreRetryCount) {
                            throw
                        }

                        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Tag 'Warning' -Message "Promoted module Save-PSResource attempt $attempt/$RestoreRetryCount failed for $target from '$Feed': $($_.Exception.Message). Retrying in $RestoreRetryDelaySeconds second(s)."
                        if ($RestoreRetryDelaySeconds -gt 0) {
                            Start-Sleep -Seconds $RestoreRetryDelaySeconds
                        }
                    }
                }
            }

            $savedManifest = Get-ChildItem -Path $restorePath -Recurse -Filter "$Name.psd1" -ErrorAction SilentlyContinue |
                Sort-Object -Property FullName -Descending |
                Select-Object -First 1
            if ($null -eq $savedManifest) {
                throw "Save-PSResource did not produce a '$Name.psd1' under '$restorePath' for $target."
            }
            $savedModulePath = $savedManifest.FullName
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Promoted module restored; manifest at '$savedModulePath'"

            # ---- Step 2: import the promoted module (it is the SUT) --------
            # A BuildMaster execution can exercise several tiers in one pwsh
            # process. Remove the prior tier's copy before importing the next
            # restored path; PowerShell otherwise permits same-name modules
            # from different paths to remain loaded simultaneously.
            Remove-Module -Name $Name -Force -ErrorAction SilentlyContinue
            $remainingCopies = @(Get-Module -Name $Name -All)
            if ($remainingCopies.Count -ne 0) {
                $remainingPaths = $remainingCopies | ForEach-Object { $_.Path } | Sort-Object -Unique
                throw "Unable to isolate promoted module '$Name'; loaded copy or copies remain: $($remainingPaths -join ', ')"
            }
            Import-Module -Name $savedModulePath -Force -ErrorAction Stop
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Imported promoted module $target"

            # ---- Step 3: run Pester from the source-tree tests/ folder -----
            # Tests are never shipped inside the .nupkg, so they come from
            # source; the imported promoted module supplies the code path.
            $outputFile = Join-Path $ResultsPath 'PesterResults.xml'
            $coverageFile = Join-Path $ResultsPath 'CoverageResults.xml'

            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Running $testDescription for $target (tests from '$ModuleSourceRoot', module from '$savedModulePath')"
            # BuildMasterRunContext.Common.ps1 intentionally enables
            # StrictMode for the stage runner. Pester test containers are
            # module-consumer code and must not inherit that runner policy:
            # under StrictMode, ordinary missing-property probes and scalar
            # .Count checks abort fixture setup, causing broad false failures.
            # A child scope keeps the caller's StrictMode unchanged while
            # giving the delegated test run normal PowerShell semantics.
            $innerResult = & {
                Set-StrictMode -Off
                Invoke-PSModulePesterTests `
                    -ModuleRoot $ModuleSourceRoot `
                    -Tier $pesterTier `
                    -OutputPath $outputFile `
                    -CoverageOutputPath $coverageFile `
                    -SkipCodeCoverage `
                    -PesterOutputVerbosity $PesterOutputVerbosity `
                    -PesterProgressInterval $PesterProgressInterval `
                    -ErrorAction Stop
            }

            $passed = if ($null -ne $innerResult) { [int]$innerResult.Passed } else { 0 }
            $failed = if ($null -ne $innerResult) { [int]$innerResult.Failed } else { 0 }
            $skipped = if ($null -ne $innerResult) { [int]$innerResult.SkippedCount } else { 0 }
            $total = if ($null -ne $innerResult) { [int]$innerResult.TotalCount } else { 0 }
            $gatePass = if ($null -ne $innerResult) { [bool]$innerResult.GatePass } else { $false }

            if ($gatePass) {
                $summary = "Promoted module $target passed $testDescription ($passed passed, $failed failed, $skipped skipped of $total)."
            } else {
                $summary = "Promoted module $target FAILED $testDescription ($passed passed, $failed failed, $skipped skipped of $total)."
            }
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message $summary

            return [PSCustomObject]@{
                OperationName   = 'Invoke-PromotedModuleTests'
                GatePass        = $gatePass
                Name            = $Name
                Version         = $Version
                Feed            = $Feed
                Tier            = $Tier
                PesterTier      = $pesterTier
                ResultsPath     = $ResultsPath
                SavedModulePath = $savedModulePath
                OutputFile      = $outputFile
                CoverageFile    = $coverageFile
                Passed          = $passed
                Failed          = $failed
                SkippedCount    = $skipped
                TotalCount      = $total
                ResponseSummary = $summary
                InnerResult     = $innerResult
            }
        } catch {
            $errMsg = "Failed to run promoted-module tests for $target against feed '$Feed': $($_.Exception.Message)"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errMsg
            throw
        } finally {
            Remove-Module -Name $Name -Force -ErrorAction SilentlyContinue
            Pop-Location
        }
    }

    end {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving $fn" -Tag 'Trace'
    }
}
