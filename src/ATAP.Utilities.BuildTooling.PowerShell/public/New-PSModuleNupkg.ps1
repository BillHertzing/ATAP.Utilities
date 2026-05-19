#Requires -Version 7.0
<#
.SYNOPSIS
    Packs a PowerShell module folder into a .nupkg on disk without
    pushing it anywhere.

.DESCRIPTION
    New-PSModuleNupkg is the "pack" half of the pack/push split for
    PowerShell modules under the immutable-build strategy. Given a module
    folder (the directory containing the module's .psd1 manifest) and an
    output folder, it produces a <ModuleName>.<Version>.nupkg file under
    the output folder and returns its [System.IO.FileInfo].

    Implementation strategy (Option 1 from V3 plan S4 G3):
        1. Register a temporary local-folder PSResourceRepository at
           `_generated/psmodules/<ModuleName>/pack-staging/` (or a sibling
           temp folder when no _generated tree exists).
        2. Call Publish-PSResource -Path <ModulePath> -Repository <temp>.
           This produces a .nupkg in the staging folder.
        3. Locate the produced .nupkg, move it to -OutputPath.
        4. In a `finally` block, unregister the temporary repository even
           if the inner Publish-PSResource fails.

    The cmdlet does NOT push anything to ProGet. The .nupkg becomes the
    handoff between the pack step and the push step (Publish-PSModuleToProGet).

    The cmdlet is idempotent: if a .nupkg with the same name already
    exists at -OutputPath, it is overwritten only with -Force; otherwise
    the existing file is returned and ResponseSummary indicates 'already
    present'.

    -WhatIf short-circuits before invoking Publish-PSResource.

.PARAMETER ModulePath
    Folder containing the module's .psd1 manifest. Must exist and contain
    at least one .psd1 file.

.PARAMETER OutputPath
    Folder where the produced .nupkg should land. Created if it does not
    exist.

.PARAMETER Force
    Overwrite an existing .nupkg at OutputPath. Without -Force, an
    existing file is treated as a no-op and returned.

.OUTPUTS
    [System.IO.FileInfo] of the .nupkg file in -OutputPath.

.EXAMPLE
    New-PSModuleNupkg `
        -ModulePath 'C:/repo/_generated/psmodules/MyModule/packages/MyModule' `
        -OutputPath 'C:/repo/_generated/psmodules/MyModule/packages-nupkg'

.NOTES
    AI assisted using Powershell.instructions.md as guidelines.
    Stream G3 of V3 plan. Pack-only; pushing is Publish-PSModuleToProGet.

.LINK
    https://github.com/whertzing/ATAP.Utilities
#>
function New-PSModuleNupkg {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([System.IO.FileInfo])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ModulePath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath,

        [switch]$Force
    )

    begin {
        $fn = 'New-PSModuleNupkg'
        $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn with ModulePath='$ModulePath' OutputPath='$OutputPath'" -Tag 'Trace'
    }

    process {
        # 1. Validate ModulePath.
        if (-not (Test-Path -LiteralPath $ModulePath -PathType Container)) {
            $msg = "ModulePath does not exist or is not a directory: '$ModulePath'"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
            throw $msg
        }
        $resolvedModulePath = (Resolve-Path -LiteralPath $ModulePath).ProviderPath

        # Find the .psd1 manifest inside ModulePath to derive the module name + version.
        $manifestFile = Get-ChildItem -LiteralPath $resolvedModulePath -Filter '*.psd1' -File -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($null -eq $manifestFile) {
            $msg = "No .psd1 manifest found in '$resolvedModulePath'."
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
            throw $msg
        }
        $moduleName = [System.IO.Path]::GetFileNameWithoutExtension($manifestFile.Name)
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Resolved module name '$moduleName' from manifest '$($manifestFile.FullName)'"

        # 2. WhatIf short-circuit before any side effect (output directory,
        #    temp repo creation, or file move).
        $resolvedOutputPath = $PSCmdlet.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
        $target = "$moduleName -> $resolvedOutputPath"
        $action = "Pack module to .nupkg via temporary local-folder PSResourceRepository"
        if (-not $PSCmdlet.ShouldProcess($target, $action)) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "WhatIf: would pack '$moduleName' from '$resolvedModulePath' to '$resolvedOutputPath'"
            return $null
        }

        # 3. Ensure OutputPath exists.
        if (-not (Test-Path -LiteralPath $OutputPath -PathType Container)) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Creating output directory '$OutputPath'"
            New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
        }
        $resolvedOutputPath = (Resolve-Path -LiteralPath $OutputPath).ProviderPath

        # 4. Idempotency check: if a .nupkg whose name starts with '<ModuleName>.'
        #    already exists in OutputPath and -Force is not specified, return it.
        $existingNupkg = Get-ChildItem -LiteralPath $resolvedOutputPath -Filter "$moduleName.*.nupkg" -File -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($null -ne $existingNupkg -and -not $Force) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "already present: '$($existingNupkg.FullName)' (use -Force to overwrite)"
            return $existingNupkg
        }

        # 5. Establish a temporary local-folder PSResourceRepository for staging.
        #    Prefer the _generated/psmodules/<ModuleName>/pack-staging/ layout
        #    when a _generated folder exists in an ancestor; otherwise use a
        #    sibling temp folder under the system temp directory.
        $stagingRoot = $null
        $cur = (Get-Item -LiteralPath $resolvedModulePath).Parent
        while ($null -ne $cur) {
            $candidate = Join-Path $cur.FullName "_generated/psmodules/$moduleName/pack-staging"
            $parentGen = Join-Path $cur.FullName '_generated'
            if (Test-Path -LiteralPath $parentGen -PathType Container) {
                $stagingRoot = $candidate
                break
            }
            $cur = $cur.Parent
        }
        if ([string]::IsNullOrWhiteSpace($stagingRoot)) {
            $stagingRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("psmodule-pack-staging-$moduleName-" + [Guid]::NewGuid().ToString('N'))
        }

        if (-not (Test-Path -LiteralPath $stagingRoot -PathType Container)) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Creating staging directory '$stagingRoot'"
            New-Item -ItemType Directory -Path $stagingRoot -Force | Out-Null
        } else {
            # Clear any leftover .nupkg files from a prior partial run to keep
            # the "produced nupkg" detection unambiguous.
            Get-ChildItem -LiteralPath $stagingRoot -Filter '*.nupkg' -File -ErrorAction SilentlyContinue |
                Remove-Item -Force -ErrorAction SilentlyContinue
        }

        $tempRepoName = "PackStaging-$moduleName-" + [Guid]::NewGuid().ToString('N').Substring(0, 8)
        $registered = $false
        $producedNupkg = $null
        try {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Registering temporary PSResourceRepository '$tempRepoName' at '$stagingRoot'"
            Register-PSResourceRepository -Name $tempRepoName -Uri $stagingRoot -Trusted
            $registered = $true

            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling Publish-PSResource for module '$moduleName' into staging repo '$tempRepoName'" -Tag 'RestCall'
            Publish-PSResource -Path $resolvedModulePath -Repository $tempRepoName -SkipDependenciesCheck
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Publish-PSResource returned successfully' -Tag 'RestCall'

            # 6. Locate the produced .nupkg in the staging folder.
            $producedNupkg = Get-ChildItem -LiteralPath $stagingRoot -Filter "$moduleName.*.nupkg" -File -ErrorAction SilentlyContinue |
                Select-Object -First 1
            if ($null -eq $producedNupkg) {
                # Fallback: any .nupkg in the staging folder.
                $producedNupkg = Get-ChildItem -LiteralPath $stagingRoot -Filter '*.nupkg' -File -ErrorAction SilentlyContinue |
                    Select-Object -First 1
            }
            if ($null -eq $producedNupkg) {
                $msg = "Publish-PSResource did not produce a .nupkg in staging folder '$stagingRoot'."
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
                throw $msg
            }

            # 7. Move the .nupkg to OutputPath.
            $destination = Join-Path $resolvedOutputPath $producedNupkg.Name
            if ((Test-Path -LiteralPath $destination -PathType Leaf) -and $Force) {
                Remove-Item -LiteralPath $destination -Force
            }
            Move-Item -LiteralPath $producedNupkg.FullName -Destination $destination -Force:$Force
            $finalNupkg = Get-Item -LiteralPath $destination
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Packed module to '$($finalNupkg.FullName)'"
            return $finalNupkg
        } finally {
            # 8. Always unregister the temporary repository, even on failure.
            if ($registered) {
                try {
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Unregistering temporary PSResourceRepository '$tempRepoName'"
                    Unregister-PSResourceRepository -Name $tempRepoName -ErrorAction SilentlyContinue
                } catch {
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Failed to unregister temporary repo '$tempRepoName': $($_.Exception.Message)"
                }
            }
        }
    }

    end {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving $fn" -Tag 'Trace'
    }
}
