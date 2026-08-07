#Requires -Version 7.0
# Pester 5+ tests for Remove-BuildMasterRelease (Stream E, task E04b).
# Mocks Invoke-RestMethod; no real network or BuildMaster contact.

BeforeAll {
  $publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
  . (Join-Path $publicDir 'Remove-BuildMasterRelease.ps1')

  # Provide a deterministic resolver within this Pester container so aggregate
  # test runs cannot alter the host's production resolver or alias.
  function Get-ParameterValueFromNeoConfigurationRoot {
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
  Set-Alias -Name Get-PVal -Value Get-ParameterValueFromNeoConfigurationRoot -Scope Script -Force

  # Suppress PSFramework noise in tests.
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
  }

  # Stub the secret store so the cmdlet resolves the BuildMaster admin API key
  # without contacting Bitwarden.
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

Describe 'Remove-BuildMasterRelease' -Tag 'Unit', 'PromotedModuleHostSensitive' {

  BeforeEach {
    $global:configRootKeys = @{
      # SC-0288 / Task 13.66.b: SecretName host suffixes come from the placement map.
      ServicePlacementMapConfigRootKey    = 'ServicePlacementMap'
      BuildMasterBaseUrlConfigRootKey     = 'BuildMasterBaseUrl'
      BuildMasterAdminApiKeyConfigRootKey = 'BuildMasterAdminApiKey'
    }
    $global:settings = @{
      ServicePlacementMap    = @{ BuildMaster = 'utat022'; ProGet = 'utat022' }
      BuildMasterBaseUrl     = 'https://buildmaster.example.test'
      BuildMasterAdminApiKey = 'unit-test-key'
    }
  }

  Context 'Happy path: cancel release (default action)' {
    It 'Selects by Release_Number when Release_Name differs and calls cancel' {
      $script:capturedUris = @()
      Mock Invoke-RestMethod -MockWith {
        $script:capturedUris += $Uri
        if ($Uri -match 'Applications_GetApplications') {
          return , @([PSCustomObject]@{ Application_Id = 42; Application_Name = 'ATAP.Utilities-PowerShell' })
        }
        if ($Uri -match 'Releases_GetReleases') {
          return , @([PSCustomObject]@{ Release_Id = 1004; Release_Number = '0.0.0'; Release_Name = 'ATAP.Utilities-PowerShell 0.0.0' })
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

  Context 'Expected release ID safety binding' {
    It 'Allows mutation when ExpectedReleaseId matches the selected Release_Id' {
      $script:capturedUris = @()
      Mock Invoke-RestMethod -MockWith {
        $script:capturedUris += $Uri
        if ($Uri -match 'Applications_GetApplications') {
          return , @([PSCustomObject]@{ Application_Id = 42; Application_Name = 'MyApp' })
        }
        if ($Uri -match 'Releases_GetReleases') {
          return , @([PSCustomObject]@{ Release_Id = 9086; Release_Number = '0.1.3'; Release_Name = 'ATAPUtilities.Database 0.1.3' })
        }
        if ($Uri -match 'Releases_PurgeReleaseData') {
          return [PSCustomObject]@{ success = $true }
        }
        throw "Unexpected URI: $Uri"
      }

      $result = Remove-BuildMasterRelease `
        -Application 'MyApp' `
        -ReleaseNumber '0.1.3' `
        -ExpectedReleaseId 9086 `
        -Purge `
        -Confirm:$false

      $result.Action | Should -Be 'Purged'
      $result.ReleaseId | Should -Be 9086
      $script:capturedUris | Where-Object { $_ -match 'Releases_PurgeReleaseData' } | Should -HaveCount 1
    }

    It 'Throws before ShouldProcess or mutation when ExpectedReleaseId differs' {
      $script:capturedUris = @()
      Mock Invoke-RestMethod -MockWith {
        $script:capturedUris += $Uri
        if ($Uri -match 'Applications_GetApplications') {
          return , @([PSCustomObject]@{ Application_Id = 42; Application_Name = 'MyApp' })
        }
        if ($Uri -match 'Releases_GetReleases') {
          return , @([PSCustomObject]@{ Release_Id = 9087; Release_Number = '0.1.4'; Release_Name = 'ATAPUtilities.Database 0.1.4' })
        }
        throw "Unexpected URI: $Uri"
      }

      { Remove-BuildMasterRelease `
          -Application 'MyApp' `
          -ReleaseNumber '0.1.4' `
          -ExpectedReleaseId 9086 `
          -Purge `
          -WhatIf } |
        Should -Throw -ExpectedMessage '*Release ID drift*Release_Id=9087*ExpectedReleaseId=9086*'

      $script:capturedUris | Where-Object { $_ -match 'Releases_CancelRelease|Releases_PurgeReleaseData' } | Should -HaveCount 0
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
          return , @([PSCustomObject]@{ Release_Id = 1006; Release_Number = 'Placeholder'; Release_Name = 'Descriptive placeholder release' })
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
    It 'Throws when multiple releases have the same Release_Number' {
      Mock Invoke-RestMethod -MockWith {
        if ($Uri -match 'Applications_GetApplications') {
          return , @([PSCustomObject]@{ Application_Id = 42; Application_Name = 'MyApp' })
        }
        if ($Uri -match 'Releases_GetReleases') {
          return , @(
            [PSCustomObject]@{ Release_Id = 100; Release_Number = 'Duplicate'; Release_Name = 'First display name' },
            [PSCustomObject]@{ Release_Id = 101; Release_Number = 'Duplicate'; Release_Name = 'Second display name' }
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
    It 'Does not match Release_Name when Release_Number differs' {
      $script:capturedUris = @()
      Mock Invoke-RestMethod -MockWith {
        $script:capturedUris += $Uri
        if ($Uri -match 'Applications_GetApplications') {
          return , @([PSCustomObject]@{ Application_Id = 42; Application_Name = 'MyApp' })
        }
        if ($Uri -match 'Releases_GetReleases') {
          return , @([PSCustomObject]@{ Release_Id = 700; Release_Number = '7.0.0'; Release_Name = 'RequestedLabel' })
        }
        throw "Unexpected URI: $Uri"
      }

      $result = Remove-BuildMasterRelease `
        -Application 'MyApp' `
        -ReleaseNumber 'RequestedLabel' `
        -Confirm:$false

      $result.Action | Should -Be 'Unchanged'
      $script:capturedUris | Where-Object { $_ -match 'Releases_CancelRelease|Releases_PurgeReleaseData' } | Should -HaveCount 0
    }

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

  Context 'Ambiguous application match (error path)' {
    It 'Throws before release lookup or mutation when exact Application_Name is duplicated' {
      $script:capturedUris = @()
      Mock Invoke-RestMethod -MockWith {
        $script:capturedUris += $Uri
        if ($Uri -match 'Applications_GetApplications') {
          return , @(
            [PSCustomObject]@{ Application_Id = 42; Application_Name = 'DuplicateApp' },
            [PSCustomObject]@{ Application_Id = 43; Application_Name = 'DuplicateApp' }
          )
        }
        throw "Unexpected URI: $Uri"
      }

      { Remove-BuildMasterRelease `
          -Application 'DuplicateApp' `
          -ReleaseNumber '1.0.0' `
          -Confirm:$false } |
        Should -Throw -ExpectedMessage '*Ambiguous application match*Application_Name=''DuplicateApp''*'

      $script:capturedUris | Where-Object { $_ -match 'Releases_GetReleases|Releases_CancelRelease|Releases_PurgeReleaseData' } | Should -HaveCount 0
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
          return , @([PSCustomObject]@{ Release_Id = 999; Release_Number = 'TestRelease'; Release_Name = 'MyApp TestRelease' })
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
          return , @([PSCustomObject]@{ Release_Id = 999; Release_Number = 'TestRelease'; Release_Name = 'MyApp TestRelease' })
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
    It 'Resolves the API key value via Get-SecretATAP for the X-ApiKey header' {
      $script:capturedHeaders = $null
      Mock Get-SecretATAP { 'explicit-key' }
      Mock Invoke-RestMethod -MockWith {
        $script:capturedHeaders = $Headers
        if ($Uri -match 'Applications_GetApplications') {
          return , @([PSCustomObject]@{ Application_Id = 42; Application_Name = 'A' })
        }
        if ($Uri -match 'Releases_GetReleases') {
          return , @([PSCustomObject]@{ Release_Id = 1; Release_Number = 'R'; Release_Name = 'A R' })
        }
        if ($Uri -match 'Releases_CancelRelease') {
          return [PSCustomObject]@{ success = $true }
        }
        throw "Unexpected URI: $Uri"
      }

      Remove-BuildMasterRelease -Application 'A' -ReleaseNumber 'R' -BuildMasterAdminApiKeySecretName 'BuildMaster.Admin.API.Key.utat01' -Confirm:$false | Out-Null
      $script:capturedHeaders['X-ApiKey'] | Should -Be 'explicit-key'
    }

    It 'Throws when the API key is not resolvable via Get-SecretATAP' {
      $global:settings = @{
        BuildMasterBaseUrl  = 'https://x.example'
        # SC-0288 / Task 13.66.b: placement must stay declared, or SecretName
        # resolution fails closed before Get-SecretATAP is ever reached.
        ServicePlacementMap = @{ BuildMaster = 'utat022'; ProGet = 'utat022' }
      }
      Mock Get-SecretATAP { throw 'secret store unavailable' }
      { Remove-BuildMasterRelease -Application 'A' -ReleaseNumber '1.0.0' -Confirm:$false } |
        Should -Throw -ExpectedMessage '*Get-SecretATAP*'
    }

    It 'Falls back to the local BuildMaster base URL when none is configured' {
      # All BuildMaster cmdlets share a documented https://utat022:50017
      # fallback when no base URL is supplied via parameter, settings, or env
      # var (mirrors Start-BuildMasterPipeline / Start-BuildMasterDeployment).
      $global:settings = @{
        BuildMasterAdminApiKey = 'k'
        # SC-0288 / Task 13.66.b: base-URL fallback is orthogonal to SecretName
        # placement, which must still be declared.
        ServicePlacementMap    = @{ BuildMaster = 'utat022'; ProGet = 'utat022' }
      }
      [Environment]::SetEnvironmentVariable('BUILDMASTER_BASE_URL', $null, 'Process')
      [Environment]::SetEnvironmentVariable('BUILDMASTER_BASE_URL', $null, 'User')
      $script:capturedUris = @()
      Mock Invoke-RestMethod -MockWith {
        $script:capturedUris += $Uri
        if ($Uri -match 'Applications_GetApplications') {
          return , @([PSCustomObject]@{ Application_Id = 42; Application_Name = 'A' })
        }
        if ($Uri -match 'Releases_GetReleases') {
          return , @([PSCustomObject]@{ Release_Id = 1004; Release_Number = '1.0.0'; Release_Name = 'A 1.0.0' })
        }
        return [PSCustomObject]@{ success = $true }
      }

      { Remove-BuildMasterRelease -Application 'A' -ReleaseNumber '1.0.0' -Confirm:$false } |
        Should -Not -Throw
      $script:capturedUris | Should -Not -BeNullOrEmpty
      $script:capturedUris[0] | Should -Match '^https://utat022:50017/'
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
          return , @([PSCustomObject]@{ Release_Id = 1234; Release_Number = 'R'; Release_Name = 'MyApp R' })
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
          return , @([PSCustomObject]@{ Release_Id = 5678; Release_Number = 'R'; Release_Name = 'MyApp R' })
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
