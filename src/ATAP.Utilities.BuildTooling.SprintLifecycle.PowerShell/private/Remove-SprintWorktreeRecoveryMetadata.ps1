function Remove-SprintWorktreeRecoveryMetadata {
  [CmdletBinding()]
  param([object]$Selection, [hashtable]$State, [scriptblock]$Record, [switch]$InventoryOnly)
  begin {
    $fn = 'Remove-SprintWorktreeRecoveryMetadata'
    $mn = 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell'
  }
  process {
    function Invoke-MetadataGit([string[]]$Arguments) {
      $result = Invoke-SprintEndNativeCommand -FilePath git -ArgumentList (@('-C', $Selection.RepositoryPath) + $Arguments) -AllowNonZeroExitCode
      if (-not $result.Succeeded) { throw 'Administrative Git validation failed.' }
      $result.Output
    }
    function Assert-MetadataEntry([string]$Path, [bool]$Directory) {
      $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
      if ([bool]$item.PSIsContainer -ne $Directory) { throw "Administrative entry type changed: $Path" }
      if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        $tag = Invoke-SprintEndNativeCommand -FilePath fsutil.exe -ArgumentList @('reparsepoint', 'query', $Path) -AllowNonZeroExitCode
        if ($item.LinkType -or -not $tag.Succeeded -or ($tag.Output -join "`n") -notmatch '(?im)^\s*Reparse Tag Value\s*:\s*0x9000[0-9a-f]01a\s*$') { throw "Administrative entry is an unsafe reparse point: $Path" }
      }
    }
    function Assert-MetadataChain([string]$Path, [bool]$Directory) {
      Assert-MetadataEntry $Path $Directory
      $parent = Split-Path $Path -Parent
      while ($parent) { Assert-MetadataEntry $parent $true; $parent = Split-Path $parent -Parent }
    }
    function Assert-RemainingMetadataSnapshot {
      Assert-MetadataChain $admin $true
      $remaining = @()
      foreach ($entry in @(Get-ChildItem -LiteralPath $admin -Force)) {
        if ($entry.Name -in @('logs', 'refs')) {
          Assert-MetadataEntry $entry.FullName $true
          $children = @(Get-ChildItem -LiteralPath $entry.FullName -Force)
          if ($entry.Name -eq 'refs' -and $children.Count) { throw 'Administrative refs changed after journaling.' }
          foreach ($child in $children) { $remaining += @{ Path = $child.FullName; Relative = $entry.Name + '/' + $child.Name } }
        } else { $remaining += @{ Path = $entry.FullName; Relative = $entry.Name } }
      }
      foreach ($file in $remaining) {
        Assert-MetadataEntry $file.Path $false
        $expectedFile = @($slot.Files | Where-Object Relative -CEQ $file.Relative)
        if ($expectedFile.Count -ne 1 -or (Get-FileHash -LiteralPath $file.Path -Algorithm SHA256).Hash -ine $expectedFile[0].SHA256) { throw "Remaining administrative file changed after journaling: $($file.Path)" }
      }
      foreach ($expectedFile in $slot.Files) {
        $filePath = Join-Path $admin $expectedFile.Relative
        if (-not (Test-Path -LiteralPath $filePath) -and -not @($State.Events | Where-Object { $_.Event -eq 'BeforeSelectedMetadataFileRemoval' -and $_.Detail -ieq $filePath }).Count) { throw 'Remaining administrative file vanished without recorded intent.' }
      }
    }
    $admin = [IO.Path]::GetFullPath($Selection.AdministrativePath).TrimEnd('\', '/')
    $common = [IO.Path]::GetFullPath([string](@(Invoke-MetadataGit @('rev-parse', '--path-format=absolute', '--git-common-dir'))[0])).TrimEnd('\', '/')
    $slots = Join-Path $common 'worktrees'
    if ((Split-Path $admin -Parent) -ine $slots) { throw 'AdministrativePath must be an exact direct child of owning common/worktrees.' }
    $ancestor = $common
    while ($ancestor) { Assert-MetadataEntry $ancestor $true; $ancestor = Split-Path $ancestor -Parent }
    Assert-MetadataEntry $slots $true
    $journal = @($State.MetadataSlots | Where-Object { $_.AdministrativePath -ieq $admin })
    if ($journal.Count -gt 1) { throw 'Ambiguous administrative recovery journal.' }
    if ($journal.Count) {
      $slot = $journal[0]
      if ($slot.RepositoryPath -ine $Selection.RepositoryPath -or $slot.WorktreePath -ine $Selection.WorktreePath -or $slot.Head -ine $Selection.Head -or $slot.RecoveryReference -cne $Selection.RecoveryReference) { throw 'Administrative recovery identity changed.' }
    } else {
      Assert-MetadataEntry $admin $true
      $gitdir = Join-Path $admin 'gitdir'
      Assert-MetadataEntry $gitdir $false
      if ([IO.Path]::GetFullPath((Get-Content $gitdir -Raw).Trim()) -ine (Join-Path $Selection.WorktreePath '.git') -or (Test-Path -LiteralPath (Join-Path $Selection.WorktreePath '.git'))) { throw 'Administrative gitdir does not identify the selected missing worktree.' }
      $headFile = Join-Path $admin 'HEAD'
      Assert-MetadataEntry $headFile $false
      $head = (Get-Content $headFile -Raw).Trim()
      if ($head -like 'ref: *') { $head = [string](@(Invoke-MetadataGit @('rev-parse', '--verify', $head.Substring(5)))[0]) }
      if ($head -ine $Selection.Head) { throw 'Administrative HEAD mismatch.' }
      $files = @()
      foreach ($entry in @(Get-ChildItem -LiteralPath $admin -Force)) {
        if ($entry.Name -eq 'logs') {
          Assert-MetadataEntry $entry.FullName $true
          foreach ($log in @(Get-ChildItem -LiteralPath $entry.FullName -Force)) {
            if ($log.Name -ne 'HEAD') { throw 'Unexpected administrative log file.' }
            Assert-MetadataEntry $log.FullName $false
            $files += @{ Relative = 'logs/HEAD'; SHA256 = (Get-FileHash $log.FullName -Algorithm SHA256).Hash }
          }
        } elseif ($entry.Name -eq 'refs') {
          Assert-MetadataEntry $entry.FullName $true
          if (@(Get-ChildItem -LiteralPath $entry.FullName -Force).Count) { throw 'Administrative refs directory must be empty.' }
        } else {
          if ($entry.Name -notin @('gitdir', 'HEAD', 'commondir', 'index', 'ORIG_HEAD', 'config.worktree')) { throw "Unexpected administrative file: $($entry.Name)" }
          Assert-MetadataEntry $entry.FullName $false
          $files += @{ Relative = $entry.Name; SHA256 = (Get-FileHash $entry.FullName -Algorithm SHA256).Hash }
        }
      }
      $slot = @{ AdministrativePath = $admin; RepositoryPath = $Selection.RepositoryPath; WorktreePath = $Selection.WorktreePath; Head = $Selection.Head; RecoveryReference = $Selection.RecoveryReference; Files = $files; RemovedFiles = @(); Completed = $false }
    }
    $preserved = [string](@(Invoke-MetadataGit @('rev-parse', '--verify', "$($slot.RecoveryReference)^{commit}"))[0])
    if ($preserved -ine $slot.Head -or (Test-Path -LiteralPath (Join-Path $slot.WorktreePath '.git'))) { throw 'Administrative recovery ref changed or selected worktree has been recreated.' }
    if (-not (Test-Path -LiteralPath $admin)) {
      if (-not $slot.Completed -and -not ($State.Events | Where-Object { $_.Event -eq 'BeforeSelectedMetadataSlotRemoval' -and $_.Detail -ieq $admin })) { throw 'Administrative slot disappeared without a recorded exact removal intent.' }
      if ($InventoryOnly) { return }
      $slot.Completed = $true
      & $Record 'SelectedMetadataSlotRemoved' $admin
      return
    }
    Assert-MetadataEntry $admin $true
    # Validate the whole surviving slot before the first effect, including new files.
    $actual = @()
    foreach ($entry in @(Get-ChildItem -LiteralPath $admin -Force)) {
      if ($entry.Name -eq 'logs') {
        Assert-MetadataEntry $entry.FullName $true
        foreach ($log in @(Get-ChildItem -LiteralPath $entry.FullName -Force)) { Assert-MetadataEntry $log.FullName $false; $actual += 'logs/' + $log.Name }
      } elseif ($entry.Name -eq 'refs') {
        Assert-MetadataEntry $entry.FullName $true
        if (@(Get-ChildItem -LiteralPath $entry.FullName -Force).Count) { throw 'Administrative refs directory changed.' }
      } else { Assert-MetadataEntry $entry.FullName $false; $actual += $entry.Name }
    }
    foreach ($relative in $actual) {
      $expected = @($slot.Files | Where-Object Relative -CEQ $relative)
      if ($expected.Count -ne 1 -or (Get-FileHash -LiteralPath (Join-Path $admin $relative) -Algorithm SHA256).Hash -ine $expected[0].SHA256) { throw "Administrative file changed: $relative" }
    }
    foreach ($expected in $slot.Files) {
      $path = Join-Path $admin $expected.Relative
      if (-not (Test-Path -LiteralPath $path)) {
        $intent = @($State.Events | Where-Object { $_.Event -eq 'BeforeSelectedMetadataFileRemoval' -and $_.Detail -ieq $path })
        if (-not $intent.Count) { throw "Administrative file vanished without recorded intent: $path" }
      }
    }
    if ($InventoryOnly) { return }
    if (-not $journal.Count) {
      if (-not $State.ContainsKey('MetadataSlots')) { $State.MetadataSlots = @() }
      $State.MetadataSlots += $slot
      & $Record 'SelectedMetadataSnapshot' $slot
    }
    foreach ($expected in @($slot.Files | Sort-Object { $_.Relative -in @('HEAD', 'gitdir') })) {
      $path = Join-Path $admin $expected.Relative
      if (-not (Test-Path -LiteralPath $path)) { continue }
      Assert-MetadataChain $path $false
      if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ine $expected.SHA256) { throw 'Administrative file changed immediately before deletion.' }
      & $Record 'BeforeSelectedMetadataFileRemoval' $path
      Assert-RemainingMetadataSnapshot
      Assert-MetadataChain $path $false
      if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ine $expected.SHA256) { throw 'Administrative file changed after journaling removal intent.' }
      [IO.File]::Delete($path)
      $slot.RemovedFiles += $expected.Relative
      & $Record 'SelectedMetadataFileRemoved' $path
    }
    $logs = Join-Path $admin 'logs'
    if (Test-Path -LiteralPath $logs) {
      Assert-MetadataChain $logs $true
      & $Record 'BeforeSelectedMetadataLogsRemoval' $logs
      Assert-RemainingMetadataSnapshot
      Assert-MetadataChain $logs $true
      if (@(Get-ChildItem -LiteralPath $logs -Force).Count) { throw 'Administrative logs changed after journaling removal intent.' }
      [IO.Directory]::Delete($logs, $false)
      & $Record 'SelectedMetadataLogsRemoved' $logs
    }
    $refs = Join-Path $admin 'refs'
    if (Test-Path -LiteralPath $refs) {
      Assert-MetadataChain $refs $true
      if (@(Get-ChildItem -LiteralPath $refs -Force).Count) { throw 'Administrative refs directory changed before deletion.' }
      & $Record 'BeforeSelectedMetadataRefsRemoval' $refs
      Assert-RemainingMetadataSnapshot
      Assert-MetadataChain $refs $true
      if (@(Get-ChildItem -LiteralPath $refs -Force).Count) { throw 'Administrative refs changed after journaling removal intent.' }
      [IO.Directory]::Delete($refs, $false)
      & $Record 'SelectedMetadataRefsRemoved' $refs
    }
    Assert-MetadataChain $admin $true
    & $Record 'BeforeSelectedMetadataSlotRemoval' $admin
    Assert-RemainingMetadataSnapshot
    Assert-MetadataChain $admin $true
    if (@(Get-ChildItem -LiteralPath $admin -Force).Count) { throw 'Administrative slot changed after journaling removal intent.' }
    [IO.Directory]::Delete($admin, $false)
    $slot.Completed = $true
    & $Record 'SelectedMetadataSlotRemoved' $admin
  }
  end { }
}




