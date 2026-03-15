<#
.SYNOPSIS
Tests the startup scheduled task registration workflow.

.DESCRIPTION
Performs a complete test of the scheduled task lifecycle: registration, verification,
and cleanup. Uses a test task name and requires credentials for registration.

.PARAMETER Credential
PSCredential object for the service account. If not provided, prompts for credentials.

.OUTPUTS
None

.EXAMPLE
$cred = Get-Credential
Invoke-StartupTaskRegistrationTest -Credential $cred

Tests the scheduled task workflow with provided credentials.

.EXAMPLE
Invoke-StartupTaskRegistrationTest

Tests the scheduled task workflow and prompts for credentials.

.NOTES
AI assisted using Powershell.instructions.md as guidelines

.LINK
https://github.com/whertzing/ATAP.Utilities
#>
function Invoke-StartupTaskRegistrationTest {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $false)]
    [System.Management.Automation.PSCredential]$Credential = $(Get-Credential -Message 'Enter service account credentials')
  )

  BEGIN {
    $fn = 'Invoke-StartupTaskRegistrationTest'
    $mn = 'ATAP.Utilities.Powershell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    $taskName = 'TestStartupRegistration'
    $scriptPath = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.BuildTooling.PowerShell\public\Launch-LocalPackageFeeds.ps1'
    $description = 'Test task for startup registration validation'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Starting task registration test sequence for: $taskName"
  }

  PROCESS {
    # Snippet: Try-Catch-Finally
    try {
      # Load required functions
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Loading Register-StartupScheduledTask function'
      . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\Register-StartupScheduledTask.ps1'

      # Register the task
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Registering test task '$taskName'"
      Register-StartupScheduledTask -TaskName $taskName -ScriptPath $scriptPath -Description $description -Credential $Credential

      # Load test function
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Loading Test-StartupScheduledTaskPresence function'
      . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\Test-StartupScheduledTaskPresence.ps1'

      # Verify task exists
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Verifying task '$taskName' exists"
      $exists = Test-StartupScheduledTaskPresence -TaskName $taskName

      if ($exists) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Validation passed: Task '$taskName' is registered"
      }
      else {
        $errorMessage = "Validation failed: Task '$taskName' was not found after registration"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        throw $errorMessage
      }

      # Load cleanup function
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Loading Unregister-StartupScheduledTask function'
      . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\Unregister-StartupScheduledTask.ps1'

      # Cleanup
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Unregistering test task '$taskName'"
      Unregister-StartupScheduledTask -TaskName $taskName
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Cleanup complete: Task '$taskName' has been unregistered"
    }
    catch {
      $errorMessage = "An error occurred during the test sequence. Exception: $($_.Exception.Message)"
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
