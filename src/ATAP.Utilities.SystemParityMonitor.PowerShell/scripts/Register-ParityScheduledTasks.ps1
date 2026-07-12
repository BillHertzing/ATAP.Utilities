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
  dedicated local SvcParityAudit identity and use that identity's purpose-specific
  CommonCIForBitwardenReadOnly DPAPI token through Get-BWSAccessToken. Use S4U for
  local-only audit registration; use Password with a PSCredential when the compare task
  must authenticate to a peer SMB share.

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

    [ValidateSet('ReadOnly', 'ReadWrite')]
    [string] $TokenPurpose = 'ReadOnly',

    [string] $CredentialDirectory,

    [string] $TaskPath = '\ATAP\',

    # Dedicated local service account that owns the DPAPI token and scheduled tasks.
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
    $auditArguments = "-StatePath `"$StatePath`" -HostName `"$HostName`" -TokenPurpose $TokenPurpose"
    if (-not [string]::IsNullOrWhiteSpace($CredentialDirectory)) {
      $auditArguments += " -CredentialDirectory `"$CredentialDirectory`""
    }

    $definitions = @(
      @{
        TaskName = 'ATAP-ParityAudit'
        ScriptName = 'Invoke-ParityScheduledAuditTask.ps1'
        Arguments = $auditArguments
        At = $AuditTime
      }
    )

    if ($TaskSet -eq 'AuditAndCompare') {
      $compareArguments = "-LeftStatePath `"$StatePath`" -RightStatePath `"$RightStatePath`" -LeftHostName `"$HostName`" -RightHostName `"$RightHostName`" -ExpectedCadenceDays $ExpectedCadenceDays -StaleMultiplier $StaleMultiplier -TokenPurpose $TokenPurpose"
      if (-not [string]::IsNullOrWhiteSpace($CredentialDirectory)) {
        $compareArguments += " -CredentialDirectory `"$CredentialDirectory`""
      }

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
        -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 2)
      $principal = New-ScheduledTaskPrincipal -UserId $UserId -LogonType $LogonType -RunLevel $RunLevel

      if ($PSCmdlet.ShouldProcess("$($definition.TaskName) -> $scriptPath", 'Register scheduled task')) {
        if ($Credential) {
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
