Describe 'Profiled remoting endpoint host selection' {
  BeforeAll {
    $moduleRoot = Split-Path -Path $PSScriptRoot -Parent | Split-Path -Parent
    $registerPath = Join-Path $moduleRoot 'public\Register-ProfiledRemotingEndpoint.ps1'
    $unregisterPath = Join-Path $moduleRoot 'public\Unregister-ProfiledRemotingEndpoint.ps1'
    $registerSource = Get-Content -LiteralPath $registerPath -Raw
    $unregisterSource = Get-Content -LiteralPath $unregisterPath -Raw
  }

  It 'starts remote registration with an explicit PowerShell 7 executable' {
    $registerSource | Should -Match 'RemotePowerShellExecutablePath'
    $registerSource | Should -Match 'Start-Process -FilePath \$PwshPath'
    $registerSource | Should -Match 'WriteAllBytes\(\$StagingPath'
    $registerSource | Should -Match 'PSVersion" Value="5\\.1"'
    $registerSource | Should -Not -Match 'Copy-Item -Path \$Path -Destination \$RemoteStagingPath -ToSession'
  }

  It 'starts remote rollback with an explicit PowerShell 7 executable' {
    $unregisterSource | Should -Match 'RemotePowerShellExecutablePath'
    $unregisterSource | Should -Match 'Start-Process -FilePath \$PwshPath'
  }
}
