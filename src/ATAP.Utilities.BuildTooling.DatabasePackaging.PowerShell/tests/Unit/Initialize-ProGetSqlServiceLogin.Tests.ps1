BeforeAll {
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
  }

  . "$PSScriptRoot\..\..\private\BuildToolingSql.Helpers.ps1"
  . "$PSScriptRoot\..\..\public\Initialize-ProGetSqlServiceLogin.ps1"
}

Describe 'Initialize-ProGetSqlServiceLogin [public]' {
  BeforeEach {
    Mock -CommandName Resolve-BuildToolingDatabaseSqlConnection -MockWith {
      [PSCustomObject]@{
        DataSource = 'mock-sql'
        Database   = 'master'
      }
    }

    Mock -CommandName Invoke-BuildToolingSqlQuery -MockWith { 1 }
  }

  It 'resolves Bitwarden connection input and executes the idempotent login script' {
    Initialize-ProGetSqlServiceLogin `
      -DBConnectionStringSecretName 'proget-sql' `
      -DatabaseName 'ProGet' `
      -ServiceAccount 'NT SERVICE\INEDOPROGETSVC' `
      -Confirm:$false | Out-Null

    Should -Invoke -CommandName Resolve-BuildToolingDatabaseSqlConnection -Times 1 -Exactly -ParameterFilter {
      $DBConnectionStringSecretName -eq 'proget-sql' -and
      $DatabaseName -eq 'master'
    }

    Should -Invoke -CommandName Invoke-BuildToolingSqlQuery -Times 1 -Exactly -ParameterFilter {
      $As -eq 'NonQuery' -and
      $Query -match 'CREATE LOGIN' -and
      $Query -match 'ALTER ROLE \[db_owner\] ADD MEMBER'
    }
  }

  It 'honors WhatIf by resolving the connection but not executing SQL' {
    Initialize-ProGetSqlServiceLogin `
      -DBConnectionStringSecretName 'proget-sql' `
      -DatabaseName 'ProGet' `
      -WhatIf | Out-Null

    Should -Invoke -CommandName Resolve-BuildToolingDatabaseSqlConnection -Times 1 -Exactly
    Should -Invoke -CommandName Invoke-BuildToolingSqlQuery -Times 0 -Exactly
  }
}
