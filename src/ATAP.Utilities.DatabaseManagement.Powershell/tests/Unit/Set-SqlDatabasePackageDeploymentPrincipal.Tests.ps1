Describe 'Set-SqlDatabasePackageDeploymentPrincipal' -Tag 'Unit' {
  BeforeAll {
    $publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
    . (Join-Path $publicDir 'Get-SqlServiceLoginGrantTarget.ps1')
    . (Join-Path $publicDir 'Set-SqlDatabasePackageDeploymentPrincipal.ps1')
    $script:baseParameters = @{
      SqlInstance = 'UTAT022\Production'
      ExpectedHostName = 'UTAT022'
      ServiceAccount = 'UTAT022\SvcBuildMaster'
      ExpectedAccountSid = 'S-1-5-21-1-2-3-1001'
      AllowedInstanceName = @('Expwhertzing', 'Devwhertzing', 'Integration', 'QA', 'Production')
      ApprovedDatabaseName = @('ATAPUtilities')
    }
  }

  BeforeEach {
    Mock Get-SqlServiceLoginGrantTarget {
      @(
        [pscustomobject]@{
          DatabaseName = 'master'; Include = $false; ExclusionReason = 'SystemDatabase'
          DriftReason = 'SystemDatabase'; IsCompliant = $false
        }
        [pscustomobject]@{
          DatabaseName = 'ATAPUtilities'; Include = $true; ExclusionReason = $null
          DriftReason = 'MissingDatabaseUser'; IsCompliant = $false
        }
        [pscustomobject]@{
          DatabaseName = 'UnmanagedApp'; Include = $false; ExclusionReason = 'NotApproved'
          DriftReason = 'NotApproved'; IsCompliant = $false
        }
      )
    }
    $script:capturedQuery = $null
    Mock Invoke-DbaQuery {
      $script:capturedQuery = $Query
    }
  }

  It 'returns the complete inventory without mutation in audit mode' {
    $result = @(Set-SqlDatabasePackageDeploymentPrincipal @script:baseParameters -AuditOnly)
    $result.Count | Should -Be 3
    ($result | Where-Object DatabaseName -EQ 'UnmanagedApp').ExclusionReason | Should -Be 'NotApproved'
    Should -Invoke Invoke-DbaQuery -Exactly 0
  }

  It 'grants only the approved database through guarded idempotent SQL' {
    $result = Set-SqlDatabasePackageDeploymentPrincipal @script:baseParameters -Ensure Present -Confirm:$false
    $result.Status | Should -Be 'Success'
    $result.DatabaseName | Should -Be 'ATAPUtilities'
    $script:capturedQuery | Should -Match 'CREATE LOGIN'
    $script:capturedQuery | Should -Match 'CREATE USER'
    $script:capturedQuery | Should -Match 'ALTER ROLE \[db_owner\] ADD MEMBER'
    $script:capturedQuery | Should -Match 'SERVERPROPERTY\(''MachineName''\)'
    $script:capturedQuery | Should -Match "DECLARE @expectedSid varbinary\(85\) = CONVERT\(varbinary\(85\), '0x[0-9A-F]+', 1\)"
    $script:capturedQuery | Should -Match 'SUSER_SID\(@account\) <> @expectedSid'
    $script:capturedQuery | Should -Not -Match 'S-1-5-21-1-2-3-1001'
    $script:capturedQuery | Should -Not -Match 'UnmanagedApp'
    Should -Invoke Invoke-DbaQuery -Exactly 1 -ParameterFilter { $Database -eq 'master' }
  }

  It 'never widens authority to a server role or forbidden propagation mechanism' {
    Set-SqlDatabasePackageDeploymentPrincipal @script:baseParameters -Ensure Present -Confirm:$false | Out-Null
    $script:capturedQuery | Should -Not -Match '(?i)\b(sysadmin|CONTROL SERVER|ALTER SERVER ROLE|sp_addsrvrolemember)\b'
    $script:capturedQuery | Should -Not -Match '(?i)USE \[model\]|CREATE TRIGGER.*ON ALL SERVER'
  }

  It 'plans without running mutation SQL under WhatIf' {
    $result = Set-SqlDatabasePackageDeploymentPrincipal @script:baseParameters -Ensure Present -WhatIf
    $result.Status | Should -Be 'WhatIf'
    $result.GeneratedSqlSha256 | Should -Match '^[0-9A-F]{64}$'
    Should -Invoke Get-SqlServiceLoginGrantTarget -Exactly 1
    Should -Invoke Invoke-DbaQuery -Exactly 0
  }

  It 'produces a deterministic secret-safe hash for identical planned SQL' {
    $first = Set-SqlDatabasePackageDeploymentPrincipal @script:baseParameters -Ensure Present -WhatIf
    $second = Set-SqlDatabasePackageDeploymentPrincipal @script:baseParameters -Ensure Present -WhatIf
    $first.GeneratedSqlSha256 | Should -BeExactly $second.GeneratedSqlSha256
  }

  It 'revokes membership and an explicitly selected newly-created user but retains the server login' {
    $result = Set-SqlDatabasePackageDeploymentPrincipal @script:baseParameters -Ensure Absent -RemoveDatabaseUser -Confirm:$false
    $result.Status | Should -Be 'Success'
    $script:capturedQuery | Should -Match 'ALTER ROLE \[db_owner\] DROP MEMBER'
    $script:capturedQuery | Should -Match 'DROP USER'
    $script:capturedQuery | Should -Not -Match 'DROP LOGIN'
    $result.Rollback | Should -Match 'Ensure Present'
  }

  It 'preserves a pre-existing mapped database user during role-only rollback' {
    Set-SqlDatabasePackageDeploymentPrincipal @script:baseParameters -Ensure Absent -Confirm:$false | Out-Null
    $script:capturedQuery | Should -Match 'IF @removeDatabaseUser = 1'
    $script:capturedQuery | Should -Match 'DECLARE @removeDatabaseUser bit = 0'
    $script:capturedQuery | Should -Not -Match 'DROP LOGIN'
  }

  It 'rejects the destructive user-removal flag outside Ensure Absent' {
    { Set-SqlDatabasePackageDeploymentPrincipal @script:baseParameters -Ensure Present -RemoveDatabaseUser -Confirm:$false } |
      Should -Throw '*valid only with -Ensure Absent*'
    Should -Invoke Get-SqlServiceLoginGrantTarget -Exactly 0
    Should -Invoke Invoke-DbaQuery -Exactly 0
  }

  It 'fails closed when inventory does not return every approved target' {
    $parameters = @{} + $script:baseParameters
    $parameters.ApprovedDatabaseName = @('ATAPUtilities', 'MissingApprovedDb')
    {
      Set-SqlDatabasePackageDeploymentPrincipal @parameters -Confirm:$false
    } | Should -Throw '*does not equal approved target count*'
    Should -Invoke Invoke-DbaQuery -Exactly 0
  }

  It 'quotes an admitted database identifier containing a closing bracket' {
    $parameters = @{} + $script:baseParameters
    $parameters.ApprovedDatabaseName = @('Approved]Db')
    Mock Get-SqlServiceLoginGrantTarget {
      [pscustomobject]@{ DatabaseName = 'Approved]Db'; Include = $true; DriftReason = 'MissingDatabaseUser' }
    }
    Set-SqlDatabasePackageDeploymentPrincipal @parameters -Confirm:$false | Out-Null
    $script:capturedQuery | Should -Match 'USE \[Approved\]\]Db\]'
  }

  It 'propagates SQL failures and does not emit a success record' {
    Mock Invoke-DbaQuery { throw 'SQL grant failed' }
    {
      Set-SqlDatabasePackageDeploymentPrincipal @script:baseParameters -Confirm:$false
    } | Should -Throw '*SQL grant failed*'
  }
}
