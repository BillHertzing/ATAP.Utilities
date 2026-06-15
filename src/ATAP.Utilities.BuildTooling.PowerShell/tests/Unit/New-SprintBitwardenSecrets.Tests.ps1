BeforeAll {
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
  }

  # Mock the Bitwarden Secrets Manager CLI (SC-0175: sprint automation uses
  # bws + machine access token; never bw/BW_SESSION).
  function global:bws {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)

    [void]$script:bwsCalls.Add(($Arguments -join ' '))
    $global:LASTEXITCODE = 0

    if ($Arguments.Count -ge 2 -and $Arguments[0] -eq 'project' -and $Arguments[1] -eq 'list') {
      return @([PSCustomObject]@{ id = 'proj-ci-shared'; name = 'CI-Shared' }) | ConvertTo-Json -Compress -AsArray
    }
    if ($Arguments.Count -ge 2 -and $Arguments[0] -eq 'secret' -and $Arguments[1] -eq 'list') {
      return $script:bwsSecretInventory | ConvertTo-Json -Compress -AsArray
    }
    if ($Arguments.Count -ge 2 -and $Arguments[0] -eq 'secret' -and $Arguments[1] -eq 'create') {
      return '{"id":"new-secret-id"}'
    }

    return ''
  }

  # The descriptor helper (single source of truth for format + classification).
  . "$PSScriptRoot\..\..\public\Get-DbConnectionStringSecretDescriptor.ps1"
  . "$PSScriptRoot\..\..\public\New-SprintBitwardenSecrets.ps1"
}

Describe 'New-SprintBitwardenSecrets [public]' {
  BeforeEach {
    $script:bwsCalls = [System.Collections.ArrayList]::new()
    $script:bwsSecretInventory = @()
    # Acceptance (Task 8.10): sprint automation must run without BW_SESSION.
    $script:oldBwSession = $env:BW_SESSION
    Remove-Item Env:BW_SESSION -ErrorAction SilentlyContinue
    $script:oldBwsToken = $env:BWS_ACCESS_TOKEN
    $env:BWS_ACCESS_TOKEN = 'test-machine-token'
  }

  AfterEach {
    if ($null -ne $script:oldBwSession) { $env:BW_SESSION = $script:oldBwSession }
    if ($null -ne $script:oldBwsToken) { $env:BWS_ACCESS_TOKEN = $script:oldBwsToken } else { Remove-Item Env:BWS_ACCESS_TOKEN -ErrorAction SilentlyContinue }
  }

  Context 'default — derive without vault write (Task 9.22)' {
    It 'derives one descriptor per (database, host, tier) with the canonical name and no vault write' {
      $result = New-SprintBitwardenSecrets `
        -SprintNumber '0008' `
        -DeveloperUsername 'tester' `
        -HostList @('localhost') `
        -Databases @('master') `
        -Confirm:$false

      $result.Count | Should -Be 2
      $result.derived | Should -Be @($true, $true)
      $result.created | Should -Be @($false, $false)
      $result.classification | Should -Be @('derivable', 'derivable')
      $result.secretName | Should -Be @(
        'dbConnectionString-master-localhost-Dev-tester',
        'dbConnectionString-master-localhost-Exp-tester'
      )
    }

    It 'makes no bws calls at all on the default derive path' {
      New-SprintBitwardenSecrets `
        -SprintNumber '0008' `
        -DeveloperUsername 'tester' `
        -HostList @('localhost') `
        -Databases @('master') `
        -Confirm:$false | Out-Null

      $script:bwsCalls.Count | Should -Be 0
    }

    It 'derives successfully even when no BWS access token is present' {
      Remove-Item Env:BWS_ACCESS_TOKEN -ErrorAction SilentlyContinue

      $result = New-SprintBitwardenSecrets `
        -SprintNumber '0008' `
        -DeveloperUsername 'tester' `
        -HostList @('localhost') `
        -Databases @('master') `
        -Confirm:$false

      $result.derived | Should -Be @($true, $true)
      $script:bwsCalls.Count | Should -Be 0
    }
  }

  Context '-WriteDerivableToVault — persist to the vault' {
    It 'creates one BWS secret per (database, host, tier) with the canonical hyphenated name' {
      $result = New-SprintBitwardenSecrets `
        -SprintNumber '0008' `
        -DeveloperUsername 'tester' `
        -HostList @('localhost') `
        -Databases @('master') `
        -WriteDerivableToVault `
        -Confirm:$false

      $result.Count | Should -Be 2
      $result.created | Should -Be @($true, $true)
      $result.secretName | Should -Be @(
        'dbConnectionString-master-localhost-Dev-tester',
        'dbConnectionString-master-localhost-Exp-tester'
      )
      $createCalls = @($script:bwsCalls | Where-Object { $_ -like 'secret create *' })
      $createCalls.Count | Should -Be 2
      $createCalls[0] | Should -Match 'proj-ci-shared'
    }

    It 'runs entirely on bws with no BW_SESSION present' {
      $env:BW_SESSION | Should -BeNullOrEmpty
      $result = New-SprintBitwardenSecrets `
        -SprintNumber '0008' `
        -DeveloperUsername 'tester' `
        -HostList @('localhost') `
        -Databases @('master') `
        -WriteDerivableToVault `
        -Confirm:$false

      $result.created | Should -Be @($true, $true)
      @($script:bwsCalls | Where-Object { $_ -like 'project list*' }).Count | Should -Be 1
    }

    It 'skips creation when the secret key already exists (idempotency)' {
      $script:bwsSecretInventory = @(
        [PSCustomObject]@{ id = 'id-dev'; key = 'dbConnectionString-master-localhost-Dev-tester' }
      )
      $result = New-SprintBitwardenSecrets `
        -SprintNumber '0008' `
        -DeveloperUsername 'tester' `
        -HostList @('localhost') `
        -Databases @('master') `
        -WriteDerivableToVault `
        -Confirm:$false

      @($result | Where-Object { $_.alreadyExists }).Count | Should -Be 1
      @($result | Where-Object { $_.created }).Count | Should -Be 1
      @($script:bwsCalls | Where-Object { $_ -like 'secret create *' }).Count | Should -Be 1
    }

    It 'WhatIf prevents secret creation' {
      New-SprintBitwardenSecrets `
        -SprintNumber '0008' `
        -DeveloperUsername 'tester' `
        -HostList @('localhost') `
        -Databases @('master') `
        -WriteDerivableToVault `
        -WhatIf | Out-Null

      @($script:bwsCalls | Where-Object { $_ -like 'secret create *' }).Count | Should -Be 0
    }

    It 'honors an explicit -ProjectId without calling bws project list' {
      $result = New-SprintBitwardenSecrets `
        -SprintNumber '0008' `
        -DeveloperUsername 'tester' `
        -HostList @('localhost') `
        -Databases @('master') `
        -WriteDerivableToVault `
        -ProjectId 'explicit-proj-id' `
        -Confirm:$false

      $result.created | Should -Be @($true, $true)
      @($script:bwsCalls | Where-Object { $_ -like 'project list*' }).Count | Should -Be 0
      @($script:bwsCalls | Where-Object { $_ -like '*explicit-proj-id*' }).Count | Should -Be 2
    }
  }
}
