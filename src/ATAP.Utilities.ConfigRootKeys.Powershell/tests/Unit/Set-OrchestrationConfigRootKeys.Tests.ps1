#Requires -Version 7.0
# Root executes with Pester 6.2.0 in a fresh profiled child; source author did not run.
BeforeAll {
  $script:saved943Variable = Get-Variable -Name configRootKeys -Scope Global -ErrorAction SilentlyContinue
  $script:saved943Value = if ($null -ne $script:saved943Variable) { $script:saved943Variable.Value } else { $null }
  $script:expected943 = [ordered]@{
    'OrchestrationMaxRequestBytesConfigRootKey' = 'OrchestrationMaxRequestBytes'
    'OrchestrationMaxBatchRequestsConfigRootKey' = 'OrchestrationMaxBatchRequests'
    'OrchestrationMaxBatchBytesConfigRootKey' = 'OrchestrationMaxBatchBytes'
    'OrchestrationMaxDrainRequestsConfigRootKey' = 'OrchestrationMaxDrainRequests'
    'OrchestrationMaxDrainBatchesConfigRootKey' = 'OrchestrationMaxDrainBatches'
    'OrchestrationMaxDrainMillisecondsConfigRootKey' = 'OrchestrationMaxDrainMilliseconds'
    'OrchestrationMaxRetryAttemptsConfigRootKey' = 'OrchestrationMaxRetryAttempts'
    'OrchestrationRetryBudgetMillisecondsConfigRootKey' = 'OrchestrationRetryBudgetMilliseconds'
    'OrchestrationClosedSprintRetentionDaysConfigRootKey' = 'OrchestrationClosedSprintRetentionDays'
    'OrchestrationMigrationRetentionDaysConfigRootKey' = 'OrchestrationMigrationRetentionDays'
    'OrchestrationStateRootPathConfigRootKey' = 'OrchestrationStateRootPath'
    'OrchestrationCustodyRecordPathConfigRootKey' = 'OrchestrationCustodyRecordPath'
    'OrchestrationProtectedBackupRootPathConfigRootKey' = 'OrchestrationProtectedBackupRootPath'
    'OrchestrationRecoveryHistoryRootPathConfigRootKey' = 'OrchestrationRecoveryHistoryRootPath'
    'OrchestrationSevenZipPathConfigRootKey' = 'OrchestrationSevenZipPath'
    'OrchestrationSevenZipSha256ConfigRootKey' = 'OrchestrationSevenZipSha256'
    'OrchestrationBoardLockRootPathConfigRootKey' = 'OrchestrationBoardLockRootPath'
    'OrchestrationBackupPolicyReferenceConfigRootKey' = 'OrchestrationBackupPolicyReference'
    'OrchestrationResourceRegistryPathConfigRootKey' = 'OrchestrationResourceRegistryPath'
    'OrchestrationCompatibilityMatrixPathConfigRootKey' = 'OrchestrationCompatibilityMatrixPath'
  }
  . (Join-Path $PSScriptRoot '../../public/Set-OrchestrationConfigRootKeys.ps1')
}
AfterAll {
  if ($null -ne $script:saved943Variable) {
    $global:configRootKeys = $script:saved943Value
  } else {
    Remove-Variable -Name configRootKeys -Scope Global -ErrorAction SilentlyContinue
  }
}
Describe 'Orchestration name registration contract' {
  BeforeEach { $global:configRootKeys = @{} }

  It 'registers exactly the twenty selected literal mappings' {
    Set-OrchestrationConfigRootKeys -Confirm:$false

    $global:configRootKeys.Count | Should -Be 20
    foreach ($entry in $script:expected943.GetEnumerator()) {
      $global:configRootKeys.ContainsKey($entry.Key) | Should -BeTrue
      $global:configRootKeys[$entry.Key] | Should -BeExactly $entry.Value
    }
  }

  It 'does not initialize a missing global' {
    Remove-Variable -Name configRootKeys -Scope Global -ErrorAction SilentlyContinue

    { Set-OrchestrationConfigRootKeys -Confirm:$false } | Should -Throw -ExpectedMessage '*initialized Hashtable*'
    (Get-Variable -Name configRootKeys -Scope Global -ErrorAction SilentlyContinue) | Should -BeNullOrEmpty
  }

  It 'refuses null and non-Hashtable globals without replacing them' {
    foreach ($invalid in @($null, 42, 'invalid', [ordered]@{ Unrelated = 'kept' })) {
      $global:configRootKeys = $invalid

      { Set-OrchestrationConfigRootKeys -Confirm:$false } | Should -Throw -ExpectedMessage '*initialized Hashtable*'
      if ($null -eq $invalid) { $global:configRootKeys | Should -BeNullOrEmpty }
      elseif ($invalid -is [ValueType]) { $global:configRootKeys | Should -Be $invalid }
      else { [object]::ReferenceEquals($global:configRootKeys, $invalid) | Should -BeTrue }
    }
  }

  It 'preserves unrelated keys and the existing dictionary reference' {
    $sentinel = [object]::new()
    $global:configRootKeys = @{ Unrelated = $sentinel }
    $original = $global:configRootKeys

    Set-OrchestrationConfigRootKeys -Confirm:$false

    [object]::ReferenceEquals($global:configRootKeys, $original) | Should -BeTrue
    [object]::ReferenceEquals($global:configRootKeys.Unrelated, $sentinel) | Should -BeTrue
    $global:configRootKeys.Count | Should -Be 21
  }

  It 'fills a partial matching registration and is idempotent on repetition' {
    $global:configRootKeys = @{ OrchestrationMaxRequestBytesConfigRootKey = 'OrchestrationMaxRequestBytes' }

    Set-OrchestrationConfigRootKeys -Confirm:$false
    Set-OrchestrationConfigRootKeys -Confirm:$false

    $global:configRootKeys.Count | Should -Be 20
    foreach ($entry in $script:expected943.GetEnumerator()) {
      $global:configRootKeys[$entry.Key] | Should -BeExactly $entry.Value
    }
  }

  It 'preflights a final-entry conflict before adding any missing mapping' {
    $global:configRootKeys = @{
      Unrelated = 'kept'
      OrchestrationCompatibilityMatrixPathConfigRootKey = 'WrongName'
    }

    { Set-OrchestrationConfigRootKeys -Confirm:$false } | Should -Throw -ExpectedMessage '*Conflicting orchestration key mapping*'

    $global:configRootKeys.Count | Should -Be 2
    $global:configRootKeys.ContainsKey('OrchestrationMaxRequestBytesConfigRootKey') | Should -BeFalse
    $global:configRootKeys.OrchestrationCompatibilityMatrixPathConfigRootKey | Should -BeExactly 'WrongName'
    $global:configRootKeys.Unrelated | Should -BeExactly 'kept'
  }

  It 'refuses case-different and nonstring mapped values rather than normalizing them' {
    foreach ($wrongValue in @('ORCHESTRATIONMAXREQUESTBYTES', 1, $null)) {
      $global:configRootKeys = @{ OrchestrationMaxRequestBytesConfigRootKey = $wrongValue }

      { Set-OrchestrationConfigRootKeys -Confirm:$false } | Should -Throw -ExpectedMessage '*Conflicting orchestration key mapping*'
      $global:configRootKeys.Count | Should -Be 1
    }
  }

  It 'finds a case-alias conflict using native Hashtable lookup before writes' {
    $global:configRootKeys = @{ orchestrationcompatibilitymatrixpathconfigrootkey = 'WrongName' }

    { Set-OrchestrationConfigRootKeys -Confirm:$false } | Should -Throw -ExpectedMessage '*Conflicting orchestration key mapping*'

    $global:configRootKeys.Count | Should -Be 1
  }

  It 'does not mutate a valid dictionary under WhatIf' {
    $global:configRootKeys = @{ Unrelated = 'kept' }

    Set-OrchestrationConfigRootKeys -WhatIf

    $global:configRootKeys.Count | Should -Be 1
    $global:configRootKeys.Unrelated | Should -BeExactly 'kept'
  }
}

Describe 'Comparer-independent orchestration alias preflight' {
  BeforeEach { $global:configRootKeys = [hashtable]::new([StringComparer]::Ordinal) }

  It 'refuses a late conflicting lowercase alias in an ordinal table before additions' {
    $global:configRootKeys.Add('Unrelated', 'kept')
    $global:configRootKeys.Add('orchestrationcompatibilitymatrixpathconfigrootkey', 'WrongName')

    { Set-OrchestrationConfigRootKeys -Confirm:$false } | Should -Throw -ExpectedMessage '*Conflicting orchestration key mapping*'

    $global:configRootKeys.Count | Should -Be 2
    $global:configRootKeys.ContainsKey('OrchestrationMaxRequestBytesConfigRootKey') | Should -BeFalse
    $global:configRootKeys['Unrelated'] | Should -BeExactly 'kept'
  }

  It 'refuses a matching-value noncanonical alias instead of creating a second logical key' {
    $global:configRootKeys.Add('orchestrationmaxrequestbytesconfigrootkey', 'OrchestrationMaxRequestBytes')

    { Set-OrchestrationConfigRootKeys -Confirm:$false } | Should -Throw -ExpectedMessage '*Ambiguous orchestration key spelling*'

    $global:configRootKeys.Count | Should -Be 1
    $global:configRootKeys.ContainsKey('OrchestrationMaxRequestBytesConfigRootKey') | Should -BeFalse
  }

  It 'refuses two logical aliases even when both values match' {
    $global:configRootKeys.Add('OrchestrationCompatibilityMatrixPathConfigRootKey', 'OrchestrationCompatibilityMatrixPath')
    $global:configRootKeys.Add('orchestrationcompatibilitymatrixpathconfigrootkey', 'OrchestrationCompatibilityMatrixPath')

    { Set-OrchestrationConfigRootKeys -Confirm:$false } | Should -Throw -ExpectedMessage '*Ambiguous orchestration key spelling*'

    $global:configRootKeys.Count | Should -Be 2
    $global:configRootKeys.ContainsKey('OrchestrationMaxRequestBytesConfigRootKey') | Should -BeFalse
  }

  It 'supports canonical mappings and repeat calls in an ordinal table' {
    Set-OrchestrationConfigRootKeys -Confirm:$false
    Set-OrchestrationConfigRootKeys -Confirm:$false

    $global:configRootKeys.Count | Should -Be 20
    foreach ($entry in $script:expected943.GetEnumerator()) {
      $global:configRootKeys.ContainsKey($entry.Key) | Should -BeTrue
      $global:configRootKeys[$entry.Key] | Should -BeExactly $entry.Value
    }
  }

  It 'leaves a conflicting ordinal table untouched under WhatIf' {
    $global:configRootKeys.Add('orchestrationcompatibilitymatrixpathconfigrootkey', 1)

    { Set-OrchestrationConfigRootKeys -WhatIf } | Should -Throw -ExpectedMessage '*Conflicting orchestration key mapping*'

    $global:configRootKeys.Count | Should -Be 1
    $global:configRootKeys.ContainsKey('OrchestrationMaxRequestBytesConfigRootKey') | Should -BeFalse
  }
}
