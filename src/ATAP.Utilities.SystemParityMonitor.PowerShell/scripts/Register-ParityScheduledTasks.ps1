<#
.SYNOPSIS
  Registers the two SystemParityMonitor scheduled tasks (daily parity audit and
  daily parity compare) on the local host.

.DESCRIPTION
  Reconstructed 2026-07-07 (Sprint 0012 Task 12.46.c): the original
  Register-ParityScheduledTasks.ps1 in ATAP.IAC Windows\Parity was never committed and
  the on-disk copy was corrupted to all null bytes, so this script was rewritten from
  the contract of the two intact task-action scripts it registers
  (Invoke-ParityScheduledAuditTask.ps1 and Invoke-ParityScheduledCompareTask.ps1).

  Each task runs pwsh -File against the sibling script in this module's scripts\
  folder, under the invoking user's account. The task-action scripts resolve their own
  BWS access token from C:\ProgramData\ATAP\BitwardenCredentials and import the module
  from this folder's parent, so the registration only needs stable paths.

.NOTES
  Dual-purpose script guard: registration only fires under `pwsh -File`; dot-sourcing
  or module import defines the function without side effects (module-loading standard).
#>

function Register-ParityScheduledTasks {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    # Local parity state root passed to the audit task.
    [string] $StatePath = 'C:\ProgramData\ATAP\ParityState',

    # Peer parity state share passed to the compare task.
    [string] $RightStatePath = '\\utat01\ParityState',

    # Peer host name passed to the compare task.
    [string] $RightHostName = 'utat01',

    # Daily trigger times (local).
    [string] $AuditTime = '03:00',
    [string] $CompareTime = '03:30',

    [string] $TaskPath = '\ATAP\',

    # Account the tasks run under; defaults to the invoking user.
    [string] $UserId = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
  )

  begin {
    $fn = 'Register-ParityScheduledTasks'
    $mn = 'ATAP.Utilities.SystemParityMonitor.PowerShell'
    $scriptRoot = $PSScriptRoot
    $pwshPath = (Get-Command -Name 'pwsh' -CommandType Application -ErrorAction Stop).Source
  }

  process {
    $definitions = @(
      @{
        TaskName = 'ATAP-ParityAudit'
        ScriptName = 'Invoke-ParityScheduledAuditTask.ps1'
        Arguments = "-StatePath `"$StatePath`""
        At = $AuditTime
      },
      @{
        TaskName = 'ATAP-ParityCompare'
        ScriptName = 'Invoke-ParityScheduledCompareTask.ps1'
        Arguments = "-LeftStatePath `"$StatePath`" -RightStatePath `"$RightStatePath`" -RightHostName `"$RightHostName`""
        At = $CompareTime
      }
    )

    foreach ($definition in $definitions) {
      $scriptPath = Join-Path $scriptRoot $definition.ScriptName
      if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        throw "Task-action script was not found at '$scriptPath'."
      }

      $action = New-ScheduledTaskAction -Execute $pwshPath `
        -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$scriptPath`" $($definition.Arguments)"
      $trigger = New-ScheduledTaskTrigger -Daily -At $definition.At
      $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable `
        -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 2)
      $principal = New-ScheduledTaskPrincipal -UserId $UserId -LogonType S4U -RunLevel Highest

      if ($PSCmdlet.ShouldProcess("$($definition.TaskName) -> $scriptPath", 'Register scheduled task')) {
        Register-ScheduledTask -TaskName $definition.TaskName -TaskPath $TaskPath `
          -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null

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
