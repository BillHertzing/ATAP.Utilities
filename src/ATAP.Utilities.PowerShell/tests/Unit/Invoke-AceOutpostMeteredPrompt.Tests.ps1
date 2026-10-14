# tests/Unit/Invoke-AceOutpostMeteredPrompt.Tests.ps1
#
# Task 15.190.e. Covers the three obligations board row 15.190.e names for the terminal-skill
# adapter - lossless prompt/argument pass-through, exit-code and stream relay, and nested-
# invocation identification - plus the fail-closed inheritance from the core and the honest
# per-client metering claim.
#
# WHY THE PROBE CHILD IS A COMPILED EXECUTABLE. The adapter places the harness's non-interactive
# flag ('exec' for Codex, '-p' for ClaudeCode) FIRST in the child's argument vector, before the
# caller's arguments, an end-of-options marker, and the prompt. pwsh cannot stand in for the
# harness here: it would read a leading 'exec' as a script path and fail. The probe is therefore
# a ~30-line C# console program compiled at test time by the .NET Framework csc.exe that ships
# with Windows - no SDK, no artifacts path, no network. Its Main(string[] args) receives the
# vector through the same CommandLineToArgvW rules ProcessStartInfo.ArgumentList quotes for, so a
# byte-for-byte assertion on what it recorded is a real assertion about the OS argument path.
#
# No live provider traffic is generated: the child under test is always the probe or pwsh, and
# the "proxy listener" is a bare loopback TcpListener that accepts a connection and serves
# nothing. The credential used throughout is the obviously fake literal 'test-user:test-secret'.
#
# The nested-invocation test spawns a pwsh CHILD with the invocation marker in ITS block, using
# ProcessStartInfo exactly as the core does. Nothing in this suite writes an environment variable
# in the test process or at any durable scope.

#Requires -Module Pester

BeforeAll {
  $coreFile = Join-Path $PSScriptRoot '..\..\public\Start-AceOutpostMeteredHarness.ps1'
  $functionFile = Join-Path $PSScriptRoot '..\..\public\Invoke-AceOutpostMeteredPrompt.ps1'
  . $coreFile
  . $functionFile
  $script:coreFilePath = (Resolve-Path $coreFile).Path
  $script:functionFilePath = (Resolve-Path $functionFile).Path
  if (Get-Module -ListAvailable -Name PSFramework) {
    Import-Module PSFramework -ErrorAction SilentlyContinue
  }

  $script:pwshPath = (Get-Command pwsh -CommandType Application | Select-Object -First 1).Source

  $script:stateDirectory = Join-Path $TestDrive 'AceOutpostState'
  New-Item -ItemType Directory -Path $script:stateDirectory -Force | Out-Null
  $script:rootPem = Join-Path $script:stateDirectory 'AceOutpost-Interception-Root.pem'
  Set-Content -LiteralPath $script:rootPem -Value 'public-root-placeholder'

  $script:emptyStateDirectory = Join-Path $TestDrive 'EmptyState'
  New-Item -ItemType Directory -Path $script:emptyStateDirectory -Force | Out-Null

  # Obviously fake. Never a real credential.
  $script:fakeCredential = 'test-user:test-secret'
  function Get-SecretATAP {
    param([string]$SecretName)
    $script:fakeCredential
  }

  # Probe child. Records every argument it received as base64 of its UTF-8 bytes (so nothing
  # about the record format can lose or alter a byte), the two invocation-marker names plus one
  # composed proxy name (to prove it was launched through the core), and its own pid. Optional
  # directives in the argument vector drive stdout, stderr, a large stdout flood, and the exit
  # code. The record path is args[1] - the first caller-supplied argument after the harness flag.
  $cscPath = 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe'
  if (-not (Test-Path -LiteralPath $cscPath -PathType Leaf)) {
    throw "csc.exe was not found at '$cscPath'; this suite compiles its probe child with the .NET Framework compiler that ships with Windows."
  }
  $probeSource = Join-Path $TestDrive 'probe.cs'
  $script:probeExe = Join-Path $TestDrive 'probe.exe'
  Set-Content -LiteralPath $probeSource -Encoding utf8 -Value @'
using System;
using System.IO;
using System.Text;
class Probe {
  static int Main(string[] args) {
    var record = new StringBuilder();
    int exitCode = 0;
    foreach (var a in args) { record.AppendLine("ARG:" + Convert.ToBase64String(Encoding.UTF8.GetBytes(a))); }
    foreach (var n in new[] { "ACEOUTPOST_METERED_INVOCATION", "ACEOUTPOST_METERED_PARENT_INVOCATION", "HTTPS_PROXY" }) {
      var v = Environment.GetEnvironmentVariable(n);
      record.AppendLine("ENV:" + n + "=" + (v == null ? "<null>" : Convert.ToBase64String(Encoding.UTF8.GetBytes(v))));
    }
    record.AppendLine("PID:" + System.Diagnostics.Process.GetCurrentProcess().Id);
    foreach (var a in args) {
      if (a.StartsWith("--stdout=")) { Console.Out.Write(a.Substring(9)); }
      else if (a.StartsWith("--stderr=")) { Console.Error.Write(a.Substring(9)); }
      else if (a.StartsWith("--exit=")) { exitCode = int.Parse(a.Substring(7)); }
      else if (a.StartsWith("--flood=")) { var line = new string('x', 80); int n = int.Parse(a.Substring(8)); for (int i = 0; i < n; i++) { Console.Out.WriteLine(line); } }
    }
    if (args.Length > 1) { File.WriteAllText(args[1], record.ToString(), new UTF8Encoding(false)); }
    return exitCode;
  }
}
'@
  $cscOutput = & $cscPath /nologo /target:exe "/out:$($script:probeExe)" $probeSource 2>&1
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $script:probeExe)) {
    throw "Probe compilation failed (exit $LASTEXITCODE): $cscOutput"
  }

  # A bare loopback listener standing in for AceOutpostService's proxy endpoint. Ports are chosen
  # dynamically, and must be: 50060-50159 is an OS-reserved exclusion range on this host and
  # 50055 - the AceOutpost default - may be in use by the real listener.
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
  $script:deadPort = $script:freePorts[1]

  function ConvertFrom-ProbeRecord {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $arguments = [System.Collections.Generic.List[string]]::new()
    $environment = [ordered]@{}
    $processId = $null
    foreach ($line in (Get-Content -LiteralPath $Path)) {
      if ($line.StartsWith('ARG:')) {
        $arguments.Add([System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($line.Substring(4))))
      } elseif ($line.StartsWith('ENV:')) {
        $pair = $line.Substring(4).Split('=', 2)
        $environment[$pair[0]] = if ($pair[1] -eq '<null>') { $null } else { [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($pair[1])) }
      } elseif ($line.StartsWith('PID:')) {
        $processId = [int]$line.Substring(4)
      }
    }
    [pscustomobject]@{ Args = $arguments.ToArray(); Env = $environment; Pid = $processId }
  }

  function Invoke-ProbePrompt {
    param(
      [string]$Client = 'Codex',
      [string]$Prompt = 'a plain prompt',
      [string[]]$ExtraArguments = @(),
      [int]$Port = $script:proxyPort,
      [string]$StateDirectory = $script:stateDirectory,
      [switch]$OmitEndOfOptionsMarker
    )
    $outPath = Join-Path $TestDrive ("probe-{0}.txt" -f ([guid]::NewGuid().ToString('N')))
    $arguments = @($outPath) + $ExtraArguments
    $result = Invoke-AceOutpostMeteredPrompt `
      -Client $Client `
      -Prompt $Prompt `
      -ProxyPort $Port `
      -StateDirectory $StateDirectory `
      -HarnessPath $script:probeExe `
      -OmitEndOfOptionsMarker:$OmitEndOfOptionsMarker `
      -Confirm:$false `
      -ArgumentList $arguments
    [pscustomobject]@{
      Result   = $result
      OutPath  = $outPath
      Captured = ConvertFrom-ProbeRecord -Path $outPath
    }
  }
}

AfterAll {
  if ($null -ne $script:listener) { $script:listener.Stop() }
  Remove-Item -LiteralPath Function:\Get-SecretATAP -ErrorAction SilentlyContinue
}

Describe 'Invoke-AceOutpostMeteredPrompt' -Tag 'Unit' {

  Context 'Seam - the adapter signature (packet sections 4.1 and 4.4)' {

    It 'takes a mandatory Prompt and collects ArgumentList from the remaining arguments' {
      $parameters = (Get-Command Invoke-AceOutpostMeteredPrompt).Parameters
      $promptAttribute = $parameters['Prompt'].Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }
      @($promptAttribute).Mandatory | Should -Contain $true
      $listAttribute = $parameters['ArgumentList'].Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }
      @($listAttribute).ValueFromRemainingArguments | Should -Contain $true
    }

    It 'accepts both clients the core accepts, including ClaudeCode' {
      $setAttribute = (Get-Command Invoke-AceOutpostMeteredPrompt).Parameters['Client'].Attributes |
        Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
      $setAttribute.ValidValues | Should -Be @('ClaudeCode', 'Codex')
    }

    It 'passes only a SecretName through and offers no credential, scope, or persistence parameter' {
      $parameters = (Get-Command Invoke-AceOutpostMeteredPrompt).Parameters
      $parameters.ContainsKey('CredentialSecretName') | Should -BeTrue
      foreach ($forbidden in @('Credential', 'Password', 'ProxyUrl', 'Scope', 'Persist', 'LaunchMode')) {
        $parameters.ContainsKey($forbidden) | Should -BeFalse -Because "section 4.1 forbids -$forbidden on any adapter; LaunchMode is fixed to Wait for a non-interactive prompt"
      }
    }

    It 'resolves the suite stub for Get-SecretATAP, never the real secret store' {
      # Safety interlock, asserted about INVOCATION rather than visibility (SC-0410): the value
      # the core actually receives must be the sentinel, whoever else is visible to Get-Command.
      (Get-SecretATAP -SecretName 'any') | Should -Be 'test-user:test-secret' -Because 'the stub must win invocation; a real value here means the live vault was reached'
    }

    It 'never resolves a credential, builds a proxy URL, or writes an environment variable' {
      # Structural: the adapter has no credential path of its own and no scope of its own.
      $source = Get-Content -LiteralPath $script:functionFilePath -Raw
      $source | Should -Not -Match 'Get-SecretATAP'
      $source | Should -Not -Match 'SetEnvironmentVariable'
      $source | Should -Not -Match '\$env:'
      $source | Should -Not -Match 'EnvironmentVariableTarget'
      $source | Should -Not -Match '@127\.0\.0\.1'
      $source | Should -Not -Match 'NODE_TLS_REJECT_UNAUTHORIZED\s*=\s*[''"]?0' -Because 'the adapter may explicitly enforce TLS verification with value 1 but must never disable it'
    }
  }

  Context 'Prompt and argument pass-through, never interpreted' {

    It 'places the harness flag, caller arguments, the end-of-options marker, and the prompt as discrete items in that order' {
      $launch = Invoke-ProbePrompt -Client Codex -Prompt 'the prompt' -ExtraArguments @('--model', 'o4-mini')
      $launch.Captured | Should -Not -BeNullOrEmpty
      $launch.Captured.Args | Should -Be @('exec', $launch.OutPath, '--model', 'o4-mini', '--', 'the prompt')
      $launch.Result.HarnessFlag | Should -Be @('exec')
      $launch.Result.ArgumentCount | Should -Be 6
    }

    It 'uses -p for ClaudeCode and exec for Codex' {
      $claude = Invoke-ProbePrompt -Client ClaudeCode -Prompt 'x'
      $claude.Captured.Args[0] | Should -BeExactly '-p'
      $codex = Invoke-ProbePrompt -Client Codex -Prompt 'x'
      $codex.Captured.Args[0] | Should -BeExactly 'exec'
    }

    It 'automatically supplies Claude Code invocation-scoped CA settings from the preflighted state directory' {
      $claude = Invoke-ProbePrompt -Client ClaudeCode -Prompt 'x'
      $claude.Captured.Args | Should -HaveCount 6
      $claude.Captured.Args[0] | Should -BeExactly '-p'
      $claude.Captured.Args[1] | Should -BeExactly $claude.OutPath
      $claude.Captured.Args[2] | Should -BeExactly '--settings'
      $settings = $claude.Captured.Args[3] | ConvertFrom-Json
      $settings.env.NODE_EXTRA_CA_CERTS | Should -BeExactly $script:rootPem
      $settings.env.NODE_USE_SYSTEM_CA | Should -BeExactly '1'
      $settings.env.NODE_TLS_REJECT_UNAUTHORIZED | Should -BeExactly '1'
      $claude.Captured.Args[4] | Should -BeExactly '--'
      $claude.Captured.Args[5] | Should -BeExactly 'x'
    }

    It 'fails closed before child creation when a Claude caller supplies a conflicting settings option' -TestCases @(
      @{ ConflictingArgument = '--settings' }
      @{ ConflictingArgument = '--settings={"env":{}}' }
    ) {
      param($ConflictingArgument)
      $outPath = Join-Path $TestDrive ("conflict-{0}.txt" -f ([guid]::NewGuid().ToString('N')))
      {
        Invoke-AceOutpostMeteredPrompt -Client ClaudeCode -Prompt 'p' -ProxyPort $script:proxyPort `
          -StateDirectory $script:stateDirectory -HarnessPath $script:probeExe -Confirm:$false `
          -ArgumentList @($outPath, $ConflictingArgument)
      } | Should -Throw '*reserves that option*'
      Test-Path -LiteralPath $outPath | Should -BeFalse
    }

    It 'delivers a prompt containing spaces, both quote kinds, a newline, a dollar sign, a backtick, and a literal -- byte-for-byte' {
      $awkward = "line one with spaces`nline `"two`" has 'both' quotes, `$notAVariable, a `` backtick, -- and a trailing backslash\"
      $launch = Invoke-ProbePrompt -Client Codex -Prompt $awkward
      $launch.Captured | Should -Not -BeNullOrEmpty
      $launch.Captured.Args[-1] | Should -BeExactly $awkward -Because 'the prompt must arrive unchanged; the adapter never joins, quotes, or interprets it'
      $launch.Captured.Args[-2] | Should -BeExactly '--'
    }

    It 'delivers a prompt that begins with a dash after the end-of-options marker, so the harness cannot read it as an option' {
      $launch = Invoke-ProbePrompt -Client Codex -Prompt '--not-an-option'
      $launch.Captured.Args[-2] | Should -BeExactly '--'
      $launch.Captured.Args[-1] | Should -BeExactly '--not-an-option'
    }

    It 'delivers caller arguments with spaces, quotes, and newlines byte-for-byte and in order' {
      $awkwardArguments = @('has "double" quotes', "has 'single' quotes", "line one`nline two", 'C:\path with spaces\file.txt', '--')
      $launch = Invoke-ProbePrompt -Client Codex -Prompt 'p' -ExtraArguments $awkwardArguments
      $received = $launch.Captured.Args
      # Layout: flag, outPath, <awkwardArguments...>, '--', prompt.
      $received.Count | Should -Be (2 + $awkwardArguments.Count + 2)
      for ($i = 0; $i -lt $awkwardArguments.Count; $i++) {
        $received[2 + $i] | Should -BeExactly $awkwardArguments[$i] -Because "caller argument $i must arrive byte-for-byte"
      }
    }

    It 'omits the end-of-options marker only when asked' {
      $launch = Invoke-ProbePrompt -Client Codex -Prompt 'p' -OmitEndOfOptionsMarker
      $launch.Captured.Args | Should -Be @('exec', $launch.OutPath, 'p')
      $launch.Result.EndOfOptionsMarker | Should -BeFalse
    }

    It 'accepts an empty prompt and still delivers it as a discrete item' {
      $launch = Invoke-ProbePrompt -Client Codex -Prompt ''
      $launch.Captured.Args | Should -Be @('exec', $launch.OutPath, '--', '')
    }
  }

  Context 'Exit code and both streams reach the caller (R-34)' {

    It 'propagates exit code 0' {
      $launch = Invoke-ProbePrompt -ExtraArguments @('--exit=0')
      $launch.Result.ExitCode | Should -Be 0
      $launch.Result.Started | Should -BeTrue
    }

    It 'propagates a non-zero exit code' {
      $launch = Invoke-ProbePrompt -ExtraArguments @('--exit=42')
      $launch.Result.ExitCode | Should -Be 42
    }

    It 'captures stdout and stderr independently' {
      $launch = Invoke-ProbePrompt -ExtraArguments @('--stdout=out-marker', '--stderr=err-marker', '--exit=7')
      $launch.Result.StdOut | Should -BeExactly 'out-marker'
      $launch.Result.StdErr | Should -BeExactly 'err-marker'
      $launch.Result.ExitCode | Should -Be 7
    }

    It 'drains a large stdout payload without deadlocking' {
      # A payload well past the pipe buffer: waiting before draining would hang here.
      $launch = Invoke-ProbePrompt -ExtraArguments @('--flood=20000')
      $launch.Result.ExitCode | Should -Be 0
      $launch.Result.StdOut.Length | Should -BeGreaterThan 1600000
    }

    It 'returns exactly one object and writes nothing else to the pipeline' {
      $outPath = Join-Path $TestDrive 'single-object.txt'
      $output = @(Invoke-AceOutpostMeteredPrompt -Client Codex -Prompt 'p' -ProxyPort $script:proxyPort `
          -StateDirectory $script:stateDirectory -HarnessPath $script:probeExe -Confirm:$false `
          -ArgumentList @($outPath, '--stdout=should-not-be-on-the-pipeline'))
      $output.Count | Should -Be 1
      $output[0] | Should -BeOfType [pscustomobject]
      $output[0].StdOut | Should -BeExactly 'should-not-be-on-the-pipeline'
    }

    It 'reports the proxy port and endpoint without userinfo, and no credential anywhere in the result' {
      $launch = Invoke-ProbePrompt
      $launch.Result.ProxyPort | Should -Be $script:proxyPort
      $launch.Result.ProxyEndpoint | Should -Be "http://127.0.0.1:$($script:proxyPort)"
      ($launch.Result | ConvertTo-Json -Depth 6) | Should -Not -Match 'test-secret'
    }

    It 'launched the probe through the core, which composed the proxy block' {
      $launch = Invoke-ProbePrompt
      $launch.Captured.Env.HTTPS_PROXY | Should -Be "http://test-user:test-secret@127.0.0.1:$($script:proxyPort)"
      $launch.Result.HarnessProcessId | Should -Be $launch.Captured.Pid
    }
  }

  Context 'Nested-invocation identification' {

    It 'generates a distinct InvocationId per call' {
      $first = Invoke-ProbePrompt
      $second = Invoke-ProbePrompt
      $first.Result.InvocationId | Should -Match '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      $second.Result.InvocationId | Should -Not -Be $first.Result.InvocationId
      $first.Result.CallerProcessId | Should -Be $PID
    }

    It 'reports no parent marker and delivers a new marker when the current process carries none' {
      $launch = Invoke-ProbePrompt
      $launch.Result.ParentInvocationId | Should -BeNullOrEmpty
      $launch.Result.NestingEvidence | Should -Not -Contain 'EnvironmentMarker'
      $launch.Result.ChildMarkerDelivered | Should -BeTrue
      $launch.Captured.Env.ACEOUTPOST_METERED_INVOCATION | Should -BeExactly $launch.Result.InvocationId
      $launch.Captured.Env.ACEOUTPOST_METERED_PARENT_INVOCATION | Should -BeNullOrEmpty
      (Get-Command Start-AceOutpostMeteredHarness).Parameters.ContainsKey('InvocationId') | Should -BeTrue
    }

    It 'records the process ancestry and flags a harness ancestor consistently with it' {
      $launch = Invoke-ProbePrompt
      $ancestry = @($launch.Result.ProcessAncestry)
      $ancestry.Count | Should -BeGreaterThan 0
      $harnessAncestor = $ancestry | Where-Object { ($_ -split ':', 2)[1] -in @('claude', 'codex') } | Select-Object -First 1
      if ($null -ne $harnessAncestor) {
        # This suite is itself running inside a harness (unmetered or not); the walk must say so.
        $launch.Result.AncestorHarnessProcessId | Should -Be ([int]($harnessAncestor -split ':', 2)[0])
        $launch.Result.NestingEvidence | Should -Contain 'ProcessAncestry'
        $launch.Result.IsNested | Should -BeTrue
      } else {
        $launch.Result.AncestorHarnessProcessId | Should -BeNullOrEmpty
        $launch.Result.NestingEvidence | Should -Not -Contain 'ProcessAncestry'
      }
    }

    It 'reads an inherited invocation marker as its parent id when it runs inside a metered launch' {
      # The adapter runs in a CHILD pwsh whose block carries the marker - composed here with
      # ProcessStartInfo exactly as the core composes a child block, never by writing the test
      # process's own environment. The child then makes a real metered launch of the probe.
      $parentId = [guid]::NewGuid().ToString('D')
      $nestedScript = Join-Path $TestDrive 'nested-adapter.ps1'
      $nestedOut = Join-Path $TestDrive 'nested-result.json'
      $grandchildOut = Join-Path $TestDrive 'nested-probe.txt'
      Set-Content -LiteralPath $nestedScript -Encoding utf8 -Value @'
param([string]$CorePath, [string]$AdapterPath, [string]$ProbeExe, [string]$StateDirectory, [int]$Port, [string]$OutPath, [string]$GrandchildOutPath)
if (Get-Module -ListAvailable -Name PSFramework) { Import-Module PSFramework -ErrorAction SilentlyContinue }
if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) { function Write-PSFMessage { param($FunctionName, $ModuleName, $Level, $Message, $Tag) } }
. $CorePath
. $AdapterPath
function Get-SecretATAP { param([string]$SecretName) 'test-user:test-secret' }
$result = Invoke-AceOutpostMeteredPrompt -Client Codex -Prompt 'nested prompt' -ProxyPort $Port `
  -StateDirectory $StateDirectory -HarnessPath $ProbeExe -Confirm:$false -ArgumentList @($GrandchildOutPath)
$result | Select-Object InvocationId, ParentInvocationId, IsNested, NestingEvidence, ProcessAncestry, CallerProcessId, ExitCode, ChildMarkerDelivered |
  ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $OutPath -Encoding utf8
'@
      $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
      $startInfo.FileName = $script:pwshPath
      $startInfo.UseShellExecute = $false
      $startInfo.RedirectStandardOutput = $true
      $startInfo.RedirectStandardError = $true
      foreach ($item in @('-NonInteractive', '-File', $nestedScript, $script:coreFilePath, $script:functionFilePath, $script:probeExe, $script:stateDirectory, "$($script:proxyPort)", $nestedOut, $grandchildOut)) {
        $null = $startInfo.ArgumentList.Add($item)
      }
      $startInfo.Environment['ACEOUTPOST_METERED_INVOCATION'] = $parentId
      $child = [System.Diagnostics.Process]::new()
      $child.StartInfo = $startInfo
      try {
        $null = $child.Start()
        $stdoutTask = $child.StandardOutput.ReadToEndAsync()
        $stderrTask = $child.StandardError.ReadToEndAsync()
        $child.WaitForExit()
        $childError = $stderrTask.GetAwaiter().GetResult()
        $null = $stdoutTask.GetAwaiter().GetResult()
        $child.ExitCode | Should -Be 0 -Because "the nested adapter run must succeed; stderr: $childError"
      } finally {
        $child.Dispose()
      }

      $nested = Get-Content -LiteralPath $nestedOut -Raw | ConvertFrom-Json
      $nested.ParentInvocationId | Should -Be $parentId
      $nested.InvocationId | Should -Not -Be $parentId
      $nested.IsNested | Should -BeTrue
      @($nested.NestingEvidence) | Should -Contain 'EnvironmentMarker'
      @($nested.ProcessAncestry) | Should -Contain ('{0}:pwsh' -f $PID) -Because 'the nested call must see this test process in its ancestry'
      $nested.ExitCode | Should -Be 0

      # Contract section 5.3 requires the child marker to identify this invocation while the
      # parent marker preserves the inherited caller identity.
      $grandchild = ConvertFrom-ProbeRecord -Path $grandchildOut
      $grandchild | Should -Not -BeNullOrEmpty
      $grandchild.Env.ACEOUTPOST_METERED_INVOCATION | Should -BeExactly $nested.InvocationId
      $grandchild.Env.ACEOUTPOST_METERED_INVOCATION | Should -Not -Be $parentId
      $grandchild.Env.ACEOUTPOST_METERED_PARENT_INVOCATION | Should -BeExactly $parentId
      $nested.ChildMarkerDelivered | Should -BeTrue
    }

    It 'leaves the test process carrying no invocation marker after every call' {
      $null = Invoke-ProbePrompt
      [Environment]::GetEnvironmentVariable('ACEOUTPOST_METERED_INVOCATION', 'Process') | Should -BeNullOrEmpty
      [Environment]::GetEnvironmentVariable('ACEOUTPOST_METERED_PARENT_INVOCATION', 'Process') | Should -BeNullOrEmpty
    }
  }

  Context 'Honest metering claim per client' {

    It 'reports Codex as harness-traffic-only metering' {
      $launch = Invoke-ProbePrompt -Client Codex
      $launch.Result.MeteringClaim | Should -Match '^Harness traffic only'
      $launch.Result.MeteringClaim | Should -Match 'inherit = "core"'
    }

    It 'accepts ClaudeCode, launches through the core, and reports truthful harness metering with the child-tool boundary' {
      $launch = Invoke-ProbePrompt -Client ClaudeCode
      $launch.Result.Client | Should -Be 'ClaudeCode'
      $launch.Result.ClientId | Should -Be 'claude-code'
      $launch.Result.ExitCode | Should -Be 0
      $launch.Result.MeteringClaim | Should -Match '^Harness traffic is metered'
      $launch.Result.MeteringClaim | Should -Match 'invocation-scoped Node CA settings'
      $launch.Result.MeteringClaim | Should -Match '15\.190\.f section 4'
      $launch.Result.TrustVariable | Should -Be 'NODE_EXTRA_CA_CERTS'
    }

    It 'documents automatic Claude trust and both clients honest coverage boundaries in help' {
      $help = Get-Help Invoke-AceOutpostMeteredPrompt -Full | Out-String
      $help | Should -Match 'invocation-scoped --settings'
      $help | Should -Match 'child-tool isolation is not claimed'
      $help | Should -Match 'Harness traffic only'
    }
  }

  Context 'Fail closed - core refusals propagate as terminating errors (packet section 6)' {

    It 'throws when no proxy listener answers, and creates no child' {
      $outPath = Join-Path $TestDrive 'dead-listener-must-not-exist.txt'
      {
        Invoke-AceOutpostMeteredPrompt -Client Codex -Prompt 'p' -ProxyPort $script:deadPort `
          -StateDirectory $script:stateDirectory -HarnessPath $script:probeExe -Confirm:$false -ArgumentList @($outPath)
      } | Should -Throw '*No AceOutpost proxy listener answered*'
      Test-Path -LiteralPath $outPath | Should -BeFalse -Because 'fail-closed means never reaching CreateProcess'
    }

    It 'throws when the interception root is missing' {
      {
        Invoke-ProbePrompt -StateDirectory $script:emptyStateDirectory
      } | Should -Throw '*interception root was not found*'
    }

    It 'throws when the credential does not resolve to a valid pair, naming the SecretName and leaking no value' {
      $saved = $script:fakeCredential
      try {
        $script:fakeCredential = 'unparseable-sentinel-value'
        $message = $null
        try { $null = Invoke-ProbePrompt } catch { $message = $_.Exception.Message }
        $message | Should -Match 'not a valid username:secret pair'
        $message | Should -Match 'proxyCredential\.Ace\.AceOutpost\.codex'
        $message | Should -Not -Match 'sentinel'
      } finally {
        $script:fakeCredential = $saved
      }
    }

    It 'passes CredentialSecretName through to the core untouched' {
      $launch = Invoke-AceOutpostMeteredPrompt -Client Codex -Prompt 'p' -ProxyPort $script:proxyPort `
        -StateDirectory $script:stateDirectory -HarnessPath $script:probeExe -Confirm:$false `
        -CredentialSecretName 'proxyCredential.Ace.AceOutpost.custom-name' -ArgumentList @((Join-Path $TestDrive 'named.txt'))
      $launch.CredentialSecretName | Should -Be 'proxyCredential.Ace.AceOutpost.custom-name'
    }

    It 'contains no try/catch around the core call, so a refusal is never softened into a result' {
      $ast = [System.Management.Automation.Language.Parser]::ParseFile($script:functionFilePath, [ref]$null, [ref]$null)
      $coreCalls = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.CommandAst] -and $args[0].GetCommandName() -eq 'Start-AceOutpostMeteredHarness' }, $true)
      $coreCalls.Count | Should -Be 1
      $enclosingTry = $coreCalls[0].Parent
      while ($null -ne $enclosingTry -and -not ($enclosingTry -is [System.Management.Automation.Language.TryStatementAst])) { $enclosingTry = $enclosingTry.Parent }
      $enclosingTry | Should -BeNullOrEmpty -Because 'a skill that thinks it ran metered when it did not is the failure this adapter exists to prevent'
    }

    It 'creates no child under WhatIf' {
      $outPath = Join-Path $TestDrive 'whatif-must-not-exist.txt'
      $result = Invoke-AceOutpostMeteredPrompt -Client Codex -Prompt 'p' -ProxyPort $script:proxyPort `
        -StateDirectory $script:stateDirectory -HarnessPath $script:probeExe -WhatIf -ArgumentList @($outPath)
      $result.Started | Should -BeFalse
      $result.ExitCode | Should -BeNullOrEmpty
      $result.InvocationId | Should -Not -BeNullOrEmpty
      Test-Path -LiteralPath $outPath | Should -BeFalse
    }
  }
}
