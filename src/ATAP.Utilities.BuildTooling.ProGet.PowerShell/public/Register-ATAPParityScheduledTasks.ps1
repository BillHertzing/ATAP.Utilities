function Register-ATAPParityScheduledTasks {
  <#
  .SYNOPSIS
    Repoints only the approved local parity tasks to an installed module version.

  .DESCRIPTION
    This command is the elevation broker's narrowly typed parity-task installer. It accepts
    only a semantic module version, derives every other value from the local host policy, and
    preserves the existing task definition except for the approved action script version.
  #>
  [CmdletBinding(SupportsShouldProcess)]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d+\.\d+\.\d+(?:\.\d+)?$')]
    [string] $ModuleVersion
  )

  begin {
    $fn = 'Register-ATAPParityScheduledTasks'
    $mn = 'ATAP.Utilities.BuildTooling.ProGet.PowerShell'
    $hostName = $env:COMPUTERNAME.ToLowerInvariant()
    $moduleRoot = Join-Path 'C:\Program Files\PowerShell\Modules\ATAP.Utilities.SystemParityMonitor.PowerShell' $ModuleVersion
    $statePath = 'C:\ProgramData\ATAP\ParityState'
    $profilesPath = Join-Path $statePath 'Configuration\PackageManagerProfiles.v1.json'
    $pwshPath = 'C:\Program Files\PowerShell\7\pwsh.exe'
    $backupDirectory = Join-Path 'C:\ProgramData\ATAP\ElevationBroker\backups' ("parity-tasks-{0}-{1}" -f $hostName, [guid]::NewGuid().ToString('N'))
    $taskPolicy = switch ($hostName) {
      'utat01' { @([pscustomobject]@{ Name = 'ATAP-ParityAudit'; Script = 'Invoke-ParityScheduledAuditTask.ps1'; LogonType = 'S4U'; RunLevel = 'Limited' }) }
      'utat022' { @(
          [pscustomobject]@{ Name = 'ATAP-ParityAudit'; Script = 'Invoke-ParityScheduledAuditTask.ps1'; LogonType = 'Password'; RunLevel = 'HighestAvailable' },
          [pscustomobject]@{ Name = 'ATAP-ParityCompare'; Script = 'Invoke-ParityScheduledCompareTask.ps1'; LogonType = 'Password'; RunLevel = 'HighestAvailable' }
        ) }
      default { throw "Host '$hostName' is not an approved parity-task target." }
    }
  }

  process {
    foreach ($policy in $taskPolicy) {
      $scriptPath = Join-Path $moduleRoot (Join-Path 'scripts' $policy.Script)
      if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        throw "Approved parity script '$scriptPath' is not installed."
      }
    }
    if (-not (Test-Path -LiteralPath $profilesPath -PathType Leaf)) {
      throw "Approved parity profile configuration '$profilesPath' is missing."
    }
    if (-not (Test-Path -LiteralPath $pwshPath -PathType Leaf)) {
      throw "Approved PowerShell executable '$pwshPath' is missing."
    }

    New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null
    $service = New-Object -ComObject 'Schedule.Service'
    $service.Connect()
    $folder = $service.GetFolder('\ATAP')
    $results = foreach ($policy in $taskPolicy) {
      $task = $folder.GetTask($policy.Name)
      $xml = [xml] $task.Xml
      if ($xml.Task.Principals.Principal.LogonType -ne $policy.LogonType -or
        ($policy.RunLevel -eq 'Limited' -and $xml.Task.Principals.Principal.RunLevel)) {
        throw "Task '$($policy.Name)' does not match the approved $hostName principal policy."
      }
      if ($policy.RunLevel -eq 'HighestAvailable' -and $xml.Task.Principals.Principal.RunLevel -ne 'HighestAvailable') {
        throw "Task '$($policy.Name)' does not match the approved $hostName run level."
      }
      $action = $xml.Task.Actions.Exec
      if ($null -eq $action -or $action.Arguments -notmatch ([regex]::Escape("scripts\$($policy.Script)"))) {
        throw "Task '$($policy.Name)' does not reference its approved parity script."
      }
      $backupPath = Join-Path $backupDirectory "$($policy.Name).before.xml"
      $task.Xml | Set-Content -LiteralPath $backupPath -Encoding utf8
      $scriptPath = Join-Path $moduleRoot (Join-Path 'scripts' $policy.Script)
      $arguments = "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$scriptPath`" -StatePath `"$statePath`" -HostName `"$hostName`" -PackageManagerProfilesPath `"$profilesPath`""
      if ($PSCmdlet.ShouldProcess("\\ATAP\\$($policy.Name)", "repoint approved action to $ModuleVersion")) {
        # schtasks /Change /TR changes only the action, preserving the current logon
        # token, principal, triggers, and settings. Re-registering XML would require
        # the existing Password-logon secret on UTAT022 and risks changing S4U policy.
        $taskPath = "\ATAP\$($policy.Name)"
        $taskRun = "`"$pwshPath`" $arguments"
        & schtasks.exe /Change /TN $taskPath /TR $taskRun | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Task Scheduler refused action update for '$taskPath' (exit $LASTEXITCODE)." }
      }
      [pscustomobject]@{ TaskName = $policy.Name; BackupPath = $backupPath; ModuleVersion = $ModuleVersion; ExitStatus = 0; ErrorText = $null }
    }
    return $results
  }
}
