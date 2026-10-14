# Set-SqlDatabaseRoleMembership.Tests.ps1
# Unit tests for Set-SqlDatabaseRoleMembership

Describe 'Set-SqlDatabaseRoleMembership' -Tag 'Unit' {

  BeforeAll {
    $publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
    . (Join-Path $publicDir 'Set-SqlDatabaseRoleMembership.ps1')

    Write-PSFMessage -Level Debug -Message 'Starting Set-SqlDatabaseRoleMembership tests' -Tag 'Trace', 'Tests'

    $script:instance = 'UTAT022\Exp'
    $script:database = 'ATAPUtilities'
    $script:principal = 'UTAT022\SvcAceOutpost'
    $script:role = 'AceAISupervisorCaptureExecutor'
  }

  # -------------------------------------------------------------------------
  Context 'Success path' {

    BeforeEach {
      Mock -CommandName Invoke-DbaQuery -MockWith { }
    }

    It 'returns Status = Success' {
      $result = Set-SqlDatabaseRoleMembership `
        -SqlInstance $script:instance -DatabaseName $script:database `
        -DatabasePrincipal $script:principal -RoleName $script:role
      $result.Status | Should -Be 'Success'
    }

    It 'echoes the principal, role and database in the result' {
      $result = Set-SqlDatabaseRoleMembership `
        -SqlInstance $script:instance -DatabaseName $script:database `
        -DatabasePrincipal $script:principal -RoleName $script:role
      $result.DatabasePrincipal | Should -Be $script:principal
      $result.RoleName | Should -Be $script:role
      $result.DatabaseName | Should -Be $script:database
    }

    It 'defaults Ensure to Present' {
      $result = Set-SqlDatabaseRoleMembership `
        -SqlInstance $script:instance -DatabaseName $script:database `
        -DatabasePrincipal $script:principal -RoleName $script:role
      $result.Ensure | Should -Be 'Present'
    }

    It 'runs a single batch against the target database, not master' {
      # The role and the principal are both database-scoped; touching master here would
      # mean the function had drifted into login provisioning, which is another function.
      Set-SqlDatabaseRoleMembership `
        -SqlInstance $script:instance -DatabaseName $script:database `
        -DatabasePrincipal $script:principal -RoleName $script:role | Out-Null
      Should -Invoke Invoke-DbaQuery -Times 1 -Exactly
      Should -Invoke Invoke-DbaQuery -Times 1 -ParameterFilter { $Database -eq $script:database }
    }
  }

  # -------------------------------------------------------------------------
  Context 'Generated T-SQL' {

    BeforeEach {
      $script:capturedQuery = $null
      Mock -CommandName Invoke-DbaQuery -MockWith { $script:capturedQuery = $Query }
    }

    It 'emits ADD MEMBER when Ensure is Present' {
      Set-SqlDatabaseRoleMembership `
        -SqlInstance $script:instance -DatabaseName $script:database `
        -DatabasePrincipal $script:principal -RoleName $script:role -Ensure Present | Out-Null
      $script:capturedQuery | Should -Match 'ADD MEMBER'
      $script:capturedQuery | Should -Not -Match 'DROP MEMBER'
    }

    It 'emits DROP MEMBER when Ensure is Absent' {
      # Revocation is a first-class parameter because every grant this function makes is
      # expected to be revoked eventually.
      Set-SqlDatabaseRoleMembership `
        -SqlInstance $script:instance -DatabaseName $script:database `
        -DatabasePrincipal $script:principal -RoleName $script:role -Ensure Absent | Out-Null
      $script:capturedQuery | Should -Match 'DROP MEMBER'
      $script:capturedQuery | Should -Not -Match 'ADD MEMBER'
    }

    It 'refuses rather than creating a missing role' {
      # A membership call that created its own role would hide the fact that the migration
      # defining it had not been deployed.
      Set-SqlDatabaseRoleMembership `
        -SqlInstance $script:instance -DatabaseName $script:database `
        -DatabasePrincipal $script:principal -RoleName $script:role | Out-Null
      $script:capturedQuery | Should -Match 'THROW 60001'
      $script:capturedQuery | Should -Not -Match 'CREATE ROLE'
    }

    It 'refuses rather than creating a missing principal' {
      Set-SqlDatabaseRoleMembership `
        -SqlInstance $script:instance -DatabaseName $script:database `
        -DatabasePrincipal $script:principal -RoleName $script:role | Out-Null
      $script:capturedQuery | Should -Match 'THROW 60002'
      $script:capturedQuery | Should -Not -Match 'CREATE USER'
    }

    It 'never grants a fixed server or database role' {
      # db_owner is Initialize-SqlServiceLogin's business. This function grants exactly the
      # named application role and nothing wider.
      Set-SqlDatabaseRoleMembership `
        -SqlInstance $script:instance -DatabaseName $script:database `
        -DatabasePrincipal $script:principal -RoleName $script:role | Out-Null
      $script:capturedQuery | Should -Not -Match 'db_owner'
      $script:capturedQuery | Should -Not -Match 'sysadmin'
    }

    It 'guards the change behind an existence check so a rerun is a no-op' {
      Set-SqlDatabaseRoleMembership `
        -SqlInstance $script:instance -DatabaseName $script:database `
        -DatabasePrincipal $script:principal -RoleName $script:role | Out-Null
      $script:capturedQuery | Should -Match 'sys\.database_role_members'
      $script:capturedQuery | Should -Match 'IF @isMember <>'
    }

    It 'resolves the principal by login SID as well as by user name' {
      # A database user whose name differs from the account short name is common after a
      # login remap, and missing it would surface much later as a permission defect.
      Set-SqlDatabaseRoleMembership `
        -SqlInstance $script:instance -DatabaseName $script:database `
        -DatabasePrincipal $script:principal -RoleName $script:role | Out-Null
      $script:capturedQuery | Should -Match 'SUSER_SID'
    }

    It 'quotes every dynamic identifier through QUOTENAME' {
      Set-SqlDatabaseRoleMembership `
        -SqlInstance $script:instance -DatabaseName $script:database `
        -DatabasePrincipal $script:principal -RoleName $script:role | Out-Null
      $script:capturedQuery | Should -Match 'QUOTENAME\(@role\)'
      $script:capturedQuery | Should -Match 'QUOTENAME\(@mappedUser\)'
    }

    It "escapes an embedded apostrophe in a principal name" {
      $awkward = "UTAT022\O'Brien"
      Set-SqlDatabaseRoleMembership `
        -SqlInstance $script:instance -DatabaseName $script:database `
        -DatabasePrincipal $awkward -RoleName $script:role | Out-Null
      $script:capturedQuery | Should -Match "O''Brien"
    }
  }

  # -------------------------------------------------------------------------
  Context 'WhatIf' {

    BeforeEach {
      Mock -CommandName Invoke-DbaQuery -MockWith { }
    }

    It 'reports WhatIf and issues no query' {
      $result = Set-SqlDatabaseRoleMembership `
        -SqlInstance $script:instance -DatabaseName $script:database `
        -DatabasePrincipal $script:principal -RoleName $script:role -WhatIf
      $result.Status | Should -Be 'WhatIf'
      Should -Invoke Invoke-DbaQuery -Times 0 -Exactly
    }
  }

  # -------------------------------------------------------------------------
  Context 'Failure path' {

    BeforeEach {
      Mock -CommandName Invoke-DbaQuery -MockWith { throw 'permission denied' }
    }

    It 'rethrows so a failed grant cannot be mistaken for a successful one' {
      { Set-SqlDatabaseRoleMembership `
          -SqlInstance $script:instance -DatabaseName $script:database `
          -DatabasePrincipal $script:principal -RoleName $script:role } | Should -Throw
    }
  }

  # -------------------------------------------------------------------------
  Context 'Parameter validation' {

    It 'rejects an Ensure value outside Present and Absent' {
      { Set-SqlDatabaseRoleMembership `
          -SqlInstance $script:instance -DatabaseName $script:database `
          -DatabasePrincipal $script:principal -RoleName $script:role `
          -Ensure 'Maybe' } | Should -Throw
    }
  }
}
