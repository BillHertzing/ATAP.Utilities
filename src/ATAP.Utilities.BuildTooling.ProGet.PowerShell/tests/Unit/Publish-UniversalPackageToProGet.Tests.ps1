#Requires -Version 7.0
# Pester 5+ tests for Publish-UniversalPackageToProGet (Stream G5).
# Invoke-RestMethod is mocked; no real HTTP traffic is generated.

BeforeAll {
    $publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
    . (Join-Path $publicDir 'Resolve-ProGetFeedFromSettings.ps1')
    . (Join-Path $publicDir 'Publish-UniversalPackageToProGet.ps1')

    # Capturing Write-PSFMessage so tests can assert API-key secrecy.
    $global:WritePSFMessageCalls = [System.Collections.Generic.List[hashtable]]::new()
    function global:Write-PSFMessage {
        param(
            [string]$FunctionName,
            [string]$ModuleName,
            [string]$Level,
            [string]$Message,
            [string[]]$Tag,
            [Parameter(ValueFromRemainingArguments = $true)]$rest
        )
        $global:WritePSFMessageCalls.Add(@{
            Level   = $Level
            Message = $Message
            Tag     = $Tag
        })
    }

    # Fake .upack file.
    $script:tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('PubUPackTest_' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $script:tempRoot -Force | Out-Null
    $script:fakeUpack = Join-Path $script:tempRoot 'FakeBundle.1.4.0.upack'
    Set-Content -LiteralPath $script:fakeUpack -Value 'not a real upack' -Encoding Ascii

    $script:oldConfigRootKeys = $global:configRootKeys
    $script:oldSettings = $global:Settings
    $script:savedAdminApiKey = [Environment]::GetEnvironmentVariable('PROGET_ADMIN_API_KEY', 'User')
    $script:secretApiKey = 'super-secret-universal-key-ABC123'
    [Environment]::SetEnvironmentVariable('PROGET_ADMIN_API_KEY', $script:secretApiKey, 'User')
    function Get-SecretATAP { [CmdletBinding()] param($SecretName, $SecretStoreType) $script:secretApiKey }

    # Empty settings -> the cmdlet should fall back to env var or local default.
    $global:configRootKeys = @{
      # SC-0288 / Task 13.66.b: SecretName host suffixes come from the placement map.
      ServicePlacementMapConfigRootKey = 'ServicePlacementMap'
        ProGetFeedCollectionConfigRootKey = 'ProGetFeedCollection'
    }
    $global:Settings = @{
      ServicePlacementMap = @{ ProGet = 'utat022'; BuildMaster = 'utat022' }
        ProGetFeedCollection = @{}
    }
}

AfterAll {
    if ($script:tempRoot -and (Test-Path -LiteralPath $script:tempRoot)) {
        Remove-Item -LiteralPath $script:tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
    $global:configRootKeys = $script:oldConfigRootKeys
    $global:Settings = $script:oldSettings
    [Environment]::SetEnvironmentVariable('PROGET_ADMIN_API_KEY', $script:savedAdminApiKey, 'User')
    foreach ($v in 'PROGET_RELEASEBUNDLE_EXPERIMENTAL_URI', 'PROGET_RELEASEBUNDLE_DEVELOPMENT_URI') {
        [Environment]::SetEnvironmentVariable($v, $null, 'User')
        [Environment]::SetEnvironmentVariable($v, $null, 'Process')
    }
    Remove-Variable -Name 'WritePSFMessageCalls' -Scope Global -ErrorAction SilentlyContinue
    Remove-Item Function:\Write-PSFMessage -ErrorAction SilentlyContinue
}

Describe 'Publish-UniversalPackageToProGet' -Tag 'Unit', 'PromotedModuleHostSensitive' {

    BeforeEach {
        $global:WritePSFMessageCalls.Clear()
        # Default mock: 200 OK, empty body.
        Mock Invoke-RestMethod { @{ status = 'ok' } }
    }

    Context 'Input validation' {
        It 'Throws when Path does not exist' {
            { Publish-UniversalPackageToProGet -Path 'C:/does/not/exist.upack' } |
                Should -Throw -ExpectedMessage '*does not exist*'
        }

        It 'Throws when Path is not .upack' {
            $wrong = Join-Path $script:tempRoot 'NotAnUpack.nupkg'
            Set-Content -LiteralPath $wrong -Value 'x' -Encoding Ascii
            try {
                { Publish-UniversalPackageToProGet -Path $wrong } |
                    Should -Throw -ExpectedMessage '*.upack extension*'
            } finally {
                Remove-Item -LiteralPath $wrong -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context 'Default feed and URL composition' {
        It 'Defaults Feed to releasebundle-experimental' {
            $result = Publish-UniversalPackageToProGet -Path $script:fakeUpack
            $result.FeedName | Should -Be 'releasebundle-experimental'
        }

        It 'Falls back to local default when settings lacks a Universal feed entry' {
            $result = Publish-UniversalPackageToProGet -Path $script:fakeUpack
            $result.FeedUri | Should -Match 'http://localhost:50000/upack/releasebundle-experimental/?$'
        }

        It 'Uses env var PROGET_RELEASEBUNDLE_<TIER>_URI when present' {
            [Environment]::SetEnvironmentVariable('PROGET_RELEASEBUNDLE_DEVELOPMENT_URI', 'https://proget.example.test/upack/releasebundle-development', 'Process')
            try {
                $result = Publish-UniversalPackageToProGet -Path $script:fakeUpack -Feed 'releasebundle-development' -CeilingTier 'Development'
                $result.FeedUri | Should -Match 'proget\.example\.test/upack/releasebundle-development/?$'
            } finally {
                [Environment]::SetEnvironmentVariable('PROGET_RELEASEBUNDLE_DEVELOPMENT_URI', $null, 'Process')
            }
        }

        It 'Requires CeilingTier when publishing directly above Experimental' {
            { Publish-UniversalPackageToProGet -Path $script:fakeUpack -Feed 'releasebundle-development' } |
                Should -Throw -ExpectedMessage '*CeilingTier is required*'

            Assert-MockCalled Invoke-RestMethod -Times 0 -Exactly -Scope It
        }

        It 'Blocks direct publish above the ceiling before REST call' {
            { Publish-UniversalPackageToProGet -Path $script:fakeUpack -Feed 'releasebundle-development' -CeilingTier 'Experimental' } |
                Should -Throw -ExpectedMessage '*Promotion ceiling exceeded*'

            Assert-MockCalled Invoke-RestMethod -Times 0 -Exactly -Scope It
        }

        It 'Allows an explicit Force bypass for direct publish above Experimental' {
            $result = Publish-UniversalPackageToProGet -Path $script:fakeUpack -Feed 'releasebundle-development' -Force
            $result.FeedName | Should -Be 'releasebundle-development'
            $result.Published | Should -BeTrue
        }

        It 'Calls Invoke-RestMethod with Method=Put and the resolved feed URI' {
            $script:capturedUri = $null
            $script:capturedMethod = $null
            $script:capturedHeaders = $null
            Mock Invoke-RestMethod {
                param($Uri, $Method, $InFile, $Headers, $ContentType, [Parameter(ValueFromRemainingArguments = $true)]$rest)
                $script:capturedUri = [string]$Uri
                $script:capturedMethod = [string]$Method
                $script:capturedHeaders = $Headers
                return @{ status = 'ok' }
            }
            Publish-UniversalPackageToProGet -Path $script:fakeUpack | Out-Null
            $script:capturedMethod | Should -Be 'Put'
            $script:capturedUri    | Should -Match 'releasebundle-experimental'
            $script:capturedHeaders['X-ApiKey'] | Should -Be $script:secretApiKey
        }
    }

    Context 'WhatIf' {
        It 'Does not call Invoke-RestMethod under -WhatIf' {
            $result = Publish-UniversalPackageToProGet -Path $script:fakeUpack -WhatIf
            $result.Published       | Should -BeFalse
            $result.ResponseSummary | Should -Match 'WhatIf'
            Assert-MockCalled Invoke-RestMethod -Times 0 -Exactly -Scope It
        }
    }

    Context 'Output shape' {
        It 'Returns documented PSCustomObject' {
            $result = Publish-UniversalPackageToProGet -Path $script:fakeUpack
            $result.PSObject.Properties.Name | Should -Contain 'NupkgPath'
            $result.PSObject.Properties.Name | Should -Contain 'FeedName'
            $result.PSObject.Properties.Name | Should -Contain 'FeedUri'
            $result.PSObject.Properties.Name | Should -Contain 'Published'
            $result.PSObject.Properties.Name | Should -Contain 'ResponseSummary'
            $result.Published | Should -BeTrue
        }
    }

    Context 'API key secrecy' {
        It 'Never logs the API key value in any PSFramework call' {
            Publish-UniversalPackageToProGet -Path $script:fakeUpack | Out-Null
            foreach ($call in $global:WritePSFMessageCalls) {
                ([string]$call.Message) | Should -Not -Match ([regex]::Escape($script:secretApiKey))
            }
        }

        It 'Rejects environment fallback when the named secret is unavailable' {
            Mock Get-SecretATAP { throw 'secret unavailable' }
            [Environment]::SetEnvironmentVariable('PROGET_ADMIN_API_KEY', 'must-not-be-used', 'Process')
            try {
                { Publish-UniversalPackageToProGet -Path $script:fakeUpack } |
                    Should -Throw -ExpectedMessage '*ProGet.BuildMaster.API.Key*'
            } finally {
                [Environment]::SetEnvironmentVariable('PROGET_ADMIN_API_KEY', $null, 'Process')
            }
        }
    }

    Context 'Idempotent re-upload' {
        It 'Treats 409/already-exists as no-op success' {
            Mock Invoke-RestMethod { throw 'ProGet returned 409 Conflict: package already exists.' }
            $result = Publish-UniversalPackageToProGet -Path $script:fakeUpack
            $result.Published       | Should -BeTrue
            $result.ResponseSummary | Should -Match 'already present'
        }

        It 'Re-throws non-idempotent failures' {
            Mock Invoke-RestMethod { throw 'ProGet 500 Internal Server Error' }
            { Publish-UniversalPackageToProGet -Path $script:fakeUpack } |
                Should -Throw -ExpectedMessage '*500*'
        }
    }
}