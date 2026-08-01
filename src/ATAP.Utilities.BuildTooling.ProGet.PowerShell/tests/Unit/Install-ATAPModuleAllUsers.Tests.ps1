#Requires -Version 7.0

# Task 13.76.c — canonical validated AllUsers installer, promoted from the standalone
# _Planning script. Coverage deliberately includes the integration path: the standalone
# version shipped with green unit tests and had never completed an install, because every
# defect that mattered sat in the untested path between download and fresh import.

BeforeAll {
  $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $privateDir = Join-Path $moduleRoot 'private'
  $publicDir = Join-Path $moduleRoot 'public'

  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage {
      param([Parameter(ValueFromRemainingArguments = $true)]$rest)
    }
  }

  foreach ($helper in @(
      'Get-ATAPModuleVersionInstallPath.ps1'
      'Test-ATAPModuleFileHash.ps1'
      'Get-ATAPModuleDependencyFloorViolations.ps1'
      'Get-ATAPModuleDependencyRequirementsFromManifest.ps1'
      'Get-ATAPModuleInstalledVersions.ps1'
      'Get-ATAPModuleDownloadCandidateUris.ps1'
      'Test-ATAPModuleEndpointReachable.ps1'
      'Get-ATAPModuleDownloadUri.ps1'
      'Test-ATAPModuleAllUsersElevated.ps1'
    )) {
    . (Join-Path $privateDir $helper)
  }
  . (Join-Path $publicDir 'Install-ATAPModuleAllUsers.ps1')
}

Describe 'Get-ATAPModuleVersionInstallPath' {
  It 'composes <ModulesRoot>\<Name>\<Version>' {
    $expected = Join-Path (Join-Path 'C:\Modules' 'ATAP.Utilities') '1.2.3'
    Get-ATAPModuleVersionInstallPath -ModuleName 'ATAP.Utilities' -RequiredVersion '1.2.3' -ModulesRoot 'C:\Modules' |
      Should -Be $expected
  }
}

Describe 'Test-ATAPModuleFileHash' {
  BeforeAll {
    $script:HashFile = Join-Path $TestDrive 'hash-fixture.txt'
    Set-Content -LiteralPath $script:HashFile -Value 'installer-hash-fixture' -NoNewline
    $script:RealHash = (Get-FileHash -Algorithm SHA256 -Path $script:HashFile).Hash
  }

  It 'returns true for a matching hash' {
    Test-ATAPModuleFileHash -Path $script:HashFile -ExpectedSha256 $script:RealHash | Should -BeTrue
  }

  It 'is case-insensitive, so a pin recorded in lower case still matches' {
    Test-ATAPModuleFileHash -Path $script:HashFile -ExpectedSha256 $script:RealHash.ToLower() | Should -BeTrue
  }

  It 'returns false for a non-matching hash' {
    Test-ATAPModuleFileHash -Path $script:HashFile -ExpectedSha256 ('0' * 64) | Should -BeFalse
  }
}

Describe 'Get-ATAPModuleDownloadCandidateUris' {
  BeforeAll {
    $script:Feed = 'http://localhost:50000/nuget/powershellget-stable'
    $script:Name = 'ATAP.Utilities.BuildTooling.Common.PowerShell'
    $script:Version = '0.1.8'
  }

  It 'offers the direct package endpoint BEFORE the OData v2 endpoint' {
    # Order is the defect that made the standalone installer unusable: ProGet Free answers
    # /api/v2 with "OData method is not implemented", and only /api/v2 was emitted.
    $uris = @(Get-ATAPModuleDownloadCandidateUris -BaseFeedUrl $script:Feed -ModuleName $script:Name -RequiredVersion $script:Version)
    $direct = "$script:Feed/package/$script:Name/$script:Version"
    $odata = "$script:Feed/api/v2/package/$script:Name/$script:Version"

    $uris | Should -Contain $direct
    $uris | Should -Contain $odata
    $uris.IndexOf($direct) | Should -BeLessThan $uris.IndexOf($odata)
  }

  It 'prefers localhost over the utat01 hostname' {
    $uris = @(Get-ATAPModuleDownloadCandidateUris -BaseFeedUrl 'http://utat01:50000/nuget/powershellget-stable' -ModuleName $script:Name -RequiredVersion $script:Version)
    $uris[0] | Should -Match '^http://localhost:50000/'
    @($uris | Where-Object { $_ -match '^http://utat01:50000/' }).Count | Should -BeGreaterThan 0
  }

  It 'honors an explicit /api/v2 base and still offers the direct form' {
    $uris = @(Get-ATAPModuleDownloadCandidateUris -BaseFeedUrl "$script:Feed/api/v2" -ModuleName $script:Name -RequiredVersion $script:Version)
    $uris[0] | Should -Be "$script:Feed/api/v2/package/$script:Name/$script:Version"
    $uris | Should -Contain "$script:Feed/package/$script:Name/$script:Version"
  }

  It 'tolerates a trailing slash' {
    $uris = @(Get-ATAPModuleDownloadCandidateUris -BaseFeedUrl "$script:Feed/" -ModuleName $script:Name -RequiredVersion $script:Version)
    $uris[0] | Should -Be "$script:Feed/package/$script:Name/$script:Version"
  }
}

Describe 'Get-ATAPModuleDownloadUri' {
  It 'returns the first reachable candidate' {
    Mock Test-ATAPModuleEndpointReachable { $Uri -notmatch '/api/v2/' }
    $uri = Get-ATAPModuleDownloadUri -FeedUrl 'http://localhost:50000/nuget/powershellget-stable' -ModuleName 'M' -RequiredVersion '1.0.0'
    $uri | Should -Be 'http://localhost:50000/nuget/powershellget-stable/package/M/1.0.0'
  }

  It 'falls through to the OData endpoint when the direct form is unreachable' {
    Mock Test-ATAPModuleEndpointReachable { $Uri -match '/api/v2/' }
    $uri = Get-ATAPModuleDownloadUri -FeedUrl 'http://localhost:50000/nuget/powershellget-stable' -ModuleName 'M' -RequiredVersion '1.0.0'
    $uri | Should -Be 'http://localhost:50000/nuget/powershellget-stable/api/v2/package/M/1.0.0'
  }

  It 'throws when no candidate is reachable' {
    Mock Test-ATAPModuleEndpointReachable { $false }
    { Get-ATAPModuleDownloadUri -FeedUrl 'http://localhost:50000/nuget/powershellget-stable' -ModuleName 'M' -RequiredVersion '1.0.0' } |
      Should -Throw -ExpectedMessage '*No reachable download URI*'
  }
}

Describe 'Get-ATAPModuleDependencyFloorViolations' {
  It 'flags a missing dependency and one below its floor' {
    $requirements = @(
      [pscustomobject]@{ ModuleName = 'PSFramework'; ModuleVersion = '1.14.457' }
      [pscustomobject]@{ ModuleName = 'ShouldNotExist'; ModuleVersion = '1.0.0' }
      [pscustomobject]@{ ModuleName = 'LegacyKit'; ModuleVersion = '2.5.1' }
    )
    $installed = @{ PSFramework = '1.14.457'; LegacyKit = '2.4.0' }

    $violations = @(Get-ATAPModuleDependencyFloorViolations -DependencyRequirements $requirements -InstalledModules $installed)
    $violations.Count | Should -Be 2
    ($violations | Where-Object Dependency -EQ 'ShouldNotExist').Status | Should -Be 'Missing'
    ($violations | Where-Object Dependency -EQ 'LegacyKit').Status | Should -Be 'BelowMinimum'
  }

  It 'returns nothing when every floor is satisfied, including a bare string entry' {
    $requirements = @(
      [pscustomobject]@{ ModuleName = 'PSFramework'; ModuleVersion = '1.14.457' }
      'SimpleStringDependency'
    )
    $installed = @{ PSFramework = '1.14.999'; SimpleStringDependency = '0.1.0' }
    @(Get-ATAPModuleDependencyFloorViolations -DependencyRequirements $requirements -InstalledModules $installed).Count |
      Should -Be 0
  }

  It 'accepts RequiredVersion as well as ModuleVersion' {
    $requirements = @([pscustomobject]@{ ModuleName = 'Pinned'; RequiredVersion = '3.0.0' })
    @(Get-ATAPModuleDependencyFloorViolations -DependencyRequirements $requirements -InstalledModules @{ Pinned = '2.9.9' }).Count |
      Should -Be 1
    @(Get-ATAPModuleDependencyFloorViolations -DependencyRequirements $requirements -InstalledModules @{ Pinned = '3.0.0' }).Count |
      Should -Be 0
  }

  It 'treats an unparseable declared version as no floor rather than throwing' {
    # A malformed manifest entry must not crash the install, but it must also not be
    # silently upgraded into a satisfied dependency it never proved.
    $requirements = @([pscustomobject]@{ ModuleName = 'Weird'; ModuleVersion = 'not-a-version' })
    @(Get-ATAPModuleDependencyFloorViolations -DependencyRequirements $requirements -InstalledModules @{ Weird = '0.0.1' }).Count |
      Should -Be 0
  }

  It 'returns nothing for an empty requirement set' {
    @(Get-ATAPModuleDependencyFloorViolations -DependencyRequirements @() -InstalledModules @{}).Count | Should -Be 0
  }
}

Describe 'Get-ATAPModuleDependencyRequirementsFromManifest' {
  It 'reads RequiredModules from a manifest' {
    $p = Join-Path $TestDrive 'WithDeps.psd1'
    Set-Content -LiteralPath $p -Value "@{ ModuleVersion = '1.0.0'; RequiredModules = @(@{ ModuleName = 'PSFramework'; ModuleVersion = '1.14.457' }) }"
    $reqs = @(Get-ATAPModuleDependencyRequirementsFromManifest -ModuleManifestPath $p)
    $reqs.Count | Should -Be 1
    $reqs[0].ModuleName | Should -Be 'PSFramework'
  }

  It 'returns an empty set when the manifest declares no RequiredModules' {
    $p = Join-Path $TestDrive 'NoDeps.psd1'
    Set-Content -LiteralPath $p -Value "@{ ModuleVersion = '1.0.0' }"
    @(Get-ATAPModuleDependencyRequirementsFromManifest -ModuleManifestPath $p).Count | Should -Be 0
  }
}

Describe 'Install-ATAPModuleAllUsers' {
  BeforeEach {
    $script:Root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    $script:ModulesRoot = Join-Path $script:Root 'Modules'
    $script:DeployRoot = Join-Path $script:Root 'deploy'
    New-Item -ItemType Directory -Path $script:ModulesRoot, $script:DeployRoot -Force | Out-Null

    $script:Name = 'Fixture.Module'
    $script:Version = '1.0.0'

    # Build a real .nupkg (a zip) so the expand/manifest/staging path is genuinely exercised.
    $pkgSrc = Join-Path $script:Root 'pkgsrc'
    New-Item -ItemType Directory -Path $pkgSrc -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $pkgSrc "$script:Name.psd1") `
      -Value "@{ ModuleVersion = '$script:Version'; RootModule = '$script:Name.psm1'; FunctionsToExport = @('Get-FixtureThing') }"
    Set-Content -LiteralPath (Join-Path $pkgSrc "$script:Name.psm1") `
      -Value "function Get-FixtureThing { 'fixture' }"
    $script:Nupkg = Join-Path $script:Root "$script:Name.$script:Version.nupkg"
    Compress-Archive -Path (Join-Path $pkgSrc '*') -DestinationPath $script:Nupkg -Force
    $script:NupkgHash = (Get-FileHash -Algorithm SHA256 -Path $script:Nupkg).Hash

    Mock Test-ATAPModuleAllUsersElevated { $true }
    Mock Get-PSRepository { [pscustomobject]@{ Name = 'powershellget-stable' } }
    Mock Get-ATAPModuleDownloadUri { 'http://localhost:50000/nuget/powershellget-stable/package/Fixture.Module/1.0.0' }
    Mock Invoke-WebRequest { Copy-Item -LiteralPath $script:Nupkg -Destination $OutFile -Force }
    Mock Get-ATAPModuleInstalledVersions { @{} }
    Mock Start-Transcript { }
    Mock Stop-Transcript { }
  }

  It 'installs into <ModulesRoot>\<Name>\<Version> and validates the fresh import' {
    $r = Install-ATAPModuleAllUsers -ModuleName $script:Name -RequiredVersion $script:Version `
      -Repository 'powershellget-stable' -FeedUrl 'http://localhost:50000/nuget/powershellget-stable' `
      -ExpectedSha256 $script:NupkgHash -ModulesRoot $script:ModulesRoot -DeployRoot $script:DeployRoot -Confirm:$false

    $r.ExitStatus | Should -Be 0
    $r.ErrorText | Should -BeNullOrEmpty
    $expected = Join-Path (Join-Path $script:ModulesRoot $script:Name) $script:Version
    $r.VersionPath | Should -Be $expected

    # The manifest must sit directly in the version folder, NOT nested one level deeper.
    Test-Path -LiteralPath (Join-Path $expected "$script:Name.psd1") | Should -BeTrue
    Test-Path -LiteralPath (Join-Path $expected 'expand') | Should -BeFalse
  }

  It 'creates the version folder at the AllUsers root instead of moving the broker-temp folder' {
    $r = Install-ATAPModuleAllUsers -ModuleName $script:Name -RequiredVersion $script:Version `
      -Repository 'powershellget-stable' -FeedUrl 'http://localhost:50000/nuget/powershellget-stable' `
      -ExpectedSha256 $script:NupkgHash -ModulesRoot $script:ModulesRoot -DeployRoot $script:DeployRoot -Confirm:$false

    $r.ExitStatus | Should -Be 0
    $expected = Join-Path (Join-Path $script:ModulesRoot $script:Name) $script:Version
    $parent = Split-Path -Path $expected -Parent
    (Get-Acl -LiteralPath $expected).AreAccessRulesProtected | Should -BeFalse
    (Get-Acl -LiteralPath $expected).AccessToString | Should -Be (Get-Acl -LiteralPath $parent).AccessToString
  }

  It 'writes a JSON result record for the run' {
    $r = Install-ATAPModuleAllUsers -ModuleName $script:Name -RequiredVersion $script:Version `
      -Repository 'powershellget-stable' -FeedUrl 'http://localhost:50000/nuget/powershellget-stable' `
      -ExpectedSha256 $script:NupkgHash -ModulesRoot $script:ModulesRoot -DeployRoot $script:DeployRoot -Confirm:$false

    Test-Path -LiteralPath $r.ResultJsonPath | Should -BeTrue
    $record = Get-Content -LiteralPath $r.ResultJsonPath -Raw | ConvertFrom-Json
    $record.ExitStatus | Should -Be 0
    $record.ActualSha256 | Should -Be $script:NupkgHash
  }

  It 'refuses a package whose hash does not match the pin, and installs nothing' {
    $r = Install-ATAPModuleAllUsers -ModuleName $script:Name -RequiredVersion $script:Version `
      -Repository 'powershellget-stable' -FeedUrl 'http://localhost:50000/nuget/powershellget-stable' `
      -ExpectedSha256 ('A' * 64) -ModulesRoot $script:ModulesRoot -DeployRoot $script:DeployRoot -Confirm:$false

    $r.ExitStatus | Should -Be 1
    $r.ErrorText | Should -Match 'SHA-256 validation failed'
    Test-Path -LiteralPath (Join-Path (Join-Path $script:ModulesRoot $script:Name) $script:Version) | Should -BeFalse
  }

  It 'exits 2 without installing when not elevated' {
    Mock Test-ATAPModuleAllUsersElevated { $false }
    $r = Install-ATAPModuleAllUsers -ModuleName $script:Name -RequiredVersion $script:Version `
      -Repository 'powershellget-stable' -FeedUrl 'http://localhost:50000/nuget/powershellget-stable' `
      -ExpectedSha256 $script:NupkgHash -ModulesRoot $script:ModulesRoot -DeployRoot $script:DeployRoot -Confirm:$false

    $r.ExitStatus | Should -Be 2
    $r.ErrorText | Should -Match 'Administrator rights'
  }

  It 'refuses to overwrite an existing version folder' {
    # ProGet versions are immutable; silently replacing one hides what is deployed.
    $existing = Join-Path (Join-Path $script:ModulesRoot $script:Name) $script:Version
    New-Item -ItemType Directory -Path $existing -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $existing 'sentinel.txt') -Value 'do not clobber'

    $r = Install-ATAPModuleAllUsers -ModuleName $script:Name -RequiredVersion $script:Version `
      -Repository 'powershellget-stable' -FeedUrl 'http://localhost:50000/nuget/powershellget-stable' `
      -ExpectedSha256 $script:NupkgHash -ModulesRoot $script:ModulesRoot -DeployRoot $script:DeployRoot -Confirm:$false

    $r.ExitStatus | Should -Be 1
    $r.ErrorText | Should -Match 'already exists'
    # The pre-existing install must survive, and must NOT be rolled back.
    Get-Content -LiteralPath (Join-Path $existing 'sentinel.txt') | Should -Be 'do not clobber'
    $r.RolledBack | Should -BeFalse
  }

  It 'fails closed when a declared dependency is below its floor' {
    Mock Get-ATAPModuleInstalledVersions { @{ PSFramework = '1.0.0' } }
    $pkgSrc = Join-Path $script:Root 'pkgsrc'
    Set-Content -LiteralPath (Join-Path $pkgSrc "$script:Name.psd1") `
      -Value "@{ ModuleVersion = '$script:Version'; RootModule = '$script:Name.psm1'; RequiredModules = @(@{ ModuleName = 'PSFramework'; ModuleVersion = '1.14.457' }) }"
    Compress-Archive -Path (Join-Path $pkgSrc '*') -DestinationPath $script:Nupkg -Force
    $hash = (Get-FileHash -Algorithm SHA256 -Path $script:Nupkg).Hash

    $r = Install-ATAPModuleAllUsers -ModuleName $script:Name -RequiredVersion $script:Version `
      -Repository 'powershellget-stable' -FeedUrl 'http://localhost:50000/nuget/powershellget-stable' `
      -ExpectedSha256 $hash -ModulesRoot $script:ModulesRoot -DeployRoot $script:DeployRoot -Confirm:$false

    $r.ExitStatus | Should -Be 1
    $r.ErrorText | Should -Match 'floor requirements'
    $r.DependencyFailures.Count | Should -Be 1
    Test-Path -LiteralPath (Join-Path (Join-Path $script:ModulesRoot $script:Name) $script:Version) | Should -BeFalse
  }

  It 'rolls back a version folder it created when validation fails afterwards' {
    # The install must be all-or-nothing: a leftover folder makes the NEXT attempt fail with
    # "already exists" instead of the real error.
    Mock Import-Module { throw 'simulated import failure' } -ParameterFilter { $FullyQualifiedName }

    $r = Install-ATAPModuleAllUsers -ModuleName $script:Name -RequiredVersion $script:Version `
      -Repository 'powershellget-stable' -FeedUrl 'http://localhost:50000/nuget/powershellget-stable' `
      -ExpectedSha256 $script:NupkgHash -ModulesRoot $script:ModulesRoot -DeployRoot $script:DeployRoot -Confirm:$false

    $r.ExitStatus | Should -Be 1
    $r.RolledBack | Should -BeTrue
    $r.VersionPath | Should -BeNullOrEmpty
    Test-Path -LiteralPath (Join-Path (Join-Path $script:ModulesRoot $script:Name) $script:Version) | Should -BeFalse
  }
}
