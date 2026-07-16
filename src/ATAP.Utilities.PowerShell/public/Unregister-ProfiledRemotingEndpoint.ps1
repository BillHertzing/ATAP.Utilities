function Unregister-ProfiledRemotingEndpoint {
  <#
  .SYNOPSIS
    Removes the managed, profiled PowerShell 7 WinRM session configuration
    (SC-0267) from the local or a remote computer.

  .DESCRIPTION
    Bounded rollback: this removes the registered endpoint. It does not
    restore an arbitrary prior configuration -- since WithProfiles.pssc is
    version-controlled, restoring means re-running Register-ProfiledRemotingEndpoint
    from source control, not a snapshot/diff-based undo.

  .PARAMETER ComputerName
    Target host. '.', 'localhost', or the local machine name unregister
    locally. Any other value requires -Credential and unregisters over WinRM.

  .PARAMETER Credential
    Credential used to open the remote session. Get-SecretATAP returns a
    single string field, not a PSCredential, so build one at the call site
    from the 'username' and 'password' fields of the same secret item --
    never hard-code a secret name in library code.

  .PARAMETER ConfigurationName
    Name of the session configuration to remove.

  .PARAMETER ThrowOnFailure
    Throw when removal did not succeed.

  .OUTPUTS
    PSCustomObject with ComputerName, ConfigurationName, Action, Ok, Failures.

  .EXAMPLE
    $u = Get-SecretATAP -SecretName 'Windows.Remoting.Credential.UTAT01' -SecretField 'username'
    $p = Get-SecretATAP -SecretName 'Windows.Remoting.Credential.UTAT01' -SecretField 'password'
    $cred = [PSCredential]::new($u, (ConvertTo-SecureString $p -AsPlainText -Force))
    Unregister-ProfiledRemotingEndpoint -ComputerName utat01 -Credential $cred

  .NOTES
    AI assisted using ./.claude/Rules/Powershell.md as guidelines.
    Implements SC-0267 bounded-rollback requirement.
  .LINK
    Register-ProfiledRemotingEndpoint
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
    [string] $StagingPath = 'C:\ProgramData\ATAP\RemotingEndpoints\WithProfiles.pssc',

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

    $localComputerName = if ($env:COMPUTERNAME) { $env:COMPUTERNAME } else { [Environment]::MachineName }
    $localNames = @('.', 'localhost', $localComputerName) | Where-Object { $_ }
    $isLocal = $ComputerName -in $localNames

    if (-not $isLocal -and -not $Credential) {
      throw "A -Credential is required to unregister '$ConfigurationName' on remote host '$ComputerName'."
    }

    $script:unregisterScript = {
      param($ConfigurationName, $StagingPath)

      $existing = Get-PSSessionConfiguration -Name $ConfigurationName -ErrorAction SilentlyContinue
      if (-not $existing) {
        return [PSCustomObject]@{ Action = 'AlreadyAbsent'; Error = $null }
      }
      try {
        Unregister-PSSessionConfiguration -Name $ConfigurationName -Force -NoServiceRestart -ErrorAction Stop
        # Remove the idempotency hash-marker so a subsequent Register-ProfiledRemotingEndpoint
        # does not report a stale AlreadyCurrent against a now-unregistered endpoint.
        $hashMarkerPath = "$StagingPath.registered-sha256"
        Remove-Item -LiteralPath $hashMarkerPath -Force -ErrorAction SilentlyContinue

        # See Register-ProfiledRemotingEndpoint for why this restart is detached: a
        # synchronous Restart-Service here would stop the WinRM listener hosting this
        # very session before the "start" half can run, killing the connection and
        # potentially leaving the service Stopped on the remote host.
        Start-Process -FilePath (Join-Path $PSHOME 'pwsh.exe') `
          -ArgumentList '-NoLogo', '-Command', 'Start-Sleep -Seconds 2; Restart-Service -Name WinRM -Force' `
          -WindowStyle Hidden

        return [PSCustomObject]@{ Action = 'Removed'; Error = $null }
      } catch {
        return [PSCustomObject]@{ Action = 'RemoveFailed'; Error = $_.Exception.Message }
      }
    }
  }

  process {
    $failures = [System.Collections.Generic.List[string]]::new()
    $outcome = $null

    if ($isLocal) {
      if ($PSCmdlet.ShouldProcess("$ConfigurationName@local", 'Unregister profiled remoting endpoint')) {
        $outcome = & $script:unregisterScript $ConfigurationName $StagingPath
      } else {
        $existing = Get-PSSessionConfiguration -Name $ConfigurationName -ErrorAction SilentlyContinue
        $outcome = [PSCustomObject]@{ Action = $(if ($existing) { 'WouldRemove' } else { 'AlreadyAbsent' }); Error = $null }
      }
    } else {
      # Unregister-PSSessionConfiguration recycles the WinRM plugin host process
      # servicing the CURRENT session (same underlying WSMan behavior as
      # Register-PSSessionConfiguration -- see Register-ProfiledRemotingEndpoint),
      # so running it inline over $session reliably severs the connection before a
      # result can return. Use the same detached-process-then-verify pattern.
      $resultPath = "$StagingPath.unregister-result.json"
      $unregisterScriptPath = "$StagingPath.unregister.ps1"
      $session = $null
      try {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling Invoke-Command on $ComputerName" -Tag 'InvokeCommandCall'
        $session = New-PSSession -ComputerName $ComputerName -Credential $Credential -ErrorAction Stop

        if ($PSCmdlet.ShouldProcess("$ConfigurationName@$ComputerName", 'Unregister profiled remoting endpoint')) {
          $hashMarkerPath = "$StagingPath.registered-sha256"
          $detachedScriptText = @"
try {
  `$existing = Get-PSSessionConfiguration -Name '$ConfigurationName' -ErrorAction SilentlyContinue
  if (-not `$existing) {
    [PSCustomObject]@{ Action = 'AlreadyAbsent'; Error = `$null } | ConvertTo-Json | Set-Content -LiteralPath '$resultPath' -Encoding UTF8 -Force
  } else {
    Unregister-PSSessionConfiguration -Name '$ConfigurationName' -Force -NoServiceRestart -ErrorAction Stop
    Remove-Item -LiteralPath '$hashMarkerPath' -Force -ErrorAction SilentlyContinue
    [PSCustomObject]@{ Action = 'Removed'; Error = `$null } | ConvertTo-Json | Set-Content -LiteralPath '$resultPath' -Encoding UTF8 -Force
  }
} catch {
  [PSCustomObject]@{ Action = 'RemoveFailed'; Error = `$_.Exception.Message } | ConvertTo-Json | Set-Content -LiteralPath '$resultPath' -Encoding UTF8 -Force
} finally {
  Restart-Service -Name WinRM -Force -ErrorAction SilentlyContinue
}
"@
          Invoke-Command -Session $session -ScriptBlock {
            param($ScriptPath, $ScriptText, $ResultPath, $PwshPath)
            Remove-Item -LiteralPath $ResultPath -Force -ErrorAction SilentlyContinue
            Set-Content -LiteralPath $ScriptPath -Value $ScriptText -Encoding UTF8 -Force
            # The bootstrap session may be Windows PowerShell 5.1; run endpoint
            # mutation under the explicit remote PowerShell 7 executable instead.
            if (-not (Test-Path -LiteralPath $PwshPath -PathType Leaf)) {
              throw "The required PowerShell 7 executable was not found: '$PwshPath'."
            }
            Start-Process -FilePath $PwshPath -ArgumentList '-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $ScriptPath -WindowStyle Hidden
          } -ArgumentList $unregisterScriptPath, $detachedScriptText, $resultPath, $RemotePowerShellExecutablePath -ErrorAction Stop

          Remove-PSSession -Session $session -ErrorAction SilentlyContinue
          $session = $null

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
            $outcome = [PSCustomObject]@{ Action = 'RemoveFailed'; Error = "Detached unregistration on '$ComputerName' produced no result within 30 seconds." }
          }
        } else {
          $existing = Invoke-Command -Session $session -ScriptBlock { param($n) Get-PSSessionConfiguration -Name $n -ErrorAction SilentlyContinue } -ArgumentList $ConfigurationName
          $outcome = [PSCustomObject]@{ Action = $(if ($existing) { 'WouldRemove' } else { 'AlreadyAbsent' }); Error = $null }
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

    $result = [PSCustomObject]@{
      ComputerName      = $ComputerName
      ConfigurationName = $ConfigurationName
      Action            = $outcome.Action
      Ok                = ($failures.Count -eq 0)
      Failures          = $failures.ToArray()
    }

    if (-not $result.Ok -and $ThrowOnFailure) {
      throw "Unregister-ProfiledRemotingEndpoint failed: $($result.Failures -join '; ')."
    }

    return $result
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving $fn"
  }
}
