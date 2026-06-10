#Requires -Version 7.0
<#
.SYNOPSIS
    Pester tests for Get-DatabasePackageBuildContext.

.NOTES
    Task: TASKS_V4-DBA2.md DBA2-T01.
    Run: pwsh -Command "Invoke-Pester -Path './tests/Get-DatabasePackageBuildContext.Tests.ps1' -Output Detailed"
#>

BeforeAll {
    Import-Module PSFramework -MinimumVersion '1.10.0' -Force

    # Load the cmdlet under test and its dependency.
    $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)   # …/ATAP.Utilities.BuildTooling.PowerShell
    $publicDir = Join-Path $repoRoot 'public'
    . (Join-Path $publicDir 'Get-BuildContext.ps1')
    . (Join-Path $publicDir 'Get-DatabasePackageBuildContext.ps1')

    # ---------------------------------------------------------------------------
    # Shared test fixture: a minimal database package source tree in a temp dir.
    # ---------------------------------------------------------------------------
    $script:tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "DbBuildContextTests_$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $script:tempRoot -Force | Out-Null

    # Minimal git repo (needed by Get-BuildContext for 'git rev-parse --show-toplevel').
    Push-Location $script:tempRoot
    & git init --quiet 2>&1 | Out-Null
    & git commit --allow-empty -m 'init' --quiet 2>&1 | Out-Null
    Pop-Location

    # Database/ATAPUtilities/version.json  (single-stream fixture)
    $atapDbDir = Join-Path $script:tempRoot 'Database' 'ATAPUtilities'
    New-Item -ItemType Directory -Path $atapDbDir -Force | Out-Null
    @{
        '$schema'            = 'https://raw.githubusercontent.com/dotnet/Nerdbank.GitVersioning/main/src/NerdBank.GitVersioning/version.schema.json'
        version              = '0.1-Sprint.{height}'
        nuGetPackageVersion  = @{ semVer = 2 }
        pathFilters          = @('./')
        publicReleaseRefSpec = @('.*')
    } | ConvertTo-Json | Set-Content -Path (Join-Path $atapDbDir 'version.json') -Encoding UTF8

    # Database/AceCommander.Reporting/version.json  (multi-stream fixture)
    $reportingDbDir = Join-Path $script:tempRoot 'Database' 'AceCommander.Reporting'
    New-Item -ItemType Directory -Path $reportingDbDir -Force | Out-Null
    @{
        '$schema'            = 'https://raw.githubusercontent.com/dotnet/Nerdbank.GitVersioning/main/src/NerdBank.GitVersioning/version.schema.json'
        version              = '0.1-Sprint.{height}'
        nuGetPackageVersion  = @{ semVer = 2 }
        pathFilters          = @('./')
        publicReleaseRefSpec = @('.*')
    } | ConvertTo-Json | Set-Content -Path (Join-Path $reportingDbDir 'version.json') -Encoding UTF8
}

AfterAll {
    # Clean up temp directory.
    Remove-Item -Recurse -Force $script:tempRoot -ErrorAction SilentlyContinue
}

Describe 'Get-DatabasePackageBuildContext' {

    BeforeAll {
        # Mock Get-BuildContext to avoid requiring a live nbgv installation.
        Mock Get-BuildContext {
            param($Application, $ProjectPath, $Stage, $Branch, $ReleaseTag)
            [PSCustomObject]@{
                Application            = $Application
                ProjectPath            = $ProjectPath
                Branch                 = $Branch
                BranchType             = 'sprint'
                FeatureSlug            = $null
                RepoRoot               = $script:tempRoot
                SourceTag              = $null
                SourceCommit           = 'abc1234'
                ResolvedPackageVersion = '0.1.0-Sprint.42'
                MajorMinorPatch        = '0.1.0'
                PrereleaseLabel        = 'Sprint.42'
                CurrentTier            = 'Experimental'
                CeilingTier            = 'Experimental'
                IsAtCeiling            = $true
                DbAssetsIncluded       = $false
            }
        } -ModuleName $null
    }

    Context 'Single-stream happy path' {

        It 'Returns an object with DatabasePackageId set to <Application>.Database' {
            $ctx = Get-DatabasePackageBuildContext `
                -Application 'ATAPUtilities' `
                -RepoRoot $script:tempRoot `
                -Branch 'main'

            $ctx.DatabasePackageId | Should -Be 'ATAPUtilities.Database'
        }

        It 'Returns DatabasePackageSourcePath pointing to Database/ATAPUtilities' {
            $ctx = Get-DatabasePackageBuildContext `
                -Application 'ATAPUtilities' `
                -RepoRoot $script:tempRoot `
                -Branch 'main'

            $expected = Join-Path $script:tempRoot 'Database' 'ATAPUtilities'
            $ctx.DatabasePackageSourcePath | Should -Be $expected
        }

        It 'Returns DatabaseVersionJsonPath pointing to the version.json' {
            $ctx = Get-DatabasePackageBuildContext `
                -Application 'ATAPUtilities' `
                -RepoRoot $script:tempRoot `
                -Branch 'main'

            $expected = Join-Path $script:tempRoot 'Database' 'ATAPUtilities' 'version.json'
            $ctx.DatabaseVersionJsonPath | Should -Be $expected
        }

        It 'Returns PackageKind = DatabaseChangePackage' {
            $ctx = Get-DatabasePackageBuildContext `
                -Application 'ATAPUtilities' `
                -RepoRoot $script:tempRoot `
                -Branch 'main'

            $ctx.PackageKind | Should -Be 'DatabaseChangePackage'
        }
    }

    Context 'Multi-stream happy path' {

        It 'Constructs <Application>.<Stream>.Database package id' {
            $ctx = Get-DatabasePackageBuildContext `
                -Application 'AceCommander' `
                -Stream 'Reporting' `
                -RepoRoot $script:tempRoot `
                -Branch 'main'

            $ctx.DatabasePackageId | Should -Be 'AceCommander.Reporting.Database'
        }

        It 'Points DatabasePackageSourcePath to Database/AceCommander.Reporting' {
            $ctx = Get-DatabasePackageBuildContext `
                -Application 'AceCommander' `
                -Stream 'Reporting' `
                -RepoRoot $script:tempRoot `
                -Branch 'main'

            $expected = Join-Path $script:tempRoot 'Database' 'AceCommander.Reporting'
            $ctx.DatabasePackageSourcePath | Should -Be $expected
        }
    }

    Context 'Missing version.json → terminating error' {

        It 'Throws when the database source folder does not contain version.json' {
            { Get-DatabasePackageBuildContext `
                    -Application 'NonExistentApp' `
                    -RepoRoot $script:tempRoot `
                    -Branch 'main' } | Should -Throw -ExpectedMessage '*version.json*'
        }
    }
}
