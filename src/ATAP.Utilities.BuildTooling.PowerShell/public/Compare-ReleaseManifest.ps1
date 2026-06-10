#Requires -Version 7.0
<#
.SYNOPSIS
    Compares two release manifests and summarizes support-relevant changes.

.DESCRIPTION
    Compare-ReleaseManifest accepts parsed manifest objects or paths to
    manifest.json files. It returns a PSCustomObject that is intentionally
    readable with Format-List and highlights the differences support staff
    most often need: library package pins, Flyway migration files, and changed
    checksums.

.PARAMETER Old
    The earlier manifest as a parsed object, path string, or FileInfo.

.PARAMETER New
    The later manifest as a parsed object, path string, or FileInfo.

.OUTPUTS
    [PSCustomObject] summarizing added, removed, and changed manifest content.
#>
function Compare-ReleaseManifest {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object]$Old,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object]$New
    )

    begin {
        $fn = 'Compare-ReleaseManifest'
        $mn = 'ATAP.Utilities.BuildTooling.PowerShell'

        $ensureManifestReader = {
            if (Get-Command -Name Get-DeployedReleaseManifest -CommandType Function -ErrorAction SilentlyContinue) {
                return
            }

            $readerPath = Join-Path -Path $PSScriptRoot -ChildPath 'Get-DeployedReleaseManifest.ps1'
            if (-not (Test-Path -LiteralPath $readerPath -PathType Leaf)) {
                throw "Compare-ReleaseManifest needs Get-DeployedReleaseManifest, but '$readerPath' was not found."
            }

            . $readerPath
        }

        $resolveManifestInput = {
            param(
                [object]$InputObject,
                [string]$ParameterName
            )

            if ($InputObject -is [string]) {
                return Get-DeployedReleaseManifest -Path $InputObject
            }

            if ($InputObject -is [System.IO.FileInfo]) {
                return Get-DeployedReleaseManifest -Path $InputObject.FullName
            }

            if ($InputObject -is [System.Management.Automation.PSCustomObject]) {
                return $InputObject
            }

            if ($InputObject -is [System.Collections.IDictionary]) {
                return [PSCustomObject]$InputObject
            }

            throw "Compare-ReleaseManifest -$ParameterName expects a manifest object or a path to manifest.json. Received '$($InputObject.GetType().FullName)'."
        }

        $getRequiredProperty = {
            param(
                [pscustomobject]$Manifest,
                [string]$PropertyName,
                [string]$ManifestName
            )

            $property = $Manifest.PSObject.Properties[$PropertyName]
            if ($null -eq $property) {
                throw "The $ManifestName manifest is missing required property '$PropertyName'."
            }

            return $property.Value
        }

        $getPackageMap = {
            param(
                [pscustomobject]$Manifest,
                [string]$ManifestName
            )

            $map = @{}
            $packages = & $getRequiredProperty $Manifest 'includedLibraryPackages' $ManifestName
            foreach ($package in @($packages)) {
                if ($null -eq $package) {
                    continue
                }

                $id = [string]$package.id
                $version = [string]$package.version
                if ([string]::IsNullOrWhiteSpace($id) -or [string]::IsNullOrWhiteSpace($version)) {
                    throw "The $ManifestName manifest contains an includedLibraryPackages entry without both id and version."
                }

                $map[$id] = [PSCustomObject]@{
                    Id      = $id
                    Version = $version
                }
            }

            return $map
        }

        $getStringList = {
            param(
                [pscustomobject]$Manifest,
                [string]$PropertyName,
                [string]$ManifestName
            )

            $values = & $getRequiredProperty $Manifest $PropertyName $ManifestName
            return @($values | ForEach-Object { [string]$_ })
        }

        $getChecksumMap = {
            param(
                [pscustomobject]$Manifest,
                [string]$ManifestName
            )

            $map = @{}
            $checksums = & $getRequiredProperty $Manifest 'checksums' $ManifestName
            if ($checksums -is [System.Collections.IDictionary]) {
                foreach ($key in $checksums.Keys) {
                    $map[[string]$key] = [string]$checksums[$key]
                }

                return $map
            }

            foreach ($property in $checksums.PSObject.Properties) {
                if ($property.MemberType -in 'NoteProperty', 'Property') {
                    $map[[string]$property.Name] = [string]$property.Value
                }
            }

            return $map
        }
    }

    process {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn" -Tag 'Trace'

        & $ensureManifestReader

        $oldManifest = & $resolveManifestInput $Old 'Old'
        $newManifest = & $resolveManifestInput $New 'New'

        $oldPackages = & $getPackageMap $oldManifest 'Old'
        $newPackages = & $getPackageMap $newManifest 'New'

        $addedLibraryPackages = @(
            foreach ($key in ($newPackages.Keys | Where-Object { -not $oldPackages.ContainsKey($_) } | Sort-Object)) {
                $newPackages[$key]
            }
        )

        $removedLibraryPackages = @(
            foreach ($key in ($oldPackages.Keys | Where-Object { -not $newPackages.ContainsKey($_) } | Sort-Object)) {
                $oldPackages[$key]
            }
        )

        $changedLibraryPackages = @(
            foreach ($key in ($oldPackages.Keys | Where-Object { $newPackages.ContainsKey($_) } | Sort-Object)) {
                if ($oldPackages[$key].Version -ne $newPackages[$key].Version) {
                    [PSCustomObject]@{
                        Id         = $oldPackages[$key].Id
                        OldVersion = $oldPackages[$key].Version
                        NewVersion = $newPackages[$key].Version
                    }
                }
            }
        )

        $oldMigrationFiles = & $getStringList $oldManifest 'migrationFiles' 'Old'
        $newMigrationFiles = & $getStringList $newManifest 'migrationFiles' 'New'

        $addedMigrationFiles = @(
            foreach ($migrationFile in $newMigrationFiles) {
                if ($oldMigrationFiles -notcontains $migrationFile) {
                    $migrationFile
                }
            }
        )

        $removedMigrationFiles = @(
            foreach ($migrationFile in $oldMigrationFiles) {
                if ($newMigrationFiles -notcontains $migrationFile) {
                    $migrationFile
                }
            }
        )

        $oldChecksums = & $getChecksumMap $oldManifest 'Old'
        $newChecksums = & $getChecksumMap $newManifest 'New'

        $changedChecksums = @(
            foreach ($path in ($oldChecksums.Keys | Where-Object { $newChecksums.ContainsKey($_) } | Sort-Object)) {
                if ($oldChecksums[$path] -ne $newChecksums[$path]) {
                    [PSCustomObject]@{
                        Path        = $path
                        OldChecksum = $oldChecksums[$path]
                        NewChecksum = $newChecksums[$path]
                    }
                }
            }
        )

        $oldReleaseVersion = [string](& $getRequiredProperty $oldManifest 'releaseVersion' 'Old')
        $newReleaseVersion = [string](& $getRequiredProperty $newManifest 'releaseVersion' 'New')
        $differenceCount = $addedLibraryPackages.Count + $removedLibraryPackages.Count + $changedLibraryPackages.Count +
            $addedMigrationFiles.Count + $removedMigrationFiles.Count + $changedChecksums.Count

        $summary = "Compared release '$oldReleaseVersion' to '$newReleaseVersion': " +
            "library packages +$($addedLibraryPackages.Count) -$($removedLibraryPackages.Count) ~$($changedLibraryPackages.Count); " +
            "migration files +$($addedMigrationFiles.Count) -$($removedMigrationFiles.Count); " +
            "checksums ~$($changedChecksums.Count)."

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message $summary

        return [PSCustomObject]@{
            OperationName           = 'Compare-ReleaseManifest'
            OldReleaseVersion       = $oldReleaseVersion
            NewReleaseVersion       = $newReleaseVersion
            HasDifferences          = ($differenceCount -gt 0)
            AddedLibraryPackages    = $addedLibraryPackages
            RemovedLibraryPackages  = $removedLibraryPackages
            ChangedLibraryPackages  = $changedLibraryPackages
            AddedMigrationFiles     = $addedMigrationFiles
            RemovedMigrationFiles   = $removedMigrationFiles
            ChangedChecksums        = $changedChecksums
            ResponseSummary         = $summary
        }
    }

    end {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving $fn" -Tag 'Trace'
    }
}
