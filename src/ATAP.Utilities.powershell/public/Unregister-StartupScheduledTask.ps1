function Unregister-StartupScheduledTask {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [Parameter(Mandatory)]
    [string]$TaskName
  )

  Write-PSFMessage -Level Verbose -Message 'Entering function: Unregister-StartupScheduledTask'
  Write-PSFMessage -Level Information -Message "Attempting to unregister task: $TaskName"

  try {
    if (-not (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue)) {
      $msg = "Scheduled task '$TaskName' not found."
      Write-PSFMessage -Level Warning -Message $msg
      return
    }

    if ($PSCmdlet.ShouldProcess("Scheduled Task '$TaskName'", 'Unregister')) {
      Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
      Write-PSFMessage -Level Information -Message "Scheduled task '$TaskName' unregistered successfully."
    }
  } catch {
    $errorMessage = "Failed to unregister scheduled task '$TaskName'. Exception: $($_.Exception.Message)"
    Write-PSFMessage -Level Error -Message $errorMessage -Exception $_.Exception
    throw $_
  } finally {
    Write-PSFMessage -Level Verbose -Message 'Exiting function: Unregister-StartupScheduledTask'
  }
}
