#Requires -Version 7.0
<#
.SYNOPSIS
    Compiles an execution-scoped SDK consumer against an already-promoted
    NuGet package without restoring or building the repository solution.

.DESCRIPTION
    The package is built exactly once at Experimental. Every promoted tier
    validates the immutable package by generating a deterministic SDK consumer
    beneath the original execution artifacts root. The consumer targets net8.0,
    or net8.0-windows7.0 when the package ID ends in `.Windows`, and has
    exactly one XML-escaped PackageReference for Name and Version.

    Restore suppresses repository Directory.Build and central-package imports,
    selects the requested lifecycle tier, stable as a dependency-only fallback,
    plus configured non-lifecycle sources, uses a tier-scoped packages directory,
    and verifies the restored
    package's .nupkg.metadata source. The consumer is then compiled with
    dotnet build --no-restore. The gate never targets the SUT solution or
    project and never claims that xUnit tests ran.

    Development may create or update the deterministic project and lock file.
    Integration, QA, and Production use LockedRestore and require the persisted
    project and lock file to match.

.PARAMETER Name
    Exact promoted package ID written to the consumer PackageReference.

.PARAMETER Version
    Exact promoted package version written to the consumer PackageReference.

.PARAMETER Feed
    Exact approved NuGet lifecycle feed.

.PARAMETER ResultsPath
    Execution-scoped results directory retained in the result contract.

.PARAMETER TestFilter
    Compatibility-only input echoed in the result. No xUnit test is run.

.PARAMETER CollectCoverage
    Compatibility-only switch. Coverage is not collected by this compile gate.

.PARAMETER ProjectPath
    Compatibility-only original SUT target echoed as RequestedProjectPath.
    It is never passed to dotnet.

.PARAMETER ProGetUrl
    ProGet base URL used to construct and verify the requested tier source.

.PARAMETER WorkingDirectory
    Repository root used only to read NuGet.Config for configured
    non-lifecycle sources.

.PARAMETER LockedRestore
    Requires the deterministic consumer project and packages.lock.json to
    already exist and adds --locked-mode to restore.

.PARAMETER ArtifactsContext
    Resolver result containing the external execution artifacts identity.

.OUTPUTS
    PSCustomObject preserving the existing gate fields. GatePass reflects
    isolated consumer compilation. RestoreExitCode and BuildExitCode report
    the two real operations. TestExitCode, TrxPath, and FailingTestCount remain
    null because no xUnit test runs.

.EXAMPLE
    Invoke-PromotedPackageTests -Name 'ATAP.Utilities.ETW' -Version '0.1.3' `
        -Feed 'nuget-development' -ProGetUrl 'https://utat022:50000' `
        -ResultsPath 'test-results/development' -ArtifactsContext $context

.EXAMPLE
    Invoke-PromotedPackageTests -Name 'ATAP.Utilities.ETW' -Version '0.1.3' `
        -Feed 'nuget-integration' -ProGetUrl 'https://utat022:50000' `
        -ResultsPath 'test-results/integration' -LockedRestore -ArtifactsContext $context

.NOTES
    AI assisted using Powershell.instructions.md as guidelines.
    Task 15.182.F03 isolated promoted-package consumer gate.

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
        [switch]$LockedRestore,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [psobject]$ArtifactsContext
    )

    begin {
        $fn = 'Invoke-PromotedPackageTests'
        $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn with Name='$Name' Version='$Version' Feed='$Feed' ProjectPath='$ProjectPath'" -Tag 'Trace'

        foreach ($propertyName in @('Root', 'WorktreeId', 'ExecutionId', 'ArtifactsPath', 'BinlogPath', 'PackageStagingPath', 'PublishStagingPath')) {
            if ($ArtifactsContext.PSObject.Properties.Name -notcontains $propertyName -or [string]::IsNullOrWhiteSpace([string]$ArtifactsContext.$propertyName)) {
                throw "ArtifactsContext.$propertyName is required."
            }
        }
        $artifactsRoot = [IO.Path]::GetFullPath([string]$ArtifactsContext.Root)
        $artifactsPath = [IO.Path]::GetFullPath([string]$ArtifactsContext.ArtifactsPath)
        $expectedArtifactsPath = [IO.Path]::GetFullPath((Join-Path $artifactsRoot 'dotnet' 'ATAP.Utilities' ([string]$ArtifactsContext.WorktreeId) ([string]$ArtifactsContext.ExecutionId)))
        if ($artifactsPath -cne $expectedArtifactsPath -or $artifactsPath -match '(?i)[\\/]Dropbox[\\/]') {
            throw "ArtifactsContext.ArtifactsPath '$artifactsPath' is not the canonical external path '$expectedArtifactsPath'."
        }
        $artifactsOwner = "ATAP.Utilities|$($ArtifactsContext.WorktreeId)|$($ArtifactsContext.ExecutionId)"
        $ownerMarkerPath = Join-Path $artifactsPath '.atap-artifacts-owner'
        if (-not (Test-Path -LiteralPath $ownerMarkerPath -PathType Leaf)) {
            throw "Package-smoke owner marker is missing: '$ownerMarkerPath'."
        }
        $existingOwner = (Get-Content -LiteralPath $ownerMarkerPath -Raw).Trim()
        if ($existingOwner -cne $artifactsOwner) {
            throw "ArtifactsPath '$artifactsPath' is owned by '$existingOwner', not '$artifactsOwner'."
        }
        $resolvedResultsPath = if ([IO.Path]::IsPathRooted($ResultsPath)) {
            [IO.Path]::GetFullPath($ResultsPath)
        } else {
            [IO.Path]::GetFullPath((Join-Path $artifactsPath $ResultsPath))
        }
        if (-not $resolvedResultsPath.StartsWith($artifactsPath + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
            throw "ResultsPath '$resolvedResultsPath' must remain beneath ArtifactsPath '$artifactsPath'."
        }
        $artifactArguments = @(
            '--artifacts-path'
            $artifactsPath
            "/p:ATAPArtifactsRoot=$artifactsRoot"
            "/p:ATAPArtifactsWorktreeId=$($ArtifactsContext.WorktreeId)"
            "/p:ATAPArtifactsExecutionId=$($ArtifactsContext.ExecutionId)"
        )
        $resolvedBinlogPath = [IO.Path]::GetFullPath([string]$ArtifactsContext.BinlogPath)
    }

    process {
        $target = "$Name $Version"
        $action = "Compile isolated consumer against feed '$Feed'"
        $identityBytes = [Text.Encoding]::UTF8.GetBytes("$Name`n$Version")
        $identityHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($identityBytes)).ToLowerInvariant()
        $consumerRoot = Join-Path $artifactsPath 'promoted-consumer' $identityHash
        $consumerProjectPath = Join-Path $consumerRoot 'PromotedPackageConsumer.csproj'
        $consumerLockPath = Join-Path $consumerRoot 'packages.lock.json'
        $tierPackagesPath = Join-Path $artifactsPath 'nuget-packages' $Feed
        $consumerTargetFramework = if ($Name.EndsWith('.Windows', [StringComparison]::OrdinalIgnoreCase)) {
            'net8.0-windows7.0'
        }
        else {
            'net8.0'
        }
        $directPackageReferences = [ordered]@{ $Name = $Version }
        $newConsumerProjectContent = {
            param([System.Collections.IDictionary]$References)
            $referenceLines = @($References.GetEnumerator() | Sort-Object Key | ForEach-Object {
                    $escapedReferenceName = [Security.SecurityElement]::Escape([string]$_.Key)
                    $escapedReferenceVersion = [Security.SecurityElement]::Escape([string]$_.Value)
                    "    <PackageReference Include=`"$escapedReferenceName`" Version=`"$escapedReferenceVersion`" />"
                })
            return (@(
                    '<Project Sdk="Microsoft.NET.Sdk">'
                    '  <PropertyGroup>'
                    "    <TargetFramework>$consumerTargetFramework</TargetFramework>"
                    '    <ManagePackageVersionsCentrally>false</ManagePackageVersionsCentrally>'
                    '    <RestorePackagesWithLockFile>true</RestorePackagesWithLockFile>'
                    '  </PropertyGroup>'
                    '  <ItemGroup>'
                    $referenceLines
                    '  </ItemGroup>'
                    '</Project>'
                ) -join [Environment]::NewLine) + [Environment]::NewLine
        }
        $consumerProjectContent = & $newConsumerProjectContent -References $directPackageReferences

        $newResult = {
            param(
                [bool]$GatePass,
                [AllowNull()][Nullable[int]]$RestoreExitCode,
                [AllowNull()][Nullable[int]]$BuildExitCode,
                [string]$ResponseSummary
            )
            [PSCustomObject]@{
                OperationName      = 'Invoke-PromotedPackageTests'
                GatePass           = $GatePass
                Name               = $Name
                Version            = $Version
                Feed               = $Feed
                ProjectPath        = $consumerProjectPath
                RequestedProjectPath = $ProjectPath
                TestFilter         = if ([string]::IsNullOrWhiteSpace($TestFilter)) { $null } else { $TestFilter }
                ResultsPath        = $resolvedResultsPath
                TrxPath            = $null
                FailingTestCount   = $null
                LockedRestore      = [bool]$LockedRestore
                RestoreExitCode    = $RestoreExitCode
                TestExitCode       = $null
                BuildExitCode      = $BuildExitCode
                ArtifactsPath      = $artifactsPath
                ResponseSummary    = $ResponseSummary
            }
        }

        if (-not $PSCmdlet.ShouldProcess($target, $action)) {
            $summary = "WhatIf: would restore and compile isolated consumer for $target from feed '$Feed'."
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message $summary
            return & $newResult -GatePass $true -RestoreExitCode $null -BuildExitCode $null -ResponseSummary $summary
        }

        try {
            if ([string]::IsNullOrWhiteSpace($ProGetUrl)) {
                throw 'ProGetUrl is required to verify the requested promoted-package tier.'
            }
            $lifecycleFeeds = @(
                'nuget-experimental'
                'nuget-development'
                'nuget-integration'
                'nuget-qa'
                'nuget-stable'
            )
            if ($Feed -cnotin $lifecycleFeeds) {
                throw "Feed '$Feed' is not an approved NuGet lifecycle tier."
            }

            foreach ($directory in @($resolvedResultsPath, $consumerRoot, $tierPackagesPath)) {
                if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
                    New-Item -ItemType Directory -Path $directory -Force | Out-Null
                }
            }

            if ($LockedRestore) {
                if (-not (Test-Path -LiteralPath $consumerProjectPath -PathType Leaf)) {
                    throw "Locked promoted-package restore requires the persisted consumer project '$consumerProjectPath'."
                }
                $persistedProjectContent = Get-Content -LiteralPath $consumerProjectPath -Raw
                try {
                    [xml]$persistedProject = $persistedProjectContent
                    $primaryReference = @($persistedProject.Project.ItemGroup.PackageReference | Where-Object {
                            [string]$_.Include -ceq $Name -and [string]$_.Version -ceq $Version
                        })
                }
                catch {
                    throw "Locked promoted-package consumer project is not valid XML for '$target'."
                }
                if ($primaryReference.Count -ne 1) {
                    throw "Locked promoted-package consumer project drifted from the exact primary reference for '$target'."
                }
                $consumerProjectContent = $persistedProjectContent
                if (-not (Test-Path -LiteralPath $consumerLockPath -PathType Leaf)) {
                    throw "Locked promoted-package restore requires the persisted lock file '$consumerLockPath'."
                }
            }
            else {
                $writeConsumerProject = -not (Test-Path -LiteralPath $consumerProjectPath -PathType Leaf)
                if (-not $writeConsumerProject) {
                    $writeConsumerProject = (Get-Content -LiteralPath $consumerProjectPath -Raw) -cne $consumerProjectContent
                }
                if ($writeConsumerProject) {
                    Set-Content -LiteralPath $consumerProjectPath -Value $consumerProjectContent -Encoding utf8NoBOM -NoNewline
                }
            }

            $feedSource = "$($ProGetUrl.TrimEnd('/'))/nuget/$Feed/v3/index.json"
            $nugetConfigPath = Join-Path $WorkingDirectory 'NuGet.Config'
            if (-not (Test-Path -LiteralPath $nugetConfigPath -PathType Leaf)) {
                throw 'NuGet.Config is required to preserve configured non-lifecycle package sources.'
            }
            [xml]$nugetConfig = Get-Content -LiteralPath $nugetConfigPath -Raw
            $configuredSources = @($nugetConfig.configuration.packageSources.add)
            if (-not ($configuredSources | Where-Object { [string]$_.key -ceq $Feed } | Select-Object -First 1)) {
                throw "NuGet.Config does not define the requested lifecycle feed '$Feed'."
            }

            $restoreSources = @($feedSource)
            if ($Feed -cne 'nuget-stable') {
                $restoreSources += "$($ProGetUrl.TrimEnd('/'))/nuget/nuget-stable/v3/index.json"
            }
            foreach ($configuredSource in $configuredSources) {
                $sourceKey = [string]$configuredSource.key
                $sourceValue = [string]$configuredSource.value
                $isLifecycleSource = $sourceKey -in $lifecycleFeeds -or
                    $sourceValue -match '(?i)/nuget/nuget-(experimental|development|integration|qa|stable)/'
                if (-not $isLifecycleSource -and -not [string]::IsNullOrWhiteSpace($sourceValue)) {
                    $restoreSources += $sourceValue
                }
            }
            $restoreSources = @($restoreSources | Select-Object -Unique)

            $importIsolationProperties = @(
                '/p:ImportDirectoryBuildProps=false'
                '/p:ImportDirectoryBuildTargets=false'
                '/p:ImportDirectoryPackagesProps=false'
                '/p:ManagePackageVersionsCentrally=false'
                '/p:RestorePackagesWithLockFile=true'
                '/p:ATAPExplicitPublicationInvocation=true'
            )
            $restoreArgs = @(
                'restore'
                $consumerProjectPath
                $importIsolationProperties
                '--packages'
                $tierPackagesPath
                '--force'
                '--no-cache'
            )
            foreach ($restoreSource in $restoreSources) {
                $restoreArgs += @('--source', $restoreSource)
            }
            if ($LockedRestore) {
                $restoreArgs += '--locked-mode'
            }

            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Restoring isolated promoted-package consumer for $target from requested feed '$Feed'."
            $restoreAttempt = 0
            do {
                $restoreAttempt++
                dotnet @restoreArgs
                $restoreExitCode = $LASTEXITCODE
                if ($restoreExitCode -eq 0 -or $LockedRestore) { break }

                $nugetCachePath = Join-Path $consumerRoot 'obj\project.nuget.cache'
                $newDirectReferences = 0
                if (Test-Path -LiteralPath $nugetCachePath -PathType Leaf) {
                    try {
                        $nugetCache = Get-Content -LiteralPath $nugetCachePath -Raw | ConvertFrom-Json -Depth 20
                        foreach ($restoreLog in @($nugetCache.logs | Where-Object {
                                    [string]$_.code -ceq 'NU1102' -and [string]$_.libraryId -like 'ATAP.*'
                                })) {
                            $missingName = [string]$restoreLog.libraryId
                            $nearestMatch = [regex]::Match([string]$restoreLog.message, 'Nearest version:\s*([^\]\s]+)')
                            if (-not $nearestMatch.Success) { continue }
                            $missingVersion = $nearestMatch.Groups[1].Value
                            if (-not $directPackageReferences.Contains($missingName)) {
                                $directPackageReferences[$missingName] = $missingVersion
                                $newDirectReferences++
                            }
                        }
                    }
                    catch {
                        $newDirectReferences = 0
                    }
                }
                if ($newDirectReferences -eq 0) { break }
                $consumerProjectContent = & $newConsumerProjectContent -References $directPackageReferences
                Set-Content -LiteralPath $consumerProjectPath -Value $consumerProjectContent -Encoding utf8NoBOM -NoNewline
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Retrying isolated restore after pinning $newDirectReferences exact ATAP dependency reference(s)."
            } while ($restoreAttempt -lt 16)

            if ($restoreExitCode -ne 0) {
                $summary = "Isolated consumer restore for $target from feed '$Feed' failed (exit $restoreExitCode); compile not run."
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $summary
                return & $newResult -GatePass $false -RestoreExitCode $restoreExitCode -BuildExitCode $null -ResponseSummary $summary
            }

            $packageMetadataPath = Join-Path $tierPackagesPath $Name.ToLowerInvariant() $Version.ToLowerInvariant() '.nupkg.metadata'
            if (-not (Test-Path -LiteralPath $packageMetadataPath -PathType Leaf)) {
                $summary = "Restore completed but source metadata for promoted package $target is missing; compile not run."
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $summary
                return & $newResult -GatePass $false -RestoreExitCode $restoreExitCode -BuildExitCode $null -ResponseSummary $summary
            }
            $packageMetadata = Get-Content -LiteralPath $packageMetadataPath -Raw | ConvertFrom-Json
            $actualPackageSource = [string]$packageMetadata.source
            if ([string]::IsNullOrWhiteSpace($actualPackageSource) -or
                $actualPackageSource.TrimEnd('/') -ine $feedSource.TrimEnd('/')) {
                $summary = "Promoted package $target did not restore from requested feed '$Feed'; compile not run."
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $summary
                return & $newResult -GatePass $false -RestoreExitCode $restoreExitCode -BuildExitCode $null -ResponseSummary $summary
            }

            $buildArgs = @(
                'build'
                $consumerProjectPath
                '--configuration'
                'Release'
                '--no-restore'
                $importIsolationProperties
            )
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Compiling isolated promoted-package consumer for $target with --no-restore."
            dotnet @buildArgs
            $buildExitCode = $LASTEXITCODE
            $gatePass = $buildExitCode -eq 0
            $summary = if ($gatePass) {
                "Promoted package $target restored from feed '$Feed' and compiled in an isolated consumer (exit 0)."
            }
            else {
                "Isolated consumer compile for promoted package $target failed (exit $buildExitCode)."
            }
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level $(if ($gatePass) { 'Important' } else { 'Error' }) -Message $summary
            return & $newResult -GatePass $gatePass -RestoreExitCode $restoreExitCode -BuildExitCode $buildExitCode -ResponseSummary $summary
        }
        catch {
            $errMsg = "Failed to run isolated promoted-package consumer gate for $target against feed '$Feed': $($_.Exception.Message)"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errMsg
            throw
        }
    }

    end {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving $fn" -Tag 'Trace'
    }
}
