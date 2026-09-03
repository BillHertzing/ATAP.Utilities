#Requires -Version 7.0
<#
.SYNOPSIS
    Creates or verifies a deterministic schema-v2 ReleaseBundle archive.
.DESCRIPTION
    Composes root upack.json identity metadata, manifest.json, and declared
    app/, installer/, tests/, and docs/ payloads only. The existing roots are
    Universal Package metacontent for this custom consumer, not package/
    content for generic upack installation. Schema v1 and embedded database
    content are rejected. ZIP entries use ordinal order, fixed timestamps, and
    fixed permission metadata.
    Every completed archive is reopened, safely extracted to a fresh path, and
    verified against payloadFiles SHA-256 and size values.
.PARAMETER Manifest
    Schema-v2 ReleaseBundle manifest.
.PARAMETER OutputPath
    Directory that receives the immutable .upack and fresh verification tree.
.PARAMETER SourceRoot
    Optional first source root for manifest-relative payloads.
.PARAMETER BundlePath
    Existing ReleaseBundle to verify without assembling it.
.PARAMETER VerificationPath
    New, nonexistent directory for safe extraction and verification.
.OUTPUTS
    PSCustomObject describing the verified ReleaseBundle.
.EXAMPLE
    New-ReleaseBundle -Manifest ./manifest.json -OutputPath ./out -SourceRoot ./publish
.EXAMPLE
    New-ReleaseBundle -BundlePath ./bundle.upack -VerificationPath ./verify
.NOTES
    Performs no feed, BuildMaster, credential, database, installation, or live action.
.LINK
    New-ReleaseManifest
.LINK
    https://docs.inedo.com/docs/proget/feeds/universal/universal-packages
#>
function New-ReleaseBundle {
    [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'Assemble')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Assemble')]
        [ValidateNotNull()]
        [System.IO.FileInfo]$Manifest,

        [Parameter(Mandatory, ParameterSetName = 'Assemble')]
        [ValidateNotNull()]
        [System.IO.DirectoryInfo]$OutputPath,

        [Parameter(ParameterSetName = 'Assemble')]
        [ValidateNotNull()]
        [System.IO.DirectoryInfo]$SourceRoot,

        [Parameter(Mandatory, ParameterSetName = 'Verify')]
        [ValidateNotNull()]
        [System.IO.FileInfo]$BundlePath,

        [Parameter(Mandatory, ParameterSetName = 'Verify')]
        [ValidateNotNull()]
        [System.IO.DirectoryInfo]$VerificationPath,

        [Parameter()]
        [ValidateNotNull()]
        [System.IO.FileInfo]$ManifestSchema
    )

    begin {
        $fn = 'New-ReleaseBundle'
        $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
        $fixedTimestamp = [DateTimeOffset]::new(2000, 1, 1, 0, 0, 0, [TimeSpan]::Zero)
        $fixedAttributes = -2119958528
        $allowedRoots = @('app', 'installer', 'tests', 'docs')
        $legacyFields = @(
            'databasePackageIncluded', 'dbChangeUnit', 'flywayTargetVersion',
            'migrationFiles', 'seedFiles', 'seedLoaderScripts', 'checksums'
        )
        $schemaPath = if ($PSBoundParameters.ContainsKey('ManifestSchema')) {
            $ManifestSchema.FullName
        } else {
            [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\SolutionDocumentation\schemas\manifest.schema.json'))
        }
        if (-not (Test-Path -LiteralPath $schemaPath -PathType Leaf)) {
            throw "ATAPBUILD014: Canonical ReleaseBundle manifest schema was not found at '$schemaPath'; supply -ManifestSchema explicitly."
        }

        function Has-Property {
            param([pscustomobject]$Object, [string]$Name)
            return $Object.PSObject.Properties.Name -contains $Name
        }

        function Get-RequiredString {
            param([pscustomobject]$Object, [string]$Name)
            if (-not (Has-Property $Object $Name)) {
                throw "ATAPBUILD014: Manifest is missing required field '$Name'."
            }
            $value = [string]$Object.PSObject.Properties[$Name].Value
            if ([string]::IsNullOrWhiteSpace($value)) {
                throw "ATAPBUILD014: Manifest field '$Name' must not be empty."
            }
            return $value
        }

        function Normalize-EntryPath {
            param([string]$Path, [string]$Purpose, [switch]$AllowMetadata)
            if ([string]::IsNullOrWhiteSpace($Path)) {
                throw "ATAPBUILD014: $Purpose path must not be empty."
            }
            $normalized = $Path.Replace('\', '/')
            if ($normalized.StartsWith('/') -or [IO.Path]::IsPathRooted($normalized) -or $normalized -match '^[A-Za-z]:') {
                throw "ATAPBUILD014: $Purpose path '$Path' must be relative."
            }
            $segments = @($normalized.Split('/'))
            if (@($segments | Where-Object { [string]::IsNullOrWhiteSpace($_) -or $_ -in @('.', '..') }).Count -gt 0) {
                throw "ATAPBUILD014: $Purpose path '$Path' contains an empty, current-directory, or traversal segment."
            }
            if ($normalized.IndexOf([char]0) -ge 0) {
                throw "ATAPBUILD014: $Purpose path '$Path' contains a null character."
            }
            foreach ($segment in $segments) {
                $stem = $segment.Split('.')[0]
                if ($segment.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0 -or
                    $segment.EndsWith('.') -or $segment.EndsWith(' ') -or
                    $stem -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$') {
                    throw "ATAPBUILD014: $Purpose path '$Path' contains a Windows-unsafe segment '$segment'."
                }
            }
            if ($AllowMetadata -and $normalized -in @('manifest.json', 'upack.json')) {
                return $normalized
            }
            if ($allowedRoots -notcontains $segments[0]) {
                throw "ATAPBUILD015: $Purpose path '$Path' is outside app/, installer/, tests/, and docs/."
            }
            if ($segments | Where-Object { $_ -in @('db', 'flyway', 'seed') }) {
                throw "ATAPBUILD015: $Purpose path '$Path' contains forbidden embedded database content."
            }
            if ($segments[-1] -ieq 'db-manifest.json') {
                throw "ATAPBUILD015: $Purpose path '$Path' contains a forbidden database side manifest."
            }
            return $normalized
        }

        function Resolve-SafePath {
            param([string]$Root, [string]$RelativePath, [string]$Purpose)
            $entryPath = Normalize-EntryPath $RelativePath $Purpose
            $rootPath = [IO.Path]::GetFullPath($Root).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
            $candidate = [IO.Path]::GetFullPath((Join-Path $rootPath $entryPath.Replace('/', [IO.Path]::DirectorySeparatorChar)))
            if (-not $candidate.StartsWith($rootPath + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
                throw "ATAPBUILD014: $Purpose path '$RelativePath' escapes '$rootPath'."
            }
            return $candidate
        }

        function Get-Hash {
            param([byte[]]$Bytes)
            return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes)).ToLowerInvariant()
        }

        function Read-Manifest {
            param([byte[]]$Bytes)
            try {
                $object = [Text.Encoding]::UTF8.GetString($Bytes) | ConvertFrom-Json -ErrorAction Stop
            } catch {
                throw "ATAPBUILD014: Unable to parse ReleaseBundle manifest JSON: $($_.Exception.Message)"
            }
            if (-not (Has-Property $object 'schemaVersion') -or [int]$object.schemaVersion -ne 2) {
                throw 'ATAPBUILD014: Ordinary ReleaseBundle paths require schemaVersion 2; v1 is rejected.'
            }
            foreach ($field in $legacyFields) {
                if (Has-Property $object $field) {
                    throw "ATAPBUILD015: Schema-v2 manifest contains forbidden legacy database field '$field'."
                }
            }
            $releaseVersion = Get-RequiredString $object 'releaseVersion'
            if (-not (Has-Property $object 'applicationProvenance') -or $null -eq $object.applicationProvenance) {
                throw "ATAPBUILD014: Manifest is missing required field 'applicationProvenance'."
            }
            $productId = Get-RequiredString $object.applicationProvenance 'productId'
            if (-not (Has-Property $object 'databasePackageReference') -or $null -eq $object.databasePackageReference) {
                throw "ATAPBUILD015: Manifest is missing required field 'databasePackageReference'."
            }
            foreach ($field in @('id', 'compatibleVersionRange', 'pinnedVersion', 'lifecycleCeiling')) {
                $null = Get-RequiredString $object.databasePackageReference $field
            }
            if (-not (Has-Property $object 'payloadFiles') -or $null -eq $object.payloadFiles) {
                throw "ATAPBUILD014: Manifest is missing required field 'payloadFiles'."
            }

            $payload = [Collections.Generic.List[object]]::new()
            $exact = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
            $folded = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
            $previous = $null
            foreach ($item in @($object.payloadFiles)) {
                $path = Normalize-EntryPath (Get-RequiredString $item 'path') 'payload'
                if (-not $exact.Add($path)) {
                    throw "ATAPBUILD014: Manifest contains duplicate payload '$path'."
                }
                if (-not $folded.Add($path)) {
                    throw "ATAPBUILD012: Manifest contains case-colliding payload '$path'."
                }
                if ($null -ne $previous -and [StringComparer]::Ordinal.Compare($previous, $path) -ge 0) {
                    throw 'ATAPBUILD014: payloadFiles must be path-sorted with ordinal comparison.'
                }
                $previous = $path
                $hash = (Get-RequiredString $item 'checksumSha256').ToLowerInvariant()
                if ($hash -notmatch '^[0-9a-f]{64}$') {
                    throw "ATAPBUILD014: Payload '$path' checksumSha256 must be 64 hexadecimal characters."
                }
                if (-not (Has-Property $item 'sizeBytes')) {
                    throw "ATAPBUILD014: Payload '$path' is missing sizeBytes."
                }
                $size = 0L
                if (-not [long]::TryParse([string]$item.sizeBytes, [Globalization.NumberStyles]::None, [Globalization.CultureInfo]::InvariantCulture, [ref]$size) -or $size -lt 0) {
                    throw "ATAPBUILD014: Payload '$path' sizeBytes must be a non-negative integer."
                }
                $payload.Add([pscustomobject]@{ Path = $path; Hash = $hash; Size = $size })
            }
            try {
                $schemaValid = [Text.Encoding]::UTF8.GetString($Bytes) | Test-Json -SchemaFile $schemaPath -ErrorAction Stop
            } catch {
                throw "ATAPBUILD014: ReleaseBundle manifest failed canonical v2 schema validation: $($_.Exception.Message)"
            }
            if (-not $schemaValid) {
                throw 'ATAPBUILD014: ReleaseBundle manifest failed canonical v2 schema validation.'
            }
            return [pscustomobject]@{ Object = $object; Version = $releaseVersion; ProductId = $productId; Payload = @($payload) }
        }

        function Assert-Payload {
            param([byte[]]$Bytes, [pscustomobject]$Payload)
            if ($Bytes.LongLength -ne $Payload.Size) {
                throw "ATAPBUILD014: Payload '$($Payload.Path)' size mismatch: manifest=$($Payload.Size), actual=$($Bytes.LongLength)."
            }
            $actual = Get-Hash $Bytes
            if ($actual -ine $Payload.Hash) {
                throw "ATAPBUILD014: Payload '$($Payload.Path)' SHA-256 mismatch: manifest=$($Payload.Hash), actual=$actual."
            }
        }

        function Get-UpackMetadataBytes {
            param([pscustomobject]$ManifestData)
            if ($ManifestData.ProductId -cnotmatch '^[A-Za-z0-9_.-]{1,50}$') {
                throw 'ATAPBUILD014: Universal Package name must contain 1-50 ASCII letters, digits, periods, underscores, or dashes.'
            }
            # The v2 schema permits some prerelease strings that SemVer2 does not.
            $semVerPattern = '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-((?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*)(?:\.(?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*))*))?(?:\+([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?$'
            if ($ManifestData.Version -cnotmatch $semVerPattern) {
                throw 'ATAPBUILD014: Universal Package version must be a valid SemVer2 version.'
            }
            $metadata = [ordered]@{ name = $ManifestData.ProductId; version = $ManifestData.Version }
            return [Text.Encoding]::UTF8.GetBytes(($metadata | ConvertTo-Json -Compress))
        }

        function Assert-UpackMetadata {
            param([byte[]]$Bytes, [pscustomobject]$ManifestData)
            try {
                $metadata = [Text.Encoding]::UTF8.GetString($Bytes) | ConvertFrom-Json -ErrorAction Stop
            } catch {
                throw "ATAPBUILD014: Unable to parse upack.json metadata: $($_.Exception.Message)"
            }
            if ($metadata -isnot [pscustomobject] -or
                -not (Has-Property $metadata 'name') -or -not (Has-Property $metadata 'version') -or
                $metadata.name -isnot [string] -or $metadata.name -cne $ManifestData.ProductId -or
                $metadata.version -isnot [string] -or $metadata.version -cne $ManifestData.Version) {
                throw 'ATAPBUILD014: upack.json name/version must exactly match the ReleaseBundle manifest identity.'
            }
            $expectedBytes = Get-UpackMetadataBytes $ManifestData
            # Exact canonical bytes also reject duplicate fields, alternate identity
            # casing, an injected group, and unapproved additional metadata.
            if ((Get-Hash $Bytes) -cne (Get-Hash $expectedBytes)) {
                throw 'ATAPBUILD014: upack.json must contain only canonical deterministic name/version metadata.'
            }
        }

        function Add-Root {
            param([Collections.Generic.List[string]]$List, [string]$Path)
            $full = [IO.Path]::GetFullPath($Path)
            if (-not ($List | Where-Object { $_ -ieq $full })) {
                $List.Add($full)
            }
        }

        function Write-Archive {
            param([string]$Path, [Collections.IDictionary]$Entries)
            Add-Type -AssemblyName System.IO.Compression
            $file = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
            try {
                $zip = [IO.Compression.ZipArchive]::new($file, [IO.Compression.ZipArchiveMode]::Create, $true, [Text.Encoding]::UTF8)
                try {
                    $names = [string[]]@($Entries.Keys)
                    [Array]::Sort($names, [StringComparer]::Ordinal)
                    foreach ($name in $names) {
                        $entry = $zip.CreateEntry($name, [IO.Compression.CompressionLevel]::Optimal)
                        $entry.LastWriteTime = $fixedTimestamp
                        $entry.ExternalAttributes = [int]$fixedAttributes
                        $target = $entry.Open()
                        try {
                            $bytes = [byte[]]$Entries[$name]
                            $target.Write($bytes, 0, $bytes.Length)
                        } finally {
                            $target.Dispose()
                        }
                    }
                } finally {
                    $zip.Dispose()
                }
            } finally {
                $file.Dispose()
            }
        }

        function Verify-Archive {
            param([string]$Path, [string]$ExtractPath)
            if (Test-Path -LiteralPath $ExtractPath) {
                throw "ATAPBUILD014: VerificationPath must be fresh and nonexistent: '$ExtractPath'."
            }
            New-Item -ItemType Directory -Path $ExtractPath -Force | Out-Null
            Add-Type -AssemblyName System.IO.Compression
            $file = [IO.File]::OpenRead($Path)
            try {
                $zip = [IO.Compression.ZipArchive]::new($file, [IO.Compression.ZipArchiveMode]::Read, $true, [Text.Encoding]::UTF8)
                try {
                    $entries = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
                    $folded = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
                    $order = [Collections.Generic.List[string]]::new()
                    foreach ($entry in $zip.Entries) {
                        if ([string]::IsNullOrEmpty($entry.Name)) {
                            throw "ATAPBUILD014: Archive contains unexpected directory entry '$($entry.FullName)'."
                        }
                        $name = Normalize-EntryPath $entry.FullName 'archive entry' -AllowMetadata
                        if (-not $entries.TryAdd($name, $entry)) {
                            throw "ATAPBUILD014: Archive contains duplicate entry '$name'."
                        }
                        if (-not $folded.Add($name)) {
                            throw "ATAPBUILD012: Archive contains case-colliding entry '$name'."
                        }
                        if ($entry.LastWriteTime.DateTime -ne $fixedTimestamp.DateTime) {
                            throw "ATAPBUILD016: Archive entry '$name' has a nondeterministic timestamp."
                        }
                        if ([int]$entry.ExternalAttributes -ne [int]$fixedAttributes) {
                            throw "ATAPBUILD016: Archive entry '$name' has nondeterministic permission metadata."
                        }
                        $order.Add($name)
                    }
                    $sorted = [string[]]@($order)
                    [Array]::Sort($sorted, [StringComparer]::Ordinal)
                    if (-not $entries.ContainsKey('manifest.json')) {
                        throw "ATAPBUILD014: Archive is missing 'manifest.json'."
                    }
                    $memory = [IO.MemoryStream]::new()
                    $manifestStream = $entries['manifest.json'].Open()
                    try {
                        $manifestStream.CopyTo($memory)
                    } finally {
                        $manifestStream.Dispose()
                    }
                    $manifestData = Read-Manifest $memory.ToArray()
                    $memory.Dispose()

                    if (-not $entries.ContainsKey('upack.json')) {
                        throw "ATAPBUILD014: Archive is missing 'upack.json'."
                    }
                    $metadataMemory = [IO.MemoryStream]::new()
                    $metadataStream = $entries['upack.json'].Open()
                    try {
                        $metadataStream.CopyTo($metadataMemory)
                        Assert-UpackMetadata $metadataMemory.ToArray() $manifestData
                    } finally {
                        $metadataStream.Dispose()
                        $metadataMemory.Dispose()
                    }

                    $expected = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
                    $null = $expected.Add('manifest.json')
                    $null = $expected.Add('upack.json')
                    foreach ($payload in $manifestData.Payload) {
                        $null = $expected.Add($payload.Path)
                    }
                    foreach ($name in $entries.Keys) {
                        if (-not $expected.Contains($name)) {
                            throw "ATAPBUILD014: Archive contains unexpected entry '$name'."
                        }
                    }
                    foreach ($name in $expected) {
                        if (-not $entries.ContainsKey($name)) {
                            throw "ATAPBUILD014: Archive is missing manifest-declared entry '$name'."
                        }
                    }
                    foreach ($payload in $manifestData.Payload) {
                        if ([long]$entries[$payload.Path].Length -ne [long]$payload.Size) {
                            throw "ATAPBUILD014: Payload '$($payload.Path)' size mismatch: manifest=$($payload.Size), archive=$($entries[$payload.Path].Length)."
                        }
                    }
                    foreach ($name in $sorted) {
                        $destination = if ($name -cin @('manifest.json', 'upack.json')) {
                            Join-Path $ExtractPath $name
                        } else {
                            Resolve-SafePath $ExtractPath $name 'extraction'
                        }
                        $parent = Split-Path -Parent $destination
                        if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
                            New-Item -ItemType Directory -Path $parent -Force | Out-Null
                        }
                        $source = $entries[$name].Open()
                        $target = [IO.File]::Open($destination, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
                        try {
                            $source.CopyTo($target)
                        } finally {
                            $target.Dispose()
                            $source.Dispose()
                        }
                    }
                } finally {
                    $zip.Dispose()
                }
            } finally {
                $file.Dispose()
            }

            $actual = [string[]]@(Get-ChildItem -LiteralPath $ExtractPath -Recurse -File | ForEach-Object {
                    [IO.Path]::GetRelativePath($ExtractPath, $_.FullName).Replace('\', '/')
                })
            [Array]::Sort($actual, [StringComparer]::Ordinal)
            $expectedNames = [string[]](@('manifest.json', 'upack.json') + @($manifestData.Payload.Path))
            [Array]::Sort($expectedNames, [StringComparer]::Ordinal)
            if (($actual -join [Environment]::NewLine) -cne ($expectedNames -join [Environment]::NewLine)) {
                throw 'ATAPBUILD014: Fresh extraction contains missing or unexpected files.'
            }
            foreach ($payload in $manifestData.Payload) {
                $payloadPath = Resolve-SafePath $ExtractPath $payload.Path 'verification'
                Assert-Payload ([IO.File]::ReadAllBytes($payloadPath)) $payload
            }
            if (($order -join [Environment]::NewLine) -cne ($sorted -join [Environment]::NewLine)) {
                throw 'ATAPBUILD016: Archive entries are not in deterministic ordinal order.'
            }

            $bundle = Get-Item -LiteralPath $Path
            return [pscustomobject]@{
                Path = $bundle
                BundleVersion = $manifestData.Version
                ProductId = $manifestData.ProductId
                BundleSize = $bundle.Length
                BundleSha256 = (Get-FileHash -LiteralPath $bundle.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
                VerifiedEntryCount = $expectedNames.Count
                VerificationPath = Get-Item -LiteralPath $ExtractPath
            }
        }
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'Verify') {
            if (-not (Test-Path -LiteralPath $BundlePath.FullName -PathType Leaf)) {
                throw "Bundle file not found: '$($BundlePath.FullName)'."
            }
            if (-not $PSCmdlet.ShouldProcess($VerificationPath.FullName, "Fresh-extract and verify '$($BundlePath.FullName)'")) {
                return
            }
            return Verify-Archive $BundlePath.FullName $VerificationPath.FullName
        }

        if (-not (Test-Path -LiteralPath $Manifest.FullName -PathType Leaf)) {
            throw "Manifest file not found: '$($Manifest.FullName)'."
        }
        if ((Test-Path -LiteralPath $OutputPath.FullName -PathType Leaf)) {
            throw "OutputPath must be a directory, but a file exists at '$($OutputPath.FullName)'."
        }

        if ($PSBoundParameters.ContainsKey('SourceRoot') -and -not (Test-Path -LiteralPath $SourceRoot.FullName -PathType Container)) {
            throw "SourceRoot directory not found: '$($SourceRoot.FullName)'."
        }

        $manifestBytes = [IO.File]::ReadAllBytes((Get-Item -LiteralPath $Manifest.FullName).FullName)
        $manifestData = Read-Manifest $manifestBytes
        $upackBytes = Get-UpackMetadataBytes $manifestData
        $baseName = '{0}.{1}' -f $manifestData.ProductId, $manifestData.Version
        if ($baseName.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0) {
            throw "ATAPBUILD014: Bundle identity '$baseName' contains invalid file-name characters."
        }
        $archivePath = Join-Path $OutputPath.FullName "$baseName.upack"
        if (Test-Path -LiteralPath $archivePath) {
            throw "ATAPBUILD016: Refusing to overwrite immutable ReleaseBundle '$archivePath'."
        }
        if (-not $PSCmdlet.ShouldProcess($archivePath, "Create deterministic ReleaseBundle from '$($Manifest.FullName)'")) {
            return [pscustomobject]@{ Path = [IO.FileInfo]$archivePath; BundleVersion = $manifestData.Version; BundleSize = 0L }
        }
        if (-not (Test-Path -LiteralPath $OutputPath.FullName -PathType Container)) {
            New-Item -ItemType Directory -Path $OutputPath.FullName -Force | Out-Null
        }

        $roots = [Collections.Generic.List[string]]::new()
        if ($PSBoundParameters.ContainsKey('SourceRoot')) {
            Add-Root $roots $SourceRoot.FullName
        }
        Add-Root $roots $Manifest.Directory.FullName
        $cursor = $Manifest.Directory
        while ($null -ne $cursor) {
            if ($cursor.Name -ieq '_generated') {
                if ($null -ne $cursor.Parent) {
                    Add-Root $roots $cursor.Parent.FullName
                }
                Add-Root $roots $cursor.FullName
                break
            }
            $cursor = $cursor.Parent
        }

        $bytesByEntry = [Collections.Specialized.OrderedDictionary]::new([StringComparer]::Ordinal)
        $bytesByEntry.Add('manifest.json', $manifestBytes)
        $bytesByEntry.Add('upack.json', $upackBytes)
        foreach ($payload in $manifestData.Payload) {
            $sourcePath = $null
            foreach ($root in $roots) {
                $candidate = Resolve-SafePath $root $payload.Path 'source payload'
                if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                    $sourcePath = $candidate
                    break
                }
            }
            if ($null -eq $sourcePath) {
                throw "ATAPBUILD014: Payload '$($payload.Path)' was not found under any source root."
            }
            $bytes = [IO.File]::ReadAllBytes($sourcePath)
            Assert-Payload $bytes $payload
            $bytesByEntry.Add($payload.Path, $bytes)
        }

        Write-Archive $archivePath $bytesByEntry
        $verifyPath = Join-Path $OutputPath.FullName ('_verification/{0}.{1}' -f $baseName, [Guid]::NewGuid().ToString('N'))
        return Verify-Archive $archivePath $verifyPath
    }

    end {
    }
}
