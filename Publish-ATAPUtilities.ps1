#Requires -Version 7.0
<#
.SYNOPSIS
    Builds and publishes all ATAP.Utilities packages to the ProGet nuget-experimental feed.

.DESCRIPTION
    For each .csproj under src/:
      1. Deletes any stale .UpdatePackageVersion.lock file so the version is incremented on this build.
      2. Runs `dotnet build -c Release`.
    The ATAP.Utilities.BuildTooling.targets file automatically increments the version,
    packs the NuGet package, and pushes it to ProGet on every successful build.

    Requires the environment variable PROGET_ADMIN_API_KEY to be set (loaded from
    Bitwarden by the login script).

.PARAMETER ProjectFilter
    Optional glob pattern to restrict which projects are built.
    Matched against the full path of each .csproj file. Default: '*' (all projects).

.OUTPUTS
    None. Progress and summary are written via Write-PSFMessage.

.EXAMPLE
    ./Publish-ATAPUtilities.ps1

    Builds and publishes every .csproj under src/.

.EXAMPLE
    ./Publish-ATAPUtilities.ps1 -ProjectFilter '*Configuration*'

    Builds and publishes only projects whose path contains 'Configuration'.

.EXAMPLE
    ./Publish-ATAPUtilities.ps1 -WhatIf

    Dry run — shows what would be deleted and built without doing anything.

.NOTES
    AI assisted using Powershell.instructions.md as guidelines

.LINK
    https://github.com/whertzing/ATAP.Utilities
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string] $ProjectFilter = '*',

    # When set, also publishes all PowerShell modules found under src/ via their
    # module.build.ps1 Publish task. The tier is resolved from NBGV at build time.
    [switch] $IncludePowerShellModules
)

begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'Publish-ATAPUtilities'

    # Snippet: Check and populate simple parameter, substituting ProjectFilter
    $ProjectFilter = Get-PVal -ParameterName 'ProjectFilter' -originalPSBoundParameters $PSBoundParameters -dottedPath 'ProjectFilter' -DefaultValue $ProjectFilter

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Starting $fn"
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "ProjectFilter: $ProjectFilter"

    if (-not $env:PROGET_ADMIN_API_KEY) {
        $errorMessage = 'PROGET_ADMIN_API_KEY environment variable is not set. Load it from Bitwarden before running this script.'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        throw $errorMessage
    }

    $repoRoot = $PSScriptRoot
    $succeeded = [System.Collections.Generic.List[string]]::new()
    $failed = [System.Collections.Generic.List[string]]::new()
}

process {
    try {
        $allProjects = Get-ChildItem -Path (Join-Path $repoRoot 'src') -Recurse -Filter '*.csproj' |
            Where-Object { $_.FullName -like $ProjectFilter } |
            Sort-Object FullName

        if ($allProjects.Count -eq 0) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "No .csproj files matched filter '$ProjectFilter' under src/."
            return
        }

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Found $($allProjects.Count) project(s) to publish."

        foreach ($proj in $allProjects) {
            $lockFile = Join-Path $proj.DirectoryName '.UpdatePackageVersion.lock'

            if ($PSCmdlet.ShouldProcess($proj.FullName, 'Build and publish')) {
                if (Test-Path $lockFile) {
                    try {
                        Remove-Item $lockFile -Force
                        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Removed lock file: $lockFile"
                    } catch {
                        $errorMessage = "Failed to remove lock file '$lockFile'. Exception: $($_.Exception.Message)"
                        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
                        throw
                    } finally {
                        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving Function $fn in module $mn"
                    }
                }

                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Building: $($proj.Name)"

                try {
                    dotnet build $proj.FullName -c Release --ignore-failed-sources
                    if ($LASTEXITCODE -eq 0) {
                        $succeeded.Add($proj.Name)
                        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Build succeeded: $($proj.Name)"
                    } else {
                        $errorMessage = "Build failed for $($proj.Name) with exit code $LASTEXITCODE"
                        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
                        $failed.Add($proj.Name)
                    }
                } catch {
                    $errorMessage = "Exception building $($proj.Name). Exception: $($_.Exception.Message)"
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
                    $failed.Add($proj.Name)
                    throw
                } finally {
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving Function $fn in module $mn"
                }
            } else {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "WhatIf: would delete lock '$lockFile' then build '$($proj.FullName)'"
            }
        }

        # -------------------------------------------------------------------
        # PowerShell modules section
        # Iterates every module.build.ps1 under src/, resolves the current
        # 5-Tier tier from NBGV, and calls Invoke-Build Publish for each module.
        # Activated only when -IncludePowerShellModules is supplied.
        # -------------------------------------------------------------------
        if ($IncludePowerShellModules) {
            # Resolve NBGV prerelease label to tier name
            $nbgvOutput = & nbgv get-version --variable NuGetPackageVersion 2>&1
            if ($LASTEXITCODE -ne 0) {
                $errorMessage = "NBGV failed to resolve version (exit $LASTEXITCODE): $nbgvOutput"
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
                throw $errorMessage
            }
            $prereleaseLabel = if ($nbgvOutput -match '^[0-9]+\.[0-9]+\.[0-9]+-?([A-Za-z]*)') { $Matches[1] } else { '' }
            $psModuleTier = switch ($prereleaseLabel) {
                'Sprint' { 'Sprint' }
                'Alpha' { 'Alpha' }
                'Beta' { 'Beta' }
                'QA' { 'QA' }
                default { 'Production' }
            }
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message `
                "PS modules — NBGV label='$prereleaseLabel'  resolved Tier=$psModuleTier"

            # Verify Invoke-Build is available
            if (-not (Get-Command 'Invoke-Build' -ErrorAction SilentlyContinue)) {
                $errorMessage = 'Invoke-Build is not available. Install it with: Install-Module InvokeBuild -Scope CurrentUser'
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
                throw $errorMessage
            }

            # Enumerate all module roots containing a module.build.ps1
            $psModuleRoots = Get-ChildItem -Path (Join-Path $repoRoot 'src') -Recurse -Filter 'module.build.ps1' -File |
                Select-Object -ExpandProperty DirectoryName |
                Sort-Object

            if ($psModuleRoots.Count -eq 0) {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message `
                    'No module.build.ps1 files found under src/; no PowerShell modules to publish.'
            } else {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message `
                    "Found $($psModuleRoots.Count) PowerShell module(s) to publish at Tier=$psModuleTier."
            }

            foreach ($moduleRoot in $psModuleRoots) {
                $moduleBuildScript = Join-Path $moduleRoot 'module.build.ps1'
                $moduleName = Split-Path $moduleRoot -Leaf

                if ($PSCmdlet.ShouldProcess($moduleRoot, "Invoke-Build Publish -Tier $psModuleTier")) {
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message `
                        "PS modules — publishing: $moduleName"
                    try {
                        Invoke-Build -File $moduleBuildScript Publish -Tier $psModuleTier
                        $succeeded.Add($moduleName)
                        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message `
                            "PS modules — publish succeeded: $moduleName"
                    } catch {
                        $errorMessage = "Invoke-Build Publish failed for '$moduleName'. Exception: $($_.Exception.Message)"
                        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
                        $failed.Add($moduleName)
                        throw
                    }
                } else {
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message `
                        "WhatIf: would Invoke-Build Publish -Tier $psModuleTier for '$moduleRoot'"
                }
            }
        }
    } catch {
        $errorMessage = "Unhandled error in $fn. Exception: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        throw
    } finally {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving Function $fn in module $mn"
    }
}

end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Publish complete: $($succeeded.Count) succeeded, $($failed.Count) failed."

    if ($failed.Count -gt 0) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failed projects: $($failed -join ', ')"
        exit 1
    }
}
