#Requires -Version 7.0

BeforeAll {
  $publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
  . (Join-Path $publicDir 'New-BuildMasterApplication.ps1')
  . (Join-Path $publicDir 'Set-BuildMasterApplicationVariables.ps1')
  . (Join-Path $publicDir 'Set-BuildMasterSprintVariables.ps1')
  . (Join-Path $publicDir 'Set-BuildMasterStableVariables.ps1')
  . (Join-Path $publicDir 'New-BuildMasterScript.ps1')
  . (Join-Path $publicDir 'Remove-BuildMasterScript.ps1')
  . (Join-Path $publicDir 'Remove-BuildMasterApplicationVariable.ps1')
  . (Join-Path $publicDir 'Remove-BuildMasterApplication.ps1')

  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
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

Describe 'BuildMaster configuration API functions' -Tag 'Unit' {
  BeforeEach {
    $global:configRootKeys = @{
      BuildMasterBaseUrlConfigRootKey     = 'BuildMasterBaseUrl'
      BuildMasterAdminApiKeyConfigRootKey = 'BuildMasterAdminApiKey'
    }
    $global:settings = @{
      BuildMasterBaseUrl     = 'https://buildmaster.example.test'
      BuildMasterAdminApiKey = 'unit-test-key'
    }
    $script:restCalls = [System.Collections.ArrayList]::new()
  }

  It 'creates a BuildMaster application with the default raft' {
    Mock Invoke-RestMethod -MockWith {
      param($Uri, $Method, $Headers, $ContentType, $Body)

      [void]$script:restCalls.Add([PSCustomObject]@{
        Uri         = $Uri
        Method      = $Method
        Headers     = $Headers
        ContentType = $ContentType
        Body        = $Body
      })

      if ($Uri -like '*/api/applications/list') {
        return @()
      }
      if ($Uri -like '*/api/applications/create') {
        return [PSCustomObject]@{ id = 101; name = 'ATAP.Utilities-CSharp' }
      }

      throw "Unexpected REST call: $Method $Uri"
    }

    $result = New-BuildMasterApplication -Name 'ATAP.Utilities-CSharp' -Description 'ATAP package application.'

    $result.Action | Should -Be 'Created'
    $createCall = @($script:restCalls | Where-Object { $_.Uri -like '*/api/applications/create' })[0]
    $body = $createCall.Body | ConvertFrom-Json
    $body.name | Should -Be 'ATAP.Utilities-CSharp'
    $body.description | Should -Be 'ATAP package application.'
    $body.releaseUsage | Should -Be 'Required'
    $body.raft | Should -Be $null
    $createCall.Headers['X-ApiKey'] | Should -Be 'unit-test-key'
  }

  It 'sets simple and sensitive BuildMaster application variables idempotently' {
    Mock Invoke-RestMethod -MockWith {
      param($Uri, $Method, $Headers, $ContentType, $Body)

      [void]$script:restCalls.Add([PSCustomObject]@{
        Uri         = $Uri
        Method      = $Method
        Headers     = $Headers
        ContentType = $ContentType
        Body        = $Body
      })

      if ($Uri -like '*/api/variables/application/ATAP.Utilities/Branch' -and $Method -eq 'Get') {
        return 'main'
      }
      if ($Uri -like '*/api/variables/application/ATAP.Utilities/Configuration' -and $Method -eq 'Get') {
        return 'Debug'
      }
      if ($Uri -like '*/api/variables/application/ATAP.Utilities/Configuration' -and $Method -eq 'Post') {
        return @{}
      }
      if ($Uri -like '*/api/variables/scoped/single' -and $Method -eq 'Post') {
        return @{}
      }

      throw "Unexpected REST call: $Method $Uri"
    }

    $result = Set-BuildMasterApplicationVariables -ApplicationName 'ATAP.Utilities' -Variables @{
      Branch        = 'main'
      Configuration = 'Release'
      ProGetApiKey  = @{ Value = 'secret-value'; Sensitive = $true }
    }

    $result.Succeeded | Should -BeTrue
    $result.Unchanged | Should -Contain 'ATAP.Utilities/Branch'
    $result.Changed | Should -Contain 'ATAP.Utilities/Configuration'
    $result.Changed | Should -Contain 'ATAP.Utilities/ProGetApiKey'

    $simplePost = @($script:restCalls | Where-Object { $_.Uri -like '*/api/variables/application/ATAP.Utilities/Configuration' -and $_.Method -eq 'Post' })[0]
    $simplePost.ContentType | Should -Be 'text/plain'
    $simplePost.Body | Should -Be 'Release'

    $scopedPost = @($script:restCalls | Where-Object { $_.Uri -like '*/api/variables/scoped/single' })[0]
    $scopedBody = $scopedPost.Body | ConvertFrom-Json
    $scopedBody.name | Should -Be 'ProGetApiKey'
    $scopedBody.application | Should -Be 'ATAP.Utilities'
    $scopedBody.sensitive | Should -BeTrue
  }

  It 'creates or updates a BuildMaster script in the default raft' {
    Mock Invoke-RestMethod -MockWith {
      param($Uri, $Method, $Headers, $ContentType, $Body)

      [void]$script:restCalls.Add([PSCustomObject]@{
        Uri         = $Uri
        Method      = $Method
        Headers     = $Headers
        ContentType = $ContentType
        Body        = $Body
      })

      if ($Uri -like '*/Rafts_GetRaftItems') {
        return @()
      }
      if ($Uri -like '*/Rafts_CreateOrUpdateRaftItem') {
        return [PSCustomObject]@{ RaftItem_Id = 77 }
      }

      throw "Unexpected REST call: $Method $Uri"
    }

    $result = New-BuildMasterScript -ScriptName 'Build.otter' -ScriptContent 'Log-Information hello;'

    $result.Action | Should -Be 'Created'
    $uploadCall = @($script:restCalls | Where-Object { $_.Uri -like '*/Rafts_CreateOrUpdateRaftItem' })[0]
    $uploadCall.Body.API_Key | Should -Be 'unit-test-key'
    $uploadCall.Body.Raft_Id | Should -Be 1
    $uploadCall.Body.RaftItemType_Code | Should -Be 6
    $uploadCall.Body.RaftItem_Name | Should -Be 'Build.otter'
    [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($uploadCall.Body.Content_Bytes)) | Should -Be 'Log-Information hello;'
  }

  It 'removes a BuildMaster script from the default raft' {
    Mock Invoke-RestMethod -MockWith {
      param($Uri, $Method, $Headers, $ContentType, $Body)

      [void]$script:restCalls.Add([PSCustomObject]@{
        Uri         = $Uri
        Method      = $Method
        Headers     = $Headers
        ContentType = $ContentType
        Body        = $Body
      })

      if ($Uri -like '*/Rafts_GetRaftItems') {
        return @([PSCustomObject]@{ RaftItem_Id = 88; RaftItem_Name = 'Build.otter' })
      }
      if ($Uri -like '*/Rafts_DeleteRaftItem') {
        return @{}
      }

      throw "Unexpected REST call: $Method $Uri"
    }

    $result = Remove-BuildMasterScript -ScriptName 'Build.otter' -Confirm:$false

    $result.Action | Should -Be 'Removed'
    $deleteCall = @($script:restCalls | Where-Object { $_.Uri -like '*/Rafts_DeleteRaftItem' })[0]
    $deleteCall.Body.RaftItem_Id | Should -Be 88
    $deleteCall.Body.PurgeHistory_Indicator | Should -Be 'N'
  }

  It 'removes BuildMaster application variables through the entity endpoint' {
    Mock Invoke-RestMethod -MockWith {
      param($Uri, $Method, $Headers, $ContentType, $Body)

      [void]$script:restCalls.Add([PSCustomObject]@{
        Uri         = $Uri
        Method      = $Method
        Headers     = $Headers
        ContentType = $ContentType
        Body        = $Body
      })

      if ($Uri -like '*/api/variables/application/ATAP.Utilities/Configuration' -and $Method -eq 'Delete') {
        return @{}
      }

      throw "Unexpected REST call: $Method $Uri"
    }

    $result = Remove-BuildMasterApplicationVariable -ApplicationName 'ATAP.Utilities' -VariableName 'Configuration'

    $result.Succeeded | Should -BeTrue
    $result.Removed | Should -Contain 'ATAP.Utilities/Configuration'
    $deleteCall = @($script:restCalls | Where-Object { $_.Method -eq 'Delete' })[0]
    $deleteCall.Headers['X-ApiKey'] | Should -Be 'unit-test-key'
  }

  It 'purges BuildMaster applications through the Application Management API' {
    Mock Invoke-RestMethod -MockWith {
      param($Uri, $Method, $Headers, $ContentType, $Body)

      [void]$script:restCalls.Add([PSCustomObject]@{
        Uri         = $Uri
        Method      = $Method
        Headers     = $Headers
        ContentType = $ContentType
        Body        = $Body
      })

      if ($Uri -like '*/api/applications/list') {
        return @([PSCustomObject]@{ id = 303; name = 'Old-App' })
      }
      if ($Uri -like '*/api/applications/purge*') {
        return @{}
      }

      throw "Unexpected REST call: $Method $Uri"
    }

    $result = Remove-BuildMasterApplication -Name 'Old-App' -Confirm:$false

    $result.Action | Should -Be 'Purged'
    $purgeCall = @($script:restCalls | Where-Object { $_.Uri -like '*/api/applications/purge*' })[0]
    $purgeCall.Uri | Should -Be 'https://buildmaster.example.test/api/applications/purge?application=Old-App'
    $purgeCall.Method | Should -Be 'Post'
  }
}

Describe 'Set-BuildMasterApplicationVariables' -Tag 'Unit' {
  BeforeEach {
    $global:configRootKeys = @{
      BuildMasterBaseUrlConfigRootKey     = 'BuildMasterBaseUrl'
      BuildMasterAdminApiKeyConfigRootKey = 'BuildMasterAdminApiKey'
    }
    $global:settings = @{
      BuildMasterBaseUrl     = 'https://buildmaster.example.test'
      BuildMasterAdminApiKey = 'unit-test-key'
    }
    $script:restCalls = [System.Collections.ArrayList]::new()
  }

  It 'sets a simple variable via the single-variable endpoint' {
    Mock Invoke-RestMethod -MockWith {
      param($Uri, $Method, $Headers, $ContentType, $Body)

      [void]$script:restCalls.Add([PSCustomObject]@{
        Uri         = $Uri
        Method      = $Method
        Headers     = $Headers
        ContentType = $ContentType
        Body        = $Body
      })

      # GET returns 404 (variable does not exist yet)
      if ($Uri -like '*/api/variables/application/TestApp/Branch' -and $Method -eq 'Get') {
        throw [System.Net.WebException]::new('404 not found')
      }
      # POST succeeds
      if ($Uri -like '*/api/variables/application/TestApp/Branch' -and $Method -eq 'Post') {
        return @{}
      }

      throw "Unexpected REST call: $Method $Uri"
    }

    $result = Set-BuildMasterApplicationVariables `
      -ApplicationName 'TestApp' `
      -Variables @{ Branch = 'test-branch' }

    $result.Succeeded | Should -BeTrue
    $result.Changed | Should -Contain 'TestApp/Branch'

    $postCall = @($script:restCalls | Where-Object { $_.Method -eq 'Post' -and $_.Uri -like '*/api/variables/application/TestApp/Branch' })[0]
    $postCall | Should -Not -BeNullOrEmpty
    $postCall.Body | Should -Be 'test-branch'
    $postCall.ContentType | Should -Be 'text/plain'
  }

  It 'skips a simple variable that already matches' {
    Mock Invoke-RestMethod -MockWith {
      param($Uri, $Method, $Headers, $ContentType, $Body)

      [void]$script:restCalls.Add([PSCustomObject]@{
        Uri         = $Uri
        Method      = $Method
        Headers     = $Headers
        ContentType = $ContentType
        Body        = $Body
      })

      # GET returns the current matching value
      if ($Uri -like '*/api/variables/application/TestApp/Branch' -and $Method -eq 'Get') {
        return 'existing-branch'
      }

      throw "Unexpected REST call: $Method $Uri"
    }

    $result = Set-BuildMasterApplicationVariables `
      -ApplicationName 'TestApp' `
      -Variables @{ Branch = 'existing-branch' }

    $result.Succeeded | Should -BeTrue
    $result.Unchanged | Should -Contain 'TestApp/Branch'
    $result.Changed | Should -BeNullOrEmpty

    # No POST call should have been made
    $postCalls = @($script:restCalls | Where-Object { $_.Method -eq 'Post' })
    $postCalls.Count | Should -Be 0
  }

  It 'sets a sensitive variable via the scoped endpoint without using the plain-value endpoint' {
    Mock Invoke-RestMethod -MockWith {
      param($Uri, $Method, $Headers, $ContentType, $Body)

      [void]$script:restCalls.Add([PSCustomObject]@{
        Uri         = $Uri
        Method      = $Method
        Headers     = $Headers
        ContentType = $ContentType
        Body        = $Body
      })

      # Only the scoped endpoint should be called
      if ($Uri -like '*/api/variables/scoped/single' -and $Method -eq 'Post') {
        return @{}
      }

      throw "Unexpected REST call: $Method $Uri"
    }

    $result = Set-BuildMasterApplicationVariables `
      -ApplicationName 'TestApp' `
      -Variables @{ ProGetApiKey = @{ Value = 'secret-sentinel'; Sensitive = $true } }

    $result.Succeeded | Should -BeTrue
    $result.Changed | Should -Contain 'TestApp/ProGetApiKey'

    # The scoped endpoint must have been called
    $scopedCall = @($script:restCalls | Where-Object { $_.Uri -like '*/api/variables/scoped/single' })[0]
    $scopedCall | Should -Not -BeNullOrEmpty

    # Verify JSON body carries sensitive=true and the correct variable name
    $scopedBody = $scopedCall.Body | ConvertFrom-Json
    $scopedBody.name | Should -Be 'ProGetApiKey'
    $scopedBody.application | Should -Be 'TestApp'
    $scopedBody.sensitive | Should -BeTrue

    # The single-variable (entity) endpoint must NOT have been called — sensitive
    # values never travel through the plain GET+POST path
    $singleCalls = @($script:restCalls | Where-Object { $_.Uri -like '*/api/variables/application/*' })
    $singleCalls.Count | Should -Be 0
  }

  It 'throws an informative error when the API key is not resolvable' {
    # Ensure all resolution paths are empty
    $global:configRootKeys = $null
    $global:settings = $null
    [Environment]::SetEnvironmentVariable('BUILDMASTER_ADMIN_API_KEY', $null, 'Process')
    [Environment]::SetEnvironmentVariable('BUILDMASTER_ADMIN_API_KEY', $null, 'User')

    { Set-BuildMasterApplicationVariables `
        -ApplicationName 'TestApp' `
        -Variables @{ Branch = 'any' } `
    } | Should -Throw -ExpectedMessage '*BUILDMASTER_ADMIN_API_KEY*'
  }
}

Describe 'Deprecated BuildMaster variable cmdlets emit deprecation warnings' -Tag 'Unit' {
  BeforeEach {
    $global:configRootKeys = @{
      BuildMasterBaseUrlConfigRootKey     = 'BuildMasterBaseUrl'
      BuildMasterAdminApiKeyConfigRootKey = 'BuildMasterAdminApiKey'
    }
    $global:settings = @{
      BuildMasterBaseUrl     = 'https://buildmaster.example.test'
      BuildMasterAdminApiKey = 'unit-test-key'
    }
    $script:deprecationMessages = [System.Collections.ArrayList]::new()
    # Capture Write-PSFMessage calls so we can assert on level and message without
    # needing a live PSFramework installation.
    function global:Write-PSFMessage {
      param(
        [string]$FunctionName,
        [string]$ModuleName,
        [string]$Level,
        [string]$Message,
        [string[]]$Tag
      )
      [void]$script:deprecationMessages.Add([PSCustomObject]@{
        Level   = $Level
        Message = $Message
      })
    }
    # Stub helpers that the deprecated cmdlets call so they do not fail due to
    # missing modules or environment variables before the deprecation warning fires.
    function global:Get-PVal { param([string]$ParameterName, $originalPSBoundParameters, $DefaultValue) return 'https://buildmaster.example.test' }
    function global:Resolve-BuildToolingSettingValue { param([string]$Name) return 'stub' }
    function global:Resolve-ProGetFeedFromSettings {
      param([string]$FeedType, [string]$Tier)
      return [PSCustomObject]@{ FeedName = 'stub-feed'; EndpointUri = 'https://proget.example.test/nuget/stub' }
    }
    # Stub Get-ParameterValueFromNeoConfigurationRoot so the helper-load block
    # in the deprecated cmdlets does not try to dot-source a real file path.
    function global:Get-ParameterValueFromNeoConfigurationRoot { param([Parameter(ValueFromRemainingArguments=$true)]$Rest) }
    [Environment]::SetEnvironmentVariable('BUILDMASTER_ADMIN_API_KEY', 'unit-test-key', 'Process')
  }

  AfterEach {
    [Environment]::SetEnvironmentVariable('BUILDMASTER_ADMIN_API_KEY', $null, 'Process')
    Remove-Item -Path 'Function:\Get-PVal' -ErrorAction SilentlyContinue
    Remove-Item -Path 'Function:\Resolve-BuildToolingSettingValue' -ErrorAction SilentlyContinue
    Remove-Item -Path 'Function:\Resolve-ProGetFeedFromSettings' -ErrorAction SilentlyContinue
    Remove-Item -Path 'Function:\Get-ParameterValueFromNeoConfigurationRoot' -ErrorAction SilentlyContinue
    Remove-Item -Path 'Function:\Write-PSFMessage' -ErrorAction SilentlyContinue
  }

  It 'Set-BuildMasterSprintVariables emits an Important-level deprecation warning' {
    Mock Invoke-RestMethod { return @{} }

    Set-BuildMasterSprintVariables -SprintNumber '0007' -WhatIf

    $deprecationWarning = $script:deprecationMessages |
      Where-Object { $_.Level -eq 'Important' -and $_.Message -like '*DEPRECATED*Set-BuildMasterApplicationVariables*' } |
      Select-Object -First 1

    $deprecationWarning | Should -Not -BeNullOrEmpty
    $deprecationWarning.Message | Should -BeLike '*Sprint 0008*'
  }

  It 'Set-BuildMasterStableVariables emits an Important-level deprecation warning' {
    Mock Invoke-RestMethod { return @{} }

    Set-BuildMasterStableVariables -WhatIf

    $deprecationWarning = $script:deprecationMessages |
      Where-Object { $_.Level -eq 'Important' -and $_.Message -like '*DEPRECATED*Set-BuildMasterApplicationVariables*' } |
      Select-Object -First 1

    $deprecationWarning | Should -Not -BeNullOrEmpty
    $deprecationWarning.Message | Should -BeLike '*Sprint 0008*'
  }
}
