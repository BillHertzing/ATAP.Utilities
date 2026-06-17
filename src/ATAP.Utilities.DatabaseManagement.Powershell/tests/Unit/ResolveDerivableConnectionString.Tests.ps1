#Requires -Version 7.0
# Pester 5+ tests for the Task 9.22 layered resolution of a connection-string
# secret in Resolve-DatabaseSqlConnectionFromDBConnectionStringSecretName:
#   (a) real vault secret  ->  (b) deterministic derive  ->  (c) hard fail.
# These mock the connection-opening helper so no SQL Server is required.

BeforeAll {
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
  }

  $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $privateDir = Join-Path $moduleRoot 'private'
  . (Join-Path $privateDir 'DatabaseSqlConnection.Helpers.ps1')

  # The single source of truth for format + classification lives in BuildTooling.
  $srcRoot = Split-Path -Parent $moduleRoot
  . (Join-Path $srcRoot 'ATAP.Utilities.BuildTooling.PowerShell\public\Get-DbConnectionStringSecretDescriptor.ps1')

  # Stub Get-SecretATAP so the per-test Mock has a command to replace.
  function global:Get-SecretATAP { param($SecretName, $SecretField) }
}

Describe 'Resolve-DatabaseSqlConnectionFromDBConnectionStringSecretName — layered resolution' -Tag 'Unit' {
  BeforeEach {
    # Capture the opened connection string + source without touching SQL Server.
    Mock New-DatabaseSqlConnectionFromConnectionString {
      [pscustomobject]@{ ConnectionString = $ConnectionString; Source = $Source }
    }
  }

  It '(a) uses the real vault secret when present' {
    Mock Get-SecretATAP { 'Server=fromvault;Database=ATAPUtilities;Integrated Security=True;' }

    $r = Resolve-DatabaseSqlConnectionFromDBConnectionStringSecretName `
      -SecretName 'dbConnectionString-ATAPUtilities-localhost-Dev-jsmith'

    $r.ConnectionString | Should -Be 'Server=fromvault;Database=ATAPUtilities;Integrated Security=True;'
    $r.Source | Should -Match 'notes field'
  }

  It '(b) derives deterministically when the vault read throws and the name is derivable' {
    Mock Get-SecretATAP { throw 'Secret not found' }

    $r = Resolve-DatabaseSqlConnectionFromDBConnectionStringSecretName `
      -SecretName 'dbConnectionString-ATAPUtilities-localhost-Dev-jsmith'

    $r.ConnectionString | Should -BeExactly `
      'Server=localhost\Devjsmith;Database=ATAPUtilities;Integrated Security=True;MultipleActiveResultSets=True;TrustServerCertificate=True;'
    $r.Source | Should -Match 'deterministic fallback'
  }

  It '(b) derives when the vault returns an empty value' {
    Mock Get-SecretATAP { '' }

    $r = Resolve-DatabaseSqlConnectionFromDBConnectionStringSecretName `
      -SecretName 'dbConnectionString-master-localhost-Exp-tester'

    $r.ConnectionString | Should -BeExactly `
      'Server=localhost\Exptester;Database=master;Integrated Security=True;MultipleActiveResultSets=True;TrustServerCertificate=True;'
    $r.Source | Should -Match 'deterministic fallback'
  }

  It '(c) hard-fails when a credentialed secret is absent (never derives)' {
    Mock Get-SecretATAP { throw 'Secret not found' }

    { Resolve-DatabaseSqlConnectionFromDBConnectionStringSecretName `
        -SecretName 'dbConnectionString-ATAPUtilities-sql01-Production' } |
      Should -Throw '*not derivable*'
  }

  It 'prefers the vault value over derivation even for a derivable name' {
    Mock Get-SecretATAP { 'Server=vaultwins;Database=ATAPUtilities;Integrated Security=True;' }

    $r = Resolve-DatabaseSqlConnectionFromDBConnectionStringSecretName `
      -SecretName 'dbConnectionString-ATAPUtilities-localhost-Dev-jsmith'

    $r.ConnectionString | Should -Match 'vaultwins'
    $r.Source | Should -Match 'notes field'
  }
}
