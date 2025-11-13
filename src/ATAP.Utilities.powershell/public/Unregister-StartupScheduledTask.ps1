<#
.SYNOPSIS
Unregisters a scheduled task by name.

.DESCRIPTION
Removes a scheduled task from the system. If the task does not exist, a warning
is logged but no error is thrown.

.PARAMETER TaskName
Name of the scheduled task to unregister.

.OUTPUTS
None

.EXAMPLE
Unregister-StartupScheduledTask -TaskName 'MyStartupTask'

Unregisters the scheduled task named 'MyStartupTask'.

.NOTES
AI assisted using Powershell.instructions.md as guidelines

.LINK
https://github.com/whertzing/ATAP.Utilities
#>
function Unregister-StartupScheduledTask {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [Parameter(Mandatory = $true)]
    [string]$TaskName
  )

  BEGIN {
    $fn = 'Unregister-StartupScheduledTask'
    $mn = 'ATAP.Utilities.Powershell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Attempting to unregister task: $TaskName"
  }

  PROCESS {
    # Snippet: Try-Catch-Finally
    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Checking if scheduled task '$TaskName' exists"

      if (-not (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue)) {
        $msg = "Scheduled task '$TaskName' not found"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message $msg
        return
      }

      if ($PSCmdlet.ShouldProcess("Scheduled Task '$TaskName'", 'Unregister')) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Unregistering scheduled task '$TaskName'"
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Scheduled task '$TaskName' unregistered successfully"
      }
    }
    catch {
      $errorMessage = "Failed to unregister scheduled task '$TaskName'. Exception: $($_.Exception.Message)"
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
