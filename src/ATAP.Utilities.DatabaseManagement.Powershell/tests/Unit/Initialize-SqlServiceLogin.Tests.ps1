# Initialize-SqlServiceLogin.Tests.ps1
# Unit tests for Initialize-SqlServiceLogin

Describe 'Initialize-SqlServiceLogin' -Tag 'Unit' {

  BeforeAll {
    $publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
    . (Join-Path $publicDir 'Initialize-SqlServiceLogin.ps1')

    Write-PSFMessage -Level Debug -Message 'Starting Initialize-SqlServiceLogin tests' -Tag 'Trace', 'Tests'

    $script:instance = 'localhost\Production'
    $script:database = 'ProGet'
    $script:account = 'TESTHOST\SvcProGet'
  }

  # -------------------------------------------------------------------------
  Context 'Success path - Invoke-DbaQuery succeeds for both batches' {

    BeforeEach {
      Mock -CommandName Invoke-DbaQuery -MockWith { }
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

    It 'calls Invoke-DbaQuery exactly twice (login batch + user/role batch)' {
      Initialize-SqlServiceLogin `
        -SqlInstance $script:instance `
        -DatabaseName $script:database `
        -ServiceAccount $script:account | Out-Null
      Should -Invoke Invoke-DbaQuery -Exactly 2
    }

    It 'first Invoke-DbaQuery call targets master database' {
      Initialize-SqlServiceLogin `
        -SqlInstance $script:instance `
        -DatabaseName $script:database `
        -ServiceAccount $script:account | Out-Null
      Should -Invoke Invoke-DbaQuery -ParameterFilter { $Database -eq 'master' } -Exactly 1
    }

    It 'second Invoke-DbaQuery call targets the application database' {
      Initialize-SqlServiceLogin `
        -SqlInstance $script:instance `
        -DatabaseName $script:database `
        -ServiceAccount $script:account | Out-Null
      Should -Invoke Invoke-DbaQuery -ParameterFilter { $Database -eq $script:database } -Exactly 1
    }

    It 'passes Trust Server Certificate = True in the appended connection string when switch is specified' {
      Initialize-SqlServiceLogin `
        -SqlInstance $script:instance `
        -DatabaseName $script:database `
        -ServiceAccount $script:account `
        -TrustServerCertificate | Out-Null
      Should -Invoke Invoke-DbaQuery `
        -ParameterFilter { $AppendConnectionString -match 'Trust Server Certificate=True' } -Exactly 2
    }

    It 'passes Encrypt = Mandatory when specified' {
      Initialize-SqlServiceLogin `
        -SqlInstance $script:instance `
        -DatabaseName $script:database `
        -ServiceAccount $script:account `
        -Encrypt Mandatory | Out-Null
      Should -Invoke Invoke-DbaQuery `
        -ParameterFilter { $AppendConnectionString -match 'Encrypt=Mandatory' } -Exactly 2
    }

    It 'enables dbatools exceptions so failures are caught by the cmdlet try/catch' {
      Initialize-SqlServiceLogin `
        -SqlInstance $script:instance `
        -DatabaseName $script:database `
        -ServiceAccount $script:account | Out-Null
      Should -Invoke Invoke-DbaQuery `
        -ParameterFilter { $EnableException -eq $true -and $ErrorAction -eq 'Stop' } -Exactly 2
    }
  }

  # -------------------------------------------------------------------------
  Context '-WhatIf suppresses SQL execution' {

    BeforeEach {
      Mock -CommandName Invoke-DbaQuery -MockWith { }
    }

    It 'returns Status = WhatIf' {
      $result = Initialize-SqlServiceLogin `
        -SqlInstance $script:instance `
        -DatabaseName $script:database `
        -ServiceAccount $script:account `
        -WhatIf
      $result.Status | Should -Be 'WhatIf'
    }

    It 'does NOT call Invoke-DbaQuery' {
      Initialize-SqlServiceLogin `
        -SqlInstance $script:instance `
        -DatabaseName $script:database `
        -ServiceAccount $script:account `
        -WhatIf | Out-Null
      Should -Invoke Invoke-DbaQuery -Exactly 0
    }
  }

  # -------------------------------------------------------------------------
  Context 'Error handling - first Invoke-DbaQuery throws' {

    BeforeEach {
      Mock -CommandName Invoke-DbaQuery -MockWith {
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
      Mock -CommandName Invoke-DbaQuery -MockWith {
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
      Mock -CommandName Invoke-DbaQuery -MockWith {
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
      Mock -CommandName Invoke-DbaQuery -MockWith {
        param($Query, $Database)
        if ($Database -eq $script:database) { $script:capturedUserQuery = $Query }
      }

      Initialize-SqlServiceLogin `
        -SqlInstance $script:instance `
        -DatabaseName $script:database `
        -ServiceAccount $script:account | Out-Null

      $script:capturedUserQuery | Should -Match 'ALTER ROLE \[db_owner\] ADD MEMBER'
    }

    It 'finds an existing database user by login SID before creating a short-name user' {
      Mock -CommandName Invoke-DbaQuery -MockWith {
        param($Query, $Database)
        if ($Database -eq $script:database) { $script:capturedUserQuery = $Query }
      }

      Initialize-SqlServiceLogin `
        -SqlInstance $script:instance `
        -DatabaseName $script:database `
        -ServiceAccount $script:account | Out-Null

      $script:capturedUserQuery | Should -Match 'SUSER_SID\(@login\)'
      $script:capturedUserQuery | Should -Match 'IF @mappedUser IS NULL'
    }

    It 'grants db_owner to the actual SID-mapped username' {
      Mock -CommandName Invoke-DbaQuery -MockWith {
        param($Query, $Database)
        if ($Database -eq $script:database) { $script:capturedUserQuery = $Query }
      }

      Initialize-SqlServiceLogin `
        -SqlInstance $script:instance `
        -DatabaseName $script:database `
        -ServiceAccount $script:account | Out-Null

      $script:capturedUserQuery | Should -Match 'QUOTENAME\(@mappedUser\)'
      $script:capturedUserQuery | Should -Match 'memberPrincipal\.\[name\] = @mappedUser'
    }
  }

  # -------------------------------------------------------------------------
  Context 'Single-quote in ServiceAccount is escaped (SQL injection resistance)' {

    BeforeEach {
      Mock -CommandName Invoke-DbaQuery -MockWith { }
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
  # -------------------------------------------------------------------------
  Context 'DBConnectionStringSecretName path uses the resolved SQL connection' {

    BeforeEach {
      function New-FakeSqlConnection {
        param(
          [string] $DataSource
        )

        $connection = [pscustomobject]@{
          DataSource = $DataSource
          CommandLog = [System.Collections.Generic.List[string]]::new()
        }
        $connection | Add-Member -MemberType ScriptMethod -Name CreateCommand -Value {
          $command = [pscustomobject]@{
            CommandText = $null
            ParentConnection = $this
          }
          $command | Add-Member -MemberType ScriptMethod -Name ExecuteNonQuery -Value {
            $this.ParentConnection.CommandLog.Add($this.CommandText) | Out-Null
            return 1
          }
          return $command
        }
        $connection | Add-Member -MemberType ScriptMethod -Name Close -Value { }
        $connection | Add-Member -MemberType ScriptMethod -Name Dispose -Value { }
        return $connection
      }

      $script:resolvedSecretName = $null
      $script:fakeConnection = New-FakeSqlConnection -DataSource 'secret-host\Production'

      Mock -CommandName Resolve-DatabaseSqlConnection -MockWith {
        param(
          $OriginalPSBoundParameters,
          $SqlConnection,
          $DBConnectionStringSecretName,
          $DatabaseName
        )

        $script:resolvedSecretName = $DBConnectionStringSecretName
        [pscustomobject]@{
          Connection    = $script:fakeConnection
          IsCallerOwned = $false
        }
      }
    }

    It 'accepts DBConnectionStringSecretName and returns Success' {
      $result = Initialize-SqlServiceLogin `
        -DBConnectionStringSecretName 'DB_SECRET_NAME' `
        -DatabaseName $script:database `
        -ServiceAccount $script:account

      $result.Status | Should -Be 'Success'
      $script:resolvedSecretName | Should -Be 'DB_SECRET_NAME'
    }

    It 'echoes SqlInstance from the resolved connection when using DBConnectionStringSecretName' {
      $result = Initialize-SqlServiceLogin `
        -DBConnectionStringSecretName 'DB_SECRET_NAME' `
        -DatabaseName $script:database `
        -ServiceAccount $script:account

      $result.SqlInstance | Should -Be 'secret-host\Production'
    }

    It 'executes both login and user batches through the resolved connection' {
      Initialize-SqlServiceLogin `
        -DBConnectionStringSecretName 'DB_SECRET_NAME' `
        -DatabaseName $script:database `
        -ServiceAccount $script:account | Out-Null

      $script:fakeConnection.CommandLog.Count | Should -Be 2
      $script:fakeConnection.CommandLog[0] | Should -Match 'CREATE LOGIN'
      $script:fakeConnection.CommandLog[1] | Should -Match 'ALTER ROLE \[db_owner\] ADD MEMBER'
    }

    It 'supports DBConnectionStringSecretName when targeting master' {
      $masterConnection = New-FakeSqlConnection -DataSource 'secret-host\Production'
      Mock -CommandName Resolve-DatabaseSqlConnection -MockWith {
        [pscustomobject]@{
          Connection    = $masterConnection
          IsCallerOwned = $false
        }
      }

      $result = Initialize-SqlServiceLogin `
        -DBConnectionStringSecretName 'MASTER_SECRET_NAME' `
        -DatabaseName 'master' `
        -ServiceAccount $script:account

      $result.Status | Should -Be 'Success'
      $masterConnection.CommandLog.Count | Should -Be 2
      $masterConnection.CommandLog[0] | Should -Match 'USE \[master\]'
      $masterConnection.CommandLog[1] | Should -Match 'USE \[master\]'
    }
  }
}

