#Requires -Version 7.0
# Pester 5+ tests for Task 10.7 BWS-only connection-string resolution in
# Resolve-DatabaseSqlConnectionFromDBConnectionStringSecretName.
# These mock the connection-opening helper so no SQL Server is required.

BeforeAll {
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
  }

  $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $privateDir = Join-Path $moduleRoot 'private'
  . (Join-Path $privateDir 'DatabaseSqlConnection.Helpers.ps1')

  # The descriptor helper remains available for diagnostics/legacy callers, but
  # runtime connection opening must not use it to derive missing secrets.
  #
  # Resolve it by SEARCHING the BuildTooling family rather than pinning the parent's
  # public folder. Task 13.72.4 moved this function into the Secrets child, which broke
  # this dot-source and failed all six tests in this file. Any single hard-coded module
  # folder goes stale at the next extraction, so probe every family member.
  $srcRoot = Split-Path -Parent $moduleRoot
  $descriptorName = 'Get-DbConnectionStringSecretDescriptor.ps1'
  $descriptorPath = Get-ChildItem -LiteralPath $srcRoot -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like 'ATAP.Utilities.BuildTooling.*' } |
    ForEach-Object { Join-Path $_.FullName "public\$descriptorName" } |
    Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
    Select-Object -First 1
  if (-not $descriptorPath) {
    throw "$descriptorName was not found under any $srcRoot\ATAP.Utilities.BuildTooling.*\public folder."
  }
  . $descriptorPath

  # Stub Get-SecretATAP so the per-test Mock has a command to replace.
  function global:Get-SecretATAP { param($SecretName, $SecretField, $SecretStoreType) }
}

Describe 'Resolve-DatabaseSqlConnectionFromDBConnectionStringSecretName - BWS-only resolution' -Tag 'Unit' {
  BeforeEach {
    # Capture the opened connection string + source without touching SQL Server.
    Mock New-DatabaseSqlConnectionFromConnectionString {
      [pscustomobject]@{ ConnectionString = $ConnectionString; Source = $Source }
    }
  }

  It 'uses the BWS vault secret when present' {
    Mock Get-SecretATAP { 'Server=fromvault;Database=ATAPUtilities;Integrated Security=True;' }

    $r = Resolve-DatabaseSqlConnectionFromDBConnectionStringSecretName `
      -SecretName 'dbConnectionString-ATAPUtilities-localhost-Dev-jsmith'

    $r.ConnectionString | Should -Be 'Server=fromvault;Database=ATAPUtilities;Integrated Security=True;'
    $r.Source | Should -Match 'notes field'
    Should -Invoke Get-SecretATAP -Times 1 -ParameterFilter {
      $SecretName -eq 'dbConnectionString-ATAPUtilities-localhost-Dev-jsmith' -and
      $SecretField -eq 'notes' -and
      $SecretStoreType -eq 'BitwardenSecretsManager'
    }
  }

  It 'hard-fails for a Dev name when the BWS lookup throws' {
    Mock Get-SecretATAP { throw 'Secret not found' }

    { Resolve-DatabaseSqlConnectionFromDBConnectionStringSecretName `
        -SecretName 'dbConnectionString-ATAPUtilities-localhost-Dev-jsmith' } |
      Should -Throw '*Bitwarden Secrets Manager*Secret not found*'
    Should -Invoke New-DatabaseSqlConnectionFromConnectionString -Times 0
  }

  It 'hard-fails for an Exp name when BWS returns an empty value' {
    Mock Get-SecretATAP { '' }

    { Resolve-DatabaseSqlConnectionFromDBConnectionStringSecretName `
        -SecretName 'dbConnectionString-master-localhost-Exp-tester' } |
      Should -Throw '*Bitwarden Secrets Manager*'
    Should -Invoke New-DatabaseSqlConnectionFromConnectionString -Times 0
  }

  It 'throws when BWS returns multiple values for one secret' {
    Mock Get-SecretATAP { @('first', 'second') }

    { Resolve-DatabaseSqlConnectionFromDBConnectionStringSecretName `
        -SecretName 'dbConnectionString-ATAPUtilities-localhost-Dev-jsmith' } |
      Should -Throw '*returned multiple values*'
    Should -Invoke New-DatabaseSqlConnectionFromConnectionString -Times 0
  }

  It 'throws when BWS returns a non-string value for one secret' {
    Mock Get-SecretATAP { [pscustomobject]@{ value = 'not-a-string' } }

    { Resolve-DatabaseSqlConnectionFromDBConnectionStringSecretName `
        -SecretName 'dbConnectionString-ATAPUtilities-localhost-Dev-jsmith' } |
      Should -Throw '*Expected a string*'
    Should -Invoke New-DatabaseSqlConnectionFromConnectionString -Times 0
  }

  It 'reads both Dev and Exp connection strings from BWS' {
    Mock Get-SecretATAP {
      "Server=from-bws;Database=$SecretName;Integrated Security=True;"
    }

    foreach ($secretName in @(
        'dbConnectionString-ATAPUtilities-localhost-Dev-jsmith',
        'dbConnectionString-ATAPUtilities-localhost-Exp-jsmith'
      )) {
      $r = Resolve-DatabaseSqlConnectionFromDBConnectionStringSecretName -SecretName $secretName
      $r.ConnectionString | Should -Match 'Server=from-bws'
      $r.Source | Should -Match 'notes field'
    }

    Should -Invoke Get-SecretATAP -Times 2 -ParameterFilter {
      $SecretStoreType -eq 'BitwardenSecretsManager'
    }
  }
}
