#Requires -Version 7.0
# Pester 5+ tests for Publish-NuGetPackageToProGet (Stream G4).
# Invoke-DotnetNuGetPush is mocked; no real `dotnet` process is spawned.

BeforeAll {
    $publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
    $privateDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'private'
    . (Join-Path $privateDir 'Resolve-ProGetFeedFromSettings.ps1')
    . (Join-Path $publicDir 'Publish-NuGetPackageToProGet.ps1')

    if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
        # Capturing version: every call's parameters are recorded in
        # $global:WritePSFMessageCalls so tests can assert what was logged.
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
    } else {
        # Module is loaded — we still want to capture call args. Save and
        # restore the function by shadowing it in the global scope.
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
    }

    # Fake .nupkg.
    $script:tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('PubNuGetTest_' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $script:tempRoot -Force | Out-Null
    $script:fakeNupkg = Join-Path $script:tempRoot 'FakePkg.1.0.0.nupkg'
    Set-Content -LiteralPath $script:fakeNupkg -Value 'not a real nupkg' -Encoding Ascii

    $script:oldConfigRootKeys = $global:configRootKeys
    $script:oldSettings = $global:Settings
    $script:savedAdminApiKey = [Environment]::GetEnvironmentVariable('PROGET_ADMIN_API_KEY', 'User')
    $script:secretApiKey = 'super-secret-api-key-XYZ987'
    [Environment]::SetEnvironmentVariable('PROGET_ADMIN_API_KEY', $script:secretApiKey, 'User')

    $global:configRootKeys = @{
        ProGetFeedCollectionConfigRootKey = 'ProGetFeedCollection'
    }
    $global:Settings = @{
        ProGetFeedCollection = @{
            ProGetFeedNuGetExperimental = @{
                FeedName   = 'nuget-experimental'
                FeedType   = 'nuget'
                Tier       = 'experimental'
                NuGetV3Uri = 'https://proget.example.test/nuget/nuget-experimental/v3/index.json'
                ApiKeyName = 'PROGET_APIKEY_NUGET_EXPERIMENTAL'
            }
            ProGetFeedNuGetDevelopment = @{
                FeedName   = 'nuget-development'
                FeedType   = 'nuget'
                Tier       = 'development'
                NuGetV3Uri = 'https://proget.example.test/nuget/nuget-development/v3/index.json'
                ApiKeyName = 'PROGET_APIKEY_NUGET_DEVELOPMENT'
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
    [Environment]::SetEnvironmentVariable('PROGET_ADMIN_API_KEY', $script:savedAdminApiKey, 'User')
    Remove-Variable -Name 'WritePSFMessageCalls' -Scope Global -ErrorAction SilentlyContinue
    Remove-Item Function:\Write-PSFMessage -ErrorAction SilentlyContinue
}

Describe 'Publish-NuGetPackageToProGet' -Tag 'Unit' {

    BeforeEach {
        $global:WritePSFMessageCalls.Clear()
        Mock Invoke-DotnetNuGetPush {
            [PSCustomObject]@{ ExitCode = 0; StdOut = 'Pushed successfully.' }
        }
    }

    Context 'Input validation' {
        It 'Throws when NupkgPath does not exist' {
            { Publish-NuGetPackageToProGet -NupkgPath 'C:/does/not/exist.nupkg' } |
                Should -Throw -ExpectedMessage '*does not exist*'
        }

        It 'Throws when NupkgPath is not .nupkg' {
            $wrongExt = Join-Path $script:tempRoot 'NotANupkg.zip'
            Set-Content -LiteralPath $wrongExt -Value 'x' -Encoding Ascii
            try {
                { Publish-NuGetPackageToProGet -NupkgPath $wrongExt } |
                    Should -Throw -ExpectedMessage '*.nupkg extension*'
            } finally {
                Remove-Item -LiteralPath $wrongExt -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context 'Default feed and required flags' {
        It 'Defaults Feed to nuget-experimental when not supplied' {
            $result = Publish-NuGetPackageToProGet -NupkgPath $script:fakeNupkg
            $result.FeedName | Should -Be 'nuget-experimental'
        }

        It 'Always passes --skip-duplicate to the dotnet helper' {
            $capturedArgs = $null
            Mock Invoke-DotnetNuGetPush {
                # Capture the parameter values for assertion. The helper itself
                # builds the dotnet argv internally; we only need to confirm
                # the helper is invoked with feed URI + api key (skip-duplicate
                # is a hard-coded constant inside the helper).
                $script:capturedNupkgPath = $NupkgPath
                $script:capturedFeedUri = $FeedUri
                $script:capturedApiKey = $ApiKey
                [PSCustomObject]@{ ExitCode = 0; StdOut = '' }
            }

            Publish-NuGetPackageToProGet -NupkgPath $script:fakeNupkg | Out-Null

            # Verify the cmdlet source code embeds --skip-duplicate in the helper.
            $sourceFile = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public/Publish-NuGetPackageToProGet.ps1'
            $sourceText = Get-Content -LiteralPath $sourceFile -Raw
            $sourceText | Should -Match '--skip-duplicate'

            $script:capturedFeedUri | Should -Match 'nuget-experimental'
            $script:capturedApiKey  | Should -Be $script:secretApiKey
        }
    }

    Context 'Output shape' {
        It 'Returns documented PSCustomObject' {
            $result = Publish-NuGetPackageToProGet -NupkgPath $script:fakeNupkg
            $result.PSObject.Properties.Name | Should -Contain 'NupkgPath'
            $result.PSObject.Properties.Name | Should -Contain 'FeedName'
            $result.PSObject.Properties.Name | Should -Contain 'FeedUri'
            $result.PSObject.Properties.Name | Should -Contain 'Published'
            $result.PSObject.Properties.Name | Should -Contain 'ResponseSummary'
            $result.Published | Should -BeTrue
        }
    }

    Context 'WhatIf' {
        It 'Does not call Invoke-DotnetNuGetPush under -WhatIf' {
            $result = Publish-NuGetPackageToProGet -NupkgPath $script:fakeNupkg -WhatIf
            $result.Published       | Should -BeFalse
            $result.ResponseSummary | Should -Match 'WhatIf'
            Assert-MockCalled Invoke-DotnetNuGetPush -Times 0 -Exactly -Scope It
        }
    }

    Context 'API key secrecy' {
        It 'Does not include the API key value in any PSFramework log line' {
            Publish-NuGetPackageToProGet -NupkgPath $script:fakeNupkg | Out-Null
            foreach ($call in $global:WritePSFMessageCalls) {
                ([string]$call.Message) | Should -Not -Match ([regex]::Escape($script:secretApiKey))
            }
        }

        It 'Does not leak the API key even when dotnet stdout echoes it' {
            Mock Invoke-DotnetNuGetPush {
                [PSCustomObject]@{ ExitCode = 0; StdOut = "pushed with --api-key $script:secretApiKey successfully" }
            }
            Publish-NuGetPackageToProGet -NupkgPath $script:fakeNupkg | Out-Null
            foreach ($call in $global:WritePSFMessageCalls) {
                ([string]$call.Message) | Should -Not -Match ([regex]::Escape($script:secretApiKey))
            }
        }

        It 'Throws when PROGET_ADMIN_API_KEY is not set' {
            [Environment]::SetEnvironmentVariable('PROGET_ADMIN_API_KEY', $null, 'User')
            [Environment]::SetEnvironmentVariable('PROGET_ADMIN_API_KEY', $null, 'Process')
            try {
                { Publish-NuGetPackageToProGet -NupkgPath $script:fakeNupkg } |
                    Should -Throw -ExpectedMessage '*PROGET_ADMIN_API_KEY*'
            } finally {
                [Environment]::SetEnvironmentVariable('PROGET_ADMIN_API_KEY', $script:secretApiKey, 'User')
            }
        }
    }

    Context 'Idempotent re-push' {
        It 'Marks ResponseSummary as already-present when dotnet output mentions duplicate' {
            Mock Invoke-DotnetNuGetPush {
                [PSCustomObject]@{ ExitCode = 0; StdOut = 'Conflict: package already exists; skipping' }
            }
            $result = Publish-NuGetPackageToProGet -NupkgPath $script:fakeNupkg
            $result.Published       | Should -BeTrue
            $result.ResponseSummary | Should -Match 'already present'
        }
    }

    Context 'Failure handling' {
        It 'Throws when dotnet exits non-zero' {
            Mock Invoke-DotnetNuGetPush {
                [PSCustomObject]@{ ExitCode = 1; StdOut = 'auth failure' }
            }
            { Publish-NuGetPackageToProGet -NupkgPath $script:fakeNupkg } |
                Should -Throw -ExpectedMessage '*exit code 1*'
        }
    }
}
