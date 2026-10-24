#Requires -Version 7.0
param([string]$FixtureRoot)

# Task 13.76.c — canonical validated AllUsers installer, promoted from the standalone
# _Planning script. Coverage includes fixture staging with the import boundary mocked: the standalone
# version shipped with green unit tests and had never completed an install, because every
# defect that mattered sat in the untested path between download and fresh import.

BeforeAll {
  # The reviewed isolated run disables Pester's automatic TEMP TestDrive and supplies
  # a unique physical fixture root under this repository's _generated directory.
  if ($FixtureRoot) { $TestDrive = $FixtureRoot }
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
  . (Join-Path $publicDir 'Test-PSModulePackageSignature.ps1')
}

Describe 'Get-ATAPModuleVersionInstallPath' {
  BeforeEach { Mock Write-PSFMessage { } }

  It 'composes <ModulesRoot>\<Name>\<Version>' {
    $expected = Join-Path (Join-Path 'C:\Modules' 'ATAP.Utilities') '1.2.3'
    Get-ATAPModuleVersionInstallPath -ModuleName 'ATAP.Utilities' -RequiredVersion '1.2.3' -ModulesRoot 'C:\Modules' |
      Should -Be $expected
  }
}

Describe 'Test-ATAPModuleFileHash' {
  BeforeEach { Mock Write-PSFMessage { } }

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
  BeforeEach { Mock Write-PSFMessage { } }

  BeforeAll {
    $script:Feed = 'https://localhost:50000/nuget/powershellget-stable'
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
    $uris = @(Get-ATAPModuleDownloadCandidateUris -BaseFeedUrl 'https://utat01:50000/nuget/powershellget-stable' -ModuleName $script:Name -RequiredVersion $script:Version)
    $uris[0] | Should -Match '^https://localhost:50000/'
    @($uris | Where-Object { $_ -match '^https://utat01:50000/' }).Count | Should -BeGreaterThan 0
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
  BeforeEach { Mock Write-PSFMessage { } }

  It 'returns the first reachable candidate' {
    Mock Test-ATAPModuleEndpointReachable { $Uri -notmatch '/api/v2/' }
    $uri = Get-ATAPModuleDownloadUri -FeedUrl 'https://localhost:50000/nuget/powershellget-stable' -ModuleName 'M' -RequiredVersion '1.0.0'
    $uri | Should -Be 'https://localhost:50000/nuget/powershellget-stable/package/M/1.0.0'
  }

  It 'falls through to the OData endpoint when the direct form is unreachable' {
    Mock Test-ATAPModuleEndpointReachable { $Uri -match '/api/v2/' }
    $uri = Get-ATAPModuleDownloadUri -FeedUrl 'https://localhost:50000/nuget/powershellget-stable' -ModuleName 'M' -RequiredVersion '1.0.0'
    $uri | Should -Be 'https://localhost:50000/nuget/powershellget-stable/api/v2/package/M/1.0.0'
  }

  It 'throws when no candidate is reachable' {
    Mock Test-ATAPModuleEndpointReachable { $false }
    { Get-ATAPModuleDownloadUri -FeedUrl 'https://localhost:50000/nuget/powershellget-stable' -ModuleName 'M' -RequiredVersion '1.0.0' } |
      Should -Throw -ExpectedMessage '*No reachable download URI*'
  }
}

Describe 'Get-ATAPModuleDependencyFloorViolations' {
  BeforeEach { Mock Write-PSFMessage { } }

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
  BeforeEach { Mock Write-PSFMessage { } }

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
  BeforeAll {
    if (-not (Get-Command Get-PVal -ErrorAction SilentlyContinue)) {
      function Get-PVal {
        [CmdletBinding()]
        param($ParameterName, $dottedPath, $originalPSBoundParameters, $Settings)
        throw 'The settings resolver must be mocked in installer unit tests.'
      }
    }
    function Invoke-FixtureInstall {
      Install-ATAPModuleAllUsers -ModuleName $script:Name -RequiredVersion $script:Version `
        -Repository 'powershellget-stable' -FeedUrl 'https://localhost:50000/nuget/powershellget-stable' `
        -ExpectedSha256 $script:NupkgHash -ModulesRoot $script:ModulesRoot -DeployRoot $script:DeployRoot -Confirm:$false
    }
  }

  BeforeEach {
    Mock Write-PSFMessage { }
    $script:SavedSettings = Get-Variable -Name settings -Scope Global -ErrorAction SilentlyContinue
    $script:SavedKeys = Get-Variable -Name configRootKeys -Scope Global -ErrorAction SilentlyContinue
    $script:SavedSettingsValue = if ($script:SavedSettings) { $script:SavedSettings.Value } else { $null }
    $script:SavedKeysValue = if ($script:SavedKeys) { $script:SavedKeys.Value } else { $null }
    $script:Root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    $script:ModulesRoot = Join-Path $script:Root 'Modules'
    $script:DeployRoot = Join-Path $script:Root 'deploy'
    New-Item -ItemType Directory -Path $script:ModulesRoot, $script:DeployRoot -Force | Out-Null
    $script:FastTemp = Join-Path $script:Root 'configured-temp'
    New-Item -ItemType Directory -Path $script:FastTemp | Out-Null
    $global:configRootKeys = @{ FastTempBasePathConfigRootKey = 'FAST_TEMP_BASE_PATH' }
    $global:settings = @{ FAST_TEMP_BASE_PATH = $script:FastTemp }
    $script:DownloadPaths = [Collections.Generic.List[string]]::new()

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
    Mock Get-ATAPModuleDownloadUri { 'https://localhost:50000/nuget/powershellget-stable/package/Fixture.Module/1.0.0' }
    Mock Invoke-WebRequest {
      $script:DownloadPaths.Add($OutFile)
      Copy-Item -LiteralPath $script:Nupkg -Destination $OutFile -Force
    }
    Mock Get-PVal { $Settings[$dottedPath] }
    Mock Get-Item {
      # Model metadata for synthetic fixtures, while retaining real creation/copy/removal.
      # Sync-backed fixture attributes are not an input to these installer unit cases.
      # Adverse tests below override this default with explicit reparse/denial metadata.
      $candidate = [IO.Path]::GetFullPath([string]$LiteralPath)
      $boundary = [IO.Path]::GetFullPath($script:Root).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
      if (-not $candidate.StartsWith($boundary, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Unexpected metadata probe outside owned fixture: $candidate"
      }
      $isDirectory = [IO.Directory]::Exists($candidate)
      if (-not $isDirectory -and -not [IO.File]::Exists($candidate)) {
        throw "Fixture path does not exist: $candidate"
      }
      [pscustomobject]@{
        FullName = $candidate
        PSProvider = [pscustomobject]@{ Name = 'FileSystem' }
        PSIsContainer = $isDirectory
        Attributes = if ($isDirectory) { [IO.FileAttributes]::Directory } else { [IO.FileAttributes]::Normal }
      }
    }
    Mock Register-PSRepository { throw 'Unexpected repository registration in unit tests.' }
    Mock Unregister-PSRepository { }
    Mock Import-Module { } -ParameterFilter { $FullyQualifiedName }
    Mock Remove-Module { } -ParameterFilter { $Name -eq $script:Name }
    Mock Get-Module {
      [pscustomobject]@{
        ModuleBase = Join-Path (Join-Path $script:ModulesRoot $script:Name) $script:Version
        Version = [version]$script:Version
      }
    } -ParameterFilter { $Name -eq $script:Name }
    Mock Get-ATAPModuleInstalledVersions { @{} }
    Mock Test-PSModulePackageSignature { [pscustomobject]@{ Valid = $true } }
    Mock Start-Transcript { }
    Mock Stop-Transcript { }
  }

  AfterEach {
    if ($script:SavedSettings) { $global:settings = $script:SavedSettingsValue }
    else { Remove-Variable -Name settings -Scope Global -ErrorAction SilentlyContinue }
    if ($script:SavedKeys) { $global:configRootKeys = $script:SavedKeysValue }
    else { Remove-Variable -Name configRootKeys -Scope Global -ErrorAction SilentlyContinue }
  }

  It 'uses the configured root despite a different process TEMP and cleans only its unique child' {
    $originalTemp = $env:TEMP
    $script:FastTemp | Should -Not -Be $originalTemp
    $sentinel = Join-Path $script:FastTemp 'unrelated.txt'
    Set-Content -LiteralPath $sentinel -Value 'retain'
    $unrelated = Join-Path $script:FastTemp 'ATAP-InstallModule-preexisting'
    New-Item -ItemType Directory -Path $unrelated | Out-Null
    $r = Invoke-FixtureInstall
    $r.ExitStatus | Should -Be 0
    $child = Split-Path $script:DownloadPaths[0] -Parent
    (Split-Path $child -Parent) | Should -Be $script:FastTemp
    (Split-Path $child -Leaf) | Should -Match '^ATAP-InstallModule-[0-9a-f]{32}$'
    Test-Path -LiteralPath $child | Should -BeFalse
    Get-Content -LiteralPath $sentinel | Should -Be 'retain'
    Test-Path -LiteralPath $unrelated | Should -BeTrue
    $env:TEMP | Should -Be $originalTemp
    Should -Invoke Get-PVal -Times 1 -Exactly -ParameterFilter {
      $ParameterName -eq 'FAST_TEMP_BASE_PATH' -and $dottedPath -eq 'FAST_TEMP_BASE_PATH' -and
      $originalPSBoundParameters.Count -eq 0 -and $Settings.FAST_TEMP_BASE_PATH -eq $script:FastTemp
    }
  }

  It 'chooses a different owned child for each attempt' {
    Invoke-FixtureInstall | Out-Null
    # The second call reaches download but refuses to overwrite the first fixture install.
    $r = Invoke-FixtureInstall
    $r.ErrorText | Should -Match 'already exists'
    $script:DownloadPaths.Count | Should -Be 2
    $script:DownloadPaths[0] | Should -Not -Be $script:DownloadPaths[1]
    foreach ($download in $script:DownloadPaths) {
      Test-Path -LiteralPath (Split-Path $download -Parent) | Should -BeFalse
    }
  }

  It 'fails before repository or download access for invalid FastTemp configuration: <Case>' -ForEach @(
    @{ Case = 'missing key'; Kind = 'key'; Value = $null }
    @{ Case = 'missing settings'; Kind = 'settings'; Value = $null }
    @{ Case = 'missing value'; Kind = 'value'; Value = $null }
    @{ Case = 'empty value'; Kind = 'path'; Value = '' }
    @{ Case = 'whitespace'; Kind = 'path'; Value = '  ' }
    @{ Case = 'nonstring'; Kind = 'path'; Value = 42 }
    @{ Case = 'relative'; Kind = 'path'; Value = 'temp' }
    @{ Case = 'drive relative'; Kind = 'path'; Value = 'C:temp' }
    @{ Case = 'provider'; Kind = 'path'; Value = 'Registry::HKEY_CURRENT_USER\Temp' }
    @{ Case = 'UNC'; Kind = 'path'; Value = '\\server\share\temp' }
    @{ Case = 'drive root'; Kind = 'path'; Value = 'C:\' }
    @{ Case = 'alternate stream'; Kind = 'path'; Value = 'C:\Temp:stream' }
  ) {
    switch ($Kind) {
      'key' { $global:configRootKeys = @{} }
      'settings' { Remove-Variable -Name settings -Scope Global }
      'value' { $global:settings = @{} }
      'path' { $global:settings.FAST_TEMP_BASE_PATH = $Value }
    }
    $r = Invoke-FixtureInstall
    $r.ExitStatus | Should -Be 1
    $r.ErrorText | Should -Not -BeNullOrEmpty
    Should -Invoke Get-PSRepository -Times 0 -Exactly
    Should -Invoke Register-PSRepository -Times 0 -Exactly
    Should -Invoke Invoke-WebRequest -Times 0 -Exactly
    Should -Invoke Import-Module -Times 0 -Exactly -ParameterFilter { $FullyQualifiedName }
    @(Get-ChildItem -LiteralPath $script:FastTemp -Force).Count | Should -Be 0
  }

  It 'rejects a conflicting resolver override instead of using another root' {
    Mock Get-PVal { $env:TEMP }
    $r = Invoke-FixtureInstall
    $r.ExitStatus | Should -Be 1
    $r.ErrorText | Should -Match 'differs from global settings'
    Should -Invoke Invoke-WebRequest -Times 0 -Exactly
  }

  It 'rejects a configured <Kind> before download' -ForEach @(@{ Kind = 'file' }, @{ Kind = 'absent' }) {
    $invalid = Join-Path $script:Root $Kind
    if ($Kind -eq 'file') { Set-Content -LiteralPath $invalid -Value 'retain' }
    $global:settings.FAST_TEMP_BASE_PATH = $invalid
    (Invoke-FixtureInstall).ExitStatus | Should -Be 1
    Should -Invoke Invoke-WebRequest -Times 0 -Exactly
  }

  It 'does not adopt or clean a child when directory creation fails' {
    Mock New-Item { throw 'simulated staging collision' } -ParameterFilter {
      $Path -like "$script:FastTemp*ATAP-InstallModule-*"
    }
    Mock Remove-Item { throw 'Unexpected cleanup of unowned path' } -ParameterFilter {
      $LiteralPath -like "$script:FastTemp*"
    }
    $r = Invoke-FixtureInstall
    $r.ErrorText | Should -Match 'staging collision'
    Should -Invoke Remove-Item -Times 0 -Exactly -ParameterFilter { $LiteralPath -like "$script:FastTemp*" }
    Should -Invoke Invoke-WebRequest -Times 0 -Exactly
  }

  It 'records cleanup failure in both returned and persisted results' {
    Mock Remove-Item { throw 'simulated cleanup denial' } -ParameterFilter {
      $LiteralPath -like "$script:FastTemp*ATAP-InstallModule-*"
    }
    $r = Invoke-FixtureInstall
    $r.ExitStatus | Should -Be 1
    $r.ErrorText | Should -Match 'Staging cleanup failed.*cleanup denial'
    $record = Get-Content -LiteralPath $r.ResultJsonPath -Raw | ConvertFrom-Json
    $record.ExitStatus | Should -Be 1
    $record.ErrorText | Should -Be $r.ErrorText
    Test-Path -LiteralPath (Split-Path $script:DownloadPaths[0] -Parent) | Should -BeTrue
  }

  It 'rejects a configured reparse point before directory creation or download' {
    Mock Get-Item {
      [pscustomobject]@{
        PSProvider = [pscustomobject]@{ Name = 'FileSystem' }
        PSIsContainer = $true
        Attributes = [IO.FileAttributes]::Directory -bor [IO.FileAttributes]::ReparsePoint
      }
    } -ParameterFilter { $LiteralPath -eq $script:FastTemp }
    $r = Invoke-FixtureInstall
    $r.ErrorText | Should -Match 'without a reparse point'
    Should -Invoke Invoke-WebRequest -Times 0 -Exactly
    @(Get-ChildItem -LiteralPath $script:FastTemp).Count | Should -Be 0
  }

  It 'refuses recursive cleanup if the owned child is replaced by a reparse point' {
    # Metadata substitution only: never create a real link to another directory.
    Mock Get-Item {
      [pscustomobject]@{
        PSIsContainer = $true
        Attributes = [IO.FileAttributes]::Directory -bor [IO.FileAttributes]::ReparsePoint
      }
    } -ParameterFilter { $LiteralPath -like "$script:FastTemp*ATAP-InstallModule-*" }
    Mock Remove-Item { throw 'Unexpected recursive cleanup' } -ParameterFilter {
      $LiteralPath -like "$script:FastTemp*ATAP-InstallModule-*"
    }
    $r = Invoke-FixtureInstall
    $r.ExitStatus | Should -Be 1
    $r.ErrorText | Should -Match 'cleanup refused.*reparse point'
    $record = Get-Content -LiteralPath $r.ResultJsonPath -Raw | ConvertFrom-Json
    $record.ExitStatus | Should -Be 1
    $record.ErrorText | Should -Be $r.ErrorText
    Should -Invoke Remove-Item -Times 0 -Exactly -ParameterFilter {
      $LiteralPath -like "$script:FastTemp*ATAP-InstallModule-*"
    }
  }

  It 'records an unreadable owned child as unknown cleanup rather than success' {
    Mock Get-Item { throw 'simulated probe denial' } -ParameterFilter {
      $LiteralPath -like "$script:FastTemp*ATAP-InstallModule-*"
    }
    $r = Invoke-FixtureInstall
    $r.ExitStatus | Should -Be 1
    $r.ErrorText | Should -Match 'Staging cleanup failed.*probe denial'
    $record = Get-Content -LiteralPath $r.ResultJsonPath -Raw | ConvertFrom-Json
    $record.ExitStatus | Should -Be 1
  }

  It 'rejects a cleartext feed URL at parameter binding' {
    { Install-ATAPModuleAllUsers -ModuleName $script:Name -RequiredVersion $script:Version `
        -Repository 'powershellget-stable' -FeedUrl 'http://localhost:50000/nuget/powershellget-stable' `
        -ExpectedSha256 $script:NupkgHash -ModulesRoot $script:ModulesRoot -DeployRoot $script:DeployRoot -Confirm:$false } |
      Should -Throw '*absolute HTTPS URI*'

    Should -Invoke Invoke-WebRequest -Times 0 -Exactly -Scope It
  }

  It 'installs into <ModulesRoot>\<Name>\<Version> and validates the fresh import' {
    $r = Install-ATAPModuleAllUsers -ModuleName $script:Name -RequiredVersion $script:Version `
      -Repository 'powershellget-stable' -FeedUrl 'https://localhost:50000/nuget/powershellget-stable' `
      -ExpectedSha256 $script:NupkgHash -ModulesRoot $script:ModulesRoot -DeployRoot $script:DeployRoot -Confirm:$false

    $r.ExitStatus | Should -Be 0
    $r.SignatureVerified | Should -BeTrue
    $r.ErrorText | Should -BeNullOrEmpty
    $expected = Join-Path (Join-Path $script:ModulesRoot $script:Name) $script:Version
    $r.VersionPath | Should -Be $expected

    # The manifest must sit directly in the version folder, NOT nested one level deeper.
    Test-Path -LiteralPath (Join-Path $expected "$script:Name.psd1") | Should -BeTrue
    Test-Path -LiteralPath (Join-Path $expected 'expand') | Should -BeFalse
  }

  It 'creates the version folder at the AllUsers root instead of moving the broker-temp folder' {
    $r = Install-ATAPModuleAllUsers -ModuleName $script:Name -RequiredVersion $script:Version `
      -Repository 'powershellget-stable' -FeedUrl 'https://localhost:50000/nuget/powershellget-stable' `
      -ExpectedSha256 $script:NupkgHash -ModulesRoot $script:ModulesRoot -DeployRoot $script:DeployRoot -Confirm:$false

    $r.ExitStatus | Should -Be 0
    $expected = Join-Path (Join-Path $script:ModulesRoot $script:Name) $script:Version
    $parent = Split-Path -Path $expected -Parent
    (Get-Acl -LiteralPath $expected).AreAccessRulesProtected | Should -BeFalse
    (Get-Acl -LiteralPath $expected).AccessToString | Should -Be (Get-Acl -LiteralPath $parent).AccessToString
  }

  It 'writes a JSON result record for the run' {
    $r = Install-ATAPModuleAllUsers -ModuleName $script:Name -RequiredVersion $script:Version `
      -Repository 'powershellget-stable' -FeedUrl 'https://localhost:50000/nuget/powershellget-stable' `
      -ExpectedSha256 $script:NupkgHash -ModulesRoot $script:ModulesRoot -DeployRoot $script:DeployRoot -Confirm:$false

    Test-Path -LiteralPath $r.ResultJsonPath | Should -BeTrue
    $record = Get-Content -LiteralPath $r.ResultJsonPath -Raw | ConvertFrom-Json
    $record.ExitStatus | Should -Be 0
    $record.ActualSha256 | Should -Be $script:NupkgHash
  }

  It 'refuses a package whose hash does not match the pin, and installs nothing' {
    $r = Install-ATAPModuleAllUsers -ModuleName $script:Name -RequiredVersion $script:Version `
      -Repository 'powershellget-stable' -FeedUrl 'https://localhost:50000/nuget/powershellget-stable' `
      -ExpectedSha256 ('A' * 64) -ModulesRoot $script:ModulesRoot -DeployRoot $script:DeployRoot -Confirm:$false

    $r.ExitStatus | Should -Be 1
    $r.ErrorText | Should -Match 'SHA-256 validation failed'
    Test-Path -LiteralPath (Join-Path (Join-Path $script:ModulesRoot $script:Name) $script:Version) | Should -BeFalse
  }

  It 'rejects an unsigned package before expanding or installing it' {
    Mock Test-PSModulePackageSignature { throw 'PowerShell package signature verification failed: NotSigned' }

    $r = Install-ATAPModuleAllUsers -ModuleName $script:Name -RequiredVersion $script:Version `
      -Repository 'powershellget-stable' -FeedUrl 'https://localhost:50000/nuget/powershellget-stable' `
      -ExpectedSha256 $script:NupkgHash -ModulesRoot $script:ModulesRoot -DeployRoot $script:DeployRoot -Confirm:$false

    $r.ExitStatus | Should -Be 1
    $r.SignatureVerified | Should -BeFalse
    $r.ErrorText | Should -Match 'signature verification failed'
    Test-Path -LiteralPath (Join-Path (Join-Path $script:ModulesRoot $script:Name) $script:Version) | Should -BeFalse
  }

  It 'exits 2 without installing when not elevated' {
    Mock Test-ATAPModuleAllUsersElevated { $false }
    $r = Install-ATAPModuleAllUsers -ModuleName $script:Name -RequiredVersion $script:Version `
      -Repository 'powershellget-stable' -FeedUrl 'https://localhost:50000/nuget/powershellget-stable' `
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
      -Repository 'powershellget-stable' -FeedUrl 'https://localhost:50000/nuget/powershellget-stable' `
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
      -Repository 'powershellget-stable' -FeedUrl 'https://localhost:50000/nuget/powershellget-stable' `
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
      -Repository 'powershellget-stable' -FeedUrl 'https://localhost:50000/nuget/powershellget-stable' `
      -ExpectedSha256 $script:NupkgHash -ModulesRoot $script:ModulesRoot -DeployRoot $script:DeployRoot -Confirm:$false

    $r.ExitStatus | Should -Be 1
    $r.RolledBack | Should -BeTrue
    $r.VersionPath | Should -BeNullOrEmpty
    Test-Path -LiteralPath (Join-Path (Join-Path $script:ModulesRoot $script:Name) $script:Version) | Should -BeFalse
  }
}
