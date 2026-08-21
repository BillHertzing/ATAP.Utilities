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
}

Describe 'New-ReleaseBundle deterministic schema-v2 contract' -Tag 'Unit' {
    BeforeEach {
        $script:tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('NewReleaseBundle_' + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:tempRoot -Force | Out-Null
    }

    AfterEach {
        if ($script:tempRoot -and (Test-Path -LiteralPath $script:tempRoot)) {
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
        $first.VerifiedEntryCount | Should -Be 5
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
                'tests/unit-results.trx'
            )
            @($names | Where-Object { $_ -match '(?i)(^|/)db(/|$)|flyway|(^|/)seed(/|$)|db-manifest\.json' }).Count | Should -Be 0
            foreach ($entry in $archive.Entries) {
                $entry.LastWriteTime.DateTime | Should -Be $script:fixedTimestamp.DateTime
                $entry.ExternalAttributes | Should -Be $script:fixedAttributes
            }
        } finally {
            $archive.Dispose()
        }
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
