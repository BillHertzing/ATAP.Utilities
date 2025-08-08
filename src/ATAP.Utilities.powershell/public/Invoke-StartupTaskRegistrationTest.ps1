function Invoke-StartupTaskRegistrationTest {
  [CmdletBinding()]
  param (
    [System.Management.Automation.PSCredential]$Credential = $(Get-Credential -Message 'Enter service account credentials')
  )

  $taskName = 'TestStartupRegistration'
  $scriptPath = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.BuildTooling.PowerShell\public\Launch-LocalPackageFeeds.ps1'

  try {
    Write-PSFMessage -Level Information -Message "Invoking task registration test sequence for: $taskName"
    . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.BuildTooling.PowerShell\public\Register-ScheduledTaskForStartup.ps1'
    Register-StartupScheduledTask -TaskName $taskName -ScriptPath $scriptPath -Credential $Credential
    . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.BuildTooling.PowerShell\public\Test-StartupScheduledTaskPresence.ps1'
    $exists = Test-StartupScheduledTaskPresence -TaskName $taskName

    if ($exists) {
      Write-PSFMessage -Level Information -Message "Validation passed: Task '$taskName' is registered."
    } else {
      Write-PSFMessage -Level Error -Message "Validation failed: Task '$taskName' was not found after registration."
    }
    . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.BuildTooling.PowerShell\public\Unregister-StartupScheduledTask.ps1'
    Unregister-StartupScheduledTask -TaskName $taskName
    Write-PSFMessage -Level Information -Message "Cleanup complete: Task '$taskName' has been unregistered."
  } catch {
    Write-PSFMessage -Level Error -Message "An error occurred during the test sequence: $($_.Exception.Message)" -Exception $_.Exception
  }
}
