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
    Registration passes resolved XML directly to the existing Task Scheduler COM API.
    The exact TaskPath folder must already exist under separately approved bootstrap ACLs.
    Task preimages are retained; failures never trigger an automatic restore.

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

    $isAdmin = Test-ElevationBrokerAdministrator
    if (-not $isAdmin) {
      throw "Must run ELEVATED. Registering a task that runs as $ServiceAccount with HighestAvailable requires administrator rights."
    }
  }

  process {
    if ([string]::IsNullOrWhiteSpace($TaskName) -or $TaskName -cne $TaskName.Trim() -or
      $TaskName -in @('.', '..') -or $TaskName.Contains('\') -or $TaskName.Contains('/') -or
      [string]::IsNullOrWhiteSpace($TaskPath) -or -not $TaskPath.StartsWith('\') -or
      $TaskPath -match '(^|\\)\.{1,2}(\\|$)') {
      throw 'BrokerTaskTargetInvalid'
    }
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
      $resolvedSid = Resolve-ElevationBrokerAccountSid -ServiceAccount $ServiceAccount
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

    # Validate only nonsecret XML before the registration approval boundary.
    $resolvedTask = [xml]::new()
    $resolvedTask.XmlResolver = $null
    try { $resolvedTask.LoadXml($xml) }
    catch { throw 'BrokerTaskTemplateInvalid' }
    if (-not $resolvedTask.Task -or
      [string]$resolvedTask.Task.Principals.Principal.UserId -cne $ServiceAccount -or
      [string]$resolvedTask.Task.Principals.Principal.LogonType -cne 'Password') {
      throw 'BrokerTaskTemplatePrincipalInvalid'
    }
    $desiredEnabled = $false
    if (-not [bool]::TryParse([string]$resolvedTask.Task.Settings.Enabled, [ref]$desiredEnabled)) {
      throw 'BrokerTaskTemplateEnabledInvalid'
    }

    $registered = $false
    $backupPath = $null
    $statePath = $null
    # Payload has its own earlier ShouldProcess. This is not a whole-function transaction.
    if ($PSCmdlet.ShouldProcess($fullTaskName, 'Register scheduled task')) {
      $password = $null
      $service = $null
      $folder = $null
      $existing = $null
      $current = $null
      $verifiedTask = $null
      $stage = 'SchedulerConnect'
      $registrationAttempted = $false
      try {
        $service = New-Object -ComObject 'Schedule.Service'
        $service.Connect()
        $stage = 'TaskFolder'
        # Folder provisioning/ACL policy is a separate bootstrap effect; never guess or
        # enumerate another location when the exact admitted folder is unavailable.
        $folder = $service.GetFolder($TaskPath.TrimEnd('\'))
        if ($null -eq $folder) { throw 'BrokerTaskFolderUnavailable' }
        $stage = 'TaskLookup'
        $readExactTask = {
          try {
            $task = $folder.GetTask($TaskName)
            if ($null -eq $task) { throw 'BrokerTaskLookupUnresolved' }
            return $task
          }
          catch {
            $notFound = $false
            $lookupError = $_.Exception
            for ($depth = 0; $null -ne $lookupError -and $depth -lt 8; $depth++) {
              if ($lookupError -is [IO.FileNotFoundException] -or
                $lookupError.HResult -eq -2147024894) { $notFound = $true; break }
              $lookupError = $lookupError.InnerException
            }
            if (-not $notFound) { throw }
            return $null
          }
        }
        $existing = & $readExactTask

        $existingXml = $null
        $existingSddl = $null
        $existingEnabled = $null
        if ($null -ne $existing) {
          $stage = 'TaskPreimage'
          $existingXml = [string]$existing.Xml
          $existingEnabled = [bool]$existing.Enabled
          $existingSddl = [string]$existing.GetSecurityDescriptor(7)
          if ([string]::IsNullOrWhiteSpace($existingXml) -or [string]::IsNullOrWhiteSpace($existingSddl)) {
            throw 'BrokerTaskPreimageUnavailable'
          }
          $previousTask = [xml]::new()
          $previousTask.XmlResolver = $null
          $previousTask.LoadXml($existingXml)
          if ([string]$previousTask.Task.Principals.Principal.UserId -cne $ServiceAccount -or
            [string]$previousTask.Task.Principals.Principal.LogonType -cne 'Password') {
            throw 'BrokerTaskExistingPrincipalMismatch'
          }
          # The enabled template must never silently enable an existing disabled task.
          $desiredEnabled = $existingEnabled
          $resolvedTask.Task.Settings.Enabled = $desiredEnabled.ToString().ToLowerInvariant()

          $backupDir = Join-Path $BrokerRoot '_generated\task-backups'
          if (-not (Test-Path -LiteralPath $backupDir)) {
            $null = New-Item -ItemType Directory -Path $backupDir -ErrorAction Stop
          }
          $backupName = '{0}-{1}-{2}' -f $TaskName, (Get-Date -Format 'yyyyMMdd-HHmmss'), ([guid]::NewGuid().ToString('N'))
          $backupPath = Join-Path $backupDir ($backupName + '.xml')
          $statePath = Join-Path $backupDir ($backupName + '.state.json')
          # Keep the existing task-export serialization contract. The JSON preimage
          # additionally preserves the exact scheduler XML string, SDDL and enabled state.
          $backupXml = $existingXml.Replace(([string][char]13 + [char]10), [string][char]10).Replace([string][char]13, [string][char]10)
          if (-not $backupXml.EndsWith([string][char]10)) { $backupXml += [char]10 }
          $preimage = [ordered]@{
            TaskName = $fullTaskName; Xml = $existingXml; Sddl = $existingSddl
            Enabled = $existingEnabled; ServiceAccount = $ServiceAccount
          } | ConvertTo-Json -Depth 6
          foreach ($entry in @(
              @{ Path = $backupPath; Bytes = [Text.UnicodeEncoding]::new($false, $true).GetBytes($backupXml); Preamble = [Text.UnicodeEncoding]::new($false, $true).GetPreamble() },
              @{ Path = $statePath; Bytes = [Text.Encoding]::UTF8.GetBytes($preimage); Preamble = [byte[]]@() })) {
            $stream = [IO.File]::Open($entry.Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
            try {
              if ($entry.Preamble.Length) { $stream.Write($entry.Preamble) }
              $stream.Write($entry.Bytes)
              $stream.Flush($true)
            }
            finally { $stream.Dispose() }
          }
          if ([IO.File]::ReadAllText($statePath) -cne $preimage) { throw 'BrokerTaskPreimageReadback' }
          $stage = 'TaskPreimageCurrent'
          $current = $folder.GetTask($TaskName)
          if ([string]$current.Xml -cne $existingXml -or
            [bool]$current.Enabled -ne $existingEnabled -or
            [string]$current.GetSecurityDescriptor(7) -cne $existingSddl) {
            throw 'BrokerTaskPreimageChanged'
          }
        }

        else {
          $stage = 'TaskAbsenceCurrent'
          $current = & $readExactTask
          if ($null -ne $current) { throw 'BrokerTaskAppearedWithoutPreimage' }
        }

        # Select an operation that cannot silently switch from protected update to
        # create, or from observed absence to overwriting an unpreimaged task.
        $registrationFlags = if ($null -eq $existing) { 2 } else { 4 }
        $stage = 'Credential'
        if (-not (Get-Command Get-SecretATAP -ErrorAction SilentlyContinue)) {
          throw 'BrokerTaskSecretGetterUnavailable'
        }
        $password = Get-SecretATAP -SecretName $SecretName
        if ($password -isnot [string] -or [string]::IsNullOrWhiteSpace($password)) {
          throw 'BrokerTaskCredentialUnavailable'
        }

        $stage = 'TaskStateCurrent'
        $current = & $readExactTask
        if ($registrationFlags -eq 2) {
          if ($null -ne $current) { throw 'BrokerTaskAppearedWithoutPreimage' }
        }
        elseif ($null -eq $current -or [string]$current.Xml -cne $existingXml -or
          [bool]$current.Enabled -ne $existingEnabled -or
          [string]$current.GetSecurityDescriptor(7) -cne $existingSddl) {
          throw 'BrokerTaskPreimageChanged'
        }

        $stage = 'Register'
        $registrationAttempted = $true
        $TASK_LOGON_PASSWORD = 1
        # No native argv, temporary credential XML, delete-first or automatic restore.
        # New-task enabled/BootTrigger policy requires separate live admission; this
        # transport repair neither implements disabled-first nor authorizes a task start.
        $null = $folder.RegisterTask(
          $TaskName, $resolvedTask.OuterXml, $registrationFlags,
          $ServiceAccount, $password, $TASK_LOGON_PASSWORD, $existingSddl)
        $stage = 'TaskReadback'
        $verifiedTask = $folder.GetTask($TaskName)
        if ($null -eq $verifiedTask -or [bool]$verifiedTask.Enabled -ne $desiredEnabled) {
          throw 'BrokerTaskReadbackState'
        }
        $readback = [xml]::new()
        $readback.XmlResolver = $null
        $readback.LoadXml([string]$verifiedTask.Xml)
        if ([string]$readback.Task.Principals.Principal.UserId -cne $ServiceAccount -or
          [string]$readback.Task.Principals.Principal.LogonType -cne 'Password' -or
          ($null -ne $existingSddl -and [string]$verifiedTask.GetSecurityDescriptor(7) -cne $existingSddl)) {
          throw 'BrokerTaskReadbackIdentity'
        }
        $registered = $true
      }
      catch {
        # Provider/COM errors may contain credentials. Do not retain their message,
        # InvocationInfo or inner exception in the public error or PSFramework logs.
        $safeHresult = '0x{0:X8}' -f $_.Exception.HResult
        $safeMessage = "BrokerTaskRegistrationFailed Stage=$stage HResult=$safeHresult PartialStatePossible=$registrationAttempted BackupPath=$backupPath StatePath=$statePath. Preserve evidence; no automatic retry or restore."
        $safeError = [Management.Automation.ErrorRecord]::new(
          [InvalidOperationException]::new($safeMessage), 'BrokerTaskRegistrationFailed',
          [Management.Automation.ErrorCategory]::InvalidOperation, $null)
        $PSCmdlet.ThrowTerminatingError($safeError)
      }
      finally {
        $password = $null
        foreach ($reference in @($verifiedTask, $current, $existing, $folder, $service)) {
          if ($null -ne $reference -and [Runtime.InteropServices.Marshal]::IsComObject($reference)) {
            try { $null = [Runtime.InteropServices.Marshal]::ReleaseComObject($reference) } catch {}
          }
        }
      }
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message (
      "Registration alone does not make on-demand start work. Run: " +
      "Grant-ElevationBrokerStartRights -Principal '$RequesterPrincipal'")

    [PSCustomObject]@{
      TaskName           = $fullTaskName
      Registered         = $registered
      ServiceAccount     = $ServiceAccount
      SecretName         = $SecretName
      BrokerRoot         = $BrokerRoot
      BrokerScript       = $brokerScript
      BackupPath         = $backupPath
      StatePath          = $statePath
      RequesterPrincipal = $RequesterPrincipal
      NextStep           = "Grant-ElevationBrokerStartRights -Principal '$RequesterPrincipal'"
    }
  }

  end {
  }
}

function Test-ElevationBrokerAdministrator {
  ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
  ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Resolve-ElevationBrokerAccountSid {
  param([string]$ServiceAccount)

  ([System.Security.Principal.NTAccount]$ServiceAccount).Translate(
    [System.Security.Principal.SecurityIdentifier]).Value
}
