function Grant-ElevationBrokerStartRights {
  <#
  .SYNOPSIS
    Grants a build/developer principal the rights needed to START the elevation broker task
    on demand, without granting any ability to change what the task runs.

  .DESCRIPTION
    Companion to the 2026-07-28 trigger change. The broker no longer drains on a one-minute
    timer; Request-ElevatedInstall starts the task the moment it stages a request. An
    unelevated caller cannot start a task that runs as another account with HighestAvailable
    unless it has Read+Execute on that task object, so this grants exactly that.

    WHAT THIS DOES NOT GRANT. Read+Execute on a task object permits enumerate/read/run. It
    does NOT permit modifying the task. The Action (pwsh.exe + the broker script + -Once)
    lives in the registration, which remains writable only by administrators. So a grantee can
    ask the broker to drain the requests folder and nothing else: it cannot change the
    command, the arguments, or the account the task runs as.

    WHY THIS IS NOT AN ESCALATION. The grantee can already write into the requests folder;
    that is the broker's entire purpose, and the broker treats every request as untrusted
    (installer ids only, admin-owned id-to-target config, per-installer parameter allowlists,
    trusted-root or SHA-256 integrity proof, atomic claim). Being able to trigger the drain
    sooner does not widen that surface, it only removes the wait. Do not extend this grant to
    Everyone, Authenticated Users, or Users: the broker itself refuses to run when those
    identities can write to the requests folder, and the same reasoning applies here.

    Rights are granted by editing the task's security descriptor through the Schedule.Service
    COM API. The existing DACL is READ FIRST and the new ACE is APPENDED; no existing ACE is
    removed. The prior SDDL is written to disk before any change, so the grant is reversible.

  .PARAMETER Principal
    Account or group to grant start rights to. Defaults to the invoking user. Prefer a group
    once more than one developer account needs this.

  .PARAMETER TaskPath
    Task Scheduler folder. Default \ATAP\.

  .PARAMETER TaskName
    Task name. Default ATAP-ElevatedInstallBroker.

  .PARAMETER BackupDir
    Where the pre-change SDDL is written. Defaults to the broker's
    _generated\task-acl-backups (SC-0033: generated output belongs under _generated).

  .PARAMETER Revoke
    Remove this principal's ACE instead of adding it.

  .OUTPUTS
    PSCustomObject with Task, Principal, Sid, Action, Changed, BackupPath, NewSddl.

  .EXAMPLE
    # From an ELEVATED pwsh, grant the current developer account:
    Grant-ElevationBrokerStartRights -Verbose

  .EXAMPLE
    Grant-ElevationBrokerStartRights -Principal 'UTAT01\whertzing' -WhatIf

  .NOTES
    MUST RUN ELEVATED. Reading or writing a task security descriptor for a task that runs as
    another account requires administrator rights.
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $false)]
    [string] $Principal = [Security.Principal.WindowsIdentity]::GetCurrent().Name,

    [Parameter(Mandatory = $false)]
    [string] $TaskPath = '\ATAP\',

    [Parameter(Mandatory = $false)]
    [string] $TaskName = 'ATAP-ElevatedInstallBroker',

    [Parameter(Mandatory = $false)]
    [string] $BackupDir = 'C:\ProgramData\ATAP\ElevationBroker\_generated\task-acl-backups',

    [switch] $Revoke
  )

  begin {
    $fn = 'Grant-ElevationBrokerStartRights'
    $mn = 'ATAP.Utilities.BuildTooling.ProGet.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    # TASK_READ | TASK_EXECUTE, written as generic rights. GR = GENERIC_READ (enumerate/query),
    # GX = GENERIC_EXECUTE (run). No GW: the grantee cannot modify the task.
    # Function-local by design: module .ps1 files must not define module-scope state.
    $startRightsMask = 'GRGX'

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
      throw 'Must run ELEVATED. Reading/writing the security descriptor of a task that runs as another account requires administrator rights.'
    }
  }

  process {
    # Refuse the identities the broker itself refuses. Granting these would let any local
    # account trigger an administrator context, which is what the broker's ACL check prevents.
    $forbidden = @('Everyone', 'Authenticated Users', 'Users', 'BUILTIN\Users', 'NT AUTHORITY\Authenticated Users', 'INTERACTIVE')
    $principalLeaf = ($Principal -split '\\')[-1]
    if ($forbidden -contains $Principal -or $forbidden -contains $principalLeaf) {
      throw "Refusing to grant broker start rights to '$Principal'. The broker refuses to run when such an identity can write to the requests folder; granting it start rights is the same mistake."
    }

    try {
      $sid = ([System.Security.Principal.NTAccount]$Principal).Translate(
        [System.Security.Principal.SecurityIdentifier]).Value
    }
    catch {
      throw "Principal '$Principal' does not resolve to a SID: $($_.Exception.Message)"
    }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Principal '$Principal' resolves to SID $sid."

    # ── Connect and read the CURRENT descriptor ──────────────────────────────
    $svc = New-Object -ComObject 'Schedule.Service'
    $svc.Connect()

    $folderPath = $TaskPath.TrimEnd('\')
    if (-not $folderPath) { $folderPath = '\' }
    try { $folder = $svc.GetFolder($folderPath) }
    catch { throw "Task folder '$folderPath' not found: $($_.Exception.Message)" }

    try { $task = $folder.GetTask($TaskName) }
    catch { throw "Task '$folderPath\$TaskName' not found. Register it with Register-ElevationBrokerTask first." }

    # 0x4 = DACL_SECURITY_INFORMATION. Read before write, always.
    $currentSddl = $task.GetSecurityDescriptor(0x4)
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Current SDDL: $currentSddl"

    # ── Back the descriptor up BEFORE changing it ────────────────────────────
    if (-not $WhatIfPreference) {
      if (-not (Test-Path -LiteralPath $BackupDir)) {
        New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
      }
      $backupPath = Join-Path $BackupDir ("{0}-sddl-{1}.txt" -f $TaskName, (Get-Date -Format 'yyyyMMdd-HHmmss'))
      Set-Content -LiteralPath $backupPath -Value $currentSddl -Encoding utf8
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Previous SDDL saved to '$backupPath'."
    }
    else {
      $backupPath = '(WhatIf: no backup written)'
    }

    # ── Compute the new descriptor ───────────────────────────────────────────
    $ace = "(A;;$startRightsMask;;;$sid)"
    $existingMask = Get-BrokerTaskAceMask -Sddl $currentSddl -Sid $sid
    $alreadyPresent = Test-BrokerTaskStartRight -Mask $existingMask
    if ($existingMask) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Existing ACE for '$Principal' has mask '$existingMask' (grants start: $alreadyPresent)."
    }

    if ($Revoke) {
      if (-not $existingMask) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "No ACE for '$Principal'; nothing to revoke."
        return [PSCustomObject]@{ Task = "$folderPath\$TaskName"; Principal = $Principal; Sid = $sid; Action = 'revoke'; Changed = $false; BackupPath = $backupPath; NewSddl = $currentSddl }
      }
      # Remove by SID, not by the literal ACE we would have sent: the stored ACE carries the
      # canonicalised mask (e.g. 0x1200a9), so replacing '(A;;GRGX;;;<sid>)' removes nothing.
      $newSddl = [regex]::Replace($currentSddl, "\(A;[^;]*;[^;]+;;;$([regex]::Escape($sid))\)", '')
      $actionText = "revoke start rights (mask '$existingMask') from $Principal"
    }
    else {
      if ($alreadyPresent) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "'$Principal' already holds start rights; leaving the descriptor untouched."
        return [PSCustomObject]@{ Task = "$folderPath\$TaskName"; Principal = $Principal; Sid = $sid; Action = 'grant'; Changed = $false; BackupPath = $backupPath; NewSddl = $currentSddl }
      }
      # Append to the existing DACL rather than replacing it: never drop an ACE we did not add.
      if ($currentSddl -notmatch 'D:') {
        throw "Task descriptor has no DACL to extend; refusing to synthesise one. SDDL was: $currentSddl"
      }
      $newSddl = $currentSddl + $ace
      $actionText = "grant start rights ($startRightsMask) to $Principal"
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "New SDDL: $newSddl"

    # ── Apply ────────────────────────────────────────────────────────────────
    if ($PSCmdlet.ShouldProcess("$folderPath\$TaskName", $actionText)) {
      try {
        $task.SetSecurityDescriptor($newSddl, 0)
      }
      catch {
        throw "Failed to set the task security descriptor: $($_.Exception.Message). The task is unchanged; the previous SDDL is at '$backupPath'."
      }

      # Verify against the CANONICALISED descriptor, by SID and mask. Windows rewrites what we
      # sent, so an exact string match on the submitted ACE would be a false negative.
      $verifySddl = $task.GetSecurityDescriptor(0x4)
      $verifyMask = Get-BrokerTaskAceMask -Sddl $verifySddl -Sid $sid
      $verified = if ($Revoke) { -not $verifyMask } else { Test-BrokerTaskStartRight -Mask $verifyMask }
      if (-not $verified) {
        throw ("Descriptor write reported success but verification failed (stored mask for {0}: '{1}'). " +
          "Restore from '{2}' and investigate." -f $Principal, $verifyMask, $backupPath)
      }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Verified: stored mask for '$Principal' is '$verifyMask'."

      return [PSCustomObject]@{
        Task       = "$folderPath\$TaskName"
        Principal  = $Principal
        Sid        = $sid
        Action     = $(if ($Revoke) { 'revoke' } else { 'grant' })
        Changed    = $true
        BackupPath = $backupPath
        NewSddl    = $verifySddl
      }
    }
  }

  end {
  }
}
