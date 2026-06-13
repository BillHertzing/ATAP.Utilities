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

    if ($Arguments.Count -ge 2 -and $Arguments[0] -eq 'secret' -and $Arguments[1] -eq 'list') {
      return $script:bwsSecretInventory | ConvertTo-Json -Compress -AsArray
    }

    return ''
  }

  . "$PSScriptRoot\..\..\public\Remove-SprintBitwardenSecrets.ps1"
}

Describe 'Remove-SprintBitwardenSecrets [public]' {
  BeforeEach {
    $script:bwsCalls = [System.Collections.ArrayList]::new()
    $script:bwsSecretInventory = @(
      [PSCustomObject]@{ id = 'id-dev'; key = 'dbConnectionString-master-localhost-Dev-tester' }
      [PSCustomObject]@{ id = 'id-exp'; key = 'dbConnectionString-master-localhost-Exp-tester' }
      [PSCustomObject]@{ id = 'id-other'; key = 'BuildMaster.Admin.API.Key' }
    )
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

  It 'Force suppresses high-impact confirmation and deletes without Confirm false' {
    $result = Remove-SprintBitwardenSecrets `
      -DeveloperUsername 'tester' `
      -HostList @('localhost') `
      -Databases @('master') `
      -Force

    $result.Count | Should -Be 2
    $result.deleted | Should -Be @($true, $true)
    @($script:bwsCalls | Where-Object { $_ -like 'secret delete *' }).Count | Should -Be 2
  }

  It 'Runs entirely on bws with no BW_SESSION present' {
    $env:BW_SESSION | Should -BeNullOrEmpty
    $result = Remove-SprintBitwardenSecrets `
      -DeveloperUsername 'tester' `
      -HostList @('localhost') `
      -Databases @('master') `
      -Force

    $result.deleted | Should -Be @($true, $true)
    @($script:bwsCalls | Where-Object { $_ -like 'secret list*' }).Count | Should -Be 1
  }

  It 'Marks a secret skipped when it is not in the BWS inventory' {
    $script:bwsSecretInventory = @(
      [PSCustomObject]@{ id = 'id-dev'; key = 'dbConnectionString-master-localhost-Dev-tester' }
    )
    $result = Remove-SprintBitwardenSecrets `
      -DeveloperUsername 'tester' `
      -HostList @('localhost') `
      -Databases @('master') `
      -Force

    @($result | Where-Object { $_.deleted }).Count | Should -Be 1
    @($result | Where-Object { $_.skipped }).Count | Should -Be 1
    @($script:bwsCalls | Where-Object { $_ -like 'secret delete *' }).Count | Should -Be 1
  }

  It 'WhatIf still prevents deletion when Force is supplied' {
    Remove-SprintBitwardenSecrets `
      -DeveloperUsername 'tester' `
      -HostList @('localhost') `
      -Databases @('master') `
      -Force `
      -WhatIf | Out-Null

    @($script:bwsCalls | Where-Object { $_ -like 'secret delete *' }).Count | Should -Be 0
  }
}
