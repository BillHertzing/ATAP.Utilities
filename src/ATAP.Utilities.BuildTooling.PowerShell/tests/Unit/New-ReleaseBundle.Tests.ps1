#Requires -Version 7.0
# Pester 5+ tests for deterministic schema-v2 ReleaseBundle assembly.

BeforeAll {
    $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $publicDir = Join-Path $moduleRoot 'public'
    $fixturesDir = Join-Path $moduleRoot 'tests/fixtures/New-ReleaseBundle'
    . (Join-Path $publicDir 'New-ReleaseBundle.ps1')

    $script:fixtureManifest = Join-Path $fixturesDir 'manifest/manifest.json'
    $script:fixtureSourceRoot = Join-Path $fixturesDir 'source'
    $script:fixedTimestamp = [DateTimeOffset]::new(2000, 1, 1, 0, 0, 0, [TimeSpan]::Zero)
    $script:fixedAttributes = -2119958528
    $script:fixtureOutputRoot = [IO.Path]::GetFullPath((Join-Path $moduleRoot '../../_generated/Sprint0015/Task15.185/COMMANDER02-release-repair/bundle-compatibility/fixtures'))

    function Copy-TestManifest {
        param(
            [Parameter(Mandatory)] [string]$Destination,
            [Parameter(Mandatory)] [scriptblock]$Mutate
        )
        $object = Get-Content -LiteralPath $script:fixtureManifest -Raw | ConvertFrom-Json
        & $Mutate $object
        $object | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $Destination -Encoding utf8NoBOM
        return $Destination
    }

    function Add-TestArchiveEntry {
        param(
            [Parameter(Mandatory)] [string]$ArchivePath,
            [Parameter(Mandatory)] [string]$EntryName,
            [Parameter(Mandatory)] [byte[]]$Bytes
        )
        Add-Type -AssemblyName System.IO.Compression
        $stream = [IO.File]::Open($ArchivePath, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
        try {
            $archive = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Update, $true, [Text.Encoding]::UTF8)
            try {
                $entry = $archive.CreateEntry($EntryName, [IO.Compression.CompressionLevel]::Optimal)
                $entry.LastWriteTime = $script:fixedTimestamp
                $entry.ExternalAttributes = $script:fixedAttributes
                $target = $entry.Open()
                try {
                    $target.Write($Bytes, 0, $Bytes.Length)
                } finally {
                    $target.Dispose()
                }
            } finally {
                $archive.Dispose()
            }
        } finally {
            $stream.Dispose()
        }
    }

    function Replace-TestArchiveEntry {
        param(
            [Parameter(Mandatory)] [string]$ArchivePath,
            [Parameter(Mandatory)] [string]$EntryName,
            [Parameter(Mandatory)] [byte[]]$Bytes
        )
        Add-Type -AssemblyName System.IO.Compression
        $stream = [IO.File]::Open($ArchivePath, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
        try {
            $archive = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Update, $true, [Text.Encoding]::UTF8)
            try {
                $existing = $archive.GetEntry($EntryName)
                if ($null -eq $existing) {
                    throw "Test setup could not find '$EntryName'."
                }
                $existing.Delete()
                $entry = $archive.CreateEntry($EntryName, [IO.Compression.CompressionLevel]::Optimal)
                $entry.LastWriteTime = $script:fixedTimestamp
                $entry.ExternalAttributes = $script:fixedAttributes
                $target = $entry.Open()
                try {
                    $target.Write($Bytes, 0, $Bytes.Length)
                } finally {
                    $target.Dispose()
                }
            } finally {
                $archive.Dispose()
            }
        } finally {
            $stream.Dispose()
        }
    }

    function Remove-TestArchiveEntry {
        param([string]$ArchivePath, [string]$EntryName)
        $archive = [IO.Compression.ZipFile]::Open($ArchivePath, [IO.Compression.ZipArchiveMode]::Update)
        try {
            $archive.GetEntry($EntryName).Delete()
        } finally {
            $archive.Dispose()
        }
    }
}

Describe 'New-ReleaseBundle deterministic schema-v2 contract' -Tag 'Unit' {
    BeforeEach {
        $script:tempRoot = Join-Path $script:fixtureOutputRoot ('NewReleaseBundle_' + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:tempRoot -Force | Out-Null
    }

    AfterEach {
        if ($script:tempRoot -and (Test-Path -LiteralPath $script:tempRoot)) {
            $resolvedTarget = [IO.Path]::GetFullPath($script:tempRoot)
            if (-not $resolvedTarget.StartsWith($script:fixtureOutputRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
                throw 'Test cleanup target escaped its generated fixture root.'
            }
            Remove-Item -LiteralPath $script:tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'assembles identical bytes twice with exact ordered metadata and no database entries' {
        $firstOutput = Join-Path $script:tempRoot 'first'
        $secondOutput = Join-Path $script:tempRoot 'second'

        $first = New-ReleaseBundle -Manifest $script:fixtureManifest -OutputPath $firstOutput -SourceRoot $script:fixtureSourceRoot
        $second = New-ReleaseBundle -Manifest $script:fixtureManifest -OutputPath $secondOutput -SourceRoot $script:fixtureSourceRoot

        $first.BundleSha256 | Should -Be $second.BundleSha256
        [IO.File]::ReadAllBytes($first.Path.FullName) | Should -Be ([IO.File]::ReadAllBytes($second.Path.FullName))
        $first.VerifiedEntryCount | Should -Be 6
        $first.BundleVersion | Should -Be '1.4.0'
        $first.ProductId | Should -Be 'AceCommander'
        $first.VerificationPath.Exists | Should -BeTrue

        Add-Type -AssemblyName System.IO.Compression
        $archive = [IO.Compression.ZipFile]::OpenRead($first.Path.FullName)
        try {
            $names = @($archive.Entries.FullName)
            $names | Should -Be @(
                'app/config/appsettings.template.json',
                'docs/RELEASE_NOTES.md',
                'installer/Install-Application.ps1',
                'manifest.json',
                'tests/unit-results.trx',
                'upack.json'
            )
            @($names | Where-Object { $_ -like 'package/*' }).Count | Should -Be 0
            @($names | Where-Object { $_ -match '(?i)(^|/)db(/|$)|flyway|(^|/)seed(/|$)|db-manifest\.json' }).Count | Should -Be 0
            foreach ($entry in $archive.Entries) {
                $entry.LastWriteTime.DateTime | Should -Be $script:fixedTimestamp.DateTime
                $entry.ExternalAttributes | Should -Be $script:fixedAttributes
            }
        } finally {
            $archive.Dispose()
        }
        $metadataPath = Join-Path $first.VerificationPath.FullName 'upack.json'
        [IO.File]::ReadAllText($metadataPath) | Should -BeExactly '{"name":"AceCommander","version":"1.4.0"}'
        $metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
        $metadata.name | Should -BeExactly $first.ProductId
        $metadata.version | Should -BeExactly $first.BundleVersion
        [IO.File]::ReadAllBytes((Join-Path $first.VerificationPath.FullName 'manifest.json')) |
            Should -Be ([IO.File]::ReadAllBytes($script:fixtureManifest))
    }

    It 'uses ordinal archive order and identical bytes independently of current culture' {
        $source = Join-Path $script:tempRoot 'source'
        Copy-Item -LiteralPath $script:fixtureSourceRoot -Destination $source -Recurse
        $extraPayload = foreach ($name in @('Z.txt', 'a.txt')) {
            $path = Join-Path $source "app/$name"
            [IO.File]::WriteAllText($path, $name, [Text.UTF8Encoding]::new($false))
            [pscustomobject]@{
                path = "app/$name"
                checksumSha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
                sizeBytes = (Get-Item -LiteralPath $path).Length
            }
        }
        $manifest = Copy-TestManifest (Join-Path $script:tempRoot 'ordinal.json') {
            param($m)
            $allPayload = @($m.payloadFiles) + @($extraPayload)
            $names = [string[]]@($allPayload.path)
            [Array]::Sort($names, [StringComparer]::Ordinal)
            $m.payloadFiles = @($names | ForEach-Object { $name = $_; $allPayload | Where-Object path -CEQ $name })
        }
        $originalCulture = [Globalization.CultureInfo]::CurrentCulture
        try {
            [Globalization.CultureInfo]::CurrentCulture = [Globalization.CultureInfo]::GetCultureInfo('en-US')
            $first = New-ReleaseBundle -Manifest $manifest -OutputPath (Join-Path $script:tempRoot 'en') -SourceRoot $source
            [Globalization.CultureInfo]::CurrentCulture = [Globalization.CultureInfo]::GetCultureInfo('tr-TR')
            $second = New-ReleaseBundle -Manifest $manifest -OutputPath (Join-Path $script:tempRoot 'tr') -SourceRoot $source
        } finally {
            [Globalization.CultureInfo]::CurrentCulture = $originalCulture
        }
        $first.BundleSha256 | Should -BeExactly $second.BundleSha256
        $archive = [IO.Compression.ZipFile]::OpenRead($first.Path.FullName)
        try {
            $names = [string[]]@($archive.Entries.FullName)
            $expected = [string[]]$names.Clone()
            [Array]::Sort($expected, [StringComparer]::Ordinal)
            $names | Should -Be $expected
            $names[0] | Should -BeExactly 'app/Z.txt'
        } finally {
            $archive.Dispose()
        }
    }

    It 'rejects missing root upack.json before extracting payloads' {
        $built = New-ReleaseBundle -Manifest $script:fixtureManifest -OutputPath (Join-Path $script:tempRoot 'out') -SourceRoot $script:fixtureSourceRoot
        Remove-TestArchiveEntry $built.Path.FullName 'upack.json'
        $verification = Join-Path $script:tempRoot 'verify-missing'
        { New-ReleaseBundle -BundlePath $built.Path.FullName -VerificationPath $verification } |
            Should -Throw -ExpectedMessage "*missing 'upack.json'*"
        @(Get-ChildItem -LiteralPath $verification -Recurse -File).Count | Should -Be 0
    }

    It 'rejects <Label> upack identity metadata before extracting payloads' -ForEach @(
        @{ Label = 'changed name'; Json = '{"name":"OtherProduct","version":"1.4.0"}'; ExpectedError = '*must exactly match*' },
        @{ Label = 'changed name casing'; Json = '{"name":"acecommander","version":"1.4.0"}'; ExpectedError = '*must exactly match*' },
        @{ Label = 'changed version'; Json = '{"name":"AceCommander","version":"1.4.1"}'; ExpectedError = '*must exactly match*' },
        @{ Label = 'missing name'; Json = '{"version":"1.4.0"}'; ExpectedError = '*must exactly match*' },
        @{ Label = 'missing version'; Json = '{"name":"AceCommander"}'; ExpectedError = '*must exactly match*' },
        @{ Label = 'nonstring version'; Json = '{"name":"AceCommander","version":1}'; ExpectedError = '*must exactly match*' },
        @{ Label = 'null root'; Json = 'null'; ExpectedError = '*must exactly match*' },
        @{ Label = 'malformed JSON'; Json = '{'; ExpectedError = '*Unable to parse upack.json*' },
        @{ Label = 'duplicate identity field'; Json = '{"name":"OtherProduct","name":"AceCommander","version":"1.4.0"}'; ExpectedError = '*canonical deterministic*' },
        @{ Label = 'injected group'; Json = '{"name":"AceCommander","version":"1.4.0","group":"other"}'; ExpectedError = '*canonical deterministic*' },
        @{ Label = 'unapproved field'; Json = '{"name":"AceCommander","version":"1.4.0","createdDate":"2026-09-03"}'; ExpectedError = '*canonical deterministic*' }
    ) {
        $built = New-ReleaseBundle -Manifest $script:fixtureManifest -OutputPath (Join-Path $script:tempRoot 'out') -SourceRoot $script:fixtureSourceRoot
        Replace-TestArchiveEntry $built.Path.FullName 'upack.json' ([Text.Encoding]::UTF8.GetBytes($Json))
        $verification = Join-Path $script:tempRoot 'verify-metadata'
        { New-ReleaseBundle -BundlePath $built.Path.FullName -VerificationPath $verification } |
            Should -Throw -ExpectedMessage $ExpectedError
        @(Get-ChildItem -LiteralPath $verification -Recurse -File).Count | Should -Be 0
    }

    It 'rejects <EntryName> metadata archive collision' -ForEach @(
        @{ EntryName = 'upack.json'; ExpectedError = '*duplicate entry*' },
        @{ EntryName = 'UPACK.JSON'; ExpectedError = '*case-colliding entry*' }
    ) {
        $built = New-ReleaseBundle -Manifest $script:fixtureManifest -OutputPath (Join-Path $script:tempRoot 'out') -SourceRoot $script:fixtureSourceRoot
        Add-TestArchiveEntry $built.Path.FullName $EntryName ([Text.Encoding]::UTF8.GetBytes('{"name":"AceCommander","version":"1.4.0"}'))
        { New-ReleaseBundle -BundlePath $built.Path.FullName -VerificationPath (Join-Path $script:tempRoot 'verify-collision') } |
            Should -Throw -ExpectedMessage $ExpectedError
    }

    It 'reports missing metadata identity under caller StrictMode without a property-access error' {
        $built = New-ReleaseBundle -Manifest $script:fixtureManifest -OutputPath (Join-Path $script:tempRoot 'out') -SourceRoot $script:fixtureSourceRoot
        Replace-TestArchiveEntry $built.Path.FullName 'upack.json' ([Text.Encoding]::UTF8.GetBytes('{"version":"1.4.0"}'))
        {
            Set-StrictMode -Version Latest
            New-ReleaseBundle -BundlePath $built.Path.FullName -VerificationPath (Join-Path $script:tempRoot 'verify-strict')
        } | Should -Throw -ExpectedMessage '*upack.json name/version must exactly match*'
    }

    It 'rejects a product name longer than the Universal Package limit before writing output' {
        $bad = Copy-TestManifest (Join-Path $script:tempRoot 'long-name.json') {
            param($m)
            $m.applicationProvenance.productId = 'A' * 51
        }
        $output = Join-Path $script:tempRoot 'out'
        { New-ReleaseBundle -Manifest $bad -OutputPath $output -SourceRoot $script:fixtureSourceRoot } |
            Should -Throw -ExpectedMessage '*Universal Package name*1-50*'
        Test-Path -LiteralPath $output | Should -BeFalse
    }

    It 'rejects schema-permitted but invalid SemVer2 version <Version>' -ForEach @(
        @{ Version = '1.4.0-01' },
        @{ Version = '1.4.0-alpha..1' },
        @{ Version = '1.4.0+build..1' }
    ) {
        $bad = Copy-TestManifest (Join-Path $script:tempRoot 'invalid-version.json') {
            param($m)
            $m.releaseVersion = $Version
        }
        { New-ReleaseBundle -Manifest $bad -OutputPath (Join-Path $script:tempRoot 'out') -SourceRoot $script:fixtureSourceRoot } |
            Should -Throw -ExpectedMessage '*Universal Package version*SemVer2*'
    }

    It 'preserves valid SemVer2 prerelease and build metadata without normalization' {
        $manifest = Copy-TestManifest (Join-Path $script:tempRoot 'prerelease.json') {
            param($m)
            $m.releaseVersion = '1.4.0-rc.0+build.01'
            $m.applicationProvenance.productId = 'A' * 50
        }
        $built = New-ReleaseBundle -Manifest $manifest -OutputPath (Join-Path $script:tempRoot 'out') -SourceRoot $script:fixtureSourceRoot
        $metadata = Get-Content -LiteralPath (Join-Path $built.VerificationPath.FullName 'upack.json') -Raw | ConvertFrom-Json
        $metadata.name.Length | Should -Be 50
        $metadata.version | Should -BeExactly '1.4.0-rc.0+build.01'
    }

    It 'refuses to verify into an existing extraction directory' {
        $built = New-ReleaseBundle -Manifest $script:fixtureManifest -OutputPath (Join-Path $script:tempRoot 'out') -SourceRoot $script:fixtureSourceRoot
        { New-ReleaseBundle -BundlePath $built.Path.FullName -VerificationPath $built.VerificationPath.FullName } |
            Should -Throw -ExpectedMessage '*must be fresh and nonexistent*'
    }

    It 'does not create output when WhatIf declines assembly' {
        $output = Join-Path $script:tempRoot 'whatif-output'
        $result = New-ReleaseBundle -Manifest $script:fixtureManifest -OutputPath $output -SourceRoot $script:fixtureSourceRoot -WhatIf

        $result.BundleSize | Should -Be 0
        Test-Path -LiteralPath $output | Should -BeFalse
    }

    It 'rejects schema v1 on the ordinary assembly path' {
        $bad = Copy-TestManifest (Join-Path $script:tempRoot 'v1.json') { param($m) $m.schemaVersion = 1 }
        { New-ReleaseBundle -Manifest $bad -OutputPath (Join-Path $script:tempRoot 'out') -SourceRoot $script:fixtureSourceRoot } |
            Should -Throw -ExpectedMessage '*schemaVersion 2*v1 is rejected*'
    }

    It 'rejects a schema-v2 manifest missing a canonical top-level field' {
        $bad = Copy-TestManifest (Join-Path $script:tempRoot 'missing-source-tag.json') {
            param($m)
            $m.PSObject.Properties.Remove('sourceTag')
        }
        { New-ReleaseBundle -Manifest $bad -OutputPath (Join-Path $script:tempRoot 'out') -SourceRoot $script:fixtureSourceRoot } |
            Should -Throw -ExpectedMessage '*failed canonical v2 schema validation*'
    }

    It 'rejects legacy embedded database fields even when schemaVersion is 2' {
        $bad = Copy-TestManifest (Join-Path $script:tempRoot 'db.json') {
            param($m)
            $m | Add-Member -NotePropertyName migrationFiles -NotePropertyValue @('db/flyway/V1.sql')
        }
        { New-ReleaseBundle -Manifest $bad -OutputPath (Join-Path $script:tempRoot 'out') -SourceRoot $script:fixtureSourceRoot } |
            Should -Throw -ExpectedMessage "*forbidden legacy database field 'migrationFiles'*"
    }

    It 'rejects payload traversal before reading source bytes' {
        $bad = Copy-TestManifest (Join-Path $script:tempRoot 'traversal.json') {
            param($m)
            $m.payloadFiles[0].path = '../outside.txt'
        }
        { New-ReleaseBundle -Manifest $bad -OutputPath (Join-Path $script:tempRoot 'out') -SourceRoot $script:fixtureSourceRoot } |
            Should -Throw -ExpectedMessage '*traversal segment*'
    }

    It 'rejects Windows alternate-data-stream payload syntax' {
        $bad = Copy-TestManifest (Join-Path $script:tempRoot 'ads.json') {
            param($m)
            $m.payloadFiles[0].path = 'app/config/appsettings.json:secret'
        }
        { New-ReleaseBundle -Manifest $bad -OutputPath (Join-Path $script:tempRoot 'out') -SourceRoot $script:fixtureSourceRoot } |
            Should -Throw -ExpectedMessage '*Windows-unsafe segment*'
    }

    It 'rejects case-colliding payload paths' {
        $bad = Copy-TestManifest (Join-Path $script:tempRoot 'collision.json') {
            param($m)
            $copy = $m.payloadFiles[1].PSObject.Copy()
            $copy.path = 'DOCS/RELEASE_NOTES.md'
            $m.payloadFiles = @($copy) + @($m.payloadFiles)
        }
        { New-ReleaseBundle -Manifest $bad -OutputPath (Join-Path $script:tempRoot 'out') -SourceRoot $script:fixtureSourceRoot } |
            Should -Throw -ExpectedMessage '*case-colliding payload*'
    }

    It 'rejects manifest size drift before assembly' {
        $bad = Copy-TestManifest (Join-Path $script:tempRoot 'size.json') {
            param($m)
            $m.payloadFiles[0].sizeBytes = [long]$m.payloadFiles[0].sizeBytes + 1
        }
        { New-ReleaseBundle -Manifest $bad -OutputPath (Join-Path $script:tempRoot 'out') -SourceRoot $script:fixtureSourceRoot } |
            Should -Throw -ExpectedMessage '*size mismatch*'
    }

    It 'rejects manifest hash drift before assembly' {
        $bad = Copy-TestManifest (Join-Path $script:tempRoot 'hash.json') {
            param($m)
            $m.payloadFiles[0].checksumSha256 = '0' * 64
        }
        { New-ReleaseBundle -Manifest $bad -OutputPath (Join-Path $script:tempRoot 'out') -SourceRoot $script:fixtureSourceRoot } |
            Should -Throw -ExpectedMessage '*SHA-256 mismatch*'
    }

    It 'rejects an unexpected archive entry during fresh verification' {
        $built = New-ReleaseBundle -Manifest $script:fixtureManifest -OutputPath (Join-Path $script:tempRoot 'out') -SourceRoot $script:fixtureSourceRoot
        Add-TestArchiveEntry $built.Path.FullName 'docs/EXTRA.md' ([Text.Encoding]::UTF8.GetBytes('extra'))

        { New-ReleaseBundle -BundlePath $built.Path.FullName -VerificationPath (Join-Path $script:tempRoot 'verify-extra') } |
            Should -Throw -ExpectedMessage "*unexpected entry 'docs/EXTRA.md'*"
    }

    It 'rejects an archive traversal entry without writing outside the fresh extraction root' {
        $built = New-ReleaseBundle -Manifest $script:fixtureManifest -OutputPath (Join-Path $script:tempRoot 'out') -SourceRoot $script:fixtureSourceRoot
        Add-TestArchiveEntry $built.Path.FullName '../escape.txt' ([Text.Encoding]::UTF8.GetBytes('escape'))
        $outside = Join-Path $script:tempRoot 'escape.txt'

        { New-ReleaseBundle -BundlePath $built.Path.FullName -VerificationPath (Join-Path $script:tempRoot 'verify-traversal') } |
            Should -Throw -ExpectedMessage '*traversal segment*'
        Test-Path -LiteralPath $outside | Should -BeFalse
    }

    It 'rejects a case-colliding archive entry' {
        $built = New-ReleaseBundle -Manifest $script:fixtureManifest -OutputPath (Join-Path $script:tempRoot 'out') -SourceRoot $script:fixtureSourceRoot
        Add-TestArchiveEntry $built.Path.FullName 'DOCS/RELEASE_NOTES.md' ([Text.Encoding]::UTF8.GetBytes('collision'))

        { New-ReleaseBundle -BundlePath $built.Path.FullName -VerificationPath (Join-Path $script:tempRoot 'verify-collision') } |
            Should -Throw -ExpectedMessage '*case-colliding entry*'
    }

    It 'rejects changed same-size payload bytes on fresh verification' {
        $built = New-ReleaseBundle -Manifest $script:fixtureManifest -OutputPath (Join-Path $script:tempRoot 'out') -SourceRoot $script:fixtureSourceRoot
        $original = [IO.File]::ReadAllBytes((Join-Path $script:fixtureSourceRoot 'docs/RELEASE_NOTES.md'))
        $changed = [byte[]]::new($original.Length)
        [Array]::Copy($original, $changed, $original.Length)
        $changed[0] = $changed[0] -bxor 1
        Replace-TestArchiveEntry $built.Path.FullName 'docs/RELEASE_NOTES.md' $changed

        { New-ReleaseBundle -BundlePath $built.Path.FullName -VerificationPath (Join-Path $script:tempRoot 'verify-hash') } |
            Should -Throw -ExpectedMessage '*SHA-256 mismatch*'
    }

    It 'rejects changed payload size on fresh verification' {
        $built = New-ReleaseBundle -Manifest $script:fixtureManifest -OutputPath (Join-Path $script:tempRoot 'out') -SourceRoot $script:fixtureSourceRoot
        Replace-TestArchiveEntry $built.Path.FullName 'docs/RELEASE_NOTES.md' ([Text.Encoding]::UTF8.GetBytes('short'))

        { New-ReleaseBundle -BundlePath $built.Path.FullName -VerificationPath (Join-Path $script:tempRoot 'verify-size') } |
            Should -Throw -ExpectedMessage '*size mismatch*'
    }
}
