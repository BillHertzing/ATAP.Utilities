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

  # Names this function may compose, plus the negative-control name it must never set, plus the
  # two invocation-marker names added by Task 15.190.e.CORE01 (contract section 5.3).
  $script:composedNames = @(
    'HTTP_PROXY', 'HTTPS_PROXY', 'NO_PROXY',
    'NODE_EXTRA_CA_CERTS', 'SSL_CERT_FILE', 'NODE_TLS_REJECT_UNAUTHORIZED',
    'ACEOUTPOST_METERED_INVOCATION', 'ACEOUTPOST_METERED_PARENT_INVOCATION'
  )
  $script:invocationMarkerName = 'ACEOUTPOST_METERED_INVOCATION'
  $script:parentMarkerName = 'ACEOUTPOST_METERED_PARENT_INVOCATION'

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
$names = @('HTTP_PROXY','HTTPS_PROXY','NO_PROXY','NODE_EXTRA_CA_CERTS','SSL_CERT_FILE','NODE_TLS_REJECT_UNAUTHORIZED','http_proxy','https_proxy','no_proxy','ACEOUTPOST_METERED_INVOCATION','ACEOUTPOST_METERED_PARENT_INVOCATION')
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
      [int]$Port = $script:proxyPort,
      [string]$InvocationId,
      [string]$ParentInvocationId
    )
    $outPath = Join-Path $TestDrive ("probe-{0}.json" -f ([guid]::NewGuid().ToString('N')))
    $arguments = @('-NonInteractive', '-File', $script:stubPath, $outPath) + $ExtraArguments
    # The marker parameters are forwarded only when the caller bound them, so a test that omits
    # them exercises the opt-out path of the core rather than passing an empty string.
    $markerParameters = @{}
    if ($PSBoundParameters.ContainsKey('InvocationId')) { $markerParameters['InvocationId'] = $InvocationId }
    if ($PSBoundParameters.ContainsKey('ParentInvocationId')) { $markerParameters['ParentInvocationId'] = $ParentInvocationId }
    $result = Start-AceOutpostMeteredHarness `
      -Client $Client `
      -LaunchMode $LaunchMode `
      -ProxyPort $Port `
      -StateDirectory $script:stateDirectory `
      -HarnessPath $script:pwshPath `
      -ArgumentList $arguments `
      -Confirm:$false `
      @markerParameters
    [pscustomobject]@{
      Result   = $result
      OutPath  = $outPath
      Captured = if (Test-Path -LiteralPath $outPath) { Get-Content -LiteralPath $outPath -Raw | ConvertFrom-Json } else { $null }
    }
  }

  # Sets one or more Process-scope variables on THIS test process for the duration of a script
  # block and restores the exact prior values (including absence) afterwards. Process scope only,
  # never User or Machine: this is how the tests simulate "the caller itself was launched
  # metered" so the core's overwrite semantics can be asserted against a real inherited value.
  function Invoke-WithProcessEnvironment {
    param(
      [hashtable]$Variables,
      [scriptblock]$ScriptBlock
    )
    $saved = @{}
    foreach ($name in $Variables.Keys) {
      $saved[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
    }
    try {
      foreach ($name in $Variables.Keys) {
        [Environment]::SetEnvironmentVariable($name, $Variables[$name], 'Process')
      }
      & $ScriptBlock
    } finally {
      foreach ($name in $saved.Keys) {
        [Environment]::SetEnvironmentVariable($name, $saved[$name], 'Process')
      }
    }
  }

  # End-to-end probe for the adapter. Invoke-AceOutpostMeteredPrompt places the harness
  # sub-command ('exec') first in the child vector, which pwsh would read as a script name, so
  # the adapter path needs a real executable that tolerates it. This mirrors the sibling
  # adapter suite's compiled probe, reduced to what these tests read: the two marker names, one
  # composed proxy name (proof the launch went through the core), and its pid. The record path
  # is args[1] - the first caller-supplied argument after the harness sub-command.
  $adapterFile = Join-Path $PSScriptRoot '..\..\public\Invoke-AceOutpostMeteredPrompt.ps1'
  $script:adapterFilePath = (Resolve-Path $adapterFile).Path
  $cscPath = 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe'
  $script:adapterProbeExe = $null
  if (Test-Path -LiteralPath $cscPath -PathType Leaf) {
    $probeSource = Join-Path $TestDrive 'marker-probe.cs'
    $script:adapterProbeExe = Join-Path $TestDrive 'marker-probe.exe'
    Set-Content -LiteralPath $probeSource -Encoding utf8 -Value @'
using System;
using System.IO;
using System.Text;
class MarkerProbe {
  static int Main(string[] args) {
    var record = new StringBuilder();
    foreach (var n in new[] { "ACEOUTPOST_METERED_INVOCATION", "ACEOUTPOST_METERED_PARENT_INVOCATION", "HTTPS_PROXY" }) {
      var v = Environment.GetEnvironmentVariable(n);
      record.AppendLine("ENV:" + n + "=" + (v == null ? "<null>" : Convert.ToBase64String(Encoding.UTF8.GetBytes(v))));
    }
    record.AppendLine("PID:" + System.Diagnostics.Process.GetCurrentProcess().Id);
    if (args.Length > 1) { File.WriteAllText(args[1], record.ToString(), new UTF8Encoding(false)); }
    return 0;
  }
}
'@
    $cscOutput = & $cscPath /nologo /target:exe "/out:$($script:adapterProbeExe)" $probeSource 2>&1
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $script:adapterProbeExe)) {
      throw "Marker probe compilation failed (exit $LASTEXITCODE): $cscOutput"
    }
  }

  function ConvertFrom-MarkerProbeRecord {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $environment = [ordered]@{}
    $processId = $null
    foreach ($line in (Get-Content -LiteralPath $Path)) {
      if ($line.StartsWith('ENV:')) {
        $pair = $line.Substring(4).Split('=', 2)
        $environment[$pair[0]] = if ($pair[1] -eq '<null>') { $null } else { [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($pair[1])) }
      } elseif ($line.StartsWith('PID:')) {
        $processId = [int]$line.Substring(4)
      }
    }
    [pscustomobject]@{ Env = $environment; Pid = $processId }
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

    It 'declares the InvocationId and ParentInvocationId extension the adapter detects at run time' {
      # Contract section 5.3. The adapter's forward-compatibility check is exactly this key
      # lookup, so this is the seam that flips ChildMarkerDelivered.
      $parameters = (Get-Command Start-AceOutpostMeteredHarness).Parameters
      $parameters.ContainsKey('InvocationId') | Should -BeTrue
      $parameters.ContainsKey('ParentInvocationId') | Should -BeTrue
      $parameters['InvocationId'].Attributes |
        Where-Object { $_ -is [System.Management.Automation.ValidateNotNullOrEmptyAttribute] } |
        Should -Not -BeNullOrEmpty -Because 'an empty invocation id would stamp the child with nothing while claiming delivery'
    }

    It 'refuses an empty InvocationId before doing anything' {
      $outPath = Join-Path $TestDrive 'empty-invocation-must-not-exist.json'
      $arguments = @('-NonInteractive', '-File', $script:stubPath, $outPath)
      {
        Start-AceOutpostMeteredHarness -Client Codex -ProxyPort $script:proxyPort `
          -StateDirectory $script:stateDirectory -HarnessPath $script:pwshPath `
          -ArgumentList $arguments -InvocationId '' -Confirm:$false
      } | Should -Throw -ExceptionType ([System.Management.Automation.ParameterBindingException])
      Test-Path -LiteralPath $outPath | Should -BeFalse
    }

    It 'resolves the suite stub for Get-SecretATAP, never the real secret store' {
      # Safety interlock. If a future edit lets the real, module-exported Get-SecretATAP win,
      # this suite would resolve a live vault credential and write it into a child process.
      # Fail loudly here rather than silently there.
      #
      # The assertion is deliberately about INVOCATION, not about which commands are visible.
      # An earlier version also asserted the resolved command had no ModuleName, and that was
      # wrong: it tested the ambient module set rather than the safety property. It passed
      # locally and failed in the promoted-module run, where BuildTooling is loaded and its
      # exported Get-SecretATAP becomes visible to Get-Command - while the script-scoped stub
      # still won at invocation, as every composition test asserting the fake credential
      # proved by passing. What must hold is that the value the function actually receives is
      # the sentinel; who else is merely visible is not this test's business.
      (Get-SecretATAP -SecretName 'any') | Should -Be 'test-user:test-secret' -Because 'the stub must win invocation; a real value here means the live vault was reached'
    }

    It 'never lets a real credential reach the child, even if the stub is bypassed' {
      # The end-to-end form of the interlock: whatever resolved, the credential that landed in
      # the child block must be the sentinel. This is the assertion that would actually catch
      # a leak, because it inspects the composed result rather than the lookup.
      $launch = Invoke-ProbeLaunch -Client Codex
      $launch.Captured | Should -Not -BeNullOrEmpty
      $proxy = [string]$launch.Captured.Env.HTTP_PROXY
      $proxy | Should -Match 'test-user' -Because 'the child must carry the fake credential'
      $proxy | Should -Not -Match 'proxyCredential' -Because 'a SecretName must never appear as a value'
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

  Context 'Invocation markers (Task 15.190.e contract section 5.3)' {

    # The load-bearing property is OVERWRITE. The core copies the calling process's block into
    # the child's, so a marker this process inherited from its own metered launch would flow into
    # the child unchanged and stamp it with the grandparent's id. Each test below sets the
    # inherited value on THIS process (Process scope, restored in finally) and asserts what the
    # probe child actually received.

    It 'overwrites an inherited invocation marker rather than setting it only when absent' {
      Invoke-WithProcessEnvironment -Variables @{ $script:invocationMarkerName = 'stale-grandparent-id' } -ScriptBlock {
        $launch = Invoke-ProbeLaunch -Client Codex -InvocationId 'child-id'
        $launch.Captured | Should -Not -BeNullOrEmpty
        $launch.Captured.Env.ACEOUTPOST_METERED_INVOCATION | Should -BeExactly 'child-id' -Because 'a set-if-absent core would preserve the stale inherited id (contract section 5.3)'
        $launch.Captured.Env.ACEOUTPOST_METERED_INVOCATION | Should -Not -Be 'stale-grandparent-id'
      }
    }

    It 'sets the invocation marker in the child when none is inherited' {
      Invoke-WithProcessEnvironment -Variables @{ $script:invocationMarkerName = $null; $script:parentMarkerName = $null } -ScriptBlock {
        $launch = Invoke-ProbeLaunch -Client Codex -InvocationId 'child-id'
        $launch.Captured.Env.ACEOUTPOST_METERED_INVOCATION | Should -BeExactly 'child-id'
        $launch.Captured.Env.ACEOUTPOST_METERED_PARENT_INVOCATION | Should -BeNullOrEmpty
      }
    }

    It 'propagates the parent marker alongside the invocation marker' {
      $launch = Invoke-ProbeLaunch -Client Codex -InvocationId 'c' -ParentInvocationId 'p'
      $launch.Captured.Env.ACEOUTPOST_METERED_INVOCATION | Should -BeExactly 'c'
      $launch.Captured.Env.ACEOUTPOST_METERED_PARENT_INVOCATION | Should -BeExactly 'p'
    }

    It 'overwrites an inherited parent marker when a parent id is supplied' {
      Invoke-WithProcessEnvironment -Variables @{ $script:invocationMarkerName = 'stale-id'; $script:parentMarkerName = 'stale-parent-id' } -ScriptBlock {
        $launch = Invoke-ProbeLaunch -Client Codex -InvocationId 'c' -ParentInvocationId 'p'
        $launch.Captured.Env.ACEOUTPOST_METERED_INVOCATION | Should -BeExactly 'c'
        $launch.Captured.Env.ACEOUTPOST_METERED_PARENT_INVOCATION | Should -BeExactly 'p'
      }
    }

    It 'removes an inherited parent marker when no parent id is supplied' {
      Invoke-WithProcessEnvironment -Variables @{ $script:parentMarkerName = 'stale-parent-id' } -ScriptBlock {
        $launch = Invoke-ProbeLaunch -Client Codex -InvocationId 'c'
        $launch.Captured.Env.ACEOUTPOST_METERED_INVOCATION | Should -BeExactly 'c'
        $launch.Captured.Env.ACEOUTPOST_METERED_PARENT_INVOCATION |
          Should -BeNullOrEmpty -Because 'a stale parent id must not be inherited into a call that has no parent'
      }
    }

    It 'treats a whitespace or empty ParentInvocationId as absent and removes the inherited marker' -ForEach @(
      @{ Parent = '' }
      @{ Parent = '   ' }
    ) {
      Invoke-WithProcessEnvironment -Variables @{ $script:parentMarkerName = 'stale-parent-id' } -ScriptBlock {
        $launch = Invoke-ProbeLaunch -Client Codex -InvocationId 'c' -ParentInvocationId $Parent
        $launch.Captured.Env.ACEOUTPOST_METERED_INVOCATION | Should -BeExactly 'c'
        $launch.Captured.Env.ACEOUTPOST_METERED_PARENT_INVOCATION | Should -BeNullOrEmpty
      }
    }

    It 'leaves both markers exactly as inherited when InvocationId is not supplied' {
      # Opt-in only. A caller that never bound -InvocationId gets the pre-extension behaviour:
      # the child inherits whatever the caller carries, and nothing is stripped.
      Invoke-WithProcessEnvironment -Variables @{ $script:invocationMarkerName = 'inherited-id'; $script:parentMarkerName = 'inherited-parent-id' } -ScriptBlock {
        $launch = Invoke-ProbeLaunch -Client Codex
        $launch.Captured.Env.ACEOUTPOST_METERED_INVOCATION | Should -BeExactly 'inherited-id'
        $launch.Captured.Env.ACEOUTPOST_METERED_PARENT_INVOCATION | Should -BeExactly 'inherited-parent-id'
      }
    }

    It 'ignores ParentInvocationId when InvocationId is not supplied' {
      Invoke-WithProcessEnvironment -Variables @{ $script:invocationMarkerName = $null; $script:parentMarkerName = $null } -ScriptBlock {
        $launch = Invoke-ProbeLaunch -Client Codex -ParentInvocationId 'orphan-parent'
        $launch.Captured.Env.ACEOUTPOST_METERED_INVOCATION | Should -BeNullOrEmpty
        $launch.Captured.Env.ACEOUTPOST_METERED_PARENT_INVOCATION | Should -BeNullOrEmpty -Because 'the parent marker is honoured only alongside an invocation id'
      }
    }

    It 'does not report the marker names among the composed proxy variable names' {
      # ComposedVariableNames is the proxy composition report; the markers are identifiers,
      # not proxy configuration, and the existing assertion on that list must keep holding.
      $launch = Invoke-ProbeLaunch -Client Codex -InvocationId 'c' -ParentInvocationId 'p'
      $launch.Result.ComposedVariableNames | Should -Be @('HTTP_PROXY', 'HTTPS_PROXY', 'NO_PROXY', 'SSL_CERT_FILE')
    }

    It 'leaves the calling process block carrying exactly the marker values it had before (G2)' {
      Invoke-WithProcessEnvironment -Variables @{ $script:invocationMarkerName = 'parent-own-id'; $script:parentMarkerName = 'parent-own-parent-id' } -ScriptBlock {
        $null = Invoke-ProbeLaunch -Client Codex -InvocationId 'c' -ParentInvocationId 'p'
        $null = Invoke-ProbeLaunch -Client Codex -InvocationId 'c'
        [Environment]::GetEnvironmentVariable($script:invocationMarkerName, 'Process') | Should -BeExactly 'parent-own-id'
        [Environment]::GetEnvironmentVariable($script:parentMarkerName, 'Process') | Should -BeExactly 'parent-own-parent-id'
      }
      Invoke-WithProcessEnvironment -Variables @{ $script:invocationMarkerName = $null; $script:parentMarkerName = $null } -ScriptBlock {
        $null = Invoke-ProbeLaunch -Client Codex -InvocationId 'c' -ParentInvocationId 'p'
        [Environment]::GetEnvironmentVariable($script:invocationMarkerName, 'Process') | Should -BeNullOrEmpty
        [Environment]::GetEnvironmentVariable($script:parentMarkerName, 'Process') | Should -BeNullOrEmpty
      }
    }
  }

  Context 'End to end through the adapter (Invoke-AceOutpostMeteredPrompt)' {

    BeforeAll {
      if ($null -eq $script:adapterProbeExe) {
        Set-ItResult -Skipped -Because 'csc.exe was not found; the adapter path needs a compiled probe that tolerates the harness sub-command'
      }
      . $script:adapterFilePath
    }

    It 'delivers the adapter''s own invocation id to the child and reports ChildMarkerDelivered' {
      # The requirement contract section 5.3 left blocked. The adapter detects the extension by
      # parameter lookup and passes its fresh id; the probe must see THAT id, not an inherited one.
      Invoke-WithProcessEnvironment -Variables @{ $script:invocationMarkerName = $null; $script:parentMarkerName = $null } -ScriptBlock {
        $outPath = Join-Path $TestDrive ("adapter-probe-{0}.txt" -f ([guid]::NewGuid().ToString('N')))
        $result = Invoke-AceOutpostMeteredPrompt -Client Codex -Prompt 'a plain prompt' `
          -ProxyPort $script:proxyPort -StateDirectory $script:stateDirectory `
          -HarnessPath $script:adapterProbeExe -Confirm:$false -ArgumentList @($outPath)
        $captured = ConvertFrom-MarkerProbeRecord -Path $outPath

        $result.ChildMarkerDelivered | Should -BeTrue
        $result.ExitCode | Should -Be 0
        $result.InvocationId | Should -Match '^[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}$'
        $captured | Should -Not -BeNullOrEmpty
        $captured.Env.ACEOUTPOST_METERED_INVOCATION | Should -BeExactly $result.InvocationId
        $captured.Env.ACEOUTPOST_METERED_PARENT_INVOCATION | Should -BeNullOrEmpty -Because 'this call has no metered parent'
        $captured.Env.HTTPS_PROXY | Should -Be "http://test-user:test-secret@127.0.0.1:$($script:proxyPort)" -Because 'the launch must have gone through the core'
        $captured.Pid | Should -Be $result.HarnessProcessId
      }
    }

    It 'stamps a nested call''s child with the nested id and its parent, never the stale inherited id' {
      # The stale-inheritance finding, end to end: this process carries a parent's marker (as it
      # would inside a metered launch), the adapter reads it as ParentInvocationId, and the child
      # must receive the adapter's NEW id as its invocation and the inherited one as its parent.
      Invoke-WithProcessEnvironment -Variables @{ $script:invocationMarkerName = 'outer-invocation-id'; $script:parentMarkerName = $null } -ScriptBlock {
        $outPath = Join-Path $TestDrive ("adapter-nested-{0}.txt" -f ([guid]::NewGuid().ToString('N')))
        $result = Invoke-AceOutpostMeteredPrompt -Client Codex -Prompt 'nested prompt' `
          -ProxyPort $script:proxyPort -StateDirectory $script:stateDirectory `
          -HarnessPath $script:adapterProbeExe -Confirm:$false -ArgumentList @($outPath)
        $captured = ConvertFrom-MarkerProbeRecord -Path $outPath

        $result.ParentInvocationId | Should -BeExactly 'outer-invocation-id'
        $result.NestingEvidence | Should -Contain 'EnvironmentMarker'
        $result.ChildMarkerDelivered | Should -BeTrue
        $captured.Env.ACEOUTPOST_METERED_INVOCATION | Should -BeExactly $result.InvocationId
        $captured.Env.ACEOUTPOST_METERED_INVOCATION | Should -Not -Be 'outer-invocation-id' -Because 'the grandchild must not be stamped with the grandparent id (contract section 5.3)'
        $captured.Env.ACEOUTPOST_METERED_PARENT_INVOCATION | Should -BeExactly 'outer-invocation-id'
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
