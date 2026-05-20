#Requires -Version 7.0
# Pester 5+ tests for New-PSModuleNupkg (Stream G3).
# Register-/Unregister-PSResourceRepository and Publish-PSResource are mocked.

BeforeAll {
    $publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
    . (Join-Path $publicDir 'New-PSModuleNupkg.ps1')

    if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
        function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
    }

    foreach ($cmd in @('Register-PSResourceRepository', 'Unregister-PSResourceRepository', 'Publish-PSResource')) {
        if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
            $scriptBody = "function global:$cmd { param([Parameter(ValueFromRemainingArguments=`$true)]`$args) }"
            Invoke-Expression $scriptBody
        }
    }

    # Build a fake module folder containing a .psd1 manifest.
    $script:tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('NewPSModNupkgTest_' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $script:tempRoot -Force | Out-Null

    $script:modulePath = Join-Path $script:tempRoot 'FakeModule'
    New-Item -ItemType Directory -Path $script:modulePath -Force | Out-Null
    $psd1Path = Join-Path $script:modulePath 'FakeModule.psd1'
    # Minimal valid PowerShell data file (hashtable). Content is enough — the
    # cmdlet only uses the file name to derive the module name.
    Set-Content -LiteralPath $psd1Path -Value "@{ ModuleVersion = '1.0.0' }" -Encoding UTF8

    $script:outputPath = Join-Path $script:tempRoot 'out'
}

AfterAll {
    if ($script:tempRoot -and (Test-Path -LiteralPath $script:tempRoot)) {
        Remove-Item -LiteralPath $script:tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'New-PSModuleNupkg' -Tag 'Unit' {

    BeforeEach {
        Mock Write-PSFMessage { }

        # Wipe output folder between tests.
        if (Test-Path -LiteralPath $script:outputPath) {
            Remove-Item -LiteralPath $script:outputPath -Recurse -Force -ErrorAction SilentlyContinue
        }

        # The mock Publish-PSResource creates an empty .nupkg file in the
        # staging Repository folder. The cmdlet later locates and moves it.
        Mock Register-PSResourceRepository {
            param($Name, $Uri, [switch]$Trusted)
            # Capture Uri to use in the Publish-PSResource mock.
            $script:stagingUri = [string]$Uri
            $script:stagingRepoName = [string]$Name
        }
        Mock Publish-PSResource {
            param($Path, $Repository, [string]$NupkgPath, [switch]$SkipDependenciesCheck, [Parameter(ValueFromRemainingArguments = $true)]$rest)
            # Discover the staging path that was captured during Register-PSResourceRepository.
            $stagingUri = $script:stagingUri
            if ([string]::IsNullOrWhiteSpace($stagingUri)) {
                throw 'Mock Publish-PSResource: staging URI was not captured.'
            }
            if (-not (Test-Path -LiteralPath $stagingUri -PathType Container)) {
                New-Item -ItemType Directory -Path $stagingUri -Force | Out-Null
            }
            $nupkgName = 'FakeModule.1.0.0.nupkg'
            $nupkgPath = Join-Path $stagingUri $nupkgName
            Set-Content -LiteralPath $nupkgPath -Value 'fake nupkg content' -Encoding Ascii
        }
        Mock Unregister-PSResourceRepository { }
    }

    Context 'Input validation' {
        It 'Throws when ModulePath does not exist' {
            { New-PSModuleNupkg -ModulePath 'C:/does/not/exist' -OutputPath $script:outputPath } |
                Should -Throw -ExpectedMessage '*does not exist*'
        }

        It 'Throws when ModulePath has no .psd1 manifest' {
            $emptyMod = Join-Path $script:tempRoot 'NoManifest'
            New-Item -ItemType Directory -Path $emptyMod -Force | Out-Null
            try {
                { New-PSModuleNupkg -ModulePath $emptyMod -OutputPath $script:outputPath } |
                    Should -Throw -ExpectedMessage '*.psd1 manifest*'
            } finally {
                Remove-Item -LiteralPath $emptyMod -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context 'Happy path' {
        It 'Produces a .nupkg under OutputPath and returns its FileInfo' {
            $result = New-PSModuleNupkg -ModulePath $script:modulePath -OutputPath $script:outputPath
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType ([System.IO.FileInfo])
            $result.Name | Should -Match '^FakeModule\..*\.nupkg$'
            Test-Path -LiteralPath $result.FullName -PathType Leaf | Should -BeTrue
        }

        It 'Always unregisters the temporary repository (finally cleanup)' {
            New-PSModuleNupkg -ModulePath $script:modulePath -OutputPath $script:outputPath | Out-Null
            Assert-MockCalled Unregister-PSResourceRepository -Times 1 -Exactly -Scope It
        }

        It 'Calls Publish-PSResource with -Path and skips dependency resolution for the empty staging repository' {
            New-PSModuleNupkg -ModulePath $script:modulePath -OutputPath $script:outputPath | Out-Null
            Assert-MockCalled Publish-PSResource -Times 1 -Exactly -Scope It -ParameterFilter {
                # Mock parameter binding: $Path is the bound parameter name from the mock signature.
                $Path -eq (Resolve-Path -LiteralPath $script:modulePath).ProviderPath -and
                [string]::IsNullOrWhiteSpace($NupkgPath) -and
                $SkipDependenciesCheck
            }
        }
    }

    Context 'Finally cleanup runs on inner failure' {
        It 'Unregisters the temporary repo even when Publish-PSResource throws' {
            Mock Publish-PSResource { throw 'Simulated pack failure' }
            try {
                { New-PSModuleNupkg -ModulePath $script:modulePath -OutputPath $script:outputPath } |
                    Should -Throw -ExpectedMessage '*Simulated pack failure*'
            } finally {
                Assert-MockCalled Unregister-PSResourceRepository -Times 1 -Exactly -Scope It
            }
        }
    }

    Context 'Idempotent behavior' {
        It 'Returns the existing .nupkg without re-packing when one is present (no -Force)' {
            # Seed the output folder with an existing nupkg.
            New-Item -ItemType Directory -Path $script:outputPath -Force | Out-Null
            $existing = Join-Path $script:outputPath 'FakeModule.0.9.0.nupkg'
            Set-Content -LiteralPath $existing -Value 'preexisting' -Encoding Ascii

            $result = New-PSModuleNupkg -ModulePath $script:modulePath -OutputPath $script:outputPath
            $result.FullName | Should -Be $existing
            Assert-MockCalled Publish-PSResource -Times 0 -Exactly -Scope It
        }
    }

    Context 'WhatIf' -Tag 'BuildTranscriptNoise' {
        It 'Does not invoke Publish-PSResource under -WhatIf' {
            New-PSModuleNupkg -ModulePath $script:modulePath -OutputPath $script:outputPath -WhatIf | Out-Null
            Assert-MockCalled Publish-PSResource -Times 0 -Exactly -Scope It
        }
    }
}
