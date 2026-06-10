#Requires -Version 7.0
# Pester 5+ tests for Compare-ReleaseManifest (Stream I4).

BeforeAll {
    $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $publicDir = Join-Path $moduleRoot 'public'
    $fixtureDir = Join-Path $moduleRoot 'tests\fixtures\release-manifests'
    . (Join-Path $publicDir 'Get-DeployedReleaseManifest.ps1')
    . (Join-Path $publicDir 'Compare-ReleaseManifest.ps1')

    if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
        function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
    }

    $script:oldManifestPath = Join-Path $fixtureDir 'acecommander-1.4.0-manifest.json'
    $script:newManifestPath = Join-Path $fixtureDir 'acecommander-1.4.1-manifest.json'
}

Describe 'Compare-ReleaseManifest' -Tag 'Unit' {
    It 'Accepts manifest paths and reports the expected known differences' {
        $result = Compare-ReleaseManifest -Old $script:oldManifestPath -New $script:newManifestPath

        $result.OperationName | Should -Be 'Compare-ReleaseManifest'
        $result.OldReleaseVersion | Should -Be '1.4.0'
        $result.NewReleaseVersion | Should -Be '1.4.1'
        $result.HasDifferences | Should -BeTrue

        $result.AddedLibraryPackages.Count | Should -Be 1
        $result.AddedLibraryPackages[0].Id | Should -Be 'ATAP.Utilities.NewLibrary'
        $result.AddedLibraryPackages[0].Version | Should -Be '1.0.0'

        $result.RemovedLibraryPackages.Count | Should -Be 1
        $result.RemovedLibraryPackages[0].Id | Should -Be 'ATAP.Utilities.Legacy'

        $result.ChangedLibraryPackages.Count | Should -Be 1
        $result.ChangedLibraryPackages[0].Id | Should -Be 'ATAP.Utilities.ETW'
        $result.ChangedLibraryPackages[0].OldVersion | Should -Be '0.1.0-Beta.42'
        $result.ChangedLibraryPackages[0].NewVersion | Should -Be '0.1.0-Beta.43'

        $result.AddedMigrationFiles | Should -Contain 'db/flyway/V1.4.2__new_feature_tables.sql'
        $result.RemovedMigrationFiles | Should -Contain 'db/flyway/V1.4.1__old_feature_tables.sql'

        $result.ChangedChecksums.Count | Should -Be 1
        $result.ChangedChecksums[0].Path | Should -Be 'app/bin/AceCommander.dll'
        $result.ResponseSummary | Should -Match 'library packages \+1 -1 ~1'
        $result.ResponseSummary | Should -Match 'migration files \+1 -1'
        $result.ResponseSummary | Should -Match 'checksums ~1'
    }

    It 'Accepts parsed manifest objects' {
        $oldManifest = Get-DeployedReleaseManifest -Path $script:oldManifestPath
        $newManifest = Get-DeployedReleaseManifest -Path $script:newManifestPath

        $result = Compare-ReleaseManifest -Old $oldManifest -New $newManifest

        $result.NewReleaseVersion | Should -Be '1.4.1'
        $result.ChangedLibraryPackages[0].Id | Should -Be 'ATAP.Utilities.ETW'
    }

    It 'Returns no differences when comparing the same manifest to itself' {
        $manifest = Get-DeployedReleaseManifest -Path $script:oldManifestPath

        $result = Compare-ReleaseManifest -Old $manifest -New $manifest

        $result.HasDifferences | Should -BeFalse
        $result.AddedLibraryPackages.Count | Should -Be 0
        $result.RemovedLibraryPackages.Count | Should -Be 0
        $result.ChangedLibraryPackages.Count | Should -Be 0
        $result.AddedMigrationFiles.Count | Should -Be 0
        $result.RemovedMigrationFiles.Count | Should -Be 0
        $result.ChangedChecksums.Count | Should -Be 0
    }

    It 'Produces readable Format-List output with the important sections present' {
        $result = Compare-ReleaseManifest -Old $script:oldManifestPath -New $script:newManifestPath

        $formatted = $result | Format-List | Out-String

        $formatted | Should -Match 'AddedLibraryPackages'
        $formatted | Should -Match 'RemovedMigrationFiles'
        $formatted | Should -Match 'ChangedChecksums'
        $formatted | Should -Match 'ResponseSummary'
    }

    It 'Throws clearly when an input is neither a manifest object nor a path' {
        { Compare-ReleaseManifest -Old 42 -New $script:newManifestPath } |
            Should -Throw -ExpectedMessage '*expects a manifest object or a path*'
    }
}
