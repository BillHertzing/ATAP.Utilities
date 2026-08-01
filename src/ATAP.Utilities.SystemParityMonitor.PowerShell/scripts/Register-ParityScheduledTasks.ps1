<#
.SYNOPSIS
  Registers the SystemParityMonitor scheduled tasks on the local host.

.DESCRIPTION
  Reconstructed 2026-07-07 (Sprint 0012 Task 12.46.c): the original
  Register-ParityScheduledTasks.ps1 in ATAP.IAC Windows\Parity was never committed and
  the on-disk copy was corrupted to all null bytes, so this script was rewritten from
  the contract of the two intact task-action scripts it registers
  (Invoke-ParityScheduledAuditTask.ps1 and Invoke-ParityScheduledCompareTask.ps1).

  Task 12.38.e hardened the scheduled path: every host registers a local audit task
  that writes only to its own ParityState folder, and the primary host also registers
  the compare task that reads the peer share and writes drift reports. Tasks run as the
  dedicated local SvcParityAudit identity without Bitwarden or BWS access. Use S4U for
  local-only audit registration; use Password with a PSCredential when the compare task
  must authenticate to a peer SMB share. That Windows logon credential is solely for task
  registration and peer SMB access; it is not a vault credential.

.NOTES
  Dual-purpose script guard: registration only fires under `pwsh -File`; dot-sourcing
  or module import defines the function without side effects (module-loading standard).
#>

function New-ParityScheduledTaskTrigger {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Daily', 'BiWeekly')]
    [string] $Cadence,

    [Parameter(Mandatory = $true)]
    [string] $At,

    [Parameter(Mandatory = $false)]
    [string[]] $BiWeeklyDaysOfWeek = @('Monday')
  )

  if ($Cadence -eq 'Daily') {
    return New-ScheduledTaskTrigger -Daily -At $At
  }

  return New-ScheduledTaskTrigger -Weekly -WeeksInterval 2 -DaysOfWeek $BiWeeklyDaysOfWeek -At $At
}

function Register-ParityScheduledTaskS4U {
  [CmdletBinding()]
  param(
    [string] $TaskName,
    [string] $TaskPath,
    [string] $PwshPath,
    [string] $Arguments,
    [ValidateSet('Daily', 'BiWeekly')]
    [string] $Cadence,
    [string] $At,
    [string[]] $BiWeeklyDaysOfWeek,
    [string] $UserId,
    [System.Management.Automation.PSCredential] $Credential,
    [ValidateSet('Limited', 'Highest')]
    [string] $RunLevel
  )

  $scheduler = New-Object -ComObject 'Schedule.Service'
  $scheduler.Connect()
  $folderPath = $TaskPath.TrimEnd('\\')
  if ([string]::IsNullOrWhiteSpace($folderPath)) {
    $folderPath = '\\'
  }
  $folder = $scheduler.GetFolder($folderPath)
  $definition = $scheduler.NewTask(0)
  $definition.Principal.UserId = $UserId
  $definition.Principal.LogonType = 2 # TASK_LOGON_S4U
  $definition.Principal.RunLevel = if ($RunLevel -eq 'Highest') { 1 } else { 0 }
  $definition.Settings.StartWhenAvailable = $true
  $definition.Settings.MultipleInstances = 2 # TASK_INSTANCES_IGNORE_NEW
  $definition.Settings.ExecutionTimeLimit = 'PT2H'

  $startBoundary = (Get-Date).Date.Add([datetime]::ParseExact($At, 'HH:mm', [Globalization.CultureInfo]::InvariantCulture).TimeOfDay)
  if ($startBoundary -le (Get-Date)) {
    $startBoundary = $startBoundary.AddDays(1)
  }
  $trigger = if ($Cadence -eq 'Daily') { $definition.Triggers.Create(2) } else { $definition.Triggers.Create(3) }
  $trigger.StartBoundary = $startBoundary.ToString('s', [Globalization.CultureInfo]::InvariantCulture)
  if ($Cadence -eq 'Daily') {
    $trigger.DaysInterval = 1
  } else {
    $dayFlags = @{ Sunday = 1; Monday = 2; Tuesday = 4; Wednesday = 8; Thursday = 16; Friday = 32; Saturday = 64 }
    $trigger.WeeksInterval = 2
    $trigger.DaysOfWeek = ($BiWeeklyDaysOfWeek | ForEach-Object { $dayFlags[$_] } | Measure-Object -Sum).Sum
  }

  $action = $definition.Actions.Create(0) # TASK_ACTION_EXEC
  $action.Path = $PwshPath
  $action.Arguments = $Arguments
  $null = $folder.RegisterTaskDefinition($TaskName, $definition, 6, $Credential.UserName, $Credential.GetNetworkCredential().Password, 2, $null)
}

function Register-ParityScheduledTasks {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    # Local parity state root passed to the audit task.
    [string] $StatePath = 'C:\ProgramData\ATAP\ParityState',

    # Peer parity state share passed to the compare task.
    [string] $RightStatePath = '\\utat01\ParityState',

    # Peer host name passed to the compare task.
    [string] $RightHostName = 'utat01',

    # Local host name passed to both task-action scripts.
    [string] $HostName = $env:COMPUTERNAME,

    # Daily trigger times (local).
    [string] $AuditTime = '03:00',
    [string] $CompareTime = '03:30',

    [ValidateSet('AuditOnly', 'AuditAndCompare')]
    [string] $TaskSet = $(if ($env:COMPUTERNAME -ieq 'utat022') { 'AuditAndCompare' } else { 'AuditOnly' }),

    [ValidateSet('Daily', 'BiWeekly')]
    [string] $Cadence = 'Daily',

    [string[]] $BiWeeklyDaysOfWeek = @('Monday'),

    [double] $ExpectedCadenceDays = 0,

    [double] $StaleMultiplier = 1.5,

    [string] $TaskPath = '\ATAP\',

    # Dedicated local service account that owns the scheduled tasks but no vault token.
    [string] $RunAsAccountName = 'SvcParityAudit',

    [string] $UserId,

    [ValidateSet('S4U', 'Password', 'ServiceAccount')]
    [string] $LogonType = 'S4U',

    [System.Management.Automation.PSCredential] $Credential,

    # Audit-only S4U tasks should remain least-privileged. Other task/logon
    # combinations retain the historical Highest default unless explicitly overridden.
    [ValidateSet('Limited', 'Highest')]
    [string] $RunLevel
  )

  begin {
    $fn = 'Register-ParityScheduledTasks'
    $mn = 'ATAP.Utilities.SystemParityMonitor.PowerShell'
    $scriptRoot = $PSScriptRoot
    $pwshPath = (Get-Command -Name 'pwsh' -CommandType Application -ErrorAction Stop).Source
    if ([string]::IsNullOrWhiteSpace($UserId)) {
      $UserId = if ($Credential) {
        $Credential.UserName
      } else {
        "$env:COMPUTERNAME\$RunAsAccountName"
      }
    }

    if ($LogonType -eq 'Password' -and -not $Credential) {
      throw 'Credential is required when -LogonType Password is used.'
    }

    if ($Credential -and $Credential.UserName -ne $UserId) {
      throw "Credential.UserName ('$($Credential.UserName)') must match UserId ('$UserId') when a credential is supplied."
    }

    if ($ExpectedCadenceDays -le 0) {
      $ExpectedCadenceDays = if ($Cadence -eq 'BiWeekly') { 14 } else { 1 }
    }

    if ([string]::IsNullOrWhiteSpace($RunLevel)) {
      $RunLevel = if ($TaskSet -eq 'AuditOnly' -and $LogonType -eq 'S4U') {
        'Limited'
      } else {
        'Highest'
      }
    }
  }

  process {
    $auditArguments = "-StatePath `"$StatePath`" -HostName `"$HostName`""

    $definitions = @(
      @{
        TaskName = 'ATAP-ParityAudit'
        ScriptName = 'Invoke-ParityScheduledAuditTask.ps1'
        Arguments = $auditArguments
        At = $AuditTime
      }
    )

    if ($TaskSet -eq 'AuditAndCompare') {
      $compareArguments = "-LeftStatePath `"$StatePath`" -RightStatePath `"$RightStatePath`" -LeftHostName `"$HostName`" -RightHostName `"$RightHostName`" -ExpectedCadenceDays $ExpectedCadenceDays -StaleMultiplier $StaleMultiplier"

      $definitions += @{
        TaskName = 'ATAP-ParityCompare'
        ScriptName = 'Invoke-ParityScheduledCompareTask.ps1'
        Arguments = $compareArguments
        At = $CompareTime
      }
    }

    foreach ($definition in $definitions) {
      $scriptPath = Join-Path $scriptRoot $definition.ScriptName
      if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        throw "Task-action script was not found at '$scriptPath'."
      }

      $action = New-ScheduledTaskAction -Execute $pwshPath `
        -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$scriptPath`" $($definition.Arguments)"
      $trigger = New-ParityScheduledTaskTrigger -Cadence $Cadence -At $definition.At -BiWeeklyDaysOfWeek $BiWeeklyDaysOfWeek
      $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 2)
      $principal = New-ScheduledTaskPrincipal -UserId $UserId -LogonType $LogonType -RunLevel $RunLevel

      if ($PSCmdlet.ShouldProcess("$($definition.TaskName) -> $scriptPath", 'Register scheduled task')) {
        if ($LogonType -eq 'S4U' -and $Credential) {
          Register-ParityScheduledTaskS4U `
            -TaskName $definition.TaskName -TaskPath $TaskPath -PwshPath $pwshPath `
            -Arguments "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$scriptPath`" $($definition.Arguments)" `
            -Cadence $Cadence -At $definition.At -BiWeeklyDaysOfWeek $BiWeeklyDaysOfWeek `
            -UserId $UserId -Credential $Credential -RunLevel $RunLevel
        } elseif ($Credential) {
          $task = New-ScheduledTask -Action $action -Trigger $trigger -Settings $settings -Principal $principal
          Register-ScheduledTask -TaskName $definition.TaskName -TaskPath $TaskPath `
            -InputObject $task -User $Credential.UserName -Password $Credential.GetNetworkCredential().Password `
            -Force -ErrorAction Stop | Out-Null
        } else {
          Register-ScheduledTask -TaskName $definition.TaskName -TaskPath $TaskPath `
            -Action $action -Trigger $trigger -Settings $settings -Principal $principal `
            -Force -ErrorAction Stop | Out-Null
        }

        if (Get-Command -Name 'Write-PSFMessage' -ErrorAction SilentlyContinue) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
            -Message "Registered scheduled task '$($definition.TaskName)' -> '$scriptPath'." -Tag 'ScheduledTask'
        }
      }
    }
  }

  end {
  }
}

if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.InvocationName -ne '&') {
  # Fires ONLY under: pwsh -File <script>; skipped on dot-source, module import, and &.
  Register-ParityScheduledTasks @args
}
