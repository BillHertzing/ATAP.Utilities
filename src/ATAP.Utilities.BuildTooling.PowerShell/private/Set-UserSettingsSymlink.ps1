function Set-UserSettingsSymlink {
  <#
  .SYNOPSIS
    Transactionally selects a readable SharedVSCode settings file.
  .DESCRIPTION
    Captures entry metadata before dereferencing it. A previous entry is moved
    intact to a recovery path until replacement and readback succeed. On failure
    it is restored; failed recovery is reported with the retained recovery path.
    CheckOnly audits exact target, readability and survival of worktree removal.
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$SharedVSCodeWorktreePath,
    [switch]$CheckOnly,
    [string[]]$WorktreePaths = @()
  )
  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"
  }
  process {
    $sourcePath = [IO.Path]::GetFullPath((Join-Path $SharedVSCodeWorktreePath 'UserSettings.jsonc'))
    $targetPath = Join-Path $env:APPDATA 'Code' 'User' 'settings.json'
    $targetDir = Split-Path $targetPath -Parent
    # Get-Item -Force preserves dangling-link metadata; Test-Path alone cannot.
    $existingItem = Get-Item -LiteralPath $targetPath -Force -ErrorAction SilentlyContinue
    $before = if ($null -ne $existingItem) {
      [PSCustomObject]@{ Path = $existingItem.FullName; LinkType = $existingItem.LinkType;
        Target = @($existingItem.Target); Attributes = [string]$existingItem.Attributes;
        CreationTimeUtc = $existingItem.CreationTimeUtc; LastWriteTimeUtc = $existingItem.LastWriteTimeUtc }
    } else { $null }
    $result = [PSCustomObject]@{ Ok = $false; Changed = $false; Planned = $false;
      TargetPath = $targetPath; ExpectedTarget = $sourcePath; Before = $before; After = $null;
      RecoveryPath = $null; Rollback = [PSCustomObject]@{ Attempted = $false; Succeeded = $false; Error = $null } }
    $readable = {
      param($path)
      if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Settings file missing: '$path'" }
      $stream = $null
      try { $stream = [IO.File]::Open($path, 'Open', 'Read', 'ReadWrite'); [void]$stream.ReadByte() }
      finally { if ($null -ne $stream) { $stream.Dispose() } }
    }
    $inspect = {
      $item = Get-Item -LiteralPath $targetPath -Force -ErrorAction Stop
      $rawTarget = @($item.Target)
      if ($item.LinkType -ne 'SymbolicLink' -or $rawTarget.Count -ne 1) { throw 'Settings entry must be one symbolic link.' }
      $resolvedTarget = if ([IO.Path]::IsPathRooted($rawTarget[0])) {
        [IO.Path]::GetFullPath($rawTarget[0])
      } else { [IO.Path]::GetFullPath((Join-Path $targetDir $rawTarget[0])) }
      if (-not [StringComparer]::OrdinalIgnoreCase.Equals($resolvedTarget, $sourcePath)) { throw "Settings target mismatch: '$resolvedTarget'; expected '$sourcePath'." }
      & $readable $targetPath
      [PSCustomObject]@{ LinkType = $item.LinkType; Target = $rawTarget[0]; ResolvedTarget = $resolvedTarget; Readable = $true }
    }
    try {
      foreach ($root in $WorktreePaths) {
        $removalRoot = [IO.Path]::GetFullPath($root).TrimEnd([char[]]'\/')
        if ([StringComparer]::OrdinalIgnoreCase.Equals($sourcePath, $removalRoot) -or
            $sourcePath.StartsWith($removalRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
          throw "Settings destination would be removed with worktree '$removalRoot'."
        }
      }
      if ($null -ne $before -and -not $before.LinkType -and -not $existingItem.PSIsContainer) {
        $before | Add-Member -NotePropertyName Hash -NotePropertyValue (Get-FileHash -LiteralPath $targetPath -Algorithm SHA256 -ErrorAction Stop).Hash
      }
      # A lexically stable destination must not hide a departing target behind
      # another link/junction. Reject indirection rather than guessing survival.
      $sourceEntryPath = $sourcePath
      while ($sourceEntryPath) {
        $sourceEntry = Get-Item -LiteralPath $sourceEntryPath -Force -ErrorAction Stop
        if ($sourceEntry.LinkType -in @('SymbolicLink', 'Junction')) { throw "Settings source traverses an indirect destination: '$sourceEntryPath'." }
        $sourceEntryPath = Split-Path -Path $sourceEntryPath -Parent
      }
      & $readable $sourcePath
      try { $result.After = & $inspect; $result.Ok = $true } catch { if ($CheckOnly) { throw } }
      if ($result.Ok -or $CheckOnly) { return $result }
      if (-not $PSCmdlet.ShouldProcess($targetPath, "Transactionally retarget settings -> $sourcePath")) {
        $result.Planned = $true
        return $result
      }
      $replacementAttempted = $false
      $moved = $false
      try {
        if (-not (Test-Path -LiteralPath $targetDir -PathType Container)) {
          New-Item -ItemType Directory -Path $targetDir -Force -Confirm:$false -ErrorAction Stop | Out-Null
        }
        if ($null -ne $existingItem) {
          if ($existingItem.PSIsContainer) { throw 'Refusing to replace a settings directory.' }
          $result.RecoveryPath = "$targetPath.recovery-$([guid]::NewGuid().ToString('N'))"
          Move-Item -LiteralPath $targetPath -Destination $result.RecoveryPath -Confirm:$false -ErrorAction Stop
          $moved = $true
        }
        $replacementAttempted = $true
        New-Item -ItemType SymbolicLink -Path $targetPath -Target $sourcePath -Confirm:$false -ErrorAction Stop | Out-Null
        $result.After = & $inspect
        if ($moved) { Remove-Item -LiteralPath $result.RecoveryPath -Force -Confirm:$false -ErrorAction Stop }
        $result.Ok = $true
        $result.Changed = $true
        return $result
      } catch {
        $originalError = $_
        $result.Rollback.Attempted = $replacementAttempted -or $moved
        try {
          if ($replacementAttempted -and $null -ne (Get-Item -LiteralPath $targetPath -Force -ErrorAction SilentlyContinue)) {
            Remove-Item -LiteralPath $targetPath -Force -Confirm:$false -ErrorAction Stop
          }
          if ($moved) { Move-Item -LiteralPath $result.RecoveryPath -Destination $targetPath -Confirm:$false -ErrorAction Stop }
          if ($moved) {
            $restored = Get-Item -LiteralPath $targetPath -Force -ErrorAction Stop
            if ([string]$restored.LinkType -ne [string]$before.LinkType -or
                [string]$restored.Attributes -ne $before.Attributes -or
                $restored.CreationTimeUtc -ne $before.CreationTimeUtc -or
                $restored.LastWriteTimeUtc -ne $before.LastWriteTimeUtc -or
                (@($restored.Target) -join '|') -cne ($before.Target -join '|')) { throw 'Rollback metadata verification failed.' }
            if (-not $before.LinkType -and (Get-FileHash -LiteralPath $targetPath -Algorithm SHA256 -ErrorAction Stop).Hash -ne $before.Hash) { throw 'Rollback content verification failed.' }
          }
          $result.Rollback.Succeeded = $true
        } catch { $result.Rollback.Error = $_.Exception.Message }
        $exception = [InvalidOperationException]::new("Settings replacement failed: $($originalError.Exception.Message). Rollback succeeded: $($result.Rollback.Succeeded). Recovery path: '$($result.RecoveryPath)'.", $originalError.Exception)
        $exception.Data['SettingsLinkResult'] = $result
        throw $exception
      }
    } catch {
      if ($CheckOnly) {
        $result | Add-Member -NotePropertyName Error -NotePropertyValue $_.Exception.Message
        return $result
      }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $_.Exception.Message
      throw
    }
  }
  end { }
}
