#Requires -Version 7.0
# Pester 5+ tests for New-BuildMasterRelease (Stream H, task H3).
# Mocks Invoke-RestMethod; no real network or BuildMaster contact.

BeforeAll {
  $publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
  . (Join-Path $publicDir 'New-BuildMasterRelease.ps1')

  # Suppress PSFramework noise in tests.
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
  }

  $script:oldConfigRootKeys = $global:configRootKeys
  $script:oldSettings = $global:settings
  $script:savedApiKey = [Environment]::GetEnvironmentVariable('BUILDMASTER_ADMIN_API_KEY', 'User')
  $script:savedBaseUrl = [Environment]::GetEnvironmentVariable('BUILDMASTER_BASE_URL', 'User')
}

AfterAll {
  $global:configRootKeys = $script:oldConfigRootKeys
  $global:settings = $script:oldSettings
  [Environment]::SetEnvironmentVariable('BUILDMASTER_ADMIN_API_KEY', $script:savedApiKey, 'User')
  [Environment]::SetEnvironmentVariable('BUILDMASTER_BASE_URL', $script:savedBaseUrl, 'User')
}

Describe 'New-BuildMasterRelease' -Tag 'Unit', 'PromotedModuleHostSensitive' {

  BeforeEach {
    Mock Write-PSFMessage { }

    $global:configRootKeys = @{
      BuildMasterBaseUrlConfigRootKey      = 'BuildMasterBaseUrl'
      BuildMasterAdminApiKeyConfigRootKey  = 'BuildMasterAdminApiKey'
    }
    $global:settings = @{
      BuildMasterBaseUrl     = 'https://buildmaster.example.test'
      BuildMasterAdminApiKey = 'unit-test-key'
    }
  }

  Context 'Happy path: create returns new release id' {
    It 'POSTs to /api/releases/create and returns the new id' {
      Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Post' } -MockWith {
        [PSCustomObject]@{ id = 12345 }
      }
      Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Get' } -MockWith {
        throw 'Get should not be called on the happy path'
      }

      $result = New-BuildMasterRelease `
        -Application 'AceCommander' `
        -ReleaseNumber '0.1.0-Sprint.42' `
        -PipelineName 'CSharp-Package-Pipeline'

      $result.Succeeded | Should -BeTrue
      $result.OperationName | Should -Be 'New-BuildMasterRelease'
      $result.ReleaseId | Should -Be '12345'
      $result.ResponseSummary | Should -Match 'created'
      Assert-MockCalled Invoke-RestMethod -Times 1 -Exactly -Scope It -ParameterFilter { $Method -eq 'Post' }
    }

    It 'Includes the X-ApiKey header on the POST' {
      $script:capturedHeaders = $null
      Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Post' } -MockWith {
        $script:capturedHeaders = $Headers
        [PSCustomObject]@{ id = 1 }
      }
      New-BuildMasterRelease -Application 'A' -ReleaseNumber '1.0.0' -PipelineName 'P' | Out-Null
      $script:capturedHeaders.ContainsKey('X-ApiKey') | Should -BeTrue
      $script:capturedHeaders['X-ApiKey'] | Should -Be 'unit-test-key'
    }

    It 'Posts a JSON body containing ApplicationName, ReleaseNumber, PipelineName' {
      $script:capturedBody = $null
      Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Post' } -MockWith {
        $script:capturedBody = $Body
        [PSCustomObject]@{ id = 2 }
      }
      New-BuildMasterRelease -Application 'MyApp' -ReleaseNumber '1.2.3' -PipelineName 'MyPipe' | Out-Null
      $parsed = $script:capturedBody | ConvertFrom-Json
      $parsed.ApplicationName | Should -Be 'MyApp'
      $parsed.ReleaseNumber | Should -Be '1.2.3'
      $parsed.PipelineName | Should -Be 'MyPipe'
    }
  }

  Context 'Idempotent path: release already exists' {
    It 'Falls back to GET when POST returns HTTP 409' {
      Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Post' } -MockWith {
        $resp = [PSCustomObject]@{ StatusCode = 409 }
        $ex = [System.Net.WebException]::new('Release already exists')
        $errRec = [System.Management.Automation.ErrorRecord]::new($ex, 'BMConflict', 'InvalidOperation', $null)
        $errRec.Exception | Add-Member -NotePropertyName 'Response' -NotePropertyValue $resp -Force
        throw $errRec
      }
      Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Get' } -MockWith {
        [PSCustomObject]@{ id = 999 }
      }

      $result = New-BuildMasterRelease -Application 'A' -ReleaseNumber '1.0.0' -PipelineName 'P'
      $result.Succeeded | Should -BeTrue
      $result.ReleaseId | Should -Be '999'
      $result.ResponseSummary | Should -Be 'idempotent: release already exists'
    }

    It 'Falls back to GET when error message contains "already exists" regardless of status code' {
      Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Post' } -MockWith {
        throw 'BuildMaster: a release with this number already exists for this application.'
      }
      Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Get' } -MockWith {
        ,@([PSCustomObject]@{ id = 777 })
      }

      $result = New-BuildMasterRelease -Application 'A' -ReleaseNumber '1.0.0' -PipelineName 'P'
      $result.Succeeded | Should -BeTrue
      $result.ReleaseId | Should -Be '777'
      $result.ResponseSummary | Should -Be 'idempotent: release already exists'
    }
  }

  Context 'Auth failure' {
    It 'Throws on HTTP 401' {
      Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Post' } -MockWith {
        $resp = [PSCustomObject]@{ StatusCode = 401 }
        $ex = [System.Net.WebException]::new('Unauthorized')
        $errRec = [System.Management.Automation.ErrorRecord]::new($ex, 'BMUnauthorized', 'AuthenticationError', $null)
        $errRec.Exception | Add-Member -NotePropertyName 'Response' -NotePropertyValue $resp -Force
        throw $errRec
      }
      { New-BuildMasterRelease -Application 'A' -ReleaseNumber '1.0.0' -PipelineName 'P' } |
        Should -Throw -ExpectedMessage '*authentication failed*'
    }
  }

  Context 'Config resolution' {
    It 'Uses -ApiKey parameter when supplied (overrides $global:settings)' {
      $script:capturedHeaders = $null
      Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Post' } -MockWith {
        $script:capturedHeaders = $Headers
        [PSCustomObject]@{ id = 5 }
      }
      New-BuildMasterRelease -Application 'A' -ReleaseNumber '1.0.0' -PipelineName 'P' -ApiKey 'explicit-key' | Out-Null
      $script:capturedHeaders['X-ApiKey'] | Should -Be 'explicit-key'
    }

    It 'Throws when neither setting nor env var nor parameter provides an API key' {
      $global:settings = @{ BuildMasterBaseUrl = 'https://x.example' }
      [Environment]::SetEnvironmentVariable('BUILDMASTER_ADMIN_API_KEY', $null, 'Process')
      [Environment]::SetEnvironmentVariable('BUILDMASTER_ADMIN_API_KEY', $null, 'User')
      { New-BuildMasterRelease -Application 'A' -ReleaseNumber '1.0.0' -PipelineName 'P' } |
        Should -Throw -ExpectedMessage '*BUILDMASTER_ADMIN_API_KEY*'
    }

    It 'Throws when no base URL is configured' {
      $global:settings = @{ BuildMasterAdminApiKey = 'k' }
      [Environment]::SetEnvironmentVariable('BUILDMASTER_BASE_URL', $null, 'Process')
      [Environment]::SetEnvironmentVariable('BUILDMASTER_BASE_URL', $null, 'User')
      { New-BuildMasterRelease -Application 'A' -ReleaseNumber '1.0.0' -PipelineName 'P' } |
        Should -Throw -ExpectedMessage '*base URL*'
    }
  }

  Context 'WhatIf short-circuit' -Tag 'BuildTranscriptNoise' {
    It 'Does not call Invoke-RestMethod when -WhatIf is supplied' {
      Mock Invoke-RestMethod { throw 'Should not be called under -WhatIf' }
      $result = New-BuildMasterRelease -Application 'A' -ReleaseNumber '1.0.0' -PipelineName 'P' -WhatIf
      $result.Succeeded | Should -BeFalse
      $result.ResponseSummary | Should -Match 'WhatIf'
      Assert-MockCalled Invoke-RestMethod -Times 0 -Exactly -Scope It
    }
  }
}
