function Get-GeneratedRemediationFileSnapshot {
  <#
  .SYNOPSIS
    Observes one explicit local file and its NTFS data streams without modifying it.
  .DESCRIPTION
    RootPath is a supplied capture boundary, not repository identity. Requires a
    quiet producer window. Two matching observations do not exclude ABA changes,
    hard-link aliases or replacement with identical metadata/content. No atomic
    file identity, custody, archive, restore or complete inventory is asserted.
    Read-only acquisition deliberately has no ShouldProcess or Git discovery.
  .PARAMETER RootPath
    Absolute fixed local NTFS capture boundary, with no redirecting ancestors.
  .PARAMETER RelativePath
    Canonical forward-slash file path below _generated/ within the boundary.
  .OUTPUTS
    One acquisition envelope; never a selector-ready or approved manifest.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$RootPath,
    [Parameter(Mandatory)][string]$RelativePath
  )
  begin {
    $fn = 'Get-GeneratedRemediationFileSnapshot'
    $mn = 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell'
    if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
      Import-Module PSFramework -ErrorAction Stop
    }
    $result = [pscustomobject]@{
      Success = $false; Errors = @(); Attempts = @(); Binding = $null
      Observations = @(); Consistent = $false
      InventoryComplete = $false; ReadyForManifest = $false; CustodyVerified = $false
      Limitations = @('Supplied boundary is not Git identity.', 'Non-atomic; quiet producers required; ABA and identical replacements can be missed.',
        'No file identity, hard-link alias, ACL, directory/root ADS, custody or restore proof.')
    }
    $attempts = [Collections.Generic.List[object]]::new()
    $observations = [Collections.Generic.List[object]]::new()

    function assertFileSnapshotSegments([string[]]$Segments) {
      foreach ($segment in $Segments) {
        if (-not $segment -or $segment -in @('.', '..') -or $segment -match '[\x00-\x1f\x7f<>:"|?*]' -or
          $segment -match '[ .]$' -or $segment -match '^(?i:CON|PRN|AUX|NUL|COM[0-9¹²³]|LPT[0-9¹²³])(?:\.|$)') {
          throw [ArgumentException]::new('Invalid or ambiguous path segment.')
        }
      }
    }
    function getFileSnapshotMetadata([string]$Path) {
      $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
      if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -and $null -ne $item.LinkTarget) {
        throw [InvalidOperationException]::new('Redirecting link refused.')
      }
      if ($item.Attributes -band [IO.FileAttributes]::Encrypted) {
        throw [InvalidOperationException]::new('Encrypted source unsupported.')
      }
      return $item
    }
    function getFileSnapshotState {
      # Descend only after checking each parent; never first probe the leaf.
      $current = $driveRoot
      $node = getFileSnapshotMetadata $current
      foreach ($segment in $allSegments) {
        if (-not $node.PSIsContainer) { throw [InvalidOperationException]::new('Non-directory ancestor.') }
        # Root may itself be a Git worktree. Any .git marker below it is a hold.
        if ($current.Length -gt $canonicalRoot.Length) {
          $markers = @(Get-ChildItem -LiteralPath $current -Force -ErrorAction Stop | Where-Object Name -ieq '.git')
          if ($markers.Count) { throw [InvalidOperationException]::new('Nested repository marker refused.') }
        }
        $current = Join-Path $current $segment
        $node = getFileSnapshotMetadata $current
      }
      if ($node.PSIsContainer) { throw [InvalidOperationException]::new('A single regular file is required.') }
      $streams = @(Get-Item -LiteralPath $extendedPath -Stream '*' -Force -ErrorAction Stop)
      $names = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
      $descriptors = [Collections.Generic.List[object]]::new()
      $defaultCount = 0
      foreach ($stream in $streams) {
        $name = [string]$stream.Stream
        if ($name -ceq ':$DATA') { $defaultCount++ }
        elseif (-not $name -or $name -match '[\x00-\x1f\x7f:/\\<>"|?*]' -or $name -match '[ .]$') {
          throw [InvalidOperationException]::new('Invalid stream metadata.')
        }
        if (-not $names.Add($name) -or $null -eq $stream.Length -or $stream.Length -isnot [long] -or $stream.Length -lt 0) {
          throw [InvalidOperationException]::new('Duplicate or invalid stream metadata.')
        }
        $descriptors.Add([pscustomobject]@{ Name = $name; Bytes = $stream.Length })
      }
      if ($defaultCount -ne 1) { throw [InvalidOperationException]::new('Default stream census missing or ambiguous.') }
      $descriptorsArray = @($descriptors | Sort-Object Name -CaseSensitive)
      if (($descriptorsArray | Where-Object Name -CEQ ':$DATA').Bytes -ne $node.Length) {
        throw [InvalidOperationException]::new('Default stream metadata drift.')
      }
      [pscustomobject]@{
        Bytes = $node.Length; LastWriteTicks = $node.LastWriteTimeUtc.Ticks
        CreationTicks = $node.CreationTimeUtc.Ticks; Attributes = [long]$node.Attributes
        Streams = $descriptorsArray
      }
    }
    function getFileSnapshotDigest([string]$Path) {
      $handle = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
      try {
        [pscustomobject]@{ Bytes = $handle.Length; SHA256 = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($handle)) }
      } finally { $handle.Dispose() }
    }
  }
  process {
    try {
      if (-not $IsWindows -or $RootPath -notmatch '^[A-Za-z]:[\\/]' -or $RootPath -match '[\x00-\x1f\x7f]' -or
        $RootPath.Substring(2).Contains(':')) { throw [ArgumentException]::new('Expected absolute local Windows root.') }
      $rootTail = $RootPath.Substring(3).TrimEnd('\', '/')
      if ($rootTail.Contains('\') -and $rootTail.Contains('/')) { throw [ArgumentException]::new('Mixed root separators.') }
      $rootSegments = @($rootTail -split '[\\/]')
      if (-not $rootTail) { throw [ArgumentException]::new('Drive root is not a capture boundary.') }
      assertFileSnapshotSegments $rootSegments
      if (-not $RelativePath.StartsWith('_generated/', [StringComparison]::Ordinal) -or $RelativePath.Contains('\')) {
        throw [ArgumentException]::new('Expected canonical _generated/ relative file path.')
      }
      $relativeSegments = @($RelativePath.Split('/'))
      assertFileSnapshotSegments $relativeSegments
      if (@($relativeSegments | Where-Object { $_ -ieq '.git' }).Count) { throw [ArgumentException]::new('Git control path refused.') }
      $driveRoot = $RootPath.Substring(0, 2) + '\'
      $drive = [IO.DriveInfo]::new($driveRoot)
      if ($drive.DriveType -ne [IO.DriveType]::Fixed -or $drive.DriveFormat -ne 'NTFS') {
        throw [InvalidOperationException]::new('Only fixed local NTFS is supported.')
      }
      $canonicalRoot = [IO.Path]::GetFullPath($RootPath).TrimEnd('\', '/')
      $filePath = Join-Path $canonicalRoot $RelativePath
      $extendedPath = '\\?\' + $filePath.Replace('/', '\')
      $allSegments = @($rootSegments) + @($relativeSegments)
      $result.Binding = [pscustomobject]@{ Root = $canonicalRoot; RelativePath = $RelativePath; Path = $filePath }
      $baselineState = $null
      for ($pass = 1; $pass -le 2; $pass++) {
        for ($attempt = 1; $attempt -le 3; $attempt++) {
          try {
            $before = getFileSnapshotState
            $stateJson = ConvertTo-Json -InputObject $before -Depth 6 -Compress
            if ($null -eq $baselineState) { $baselineState = $stateJson }
            elseif ($stateJson -cne $baselineState) { throw [InvalidOperationException]::new('Metadata or stream-set drift.') }
            $captured = @(foreach ($descriptor in $before.Streams) {
              $streamPath = if ($descriptor.Name -ceq ':$DATA') { $extendedPath } else { $extendedPath + ':' + $descriptor.Name }
              $digest = getFileSnapshotDigest $streamPath
              if ($digest.Bytes -ne $descriptor.Bytes) { throw [InvalidOperationException]::new('Stream length drift.') }
              [pscustomobject]@{ Name = $descriptor.Name; Bytes = $digest.Bytes; SHA256 = $digest.SHA256 }
            })
            $after = getFileSnapshotState
            if ((ConvertTo-Json -InputObject $after -Depth 6 -Compress) -cne $stateJson) {
              throw [InvalidOperationException]::new('Metadata or stream-set drift.')
            }
            $observation = [pscustomobject]@{ Metadata = $before; Streams = $captured }
            if ($observations.Count -and (ConvertTo-Json $observation -Depth 8 -Compress) -cne (ConvertTo-Json $observations[0] -Depth 8 -Compress)) {
              throw [InvalidOperationException]::new('Content drift between observations.')
            }
            $observations.Add($observation)
            $attempts.Add([pscustomobject]@{ Pass = $pass; Attempt = $attempt; Success = $true; Error = $null; Retry = $false })
            break
          } catch {
            $cause = $_.Exception
            while ($cause.InnerException) { $cause = $cause.InnerException }
            # Only sharing/lock violations and access-denied are plausibly transient.
            $nativeCode = $cause.HResult -band 0xffff
            $retry = (($cause -is [IO.IOException] -and $nativeCode -in @(32, 33)) -or $cause -is [UnauthorizedAccessException]) -and $attempt -lt 3
            $attempts.Add([pscustomobject]@{ Pass = $pass; Attempt = $attempt; Success = $false; Error = $cause.Message; Retry = $retry })
            if (-not $retry) { throw }
            Start-Sleep -Milliseconds (500 * $attempt)
          }
        }
      }
      $result.Consistent = $true
      $result.Success = $true
    } catch {
      $result.Errors = @($_.Exception.Message)
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'File snapshot refused; see structured errors.'
    }
    $result.Attempts = @($attempts.ToArray())
    $result.Observations = @($observations.ToArray())
    $result
  }
  end { }
}
