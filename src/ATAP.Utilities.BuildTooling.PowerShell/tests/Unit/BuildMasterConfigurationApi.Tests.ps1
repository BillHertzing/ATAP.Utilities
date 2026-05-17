#Requires -Version 7.0

BeforeAll {
  $publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
  . (Join-Path $publicDir 'New-BuildMasterApplication.ps1')
  . (Join-Path $publicDir 'Set-BuildMasterApplicationVariables.ps1')
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
