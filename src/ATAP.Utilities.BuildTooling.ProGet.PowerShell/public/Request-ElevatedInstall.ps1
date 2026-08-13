function Request-ElevatedInstall {
  <#
  .SYNOPSIS
      Asks the elevation broker to run a validated installer, then waits for the result.
      No UAC prompt anywhere.

  .DESCRIPTION
      This is the call an unelevated agent or build step makes instead of
      `Start-Process -Verb RunAs` or a bare `Install-Module -Scope AllUsers`. It writes a
      request JSON into the broker's requests folder, starts the broker task on demand, polls
      for the matching result, and returns it. The broker (running as the broker service
      account under the ATAP-ElevatedInstallBroker scheduled task) does the elevated work.

      The point of this helper is that the failure is DIAGNOSABLE and BOUNDED. The 2026-07-25
      Codex review recorded agents retrying elevation blindly after a denied UAC prompt, with
      no transcript to explain why. Here a timeout returns a result object with status
      'timeout' and the path of the broker transcript, and the caller is expected to hand
      that to the user rather than retry.

      NOTE ON TRUST DIRECTION: this helper writes into a folder that an elevated process reads
      and acts on. It therefore sends the installer *id*, never a path or a command. The
      broker resolves the id against its admin-owned config and proves the target's integrity
      itself (a trusted-root plus minimum-version check for a module command, or a SHA-256
      re-verification for a legacy script). Do not add a parameter here that lets the caller
      name what runs; that would make this a local privilege-escalation tool.

  .PARAMETER InstallerId
      Registered installer id in the broker config. 'install-atap-module-allusers' is the only
      one registered by default.

  .PARAMETER Parameters
      Hashtable of parameters to pass to the installer. The broker allowlists these by name
      and value pattern and rejects anything else. For 'install-atap-module-allusers' all of
      ModuleName, RequiredVersion, Repository, FeedUrl and ExpectedSha256 are REQUIRED; the
      broker rejects a request missing any of them.

  .PARAMETER BrokerRoot
      Broker root folder. Must match the broker's -BrokerRoot.

  .PARAMETER TimeoutSeconds
      How long to wait for a result before returning status 'timeout'.

  .PARAMETER PollMilliseconds
      Result-polling interval.

  .PARAMETER BrokerTaskPath
      Task Scheduler folder holding the broker task. Must match the registration.

  .PARAMETER BrokerTaskName
      Broker task name started on demand once the request is staged.

  .PARAMETER SkipBrokerStart
      Stage the request without starting the broker task. For tests. There is no repeating
      timer, so a skipped start means the request waits until the next BootTrigger.

  .OUTPUTS
      PSCustomObject with requestId, status, exitCode, error, transcriptPath.

  .EXAMPLE
      $r = Request-ElevatedInstall -InstallerId 'install-atap-module-allusers' -Parameters @{
          ModuleName      = 'ATAP.Utilities.BuildTooling.PowerShell'
          RequiredVersion = '0.1.71'
          Repository      = 'powershellget-stable'
          FeedUrl         = 'http://localhost:8624/nuget/powershellget-stable'
          ExpectedSha256  = '2B05F143CE2818CB1910F261ACC7990A1DF4D7BEF7ADE4A329551EC7B708147B'
      }
      if ($r.status -ne 'succeeded') { throw "Elevated install failed: $($r.error). Transcript: $($r.transcriptPath)" }

  .NOTES
      Task 13.76.g. Companions: Resources\ElevationBroker\Invoke-ElevationBrokerRequest.ps1
      (broker), Resources\ElevationBroker\ATAP-ElevatedInstallBroker.xml (scheduled task),
      Register-ElevationBrokerTask, Grant-ElevationBrokerStartRights.
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-z0-9][a-z0-9-]{2,63}$')]
    [string] $InstallerId,

    [Parameter(Mandatory = $false)]
    [hashtable] $Parameters = @{},

    [Parameter(Mandatory = $false)]
    [string] $BrokerRoot = 'C:\ProgramData\ATAP\ElevationBroker',

    [ValidateRange(10, 3600)]
    [int] $TimeoutSeconds = 600,

    [ValidateRange(100, 10000)]
    [int] $PollMilliseconds = 1000,

    [Parameter(Mandatory = $false)]
    # \ATAP-Broker, not \ATAP. The broker task was moved out of \ATAP on 2026-08-11 so that
    # granting the broker service account folder-level create/update on \ATAP -- which
    # ITaskFolder.RegisterTaskDefinition requires to manage the parity tasks -- cannot also let
    # it rewrite its own task definition. Keeping the broker in a folder it has no rights on is
    # what makes that grant safe.
    [string] $BrokerTaskPath = '\ATAP-Broker\',

    [Parameter(Mandatory = $false)]
    [string] $BrokerTaskName = 'ATAP-ElevatedInstallBroker',

    [switch] $SkipBrokerStart
  )

  begin {
    $fn = 'Request-ElevatedInstall'
    $mn = 'ATAP.Utilities.BuildTooling.ProGet.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
  }

  process {
    $requestsDir = Join-Path $BrokerRoot 'requests'
    $resultsDir = Join-Path $BrokerRoot 'results'

    foreach ($dir in $requestsDir, $resultsDir) {
      if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
        throw "Elevation broker folder '$dir' does not exist. The broker is not provisioned on this machine; run Register-ElevationBrokerTask (elevated) or fall back to a single documented elevation attempt with transcript capture, then hand off to the user."
      }
    }

    # A time-ordered id keeps the requests folder readable and makes the transcript easy to
    # correlate; the GUID tail keeps two agents in the same second from colliding.
    $requestId = '{0}-{1}' -f (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss'), ([guid]::NewGuid().ToString('N').Substring(0, 8))

    $request = [PSCustomObject]@{
      requestId     = $requestId
      installerId   = $InstallerId
      parameters    = $Parameters
      requestedBy   = [Security.Principal.WindowsIdentity]::GetCurrent().Name
      requestedUtc  = (Get-Date).ToUniversalTime().ToString('o')
      clientVersion = '1.1.0'
    }

    $requestPath = Join-Path $requestsDir "$requestId.json"
    $resultPath = Join-Path $resultsDir "$requestId.json"

    if (-not $PSCmdlet.ShouldProcess($requestPath, "submit elevated install request for '$InstallerId'")) {
      return [PSCustomObject]@{
        requestId      = $requestId
        status         = 'skipped'
        exitCode       = $null
        error          = $null
        transcriptPath = $null
      }
    }

    # Stage then rename: the broker must never see a partially written request file.
    $stagePath = "$requestPath.tmp"
    $request | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $stagePath -Encoding UTF8
    Move-Item -LiteralPath $stagePath -Destination $requestPath -Force

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Submitted elevation request '$requestId' for installer '$InstallerId'."

    # ── Start the broker on demand: the request IS the event ─────────────────────
    # Until 2026-07-28 the broker was drained by a one-minute repeating timer, which cost a
    # full profiled pwsh start every minute (~4,644 fires for 4 real requests) and still made
    # a caller wait up to 60s. Starting the task here removes both the waste and the latency.
    #
    # This is NOT the folder watcher the original design rejected: no ETW/WMI subscription is
    # created, and the task's Action is fixed in its registration, so start rights let a caller
    # ask the broker to drain, never influence what the broker runs.
    #
    # Started through the Schedule.Service COM API, NOT Start-ScheduledTask. The ScheduledTasks
    # module is a CDXML module that ships with Windows PowerShell; on utat01 it is not present
    # at all under PowerShell 7 (Get-Module -ListAvailable returns nothing, and
    # -SkipEditionCheck does not help), so Start-ScheduledTask would fail with
    # CommandNotFoundException on the very machine this runs on. COM needs no module.
    #
    # A request arriving while an instance is running is handled because the task is registered
    # with MultipleInstancesPolicy=Queue.
    if (-not $SkipBrokerStart) {
      try {
        $taskFolder = $BrokerTaskPath.TrimEnd('\')
        if (-not $taskFolder) { $taskFolder = '\' }
        $scheduleService = New-Object -ComObject 'Schedule.Service'
        $scheduleService.Connect()
        $brokerTask = $scheduleService.GetFolder($taskFolder).GetTask($BrokerTaskName)
        # Run(): requires TASK_EXECUTE, which Grant-ElevationBrokerStartRights confers.
        # $null = no extra invocation parameters; the Action is fixed in the registration.
        [void]$brokerTask.Run($null)
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Started broker task '$taskFolder\$BrokerTaskName' for request '$requestId'."
      }
      catch {
        # Deliberately NOT a retry and NOT a silent fall-through to the wait loop. With no
        # timer left, an unstartable broker means this request will not be serviced until the
        # next boot, so waiting out TimeoutSeconds would only delay a knowable failure.
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Could not start broker task: $($_.Exception.Message)"
        return [PSCustomObject]@{
          requestId      = $requestId
          installerId    = $InstallerId
          status         = 'broker-unreachable'
          exitCode       = $null
          error          = ("Request staged at '{0}' but the broker task '{1}\{2}' could not be started: {3} " +
            "Grant this account start rights with Grant-ElevationBrokerStartRights (elevated), " +
            "confirm the task is registered and Enabled, then re-run. The staged request remains " +
            "and will be drained at next boot.") -f $requestPath, $taskFolder, $BrokerTaskName, $_.Exception.Message
          transcriptPath = (Join-Path $BrokerRoot "transcripts\$requestId.log")
        }
      }
    }

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
      if (Test-Path -LiteralPath $resultPath -PathType Leaf) {
        try {
          return (Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json)
        }
        catch {
          # The broker renames the result into place, so this should not happen; if it does,
          # treat it as not-yet-readable rather than as a failure.
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Result for '$requestId' not yet readable: $($_.Exception.Message)"
        }
      }
      Start-Sleep -Milliseconds $PollMilliseconds
    }

    # Deliberately NOT an exception and deliberately NOT a retry: return an inspectable record
    # so the caller reports it to the user instead of looping (the exact misstep this whole
    # task exists to eliminate).
    return [PSCustomObject]@{
      requestId      = $requestId
      installerId    = $InstallerId
      status         = 'timeout'
      exitCode       = $null
      error          = "No result after $TimeoutSeconds seconds. The broker task started successfully, so the request reached an elevated instance but produced no result: inspect the transcript below, and confirm the task runs as the broker service account. Request file: $requestPath"
      transcriptPath = (Join-Path $BrokerRoot "transcripts\$requestId.log")
    }
  }

  end {
  }
}
