<#
.SYNOPSIS
  Dot-source this file to load the Invoke-WithFileLock function, then call it to run a
  script block under an OS-level exclusive file-system lock.

.DESCRIPTION
  Designed for concurrent Claude Code agents in separate VS Code / worktree windows that
  share common files (TASKS.md, CLAUDE.md, etc.).

  How it works
  ------------
  - Opens a dedicated .lock file with FileShare.None — a genuine OS-level exclusive handle.
    No other process on Windows can open the same file while this handle is held.
  - Writes the acquiring agent's PID, hostname, timestamp, and lock name into the lock file
    for diagnostics.
  - On collision (IOException) the agent waits with truncated exponential back-off plus
    randomised jitter (±40 %) to prevent the "thundering herd" problem and give every
    agent equitable access over time.
  - The lock is held for the entire duration of the Action script block, then released in a
    `finally` block — guaranteed even if Action throws.

  Lock files are stored in a shared directory (default: _Planning/_locks/).  The directory
  is created automatically on first use.

.NOTES
  AI assisted using Powershell.instructions.md as guidelines

  Equitability guarantee
  ----------------------
  Pure randomised jitter does not guarantee strict ordering, but in practice — because each
  agent's back-off grows independently — the probability of one agent monopolising the lock
  falls exponentially with each attempt.  For infrequent, fast-completing operations (a
  read-modify-write on a text file) this is sufficient.  If strict FIFO ordering is ever
  required, replace the retry loop with a ticket-lock (queue file per agent) — see comments
  in the PROCESS block.

.LINK
  https://learn.microsoft.com/en-us/dotnet/api/system.io.file.open
#>

function Invoke-WithFileLock {
  <#
  .SYNOPSIS
    Acquires an exclusive lock on a named resource, runs a script block, then releases the lock.

  .PARAMETER LockName
    Logical name for the resource being locked.  Becomes the base name of the .lock file.
    Examples: 'TASKS.md', 'CLAUDE.md', 'SharedVSCode-UserSettings'

  .PARAMETER Action
    Script block to execute while holding the lock.  Keep it short — holds the lock for its
    entire duration.  The return value (if any) is passed back to the caller.

  .PARAMETER LockDirectory
    Directory where .lock files are stored.
    Default: C:/Dropbox/whertzing/github/_planning/_locks

  .PARAMETER TimeoutSeconds
    Seconds to wait before giving up and throwing.  Default: 90.

  .PARAMETER MaxRetryMs
    Upper ceiling for a single retry wait interval (milliseconds).  Default: 4000.

  .OUTPUTS
    Whatever the Action script block returns, if anything.

  .EXAMPLE
    # Dot-source then use:
    . 'C:/Dropbox/whertzing/github/SharedVSCode/Powershell/public/Invoke-WithFileLock.ps1'

    $tasksPath = 'C:/Dropbox/whertzing/github/_planning/TASKS.md'
    Invoke-WithFileLock -LockName 'TASKS.md' -Action {
        $content = Get-Content $tasksPath -Raw
        $content = $content -replace '\[ \] Step 7 — ', '[x] Step 7 — '
        [System.IO.File]::WriteAllText($tasksPath, $content)
    }

  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$LockName,

    [Parameter(Mandatory)]
    [scriptblock]$Action,

    [Parameter()]
    [string]$LockDirectory = 'C:/Dropbox/whertzing/github/_planning/_locks',

    [Parameter()]
    [int]$TimeoutSeconds = 90,

    [Parameter()]
    [int]$MaxRetryMs = 4000
  )

  BEGIN {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'SharedTools'

    # Sanitize lock name — strip chars illegal in Windows filenames
    $safeName  = $LockName -replace '[\\/:*?"<>|]', '_'
    $lockFile  = Join-Path $LockDirectory "$safeName.lock"
    $ownerInfo = "$PID|$(hostname)|$([DateTime]::UtcNow.ToString('o'))|$LockName"

    if (-not (Test-Path $LockDirectory)) {
      $null = New-Item -ItemType Directory -Path $LockDirectory -Force
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
        -Message "Created lock directory: $LockDirectory"
    }

    $deadline   = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    $attempt    = 0
    $acquired   = $false
    $lockStream = $null
    $result     = $null
  }

  PROCESS {
    # ----------------------------------------------------------------
    # Phase 1 — Acquisition loop.
    #
    # Only the Open() call lives inside catch [IOException].
    # This prevents an IOException thrown by $Action from being
    # misidentified as lock contention and silently retried.
    #
    # On each failed attempt the handle is explicitly closed before
    # sleeping.  On success the loop exits with $lockStream still open
    # — the handle is NOT closed here; Phase 2 owns its lifetime.
    # ----------------------------------------------------------------
    while (-not $acquired -and ([DateTime]::UtcNow -lt $deadline)) {
      $attempt++

      try {
        # FileShare.None — no other process may open this file until
        # we close the handle.  The open itself is the atomic lock op.
        $lockStream = [System.IO.File]::Open(
          $lockFile,
          [System.IO.FileMode]::OpenOrCreate,
          [System.IO.FileAccess]::ReadWrite,
          [System.IO.FileShare]::None
        )

        # Stamp owner info for diagnostics
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($ownerInfo)
        $lockStream.SetLength(0)
        $lockStream.Write($bytes, 0, $bytes.Length)
        $lockStream.Flush()
        $acquired = $true

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
          -Message "Lock '$LockName' acquired on attempt $attempt (PID $PID)"
      }
      catch [System.IO.IOException] {
        # ----------------------------------------------------------------
        # Lock held by another agent — back off with truncated exponential
        # delay plus ±40 % jitter.
        #
        # Back-off curve (MaxRetryMs = 4000):
        #   attempt 1  ~150 ms
        #   attempt 3  ~340 ms
        #   attempt 5  ~760 ms
        #   attempt 8  ~1900 ms
        #   attempt 12+  ~4000 ms  (capped)
        # ----------------------------------------------------------------
        if ($lockStream) { $lockStream.Close(); $lockStream.Dispose(); $lockStream = $null }

        $baseMs   = [Math]::Min(100 * [Math]::Pow(1.5, [Math]::Min($attempt, 12)), $MaxRetryMs)
        $jitterMs = Get-Random -Minimum 0 -Maximum ([int]($baseMs * 0.4))
        $waitMs   = [int]$baseMs + $jitterMs

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
          -Message "Lock '$LockName' busy (attempt $attempt) — retry in ${waitMs} ms"

        Start-Sleep -Milliseconds $waitMs
      }
      catch {
        # Unexpected error during Open() — release any partial handle and abort
        if ($lockStream) { $lockStream.Close(); $lockStream.Dispose(); $lockStream = $null }
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error `
          -Message "Lock '$LockName' — unexpected error acquiring on attempt ${attempt}: $_"
        throw
      }
    }

    if (-not $acquired) {
      throw "Invoke-WithFileLock: timed out waiting for lock '$LockName' after $TimeoutSeconds s ($attempt attempts)."
    }

    # ----------------------------------------------------------------
    # Phase 2 — Run the caller's action with the lock held.
    #
    # The finally here is the sole owner of the handle's lifetime.
    # Any exception from $Action propagates to the caller unchanged;
    # the lock is always released regardless.
    # ----------------------------------------------------------------
    try {
      $result = & $Action
    }
    finally {
      if ($lockStream) {
        $lockStream.Close()
        $lockStream.Dispose()
        $lockStream = $null
      }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
        -Message "Lock '$LockName' released after $attempt attempt(s)"
    }

    return $result
  }
}
