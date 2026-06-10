#Requires -Version 7.0
# Pester 5+ tests for Invoke-PromotedModuleTests (Stream M3).
# Save-PSResource, Import-Module, Invoke-PSModulePesterTests and the
# filesystem cmdlets are mocked; no real feed restore or test run happens.

BeforeAll {
    $publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
    . (Join-Path $publicDir 'Invoke-PromotedModuleTests.ps1')

    $script:hadGlobalProGetBaseUrl = Test-Path -Path 'Variable:\global:ProGetBaseUrl'
    $script:originalGlobalProGetBaseUrl = if ($script:hadGlobalProGetBaseUrl) { $global:ProGetBaseUrl } else { $null }

    # Suppress PSFramework noise when the module is not loaded.
    if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
        function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
    }

    # Stand-in for the PSResourceGet cmdlet so the tests do not depend on
    # it being installed and so Pester's Mock can replace it.
    if (-not (Get-Command Save-PSResource -ErrorAction SilentlyContinue)) {
        function global:Save-PSResource {
            param(
                [string]$Name, [string]$Version, [string]$Repository, [string]$Path,
                [switch]$TrustRepository,
                [System.Management.Automation.ActionPreference]$ErrorAction
            )
        }
    }

    # Stand-in for the sibling Pester driver cmdlet.
    if (-not (Get-Command Invoke-PSModulePesterTests -ErrorAction SilentlyContinue)) {
        function global:Invoke-PSModulePesterTests {
            param(
                [string]$ModuleRoot, [string]$Tier, [string]$OutputPath,
                [string]$CoverageOutputPath, [string[]]$TestPaths,
                [switch]$SkipTestResult,
                [switch]$SkipCodeCoverage,
                [string]$PesterOutputVerbosity,
                [int]$PesterProgressInterval,
                [System.Management.Automation.ActionPreference]$ErrorAction
            )
        }
    }
}

AfterAll {
    if ($script:hadGlobalProGetBaseUrl) {
        $global:ProGetBaseUrl = $script:originalGlobalProGetBaseUrl
    } else {
        Remove-Variable -Name ProGetBaseUrl -Scope Global -ErrorAction SilentlyContinue
    }

    Remove-Item function:global:Save-PSResource -ErrorAction SilentlyContinue
    Remove-Item function:global:Invoke-PSModulePesterTests -ErrorAction SilentlyContinue
}

Describe 'Invoke-PromotedModuleTests' -Tag 'Unit' {

    BeforeEach {
        # BuildMaster sets this global before invoking the promoted-module gate.
        # Keep unit tests deterministic and opt into the direct ProGet path only
        # in the test that explicitly supplies -ProGetBaseUrl.
        $global:ProGetBaseUrl = ''

        # Keep the cmdlet off the real filesystem / feed.
        Mock Write-PSFMessage { }
        Mock Push-Location { }
        Mock Pop-Location { }
        Mock New-Item { }
        Mock Test-Path { $true }
        Mock Remove-Item { }
        Mock Save-PSResource { }
        Mock Invoke-WebRequest { }
        Mock Start-Sleep { }
        Mock Expand-Archive { }
        Mock Import-Module { }
        Mock Get-ChildItem {
            [PSCustomObject]@{
                FullName = 'C:\fake\_generated\_promoted-modules\Mod.1.0.0.powershellget-development\Mod\1.0.0\Mod.psd1'
            }
        }
        # Default: the delegated Pester run passes.
        Mock Invoke-PSModulePesterTests {
            [PSCustomObject]@{
                Tier         = $Tier
                Passed       = 12
                Failed       = 0
                PassedCount  = 12
                FailedCount  = 0
                SkippedCount = 1
                TotalCount   = 13
                Duration     = [TimeSpan]::Zero
                GatePass     = $true
                OutputFile   = $OutputPath
                CoverageFile = $CoverageOutputPath
                Result       = $null
            }
        }
    }

    Context 'Parameter validation' {
        It 'Throws when Name is empty' {
            { Invoke-PromotedModuleTests -Name '' -Version '1.0.0' -Feed 'powershellget-development' `
                -Tier 'Development' -ResultsPath 'r' } | Should -Throw
        }

        It 'Throws when Version is empty' {
            { Invoke-PromotedModuleTests -Name 'Mod' -Version '' -Feed 'powershellget-development' `
                -Tier 'Development' -ResultsPath 'r' } | Should -Throw
        }

        It 'Throws when Feed is empty' {
            { Invoke-PromotedModuleTests -Name 'Mod' -Version '1.0.0' -Feed '' `
                -Tier 'Development' -ResultsPath 'r' } | Should -Throw
        }

        It 'Throws when ResultsPath is empty' {
            { Invoke-PromotedModuleTests -Name 'Mod' -Version '1.0.0' -Feed 'powershellget-development' `
                -Tier 'Development' -ResultsPath '' } | Should -Throw
        }

        It 'Throws when Tier is not a known BuildMaster tier' {
            { Invoke-PromotedModuleTests -Name 'Mod' -Version '1.0.0' -Feed 'powershellget-development' `
                -Tier 'Bogus' -ResultsPath 'r' } | Should -Throw
        }
    }

    Context 'WhatIf short-circuit' -Tag 'BuildTranscriptNoise' {
        It 'Does not restore or test when -WhatIf is supplied' {
            $result = Invoke-PromotedModuleTests -Name 'Mod' -Version '1.0.0' `
                -Feed 'powershellget-development' -Tier 'Development' -ResultsPath 'r' `
                -ModuleSourceRoot 'C:\fake\src\Mod' -WorkingDirectory 'C:\fake' -WhatIf

            $result.OperationName   | Should -Be 'Invoke-PromotedModuleTests'
            $result.GatePass        | Should -BeTrue
            $result.PesterTier      | Should -Be 'Alpha'
            $result.ResponseSummary | Should -Match 'WhatIf'
            $result.InnerResult     | Should -BeNullOrEmpty
            Assert-MockCalled Save-PSResource -Times 0 -Exactly -Scope It
            Assert-MockCalled Invoke-PSModulePesterTests -Times 0 -Exactly -Scope It
        }
    }

    Context 'BuildMaster-to-Pester tier translation' {
        It 'Maps Development to Alpha' {
            Invoke-PromotedModuleTests -Name 'Mod' -Version '1.0.0' -Feed 'powershellget-development' `
                -Tier 'Development' -ResultsPath 'r' -ModuleSourceRoot 'C:\fake\src\Mod' `
                -WorkingDirectory 'C:\fake' | Out-Null
            Assert-MockCalled Invoke-PSModulePesterTests -Times 1 -Exactly -Scope It -ParameterFilter { $Tier -eq 'Alpha' }
        }

        It 'Maps Integration to Beta' {
            Invoke-PromotedModuleTests -Name 'Mod' -Version '1.0.0' -Feed 'powershellget-integration' `
                -Tier 'Integration' -ResultsPath 'r' -ModuleSourceRoot 'C:\fake\src\Mod' `
                -WorkingDirectory 'C:\fake' | Out-Null
            Assert-MockCalled Invoke-PSModulePesterTests -Times 1 -Exactly -Scope It -ParameterFilter { $Tier -eq 'Beta' }
        }

        It 'Maps Experimental to Sprint' {
            $result = Invoke-PromotedModuleTests -Name 'Mod' -Version '1.0.0' -Feed 'powershellget-experimental' `
                -Tier 'Experimental' -ResultsPath 'r' -ModuleSourceRoot 'C:\fake\src\Mod' `
                -WorkingDirectory 'C:\fake'
            $result.PesterTier | Should -Be 'Sprint'
            Assert-MockCalled Invoke-PSModulePesterTests -Times 1 -Exactly -Scope It -ParameterFilter { $Tier -eq 'Sprint' }
        }

        It 'Maps QA and Production to themselves' {
            $qa = Invoke-PromotedModuleTests -Name 'Mod' -Version '1.0.0' -Feed 'powershellget-qa' `
                -Tier 'QA' -ResultsPath 'r' -ModuleSourceRoot 'C:\fake\src\Mod' -WorkingDirectory 'C:\fake'
            $prod = Invoke-PromotedModuleTests -Name 'Mod' -Version '1.0.0' -Feed 'powershellget-stable' `
                -Tier 'Production' -ResultsPath 'r' -ModuleSourceRoot 'C:\fake\src\Mod' -WorkingDirectory 'C:\fake'
            $qa.PesterTier   | Should -Be 'QA'
            $prod.PesterTier | Should -Be 'Production'
        }
    }

    Context 'Happy path' {
        It 'Restores the promoted module, imports it, delegates to Pester, and reports GatePass' {
            $result = Invoke-PromotedModuleTests -Name 'Mod' -Version '1.0.0' `
                -Feed 'powershellget-development' -Tier 'Development' -ResultsPath 'r' `
                -ModuleSourceRoot 'C:\fake\src\Mod' -WorkingDirectory 'C:\fake'

            $result.OperationName   | Should -Be 'Invoke-PromotedModuleTests'
            $result.GatePass        | Should -BeTrue
            $result.Name            | Should -Be 'Mod'
            $result.Version         | Should -Be '1.0.0'
            $result.Feed            | Should -Be 'powershellget-development'
            $result.Tier            | Should -Be 'Development'
            $result.PesterTier      | Should -Be 'Alpha'
            $result.Passed          | Should -Be 12
            $result.Failed          | Should -Be 0
            $result.TotalCount      | Should -Be 13
            $result.SavedModulePath | Should -Match 'Mod\.psd1'
            $result.ResponseSummary | Should -Match 'passed'
            $result.ResponseSummary | Should -Match 'Development-tier promoted-module tests using Alpha Pester filter'
            $result.InnerResult     | Should -Not -BeNullOrEmpty

            Assert-MockCalled Save-PSResource -Times 1 -Exactly -Scope It -ParameterFilter {
                $Name -eq 'Mod' -and $Version -eq '1.0.0' -and $Repository -eq 'powershellget-development'
            }
            Assert-MockCalled Invoke-WebRequest -Times 0 -Exactly -Scope It
            Assert-MockCalled Import-Module -Times 1 -Exactly -Scope It -ParameterFilter { $Name -match 'Mod\.psd1' }
            Assert-MockCalled Invoke-PSModulePesterTests -Times 1 -Exactly -Scope It -ParameterFilter {
                $ModuleRoot -eq 'C:\fake\src\Mod' -and $Tier -eq 'Alpha' -and (-not $SkipTestResult) -and $SkipCodeCoverage -and
                $PesterOutputVerbosity -eq 'Normal' -and $PesterProgressInterval -eq 20
            }
        }

        It 'Passes explicit Pester output settings to the delegated test runner' {
            Invoke-PromotedModuleTests -Name 'Mod' -Version '1.0.0' `
                -Feed 'powershellget-development' -Tier 'Development' -ResultsPath 'r' `
                -ModuleSourceRoot 'C:\fake\src\Mod' -WorkingDirectory 'C:\fake' `
                -PesterOutputVerbosity 'Diagnostic' `
                -PesterProgressInterval 10 | Out-Null

            Assert-MockCalled Invoke-PSModulePesterTests -Times 1 -Exactly -Scope It -ParameterFilter {
                $PesterOutputVerbosity -eq 'Diagnostic' -and $PesterProgressInterval -eq 10
            }
        }

        It 'Restores from the direct ProGet package endpoint when ProGetBaseUrl is supplied' {
            $result = Invoke-PromotedModuleTests -Name 'Mod' -Version '1.0.0-Alpha001' `
                -Feed 'powershellget-development' -Tier 'Development' -ResultsPath 'r' `
                -ModuleSourceRoot 'C:\fake\src\Mod' -WorkingDirectory 'C:\fake' `
                -ProGetBaseUrl 'http://localhost:50000/' -ApiKey 'secret'

            $result.GatePass | Should -BeTrue
            Assert-MockCalled Save-PSResource -Times 0 -Exactly -Scope It
            Assert-MockCalled Invoke-WebRequest -Times 1 -Exactly -Scope It -ParameterFilter {
                $Uri -eq 'http://localhost:50000/nuget/powershellget-development/package/Mod/1.0.0-Alpha001' -and
                $OutFile -eq 'C:\fake\_generated\_promoted-modules\Mod.1.0.0-Alpha001.powershellget-development\Mod.1.0.0-Alpha001.nupkg' -and
                $Headers['X-ApiKey'] -eq 'secret' -and
                $TimeoutSec -eq 30
            }
            Assert-MockCalled Expand-Archive -Times 1 -Exactly -Scope It -ParameterFilter {
                $LiteralPath -eq 'C:\fake\_generated\_promoted-modules\Mod.1.0.0-Alpha001.powershellget-development\Mod.1.0.0-Alpha001.nupkg' -and
                $DestinationPath -eq 'C:\fake\_generated\_promoted-modules\Mod.1.0.0-Alpha001.powershellget-development\package'
            }
        }

        It 'Retries direct ProGet package download while the promoted package becomes available' {
            $script:downloadAttempts = 0
            Mock Invoke-WebRequest {
                $script:downloadAttempts++
                if ($script:downloadAttempts -eq 1) {
                    throw '404 Not Found'
                }
            }

            $result = Invoke-PromotedModuleTests -Name 'Mod' -Version '1.0.0-Beta006' `
                -Feed 'powershellget-integration' -Tier 'Integration' -ResultsPath 'r' `
                -ModuleSourceRoot 'C:\fake\src\Mod' -WorkingDirectory 'C:\fake' `
                -ProGetBaseUrl 'http://localhost:50000/' -ApiKey 'secret' `
                -RestoreRetryCount 2 -RestoreRetryDelaySeconds 1

            $result.GatePass | Should -BeTrue
            $script:downloadAttempts | Should -Be 2
            Assert-MockCalled Invoke-WebRequest -Times 2 -Exactly -Scope It
            Assert-MockCalled Start-Sleep -Times 1 -Exactly -Scope It -ParameterFilter { $Seconds -eq 1 }
        }

        It 'Throws when Save-PSResource produced no manifest' {
            Mock Get-ChildItem { $null }
            { Invoke-PromotedModuleTests -Name 'Mod' -Version '1.0.0' -Feed 'powershellget-development' `
                -Tier 'Development' -ResultsPath 'r' -ModuleSourceRoot 'C:\fake\src\Mod' `
                -WorkingDirectory 'C:\fake' } | Should -Throw -ExpectedMessage '*did not produce*'
        }
    }

    Context 'Missing module source root' {
        It 'Throws when the source-tree module folder does not exist' {
            Mock Test-Path -ParameterFilter { $Path -eq 'C:\fake\src\Mod' } { $false }
            { Invoke-PromotedModuleTests -Name 'Mod' -Version '1.0.0' -Feed 'powershellget-development' `
                -Tier 'Development' -ResultsPath 'r' -ModuleSourceRoot 'C:\fake\src\Mod' `
                -WorkingDirectory 'C:\fake' } | Should -Throw -ExpectedMessage '*does not exist*'
        }
    }

    Context 'Test failure' {
        It 'Reports GatePass=$false when the delegated Pester run fails' {
            Mock Invoke-PSModulePesterTests {
                [PSCustomObject]@{
                    Tier = $Tier; Passed = 10; Failed = 2; PassedCount = 10; FailedCount = 2
                    SkippedCount = 0; TotalCount = 12; Duration = [TimeSpan]::Zero
                    GatePass = $false; OutputFile = $OutputPath; CoverageFile = $CoverageOutputPath; Result = $null
                }
            }

            $result = Invoke-PromotedModuleTests -Name 'Mod' -Version '1.0.0' `
                -Feed 'powershellget-development' -Tier 'Development' -ResultsPath 'r' `
                -ModuleSourceRoot 'C:\fake\src\Mod' -WorkingDirectory 'C:\fake'

            $result.GatePass        | Should -BeFalse
            $result.Failed          | Should -Be 2
            $result.ResponseSummary | Should -Match 'FAILED'
        }
    }

    Context 'Output shape' {
        It 'Returns an object with the documented properties' {
            $result = Invoke-PromotedModuleTests -Name 'Mod' -Version '1.0.0' `
                -Feed 'powershellget-development' -Tier 'Development' -ResultsPath 'r' `
                -ModuleSourceRoot 'C:\fake\src\Mod' -WorkingDirectory 'C:\fake'

            $result | Should -Not -BeNullOrEmpty
            foreach ($prop in @('OperationName', 'GatePass', 'Name', 'Version', 'Feed', 'Tier',
                    'PesterTier', 'ResultsPath', 'SavedModulePath', 'OutputFile', 'CoverageFile',
                    'Passed', 'Failed', 'SkippedCount', 'TotalCount', 'ResponseSummary', 'InnerResult')) {
                $result.PSObject.Properties.Name | Should -Contain $prop
            }
        }
    }
}
