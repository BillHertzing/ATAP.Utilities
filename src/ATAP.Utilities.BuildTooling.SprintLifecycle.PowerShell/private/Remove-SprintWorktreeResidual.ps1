function Remove-SprintWorktreeResidual {
  [CmdletBinding()]
  param([string]$Root, [string[]]$PlaceholderPath, [hashtable]$JunctionTarget,
    [string[]]$DirectoryRoot, [scriptblock]$Record, [switch]$InventoryOnly)
  begin {
    $fn = 'Remove-SprintWorktreeResidual'
    $mn = 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell'
  }
  process {
    # Never enumerate a junction. Cloud tags are read from the native tag, not Attributes.
    function Get-ResidualKind([string]$Path, [switch]$AllowCloudFamily) {
      $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
      if (-not $item.PSIsContainer) { throw "Residual file is forbidden: $Path" }
      if (-not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { return 'Directory' }
      if ($item.LinkType -eq 'Junction') { return 'Junction' }
      $query = Invoke-SprintEndNativeCommand -FilePath 'fsutil.exe' -ArgumentList @('reparsepoint', 'query', $Path) -AllowNonZeroExitCode
      $tagPattern = if ($AllowCloudFamily) { '(?im)^\s*Reparse Tag Value\s*:\s*0x9000[0-9a-f]01a\s*$' } else { '(?im)^\s*Reparse Tag Value\s*:\s*0x9000e01a\s*$' }
      if ($query.Succeeded -and ($query.Output -join "`n") -match $tagPattern -and -not $item.LinkType) { return 'Cloud' }
      throw "Unknown or forbidden residual reparse point: $Path"
    }
    function Assert-ResidualAncestors([string]$Path) {
      $parent = Split-Path -Parent $Path
      while ($parent) {
        $kind = Get-ResidualKind $parent -AllowCloudFamily
        if ($kind -notin @('Directory', 'Cloud')) { throw "Unsafe residual ancestor: $parent" }
        $parent = Split-Path -Parent $parent
      }
      if ((Get-ResidualKind $Root) -notin @('Directory', 'Cloud')) { throw 'Unsafe residual root.' }
    }
    function Assert-ApprovedResidualJunction([string]$Path) {
      $key = [IO.Path]::GetRelativePath($Root, $Path).Replace('\', '/')
      $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
      if (-not $JunctionTarget.ContainsKey($key) -or (Get-ResidualKind $Path) -ne 'Junction' -or [IO.Path]::GetFullPath([string]$item.Target).TrimEnd('\', '/') -ine [IO.Path]::GetFullPath($JunctionTarget[$key]).TrimEnd('\', '/')) { throw "Changed, unknown, or invalid approved junction: $Path" }
    }
    $directories = [Collections.Generic.List[string]]::new()
    $junctions = [Collections.Generic.List[string]]::new()
    if (-not (Test-Path -LiteralPath $Root)) { return @() }
    Assert-ResidualAncestors $Root
    if ((Get-ResidualKind $Root) -notin @('Directory', 'Cloud')) { throw 'Residual root must be an ordinary directory.' }
    foreach ($child in @(Get-ChildItem -LiteralPath $Root -Force -ErrorAction Stop)) {
      $kind = Get-ResidualKind $child.FullName
      if ($JunctionTarget.ContainsKey($child.Name)) {
        Assert-ApprovedResidualJunction $child.FullName
        $junctions.Add($child.FullName)
      } elseif ($child.Name -in $PlaceholderPath) {
        if ($kind -ne 'Directory' -or @(Get-ChildItem -LiteralPath $child.FullName -Force).Count) { throw "Refused non-empty or reparse-point adapter placeholder: $($child.FullName)" }
        $directories.Add($child.FullName)
      } elseif ($child.Name -in $DirectoryRoot) {
        $queue = [Collections.Generic.Queue[string]]::new()
        $queue.Enqueue($child.FullName)
        while ($queue.Count) {
          $path = $queue.Dequeue()
          Assert-ResidualAncestors $path
          $pathKind = Get-ResidualKind $path
          if ($pathKind -eq 'Junction') {
            Assert-ApprovedResidualJunction $path
            $junctions.Add($path)
            continue
          }
          if ($pathKind -notin @('Directory', 'Cloud')) { throw "Unapproved junction in directory manifest: $path" }
          $directories.Add($path)
          foreach ($entry in @(Get-ChildItem -LiteralPath $path -Force -ErrorAction Stop)) {
            if (-not $entry.PSIsContainer) { throw "Residual file is forbidden: $($entry.FullName)" }
            $queue.Enqueue($entry.FullName)
          }
        }
      } else { throw "Unapproved residual root entry: $($child.FullName)" }
    }
    $inventory = @($junctions.ToArray()) + @($directories.ToArray())
    if ($InventoryOnly) { return $inventory }
    # The complete inventory must pass before the first unlink. Each effect is rechecked.
    foreach ($path in @($junctions | Sort-Object Length -Descending)) {
      Assert-ResidualAncestors $path
      Assert-ApprovedResidualJunction $path
      & $Record 'BeforeJunctionUnlink' $path
      Assert-ResidualAncestors $path
      Assert-ApprovedResidualJunction $path
      [IO.Directory]::Delete($path, $false)
      & $Record 'JunctionUnlinked' $path
    }
    foreach ($path in @($directories | Sort-Object Length -Descending)) {
      Assert-ResidualAncestors $path
      if ((Get-ResidualKind $path) -notin @('Directory', 'Cloud') -or @(Get-ChildItem -LiteralPath $path -Force).Count) { throw "Residual directory changed or is not empty: $path" }
      & $Record 'BeforeEmptyDirectoryRemoval' $path
      Assert-ResidualAncestors $path
      if ((Get-ResidualKind $path) -notin @('Directory', 'Cloud') -or @(Get-ChildItem -LiteralPath $path -Force).Count) { throw "Residual directory changed after journaling removal intent: $path" }
      [IO.Directory]::Delete($path, $false)
      & $Record 'EmptyDirectoryRemoved' $path
    }
    if ((Get-ResidualKind $Root) -notin @('Directory', 'Cloud') -or @(Get-ChildItem -LiteralPath $Root -Force).Count) { throw 'Residual root changed or is not empty.' }
    & $Record 'BeforeRootRemoval' $Root
    Assert-ResidualAncestors $Root
    if ((Get-ResidualKind $Root) -notin @('Directory', 'Cloud') -or @(Get-ChildItem -LiteralPath $Root -Force).Count) { throw 'Residual root changed after journaling removal intent.' }
    [IO.Directory]::Delete($Root, $false)
    & $Record 'RootRemoved' $Root
    return $inventory
  }
  end { }
}



