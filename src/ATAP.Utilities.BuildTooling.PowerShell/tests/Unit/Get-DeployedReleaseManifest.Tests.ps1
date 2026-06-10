#Requires -Version 7.0
# Pester 5+ tests for Get-DeployedReleaseManifest (Stream I3).

BeforeAll {
    $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $publicDir = Join-Path $moduleRoot 'public'
    $fixtureDir = Join-Path $moduleRoot 'tests\fixtures\release-manifests'
    . (Join-Path $publicDir 'Get-DeployedReleaseManifest.ps1')

    if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
        function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
    }

    $script:validManifestPath = Join-Path $fixtureDir 'acecommander-1.4.0-manifest.json'
    $script:malformedManifestPath = Join-Path $fixtureDir 'malformed-manifest.json'
    $script:invalidSchemaManifestPath = Join-Path $fixtureDir 'invalid-schema-manifest.json'
    $script:schemaPath = Join-Path (Split-Path -Parent (Split-Path -Parent $moduleRoot)) 'SolutionDocumentation\schemas\manifest.schema.json'
    $script:schemaAvailable = Test-Path -LiteralPath $script:schemaPath -PathType Leaf
    $script:oldProgramData = $env:ProgramData
}

AfterAll {
    $env:ProgramData = $script:oldProgramData
}

Describe 'Get-DeployedReleaseManifest' -Tag 'Unit' {
    It 'Returns a parsed PSCustomObject for a valid deployed manifest' {
        $manifest = Get-DeployedReleaseManifest -Path $script:validManifestPath

        $manifest | Should -BeOfType [PSCustomObject]
        $manifest.releaseVersion | Should -Be '1.4.0'
        $manifest.sourceTag | Should -Be 'v1.4.0'
        $manifest.includedLibraryPackages[0].id | Should -Be 'ATAP.Utilities.Philote'
        $manifest.dbChangeUnit | Should -Be 'AceCommander-db-1.4.0'
        $manifest.flywayTargetVersion | Should -Be '1.4.1'
    }

    It 'Defaults to ${env:ProgramData}\AceCommander\manifest.json' {
        $tempProgramData = Join-Path ([System.IO.Path]::GetTempPath()) ('DeployedManifestTest_' + [Guid]::NewGuid().ToString('N'))
        $manifestDir = Join-Path $tempProgramData 'AceCommander'
        New-Item -ItemType Directory -Path $manifestDir -Force | Out-Null
        Copy-Item -LiteralPath $script:validManifestPath -Destination (Join-Path $manifestDir 'manifest.json') -Force

        try {
            $env:ProgramData = $tempProgramData
            $manifest = Get-DeployedReleaseManifest
            $manifest.releaseVersion | Should -Be '1.4.0'
        } finally {
            $env:ProgramData = $script:oldProgramData
            Remove-Item -LiteralPath $tempProgramData -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Throws a clear missing-file message' {
        $missingPath = Join-Path ([System.IO.Path]::GetTempPath()) ('missing-' + [Guid]::NewGuid().ToString('N') + '.json')

        { Get-DeployedReleaseManifest -Path $missingPath } |
            Should -Throw -ExpectedMessage '*Release manifest file was not found*'
    }

    It 'Throws a clear malformed JSON message' {
        { Get-DeployedReleaseManifest -Path $script:malformedManifestPath } |
            Should -Throw -ExpectedMessage '*malformed JSON*'
    }

    It 'Throws a clear schema-validation message when manifest.schema.json is available' {
        if (-not $script:schemaAvailable) {
            Set-ItResult -Skipped -Because "manifest.schema.json was not found at '$script:schemaPath'."
            return
        }

        { Get-DeployedReleaseManifest -Path $script:invalidSchemaManifestPath } |
            Should -Throw -ExpectedMessage '*failed schema validation*'
    }
}
