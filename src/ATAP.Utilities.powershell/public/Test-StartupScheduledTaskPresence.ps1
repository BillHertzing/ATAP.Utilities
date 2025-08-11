function Test-StartupScheduledTaskPresence {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string]$TaskName
  )

  Write-PSFMessage -Level Verbose -Message 'Entering function: Test-StartupScheduledTaskPresence'
  Write-PSFMessage -Level Information -Message "Checking existence of scheduled task: $TaskName"

  try {
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

    if ($null -ne $task) {
      Write-PSFMessage -Level Information -Message "Scheduled task '$TaskName' exists."
      return $true
    } else {
      Write-PSFMessage -Level Warning -Message "Scheduled task '$TaskName' does not exist."
      return $false
    }
  } catch {
    $errorMessage = "Failed to check presence of scheduled task '$TaskName'. Exception: $($_.Exception.Message)"
    Write-PSFMessage -Level Error -Message $errorMessage -Exception $_.Exception
    throw $_
  } finally {
    Write-PSFMessage -Level Verbose -Message 'Leaving function: Test-StartupScheduledTaskPresence'
  }
}
