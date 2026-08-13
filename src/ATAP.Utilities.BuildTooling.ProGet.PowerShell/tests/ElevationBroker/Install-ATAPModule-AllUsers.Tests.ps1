BeforeAll {
    # The installer ships as a broker resource, not as a test fixture. Resolving it from
    # $PSScriptRoot silently pointed at a path that has never existed, so this whole
    # container failed at load and its nine tests were counted as failures rather than
    # as coverage. Resolve it where the module actually keeps it.
    $script:ModuleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:InstallerScript = Join-Path $script:ModuleRoot 'Resources\ElevationBroker\Install-ATAPModule-AllUsers.ps1'
    if (-not (Test-Path -LiteralPath $script:InstallerScript -PathType Leaf)) {
        throw "The broker installer resource '$script:InstallerScript' is missing."
    }
    . $script:InstallerScript
}

Describe 'Get-ATAPModuleFileHash' {
    It 'returns true when hash matches expected value' {
        $tmpPath = Join-Path -Path $env:TEMP -ChildPath "ATAP-HashMatch-Test.txt"
        Set-Content -LiteralPath $tmpPath -Value 'installer-hash-fixture'

        $expected = (Get-FileHash -Algorithm SHA256 -Path $tmpPath).Hash
        Test-ATAPModuleFileHash -Path $tmpPath -ExpectedSha256 $expected | Should -BeTrue

        Remove-Item -LiteralPath $tmpPath -Force
    }

    It 'returns false when hash does not match expected value' {
        $tmpPath = Join-Path -Path $env:TEMP -ChildPath "ATAP-HashMismatch-Test.txt"
        Set-Content -LiteralPath $tmpPath -Value 'installer-hash-fixture-mismatch'

        Test-ATAPModuleFileHash -Path $tmpPath -ExpectedSha256 ('0' * 64) | Should -BeFalse

        Remove-Item -LiteralPath $tmpPath -Force
    }
}

Describe 'Get-ATAPModuleDependencyFloorViolations' {
    It 'flags missing and below-minimum dependencies' {
        $requirements = @(
            [pscustomobject]@{ Name = 'PSFramework'; ModuleVersion = '1.14.457' }
            [pscustomobject]@{ Name = 'ShouldNotExist'; ModuleVersion = '1.0.0' }
            [pscustomobject]@{ Name = 'LegacyKit'; ModuleVersion = '2.5.1' }
        )
        $installedModules = @{
            PSFramework  = '1.14.457'
            LegacyKit    = '2.4.0'
        }

        $violations = Get-ATAPModuleDependencyFloorViolations -DependencyRequirements $requirements -InstalledModules $installedModules

        $violations | Measure-Object | Select-Object -ExpandProperty Count | Should -Be 2
        $violations[0].Dependency | Should -BeIn 'ShouldNotExist', 'LegacyKit'
    }

    It 'returns no violations when requirements are satisfied' {
        $requirements = @(
            [pscustomobject]@{ Name = 'PSFramework'; ModuleVersion = '1.14.457' }
            [string] 'SimpleStringDependency'
        )
        $installedModules = @{
            PSFramework             = '1.14.999'
            SimpleStringDependency   = '0.1.0'
        }

        $violations = Get-ATAPModuleDependencyFloorViolations -DependencyRequirements $requirements -InstalledModules $installedModules
        $violations.Count | Should -Be 0
    }
}

Describe 'Get-ATAPModuleDownloadCandidateUris' {
    # This function had no coverage, which is how it shipped emitting ONLY the /api/v2 form.
    # ProGet Free answers that with "OData method is not implemented", so every download
    # failed against the ProGet the ATAP feeds actually run on (observed 2026-07-25 while
    # deploying SprintLifecycle 0.1.6).
    BeforeAll {
        $script:Feed = 'https://utat022:50000/nuget/powershellget-stable'
        $script:Name = 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell'
        $script:Version = '0.1.6'
    }

    It 'offers the direct package endpoint BEFORE the OData v2 endpoint' {
        $uris = @(Get-ATAPModuleDownloadCandidateUris -BaseFeedUrl $script:Feed -ModuleName $script:Name -RequiredVersion $script:Version)

        $direct = "$script:Feed/package/$script:Name/$script:Version"
        $odata = "$script:Feed/api/v2/package/$script:Name/$script:Version"

        $uris | Should -Contain $direct
        $uris | Should -Contain $odata
        # Order is the whole point: the first reachable candidate wins.
        $uris.IndexOf($direct) | Should -BeLessThan $uris.IndexOf($odata)
    }

    It 'prefers localhost over the utat01 hostname' {
        # Session evidence: the localhost endpoint is reachable when the host name is not.
        $uris = @(Get-ATAPModuleDownloadCandidateUris -BaseFeedUrl 'http://utat01:50000/nuget/powershellget-stable' -ModuleName $script:Name -RequiredVersion $script:Version)
        # The rewrite substitutes the HOST only; it must not silently change the scheme,
        # or a caller pinned to plain http would be redirected somewhere it did not ask for.
        $uris[0] | Should -Match '^http://localhost:50000/'
        # The original hostname stays in the candidate list as a fallback.
        ($uris | Where-Object { $_ -match '^http://utat01:50000/' }).Count | Should -BeGreaterThan 0
    }

    It 'honors an explicit /api/v2 base and still offers the direct form' {
        $uris = @(Get-ATAPModuleDownloadCandidateUris -BaseFeedUrl "$script:Feed/api/v2" -ModuleName $script:Name -RequiredVersion $script:Version)
        $uris[0] | Should -Be "$script:Feed/api/v2/package/$script:Name/$script:Version"
        $uris | Should -Contain "$script:Feed/package/$script:Name/$script:Version"
    }

    It 'tolerates a trailing slash on the feed URL' {
        $uris = @(Get-ATAPModuleDownloadCandidateUris -BaseFeedUrl "$script:Feed/" -ModuleName $script:Name -RequiredVersion $script:Version)
        $uris | Should -Not -Contain "$script:Feed//package/$script:Name/$script:Version"
        $uris[0] | Should -Be "$script:Feed/package/$script:Name/$script:Version"
    }
}

Describe 'Get-ATAPModuleVersionInstallPath' {
    It 'computes the expected versioned AllUsers target path' {
        $expected = Join-Path -Path 'C:\Program Files\PowerShell\Modules' -ChildPath 'ATAP.Utilities'
        $expected = Join-Path -Path $expected -ChildPath '1.2.3'
        Get-ATAPModuleVersionInstallPath -ModuleName 'ATAP.Utilities' -RequiredVersion '1.2.3' -ModulesRoot 'C:\Program Files\PowerShell\Modules' | Should -Be $expected
    }
}
