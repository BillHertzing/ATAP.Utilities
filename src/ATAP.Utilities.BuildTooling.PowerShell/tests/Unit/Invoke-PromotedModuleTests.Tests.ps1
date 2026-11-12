#Requires -Version 7.0
# Pester 6.2+ tests for Invoke-PromotedModuleTests (Stream M3).
# Save-Module, Import-Module, Invoke-PSModulePesterTests and the
# filesystem cmdlets are mocked; no real feed restore or test run happens.

BeforeAll {
    $publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
    . (Join-Path $publicDir 'Invoke-PromotedModuleTests.ps1')
    function Get-SecretATAP { [CmdletBinding()] param($SecretName, $SecretStoreType) 'secret' }

    $script:hadGlobalProGetBaseUrl = Test-Path -Path 'Variable:\global:ProGetBaseUrl'
    $script:originalGlobalProGetBaseUrl = if ($script:hadGlobalProGetBaseUrl) { $global:ProGetBaseUrl } else { $null }

    # Suppress PSFramework noise when the module is not loaded.
    if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
        function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
    }

    # Stand-in for the PowerShellGet restore cmdlet so the tests do not depend
    # on it being installed and so Pester's Mock can replace it.
    if (-not (Get-Command Save-Module -ErrorAction SilentlyContinue)) {
        function global:Save-Module {
            param(
                [string]$Name, [string]$RequiredVersion, [string]$Repository, [string]$Path,
                [switch]$Force,
                [System.Management.Automation.ActionPreference]$ErrorAction
            )
        }
    }

    # Stand-in for the sibling Pester driver cmdlet.
    if (-not (Get-Command Invoke-PSModulePesterTests -ErrorAction SilentlyContinue)) {
        function global:Invoke-PSModulePesterTests {
            param(
                [string]$ModuleRoot, [string]$Tier, [string]$OutputPath,
                [string]$CoverageOutputPath, [string[]]$TestPaths, [string[]]$AdditionalExcludeTag,
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

    Remove-Item function:global:Save-Module -ErrorAction SilentlyContinue
    Remove-Item function:global:Invoke-PSModulePesterTests -ErrorAction SilentlyContinue
}

Describe 'Invoke-PromotedModuleTests' -Tag 'Unit' {

    BeforeEach {
        $script:priorPromotedManifest = [Environment]::GetEnvironmentVariable('ATAP_PROMOTED_MODULE_MANIFEST', 'Process')
        $script:priorPromotedVersion = [Environment]::GetEnvironmentVariable('ATAP_PROMOTED_MODULE_VERSION', 'Process')
        $script:observedPromotedPair = $null
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
        Mock Save-Module { }
        Mock Invoke-WebRequest { }
        Mock Start-Sleep { }
        Mock Expand-Archive { }
        Mock Remove-Module { }
        Mock Get-Module { @() }
        Mock Import-Module { }
        Mock Get-ChildItem {
            [PSCustomObject]@{
                FullName = 'C:\fake\_generated\_promoted-modules\Mod.1.0.0.powershellget-development\Mod\1.0.0\Mod.psd1'
            }
        }
        # Default: the delegated Pester run passes.
        Mock Invoke-PSModulePesterTests {
            $script:observedPromotedPair = @{
                Manifest = [Environment]::GetEnvironmentVariable('ATAP_PROMOTED_MODULE_MANIFEST', 'Process')
                Version = [Environment]::GetEnvironmentVariable('ATAP_PROMOTED_MODULE_VERSION', 'Process')
            }
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

    AfterEach {
        if ($null -eq $script:priorPromotedManifest) { [Environment]::SetEnvironmentVariable('ATAP_PROMOTED_MODULE_MANIFEST', [NullString]::Value, 'Process') }
        else { [Environment]::SetEnvironmentVariable('ATAP_PROMOTED_MODULE_MANIFEST', $script:priorPromotedManifest, 'Process') }
        if ($null -eq $script:priorPromotedVersion) { [Environment]::SetEnvironmentVariable('ATAP_PROMOTED_MODULE_VERSION', [NullString]::Value, 'Process') }
        else { [Environment]::SetEnvironmentVariable('ATAP_PROMOTED_MODULE_VERSION', $script:priorPromotedVersion, 'Process') }
    }

    Context 'Independent promoted test context' {
        It 'passes the caller version independently of the selected manifest and restores the prior pair' {
            [Environment]::SetEnvironmentVariable('ATAP_PROMOTED_MODULE_MANIFEST', 'prior-manifest', 'Process')
            [Environment]::SetEnvironmentVariable('ATAP_PROMOTED_MODULE_VERSION', 'prior-version', 'Process')

            $null = Invoke-PromotedModuleTests -Name Mod -Version '0.1.16-Beta.2+build.7' -Feed powershellget-development `
                -Tier Development -ResultsPath r -ModuleSourceRoot 'C:\fake\src\Mod' -WorkingDirectory 'C:\fake'

            $script:observedPromotedPair.Manifest | Should -Match 'Mod\.1\.0\.0.*Mod\.psd1'
            $script:observedPromotedPair.Version | Should -BeExactly '0.1.16-Beta.2+build.7'
            [Environment]::GetEnvironmentVariable('ATAP_PROMOTED_MODULE_MANIFEST', 'Process') | Should -BeExactly 'prior-manifest'
            [Environment]::GetEnvironmentVariable('ATAP_PROMOTED_MODULE_VERSION', 'Process') | Should -BeExactly 'prior-version'
        }

        It 'restores an absent pair after delegation' {
            [Environment]::SetEnvironmentVariable('ATAP_PROMOTED_MODULE_MANIFEST', [NullString]::Value, 'Process')
            [Environment]::SetEnvironmentVariable('ATAP_PROMOTED_MODULE_VERSION', [NullString]::Value, 'Process')
            $null = Invoke-PromotedModuleTests -Name Mod -Version '0.1.16' -Feed powershellget-development `
                -Tier Development -ResultsPath r -ModuleSourceRoot 'C:\fake\src\Mod' -WorkingDirectory 'C:\fake'
            ($null -eq [Environment]::GetEnvironmentVariable('ATAP_PROMOTED_MODULE_MANIFEST', 'Process')) | Should -BeTrue
            ($null -eq [Environment]::GetEnvironmentVariable('ATAP_PROMOTED_MODULE_VERSION', 'Process')) | Should -BeTrue
        }

        It 'restores both prior values when delegation throws' {
            [Environment]::SetEnvironmentVariable('ATAP_PROMOTED_MODULE_MANIFEST', 'prior-manifest', 'Process')
            [Environment]::SetEnvironmentVariable('ATAP_PROMOTED_MODULE_VERSION', 'prior-version', 'Process')
            Mock Invoke-PSModulePesterTests { throw 'DisposableDelegationFailure' }
            { Invoke-PromotedModuleTests -Name Mod -Version '0.1.16' -Feed powershellget-development `
                -Tier Development -ResultsPath r -ModuleSourceRoot 'C:\fake\src\Mod' -WorkingDirectory 'C:\fake' } |
                Should -Throw '*DisposableDelegationFailure*'
            [Environment]::GetEnvironmentVariable('ATAP_PROMOTED_MODULE_MANIFEST', 'Process') | Should -BeExactly 'prior-manifest'
            [Environment]::GetEnvironmentVariable('ATAP_PROMOTED_MODULE_VERSION', 'Process') | Should -BeExactly 'prior-version'
        }

        It 'restores the first set and the prior pair when the second context set fails' {
            [Environment]::SetEnvironmentVariable('ATAP_PROMOTED_MODULE_MANIFEST', 'prior-manifest', 'Process')
            [Environment]::SetEnvironmentVariable('ATAP_PROMOTED_MODULE_VERSION', 'prior-version', 'Process')
            Mock Set-Item { [Environment]::SetEnvironmentVariable($LiteralPath.Substring(4), $Value, 'Process') }
            Mock Set-Item { throw 'DisposableSecondContextSetFailure' } -ParameterFilter { $LiteralPath -ceq 'Env:ATAP_PROMOTED_MODULE_VERSION' }
            { Invoke-PromotedModuleTests -Name Mod -Version '0.1.16' -Feed powershellget-development `
                -Tier Development -ResultsPath r -ModuleSourceRoot 'C:\fake\src\Mod' -WorkingDirectory 'C:\fake' } |
                Should -Throw '*DisposableSecondContextSetFailure*'
            Should -Invoke Set-Item -Times 1 -Exactly -Scope It -ParameterFilter { $LiteralPath -ceq 'Env:ATAP_PROMOTED_MODULE_MANIFEST' }
            Should -Invoke Invoke-PSModulePesterTests -Times 0 -Exactly -Scope It
            [Environment]::GetEnvironmentVariable('ATAP_PROMOTED_MODULE_MANIFEST', 'Process') | Should -BeExactly 'prior-manifest'
            [Environment]::GetEnvironmentVariable('ATAP_PROMOTED_MODULE_VERSION', 'Process') | Should -BeExactly 'prior-version'
        }

        It 'restores the prior pair when the first context set fails' {
            [Environment]::SetEnvironmentVariable('ATAP_PROMOTED_MODULE_MANIFEST', 'prior-manifest', 'Process')
            [Environment]::SetEnvironmentVariable('ATAP_PROMOTED_MODULE_VERSION', 'prior-version', 'Process')
            Mock Set-Item { throw 'DisposableFirstContextSetFailure' }
            { Invoke-PromotedModuleTests -Name Mod -Version '0.1.16' -Feed powershellget-development `
                -Tier Development -ResultsPath r -ModuleSourceRoot 'C:\fake\src\Mod' -WorkingDirectory 'C:\fake' } |
                Should -Throw '*DisposableFirstContextSetFailure*'
            Should -Invoke Invoke-PSModulePesterTests -Times 0 -Exactly -Scope It
            [Environment]::GetEnvironmentVariable('ATAP_PROMOTED_MODULE_MANIFEST', 'Process') | Should -BeExactly 'prior-manifest'
            [Environment]::GetEnvironmentVariable('ATAP_PROMOTED_MODULE_VERSION', 'Process') | Should -BeExactly 'prior-version'
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
            Should -Invoke Save-Module -Times 0 -Exactly -Scope It
            Should -Invoke Invoke-PSModulePesterTests -Times 0 -Exactly -Scope It
        }
    }

    Context 'BuildMaster-to-Pester tier translation' {
        It 'Maps Development to Alpha' {
            Invoke-PromotedModuleTests -Name 'Mod' -Version '1.0.0' -Feed 'powershellget-development' `
                -Tier 'Development' -ResultsPath 'r' -ModuleSourceRoot 'C:\fake\src\Mod' `
                -WorkingDirectory 'C:\fake' | Out-Null
            Should -Invoke Invoke-PSModulePesterTests -Times 1 -Exactly -Scope It -ParameterFilter { $Tier -eq 'Alpha' }
        }

        It 'Maps Integration to Beta' {
            Invoke-PromotedModuleTests -Name 'Mod' -Version '1.0.0' -Feed 'powershellget-integration' `
                -Tier 'Integration' -ResultsPath 'r' -ModuleSourceRoot 'C:\fake\src\Mod' `
                -WorkingDirectory 'C:\fake' | Out-Null
            Should -Invoke Invoke-PSModulePesterTests -Times 1 -Exactly -Scope It -ParameterFilter { $Tier -eq 'Beta' }
        }

        It 'Maps Experimental to Sprint' {
            $result = Invoke-PromotedModuleTests -Name 'Mod' -Version '1.0.0' -Feed 'powershellget-experimental' `
                -Tier 'Experimental' -ResultsPath 'r' -ModuleSourceRoot 'C:\fake\src\Mod' `
                -WorkingDirectory 'C:\fake'
            $result.PesterTier | Should -Be 'Sprint'
            Should -Invoke Invoke-PSModulePesterTests -Times 1 -Exactly -Scope It -ParameterFilter { $Tier -eq 'Sprint' }
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

            Should -Invoke Save-Module -Times 1 -Exactly -Scope It -ParameterFilter {
                $Name -eq 'Mod' -and $RequiredVersion -eq '1.0.0' -and $Repository -eq 'powershellget-development'
            }
            Should -Invoke Invoke-WebRequest -Times 0 -Exactly -Scope It
            Should -Invoke Remove-Module -Times 2 -Exactly -Scope It -ParameterFilter {
                $Name -eq 'Mod' -and $Force
            }
            Should -Invoke Import-Module -Times 1 -Exactly -Scope It -ParameterFilter { $Name -match 'Mod\.psd1' }
            Should -Invoke Invoke-PSModulePesterTests -Times 1 -Exactly -Scope It -ParameterFilter {
                $ModuleRoot -eq 'C:\fake\src\Mod' -and $Tier -eq 'Alpha' -and (-not $SkipTestResult) -and $SkipCodeCoverage -and
                $PesterOutputVerbosity -eq 'Normal' -and $PesterProgressInterval -eq 20 -and
                $AdditionalExcludeTag -contains 'PromotedModuleHostSensitive'
            }
        }

        It 'removes a prior tier copy before import and cleans up after testing' {
            $script:removeCount = 0
            Mock Remove-Module { $script:removeCount++ }
            Mock Import-Module {
                $script:removeCount | Should -Be 1
            }

            Invoke-PromotedModuleTests -Name 'Mod' -Version '1.0.0' `
                -Feed 'powershellget-development' -Tier 'Development' -ResultsPath 'r' `
                -ModuleSourceRoot 'C:\fake\src\Mod' -WorkingDirectory 'C:\fake' | Out-Null

            $script:removeCount | Should -Be 2
        }

        It 'removes a nested prior-tier ModuleInfo copy that name-based removal cannot see' {
            $nestedCopy = [System.Management.Automation.PSModuleInfo]::new(
                [scriptblock]::Create('$null = 1')
            )
            $script:getModuleCall = 0
            Mock Get-Module {
                $script:getModuleCall++
                if ($script:getModuleCall -eq 1) {
                    return $nestedCopy
                }
                return @()
            }

            Invoke-PromotedModuleTests -Name 'Mod' -Version '1.0.0' `
                -Feed 'powershellget-integration' -Tier 'Integration' -ResultsPath 'r' `
                -ModuleSourceRoot 'C:\fake\src\Mod' -WorkingDirectory 'C:\fake' | Out-Null

            Should -Invoke Remove-Module -Times 1 -Exactly -Scope It -ParameterFilter {
                $ModuleInfo -eq $nestedCopy -and $Force
            }
            Should -Invoke Import-Module -Times 1 -Exactly -Scope It
        }

        It 'exposes sibling source modules only while importing the promoted target' {
            $before = $env:PSModulePath
            Mock Import-Module {
                @($env:PSModulePath -split [IO.Path]::PathSeparator) |
                    Should -Contain 'C:\fake\src'
            }

            Invoke-PromotedModuleTests -Name 'Mod' -Version '1.0.0' `
                -Feed 'powershellget-development' -Tier 'Development' -ResultsPath 'r' `
                -ModuleSourceRoot 'C:\fake\src\Mod' -WorkingDirectory 'C:\fake' | Out-Null

            $env:PSModulePath | Should -Be $before
        }

        It 'keeps restore work external while discovering siblings from ModuleSourceRoot' {
            $before = $env:PSModulePath
            Mock Import-Module {
                @($env:PSModulePath -split [IO.Path]::PathSeparator) |
                    Should -Contain 'C:\fake\src'
            }

            Invoke-PromotedModuleTests -Name 'Mod' -Version '1.0.0' `
                -Feed 'powershellget-development' -Tier 'Development' -ResultsPath 'C:\external\results' `
                -ModuleSourceRoot 'C:\fake\src\Mod' -WorkingDirectory 'C:\external\working' | Out-Null

            Should -Invoke Save-Module -Times 1 -Exactly -Scope It -ParameterFilter {
                $Path -eq 'C:\external\working\_generated\_promoted-modules\Mod.1.0.0.powershellget-development'
            }
            $env:PSModulePath | Should -Be $before
        }

        It 'fails before import when a same-name module remains loaded' {
            Mock Get-Module {
                [PSCustomObject]@{ Name = 'Mod'; Path = 'C:\old-tier\Mod.psd1' }
            }

            {
                Invoke-PromotedModuleTests -Name 'Mod' -Version '1.0.0' `
                    -Feed 'powershellget-integration' -Tier 'Integration' -ResultsPath 'r' `
                    -ModuleSourceRoot 'C:\fake\src\Mod' -WorkingDirectory 'C:\fake'
            } | Should -Throw '*Unable to isolate promoted module*old-tier*'

            Should -Invoke Import-Module -Times 0 -Exactly -Scope It
        }

        It 'Passes explicit Pester output settings to the delegated test runner' {
            Invoke-PromotedModuleTests -Name 'Mod' -Version '1.0.0' `
                -Feed 'powershellget-development' -Tier 'Development' -ResultsPath 'r' `
                -ModuleSourceRoot 'C:\fake\src\Mod' -WorkingDirectory 'C:\fake' `
                -PesterOutputVerbosity 'Diagnostic' `
                -PesterProgressInterval 10 | Out-Null

            Should -Invoke Invoke-PSModulePesterTests -Times 1 -Exactly -Scope It -ParameterFilter {
                $PesterOutputVerbosity -eq 'Diagnostic' -and $PesterProgressInterval -eq 10
            }
        }

        It 'isolates the delegated Pester run from caller StrictMode' {
            $script:strictModeWasDisabled = $false
            Mock Invoke-PSModulePesterTests {
                $probe = [PSCustomObject]@{}
                $null = $probe.PropertyThatDoesNotExist
                $script:strictModeWasDisabled = $true

                [PSCustomObject]@{
                    Tier         = $Tier
                    Passed       = 1
                    Failed       = 0
                    PassedCount  = 1
                    FailedCount  = 0
                    SkippedCount = 0
                    TotalCount   = 1
                    Duration     = [TimeSpan]::Zero
                    GatePass     = $true
                    OutputFile   = $OutputPath
                    CoverageFile = $CoverageOutputPath
                    Result       = $null
                }
            }

            & {
                Set-StrictMode -Version Latest
                Invoke-PromotedModuleTests -Name 'Mod' -Version '1.0.0' `
                    -Feed 'powershellget-development' -Tier 'Development' -ResultsPath 'r' `
                    -ModuleSourceRoot 'C:\fake\src\Mod' -WorkingDirectory 'C:\fake'
            } | Out-Null

            $script:strictModeWasDisabled | Should -BeTrue
        }

        It 'Restores from the direct ProGet package endpoint when ProGetBaseUrl is supplied' {
            $result = Invoke-PromotedModuleTests -Name 'Mod' -Version '1.0.0-Alpha001' `
                -Feed 'powershellget-development' -Tier 'Development' -ResultsPath 'r' `
                -ModuleSourceRoot 'C:\fake\src\Mod' -WorkingDirectory 'C:\fake' `
                -ProGetBaseUrl 'https://utat022:50000/' -ProGetApiKeySecretName 'Test.ProGet.API.Key'

            $result.GatePass | Should -BeTrue
            Should -Invoke Save-Module -Times 0 -Exactly -Scope It
            Should -Invoke Invoke-WebRequest -Times 1 -Exactly -Scope It -ParameterFilter {
                $Uri -eq 'https://utat022:50000/nuget/powershellget-development/package/Mod/1.0.0-Alpha001' -and
                $OutFile -eq 'C:\fake\_generated\_promoted-modules\Mod.1.0.0-Alpha001.powershellget-development\Mod.1.0.0-Alpha001.nupkg' -and
                $Headers['X-ApiKey'] -eq 'secret' -and
                $TimeoutSec -eq 30
            }
            Should -Invoke Expand-Archive -Times 1 -Exactly -Scope It -ParameterFilter {
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
                -ProGetBaseUrl 'https://utat022:50000/' -ProGetApiKeySecretName 'Test.ProGet.API.Key' `
                -RestoreRetryCount 2 -RestoreRetryDelaySeconds 1

            $result.GatePass | Should -BeTrue
            $script:downloadAttempts | Should -Be 2
            Should -Invoke Invoke-WebRequest -Times 2 -Exactly -Scope It
            Should -Invoke Start-Sleep -Times 1 -Exactly -Scope It -ParameterFilter { $Seconds -eq 1 }
        }

        It 'Throws when the promoted-module restore produced no manifest' {
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

    Context 'Feed-restore cmdlet contract' {
        # Regression for the Sprint 0014 promotion of
        # ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell 0.1.29, where every
        # promoted-module test run failed even though the package was correctly
        # promoted. Save-PSResource queries the OData v2 FindPackagesById()
        # endpoint, which this ProGet edition answers with 404 (see
        # .claude/rules/ProGet.md), so the retry loop burned all 12 attempts
        # against an endpoint that can never succeed. Save-Module resolves the
        # same package/version from the same feed. Pin the choice so a future
        # "modernize to PSResourceGet" edit cannot silently reintroduce the
        # outage.
        It 'restores with Save-Module and never with Save-PSResource' {
            $sourcePath = Join-Path (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public') 'Invoke-PromotedModuleTests.ps1'
            $tokens = $null
            $parseErrors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($sourcePath, [ref]$tokens, [ref]$parseErrors)
            $parseErrors | Should -BeNullOrEmpty

            $invokedNames = @(
                $ast.FindAll({
                        param($node)
                        $node -is [System.Management.Automation.Language.CommandAst]
                    }, $true) | ForEach-Object { $_.GetCommandName() } | Where-Object { $_ }
            )

            $invokedNames | Should -Contain 'Save-Module'
            $invokedNames | Should -Not -Contain 'Save-PSResource'
        }
    }
}

Describe 'Recovery discovery version authority on disposable modules' -Tag Unit {
    BeforeAll {
        $script:fixtureModuleName = 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell'
        if (@(Get-Module -Name $script:fixtureModuleName -All).Count) { throw 'RecoveryDiscoveryNeedsFreshProcess' }
        $script:discoverySourceRoot = Join-Path ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))) 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell/tests/Integration'
        $script:discoveryFixtureBase = [Environment]::GetEnvironmentVariable('ATAP_VERSION_AUTHORITY_TEST_ROOT', 'Process')
        if (-not $script:discoveryFixtureBase) {
            $script:discoveryFixtureBase = switch ([Environment]::MachineName.ToUpperInvariant()) {
                UTAT022 { 'D:/ATAPArtifacts/_generated/Sprint0017/ResidentVersionAuthorityFix' }
                UTAT01 { 'C:/ATAPArtifacts/_generated/Sprint0017/ResidentVersionAuthorityFix' }
                default { throw 'RecoveryDiscoveryFixtureHostUnknown' }
            }
        }
        $allowedBase = switch ([Environment]::MachineName.ToUpperInvariant()) {
            UTAT022 { 'D:\ATAPArtifacts\_generated\Sprint0017\ResidentVersionAuthorityFix' }
            UTAT01 { 'C:\ATAPArtifacts\_generated\Sprint0017\ResidentVersionAuthorityFix' }
            default { throw 'RecoveryDiscoveryFixtureHostUnknown' }
        }
        $script:discoveryFixtureBase = [IO.Path]::GetFullPath($script:discoveryFixtureBase)
        if ($script:discoveryFixtureBase -ine $allowedBase -and -not $script:discoveryFixtureBase.StartsWith($allowedBase + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'RecoveryDiscoveryFixtureOutsideAssignedRoot' }
        for ($part = $script:discoveryFixtureBase; $part; $part = [IO.Path]::GetDirectoryName($part)) {
            if ((Test-Path -LiteralPath $part) -and ((Get-Item -LiteralPath $part -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'RecoveryDiscoveryFixtureReparseRefused' }
        }
        $null = [IO.Directory]::CreateDirectory($script:discoveryFixtureBase)

        function Invoke-DisposableRecoveryDiscovery {
            param([string]$Container, [string]$ContextMode, [AllowNull()][AllowEmptyString()][string]$CallerVersion, [string]$SelectedVersion, [string]$SelectedRootModule)
            $fixture = Join-Path $script:discoveryFixtureBase ([guid]::NewGuid().ToString('N'))
            $source = Join-Path $fixture 'Source'
            $promoted = Join-Path $fixture 'Promoted'
            $null = [IO.Directory]::CreateDirectory((Join-Path $source 'tests/Integration'))
            $null = [IO.Directory]::CreateDirectory($promoted)
            foreach ($entry in @(@{ Root = $source; Version = '0.1.15'; RootModule = $script:fixtureModuleName + '.psm1' }, @{ Root = $promoted; Version = $SelectedVersion; RootModule = $SelectedRootModule })) {
                $manifestText = "@{ RootModule = '$($entry.RootModule)'; ModuleVersion = '$($entry.Version)'; GUID = '01131809-7fd2-4b6d-8a34-f584b55ad4fa'; FunctionsToExport = @() }"
                [IO.File]::WriteAllText((Join-Path $entry.Root ($script:fixtureModuleName + '.psd1')), $manifestText)
                [IO.File]::WriteAllText((Join-Path $entry.Root ($script:fixtureModuleName + '.psm1')), '# Disposable empty module; no coordination code or state access.')
            }
            $manifestValue = if ($ContextMode -in @('Both', 'ManifestOnly')) { Join-Path $promoted ($script:fixtureModuleName + '.psd1') } else { $null }
            $versionValue = if ($ContextMode -in @('Both', 'VersionOnly')) { $CallerVersion } else { $null }
            if ($null -eq $manifestValue) { [Environment]::SetEnvironmentVariable('ATAP_PROMOTED_MODULE_MANIFEST', [NullString]::Value, 'Process') }
            else { [Environment]::SetEnvironmentVariable('ATAP_PROMOTED_MODULE_MANIFEST', $manifestValue, 'Process') }
            if ($null -eq $versionValue) { [Environment]::SetEnvironmentVariable('ATAP_PROMOTED_MODULE_VERSION', [NullString]::Value, 'Process') }
            else { [Environment]::SetEnvironmentVariable('ATAP_PROMOTED_MODULE_VERSION', $versionValue, 'Process') }
            $parseTokens = $null; $parseErrors = $null
            $ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $script:discoverySourceRoot $Container), [ref]$parseTokens, [ref]$parseErrors)
            if ($parseErrors.Count) { throw 'RecoveryDiscoverySourceParseFailed' }
            $commands = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.CommandAst] -and $node.GetCommandName() -ceq 'BeforeDiscovery' }, $true))
            if ($commands.Count -ne 1) { throw 'RecoveryDiscoveryBlockNotUnique' }
            $body = $commands[0].CommandElements[1].ScriptBlock.Extent.Text
            $discoveryPath = Join-Path $source ('tests/Integration/' + $Container)
            [IO.File]::WriteAllText($discoveryPath, $body.Substring(1, $body.Length - 2))
            # Execute the actual source discovery block, against only the empty
            # disposable modules. Never execute Describe/BeforeAll/recovery tests.
            . $discoveryPath
            [pscustomobject]@{ Version = $selected.Version.ToString(); Path = $selected.Path; Fixture = $fixture }
        }
    }

    BeforeEach {
        $script:discoveryPriorManifest = [Environment]::GetEnvironmentVariable('ATAP_PROMOTED_MODULE_MANIFEST', 'Process')
        $script:discoveryPriorVersion = [Environment]::GetEnvironmentVariable('ATAP_PROMOTED_MODULE_VERSION', 'Process')
    }

    AfterEach {
        foreach ($module in @(Get-Module -Name $script:fixtureModuleName -All)) {
            if (-not $module.ModuleBase.StartsWith($script:discoveryFixtureBase + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'RecoveryDiscoveryCleanupOutsideFixture' }
            Remove-Module -ModuleInfo $module -Force -ErrorAction Stop
        }
        if ($null -eq $script:discoveryPriorManifest) { [Environment]::SetEnvironmentVariable('ATAP_PROMOTED_MODULE_MANIFEST', [NullString]::Value, 'Process') }
        else { [Environment]::SetEnvironmentVariable('ATAP_PROMOTED_MODULE_MANIFEST', $script:discoveryPriorManifest, 'Process') }
        if ($null -eq $script:discoveryPriorVersion) { [Environment]::SetEnvironmentVariable('ATAP_PROMOTED_MODULE_VERSION', [NullString]::Value, 'Process') }
        else { [Environment]::SetEnvironmentVariable('ATAP_PROMOTED_MODULE_VERSION', $script:discoveryPriorVersion, 'Process') }
    }

    It '<Container> <Scenario>' -TestCases @(
        foreach ($container in @('CoordCustodyHandoff.Tests.ps1', 'CoordRestore.Tests.ps1')) {
            foreach ($case in @(
                @{ Scenario = 'accepts independent016 despite source015'; Mode = 'Both'; Caller = '0.1.16'; Selected = '0.1.16'; Error = $null; Expected = '0.1.16' },
                @{ Scenario = 'maps prerelease and build metadata to module version'; Mode = 'Both'; Caller = '0.1.16-Beta.2+build.7'; Selected = '0.1.16'; Error = $null; Expected = '0.1.16' },
                @{ Scenario = 'rejects wrong selected version'; Mode = 'Both'; Caller = '0.1.16'; Selected = '0.1.15'; Error = '*RecoverySelectedModuleVersionMismatch*'; Expected = $null },
                @{ Scenario = 'rejects missing expected version'; Mode = 'ManifestOnly'; Caller = $null; Selected = '0.1.16'; Error = '*RecoveryPromotedContextIncomplete*'; Expected = $null },
                @{ Scenario = 'rejects version without manifest'; Mode = 'VersionOnly'; Caller = '0.1.16'; Selected = '0.1.16'; Error = '*RecoveryPromotedContextIncomplete*'; Expected = $null },
                @{ Scenario = 'rejects empty version'; Mode = 'Both'; Caller = ''; Selected = '0.1.16'; Error = '*RecoveryPromotedContext*'; Expected = $null },
                @{ Scenario = 'rejects whitespace version'; Mode = 'Both'; Caller = ' '; Selected = '0.1.16'; Error = '*RecoveryPromotedContextEmpty*'; Expected = $null },
                @{ Scenario = 'rejects invalid version'; Mode = 'Both'; Caller = 'invalid'; Selected = '0.1.16'; Error = '*RecoveryPromotedVersionInvalid*'; Expected = $null },
                @{ Scenario = 'selects source015 only when both values absent'; Mode = 'SourceOnly'; Caller = $null; Selected = '0.1.16'; Error = $null; Expected = '0.1.15' }
            )) {
                @{ Container = $container; Scenario = $case.Scenario; ContextMode = $case.Mode; CallerVersion = $case.Caller; SelectedVersion = $case.Selected; ExpectedError = $case.Error; ExpectedVersion = $case.Expected }
            }
        }
    ) {
        param($Container, $Scenario, $ContextMode, $CallerVersion, $SelectedVersion, $ExpectedError, $ExpectedVersion)
        $arguments = @{ Container = $Container; ContextMode = $ContextMode; CallerVersion = $CallerVersion; SelectedVersion = $SelectedVersion; SelectedRootModule = $script:fixtureModuleName + '.psm1' }
        if ($ExpectedError) { { Invoke-DisposableRecoveryDiscovery @arguments } | Should -Throw $ExpectedError }
        else { (Invoke-DisposableRecoveryDiscovery @arguments).Version | Should -BeExactly $ExpectedVersion }
    }
}
