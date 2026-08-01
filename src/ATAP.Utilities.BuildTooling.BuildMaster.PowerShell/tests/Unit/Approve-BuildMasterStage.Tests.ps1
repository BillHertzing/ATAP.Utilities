#Requires -Version 7.0
# Pester 5+ tests for Approve-BuildMasterStage (Stream H, task H5).
# Mocks Invoke-RestMethod; no real network or BuildMaster contact.

BeforeAll {
  $publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
  . (Join-Path $publicDir 'Approve-BuildMasterStage.ps1')

  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
  }

  # Stub the secret-name resolver and the secret store so the cmdlet resolves the
  # BuildMaster admin API key without contacting Bitwarden.
  function Get-ParameterValueFromNeoConfigurationRoot {
    param([string]$ParameterName, $originalPSBoundParameters, [AllowNull()]$DefaultValue = $null, [string]$dottedPath, [hashtable]$Settings)
    if ($originalPSBoundParameters -and $originalPSBoundParameters.ContainsKey($ParameterName)) { return $originalPSBoundParameters[$ParameterName] }
    $settingsRoot = if ($Settings) { $Settings } elseif ($global:settings) { $global:settings } else { @{} }
    $key = if (-not [string]::IsNullOrWhiteSpace($dottedPath)) { $dottedPath } else { $ParameterName }
    if ($settingsRoot -is [System.Collections.IDictionary] -and $settingsRoot.Contains($key)) { return $settingsRoot[$key] }
    return $DefaultValue
  }
  Set-Alias -Name Get-PVal -Value Get-ParameterValueFromNeoConfigurationRoot -Scope Script -Force
  function Get-SecretATAP {
    param([Parameter(ValueFromPipelineByPropertyName = $true)][Alias('BuildMasterAdminApiKeySecretName')][string]$SecretName, [string]$SecretField = 'password', [string]$SecretStoreType)
    'unit-test-key'
  }

  $script:oldConfigRootKeys = $global:configRootKeys
  $script:oldSettings = $global:settings
  $script:savedBaseUrl = [Environment]::GetEnvironmentVariable('BUILDMASTER_BASE_URL', 'User')
}

AfterAll {
  $global:configRootKeys = $script:oldConfigRootKeys
  $global:settings = $script:oldSettings
  [Environment]::SetEnvironmentVariable('BUILDMASTER_BASE_URL', $script:savedBaseUrl, 'User')
}

Describe 'Approve-BuildMasterStage' -Tag 'Unit' {

  BeforeEach {
    Mock Write-PSFMessage { }

    $global:configRootKeys = @{
      # SC-0288 / Task 13.66.b: SecretName host suffixes come from the placement map.
      ServicePlacementMapConfigRootKey    = 'ServicePlacementMap'
      BuildMasterBaseUrlConfigRootKey      = 'BuildMasterBaseUrl'
      BuildMasterAdminApiKeyConfigRootKey  = 'BuildMasterAdminApiKey'
    }
    $global:settings = @{
      ServicePlacementMap    = @{ BuildMaster = 'utat022'; ProGet = 'utat022' }
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
    It 'Throws when the API key is not resolvable via Get-SecretATAP' {
      $global:settings = @{
        BuildMasterBaseUrl  = 'https://x.example'
        # SC-0288 / Task 13.66.b: placement must stay declared, or SecretName
        # resolution fails closed before Get-SecretATAP is ever reached.
        ServicePlacementMap = @{ BuildMaster = 'utat022'; ProGet = 'utat022' }
      }
      Mock Get-SecretATAP { throw 'secret store unavailable' }
      { Approve-BuildMasterStage -Application 'A' -ReleaseNumber '1.0.0' -BuildNumber '1' -Stage 'QA' } |
        Should -Throw -ExpectedMessage '*Get-SecretATAP*'
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