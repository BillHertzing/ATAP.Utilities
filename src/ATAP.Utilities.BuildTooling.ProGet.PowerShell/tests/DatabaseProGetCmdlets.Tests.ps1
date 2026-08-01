#Requires -Version 7.0
<#
.SYNOPSIS
    Pester 5 tests for Publish-DatabaseChangePackageToProGet and
    Promote-DatabaseChangePackage.

.NOTES
    AI assisted using pesterTest.instructions.md as guidelines.
    DBA2-T02.
#>

BeforeAll {
    # Dot-source the cmdlets under test into the test session scope.
    $cmdletRoot = Join-Path $PSScriptRoot '..' 'public'

    # The process wrapper remains a parent runtime contract during this
    # extraction. Define a child-test stand-in before loading the publisher.
    function global:Invoke-DotnetDatabaseNuGetPush {
        param($NupkgPath, $FeedUri, $ApiKey)
        [PSCustomObject]@{ ExitCode = 0; StdOut = 'stubbed' }
    }

    . (Join-Path $cmdletRoot 'Publish-DatabaseChangePackageToProGet.ps1')
    . (Join-Path $cmdletRoot 'Promote-DatabaseChangePackage.ps1')

    # Stub Move-ProGetPackageInterTier so tests never call ProGet. It mirrors the
    # REAL cmdlet's return shape (a 'Promoted' flag + a 'Response' payload); the
    # earlier fixture used a fictional 'Succeeded'/'ResponseSummary' shape that
    # masked the wrapper reading the wrong properties.
    function global:Move-ProGetPackageInterTier {
        [CmdletBinding()]
        param($Name, $Version, $FromFeed, $ToFeed, $Reason, $ProGetBaseUrl, $ProGetApiKeySecretName)
        return [PSCustomObject]@{
            PackageName = $Name
            Version     = $Version
            SourceFeed  = $FromFeed
            DestinationFeed = $ToFeed
            Promoted    = $true
            Response    = "Moved $Name $Version from $FromFeed to $ToFeed"
        }
    }

    # Stub Test-PromotionWithinCeiling — pass-through by default.
    function global:Test-PromotionWithinCeiling {
        [CmdletBinding()]
        param($CurrentTier, $CeilingTier)
        # Default: no-op (pass). Tests that need a ceiling violation will
        # Mock this to throw.
    }

    function global:Resolve-ProGetFeedFromSettings {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [string]$FeedType,
            [Parameter(Mandatory)]
            [string]$Tier
        )
        $canonicalTier = switch ($Tier.ToLowerInvariant()) {
            'experimental' { 'experimental' }
            'development' { 'development' }
            'integration' { 'integration' }
            'qa' { 'qa' }
            'stable' { 'stable' }
            default { throw "Unexpected tier '$Tier'." }
        }
        return [PSCustomObject]@{
            FeedName    = "$FeedType-$canonicalTier"
            EndpointUri = "http://proget.local/nuget/$FeedType-$canonicalTier"
        }
    }

    function global:Get-SecretATAP {
        param($SecretName, $SecretStoreType)
        'test-proget-key'
    }

    # Create a temp .nupkg for publish tests.
    $script:TempNupkg = Join-Path $TestDrive 'test-package.1.0.0-experimental.1.nupkg'
    New-Item -ItemType File -Path $script:TempNupkg -Force | Out-Null
}

Describe 'Publish-DatabaseChangePackageToProGet' {

    Context 'Parameter validation' {

        It 'Throws when -Feed is not a canonical database feed name' {
            { Publish-DatabaseChangePackageToProGet -NupkgPath $script:TempNupkg -Feed 'nuget-experimental' } |
                Should -Throw -ExpectedMessage '*canonical database feed*'
        }

        It 'Throws when -NupkgPath does not exist' {
            { Publish-DatabaseChangePackageToProGet -NupkgPath 'C:\does-not-exist\no.nupkg' -Feed 'database-experimental' } |
                Should -Throw -ExpectedMessage '*does not exist*'
        }

        It 'Throws when -NupkgPath does not have a .nupkg extension' {
            $zipPath = Join-Path $TestDrive 'bad-extension.zip'
            New-Item -ItemType File -Path $zipPath -Force | Out-Null
            { Publish-DatabaseChangePackageToProGet -NupkgPath $zipPath -Feed 'database-experimental' } |
                Should -Throw -ExpectedMessage '*.nupkg extension*'
        }

        It 'Throws when publishing to non-Experimental feed without -CeilingTier or -Force' {
            { Publish-DatabaseChangePackageToProGet -NupkgPath $script:TempNupkg -Feed 'database-development' } |
                Should -Throw -ExpectedMessage '*CeilingTier is required*'
        }
    }

    Context 'WhatIf behavior' {

        It 'Returns a result with Published=$true on -WhatIf without calling dotnet' {
            Mock 'Invoke-DotnetDatabaseNuGetPush' { throw 'Should not be called on WhatIf' }

            $result = Publish-DatabaseChangePackageToProGet `
                -NupkgPath $script:TempNupkg `
                -Feed 'database-experimental' `
                -WhatIf

            $result.Published        | Should -Be $true
            $result.ResponseSummary  | Should -Match 'WhatIf'
        }
    }

    Context 'Successful Experimental publish' {

        It 'Calls Invoke-DotnetDatabaseNuGetPush and returns Published=$true when exit code is 0' {
            Mock 'Invoke-DotnetDatabaseNuGetPush' {
                return [PSCustomObject]@{ ExitCode = 0; StdOut = 'pushed' }
            }

            # Resolve-ProGetFeedFromSettings may not exist; stub it.
            Mock 'Resolve-ProGetFeedFromSettings' {
                return [PSCustomObject]@{
                    FeedName    = "$FeedType-experimental"
                    EndpointUri = "http://proget.local/nuget/$FeedType-experimental"
                }
            } -ParameterFilter { $FeedType -eq 'database' }

            $result = Publish-DatabaseChangePackageToProGet `
                -NupkgPath $script:TempNupkg `
                -Feed 'database-experimental'

            $result.Published        | Should -Be $true
            $result.FeedName         | Should -Be 'database-experimental'
        }
    }
}

Describe 'Promote-DatabaseChangePackage' {

    Context 'Feed validation' {

        It 'Throws when -FromFeed is not a canonical database feed' {
            {
                Promote-DatabaseChangePackage `
                    -PackageId 'ATAPUtilities.Database' `
                    -Version '1.0.0-experimental.1' `
                    -FromFeed 'nuget-experimental' `
                    -ToFeed 'database-development' `
                    -CeilingTier 'Development' `
                    -Reason 'test'
            } | Should -Throw -ExpectedMessage '*canonical database feed*'
        }

        It 'Throws when -ToFeed is not a canonical database feed' {
            {
                Promote-DatabaseChangePackage `
                    -PackageId 'ATAPUtilities.Database' `
                    -Version '1.0.0-experimental.1' `
                    -FromFeed 'database-experimental' `
                    -ToFeed 'nuget-development' `
                    -CeilingTier 'Development' `
                    -Reason 'test'
            } | Should -Throw -ExpectedMessage '*canonical database feed*'
        }
    }

    Context 'Direction enforcement' {

        It 'Throws when promoting in reverse direction (stable -> experimental)' {
            {
                Promote-DatabaseChangePackage `
                    -PackageId 'ATAPUtilities.Database' `
                    -Version '1.0.0-experimental.1' `
                    -FromFeed 'database-stable' `
                    -ToFeed 'database-experimental' `
                    -NoCeilingCheck `
                    -Reason 'wrong direction'
            } | Should -Throw -ExpectedMessage '*Reverse*'
        }

        It 'Throws when skipping a tier (experimental -> integration)' {
            {
                Promote-DatabaseChangePackage `
                    -PackageId 'ATAPUtilities.Database' `
                    -Version '1.0.0-experimental.1' `
                    -FromFeed 'database-experimental' `
                    -ToFeed 'database-integration' `
                    -NoCeilingCheck `
                    -Reason 'skip tier'
            } | Should -Throw -ExpectedMessage '*Skip-tier*'
        }
    }

    Context 'Ceiling enforcement' {

        It 'Throws when the destination tier exceeds the effective ceiling' {
            # Override Test-PromotionWithinCeiling to simulate a ceiling violation.
            Mock 'Test-PromotionWithinCeiling' {
                throw "Promotion to 'Integration' blocked: ceiling is 'Development'."
            }

            {
                Promote-DatabaseChangePackage `
                    -PackageId 'ATAPUtilities.Database' `
                    -Version '1.0.0-development.5' `
                    -FromFeed 'database-development' `
                    -ToFeed 'database-integration' `
                    -CeilingTier 'Development' `
                    -Reason 'ceiling violation test'
            } | Should -Throw -ExpectedMessage "*ceiling*"
        }
    }

    Context 'Successful promotion' {

        It 'Returns Succeeded=$true when Move-ProGetPackageInterTier succeeds' {
            # Restore pass-through ceiling stub (previous test may have replaced it).
            Mock 'Test-PromotionWithinCeiling' {}
            Mock 'Move-ProGetPackageInterTier' {
                return [PSCustomObject]@{
                    PackageName = $Name
                    Version     = $Version
                    Promoted    = $true
                    Response    = 'Moved'
                }
            }

            $result = Promote-DatabaseChangePackage `
                -PackageId 'ATAPUtilities.Database' `
                -Version '1.0.0-experimental.42' `
                -FromFeed 'database-experimental' `
                -ToFeed 'database-development' `
                -CeilingTier 'Development' `
                -Reason 'sprint-0007 promotion'

            $result.OperationName  | Should -Be 'Promote-DatabaseChangePackage'
            $result.Succeeded      | Should -Be $true
            $result.PackageId      | Should -Be 'ATAPUtilities.Database'
            $result.FromFeed       | Should -Be 'database-experimental'
            $result.ToFeed         | Should -Be 'database-development'
        }

        It 'Returns Succeeded=$false when Move-ProGetPackageInterTier reports Promoted=$false' {
            # Regression: the wrapper must read the REAL 'Promoted' flag. A false
            # Promoted (no exception thrown) is a genuine failure, not success.
            Mock 'Test-PromotionWithinCeiling' {}
            Mock 'Move-ProGetPackageInterTier' {
                return [PSCustomObject]@{ PackageName = $Name; Version = $Version; Promoted = $false; Response = '' }
            }

            $result = Promote-DatabaseChangePackage `
                -PackageId 'ATAPUtilities.Database' `
                -Version '1.0.0-experimental.42' `
                -FromFeed 'database-experimental' `
                -ToFeed 'database-development' `
                -CeilingTier 'Development' `
                -Reason 'regression: promoted=false'

            $result.Succeeded       | Should -Be $false
            $result.ResponseSummary | Should -Match 'Promoted=false'
        }

        It 'Treats Promoted=$true as success for an idempotent re-promote (real contract)' {
            Mock 'Test-PromotionWithinCeiling' {}
            Mock 'Move-ProGetPackageInterTier' {
                return [PSCustomObject]@{ PackageName = $Name; Version = $Version; Promoted = $true; Response = 'Move successful' }
            }

            $result = Promote-DatabaseChangePackage `
                -PackageId 'ATAPUtilities.Database' `
                -Version '0.1.0' `
                -FromFeed 'database-qa' `
                -ToFeed 'database-stable' `
                -CeilingTier 'Production' `
                -Reason 'paired tier promotion to Production'

            $result.Succeeded | Should -Be $true
        }

        It 'Returns Succeeded=$true on -WhatIf without calling Move-ProGetPackageInterTier' {
            Mock 'Move-ProGetPackageInterTier' { throw 'Should not be called on WhatIf' }

            $result = Promote-DatabaseChangePackage `
                -PackageId 'ATAPUtilities.Database' `
                -Version '1.0.0-experimental.42' `
                -FromFeed 'database-experimental' `
                -ToFeed 'database-development' `
                -CeilingTier 'Development' `
                -Reason 'whatif test' `
                -WhatIf

            $result.Succeeded       | Should -Be $true
            $result.ResponseSummary | Should -Match 'WhatIf'
            $result.InnerResult     | Should -BeNullOrEmpty
        }
    }

    Context 'NoCeilingCheck bypass' {

        It 'Promotes successfully when -NoCeilingCheck is supplied' {
            Mock 'Move-ProGetPackageInterTier' {
                return [PSCustomObject]@{ PackageName = $Name; Version = $Version; Promoted = $true; Response = 'Moved' }
            }

            $result = Promote-DatabaseChangePackage `
                -PackageId 'ATAPUtilities.Database' `
                -Version '1.0.0-experimental.1' `
                -FromFeed 'database-experimental' `
                -ToFeed 'database-development' `
                -NoCeilingCheck `
                -Reason 'manual emergency promotion'

            $result.Succeeded | Should -Be $true
        }
    }
}
