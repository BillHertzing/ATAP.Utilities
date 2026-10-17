function Get-GeneratedRemediationTreeCensus {
  <#
  .SYNOPSIS
    Collects two bounded structural observations of an explicit _generated tree.
  .DESCRIPTION
    Supplied RootPath is not Git identity. No data or ADS is opened. One-level
    enumeration includes hidden entries; iterative descent stops at holds.
    Matching metadata is not atomic, file identity, custody or deletion proof.
    Requires quiet producers; ABA and provider side effects remain possible.
    Retries restart a whole walk, at most three attempts per observation.
    Applicable ambient parameter defaults are rejected without evaluating their
    values. Caller defaults are never modified, including disabled dictionaries.
    Read-only acquisition deliberately omits ShouldProcess and Git discovery.
  .PARAMETER RootPath
    Absolute fixed local NTFS capture boundary containing _generated.
  .PARAMETER MaxEntries
    Maximum entries including the _generated root. Reaching beyond it fails.
  .PARAMETER MaxDepth
    Maximum descendant depth; _generated has depth zero. Exceeding it fails.
  .OUTPUTS
    One envelope; only StructuralInventoryComplete can become true.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$RootPath,
    [ValidateRange(1, 1000000)][int]$MaxEntries = 100000,
    [ValidateRange(1, 1024)][int]$MaxDepth = 128
  )
  begin {
    $fn = 'Get-GeneratedRemediationTreeCensus'
    $mn = 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell'
    $loggingReady = $false
    $result = [pscustomobject]@{
      Success = $false; RootState = 'NotObserved'; Binding = $null
      Observations = @(); FailedWalks = @(); Attempts = @(); Errors = @(); Consistent = $false
      StructuralInventoryComplete = $false; InventoryComplete = $false
      ReadyForManifest = $false; CustodyVerified = $false
      Limitations = @('Supplied boundary is not Git identity.', 'Non-atomic metadata only; quiet producers required; ABA and identical replacements can be missed.',
        'No file identity, data/ADS, custody, physical emptiness or deletion readiness proof; provider metadata access may have side effects.')
    }
    $observations = [Collections.Generic.List[object]]::new()
    $failedWalks = [Collections.Generic.List[object]]::new()
    $attempts = [Collections.Generic.List[object]]::new()
    function assertCensusName([string]$Name) {
      if (-not $Name -or $Name -in @('.', '..') -or $Name -match '[\x00-\x1f\x7f<>:"|?*\\/]' -or
        $Name -match '[ .]$' -or $Name -match '^(?i:CON|PRN|AUX|NUL|COM[0-9¹²³]|LPT[0-9¹²³])(?:\.|$)') {
        throw [ArgumentException]::new('Invalid or ambiguous path name.')
      }
    }
    function getCensusClassification($Item) {
      $attributes = [long]$Item.Attributes
      if ($attributes -band [long][IO.FileAttributes]::ReparsePoint) {
        if ($null -ne $Item.LinkTarget) { return 'RedirectingLink' }
        return 'UnsupportedReparsePoint'
      }
      if ($attributes -band [long][IO.FileAttributes]::Encrypted) { return 'Encrypted' }
      # Offline, recall/provider-specific and unknown bits are deliberately held.
      $allowed = 1 -bor 2 -bor 4 -bor 16 -bor 32 -bor 128 -bor 256 -bor 512 -bor 2048 -bor 8192
      if ($attributes -band (-bnot $allowed)) { return 'UnsupportedAttributes' }
      if ($Item.PSIsContainer) { return 'Directory' }
      if ($Item -is [IO.FileInfo]) { return 'File' }
      return 'UnsupportedType'
    }
    function getCensusGuardedItem([string]$Relative) {
      $current = $driveRoot
      $segments = @($rootSegments) + @($Relative.Split('/'))
      $node = Get-Item -LiteralPath $current -Force -ErrorAction Stop
      foreach ($segment in $segments) {
        if ((getCensusClassification $node) -ne 'Directory') { throw [InvalidOperationException]::new('Unsafe or non-directory ancestor.') }
        $current = Join-Path $current $segment
        $node = Get-Item -LiteralPath $current -Force -ErrorAction Stop
      }
      return $node
    }
    function getCensusRow($Item, [string]$Relative, [int]$Depth) {
      $kind = getCensusClassification $Item
      [pscustomobject]@{
        RelativePath = $Relative; Depth = $Depth; Kind = $kind
        Attributes = [long]$Item.Attributes; LastWriteTicks = $Item.LastWriteTimeUtc.Ticks
        CreationTicks = $Item.CreationTimeUtc.Ticks
        Length = if ($kind -eq 'File') { $Item.Length } else { $null }
        Hold = ($kind -notin @('File', 'Directory'))
      }
    }
    function getCensusSortedRows($Rows) {
      $byName = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
      foreach ($row in $Rows) { $byName.Add($row.RelativePath, $row) }
      $keys = [string[]]@($byName.Keys)
      [Array]::Sort($keys, [StringComparer]::Ordinal)
      foreach ($key in $keys) { $byName[$key] }
    }
  }
  process {
    try {
      # Even explicit recursion switches cannot neutralize Filter/Name/Stream or
      # wildcard defaults. Inspect keys only, before discovery or target access;
      # scriptblock default values must never execute inside this acquisition.
      foreach ($defaultKey in $PSDefaultParameterValues.Keys) {
        if ([string]$defaultKey -ieq 'Disabled') { continue }
        $separator = ([string]$defaultKey).IndexOf(':')
        if ($separator -lt 1) { throw [InvalidOperationException]::new('Unsupported ambient parameter-default key.') }
        # These exact profile defaults cannot bind to any command guarded below.
        # Do not ignore wildcard/abbreviated parameter patterns or inspect values.
        $parameterPattern = ([string]$defaultKey).Substring($separator + 1).Trim()
        if ($parameterPattern -in @('Encoding', 'Settings')) { continue }
        $commandPattern = ([string]$defaultKey).Substring(0, $separator).Trim()
        $matcher = [Management.Automation.WildcardPattern]::new($commandPattern, [Management.Automation.WildcardOptions]::IgnoreCase)
        foreach ($commandName in @('Get-Item', 'Get-ChildItem', 'gi', 'gci', 'dir', 'ls',
          'Microsoft.PowerShell.Management\Get-Item', 'Microsoft.PowerShell.Management\Get-ChildItem',
          'Get-Command', 'gcm', 'Microsoft.PowerShell.Core\Get-Command',
          'Import-Module', 'ipmo', 'Microsoft.PowerShell.Core\Import-Module')) {
          if ($matcher.IsMatch($commandName)) { throw [InvalidOperationException]::new('Applicable ambient parameter defaults are unsupported.') }
        }
      }
      if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) { Import-Module PSFramework -ErrorAction Stop }
      $loggingReady = $true
      if (-not $IsWindows -or $RootPath -notmatch '^[A-Za-z]:[\\/]' -or $RootPath -match '[\x00-\x1f\x7f]' -or
        $RootPath.Substring(2).Contains(':')) { throw [ArgumentException]::new('Expected absolute local Windows root.') }
      $rootTail = $RootPath.Substring(3).TrimEnd('\', '/')
      if (-not $rootTail -or ($rootTail.Contains('\') -and $rootTail.Contains('/'))) { throw [ArgumentException]::new('Ambiguous capture boundary.') }
      $rootSegments = @($rootTail -split '[\\/]')
      foreach ($segment in $rootSegments) { assertCensusName $segment }
      $driveRoot = $RootPath.Substring(0, 2) + '\'
      $drive = [IO.DriveInfo]::new($driveRoot)
      if ($drive.DriveType -ne [IO.DriveType]::Fixed -or $drive.DriveFormat -ne 'NTFS') { throw [InvalidOperationException]::new('Fixed local NTFS required.') }
      $canonicalRoot = [IO.Path]::GetFullPath($RootPath).TrimEnd('\', '/')
      $result.Binding = [pscustomobject]@{ Root = $canonicalRoot; RelativePath = '_generated'; MaxEntries = $MaxEntries; MaxDepth = $MaxDepth }
      for ($pass = 1; $pass -le 2; $pass++) {
        for ($attempt = 1; $attempt -le 3; $attempt++) {
          $rows = [Collections.Generic.List[object]]::new()
          try {
            # Verify ancestors before enumerating the capture boundary for target presence.
            $boundary = getCensusGuardedItem ''
            if ((getCensusClassification $boundary) -ne 'Directory') { throw [InvalidOperationException]::new('Unsafe capture boundary.') }
            $rootMatches = @(Get-ChildItem -LiteralPath $canonicalRoot -Force -Recurse:$false -FollowSymlink:$false -ErrorAction Stop | Where-Object Name -ieq '_generated')
            if ($rootMatches.Count -eq 0) { $result.RootState = 'Missing'; throw [InvalidOperationException]::new('Target root missing; not an empty census.') }
            if ($rootMatches.Count -ne 1 -or $rootMatches[0].Name -cne '_generated') { throw [InvalidOperationException]::new('Target root spelling/alias ambiguity.') }
            $result.RootState = 'Present'
            $rootItem = getCensusGuardedItem '_generated'
            $rootRow = getCensusRow $rootItem '_generated' 0
            if ($rootRow.Kind -eq 'File') { $rootRow.Kind = 'NonDirectoryRoot'; $rootRow.Hold = $true }
            $rows.Add($rootRow)
            $queue = [Collections.Generic.Queue[object]]::new()
            if (-not $rootRow.Hold) { $queue.Enqueue($rootRow) }
            while ($queue.Count) {
              $parent = $queue.Dequeue()
              $before = getCensusRow (getCensusGuardedItem $parent.RelativePath) $parent.RelativePath $parent.Depth
              if ((ConvertTo-Json $before -Compress) -cne (ConvertTo-Json $parent -Compress)) { throw [InvalidOperationException]::new('Directory metadata drift before read.') }
              $path = Join-Path $canonicalRoot $parent.RelativePath
              $children = @(Get-ChildItem -LiteralPath $path -Force -Recurse:$false -FollowSymlink:$false -ErrorAction Stop)
              $names = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
              foreach ($child in $children) {
                assertCensusName $child.Name
                if (-not $names.Add($child.Name)) { throw [InvalidOperationException]::new('Case-alias or duplicate child entry.') }
              }
              $after = getCensusRow (getCensusGuardedItem $parent.RelativePath) $parent.RelativePath $parent.Depth
              if ((ConvertTo-Json $after -Compress) -cne (ConvertTo-Json $before -Compress)) { throw [InvalidOperationException]::new('Directory metadata drift after read.') }
              # Name-only conservative boundaries: never inspect .git, HEAD, objects or refs contents.
              if ($names.Contains('.git') -or ($names.Contains('HEAD') -and $names.Contains('objects') -and $names.Contains('refs'))) {
                $parent.Kind = if ($names.Contains('.git')) { 'NestedRepository' } else { 'PossibleBareRepository' }
                $parent.Hold = $true
                continue
              }
              foreach ($child in $children) {
                if ($rows.Count -ge $MaxEntries) { throw [InvalidOperationException]::new('MaxEntries exceeded; census incomplete.') }
                $depth = $parent.Depth + 1
                if ($depth -gt $MaxDepth) { throw [InvalidOperationException]::new('MaxDepth exceeded; census incomplete.') }
                $relative = $parent.RelativePath + '/' + $child.Name
                # NTFS directory enumeration can return cached timestamps. Obtain
                # fresh metadata for regular children, behind all ancestor guards.
                # Held entries use enumeration metadata and are never followed.
                $row = getCensusRow $child $relative $depth
                if (-not $row.Hold) { $row = getCensusRow (getCensusGuardedItem $relative) $relative $depth }
                $rows.Add($row)
                if ($row.Kind -eq 'Directory') { $queue.Enqueue($row) }
              }
            }
            $observation = [pscustomobject]@{ Rows = @(getCensusSortedRows $rows); Holds = @($rows | Where-Object Hold).Count }
            $observations.Add($observation)
            $attempts.Add([pscustomobject]@{Pass=$pass;Attempt=$attempt;Success=$true;Error=$null;Retry=$false})
            break
          } catch {
            $cause = $_.Exception
            while ($cause.InnerException) { $cause = $cause.InnerException }
            $code = $cause.HResult -band 0xffff
            $retry = (($cause -is [UnauthorizedAccessException]) -or ($cause -is [IO.IOException] -and $code -in @(32, 33))) -and $attempt -lt 3
            $failedWalks.Add([pscustomobject]@{Pass=$pass;Attempt=$attempt;PartialRows=@(getCensusSortedRows $rows);Error=$cause.Message})
            $attempts.Add([pscustomobject]@{Pass=$pass;Attempt=$attempt;Success=$false;Error=$cause.Message;Retry=$retry})
            if (-not $retry) { throw }
            Start-Sleep -Milliseconds (500 * $attempt)
          }
        }
      }
      if ((ConvertTo-Json $observations[0] -Depth 8 -Compress) -cne (ConvertTo-Json $observations[1] -Depth 8 -Compress)) {
        throw [InvalidOperationException]::new('Structural drift between observations.')
      }
      $result.Consistent = $true
      $result.Success = $true
      $result.StructuralInventoryComplete = ($observations[0].Holds -eq 0 -and $failedWalks.Count -eq 0)
    } catch {
      $result.Errors = @($_.Exception.Message)
      if ($loggingReady) { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Structural census refused; see structured errors.' }
    }
    $result.Observations = @($observations.ToArray())
    $result.FailedWalks = @($failedWalks.ToArray())
    $result.Attempts = @($attempts.ToArray())
    $result
  }
  end { }
}
