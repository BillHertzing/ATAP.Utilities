Describe 'Get-SqlServiceLoginGrantTarget' -Tag 'Unit' {
  BeforeAll {
    $publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
    . (Join-Path $publicDir 'Get-SqlServiceLoginGrantTarget.ps1')
    $script:instance = 'UTAT022\Production'
    $script:hostName = 'UTAT022'
    $script:account = 'UTAT022\SvcBuildMaster'
    $script:sid = 'S-1-5-21-1-2-3-1001'
    $sidObject = [Security.Principal.SecurityIdentifier]::new($script:sid)
    $sidBytes = [byte[]]::new($sidObject.BinaryLength)
    $sidObject.GetBinaryForm($sidBytes, 0)
    $script:sidHex = '0x' + [Convert]::ToHexString($sidBytes)
    $script:allowed = @('Expwhertzing', 'Devwhertzing', 'Integration', 'QA', 'Production')
  }

  BeforeEach {
    $script:loginSidHex = $script:sidHex
    $script:machineName = $script:hostName
    $script:databaseRows = @(
      [pscustomobject]@{ DatabaseName = 'master'; DatabaseId = 1; State = 'ONLINE'; UserAccess = 'MULTI_USER'; IsReadOnly = $false; SourceDatabaseId = $null }
      [pscustomobject]@{ DatabaseName = 'ATAPUtilities'; DatabaseId = 5; State = 'ONLINE'; UserAccess = 'MULTI_USER'; IsReadOnly = $false; SourceDatabaseId = $null }
      [pscustomobject]@{ DatabaseName = 'UnmanagedApp'; DatabaseId = 6; State = 'ONLINE'; UserAccess = 'MULTI_USER'; IsReadOnly = $false; SourceDatabaseId = $null }
      [pscustomobject]@{ DatabaseName = 'OfflineDb'; DatabaseId = 7; State = 'OFFLINE'; UserAccess = 'MULTI_USER'; IsReadOnly = $false; SourceDatabaseId = $null }
    )
    Mock Invoke-DbaQuery {
      if ($Database -eq 'master') {
        return @($script:databaseRows | ForEach-Object {
            [pscustomobject]@{
              MachineName = $script:machineName; ResolvedAccountSidHex = $script:sidHex
              ServerLoginSidHex = $script:loginSidHex; DatabaseName = $_.DatabaseName
              DatabaseId = $_.DatabaseId; State = $_.State; UserAccess = $_.UserAccess
              IsReadOnly = $_.IsReadOnly; SourceDatabaseId = $_.SourceDatabaseId
            }
          })
      }
      [pscustomobject]@{
        DatabaseUserName = 'SvcBuildMaster'
        DatabaseUserSidHex = $script:sidHex
        IsDbOwner = $true
      }
    }
  }

  It 'includes only the explicitly admitted compliant database' {
    $result = @(Get-SqlServiceLoginGrantTarget -SqlInstance $script:instance `
        -ExpectedHostName $script:hostName -ServiceAccount $script:account `
        -ExpectedAccountSid $script:sid -AllowedInstanceName $script:allowed `
        -ApprovedDatabaseName 'ATAPUtilities')

    $target = $result | Where-Object DatabaseName -EQ 'ATAPUtilities'
    $target.Include | Should -BeTrue
    $target.IsCompliant | Should -BeTrue
    $target.ResolvedAccountSid | Should -Be $script:sid
    ($result | Where-Object DatabaseName -EQ 'UnmanagedApp').ExclusionReason | Should -Be 'NotApproved'
    Should -Invoke Invoke-DbaQuery -Exactly 2
  }

  It 'reports system and non-approved databases without auditing them' {
    $result = @(Get-SqlServiceLoginGrantTarget -SqlInstance $script:instance `
        -ExpectedHostName $script:hostName -ServiceAccount $script:account `
        -ExpectedAccountSid $script:sid -AllowedInstanceName $script:allowed `
        -ApprovedDatabaseName 'ATAPUtilities')

    ($result | Where-Object DatabaseName -EQ 'master').ExclusionReason | Should -Be 'SystemDatabase'
    ($result | Where-Object DatabaseName -EQ 'OfflineDb').ExclusionReason | Should -Be 'NotApproved'
    @($result | Where-Object Include).DatabaseName | Should -Be @('ATAPUtilities')
  }

  It 'classifies an approved restoring database as ineligible' {
    $script:databaseRows[1].State = 'RESTORING'
    {
      Get-SqlServiceLoginGrantTarget -SqlInstance $script:instance `
        -ExpectedHostName $script:hostName -ServiceAccount $script:account `
        -ExpectedAccountSid $script:sid -AllowedInstanceName $script:allowed `
        -ApprovedDatabaseName 'ATAPUtilities'
    } | Should -Throw '*Approved database targets were not returned*'
    Should -Invoke Invoke-DbaQuery -Exactly 1
  }

  It 'reports missing login drift without fabricating compliance' {
    $script:loginSidHex = $null
    $target = Get-SqlServiceLoginGrantTarget -SqlInstance $script:instance `
      -ExpectedHostName $script:hostName -ServiceAccount $script:account `
      -ExpectedAccountSid $script:sid -AllowedInstanceName $script:allowed `
      -ApprovedDatabaseName 'ATAPUtilities' | Where-Object Include

    $target.IsCompliant | Should -BeFalse
    $target.DriftReason | Should -Be 'MissingServerLogin'
  }

  It 'rejects a frozen Windows SID mismatch before database audit' {
    {
      Get-SqlServiceLoginGrantTarget -SqlInstance $script:instance `
        -ExpectedHostName $script:hostName -ServiceAccount $script:account `
        -ExpectedAccountSid 'S-1-5-21-1-2-3-1002' -AllowedInstanceName $script:allowed `
        -ApprovedDatabaseName 'ATAPUtilities'
    } | Should -Throw '*Windows SID mismatch*'
    Should -Invoke Invoke-DbaQuery -Exactly 1
  }

  It 'rejects an existing SQL login with a different SID' {
    $script:loginSidHex = '0x010100000000000512000000'
    {
      Get-SqlServiceLoginGrantTarget -SqlInstance $script:instance `
        -ExpectedHostName $script:hostName -ServiceAccount $script:account `
        -ExpectedAccountSid $script:sid -AllowedInstanceName $script:allowed `
        -ApprovedDatabaseName 'ATAPUtilities'
    } | Should -Throw '*login SID*does not match*'
  }

  It 'rejects a server that reports a different physical machine' {
    $script:machineName = 'UTAT01'
    {
      Get-SqlServiceLoginGrantTarget -SqlInstance $script:instance `
        -ExpectedHostName $script:hostName -ServiceAccount $script:account `
        -ExpectedAccountSid $script:sid -AllowedInstanceName $script:allowed `
        -ApprovedDatabaseName 'ATAPUtilities'
    } | Should -Throw '*not expected host*'
  }

  It 'rejects remote, generic Experimental, and unknown instance targets before SQL' -TestCases @(
    @{ SqlInstance = 'UTAT01\Production'; Expected = '*not local*' }
    @{ SqlInstance = 'localhost\Experimental'; Expected = '*Generic SQL instance name*' }
    @{ SqlInstance = 'localhost\Unknown'; Expected = '*not present in the explicit allow-list*' }
  ) {
    param($SqlInstance, $Expected)
    {
      Get-SqlServiceLoginGrantTarget -SqlInstance $SqlInstance `
        -ExpectedHostName $script:hostName -ServiceAccount $script:account `
        -ExpectedAccountSid $script:sid -AllowedInstanceName $script:allowed `
        -ApprovedDatabaseName 'ATAPUtilities'
    } | Should -Throw $Expected
    Should -Invoke Invoke-DbaQuery -Exactly 0
  }

  It 'rejects duplicate approved names without regard to case' {
    {
      Get-SqlServiceLoginGrantTarget -SqlInstance $script:instance `
        -ExpectedHostName $script:hostName -ServiceAccount $script:account `
        -AllowedInstanceName $script:allowed `
        -ApprovedDatabaseName @('ATAPUtilities', 'ataputilities')
    } | Should -Throw '*unique without regard to case*'
  }

  It 'does not query SQL under WhatIf' {
    $result = Get-SqlServiceLoginGrantTarget -SqlInstance $script:instance `
      -ExpectedHostName $script:hostName -ServiceAccount $script:account `
      -ExpectedAccountSid $script:sid -AllowedInstanceName $script:allowed `
      -ApprovedDatabaseName 'ATAPUtilities' -WhatIf
    $result.ExclusionReason | Should -Be 'WhatIf'
    Should -Invoke Invoke-DbaQuery -Exactly 0
  }

  It 'fails when an approved database is absent' {
    {
      Get-SqlServiceLoginGrantTarget -SqlInstance $script:instance `
        -ExpectedHostName $script:hostName -ServiceAccount $script:account `
        -ExpectedAccountSid $script:sid -AllowedInstanceName $script:allowed `
        -ApprovedDatabaseName 'FutureApprovedDb'
    } | Should -Throw '*Approved database targets were not returned*FutureApprovedDb*'
  }
}
