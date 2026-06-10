function Get-ScheduledTasks {
  [CmdletBinding()]
  [OutputType([hashtable])]
  param()

  # Run the command and capture the output
  $output = schtasks.exe /Query /FO LIST /V

  # Split output into lines
  $lines = $output -split "`r?`n"

  $tasks = @{}
  $currentTaskName = $null
  $currentProperties = @{}

  foreach ($line in $lines) {
    if ([string]::IsNullOrWhiteSpace($line)) {
      # End of current task block; save if exists
      if ($currentTaskName) {
        $tasks[$currentTaskName] = [PSCustomObject]$currentProperties
        $currentTaskName = $null
        $currentProperties = @{}
      }
      continue
    }
    else {
      # Parse key-value
      $splitPos = $line.IndexOf(':')
      if ($splitPos -gt 0) {
        $key = $line.Substring(0, $splitPos).Trim()
        $value = $line.Substring($splitPos + 1).Trim()

        if ($key -eq 'TaskName') {
          # New task starts
          if ($currentTaskName) {
            $tasks[$currentTaskName] = [PSCustomObject]$currentProperties
            $currentProperties = @{}
          }
          $currentTaskName = $value
        }
        else {
          $currentProperties[$key] = $value
        }
      }
    }
  }

  # Save the last task if any
  if ($currentTaskName) {
    $tasks[$currentTaskName] = [PSCustomObject]$currentProperties
  }

  # $tasks is now a hashtable keyed by task name, with value as PSCustomObject of properties
  $tasks
}
