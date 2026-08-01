#Requires -Version 7.0
# Pester 5+ tests for Promote-ProGetPackage (Stream G1).
# Move-ProGetPackageInterTier is mocked; no external ProGet calls happen.

BeforeAll {
    $publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
    . (Join-Path $publicDir 'Get-TierOrder.ps1')
    . (Join-Path $publicDir 'Test-PromotionWithinCeiling.ps1')
    . (Join-Path $publicDir 'Move-ProGetPackageInterTier.ps1')
    . (Join-Path $publicDir 'Promote-ProGetPackage.ps1')

    # Suppress PSFramework noise in tests when the module is not loaded.
    if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
        function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
    }

    # SC-0288 / Task 13.66.b: the cmdlet derives its SecretName host suffix from
    # the service placement map and fails closed when placement is unknown, so a
    # suite that leaves -ProGetApiKeySecretName unbound must declare placement.
    $script:oldConfigRootKeys = $global:configRootKeys
    $script:oldSettings = $global:Settings
    $global:configRootKeys = @{ ServicePlacementMapConfigRootKey = 'ServicePlacementMap' }
    $global:Settings = @{ ServicePlacementMap = @{ ProGet = 'utat022'; BuildMaster = 'utat022' } }

    # Provide a stand-in definition of the inner cmdlet so Pester's Mock can replace it.
    # Mirrors the post-C2.3 canonical parameter set, with the legacy names kept as aliases.
    if (-not (Get-Command Move-ProGetPackageInterTier -ErrorAction SilentlyContinue)) {
        function global:Move-ProGetPackageInterTier {
            param(
                [Alias('PackageName')]
                [string]$Name,
                [Alias('PackageVersion')]
                [string]$Version,
                [Alias('SourceFeed')]
                [string]$FromFeed,
                [Alias('DestinationFeed')]
                [string]$ToFeed,
                [Alias('Comments')]
                [string]$Reason,
                [string]$ProGetBaseUrl,
                [string]$ProGetApiKeySecretName,
                [System.Management.Automation.ActionPreference]$ErrorAction
            )
        }
    }
}

Describe 'Promote-ProGetPackage' -Tag 'Unit', 'PromotedModuleHostSensitive' {

    BeforeEach {
        Mock Move-ProGetPackageInterTier {
            [PSCustomObject]@{
                PackageName     = $Name
                Version         = $Version
                SourceFeed      = $FromFeed
                DestinationFeed = $ToFeed
                Promoted        = $true
                Response        = 'OK'
            }
        }
    }

    Context 'Parameter validation' {
        It 'Throws when Name is empty' {
            { Promote-ProGetPackage -Name '' -Version '1.0.0' -FromFeed 'nuget-experimental' -ToFeed 'nuget-development' -Reason 'r' -CeilingTier 'Development' } |
                Should -Throw
        }

        It 'Throws when Version is empty' {
            { Promote-ProGetPackage -Name 'pkg' -Version '' -FromFeed 'nuget-experimental' -ToFeed 'nuget-development' -Reason 'r' -CeilingTier 'Development' } |
                Should -Throw
        }

        It 'Throws when FromFeed is empty' {
            { Promote-ProGetPackage -Name 'pkg' -Version '1.0.0' -FromFeed '' -ToFeed 'nuget-development' -Reason 'r' -CeilingTier 'Development' } |
                Should -Throw
        }

        It 'Throws when ToFeed is empty' {
            { Promote-ProGetPackage -Name 'pkg' -Version '1.0.0' -FromFeed 'nuget-experimental' -ToFeed '' -Reason 'r' -CeilingTier 'Development' } |
                Should -Throw
        }

        It 'Throws when Reason is empty' {
            { Promote-ProGetPackage -Name 'pkg' -Version '1.0.0' -FromFeed 'nuget-experimental' -ToFeed 'nuget-development' -Reason '' -CeilingTier 'Development' } |
                Should -Throw
        }

        It 'Requires CeilingTier unless NoCeilingCheck is supplied' {
            { Promote-ProGetPackage -Name 'pkg' -Version '1.0.0' -FromFeed 'nuget-experimental' -ToFeed 'nuget-development' -Reason 'r' } |
                Should -Throw -ExpectedMessage '*CeilingTier*'
        }
    }

    Context 'WhatIf short-circuit' {
        It 'Does not invoke Move-ProGetPackageInterTier when -WhatIf is supplied' {
            $result = Promote-ProGetPackage -Name 'pkg' -Version '1.0.0' `
                -FromFeed 'nuget-experimental' -ToFeed 'nuget-development' `
                -Reason 'plan' -CeilingTier 'Development' -WhatIf

            $result.OperationName   | Should -Be 'Promote-ProGetPackage'
            $result.Succeeded       | Should -BeTrue
            $result.ResponseSummary | Should -Match 'WhatIf'
            $result.InnerResult     | Should -BeNullOrEmpty
            Assert-MockCalled Move-ProGetPackageInterTier -Times 0 -Exactly -Scope It
        }
    }

    Context 'Happy path' {
        It 'Promotes a package and forwards parameters to the inner cmdlet' {
            $result = Promote-ProGetPackage -Name 'ATAP.Utilities.Foo' -Version '1.2.0-experimental.42' `
                -FromFeed 'nuget-experimental' -ToFeed 'nuget-development' `
                -Reason 'sprint-0007 promotion' -CeilingTier 'Development'

            $result.OperationName   | Should -Be 'Promote-ProGetPackage'
            $result.Succeeded       | Should -BeTrue
            $result.Name            | Should -Be 'ATAP.Utilities.Foo'
            $result.Version         | Should -Be '1.2.0-experimental.42'
            $result.FromFeed        | Should -Be 'nuget-experimental'
            $result.ToFeed          | Should -Be 'nuget-development'
            $result.ResponseSummary | Should -Match 'Promoted'
            $result.InnerResult     | Should -Not -BeNullOrEmpty

            Assert-MockCalled Move-ProGetPackageInterTier -Times 1 -Exactly -Scope It -ParameterFilter {
                $Name -eq 'ATAP.Utilities.Foo' -and
                $Version -eq '1.2.0-experimental.42' -and
                $FromFeed -eq 'nuget-experimental' -and
                $ToFeed -eq 'nuget-development' -and
                $Reason -eq 'sprint-0007 promotion'
            }
        }

        It 'Forwards -Name and -Reason to the inner cmdlet under their canonical names' {
            Promote-ProGetPackage -Name 'pkg' -Version '1.0.0' `
                -FromFeed 'nuget-development' -ToFeed 'nuget-integration' -Reason 'why' -CeilingTier 'Integration' | Out-Null

            Assert-MockCalled Move-ProGetPackageInterTier -Times 1 -Exactly -Scope It -ParameterFilter {
                $Name -eq 'pkg' -and $Reason -eq 'why'
            }
        }

        It 'Forwards ProGetBaseUrl and ApiKey to the inner cmdlet for profileless BuildMaster runners' {
            Promote-ProGetPackage -Name 'pkg' -Version '1.0.0' `
                -FromFeed 'powershellget-development' -ToFeed 'powershellget-integration' `
                -Reason 'integration gate' -CeilingTier 'Integration' `
                -ProGetBaseUrl 'http://localhost:50000' -ProGetApiKeySecretName 'Test.ProGet.API.Key' | Out-Null

            Assert-MockCalled Move-ProGetPackageInterTier -Times 1 -Exactly -Scope It -ParameterFilter {
                $ProGetBaseUrl -eq 'http://localhost:50000' -and $ProGetApiKeySecretName -eq 'Test.ProGet.API.Key'
            }
        }

        It 'Allows promotion when the destination tier is within CeilingTier' {
            $result = Promote-ProGetPackage -Name 'pkg' -Version '1.0.0' `
                -FromFeed 'nuget-experimental' -ToFeed 'nuget-development' `
                -Reason 'within ceiling' -CeilingTier 'Development'

            $result.Succeeded   | Should -BeTrue
            $result.CeilingTier | Should -Be 'Development'

            Assert-MockCalled Move-ProGetPackageInterTier -Times 1 -Exactly -Scope It
        }

        It 'Aborts before the inner cmdlet when destination tier exceeds CeilingTier' {
            { Promote-ProGetPackage -Name 'pkg' -Version '1.0.0' `
                -FromFeed 'nuget-experimental' -ToFeed 'nuget-development' `
                -Reason 'blocked' -CeilingTier 'Experimental' } |
                Should -Throw -ExpectedMessage '*Promotion ceiling exceeded*'

            Assert-MockCalled Move-ProGetPackageInterTier -Times 0 -Exactly -Scope It
        }

        It 'Allows an explicit NoCeilingCheck bypass' {
            $result = Promote-ProGetPackage -Name 'pkg' -Version '1.0.0' `
                -FromFeed 'nuget-experimental' -ToFeed 'nuget-development' `
                -Reason 'manual emergency promotion' -NoCeilingCheck

            $result.Succeeded | Should -BeTrue
            Assert-MockCalled Move-ProGetPackageInterTier -Times 1 -Exactly -Scope It
        }
    }

    Context 'Idempotent re-run' {
        It 'Surfaces "already promoted" as no-op when inner Response indicates already' {
            Mock Move-ProGetPackageInterTier {
                [PSCustomObject]@{
                    PackageName = $Name
                    Version     = $Version
                    SourceFeed  = $FromFeed
                    Promoted    = $true
                    Response    = 'Package already exists in destination feed'
                }
            }

            $result = Promote-ProGetPackage -Name 'pkg' -Version '1.0.0' `
                -FromFeed 'nuget-experimental' -ToFeed 'nuget-development' -Reason 'retry' -CeilingTier 'Development'

            $result.Succeeded       | Should -BeTrue
            $result.ResponseSummary | Should -Match 'No-op'
        }

        It 'Surfaces 409/already-in-feed exception text as no-op (not failure)' {
            Mock Move-ProGetPackageInterTier {
                throw "ProGet returned 409 Conflict: package already in feed 'nuget-development'."
            }

            $result = Promote-ProGetPackage -Name 'pkg' -Version '1.0.0' `
                -FromFeed 'nuget-experimental' -ToFeed 'nuget-development' -Reason 'retry' -CeilingTier 'Development'

            $result.Succeeded       | Should -BeTrue
            $result.ResponseSummary | Should -Match 'No-op'
        }

        It 'Re-throws non-idempotent failures' {
            Mock Move-ProGetPackageInterTier { throw 'ProGet 500 Internal Server Error' }

            { Promote-ProGetPackage -Name 'pkg' -Version '1.0.0' `
                -FromFeed 'nuget-experimental' -ToFeed 'nuget-development' -Reason 'r' -CeilingTier 'Development' } |
                Should -Throw -ExpectedMessage '*500*'
        }
    }

    Context 'Output shape' {
        It 'Returns an object with OperationName, Succeeded, ResponseSummary, and echoed inputs' {
            $result = Promote-ProGetPackage -Name 'pkg' -Version '1.0.0' `
                -FromFeed 'nuget-experimental' -ToFeed 'nuget-development' -Reason 'r' -CeilingTier 'Development'

            $result | Should -Not -BeNullOrEmpty
            $result.PSObject.Properties.Name | Should -Contain 'OperationName'
            $result.PSObject.Properties.Name | Should -Contain 'Succeeded'
            $result.PSObject.Properties.Name | Should -Contain 'ResponseSummary'
            $result.PSObject.Properties.Name | Should -Contain 'Name'
            $result.PSObject.Properties.Name | Should -Contain 'Version'
            $result.PSObject.Properties.Name | Should -Contain 'FromFeed'
            $result.PSObject.Properties.Name | Should -Contain 'ToFeed'
            $result.PSObject.Properties.Name | Should -Contain 'CeilingTier'
            $result.PSObject.Properties.Name | Should -Contain 'InnerResult'
        }
    }
}

AfterAll {
    # Restore the globals stashed for the SC-0288 placement declaration above.
    $global:configRootKeys = $script:oldConfigRootKeys
    $global:Settings = $script:oldSettings
}
