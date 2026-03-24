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

    Requires the environment variable PROGET_ADMIN_API_TOKEN to be set (loaded from
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
    [string] $ProjectFilter = '*'
)

BEGIN {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'Publish-ATAPUtilities'

    # Snippet: Check and populate simple parameter, substituting ProjectFilter
    $ProjectFilter = Get-PVal -ParameterName 'ProjectFilter' -originalPSBoundParameters $PSBoundParameters -dottedPath 'ProjectFilter' -DefaultValue $ProjectFilter

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Starting $fn"
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "ProjectFilter: $ProjectFilter"

    if (-not $env:PROGET_ADMIN_API_TOKEN) {
        $errorMessage = 'PROGET_ADMIN_API_TOKEN environment variable is not set. Load it from Bitwarden before running this script.'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        throw $errorMessage
    }

    $repoRoot  = $PSScriptRoot
    $succeeded = [System.Collections.Generic.List[string]]::new()
    $failed    = [System.Collections.Generic.List[string]]::new()
}

PROCESS {
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
    } catch {
        $errorMessage = "Unhandled error in $fn. Exception: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        throw
    } finally {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving Function $fn in module $mn"
    }
}

END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Publish complete: $($succeeded.Count) succeeded, $($failed.Count) failed."

    if ($failed.Count -gt 0) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failed projects: $($failed -join ', ')"
        exit 1
    }
}
