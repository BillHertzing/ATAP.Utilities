function Register-ElevationBrokerTask {
  <#
  .SYNOPSIS
    Provisions the elevation broker on a machine: deploys its payload, creates the folder
    structure with a safe ACL, and registers the ATAP-ElevatedInstallBroker scheduled task.

  .DESCRIPTION
    Task 13.76.g authored ATAP-ElevatedInstallBroker.xml but left registration as a HITL step.
    On 2026-07-27 the task was found MISSING on utat01 even though Task 13.76.f had recorded it
    registered and Ready on 2026-07-25, so registration needs to be repeatable, not a one-off
    console session. This is that repeatable step, and the procedure for a NEW COMPUTER.

    BOOTSTRAP NOTE. The broker is what performs AllUsers module installs, so on a new computer
    it must be provisioned BEFORE the module-install machinery works. Run this function from a
    GIT CLONE of ATAP.Utilities (dot-source the file, or import the module from source) rather
    than from an installed copy of the module. Everything it needs ships beside it under
    Resources\ElevationBroker.

    MUST RUN ELEVATED. Registering a task that runs as another account with HighestAvailable
    requires administrator rights.

    The service account password is read from Bitwarden through Get-SecretATAP and is never
    written to disk, never echoed, and never placed on a command line that appears in the
    process list.

  .PARAMETER TemplatePath
    ATAP-ElevatedInstallBroker.xml. Defaults to the copy under the module's
    Resources\ElevationBroker.

  .PARAMETER BrokerRoot
    Broker root. Default C:\ProgramData\ATAP\ElevationBroker.

  .PARAMETER ServiceAccount
    Account the task runs as. Default .\SvcAnsibleAdmin (local).

  .PARAMETER SecretName
    Bitwarden SecretName holding that account's password. Default SvcAnsibleAdmin.<host>.

  .PARAMETER RequesterPrincipal
    Account or group allowed to submit requests (write to requests\) and, via
    Grant-ElevationBrokerStartRights, to start the task. Defaults to the invoking user.

  .PARAMETER SkipPayloadDeployment
    Do not copy the broker script or config template into BrokerRoot. Use when the payload is
    managed separately. An existing config.json is NEVER overwritten unless -ForcePayload.

  .PARAMETER ForcePayload
    Overwrite an existing config.json with the template. The deployed config is the broker's
    TRUST ANCHOR, so this is deliberately opt-in.

  .EXAMPLE
    # New computer, from an ELEVATED pwsh in a clone of ATAP.Utilities:
    . .\src\ATAP.Utilities.BuildTooling.ProGet.PowerShell\public\Register-ElevationBrokerTask.ps1
    Register-ElevationBrokerTask -Verbose

  .NOTES
    Encoding gotcha: the template declares encoding="UTF-16". schtasks /XML and
    Register-ScheduledTask both fail or mis-parse when the declared encoding does not match the
    file's actual bytes, so the resolved file is written as Unicode (UTF-16LE with BOM).

    After this returns, run Grant-ElevationBrokerStartRights so the requester can start the
    task on demand. Registration alone is not sufficient: the task has no repeating timer.
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $false)]
    [string]$TemplatePath,

    [Parameter(Mandatory = $false)]
    [string]$BrokerRoot = 'C:\ProgramData\ATAP\ElevationBroker',

    [Parameter(Mandatory = $false)]
    [string]$ServiceAccount = '.\SvcAnsibleAdmin',

    [Parameter(Mandatory = $false)]
    [string]$SecretName,

    [Parameter(Mandatory = $false)]
    [string]$RequesterPrincipal = [Security.Principal.WindowsIdentity]::GetCurrent().Name,

    [Parameter(Mandatory = $false)]
    # \ATAP-Broker, not \ATAP: the broker must not live in a folder it holds rights over.
    # See Request-ElevatedInstall's -BrokerTaskPath note (2026-08-11, Task 14.72).
    [string]$TaskPath = '\ATAP-Broker\',

    [Parameter(Mandatory = $false)]
    [string]$TaskName = 'ATAP-ElevatedInstallBroker',

    [switch]$SkipPayloadDeployment,

    [switch]$ForcePayload
  )

  begin {
    $fn = 'Register-ElevationBrokerTask'
    $mn = 'ATAP.Utilities.BuildTooling.ProGet.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    # Resources live one level up from public\. $PSScriptRoot resolves against THIS file,
    # so it works both from an installed module and from a git clone.
    $resourceRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'Resources\ElevationBroker'
    if (-not $TemplatePath) {
      $TemplatePath = Join-Path $resourceRoot 'ATAP-ElevatedInstallBroker.xml'
    }

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
      throw "Must run ELEVATED. Registering a task that runs as $ServiceAccount with HighestAvailable requires administrator rights."
    }
  }

  process {
    $fullTaskName = ($TaskPath.TrimEnd('\')) + '\' + $TaskName
    if (-not (Test-Path -LiteralPath $TemplatePath)) { throw "Template not found: $TemplatePath" }

    $accountLeaf = ($ServiceAccount -split '\\')[-1]
    if (-not (& net user $accountLeaf 2>$null)) {
      throw "Service account '$accountLeaf' does not exist. Provision it (Task 13.76.f) before registering."
    }

    # Task Scheduler XML <UserId> must be resolvable to a SID. A '.\Account' prefix is NOT: it
    # fails registration with "No mapping between account names and security IDs was done" at
    # the UserId line. Normalise to MACHINE\Account, and verify the SID resolves BEFORE
    # touching the existing task, so a bad account name can never cost a working registration.
    if ($ServiceAccount -match '^\.\\') {
      $ServiceAccount = "$env:COMPUTERNAME\$accountLeaf"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Normalised ServiceAccount to '$ServiceAccount' for XML UserId SID resolution."
    }
    try {
      $resolvedSid = ([System.Security.Principal.NTAccount]$ServiceAccount).Translate(
        [System.Security.Principal.SecurityIdentifier]).Value
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "ServiceAccount '$ServiceAccount' resolves to SID $resolvedSid."
    }
    catch {
      throw "ServiceAccount '$ServiceAccount' does not resolve to a SID: $($_.Exception.Message). Fix the account name before registering; the existing task has NOT been touched."
    }

    if (-not $SecretName) { $SecretName = "$accountLeaf.$($env:COMPUTERNAME.ToLower())" }

    $brokerScript = Join-Path $BrokerRoot 'bin\Invoke-ElevationBrokerRequest.ps1'
    $brokerConfig = Join-Path $BrokerRoot 'config.json'

    # ── Deploy the payload (new-computer path) ───────────────────────────────
    if (-not $SkipPayloadDeployment) {
      if ($PSCmdlet.ShouldProcess($BrokerRoot, 'deploy broker payload and create folder structure')) {
        foreach ($sub in 'bin', 'requests', 'results', 'transcripts', 'work') {
          $p = Join-Path $BrokerRoot $sub
          if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
        }

        foreach ($payload in 'Invoke-ElevationBrokerRequest.ps1', 'Install-ATAPModule-AllUsers.ps1') {
          $srcFile = Join-Path $resourceRoot $payload
          if (Test-Path -LiteralPath $srcFile) {
            Copy-Item -LiteralPath $srcFile -Destination (Join-Path $BrokerRoot 'bin') -Force
          }
        }

        # The config is the TRUST ANCHOR. Never clobber a machine's tuned copy by accident.
        $templateConfig = Join-Path $resourceRoot 'ElevationBroker-config.template.json'
        if (Test-Path -LiteralPath $templateConfig) {
          if ((-not (Test-Path -LiteralPath $brokerConfig)) -or $ForcePayload) {
            Copy-Item -LiteralPath $templateConfig -Destination $brokerConfig -Force
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Deployed broker config to '$brokerConfig'."
          }
          else {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Existing config.json left untouched (pass -ForcePayload to replace it)."
          }
        }

        # ── ACL the requests folder ────────────────────────────────────────
        # The broker REFUSES TO RUN when Everyone/Authenticated Users/Users can write here,
        # because that would let any local account reach an administrator context. Set an
        # explicit, non-inherited ACL so a fresh machine satisfies that check.
        $requestsDir = Join-Path $BrokerRoot 'requests'
        $acl = Get-Acl -LiteralPath $requestsDir
        $acl.SetAccessRuleProtection($true, $false)   # disable inheritance, drop inherited ACEs
        foreach ($rule in @($acl.Access)) { [void]$acl.RemoveAccessRule($rule) }
        foreach ($grant in @(
            @{ Id = 'NT AUTHORITY\SYSTEM'; Rights = 'FullControl' },
            @{ Id = 'BUILTIN\Administrators'; Rights = 'FullControl' },
            @{ Id = $ServiceAccount; Rights = 'Modify' },
            @{ Id = $RequesterPrincipal; Rights = 'Modify' })) {
          try {
            $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
                  $grant.Id, $grant.Rights, 'ContainerInherit,ObjectInherit', 'None', 'Allow')))
          }
          catch {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Could not add ACE for '$($grant.Id)': $($_.Exception.Message)"
          }
        }
        Set-Acl -LiteralPath $requestsDir -AclObject $acl
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Applied restrictive ACL to '$requestsDir'."
      }
    }

    foreach ($p in @($BrokerRoot, $brokerScript, $brokerConfig)) {
      if (-not (Test-Path -LiteralPath $p)) {
        throw "Broker prerequisite missing: '$p'. Deploy the broker payload before registering (omit -SkipPayloadDeployment)."
      }
    }

    # ── Resolve the template ─────────────────────────────────────────────────
    $xml = Get-Content -LiteralPath $TemplatePath -Raw
    foreach ($pair in @(
        @{ Token = '__BROKER_ROOT__'; Value = $BrokerRoot },
        @{ Token = '__BROKER_SCRIPT__'; Value = $brokerScript },
        @{ Token = '__SERVICE_ACCOUNT__'; Value = $ServiceAccount })) {
      if ($xml -notmatch [regex]::Escape($pair.Token)) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Token $($pair.Token) not present in template (already resolved?)"
      }
      $xml = $xml.Replace($pair.Token, $pair.Value)
    }
    if ($xml -match '__[A-Z_]+__') {
      throw "Unresolved placeholder remains in the template: $($Matches[0])"
    }

    # ── Credential (never printed, never persisted) ──────────────────────────
    if (-not (Get-Command Get-SecretATAP -ErrorAction SilentlyContinue)) {
      throw 'Get-SecretATAP is unavailable. Start an elevated shell that loads the PowerShell profile.'
    }
    $password = Get-SecretATAP -SecretName $SecretName
    if ([string]::IsNullOrWhiteSpace($password)) {
      throw "Get-SecretATAP returned nothing for '$SecretName'."
    }

    # ── Register ─────────────────────────────────────────────────────────────
    if ($PSCmdlet.ShouldProcess($fullTaskName, 'Register scheduled task')) {
      # EXPORT BEFORE DELETE. Learned the hard way on 2026-07-27: an UNELEVATED
      # `schtasks /query` reports "cannot find the path specified" for a task that actually
      # exists, so "the task is missing" is not a safe conclusion from an unelevated shell,
      # and an earlier version of this code deleted a live registration and then failed to
      # recreate it. Never destroy a registration without a restorable copy on disk first.
      $backupPath = $null
      & schtasks /query /tn $fullTaskName 2>$null | Out-Null
      if ($LASTEXITCODE -eq 0) {
        $backupDir = Join-Path $BrokerRoot '_generated\task-backups'
        if (-not (Test-Path -LiteralPath $backupDir)) { New-Item -ItemType Directory -Path $backupDir -Force | Out-Null }
        $backupPath = Join-Path $backupDir ("{0}-{1}.xml" -f $TaskName, (Get-Date -Format 'yyyyMMdd-HHmmss'))

        $exported = & schtasks /query /tn $fullTaskName /xml ONE 2>$null
        if ($LASTEXITCODE -eq 0 -and $exported) {
          [System.IO.File]::WriteAllText($backupPath, ($exported -join "`r`n"),
            [System.Text.UnicodeEncoding]::new($false, $true))
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Existing task exported to '$backupPath' before deletion."
        }
        else {
          throw "Existing task '$fullTaskName' could not be exported for backup. Refusing to delete it. Export it manually (schtasks /query /tn '$fullTaskName' /xml ONE) before re-running."
        }

        & schtasks /delete /tn $fullTaskName /f | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Failed to delete existing task '$fullTaskName' (exit $LASTEXITCODE); nothing was changed." }
      }

      # UTF-16LE with BOM, matching the template's own encoding declaration.
      $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("ATAP-broker-{0}.xml" -f ([Guid]::NewGuid().ToString('N')))
      try {
        [System.IO.File]::WriteAllText($tmp, $xml, [System.Text.UnicodeEncoding]::new($false, $true))
        & schtasks /create /tn $fullTaskName /xml $tmp /ru $ServiceAccount /rp $password | Out-Null
        if ($LASTEXITCODE -ne 0) {
          $msg = "schtasks /create failed with exit code $LASTEXITCODE."
          if ($backupPath) {
            & schtasks /create /tn $fullTaskName /xml $backupPath /ru $ServiceAccount /rp $password 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) { $msg += " The PREVIOUS registration was restored from '$backupPath'." }
            else { $msg += " RESTORE ALSO FAILED - the task is now absent. Re-register manually from '$backupPath'." }
          }
          throw $msg
        }
      }
      finally {
        $password = $null
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
      }
    }

    # ── Verify ───────────────────────────────────────────────────────────────
    # 'Repeat: Every' is deliberately no longer expected: as of 2026-07-28 the task has NO
    # repeating time trigger. It is started on demand by Request-ElevatedInstall, with
    # BootTrigger as the only unattended drain. A non-empty repeat interval here now means a
    # STALE registration was resurrected from a backup XML.
    & schtasks /query /tn $fullTaskName /fo LIST /v 2>&1 |
      Select-String 'TaskName|Status|Scheduled Task State|Run As User|Last Result|Repeat: Every'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message (
      "Registration alone does not make on-demand start work. Run: " +
      "Grant-ElevationBrokerStartRights -Principal '$RequesterPrincipal'")

    [PSCustomObject]@{
      TaskName           = $fullTaskName
      Registered         = ($LASTEXITCODE -eq 0)
      ServiceAccount     = $ServiceAccount
      SecretName         = $SecretName
      BrokerRoot         = $BrokerRoot
      BrokerScript       = $brokerScript
      RequesterPrincipal = $RequesterPrincipal
      NextStep           = "Grant-ElevationBrokerStartRights -Principal '$RequesterPrincipal'"
    }
  }

  end {
  }
}
