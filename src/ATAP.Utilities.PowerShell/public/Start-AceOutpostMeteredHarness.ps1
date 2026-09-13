function Start-AceOutpostMeteredHarness {
  <#
  .SYNOPSIS
    Starts one AI harness child process with a private AceOutpost proxy environment block.
  .DESCRIPTION
    Composes the documented AceOutpost forward-proxy environment (HTTP_PROXY, HTTPS_PROXY,
    NO_PROXY, and the client's interception-root trust variable) and applies it to exactly one
    child process at process creation. The block is a copy of the current process's environment
    plus those entries; it is handed to the child by CreateProcess and is never written to the
    calling process, to another process, or to the User or Machine environment scopes.

    This is the shared launch core ratified by Task 15.190.a. It exists because
    Set-AceOutpostProxyEnvironment can only make the proxy credential durable by persisting it
    at User or Machine scope, where every process on the host inherits it. The credential is
    resolved from the approved secret store, interpolated into the child's block, and scrubbed
    from local variables; it is never returned, logged, or persisted.

    The function fails closed. Three preconditions are all checked before CreateProcess, so a
    failure never leaves a partially proxied harness running: the interception root must exist,
    the loopback proxy listener must answer, and the proxy credential must resolve to a valid
    username:secret pair. There is no degraded, unproxied fallback mode, and the function never
    sets NODE_TLS_REJECT_UNAUTHORIZED at any value under any failure condition.
  .PARAMETER Client
    The AceOutpost client identity: ClaudeCode or Codex. Mapped internally to the service's
    clientId, matching Set-AceOutpostProxyEnvironment.
  .PARAMETER LaunchMode
    Wait runs the child to completion, drains its redirected output, and returns its exit code.
    Detach starts the child and returns immediately without waiting.
  .PARAMETER ProxyPort
    AceOutpost's loopback proxy listener port. The documented default is 50055.
  .PARAMETER NoProxy
    Value written to the child's NO_PROXY entry.
  .PARAMETER CredentialSecretName
    SecretName resolved through Get-SecretATAP. Defaults to the documented per-client name.
    Only a name is accepted; there is deliberately no credential, password, or proxy-URL
    parameter, so the sole credential path is the approved secret store.
  .PARAMETER StateDirectory
    Directory in which AceOutpostService publishes its public interception root.
  .PARAMETER WorkingDirectory
    Working directory for the child process. Defaults to the caller's current directory.
  .PARAMETER HarnessPath
    Full path to the harness executable. When omitted the client's CLI is resolved from PATH.
  .PARAMETER ChromiumProxyBridge
    Starts a process-private loopback proxy bridge and supplies Chromium command-line proxy
    switches to the child. Use this for packaged desktop applications that ignore HTTP_PROXY
    and HTTPS_PROXY. The bridge accepts only the launched process and its descendants, injects
    the AceOutpost proxy credential upstream, disables QUIC, and requires LaunchMode Wait so the
    bridge lifetime exactly matches the desktop process lifetime.
  .PARAMETER InvocationId
    Identifier of this metered call, written into the child's block as
    ACEOUTPOST_METERED_INVOCATION. When supplied it is assigned unconditionally, so any value the
    calling process inherited is overwritten rather than preserved. When omitted, neither marker
    name is touched and the child inherits whatever the calling process carries, exactly as it
    did before this parameter existed. The value is an opaque identifier, never a secret; the
    adapter Invoke-AceOutpostMeteredPrompt supplies a fresh GUID per call.
  .PARAMETER ParentInvocationId
    Identifier of the enclosing metered call, written into the child's block as
    ACEOUTPOST_METERED_PARENT_INVOCATION. Honoured only when InvocationId is also supplied. When
    InvocationId is supplied and this is omitted, empty, or whitespace, the parent marker is
    REMOVED from the child's block so a stale inherited parent id cannot flow through.
  .PARAMETER ArgumentList
    Arguments passed to the child verbatim. Collected from the remaining arguments and never
    parsed, re-quoted, or interpreted by this function.
  .OUTPUTS
    PSCustomObject with redacted launch metadata. The proxy endpoint it reports carries no
    userinfo.
  .EXAMPLE
    Start-AceOutpostMeteredHarness -Client Codex -LaunchMode Wait exec -- 'Summarize this repo'

    Runs a metered Codex prompt to completion and returns its exit code and drained output. The
    end-of-options marker precedes the prompt because in the Codex CLI '-p' is --profile, not a
    prompt flag; this function passes the vector through without interpreting any of it.
  .EXAMPLE
    Start-AceOutpostMeteredHarness -Client Codex -LaunchMode Detach

    Starts a metered interactive Codex session and returns without waiting.
  .EXAMPLE
    Start-AceOutpostMeteredHarness -Client ClaudeCode -LaunchMode Wait `
      -HarnessPath 'C:\Program Files\Claude\Claude.exe' -ChromiumProxyBridge

    Starts packaged Claude Desktop through a process-private authenticated proxy bridge and
    waits for the desktop process to exit.
  .NOTES
    Ratified design: Task15.190.a-SharedLaunchCoreDecisionPacket.md, sections 2, 2.1, 3, and 6.

    Two implementation notes that differ from a literal reading of that packet, both recorded
    as coverage findings for Task 15.190.c:

    1. Packet section 2.1 proposes setting lowercase twins (http_proxy, https_proxy) alongside
       the uppercase names. On Windows that is not expressible:
       ProcessStartInfo.Environment is an ordinal-case-insensitive dictionary, so assigning a
       second casing overwrites the first entry rather than adding one. The intent is satisfied
       regardless, because the Windows environment block is itself case-insensitive and a child
       reading the lowercase spelling resolves the uppercase entry. Only canonical uppercase
       names are set.
    2. NODE_TLS_REJECT_UNAUTHORIZED is removed from the child's block when it is inherited from
       the parent. The packet forbids ever setting it; allowing an ambient certificate-
       verification bypass to flow into the metered child would defeat the same guarantee by a
       different route. Removal is never a substitute for trust material.
    3. The invocation markers (Task 15.190.e contract section 5.3) are OVERWRITTEN, not set when
       absent. The child's block starts as a copy of this process's block, so a marker this
       process inherited from its own metered launch would otherwise flow unchanged into the
       child: a harness started from a nested call would be stamped with its grandparent's id,
       silently mis-attributing the exchange. That stale inheritance was observed in the
       adapter's nested test before this extension existed. Both markers are therefore assigned
       or removed at composition whenever -InvocationId is bound, and left exactly as inherited
       when it is not, so callers that do not opt in see no change in behaviour.

    Packaged Chromium clients do not consistently honor proxy environment variables. The
    ChromiumProxyBridge path therefore supplies explicit Chromium routing switches while
    preserving certificate verification and the same child-only environment contract.
  .LINK
    AceOutpost.Windows/Documentation/AceOutpostService-ProxyEnablement.md
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [ValidateSet('ClaudeCode', 'Codex')]
    [string]$Client,

    [ValidateSet('Wait', 'Detach')]
    [string]$LaunchMode = 'Wait',

    [ValidateRange(50000, 50099)]
    [int]$ProxyPort = 50055,

    [ValidateNotNullOrEmpty()]
    [string]$NoProxy = 'localhost,127.0.0.1,::1',

    [ValidateNotNullOrEmpty()]
    [string]$CredentialSecretName,

    [ValidateNotNullOrEmpty()]
    [string]$StateDirectory = 'C:\ProgramData\ATAP\AceOutpostService\state',

    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$WorkingDirectory = $PWD.ProviderPath,

    [string]$HarnessPath,

    [switch]$ChromiumProxyBridge,

    [ValidateNotNullOrEmpty()]
    [string]$InvocationId,

    [string]$ParentInvocationId,

    [Parameter(ValueFromRemainingArguments)]
    [string[]]$ArgumentList = @()
  )

  begin {
    $fn = 'Start-AceOutpostMeteredHarness'
    $mn = 'ATAP.Utilities.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    $clientSettings = @{
      ClaudeCode = @{ ClientId = 'claude-code'; TrustVariable = 'NODE_EXTRA_CA_CERTS'; Executable = 'claude' }
      Codex      = @{ ClientId = 'codex'; TrustVariable = 'SSL_CERT_FILE'; Executable = 'codex' }
    }
    $clientSetting = $clientSettings[$Client]
    $rootPem = Join-Path -Path $StateDirectory -ChildPath 'AceOutpost-Interception-Root.pem'
    if (-not $PSBoundParameters.ContainsKey('CredentialSecretName')) {
      $CredentialSecretName = "proxyCredential.Ace.AceOutpost.$($clientSetting.ClientId)"
    }
    $preflightTimeoutMilliseconds = 2000

    if ($ChromiumProxyBridge -and $LaunchMode -ne 'Wait') {
      throw 'ChromiumProxyBridge requires LaunchMode Wait so the private bridge remains available for the desktop process lifetime.'
    }
    if ($ChromiumProxyBridge) {
      if (-not ('ATAP.Utilities.PowerShell.AceOutpostDesktopProxyBridge' -as [type])) {
        $bridgeTypePath = Join-Path $PSScriptRoot '..\lib\AceOutpostDesktopProxyBridge.types.ps1'
        if (-not (Test-Path -LiteralPath $bridgeTypePath -PathType Leaf)) {
          throw "The required desktop proxy bridge implementation was not found at '$bridgeTypePath'."
        }
        . $bridgeTypePath
      }
      if (-not ('ATAP.Utilities.PowerShell.AceOutpostDesktopProxyBridge' -as [type])) {
        throw 'The required desktop proxy bridge type could not be loaded.'
      }

      $reservedChromiumProxyArguments = @(
        '^--proxy-server(?:=|$)',
        '^--proxy-bypass-list(?:=|$)',
        '^--no-proxy-server(?:=|$)',
        '^--disable-quic(?:=|$)',
        '^--ignore-certificate-errors(?:=|$)',
        '^--ignore-certificate-errors-spki-list(?:=|$)'
      )
      foreach ($argument in $ArgumentList) {
        if ($reservedChromiumProxyArguments.Where({ $argument -match $_ }, 'First').Count -gt 0) {
          throw "ArgumentList contains the reserved Chromium proxy argument '$argument'. The bridge owns all proxy-routing switches."
        }
      }
    }
  }

  process {
    $credential = $username = $secret = $proxyUrl = $null
    $process = $bridge = $null

    try {
      # Precondition 1 of 3 - CA trust material must be present (packet section 6.3).
      if (-not (Test-Path -LiteralPath $rootPem -PathType Leaf)) {
        throw "AceOutpost interception root was not found at '$rootPem'. Start AceOutpostService and confirm its proxy bootstrap completed before starting a metered harness."
      }
      if ($ChromiumProxyBridge) {
        try {
          $rootCertificatePem = Get-Content -LiteralPath $rootPem -Raw -ErrorAction Stop
          $rootCertificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::CreateFromPem($rootCertificatePem)
          $rootPublicKey = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($rootCertificate)
          if ($null -eq $rootPublicKey) {
            throw 'The interception root does not contain an RSA public key.'
          }
          $rootSpkiFingerprint = [Convert]::ToBase64String(
            [System.Security.Cryptography.SHA256]::HashData($rootPublicKey.ExportSubjectPublicKeyInfo()))
        } catch {
          throw "AceOutpost interception root at '$rootPem' could not supply Chromium trust: $($_.Exception.Message)"
        } finally {
          if ($null -ne $rootPublicKey) { $rootPublicKey.Dispose() }
          if ($null -ne $rootCertificate) { $rootCertificate.Dispose() }
          $rootCertificatePem = $null
        }
      }

      # Precondition 2 of 3 - the loopback listener must already be up (packet section 6.1).
      # This closes a gap in both existing tools, neither of which checks the listener at all.
      # It is deliberately only a pre-flight: mid-session listener loss is the deployed
      # listener's contract, not this function's.
      $tcpClient = $null
      try {
        $tcpClient = [System.Net.Sockets.TcpClient]::new()
        $connectTask = $tcpClient.ConnectAsync('127.0.0.1', $ProxyPort)
        if (-not $connectTask.Wait($preflightTimeoutMilliseconds) -or -not $tcpClient.Connected) {
          throw "No AceOutpost proxy listener answered at 127.0.0.1:$ProxyPort within $preflightTimeoutMilliseconds ms. Refusing to start an unmetered $Client harness."
        }
      } catch [System.Management.Automation.MethodInvocationException] {
        throw "No AceOutpost proxy listener answered at 127.0.0.1:$ProxyPort within $preflightTimeoutMilliseconds ms. Refusing to start an unmetered $Client harness."
      } finally {
        if ($null -ne $tcpClient) { $tcpClient.Dispose() }
      }

      # Resolve the harness executable before touching the credential, so a PATH failure
      # never causes a secret to be resolved needlessly.
      $resolvedHarnessPath = $HarnessPath
      if ([string]::IsNullOrWhiteSpace($resolvedHarnessPath)) {
        $harnessCommand = Get-Command -Name $clientSetting.Executable -CommandType Application -ErrorAction SilentlyContinue |
          Select-Object -First 1
        if ($null -eq $harnessCommand) {
          throw "The $Client harness executable '$($clientSetting.Executable)' was not found on PATH. Pass -HarnessPath explicitly."
        }
        $resolvedHarnessPath = $harnessCommand.Source
      }
      if (-not (Test-Path -LiteralPath $resolvedHarnessPath -PathType Leaf)) {
        throw "The $Client harness executable was not found at '$resolvedHarnessPath'."
      }

      # Precondition 3 of 3 - the credential must resolve to a valid pair (packet section 6.2).
      # Resolved last so the secret's lifetime in this process is as short as possible.
      # No part of a resolved value, including its length, may appear in an error message.
      if (-not (Get-Command -Name Get-SecretATAP -ErrorAction SilentlyContinue)) {
        throw 'Get-SecretATAP is required to resolve the AceOutpost proxy credential but is unavailable.'
      }

      $credential = Get-SecretATAP -SecretName $CredentialSecretName
      if ($credential -is [securestring]) {
        $credential = [System.Net.NetworkCredential]::new('', $credential).Password
      }
      $separator = ([string]$credential).IndexOf(':')
      if ($separator -le 0 -or $separator -eq ([string]$credential).Length - 1) {
        throw "The proxy credential resolved from '$CredentialSecretName' is not a valid username:secret pair."
      }

      $username = [Uri]::EscapeDataString(([string]$credential).Substring(0, $separator))
      $secret = [Uri]::EscapeDataString(([string]$credential).Substring($separator + 1))
      $proxyUrl = "http://${username}:${secret}@127.0.0.1:$ProxyPort"

      # Compose the child's block. ProcessStartInfo.Environment is pre-populated with a copy of
      # this process's environment; mutating it affects only the block handed to CreateProcess.
      # Nothing here writes to the calling process or to any durable scope.
      $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
      $startInfo.FileName = $resolvedHarnessPath
      $startInfo.WorkingDirectory = $WorkingDirectory
      $startInfo.UseShellExecute = $false
      foreach ($argument in $ArgumentList) {
        # Added as discrete items so the runtime performs the quoting. The vector is never
        # joined into a command-line string here, which is what keeps arguments containing
        # spaces, quotes, and newlines lossless.
        $null = $startInfo.ArgumentList.Add($argument)
      }

      $composed = [ordered]@{
        HTTP_PROXY  = $proxyUrl
        HTTPS_PROXY = $proxyUrl
        NO_PROXY    = $NoProxy
      }
      $composed[$clientSetting.TrustVariable] = $rootPem
      if ($Client -eq 'ClaudeCode') {
        # Claude Code's documented aggregate switch disables updater, telemetry, feedback,
        # and error-reporting traffic. It does not suppress the essential /api/hello startup
        # probe, which is separately authorized by the listener's exact closed route.
        $composed['CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC'] = '1'
      }
      foreach ($name in $composed.Keys) {
        $startInfo.Environment[$name] = $composed[$name]
      }
      if ($startInfo.Environment.ContainsKey('NODE_TLS_REJECT_UNAUTHORIZED')) {
        $null = $startInfo.Environment.Remove('NODE_TLS_REJECT_UNAUTHORIZED')
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Removed inherited NODE_TLS_REJECT_UNAUTHORIZED from the child environment block.'
      }

      # Invocation markers (Task 15.190.e contract section 5.3). Assigned UNCONDITIONALLY when
      # -InvocationId is bound, so a marker inherited from this process's own metered launch is
      # overwritten rather than passed through to the child as a stale grandparent id. The
      # parent marker is set or removed by the same rule. When -InvocationId is not bound both
      # names are left exactly as inherited. Same shape as the NODE_TLS_REJECT_UNAUTHORIZED
      # handling above: the child's block is shaped at composition, the parent's never.
      if ($PSBoundParameters.ContainsKey('InvocationId')) {
        $startInfo.Environment['ACEOUTPOST_METERED_INVOCATION'] = $InvocationId
        if (-not [string]::IsNullOrWhiteSpace($ParentInvocationId)) {
          $startInfo.Environment['ACEOUTPOST_METERED_PARENT_INVOCATION'] = $ParentInvocationId
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Set ACEOUTPOST_METERED_INVOCATION and ACEOUTPOST_METERED_PARENT_INVOCATION in the child environment block.'
        } else {
          $null = $startInfo.Environment.Remove('ACEOUTPOST_METERED_PARENT_INVOCATION')
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Set ACEOUTPOST_METERED_INVOCATION and removed any inherited ACEOUTPOST_METERED_PARENT_INVOCATION from the child environment block.'
        }
      }

      # Names only. The composed values include the credential-bearing proxy URL and are
      # never logged, returned, or surfaced in an error.
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Composed child environment variables: $(@($composed.Keys) -join ', ')."

      $standardOutput = $null
      $standardError = $null
      $exitCode = $null
      $processId = $null
      $started = $false
      $bridgeEndpoint = $null
      $bridgeAcceptedConnectionCount = $null
      $bridgeRejectedConnectionCount = $null

      if ($PSCmdlet.ShouldProcess("$Client harness '$resolvedHarnessPath' ($LaunchMode)", 'Start with a private AceOutpost proxy environment block')) {
        if ($ChromiumProxyBridge) {
          $bridge = [ATAP.Utilities.PowerShell.AceOutpostDesktopProxyBridge]::new($ProxyPort, [string]$credential)
          $bridge.Start()
          $bridgeEndpoint = "http://127.0.0.1:$($bridge.LocalPort)"
          $null = $startInfo.ArgumentList.Add("--proxy-server=$bridgeEndpoint")
          $null = $startInfo.ArgumentList.Add('--proxy-bypass-list=<-loopback>')
          $null = $startInfo.ArgumentList.Add('--disable-quic')
          # Chromium does not consume Node/OpenSSL trust environment variables. Scope trust
          # to this process and this exact interception-root public key instead of installing
          # the CA in a Windows Trusted Root store or disabling certificate verification.
          $null = $startInfo.ArgumentList.Add("--ignore-certificate-errors-spki-list=$rootSpkiFingerprint")
        }

        if ($LaunchMode -eq 'Wait' -and -not $ChromiumProxyBridge) {
          $startInfo.RedirectStandardOutput = $true
          $startInfo.RedirectStandardError = $true
        }

        $process = [System.Diagnostics.Process]::new()
        $process.StartInfo = $startInfo
        $null = $process.Start()
        $started = $true
        $processId = $process.Id

        if ($ChromiumProxyBridge) {
          try {
            $bridge.SetAllowedRootProcess($processId)
          } catch {
            try { $process.Kill($true) } catch { }
            throw "The desktop proxy bridge could not bind authorization to the launched process. The desktop process was terminated: $($_.Exception.Message)"
          }
          $process.WaitForExit()
          $exitCode = $process.ExitCode
          $bridgeAcceptedConnectionCount = $bridge.AcceptedConnectionCount
          $bridgeRejectedConnectionCount = $bridge.RejectedConnectionCount
        } elseif ($LaunchMode -eq 'Wait') {
          # R-34. Both redirected streams begin draining here, BEFORE the wait below. Waiting
          # on the process while either redirected buffer can still fill is a deadlock, and a
          # harness returning a large -p response is exactly the case that fills them.
          $outputTask = $process.StandardOutput.ReadToEndAsync()
          $errorTask = $process.StandardError.ReadToEndAsync()
          $process.WaitForExit()
          $standardOutput = $outputTask.GetAwaiter().GetResult()
          $standardError = $errorTask.GetAwaiter().GetResult()
          $exitCode = $process.ExitCode
        }
      }

      [PSCustomObject]@{
        Client                  = $Client
        ClientId                = $clientSetting.ClientId
        LaunchMode              = $LaunchMode
        Started                 = $started
        ProcessId               = $processId
        ExitCode                = $exitCode
        HarnessPath             = $resolvedHarnessPath
        WorkingDirectory        = $WorkingDirectory
        ProxyEndpoint           = "http://127.0.0.1:$ProxyPort"
        ChromiumProxyBridgeEnabled = [bool]$ChromiumProxyBridge
        ChromiumProxyEndpoint   = $bridgeEndpoint
        BridgeAcceptedConnectionCount = $bridgeAcceptedConnectionCount
        BridgeRejectedConnectionCount = $bridgeRejectedConnectionCount
        TrustVariable           = $clientSetting.TrustVariable
        CredentialSecretName    = $CredentialSecretName
        ComposedVariableNames   = @($composed.Keys)
        ArgumentCount           = @($ArgumentList).Count
        StandardOutput          = $standardOutput
        StandardError           = $standardError
      }
    } catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "AceOutpost metered harness launch failed: $($_.Exception.Message)"
      throw
    } finally {
      # Scrub the credential and every derivative from this process. The composed values live
      # on in the child's block only, which is the entire point of the design.
      $credential = $username = $secret = $proxyUrl = $null
      $rootSpkiFingerprint = $null
      $composed = $null
      $startInfo = $null
      if ($null -ne $bridge) { $bridge.Dispose() }
      if ($null -ne $process -and $LaunchMode -eq 'Wait') { $process.Dispose() }
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "AceOutpost metered harness launch requested for $Client in $LaunchMode mode."
  }
}
