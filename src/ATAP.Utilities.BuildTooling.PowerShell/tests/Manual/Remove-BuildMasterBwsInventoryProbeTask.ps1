<#
.SYNOPSIS
Deletes the ad-hoc SvcBuildmaster BWS inventory scheduled task.
#>
function Remove-BuildMasterBwsInventoryProbeTask {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$TaskName = 'ATAP BuildMaster BWS Inventory Probe'
  )

  Set-StrictMode -Version Latest
  $ErrorActionPreference = 'Stop'

  $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
  if (-not $task) {
    return [pscustomobject]@{
      TaskName = $TaskName
      Removed  = $false
      Message  = 'Task did not exist.'
    }
  }

  if ($PSCmdlet.ShouldProcess($TaskName, 'Unregister scheduled task')) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
  }

  [pscustomobject]@{
    TaskName = $TaskName
    Removed  = $true
    Message  = 'Task removed.'
  }
}

if ($MyInvocation.InvocationName -ne '.') {
  Remove-BuildMasterBwsInventoryProbeTask @PSBoundParameters
}
