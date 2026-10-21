function New-GeneratedRemediationDirectoryArchive {
  <#
  .SYNOPSIS
    Archives only the named streams of one explicit directory.
  .DESCRIPTION
    Root _generated and descendants require separate calls. No children are
    enumerated or copied and unnamed directory data is never opened. Zero named
    streams is valid. Only an exact zero-length :$DATA provider marker is excluded.
    Limits: 64 named streams, 64 MiB total payload/archive, 64 KiB manifest/buffer.
    Rechecks and readback prove this directory only; partial outputs are retained.
    Quiet producers are required; non-atomic observations can miss ABA/alias races.
  .PARAMETER RootPath
    Existing absolute fixed-local NTFS source boundary.
  .PARAMETER RelativePath
    Exactly _generated or a canonical forward-slash descendant directory.
  .PARAMETER ArchivePath
    NEW external file with an existing ordinary parent.
  .OUTPUTS
    One-directory observations; all global coverage/readiness flags false.
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [Parameter(Mandatory)][string]$RootPath,
    [Parameter(Mandatory)][string]$RelativePath,
    [Parameter(Mandatory)][string]$ArchivePath
  )
  begin {
    $fn = 'New-GeneratedRemediationDirectoryArchive'
    $mn = 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell'
    if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) { Import-Module PSFramework -ErrorAction Stop }

    # v1 limits: 64 named streams, 64 MiB uncompressed, 64 KiB manifest.
    $byteLimit = 67108864L
    function assertArchiveSegment([string]$Segment) {
      # Conservative filesystem-device refusal, including spaces before an extension.
      $stem = ($Segment -split '\.', 2)[0].TrimEnd(' ')
      if (-not $Segment -or $Segment -in @('.', '..') -or $Segment -ieq '.git' -or
        $Segment -match '[\x00-\x1f\x7f<>:"|?*~]' -or $Segment -match '[ .]$' -or
        $stem -match '\A(?i:CON|CONIN\$|CONOUT\$|CLOCK\$|PRN|AUX|NUL|COM[0-9\u00b9\u00b2\u00b3]|LPT[0-9\u00b9\u00b2\u00b3])\z') { throw 'Unsafe archive path segment.' }
    }
    function getArchiveLocalPath([string]$Path, [bool]$NewLeaf, [bool]$Directory) {
      if (-not $IsWindows -or $Path -notmatch '\A[A-Za-z]:[\\/]' -or $Path.Substring(2).Contains(':')) { throw 'Expected fixed local NTFS path.' }
      $tail = $Path.Substring(3).TrimEnd('\', '/')
      if (-not $tail) { throw 'A drive root is not a boundary.' }
      $segments = @($tail -split '[\\/]')
      foreach ($segment in $segments) { assertArchiveSegment $segment }
      $drive = [IO.DriveInfo]::new($Path.Substring(0, 3))
      if ($drive.DriveType -ne [IO.DriveType]::Fixed -or $drive.DriveFormat -ne 'NTFS') { throw 'Only fixed local NTFS is supported.' }
      $full = [IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
      $current = [IO.Path]::GetPathRoot($full)
      for ($i = 0; $i -lt $segments.Count; $i++) {
        $current = Join-Path $current $segments[$i]
        if ($NewLeaf -and $i -eq $segments.Count - 1) {
          if (Test-Path -LiteralPath $current -ErrorAction Stop) { throw 'Output already exists; no overwrite.' }
          break
        }
        $node = Get-Item -LiteralPath $current -Force -ErrorAction Stop
        if (($node.Attributes -band [IO.FileAttributes]::ReparsePoint) -and $null -ne $node.LinkTarget) { throw 'Redirecting archive ancestor refused.' }
        if ($i -lt $segments.Count - 1 -and -not $node.PSIsContainer) { throw 'Non-directory archive ancestor.' }
        if ($i -eq $segments.Count - 1) {
          if ($Directory -ne [bool]$node.PSIsContainer) { throw 'Unsupported archive boundary shape.' }
          if (-not $Directory -and ($node.Attributes -band ([IO.FileAttributes]::ReparsePoint -bor [IO.FileAttributes]::Offline -bor [IO.FileAttributes]::Encrypted -bor [IO.FileAttributes]::Device))) { throw 'Unsupported source file state.' }
        }
      }
      $full
    }
    function assertArchiveRelative([string]$Relative) {
      if (($Relative -cne '_generated' -and -not $Relative.StartsWith('_generated/', [StringComparison]::Ordinal)) -or $Relative.Contains('\')) { throw 'Expected canonical _generated directory path.' }
      foreach ($segment in $Relative.Split('/')) { assertArchiveSegment $segment }
    }
    function testArchiveOverlap([string]$Left, [string]$Right) {
      $Left -ieq $Right -or $Left.StartsWith($Right + '\', [StringComparison]::OrdinalIgnoreCase) -or
        $Right.StartsWith($Left + '\', [StringComparison]::OrdinalIgnoreCase)
    }
    function assertArchiveStreamName([string]$Name) {
      if ($Name -ceq ':$DATA') { throw 'Unnamed directory payload is unsupported.' }
      if (-not $Name -or $Name -in @('.', '..') -or $Name -match '[\x00-\x1f\x7f:/\\<>"|?*]' -or $Name -match '[ .]$') { throw 'Unsafe named stream.' }
    }
    function getArchiveDirectoryState([string]$Path) {
      $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
      if (-not $item.PSIsContainer -or
        (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -and $null -ne $item.LinkTarget) -or
        ($item.Attributes -band ([IO.FileAttributes]::Offline -bor [IO.FileAttributes]::Encrypted -bor [IO.FileAttributes]::Device))) { throw 'Unsupported source directory state.' }
      $streams = @(Get-Item -LiteralPath $Path -Stream '*' -Force -ErrorAction Stop)
      if ($streams.Count -gt 65) { throw 'Stream count limit.' }
      $names = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
      $total = 0L; $markerCount = 0
      $rows = @(foreach ($stream in $streams) {
        $name = [string]$stream.Stream
        if ($name -ceq ':$DATA') {
          $markerCount++
          if ($markerCount -gt 1 -or $stream.Length -isnot [long] -or $stream.Length -ne 0) { throw 'Unsupported directory default marker.' }
          continue
        }
        assertArchiveStreamName $name
        if (-not $names.Add($name) -or $stream.Length -isnot [long] -or $stream.Length -lt 0 -or $names.Count -gt 64) { throw 'Invalid directory stream census.' }
        $total += $stream.Length
        if ($total -gt $byteLimit) { throw 'Uncompressed byte limit.' }
        [pscustomobject]@{ Name = $name; Bytes = $stream.Length }
      })
      [pscustomobject]@{ Creation = $item.CreationTimeUtc.Ticks; Written = $item.LastWriteTimeUtc.Ticks
        Attributes = [long]$item.Attributes; Streams = @($rows | Sort-Object Name -CaseSensitive) }
    }
    function copyArchiveData([IO.Stream]$InputStream, [IO.Stream]$OutputStream) {
      $buffer = [byte[]]::new(65536)
      $hash = [Security.Cryptography.IncrementalHash]::CreateHash([Security.Cryptography.HashAlgorithmName]::SHA256)
      $bytes = 0L
      try {
        while (($count = $InputStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
          $bytes += $count
          if ($bytes -gt $byteLimit) { throw 'Actual payload exceeds byte limit.' }
          $hash.AppendData($buffer, 0, $count)
          if ($null -ne $OutputStream) { $OutputStream.Write($buffer, 0, $count) }
        }
        [pscustomobject]@{ Bytes = $bytes; SHA256 = [Convert]::ToHexString($hash.GetHashAndReset()) }
      } finally { $hash.Dispose() }
    }
    function getArchiveDigest([string]$Path) {
      $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
      try { copyArchiveData $stream $null } finally { $stream.Dispose() }
    }

  }
  process {
    $result = [pscustomobject]@{
      Status = 'Hold'; Errors = @(); ArchivePath = $null; ArchiveSHA256 = $null
      ArchiveCreated = $false; DirectoryArchiveVerified = $false; DirectoryRestoreVerified = $false
      NamedStreamCount = 0; Branch = $null; Manifest = $null
      Approved = $false; ReadyForRemoval = $false; CustodyVerified = $false
      DirectoryStreamsVerified = $false; RootStreamsVerified = $false
      Limitations = @('One explicit directory named data only; no children, ACL, identity or whole-tree proof.',
        'Non-atomic observations; quiet producers required, ABA and aliases can be missed.', 'Partial output is retained on failure.')
    }
    $zip = $null; $archiveStream = $null
    try {
      assertArchiveRelative $RelativePath
      $root = getArchiveLocalPath $RootPath $false $true
      $source = getArchiveLocalPath (Join-Path $root $RelativePath) $false $true
      # Explicitly refuse nested repositories below the capture root.
      $parent = $source
      while ($parent.Length -gt $root.Length) {
        if (Test-Path -LiteralPath (Join-Path $parent '.git') -ErrorAction Stop) { throw 'Nested repository boundary.' }
        $parent = Split-Path -Parent $parent
      }
      $archive = getArchiveLocalPath $ArchivePath $true $false
      if (testArchiveOverlap $root $archive) { throw 'Archive overlaps source boundary.' }
      $before = getArchiveDirectoryState $source
      $result.NamedStreamCount = $before.Streams.Count
      $result.Branch = if ($result.NamedStreamCount) { 'NamedStreamsPresent' } else { 'NoNamedStreams' }
      if (-not $PSCmdlet.ShouldProcess($archive, 'Create one-directory named-stream archive')) { $result.Status = 'Skipped'; return $result }
      $archiveStream = [IO.File]::Open($archive, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
      $result.ArchiveCreated = $true; $result.ArchivePath = $archive
      $zip = [IO.Compression.ZipArchive]::new($archiveStream, [IO.Compression.ZipArchiveMode]::Create, $true)
      $descriptors = [Collections.Generic.List[object]]::new()
      $index = 0
      foreach ($stream in $before.Streams) {
        $entryName = 'data/{0:D4}.bin' -f $index
        $inputPath = $source + ':' + $stream.Name
        $payloadInput = [IO.File]::Open($inputPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
        $output = $null
        try {
          $output = $zip.CreateEntry($entryName, [IO.Compression.CompressionLevel]::Optimal).Open()
          $digest = copyArchiveData $payloadInput $output
          if ($digest.Bytes -ne $stream.Bytes) { throw 'Source length drift during copy.' }
          $descriptors.Add([pscustomobject]@{ Name = $stream.Name; Bytes = $digest.Bytes; SHA256 = $digest.SHA256; Entry = $entryName })
        } finally { if ($null -ne $output) { $output.Dispose() }; $payloadInput.Dispose() }
        $index++
      }
      $manifest = [pscustomobject]@{ Version = 1; SourceKind = 'DirectoryNamedStreams'; SourceRoot = $root; RelativePath = $RelativePath; Streams = @($descriptors) }
      $jsonBytes = [Text.Encoding]::UTF8.GetBytes(($manifest | ConvertTo-Json -Depth 6 -Compress))
      if ($jsonBytes.Length -gt 65536) { throw 'Manifest limit.' }
      $manifestStream = $zip.CreateEntry('manifest.json').Open()
      try { $manifestStream.Write($jsonBytes, 0, $jsonBytes.Length) } finally { $manifestStream.Dispose() }
      $zip.Dispose(); $zip = $null
      $after = getArchiveDirectoryState $source
      if (($before | ConvertTo-Json -Depth 5 -Compress) -cne ($after | ConvertTo-Json -Depth 5 -Compress)) { throw 'Source metadata/stream-set drift.' }
      foreach ($descriptor in $descriptors) {
        $path = $source + ':' + $descriptor.Name
        $actual = getArchiveDigest $path
        if ($actual.Bytes -ne $descriptor.Bytes -or $actual.SHA256 -cne $descriptor.SHA256) { throw 'Source content drift.' }
      }
      $finalState = getArchiveDirectoryState $source
      if (($before | ConvertTo-Json -Depth 5 -Compress) -cne ($finalState | ConvertTo-Json -Depth 5 -Compress)) { throw 'Source metadata/stream-set drift.' }
      $archiveStream.Position = 0
      $zip = [IO.Compression.ZipArchive]::new($archiveStream, [IO.Compression.ZipArchiveMode]::Read, $true)
      if ($zip.Entries.Count -ne $descriptors.Count + 1) { throw 'Archive membership mismatch.' }
      $manifestReadback = $zip.GetEntry('manifest.json').Open()
      try { $manifestDigest = copyArchiveData $manifestReadback $null } finally { $manifestReadback.Dispose() }
      if ($manifestDigest.Bytes -ne $jsonBytes.Length -or
        $manifestDigest.SHA256 -cne [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($jsonBytes))) {
        throw 'Archive manifest readback mismatch.'
      }
      foreach ($descriptor in $descriptors) {
        $entryStream = $zip.GetEntry($descriptor.Entry).Open()
        try { $actual = copyArchiveData $entryStream $null } finally { $entryStream.Dispose() }
        if ($actual.Bytes -ne $descriptor.Bytes -or $actual.SHA256 -cne $descriptor.SHA256) { throw 'Archive payload verification failed.' }
      }
      $zip.Dispose(); $zip = $null
      $archiveStream.Position = 0
      $result.ArchiveSHA256 = (copyArchiveData $archiveStream $null).SHA256
      $result.Manifest = $manifest; $result.DirectoryArchiveVerified = $true; $result.Status = 'Verified'
    } catch {
      $result.Errors = @($_.Exception.Message)
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Directory archive held; partial outputs retained.'
    } finally {
      if ($null -ne $zip) { $zip.Dispose() }
      if ($null -ne $archiveStream) { $archiveStream.Dispose() }
    }
    $result
  }
  end { }
}

