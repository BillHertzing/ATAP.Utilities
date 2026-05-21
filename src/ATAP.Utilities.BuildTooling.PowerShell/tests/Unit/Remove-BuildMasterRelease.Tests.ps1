#Requires -Version 7.0
# Pester 5+ tests for Remove-BuildMasterRelease (Stream E, task E04b).
# Mocks Invoke-RestMethod; no real network or BuildMaster contact.

BeforeAll {
  $publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
  . (Join-Path $publicDir 'Remove-BuildMasterRelease.ps1')

  # Provide a deterministic settings resolver for this test file. The real
  # helper can be loaded by earlier tests in aggregate runs, so preserve and
  # restore any existing global definition instead of depending on load order.
  $script:hadGlobalGetPValFunction = Test-Path -Path 'Function:\global:Get-ParameterValueFromNeoConfigurationRoot'
  if ($script:hadGlobalGetPValFunction) {
    $script:originalGlobalGetPValFunction = (Get-Item -Path 'Function:\global:Get-ParameterValueFromNeoConfigurationRoot').ScriptBlock
  }
  $script:hadGlobalGetPValAlias = Test-Path -Path 'Alias:\Get-PVal'
  if ($script:hadGlobalGetPValAlias) {
    $script:originalGlobalGetPValAlias = (Get-Alias -Name Get-PVal).Definition
  }

  function global:Get-ParameterValueFromNeoConfigurationRoot {
    param(
      [string]$ParameterName,
      $originalPSBoundParameters,
      [AllowNull()]$DefaultValue = $null,
      [string]$dottedPath,
      [hashtable]$Settings
    )

    if ($originalPSBoundParameters -and $originalPSBoundParameters.ContainsKey($ParameterName)) {
      return $originalPSBoundParameters[$ParameterName]
    }

    $settingsRoot = if ($Settings) { $Settings } elseif ($global:settings) { $global:settings } else { @{} }
    $settingsKey = if (-not [string]::IsNullOrWhiteSpace($dottedPath)) { $dottedPath } else { $ParameterName }
    if ($settingsRoot -is [System.Collections.IDictionary] -and $settingsRoot.Contains($settingsKey)) {
      return $settingsRoot[$settingsKey]
    }

    $processEnvValue = [Environment]::GetEnvironmentVariable($ParameterName, 'Process')
    if (-not [string]::IsNullOrWhiteSpace($processEnvValue)) {
      return $processEnvValue
    }

    $userEnvValue = [Environment]::GetEnvironmentVariable($ParameterName, 'User')
    if (-not [string]::IsNullOrWhiteSpace($userEnvValue)) {
      return $userEnvValue
    }

    return $DefaultValue
  }
  Set-Alias -Name Get-PVal -Value Get-ParameterValueFromNeoConfigurationRoot -Scope Global -Force

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

  if ($script:hadGlobalGetPValFunction) {
    Set-Item -Path 'Function:\global:Get-ParameterValueFromNeoConfigurationRoot' -Value $script:originalGlobalGetPValFunction
  } else {
    Remove-Item -Path 'Function:\global:Get-ParameterValueFromNeoConfigurationRoot' -ErrorAction SilentlyContinue
  }
  if ($script:hadGlobalGetPValAlias) {
    Set-Alias -Name Get-PVal -Value $script:originalGlobalGetPValAlias -Scope Global -Force
  } else {
    Remove-Item -Path 'Alias:\Get-PVal' -ErrorAction SilentlyContinue
  }
}

Describe 'Remove-BuildMasterRelease' -Tag 'Unit', 'PromotedModuleHostSensitive' {

  BeforeEach {
    $global:configRootKeys = @{
      BuildMasterBaseUrlConfigRootKey     = 'BuildMasterBaseUrl'
      BuildMasterAdminApiKeyConfigRootKey = 'BuildMasterAdminApiKey'
    }
    $global:settings = @{
      BuildMasterBaseUrl     = 'https://buildmaster.example.test'
      BuildMasterAdminApiKey = 'unit-test-key'
    }
  }

  Context 'Happy path: cancel release (default action)' {
    It 'Calls Applications_GetApplications, Releases_GetReleases, and Releases_CancelRelease' {
      $script:capturedUris = @()
      Mock Invoke-RestMethod -MockWith {
        $script:capturedUris += $Uri
        if ($Uri -match 'Applications_GetApplications') {
          return , @([PSCustomObject]@{ Application_Id = 42; Application_Name = 'ATAP.Utilities-PowerShell' })
        }
        if ($Uri -match 'Releases_GetReleases') {
          return , @([PSCustomObject]@{ Release_Id = 1004; Release_Name = '0.0.0' })
        }
        if ($Uri -match 'Releases_CancelRelease') {
          return [PSCustomObject]@{ success = $true }
        }
        throw "Unexpected URI: $Uri"
      }

      $result = Remove-BuildMasterRelease `
        -Application 'ATAP.Utilities-PowerShell' `
        -ReleaseNumber '0.0.0' `
        -Confirm:$false

      $result.Succeeded | Should -BeTrue
      $result.OperationName | Should -Be 'Remove-BuildMasterRelease'
      $result.ReleaseId | Should -Be 1004
      $result.Action | Should -Be 'Canceled'
      $result.ResponseSummary | Should -Match 'canceled release id 1004'
      $script:capturedUris | Where-Object { $_ -match 'Releases_CancelRelease' } | Should -HaveCount 1
    }
  }

  Context 'Happy path: purge release (with -Purge switch)' {
    It 'Calls Releases_PurgeReleaseData instead of Releases_CancelRelease' {
      $script:capturedUris = @()
      Mock Invoke-RestMethod -MockWith {
        $script:capturedUris += $Uri
        if ($Uri -match 'Applications_GetApplications') {
          return , @([PSCustomObject]@{ Application_Id = 42; Application_Name = 'ATAP.Utilities-PowerShell' })
        }
        if ($Uri -match 'Releases_GetReleases') {
          return , @([PSCustomObject]@{ Release_Id = 1006; Release_Name = 'Placeholder' })
        }
        if ($Uri -match 'Releases_PurgeReleaseData') {
          return [PSCustomObject]@{ success = $true }
        }
        throw "Unexpected URI: $Uri"
      }

      $result = Remove-BuildMasterRelease `
        -Application 'ATAP.Utilities-PowerShell' `
        -ReleaseNumber 'Placeholder' `
        -Purge `
        -Confirm:$false

      $result.Succeeded | Should -BeTrue
      $result.Action | Should -Be 'Purged'
      $result.ReleaseId | Should -Be 1006
      $result.ResponseSummary | Should -Match 'purged release id 1006'
      $script:capturedUris | Where-Object { $_ -match 'Releases_PurgeReleaseData' } | Should -HaveCount 1
      $script:capturedUris | Where-Object { $_ -match 'Releases_CancelRelease' } | Should -HaveCount 0
    }
  }

  Context 'Ambiguous release match (error path)' {
    It 'Throws when multiple releases have the same Release_Name' {
      Mock Invoke-RestMethod -MockWith {
        if ($Uri -match 'Applications_GetApplications') {
          return , @([PSCustomObject]@{ Application_Id = 42; Application_Name = 'MyApp' })
        }
        if ($Uri -match 'Releases_GetReleases') {
          return , @(
            [PSCustomObject]@{ Release_Id = 100; Release_Name = 'Duplicate' },
            [PSCustomObject]@{ Release_Id = 101; Release_Name = 'Duplicate' }
          )
        }
        throw "Unexpected URI: $Uri"
      }

      { Remove-BuildMasterRelease `
          -Application 'MyApp' `
          -ReleaseNumber 'Duplicate' `
          -Confirm:$false } |
        Should -Throw -ExpectedMessage '*Ambiguous match*'
    }
  }

  Context 'Missing release (idempotent no-op)' {
    It 'Returns Action=Unchanged when release not found' {
      Mock Invoke-RestMethod -MockWith {
        if ($Uri -match 'Applications_GetApplications') {
          return , @([PSCustomObject]@{ Application_Id = 42; Application_Name = 'MyApp' })
        }
        if ($Uri -match 'Releases_GetReleases') {
          return , @()
        }
        throw "Unexpected URI: $Uri"
      }

      $result = Remove-BuildMasterRelease `
        -Application 'MyApp' `
        -ReleaseNumber 'NonExistent' `
        -Confirm:$false

      $result.Succeeded | Should -BeTrue
      $result.Action | Should -Be 'Unchanged'
      $result.ReleaseId | Should -BeNullOrEmpty
      $result.ResponseSummary | Should -Match 'not found'
    }
  }

  Context 'Missing application (idempotent no-op)' {
    It 'Returns Action=NotFound when application not found' {
      Mock Invoke-RestMethod -MockWith {
        if ($Uri -match 'Applications_GetApplications') {
          return , @()
        }
        throw "Unexpected URI: $Uri"
      }

      $result = Remove-BuildMasterRelease `
        -Application 'NonExistentApp' `
        -ReleaseNumber '1.0.0' `
        -Confirm:$false

      $result.Succeeded | Should -BeTrue
      $result.Action | Should -Be 'NotFound'
      $result.ReleaseId | Should -BeNullOrEmpty
      $result.ResponseSummary | Should -Match 'application.*not found'
    }
  }

  Context 'WhatIf short-circuit' {
    It 'Does not call cancel or purge when -WhatIf is supplied' {
      $script:capturedUris = @()
      Mock Invoke-RestMethod -MockWith {
        $script:capturedUris += $Uri
        if ($Uri -match 'Applications_GetApplications') {
          return , @([PSCustomObject]@{ Application_Id = 42; Application_Name = 'MyApp' })
        }
        if ($Uri -match 'Releases_GetReleases') {
          return , @([PSCustomObject]@{ Release_Id = 999; Release_Name = 'TestRelease' })
        }
        throw "Unexpected URI: $Uri"
      }

      $result = Remove-BuildMasterRelease `
        -Application 'MyApp' `
        -ReleaseNumber 'TestRelease' `
        -WhatIf

      $result.Succeeded | Should -BeFalse
      $result.Action | Should -Be 'WhatIf'
      $result.ResponseSummary | Should -Match 'WhatIf.*planned cancel'
      $script:capturedUris | Where-Object { $_ -match 'Releases_CancelRelease|Releases_PurgeReleaseData' } | Should -HaveCount 0
    }

    It 'WhatIf for purge shows "planned purge"' {
      Mock Invoke-RestMethod -MockWith {
        if ($Uri -match 'Applications_GetApplications') {
          return , @([PSCustomObject]@{ Application_Id = 42; Application_Name = 'MyApp' })
        }
        if ($Uri -match 'Releases_GetReleases') {
          return , @([PSCustomObject]@{ Release_Id = 999; Release_Name = 'TestRelease' })
        }
        throw "Unexpected URI: $Uri"
      }

      $result = Remove-BuildMasterRelease `
        -Application 'MyApp' `
        -ReleaseNumber 'TestRelease' `
        -Purge `
        -WhatIf

      $result.Action | Should -Be 'WhatIf'
      $result.ResponseSummary | Should -Match 'WhatIf.*planned purge'
    }
  }

  Context 'Config resolution' {
    It 'Uses -ApiKey parameter when supplied (overrides $global:settings)' {
      $script:capturedHeaders = $null
      Mock Invoke-RestMethod -MockWith {
        $script:capturedHeaders = $Headers
        if ($Uri -match 'Applications_GetApplications') {
          return , @([PSCustomObject]@{ Application_Id = 42; Application_Name = 'A' })
        }
        if ($Uri -match 'Releases_GetReleases') {
          return , @([PSCustomObject]@{ Release_Id = 1; Release_Name = 'R' })
        }
        if ($Uri -match 'Releases_CancelRelease') {
          return [PSCustomObject]@{ success = $true }
        }
        throw "Unexpected URI: $Uri"
      }

      Remove-BuildMasterRelease -Application 'A' -ReleaseNumber 'R' -ApiKey 'explicit-key' -Confirm:$false | Out-Null
      $script:capturedHeaders['X-ApiKey'] | Should -Be 'explicit-key'
    }

    It 'Throws when neither setting nor env var nor parameter provides an API key' {
      $global:settings = @{ BuildMasterBaseUrl = 'https://x.example' }
      [Environment]::SetEnvironmentVariable('BUILDMASTER_ADMIN_API_KEY', $null, 'Process')
      [Environment]::SetEnvironmentVariable('BUILDMASTER_ADMIN_API_KEY', $null, 'User')
      { Remove-BuildMasterRelease -Application 'A' -ReleaseNumber '1.0.0' -Confirm:$false } |
        Should -Throw -ExpectedMessage '*BUILDMASTER_ADMIN_API_KEY*'
    }

    It 'Throws when no base URL is configured' {
      $global:settings = @{ BuildMasterAdminApiKey = 'k' }
      [Environment]::SetEnvironmentVariable('BUILDMASTER_BASE_URL', $null, 'Process')
      [Environment]::SetEnvironmentVariable('BUILDMASTER_BASE_URL', $null, 'User')
      { Remove-BuildMasterRelease -Application 'A' -ReleaseNumber '1.0.0' -Confirm:$false } |
        Should -Throw -ExpectedMessage '*base URL*'
    }
  }

  Context 'Auth failure' {
    It 'Throws on HTTP 401' {
      Mock Invoke-RestMethod -MockWith {
        $resp = [PSCustomObject]@{ StatusCode = 401 }
        $ex = [System.Net.WebException]::new('Unauthorized')
        $errRec = [System.Management.Automation.ErrorRecord]::new($ex, 'BMUnauthorized', 'AuthenticationError', $null)
        $errRec.Exception | Add-Member -NotePropertyName 'Response' -NotePropertyValue $resp -Force
        throw $errRec
      }
      { Remove-BuildMasterRelease -Application 'A' -ReleaseNumber '1.0.0' -Confirm:$false } |
        Should -Throw
    }
  }

  Context 'Request body validation' {
    It 'Purge request body contains Release_Id' {
      $script:capturedBody = $null
      Mock Invoke-RestMethod -MockWith {
        if ($Uri -match 'Applications_GetApplications') {
          return , @([PSCustomObject]@{ Application_Id = 42; Application_Name = 'MyApp' })
        }
        if ($Uri -match 'Releases_GetReleases') {
          return , @([PSCustomObject]@{ Release_Id = 1234; Release_Name = 'R' })
        }
        if ($Uri -match 'Releases_PurgeReleaseData') {
          $script:capturedBody = $Body
          return [PSCustomObject]@{ success = $true }
        }
        throw "Unexpected URI: $Uri"
      }

      Remove-BuildMasterRelease -Application 'MyApp' -ReleaseNumber 'R' -Purge -Confirm:$false | Out-Null
      $parsed = $script:capturedBody | ConvertFrom-Json
      $parsed.Release_Id | Should -Be 1234
    }

    It 'Cancel request body contains Release_Id' {
      $script:capturedBody = $null
      Mock Invoke-RestMethod -MockWith {
        if ($Uri -match 'Applications_GetApplications') {
          return , @([PSCustomObject]@{ Application_Id = 42; Application_Name = 'MyApp' })
        }
        if ($Uri -match 'Releases_GetReleases') {
          return , @([PSCustomObject]@{ Release_Id = 5678; Release_Name = 'R' })
        }
        if ($Uri -match 'Releases_CancelRelease') {
          $script:capturedBody = $Body
          return [PSCustomObject]@{ success = $true }
        }
        throw "Unexpected URI: $Uri"
      }

      Remove-BuildMasterRelease -Application 'MyApp' -ReleaseNumber 'R' -Confirm:$false | Out-Null
      $parsed = $script:capturedBody | ConvertFrom-Json
      $parsed.Release_Id | Should -Be 5678
    }
  }
}
