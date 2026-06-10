BeforeAll {
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
  }

  function global:bw {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)

    [void]$script:bwCalls.Add(($Arguments -join ' '))
    $global:LASTEXITCODE = 0

    if ($Arguments.Count -ge 4 -and $Arguments[0] -eq 'list' -and $Arguments[1] -eq 'items') {
      $secretName = $Arguments[3]
      return @([PSCustomObject]@{
          id   = "id-$secretName"
          name = $secretName
        }) | ConvertTo-Json -Compress
    }

    return ''
  }

  . "$PSScriptRoot\..\..\public\Remove-SprintBitwardenSecrets.ps1"
}

Describe 'Remove-SprintBitwardenSecrets [public]' {
  BeforeEach {
    $script:bwCalls = [System.Collections.ArrayList]::new()
    $script:oldBwSession = $env:BW_SESSION
    $env:BW_SESSION = 'test-session'
  }

  AfterEach {
    $env:BW_SESSION = $script:oldBwSession
  }

  It 'Force suppresses high-impact confirmation and deletes without Confirm false' {
    $result = Remove-SprintBitwardenSecrets `
      -DeveloperUsername 'tester' `
      -HostList @('localhost') `
      -Databases @('master') `
      -Force

    $result.Count | Should -Be 2
    $result.deleted | Should -Be @($true, $true)
    @($script:bwCalls | Where-Object { $_ -like 'delete item *' }).Count | Should -Be 2
    @($script:bwCalls | Where-Object { $_ -like 'sync *' }).Count | Should -Be 1
  }

  It 'WhatIf still prevents deletion when Force is supplied' {
    Remove-SprintBitwardenSecrets `
      -DeveloperUsername 'tester' `
      -HostList @('localhost') `
      -Databases @('master') `
      -Force `
      -WhatIf | Out-Null

    @($script:bwCalls | Where-Object { $_ -like 'delete item *' }).Count | Should -Be 0
    @($script:bwCalls | Where-Object { $_ -like 'sync *' }).Count | Should -Be 0
  }
}
