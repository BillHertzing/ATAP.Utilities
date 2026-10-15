function Get-SprintWorktreeRecoveryState {
  [CmdletBinding()]
  param([string]$RepositoryPath, [string]$WorktreePath, [string]$ReceiptPath,
    [string]$LegacyRecoveryEvidencePath, [switch]$AcceptLegacy043Recovery)
  begin {
    $fn = 'Get-SprintWorktreeRecoveryState'
    $mn = 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell'
  }
  process {
    function Get-RecoveryGit([string[]]$Arguments) {
      $r = Invoke-SprintEndNativeCommand -FilePath git -ArgumentList (@('-C', $RepositoryPath) + $Arguments) -AllowNonZeroExitCode
      if (-not $r.Succeeded) { throw "Recovery Git validation failed: $($Arguments -join ' ')" }
      return $r.Output
    }
    function Convert-RecoveryRegistration([string[]]$Lines) {
      $entry = $null
      foreach ($line in $Lines) {
        if ($line -like 'worktree *') {
          if ($entry) { [pscustomobject]$entry }
          $entry = @{ Path = [IO.Path]::GetFullPath($line.Substring(9)).TrimEnd('\', '/'); Head = ''; Prunable = $false }
        } elseif ($entry -and $line -like 'HEAD *') { $entry.Head = $line.Substring(5) }
        elseif ($entry -and $line -like 'prunable*') { $entry.Prunable = $true }
      }
      if ($entry) { [pscustomobject]$entry }
    }
    $common = [IO.Path]::GetFullPath([string](@(Get-RecoveryGit @('rev-parse', '--path-format=absolute', '--git-common-dir'))[0])).TrimEnd('\', '/')
    $lines = @(Get-RecoveryGit @('worktree', 'list', '--porcelain'))
    $registrations = @(Convert-RecoveryRegistration $lines)
    $registered = @($registrations | Where-Object Path -IEQ $WorktreePath)
    if ($registered.Count -gt 1) { throw 'Ambiguous worktree registration.' }
    $state = $null
    if (Test-Path -LiteralPath $ReceiptPath -PathType Leaf) {
      $state = Get-Content -LiteralPath $ReceiptPath -Raw | ConvertFrom-Json -AsHashtable
      if ($state.SchemaVersion -ne 1 -or $state.RepositoryPath -ine $RepositoryPath -or $state.WorktreePath -ine $WorktreePath -or $state.CommonDirectory -ine $common -or -not $state.Head -or -not $state.RecoveryReference) { throw 'Receipt identity mismatch or malformed receipt.' }
      if (-not $registered.Count -and -not $state.Deregistered) { throw 'Receipt does not prove completed deregistration.' }
      if ($registered.Count -and $state.Deregistered) { throw 'Deregistered receipt conflicts with a current registered checkout.' }
      $capturedReceipt = @(Convert-RecoveryRegistration $state.BeforeRegistration | Where-Object Path -IEQ $WorktreePath)
      if ($capturedReceipt.Count -ne 1 -or $capturedReceipt[0].Head -ine $state.Head) { throw 'Receipt has no exact pre-removal registration and HEAD.' }
      if ($state.Deregistered) {
        if ($state.LegacyImport) {
          if (-not $state.LegacyEvidencePath) { throw 'Legacy receipt has no reviewed evidence path.' }
          $legacyRecheck = Get-SprintWorktreeRecoveryState -RepositoryPath $RepositoryPath -WorktreePath $WorktreePath -ReceiptPath ($ReceiptPath + '.' + [guid]::NewGuid().ToString('N')) -LegacyRecoveryEvidencePath $state.LegacyEvidencePath -AcceptLegacy043Recovery
          if ($legacyRecheck.State.Head -ine $state.Head -or $legacyRecheck.State.RecoveryReference -ine $state.RecoveryReference) { throw 'Legacy receipt evidence changed.' }
        } else {
          $successful = @($state.NativeAttempts | Where-Object {
            $nativeArguments = @($_.Result.ArgumentList)
            $_.Result.Succeeded -eq $true -and $_.Result.ExitCode -eq 0 -and $_.Result.FilePath -eq 'git' -and $nativeArguments.Count -eq 6 -and $nativeArguments[0] -eq '-C' -and $nativeArguments[1] -ieq $RepositoryPath -and $nativeArguments[2] -eq 'worktree' -and $nativeArguments[3] -eq 'remove' -and $nativeArguments[4] -ieq $WorktreePath -and $nativeArguments[5] -eq '--force'
          })
          if ($successful.Count -ne 1 -or -not $state.AfterRegistration) { throw 'Receipt lacks exactly one successful native removal and registration result.' }
          if (@(Convert-RecoveryRegistration $state.AfterRegistration | Where-Object Path -IEQ $WorktreePath).Count) { throw 'Receipt post-registration contradicts deregistration.' }
        }
      }
    } elseif ($LegacyRecoveryEvidencePath) {
      if (-not $AcceptLegacy043Recovery) { throw 'Legacy recovery requires explicit -AcceptLegacy043Recovery.' }
      $legacy = Get-Content -LiteralPath $LegacyRecoveryEvidencePath -Raw | ConvertFrom-Json
      if ($legacy.SchemaVersion -ne 1 -or $legacy.RepositoryPath -ine $RepositoryPath -or $legacy.WorktreePath -ine $WorktreePath -or $registered.Count) { throw 'Legacy identity mismatch or root is still registered.' }
      # Pinned reviewed .43 package hash: this proves the supplied historical binary;
      # it does not authenticate the human-supplied JSON evidence.
      $knownHash = 'E26A75A7FF932FE943F3C654444470E3B8B057042BF80215B22E34A03170CC2E'
      if ($legacy.InstalledModuleSha256 -ine $knownHash -or (Get-FileHash -LiteralPath $legacy.InstalledModulePath -Algorithm SHA256).Hash -ine $knownHash) { throw 'Legacy installed .43 source provenance mismatch.' }
      $before = Get-Content -LiteralPath $legacy.BeforeSnapshotPath -Raw | ConvertFrom-Json
      $owner = @($before.Repositories | Where-Object { $_.Repository -ieq $RepositoryPath -and $_.Worktree -ieq $WorktreePath })
      $old = Get-Content -LiteralPath $legacy.FailedReceiptPath -Raw | ConvertFrom-Json
      $expectedFailures = @('Attempt 2 failed with Git exit code 128.', 'Attempt 3 failed with Git exit code 128.', 'Worktree remains after 3 bounded removal attempts.')
      if ($owner.Count -ne 1 -or $before.InstalledModuleVersion -ne '0.1.43' -or $before.InstalledModuleSha256 -ine $knownHash -or $owner[0].WorktreeHead -ine $legacy.Head -or $old.WorktreePath -ine $WorktreePath -or $old.Ok -ne $false -or $old.Removed -ne $false -or $old.Attempts -ne 3 -or @($old.ActiveRoots).Count -or @($old.Failures).Count -ne 3 -or ($old.Failures -join "`n") -cne ($expectedFailures -join "`n")) { throw 'Legacy before-snapshot or exact .43 result semantics mismatch.' }
      $captured = @(Convert-RecoveryRegistration $owner[0].Registration | Where-Object Path -IEQ $WorktreePath)
      if ($captured.Count -ne 1 -or $captured[0].Head -ine $legacy.Head) { throw 'Legacy before-registration HEAD mismatch.' }
      $state = @{ SchemaVersion = 1; RepositoryPath = $RepositoryPath; WorktreePath = $WorktreePath; CommonDirectory = $common; Head = $legacy.Head; RecoveryReference = $legacy.RecoveryReference; Deregistered = $true; LegacyImport = $legacy; LegacyEvidencePath = $LegacyRecoveryEvidencePath; BeforeRegistration = @($owner[0].Registration); Events = @(); NativeAttempts = @() }
    } elseif ($registered.Count) {
      if ($registered[0].Head -notmatch '^[0-9a-f]{40,64}$') { throw 'Registration has no valid HEAD.' }
      $state = @{ SchemaVersion = 1; RepositoryPath = $RepositoryPath; WorktreePath = $WorktreePath; CommonDirectory = $common; Head = $registered[0].Head; RecoveryReference = "refs/archive/sprint-worktree-removal/$($registered[0].Head)"; Deregistered = $false; BeforeRegistration = $lines; Events = @(); NativeAttempts = @() }
    } else { throw 'The exact worktree path is not registered and no reviewed recovery receipt was supplied.' }
    if ($state.Head -notmatch '^[0-9a-f]{40,64}$' -or $state.RecoveryReference -notmatch '^refs/archive/[a-zA-Z0-9/._-]+$') { throw 'Invalid recovery HEAD or reference.' }
    if ($state.Deregistered -or (Test-Path -LiteralPath $ReceiptPath) -or $LegacyRecoveryEvidencePath) {
      $preserved = @(Get-RecoveryGit @('rev-parse', '--verify', "$($state.RecoveryReference)^{commit}"))
      if ($preserved[0] -ine $state.Head) { throw 'Recovery reference no longer preserves captured HEAD.' }
    }
    if ($registered.Count -and $registered[0].Head -ine $state.Head) { throw 'Registered HEAD changed since receipt.' }
    return [pscustomobject]@{ State = $state; Registrations = $registrations; Registered = [bool]$registered.Count }
  }
  end { }
}




