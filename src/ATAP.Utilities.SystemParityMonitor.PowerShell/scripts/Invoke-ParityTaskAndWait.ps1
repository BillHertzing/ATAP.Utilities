[CmdletBinding(SupportsShouldProcess)]
param(
  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string] $TaskName,

  [ValidateNotNullOrEmpty()]
  [string] $TaskPath = '\ATAP\',

  [ValidateRange(1, 3600)]
  [int] $TimeoutSeconds = 300,

  [ValidateRange(1, 60)]
  [int] $PollIntervalSeconds = 2
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-ParityTaskAndWait {
  <#
  .SYNOPSIS
    Starts a parity scheduled task and waits for its newly requested run to finish.

  .DESCRIPTION
    Starts one task in the ATAP Task Scheduler folder, waits until Task Scheduler
    records a run that began after this invocation, and throws if the task times out
    or reports a non-zero LastTaskResult. The script never handles a task credential
    or a BWS token.

  .PARAMETER TaskName
    Name of the scheduled task to start.

  .PARAMETER TaskPath
    Task Scheduler folder containing the task.

  .PARAMETER TimeoutSeconds
    Maximum elapsed time to wait for the newly started task to complete.

  .PARAMETER PollIntervalSeconds
    Number of seconds between Task Scheduler status checks.

  .OUTPUTS
    PSCustomObject containing the completed task identity and result metadata.

  .EXAMPLE
    powershell.exe -NoProfile -File .\Invoke-ParityTaskAndWait.ps1 -TaskName 'ATAP-ParityAudit'

  .NOTES
    The function is available when this file is dot-sourced. Direct execution is
    intentionally limited to PowerShell -File; this preserves the repository's
    dual-purpose-script guard.
  #>
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $TaskName,

    [ValidateNotNullOrEmpty()]
    [string] $TaskPath = '\ATAP\',

    [ValidateRange(1, 3600)]
    [int] $TimeoutSeconds = 300,

    [ValidateRange(1, 60)]
    [int] $PollIntervalSeconds = 2
  )

  begin {
    $fn = 'Invoke-ParityTaskAndWait'
    $mn = 'ATAP.Utilities.SystemParityMonitor.PowerShell'
  }

  process {
    try {
      $previousInfo = Get-ScheduledTaskInfo -TaskPath $TaskPath -TaskName $TaskName -ErrorAction Stop
      if (-not $PSCmdlet.ShouldProcess("$TaskPath$TaskName", 'Start scheduled task and wait for completion')) {
        return [pscustomobject]@{
          TaskName = $TaskName
          TaskPath = $TaskPath
          WouldStart = $true
        }
      }

      Start-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction Stop
      $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
      $observedNewRun = $false

      do {
        Start-Sleep -Seconds $PollIntervalSeconds
        $task = Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction Stop
        $info = Get-ScheduledTaskInfo -TaskPath $TaskPath -TaskName $TaskName -ErrorAction Stop

        $observedNewRun = $info.LastRunTime -gt $previousInfo.LastRunTime
      } while (
        ((-not $observedNewRun) -or ($task.State -eq 'Running')) -and
        ((Get-Date) -lt $deadline)
      )

      if (-not $observedNewRun) {
        throw "Task '$TaskPath$TaskName' did not record a new run within $TimeoutSeconds seconds."
      }
      if ($task.State -eq 'Running') {
        throw "Task '$TaskPath$TaskName' did not complete within $TimeoutSeconds seconds."
      }
      if ($info.LastTaskResult -ne 0) {
        throw "Task '$TaskPath$TaskName' failed with LastTaskResult $($info.LastTaskResult)."
      }

      [pscustomobject]@{
        TaskName = $TaskName
        TaskPath = $TaskPath
        State = $task.State
        LastRunTime = $info.LastRunTime
        LastTaskResult = $info.LastTaskResult
      }
    } catch {
      if (Get-Command -Name 'Write-PSFMessage' -ErrorAction SilentlyContinue) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error `
          -Message "Parity task '$TaskPath$TaskName' failed to start or complete. $($_.Exception.Message)" `
          -Tag 'ScheduledTask'
      }
      throw
    }
  }

  end {
  }
}

if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.InvocationName -ne '&') {
  Invoke-ParityTaskAndWait @PSBoundParameters
}
