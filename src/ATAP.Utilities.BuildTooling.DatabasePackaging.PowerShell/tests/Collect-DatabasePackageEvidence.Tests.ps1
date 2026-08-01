# AI assisted using Powershell.instructions.md as guidelines
# Pester 5+ tests for DBA2-T07 / V4-E14: Collect-DatabasePackageEvidence
# must capture every evidence key into the output folder, record missing
# optional sources as $null in evidence-bundle.json, and compute the
# .nupkg SHA-256.

BeforeAll {
    $script:CmdletPath = Join-Path $PSScriptRoot '..\public\Collect-DatabasePackageEvidence.ps1'

    if (-not (Get-Command -Name Write-PSFMessage -ErrorAction SilentlyContinue)) {
        function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments)]$args) }
    }

    . $script:CmdletPath

    $script:Workspace = Join-Path ([System.IO.Path]::GetTempPath()) (
        'DBA2-T07-' + [Guid]::NewGuid().ToString('N')
    )
    New-Item -ItemType Directory -Path $script:Workspace -Force | Out-Null

    function script:New-StubFile {
        param(
            [Parameter(Mandatory)][string]$Path,
            [Parameter(Mandatory)][string]$Content
        )
        $parent = Split-Path -Parent $Path
        if (-not (Test-Path -LiteralPath $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
        Set-Content -LiteralPath $Path -Value $Content -Encoding utf8
    }
}

AfterAll {
    if (Test-Path -LiteralPath $script:Workspace) {
        Remove-Item -LiteralPath $script:Workspace -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'Collect-DatabasePackageEvidence — all sources present' {

    BeforeAll {
        $script:Inputs = Join-Path $script:Workspace 'all-present'
        New-Item -ItemType Directory -Path $script:Inputs -Force | Out-Null

        $script:NupkgPath = Join-Path $script:Inputs 'ATAPUtilities.Database.1.5.0-experimental.42.nupkg'
        New-StubFile -Path $script:NupkgPath -Content 'fake-nupkg-bytes'

        $script:ManifestPath = Join-Path $script:Inputs 'db-release-unit-manifest.json'
        New-StubFile -Path $script:ManifestPath -Content '{"compatibleAppPackageRanges":["[1.0.0,2.0.0)"]}'

        $script:ContentChecksumsPath = Join-Path $script:Inputs 'package-evidence.json'
        New-StubFile -Path $script:ContentChecksumsPath -Content '{"checksums":{}}'

        $script:FlywayInfoPath = Join-Path $script:Inputs 'flyway-info.txt'
        New-StubFile -Path $script:FlywayInfoPath -Content 'Schema version: 1.5.0'

        $script:FlywayMigrationLogPath = Join-Path $script:Inputs 'flyway-migration.log'
        New-StubFile -Path $script:FlywayMigrationLogPath -Content 'Migrating to 1.5.0...'

        $script:SeedLoaderLogPath = Join-Path $script:Inputs 'seed-loader.log'
        New-StubFile -Path $script:SeedLoaderLogPath -Content 'Loaded 17 rows.'

        $script:PreMigrationSnapshotPath = Join-Path $script:Inputs 'pre-migration-snapshot.json'
        New-StubFile -Path $script:PreMigrationSnapshotPath -Content '{"snapshotId":"snap-001"}'

        $script:PesterResultsPath = Join-Path $script:Inputs 'pester-results.xml'
        New-StubFile -Path $script:PesterResultsPath -Content '<?xml version="1.0"?><test-results />'

        $script:OutputRoot = Join-Path $script:Workspace 'output-1'
        New-Item -ItemType Directory -Path $script:OutputRoot -Force | Out-Null

        $script:Result = Collect-DatabasePackageEvidence `
            -PackageId 'ATAPUtilities.Database' `
            -Version '1.5.0-experimental.42' `
            -NupkgPath $script:NupkgPath `
            -ManifestPath $script:ManifestPath `
            -ContentChecksumsPath $script:ContentChecksumsPath `
            -FlywayInfoOutputPath $script:FlywayInfoPath `
            -FlywayMigrationLogPath $script:FlywayMigrationLogPath `
            -SeedLoaderLogPath $script:SeedLoaderLogPath `
            -PreMigrationSnapshotEvidencePath $script:PreMigrationSnapshotPath `
            -PesterResultsXmlPath $script:PesterResultsPath `
            -ProGetFeed 'database-experimental' `
            -BuildMasterBuildId '12345' `
            -OutputRoot $script:OutputRoot
    }

    It 'creates the evidence folder under <PackageId>.<Version>/evidence/' {
        $expectedFolder = Join-Path $script:OutputRoot 'ATAPUtilities.Database.1.5.0-experimental.42/evidence'
        $script:Result.EvidenceFolder | Should -Be ([System.IO.Path]::GetFullPath($expectedFolder))
        Test-Path -LiteralPath $script:Result.EvidenceFolder -PathType Container | Should -BeTrue
    }

    It 'writes evidence-bundle.json containing every expected key' {
        $summary = Get-Content -LiteralPath $script:Result.SummaryJsonPath -Raw | ConvertFrom-Json
        foreach ($expectedKey in @(
            'Manifest', 'ContentChecksums', 'FlywayInfoOutput',
            'FlywayMigrationLog', 'SeedLoaderLog', 'PreMigrationSnapshot',
            'PesterResultsXml', 'Nupkg'
        )) {
            $summary.EvidenceKeys.PSObject.Properties.Name | Should -Contain $expectedKey
        }
    }

    It 'every evidence key references a file that exists in the evidence folder' {
        $summary = Get-Content -LiteralPath $script:Result.SummaryJsonPath -Raw | ConvertFrom-Json
        foreach ($prop in $summary.EvidenceKeys.PSObject.Properties) {
            $relativePath = $prop.Value
            $relativePath | Should -Not -BeNullOrEmpty -Because "$($prop.Name) should resolve to a captured file when all sources are present"
            $fullPath = Join-Path $script:Result.EvidenceFolder $relativePath
            Test-Path -LiteralPath $fullPath -PathType Leaf | Should -BeTrue -Because "$($prop.Name) -> $fullPath should exist"
        }
    }

    It 'records the .nupkg SHA-256 digest' {
        $script:Result.PackageDigestSha256 | Should -Not -BeNullOrEmpty
        $script:Result.PackageDigestSha256.Length | Should -Be 64
        $summary = Get-Content -LiteralPath $script:Result.SummaryJsonPath -Raw | ConvertFrom-Json
        $summary.PackageDigestSha256 | Should -Be $script:Result.PackageDigestSha256
    }

    It 'records ProGet feed, actor, and BuildMaster build id in the summary' {
        $summary = Get-Content -LiteralPath $script:Result.SummaryJsonPath -Raw | ConvertFrom-Json
        $summary.ProGetFeed | Should -Be 'database-experimental'
        $summary.BuildMasterBuildId | Should -Be '12345'
        $summary.Actor | Should -Not -BeNullOrEmpty
    }
}

Describe 'Collect-DatabasePackageEvidence — missing optional sources record null, not error' {

    BeforeAll {
        $script:Inputs2 = Join-Path $script:Workspace 'partial'
        New-Item -ItemType Directory -Path $script:Inputs2 -Force | Out-Null
        $script:NupkgPath2 = Join-Path $script:Inputs2 'ATAPUtilities.Database.1.5.0.nupkg'
        New-StubFile -Path $script:NupkgPath2 -Content 'fake-bytes'

        $script:OutputRoot2 = Join-Path $script:Workspace 'output-2'
        New-Item -ItemType Directory -Path $script:OutputRoot2 -Force | Out-Null

        $script:Result2 = Collect-DatabasePackageEvidence `
            -PackageId 'ATAPUtilities.Database' `
            -Version '1.5.0' `
            -NupkgPath $script:NupkgPath2 `
            -ProGetFeed 'database-stable' `
            -BuildMasterBuildId 'no-snapshot-run' `
            -OutputRoot $script:OutputRoot2
    }

    It 'does not throw when optional sources are absent' {
        $script:Result2 | Should -Not -BeNullOrEmpty
    }

    It 'records absent optional sources as null in the summary' {
        $summary = Get-Content -LiteralPath $script:Result2.SummaryJsonPath -Raw | ConvertFrom-Json
        $summary.EvidenceKeys.Manifest | Should -BeNullOrEmpty
        $summary.EvidenceKeys.ContentChecksums | Should -BeNullOrEmpty
        $summary.EvidenceKeys.FlywayInfoOutput | Should -BeNullOrEmpty
        $summary.EvidenceKeys.FlywayMigrationLog | Should -BeNullOrEmpty
        $summary.EvidenceKeys.SeedLoaderLog | Should -BeNullOrEmpty
        $summary.EvidenceKeys.PreMigrationSnapshot | Should -BeNullOrEmpty
        $summary.EvidenceKeys.PesterResultsXml | Should -BeNullOrEmpty
        # Nupkg is required and must always be present.
        $summary.EvidenceKeys.Nupkg | Should -Not -BeNullOrEmpty
    }
}

Describe 'Collect-DatabasePackageEvidence — required input validation' {

    It 'throws when the .nupkg does not exist' {
        {
            Collect-DatabasePackageEvidence `
                -PackageId 'ATAPUtilities.Database' `
                -Version '1.5.0' `
                -NupkgPath (Join-Path $script:Workspace 'does-not-exist.nupkg') `
                -ProGetFeed 'database-experimental' `
                -OutputRoot $script:Workspace
        } | Should -Throw
    }
}
