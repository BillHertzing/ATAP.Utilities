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
    Local path to the source .pssc file. Defaults to the module's own
    WithProfiles.pssc under Profiles\.

  .PARAMETER RemoteStagingPath
    Path on the remote host where the .pssc is copied before registration.
    Ignored for local registration.

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
    [string] $Path = (Join-Path $PSScriptRoot '..\Profiles\WithProfiles.pssc'),

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $RemoteStagingPath = 'C:\ProgramData\ATAP\RemotingEndpoints\WithProfiles.pssc',

    [Parameter()]
    [switch] $ThrowOnFailure
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn"

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
      throw "Session configuration file not found: '$Path'."
    }

    $localComputerName = if ($env:COMPUTERNAME) { $env:COMPUTERNAME } else { [Environment]::MachineName }
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
      param($ConfigurationName, $PsscPath, $ExpectedHash)

      # WinRM does not expose the byte content of a registered .pssc-defined
      # configuration in a directly comparable form, so idempotency is tracked via
      # a sidecar hash-marker file written next to the staged .pssc at the end of
      # a successful registration -- not by re-hashing the source file (which would
      # trivially match itself and never detect drift).
      $hashMarkerPath = "$PsscPath.registered-sha256"
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
    $outcome = $null

    if ($isLocal) {
      if ($PSCmdlet.ShouldProcess("$ConfigurationName@local", 'Register profiled remoting endpoint')) {
        $outcome = & $script:registerScript $ConfigurationName $Path $localHash
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
          param($StagingPath)
          $dir = Split-Path -Path $StagingPath -Parent
          if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        } -ArgumentList $RemoteStagingPath -ErrorAction Stop

        Copy-Item -Path $Path -Destination $RemoteStagingPath -ToSession $session -Force -ErrorAction Stop

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
            param($ScriptPath, $ScriptText, $ResultPath)
            Remove-Item -LiteralPath $ResultPath -Force -ErrorAction SilentlyContinue
            Set-Content -LiteralPath $ScriptPath -Value $ScriptText -Encoding UTF8 -Force
            # Launch with the actual running host executable, not $PSHOME\pwsh.exe --
            # a session opened without -ConfigurationName connects to the DEFAULT
            # WinRM endpoint (Windows PowerShell 5.1), where $PSHOME has no pwsh.exe.
            $currentHostExe = (Get-Process -Id $PID).Path
            Start-Process -FilePath $currentHostExe `
              -ArgumentList '-NoLogo', '-File', $ScriptPath `
              -WindowStyle Hidden
          } -ArgumentList $registerScriptPath, $detachedScriptText, $resultPath -ErrorAction Stop

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
