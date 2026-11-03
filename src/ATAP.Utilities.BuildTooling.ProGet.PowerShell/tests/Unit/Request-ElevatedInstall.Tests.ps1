#Requires -Version 7.0

BeforeAll {
  $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage {
      param([Parameter(ValueFromRemainingArguments = $true)]$rest)
    }
  }

  . (Join-Path $moduleRoot 'public\Request-ElevatedInstall.ps1')
}

Describe 'Request-ElevatedInstall missing-broker handling' {
  It 'fails closed without directing the caller to a UAC installer fallback' {
    $brokerRoot = Join-Path $TestDrive 'broker-not-provisioned'
    $errorMessage = $null

    try {
      Request-ElevatedInstall -InstallerId 'install-atap-module-allusers' -BrokerRoot $brokerRoot
    }
    catch {
      $errorMessage = $_.Exception.Message
    }

    $errorMessage | Should -Match 'not provisioned'
    $errorMessage | Should -Match 'separately authorized administrator provisioning'
    $errorMessage | Should -Match 'Do not fall back to UAC'
    $errorMessage | Should -Not -Match 'Start-Process|RunAs|single documented elevation attempt'
  }
}
