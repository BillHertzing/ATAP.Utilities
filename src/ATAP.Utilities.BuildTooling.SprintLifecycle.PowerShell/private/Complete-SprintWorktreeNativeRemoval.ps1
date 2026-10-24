function Complete-SprintWorktreeNativeRemoval {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][ValidateSet('Capture', 'Recover')][string]$Phase,
    [Parameter(Mandatory)][hashtable]$State,
    [Parameter(Mandatory)][string]$RepositoryPath,
    [Parameter(Mandatory)][string]$WorktreePath,
    [object]$Snapshot,
    [object]$NativeResult,
    [scriptblock]$Record
  )
  function Invoke-CleanupGit([string[]]$Arguments) {
    $result = Invoke-SprintEndNativeCommand -FilePath git -ArgumentList (@('-C', $RepositoryPath) + $Arguments) -AllowNonZeroExitCode
    if (-not $result.Succeeded) { throw 'Native cleanup Git validation failed.' }
    return $result.Output
  }
  function Assert-CleanupChain([string]$Path) {
    $ancestor = $Path
    while ($ancestor) {
      $entry = Get-Item -LiteralPath $ancestor -Force -ErrorAction Stop
      if (-not $entry.PSIsContainer -or $entry.LinkType) { throw 'Native cleanup directory identity is unsafe.' }
      if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        $tag = Invoke-SprintEndNativeCommand -FilePath fsutil.exe -ArgumentList @('reparsepoint', 'query', $ancestor) -AllowNonZeroExitCode
        if (-not $tag.Succeeded -or ($tag.Output -join "`n") -notmatch '(?im)^\s*Reparse Tag Value\s*:\s*0x9000[0-9a-f]01a\s*$') { throw 'Native cleanup ancestor is an unsafe reparse point.' }
      }
      $ancestor = Split-Path $ancestor -Parent
    }
  }
  $common = [IO.Path]::GetFullPath([string](@(Invoke-CleanupGit @('rev-parse', '--path-format=absolute', '--git-common-dir'))[0])).TrimEnd('\', '/')
  $dotGit = Join-Path $WorktreePath '.git'
  if ($Phase -eq 'Capture') {
    if (-not (Test-Path -LiteralPath $dotGit -PathType Leaf)) { return $null }
    $pointer = Get-Item -LiteralPath $dotGit -Force -ErrorAction Stop
    if ($pointer.LinkType) { throw 'Native cleanup worktree pointer is unsafe.' }
    $pointerText = (Get-Content -LiteralPath $dotGit -Raw -ErrorAction Stop).Trim()
    if ($pointerText -notmatch '^gitdir: (.+)$') { throw 'Native cleanup worktree pointer is malformed.' }
    $admin = [IO.Path]::GetFullPath($Matches[1], $WorktreePath).TrimEnd('\', '/')
    if ((Split-Path $admin -Parent) -ine (Join-Path $common 'worktrees')) { throw 'Native cleanup slot is outside the exact owning worktrees directory.' }
    Assert-CleanupChain $admin
    $backlink = (Get-Content -LiteralPath (Join-Path $admin 'gitdir') -Raw -ErrorAction Stop).Trim()
    if ([IO.Path]::GetFullPath($backlink) -ine $dotGit) { throw 'Native cleanup slot backlink mismatch.' }
    $head = [string](@(Invoke-CleanupGit @('-C', $WorktreePath, 'rev-parse', 'HEAD'))[0])
    if ($head -ine $State.Head) { throw 'Native cleanup slot HEAD mismatch.' }
    return @{ AdministrativePath=$admin; CommonDirectory=$common; RepositoryPath=$RepositoryPath; WorktreePath=$WorktreePath; Head=$State.Head; RecoveryReference=$State.RecoveryReference; CreationTimeUtc=(Get-Item -LiteralPath $admin -Force).CreationTimeUtc.ToString('o') }
  }
  if (-not $Snapshot -or $NativeResult.Succeeded -or $NativeResult.ExitCode -ne 255) { return $false }
  $admin = [string]$Snapshot.AdministrativePath
  $relative = [IO.Path]::GetRelativePath($RepositoryPath, $admin).Replace('\', '/')
  $expectedError = "error: failed to delete '$relative': Permission denied"
  if (@($NativeResult.Output).Count -ne 1 -or $NativeResult.Output[0] -cne $expectedError) { return $false }
  if ($Snapshot.RepositoryPath -ine $RepositoryPath -or $Snapshot.WorktreePath -ine $WorktreePath -or $Snapshot.CommonDirectory -ine $common -or $Snapshot.Head -ine $State.Head -or $Snapshot.RecoveryReference -cne $State.RecoveryReference -or (Split-Path $admin -Parent) -ine (Join-Path $common 'worktrees')) { throw 'Native cleanup captured identity changed.' }
  function Assert-CleanupState {
    Assert-CleanupChain $admin
    if ((Get-Item -LiteralPath $admin -Force).CreationTimeUtc.ToString('o') -cne $Snapshot.CreationTimeUtc) { throw 'Native cleanup slot was replaced.' }
    if (@(Get-ChildItem -LiteralPath $admin -Force -ErrorAction Stop).Count) { throw 'Native cleanup slot must be empty.' }
    if (Get-Item -LiteralPath $dotGit -Force -ErrorAction SilentlyContinue) { throw 'Native cleanup worktree pointer remains or was recreated.' }
    if (@(Get-SprintEndActiveWorkspaceRoot -WorktreePath $WorktreePath).Count) { throw 'Active workspace blocks native cleanup.' }
    $currentCommon = [string](@(Invoke-CleanupGit @('rev-parse', '--path-format=absolute', '--git-common-dir'))[0])
    if ([IO.Path]::GetFullPath($currentCommon).TrimEnd('\', '/') -ine $common) { throw 'Native cleanup owning common directory changed.' }
    $registrations = @(Invoke-CleanupGit @('worktree', 'list', '--porcelain'))
    if (@($registrations | Where-Object { $_ -like 'worktree *' -and [IO.Path]::GetFullPath($_.Substring(9)).TrimEnd('\', '/') -ieq $WorktreePath }).Count) { throw 'Native cleanup worktree remains registered.' }
    if ([string](@(Invoke-CleanupGit @('rev-parse', '--verify', "$($Snapshot.RecoveryReference)^{commit}"))[0]) -ine $Snapshot.Head) { throw 'Native cleanup recovery reference changed.' }
  }
  for ($cleanupAttempt = 1; $cleanupAttempt -le 6; $cleanupAttempt++) {
    Assert-CleanupState
    & $Record 'BeforeNativeMetadataCleanup' @{ Snapshot=$Snapshot; Attempt=$cleanupAttempt }
    Assert-CleanupState
    try {
      Invoke-SprintWorktreeNativeDirectoryDelete -LiteralPath $admin
    } catch {
      $cleanupError = $_.Exception
      while ($cleanupError.InnerException) { $cleanupError=$cleanupError.InnerException }
      $nativeError = $cleanupError.HResult -band 0xffff
      if (($cleanupError -isnot [IO.IOException] -and $cleanupError -isnot [UnauthorizedAccessException]) -or $nativeError -notin @(5, 32, 33) -or $cleanupAttempt -eq 6) { throw }
      Write-PSFMessage -FunctionName 'Complete-SprintWorktreeNativeRemoval' -ModuleName 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell' -Level Debug -Message "Empty native metadata cleanup retry $cleanupAttempt, Windows error $nativeError."
      Start-Sleep -Milliseconds (50 * [int][math]::Pow(2, $cleanupAttempt - 1))
      continue
    }
    if (Get-Item -LiteralPath $admin -Force -ErrorAction SilentlyContinue) { throw 'Native cleanup slot still exists.' }
    & $Record 'NativeMetadataCleanupComplete' $Snapshot
    return $true
  }
  return $false
}

function Invoke-SprintWorktreeNativeDirectoryDelete {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$LiteralPath)
  [IO.Directory]::Delete($LiteralPath, $false)
}
