#Requires -Version 7.0
# Pester 5+ tests for Publish-PSModuleToProGet (Stream G2).
# All external I/O, secret stores, and PSResourceGet cmdlets are mocked.

BeforeAll {
    $publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
    . (Join-Path $publicDir 'Resolve-ProGetFeedFromSettings.ps1')
    . (Join-Path $publicDir 'Publish-PSModuleToProGet.ps1')

    if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
        function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
    }

    # Provide PSResourceGet stand-ins so Mock can replace them.
    foreach ($cmd in @('Get-PSResourceRepository', 'Register-PSResourceRepository', 'Set-PSResourceRepository', 'Publish-PSResource')) {
        if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
            $scriptBody = "function global:$cmd { param([Parameter(ValueFromRemainingArguments=`$true)]`$args) }"
            Invoke-Expression $scriptBody
        }
    }

    # Fake .nupkg for path tests.
    $script:tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('PubPSModToProGetTest_' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $script:tempRoot -Force | Out-Null
    $script:fakeNupkg = Join-Path $script:tempRoot 'FakeModule.1.0.0.nupkg'
    Set-Content -LiteralPath $script:fakeNupkg -Value 'not a real nupkg' -Encoding Ascii

    $script:oldConfigRootKeys = $global:configRootKeys
    $script:oldSettings = $global:Settings
    $script:experimentalApiKeyEnvName = 'PROGET_APIKEY_POWERSHELLGET_EXPERIMENTAL'
    $script:savedExperimentalApiKeyProcess = [Environment]::GetEnvironmentVariable($script:experimentalApiKeyEnvName, 'Process')
    $script:savedExperimentalApiKeyUser = [Environment]::GetEnvironmentVariable($script:experimentalApiKeyEnvName, 'User')
    $script:savedAdminApiKeyProcess = [Environment]::GetEnvironmentVariable('PROGET_ADMIN_API_KEY', 'Process')
    $script:savedAdminApiKeyUser = [Environment]::GetEnvironmentVariable('PROGET_ADMIN_API_KEY', 'User')
    [Environment]::SetEnvironmentVariable($script:experimentalApiKeyEnvName, $null, 'Process')
    [Environment]::SetEnvironmentVariable($script:experimentalApiKeyEnvName, $null, 'User')
    [Environment]::SetEnvironmentVariable('PROGET_ADMIN_API_KEY', $null, 'Process')
    [Environment]::SetEnvironmentVariable('PROGET_ADMIN_API_KEY', $null, 'User')
    $global:configRootKeys = @{
        ProGetFeedCollectionConfigRootKey = 'ProGetFeedCollection'
    }
    $global:Settings = @{
        ProGetFeedCollection = @{
            ProGetFeedPowerShellExperimental = @{
                FeedName   = 'powershellget-experimental'
                FeedType   = 'powershellget'
                Tier       = 'experimental'
                NuGetV3Uri = 'https://proget.example.test/nuget/powershellget-experimental/v2'
                ApiKeyName = 'PROGET_APIKEY_POWERSHELLGET_EXPERIMENTAL'
            }
        }
    }
}

AfterAll {
    if ($script:tempRoot -and (Test-Path -LiteralPath $script:tempRoot)) {
        Remove-Item -LiteralPath $script:tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
    $global:configRootKeys = $script:oldConfigRootKeys
    $global:Settings = $script:oldSettings
    [Environment]::SetEnvironmentVariable($script:experimentalApiKeyEnvName, $script:savedExperimentalApiKeyProcess, 'Process')
    [Environment]::SetEnvironmentVariable($script:experimentalApiKeyEnvName, $script:savedExperimentalApiKeyUser, 'User')
    [Environment]::SetEnvironmentVariable('PROGET_ADMIN_API_KEY', $script:savedAdminApiKeyProcess, 'Process')
    [Environment]::SetEnvironmentVariable('PROGET_ADMIN_API_KEY', $script:savedAdminApiKeyUser, 'User')
}

Describe 'Publish-PSModuleToProGet' -Tag 'Unit' {

    BeforeEach {
        Mock Get-PSResourceRepository { $null }
        Mock Register-PSResourceRepository { }
        Mock Set-PSResourceRepository { }
        Mock Publish-PSResource { [PSCustomObject]@{ Status = 'OK' } }
    }

    Context 'Input validation' {
        It 'Throws when NupkgPath does not exist' {
            function global:Get-SecretATAP { [CmdletBinding()] param([string]$SecretName, [string]$SecretStoreType) return 'dummy' }
            try {
                { Publish-PSModuleToProGet -NupkgPath 'C:/does/not/exist.nupkg' } |
                    Should -Throw -ExpectedMessage '*does not exist*'
            } finally {
                Remove-Item Function:\Get-SecretATAP -ErrorAction SilentlyContinue
            }
        }

        It 'Throws when NupkgPath is not a .nupkg' {
            function global:Get-SecretATAP { [CmdletBinding()] param([string]$SecretName, [string]$SecretStoreType) return 'dummy' }
            $wrongExt = Join-Path $script:tempRoot 'NotANupkg.zip'
            Set-Content -LiteralPath $wrongExt -Value 'x' -Encoding Ascii
            try {
                { Publish-PSModuleToProGet -NupkgPath $wrongExt } |
                    Should -Throw -ExpectedMessage '*.nupkg extension*'
            } finally {
                Remove-Item Function:\Get-SecretATAP -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath $wrongExt -Force -ErrorAction SilentlyContinue
            }
        }

        It 'Throws when NupkgPath is empty' {
            { Publish-PSModuleToProGet -NupkgPath '' } | Should -Throw
        }
    }

    Context 'Experimental-only feed targeting' {
        It 'Always targets the powershellget-experimental feed (no -Tier parameter)' {
            function global:Get-SecretATAP { [CmdletBinding()] param([string]$SecretName, [string]$SecretStoreType) return 'dummy' }
            try {
                $result = Publish-PSModuleToProGet -NupkgPath $script:fakeNupkg
                $result.FeedName | Should -Be 'powershellget-experimental'
                $result.FeedUri  | Should -Be 'https://proget.example.test/nuget/powershellget-experimental/v2'
                $result.Published | Should -BeTrue
                Assert-MockCalled Publish-PSResource -Times 1 -Exactly -Scope It
            } finally {
                Remove-Item Function:\Get-SecretATAP -ErrorAction SilentlyContinue
            }
        }

        It 'Has no -Tier parameter' {
            $cmd = Get-Command Publish-PSModuleToProGet
            $cmd.Parameters.ContainsKey('Tier') | Should -BeFalse
        }
    }

    Context 'WhatIf short-circuit' {
        It 'Does not invoke Publish-PSResource when -WhatIf is supplied' {
            function global:Get-SecretATAP { [CmdletBinding()] param([string]$SecretName, [string]$SecretStoreType) return 'dummy' }
            try {
                $result = Publish-PSModuleToProGet -NupkgPath $script:fakeNupkg -WhatIf
                $result.Published       | Should -BeFalse
                $result.FeedName        | Should -Be 'powershellget-experimental'
                $result.ResponseSummary | Should -Match 'WhatIf'
                Assert-MockCalled Publish-PSResource -Times 0 -Exactly -Scope It
            } finally {
                Remove-Item Function:\Get-SecretATAP -ErrorAction SilentlyContinue
            }
        }
    }

    Context 'Output shape' {
        It 'Returns documented PSCustomObject (S8 of Pack-and-Publish doc)' {
            function global:Get-SecretATAP { [CmdletBinding()] param([string]$SecretName, [string]$SecretStoreType) return 'dummy' }
            try {
                $result = Publish-PSModuleToProGet -NupkgPath $script:fakeNupkg
                $result.PSObject.Properties.Name | Should -Contain 'NupkgPath'
                $result.PSObject.Properties.Name | Should -Contain 'FeedName'
                $result.PSObject.Properties.Name | Should -Contain 'FeedUri'
                $result.PSObject.Properties.Name | Should -Contain 'Published'
                $result.PSObject.Properties.Name | Should -Contain 'ResponseSummary'
            } finally {
                Remove-Item Function:\Get-SecretATAP -ErrorAction SilentlyContinue
            }
        }
    }

    Context 'Idempotent re-push' {
        It 'Treats "already exists" from Publish-PSResource as no-op success' {
            function global:Get-SecretATAP { [CmdletBinding()] param([string]$SecretName, [string]$SecretStoreType) return 'dummy' }
            Mock Publish-PSResource { throw 'Package version already exists in feed.' }
            try {
                $result = Publish-PSModuleToProGet -NupkgPath $script:fakeNupkg
                $result.Published       | Should -BeTrue
                $result.ResponseSummary | Should -Match 'already present'
            } finally {
                Remove-Item Function:\Get-SecretATAP -ErrorAction SilentlyContinue
            }
        }

        It 'Re-throws non-idempotent Publish-PSResource failures' {
            function global:Get-SecretATAP { [CmdletBinding()] param([string]$SecretName, [string]$SecretStoreType) return 'dummy' }
            Mock Publish-PSResource { throw 'ProGet 500 Internal Server Error' }
            try {
                { Publish-PSModuleToProGet -NupkgPath $script:fakeNupkg } |
                    Should -Throw -ExpectedMessage '*500*'
            } finally {
                Remove-Item Function:\Get-SecretATAP -ErrorAction SilentlyContinue
            }
        }
    }

    Context 'PSResourceRepository registration' {
        It 'Registers the repository when missing' {
            function global:Get-SecretATAP { [CmdletBinding()] param([string]$SecretName, [string]$SecretStoreType) return 'dummy' }
            Mock Get-PSResourceRepository { $null }
            try {
                Publish-PSModuleToProGet -NupkgPath $script:fakeNupkg | Out-Null
                Assert-MockCalled Register-PSResourceRepository -Times 1 -Exactly -Scope It
                Assert-MockCalled Set-PSResourceRepository -Times 0 -Exactly -Scope It
            } finally {
                Remove-Item Function:\Get-SecretATAP -ErrorAction SilentlyContinue
            }
        }

        It 'Updates the repository when URI differs' {
            function global:Get-SecretATAP { [CmdletBinding()] param([string]$SecretName, [string]$SecretStoreType) return 'dummy' }
            Mock Get-PSResourceRepository { [PSCustomObject]@{ Name = 'powershellget-experimental'; Uri = 'https://old.example/' } }
            try {
                Publish-PSModuleToProGet -NupkgPath $script:fakeNupkg | Out-Null
                Assert-MockCalled Set-PSResourceRepository -Times 1 -Exactly -Scope It
                Assert-MockCalled Register-PSResourceRepository -Times 0 -Exactly -Scope It
            } finally {
                Remove-Item Function:\Get-SecretATAP -ErrorAction SilentlyContinue
            }
        }
    }

    Context 'API key sourcing' {
        It 'Does not fall back to environment variables when SecretName resolution fails' {
            function global:Get-SecretATAP { [CmdletBinding()] param([string]$SecretName, [string]$SecretStoreType) throw 'secret unavailable' }
            [Environment]::SetEnvironmentVariable('PROGET_ADMIN_API_KEY', 'must-not-be-used', 'Process')
            try {
                { Publish-PSModuleToProGet -NupkgPath $script:fakeNupkg } |
                    Should -Throw -ExpectedMessage '*ProGet.BuildMaster.API.Key*'
            } finally {
                [Environment]::SetEnvironmentVariable('PROGET_ADMIN_API_KEY', $null, 'Process')
                Remove-Item Function:\Get-SecretATAP -ErrorAction SilentlyContinue
            }
        }
    }
}
