<#
.SYNOPSIS
Tests whether a scheduled task exists.

.DESCRIPTION
Checks if a scheduled task with the specified name exists on the system.
Returns $true if the task exists, $false otherwise.

.PARAMETER TaskName
Name of the scheduled task to check.

.OUTPUTS
System.Boolean
Returns $true if the task exists, $false otherwise.

.EXAMPLE
$exists = Test-StartupScheduledTaskPresence -TaskName 'MyStartupTask'
if ($exists) { Write-Host 'Task exists' }

Checks if the scheduled task exists and displays a message.

.NOTES
AI assisted using Powershell.instructions.md as guidelines

.LINK
https://github.com/whertzing/ATAP.Utilities
#>
function Test-StartupScheduledTaskPresence {
  [CmdletBinding()]
  [OutputType([bool])]
  param (
    [Parameter(Mandatory = $true)]
    [string]$TaskName
  )

  BEGIN {
    $fn = 'Test-StartupScheduledTaskPresence'
    $mn = 'ATAP.Utilities.Powershell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Checking existence of scheduled task: $TaskName"
  }

  PROCESS {
    # Snippet: Try-Catch-Finally
    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Querying for scheduled task '$TaskName'"
      $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

      if ($null -ne $task) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Scheduled task '$TaskName' exists"
        return $true
      }
      else {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "Scheduled task '$TaskName' does not exist"
        return $false
      }
    }
    catch {
      $errorMessage = "Failed to check presence of scheduled task '$TaskName'. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      # ToDo: accumulate the errors; potentially add to 'Problems'
      throw # the unadorned throw will throw the $_ exception and keep the stack trace intact
    }
    finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving Function $fn in module $mn"
    }
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
