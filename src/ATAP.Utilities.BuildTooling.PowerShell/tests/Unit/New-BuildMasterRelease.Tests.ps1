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
  function Get-SecretATAP {
    param(
      [Alias('BuildMasterAdminApiKeySecretName')]
      [string]$SecretName,
      [string]$SecretField,
      [string]$SecretStoreType
    )
    'unit-test-key'
  }

  $script:oldConfigRootKeys = $global:configRootKeys
  $script:oldSettings = $global:settings
  $script:savedSecretName = [Environment]::GetEnvironmentVariable('BuildMasterAdminApiKeySecretName', 'User')
  $script:savedBaseUrl = [Environment]::GetEnvironmentVariable('BUILDMASTER_BASE_URL', 'User')
}

AfterAll {
  $global:configRootKeys = $script:oldConfigRootKeys
  $global:settings = $script:oldSettings
  [Environment]::SetEnvironmentVariable('BuildMasterAdminApiKeySecretName', $script:savedSecretName, 'User')
  [Environment]::SetEnvironmentVariable('BUILDMASTER_BASE_URL', $script:savedBaseUrl, 'User')
}

Describe 'New-BuildMasterRelease' -Tag 'Unit', 'PromotedModuleHostSensitive' {

  BeforeEach {
    Mock Write-PSFMessage { }
    Mock Get-SecretATAP { 'unit-test-key' }

    $global:configRootKeys = @{
      BuildMasterBaseUrlConfigRootKey                 = 'BuildMasterBaseUrl'
      BuildMasterAdminApiKeySecretNameConfigRootKey   = 'BuildMasterAdminApiKeySecretName'
    }
    $global:settings = @{
      BuildMasterBaseUrl                   = 'https://buildmaster.example.test'
      BuildMasterAdminApiKeySecretName     = 'BuildMaster.Admin.API.Key'
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

    It 'Includes ReleaseName in the JSON body when supplied' {
      $script:capturedBody = $null
      Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Post' } -MockWith {
        $script:capturedBody = $Body
        [PSCustomObject]@{ id = 3 }
      }
      $result = New-BuildMasterRelease `
        -Application 'ATAP.Utilities-PowerShell' `
        -ReleaseNumber '0.1.0-Alpha025' `
        -ReleaseName 'ATAP.Utilities.BuildTooling.PowerShell 0.1.0-Alpha025' `
        -PipelineName 'global::PowerShellModule-5Stage'

      $parsed = $script:capturedBody | ConvertFrom-Json
      $parsed.ReleaseName | Should -Be 'ATAP.Utilities.BuildTooling.PowerShell 0.1.0-Alpha025'
      $result.ReleaseName | Should -Be 'ATAP.Utilities.BuildTooling.PowerShell 0.1.0-Alpha025'
    }

    It 'Applies a finite timeout to the create call' {
      $script:createCalledWithFiniteTimeout = $false
      Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Post' } -MockWith {
        throw 'POST was called without -TimeoutSec 30.'
      }
      Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Post' -and $TimeoutSec -eq 30 } -MockWith {
        $script:createCalledWithFiniteTimeout = $true
        [PSCustomObject]@{ id = 4 }
      }

      New-BuildMasterRelease -Application 'A' -ReleaseNumber '1.0.0' -PipelineName 'P' | Out-Null

      Assert-MockCalled Invoke-RestMethod -Times 1 -Exactly -Scope It -ParameterFilter { $Method -eq 'Post' }
      $script:createCalledWithFiniteTimeout | Should -BeTrue
    }
  }

  Context 'Idempotent path: release already exists' {
    It 'Falls back to GET when POST returns HTTP 409' {
      $script:getCalledWithFiniteTimeout = $false
      Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Post' } -MockWith {
        $resp = [PSCustomObject]@{ StatusCode = 409 }
        $ex = [System.Net.WebException]::new('Release already exists')
        $errRec = [System.Management.Automation.ErrorRecord]::new($ex, 'BMConflict', 'InvalidOperation', $null)
        $errRec.Exception | Add-Member -NotePropertyName 'Response' -NotePropertyValue $resp -Force
        throw $errRec
      }
      Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Get' } -MockWith {
        throw 'GET was called without -TimeoutSec 30.'
      }
      Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Get' -and $TimeoutSec -eq 30 } -MockWith {
        $script:getCalledWithFiniteTimeout = $true
        [PSCustomObject]@{ id = 999 }
      }

      $result = New-BuildMasterRelease -Application 'A' -ReleaseNumber '1.0.0' -PipelineName 'P'
      $result.Succeeded | Should -BeTrue
      $result.ReleaseId | Should -Be '999'
      $result.ResponseSummary | Should -Be 'idempotent: release already exists'
      Assert-MockCalled Invoke-RestMethod -Times 1 -Exactly -Scope It -ParameterFilter { $Method -eq 'Get' }
      $script:getCalledWithFiniteTimeout | Should -BeTrue
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

    It 'Falls back to GET when POST returns a generic HTTP 400 and the release is already present' {
      Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Post' } -MockWith {
        $resp = [PSCustomObject]@{ StatusCode = 400 }
        $ex = [System.Net.WebException]::new('Response status code does not indicate success: 400 (Bad Request).')
        $errRec = [System.Management.Automation.ErrorRecord]::new($ex, 'BMBadRequest', 'InvalidOperation', $null)
        $errRec.Exception | Add-Member -NotePropertyName 'Response' -NotePropertyValue $resp -Force
        throw $errRec
      }
      Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Get' } -MockWith {
        [PSCustomObject]@{ id = 1013 }
      }

      $result = New-BuildMasterRelease -Application 'A' -ReleaseNumber '1.0.0' -PipelineName 'P'
      $result.Succeeded | Should -BeTrue
      $result.ReleaseId | Should -Be '1013'
      $result.ResponseSummary | Should -Be 'idempotent: release already exists'
    }

    It 'Falls back to the native release list when generic HTTP 400 is followed by REST lookup failure' {
      Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Post' -and $Uri -like '*/api/releases/create' } -MockWith {
        $resp = [PSCustomObject]@{ StatusCode = 400 }
        $ex = [System.Net.WebException]::new('Response status code does not indicate success: 400 (Bad Request).')
        $errRec = [System.Management.Automation.ErrorRecord]::new($ex, 'BMBadRequest', 'InvalidOperation', $null)
        $errRec.Exception | Add-Member -NotePropertyName 'Response' -NotePropertyValue $resp -Force
        throw $errRec
      }
      Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Get' } -MockWith {
        throw 'Response status code does not indicate success: 500 (Internal Server Error).'
      }
      Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Post' -and $Uri -like '*/api/json/Applications_GetApplications' } -MockWith {
        [PSCustomObject]@{ Application_Id = 42; Application_Name = 'A' }
      }
      Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Post' -and $Uri -like '*/api/json/Releases_GetReleases' } -MockWith {
        [PSCustomObject]@{ Release_Id = 1013; Release_Name = '1.0.0' }
      }

      $result = New-BuildMasterRelease -Application 'A' -ReleaseNumber '1.0.0' -PipelineName 'P'
      $result.Succeeded | Should -BeTrue
      $result.ReleaseId | Should -Be '1013'
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
    It 'Uses -BuildMasterAdminApiKeySecretName parameter when supplied (overrides $global:settings)' {
      $script:capturedHeaders = $null
      $script:capturedSecretName = $null
      Mock Get-SecretATAP -MockWith {
        $script:capturedSecretName = $SecretName
        'explicit-key-value'
      }
      Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Post' } -MockWith {
        $script:capturedHeaders = $Headers
        [PSCustomObject]@{ id = 5 }
      }
      New-BuildMasterRelease -Application 'A' -ReleaseNumber '1.0.0' -PipelineName 'P' -BuildMasterAdminApiKeySecretName 'Explicit.Secret.Name' | Out-Null
      $script:capturedSecretName | Should -Be 'Explicit.Secret.Name'
      $script:capturedHeaders['X-ApiKey'] | Should -Be 'explicit-key-value'
    }

    It 'Throws when neither setting nor env var nor parameter provides an API key secret name' {
      $global:settings = @{ BuildMasterBaseUrl = 'https://x.example' }
      [Environment]::SetEnvironmentVariable('BuildMasterAdminApiKeySecretName', $null, 'Process')
      [Environment]::SetEnvironmentVariable('BuildMasterAdminApiKeySecretName', $null, 'User')
      { New-BuildMasterRelease -Application 'A' -ReleaseNumber '1.0.0' -PipelineName 'P' } |
        Should -Throw -ExpectedMessage '*BuildMasterAdminApiKeySecretName*'
    }

    It 'Uses the localhost BuildMaster default when no base URL is configured' {
      $global:settings = @{ BuildMasterAdminApiKeySecretName = 'BuildMaster.Admin.API.Key' }
      [Environment]::SetEnvironmentVariable('BUILDMASTER_BASE_URL', $null, 'Process')
      [Environment]::SetEnvironmentVariable('BUILDMASTER_BASE_URL', $null, 'User')
      Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Post' } -MockWith {
        [PSCustomObject]@{ id = 6 }
      }

      New-BuildMasterRelease -Application 'A' -ReleaseNumber '1.0.0' -PipelineName 'P' | Out-Null

      Assert-MockCalled Invoke-RestMethod -Times 1 -Exactly -Scope It -ParameterFilter {
        $Method -eq 'Post' -and $Uri -eq 'http://localhost:50017/api/releases/create'
      }
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
