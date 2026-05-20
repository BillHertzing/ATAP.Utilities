#Requires -Version 7.0
# Pester 5+ tests for Approve-BuildMasterStage (Stream H, task H5).
# Mocks Invoke-RestMethod; no real network or BuildMaster contact.

BeforeAll {
  $publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
  . (Join-Path $publicDir 'Approve-BuildMasterStage.ps1')

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

Describe 'Approve-BuildMasterStage' -Tag 'Unit' {

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

  Context 'Happy path' {
    It 'POSTs to /api/releases/builds/manual-approval and returns success' {
      Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Post' } -MockWith {
        [PSCustomObject]@{ ok = $true }
      }
      $result = Approve-BuildMasterStage `
        -Application 'AceCommander' `
        -ReleaseNumber '0.1.0-Sprint.42' `
        -BuildNumber '17' `
        -Stage 'Integration' `
        -Comment 'INT-PASS'

      $result.Succeeded | Should -BeTrue
      $result.OperationName | Should -Be 'Approve-BuildMasterStage'
      $result.Stage | Should -Be 'Integration'
      $result.ResponseSummary | Should -Match 'approved'
      Assert-MockCalled Invoke-RestMethod -Times 1 -Exactly -Scope It -ParameterFilter { $Method -eq 'Post' }
    }

    It 'Targets the correct endpoint URL' {
      $script:capturedUri = $null
      Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Post' } -MockWith {
        $script:capturedUri = $Uri
        [PSCustomObject]@{ ok = $true }
      }
      Approve-BuildMasterStage -Application 'A' -ReleaseNumber '1.0.0' -BuildNumber '1' -Stage 'QA' | Out-Null
      $script:capturedUri | Should -Be 'https://buildmaster.example.test/api/releases/builds/manual-approval'
    }

    It 'Sends the four required fields and the optional Comment in the JSON body' {
      $script:capturedBody = $null
      Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Post' } -MockWith {
        $script:capturedBody = $Body
        [PSCustomObject]@{ ok = $true }
      }
      Approve-BuildMasterStage -Application 'A' -ReleaseNumber '1.0.0' -BuildNumber '2' -Stage 'QA' -Comment 'looks good' | Out-Null
      $parsed = $script:capturedBody | ConvertFrom-Json
      $parsed.ApplicationName | Should -Be 'A'
      $parsed.ReleaseNumber | Should -Be '1.0.0'
      $parsed.BuildNumber | Should -Be '2'
      $parsed.Stage | Should -Be 'QA'
      $parsed.Comment | Should -Be 'looks good'
    }

    It 'Omits Comment from the JSON body when not supplied' {
      $script:capturedBody = $null
      Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Post' } -MockWith {
        $script:capturedBody = $Body
        [PSCustomObject]@{ ok = $true }
      }
      Approve-BuildMasterStage -Application 'A' -ReleaseNumber '1.0.0' -BuildNumber '3' -Stage 'QA' | Out-Null
      $parsed = $script:capturedBody | ConvertFrom-Json
      $parsed.PSObject.Properties.Name | Should -Not -Contain 'Comment'
    }
  }

  Context 'Idempotent path: stage already approved' {
    It 'Treats HTTP 409 as success with idempotent ResponseSummary' {
      Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Post' } -MockWith {
        $resp = [PSCustomObject]@{ StatusCode = 409 }
        $ex = [System.Net.WebException]::new('Stage already approved')
        $errRec = [System.Management.Automation.ErrorRecord]::new($ex, 'BMConflict', 'InvalidOperation', $null)
        $errRec.Exception | Add-Member -NotePropertyName 'Response' -NotePropertyValue $resp -Force
        throw $errRec
      }
      $result = Approve-BuildMasterStage -Application 'A' -ReleaseNumber '1.0.0' -BuildNumber '1' -Stage 'QA'
      $result.Succeeded | Should -BeTrue
      $result.ResponseSummary | Should -Be 'idempotent: stage already approved'
    }

    It 'Treats "already approved" error message as success even when status code is unavailable' {
      Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Post' } -MockWith {
        throw 'BuildMaster: this stage was already approved.'
      }
      $result = Approve-BuildMasterStage -Application 'A' -ReleaseNumber '1.0.0' -BuildNumber '1' -Stage 'QA'
      $result.Succeeded | Should -BeTrue
      $result.ResponseSummary | Should -Be 'idempotent: stage already approved'
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
      { Approve-BuildMasterStage -Application 'A' -ReleaseNumber '1.0.0' -BuildNumber '1' -Stage 'QA' } |
        Should -Throw -ExpectedMessage '*authentication failed*'
    }
  }

  Context 'Config resolution' {
    It 'Throws when no API key is configured' {
      $global:settings = @{ BuildMasterBaseUrl = 'https://x.example' }
      [Environment]::SetEnvironmentVariable('BUILDMASTER_ADMIN_API_KEY', $null, 'Process')
      [Environment]::SetEnvironmentVariable('BUILDMASTER_ADMIN_API_KEY', $null, 'User')
      { Approve-BuildMasterStage -Application 'A' -ReleaseNumber '1.0.0' -BuildNumber '1' -Stage 'QA' } |
        Should -Throw -ExpectedMessage '*BUILDMASTER_ADMIN_API_KEY*'
    }
  }

  Context 'WhatIf short-circuit' -Tag 'BuildTranscriptNoise' {
    It 'Does not call Invoke-RestMethod when -WhatIf is supplied' {
      Mock Invoke-RestMethod { throw 'Should not be called under -WhatIf' }
      $result = Approve-BuildMasterStage -Application 'A' -ReleaseNumber '1.0.0' -BuildNumber '1' -Stage 'QA' -WhatIf
      $result.Succeeded | Should -BeFalse
      $result.ResponseSummary | Should -Match 'WhatIf'
      Assert-MockCalled Invoke-RestMethod -Times 0 -Exactly -Scope It
    }
  }
}
