#Requires -Version 7.0
# Pester 5+ tests for Start-BuildMasterDeployment.
# Mocks Invoke-RestMethod; no real BuildMaster contact.

BeforeAll {
  $publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
  . (Join-Path $publicDir 'Start-BuildMasterDeployment.ps1')

  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
  }

  function Get-ParameterValueFromNeoConfigurationRoot {
    param(
      [string]$ParameterName,
      [hashtable]$originalPSBoundParameters,
      $DefaultValue
    )

    if ($null -ne $originalPSBoundParameters -and $originalPSBoundParameters.ContainsKey($ParameterName)) {
      $boundValue = $originalPSBoundParameters[$ParameterName]
      if (-not [string]::IsNullOrWhiteSpace([string]$boundValue)) {
        return $boundValue
      }
    }
    if (-not [string]::IsNullOrWhiteSpace([string]$DefaultValue)) {
      return $DefaultValue
    }
    if ($ParameterName -eq 'BuildMasterBaseUrl') {
      $key = if ($null -ne $global:configRootKeys) { $global:configRootKeys['BuildMasterBaseUrlConfigRootKey'] } else { $null }
      if ([string]::IsNullOrWhiteSpace($key)) { $key = 'BuildMasterBaseUrl' }
      if ($null -ne $global:settings) {
        return [string]$global:settings[$key]
      }
    }
    return $null
  }
  Set-Alias -Name Get-PVal -Value Get-ParameterValueFromNeoConfigurationRoot -Scope Script -Force

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

Describe 'Start-BuildMasterDeployment' -Tag 'Unit', 'PromotedModuleHostSensitive' {

  BeforeEach {
    Mock Write-PSFMessage { }

    $global:configRootKeys = @{
      BuildMasterBaseUrlConfigRootKey     = 'BuildMasterBaseUrl'
      BuildMasterAdminApiKeyConfigRootKey = 'BuildMasterAdminApiKey'
    }
    $global:settings = @{
      BuildMasterBaseUrl     = 'https://buildmaster.example.test'
      BuildMasterAdminApiKey = 'unit-test-key'
    }
  }

  Context 'Happy path' {
    It 'POSTs to /api/releases/builds/deploy and returns deployment id + state' {
      Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Post' } -MockWith {
        [PSCustomObject]@{ id = 3021; status = 'pending' }
      }

      $result = Start-BuildMasterDeployment `
        -Application 'ATAP.Utilities-PowerShell' `
        -ReleaseNumber '0.1.0-Alpha025' `
        -BuildNumber '1' `
        -ToStage 'Experimental'

      $result.Succeeded | Should -BeTrue
      $result.OperationName | Should -Be 'Start-BuildMasterDeployment'
      $result.DeploymentId | Should -Be '3021'
      $result.DeploymentState | Should -Be 'pending'
      $result.ResponseSummary | Should -Match 'deployment started'
      Assert-MockCalled Invoke-RestMethod -Times 1 -Exactly -Scope It -ParameterFilter { $Method -eq 'Post' }
    }

    It 'Targets the correct endpoint URL' {
      $script:capturedUri = $null
      Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Post' } -MockWith {
        $script:capturedUri = $Uri
        [PSCustomObject]@{ id = 1 }
      }

      Start-BuildMasterDeployment -Application 'A' -ReleaseNumber '1.0.0' -BuildNumber '2' | Out-Null

      $script:capturedUri | Should -Be 'https://buildmaster.example.test/api/releases/builds/deploy'
    }

    It 'Sends the required body plus target stage and force when supplied' {
      $script:capturedBody = $null
      Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Post' } -MockWith {
        $script:capturedBody = $Body
        [PSCustomObject]@{ id = 1 }
      }

      Start-BuildMasterDeployment `
        -Application 'A' `
        -ReleaseNumber '1.0.0' `
        -BuildNumber '2' `
        -ToStage 'Experimental' `
        -Force | Out-Null

      $parsed = $script:capturedBody | ConvertFrom-Json
      $parsed.applicationName | Should -Be 'A'
      $parsed.releaseNumber | Should -Be '1.0.0'
      $parsed.buildNumber | Should -Be '2'
      $parsed.toStage | Should -Be 'Experimental'
      $parsed.force | Should -BeTrue
    }

    It 'Omits ToStage and Force when not supplied' {
      $script:capturedBody = $null
      Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Post' } -MockWith {
        $script:capturedBody = $Body
        [PSCustomObject]@{ id = 1 }
      }

      Start-BuildMasterDeployment -Application 'A' -ReleaseNumber '1.0.0' -BuildNumber '2' | Out-Null

      $parsed = $script:capturedBody | ConvertFrom-Json
      $parsed.PSObject.Properties.Name | Should -Not -Contain 'toStage'
      $parsed.PSObject.Properties.Name | Should -Not -Contain 'force'
    }

    It 'Includes deployment variables and normalizes missing dollar prefixes' {
      $script:capturedBody = $null
      Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Post' } -MockWith {
        $script:capturedBody = $Body
        [PSCustomObject]@{ id = 1 }
      }

      Start-BuildMasterDeployment `
        -Application 'A' `
        -ReleaseNumber '1.0.0' `
        -BuildNumber '2' `
        -Variables @{ ModuleName = 'ATAP.Utilities.PowerShell'; '$PackageVersion' = '0.1.0-Alpha001' } | Out-Null

      $parsed = $script:capturedBody | ConvertFrom-Json
      $parsed.'$ModuleName' | Should -Be 'ATAP.Utilities.PowerShell'
      $parsed.'$PackageVersion' | Should -Be '0.1.0-Alpha001'
    }

    It 'Applies a finite timeout to the deploy call' {
      Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Post' } -MockWith {
        [PSCustomObject]@{ id = 1 }
      }

      Start-BuildMasterDeployment -Application 'A' -ReleaseNumber '1.0.0' -BuildNumber '2' | Out-Null

      Assert-MockCalled Invoke-RestMethod -Times 1 -Exactly -Scope It -ParameterFilter {
        $Method -eq 'Post' -and $TimeoutSec -eq 30
      }
    }
  }

  Context 'Variable validation' {
    It 'Throws when a deployment variable name is empty' {
      Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Post' } -MockWith {
        [PSCustomObject]@{ id = 1 }
      }

      { Start-BuildMasterDeployment -Application 'A' -ReleaseNumber '1.0.0' -BuildNumber '2' -Variables @{ '' = 'bad' } } |
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

      { Start-BuildMasterDeployment -Application 'A' -ReleaseNumber '1.0.0' -BuildNumber '2' } |
        Should -Throw -ExpectedMessage '*authentication failed*'
    }
  }

  Context 'Config resolution' {
    It 'Throws when no API key is configured' {
      $global:settings = @{ BuildMasterBaseUrl = 'https://x.example' }
      [Environment]::SetEnvironmentVariable('BUILDMASTER_ADMIN_API_KEY', $null, 'Process')
      [Environment]::SetEnvironmentVariable('BUILDMASTER_ADMIN_API_KEY', $null, 'User')

      { Start-BuildMasterDeployment -Application 'A' -ReleaseNumber '1.0.0' -BuildNumber '2' } |
        Should -Throw -ExpectedMessage '*BUILDMASTER_ADMIN_API_KEY*'
    }
  }

  Context 'WhatIf short-circuit' {
    It 'Does not call Invoke-RestMethod when -WhatIf is supplied' {
      Mock Invoke-RestMethod { throw 'Should not be called under -WhatIf' }

      $result = Start-BuildMasterDeployment -Application 'A' -ReleaseNumber '1.0.0' -BuildNumber '2' -WhatIf

      $result.Succeeded | Should -BeFalse
      $result.ResponseSummary | Should -Match 'WhatIf'
      Assert-MockCalled Invoke-RestMethod -Times 0 -Exactly -Scope It
    }
  }
}
