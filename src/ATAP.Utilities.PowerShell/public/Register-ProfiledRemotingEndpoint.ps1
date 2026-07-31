function Register-ProfiledRemotingEndpoint {
  <#
  .SYNOPSIS
    Idempotently registers or updates the managed, profiled PowerShell 7 WinRM
    session configuration (SC-0267) on the local or a remote computer.

  .DESCRIPTION
    Registers the session configuration defined by WithProfiles.pssc (machine
    profile + authenticated user/service-account profile) under a dedicated
    -ConfigurationName, distinct from the profile-free automation endpoint
    tracked under SC-0266. Registration is idempotent: an endpoint whose staged
    .pssc content already matches the source file is left untouched
    (Action = 'AlreadyCurrent'); otherwise the endpoint is (re)registered from
    the source .pssc, since WinRM has no in-place field-level update for a
    .pssc-defined configuration.

    Remote registration copies the source .pssc to a staging path on the
    target host over an authenticated PSSession and registers it there, so the
    same registration/idempotency logic runs identically on local and remote
    hosts.

  .PARAMETER ComputerName
    Target host. '.', 'localhost', or the local machine name register locally.
    Any other value requires -Credential and registers over WinRM.

  .PARAMETER Credential
    Credential used to open the remote session. Get-SecretATAP returns a
    single string field, not a PSCredential, so build one at the call site
    from the 'username' and 'password' fields of the same secret item (for
    example Get-SecretATAP -SecretName 'Windows.Remoting.Credential.UTAT01'
    -SecretField 'username'/'password') -- never hard-code a secret name in
    library code.

  .PARAMETER ConfigurationName
    Name under which the session configuration is registered.

  .PARAMETER Path
    Local path to the source .pssc file: the canonical, stable
    WithProfiles.pssc that is actually registered. Defaults to a documented,
    multi-candidate resolution (dev-tree layout relative to this file's own
    Profiles\ sibling, then the installed module's ModuleBase\Profiles\) so
    resolution does not depend on a single guessed $PSScriptRoot-relative
    path being correct for every install layout. Throws a clear, bounded
    error naming the resolved candidate path when no candidate exists.

  .PARAMETER LocalMarkerPath
    Base path (without the ".registered-sha256" suffix) for the local
    idempotency hash-marker written after a successful local registration.
    Deliberately independent of -Path: registration reads its content from
    -Path, but the marker must never live beside the source .pssc when -Path
    points inside a Git worktree, since that pollutes the tree and breaks
    clean-tree gates. Defaults to a machine-state location resolved by
    Get-ProfiledRemotingMachineStateRoot (ProgramData\ATAP\RemotingEndpoints,
    with a Machine-scope and windir-derived fallback for agent shells that do
    not inherit Process-scope ProgramData/windir). Ignored for remote
    registration, which already stages/markers under -RemoteStagingPath.

  .PARAMETER RemoteStagingPath
    Path on the remote host where the .pssc is copied before registration.
    Ignored for local registration.

  .PARAMETER RemotePowerShellExecutablePath
    Absolute PowerShell 7 executable path on a remote target. The detached
    registration must run under pwsh, rather than the unnamed default WinRM
    endpoint (which is commonly Windows PowerShell 5.1).

  .PARAMETER ThrowOnFailure
    Throw when registration did not succeed.

  .OUTPUTS
    PSCustomObject with ComputerName, ConfigurationName, Action, Ok, Failures.

  .EXAMPLE
    Register-ProfiledRemotingEndpoint

  .EXAMPLE
    $u = Get-SecretATAP -SecretName 'Windows.Remoting.Credential.UTAT01' -SecretField 'username'
    $p = Get-SecretATAP -SecretName 'Windows.Remoting.Credential.UTAT01' -SecretField 'password'
    $cred = [PSCredential]::new($u, (ConvertTo-SecureString $p -AsPlainText -Force))
    Register-ProfiledRemotingEndpoint -ComputerName utat01 -Credential $cred

  .NOTES
    AI assisted using ./.claude/Rules/Powershell.md as guidelines.
    Implements SC-0267 (Rework WithProfiles.pssc into the managed profiled
    PowerShell 7 remoting endpoint).
  .LINK
    Test-ProfiledRemotingEndpoint
  .LINK
    Unregister-ProfiledRemotingEndpoint
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([PSCustomObject])]
  param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $ComputerName = '.',

    [Parameter()]
    [PSCredential] $Credential,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $ConfigurationName = 'ATAP.PS7.Profiled',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $Path = $(
      # Documented, multi-candidate default rather than a single blind
      # $PSScriptRoot guess: try the dev-tree layout first (this file lives
      # in public\, WithProfiles.pssc lives in the sibling Profiles\), then
      # fall back to the installed module's own ModuleBase\Profiles\, which
      # can differ from the dev-tree layout depending on how the module was
      # packaged/installed.
      $devCandidate = Join-Path $PSScriptRoot '..\Profiles\WithProfiles.pssc'
      if (Test-Path -LiteralPath $devCandidate -PathType Leaf) {
        (Resolve-Path -LiteralPath $devCandidate).ProviderPath
      } else {
        $installedModule = Get-Module -Name 'ATAP.Utilities.Powershell' -ErrorAction SilentlyContinue | Select-Object -First 1
        $moduleCandidate = if ($installedModule -and $installedModule.ModuleBase) {
          Join-Path $installedModule.ModuleBase 'Profiles\WithProfiles.pssc'
        }
        if ($moduleCandidate -and (Test-Path -LiteralPath $moduleCandidate -PathType Leaf)) {
          (Resolve-Path -LiteralPath $moduleCandidate).ProviderPath
        } else {
          # Neither candidate exists: return the primary (dev-tree) candidate
          # so the begin-block guard below throws a clear, stable error
          # naming a real, documented path instead of $null.
          $devCandidate
        }
      }
    ),

    [Parameter()]
    [AllowNull()]
    [AllowEmptyString()]
    [string] $LocalMarkerPath,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $RemoteStagingPath = 'C:\ProgramData\ATAP\RemotingEndpoints\WithProfiles.pssc',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $RemotePowerShellExecutablePath = 'C:\Program Files\PowerShell\7\pwsh.exe',

    [Parameter()]
    [switch] $ThrowOnFailure
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn"

    # Load-once, module-import-safe helper fallback: when the module is imported
    # normally, private\*.ps1 is already dot-sourced by the .psm1 and these commands
    # exist. When this file is dot-sourced directly (for example a lightweight Pester
    # test that avoids importing the whole module), load the sibling private helpers
    # explicitly instead of duplicating their logic here.
    if (-not (Get-Command -Name 'Resolve-ATAPMachineEnvironmentVariable' -ErrorAction SilentlyContinue)) {
      . (Join-Path $PSScriptRoot '..\private\Resolve-ATAPMachineEnvironmentVariable.ps1')
    }
    if (-not (Get-Command -Name 'Get-ProfiledRemotingMachineStateRoot' -ErrorAction SilentlyContinue)) {
      . (Join-Path $PSScriptRoot '..\private\Get-ProfiledRemotingMachineStateRoot.ps1')
    }

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
      throw "Session configuration file not found: '$Path'. Neither the dev-tree candidate (this module's own Profiles\WithProfiles.pssc) nor an installed module's ModuleBase\Profiles\WithProfiles.pssc resolved to an existing file; pass -Path explicitly to the canonical stable source."
    }

    if ([string]::IsNullOrWhiteSpace($LocalMarkerPath)) {
      # Deliberately independent of -Path: the marker must live under a
      # machine-state root, never beside the source .pssc, because -Path
      # commonly points inside a Git worktree (the dev-tree candidate above).
      # Writing the marker there pollutes the tree and breaks clean-tree gates.
      $LocalMarkerPath = Join-Path (Get-ProfiledRemotingMachineStateRoot) 'WithProfiles.pssc'
    }

    $localComputerName = Resolve-ATAPMachineEnvironmentVariable -Name 'COMPUTERNAME' -DefaultValue ([Environment]::MachineName) -FunctionName $fn -ModuleName $mn
    $localNames = @('.', 'localhost', $localComputerName) | Where-Object { $_ }
    $isLocal = $ComputerName -in $localNames

    if (-not $isLocal -and -not $Credential) {
      throw "A -Credential is required to register '$ConfigurationName' on remote host '$ComputerName'."
    }

    if (-not $isLocal -and -not $WhatIfPreference -and -not (Get-Command -Name Add-ParityChangeEntry -ErrorAction SilentlyContinue)) {
      throw 'Add-ParityChangeEntry (ATAP.Utilities.SystemParityMonitor.PowerShell) is required before a live remote registration can proceed.'
    }

    # Registration logic that must run identically whether invoked locally or
    # remotely via Invoke-Command -- kept as a single scriptblock so both paths
    # exercise the same idempotency decision.
    $script:registerScript = {
      param($ConfigurationName, $PsscPath, $MarkerPath, $ExpectedHash)

      # WinRM does not expose the byte content of a registered .pssc-defined
      # configuration in a directly comparable form, so idempotency is tracked via
      # a sidecar hash-marker file written at the end of a successful registration
      # -- not by re-hashing the source file (which would trivially match itself
      # and never detect drift). $MarkerPath is deliberately independent of
      # $PsscPath: the source .pssc is registered from $PsscPath (which may live
      # inside a Git worktree), but the marker is always written under a
      # machine-state root (see Get-ProfiledRemotingMachineStateRoot) so it never
      # pollutes the worktree.
      $hashMarkerPath = "$MarkerPath.registered-sha256"
      $existing = Get-PSSessionConfiguration -Name $ConfigurationName -ErrorAction SilentlyContinue
      $recordedHash = if (Test-Path -LiteralPath $hashMarkerPath -PathType Leaf) {
        (Get-Content -LiteralPath $hashMarkerPath -Raw -ErrorAction SilentlyContinue).Trim()
      } else {
        $null
      }

      if ($existing -and $recordedHash -eq $ExpectedHash) {
        return [PSCustomObject]@{ Action = 'AlreadyCurrent'; Error = $null }
      }

      try {
        if ($existing) {
          Unregister-PSSessionConfiguration -Name $ConfigurationName -Force -NoServiceRestart -ErrorAction Stop
        }
        Register-PSSessionConfiguration -Name $ConfigurationName -Path $PsscPath -Force -NoServiceRestart -ErrorAction Stop

        $markerDir = Split-Path -Path $hashMarkerPath -Parent
        if ($markerDir -and -not (Test-Path -LiteralPath $markerDir -PathType Container)) {
          New-Item -ItemType Directory -Path $markerDir -Force | Out-Null
        }
        Set-Content -LiteralPath $hashMarkerPath -Value $ExpectedHash -Encoding UTF8 -Force

        # Register-PSSessionConfiguration itself persists the config to the WSMan
        # store immediately (with -NoServiceRestart, no restart is needed for THAT to
        # take effect); only NEW connections need WinRM restarted to see the new
        # endpoint. Calling Restart-Service synchronously here would be self-defeating
        # for a remote invocation: it stops the very WinRM listener hosting this
        # session before the "start" half can run, killing the connection and
        # potentially leaving the service in a Stopped state on the remote host with
        # no one left to start it back up. Launch the restart in a detached process
        # instead so it survives this session's connection dying. Use the actual
        # running host executable, not $PSHOME\pwsh.exe -- a session opened without
        # -ConfigurationName connects to the DEFAULT WinRM endpoint (Windows
        # PowerShell 5.1), where $PSHOME is WindowsPowerShell\v1.0 and has no pwsh.exe.
        $currentHostExe = (Get-Process -Id $PID).Path
        Start-Process -FilePath $currentHostExe `
          -ArgumentList '-NoLogo', '-Command', 'Start-Sleep -Seconds 2; Restart-Service -Name WinRM -Force' `
          -WindowStyle Hidden

        return [PSCustomObject]@{ Action = $(if ($existing) { 'Updated' } else { 'Created' }); Error = $null }
      } catch {
        return [PSCustomObject]@{ Action = $(if ($existing) { 'UpdateFailed' } else { 'CreateFailed' }); Error = $_.Exception.Message }
      }
    }
  }

  process {
    $failures = [System.Collections.Generic.List[string]]::new()
    $localHash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    $psscContent = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($Path))
    $outcome = $null

    if ($isLocal) {
      if ($PSCmdlet.ShouldProcess("$ConfigurationName@local", 'Register profiled remoting endpoint')) {
        $localEnvironmentSnapshot = @{}
        try {
          foreach ($environmentName in @('windir', 'SystemRoot')) {
            $processValue = [System.Environment]::GetEnvironmentVariable($environmentName, 'Process')
            $localEnvironmentSnapshot[$environmentName] = $processValue
            if ([string]::IsNullOrWhiteSpace($processValue)) {
              $resolvedValue = Resolve-ATAPMachineEnvironmentVariable `
                -Name $environmentName `
                -FunctionName $fn `
                -ModuleName $mn
              if ([string]::IsNullOrWhiteSpace($resolvedValue)) {
                $alternateEnvironmentName = if ($environmentName -eq 'windir') { 'SystemRoot' } else { 'windir' }
                $resolvedValue = Resolve-ATAPMachineEnvironmentVariable `
                  -Name $alternateEnvironmentName `
                  -FunctionName $fn `
                  -ModuleName $mn
              }
              if ([string]::IsNullOrWhiteSpace($resolvedValue)) {
                throw "Local profiled-remoting registration requires a Windows root, but '$environmentName' and its alternate are empty in both Process and Machine scopes."
              }
              [System.Environment]::SetEnvironmentVariable($environmentName, $resolvedValue, 'Process')
            }
          }

          $outcome = & $script:registerScript $ConfigurationName $Path $LocalMarkerPath $localHash
        } catch {
          $outcome = [PSCustomObject]@{ Action = 'RegistrationEnvironmentUnavailable'; Error = $_.Exception.Message }
        } finally {
          foreach ($environmentName in @('windir', 'SystemRoot')) {
            if ($localEnvironmentSnapshot.ContainsKey($environmentName)) {
              [System.Environment]::SetEnvironmentVariable(
                $environmentName,
                $localEnvironmentSnapshot[$environmentName],
                'Process'
              )
            }
          }
        }
      } else {
        $existing = Get-PSSessionConfiguration -Name $ConfigurationName -ErrorAction SilentlyContinue
        $outcome = [PSCustomObject]@{ Action = $(if ($existing) { 'WouldUpdate' } else { 'WouldCreate' }); Error = $null }
      }
    } else {
      # Register-PSSessionConfiguration recycles the WinRM plugin host process
      # servicing the CURRENT session as part of applying the new/updated
      # configuration -- even with -NoServiceRestart and even though the WinRM
      # *service* itself stays Running throughout. Running it inline over
      # $session therefore reliably severs the very connection carrying the
      # command ("I/O operation has been aborted...") before a result can be
      # returned, regardless of any restart timing tricks. The only reliable
      # pattern is: write the registration logic to a file on the target, launch
      # it as a detached OS process (survives the session dying), then verify
      # success afterward over a brand-new connection.
      $resultPath = "$RemoteStagingPath.register-result.json"
      $registerScriptPath = "$RemoteStagingPath.register.ps1"
      $session = $null
      try {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling Invoke-Command on $ComputerName" -Tag 'InvokeCommandCall'
        $session = New-PSSession -ComputerName $ComputerName -Credential $Credential -ErrorAction Stop

        Invoke-Command -Session $session -ScriptBlock {
          param($StagingPath, $PwshPath, $PsscContent, $ConfigurationName)
          $dir = Split-Path -Path $StagingPath -Parent
          if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
          if (-not (Test-Path -LiteralPath $PwshPath -PathType Leaf)) {
            throw "The required PowerShell 7 executable was not found: '$PwshPath'."
          }
          # A prior version of this function could create the named endpoint from
          # the default Windows PowerShell 5.1 host. pwsh cannot unregister that
          # mismatched legacy plug-in, so remove only that clearly identified
          # registry entry before its replacement is registered under pwsh.
          $pluginPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WSMAN\Plugin\$ConfigurationName"
          $plugin = Get-ItemProperty -LiteralPath $pluginPath -ErrorAction SilentlyContinue
          if ($plugin.ConfigXML -match 'PSVersion" Value="5\.1"') {
            Remove-Item -LiteralPath $pluginPath -Recurse -Force -ErrorAction Stop
          }
          [System.IO.File]::WriteAllBytes($StagingPath, [Convert]::FromBase64String($PsscContent))
        } -ArgumentList $RemoteStagingPath, $RemotePowerShellExecutablePath, $psscContent, $ConfigurationName -ErrorAction Stop

        if ($PSCmdlet.ShouldProcess("$ConfigurationName@$ComputerName", 'Register profiled remoting endpoint')) {
          $detachedScriptText = @"
`$hashMarkerPath = '$RemoteStagingPath.registered-sha256'
try {
  `$existing = Get-PSSessionConfiguration -Name '$ConfigurationName' -ErrorAction SilentlyContinue
  if (`$existing) { Unregister-PSSessionConfiguration -Name '$ConfigurationName' -Force -NoServiceRestart -ErrorAction Stop }
  Register-PSSessionConfiguration -Name '$ConfigurationName' -Path '$RemoteStagingPath' -Force -NoServiceRestart -ErrorAction Stop
  Set-Content -LiteralPath `$hashMarkerPath -Value '$localHash' -Encoding UTF8 -Force
  [PSCustomObject]@{ Action = `$(if (`$existing) { 'Updated' } else { 'Created' }); Error = `$null } | ConvertTo-Json | Set-Content -LiteralPath '$resultPath' -Encoding UTF8 -Force
} catch {
  [PSCustomObject]@{ Action = 'CreateFailed'; Error = `$_.Exception.Message } | ConvertTo-Json | Set-Content -LiteralPath '$resultPath' -Encoding UTF8 -Force
} finally {
  Restart-Service -Name WinRM -Force -ErrorAction SilentlyContinue
}
"@
          Invoke-Command -Session $session -ScriptBlock {
            param($ScriptPath, $ScriptText, $ResultPath, $PwshPath)
            Remove-Item -LiteralPath $ResultPath -Force -ErrorAction SilentlyContinue
            Set-Content -LiteralPath $ScriptPath -Value $ScriptText -Encoding UTF8 -Force
            # The bootstrap session deliberately uses the default endpoint so this
            # recovery path remains available if the PS7 endpoint is broken. Never
            # inherit that host executable: it is normally powershell.exe 5.1.
            Start-Process -FilePath $PwshPath `
              -ArgumentList '-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $ScriptPath `
              -WindowStyle Hidden
          } -ArgumentList $registerScriptPath, $detachedScriptText, $resultPath, $RemotePowerShellExecutablePath -ErrorAction Stop

          Remove-PSSession -Session $session -ErrorAction SilentlyContinue
          $session = $null

          # Poll a fresh one-shot connection each time (the session that launched
          # the detached process may itself be gone by now) until the detached
          # process writes its result file or the bound is reached.
          $outcome = $null
          $deadline = (Get-Date).AddSeconds(30)
          while ((Get-Date) -lt $deadline) {
            Start-Sleep -Seconds 2
            try {
              $raw = Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {
                param($ResultPath)
                if (Test-Path -LiteralPath $ResultPath -PathType Leaf) {
                  Get-Content -LiteralPath $ResultPath -Raw
                }
              } -ArgumentList $resultPath -ErrorAction Stop
              if ($raw) {
                $outcome = $raw | ConvertFrom-Json
                break
              }
            } catch {
              # WinRM may still be recycling from the detached script's own
              # Restart-Service call; keep polling until the deadline.
            }
          }
          if (-not $outcome) {
            $outcome = [PSCustomObject]@{ Action = 'CreateFailed'; Error = "Detached registration on '$ComputerName' produced no result within 30 seconds." }
          }
        } else {
          $existing = Invoke-Command -Session $session -ScriptBlock { param($n) Get-PSSessionConfiguration -Name $n -ErrorAction SilentlyContinue } -ArgumentList $ConfigurationName
          $outcome = [PSCustomObject]@{ Action = $(if ($existing) { 'WouldUpdate' } else { 'WouldCreate' }); Error = $null }
        }
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from Invoke-Command on $ComputerName" -Tag 'InvokeCommandCall'
      } catch {
        $outcome = [PSCustomObject]@{ Action = 'RemoteConnectionFailed'; Error = $_.Exception.Message }
      } finally {
        if ($session) { Remove-PSSession -Session $session -ErrorAction SilentlyContinue }
      }
    }

    if ($outcome.Error) {
      $failures.Add($outcome.Error)
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $outcome.Error
    }

    $ok = ($failures.Count -eq 0)

    if (-not $isLocal -and $outcome.Action -in @('Created', 'Updated') -and (Get-Command -Name Add-ParityChangeEntry -ErrorAction SilentlyContinue)) {
      $peer = if ($ComputerName -match '(?i)^utat022$') { 'utat01' } elseif ($ComputerName -match '(?i)^utat01$') { 'utat022' } else { 'peer-review-required' }
      Add-ParityChangeEntry -Category Runbook -Item "Profiled remoting endpoint: $ConfigurationName" `
        -OldValue $(if ($outcome.Action -eq 'Created') { 'Absent' } else { 'PriorVersion' }) `
        -NewValue $localHash `
        -PeerHostName $peer -PeerActionKind Document `
        -PeerAction "Verify and, if needed, register '$ConfigurationName' on $peer via Register-ProfiledRemotingEndpoint." `
        -Reason 'SC-0267 managed profiled PowerShell 7 remoting endpoint.' `
        -Confirm:$false | Out-Null
    }

    $result = [PSCustomObject]@{
      ComputerName      = $ComputerName
      ConfigurationName = $ConfigurationName
      Action            = $outcome.Action
      Ok                = $ok
      Failures          = $failures.ToArray()
    }

    if (-not $result.Ok -and $ThrowOnFailure) {
      throw "Register-ProfiledRemotingEndpoint failed: $($result.Failures -join '; ')."
    }

    return $result
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving $fn"
  }
}
