#Requires -Version 7.0
# Pester 5+ tests for Invoke-PromotedPackageTests (Stream M2).
# `dotnet` and the filesystem cmdlets are mocked; no real build/test runs.

BeforeAll {
    $publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
    . (Join-Path $publicDir 'Invoke-PromotedPackageTests.ps1')
    $script:artifactsRoot = Join-Path ([IO.Path]::GetTempPath()) ('ATAP-Task15.180l-promoted-' + [guid]::NewGuid().ToString('N'))
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

    # Suppress PSFramework noise when the module is not loaded.
    if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
        function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
    }

    # Stand-in for the native dotnet CLI so Pester's Mock can replace it
    # and so the tests do not depend on a real SDK being installed.
    function global:dotnet { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }

    # Stand-in for the sibling TRX-parsing cmdlet.
    if (-not (Get-Command Get-NumberOfFailingTestsFromTRX -ErrorAction SilentlyContinue)) {
        function global:Get-NumberOfFailingTestsFromTRX { param([string]$xmlInputFile) 0 }
    }
}

AfterAll {
    if ($null -eq $script:previousContextDefault) { $PSDefaultParameterValues.Remove('Invoke-PromotedPackageTests:ArtifactsContext') }
    else { $PSDefaultParameterValues['Invoke-PromotedPackageTests:ArtifactsContext'] = $script:previousContextDefault }
    Remove-Item function:global:dotnet -ErrorAction SilentlyContinue
}

Describe 'Invoke-PromotedPackageTests' -Tag 'Unit' {

    BeforeEach {
        # Keep the cmdlet off the real filesystem.
        Mock Write-PSFMessage { }
        Mock Push-Location { }
        Mock Pop-Location { }
        Mock New-Item { }
        Mock Test-Path { $true }
        Mock Get-Content { 'ATAP.Utilities|wt-promoted|exec-promoted' }
        Mock Get-NumberOfFailingTestsFromTRX { 0 }
        Mock Get-ChildItem {
            [PSCustomObject]@{
                FullName      = 'C:\fake\_generated\testresults\development\run.trx'
                LastWriteTime = Get-Date
            }
        }
        # Default: both dotnet invocations succeed.
        Mock dotnet { $global:LASTEXITCODE = 0 }
    }

    Context 'Parameter validation' {
        It 'Throws when Name is empty' {
            { Invoke-PromotedPackageTests -Name '' -Version '1.0.0' -Feed 'nuget-development' -ResultsPath 'r' } |
                Should -Throw
        }

        It 'Throws when Version is empty' {
            { Invoke-PromotedPackageTests -Name 'pkg' -Version '' -Feed 'nuget-development' -ResultsPath 'r' } |
                Should -Throw
        }

        It 'Throws when Feed is empty' {
            { Invoke-PromotedPackageTests -Name 'pkg' -Version '1.0.0' -Feed '' -ResultsPath 'r' } |
                Should -Throw
        }

        It 'Throws when ResultsPath is empty' {
            { Invoke-PromotedPackageTests -Name 'pkg' -Version '1.0.0' -Feed 'nuget-development' -ResultsPath '' } |
                Should -Throw
        }
    }

    Context 'WhatIf short-circuit' -Tag 'BuildTranscriptNoise' {
        It 'Does not invoke dotnet when -WhatIf is supplied' {
            $result = Invoke-PromotedPackageTests -Name 'ATAP.Utilities' -Version '0.1.0-Sprint.142' `
                -Feed 'nuget-development' -ResultsPath '_generated\testresults\development' -WhatIf

            $result.OperationName   | Should -Be 'Invoke-PromotedPackageTests'
            $result.GatePass        | Should -BeTrue
            $result.ResponseSummary | Should -Match 'WhatIf'
            $result.TestExitCode    | Should -BeNullOrEmpty
            Assert-MockCalled dotnet -Times 0 -Exactly -Scope It
        }
    }

    Context 'Happy path' {
        It 'Restores then tests the promoted package and reports GatePass' {
            $result = Invoke-PromotedPackageTests -Name 'ATAP.Utilities' -Version '0.1.0-Sprint.142' `
                -Feed 'nuget-development' -TestFilter 'Category=Integration' `
                -ResultsPath '_generated\testresults\development'

            $result.OperationName    | Should -Be 'Invoke-PromotedPackageTests'
            $result.GatePass         | Should -BeTrue
            $result.Name             | Should -Be 'ATAP.Utilities'
            $result.Version          | Should -Be '0.1.0-Sprint.142'
            $result.Feed             | Should -Be 'nuget-development'
            $result.RestoreExitCode  | Should -Be 0
            $result.TestExitCode     | Should -Be 0
            $result.FailingTestCount | Should -Be 0
            $result.TrxPath          | Should -Match 'run\.trx'
            $result.ResponseSummary  | Should -Match 'passed'

            Assert-MockCalled dotnet -Times 2 -Exactly -Scope It
        }

        It 'Passes one artifacts path to restore and the dependent no-restore test call' {
            $result = Invoke-PromotedPackageTests -Name 'ATAP.Utilities' -Version '0.1.0-Sprint.142' `
                -Feed 'nuget-development' -ResultsPath 'testresults\development'

            $result.ArtifactsPath | Should -BeExactly $script:artifactsPath
            $result.ResultsPath | Should -BeLike "$($script:artifactsPath)*"
            Assert-MockCalled dotnet -Times 2 -Exactly -Scope It -ParameterFilter {
                ($rest -contains '--artifacts-path') -and ($rest -contains $script:artifactsPath)
            }
            Assert-MockCalled dotnet -Times 1 -Exactly -Scope It -ParameterFilter {
                $rest[0] -eq 'test' -and ($rest -contains "/bl:$($script:artifactsContext.BinlogPath)")
            }
        }

        It 'Passes UsePackageReferenceForSUT and SUTVersion to the restore call' {
            Invoke-PromotedPackageTests -Name 'ATAP.Utilities' -Version '0.1.0-Sprint.142' `
                -Feed 'nuget-development' -ResultsPath '_generated\testresults\development' | Out-Null

            Assert-MockCalled dotnet -Times 1 -Exactly -Scope It -ParameterFilter {
                $rest[0] -eq 'restore' -and
                ($rest -contains '/p:UsePackageReferenceForSUT=true') -and
                ($rest -contains '/p:SUTVersion=0.1.0-Sprint.142')
            }
        }

        It 'Adds --locked-mode to the restore call when -LockedRestore is supplied' {
            $result = Invoke-PromotedPackageTests -Name 'ATAP.Utilities' -Version '0.1.0-Sprint.142' `
                -Feed 'nuget-integration' -ResultsPath '_generated\testresults\integration' -LockedRestore

            $result.LockedRestore | Should -BeTrue
            Assert-MockCalled dotnet -Times 1 -Exactly -Scope It -ParameterFilter {
                $rest[0] -eq 'restore' -and
                ($rest -contains '--locked-mode')
            }
        }

        It 'Does not add --locked-mode to the restore call by default' {
            $result = Invoke-PromotedPackageTests -Name 'ATAP.Utilities' -Version '0.1.0-Sprint.142' `
                -Feed 'nuget-development' -ResultsPath '_generated\testresults\development'

            $result.LockedRestore | Should -BeFalse
            Assert-MockCalled dotnet -Times 1 -Exactly -Scope It -ParameterFilter {
                $rest[0] -eq 'restore' -and
                -not ($rest -contains '--locked-mode')
            }
        }

        It 'Passes UsePackageReferenceForSUT, SUTVersion, trx logger and --no-restore to the test call' {
            Invoke-PromotedPackageTests -Name 'ATAP.Utilities' -Version '0.1.0-Sprint.142' `
                -Feed 'nuget-development' -ResultsPath '_generated\testresults\development' | Out-Null

            Assert-MockCalled dotnet -Times 1 -Exactly -Scope It -ParameterFilter {
                $rest[0] -eq 'test' -and
                ($rest -contains '/p:UsePackageReferenceForSUT=true') -and
                ($rest -contains '/p:SUTVersion=0.1.0-Sprint.142') -and
                ($rest -contains '--no-restore') -and
                ($rest -contains 'trx')
            }
        }

        It 'Forwards -TestFilter to the test call only' {
            Invoke-PromotedPackageTests -Name 'pkg' -Version '1.0.0' -Feed 'nuget-qa' `
                -ResultsPath 'r' -TestFilter 'Category=Unit' | Out-Null

            Assert-MockCalled dotnet -Times 1 -Exactly -Scope It -ParameterFilter {
                $rest[0] -eq 'test' -and ($rest -contains '--filter') -and ($rest -contains 'Category=Unit')
            }
        }

        It 'Adds coverage collection when -CollectCoverage is set' {
            Invoke-PromotedPackageTests -Name 'pkg' -Version '1.0.0' -Feed 'nuget-qa' `
                -ResultsPath 'r' -CollectCoverage | Out-Null

            Assert-MockCalled dotnet -Times 1 -Exactly -Scope It -ParameterFilter {
                $rest[0] -eq 'test' -and ($rest -contains '--collect') -and ($rest -contains 'XPlat Code Coverage')
            }
        }

        It 'Adds an explicit feed --source to the restore call when -ProGetUrl is supplied' {
            Invoke-PromotedPackageTests -Name 'pkg' -Version '1.0.0' -Feed 'nuget-development' `
                -ResultsPath 'r' -ProGetUrl 'https://utat022:50000/' | Out-Null

            Assert-MockCalled dotnet -Times 1 -Exactly -Scope It -ParameterFilter {
                $rest[0] -eq 'restore' -and
                ($rest -contains '--source') -and
                ($rest -contains 'https://utat022:50000/nuget/nuget-development/v3/index.json')
            }
        }

        It 'Passes NBGV_BuildingRef to restore and test when the environment variable is set' {
            $previousBuildRef = $env:NBGV_BuildingRef
            try {
                $env:NBGV_BuildingRef = 'refs/heads/main'

                Invoke-PromotedPackageTests -Name 'pkg' -Version '1.0.0' -Feed 'nuget-stable' `
                    -ResultsPath 'r' | Out-Null

                Assert-MockCalled dotnet -Times 1 -Exactly -Scope It -ParameterFilter {
                    $rest[0] -eq 'restore' -and
                    ($rest -contains '/p:NBGV_BuildingRef=refs/heads/main')
                }
                Assert-MockCalled dotnet -Times 1 -Exactly -Scope It -ParameterFilter {
                    $rest[0] -eq 'test' -and
                    ($rest -contains '/p:NBGV_BuildingRef=refs/heads/main')
                }
            } finally {
                if ($null -eq $previousBuildRef) {
                    Remove-Item Env:\NBGV_BuildingRef -ErrorAction SilentlyContinue
                } else {
                    $env:NBGV_BuildingRef = $previousBuildRef
                }
            }
        }
    }

    Context 'Test failure' {
        It 'Reports GatePass=$false when dotnet test exits non-zero' {
            Mock dotnet -ParameterFilter { $rest[0] -eq 'restore' } { $global:LASTEXITCODE = 0 }
            Mock dotnet -ParameterFilter { $rest[0] -eq 'test' }    { $global:LASTEXITCODE = 1 }

            $result = Invoke-PromotedPackageTests -Name 'pkg' -Version '1.0.0' `
                -Feed 'nuget-development' -ResultsPath 'r'

            $result.GatePass        | Should -BeFalse
            $result.RestoreExitCode | Should -Be 0
            $result.TestExitCode    | Should -Be 1
            $result.ResponseSummary | Should -Match 'FAILED'
        }
    }

    Context 'Restore failure' {
        It 'Reports GatePass=$false and skips the test call when dotnet restore fails' {
            Mock dotnet -ParameterFilter { $rest[0] -eq 'restore' } { $global:LASTEXITCODE = 1 }
            Mock dotnet -ParameterFilter { $rest[0] -eq 'test' }    { $global:LASTEXITCODE = 0 }

            $result = Invoke-PromotedPackageTests -Name 'pkg' -Version '1.0.0' `
                -Feed 'nuget-development' -ResultsPath 'r'

            $result.GatePass        | Should -BeFalse
            $result.RestoreExitCode | Should -Be 1
            $result.TestExitCode    | Should -BeNullOrEmpty
            $result.ResponseSummary | Should -Match 'Restore'

            Assert-MockCalled dotnet -Times 0 -Exactly -Scope It -ParameterFilter { $rest[0] -eq 'test' }
        }
    }

    Context 'Output shape' {
        It 'Returns an object with the documented properties' {
            $result = Invoke-PromotedPackageTests -Name 'pkg' -Version '1.0.0' `
                -Feed 'nuget-development' -ResultsPath 'r'

            $result | Should -Not -BeNullOrEmpty
            foreach ($prop in @('OperationName', 'GatePass', 'Name', 'Version', 'Feed',
                    'ProjectPath', 'TestFilter', 'ResultsPath', 'TrxPath',
                    'FailingTestCount', 'LockedRestore', 'RestoreExitCode', 'TestExitCode', 'ArtifactsPath', 'ResponseSummary')) {
                $result.PSObject.Properties.Name | Should -Contain $prop
            }
        }
    }
}
