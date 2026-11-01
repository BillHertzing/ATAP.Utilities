BeforeAll {
  $script:originalFunctions = @{}
  foreach ($name in @('Get-PVal', 'Get-SecretATAP', 'Write-PSFMessage', 'Invoke-RestMethod')) {
    $item = Get-Item -LiteralPath "Function:\global:$name" -ErrorAction SilentlyContinue
    $script:originalFunctions[$name] = [pscustomobject]@{ Exists = ($null -ne $item); Definition = if ($item) { $item.ScriptBlock } else { $null } }
  }
  function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
  function global:Get-PVal {
    param($ParameterName, $originalPSBoundParameters, $DefaultValue)
    if ($originalPSBoundParameters.ContainsKey($ParameterName)) { $originalPSBoundParameters[$ParameterName] } else { $DefaultValue }
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

  function Save-TestGlobalSettings {
    $script:originalSettings = @{}
    foreach ($name in @('settings', 'configRootKeys')) {
      $item = Get-Variable -Name $name -Scope Global -ErrorAction SilentlyContinue
      $script:originalSettings[$name] = [pscustomobject]@{ Exists = ($null -ne $item); Value = if ($item) { $item.Value } else { $null } }
      Set-Variable -Name $name -Scope Global -Value $null
    }
  }
  function Restore-TestGlobalSettings {
    foreach ($name in @('settings', 'configRootKeys')) {
      if ($script:originalSettings[$name].Exists) { Set-Variable -Name $name -Scope Global -Value $script:originalSettings[$name].Value }
      else { Remove-Variable -Name $name -Scope Global -ErrorAction SilentlyContinue }
      $restored = Get-Variable -Name $name -Scope Global -ErrorAction SilentlyContinue
      if ($script:originalSettings[$name].Exists) {
        if ($null -eq $restored -or -not [object]::ReferenceEquals($restored.Value, $script:originalSettings[$name].Value)) { throw "Global variable restore failed: $name" }
      } elseif ($null -ne $restored) { throw "Global variable removal failed: $name" }
    }
  }

  . "$PSScriptRoot\..\..\public\Sync-BuildMasterPlans.ps1"
}

Describe 'Sync-BuildMasterPlans opt-in existing-item raw-byte guard' {
  BeforeAll {
    function Get-GuardFixtureHash([byte[]]$Bytes) { [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes)) }
    function Reset-GuardFixture {
      $script:guardCalls.Clear(); $script:guardReads = 0; $script:guardSecrets = 0; $script:guardScenario = ''
      $script:guardRemote = @([pscustomobject]@{ RaftItem_Name = 'ApplicationBuild-1Stage.otter'; RaftItem_Id = 99; Content_Bytes = [Convert]::ToBase64String($script:guardOld) })
    }
    function Get-GuardWrites { @($script:guardCalls | Where-Object { $_.Uri -like '*/Rafts_CreateOrUpdateRaftItem' }) }
  }
  BeforeEach {
    Save-TestGlobalSettings
    $script:guardFixtureRoot = 'D:/ATAPArtifacts/Sprint0017/Task17.56.c/GuardedSync879/FakeFixtures'
    $script:guardDirectory = Join-Path $script:guardFixtureRoot ([guid]::NewGuid().ToString('N'))
    $null = New-Item -ItemType Directory -Path (Join-Path $script:guardDirectory 'Forward'), (Join-Path $script:guardDirectory 'Rollback') -Force
    $script:guardForward = Join-Path $script:guardDirectory 'Forward/ApplicationBuild-1Stage.otter'
    $script:guardRollback = Join-Path $script:guardDirectory 'Rollback/ApplicationBuild-1Stage.otter'
    $script:guardOld = [Text.Encoding]::UTF8.GetBytes("Log-Information OLD;`r`n")
    $script:guardNew = [Text.Encoding]::UTF8.GetBytes("Log-Information NEW;`n")
    [IO.File]::WriteAllBytes($script:guardForward, $script:guardNew)
    [IO.File]::WriteAllBytes($script:guardRollback, $script:guardOld)
    $script:guardCalls = [Collections.Generic.List[object]]::new()
    $script:guardParameters = @{ Path = $script:guardForward; BuildMasterBaseUrl = 'https://example.invalid'; BuildMasterAdminApiKeySecretName = 'SYNTHETIC.KEY'
      RaftId = 1; RaftItemTypeCode = 6; RequireExisting = $true; ExpectedRemoteSha256 = (Get-GuardFixtureHash $script:guardOld); Confirm = $false }
    Mock Get-PVal { if ($originalPSBoundParameters.ContainsKey($ParameterName)) { $originalPSBoundParameters[$ParameterName] } else { $DefaultValue } }
    Mock Get-SecretATAP { $script:guardSecrets++; 'SYNTHETIC-NOT-A-CREDENTIAL' }
    Mock Write-PSFMessage { }
    Mock Invoke-RestMethod { & $script:invokeRestMethodHandler -Uri $Uri -Method $Method -Body $Body }
    $script:invokeRestMethodHandler = {
      param($Uri, $Method, $Body)
      $script:guardCalls.Add([pscustomobject]@{ Uri = $Uri; Method = $Method; Body = $Body.Clone() })
      if ($Uri -like '*/Rafts_GetRaftItems') {
        $script:guardReads++
        if ($script:guardReads -gt 1) {
          if ($script:guardScenario -eq 'PostError') { throw 'SYNTHETIC_POST_ERROR' }
          if ($script:guardScenario -eq 'PostId') { $script:guardRemote[0].RaftItem_Id = 100 }
          if ($script:guardScenario -eq 'PostHash') { $script:guardRemote[0].Content_Bytes = [Convert]::ToBase64String($script:guardOld) }
        }
        return $script:guardRemote
      }
      if ($Uri -like '*/Rafts_CreateOrUpdateRaftItem') {
        if ($script:guardScenario -eq 'WriteError') { throw 'SYNTHETIC_WRITE_ERROR' }
        $script:guardRemote = @([pscustomobject]@{ RaftItem_Name = $Body.RaftItem_Name; RaftItem_Id = $Body.RaftItem_Id; Content_Bytes = $Body.Content_Bytes })
        return @{}
      }
      throw 'UNEXPECTED_FAKE_ROUTE'
    }
    Reset-GuardFixture
    # Every mutation is anchored by a successful call through the production guard.
    $baseline = Sync-BuildMasterPlans @script:guardParameters
    $baseline.GuardedSuccess | Should -BeTrue
    $baseline.Errors.Count | Should -Be 0
    $baseline.GuardedResults[0].Status | Should -BeExactly 'Verified'
    @(Get-GuardWrites).Count | Should -Be 1
    Reset-GuardFixture
  }
  AfterEach {
    try {
      $resolved = [IO.Path]::GetFullPath($script:guardDirectory)
      $boundary = [IO.Path]::GetFullPath($script:guardFixtureRoot).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
      if (-not $resolved.StartsWith($boundary, [StringComparison]::OrdinalIgnoreCase)) { throw 'Fixture cleanup escaped boundary' }
      Remove-Item -LiteralPath $resolved -Recurse -Force
    } finally { Restore-TestGlobalSettings }
  }
  It 'uses one existing positive ID write and verifies the exact new raw bytes' {
    $result = Sync-BuildMasterPlans @script:guardParameters
    $writes = @(Get-GuardWrites)
    $writes.Count | Should -Be 1; $script:guardReads | Should -Be 2
    $writes[0].Body.RaftItem_Id | Should -Be 99; $writes[0].Body.Raft_Id | Should -Be 1
    $writes[0].Body.RaftItemType_Code | Should -Be 6
    $writes[0].Body.RaftItem_Name | Should -BeExactly 'ApplicationBuild-1Stage.otter'
    $writes[0].Body.ContainsKey('Application_Id') | Should -BeFalse
    $writes[0].Body.Content_Bytes | Should -BeExactly ([Convert]::ToBase64String($script:guardNew))
    $result.GuardedSuccess | Should -BeTrue; $result.GuardedResults[0].PostReadVerified | Should -BeTrue
    $result.PlansSynced[0].Uploaded | Should -BeTrue
  }
  It 'refuses <Variant> before any write' -ForEach @(
    @{ Variant = 'Missing'; Gate = 'GuardedExistingNotUnique' }, @{ Variant = 'Duplicates'; Gate = 'GuardedExistingNotUnique' },
    @{ Variant = 'CaseDuplicates'; Gate = 'GuardedExistingNotUnique' }, @{ Variant = 'CaseName'; Gate = 'GuardedExistingNameMismatch' },
    @{ Variant = 'NullId'; Gate = 'GuardedExistingIdInvalid' }, @{ Variant = 'MissingId'; Gate = 'GuardedExistingIdInvalid' },
    @{ Variant = 'Zero'; Gate = 'GuardedExistingIdInvalid' }, @{ Variant = 'Negative'; Gate = 'GuardedExistingIdInvalid' },
    @{ Variant = 'Fraction'; Gate = 'GuardedExistingIdInvalid' }, @{ Variant = 'FloatingInteger'; Gate = 'GuardedExistingIdInvalid' },
    @{ Variant = 'Boolean'; Gate = 'GuardedExistingIdInvalid' }, @{ Variant = 'Overflow'; Gate = 'GuardedExistingIdInvalid' },
    @{ Variant = 'IdText'; Gate = 'GuardedExistingIdInvalid' }, @{ Variant = 'MissingContent'; Gate = 'GuardedExistingContentInvalid' },
    @{ Variant = 'EmptyBytes'; Gate = 'GuardedExistingContentInvalid' }, @{ Variant = 'BadContent'; Gate = 'GuardedExistingContentInvalid' },
    @{ Variant = 'Hash'; Gate = 'GuardedRemoteHashMismatch' }, @{ Variant = 'NormalizedOnly'; Gate = 'GuardedRemoteHashMismatch' }) {
    param($Variant, $Gate)
    $row = $script:guardRemote[0]
    switch ($Variant) {
      Missing { $script:guardRemote = @() }
      Duplicates { $script:guardRemote += $row.PSObject.Copy() }
      CaseDuplicates { $other = $row.PSObject.Copy(); $other.RaftItem_Name = $row.RaftItem_Name.ToLowerInvariant(); $script:guardRemote += $other }
      CaseName { $row.RaftItem_Name = $row.RaftItem_Name.ToLowerInvariant() }
      NullId { $row.RaftItem_Id = $null }
      MissingId { $row.PSObject.Properties.Remove('RaftItem_Id') }
      Zero { $row.RaftItem_Id = 0 }
      Negative { $row.RaftItem_Id = -1 }
      Fraction { $row.RaftItem_Id = 1.5 }
      FloatingInteger { $row.RaftItem_Id = [double]99 }
      Boolean { $row.RaftItem_Id = $true }
      Overflow { $row.RaftItem_Id = '2147483648' }
      IdText { $row.RaftItem_Id = '99.0' }
      MissingContent { $row.PSObject.Properties.Remove('Content_Bytes') }
      EmptyBytes { $row.Content_Bytes = [byte[]]@() }
      BadContent { $row.Content_Bytes = [pscustomobject]@{ Raw = 'bad' } }
      Hash { $row.Content_Bytes = [Convert]::ToBase64String($script:guardNew) }
      NormalizedOnly { $row.Content_Bytes = "Log-Information OLD;`n" }
    }
    $result = Sync-BuildMasterPlans @script:guardParameters
    $result.Errors.Count | Should -Be 1; $result.Errors[0] | Should -Match $Gate
    $result.GuardedResults[0].Status | Should -BeExactly 'RefusedBeforeWrite'
    $result.GuardedSuccess | Should -BeFalse; $result.GuardedResults[0].WriteAttempted | Should -BeFalse
    @(Get-GuardWrites).Count | Should -Be 0
  }
  It 'accepts source-proven raw content representation <Representation> without normalization' -ForEach @(
    @{ Representation = 'ByteArray' }, @{ Representation = 'Base64' }, @{ Representation = 'UTF8Fallback' },
    @{ Representation = 'ContentText' }, @{ Representation = 'Content' }, @{ Representation = 'IntegerStringId' }, @{ Representation = 'LowercaseHash' }) {
    param($Representation)
    $row = $script:guardRemote[0]
    switch ($Representation) {
      ByteArray { $row.Content_Bytes = $script:guardOld }
      UTF8Fallback { $row.Content_Bytes = [Text.Encoding]::UTF8.GetString($script:guardOld) }
      ContentText { $row.PSObject.Properties.Remove('Content_Bytes'); $row | Add-Member NoteProperty Content_Text ([Text.Encoding]::UTF8.GetString($script:guardOld)) }
      Content { $row.PSObject.Properties.Remove('Content_Bytes'); $row | Add-Member NoteProperty Content ([Text.Encoding]::UTF8.GetString($script:guardOld)) }
      IntegerStringId { $row.RaftItem_Id = '99' }
      LowercaseHash { $script:guardParameters.ExpectedRemoteSha256 = $script:guardParameters.ExpectedRemoteSha256.ToLowerInvariant() }
    }
    $result = Sync-BuildMasterPlans @script:guardParameters
    $result.Errors.Count | Should -Be 0; $result.GuardedSuccess | Should -BeTrue
    @(Get-GuardWrites).Count | Should -Be 1
  }
  It 'rejects unpaired or false guard parameters <Variant> before secret/API effects' -ForEach @(
    @{ Variant = 'HashOnly' }, @{ Variant = 'SwitchOnly' }, @{ Variant = 'FalseWithHash' }, @{ Variant = 'FalseOnly' }, @{ Variant = 'MalformedHash' }) {
    param($Variant)
    $parameters = $script:guardParameters.Clone()
    switch ($Variant) {
      HashOnly { $parameters.Remove('RequireExisting') }
      SwitchOnly { $parameters.Remove('ExpectedRemoteSha256') }
      FalseWithHash { $parameters.RequireExisting = $false }
      FalseOnly { $parameters.RequireExisting = $false; $parameters.Remove('ExpectedRemoteSha256') }
      MalformedHash { $parameters.ExpectedRemoteSha256 = 'not-a-hash' }
    }
    { Sync-BuildMasterPlans @parameters } | Should -Throw
    $script:guardSecrets | Should -Be 0; $script:guardCalls.Count | Should -Be 0
  }
  It 'rejects guarded fanout or lookup bypass <Variant> before secret/API effects' -ForEach @(
    @{ Variant = 'Directory' }, @{ Variant = 'Wildcard' }, @{ Variant = 'Recurse' },
    @{ Variant = 'IncludePipelines' }, @{ Variant = 'SkipExistingLookup' }, @{ Variant = 'PipelineFile' }) {
    param($Variant)
    $parameters = $script:guardParameters.Clone()
    switch ($Variant) {
      Directory { $parameters.Path = $script:guardDirectory }
      Wildcard { $parameters.Path = Join-Path $script:guardDirectory '*.otter' }
      PipelineFile { $parameters.Path = Join-Path $script:guardDirectory 'Other.pipeline.json'; [IO.File]::WriteAllText($parameters.Path, '{}') }
      default { $parameters[$Variant] = $true }
    }
    { Sync-BuildMasterPlans @parameters } | Should -Throw '*GuardedSingleLiteralFileRequired*'
    $script:guardSecrets | Should -Be 0; $script:guardCalls.Count | Should -Be 0
  }
  It 'keeps WhatIf unwritten and never claims post-read verification' {
    $result = Sync-BuildMasterPlans @script:guardParameters -WhatIf
    $result.Errors.Count | Should -Be 0; $result.GuardedSuccess | Should -BeFalse
    $result.GuardedResults[0].Status | Should -BeExactly 'NotWritten'
    $result.GuardedResults[0].WriteAttempted | Should -BeFalse; $result.GuardedResults[0].PostReadVerified | Should -BeFalse
    $result.PlansSynced[0].Uploaded | Should -BeFalse
    @(Get-GuardWrites).Count | Should -Be 0; $script:guardReads | Should -Be 1
  }
  It 'retains uncertainty without retry or compensation after <Variant>' -ForEach @(
    @{ Variant = 'WriteError'; Status = 'WriteUnverified'; Gate = 'SYNTHETIC_WRITE_ERROR'; Reads = 1 },
    @{ Variant = 'PostHash'; Status = 'PostReadUnverified'; Gate = 'GuardedRemoteHashMismatch'; Reads = 2 },
    @{ Variant = 'PostId'; Status = 'PostReadUnverified'; Gate = 'GuardedPostReadIdMismatch'; Reads = 2 },
    @{ Variant = 'PostError'; Status = 'PostReadUnverified'; Gate = 'SYNTHETIC_POST_ERROR'; Reads = 2 }) {
    param($Variant, $Status, $Gate, $Reads)
    $script:guardScenario = $Variant
    $result = Sync-BuildMasterPlans @script:guardParameters
    $result.Errors.Count | Should -Be 1; $result.Errors[0] | Should -Match $Gate
    $result.GuardedResults[0].Status | Should -BeExactly $Status
    $result.GuardedResults[0].WriteAttempted | Should -BeTrue; $result.GuardedResults[0].PostReadVerified | Should -BeFalse
    $result.GuardedSuccess | Should -BeFalse; @(Get-GuardWrites).Count | Should -Be 1; $script:guardReads | Should -Be $Reads
  }
  It 'restores synthetic old bytes only through the exact same rollback basename and fresh new hash' {
    $forward = Sync-BuildMasterPlans @script:guardParameters
    $forward.GuardedSuccess | Should -BeTrue
    $script:guardCalls.Clear(); $script:guardReads = 0
    $parameters = $script:guardParameters.Clone(); $parameters.Path = $script:guardRollback
    $parameters.ExpectedRemoteSha256 = Get-GuardFixtureHash $script:guardNew
    $rollback = Sync-BuildMasterPlans @parameters
    $rollback.GuardedSuccess | Should -BeTrue
    $write = @(Get-GuardWrites); $write.Count | Should -Be 1
    $write[0].Body.RaftItem_Name | Should -BeExactly 'ApplicationBuild-1Stage.otter'
    $write[0].Body.Content_Bytes | Should -BeExactly ([Convert]::ToBase64String($script:guardOld))
    $write[0].Body.RaftItem_Id | Should -Be 99
    $script:guardCalls.Clear(); $script:guardReads = 0
    # Reusing the now-stale new-byte expectation must not write again.
    $stale = Sync-BuildMasterPlans @parameters
    $stale.Errors[0] | Should -Match 'GuardedRemoteHashMismatch'; @(Get-GuardWrites).Count | Should -Be 0
  }
}

AfterAll {
  foreach ($name in $script:originalFunctions.Keys) {
    if ($script:originalFunctions[$name].Exists) { Set-Item -LiteralPath "Function:\global:$name" -Value $script:originalFunctions[$name].Definition }
    else { Remove-Item -LiteralPath "Function:\global:$name" -Force -ErrorAction SilentlyContinue }
    $restored = Get-Item -LiteralPath "Function:\global:$name" -ErrorAction SilentlyContinue
    if ($script:originalFunctions[$name].Exists) {
      if ($null -eq $restored -or $restored.ScriptBlock.ToString() -cne $script:originalFunctions[$name].Definition.ToString()) { throw "Global function restore failed: $name" }
    } elseif ($null -ne $restored) { throw "Global function removal failed: $name" }
  }
}

Describe 'Sync-BuildMasterPlans [public]' {
  BeforeEach {
    Save-TestGlobalSettings
    Mock Get-PVal { if ($originalPSBoundParameters.ContainsKey($ParameterName)) { $originalPSBoundParameters[$ParameterName] } else { $DefaultValue } }
    Mock Get-SecretATAP { 'test-key' }
    Mock Write-PSFMessage { }
    Mock Invoke-RestMethod { & $script:invokeRestMethodHandler -Uri $Uri -Method $Method -Body $Body }
    $script:legacyFixtureRoot = 'D:/ATAPArtifacts/Sprint0017/Task17.56.c/GuardedSync879/FakeFixtures'
    $script:tempDir = Join-Path $script:legacyFixtureRoot "bm_plans_$([guid]::NewGuid().ToString('N'))"
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
    try {
      $resolved = [IO.Path]::GetFullPath($script:tempDir)
      $boundary = [IO.Path]::GetFullPath($script:legacyFixtureRoot).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
      if (-not $resolved.StartsWith($boundary, [StringComparison]::OrdinalIgnoreCase)) { throw 'Fixture cleanup escaped boundary' }
      Remove-Item -LiteralPath $resolved -Recurse -Force -ErrorAction SilentlyContinue
    } finally { Restore-TestGlobalSettings }
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
