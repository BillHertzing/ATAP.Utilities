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
    if ($hostName -ne 'utat01') {
      throw "Host '$hostName' is held from parity-task action updates. Only the UTAT01 S4U audit task is approved."
    }
    $taskPolicy = @(
      [pscustomobject]@{
        Name = 'ATAP-ParityAudit'
        Script = 'Invoke-ParityScheduledAuditTask.ps1'
        LogonType = 'S4U'
        RunLevel = 'Limited'
      }
    )

    $getInvariant = {
      param(
        [Parameter(Mandatory = $true)] $RegisteredTask,
        [Parameter(Mandatory = $true)] [xml] $TaskXml
      )

      $execActions = @($TaskXml.Task.Actions.ChildNodes | Where-Object NodeType -eq 'Element')
      if ($execActions.Count -ne 1 -or $execActions[0].LocalName -ne 'Exec') {
        throw "Task '$($RegisteredTask.Name)' must have exactly one Exec action."
      }

      [pscustomobject]@{
        Principal = $TaskXml.Task.Principals.OuterXml
        Triggers = $TaskXml.Task.Triggers.OuterXml
        Settings = $TaskXml.Task.Settings.OuterXml
        TaskVersion = [string] $TaskXml.Task.version
        ActionId = [string] $execActions[0].Id
        ActionWorkingDirectory = [string] $execActions[0].WorkingDirectory
        SecurityDescriptor = [string] $RegisteredTask.GetSecurityDescriptor(7) # OWNER, GROUP, DACL
      }
    }

    $compareInvariant = {
      param(
        [Parameter(Mandatory = $true)] $Before,
        [Parameter(Mandatory = $true)] $After
      )

      @($Before.PSObject.Properties.Name | Where-Object { $Before.$_ -cne $After.$_ })
    }

    $invokeTaskActionChange = {
      param(
        [Parameter(Mandatory = $true)] [string] $TaskPath,
        [Parameter(Mandatory = $true)] [string] $TaskRun
      )

      if ($TaskRun.Length -gt 261) {
        throw "Approved task action exceeds the schtasks /TR limit: $($TaskRun.Length)."
      }

      $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
      $startInfo.FileName = Join-Path $env:SystemRoot 'System32\schtasks.exe'
      $startInfo.UseShellExecute = $false
      $startInfo.CreateNoWindow = $true
      $startInfo.RedirectStandardOutput = $true
      $startInfo.RedirectStandardError = $true
      foreach ($argument in @('/Change', '/TN', $TaskPath, '/TR', $TaskRun)) {
        $null = $startInfo.ArgumentList.Add($argument)
      }

      $process = [System.Diagnostics.Process]::new()
      $process.StartInfo = $startInfo
      $null = $process.Start()
      $stdoutTask = $process.StandardOutput.ReadToEndAsync()
      $stderrTask = $process.StandardError.ReadToEndAsync()
      $timeout = [System.Threading.CancellationTokenSource]::new([TimeSpan]::FromSeconds(30))
      try {
        $process.WaitForExitAsync($timeout.Token).GetAwaiter().GetResult()
      }
      catch [System.OperationCanceledException] {
        try { $process.Kill($true) } catch { }
        $null = $stdoutTask.GetAwaiter().GetResult()
        $null = $stderrTask.GetAwaiter().GetResult()
        throw "Timed out changing the approved action for '$TaskPath'."
      }
      finally {
        $timeout.Dispose()
      }

      $stdout = $stdoutTask.GetAwaiter().GetResult()
      $stderr = $stderrTask.GetAwaiter().GetResult()
      if ($process.ExitCode -ne 0) {
        throw "Task Scheduler refused action update for '$TaskPath' (exit $($process.ExitCode)): $($stdout.Trim()) $($stderr.Trim())"
      }
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
      $beforeInvariant = & $getInvariant -RegisteredTask $task -TaskXml $xml
      $originalTaskRun = "`"$($action.Command)`" $($action.Arguments)".Trim()
      $backupPath = Join-Path $backupDirectory "$($policy.Name).before.xml"
      $task.Xml | Set-Content -LiteralPath $backupPath -Encoding utf8
      $scriptPath = Join-Path $moduleRoot (Join-Path 'scripts' $policy.Script)
      $dispatcherPath = Join-Path $dispatcherDirectory "$($policy.Name).ps1"
      $dispatcherInvocation = "& '$scriptPath' -StatePath '$statePath' -HostName '$hostName' -PackageManagerProfilesPath '$profilesPath'"
      Set-Content -LiteralPath $dispatcherPath -Value "`$ErrorActionPreference = 'Stop'`r`n$dispatcherInvocation`r`nexit `$LASTEXITCODE" -Encoding utf8NoBOM
      if ($PSCmdlet.ShouldProcess("\\ATAP\\$($policy.Name)", "repoint approved action to $ModuleVersion")) {
        $taskPath = "\ATAP\$($policy.Name)"
        $expectedArguments = "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$dispatcherPath`""
        $taskRun = "`"$pwshPath`" $expectedArguments"
        & $invokeTaskActionChange -TaskPath $taskPath -TaskRun $taskRun

        $updatedTask = $folder.GetTask($policy.Name)
        $updatedXml = [xml] $updatedTask.Xml
        $afterInvariant = & $getInvariant -RegisteredTask $updatedTask -TaskXml $updatedXml
        $changedInvariantFields = @(& $compareInvariant -Before $beforeInvariant -After $afterInvariant)
        $updatedAction = $updatedXml.Task.Actions.Exec
        $actionMatches = $updatedAction.Command -ceq $pwshPath -and $updatedAction.Arguments -ceq $expectedArguments
        if ($changedInvariantFields.Count -gt 0 -or -not $actionMatches) {
          $failure = if ($changedInvariantFields.Count -gt 0) {
            "Preserved task fields changed: $($changedInvariantFields -join ', ')."
          }
          else {
            'The postflight action did not match the approved executable and arguments.'
          }
          try {
            & $invokeTaskActionChange -TaskPath $taskPath -TaskRun $originalTaskRun
          }
          catch {
            throw "$failure Automatic action rollback also failed: $($_.Exception.Message)"
          }
          throw "$failure The original action was restored."
        }
      }
      [pscustomobject]@{ TaskName = $policy.Name; BackupPath = $backupPath; ModuleVersion = $ModuleVersion; ExitStatus = 0; ErrorText = $null }
    }
    return $results
  }
}
