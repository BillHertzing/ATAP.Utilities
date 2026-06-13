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

  It 'Creates one BWS secret per (database, host, tier) with the canonical hyphenated name' {
    $result = New-SprintBitwardenSecrets `
      -SprintNumber '0008' `
      -DeveloperUsername 'tester' `
      -HostList @('localhost') `
      -Databases @('master') `
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

  It 'Runs entirely on bws with no BW_SESSION present' {
    $env:BW_SESSION | Should -BeNullOrEmpty
    $result = New-SprintBitwardenSecrets `
      -SprintNumber '0008' `
      -DeveloperUsername 'tester' `
      -HostList @('localhost') `
      -Databases @('master') `
      -Confirm:$false

    $result.created | Should -Be @($true, $true)
    @($script:bwsCalls | Where-Object { $_ -like 'project list*' }).Count | Should -Be 1
  }

  It 'Skips creation when the secret key already exists (idempotency)' {
    $script:bwsSecretInventory = @(
      [PSCustomObject]@{ id = 'id-dev'; key = 'dbConnectionString-master-localhost-Dev-tester' }
    )
    $result = New-SprintBitwardenSecrets `
      -SprintNumber '0008' `
      -DeveloperUsername 'tester' `
      -HostList @('localhost') `
      -Databases @('master') `
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
      -WhatIf | Out-Null

    @($script:bwsCalls | Where-Object { $_ -like 'secret create *' }).Count | Should -Be 0
  }

  It 'Honors an explicit -ProjectId without calling bws project list' {
    $result = New-SprintBitwardenSecrets `
      -SprintNumber '0008' `
      -DeveloperUsername 'tester' `
      -HostList @('localhost') `
      -Databases @('master') `
      -ProjectId 'explicit-proj-id' `
      -Confirm:$false

    $result.created | Should -Be @($true, $true)
    @($script:bwsCalls | Where-Object { $_ -like 'project list*' }).Count | Should -Be 0
    @($script:bwsCalls | Where-Object { $_ -like '*explicit-proj-id*' }).Count | Should -Be 2
  }
}
