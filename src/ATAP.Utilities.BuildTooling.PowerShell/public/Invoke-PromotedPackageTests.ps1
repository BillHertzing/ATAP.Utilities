#Requires -Version 7.0
<#
.SYNOPSIS
    Runs tier-appropriate C# tests against an already-promoted NuGet
    package instead of a fresh from-source build.

.DESCRIPTION
    Invoke-PromotedPackageTests is the test half of the immutable-build
    promotion pipeline. Under the immutable-build strategy the package is
    built exactly once at the Experimental tier; every later tier
    (Development -> Integration -> QA -> Production) must run its tests
    against that already-promoted artifact, not against a rebuild.

    The mechanism is the `UsePackageReferenceForSUT` MSBuild property
    documented in CSharp-Packages-Test-Process.md S3.1 / S11.2: the test
    projects carry a conditional <ItemGroup> that swaps their
    <ProjectReference> to the system-under-test for a <PackageReference>
    when `UsePackageReferenceForSUT=true`, resolving the package at the
    version given by `SUTVersion`.

    This cmdlet therefore:
      1. Restores the test target with
         `/p:UsePackageReferenceForSUT=true /p:SUTVersion=<Version>` so
         the promoted package is pulled from the tier feed.
      2. Runs `dotnet test` with the same MSBuild properties, a TRX
         logger, and the caller-supplied `--filter` / coverage options.
      3. Reports a GatePass boolean derived from the `dotnet test` exit
         code, plus a best-effort failing-test count parsed from the TRX.

    -WhatIf short-circuits before invoking dotnet. The returned object
    still carries the resolved inputs so callers can inspect the plan.

    NOTE: the original M2 plan text described creating an ephemeral
    consumer .csproj. That predates the resolved
    `UsePackageReferenceForSUT` design now documented in
    CSharp-Packages-Test-Process.md S11.2 and used by the OtterScript in
    BuildMaster-ProGet-CSharp-Package-Pipeline.md S5; this implementation
    follows the resolved design.

.PARAMETER Name
    The system-under-test package ID, e.g.
    'ATAP.Utilities.Philote'. Used for logging and echoed on the result;
    the actual SUT swap is driven by the test project's conditional
    <ItemGroup> and the SUTVersion property.

.PARAMETER Version
    The exact promoted package version under test. Passed to MSBuild as
    `SUTVersion`, e.g. '1.2.0-Sprint.142'.

.PARAMETER Feed
    The ProGet feed the promoted package currently lives in, e.g.
    'nuget-development'. When -ProGetUrl is also supplied the feed's v3
    index is added to the restore as an explicit `--source`; otherwise
    the feed is assumed to be registered in the agent's NuGet.config.

.PARAMETER ResultsPath
    Directory the TRX (and coverage, when -CollectCoverage is set) is
    written to. Created if it does not exist.

.PARAMETER TestFilter
    Optional value forwarded to `dotnet test --filter`, e.g.
    'Category=Integration' or 'Category=Unit|Category=Integration'.

.PARAMETER CollectCoverage
    When set, adds `--collect:"XPlat Code Coverage"` to the test run.

.PARAMETER ProjectPath
    The solution, solution-filter (.slnf), or test project to run.
    Defaults to 'ATAP.Utilities.sln'. When TestSlice .slnf files exist,
    pass the tier-appropriate filter here.

.PARAMETER ProGetUrl
    Optional ProGet base URL (e.g. 'https://utat022:50000'). When
    supplied, '<ProGetUrl>/nuget/<Feed>/v3/index.json' is added as an
    explicit restore `--source`.

.PARAMETER WorkingDirectory
    Directory the dotnet commands run in. Defaults to the current
    location (the repository worktree root in pipeline use).

.PARAMETER LockedRestore
    Adds `--locked-mode` to the restore step. BuildMaster uses this for
    Integration, QA, and Production after Development has restored the promoted
    package once and materialized the per-build `SUTVersion` lock state.

.OUTPUTS
    [PSCustomObject] with:
      - OperationName    : Always 'Invoke-PromotedPackageTests'.
      - GatePass         : $true when `dotnet test` exited 0.
      - Name             : SUT package ID (echoed input).
      - Version          : Promoted version under test (echoed input).
      - Feed             : Tier feed (echoed input).
      - ProjectPath      : Test target (echoed input).
      - TestFilter       : The --filter value, or $null.
      - ResultsPath      : TRX output directory (echoed input).
      - TrxPath          : Path to the generated .trx, or $null.
      - FailingTestCount : Failing count parsed from the TRX, or $null
                           if the TRX could not be located/parsed.
      - LockedRestore    : $true when restore used `--locked-mode`.
      - RestoreExitCode  : `dotnet restore` exit code, or $null on WhatIf.
      - TestExitCode     : `dotnet test` exit code, or $null on WhatIf
                           or when restore failed.
      - ResponseSummary  : Short human-readable summary.

.EXAMPLE
    Invoke-PromotedPackageTests -Name 'ATAP.Utilities' `
        -Version '0.1.0-Sprint.142' `
        -Feed 'nuget-development' `
        -TestFilter 'Category=Integration' `
        -ResultsPath '_generated\testresults\development'

.EXAMPLE
    Invoke-PromotedPackageTests -Name 'ATAP.Utilities' `
        -Version '0.1.0-Sprint.142' -Feed 'nuget-qa' `
        -ResultsPath '_generated\testresults\qa' -CollectCoverage

.EXAMPLE
    Invoke-PromotedPackageTests -Name 'ATAP.Utilities' `
        -Version '0.1.0-Sprint.142' -Feed 'nuget-development' `
        -ResultsPath '_generated\testresults\development' -WhatIf

    Returns the planned test run without invoking dotnet.

.NOTES
    AI assisted using Powershell.instructions.md as guidelines.
    Stream M2 of the immutable-packages plan. The companion cmdlet for
    PowerShell modules is Invoke-PromotedModuleTests (Stream M3).

.LINK
    https://github.com/whertzing/ATAP.Utilities
#>
function Invoke-PromotedPackageTests {
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
        [ValidateNotNullOrEmpty()]
        [string]$ResultsPath,

        [Parameter()]
        [string]$TestFilter,

        [Parameter()]
        [switch]$CollectCoverage,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ProjectPath = 'ATAP.Utilities.sln',

        [Parameter()]
        [string]$ProGetUrl,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$WorkingDirectory = (Get-Location).Path,

        [Parameter()]
        [switch]$LockedRestore
    )

    begin {
        $fn = 'Invoke-PromotedPackageTests'
        $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn with Name='$Name' Version='$Version' Feed='$Feed' ProjectPath='$ProjectPath'" -Tag 'Trace'
    }

    process {
        $target = "$Name $Version"
        $action = "Test promoted package against feed '$Feed'"

        # WhatIf short-circuit BEFORE invoking dotnet.
        if (-not $PSCmdlet.ShouldProcess($target, $action)) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "WhatIf: would restore and test $target from feed '$Feed' (project: $ProjectPath)"
            return [PSCustomObject]@{
                OperationName    = 'Invoke-PromotedPackageTests'
                GatePass         = $true
                Name             = $Name
                Version          = $Version
                Feed             = $Feed
                ProjectPath      = $ProjectPath
                TestFilter       = if ([string]::IsNullOrWhiteSpace($TestFilter)) { $null } else { $TestFilter }
                ResultsPath      = $ResultsPath
                TrxPath          = $null
                FailingTestCount = $null
                LockedRestore    = [bool]$LockedRestore
                RestoreExitCode  = $null
                TestExitCode     = $null
                ResponseSummary  = "WhatIf: would restore and test $target from feed '$Feed' (project: $ProjectPath)"
            }
        }

        $restoreExitCode = $null
        $testExitCode = $null
        $trxPath = $null
        $failingTestCount = $null
        $gatePass = $false
        $summary = $null

        Push-Location -Path $WorkingDirectory
        try {
            if (-not (Test-Path -Path $ResultsPath)) {
                New-Item -ItemType Directory -Path $ResultsPath -Force | Out-Null
            }

            # ---- Step 1: restore the promoted package ----------------------
            $restoreArgs = @(
                'restore'
                $ProjectPath
                '/p:UsePackageReferenceForSUT=true'
                "/p:SUTVersion=$Version"
            )
            if (-not [string]::IsNullOrWhiteSpace($env:NBGV_BuildingRef)) {
                $restoreArgs += "/p:NBGV_BuildingRef=$env:NBGV_BuildingRef"
            }
            if ($LockedRestore) {
                $restoreArgs += '--locked-mode'
            }
            if (-not [string]::IsNullOrWhiteSpace($ProGetUrl)) {
                $feedSource = "$($ProGetUrl.TrimEnd('/'))/nuget/$Feed/v3/index.json"
                $restoreArgs += @('--source', $feedSource)
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Restore will use explicit feed source '$feedSource'"
            }

            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Restoring promoted package for $target : dotnet $($restoreArgs -join ' ')"
            dotnet @restoreArgs
            $restoreExitCode = $LASTEXITCODE
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "dotnet restore exited $restoreExitCode"

            if ($restoreExitCode -ne 0) {
                $summary = "Restore of promoted package $target from feed '$Feed' failed (dotnet restore exit $restoreExitCode); tests not run."
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $summary
                return [PSCustomObject]@{
                    OperationName    = 'Invoke-PromotedPackageTests'
                    GatePass         = $false
                    Name             = $Name
                    Version          = $Version
                    Feed             = $Feed
                    ProjectPath      = $ProjectPath
                    TestFilter       = if ([string]::IsNullOrWhiteSpace($TestFilter)) { $null } else { $TestFilter }
                    ResultsPath      = $ResultsPath
                    TrxPath          = $null
                    FailingTestCount = $null
                    LockedRestore    = [bool]$LockedRestore
                    RestoreExitCode  = $restoreExitCode
                    TestExitCode     = $null
                    ResponseSummary  = $summary
                }
            }

            # ---- Step 2: run dotnet test against the promoted package ------
            # --no-restore is safe: step 1 just restored with the same
            # MSBuild properties. A rebuild still happens because the
            # conditional <ItemGroup> changed from the developer default.
            $testArgs = @(
                'test'
                $ProjectPath
                '-c'
                'Release'
                '/p:UsePackageReferenceForSUT=true'
                "/p:SUTVersion=$Version"
                '--no-restore'
                '--logger'
                'trx'
                '--results-directory'
                $ResultsPath
            )
            if (-not [string]::IsNullOrWhiteSpace($env:NBGV_BuildingRef)) {
                $testArgs += "/p:NBGV_BuildingRef=$env:NBGV_BuildingRef"
            }
            if (-not [string]::IsNullOrWhiteSpace($TestFilter)) {
                $testArgs += @('--filter', $TestFilter)
            }
            if ($CollectCoverage) {
                $testArgs += @('--collect', 'XPlat Code Coverage')
            }

            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Testing promoted package $target : dotnet $($testArgs -join ' ')"
            dotnet @testArgs
            $testExitCode = $LASTEXITCODE
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "dotnet test exited $testExitCode"

            $gatePass = ($testExitCode -eq 0)

            # ---- Step 3: locate and parse the TRX (best effort) ------------
            $trxFile = Get-ChildItem -Path $ResultsPath -Filter '*.trx' -ErrorAction SilentlyContinue |
                Sort-Object -Property LastWriteTime -Descending |
                Select-Object -First 1
            if ($null -ne $trxFile) {
                $trxPath = $trxFile.FullName
                try {
                    if (Get-Command Get-NumberOfFailingTestsFromTRX -ErrorAction SilentlyContinue) {
                        $failingTestCount = [int](Get-NumberOfFailingTestsFromTRX -xmlInputFile $trxPath)
                    }
                } catch {
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Could not parse failing-test count from '$trxPath': $($_.Exception.Message)"
                    $failingTestCount = $null
                }
            } else {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "No .trx file found under '$ResultsPath'"
            }

            if ($gatePass) {
                $summary = "Promoted package $target passed tests against feed '$Feed' (dotnet test exit 0"
                $summary += if ($null -ne $failingTestCount) { ", $failingTestCount failing in TRX)." } else { ")." }
            } else {
                $summary = "Promoted package $target FAILED tests against feed '$Feed' (dotnet test exit $testExitCode"
                $summary += if ($null -ne $failingTestCount) { ", $failingTestCount failing in TRX)." } else { ")." }
            }
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message $summary

            return [PSCustomObject]@{
                OperationName    = 'Invoke-PromotedPackageTests'
                GatePass         = $gatePass
                Name             = $Name
                Version          = $Version
                Feed             = $Feed
                ProjectPath      = $ProjectPath
                TestFilter       = if ([string]::IsNullOrWhiteSpace($TestFilter)) { $null } else { $TestFilter }
                ResultsPath      = $ResultsPath
                TrxPath          = $trxPath
                FailingTestCount = $failingTestCount
                LockedRestore    = [bool]$LockedRestore
                RestoreExitCode  = $restoreExitCode
                TestExitCode     = $testExitCode
                ResponseSummary  = $summary
            }
        } catch {
            $errMsg = "Failed to run promoted-package tests for $target against feed '$Feed': $($_.Exception.Message)"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errMsg
            throw
        } finally {
            Pop-Location
        }
    }

    end {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving $fn" -Tag 'Trace'
    }
}
