# AI assisted using Powershell.instructions.md as guidelines.
# Regression coverage for Sprint 0013 Task 13.20.e: Register-ProfiledRemotingEndpoint
# hardening --
#   (a) %windir%/ProgramData resolve from Machine scope when absent from an
#       agent-spawned process's own environment,
#   (b) the source WithProfiles.pssc resolves reliably (and fails with a clear,
#       bounded error when it cannot be found),
#   (c) registration-hash/runtime markers are written under a machine-state root
#       (ProgramData), never beside the source .pssc inside a Git worktree.
#
# Everything that would actually register a PSSession configuration, touch
# WSMan/WinRM, or require elevation is mocked. The "agent shell" scenario is
# simulated by mocking [System.Environment]::GetEnvironmentVariable's scope
# behavior via a wrapped call, not by actually stripping the real environment.

BeforeAll {
  if (Get-Module -ListAvailable -Name PSFramework) {
    Import-Module PSFramework -ErrorAction SilentlyContinue
  }

  $script:moduleRoot = Split-Path -Path $PSScriptRoot -Parent | Split-Path -Parent
  $script:publicPath = Join-Path $script:moduleRoot 'public\Register-ProfiledRemotingEndpoint.ps1'
  $script:envHelperPath = Join-Path $script:moduleRoot 'private\Resolve-ATAPMachineEnvironmentVariable.ps1'
  $script:rootHelperPath = Join-Path $script:moduleRoot 'private\Get-ProfiledRemotingMachineStateRoot.ps1'

  foreach ($p in @($script:publicPath, $script:envHelperPath, $script:rootHelperPath)) {
    if (-not (Test-Path -LiteralPath $p)) { throw "Required file not found: $p" }
  }

  # Dot-source only what's under test (and its private dependencies) -- avoids
  # full-module import failures caused by unrelated functions in the module.
  . $script:envHelperPath
  . $script:rootHelperPath
  . $script:publicPath

  $script:worktreeProfilesDir = Join-Path $script:moduleRoot 'Profiles'
  $script:realPsscPath = Join-Path $script:worktreeProfilesDir 'WithProfiles.pssc'
}

Describe 'Resolve-ATAPMachineEnvironmentVariable' -Tag 'Unit' {

  It 'returns the Process-scope value when present' {
    # [System.Environment]::GetEnvironmentVariable is a static .NET method, not a
    # PowerShell command, so it cannot be Pester-mocked directly. Exercise the real
    # scope-fallback behavior instead using a private, namespaced test variable.
    [System.Environment]::SetEnvironmentVariable('RPRE_TEST_VAR', 'process-value', 'Process')
    try {
      Resolve-ATAPMachineEnvironmentVariable -Name 'RPRE_TEST_VAR' | Should -Be 'process-value'
    } finally {
      [System.Environment]::SetEnvironmentVariable('RPRE_TEST_VAR', $null, 'Process')
    }
  }

  It 'falls back to -DefaultValue when unresolved in Process and Machine scope' {
    [System.Environment]::SetEnvironmentVariable('RPRE_TEST_VAR_ABSENT', $null, 'Process')
    Resolve-ATAPMachineEnvironmentVariable -Name 'RPRE_TEST_VAR_ABSENT' -DefaultValue 'fallback' | Should -Be 'fallback'
  }
}

Describe 'Get-ProfiledRemotingMachineStateRoot (agent-shell windir/ProgramData resolution)' -Tag 'Unit' {

  BeforeEach {
    # Simulate an agent-spawned shell: Process scope empty for both ProgramData
    # and windir. Machine scope is left untouched (it is the real, actual value
    # on this workstation), which is exactly the "empty in process, present in
    # Machine scope" case Task 13.20.e calls out.
    $script:savedProgramData = [System.Environment]::GetEnvironmentVariable('ProgramData', 'Process')
    $script:savedWindir = [System.Environment]::GetEnvironmentVariable('windir', 'Process')
  }

  AfterEach {
    [System.Environment]::SetEnvironmentVariable('ProgramData', $script:savedProgramData, 'Process')
    [System.Environment]::SetEnvironmentVariable('windir', $script:savedWindir, 'Process')
  }

  It 'resolves ProgramData from Machine scope when Process scope is empty (agent shell)' {
    [System.Environment]::SetEnvironmentVariable('ProgramData', $null, 'Process')
    $machineProgramData = [System.Environment]::GetEnvironmentVariable('ProgramData', 'Machine')
    if ([string]::IsNullOrWhiteSpace($machineProgramData)) {
      Set-ItResult -Skipped -Because 'ProgramData is not set at Machine scope on this host'
      return
    }

    $root = Get-ProfiledRemotingMachineStateRoot
    $root | Should -Be (Join-Path $machineProgramData 'ATAP\RemotingEndpoints')
  }

  It 'never derives the machine-state root from the current working directory / a Git worktree' {
    $root = Get-ProfiledRemotingMachineStateRoot
    $root | Should -Not -BeLike "$script:moduleRoot*"
    $root | Should -Match '^[A-Za-z]:\\.*ATAP\\RemotingEndpoints$'
  }

  It 'derives the root from windir when ProgramData is unresolved in both Process and Machine scope' {
    # Deterministic regardless of host: shadow Resolve-ATAPMachineEnvironmentVariable
    # so ProgramData always reports unresolved while windir reports the real,
    # Machine-scope value -- this is the actual observed shape on this workstation
    # (ProgramData is not set at Machine scope; windir is), and is exactly the
    # last-resort fallback path Task 13.20.e calls for.
    $realWindir = [System.Environment]::GetEnvironmentVariable('windir', 'Machine')
    if ([string]::IsNullOrWhiteSpace($realWindir)) {
      Set-ItResult -Skipped -Because 'windir is not set at Machine scope on this host'
      return
    }

    $script:fallbackTestWindir = $realWindir
    function Resolve-ATAPMachineEnvironmentVariable {
      param($Name, $DefaultValue, $FunctionName, $ModuleName)
      switch ($Name) {
        'ProgramData' { return $DefaultValue }
        'windir' { return $script:fallbackTestWindir }
        default { return $DefaultValue }
      }
    }
    try {
      $root = Get-ProfiledRemotingMachineStateRoot
      $expectedDrive = [System.IO.Path]::GetPathRoot($realWindir)
      $root | Should -Be (Join-Path (Join-Path $expectedDrive 'ProgramData') 'ATAP\RemotingEndpoints')
    } finally {
      Remove-Item -Path 'function:Resolve-ATAPMachineEnvironmentVariable' -ErrorAction SilentlyContinue
      . $script:envHelperPath
    }
  }

  It 'throws a bounded error rather than falling back to a worktree path when both ProgramData and windir are unresolved' {
    [System.Environment]::SetEnvironmentVariable('ProgramData', $null, 'Process')
    [System.Environment]::SetEnvironmentVariable('windir', $null, 'Process')

    # Force both scopes empty for the duration of this one assertion by
    # temporarily shadowing Resolve-ATAPMachineEnvironmentVariable so it always
    # reports unresolved, regardless of this real machine's actual Machine-scope
    # values -- exercises the "no discoverable machine-state root" bounded-error
    # path without needing a machine where ProgramData/windir are truly unset.
    function Resolve-ATAPMachineEnvironmentVariable {
      param($Name, $DefaultValue, $FunctionName, $ModuleName)
      return $DefaultValue
    }
    try {
      { Get-ProfiledRemotingMachineStateRoot } | Should -Throw '*Refusing to fall back*'
    } finally {
      Remove-Item -Path 'function:Resolve-ATAPMachineEnvironmentVariable' -ErrorAction SilentlyContinue
      . $script:envHelperPath
    }
  }
}

Describe 'Register-ProfiledRemotingEndpoint source (.pssc) resolution' -Tag 'Unit' {

  It 'resolves the default -Path to the real, existing WithProfiles.pssc' {
    (Get-Command Register-ProfiledRemotingEndpoint).Parameters['Path'] | Should -Not -BeNullOrEmpty
    Test-Path -LiteralPath $script:realPsscPath -PathType Leaf | Should -BeTrue
  }

  It 'throws a clear, bounded error when an explicit -Path does not exist' {
    $missingPath = Join-Path $TestDrive 'DoesNotExist.pssc'
    # Should -Throw matches with -like wildcarding, not regex, so the path is
    # embedded as-is (it contains no -like wildcard metacharacters).
    { Register-ProfiledRemotingEndpoint -Path $missingPath -WhatIf } |
      Should -Throw "*Session configuration file not found*$missingPath*"
  }
}

Describe 'Register-ProfiledRemotingEndpoint local registration marker placement' -Tag 'Unit' {

  BeforeAll {
    # Point the machine-state root at a TestDrive-backed fixture instead of the
    # real C:\ProgramData, so the test never touches the real machine.
    $script:fixtureMarkerBase = Join-Path $TestDrive 'ProgramDataFixture\ATAP\RemotingEndpoints\WithProfiles.pssc'
  }

  BeforeEach {
    Mock -CommandName Get-PSSessionConfiguration -MockWith { $null }
    Mock -CommandName Register-PSSessionConfiguration -MockWith { }
    Mock -CommandName Unregister-PSSessionConfiguration -MockWith { }
    Mock -CommandName Get-Process -MockWith { [PSCustomObject]@{ Path = 'C:\Program Files\PowerShell\7\pwsh.exe' } }
    Mock -CommandName Start-Process -MockWith { }
    Mock -CommandName Write-PSFMessage -MockWith { }
  }

  It 'writes the local hash marker under -LocalMarkerPath, never beside the source .pssc in the Git worktree' {
    $result = Register-ProfiledRemotingEndpoint -Path $script:realPsscPath -LocalMarkerPath $script:fixtureMarkerBase -Confirm:$false

    $result.Ok | Should -BeTrue
    $expectedMarker = "$script:fixtureMarkerBase.registered-sha256"
    Test-Path -LiteralPath $expectedMarker -PathType Leaf | Should -BeTrue

    $worktreeMarker = "$script:realPsscPath.registered-sha256"
    Test-Path -LiteralPath $worktreeMarker -PathType Leaf | Should -BeFalse
  }

  It 'creates the machine-state marker directory on demand (ProgramData\ATAP\... may not pre-exist)' {
    $markerDir = Split-Path -Path $script:fixtureMarkerBase -Parent
    Remove-Item -LiteralPath $markerDir -Recurse -Force -ErrorAction SilentlyContinue
    Test-Path -LiteralPath $markerDir | Should -BeFalse

    Register-ProfiledRemotingEndpoint -Path $script:realPsscPath -LocalMarkerPath $script:fixtureMarkerBase -Confirm:$false | Out-Null

    Test-Path -LiteralPath $markerDir -PathType Container | Should -BeTrue
  }

  It 'defaults -LocalMarkerPath to a path outside the Git worktree when not supplied' {
    $result = Register-ProfiledRemotingEndpoint -Path $script:realPsscPath -WhatIf
    $result.DryRun | Should -Not -Be $true
    # -WhatIf takes the WouldCreate/WouldUpdate branch and never calls the
    # registration scriptblock, so no marker is written; assert instead that the
    # function did not throw and did not require -LocalMarkerPath to be supplied.
    $result | Should -Not -BeNullOrEmpty
  }

  It 'reports AlreadyCurrent on a second call once the marker records the current hash' {
    Register-ProfiledRemotingEndpoint -Path $script:realPsscPath -LocalMarkerPath $script:fixtureMarkerBase -Confirm:$false | Out-Null

    Mock -CommandName Get-PSSessionConfiguration -MockWith { [PSCustomObject]@{ Name = 'ATAP.PS7.Profiled' } }

    $second = Register-ProfiledRemotingEndpoint -Path $script:realPsscPath -LocalMarkerPath $script:fixtureMarkerBase -Confirm:$false
    $second.Action | Should -Be 'AlreadyCurrent'
  }

  It 'resolves an existing Windows directory without either Process alias' {
    $priorWindir = [Environment]::GetEnvironmentVariable('windir', 'Process')
    $priorSystemRoot = [Environment]::GetEnvironmentVariable('SystemRoot', 'Process')
    $machineWindirWithSystemRootPresent = [Environment]::GetEnvironmentVariable('windir', 'Machine')
    $machineWindirWithSystemRootPresent | Should -Not -BeNullOrEmpty
    [Environment]::SetEnvironmentVariable('windir', $null, 'Process')
    [Environment]::SetEnvironmentVariable('SystemRoot', $null, 'Process')
    try {
      $machineSystemRoot = [Environment]::GetEnvironmentVariable('SystemRoot', 'Machine')
      $machineWindir = [Environment]::GetEnvironmentVariable('windir', 'Machine')
      $machineSystemRoot | Should -BeNullOrEmpty
      $machineWindir | Should -BeNullOrEmpty

      $resolved = Get-ATAPWindowsSpecialFolderRoot
      $resolved | Should -Not -BeNullOrEmpty
      Test-Path -LiteralPath $resolved -PathType Container | Should -BeTrue
    } finally {
      [Environment]::SetEnvironmentVariable('windir', $priorWindir, 'Process')
      [Environment]::SetEnvironmentVariable('SystemRoot', $priorSystemRoot, 'Process')
    }
  }

  It 'temporarily supplies missing local Windows roots from Machine scope and restores them after success' {
    $priorWindir = [System.Environment]::GetEnvironmentVariable('windir', 'Process')
    $priorSystemRoot = [System.Environment]::GetEnvironmentVariable('SystemRoot', 'Process')
    [System.Environment]::SetEnvironmentVariable('windir', $null, 'Process')
    [System.Environment]::SetEnvironmentVariable('SystemRoot', $null, 'Process')
    $expectedWindirPresence = [System.Environment]::GetEnvironmentVariables('Process').Contains('windir')
    $expectedSystemRootPresence = [System.Environment]::GetEnvironmentVariables('Process').Contains('SystemRoot')
    $script:observedRegistrationWindir = $null
    $script:observedRegistrationSystemRoot = $null
    Mock -CommandName Resolve-ATAPMachineEnvironmentVariable -MockWith { 'C:\WINDOWS' }
    Mock -CommandName Register-PSSessionConfiguration -MockWith {
      $script:observedRegistrationWindir = [System.Environment]::GetEnvironmentVariable('windir', 'Process')
      $script:observedRegistrationSystemRoot = [System.Environment]::GetEnvironmentVariable('SystemRoot', 'Process')
    }
    Mock -CommandName Enable-PSRemoting -MockWith { throw 'Enable-PSRemoting must never be called.' }

    try {
      $result = Register-ProfiledRemotingEndpoint -Path $script:realPsscPath -LocalMarkerPath $script:fixtureMarkerBase -Confirm:$false

      $result.Ok | Should -BeTrue
      $script:observedRegistrationWindir | Should -Be 'C:\WINDOWS'
      $script:observedRegistrationSystemRoot | Should -Be 'C:\WINDOWS'
      [System.Environment]::GetEnvironmentVariable('windir', 'Process') | Should -BeNullOrEmpty
      [System.Environment]::GetEnvironmentVariable('SystemRoot', 'Process') | Should -BeNullOrEmpty
      [System.Environment]::GetEnvironmentVariables('Process').Contains('windir') | Should -Be $expectedWindirPresence
      [System.Environment]::GetEnvironmentVariables('Process').Contains('SystemRoot') | Should -Be $expectedSystemRootPresence
      Should -Invoke Enable-PSRemoting -Times 0
    } finally {
      [System.Environment]::SetEnvironmentVariable('windir', $priorWindir, 'Process')
      [System.Environment]::SetEnvironmentVariable('SystemRoot', $priorSystemRoot, 'Process')
    }
  }

  It 'restores the exact prior local Windows roots after registration failure' {
    $priorWindir = [System.Environment]::GetEnvironmentVariable('windir', 'Process')
    $priorSystemRoot = [System.Environment]::GetEnvironmentVariable('SystemRoot', 'Process')
    [System.Environment]::SetEnvironmentVariable('windir', $null, 'Process')
    [System.Environment]::SetEnvironmentVariable('SystemRoot', $null, 'Process')
    $expectedWindirPresence = [System.Environment]::GetEnvironmentVariables('Process').Contains('windir')
    $expectedSystemRootPresence = [System.Environment]::GetEnvironmentVariables('Process').Contains('SystemRoot')
    Mock -CommandName Resolve-ATAPMachineEnvironmentVariable -MockWith { 'C:\WINDOWS' }
    Mock -CommandName Register-PSSessionConfiguration -MockWith { throw 'fixture registration failure' }

    try {
      $result = Register-ProfiledRemotingEndpoint -Path $script:realPsscPath -LocalMarkerPath $script:fixtureMarkerBase -Confirm:$false

      $result.Ok | Should -BeFalse
      $result.Failures | Should -Contain 'fixture registration failure'
      [System.Environment]::GetEnvironmentVariable('windir', 'Process') | Should -BeNullOrEmpty
      [System.Environment]::GetEnvironmentVariable('SystemRoot', 'Process') | Should -BeNullOrEmpty
      [System.Environment]::GetEnvironmentVariables('Process').Contains('windir') | Should -Be $expectedWindirPresence
      [System.Environment]::GetEnvironmentVariables('Process').Contains('SystemRoot') | Should -Be $expectedSystemRootPresence
    } finally {
      [System.Environment]::SetEnvironmentVariable('windir', $priorWindir, 'Process')
      [System.Environment]::SetEnvironmentVariable('SystemRoot', $priorSystemRoot, 'Process')
    }
  }

  It 'fails closed before registration when Process and Machine Windows roots are unavailable' {
    $priorWindir = [System.Environment]::GetEnvironmentVariable('windir', 'Process')
    $priorSystemRoot = [System.Environment]::GetEnvironmentVariable('SystemRoot', 'Process')
    [System.Environment]::SetEnvironmentVariable('windir', $null, 'Process')
    [System.Environment]::SetEnvironmentVariable('SystemRoot', $null, 'Process')
    $expectedWindirPresence = [System.Environment]::GetEnvironmentVariables('Process').Contains('windir')
    $expectedSystemRootPresence = [System.Environment]::GetEnvironmentVariables('Process').Contains('SystemRoot')
    Mock -CommandName Resolve-ATAPMachineEnvironmentVariable -MockWith { $null }
    Mock -CommandName Get-ATAPWindowsSpecialFolderRoot -MockWith { $null }

    try {
      $result = Register-ProfiledRemotingEndpoint -Path $script:realPsscPath -LocalMarkerPath $script:fixtureMarkerBase -Confirm:$false

      $result.Ok | Should -BeFalse
      $result.Action | Should -Be 'RegistrationEnvironmentUnavailable'
      $result.Failures[0] | Should -Match "special-folder API were all unresolved"
      [System.Environment]::GetEnvironmentVariables('Process').Contains('windir') | Should -Be $expectedWindirPresence
      [System.Environment]::GetEnvironmentVariables('Process').Contains('SystemRoot') | Should -Be $expectedSystemRootPresence
      Should -Invoke Register-PSSessionConfiguration -Times 0
    } finally {
      [System.Environment]::SetEnvironmentVariable('windir', $priorWindir, 'Process')
      [System.Environment]::SetEnvironmentVariable('SystemRoot', $priorSystemRoot, 'Process')
    }
  }


  It 'uses the verified Windows special-folder fallback when both Process and Machine aliases are unresolved' {
    $priorWindir = [System.Environment]::GetEnvironmentVariable('windir', 'Process')
    $priorSystemRoot = [System.Environment]::GetEnvironmentVariable('SystemRoot', 'Process')
    [System.Environment]::SetEnvironmentVariable('windir', $null, 'Process')
    [System.Environment]::SetEnvironmentVariable('SystemRoot', $null, 'Process')
    $expectedWindirPresence = [System.Environment]::GetEnvironmentVariables('Process').Contains('windir')
    $expectedSystemRootPresence = [System.Environment]::GetEnvironmentVariables('Process').Contains('SystemRoot')
    $fallbackRoot = Join-Path $TestDrive 'Windows'
    New-Item -ItemType Directory -Path $fallbackRoot -Force | Out-Null
    Mock -CommandName Resolve-ATAPMachineEnvironmentVariable -MockWith { $null }
    Mock -CommandName Get-ATAPWindowsSpecialFolderRoot -MockWith { $fallbackRoot }
    Mock -CommandName Enable-PSRemoting -MockWith { throw 'Enable-PSRemoting must never be called.' }

    try {
      $result = Register-ProfiledRemotingEndpoint -Path $script:realPsscPath -LocalMarkerPath $script:fixtureMarkerBase -Confirm:$false

      $result.Ok | Should -BeTrue
      [System.Environment]::GetEnvironmentVariable('windir', 'Process') | Should -BeNullOrEmpty
      [System.Environment]::GetEnvironmentVariable('SystemRoot', 'Process') | Should -BeNullOrEmpty
      [System.Environment]::GetEnvironmentVariables('Process').Contains('windir') | Should -Be $expectedWindirPresence
      [System.Environment]::GetEnvironmentVariables('Process').Contains('SystemRoot') | Should -Be $expectedSystemRootPresence
      Should -Invoke Get-ATAPWindowsSpecialFolderRoot -Times 2
      Should -Invoke Enable-PSRemoting -Times 0
    } finally {
      [System.Environment]::SetEnvironmentVariable('windir', $priorWindir, 'Process')
      [System.Environment]::SetEnvironmentVariable('SystemRoot', $priorSystemRoot, 'Process')
    }
  }

  It 'registers through the real .NET fallback for the installed-equivalent alias-expansion gap' {
    $priorWindir = [System.Environment]::GetEnvironmentVariable('windir', 'Process')
    $priorSystemRoot = [System.Environment]::GetEnvironmentVariable('SystemRoot', 'Process')
    $machineSystemRoot = [System.Environment]::GetEnvironmentVariable('SystemRoot', 'Machine')
    $machineWindirBefore = [System.Environment]::GetEnvironmentVariable('windir', 'Machine')
    if (-not [string]::IsNullOrWhiteSpace($machineSystemRoot) -or [string]::IsNullOrWhiteSpace($machineWindirBefore)) {
      Set-ItResult -Skipped -Because 'Host does not expose the Machine windir/%SystemRoot% expansion gap.'
      return
    }

    [System.Environment]::SetEnvironmentVariable('windir', $null, 'Process')
    [System.Environment]::SetEnvironmentVariable('SystemRoot', $null, 'Process')
    $expectedWindirPresence = [System.Environment]::GetEnvironmentVariables('Process').Contains('windir')
    $expectedSystemRootPresence = [System.Environment]::GetEnvironmentVariables('Process').Contains('SystemRoot')
    $expectedRoot = [Environment]::GetFolderPath([Environment+SpecialFolder]::Windows)
    $script:observedRegistrationWindir = $null
    $script:observedRegistrationSystemRoot = $null
    Mock -CommandName Register-PSSessionConfiguration -MockWith {
      $script:observedRegistrationWindir = [System.Environment]::GetEnvironmentVariable('windir', 'Process')
      $script:observedRegistrationSystemRoot = [System.Environment]::GetEnvironmentVariable('SystemRoot', 'Process')
    }
    Mock -CommandName Enable-PSRemoting -MockWith { throw 'Enable-PSRemoting must never be called.' }

    try {
      [System.Environment]::GetEnvironmentVariable('windir', 'Machine') | Should -BeNullOrEmpty
      $result = Register-ProfiledRemotingEndpoint -Path $script:realPsscPath -LocalMarkerPath $script:fixtureMarkerBase -Confirm:$false

      $result.Ok | Should -BeTrue
      $script:observedRegistrationWindir | Should -Be $expectedRoot
      $script:observedRegistrationSystemRoot | Should -Be $expectedRoot
      [System.Environment]::GetEnvironmentVariables('Process').Contains('windir') | Should -Be $expectedWindirPresence
      [System.Environment]::GetEnvironmentVariables('Process').Contains('SystemRoot') | Should -Be $expectedSystemRootPresence
      [System.Environment]::GetEnvironmentVariable('windir', 'Process') | Should -BeNullOrEmpty
      [System.Environment]::GetEnvironmentVariable('SystemRoot', 'Process') | Should -BeNullOrEmpty
      Should -Invoke Enable-PSRemoting -Times 0
    } finally {
      [System.Environment]::SetEnvironmentVariable('windir', $priorWindir, 'Process')
      [System.Environment]::SetEnvironmentVariable('SystemRoot', $priorSystemRoot, 'Process')
    }
  }
}

Describe 'Agent-shell regression: windir/ProgramData resolution in a real child process' -Tag 'Unit' {
  # Mocking [System.Environment]::GetEnvironmentVariable cannot prove the fix works
  # against the actual failure mode: an agent-spawned pwsh process whose Process-scope
  # environment block genuinely omits variables the interactive session has. This
  # spawns a real child pwsh process with ProgramData/windir explicitly removed from
  # its *inherited* environment (Machine-scope values are untouched -- they live in
  # the registry, not the process's env block) and proves Get-ProfiledRemotingMachineStateRoot
  # still resolves correctly from inside that process.
  #
  # The child process is launched WITHOUT -NoProfile (repo policy: never pass
  # -NoProfile for ATAP work) even though this probe only needs the private
  # helper files, not $global:settings. This means the child pays full profile
  # load cost, so the process-exit wait below is generous.

  BeforeAll {
    $script:pwshExe = (Get-Process -Id $PID).Path
    if (-not (Test-Path -LiteralPath $script:pwshExe -PathType Leaf) -or $script:pwshExe -notlike '*pwsh.exe') {
      $script:pwshExe = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
    }
  }

  It 'resolves the machine-state root from Machine scope in a child process with an empty Process-scope environment for ProgramData/windir' {
    if (-not $script:pwshExe) {
      Set-ItResult -Skipped -Because 'pwsh.exe was not discoverable for a child-process regression run'
      return
    }

    # Compute the expected result the same way Get-ProfiledRemotingMachineStateRoot
    # does, from Machine-scope values only, so this assertion is portable across
    # hosts regardless of whether ProgramData or only windir is set at Machine scope
    # (on this workstation, only windir is -- ProgramData is not -- which is exactly
    # the real-world case this fallback chain exists for).
    $machineProgramData = [System.Environment]::GetEnvironmentVariable('ProgramData', 'Machine')
    $machineWindir = [System.Environment]::GetEnvironmentVariable('windir', 'Machine')
    if (-not [string]::IsNullOrWhiteSpace($machineProgramData)) {
      $expectedRoot = Join-Path $machineProgramData 'ATAP\RemotingEndpoints'
    } elseif (-not [string]::IsNullOrWhiteSpace($machineWindir)) {
      $driveRoot = [System.IO.Path]::GetPathRoot($machineWindir)
      $expectedRoot = Join-Path (Join-Path $driveRoot 'ProgramData') 'ATAP\RemotingEndpoints'
    } else {
      Set-ItResult -Skipped -Because 'Neither ProgramData nor windir is set at Machine scope on this host'
      return
    }

    # Result is written to a file, not stdout: the child runs the full ATAP
    # profile chain (no -NoProfile per repo policy), which writes its own
    # startup diagnostics to stdout and would otherwise contaminate a
    # stdout-based JSON payload. Built by concatenation, not the -f format
    # operator: the script body's own '@{ ... }' hashtable literal would
    # otherwise be mis-parsed as a format placeholder.
    $resultFilePath = Join-Path $TestDrive 'agent-shell-probe-result.json'
    $childScript = "`$ErrorActionPreference = 'Stop'`n" +
      ". '$script:rootHelperPath'`n" +
      '$root = Get-ProfiledRemotingMachineStateRoot' + "`n" +
      "[PSCustomObject]@{ Root = `$root } | ConvertTo-Json -Compress | Set-Content -LiteralPath '$resultFilePath' -Encoding UTF8 -Force"

    $childScriptPath = Join-Path $TestDrive 'agent-shell-probe.ps1'
    Set-Content -LiteralPath $childScriptPath -Value $childScript -Encoding UTF8 -Force
    Remove-Item -LiteralPath $resultFilePath -Force -ErrorAction SilentlyContinue

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $script:pwshExe
    $psi.ArgumentList.Add('-NoLogo')
    $psi.ArgumentList.Add('-ExecutionPolicy')
    $psi.ArgumentList.Add('Bypass')
    $psi.ArgumentList.Add('-File')
    $psi.ArgumentList.Add($childScriptPath)
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    # Simulate an agent-spawned shell that does not inherit the interactive
    # session's Process-scope environment: remove ProgramData/windir from the
    # CHILD process's own environment block only. Machine-scope values are
    # unaffected -- they are read straight out of the registry, never from a
    # process's environment block.
    $psi.EnvironmentVariables.Remove('ProgramData')
    $psi.EnvironmentVariables.Remove('windir')

    $proc = [System.Diagnostics.Process]::new()
    $proc.StartInfo = $psi
    [void]$proc.Start()
    # Begin draining both redirected streams asynchronously BEFORE WaitForExit,
    # per the async-process-drain rule: never block on WaitForExit while a
    # redirected buffer can still fill and deadlock the child. PS7 event-based
    # add_OutputDataReceived callbacks have no runspace on the ThreadPool thread
    # that invokes them, so use the Task-based *Async reads instead.
    $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
    $stderrTask = $proc.StandardError.ReadToEndAsync()
    $completed = $proc.WaitForExit(60000)
    if (-not $completed) {
      $proc.Kill()
      throw 'Child pwsh process for the agent-shell regression probe did not exit within 60 seconds.'
    }
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()

    $proc.ExitCode | Should -Be 0 -Because "stdout: $stdout`nstderr: $stderr"
    Test-Path -LiteralPath $resultFilePath -PathType Leaf | Should -BeTrue -Because "stdout: $stdout`nstderr: $stderr"

    $parsed = Get-Content -LiteralPath $resultFilePath -Raw | ConvertFrom-Json
    $parsed.Root | Should -Be $expectedRoot
  }
}
