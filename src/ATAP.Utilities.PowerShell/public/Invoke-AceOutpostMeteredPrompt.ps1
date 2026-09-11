function Invoke-AceOutpostMeteredPrompt {
  <#
  .SYNOPSIS
    Runs one non-interactive AI harness prompt through the AceOutpost metered launch core.
  .DESCRIPTION
    The terminal-skill adapter ratified by Task 15.190.a section 4.4 and Decision B (section 5.2).
    An agent-invoked skill calls this function instead of setting any proxy variable in its own
    shell. The function composes the harness's non-interactive invocation (codex exec / claude -p),
    hands it to Start-AceOutpostMeteredHarness in Wait mode, and returns the child's exit code and
    both drained output streams to the caller as properties of one object. Nothing is written to the
    pipeline as a side effect; the caller decides what to do with the output.

    The prompt and the caller's argument vector are never interpreted here. Each element is placed
    in the child's ArgumentList as a discrete item - the harness sub-command or flag, then the
    caller's arguments, then an end-of-options marker, then the prompt - so a prompt containing
    spaces, embedded quotes, newlines, dollar signs, backticks, or a literal '--' arrives
    byte-for-byte. No string concatenation or re-quoting occurs at any point.

    Fail-closed behaviour is inherited from the core and is not softened. A dead listener, a
    missing interception root, or an unresolvable credential is a terminating error here, exactly
    as it is in the core, so a skill can never believe it ran metered when it did not. The function
    never sets NODE_TLS_REJECT_UNAUTHORIZED, never writes an environment variable at any scope,
    never builds a proxy URL, and never carries a credential value; only a SecretName moves, and it
    is passed to the core untouched.

    NESTED INVOCATIONS. A skill running inside a metered harness can launch another metered
    harness. Every call generates its own InvocationId and records two independent lines of
    evidence about whether it is nested: (1) the ACEOUTPOST_METERED_INVOCATION marker in the
    current process's own block, read as ParentInvocationId when present; and (2) a walk of the
    current process's ancestry looking for a harness executable, which yields the ancestor harness
    process id. The second mechanism works today with no environment involvement; the first depends
    on a core extension that does not yet exist (see NOTES). The ids surface in the return object
    and in the PSFramework log, and a nested call's AncestorHarnessProcessId joins to its parent
    call's HarnessProcessId within the two calls' StartedAt/EndedAt windows.

    METERING CLAIM, PER CLIENT. The claim this function can honestly make differs by harness and is
    reported in the MeteringClaim property rather than left to the caller to infer:

      Codex      - the harness's own provider traffic is metered. Its tool shells are not: Codex's
                   shell_environment_policy inherit = "core" strips every proxy and CA variable
                   from the shells it spawns (Task 15.190.f section 2.5). Harness traffic only.
      ClaudeCode - accepted because the core accepts it, but a metered launch DOES NOT WORK TODAY.
                   claude.exe does not trust the interception root via any trust variable (packet
                   open question Q3), so the child fails at its first TLS handshake. If Q3 were
                   resolved, a second blocker applies: claude.exe passes its whole block to every
                   tool shell, so restore and package traffic from inside the session would be
                   routed at the listener (Task 15.190.f section 4). Neither is papered over here.
  .PARAMETER Client
    The AceOutpost client identity: ClaudeCode or Codex. Passed to the core as-is.
  .PARAMETER Prompt
    The prompt text, passed to the harness as one discrete argument after an end-of-options marker.
    Never parsed, trimmed, re-quoted, or joined with anything.
  .PARAMETER ArgumentList
    Additional harness arguments (for example a model or output-format flag). Collected from the
    remaining arguments and placed, in order, between the harness's non-interactive flag and the
    end-of-options marker. Never interpreted here.
  .PARAMETER OmitEndOfOptionsMarker
    Suppresses the '--' placed before the prompt. Both harness CLIs are expected to honour '--' as
    end-of-options; this switch exists only so a caller can work around a harness that does not,
    at the cost of a prompt beginning with '-' being read by the harness as an option.
  .PARAMETER ProxyPort
    Passed through to the core when bound. Otherwise the core's own default applies.
  .PARAMETER NoProxy
    Passed through to the core when bound. Otherwise the core's own default applies.
  .PARAMETER CredentialSecretName
    SecretName passed through to the core when bound, untouched. This function never resolves it.
  .PARAMETER StateDirectory
    Passed through to the core when bound. Otherwise the core's own default applies.
  .PARAMETER WorkingDirectory
    Passed through to the core when bound. Otherwise the core's own default applies.
  .PARAMETER HarnessPath
    Passed through to the core when bound. Otherwise the core resolves the client's CLI from PATH.
  .OUTPUTS
    PSCustomObject carrying ExitCode, StdOut, StdErr, Client, ClientId, ProxyPort, ProxyEndpoint,
    the invocation identifiers (InvocationId, ParentInvocationId, IsNested, NestingEvidence,
    AncestorHarnessProcessId, AncestorHarnessName, CallerProcessId, HarnessProcessId), the
    composed argument vector shape (HarnessFlag, ArgumentCount), StartedAt/EndedAt, MeteringClaim,
    and ChildMarkerDelivered. No property ever carries a credential value.
  .EXAMPLE
    $result = Invoke-AceOutpostMeteredPrompt -Client Codex -Prompt 'Summarize this repository'
    $result.ExitCode; $result.StdOut

    Runs one metered Codex prompt to completion and inspects its exit code and output.
  .EXAMPLE
    Invoke-AceOutpostMeteredPrompt -Client Codex -Prompt $prompt --model o4-mini

    Passes a harness flag through the remaining-arguments vector without interpreting it.
  .NOTES
    Ratified design: Task15.190.a-SharedLaunchCoreDecisionPacket.md sections 4.1, 4.4, 5.2, 6, and
    7 Q1/Q3. Coverage narrowing: Task15.190.f-ChildProcessDirectionCharacterization.md sections
    2.5, 4, and 7. Contract: Task15.190.e-TerminalSkillAdapterContract.md.

    Harness flags are taken from the published CLI references and are recorded as asserted, not
    verified, because confirming them requires launching a harness: Claude Code's non-interactive
    mode is 'claude -p <prompt>' (-p is --print); Codex's is 'codex exec [OPTIONS] [PROMPT]'. Note
    that in the Codex CLI '-p' is --profile, so the form 'codex exec -p <prompt>' that appears in
    earlier packet text would be misparsed; this function never emits it.

    Specified, blocked on a core change: for the environment-marker half of nested identification
    to reach the child, Start-AceOutpostMeteredHarness needs to accept an InvocationId and a
    ParentInvocationId and write them into the composed block as ACEOUTPOST_METERED_INVOCATION and
    ACEOUTPOST_METERED_PARENT_INVOCATION - OVERWRITING any inherited value, not merely setting it
    when absent. The core copies the current block into the child's, so today an inherited marker
    flows through unchanged and a harness launched from a nested call is stamped with its
    grandparent's id (proven in this function's test suite). This function detects the extension
    at run time and passes the ids when the core offers the parameters; until then
    ChildMarkerDelivered is false. Even once it lands, Codex's inherit = "core" strips the marker
    from its tool shells, which is why the process-ancestry mechanism is the one that carries
    nested identification today.
  .LINK
    Start-AceOutpostMeteredHarness
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [ValidateSet('ClaudeCode', 'Codex')]
    [string]$Client,

    [Parameter(Mandatory)]
    [AllowEmptyString()]
    [string]$Prompt,

    [switch]$OmitEndOfOptionsMarker,

    [ValidateRange(50000, 50099)]
    [int]$ProxyPort,

    [ValidateNotNullOrEmpty()]
    [string]$NoProxy,

    [ValidateNotNullOrEmpty()]
    [string]$CredentialSecretName,

    [ValidateNotNullOrEmpty()]
    [string]$StateDirectory,

    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$WorkingDirectory,

    [string]$HarnessPath,

    [Parameter(ValueFromRemainingArguments)]
    [string[]]$ArgumentList = @()
  )

  begin {
    $fn = 'Invoke-AceOutpostMeteredPrompt'
    $mn = 'ATAP.Utilities.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    # Helper-load fallback for running this file from source without the module imported.
    if (-not (Get-Command -Name 'Start-AceOutpostMeteredHarness' -ErrorAction SilentlyContinue)) {
      $corePath = Join-Path -Path $PSScriptRoot -ChildPath 'Start-AceOutpostMeteredHarness.ps1'
      if (Test-Path -LiteralPath $corePath -PathType Leaf) {
        . $corePath
      }
    }

    # Per-client shape of the non-interactive invocation. HarnessFlag is the first element of the
    # child vector; MeteringClaim is the honest, per-client statement returned to the caller.
    $clientSettings = @{
      ClaudeCode = @{
        ClientId      = 'claude-code'
        Executable    = 'claude'
        HarnessFlag   = @('-p')
        MeteringClaim = 'Blocked: a metered ClaudeCode launch does not work today. claude.exe rejects the interception root via every trust variable (packet Q3), so the child fails at TLS; and claude.exe passes its block to every tool shell, so tool traffic would be routed at the listener (15.190.f section 4).'
      }
      Codex      = @{
        ClientId      = 'codex'
        Executable    = 'codex'
        HarnessFlag   = @('exec')
        MeteringClaim = 'Harness traffic only: codex.exe provider traffic is metered; its tool shells are not, because shell_environment_policy inherit = "core" strips every proxy and CA variable (15.190.f section 2.5).'
      }
    }
    $clientSetting = $clientSettings[$Client]

    $invocationMarkerName = 'ACEOUTPOST_METERED_INVOCATION'
    $parentMarkerName = 'ACEOUTPOST_METERED_PARENT_INVOCATION'
    $harnessProcessNames = @('claude', 'codex')
    $ancestryDepthLimit = 32
  }

  process {
    $invocationId = [guid]::NewGuid().ToString('D')
    $startedAt = [DateTimeOffset]::UtcNow

    # Nested-invocation evidence 1 of 2: the environment marker in OUR OWN block. Reading our own
    # process block is a read of our own state, never a write. Absent until the core extension
    # described in NOTES exists, and absent inside Codex tool shells regardless (15.190.f 2.5).
    $parentInvocationId = [Environment]::GetEnvironmentVariable($invocationMarkerName, 'Process')
    if ([string]::IsNullOrWhiteSpace($parentInvocationId)) { $parentInvocationId = $null }

    # Nested-invocation evidence 2 of 2: process ancestry. ParentProcessId is public for every
    # process, so this works for a foreign harness ancestor even though its environment block does
    # not (15.190.b section 5.2). Bounded, and tolerant of an ancestor that has already exited.
    $ancestorHarnessProcessId = $null
    $ancestorHarnessName = $null
    $ancestry = [System.Collections.Generic.List[string]]::new()
    try {
      $cursor = Get-Process -Id $PID -ErrorAction Stop
      for ($depth = 0; $depth -lt $ancestryDepthLimit -and $null -ne $cursor; $depth++) {
        $parent = $cursor.Parent
        if ($null -eq $parent) { break }
        $ancestry.Add(('{0}:{1}' -f $parent.Id, $parent.ProcessName))
        if ($null -eq $ancestorHarnessProcessId -and $parent.ProcessName -in $harnessProcessNames) {
          $ancestorHarnessProcessId = $parent.Id
          $ancestorHarnessName = $parent.ProcessName
        }
        $cursor = $parent
      }
    } catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Process ancestry walk stopped early: $($_.Exception.Message)"
    }

    $nestingEvidence = @()
    if ($null -ne $parentInvocationId) { $nestingEvidence += 'EnvironmentMarker' }
    if ($null -ne $ancestorHarnessProcessId) { $nestingEvidence += 'ProcessAncestry' }
    $isNested = $nestingEvidence.Count -gt 0

    # Compose the child vector as DISCRETE items. Order: harness flag(s), caller arguments, the
    # end-of-options marker, the prompt. Nothing is joined, quoted, or inspected.
    $childArguments = [System.Collections.Generic.List[string]]::new()
    foreach ($flag in $clientSetting.HarnessFlag) { $childArguments.Add($flag) }
    foreach ($argument in $ArgumentList) { $childArguments.Add($argument) }
    if (-not $OmitEndOfOptionsMarker) { $childArguments.Add('--') }
    $childArguments.Add($Prompt)

    # Pass-through to the core: only what the caller bound, so the core's own defaults govern.
    $coreParameters = @{
      Client       = $Client
      LaunchMode   = 'Wait'
      ArgumentList = $childArguments.ToArray()
      Confirm      = $false
    }
    foreach ($name in @('ProxyPort', 'NoProxy', 'CredentialSecretName', 'StateDirectory', 'WorkingDirectory', 'HarnessPath')) {
      if ($PSBoundParameters.ContainsKey($name)) { $coreParameters[$name] = $PSBoundParameters[$name] }
    }

    # Forward-compatible with the specified core extension: pass the ids only when the core
    # actually declares the parameters. Today it does not, and ChildMarkerDelivered stays false.
    $childMarkerDelivered = $false
    $coreCommand = Get-Command -Name 'Start-AceOutpostMeteredHarness' -ErrorAction Stop
    if ($coreCommand.Parameters.ContainsKey('InvocationId')) {
      $coreParameters['InvocationId'] = $invocationId
      if ($null -ne $parentInvocationId -and $coreCommand.Parameters.ContainsKey('ParentInvocationId')) {
        $coreParameters['ParentInvocationId'] = $parentInvocationId
      }
      $childMarkerDelivered = $true
    }

    if ($Client -eq 'ClaudeCode') {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Invocation $invocationId targets ClaudeCode: a metered ClaudeCode launch is blocked on packet Q3 and is expected to fail at TLS in the harness. Nothing here works around that."
    }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Invocation $invocationId ($Client) parent=$(if ($null -ne $parentInvocationId) { $parentInvocationId } else { '<none>' }) ancestorHarness=$(if ($null -ne $ancestorHarnessProcessId) { "$ancestorHarnessName/$ancestorHarnessProcessId" } else { '<none>' }) caller=$PID argumentCount=$($childArguments.Count)."

    $launch = $null
    $started = $false
    if ($PSCmdlet.ShouldProcess("$Client non-interactive prompt (invocation $invocationId)", 'Run through the AceOutpost metered launch core')) {
      # No try/catch. A refusal from the core - dead listener, missing root, unresolvable
      # credential - propagates unchanged. Softening it here is exactly the failure this adapter
      # exists to prevent: a skill that believes it ran metered when it did not.
      $launch = Start-AceOutpostMeteredHarness @coreParameters
      $started = [bool]$launch.Started
    }
    $endedAt = [DateTimeOffset]::UtcNow

    $result = [PSCustomObject]@{
      InvocationId             = $invocationId
      ParentInvocationId       = $parentInvocationId
      IsNested                 = $isNested
      NestingEvidence          = @($nestingEvidence)
      AncestorHarnessProcessId = $ancestorHarnessProcessId
      AncestorHarnessName      = $ancestorHarnessName
      ProcessAncestry          = @($ancestry)
      CallerProcessId          = $PID
      ChildMarkerDelivered     = $childMarkerDelivered
      InvocationMarkerName     = $invocationMarkerName
      ParentMarkerName         = $parentMarkerName
      Client                   = $Client
      ClientId                 = $clientSetting.ClientId
      MeteringClaim            = $clientSetting.MeteringClaim
      HarnessFlag              = @($clientSetting.HarnessFlag)
      EndOfOptionsMarker       = -not $OmitEndOfOptionsMarker
      ArgumentCount            = $childArguments.Count
      Started                  = $started
      HarnessPath              = if ($null -ne $launch) { $launch.HarnessPath } else { $null }
      HarnessProcessId         = if ($null -ne $launch) { $launch.ProcessId } else { $null }
      WorkingDirectory         = if ($null -ne $launch) { $launch.WorkingDirectory } else { $null }
      ProxyPort                = if ($PSBoundParameters.ContainsKey('ProxyPort')) { $ProxyPort } elseif ($null -ne $launch) { [int]([uri]$launch.ProxyEndpoint).Port } else { $null }
      ProxyEndpoint            = if ($null -ne $launch) { $launch.ProxyEndpoint } else { $null }
      TrustVariable            = if ($null -ne $launch) { $launch.TrustVariable } else { $null }
      CredentialSecretName     = if ($null -ne $launch) { $launch.CredentialSecretName } else { $null }
      StartedAt                = $startedAt
      EndedAt                  = $endedAt
      ExitCode                 = if ($null -ne $launch) { $launch.ExitCode } else { $null }
      StdOut                   = if ($null -ne $launch) { $launch.StandardOutput } else { $null }
      StdErr                   = if ($null -ne $launch) { $launch.StandardError } else { $null }
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Invocation $invocationId ($Client) completed: started=$started exitCode=$(if ($null -ne $result.ExitCode) { $result.ExitCode } else { '<none>' }) harnessPid=$(if ($null -ne $result.HarnessProcessId) { $result.HarnessProcessId } else { '<none>' })."
    $result
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function ended'
  }
}
