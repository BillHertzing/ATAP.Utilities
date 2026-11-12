BeforeAll {
  function script:Resolve-ParityFixtureModule {
    param(
      [Parameter(Mandatory)][string]$SourceManifest,
      [object[]]$LoadedModules=@(Get-Module -Name 'ATAP.Utilities.SystemParityMonitor.PowerShell')
    )
    if ($LoadedModules.Count -eq 0) {
      $LoadedModules=@(Import-Module -Name $SourceManifest -Force -PassThru -ErrorAction Stop)
    }
    if ($LoadedModules.Count -ne 1) {
      throw 'Ambiguous Parity test fixture: exactly one loaded module identity is required.'
    }
    return $LoadedModules[0]
  }
}

Describe 'Invoke-ParityNativeCommand stream separation' -Tag 'Unit' {
  BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..\..\ATAP.Utilities.SystemParityMonitor.PowerShell.psd1'
    $null = Resolve-ParityFixtureModule -SourceManifest $modulePath
    # cmd.exe /d skips AutoRun and never loads PowerShell profiles, so profile output cannot reach stdout.
    $script:nativeCmd = 'cmd.exe'
  }

  It 'keeps stdout JSON clean and puts the stderr notice in ErrorOutput' {
    $r = InModuleScope 'ATAP.Utilities.SystemParityMonitor.PowerShell' -Parameters @{ p = $script:nativeCmd } {
      param($p)
      Invoke-ParityNativeCommand -Command $p -ArgumentList @('/d', '/c', '(echo {"a":1})&(echo npm notice New major version)1>&2')
    }
    $r.ExitCode | Should -Be 0
    ($r.Output -join '') | Should -Be '{"a":1}'
    { ($r.Output -join "`n") | ConvertFrom-Json -ErrorAction Stop } | Should -Not -Throw
    ($r.ErrorOutput -join '') | Should -Be 'npm notice New major version'
  }

  It 'preserves a non-zero exit code and empty ErrorOutput when stderr is silent' {
    $r = InModuleScope 'ATAP.Utilities.SystemParityMonitor.PowerShell' -Parameters @{ p = $script:nativeCmd } {
      param($p)
      Invoke-ParityNativeCommand -Command $p -ArgumentList @('/d', '/c', 'exit 7')
    }
    $r.ExitCode | Should -Be 7
    @($r.ErrorOutput).Count | Should -Be 0
  }

  It 'reports a non-zero exit code alongside stderr text' {
    $r = InModuleScope 'ATAP.Utilities.SystemParityMonitor.PowerShell' -Parameters @{ p = $script:nativeCmd } {
      param($p)
      Invoke-ParityNativeCommand -Command $p -ArgumentList @('/d', '/c', '(echo boom)1>&2&exit 3')
    }
    $r.ExitCode | Should -Be 3
    ($r.ErrorOutput -join '') | Should -Be 'boom'
    @($r.Output).Count | Should -Be 0
  }
}




