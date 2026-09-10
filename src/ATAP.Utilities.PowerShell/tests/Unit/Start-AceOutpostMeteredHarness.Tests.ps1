# tests/Unit/Start-AceOutpostMeteredHarness.Tests.ps1
#
# Task 15.190.c. Covers the three areas the board row names - environment composition,
# credential-resolution failure, and the child-only guarantee - against the four testable
# assertions in Task15.190.a-SharedLaunchCoreDecisionPacket.md section 3.1.
#
# WHAT THESE TESTS CAN AND CANNOT ESTABLISH. Task 15.190.b established that a FOREIGN
# process's environment block is not readable on this host, so absence cannot be proven by
# reading a sibling. These tests therefore prove G1 against a probe child we start ourselves
# (pwsh, a stub whose behaviour we control), and prove G2/G3 by reading OUR OWN process block
# and the durable registry scopes, which are directly readable. G4 - that an unrelated
# application inherits nothing - is NOT proven here; it follows from G3 plus the fact that no
# CreateProcess-time block is ever written anywhere a future process reads, and it is board
# row 15.190.h's acceptance test, not a unit test.
#
# No live provider traffic is generated: the child under test is always pwsh, and the "proxy
# listener" is a bare loopback TcpListener that accepts a connection and serves nothing.
# The credential used throughout is the obviously fake literal 'test-user:test-secret'.

#Requires -Module Pester

BeforeAll {
  $functionFile = Join-Path $PSScriptRoot '..\..\public\Start-AceOutpostMeteredHarness.ps1'
  . $functionFile
  $script:functionFilePath = (Resolve-Path $functionFile).Path
  if (Get-Module -ListAvailable -Name PSFramework) {
    Import-Module PSFramework -ErrorAction SilentlyContinue
  }

  # Names this function may compose, plus the negative-control name it must never set.
  $script:composedNames = @(
    'HTTP_PROXY', 'HTTPS_PROXY', 'NO_PROXY',
    'NODE_EXTRA_CA_CERTS', 'SSL_CERT_FILE', 'NODE_TLS_REJECT_UNAUTHORIZED'
  )

  $script:pwshPath = (Get-Command pwsh -CommandType Application | Select-Object -First 1).Source

  $script:stateDirectory = Join-Path $TestDrive 'AceOutpostState'
  New-Item -ItemType Directory -Path $script:stateDirectory -Force | Out-Null
  $script:rootPem = Join-Path $script:stateDirectory 'AceOutpost-Interception-Root.pem'
  Set-Content -LiteralPath $script:rootPem -Value 'public-root-placeholder'

  $script:emptyStateDirectory = Join-Path $TestDrive 'EmptyState'
  New-Item -ItemType Directory -Path $script:emptyStateDirectory -Force | Out-Null

  # Probe child. Emits ONLY the allow-listed names, so no ambient secret from the real
  # environment is ever written to disk by this suite.
  $script:stubPath = Join-Path $TestDrive 'probe-child.ps1'
  Set-Content -LiteralPath $script:stubPath -Encoding utf8 -Value @'
param([string]$OutPath)
$names = @('HTTP_PROXY','HTTPS_PROXY','NO_PROXY','NODE_EXTRA_CA_CERTS','SSL_CERT_FILE','NODE_TLS_REJECT_UNAUTHORIZED','http_proxy','https_proxy','no_proxy')
$captured = [ordered]@{}
foreach ($n in $names) { $captured[$n] = [Environment]::GetEnvironmentVariable($n, 'Process') }
[pscustomobject]@{
  Args = @($args)
  Env  = $captured
  Pid  = $PID
} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutPath -Encoding utf8
'@

  # Obviously fake. Never a real credential.
  $script:fakeCredential = 'test-user:test-secret'
  function Get-SecretATAP {
    param([string]$SecretName)
    $script:fakeCredential
  }

  # A bare loopback listener standing in for AceOutpostService's proxy endpoint. It accepts
  # the pre-flight TCP connect and serves nothing; no HTTP is spoken and no traffic leaves
  # the host.
  #
  # Ports are chosen dynamically, and must be. On this host `netsh int ipv4 show
  # excludedportrange protocol=tcp` reports 50060-50159 as an OS-reserved exclusion range
  # (unbindable, "access forbidden"), and 50055 - the AceOutpost default - was observed in
  # use. A hard-coded test port in the ValidateRange(50000,50099) window is therefore not
  # portable across hosts, and must never collide with the real listener.
  $script:freePorts = @()
  for ($candidate = 50001; $candidate -le 50099 -and $script:freePorts.Count -lt 2; $candidate++) {
    try {
      $attempt = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $candidate)
      $attempt.Start()
      $attempt.Stop()
      $script:freePorts += $candidate
    } catch {
      # In use, or inside an OS port-exclusion range. Try the next candidate.
    }
  }
  if ($script:freePorts.Count -lt 2) {
    throw 'Fewer than two bindable loopback ports in 50000-50099; this suite needs one listening and one dead.'
  }

  $script:proxyPort = $script:freePorts[0]
  $script:listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $script:proxyPort)
  $script:listener.Start()

  # A port in the validated range that is deliberately NOT listening.
  $script:deadPort = $script:freePorts[1]

  function Invoke-ProbeLaunch {
    param(
      [string]$Client = 'Codex',
      [string[]]$ExtraArguments = @(),
      [string]$LaunchMode = 'Wait',
      [int]$Port = $script:proxyPort
    )
    $outPath = Join-Path $TestDrive ("probe-{0}.json" -f ([guid]::NewGuid().ToString('N')))
    $arguments = @('-NonInteractive', '-File', $script:stubPath, $outPath) + $ExtraArguments
    $result = Start-AceOutpostMeteredHarness `
      -Client $Client `
      -LaunchMode $LaunchMode `
      -ProxyPort $Port `
      -StateDirectory $script:stateDirectory `
      -HarnessPath $script:pwshPath `
      -ArgumentList $arguments `
      -Confirm:$false
    [pscustomobject]@{
      Result   = $result
      OutPath  = $outPath
      Captured = if (Test-Path -LiteralPath $outPath) { Get-Content -LiteralPath $outPath -Raw | ConvertFrom-Json } else { $null }
    }
  }
}

AfterAll {
  if ($null -ne $script:listener) { $script:listener.Stop() }
  Remove-Item -LiteralPath Function:\Get-SecretATAP -ErrorAction SilentlyContinue
}

Describe 'Start-AceOutpostMeteredHarness' -Tag 'Unit' {

  Context 'Seam - the ratified signature' {

    It 'takes only a SecretName, never a credential value' {
      $parameters = (Get-Command Start-AceOutpostMeteredHarness).Parameters
      $parameters.ContainsKey('CredentialSecretName') | Should -BeTrue
      foreach ($forbidden in @('Credential', 'Password', 'ProxyUrl')) {
        $parameters.ContainsKey($forbidden) | Should -BeFalse -Because "the only credential path is Get-SecretATAP; -$forbidden would create a second one"
      }
    }

    It 'has no Scope parameter, because the core has exactly one scope' {
      (Get-Command Start-AceOutpostMeteredHarness).Parameters.ContainsKey('Scope') |
        Should -BeFalse -Because 'a scope switch would reintroduce the ambient path SC-0401 exists to remove'
    }

    It 'supports both ratified launch modes and WhatIf' {
      $command = Get-Command Start-AceOutpostMeteredHarness
      $modeAttribute = $command.Parameters['LaunchMode'].Attributes |
        Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
      $modeAttribute.ValidValues | Should -Be @('Wait', 'Detach')
      $command.Parameters.ContainsKey('WhatIf') | Should -BeTrue
    }

    It 'collects ArgumentList from the remaining arguments' {
      $attribute = (Get-Command Start-AceOutpostMeteredHarness).Parameters['ArgumentList'].Attributes |
        Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }
      @($attribute).ValueFromRemainingArguments | Should -Contain $true
    }

    It 'resolves the suite stub for Get-SecretATAP, never the real secret store' {
      # Safety interlock. If a future edit lets the real, module-exported Get-SecretATAP win
      # the command lookup, this suite would resolve a live vault credential and write it into
      # a child process. Fail loudly here rather than silently there.
      $resolved = Get-Command Get-SecretATAP -ErrorAction Stop
      $resolved.CommandType | Should -Be 'Function'
      [string]$resolved.ModuleName | Should -BeNullOrEmpty
      (Get-SecretATAP -SecretName 'any') | Should -Be 'test-user:test-secret'
    }
  }

  Context 'Environment composition (G1 - positive, child)' {

    It 'composes the documented proxy variables in the Codex child with the OpenSSL trust variable' {
      $launch = Invoke-ProbeLaunch -Client Codex
      $launch.Result.ExitCode | Should -Be 0
      $launch.Captured | Should -Not -BeNullOrEmpty

      $expectedUrl = "http://test-user:test-secret@127.0.0.1:$($script:proxyPort)"
      $launch.Captured.Env.HTTP_PROXY | Should -Be $expectedUrl
      $launch.Captured.Env.HTTPS_PROXY | Should -Be $expectedUrl
      $launch.Captured.Env.NO_PROXY | Should -Be 'localhost,127.0.0.1,::1'
      $launch.Captured.Env.SSL_CERT_FILE | Should -Be $script:rootPem
    }

    It 'composes the Node trust variable in the ClaudeCode child' {
      $launch = Invoke-ProbeLaunch -Client ClaudeCode
      $launch.Captured.Env.NODE_EXTRA_CA_CERTS | Should -Be $script:rootPem
      # Not asserted as null: an unrelated third party (Avast) publishes its own
      # NODE_EXTRA_CA_CERTS ambiently on this host per 15.190.b section 1.2, so the honest
      # assertion for the OTHER client is that OUR pem is not what the child received.
      $codex = Invoke-ProbeLaunch -Client Codex
      $codex.Captured.Env.NODE_EXTRA_CA_CERTS | Should -Not -Be $script:rootPem
    }

    It 'reports the composed variable names without ever reporting their values' {
      $launch = Invoke-ProbeLaunch -Client Codex
      $launch.Result.ComposedVariableNames | Should -Be @('HTTP_PROXY', 'HTTPS_PROXY', 'NO_PROXY', 'SSL_CERT_FILE')
      # The returned endpoint carries no userinfo.
      $launch.Result.ProxyEndpoint | Should -Be "http://127.0.0.1:$($script:proxyPort)"
      ($launch.Result | ConvertTo-Json -Depth 6) | Should -Not -Match 'test-secret'
    }

    It 'is resolvable by a child reading the lowercase spelling' {
      # Packet section 2.1 asks for lowercase twins. On Windows the child's block is
      # case-insensitive (ProcessStartInfo.Environment is an ordinal-ignore-case dictionary),
      # so a second casing cannot exist as a separate entry - and does not need to.
      $launch = Invoke-ProbeLaunch -Client Codex
      $launch.Captured.Env.https_proxy | Should -Be $launch.Captured.Env.HTTPS_PROXY
      $launch.Captured.Env.https_proxy | Should -Not -BeNullOrEmpty
    }

    It 'never sets NODE_TLS_REJECT_UNAUTHORIZED and strips it when inherited' {
      $original = [Environment]::GetEnvironmentVariable('NODE_TLS_REJECT_UNAUTHORIZED', 'Process')
      try {
        [Environment]::SetEnvironmentVariable('NODE_TLS_REJECT_UNAUTHORIZED', '0', 'Process')
        $launch = Invoke-ProbeLaunch -Client ClaudeCode
        $launch.Captured.Env.NODE_TLS_REJECT_UNAUTHORIZED |
          Should -BeNullOrEmpty -Because 'the packet forbids the core ever disabling certificate verification, by any route'
      } finally {
        [Environment]::SetEnvironmentVariable('NODE_TLS_REJECT_UNAUTHORIZED', $original, 'Process')
      }
    }

    It 'contains no call that writes an environment variable into a durable or parent scope' {
      # Structural, not behavioural: proves the mechanism is CreateProcess-time composition
      # rather than mutation of the current process.
      $source = Get-Content -LiteralPath $script:functionFilePath -Raw
      $source | Should -Not -Match 'SetEnvironmentVariable'
      $source | Should -Not -Match '\$env:'
      $source | Should -Not -Match 'EnvironmentVariableTarget'
    }
  }

  Context 'Argument pass-through' {

    It 'passes arguments containing spaces, embedded quotes, and a newline through untouched' {
      $awkward = @(
        'a plain argument',
        'has "double" quotes',
        "has 'single' quotes",
        'trailing backslash\',
        "line one`nline two",
        '-p',
        'C:\path with spaces\file.txt'
      )
      $launch = Invoke-ProbeLaunch -Client Codex -ExtraArguments $awkward
      $launch.Captured | Should -Not -BeNullOrEmpty
      @($launch.Captured.Args).Count | Should -Be $awkward.Count
      for ($i = 0; $i -lt $awkward.Count; $i++) {
        $launch.Captured.Args[$i] | Should -BeExactly $awkward[$i] -Because "argument $i must arrive byte-for-byte"
      }
    }

    It 'counts the pass-through vector without interpreting it' {
      $launch = Invoke-ProbeLaunch -Client Codex -ExtraArguments @('--flag', 'value with spaces')
      $launch.Result.ArgumentCount | Should -Be 6
    }
  }

  Context 'Child-only guarantee (G2 - negative, parent; G3 - negative, durable scopes)' {

    It 'leaves the calling process block carrying no composed name it did not already carry' {
      $before = @{}
      foreach ($name in $script:composedNames) {
        $before[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
      }

      $null = Invoke-ProbeLaunch -Client Codex

      foreach ($name in $script:composedNames) {
        [Environment]::GetEnvironmentVariable($name, 'Process') |
          Should -Be $before[$name] -Because "$name must be identical in the parent before and after the launch"
      }
    }

    It 'puts no proxy credential into the parent block even transiently' {
      $null = Invoke-ProbeLaunch -Client Codex
      foreach ($name in @('HTTP_PROXY', 'HTTPS_PROXY')) {
        $value = [Environment]::GetEnvironmentVariable($name, 'Process')
        if ($null -ne $value) { $value | Should -Not -Match 'test-secret' }
      }
    }

    It 'leaves the User and Machine scopes carrying no AceOutpost proxy credential' {
      # Read-only. This unit writes nothing at User or Machine scope.
      $null = Invoke-ProbeLaunch -Client Codex
      foreach ($scope in @('User', 'Machine')) {
        foreach ($name in @('HTTP_PROXY', 'HTTPS_PROXY', 'NO_PROXY')) {
          $value = [Environment]::GetEnvironmentVariable($name, $scope)
          # "No AceOutpost proxy credential is present" rather than "no such variable exists":
          # 15.190.b section 1.3 found pre-existing EMPTY-string proxy names at Machine scope
          # whose origin is open question Q4, and empty is not absent.
          if (-not [string]::IsNullOrEmpty($value)) {
            $value | Should -Not -Match '@127\.0\.0\.1:'
            $value | Should -Not -Match 'test-secret'
          }
        }
      }
    }
  }

  Context 'Credential-resolution failure (packet section 6.2)' {

    It 'throws when Get-SecretATAP is unavailable' {
      # The absence is simulated by mocking the DISCOVERY call, never by removing the stub
      # function. Removing it does not make Get-SecretATAP unavailable on a developer
      # workstation: the real cmdlet is exported by a profile-loaded ATAP module and the
      # command lookup falls through to it, so the test would resolve a REAL vault secret and
      # hand it to a child process. Mocking Get-Command keeps this suite entirely offline.
      Mock Get-Command -ParameterFilter { $Name -eq 'Get-SecretATAP' } -MockWith { $null }

      { Invoke-ProbeLaunch -Client Codex } | Should -Throw '*Get-SecretATAP is required*'
      Should -Invoke Get-Command -Times 1 -Exactly -ParameterFilter { $Name -eq 'Get-SecretATAP' }
    }

    It 'accepts a SecureString from the secret store' {
      $saved = $script:fakeCredential
      try {
        $script:fakeCredential = ConvertTo-SecureString 'test-user:test-secret' -AsPlainText -Force
        $launch = Invoke-ProbeLaunch -Client Codex
        $launch.Captured.Env.HTTPS_PROXY | Should -Be "http://test-user:test-secret@127.0.0.1:$($script:proxyPort)"
      } finally {
        $script:fakeCredential = $saved
      }
    }

    It 'throws on a credential with no separator, a leading separator, or a trailing separator' -ForEach @(
      @{ Value = 'no-separator-at-all' }
      @{ Value = ':secret-with-no-user' }
      @{ Value = 'user-with-no-secret:' }
      @{ Value = '' }
    ) {
      $saved = $script:fakeCredential
      try {
        $script:fakeCredential = $Value
        { Invoke-ProbeLaunch -Client Codex } | Should -Throw '*not a valid username:secret pair*'
      } finally {
        $script:fakeCredential = $saved
      }
    }

    It 'names the SecretName in the failure and leaks no part of the resolved value' {
      $saved = $script:fakeCredential
      try {
        $script:fakeCredential = 'unparseable-sentinel-value'
        $message = $null
        try { $null = Invoke-ProbeLaunch -Client Codex } catch { $message = $_.Exception.Message }
        $message | Should -Match 'proxyCredential\.Ace\.AceOutpost\.codex'
        $message | Should -Not -Match 'unparseable-sentinel-value'
        $message | Should -Not -Match 'sentinel'
      } finally {
        $script:fakeCredential = $saved
      }
    }

    It 'creates no child process when the credential does not resolve' {
      $saved = $script:fakeCredential
      $outPath = Join-Path $TestDrive 'must-not-exist.json'
      try {
        $script:fakeCredential = 'no-separator-at-all'
        $arguments = @('-NonInteractive', '-File', $script:stubPath, $outPath)
        {
          Start-AceOutpostMeteredHarness -Client Codex -ProxyPort $script:proxyPort `
            -StateDirectory $script:stateDirectory -HarnessPath $script:pwshPath `
            -ArgumentList $arguments -Confirm:$false
        } | Should -Throw
        Test-Path -LiteralPath $outPath | Should -BeFalse -Because 'fail-closed means never reaching CreateProcess'
      } finally {
        $script:fakeCredential = $saved
      }
    }
  }

  Context 'Other fail-closed preconditions (packet sections 6.1 and 6.3)' {

    It 'throws when the interception root is missing' {
      {
        Start-AceOutpostMeteredHarness -Client Codex -ProxyPort $script:proxyPort `
          -StateDirectory $script:emptyStateDirectory -HarnessPath $script:pwshPath `
          -ArgumentList @('-NonInteractive', '-Command', 'exit 0') -Confirm:$false
      } | Should -Throw '*interception root was not found*'
    }

    It 'throws when no proxy listener answers' {
      {
        Start-AceOutpostMeteredHarness -Client Codex -ProxyPort $script:deadPort `
          -StateDirectory $script:stateDirectory -HarnessPath $script:pwshPath `
          -ArgumentList @('-NonInteractive', '-Command', 'exit 0') -Confirm:$false
      } | Should -Throw '*No AceOutpost proxy listener answered*'
    }

    It 'refuses a harness path that does not exist' {
      {
        Start-AceOutpostMeteredHarness -Client Codex -ProxyPort $script:proxyPort `
          -StateDirectory $script:stateDirectory `
          -HarnessPath (Join-Path $TestDrive 'no-such-harness.exe') `
          -ArgumentList @() -Confirm:$false
      } | Should -Throw '*was not found*'
    }

    It 'creates no child process under WhatIf' {
      $outPath = Join-Path $TestDrive 'whatif-must-not-exist.json'
      $arguments = @('-NonInteractive', '-File', $script:stubPath, $outPath)
      $result = Start-AceOutpostMeteredHarness -Client Codex -ProxyPort $script:proxyPort `
        -StateDirectory $script:stateDirectory -HarnessPath $script:pwshPath `
        -ArgumentList $arguments -WhatIf

      $result.Started | Should -BeFalse
      $result.ProcessId | Should -BeNullOrEmpty
      Test-Path -LiteralPath $outPath | Should -BeFalse
    }
  }

  Context 'Launch modes' {

    It 'returns the child exit code in Wait mode' {
      $result = Start-AceOutpostMeteredHarness -Client Codex -LaunchMode Wait `
        -ProxyPort $script:proxyPort -StateDirectory $script:stateDirectory `
        -HarnessPath $script:pwshPath `
        -ArgumentList @('-NonInteractive', '-Command', 'exit 42') -Confirm:$false

      $result.ExitCode | Should -Be 42
      $result.LaunchMode | Should -Be 'Wait'
      $result.Started | Should -BeTrue
    }

    It 'drains a large stdout payload in Wait mode without deadlocking' {
      # R-34. A payload well past the pipe buffer: waiting before draining would hang here.
      $result = Start-AceOutpostMeteredHarness -Client Codex -LaunchMode Wait `
        -ProxyPort $script:proxyPort -StateDirectory $script:stateDirectory `
        -HarnessPath $script:pwshPath `
        -ArgumentList @('-NonInteractive', '-Command', "1..20000 | ForEach-Object { 'x' * 80 }") -Confirm:$false

      $result.ExitCode | Should -Be 0
      $result.StandardOutput.Length | Should -BeGreaterThan 1200000
    }

    It 'captures stderr separately in Wait mode' {
      $result = Start-AceOutpostMeteredHarness -Client Codex -LaunchMode Wait `
        -ProxyPort $script:proxyPort -StateDirectory $script:stateDirectory `
        -HarnessPath $script:pwshPath `
        -ArgumentList @('-NonInteractive', '-Command', '[Console]::Error.WriteLine("stderr-marker"); exit 7') -Confirm:$false

      $result.ExitCode | Should -Be 7
      $result.StandardError | Should -Match 'stderr-marker'
    }

    It 'returns without an exit code in Detach mode and still meters the child' {
      $outPath = Join-Path $TestDrive 'detached.json'
      $arguments = @('-NonInteractive', '-File', $script:stubPath, $outPath)
      $result = Start-AceOutpostMeteredHarness -Client Codex -LaunchMode Detach `
        -ProxyPort $script:proxyPort -StateDirectory $script:stateDirectory `
        -HarnessPath $script:pwshPath -ArgumentList $arguments -Confirm:$false

      $result.Started | Should -BeTrue
      $result.ExitCode | Should -BeNullOrEmpty -Because 'a detached launch has no exit code to return'
      $result.ProcessId | Should -BeGreaterThan 0

      $deadline = (Get-Date).AddSeconds(90)
      while (-not (Test-Path -LiteralPath $outPath) -and (Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 250
      }
      Test-Path -LiteralPath $outPath | Should -BeTrue
      $captured = Get-Content -LiteralPath $outPath -Raw | ConvertFrom-Json
      $captured.Env.HTTPS_PROXY | Should -Be "http://test-user:test-secret@127.0.0.1:$($script:proxyPort)"
    }

    It 'fails closed in Detach mode before creating any process' {
      # Packet section 6.4: all three preconditions are pre-CreateProcess, so the detached
      # case - the one with no caller to receive an exit code - never produces a partially
      # proxied child to tear down.
      $outPath = Join-Path $TestDrive 'detached-must-not-exist.json'
      $arguments = @('-NonInteractive', '-File', $script:stubPath, $outPath)
      {
        Start-AceOutpostMeteredHarness -Client Codex -LaunchMode Detach `
          -ProxyPort $script:deadPort -StateDirectory $script:stateDirectory `
          -HarnessPath $script:pwshPath -ArgumentList $arguments -Confirm:$false
      } | Should -Throw '*No AceOutpost proxy listener answered*'
      Test-Path -LiteralPath $outPath | Should -BeFalse
    }
  }
}
