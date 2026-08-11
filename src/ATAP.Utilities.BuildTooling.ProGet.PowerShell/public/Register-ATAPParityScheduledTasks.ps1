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
    $brokerModuleRoot = $MyInvocation.MyCommand.Module.ModuleBase
    if (-not $brokerModuleRoot -or -not (Test-Path -LiteralPath $brokerModuleRoot -PathType Container)) {
      throw 'The trusted broker module root could not be resolved.'
    }
    $dispatcherDirectory = Join-Path $brokerModuleRoot 'dispatchers'
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

    New-Item -ItemType Directory -Path $dispatcherDirectory -Force | Out-Null
    $writeRights = @(
      [System.Security.AccessControl.FileSystemRights]::Write
      [System.Security.AccessControl.FileSystemRights]::WriteData
      [System.Security.AccessControl.FileSystemRights]::CreateFiles
      [System.Security.AccessControl.FileSystemRights]::Modify
      [System.Security.AccessControl.FileSystemRights]::FullControl
    )
    $untrustedDispatcherAccess = (Get-Acl -LiteralPath $dispatcherDirectory).Access | Where-Object {
      $hasWriteRight = $false
      foreach ($right in $writeRights) {
        if ($_.FileSystemRights.HasFlag($right)) { $hasWriteRight = $true; break }
      }
      $_.AccessControlType -eq 'Allow' -and
      $_.IdentityReference.Value -in @('BUILTIN\Users', 'Everyone', 'NT AUTHORITY\Authenticated Users', 'NT AUTHORITY\INTERACTIVE') -and
      $hasWriteRight
    }
    if ($untrustedDispatcherAccess) {
      throw "Dispatcher root '$dispatcherDirectory' is writable by an untrusted identity."
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
      $directScriptMatch = $false
      $dispatcherMatch = $false
      if ($null -ne $action) {
        $directScriptMatch = $action.Arguments -match ([regex]::Escape("scripts\$($policy.Script)"))
        $dispatcherMatch = $action.Arguments -match "ATAP\.Utilities\.BuildTooling\.ProGet\.PowerShell\\\d+\.\d+\.\d+(?:\.\d+)?\\dispatchers\\$([regex]::Escape("$($policy.Name).ps1"))"
      }
      if ($null -eq $action -or $action.Command -ne $pwshPath -or (-not $directScriptMatch -and -not $dispatcherMatch)) {
        throw "Task '$($policy.Name)' does not reference its approved parity script."
      }
      $backupPath = Join-Path $backupDirectory "$($policy.Name).before.xml"
      $task.Xml | Set-Content -LiteralPath $backupPath -Encoding utf8
      $scriptPath = Join-Path $moduleRoot (Join-Path 'scripts' $policy.Script)
      $dispatcherPath = Join-Path $dispatcherDirectory "$($policy.Name).ps1"
      $dispatcherInvocation = if ($policy.Name -eq 'ATAP-ParityCompare') {
        "& '$scriptPath' -LeftStatePath '$statePath' -RightStatePath '\\utat01\ParityState' -LeftHostName 'utat022' -RightHostName 'utat01' -ExpectedCadenceDays 1 -StaleMultiplier 1.5 -PackageManagerProfilesPath '$profilesPath'"
      }
      else {
        "& '$scriptPath' -StatePath '$statePath' -HostName '$hostName' -PackageManagerProfilesPath '$profilesPath'"
      }
      Set-Content -LiteralPath $dispatcherPath -Value "`$ErrorActionPreference = 'Stop'`r`n$dispatcherInvocation`r`nexit `$LASTEXITCODE" -Encoding utf8NoBOM
      if ($PSCmdlet.ShouldProcess("\\ATAP\\$($policy.Name)", "repoint approved action to $ModuleVersion")) {
        # schtasks /Change /TR changes only the action, preserving the current logon
        # token, principal, triggers, and settings. Re-registering XML would require
        # the existing Password-logon secret on UTAT022 and risks changing S4U policy.
        $taskPath = "\ATAP\$($policy.Name)"
        $taskRun = "`"$pwshPath`" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$dispatcherPath`""
        if ($taskRun.Length -gt 261) { throw "Approved task action exceeds the schtasks /TR limit: $($taskRun.Length)." }
        $taskSchedulerOutput = @(& schtasks.exe /Change /TN $taskPath /TR $taskRun 2>&1)
        if ($LASTEXITCODE -ne 0) {
          throw "Task Scheduler refused action update for '$taskPath' (exit $LASTEXITCODE): $($taskSchedulerOutput -join [Environment]::NewLine)"
        }
      }
      [pscustomobject]@{ TaskName = $policy.Name; BackupPath = $backupPath; ModuleVersion = $ModuleVersion; ExitStatus = 0; ErrorText = $null }
    }
    return $results
  }
}
