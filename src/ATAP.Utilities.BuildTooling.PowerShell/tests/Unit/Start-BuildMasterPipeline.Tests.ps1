#Requires -Version 7.0
# Pester 5+ tests for Start-BuildMasterPipeline (Stream H, task H4).
# Mocks Invoke-RestMethod; no real network or BuildMaster contact.

BeforeAll {
  $publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
  . (Join-Path $publicDir 'Start-BuildMasterPipeline.ps1')

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

Describe 'Start-BuildMasterPipeline' -Tag 'Unit', 'PromotedModuleHostSensitive' {

  BeforeEach {
    $global:configRootKeys = @{
      BuildMasterBaseUrlConfigRootKey      = 'BuildMasterBaseUrl'
      BuildMasterAdminApiKeyConfigRootKey  = 'BuildMasterAdminApiKey'
    }
    $global:settings = @{
      BuildMasterBaseUrl     = 'https://buildmaster.example.test'
      BuildMasterAdminApiKey = 'unit-test-key'
    }
  }

  Context 'Happy path' {
    It 'POSTs to /api/releases/builds/create and returns the new build id + number' {
      Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Post' } -MockWith {
        [PSCustomObject]@{ id = 4271; buildNumber = '4271' }
      }
      $result = Start-BuildMasterPipeline -Application 'AceCommander' -ReleaseNumber '0.1.0-Sprint.42'
      $result.Succeeded | Should -BeTrue
      $result.OperationName | Should -Be 'Start-BuildMasterPipeline'
      $result.BuildId | Should -Be '4271'
      $result.BuildNumber | Should -Be '4271'
      $result.ResponseSummary | Should -Match 'build queued'
      Assert-MockCalled Invoke-RestMethod -Times 1 -Exactly -Scope It -ParameterFilter { $Method -eq 'Post' }
    }

    It 'Targets the correct endpoint URL' {
      $script:capturedUri = $null
      Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Post' } -MockWith {
        $script:capturedUri = $Uri
        [PSCustomObject]@{ id = 1 }
      }
      Start-BuildMasterPipeline -Application 'A' -ReleaseNumber '1.0.0' | Out-Null
      $script:capturedUri | Should -Be 'https://buildmaster.example.test/api/releases/builds/create'
    }

    It 'Includes -Pipeline and -Reason in the JSON body when supplied' {
      $script:capturedBody = $null
      Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Post' } -MockWith {
        $script:capturedBody = $Body
        [PSCustomObject]@{ id = 1 }
      }
      Start-BuildMasterPipeline -Application 'A' -ReleaseNumber '1.0.0' -Pipeline 'MyPipe' -Reason 'demo' | Out-Null
      $parsed = $script:capturedBody | ConvertFrom-Json
      $parsed.ApplicationName | Should -Be 'A'
      $parsed.ReleaseNumber | Should -Be '1.0.0'
      $parsed.PipelineName | Should -Be 'MyPipe'
      $parsed.Reason | Should -Be 'demo'
    }

    It 'Omits Pipeline and Reason from the JSON body when not supplied' {
      $script:capturedBody = $null
      Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Post' } -MockWith {
        $script:capturedBody = $Body
        [PSCustomObject]@{ id = 1 }
      }
      Start-BuildMasterPipeline -Application 'A' -ReleaseNumber '1.0.0' | Out-Null
      $parsed = $script:capturedBody | ConvertFrom-Json
      $parsed.PSObject.Properties.Name | Should -Not -Contain 'PipelineName'
      $parsed.PSObject.Properties.Name | Should -Not -Contain 'Reason'
    }

    It 'Includes build-scope variables and normalizes missing dollar prefixes' {
      $script:capturedBody = $null
      Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Post' } -MockWith {
        $script:capturedBody = $Body
        [PSCustomObject]@{ id = 1 }
      }
      Start-BuildMasterPipeline `
        -Application 'ATAP.Utilities-PowerShell' `
        -ReleaseNumber '0.1.0-Alpha025' `
        -Variables @{
          '$ModuleName' = 'ATAP.Utilities.BuildTooling.PowerShell'
          PackageName = 'ATAP.Utilities.BuildTooling.PowerShell'
          PackageVersion = '0.1.0-Alpha025'
        } | Out-Null

      $parsed = $script:capturedBody | ConvertFrom-Json
      $parsed.'$ModuleName' | Should -Be 'ATAP.Utilities.BuildTooling.PowerShell'
      $parsed.'$PackageName' | Should -Be 'ATAP.Utilities.BuildTooling.PowerShell'
      $parsed.'$PackageVersion' | Should -Be '0.1.0-Alpha025'
    }

    It 'Applies a finite timeout to the create-build call' {
      Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Post' } -MockWith {
        [PSCustomObject]@{ id = 1; buildNumber = '1' }
      }

      Start-BuildMasterPipeline -Application 'A' -ReleaseNumber '1.0.0' | Out-Null

      Assert-MockCalled Invoke-RestMethod -Times 1 -Exactly -Scope It -ParameterFilter {
        $Method -eq 'Post' -and $TimeoutSec -eq 30
      }
    }
  }

  Context 'Variable validation' {
    It 'Throws when a build variable name is empty' {
      Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Post' } -MockWith {
        [PSCustomObject]@{ id = 1 }
      }
      { Start-BuildMasterPipeline -Application 'A' -ReleaseNumber '1.0.0' -Variables @{ '' = 'bad' } } |
        Should -Throw -ExpectedMessage '*variable names must not be empty*'
    }
  }

  Context 'Auth failure' {
    It 'Throws on HTTP 401' {
      Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Post' } -MockWith {
        $resp = [PSCustomObject]@{ StatusCode = 401 }
        $ex = [System.Net.WebException]::new('Unauthorized')
        $errRec = [System.Management.Automation.ErrorRecord]::new($ex, 'BMUnauth', 'AuthenticationError', $null)
        $errRec.Exception | Add-Member -NotePropertyName 'Response' -NotePropertyValue $resp -Force
        throw $errRec
      }
      { Start-BuildMasterPipeline -Application 'A' -ReleaseNumber '1.0.0' } |
        Should -Throw -ExpectedMessage '*authentication failed*'
    }
  }

  Context 'Config resolution' {
    It 'Throws when no API key is configured' {
      $global:settings = @{ BuildMasterBaseUrl = 'https://x.example' }
      [Environment]::SetEnvironmentVariable('BUILDMASTER_ADMIN_API_KEY', $null, 'Process')
      [Environment]::SetEnvironmentVariable('BUILDMASTER_ADMIN_API_KEY', $null, 'User')
      { Start-BuildMasterPipeline -Application 'A' -ReleaseNumber '1.0.0' } |
        Should -Throw -ExpectedMessage '*BUILDMASTER_ADMIN_API_KEY*'
    }
  }

  Context 'WhatIf short-circuit' {
    It 'Does not call Invoke-RestMethod when -WhatIf is supplied' {
      Mock Invoke-RestMethod { throw 'Should not be called under -WhatIf' }
      $result = Start-BuildMasterPipeline -Application 'A' -ReleaseNumber '1.0.0' -WhatIf
      $result.Succeeded | Should -BeFalse
      $result.ResponseSummary | Should -Match 'WhatIf'
      Assert-MockCalled Invoke-RestMethod -Times 0 -Exactly -Scope It
    }
  }
}
