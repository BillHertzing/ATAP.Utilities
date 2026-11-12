Describe 'Invoke-ParityNativeCommand stream separation' -Tag 'Unit' {
  BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..\..\ATAP.Utilities.SystemParityMonitor.PowerShell.psd1'
    Import-Module -Name $modulePath -Force
    $script:pwshPath = (Get-Process -Id $PID).Path
  }

  It 'keeps stdout JSON clean and puts the stderr notice in ErrorOutput' {
    $r = InModuleScope 'ATAP.Utilities.SystemParityMonitor.PowerShell' -Parameters @{ p = $script:pwshPath } {
      param($p)
      Invoke-ParityNativeCommand -Command $p -ArgumentList @('-Command', "[Console]::Out.WriteLine('{""a"":1}'); [Console]::Error.WriteLine('npm notice New major version'); exit 0")
    }
    $r.ExitCode | Should -Be 0
    ($r.Output -join '') | Should -Be '{"a":1}'
    { ($r.Output -join "`n") | ConvertFrom-Json -ErrorAction Stop } | Should -Not -Throw
    ($r.ErrorOutput -join '') | Should -Be 'npm notice New major version'
  }

  It 'preserves a non-zero exit code and empty ErrorOutput when stderr is silent' {
    $r = InModuleScope 'ATAP.Utilities.SystemParityMonitor.PowerShell' -Parameters @{ p = $script:pwshPath } {
      param($p)
      Invoke-ParityNativeCommand -Command $p -ArgumentList @('-Command', 'exit 7')
    }
    $r.ExitCode | Should -Be 7
    @($r.ErrorOutput).Count | Should -Be 0
  }

  It 'reports a non-zero exit code alongside stderr text' {
    $r = InModuleScope 'ATAP.Utilities.SystemParityMonitor.PowerShell' -Parameters @{ p = $script:pwshPath } {
      param($p)
      Invoke-ParityNativeCommand -Command $p -ArgumentList @('-Command', "[Console]::Error.WriteLine('boom'); exit 3")
    }
    $r.ExitCode | Should -Be 3
    ($r.ErrorOutput -join '') | Should -Be 'boom'
    @($r.Output).Count | Should -Be 0
  }
}
