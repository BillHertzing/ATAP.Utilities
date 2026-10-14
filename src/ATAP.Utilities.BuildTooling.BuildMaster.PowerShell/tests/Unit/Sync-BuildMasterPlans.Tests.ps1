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

  Context 'pipeline raft items (Task 15.196.r / SC-0444)' {
    BeforeEach {
      $pipeline = @{
        Name        = 'Sample-5Stage'
        Description = 'test'
        Stages      = @(@{ Name = 'Experimental'; Targets = @(@{ ScriptId = 'global::Build.otter'; ServerNames = @('localhost') }) })
      } | ConvertTo-Json -Depth 10
      Set-Content -LiteralPath (Join-Path $script:tempDir 'Sample-5Stage.pipeline.json') -Value $pipeline -Encoding UTF8
    }

    It 'ignores pipeline files unless IncludePipelines is set' {
      Sync-BuildMasterPlans -Path $script:tempDir -BuildMasterAdminApiKeySecretName 'test-key' -BuildMasterBaseUrl 'http://buildmaster.test' -SkipExistingLookup | Out-Null

      $uploadCalls = @($script:restCalls | Where-Object { $_.Uri -like '*/Rafts_CreateOrUpdateRaftItem' })
      $uploadCalls.Body.RaftItem_Name | Should -Not -Contain 'Sample-5Stage'
      $uploadCalls.Body.RaftItemType_Code | Should -Not -Contain 8
    }

    It 'uploads a pipeline as a type-8 raft item named without extension' {
      $result = Sync-BuildMasterPlans -Path $script:tempDir -IncludePipelines -BuildMasterAdminApiKeySecretName 'test-key' -BuildMasterBaseUrl 'http://buildmaster.test' -SkipExistingLookup

      $pipelineCall = @($script:restCalls | Where-Object { $_.Uri -like '*/Rafts_CreateOrUpdateRaftItem' -and $_.Body.RaftItem_Name -eq 'Sample-5Stage' })
      $pipelineCall.Count | Should -Be 1
      $pipelineCall[0].Body.RaftItemType_Code | Should -Be 8
      $pipelineCall[0].Body.ContainsKey('Application_Id') | Should -BeFalse
      ([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($pipelineCall[0].Body.Content_Bytes)) | ConvertFrom-Json).Name | Should -Be 'Sample-5Stage'
      # The .otter beside it still goes up as type 6.
      $planCall = @($script:restCalls | Where-Object { $_.Uri -like '*/Rafts_CreateOrUpdateRaftItem' -and $_.Body.RaftItem_Name -eq 'Build.otter' })
      $planCall[0].Body.RaftItemType_Code | Should -Be 6
      ($result.PlansSynced | Where-Object Name -eq 'Sample-5Stage').RaftItemTypeCode | Should -Be 8
      $result.Errors.Count | Should -Be 0
    }

    It 'looks up the existing pipeline id with the pipeline type code' {
      $script:invokeRestMethodHandler = {
        param($Uri, $Method, $Body)
        [void]$script:restCalls.Add([PSCustomObject]@{ Uri = $Uri; Method = $Method; Body = $Body })
        if ($Uri -like '*/Rafts_GetRaftItems' -and $Body.RaftItemType_Code -eq 8) {
          return @([PSCustomObject]@{ RaftItem_Id = 15; RaftItem_Name = 'Sample-5Stage' })
        }
        if ($Uri -like '*/Rafts_GetRaftItems') { return @() }
        return @{}
      }

      Sync-BuildMasterPlans -Path (Join-Path $script:tempDir 'Sample-5Stage.pipeline.json') -IncludePipelines -BuildMasterAdminApiKeySecretName 'test-key' -BuildMasterBaseUrl 'http://buildmaster.test' | Out-Null

      $lookup = @($script:restCalls | Where-Object { $_.Uri -like '*/Rafts_GetRaftItems' })
      $lookup[0].Body.RaftItemType_Code | Should -Be 8
      $uploadCall = @($script:restCalls | Where-Object { $_.Uri -like '*/Rafts_CreateOrUpdateRaftItem' })[0]
      $uploadCall.Body.RaftItem_Id | Should -Be 15
    }

    It 'fails closed when the file name and the declared Name disagree' {
      Set-Content -LiteralPath (Join-Path $script:tempDir 'Other-5Stage.pipeline.json') -Value (@{ Name = 'Sample-5Stage'; Stages = @(@{ Name = 'x' }) } | ConvertTo-Json -Depth 5) -Encoding UTF8

      $result = Sync-BuildMasterPlans -Path $script:tempDir -IncludePipelines -BuildMasterAdminApiKeySecretName 'test-key' -BuildMasterBaseUrl 'http://buildmaster.test' -SkipExistingLookup

      $result.Errors | Should -Match "declares Name 'Sample-5Stage'"
      @($script:restCalls | Where-Object { $_.Uri -like '*/Rafts_CreateOrUpdateRaftItem' -and $_.Body.RaftItem_Name -eq 'Other-5Stage' }).Count | Should -Be 0
    }

    It 'fails closed on invalid JSON and on a pipeline with no stages' {
      Set-Content -LiteralPath (Join-Path $script:tempDir 'Broken-5Stage.pipeline.json') -Value '{ not json' -Encoding UTF8
      Set-Content -LiteralPath (Join-Path $script:tempDir 'Empty-5Stage.pipeline.json') -Value (@{ Name = 'Empty-5Stage'; Stages = @() } | ConvertTo-Json -Depth 5) -Encoding UTF8

      $result = Sync-BuildMasterPlans -Path $script:tempDir -IncludePipelines -BuildMasterAdminApiKeySecretName 'test-key' -BuildMasterBaseUrl 'http://buildmaster.test' -SkipExistingLookup

      ($result.Errors -join "`n") | Should -Match 'not valid JSON'
      ($result.Errors -join "`n") | Should -Match 'declares no Stages'
      @($script:restCalls | Where-Object { $_.Uri -like '*/Rafts_CreateOrUpdateRaftItem' }).Body.RaftItem_Name | Should -Not -Contain 'Broken-5Stage'
      @($script:restCalls | Where-Object { $_.Uri -like '*/Rafts_CreateOrUpdateRaftItem' }).Body.RaftItem_Name | Should -Not -Contain 'Empty-5Stage'
    }

    It 'refuses an application-scoped pipeline upload' {
      $result = Sync-BuildMasterPlans -Path (Join-Path $script:tempDir 'Sample-5Stage.pipeline.json') -IncludePipelines -ApplicationId 42 -BuildMasterAdminApiKeySecretName 'test-key' -BuildMasterBaseUrl 'http://buildmaster.test' -SkipExistingLookup

      $result.Errors | Should -Match 'global by decision'
      @($script:restCalls | Where-Object { $_.Uri -like '*/Rafts_CreateOrUpdateRaftItem' }).Count | Should -Be 0
    }

    It 'accepts a single pipeline file path only with IncludePipelines' {
      { Sync-BuildMasterPlans -Path (Join-Path $script:tempDir 'Sample-5Stage.pipeline.json') -BuildMasterAdminApiKeySecretName 'test-key' -BuildMasterBaseUrl 'http://buildmaster.test' -SkipExistingLookup } | Should -Throw -ExpectedMessage '*is not an .otter file*'
    }
  }
}
