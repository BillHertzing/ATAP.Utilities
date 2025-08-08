
# this function will create a new scheduled task.
# The task it runs checks for new packages in the ProGet feeds
# and if there are new packages, it will send an email notification.
# It will also log the results to a log file.
# The task will run at startup plus a 5 minute delay, and it will run every 6 hours.
# It uses the scheduled task cmdlets in ATAP.Utilities.Powershell moduleto create the task.

function New-CheckForNewPackagesStartupTask {
  [CmdletBinding()]
  param (
  )

  Begin {
    Write-PSFMessage -Level Verbose -Message 'Entering function: New-CheckForNewPackagesStartupTask' -Tag 'New-CheckForNewPackagesStartupTask', 'Trace'
    # ToDo: Remove this when packaging works
    #  if (-not (Get-Command -Name 'Register-StartupScheduledTask' -CommandType Function -ErrorAction SilentlyContinue)) {
    . "C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\Register-ScheduledTaskForStartup.ps1"
    # }
    #  if (-not (Get-Command -Name 'New-ScheduledTaskTrigger' -CommandType Function -ErrorAction SilentlyContinue)) {
    . "C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\New-ScheduledTaskTrigger.ps1"
    # }
    $taskName = 'CheckForNewPackages'
    $taskDescription = 'Checks for new packages in ProGet feeds and sends email notification if there are new packages.'
    $taskAction = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.IAC.Ansible.Powershell\public\Test-ChocoPackageUpdatesFromYaml.ps1'
    $startupTrigger = New-ScheduledTaskTrigger -AtStartup -Delay (New-TimeSpan -Minutes 5)
    # trigger: run every hour when awake (daily at midnight, repeat hourly for 24 hrs)
    $hourlyTrigger = New-ScheduledTaskTrigger -Daily -At ([DateTime]::Today) `
      -RepetitionInterval (New-TimeSpan -Hours 1) `
      -RepetitionDuration (New-TimeSpan -Days 1)
    # combine triggers
    $taskTrigger = @($startupTrigger, $hourlyTrigger)
    # do not wake the computer to run this task
    $taskSettings = New-ScheduledTaskSettingsSet -WakeToRun:$false
  }

  Process {
    Write-PSFMessage -Level Verbose -Message 'Creating scheduled task for checking new packages' -Tag 'New-CheckForNewPackagesStartupTask', 'Trace'
    try {
      Register-StartupScheduledTask -TaskName $taskName `
        -TaskDescription $taskDescription `
        -TaskAction $taskAction `
        -TaskTrigger $taskTrigger `
        -RunLevel Highest `
        -User 'SYSTEM' `
        -Force
      Write-PSFMessage -Level Verbose -Message 'Scheduled task created successfully' -Tag 'New-CheckForNewPackagesStartupTask', 'Trace'
    }
    catch {
      $errormessage = "Failed to create scheduled task. Exception: $($_.Exception.Message)"
      Write-PSFMessage -Level Error -Message $errormessage  -Tag 'New-CheckForNewPackagesStartupTask', 'Trace', 'Error'
      throw $errormessage
    }
    # Validate that the task was created
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if (-not $task) {
      $errormessage = "Scheduled task '$taskName' was not created successfully."
      Write-PSFMessage -Level Error -Message $errormessage -Tag 'New-CheckForNewPackagesStartupTask', 'Trace', 'Error'
      throw $errormessage
    }
  }

  End {
    Write-PSFMessage -Level Verbose -Message 'Leaving function: New-CheckForNewPackagesStartupTask' -Tag 'New-CheckForNewPackagesStartupTask', 'Trace'
  }
}
