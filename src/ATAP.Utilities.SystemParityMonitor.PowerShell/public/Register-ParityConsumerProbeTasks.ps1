function Register-ParityConsumerProbeTasks {
  <#
  .SYNOPSIS
    Registers the trigger-less shared .NET tool consumer probe tasks, one per evidence identity.

  .DESCRIPTION
    For every EvidenceFile consumer in the SharedDotNetTools policy this command:

      1. writes a version-independent dispatcher, ATAP-ParityConsumerProbe-<LogicalIdentity>.ps1,
         into an admin-only dispatcher directory (verified not writable by broad identities);
      2. registers task <TaskPath>ATAP-ParityConsumerProbe-<LogicalIdentity> that runs that
         dispatcher AS the consumer's ActualIdentity, with NO triggers of its own;
      3. grants the scheduler identity (default <host>\SvcAceOutpost) start-only rights (GRGX)
         on exactly that task, saving the prior SDDL first.

    The task runs the module's scripts\Invoke-ParityConsumerProbeTask.ps1, so each evidence file
    is written by the account it attests: no impersonation, no credential handling by the
    scheduler. The scheduler (the AceOutpost ParityProbe hosted service) only starts the task.
    CurrentProcess consumers (the audit identity itself) need no task and are skipped.

    LogonType: S4U by default (runs whether or not the user is logged on; no stored password).
    Hosts that refuse S4U registration (UTAT01) can pass -Credential for the consumers that need
    Password logon; each credential's UserName selects the consumer it belongs to. Credentials go
    only to Task Scheduler and are never logged or returned.

    Re-running is idempotent: the dispatcher and definition are rewritten to the same content and
    an existing identical start grant is left as is. Registering a task whose name already exists
    replaces that definition (for example an interim time-triggered task of the same name).

    Plan: _Planning _generated\Sprint0017\BoardCoordination\ClaudeTakeover-20261112\
    senior3-probe-refresh-aceoutpost\Plan.md (SHA-256 8510CC89...), phase P1; SC-0518.

  .PARAMETER PolicyPath
    Schema-v1 SharedDotNetTools policy.

  .PARAMETER StatePath
    ParityState root passed to the task script (results go to its TaskResults subfolder).

  .PARAMETER SchedulerIdentity
    Identity granted start-only rights. Default: <host>\SvcAceOutpost.

  .PARAMETER TaskPath
    Task folder. Default '\ATAP\'.

  .PARAMETER DispatcherDirectory
    Admin-only dispatcher directory. Default 'C:\Program Files\ATAP\ParityDispatchers'.

  .PARAMETER ModuleRoot
    Installed module version directory whose scripts\Invoke-ParityConsumerProbeTask.ps1 the
    dispatchers run. Default: this module's own base directory.

  .PARAMETER PwshPath
    pwsh.exe used by the task and the dispatcher.

  .PARAMETER BackupDirectory
    Receives the pre-change task SDDL for each grant.

  .PARAMETER Credential
    Optional Password-logon credentials, one per consumer that cannot use S4U.

  .OUTPUTS
    PSCustomObject per EvidenceFile consumer: LogicalIdentity, ActualIdentity, TaskName,
    LogonType, DispatcherPath, ScriptPath, SchedulerIdentity, StartRight, Applied.

  .EXAMPLE
    Register-ParityConsumerProbeTasks -WhatIf

  .EXAMPLE
    # From an elevated pwsh on the host:
    Register-ParityConsumerProbeTasks

  .NOTES
    Requires elevation to register tasks for other identities and to write the dispatcher root.

  .LINK
    Invoke-SharedDotNetToolConsumerProbe
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([PSCustomObject])]
  param(
    [string] $PolicyPath = 'C:\ProgramData\ATAP\ParityState\Configuration\SharedDotNetTools.v1.json',

    [string] $StatePath = 'C:\ProgramData\ATAP\ParityState',

    [ValidateNotNullOrEmpty()]
    [string] $SchedulerIdentity = "$($env:COMPUTERNAME)\SvcAceOutpost",

    [ValidatePattern('^\\(.+\\)?$')]
    [string] $TaskPath = '\ATAP\',

    [string] $DispatcherDirectory = 'C:\Program Files\ATAP\ParityDispatchers',

    [string] $ModuleRoot,

    [string] $PwshPath = 'C:\Program Files\PowerShell\7\pwsh.exe',

    [string] $BackupDirectory = 'C:\ProgramData\ATAP\ParityConsumerProbe\backups',

    [System.Management.Automation.PSCredential[]] $Credential = @()
  )

  begin {
    $fn = 'Register-ParityConsumerProbeTasks'
    $mn = 'ATAP.Utilities.SystemParityMonitor.PowerShell'
    Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Function started.'

    if ([string]::IsNullOrWhiteSpace($ModuleRoot)) {
      $ModuleRoot = $MyInvocation.MyCommand.Module.ModuleBase
    }
    foreach ($pair in @(
        @('PolicyPath', $PolicyPath), @('StatePath', $StatePath), @('DispatcherDirectory', $DispatcherDirectory),
        @('ModuleRoot', $ModuleRoot), @('PwshPath', $PwshPath), @('BackupDirectory', $BackupDirectory))) {
      if ([string]::IsNullOrWhiteSpace($pair[1]) -or -not [IO.Path]::IsPathFullyQualified($pair[1])) {
        throw "$($pair[0]) '$($pair[1])' must be fully qualified."
      }
    }
    $scriptPath = Join-Path $ModuleRoot 'scripts\Invoke-ParityConsumerProbeTask.ps1'
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
      throw "Consumer probe task script '$scriptPath' was not found; install the module version before registering."
    }
    $manifestPath = Join-Path $ModuleRoot 'ATAP.Utilities.SystemParityMonitor.PowerShell.psd1'
    $moduleVersion = if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
      [string](Import-PowerShellDataFile -LiteralPath $manifestPath).ModuleVersion
    } else { '<unknown>' }

    $policy = Get-Content -LiteralPath $PolicyPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    if ([int]$policy.SchemaVersion -ne 1) {
      throw "SharedDotNetTools policy at '$PolicyPath' has unsupported SchemaVersion '$($policy.SchemaVersion)'; expected 1."
    }
    $consumers = @($policy.Consumers | Where-Object { [string]$_.EvidenceMode -eq 'EvidenceFile' })
    if ($consumers.Count -eq 0) {
      throw "SharedDotNetTools policy at '$PolicyPath' has no EvidenceFile consumers; nothing to register."
    }
    $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($consumer in $consumers) {
      $logical = [string]$consumer.LogicalIdentity
      if ($logical -notmatch '^[A-Za-z0-9_.-]+$') { throw "Consumer LogicalIdentity '$logical' may contain only letters, digits, '_', '.', and '-'." }
      if (-not $seen.Add($logical)) { throw "Consumer LogicalIdentity '$logical' appears more than once." }
      if ([string]::IsNullOrWhiteSpace([string]$consumer.ActualIdentity)) { throw "Consumer '$logical' has no ActualIdentity." }
    }
    $credentialUsers = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($item in @($Credential | Where-Object { $null -ne $_ })) {
      if (-not $credentialUsers.Add($item.UserName)) { throw "More than one credential was supplied for '$($item.UserName)'." }
      if (-not @($consumers | Where-Object { [string]$_.ActualIdentity -ieq $item.UserName }).Count) {
        throw "Credential '$($item.UserName)' does not match any EvidenceFile consumer ActualIdentity."
      }
    }
    $schedulerSid = Resolve-ParityAccountSid -AccountName $SchedulerIdentity
  }

  process {
    if (-not (Test-Path -LiteralPath $DispatcherDirectory -PathType Container)) {
      if ($PSCmdlet.ShouldProcess($DispatcherDirectory, 'create dispatcher directory')) {
        New-Item -ItemType Directory -Path $DispatcherDirectory -Force | Out-Null
      }
    }
    if (Test-Path -LiteralPath $DispatcherDirectory -PathType Container) {
      Assert-ParityTrustedDirectory -Path $DispatcherDirectory
    }

    foreach ($consumer in $consumers) {
      $logical = [string]$consumer.LogicalIdentity
      $actual = [string]$consumer.ActualIdentity
      $null = Resolve-ParityAccountSid -AccountName $actual
      $taskName = "ATAP-ParityConsumerProbe-$logical"
      $dispatcherPath = Join-Path $DispatcherDirectory "$taskName.ps1"
      $matchingCredential = @($Credential | Where-Object { $null -ne $_ -and $_.UserName -ieq $actual })
      $logonType = if ($matchingCredential.Count -eq 1) { 'Password' } else { 'S4U' }
      $applied = $false
      $startRight = 'NotApplied'

      $content = New-ParityConsumerProbeDispatcherContent -ModuleVersion $moduleVersion -ScriptPath $scriptPath `
        -LogicalIdentity $logical -PolicyPath $PolicyPath -StatePath $StatePath -PwshPath $PwshPath

      if ($PSCmdlet.ShouldProcess("$TaskPath$taskName", "register trigger-less $logonType consumer probe task as $actual, startable by $SchedulerIdentity")) {
        Set-Content -LiteralPath $dispatcherPath -Value ($content + "`n") -Encoding utf8NoBOM -NoNewline -ErrorAction Stop
        Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Dispatcher '$dispatcherPath' targets '$scriptPath' (SystemParityMonitor $moduleVersion)."

        $definitionParameters = @{
          TaskPath = $TaskPath
          TaskName = $taskName
          UserId = $actual
          LogonType = $logonType
          PwshPath = $PwshPath
          DispatcherPath = $dispatcherPath
          Description = "Refreshes $actual shared .NET tool consumer evidence ($logical) for the parity audit. No triggers: started by $SchedulerIdentity (AceOutpost ParityProbe). SC-0518."
        }
        if ($logonType -eq 'Password') { $definitionParameters.Credential = $matchingCredential[0] }
        Register-ParityConsumerProbeTaskDefinition @definitionParameters -Confirm:$false

        $grant = Grant-ParityScheduledTaskStartRight -TaskPath $TaskPath -TaskName $taskName -Sid $schedulerSid -BackupDirectory $BackupDirectory -Confirm:$false
        $startRight = if ($grant.Changed) { 'Granted' } else { 'AlreadyGranted' }
        $applied = $true
      }

      [pscustomobject][ordered]@{
        LogicalIdentity = $logical
        ActualIdentity = $actual
        TaskName = "$TaskPath$taskName"
        LogonType = $logonType
        DispatcherPath = $dispatcherPath
        ScriptPath = $scriptPath
        SchedulerIdentity = $SchedulerIdentity
        StartRight = $startRight
        Applied = $applied
      }
    }
  }

  end {
    Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Function completed.'
  }
}
