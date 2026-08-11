function Register-ATAPParityScheduledTasks {
  <#
  .SYNOPSIS
    Repoints only the approved local parity tasks to an installed SystemParityMonitor version.

  .DESCRIPTION
    This command is the elevation broker's narrowly typed parity-task installer (Task 14.72).
    It accepts a semantic module version and NOTHING else. Every other value -- task name,
    executable, script, arguments, identity, state path -- is derived from a fixed host policy
    compiled into this function. A request cannot name what runs.

    VERSION SELECTION LIVES IN A DISPATCHER, NOT IN THE TASK DEFINITION.

    Each approved task's action is a fixed, version-independent dispatcher path under an
    admin-only root. Repointing to a new module version rewrites that dispatcher file; it does
    not touch Task Scheduler at all. This matters for security, not convenience:

      * Mutating a registered task requires privileges this broker repeatedly could not obtain
        (E_ACCESSDENIED against the scheduler's own object ACL), and mutating a Password-logon
        task additionally requires re-supplying the run-as password, because Task Scheduler
        will not carry a stored credential through a definition update.
      * A dispatcher rewrite requires only write access to an admin-owned directory, which the
        broker already has as an administrator.

    So the privileged task mutation is a ONE-TIME migration per host. Once a task points at its
    dispatcher, every subsequent version repoint is credential-free and scheduler-free. The
    dispatcher root is deliberately NOT under this module's own versioned directory: that would
    reintroduce a task mutation on every broker upgrade, which is the failure this design exists
    to remove.

    The dispatcher is only as trustworthy as its directory. Its ACL is verified before every
    write, and the command refuses to proceed if any untrusted identity can write there --
    otherwise an unelevated caller could edit the dispatcher and obtain code execution as the
    task's run-as identity.

  .PARAMETER ModuleVersion
    Exact installed SystemParityMonitor version to point the approved tasks at. This is the
    only request-supplied value.

  .PARAMETER TaskCredential
    Run-as credential for a Password-logon task, used ONLY when that task still needs its
    one-time migration onto the dispatcher. This parameter exists for tests. It is NOT in the
    broker's allowedParameters, so a request cannot supply it: when the migration needs a
    credential and none was passed, this function resolves it itself from the canonical
    SecretName 'SvcParityAudit.<host>'. S4U tasks need no password and never resolve one.

  .OUTPUTS
    PSCustomObject per approved task: TaskName, Action, BackupPath, ModuleVersion, ExitStatus,
    ErrorText. Never contains a credential.

  .NOTES
    Task 14.72.b / 14.72.c. Companion contract:
    _Planning/InformationForTheFuture/Parity/ParityTaskInstaller-Contract.md
  #>
  [CmdletBinding(SupportsShouldProcess)]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d+\.\d+\.\d+(?:\.\d+)?$')]
    [string] $ModuleVersion,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.PSCredential] $TaskCredential
  )

  begin {
    $fn = 'Register-ATAPParityScheduledTasks'
    $mn = 'ATAP.Utilities.BuildTooling.ProGet.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Function started for module version $ModuleVersion"

    $hostName = $env:COMPUTERNAME.ToLowerInvariant()
    $moduleRoot = Join-Path 'C:\Program Files\PowerShell\Modules\ATAP.Utilities.SystemParityMonitor.PowerShell' $ModuleVersion
    $statePath = 'C:\ProgramData\ATAP\ParityState'
    $profilesPath = Join-Path $statePath 'Configuration\PackageManagerProfiles.v1.json'
    $pwshPath = 'C:\Program Files\PowerShell\7\pwsh.exe'
    $taskFolderPath = '\ATAP'

    # Version-independent by design. See the .DESCRIPTION note: putting this under the broker
    # module's versioned base would force a privileged task mutation on every broker release.
    $dispatcherDirectory = 'C:\Program Files\ATAP\ParityDispatchers'

    $backupDirectory = Join-Path 'C:\ProgramData\ATAP\ElevationBroker\backups' ("parity-tasks-{0}-{1}" -f $hostName, [datetime]::UtcNow.ToString('yyyyMMdd-HHmmss'))

    # Fixed host policy. This table is the allowlist: a task not named here cannot be touched,
    # and the principal each host is expected to keep is asserted before anything is changed.
    $policyByHost = @{
      'utat01'  = @(
        [pscustomobject]@{
          Name      = 'ATAP-ParityAudit'
          Script    = 'Invoke-ParityScheduledAuditTask.ps1'
          Arguments = @(
            '-StatePath', $statePath
            '-HostName', 'utat01'
            '-PackageManagerProfilesPath', $profilesPath
          )
          LogonType = 'S4U'
          RunLevel  = 'Limited'
        }
      )
      'utat022' = @(
        [pscustomobject]@{
          Name      = 'ATAP-ParityAudit'
          Script    = 'Invoke-ParityScheduledAuditTask.ps1'
          Arguments = @(
            '-StatePath', $statePath
            '-HostName', 'utat022'
            '-PackageManagerProfilesPath', $profilesPath
          )
          LogonType = 'Password'
          RunLevel  = 'HighestAvailable'
        }
        [pscustomobject]@{
          Name      = 'ATAP-ParityCompare'
          Script    = 'Invoke-ParityScheduledCompareTask.ps1'
          Arguments = @(
            '-LeftStatePath', $statePath
            '-RightStatePath', '\\utat01\ParityState'
            '-LeftHostName', 'utat022'
            '-RightHostName', 'utat01'
            '-ExpectedCadenceDays', '1'
            '-StaleMultiplier', '1.5'
            '-PackageManagerProfilesPath', $profilesPath
          )
          LogonType = 'Password'
          RunLevel  = 'HighestAvailable'
        }
      )
    }

    if (-not $policyByHost.ContainsKey($hostName)) {
      throw "Host '$hostName' has no approved parity-task policy. Only utat01 and utat022 are in scope for Task 14.72."
    }
    $taskPolicy = @($policyByHost[$hostName])

    # Fields that must survive the migration byte-for-byte. The security descriptor is included
    # deliberately: a task update that silently widened who may run or modify the task would
    # otherwise look identical to a clean action swap.
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
        Principal              = $TaskXml.Task.Principals.OuterXml
        Triggers               = $TaskXml.Task.Triggers.OuterXml
        Settings               = $TaskXml.Task.Settings.OuterXml
        TaskVersion            = [string] $TaskXml.Task.version
        ActionId               = [string] $execActions[0].Id
        ActionWorkingDirectory = [string] $execActions[0].WorkingDirectory
        SecurityDescriptor     = [string] $RegisteredTask.GetSecurityDescriptor(7) # OWNER, GROUP, DACL
      }
    }

    $compareInvariant = {
      param(
        [Parameter(Mandatory = $true)] $Before,
        [Parameter(Mandatory = $true)] $After
      )

      @($Before.PSObject.Properties.Name | Where-Object { $Before.$_ -cne $After.$_ })
    }

    # Refuses a directory any untrusted identity can write to. The dispatcher runs as the task's
    # run-as identity, so a writable dispatcher root is a privilege-escalation primitive.
    $assertTrustedDirectory = {
      param([Parameter(Mandatory = $true)] [string] $Path)

      $writeRights = @(
        [System.Security.AccessControl.FileSystemRights]::Write
        [System.Security.AccessControl.FileSystemRights]::WriteData
        [System.Security.AccessControl.FileSystemRights]::CreateFiles
        [System.Security.AccessControl.FileSystemRights]::AppendData
        [System.Security.AccessControl.FileSystemRights]::Modify
        [System.Security.AccessControl.FileSystemRights]::FullControl
        [System.Security.AccessControl.FileSystemRights]::TakeOwnership
        [System.Security.AccessControl.FileSystemRights]::ChangePermissions
      )
      $untrustedIdentities = @(
        'Everyone'
        'BUILTIN\Users'
        'NT AUTHORITY\Authenticated Users'
        'NT AUTHORITY\INTERACTIVE'
      )

      $offending = @((Get-Acl -LiteralPath $Path).Access | Where-Object {
          if ($_.AccessControlType -ne 'Allow') { return $false }
          if ($_.IdentityReference.Value -notin $untrustedIdentities) { return $false }
          foreach ($right in $writeRights) {
            if ($_.FileSystemRights.HasFlag($right)) { return $true }
          }
          return $false
        })

      if ($offending.Count -gt 0) {
        $who = ($offending | ForEach-Object { $_.IdentityReference.Value }) -join ', '
        throw "Dispatcher root '$Path' is writable by an untrusted identity ($who); refusing to write a dispatcher there."
      }
    }

    # schtasks path, used only for the S4U migration. stdin is redirected and closed
    # immediately: on a Password-logon task schtasks PROMPTS for the run-as password, and an
    # inherited console turns that prompt into an indefinite hang inside the broker (observed
    # 2026-08-11). Closing stdin converts that into a prompt failure we can report.
    $invokeTaskActionChange = {
      param(
        [Parameter(Mandatory = $true)] [string] $TaskPath,
        [Parameter(Mandatory = $true)] [string] $TaskRun
      )

      if ($TaskRun.Length -gt 261) {
        throw "Approved task action exceeds the schtasks /TR limit: $($TaskRun.Length) characters."
      }

      $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
      $startInfo.FileName = Join-Path $env:SystemRoot 'System32\schtasks.exe'
      $startInfo.UseShellExecute = $false
      $startInfo.CreateNoWindow = $true
      $startInfo.RedirectStandardOutput = $true
      $startInfo.RedirectStandardError = $true
      $startInfo.RedirectStandardInput = $true
      foreach ($argument in @('/Change', '/TN', $TaskPath, '/TR', $TaskRun)) {
        $null = $startInfo.ArgumentList.Add($argument)
      }

      $process = [System.Diagnostics.Process]::new()
      $process.StartInfo = $startInfo
      $null = $process.Start()
      $process.StandardInput.Close()
      # Drain both streams before waiting (R-34): a full redirected buffer deadlocks the wait.
      $stdoutTask = $process.StandardOutput.ReadToEndAsync()
      $stderrTask = $process.StandardError.ReadToEndAsync()
      $timeout = [System.Threading.CancellationTokenSource]::new([TimeSpan]::FromSeconds(60))
      try {
        $process.WaitForExitAsync($timeout.Token).GetAwaiter().GetResult()
      }
      catch [System.OperationCanceledException] {
        try { $process.Kill($true) } catch { }
        throw "Timed out changing the approved action for '$TaskPath'."
      }
      finally {
        $timeout.Dispose()
      }

      $stdout = $stdoutTask.GetAwaiter().GetResult()
      $stderr = $stderrTask.GetAwaiter().GetResult()
      if ($process.ExitCode -ne 0) {
        throw "Task Scheduler refused the action update for '$TaskPath' (exit $($process.ExitCode)): $($stdout.Trim()) $($stderr.Trim())"
      }
    }

    # Resolves the run-as credential for a Password-logon task from the canonical SecretName.
    # Called ONLY on the one-time migration path, and only for the task's own host. The value is
    # handed straight to a PSCredential and never returned, logged, or written anywhere.
    $resolveTaskCredential = {
      param(
        [Parameter(Mandatory = $true)] $RegisteredTaskXml,
        [Parameter(Mandatory = $true)] [string] $ForHost
      )

      $userSid = [string] $RegisteredTaskXml.Task.Principals.Principal.UserId
      $accountName = try {
        (New-Object System.Security.Principal.SecurityIdentifier($userSid)).Translate([System.Security.Principal.NTAccount]).Value
      }
      catch {
        throw "Could not translate the task's run-as SID '$userSid' to an account name: $($_.Exception.Message)"
      }

      $expectedAccount = "$($env:COMPUTERNAME)\SvcParityAudit"
      if ($accountName -ne $expectedAccount) {
        throw "Task run-as account '$accountName' is not the approved parity identity '$expectedAccount'; refusing to resolve a credential for it."
      }

      $secretName = "SvcParityAudit.$ForHost"
      $secretValue = $null
      try {
        $secretValue = Get-SecretATAP -SecretName $secretName -SecretStoreType 'BitwardenSecretsManager' -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($secretValue)) {
          throw "SecretName '$secretName' resolved to an empty value."
        }
        [System.Management.Automation.PSCredential]::new(
          $accountName,
          (ConvertTo-SecureString -String $secretValue -AsPlainText -Force)
        )
      }
      catch {
        throw "Could not resolve the approved run-as credential '$secretName': $($_.Exception.Message)"
      }
      finally {
        $secretValue = $null
      }
    }

    # COM path, used only for the Password-logon migration. Task Scheduler will not preserve a
    # stored password across a definition update, so the credential must be re-supplied. It is
    # passed straight into RegisterTaskDefinition and never assigned to any variable that
    # reaches output, a result file, or a transcript.
    $invokeTaskActionChangeWithCredential = {
      param(
        [Parameter(Mandatory = $true)] $TaskFolder,
        [Parameter(Mandatory = $true)] [string] $TaskName,
        [Parameter(Mandatory = $true)] [string] $Command,
        [Parameter(Mandatory = $true)] [string] $Arguments,
        [Parameter(Mandatory = $true)] [System.Management.Automation.PSCredential] $Credential
      )

      $definition = $TaskFolder.GetTask($TaskName).Definition
      $execActions = @($definition.Actions | Where-Object { $_.Type -eq 0 })
      if ($execActions.Count -ne 1) {
        throw "Task '$TaskName' must have exactly one Exec action."
      }
      $execActions[0].Path = $Command
      $execActions[0].Arguments = $Arguments

      # 4 = TASK_CREATE_OR_UPDATE, 1 = TASK_LOGON_PASSWORD.
      $null = $TaskFolder.RegisterTaskDefinition(
        $TaskName,
        $definition,
        4,
        $Credential.UserName,
        $Credential.GetNetworkCredential().Password,
        1,
        $null
      )
    }
  }

  process {
    # --- Preflight. Nothing is written until every one of these holds. -------------------
    foreach ($policy in $taskPolicy) {
      $scriptPath = Join-Path $moduleRoot (Join-Path 'scripts' $policy.Script)
      if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        throw "Approved parity script '$scriptPath' is not installed. Install SystemParityMonitor $ModuleVersion before repointing."
      }
    }
    if (-not (Test-Path -LiteralPath $profilesPath -PathType Leaf)) {
      throw "Approved parity profile configuration '$profilesPath' is missing."
    }
    if (-not (Test-Path -LiteralPath $pwshPath -PathType Leaf)) {
      throw "Approved PowerShell executable '$pwshPath' is missing."
    }

    if (-not (Test-Path -LiteralPath $dispatcherDirectory -PathType Container)) {
      $null = New-Item -ItemType Directory -Path $dispatcherDirectory -Force
    }
    & $assertTrustedDirectory -Path $dispatcherDirectory

    $null = New-Item -ItemType Directory -Path $backupDirectory -Force

    $service = New-Object -ComObject 'Schedule.Service'
    $service.Connect()
    $folder = $service.GetFolder($taskFolderPath)

    # Resolved lazily on first need and reused across this host's approved tasks, so a two-task
    # migration performs one secret read rather than two. Cleared in the end block.
    $migrationCredential = $null

    $results = foreach ($policy in $taskPolicy) {
      $scriptPath = Join-Path $moduleRoot (Join-Path 'scripts' $policy.Script)
      $dispatcherPath = Join-Path $dispatcherDirectory "$($policy.Name).ps1"
      $expectedArguments = "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$dispatcherPath`""

      $task = $folder.GetTask($policy.Name)
      $xml = [xml] $task.Xml

      # Assert the principal BEFORE touching anything. A task whose identity has drifted from
      # policy is not a task this installer is allowed to repoint.
      $principal = $xml.Task.Principals.Principal
      if ([string] $principal.LogonType -ne $policy.LogonType) {
        throw "Task '$($policy.Name)' on $hostName has logon type '$($principal.LogonType)'; policy requires '$($policy.LogonType)'."
      }
      $actualRunLevel = if ([string]::IsNullOrEmpty([string] $principal.RunLevel)) { 'Limited' } else { [string] $principal.RunLevel }
      if ($actualRunLevel -ne $policy.RunLevel) {
        throw "Task '$($policy.Name)' on $hostName has run level '$actualRunLevel'; policy requires '$($policy.RunLevel)'."
      }

      $action = $xml.Task.Actions.Exec
      if ($null -eq $action -or [string] $action.Command -ne $pwshPath) {
        throw "Task '$($policy.Name)' does not run the approved PowerShell executable."
      }

      # The action must currently be either a direct approved parity script or this task's own
      # dispatcher. Anything else means the task was repointed outside this contract, and the
      # installer refuses rather than overwriting an unrecognized action.
      $currentArguments = [string] $action.Arguments
      $isCanonicalDispatcher = $currentArguments -ceq $expectedArguments
      $isKnownDirectScript = $currentArguments -match ([regex]::Escape("scripts\$($policy.Script)"))
      $isLegacyDispatcher = $currentArguments -match ([regex]::Escape("dispatchers\$($policy.Name).ps1"))
      if (-not ($isCanonicalDispatcher -or $isKnownDirectScript -or $isLegacyDispatcher)) {
        throw "Task '$($policy.Name)' does not reference an approved parity action; refusing to repoint it."
      }

      $beforeInvariant = & $getInvariant -RegisteredTask $task -TaskXml $xml
      $backupPath = Join-Path $backupDirectory "$($policy.Name).before.xml"
      $task.Xml | Set-Content -LiteralPath $backupPath -Encoding utf8

      # --- The version repoint itself: a dispatcher rewrite, no scheduler involvement. -----
      # The approved parity scripts are dual-purpose: each ends in an &-proof guard
      #
      #     if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.InvocationName -ne '&')
      #
      # so they run their entry point ONLY under `pwsh -File`. Invoking one with the call
      # operator returns silently with exit 0 and collects nothing -- a task that reports
      # success while producing no snapshot. The dispatcher therefore reproduces exactly the
      # `pwsh -File` invocation the task performed before migration, one process deeper.
      $quotedArguments = ($policy.Arguments | ForEach-Object {
          if ($_ -match '^-') { $_ } else { "'" + ($_ -replace "'", "''") + "'" }
        }) -join ' '
      $dispatcherContent = @(
        "# Generated by $fn for SystemParityMonitor $ModuleVersion. Do not edit by hand."
        "# Rewriting this file is how an approved parity version repoint happens; the"
        "# scheduled task definition is immutable and intentionally never references a version."
        "#"
        "# The approved script must be launched with -File. It carries an &-proof dual-purpose"
        "# guard and does nothing at all when invoked with the call operator or dot-sourced."
        "`$ErrorActionPreference = 'Stop'"
        "& '$($pwshPath -replace "'", "''")' -NoProfile -NonInteractive -ExecutionPolicy Bypass -File '$($scriptPath -replace "'", "''")' $quotedArguments"
        "exit `$LASTEXITCODE"
      ) -join "`r`n"

      if ($PSCmdlet.ShouldProcess($dispatcherPath, "point dispatcher at SystemParityMonitor $ModuleVersion")) {
        Set-Content -LiteralPath $dispatcherPath -Value $dispatcherContent -Encoding utf8NoBOM
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Dispatcher '$dispatcherPath' now targets SystemParityMonitor $ModuleVersion."
      }

      # --- One-time migration: only if the task is not already on its dispatcher. ----------
      $actionOutcome = 'dispatcher-only'
      if (-not $isCanonicalDispatcher) {
        $taskPath = "$taskFolderPath\$($policy.Name)"
        $originalTaskRun = "`"$($action.Command)`" $currentArguments".Trim()
        $taskRun = "`"$pwshPath`" $expectedArguments"

        if ($PSCmdlet.ShouldProcess($taskPath, 'migrate action onto the fixed dispatcher (one time)')) {
          if ($policy.LogonType -eq 'Password') {
            # Resolved here, at the point of use, and only when a migration is actually due.
            if (-not $migrationCredential) {
              $migrationCredential = if ($TaskCredential) { $TaskCredential } else { & $resolveTaskCredential -RegisteredTaskXml $xml -ForHost $hostName }
            }
            & $invokeTaskActionChangeWithCredential -TaskFolder $folder -TaskName $policy.Name -Command $pwshPath -Arguments $expectedArguments -Credential $migrationCredential
          }
          else {
            & $invokeTaskActionChange -TaskPath $taskPath -TaskRun $taskRun
          }

          # --- Postflight: prove only the action moved, and roll back if not. ---------------
          $updatedTask = $folder.GetTask($policy.Name)
          $updatedXml = [xml] $updatedTask.Xml
          $afterInvariant = & $getInvariant -RegisteredTask $updatedTask -TaskXml $updatedXml
          $changedInvariantFields = @(& $compareInvariant -Before $beforeInvariant -After $afterInvariant)
          $updatedAction = $updatedXml.Task.Actions.Exec
          $actionMatches = ([string] $updatedAction.Command -ceq $pwshPath) -and ([string] $updatedAction.Arguments -ceq $expectedArguments)

          if ($changedInvariantFields.Count -gt 0 -or -not $actionMatches) {
            $failure = if ($changedInvariantFields.Count -gt 0) {
              "Preserved task fields changed: $($changedInvariantFields -join ', ')."
            }
            else {
              'The postflight action did not match the approved executable and arguments.'
            }
            try {
              if ($policy.LogonType -eq 'Password') {
                & $invokeTaskActionChangeWithCredential -TaskFolder $folder -TaskName $policy.Name -Command $action.Command -Arguments $currentArguments -Credential $migrationCredential
              }
              else {
                & $invokeTaskActionChange -TaskPath $taskPath -TaskRun $originalTaskRun
              }
            }
            catch {
              throw "$failure Automatic action rollback ALSO FAILED: $($_.Exception.Message). Restore '$backupPath' manually."
            }
            throw "$failure The original action was restored from '$backupPath'."
          }
          $actionOutcome = 'migrated-to-dispatcher'
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Task '$taskPath' migrated onto its fixed dispatcher; principal, triggers, settings, and security descriptor unchanged."
        }
      }

      [pscustomobject]@{
        TaskName      = $policy.Name
        Action        = $actionOutcome
        DispatcherPath = $dispatcherPath
        BackupPath    = $backupPath
        ModuleVersion = $ModuleVersion
        ExitStatus    = 0
        ErrorText     = $null
      }
    }

    return $results
  }

  end {
    $migrationCredential = $null
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Function completed'
  }
}
