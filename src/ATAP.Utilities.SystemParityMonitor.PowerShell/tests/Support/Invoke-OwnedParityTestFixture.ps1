function Invoke-OwnedParityTestFixture {
  <#
  .SYNOPSIS
    Creates, validates or removes one process-owned parity test fixture.
  .DESCRIPTION
    Test-only cooperative isolation. All paths are explicit and confined to the
    fixed Utilities150 generated fixture root. A process registry AND an exact
    exclusive marker are required for validation/removal; disk markers never
    authorize adoption. ReparsePoint ancestors permit writes by operator policy.
    Removal preflights children without recursive link traversal and retains an
    uncertain fixture. This is not protection against hostile concurrent swaps.
    Dot-sourcing defines only this function; no module is imported here.
  .PARAMETER Operation
    Create, Validate or Remove. Omission fails without prompting.
  .PARAMETER RepositoryRoot
    Independently bound owning repository; must match this helper's location.
  .PARAMETER StatePath
    Exact fixed fixture-root/run-GUID/case-GUID path. No default or fallback.
  .PARAMETER RunId
    Nonempty GUID in N format identifying the run.
  .PARAMETER CaseId
    Nonempty GUID in N format identifying the case.
  .PARAMETER OwnerToken
    Nonempty N-format GUID identifying the caller within this process.
  .PARAMETER Paths
    Explicit named state/input/output paths, each strictly beneath this case.
  .PARAMETER HostNames
    Explicit named host arguments, restricted to fixture-left/fixture-right.
  .OUTPUTS
    PSCustomObject containing status and normalized paths; never production state.
  .EXAMPLE
    Invoke-OwnedParityTestFixture @fixtureParameters -Operation Validate
  .NOTES
    Generated using PesterTestData.instructions.md as guidelines.
    Fixtures are retained unless the exact owner explicitly requests Remove.
  .LINK
    StatePathIsolation.Tests.ps1
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [AllowNull()][AllowEmptyString()][string] $Operation,
    [AllowNull()][AllowEmptyString()][string] $RepositoryRoot,
    [AllowNull()][AllowEmptyString()][string] $StatePath,
    [AllowNull()][AllowEmptyString()][string] $RunId,
    [AllowNull()][AllowEmptyString()][string] $CaseId,
    [AllowNull()][AllowEmptyString()][string] $OwnerToken,
    [AllowNull()][hashtable] $Paths = @{},
    [AllowNull()][hashtable] $HostNames = @{}
  )

  begin {
    $fn = 'Invoke-OwnedParityTestFixture'
    $mn = 'ATAP.Utilities.SystemParityMonitor.PowerShell.Tests'
    $bound = $PSBoundParameters
    # Nested scriptblocks remain local to this function, including all constants.
    $normalize = {
      param([string] $Value)
      if ([string]::IsNullOrWhiteSpace($Value) -or $Value -cne $Value.Trim() -or
        $Value -notmatch '^[A-Za-z]:[\\/]' -or $Value -match '[\x00-\x1f<>"|?*\[\]]' -or
        $Value.Substring(2).Contains(':')) {
        throw 'Path must be an unambiguous local absolute filesystem path.'
      }
      $candidate = $Value.Replace('/', '\').TrimEnd('\')
      foreach ($segment in $candidate.Substring(3).Split('\')) {
        if ([string]::IsNullOrEmpty($segment) -or $segment -in @('.', '..') -or
          $segment.EndsWith('.') -or $segment.EndsWith(' ') -or
          $segment -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)') {
          throw 'Path contains a forbidden or ambiguous component.'
        }
      }
      [IO.Path]::GetFullPath($candidate).TrimEnd('\')
    }
    $isWithin = {
      param([string] $Child, [string] $Parent)
      $Child.StartsWith($Parent.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)
    }
    $assertEntryMetadata = {
      param($Item)
      if ($null -eq $Item -or
        -not $Item.PSObject.Properties['PSIsContainer'] -or $Item.PSIsContainer -isnot [bool] -or
        -not $Item.PSObject.Properties['Attributes'] -or $Item.Attributes -isnot [IO.FileAttributes] -or
        [int64]$Item.Attributes -lt 0) {
        throw 'Literal fixture entry metadata has invalid container or attribute values.'
      }
      $directoryAttribute = ($Item.Attributes -band [IO.FileAttributes]::Directory) -ne 0
      if ($Item.PSIsContainer -ne $directoryAttribute) {
        throw 'Literal fixture entry metadata has inconsistent container attributes.'
      }
      if ($Item.PSIsContainer -and
        (-not $Item.PSObject.Properties['CreationTimeUtc'] -or
          $Item.CreationTimeUtc -isnot [datetime] -or
          $Item.CreationTimeUtc.Kind -ne [DateTimeKind]::Utc -or
          $Item.CreationTimeUtc.Ticks -le [datetime]::MinValue.Ticks -or
          $Item.CreationTimeUtc.Ticks -ge [datetime]::MaxValue.Ticks)) {
        throw 'Literal fixture directory metadata has no usable UTC creation identity.'
      }
      # ReparsePoint is a valid typed flag, not a reason to reject an ancestor.
    }
    $readLiteralEntry = {
      param([string] $Path, [bool] $AllowAbsent)
      # Test-Path false is not an entry/absence oracle. Inspect the literal entry
      # first. Only a typed missing-item error plus an immediate-parent entry
      # check can establish absence; access/provider/ambiguous errors propagate.
      # The caller has already inspected the parent, and never requests absence
      # for the repository root. No recursive enumeration or target probing.
      try {
        $entries = @(Get-Item -LiteralPath $Path -Force -ErrorAction Stop)
      } catch [System.Management.Automation.ItemNotFoundException] {
        if (-not $AllowAbsent) { throw }
        $parent = Split-Path -Path $Path -Parent
        $leaf = Split-Path -Path $Path -Leaf
        if ([string]::IsNullOrWhiteSpace($parent) -or [string]::IsNullOrWhiteSpace($leaf)) {
          throw 'Literal fixture entry absence is ambiguous.'
        }
        $matchingEntries = @(
          foreach ($child in @(Get-ChildItem -LiteralPath $parent -Force -ErrorAction Stop)) {
            if (-not $child.PSObject.Properties['Name'] -or $child.Name -isnot [string] -or
              [string]::IsNullOrWhiteSpace($child.Name)) {
              throw 'Literal parent entry metadata is ambiguous.'
            }
            if ([StringComparer]::OrdinalIgnoreCase.Equals([string]$child.Name, $leaf)) { $child }
          }
        )
        if ($matchingEntries.Count -ne 0) {
          throw 'Literal fixture entry remains unresolved despite a missing-item response; retain evidence.'
        }
        return [pscustomobject]@{ Exists = $false; Item = $null }
      }
      if ($entries.Count -ne 1 -or $null -eq $entries[0] -or
        -not $entries[0].PSObject.Properties['PSIsContainer'] -or
        -not $entries[0].PSObject.Properties['Attributes']) {
        throw 'Literal fixture entry metadata is ambiguous.'
      }
      & $assertEntryMetadata $entries[0]
      [pscustomobject]@{ Exists = $true; Item = $entries[0] }
    }
    $readDirectoryChain = {
      param([string] $Leaf, [bool] $MustExist)
      $relative = $Leaf.Substring($repo.Length).TrimStart('\')
      $chain = @($repo)
      $cursor = $repo
      foreach ($part in $relative.Split('\')) {
        $cursor = Join-Path $cursor $part
        $chain += $cursor
      }
      foreach ($directory in $chain) {
        $allowAbsent = -not $MustExist -and -not [StringComparer]::OrdinalIgnoreCase.Equals($directory, $repo)
        $entryState = & $readLiteralEntry $directory $allowAbsent
        if (-not $entryState.Exists) {
          break
        }
        $item = $entryState.Item
        if (-not $item.PSIsContainer) { throw 'Fixture ancestor is not a directory.' }
        if (([StringComparer]::OrdinalIgnoreCase.Equals($directory, $caseRoot) -or (& $isWithin $directory $caseRoot)) -and
          $item.PSObject.Properties['LinkType'] -and $item.LinkType -in @('Junction', 'SymbolicLink')) {
          throw 'Fixture case or descendant was redirected by an unexpected link.'
        }
        # Dropbox/approved ancestors may carry ReparsePoint. Do not reject writes
        # merely for that attribute or resolve/rewrite their targets.
        [pscustomobject]@{ Path = $directory; CreationTicks = $item.CreationTimeUtc.Ticks }
      }
    }
    $assertOwned = {
      if (-not $registry.ContainsKey($caseRoot)) {
        throw 'No process registry ownership exists; a marker cannot authorize adoption.'
      }
      $entry = $registry[$caseRoot]
      if ($entry.RunId -cne $run -or $entry.CaseId -cne $case -or
        $entry.OwnerToken -cne $owner -or $entry.Status -ne 'Active' -or
        -not [StringComparer]::OrdinalIgnoreCase.Equals($entry.RepositoryRoot, $repo)) {
        throw 'Process registry identity or fixture state does not match this owner.'
      }
      $currentChain = @(& $readDirectoryChain $caseRoot $true)
      if ($currentChain.Count -ne $entry.Ancestors.Count) {
        throw 'Owned fixture ancestor identity changed.'
      }
      for ($index = 0; $index -lt $currentChain.Count; $index++) {
        if (-not [StringComparer]::OrdinalIgnoreCase.Equals($currentChain[$index].Path, $entry.Ancestors[$index].Path) -or
          $currentChain[$index].CreationTicks -ne $entry.Ancestors[$index].CreationTicks) {
          throw 'Owned fixture ancestor identity changed.'
        }
      }
      $markerItem = (& $readLiteralEntry $markerPath $false).Item
      if ($markerItem.PSIsContainer -or
        ($markerItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or
        $markerItem.Length -gt 2048) {
        throw 'Ownership marker is not the expected ordinary bounded file.'
      }
      $marker = Get-Content -LiteralPath $markerPath -Raw -Encoding utf8 -ErrorAction Stop
      if ($marker -cne $entry.MarkerJson) { throw 'Ownership marker is missing, foreign or tampered.' }
      # Recheck every requested destination's existing ancestors. Future suites
      # must validate the whole invocation, including all path-bearing splats.
      foreach ($destination in $normalizedPaths.Values) {
        $parent = Split-Path -Path $destination -Parent
        $parentChain = @(& $readDirectoryChain $parent $false)
        # A definitely absent ancestor implies no descendant entry. Otherwise
        # inspect the final sink literally, even if Test-Path would return false.
        if ($parentChain.Count -gt 0 -and [StringComparer]::OrdinalIgnoreCase.Equals($parentChain[-1].Path, $parent)) {
          $destinationState = & $readLiteralEntry $destination $true
          if ($destinationState.Exists) {
            $targetItem = $destinationState.Item
            if ($targetItem.PSObject.Properties['LinkType'] -and $targetItem.LinkType -in @('Junction', 'SymbolicLink')) {
              throw 'Requested fixture destination is an unexpected link.'
            }
          }
        }
      }
      $entry
    }
  }

  process {
    try {
      foreach ($name in @('Operation', 'RepositoryRoot', 'StatePath', 'RunId', 'CaseId', 'OwnerToken')) {
        if (-not $bound.ContainsKey($name) -or [string]::IsNullOrWhiteSpace([string]$bound[$name])) {
          throw "Explicit $name is required; no default or interactive fallback is permitted."
        }
      }
      if ($Operation -notin @('Create', 'Validate', 'Remove')) { throw 'Unknown fixture operation.' }
      foreach ($token in @($RunId, $CaseId, $OwnerToken)) {
        $parsedToken = [guid]::Empty
        if (-not [guid]::TryParseExact($token, 'N', [ref]$parsedToken) -or $parsedToken -eq [guid]::Empty) {
          throw 'RunId, CaseId and OwnerToken must be nonempty GUIDs in N format.'
        }
      }
      $run = $RunId.ToLowerInvariant()
      $case = $CaseId.ToLowerInvariant()
      $owner = $OwnerToken.ToLowerInvariant()
      $expectedRepo = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-150-Sprint-0017-work-items'
      $repo = & $normalize $RepositoryRoot
      $helperRepo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..')).TrimEnd('\')
      if (-not [StringComparer]::OrdinalIgnoreCase.Equals($repo, $expectedRepo) -or
        -not [StringComparer]::OrdinalIgnoreCase.Equals($repo, $helperRepo)) {
        throw 'RepositoryRoot must match the fixed Utilities150 helper owner.'
      }
      $fixtureRoot = Join-Path $repo '_generated/Sprint0017/17.6.a/StatePathFixtures'
      $runRoot = Join-Path $fixtureRoot $run
      $caseRoot = & $normalize $StatePath
      if (-not [StringComparer]::OrdinalIgnoreCase.Equals($caseRoot, (Join-Path $runRoot $case))) {
        throw 'StatePath must be the exact fixed generated fixture root/run/case path.'
      }
      foreach ($production in @('C:\ProgramData\ATAP\ParityState', 'C:\Dropbox\whertzing\ATAP\ParityState')) {
        if ([StringComparer]::OrdinalIgnoreCase.Equals($caseRoot, $production) -or (& $isWithin $caseRoot $production)) {
          throw 'Production parity state cannot be a test fixture.'
        }
      }
      if ($null -eq $Paths -or $null -eq $HostNames) { throw 'Paths and HostNames cannot be null.' }
      $normalizedPaths = @{}
      $allowedPaths = @('LocalStatePath', 'PeerStatePath', 'LeftStatePath', 'RightStatePath',
        'OutputPath', 'ReportPath', 'SnapshotPath', 'LeftSnapshotPath', 'RightSnapshotPath', 'WhitelistPath')
      foreach ($key in $Paths.Keys) {
        if ($key -notin $allowedPaths -or $Paths[$key] -isnot [string]) { throw 'Unknown or invalid fixture path argument.' }
        $destination = & $normalize $Paths[$key]
        if (-not (& $isWithin $destination $caseRoot)) { throw 'Every supplied path must be a strict descendant of this case.' }
        $reservedMarker = Join-Path $caseRoot '.owned-parity-fixture.json'
        if ([StringComparer]::OrdinalIgnoreCase.Equals($destination, $reservedMarker) -or (& $isWithin $destination $reservedMarker)) {
          throw 'A requested path cannot overwrite the ownership marker.'
        }
        $normalizedPaths[$key] = $destination
      }
      foreach ($key in $HostNames.Keys) {
        if ($key -notin @('HostName', 'PeerHostName', 'LocalHostName', 'LeftHostName', 'RightHostName') -or
          $HostNames[$key] -isnot [string] -or $HostNames[$key] -cnotin @('fixture-left', 'fixture-right')) {
          throw 'Host arguments must be named fixed fixture identifiers, never path fragments.'
        }
      }
      # Required dependency is autoload-or-throw, never an ad-hoc console logger.
      if (-not (Get-Command -Name Write-PSFMessage -ErrorAction SilentlyContinue)) {
        throw 'Write-PSFMessage is required; preload PSFramework in the admitted test runner.'
      }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Validating owned parity fixture operation $Operation."
      $registryVariable = Get-Variable -Name ATAPOwnedParityTestFixtures -Scope Global -ErrorAction SilentlyContinue
      if ($null -eq $registryVariable) {
        $global:ATAPOwnedParityTestFixtures = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::OrdinalIgnoreCase)
      } elseif ($registryVariable.Value -isnot [Collections.Generic.Dictionary[string, object]]) {
        throw 'Process registry has an unexpected type; refusing to replace it.'
      }
      $registry = $global:ATAPOwnedParityTestFixtures
      $markerPath = Join-Path $caseRoot '.owned-parity-fixture.json'
      $status = 'Validated'

      if ($Operation -eq 'Create') {
        if ($registry.ContainsKey($caseRoot)) {
          throw 'Case root already exists or is registered; collision cannot be adopted.'
        }
        $existingChain = @(& $readDirectoryChain $caseRoot $false)
        if ($existingChain.Count -gt 0 -and [StringComparer]::OrdinalIgnoreCase.Equals($existingChain[-1].Path, $caseRoot)) {
          throw 'Case root already exists or is registered; collision cannot be adopted.'
        }
        if ($PSCmdlet.ShouldProcess($caseRoot, 'Create exclusively marked parity test fixture')) {
          # Parent creation is confined; a partial failure retains evidence and
          # never falls back to deleting the parent or a default state path.
          New-Item -ItemType Directory -Path $runRoot -Force -ErrorAction Stop | Out-Null
          New-Item -ItemType Directory -Path $caseRoot -ErrorAction Stop | Out-Null
          $markerJson = [ordered]@{
            SchemaVersion = 1; Task = '17.6.b'; RunId = $run; CaseId = $case
            OwnerToken = $owner; MarkerToken = [guid]::NewGuid().ToString('N')
          } | ConvertTo-Json -Compress
          $stream = $null
          try {
            $stream = [IO.File]::Open($markerPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
            $bytes = [Text.UTF8Encoding]::new($false).GetBytes($markerJson)
            $stream.Write($bytes, 0, $bytes.Length)
            $stream.Flush($true)
          } finally {
            if ($null -ne $stream) { $stream.Dispose() }
          }
          $registry.Add($caseRoot, [pscustomobject]@{
              RepositoryRoot = $repo; RunId = $run; CaseId = $case; OwnerToken = $owner
              MarkerJson = $markerJson; Ancestors = @(& $readDirectoryChain $caseRoot $true); Status = 'Active'
            })
          [void](& $assertOwned)
          $status = 'Created'
        } else { $status = 'Planned' }
      } else {
        $entry = & $assertOwned
        if ($Operation -eq 'Remove') {
          # Preflight the ENTIRE case without -Recurse. Unexpected child links
          # are never followed, even when their targets look harmless.
          $directories = [Collections.Generic.List[object]]::new()
          $files = [Collections.Generic.List[object]]::new()
          $pending = [Collections.Generic.Stack[string]]::new()
          $pending.Push($caseRoot)
          while ($pending.Count -gt 0) {
            $current = $pending.Pop()
            $directory = (& $readLiteralEntry $current $false).Item
            if (-not $directory.PSIsContainer) { throw 'Cleanup directory identity is invalid.' }
            if ($directory.PSObject.Properties['LinkType'] -and $directory.LinkType -in @('Junction', 'SymbolicLink')) {
              throw 'Cleanup refuses a redirected case or child directory.'
            }
            $directories.Add([pscustomobject]@{ Path = $current; CreationTicks = $directory.CreationTimeUtc.Ticks })
            foreach ($child in @(Get-ChildItem -LiteralPath $current -Force -ErrorAction Stop)) {
              & $assertEntryMetadata $child
              if (-not (& $isWithin $child.FullName $caseRoot) -or
                ($child.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw 'Cleanup refuses an unexpected child link or escaped entry; fixture retained.'
              }
              if ($child.PSIsContainer) { $pending.Push($child.FullName) } else {
                $files.Add([pscustomobject]@{
                    Path = $child.FullName; Length = $child.Length; LastWriteTicks = $child.LastWriteTimeUtc.Ticks
                  })
              }
            }
          }
          [void](& $assertOwned)
          if ($PSCmdlet.ShouldProcess($caseRoot, 'Remove only this exact registry-owned marked case')) {
            $entry.Status = 'Removing'
            try {
              # Keep the marker until all other files have been removed. No
              # recursive cmdlet can silently traverse a newly introduced link.
              $orderedFiles = @($files | Sort-Object { [StringComparer]::OrdinalIgnoreCase.Equals($_.Path, $markerPath) })
              foreach ($file in $orderedFiles) {
                $currentFile = (& $readLiteralEntry $file.Path $false).Item
                if ($currentFile.PSIsContainer -or ($currentFile.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or
                  $currentFile.Length -ne $file.Length -or $currentFile.LastWriteTimeUtc.Ticks -ne $file.LastWriteTicks) {
                  throw 'Cleanup file identity changed; remaining evidence retained.'
                }
                Remove-Item -LiteralPath $file.Path -Force -Confirm:$false -ErrorAction Stop
              }
              for ($index = $directories.Count - 1; $index -ge 0; $index--) {
                $planned = $directories[$index]
                $currentDirectory = (& $readLiteralEntry $planned.Path $false).Item
                if (-not $currentDirectory.PSIsContainer -or $currentDirectory.CreationTimeUtc.Ticks -ne $planned.CreationTicks -or
                  ($currentDirectory.PSObject.Properties['LinkType'] -and $currentDirectory.LinkType -in @('Junction', 'SymbolicLink'))) {
                  throw 'Cleanup directory identity changed; remaining evidence retained.'
                }
                if (@(Get-ChildItem -LiteralPath $planned.Path -Force -ErrorAction Stop).Count -ne 0) {
                  throw 'Cleanup directory gained an unexpected entry; remaining evidence retained.'
                }
                Remove-Item -LiteralPath $planned.Path -Force -Confirm:$false -ErrorAction Stop
              }
              [void]$registry.Remove($caseRoot)
              $status = 'Removed'
            } catch {
              $entry.Status = 'CleanupIncomplete'
              throw
            }
          } else { $status = 'Planned' }
        }
      }
      [pscustomobject]@{
        Status = $status; RepositoryRoot = $repo; FixtureRoot = $fixtureRoot
        RunRoot = $runRoot; StatePath = $caseRoot; RunId = $run; CaseId = $case
        Paths = $normalizedPaths; HostNames = $HostNames
      }
    } catch {
      $failure = $_
      # Logging failure must never replace the original ownership/cleanup error.
      try {
        if (Get-Command -Name Write-PSFMessage -ErrorAction SilentlyContinue) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message 'Owned parity fixture operation failed; retain uncertain evidence.'
        }
      } catch { }
      $PSCmdlet.ThrowTerminatingError($failure)
    }
  }

  end { }
}
