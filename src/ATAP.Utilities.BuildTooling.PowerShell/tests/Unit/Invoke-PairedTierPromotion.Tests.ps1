#Requires -Version 7.0
# Pester 5+ tests for Invoke-PairedTierPromotion (Stream DB, Task 9.13).
# The promotion + validation delegates (Promote-ProGetPackage,
# Promote-DatabaseChangePackage, Invoke-PromotedModuleTests,
# Get-AgentTextFromDatabase) are stubbed and mocked; no external calls happen.

BeforeAll {
    $publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
    $aiRenderingPublicDir = Join-Path (
        Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    ) 'ATAP.Utilities.BuildTooling.AiRendering.PowerShell\public'

    # Suppress PSFramework noise when the module is not loaded.
    if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
        function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
    }

    # Stub the delegate cmdlets BEFORE dot-sourcing the SUT so its BEGIN block
    # finds them and does not dot-source the real siblings; Mock then replaces them.
    function Promote-ProGetPackage {
        param($Name, $Version, $FromFeed, $ToFeed, $Reason, $CeilingTier, [switch]$NoCeilingCheck, $ProGetApiKeySecretName)
    }
    function Promote-DatabaseChangePackage {
        param($PackageId, $Version, $FromFeed, $ToFeed, $Reason, $Application, $CeilingTier, [switch]$NoCeilingCheck, $ProGetApiKeySecretName)
    }
    function Invoke-PromotedModuleTests {
        param($Name, $Version, $Feed, $Tier, $ResultsPath, $ModuleSourceRoot, $WorkingDirectory, $ProGetBaseUrl, $ProGetApiKeySecretName)
    }
    function Get-AgentTextFromDatabase {
        param($ConnectionString, $SourceId)
    }

    . (Join-Path $aiRenderingPublicDir 'Test-PairedAgentTextSuite.ps1')
    . (Join-Path $publicDir 'Invoke-PairedTierPromotion.ps1')

    # Compute a known SHA-256 so the round-trip integrity test can return a record
    # whose stored hash matches (or deliberately mismatches) the body.
    $script:roundTripBody = 'paired-tier round-trip body'
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($script:roundTripBody)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $script:roundTripSha = ([System.BitConverter]::ToString($sha.ComputeHash($bytes)) -replace '-', '').ToLowerInvariant()
    } finally {
        $sha.Dispose()
    }
}

Describe 'Invoke-PairedTierPromotion' -Tag 'Unit', 'PromotedModuleHostSensitive' {

    BeforeEach {
        Mock Promote-ProGetPackage {
            [PSCustomObject]@{ OperationName = 'Promote-ProGetPackage'; Succeeded = $true; Name = $Name; Version = $Version; FromFeed = $FromFeed; ToFeed = $ToFeed }
        }
        Mock Promote-DatabaseChangePackage {
            [PSCustomObject]@{ OperationName = 'Promote-DatabaseChangePackage'; Succeeded = $true; PackageId = $PackageId; Version = $Version; FromFeed = $FromFeed; ToFeed = $ToFeed }
        }
        Mock Invoke-PromotedModuleTests {
            [PSCustomObject]@{ OperationName = 'Invoke-PromotedModuleTests'; GatePass = $true; Passed = 5; Failed = 0; ResponseSummary = 'module tests passed' }
        }
        Mock Get-AgentTextFromDatabase {
            @([PSCustomObject]@{ SourceId = $SourceId; Kind = 'agent'; BodyText = $script:roundTripBody; BodySha256 = $script:roundTripSha })
        }
    }

    Context 'Parameter validation' {
        It 'Throws when ModuleVersion is empty' {
            { Invoke-PairedTierPromotion -ModuleVersion '' -DatabasePackageVersion '1' -Tier 'Development' } | Should -Throw
        }
        It 'Throws when DatabasePackageVersion is empty' {
            { Invoke-PairedTierPromotion -ModuleVersion '1' -DatabasePackageVersion '' -Tier 'Development' } | Should -Throw
        }
        It 'Throws when Tier is not a promotion destination (Experimental rejected)' {
            { Invoke-PairedTierPromotion -ModuleVersion '1' -DatabasePackageVersion '1' -Tier 'Experimental' } | Should -Throw
        }
    }

    Context 'Feed resolution' {
        It 'Resolves previous->destination feeds for Development' {
            $r = Invoke-PairedTierPromotion -ModuleVersion '0.1.4' -DatabasePackageVersion '00.02.000040' -Tier 'Development'
            $r.ModuleFromFeed   | Should -Be 'powershellget-experimental'
            $r.ModuleToFeed     | Should -Be 'powershellget-development'
            $r.DatabaseFromFeed | Should -Be 'database-experimental'
            $r.DatabaseToFeed   | Should -Be 'database-development'
        }
        It 'Maps Production to the -stable feeds (from QA)' {
            $r = Invoke-PairedTierPromotion -ModuleVersion '0.1.4' -DatabasePackageVersion '1' -Tier 'Production' -SkipValidation
            $r.ModuleFromFeed   | Should -Be 'powershellget-qa'
            $r.ModuleToFeed     | Should -Be 'powershellget-stable'
            $r.DatabaseFromFeed | Should -Be 'database-qa'
            $r.DatabaseToFeed   | Should -Be 'database-stable'
        }
    }

    Context 'WhatIf short-circuit' {
        It 'Touches no promotion or validation cmdlet under -WhatIf' {
            $r = Invoke-PairedTierPromotion -ModuleVersion '0.1.4' -DatabasePackageVersion '1' -Tier 'QA' -WhatIf
            $r.Succeeded     | Should -BeTrue
            $r.PairedAdvance | Should -BeTrue
            $r.ResponseSummary | Should -Match 'WhatIf'
            Assert-MockCalled Promote-ProGetPackage -Times 0 -Exactly -Scope It
            Assert-MockCalled Promote-DatabaseChangePackage -Times 0 -Exactly -Scope It
            Assert-MockCalled Invoke-PromotedModuleTests -Times 0 -Exactly -Scope It
        }
    }

    Context 'Happy path (Development)' {
        It 'Promotes module then database and passes validation' {
            $r = Invoke-PairedTierPromotion -ModuleVersion '0.1.4' -DatabasePackageVersion '00.02.000040' -Tier 'Development'

            $r.Succeeded        | Should -BeTrue
            $r.PairedAdvance    | Should -BeTrue
            $r.ValidationPassed | Should -BeTrue
            $r.ModuleName       | Should -Be 'ATAP.Utilities.RulesManagement.PowerShell'

            Assert-MockCalled Promote-ProGetPackage -Times 1 -Exactly -Scope It -ParameterFilter {
                $Name -eq 'ATAP.Utilities.RulesManagement.PowerShell' -and $ToFeed -eq 'powershellget-development'
            }
            Assert-MockCalled Promote-DatabaseChangePackage -Times 1 -Exactly -Scope It -ParameterFilter {
                $PackageId -eq 'ATAPUtilities.Database' -and $ToFeed -eq 'database-development'
            }
            Assert-MockCalled Invoke-PromotedModuleTests -Times 1 -Exactly -Scope It
        }
    }

    Context 'Escalating per-tier validation plan' {
        It 'Development runs VersionAlignment + PromotedModuleTests only' {
            $r = Invoke-PairedTierPromotion -ModuleVersion '1' -DatabasePackageVersion '1' -Tier 'Development'
            $r.ValidationPlan | Should -Be @('VersionAlignment', 'PromotedModuleTests')
        }
        It 'Integration adds DatabaseDataPresence' {
            $r = Invoke-PairedTierPromotion -ModuleVersion '1' -DatabasePackageVersion '1' -Tier 'Integration'
            $r.ValidationPlan | Should -Contain 'DatabaseDataPresence'
            $r.ValidationPlan | Should -Not -Contain 'AgentTextRoundTrip'
        }
        It 'QA adds AgentTextRoundTrip (full four suites)' {
            $r = Invoke-PairedTierPromotion -ModuleVersion '1' -DatabasePackageVersion '1' -Tier 'QA'
            $r.ValidationPlan | Should -Be @('VersionAlignment', 'PromotedModuleTests', 'DatabaseDataPresence', 'AgentTextRoundTrip')
        }
    }

    Context 'Coupling: module never lets the database lead' {
        It 'Does not promote the database when module promotion fails' {
            Mock Promote-ProGetPackage { [PSCustomObject]@{ Succeeded = $false } }
            $r = Invoke-PairedTierPromotion -ModuleVersion '1' -DatabasePackageVersion '1' -Tier 'Development'
            $r.Succeeded     | Should -BeFalse
            $r.PairedAdvance | Should -BeFalse
            Assert-MockCalled Promote-DatabaseChangePackage -Times 0 -Exactly -Scope It
        }
        It 'Reports a PARTIAL ADVANCE when database promotion fails after module promotion' {
            Mock Promote-DatabaseChangePackage { [PSCustomObject]@{ Succeeded = $false } }
            $r = Invoke-PairedTierPromotion -ModuleVersion '1' -DatabasePackageVersion '1' -Tier 'Development'
            $r.Succeeded       | Should -BeFalse
            $r.PairedAdvance   | Should -BeFalse
            $r.ResponseSummary | Should -Match 'PARTIAL ADVANCE'
            Assert-MockCalled Promote-ProGetPackage -Times 1 -Exactly -Scope It
        }
    }

    Context 'Validation outcomes' {
        It 'Fails overall when PromotedModuleTests does not pass (but paired advance still true)' {
            Mock Invoke-PromotedModuleTests { [PSCustomObject]@{ GatePass = $false; ResponseSummary = 'module tests FAILED' } }
            $r = Invoke-PairedTierPromotion -ModuleVersion '1' -DatabasePackageVersion '1' -Tier 'Development'
            $r.PairedAdvance    | Should -BeTrue
            $r.ValidationPassed | Should -BeFalse
            $r.Succeeded        | Should -BeFalse
            ($r.Validations | Where-Object Name -eq 'PromotedModuleTests').Status | Should -Be 'Failed'
        }
        It 'Skips every suite under -SkipValidation but still succeeds' {
            $r = Invoke-PairedTierPromotion -ModuleVersion '1' -DatabasePackageVersion '1' -Tier 'QA' -SkipValidation
            $r.Succeeded | Should -BeTrue
            ($r.Validations | Where-Object Status -ne 'Skipped') | Should -BeNullOrEmpty
            Assert-MockCalled Invoke-PromotedModuleTests -Times 0 -Exactly -Scope It
        }
        It 'Skips only PromotedModuleTests under -SkipModuleTests' {
            $r = Invoke-PairedTierPromotion -ModuleVersion '1' -DatabasePackageVersion '1' -Tier 'Development' -SkipModuleTests
            ($r.Validations | Where-Object Name -eq 'PromotedModuleTests').Status | Should -Be 'Skipped'
            $r.Succeeded | Should -BeTrue
            Assert-MockCalled Invoke-PromotedModuleTests -Times 0 -Exactly -Scope It
        }
        It 'Forwards -ProGetBaseUrl and -ProGetApiKeySecretName to Invoke-PromotedModuleTests (direct-endpoint restore)' {
            $r = Invoke-PairedTierPromotion -ModuleVersion '1' -DatabasePackageVersion '1' -Tier 'Development' `
                -ProGetBaseUrl 'http://localhost:50000' -ProGetApiKeySecretName 'Test.ProGet.API.Key'
            $r.Succeeded | Should -BeTrue
            Assert-MockCalled Invoke-PromotedModuleTests -Times 1 -Exactly -Scope It -ParameterFilter {
                $ProGetBaseUrl -eq 'http://localhost:50000' -and $ProGetApiKeySecretName -eq 'Test.ProGet.API.Key'
            }
        }
        It 'Does not pass ProGet direct-endpoint args when they are not supplied' {
            $r = Invoke-PairedTierPromotion -ModuleVersion '1' -DatabasePackageVersion '1' -Tier 'Development'
            $r.Succeeded | Should -BeTrue
            Assert-MockCalled Invoke-PromotedModuleTests -Times 1 -Exactly -Scope It -ParameterFilter {
                [string]::IsNullOrEmpty($ProGetBaseUrl) -and $ProGetApiKeySecretName -eq 'ProGet.BuildMaster.API.Key'
            }
        }
    }

    Context 'Database-data suites' {
        It 'Skips DatabaseDataPresence when no connection string is supplied' {
            $r = Invoke-PairedTierPromotion -ModuleVersion '1' -DatabasePackageVersion '1' -Tier 'Integration'
            ($r.Validations | Where-Object Name -eq 'DatabaseDataPresence').Status | Should -Be 'Skipped'
            Assert-MockCalled Get-AgentTextFromDatabase -Times 0 -Exactly -Scope It
        }
        It 'Passes DatabaseDataPresence when the AgentText record is present' {
            $r = Invoke-PairedTierPromotion -ModuleVersion '1' -DatabasePackageVersion '1' -Tier 'Integration' -DatabaseConnectionString 'Server=x;Database=ATAPUtilities;'
            ($r.Validations | Where-Object Name -eq 'DatabaseDataPresence').Status | Should -Be 'Passed'
            $r.Succeeded | Should -BeTrue
        }
        It 'Fails DatabaseDataPresence when the AgentText record is absent' {
            Mock Get-AgentTextFromDatabase { @() }
            $r = Invoke-PairedTierPromotion -ModuleVersion '1' -DatabasePackageVersion '1' -Tier 'Integration' -DatabaseConnectionString 'Server=x;'
            ($r.Validations | Where-Object Name -eq 'DatabaseDataPresence').Status | Should -Be 'Failed'
            $r.Succeeded | Should -BeFalse
        }
        It 'Passes AgentTextRoundTrip when the stored SHA matches the body' {
            $r = Invoke-PairedTierPromotion -ModuleVersion '1' -DatabasePackageVersion '1' -Tier 'QA' -DatabaseConnectionString 'Server=x;'
            ($r.Validations | Where-Object Name -eq 'AgentTextRoundTrip').Status | Should -Be 'Passed'
        }
        It 'Fails AgentTextRoundTrip on a SHA mismatch' {
            Mock Get-AgentTextFromDatabase {
                @([PSCustomObject]@{ SourceId = $SourceId; Kind = 'agent'; BodyText = $script:roundTripBody; BodySha256 = 'deadbeef' })
            }
            $r = Invoke-PairedTierPromotion -ModuleVersion '1' -DatabasePackageVersion '1' -Tier 'QA' -DatabaseConnectionString 'Server=x;'
            ($r.Validations | Where-Object Name -eq 'AgentTextRoundTrip').Status | Should -Be 'Failed'
            $r.Succeeded | Should -BeFalse
        }
    }

    Context 'Output shape' {
        It 'Returns the documented properties' {
            $r = Invoke-PairedTierPromotion -ModuleVersion '1' -DatabasePackageVersion '1' -Tier 'Development'
            foreach ($p in 'OperationName','Succeeded','PairedAdvance','Tier','ModuleName','ModuleVersion','ModuleFromFeed','ModuleToFeed','DatabasePackageId','DatabasePackageVersion','DatabaseFromFeed','DatabaseToFeed','ModulePromotion','DatabasePromotion','ValidationPlan','Validations','ValidationPassed','ResponseSummary') {
                $r.PSObject.Properties.Name | Should -Contain $p
            }
            $r.OperationName | Should -Be 'Invoke-PairedTierPromotion'
        }
    }
}
