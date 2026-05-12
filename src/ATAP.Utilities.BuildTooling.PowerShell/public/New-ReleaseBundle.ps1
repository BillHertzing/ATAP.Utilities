#Requires -Version 7.0
<#
.SYNOPSIS
    Builds a Release Bundle `.upack` archive from a release manifest.

.DESCRIPTION
    New-ReleaseBundle reads a Release Bundle manifest, creates the documented
    bundle directory layout in an output staging directory, copies the manifest
    to the bundle root as `manifest.json`, writes the documented
    `db/db-manifest.json`, copies every referenced file from the resolved source
    roots, and packs the staging tree into a `.upack` file using
    Compress-Archive. Missing manifest-referenced payload files fail clearly so
    the produced bundle cannot silently omit bytes named by the manifest.

.PARAMETER Manifest
    The manifest JSON file produced by New-ReleaseManifest.

.PARAMETER OutputPath
    Folder where the `_staging` directory and resulting `.upack` are created.

.PARAMETER SourceRoot
    Optional source root used to resolve manifest-relative payload paths before
    inferred repo/generated roots are tried.

.OUTPUTS
    [PSCustomObject] with Path, BundleVersion, and BundleSize.
#>
function New-ReleaseBundle {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [System.IO.FileInfo]$Manifest,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [System.IO.DirectoryInfo]$OutputPath,

        [Parameter(Mandatory = $false)]
        [ValidateNotNull()]
        [System.IO.DirectoryInfo]$SourceRoot
    )

    begin {
        function Test-ManifestProperty {
            param(
                [Parameter(Mandatory = $true)] [pscustomobject]$InputObject,
                [Parameter(Mandatory = $true)] [string]$Name
            )

            return ($InputObject.PSObject.Properties.Name -contains $Name)
        }

        function Get-RequiredManifestString {
            param(
                [Parameter(Mandatory = $true)] [pscustomobject]$InputObject,
                [Parameter(Mandatory = $true)] [string]$Name
            )

            if (-not (Test-ManifestProperty -InputObject $InputObject -Name $Name)) {
                throw "Manifest is missing required field '$Name'."
            }

            $value = [string]$InputObject.PSObject.Properties[$Name].Value
            if ([string]::IsNullOrWhiteSpace($value)) {
                throw "Manifest field '$Name' must not be empty."
            }

            return $value
        }

        function Add-UniquePath {
            param(
                [System.Collections.Generic.List[string]]$List,
                [Parameter(Mandatory = $true)] [string]$Path
            )

            if ([string]::IsNullOrWhiteSpace($Path)) {
                return
            }

            $fullPath = [System.IO.Path]::GetFullPath($Path)
            foreach ($existing in $List) {
                if ([string]::Equals($existing, $fullPath, [System.StringComparison]::OrdinalIgnoreCase)) {
                    return
                }
            }

            $List.Add($fullPath)
        }

        function Resolve-UnderRoot {
            param(
                [Parameter(Mandatory = $true)] [string]$RootPath,
                [Parameter(Mandatory = $true)] [string]$RelativePath,
                [Parameter(Mandatory = $true)] [string]$Purpose
            )

            if ([string]::IsNullOrWhiteSpace($RelativePath)) {
                throw "Manifest contains an empty bundle-relative path for $Purpose."
            }

            $normalizedRelativePath = $RelativePath.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
            if ([System.IO.Path]::IsPathRooted($normalizedRelativePath)) {
                throw "Manifest path '$RelativePath' for $Purpose must be relative."
            }

            $rootFullPath = [System.IO.Path]::GetFullPath($RootPath).TrimEnd(
                [System.IO.Path]::DirectorySeparatorChar,
                [System.IO.Path]::AltDirectorySeparatorChar
            )
            $candidate = [System.IO.Path]::GetFullPath((Join-Path -Path $rootFullPath -ChildPath $normalizedRelativePath))
            $rootWithSeparator = $rootFullPath + [System.IO.Path]::DirectorySeparatorChar

            if (-not [string]::Equals($candidate, $rootFullPath, [System.StringComparison]::OrdinalIgnoreCase) -and
                -not $candidate.StartsWith($rootWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)) {
                throw "Manifest path '$RelativePath' for $Purpose escapes the allowed root '$rootFullPath'."
            }

            return $candidate
        }

        function Add-ManifestAssetPath {
            param(
                [System.Collections.Specialized.OrderedDictionary]$Paths,
                [AllowNull()] [object]$Value
            )

            if ($null -eq $Value) {
                return
            }

            $pathText = [string]$Value
            if ([string]::IsNullOrWhiteSpace($pathText)) {
                return
            }

            $key = $pathText.Replace('\', '/')
            if (-not $Paths.Contains($key)) {
                $Paths.Add($key, $pathText)
            }
        }
    }

    process {
        $manifestPath = $Manifest.FullName
        if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
            throw "Manifest file not found: '$manifestPath'."
        }
        $resolvedManifest = Get-Item -LiteralPath $manifestPath

        if ((Test-Path -LiteralPath $OutputPath.FullName -PathType Leaf)) {
            throw "OutputPath must be a folder, but a file exists at '$($OutputPath.FullName)'."
        }
        if (-not (Test-Path -LiteralPath $OutputPath.FullName -PathType Container)) {
            New-Item -ItemType Directory -Path $OutputPath.FullName -Force | Out-Null
        }
        $resolvedOutputPath = Get-Item -LiteralPath $OutputPath.FullName

        if ($PSBoundParameters.ContainsKey('SourceRoot')) {
            if (-not (Test-Path -LiteralPath $SourceRoot.FullName -PathType Container)) {
                throw "SourceRoot folder not found: '$($SourceRoot.FullName)'."
            }
        }

        $manifestObject = try {
            Get-Content -LiteralPath $resolvedManifest.FullName -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        } catch {
            throw "Unable to read release manifest JSON '$($resolvedManifest.FullName)': $($_.Exception.Message)"
        }

        if (-not (Test-ManifestProperty -InputObject $manifestObject -Name 'schemaVersion')) {
            throw "Manifest is missing required field 'schemaVersion'."
        }
        $releaseVersion = Get-RequiredManifestString -InputObject $manifestObject -Name 'releaseVersion'
        $productName = Get-RequiredManifestString -InputObject $manifestObject -Name 'appPackageId'
        if (-not (Test-ManifestProperty -InputObject $manifestObject -Name 'checksums') -or $null -eq $manifestObject.checksums) {
            throw "Manifest is missing required field 'checksums'."
        }

        $bundleVersion = $releaseVersion
        if ((Test-ManifestProperty -InputObject $manifestObject -Name 'bundleVersion') -and
            -not [string]::IsNullOrWhiteSpace([string]$manifestObject.bundleVersion)) {
            $bundleVersion = [string]$manifestObject.bundleVersion
        } elseif ($releaseVersion -notmatch '\+' -and
            (Test-ManifestProperty -InputObject $manifestObject -Name 'sourceCommit') -and
            -not [string]::IsNullOrWhiteSpace([string]$manifestObject.sourceCommit)) {
            $sourceCommit = [string]$manifestObject.sourceCommit
            $shortHashLength = [Math]::Min(7, $sourceCommit.Length)
            $bundleVersion = '{0}+{1}' -f $releaseVersion, $sourceCommit.Substring(0, $shortHashLength)
        }

        $packageBaseName = '{0}.{1}' -f $productName, $bundleVersion
        if ($packageBaseName.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars()) -ge 0) {
            throw "The package name '$packageBaseName' contains characters that are invalid for a file name."
        }

        $stagingParent = Join-Path -Path $resolvedOutputPath.FullName -ChildPath '_staging'
        $stageRoot = Join-Path -Path $stagingParent -ChildPath $packageBaseName
        $zipPath = Join-Path -Path $resolvedOutputPath.FullName -ChildPath "$packageBaseName.zip"
        $upackPath = Join-Path -Path $resolvedOutputPath.FullName -ChildPath "$packageBaseName.upack"

        if (-not $PSCmdlet.ShouldProcess($upackPath, "Create release bundle from '$($resolvedManifest.FullName)'")) {
            return [PSCustomObject]@{
                Path          = [System.IO.FileInfo]$upackPath
                BundleVersion = $bundleVersion
                BundleSize    = 0L
            }
        }

        if (Test-Path -LiteralPath $stageRoot) {
            $resolvedStageRoot = [System.IO.Path]::GetFullPath($stageRoot)
            $resolvedOutputRoot = [System.IO.Path]::GetFullPath($resolvedOutputPath.FullName).TrimEnd(
                [System.IO.Path]::DirectorySeparatorChar,
                [System.IO.Path]::AltDirectorySeparatorChar
            ) + [System.IO.Path]::DirectorySeparatorChar
            if (-not $resolvedStageRoot.StartsWith($resolvedOutputRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
                throw "Refusing to clear staging path outside OutputPath: '$stageRoot'."
            }
            Remove-Item -LiteralPath $stageRoot -Recurse -Force
        }

        foreach ($directory in @(
                $stageRoot,
                (Join-Path $stageRoot 'app'),
                (Join-Path $stageRoot 'app/bin'),
                (Join-Path $stageRoot 'app/config'),
                (Join-Path $stageRoot 'app/symbols'),
                (Join-Path $stageRoot 'db'),
                (Join-Path $stageRoot 'db/flyway'),
                (Join-Path $stageRoot 'db/seed'),
                (Join-Path $stageRoot 'installer'),
                (Join-Path $stageRoot 'tests'),
                (Join-Path $stageRoot 'docs')
            )) {
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
        }

        Copy-Item -LiteralPath $resolvedManifest.FullName -Destination (Join-Path $stageRoot 'manifest.json') -Force

        $dbManifestDestination = Join-Path $stageRoot 'db/db-manifest.json'
        $dbManifestSource = Join-Path $resolvedManifest.Directory.FullName 'db-manifest.json'
        if (Test-Path -LiteralPath $dbManifestSource -PathType Leaf) {
            Copy-Item -LiteralPath $dbManifestSource -Destination $dbManifestDestination -Force
        } else {
            $checksumMap = @{}
            foreach ($checksumProperty in $manifestObject.checksums.PSObject.Properties) {
                $checksumMap[[string]$checksumProperty.Name] = [string]$checksumProperty.Value
            }

            $dbFiles = @()
            foreach ($propertyName in @('migrationFiles', 'seedFiles', 'seedLoaderScripts')) {
                if (-not (Test-ManifestProperty -InputObject $manifestObject -Name $propertyName)) {
                    throw "Manifest is missing required field '$propertyName'."
                }

                foreach ($pathValue in @($manifestObject.PSObject.Properties[$propertyName].Value)) {
                    $bundlePath = ([string]$pathValue).Replace('\', '/')
                    if ([string]::IsNullOrWhiteSpace($bundlePath)) {
                        continue
                    }

                    $checksum = $checksumMap[$bundlePath]
                    if ([string]::IsNullOrWhiteSpace($checksum)) {
                        throw "Manifest is missing checksum for DB file '$bundlePath'."
                    }
                    if ($checksum.StartsWith('sha256:', [System.StringComparison]::OrdinalIgnoreCase)) {
                        $checksum = $checksum.Substring(7)
                    }

                    $relativeDbPath = $bundlePath -replace '^db/', ''
                    $leafName = ($relativeDbPath.Replace('\', '/') -split '/')[-1]
                    $kind = switch ($propertyName) {
                        'migrationFiles' { if ($leafName -like 'R__*') { 'repeatable' } else { 'migration' } }
                        'seedFiles' { 'seed' }
                        'seedLoaderScripts' { 'seedLoader' }
                    }

                    $dbFiles += [ordered]@{
                        path           = $relativeDbPath
                        kind           = $kind
                        checksumSha256 = $checksum
                    }
                }
            }

            $rollbackSupported = $false
            $rollbackNotes = 'Rollback guidance was not supplied in the release manifest.'
            if ((Test-ManifestProperty -InputObject $manifestObject -Name 'rollback') -and $null -ne $manifestObject.rollback) {
                if ($manifestObject.rollback.PSObject.Properties.Name -contains 'supported') {
                    $rollbackSupported = [bool]$manifestObject.rollback.supported
                }
                if ($manifestObject.rollback.PSObject.Properties.Name -contains 'notes' -and
                    -not [string]::IsNullOrWhiteSpace([string]$manifestObject.rollback.notes)) {
                    $rollbackNotes = [string]$manifestObject.rollback.notes
                }
            }

            $dbManifest = [ordered]@{
                schemaVersion       = 1
                dbChangeUnit        = Get-RequiredManifestString -InputObject $manifestObject -Name 'dbChangeUnit'
                appVersion          = Get-RequiredManifestString -InputObject $manifestObject -Name 'appPackageVersion'
                flywayTargetVersion = Get-RequiredManifestString -InputObject $manifestObject -Name 'flywayTargetVersion'
                createdUtc          = Get-RequiredManifestString -InputObject $manifestObject -Name 'buildUtc'
                createdFromGitTag   = Get-RequiredManifestString -InputObject $manifestObject -Name 'sourceTag'
                createdFromGitSha   = Get-RequiredManifestString -InputObject $manifestObject -Name 'sourceCommit'
                files               = $dbFiles
                expectedRowCounts   = [ordered]@{}
                rollbackSupported   = $rollbackSupported
                rollbackNotes       = $rollbackNotes
            }

            $dbManifest | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $dbManifestDestination -Encoding UTF8
        }

        $sourceRoots = [System.Collections.Generic.List[string]]::new()
        if ($PSBoundParameters.ContainsKey('SourceRoot')) {
            Add-UniquePath -List $sourceRoots -Path $SourceRoot.FullName
        }

        $manifestDirectory = $resolvedManifest.Directory.FullName
        $currentDirectory = $resolvedManifest.Directory
        while ($null -ne $currentDirectory) {
            if ([string]::Equals($currentDirectory.Name, '_generated', [System.StringComparison]::OrdinalIgnoreCase)) {
                if ($null -ne $currentDirectory.Parent) {
                    Add-UniquePath -List $sourceRoots -Path $currentDirectory.Parent.FullName
                }
                Add-UniquePath -List $sourceRoots -Path $currentDirectory.FullName
                break
            }
            $currentDirectory = $currentDirectory.Parent
        }
        Add-UniquePath -List $sourceRoots -Path $manifestDirectory

        $assetPaths = [ordered]@{}
        foreach ($checksumProperty in $manifestObject.checksums.PSObject.Properties) {
            Add-ManifestAssetPath -Paths $assetPaths -Value $checksumProperty.Name
        }

        foreach ($pathArrayPropertyName in @('migrationFiles', 'seedFiles', 'seedLoaderScripts', 'installerScripts')) {
            $pathArrayProperty = $manifestObject.PSObject.Properties[$pathArrayPropertyName]
            if ($null -ne $pathArrayProperty) {
                foreach ($pathValue in @($pathArrayProperty.Value)) {
                    Add-ManifestAssetPath -Paths $assetPaths -Value $pathValue
                }
            }
        }

        $testEvidenceProperty = $manifestObject.PSObject.Properties['testEvidence']
        if ($null -ne $testEvidenceProperty) {
            foreach ($testEvidence in @($testEvidenceProperty.Value)) {
                if ($null -ne $testEvidence -and ($testEvidence.PSObject.Properties.Name -contains 'path')) {
                    Add-ManifestAssetPath -Paths $assetPaths -Value $testEvidence.path
                }
            }
        }

        foreach ($assetPath in $assetPaths.Values) {
            $destination = Resolve-UnderRoot -RootPath $stageRoot -RelativePath ([string]$assetPath) -Purpose 'bundle asset'
            $source = $null

            foreach ($sourceRoot in $sourceRoots) {
                $candidate = Resolve-UnderRoot -RootPath $sourceRoot -RelativePath ([string]$assetPath) -Purpose 'source asset'
                if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                    $source = $candidate
                    break
                }
            }

            if ($null -ne $source) {
                $destinationParent = Split-Path -Parent $destination
                if (-not (Test-Path -LiteralPath $destinationParent -PathType Container)) {
                    New-Item -ItemType Directory -Path $destinationParent -Force | Out-Null
                }
                Copy-Item -LiteralPath $source -Destination $destination -Force
            } else {
                $searchedRoots = ($sourceRoots | ForEach-Object { "'$_'" }) -join ', '
                throw "Manifest references asset '$assetPath', but it was not found under any source root: $searchedRoots."
            }
        }

        if (Test-Path -LiteralPath $zipPath) {
            Remove-Item -LiteralPath $zipPath -Force
        }
        if (Test-Path -LiteralPath $upackPath) {
            Remove-Item -LiteralPath $upackPath -Force
        }

        Compress-Archive -Path (Join-Path -Path $stageRoot -ChildPath '*') -DestinationPath $zipPath -CompressionLevel Optimal -Force
        Move-Item -LiteralPath $zipPath -Destination $upackPath -Force

        $bundleFile = Get-Item -LiteralPath $upackPath
        return [PSCustomObject]@{
            Path          = $bundleFile
            BundleVersion = $bundleVersion
            BundleSize    = $bundleFile.Length
        }
    }
}
