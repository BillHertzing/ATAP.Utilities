<#
.SYNOPSIS
Starts the ad-hoc SvcBuildmaster BWS inventory scheduled task and waits.
#>
function Invoke-BuildMasterBwsInventoryProbeTask {
  [CmdletBinding()]
  param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$TaskName = 'ATAP BuildMaster BWS Inventory Probe',

    [Parameter()]
    [ValidateRange(5, 3600)]
    [int]$TimeoutSeconds = 300
  )

  Set-StrictMode -Version Latest
  $ErrorActionPreference = 'Stop'

  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  Start-ScheduledTask -TaskName $TaskName

  do {
    Start-Sleep -Seconds 2
    $task = Get-ScheduledTask -TaskName $TaskName
    $info = Get-ScheduledTaskInfo -TaskName $TaskName
  } while ($task.State -eq 'Running' -and (Get-Date) -lt $deadline)

  if ($task.State -eq 'Running') {
    throw "Scheduled task '$TaskName' did not finish within $TimeoutSeconds seconds."
  }

  [pscustomobject]@{
    TaskName       = $TaskName
    State          = $task.State
    LastRunTime    = $info.LastRunTime
    LastTaskResult = $info.LastTaskResult
  }
}

if ($MyInvocation.InvocationName -ne '.') {
  Invoke-BuildMasterBwsInventoryProbeTask @PSBoundParameters
}
