# Initialize-SqlServiceLogin.Tests.ps1
# Unit tests for Initialize-SqlServiceLogin

Describe 'Initialize-SqlServiceLogin' -Tag 'Unit' {

  BeforeAll {
    $publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
    . (Join-Path $publicDir 'Initialize-SqlServiceLogin.ps1')

    Write-PSFMessage -Level Debug -Message 'Starting Initialize-SqlServiceLogin tests' -Tag 'Trace', 'Tests'

    $script:instance = 'localhost\PRODUCTION'
    $script:database = 'ProGet'
    $script:account = 'TESTHOST\SvcProGet'
  }

  # -------------------------------------------------------------------------
  Context 'Success path — Invoke-Sqlcmd succeeds for both batches' {

    BeforeEach {
      Mock -CommandName Invoke-Sqlcmd -MockWith { }
    }

    It 'returns Status = Success' {
      $result = Initialize-SqlServiceLogin `
        -SqlInstance $script:instance `
        -DatabaseName $script:database `
        -ServiceAccount $script:account
      $result.Status | Should -Be 'Success'
    }

    It 'echoes SqlInstance in the result' {
      $result = Initialize-SqlServiceLogin `
        -SqlInstance $script:instance `
        -DatabaseName $script:database `
        -ServiceAccount $script:account
      $result.SqlInstance | Should -Be $script:instance
    }

    It 'echoes DatabaseName in the result' {
      $result = Initialize-SqlServiceLogin `
        -SqlInstance $script:instance `
        -DatabaseName $script:database `
        -ServiceAccount $script:account
      $result.DatabaseName | Should -Be $script:database
    }

    It 'echoes ServiceAccount in the result' {
      $result = Initialize-SqlServiceLogin `
        -SqlInstance $script:instance `
        -DatabaseName $script:database `
        -ServiceAccount $script:account
      $result.ServiceAccount | Should -Be $script:account
    }

    It 'calls Invoke-Sqlcmd exactly twice (login batch + user/role batch)' {
      Initialize-SqlServiceLogin `
        -SqlInstance $script:instance `
        -DatabaseName $script:database `
        -ServiceAccount $script:account | Out-Null
      Should -Invoke Invoke-Sqlcmd -Exactly 2
    }

    It 'first Invoke-Sqlcmd call targets master database' {
      Initialize-SqlServiceLogin `
        -SqlInstance $script:instance `
        -DatabaseName $script:database `
        -ServiceAccount $script:account | Out-Null
      Should -Invoke Invoke-Sqlcmd -ParameterFilter { $Database -eq 'master' } -Exactly 1
    }

    It 'second Invoke-Sqlcmd call targets the application database' {
      Initialize-SqlServiceLogin `
        -SqlInstance $script:instance `
        -DatabaseName $script:database `
        -ServiceAccount $script:account | Out-Null
      Should -Invoke Invoke-Sqlcmd -ParameterFilter { $Database -eq $script:database } -Exactly 1
    }

    It 'passes TrustServerCertificate = $true when switch is specified' {
      Initialize-SqlServiceLogin `
        -SqlInstance $script:instance `
        -DatabaseName $script:database `
        -ServiceAccount $script:account `
        -TrustServerCertificate | Out-Null
      Should -Invoke Invoke-Sqlcmd `
        -ParameterFilter { $TrustServerCertificate -eq $true } -Exactly 2
    }

    It 'passes Encrypt = Mandatory when specified' {
      Initialize-SqlServiceLogin `
        -SqlInstance $script:instance `
        -DatabaseName $script:database `
        -ServiceAccount $script:account `
        -Encrypt Mandatory | Out-Null
      Should -Invoke Invoke-Sqlcmd `
        -ParameterFilter { $Encrypt -eq 'Mandatory' } -Exactly 2
    }
  }

  # -------------------------------------------------------------------------
  Context '-WhatIf suppresses SQL execution' {

    BeforeEach {
      Mock -CommandName Invoke-Sqlcmd -MockWith { }
    }

    It 'returns Status = WhatIf' {
      $result = Initialize-SqlServiceLogin `
        -SqlInstance $script:instance `
        -DatabaseName $script:database `
        -ServiceAccount $script:account `
        -WhatIf
      $result.Status | Should -Be 'WhatIf'
    }

    It 'does NOT call Invoke-Sqlcmd' {
      Initialize-SqlServiceLogin `
        -SqlInstance $script:instance `
        -DatabaseName $script:database `
        -ServiceAccount $script:account `
        -WhatIf | Out-Null
      Should -Invoke Invoke-Sqlcmd -Exactly 0
    }
  }

  # -------------------------------------------------------------------------
  Context 'Error handling — first Invoke-Sqlcmd throws' {

    BeforeEach {
      Mock -CommandName Invoke-Sqlcmd -MockWith {
        throw [System.Exception]'Cannot connect to SQL Server'
      }
    }

    It 're-throws the exception' {
      {
        Initialize-SqlServiceLogin `
          -SqlInstance $script:instance `
          -DatabaseName $script:database `
          -ServiceAccount $script:account
      } | Should -Throw 'Cannot connect to SQL Server'
    }
  }

  # -------------------------------------------------------------------------
  Context 'SQL query content — login batch contains expected identifiers' {

    It 'login query contains the escaped service account name' {
      $capturedQuery = $null
      Mock -CommandName Invoke-Sqlcmd -MockWith {
        param($Query, $Database)
        if ($Database -eq 'master') { $script:capturedLoginQuery = $Query }
      }

      Initialize-SqlServiceLogin `
        -SqlInstance $script:instance `
        -DatabaseName $script:database `
        -ServiceAccount $script:account | Out-Null

      $script:capturedLoginQuery | Should -Match ([regex]::Escape($script:account))
    }

    It 'login query contains CREATE LOGIN' {
      Mock -CommandName Invoke-Sqlcmd -MockWith {
        param($Query, $Database)
        if ($Database -eq 'master') { $script:capturedLoginQuery = $Query }
      }

      Initialize-SqlServiceLogin `
        -SqlInstance $script:instance `
        -DatabaseName $script:database `
        -ServiceAccount $script:account | Out-Null

      $script:capturedLoginQuery | Should -Match 'CREATE LOGIN'
    }

    It 'user query contains ALTER ROLE db_owner ADD MEMBER' {
      Mock -CommandName Invoke-Sqlcmd -MockWith {
        param($Query, $Database)
        if ($Database -eq $script:database) { $script:capturedUserQuery = $Query }
      }

      Initialize-SqlServiceLogin `
        -SqlInstance $script:instance `
        -DatabaseName $script:database `
        -ServiceAccount $script:account | Out-Null

      $script:capturedUserQuery | Should -Match 'ALTER ROLE \[db_owner\] ADD MEMBER'
    }
  }

  # -------------------------------------------------------------------------
  Context 'Single-quote in ServiceAccount is escaped (SQL injection resistance)' {

    BeforeEach {
      Mock -CommandName Invoke-Sqlcmd -MockWith { }
    }

    It 'does not throw when ServiceAccount contains a single quote' {
      # Simulate a pathological name; QUOTENAME protects the EXEC, doubling protects DECLARE
      {
        Initialize-SqlServiceLogin `
          -SqlInstance $script:instance `
          -DatabaseName $script:database `
          -ServiceAccount "HOST\Svc'Test"
      } | Should -Not -Throw
    }
  }
}
