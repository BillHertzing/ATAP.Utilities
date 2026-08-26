#Requires -Version 7.0
# Pester tests for the isolated promoted-package consumer gate. All external actions are mocked.

BeforeAll {
    $publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
    . (Join-Path $publicDir 'Invoke-PromotedPackageTests.ps1')
    $script:artifactsRoot = Join-Path ([IO.Path]::GetTempPath()) ('ATAP-F03-consumer-' + [guid]::NewGuid().ToString('N'))
    $script:artifactsPath = Join-Path $script:artifactsRoot 'dotnet\ATAP.Utilities\wt-promoted\exec-promoted'
    $script:artifactsContext = [pscustomobject]@{
        Root = $script:artifactsRoot
        WorktreeId = 'wt-promoted'
        ExecutionId = 'exec-promoted'
        ArtifactsPath = $script:artifactsPath
        BinlogPath = Join-Path $script:artifactsPath 'logs\promoted.binlog'
        PackageStagingPath = Join-Path $script:artifactsPath 'packages'
        PublishStagingPath = Join-Path $script:artifactsPath 'publish'
    }
    $script:previousContextDefault = $PSDefaultParameterValues['Invoke-PromotedPackageTests:ArtifactsContext']
    $PSDefaultParameterValues['Invoke-PromotedPackageTests:ArtifactsContext'] = $script:artifactsContext
    if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
        function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
    }
    function global:dotnet { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
    $script:GetExpectedConsumerProject = {
        param([string]$Name = 'pkg', [string]$Version = '1.0.0')
        $escapedName = [Security.SecurityElement]::Escape($Name)
        $escapedVersion = [Security.SecurityElement]::Escape($Version)
        $targetFramework = if ($Name.EndsWith('.Windows', [StringComparison]::OrdinalIgnoreCase)) { 'net8.0-windows7.0' } else { 'net8.0' }
        return (@(
                '<Project Sdk="Microsoft.NET.Sdk">'
                '  <PropertyGroup>'
                "    <TargetFramework>$targetFramework</TargetFramework>"
                '    <ManagePackageVersionsCentrally>false</ManagePackageVersionsCentrally>'
                '    <RestorePackagesWithLockFile>true</RestorePackagesWithLockFile>'
                '  </PropertyGroup>'
                '  <ItemGroup>'
                ('    <PackageReference Include="{0}" Version="{1}" />' -f $escapedName, $escapedVersion)
                '  </ItemGroup>'
                '</Project>'
            ) -join [Environment]::NewLine) + [Environment]::NewLine
    }
}

AfterAll {
    if ($null -eq $script:previousContextDefault) { $PSDefaultParameterValues.Remove('Invoke-PromotedPackageTests:ArtifactsContext') }
    else { $PSDefaultParameterValues['Invoke-PromotedPackageTests:ArtifactsContext'] = $script:previousContextDefault }
    Remove-Item function:global:dotnet -ErrorAction SilentlyContinue
}

Describe 'Invoke-PromotedPackageTests isolated consumer gate' -Tag 'Unit' {
    BeforeEach {
        Mock Write-PSFMessage { }
        Mock New-Item { }
        Mock Set-Content { }
        Mock Test-Path { $true }
        Mock Get-Content { 'ATAP.Utilities|wt-promoted|exec-promoted' }
        Mock Get-Content -ParameterFilter { $LiteralPath -like '*NuGet.Config' } {
            @'
<configuration>
  <packageSources>
    <clear />
    <add key="nuget-experimental" value="https://utat022:50000/nuget/nuget-experimental/v3/index.json" />
    <add key="nuget-development" value="https://utat022:50000/nuget/nuget-development/v3/index.json" />
    <add key="nuget-integration" value="https://utat022:50000/nuget/nuget-integration/v3/index.json" />
    <add key="nuget-qa" value="https://utat022:50000/nuget/nuget-qa/v3/index.json" />
    <add key="nuget-stable" value="https://utat022:50000/nuget/nuget-stable/v3/index.json" />
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
  </packageSources>
</configuration>
'@
        }
        Mock Get-Content -ParameterFilter { $LiteralPath -like '*.csproj' } { & $script:GetExpectedConsumerProject }
        Mock Get-Content -ParameterFilter { $LiteralPath -like '*.nupkg.metadata' } {
            '{"version":2,"source":"https://utat022:50000/nuget/nuget-development/v3/index.json"}'
        }
        Mock dotnet { $global:LASTEXITCODE = 0 }
    }

    It 'short-circuits WhatIf without writing or invoking dotnet' {
        $result = Invoke-PromotedPackageTests -Name 'pkg' -Version '1.0.0' -Feed 'nuget-development' -ResultsPath 'consumer' -ProGetUrl 'https://utat022:50000' -WhatIf
        $result.GatePass | Should -BeTrue
        $result.ResponseSummary | Should -Match 'isolated consumer'
        Assert-MockCalled dotnet -Times 0 -Exactly -Scope It
        Assert-MockCalled Set-Content -Times 0 -Exactly -Scope It
    }

    It 'writes one execution-scoped net8 consumer with an XML-escaped exact PackageReference' {
        Mock Test-Path -ParameterFilter { $LiteralPath -like '*.csproj' } { $false }
        $result = Invoke-PromotedPackageTests -Name 'Pkg&<"''' -Version '1.0&<"''' -Feed 'nuget-development' -ResultsPath 'consumer' -ProGetUrl 'https://utat022:50000'
        $result.ProjectPath | Should -BeLike "$($script:artifactsPath)*promoted-consumer*PromotedPackageConsumer.csproj"
        Assert-MockCalled Set-Content -Times 1 -Exactly -Scope It -ParameterFilter {
            $LiteralPath -like '*.csproj' -and
            ([regex]::Matches([string]$Value, '<PackageReference\s+')).Count -eq 1 -and
            [string]$Value -match 'Include="Pkg&amp;&lt;&quot;&apos;"' -and
            [string]$Value -match 'Version="1\.0&amp;&lt;&quot;&apos;"' -and
            [string]$Value -match '<TargetFramework>net8\.0</TargetFramework>' -and
            [string]$Value -match '<ManagePackageVersionsCentrally>false</ManagePackageVersionsCentrally>' -and
            [string]$Value -match '<RestorePackagesWithLockFile>true</RestorePackagesWithLockFile>'
        }
    }

    It 'targets net8.0-windows7.0 for Windows package IDs case-insensitively' {
        Mock Test-Path -ParameterFilter { $LiteralPath -like '*.csproj' } { $false }
        Invoke-PromotedPackageTests -Name 'ATAP.Utilities.Example.wInDoWs' -Version '1.0.0' -Feed 'nuget-development' -ResultsPath 'consumer' -ProGetUrl 'https://utat022:50000' | Out-Null
        Assert-MockCalled Set-Content -Times 1 -Exactly -Scope It -ParameterFilter {
            $LiteralPath -like '*.csproj' -and
            [string]$Value -match '<TargetFramework>net8\.0-windows7\.0</TargetFramework>' -and
            [string]$Value -notmatch '<TargetFramework>net8\.0</TargetFramework>'
        }
    }

    It 'does not treat an embedded Windows segment as a Windows package suffix' {
        Mock Test-Path -ParameterFilter { $LiteralPath -like '*.csproj' } { $false }
        Invoke-PromotedPackageTests -Name 'ATAP.Utilities.Windows.Interfaces' -Version '1.0.0' -Feed 'nuget-development' -ResultsPath 'consumer' -ProGetUrl 'https://utat022:50000' | Out-Null
        Assert-MockCalled Set-Content -Times 1 -Exactly -Scope It -ParameterFilter {
            $LiteralPath -like '*.csproj' -and
            [string]$Value -match '<TargetFramework>net8\.0</TargetFramework>' -and
            [string]$Value -notmatch 'net8\.0-windows7\.0'
        }
    }
    It 'restores the consumer from the requested tier plus stable dependency fallback and configured public sources' {
        Invoke-PromotedPackageTests -Name 'pkg' -Version '1.0.0' -Feed 'nuget-development' -ProjectPath 'ATAP.Utilities.Production.slnf' -ResultsPath 'consumer' -ProGetUrl 'https://utat022:50000' | Out-Null
        Assert-MockCalled dotnet -Times 1 -Exactly -Scope It -ParameterFilter {
            $rest[0] -eq 'restore' -and $rest[1] -like '*PromotedPackageConsumer.csproj' -and
            -not ($rest -contains 'ATAP.Utilities.Production.slnf') -and
            ($rest -contains 'https://utat022:50000/nuget/nuget-development/v3/index.json') -and
            ($rest -contains 'https://api.nuget.org/v3/index.json') -and
            -not ($rest -contains 'https://utat022:50000/nuget/nuget-experimental/v3/index.json') -and
            -not ($rest -contains 'https://utat022:50000/nuget/nuget-integration/v3/index.json') -and
            -not ($rest -contains 'https://utat022:50000/nuget/nuget-qa/v3/index.json') -and
            ($rest -contains 'https://utat022:50000/nuget/nuget-stable/v3/index.json') -and
            ($rest -contains '/p:ImportDirectoryBuildProps=false') -and
            ($rest -contains '/p:ImportDirectoryBuildTargets=false') -and
            ($rest -contains '/p:ImportDirectoryPackagesProps=false') -and
            ($rest -contains '/p:ManagePackageVersionsCentrally=false') -and
            ($rest -contains '--force') -and ($rest -contains '--no-cache') -and ($rest -contains '--packages')
        }
    }

    It 'does not duplicate stable when stable is the requested tier' {
        Mock Get-Content -ParameterFilter { $LiteralPath -like '*.nupkg.metadata' } {
            '{"version":2,"source":"https://utat022:50000/nuget/nuget-stable/v3/index.json"}'
        }
        Invoke-PromotedPackageTests -Name 'pkg' -Version '1.0.0' -Feed 'nuget-stable' -ResultsPath 'consumer' -ProGetUrl 'https://utat022:50000' | Out-Null
        Assert-MockCalled dotnet -Times 1 -Exactly -Scope It -ParameterFilter {
            $rest[0] -eq 'restore' -and
            @($rest | Where-Object { $_ -eq 'https://utat022:50000/nuget/nuget-stable/v3/index.json' }).Count -eq 1
        }
    }
    It 'compiles only the isolated consumer with build --no-restore and never test pack or the SUT target' {
        Invoke-PromotedPackageTests -Name 'pkg' -Version '1.0.0' -Feed 'nuget-development' -ProjectPath 'src/SUT/SUT.csproj' -ResultsPath 'consumer' -ProGetUrl 'https://utat022:50000' | Out-Null
        Assert-MockCalled dotnet -Times 1 -Exactly -Scope It -ParameterFilter {
            $rest[0] -eq 'build' -and $rest[1] -like '*PromotedPackageConsumer.csproj' -and
            ($rest -contains '--no-restore') -and -not ($rest -contains 'src/SUT/SUT.csproj')
        }
        Assert-MockCalled dotnet -Times 0 -Exactly -Scope It -ParameterFilter { $rest[0] -in @('test', 'pack') }
    }

    It 'allows Development to update the project and lock without locked mode' {
        Mock Test-Path -ParameterFilter { $LiteralPath -like '*.csproj' } { $false }
        Invoke-PromotedPackageTests -Name 'pkg' -Version '1.0.0' -Feed 'nuget-development' -ResultsPath 'consumer' -ProGetUrl 'https://utat022:50000' | Out-Null
        Assert-MockCalled Set-Content -Times 1 -Exactly -Scope It -ParameterFilter { $LiteralPath -like '*.csproj' }
        Assert-MockCalled dotnet -Times 1 -Exactly -Scope It -ParameterFilter { $rest[0] -eq 'restore' -and -not ($rest -contains '--locked-mode') }
    }

    It 'fails a locked tier before dotnet when the persisted lock is missing' {
        Mock Test-Path -ParameterFilter { $LiteralPath -like '*packages.lock.json' } { $false }
        { Invoke-PromotedPackageTests -Name 'pkg' -Version '1.0.0' -Feed 'nuget-integration' -ResultsPath 'consumer' -ProGetUrl 'https://utat022:50000' -LockedRestore } | Should -Throw '*requires the persisted lock file*'
        Assert-MockCalled dotnet -Times 0 -Exactly -Scope It
    }

    It 'fails a locked tier before dotnet when the consumer project drifted' {
        Mock Get-Content -ParameterFilter { $LiteralPath -like '*.csproj' } { '<Project />' }
        { Invoke-PromotedPackageTests -Name 'pkg' -Version '1.0.0' -Feed 'nuget-integration' -ResultsPath 'consumer' -ProGetUrl 'https://utat022:50000' -LockedRestore } | Should -Throw '*consumer project drifted*'
        Assert-MockCalled dotnet -Times 0 -Exactly -Scope It
    }

    It 'uses locked restore without rewriting the deterministic consumer at locked tiers' {
        Mock Get-Content -ParameterFilter { $LiteralPath -like '*.nupkg.metadata' } {
            '{"version":2,"source":"https://utat022:50000/nuget/nuget-integration/v3/index.json"}'
        }
        $result = Invoke-PromotedPackageTests -Name 'pkg' -Version '1.0.0' -Feed 'nuget-integration' -ResultsPath 'consumer' -ProGetUrl 'https://utat022:50000' -LockedRestore
        $result.GatePass | Should -BeTrue
        Assert-MockCalled Set-Content -Times 0 -Exactly -Scope It
        Assert-MockCalled dotnet -Times 1 -Exactly -Scope It -ParameterFilter { $rest[0] -eq 'restore' -and ($rest -contains '--locked-mode') }
    }

    It 'fails provenance closed and skips compile when metadata names another tier' {
        Mock Get-Content -ParameterFilter { $LiteralPath -like '*.nupkg.metadata' } {
            '{"version":2,"source":"https://utat022:50000/nuget/nuget-stable/v3/index.json"}'
        }
        $result = Invoke-PromotedPackageTests -Name 'pkg' -Version '1.0.0' -Feed 'nuget-development' -ResultsPath 'consumer' -ProGetUrl 'https://utat022:50000'
        $result.GatePass | Should -BeFalse
        $result.BuildExitCode | Should -BeNullOrEmpty
        $result.ResponseSummary | Should -Match 'did not restore from requested feed'
        Assert-MockCalled dotnet -Times 0 -Exactly -Scope It -ParameterFilter { $rest[0] -eq 'build' }
    }

    It 'pins an exact missing ATAP dependency and retries unlocked restore' {
        $script:restoreAttempt = 0
        Mock Get-Content -ParameterFilter { $LiteralPath -like '*project.nuget.cache' } {
            '{"logs":[{"code":"NU1102","libraryId":"ATAP.Utilities.Dependency","message":"Unable to find package ATAP.Utilities.Dependency with version (>= 2.3.4) - Found 1 version(s) [ Nearest version: 2.3.4 ]"}]}'
        }
        Mock dotnet -ParameterFilter { $rest[0] -eq 'restore' } {
            $script:restoreAttempt++
            $global:LASTEXITCODE = if ($script:restoreAttempt -eq 1) { 1 } else { 0 }
        }
        $result = Invoke-PromotedPackageTests -Name 'pkg' -Version '1.0.0' -Feed 'nuget-development' -ResultsPath 'consumer' -ProGetUrl 'https://utat022:50000'
        $result.GatePass | Should -BeTrue
        $script:restoreAttempt | Should -Be 2
        Assert-MockCalled Set-Content -Times 1 -Exactly -Scope It -ParameterFilter {
            $LiteralPath -like '*.csproj' -and
            [string]$Value -match 'Include="ATAP\.Utilities\.Dependency" Version="2\.3\.4"'
        }
    }
    It 'maps restore failure into GatePass false and skips compile' {
        Mock dotnet -ParameterFilter { $rest[0] -eq 'restore' } { $global:LASTEXITCODE = 1 }
        $result = Invoke-PromotedPackageTests -Name 'pkg' -Version '1.0.0' -Feed 'nuget-development' -ResultsPath 'consumer' -ProGetUrl 'https://utat022:50000'
        $result.GatePass | Should -BeFalse
        $result.RestoreExitCode | Should -Be 1
        $result.BuildExitCode | Should -BeNullOrEmpty
        Assert-MockCalled dotnet -Times 0 -Exactly -Scope It -ParameterFilter { $rest[0] -eq 'build' }
    }

    It 'maps consumer build failure without claiming a test run' {
        Mock dotnet -ParameterFilter { $rest[0] -eq 'restore' } { $global:LASTEXITCODE = 0 }
        Mock dotnet -ParameterFilter { $rest[0] -eq 'build' } { $global:LASTEXITCODE = 1 }
        $result = Invoke-PromotedPackageTests -Name 'pkg' -Version '1.0.0' -Feed 'nuget-development' -ResultsPath 'consumer' -ProGetUrl 'https://utat022:50000'
        $result.GatePass | Should -BeFalse
        $result.BuildExitCode | Should -Be 1
        $result.TestExitCode | Should -BeNullOrEmpty
        $result.TrxPath | Should -BeNullOrEmpty
        $result.FailingTestCount | Should -BeNullOrEmpty
        $result.ResponseSummary | Should -Match 'consumer compile'
    }

    It 'rejects an unapproved lifecycle feed before invoking dotnet' {
        { Invoke-PromotedPackageTests -Name 'pkg' -Version '1.0.0' -Feed 'nuget-preview' -ResultsPath 'consumer' -ProGetUrl 'https://utat022:50000' } | Should -Throw '*not an approved NuGet lifecycle tier*'
        Assert-MockCalled dotnet -Times 0 -Exactly -Scope It
    }

    It 'returns build status without claiming xUnit results' {
        $result = Invoke-PromotedPackageTests -Name 'pkg' -Version '1.0.0' -Feed 'nuget-development' -ResultsPath 'consumer' -ProGetUrl 'https://utat022:50000'
        $result.GatePass | Should -BeTrue
        $result.RestoreExitCode | Should -Be 0
        $result.BuildExitCode | Should -Be 0
        $result.TestExitCode | Should -BeNullOrEmpty
        $result.TrxPath | Should -BeNullOrEmpty
        $result.FailingTestCount | Should -BeNullOrEmpty
        $result.ProjectPath | Should -BeLike '*PromotedPackageConsumer.csproj'
    }
}
