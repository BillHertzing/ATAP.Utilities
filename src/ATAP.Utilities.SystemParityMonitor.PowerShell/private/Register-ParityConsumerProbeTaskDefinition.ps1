function Register-ParityConsumerProbeTaskDefinition {
  <#
  .SYNOPSIS
    Registers (create or update) one trigger-less consumer probe task through Task Scheduler COM.

  .DESCRIPTION
    The task has NO triggers: it runs only when something with start rights starts it (the
    AceOutpost ParityProbe scheduler). Its single Exec action runs the version-independent
    dispatcher, with PowerShell profiles loading (no -NoProfile). RunLevel is Limited.

    LogonType S4U runs whether or not the user is logged on and stores no password; it is the
    default. LogonType Password is accepted for hosts where S4U registration is refused (UTAT01,
    see Register-ATAPParityScheduledTasks); the caller supplies the credential, which is handed
    to Task Scheduler only and never stored, logged, or returned here.

  .PARAMETER TaskPath
    Task folder, for example '\ATAP\'. Created if missing.

  .PARAMETER TaskName
    Task name.

  .PARAMETER UserId
    Run-as identity (the consumer's ActualIdentity).

  .PARAMETER LogonType
    S4U or Password.

  .PARAMETER Credential
    Required for Password; must name UserId.

  .PARAMETER PwshPath
    Fully qualified pwsh.exe path.

  .PARAMETER DispatcherPath
    Fully qualified dispatcher path the action runs.

  .PARAMETER Description
    Task description.
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [Parameter(Mandatory = $true)] [string] $TaskPath,
    [Parameter(Mandatory = $true)] [string] $TaskName,
    [Parameter(Mandatory = $true)] [string] $UserId,
    [Parameter(Mandatory = $true)] [ValidateSet('S4U', 'Password')] [string] $LogonType,
    [System.Management.Automation.PSCredential] $Credential,
    [Parameter(Mandatory = $true)] [string] $PwshPath,
    [Parameter(Mandatory = $true)] [string] $DispatcherPath,
    [string] $Description = ''
  )

  begin {
    $fn = 'Register-ParityConsumerProbeTaskDefinition'
    $mn = 'ATAP.Utilities.SystemParityMonitor.PowerShell'
    if ($LogonType -eq 'Password') {
      if (-not $Credential) { throw "A Password-logon task '$TaskName' requires a credential." }
      if ($Credential.UserName -ine $UserId) { throw "Credential user '$($Credential.UserName)' must equal the task identity '$UserId'." }
    }
  }

  process {
    if (-not $PSCmdlet.ShouldProcess("$TaskPath$TaskName", "register trigger-less $LogonType task as $UserId")) { return }

    $TASK_CREATE_OR_UPDATE = 6
    $TASK_LOGON_PASSWORD = 1
    $TASK_LOGON_S4U = 2
    $TASK_ACTION_EXEC = 0
    $TASK_INSTANCES_IGNORE_NEW = 2
    $TASK_RUNLEVEL_LUA = 0

    try {
      $scheduler = New-Object -ComObject 'Schedule.Service'
      $scheduler.Connect()
      $folderPath = $TaskPath.TrimEnd('\')
      $folder = try { $scheduler.GetFolder($folderPath) } catch { $scheduler.GetFolder('\').CreateFolder($folderPath.TrimStart('\'), $null) }

      $definition = $scheduler.NewTask(0)
      $definition.RegistrationInfo.Description = $Description
      $definition.Principal.UserId = $UserId
      $definition.Principal.LogonType = if ($LogonType -eq 'Password') { $TASK_LOGON_PASSWORD } else { $TASK_LOGON_S4U }
      $definition.Principal.RunLevel = $TASK_RUNLEVEL_LUA
      $definition.Settings.Enabled = $true
      $definition.Settings.StartWhenAvailable = $false
      $definition.Settings.DisallowStartIfOnBatteries = $false
      $definition.Settings.StopIfGoingOnBatteries = $false
      $definition.Settings.MultipleInstances = $TASK_INSTANCES_IGNORE_NEW
      $definition.Settings.ExecutionTimeLimit = 'PT10M'
      # Deliberately no $definition.Triggers.Create(...): the task never runs on its own schedule.

      $action = $definition.Actions.Create($TASK_ACTION_EXEC)
      $action.Path = $PwshPath
      # Profiles load (no -NoProfile), by operator decision 2026-11-15.
      $action.Arguments = "-NonInteractive -ExecutionPolicy Bypass -File `"$DispatcherPath`""

      if ($LogonType -eq 'Password') {
        $null = $folder.RegisterTaskDefinition($TaskName, $definition, $TASK_CREATE_OR_UPDATE, $Credential.UserName, $Credential.GetNetworkCredential().Password, $TASK_LOGON_PASSWORD, $null)
      } else {
        $null = $folder.RegisterTaskDefinition($TaskName, $definition, $TASK_CREATE_OR_UPDATE, $UserId, $null, $TASK_LOGON_S4U, $null)
      }
    } catch {
      $hresult = try { '0x{0:X8}' -f $_.Exception.HResult } catch { '<unknown>' }
      Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Task Scheduler refused to register '$TaskPath$TaskName' ($hresult): $($_.Exception.Message)"
      throw
    }
    Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Registered trigger-less $LogonType task '$TaskPath$TaskName' as '$UserId' -> '$DispatcherPath'."
  }

  end {
  }
}
