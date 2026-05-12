#Requires -Version 7.0
# Pester 5+ tests for Promote-ProGetPackage (Stream G1).
# Move-ProGetPackageInterTier is mocked; no external ProGet calls happen.

BeforeAll {
    $publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
    . (Join-Path $publicDir 'Promote-ProGetPackage.ps1')

    # Suppress PSFramework noise in tests when the module is not loaded.
    if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
        function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
    }

    # Provide a stand-in definition of the inner cmdlet so Pester's Mock can replace it.
    if (-not (Get-Command Move-ProGetPackageInterTier -ErrorAction SilentlyContinue)) {
        function global:Move-ProGetPackageInterTier {
            param(
                [string]$PackageName,
                [string]$Version,
                [string]$SourceFeed,
                [string]$DestinationFeed,
                [string]$Comments,
                [System.Management.Automation.ActionPreference]$ErrorAction
            )
        }
    }
}

Describe 'Promote-ProGetPackage' -Tag 'Unit' {

    BeforeEach {
        Mock Move-ProGetPackageInterTier {
            [PSCustomObject]@{
                PackageName     = $PackageName
                Version         = $Version
                SourceFeed      = $SourceFeed
                DestinationFeed = $DestinationFeed
                Promoted        = $true
                Response        = 'OK'
            }
        }
    }

    Context 'Parameter validation' {
        It 'Throws when Name is empty' {
            { Promote-ProGetPackage -Name '' -Version '1.0.0' -FromFeed 'nuget-experimental' -ToFeed 'nuget-development' -Reason 'r' } |
                Should -Throw
        }

        It 'Throws when Version is empty' {
            { Promote-ProGetPackage -Name 'pkg' -Version '' -FromFeed 'nuget-experimental' -ToFeed 'nuget-development' -Reason 'r' } |
                Should -Throw
        }

        It 'Throws when FromFeed is empty' {
            { Promote-ProGetPackage -Name 'pkg' -Version '1.0.0' -FromFeed '' -ToFeed 'nuget-development' -Reason 'r' } |
                Should -Throw
        }

        It 'Throws when ToFeed is empty' {
            { Promote-ProGetPackage -Name 'pkg' -Version '1.0.0' -FromFeed 'nuget-experimental' -ToFeed '' -Reason 'r' } |
                Should -Throw
        }

        It 'Throws when Reason is empty' {
            { Promote-ProGetPackage -Name 'pkg' -Version '1.0.0' -FromFeed 'nuget-experimental' -ToFeed 'nuget-development' -Reason '' } |
                Should -Throw
        }
    }

    Context 'WhatIf short-circuit' {
        It 'Does not invoke Move-ProGetPackageInterTier when -WhatIf is supplied' {
            $result = Promote-ProGetPackage -Name 'pkg' -Version '1.0.0' `
                -FromFeed 'nuget-experimental' -ToFeed 'nuget-development' `
                -Reason 'plan' -WhatIf

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
                -Reason 'sprint-0007 promotion'

            $result.OperationName   | Should -Be 'Promote-ProGetPackage'
            $result.Succeeded       | Should -BeTrue
            $result.Name            | Should -Be 'ATAP.Utilities.Foo'
            $result.Version         | Should -Be '1.2.0-experimental.42'
            $result.FromFeed        | Should -Be 'nuget-experimental'
            $result.ToFeed          | Should -Be 'nuget-development'
            $result.ResponseSummary | Should -Match 'Promoted'
            $result.InnerResult     | Should -Not -BeNullOrEmpty

            Assert-MockCalled Move-ProGetPackageInterTier -Times 1 -Exactly -Scope It -ParameterFilter {
                $PackageName -eq 'ATAP.Utilities.Foo' -and
                $Version -eq '1.2.0-experimental.42' -and
                $SourceFeed -eq 'nuget-experimental' -and
                $DestinationFeed -eq 'nuget-development' -and
                $Comments -eq 'sprint-0007 promotion'
            }
        }

        It 'Maps -Name to inner -PackageName and -Reason to inner -Comments' {
            Promote-ProGetPackage -Name 'pkg' -Version '1.0.0' `
                -FromFeed 'nuget-development' -ToFeed 'nuget-integration' -Reason 'why' | Out-Null

            Assert-MockCalled Move-ProGetPackageInterTier -Times 1 -Exactly -Scope It -ParameterFilter {
                $PackageName -eq 'pkg' -and $Comments -eq 'why'
            }
        }
    }

    Context 'Idempotent re-run' {
        It 'Surfaces "already promoted" as no-op when inner Response indicates already' {
            Mock Move-ProGetPackageInterTier {
                [PSCustomObject]@{
                    PackageName = $PackageName
                    Version     = $Version
                    SourceFeed  = $SourceFeed
                    Promoted    = $true
                    Response    = 'Package already exists in destination feed'
                }
            }

            $result = Promote-ProGetPackage -Name 'pkg' -Version '1.0.0' `
                -FromFeed 'nuget-experimental' -ToFeed 'nuget-development' -Reason 'retry'

            $result.Succeeded       | Should -BeTrue
            $result.ResponseSummary | Should -Match 'No-op'
        }

        It 'Surfaces 409/already-in-feed exception text as no-op (not failure)' {
            Mock Move-ProGetPackageInterTier {
                throw "ProGet returned 409 Conflict: package already in feed 'nuget-development'."
            }

            $result = Promote-ProGetPackage -Name 'pkg' -Version '1.0.0' `
                -FromFeed 'nuget-experimental' -ToFeed 'nuget-development' -Reason 'retry'

            $result.Succeeded       | Should -BeTrue
            $result.ResponseSummary | Should -Match 'No-op'
        }

        It 'Re-throws non-idempotent failures' {
            Mock Move-ProGetPackageInterTier { throw 'ProGet 500 Internal Server Error' }

            { Promote-ProGetPackage -Name 'pkg' -Version '1.0.0' `
                -FromFeed 'nuget-experimental' -ToFeed 'nuget-development' -Reason 'r' } |
                Should -Throw -ExpectedMessage '*500*'
        }
    }

    Context 'Output shape' {
        It 'Returns an object with OperationName, Succeeded, ResponseSummary, and echoed inputs' {
            $result = Promote-ProGetPackage -Name 'pkg' -Version '1.0.0' `
                -FromFeed 'nuget-experimental' -ToFeed 'nuget-development' -Reason 'r'

            $result | Should -Not -BeNullOrEmpty
            $result.PSObject.Properties.Name | Should -Contain 'OperationName'
            $result.PSObject.Properties.Name | Should -Contain 'Succeeded'
            $result.PSObject.Properties.Name | Should -Contain 'ResponseSummary'
            $result.PSObject.Properties.Name | Should -Contain 'Name'
            $result.PSObject.Properties.Name | Should -Contain 'Version'
            $result.PSObject.Properties.Name | Should -Contain 'FromFeed'
            $result.PSObject.Properties.Name | Should -Contain 'ToFeed'
            $result.PSObject.Properties.Name | Should -Contain 'InnerResult'
        }
    }
}
