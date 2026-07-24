BeforeAll {
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
  }

  function global:Invoke-RestMethod {
    param(
      [string]$Uri,
      [string]$Method,
      [hashtable]$Body,
      [object]$Headers,
      [object]$ErrorAction
    )

    & $script:invokeRestMethodHandler -Uri $Uri -Method $Method -Body $Body
  }

  function global:Get-SecretATAP { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) 'test-key' }

  . "$PSScriptRoot\..\..\public\Sync-BuildMasterPlans.ps1"
}

AfterAll {
  Remove-Item -Path 'Function:\Invoke-RestMethod' -Force -ErrorAction SilentlyContinue
}

Describe 'Sync-BuildMasterPlans [public]' {
  BeforeEach {
    $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "bm_plans_$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $script:tempDir -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $script:tempDir 'nested') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $script:tempDir 'Build.otter') -Value 'Log-Information hello;' -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $script:tempDir 'nested\Deploy.otter') -Value 'Log-Information deploy;' -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $script:tempDir 'ignore.txt') -Value 'ignore' -Encoding UTF8

    $script:restCalls = [System.Collections.ArrayList]::new()
    $script:invokeRestMethodHandler = {
      param($Uri, $Method, $Body)

      [void]$script:restCalls.Add([PSCustomObject]@{
        Uri    = $Uri
        Method = $Method
        Body   = $Body
      })

      if ($Uri -like '*/Applications_GetApplications') {
        return @(
          [PSCustomObject]@{ Application_Id = 42; Application_Name = 'ATAP.Utilities' }
        )
      }

      if ($Uri -like '*/Rafts_GetRaftItems') {
        return @()
      }

      return @{}
    }
  }

  AfterEach {
    Remove-Item -LiteralPath $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    $global:configRootKeys = $null
    $global:settings = $null
  }

  It 'uploads .otter files to the BuildMaster raft API' {
    $result = Sync-BuildMasterPlans -Path $script:tempDir -BuildMasterAdminApiKeySecretName 'test-key' -BuildMasterBaseUrl 'http://buildmaster.test' -SkipExistingLookup

    $uploadCalls = @($script:restCalls | Where-Object { $_.Uri -like '*/Rafts_CreateOrUpdateRaftItem' })
    $uploadCalls.Count | Should -Be 1
    $uploadCalls[0].Body.API_Key | Should -Be 'test-key'
    $uploadCalls[0].Body.Raft_Id | Should -Be 1
    $uploadCalls[0].Body.RaftItemType_Code | Should -Be 6
    $uploadCalls[0].Body.RaftItem_Name | Should -Be 'Build.otter'
    [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($uploadCalls[0].Body.Content_Bytes)) | Should -Match 'Log-Information hello'
    $result.PlansSynced.Name | Should -Contain 'Build.otter'
    $result.Errors.Count | Should -Be 0
  }

  It 'preserves relative paths and resolves application names when requested' {
    $result = Sync-BuildMasterPlans -Path $script:tempDir -Recurse -PreserveDirectoryStructure -ApplicationName 'ATAP.Utilities' -BuildMasterAdminApiKeySecretName 'test-key' -BuildMasterBaseUrl 'http://buildmaster.test' -SkipExistingLookup

    $uploadCalls = @($script:restCalls | Where-Object { $_.Uri -like '*/Rafts_CreateOrUpdateRaftItem' })
    $uploadCalls.Count | Should -Be 2
    $uploadCalls.Body.RaftItem_Name | Should -Contain 'Build.otter'
    $uploadCalls.Body.RaftItem_Name | Should -Contain 'nested/Deploy.otter'
    $uploadCalls[0].Body.Application_Id | Should -Be 42
    $result.PlansSynced.ApplicationId | Select-Object -Unique | Should -Be 42
  }

  It 'adds an existing raft item id when the plan already exists' {
    $script:invokeRestMethodHandler = {
      param($Uri, $Method, $Body)

      [void]$script:restCalls.Add([PSCustomObject]@{
        Uri    = $Uri
        Method = $Method
        Body   = $Body
      })

      if ($Uri -like '*/Rafts_GetRaftItems') {
        return @([PSCustomObject]@{ RaftItem_Id = 99; RaftItem_Name = 'Build.otter' })
      }

      return @{}
    }

    Sync-BuildMasterPlans -Path (Join-Path $script:tempDir 'Build.otter') -BuildMasterAdminApiKeySecretName 'test-key' -BuildMasterBaseUrl 'http://buildmaster.test' | Out-Null

    $uploadCall = @($script:restCalls | Where-Object { $_.Uri -like '*/Rafts_CreateOrUpdateRaftItem' })[0]
    $uploadCall.Body.RaftItem_Id | Should -Be 99
  }

  It 'does not upload when WhatIf is used' {
    Sync-BuildMasterPlans -Path $script:tempDir -BuildMasterAdminApiKeySecretName 'test-key' -BuildMasterBaseUrl 'http://buildmaster.test' -SkipExistingLookup -WhatIf | Out-Null

    @($script:restCalls | Where-Object { $_.Uri -like '*/Rafts_CreateOrUpdateRaftItem' }).Count | Should -Be 0
  }

  It 'uses global settings for the default plans path and BuildMaster URL' {
    $global:configRootKeys = @{
      BuildMasterPlansDirectoryConfigRootKey = 'BuildMaster.PlansDirectory'
      BuildMasterBaseUrlConfigRootKey        = 'BuildMaster.BaseUrl'
    }
    $global:settings = @{
      'BuildMaster.PlansDirectory' = $script:tempDir
      'BuildMaster.BaseUrl'        = 'http://buildmaster.settings'
    }

    Sync-BuildMasterPlans -BuildMasterAdminApiKeySecretName 'test-key' -SkipExistingLookup | Out-Null

    $uploadCall = @($script:restCalls | Where-Object { $_.Uri -like '*/Rafts_CreateOrUpdateRaftItem' })[0]
    $uploadCall.Uri | Should -Be 'http://buildmaster.settings/api/json/Rafts_CreateOrUpdateRaftItem'
  }

  It 'throws a clear error when no .otter files are found' {
    $emptyDir = Join-Path $script:tempDir 'empty'
    New-Item -ItemType Directory -Path $emptyDir -Force | Out-Null

    { Sync-BuildMasterPlans -Path $emptyDir -BuildMasterAdminApiKeySecretName 'test-key' -BuildMasterBaseUrl 'http://buildmaster.test' } | Should -Throw -ExpectedMessage '*No .otter files found*'
  }
}
