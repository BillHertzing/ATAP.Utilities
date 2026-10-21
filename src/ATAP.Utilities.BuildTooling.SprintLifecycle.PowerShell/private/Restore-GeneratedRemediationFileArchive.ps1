function Restore-GeneratedRemediationFileArchive {
  <#
  .SYNOPSIS
    Validates a pinned one-file archive before creating a new proof restore.
  .DESCRIPTION
    v1 requires the exact manifest schema and entry set, at most 64 streams and
    64 MiB total, 64 KiB manifest and 64 MiB archive. Every payload digest is
    checked before output creation, then actual restored bytes and stream
    membership are checked. Only named streams declared present are acquired.
    Partial proof output is retained. Non-atomic ancestry checks require quiet
    producers; no ACL, file identity, directory/root or whole-tree proof.
  .PARAMETER RootPath
    Existing source boundary, supplied only for non-overlap validation.
  .PARAMETER ArchivePath
    Existing one-file archive outside RootPath.
  .PARAMETER ExpectedArchiveSHA256
    Mandatory independently supplied archive digest, exactly 64 hexadecimal digits.
  .PARAMETER ProofRoot
    NEW external NTFS proof directory with an existing ordinary parent.
  .OUTPUTS
    One file-specific restore envelope with global custody/readiness flags false.
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [Parameter(Mandatory)][string]$RootPath,
    [Parameter(Mandatory)][string]$ArchivePath,
    [Parameter(Mandatory)][string]$ExpectedArchiveSHA256,
    [Parameter(Mandatory)][string]$ProofRoot
  )
  begin {
    $fn = 'Restore-GeneratedRemediationFileArchive'
    $mn = 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell'
    if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) { Import-Module PSFramework -ErrorAction Stop }

    # v1 limits: 64 streams including default, 64 MiB uncompressed, 64 KiB manifest.
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
      if (-not $Relative.StartsWith('_generated/', [StringComparison]::Ordinal) -or $Relative.Contains('\')) { throw 'Expected canonical _generated/ file path.' }
      foreach ($segment in $Relative.Split('/')) { assertArchiveSegment $segment }
    }
    function testArchiveOverlap([string]$Left, [string]$Right) {
      $Left -ieq $Right -or $Left.StartsWith($Right + '\', [StringComparison]::OrdinalIgnoreCase) -or
        $Right.StartsWith($Left + '\', [StringComparison]::OrdinalIgnoreCase)
    }
    function assertArchiveStreamName([string]$Name) {
      if ($Name -ceq ':$DATA') { return }
      if (-not $Name -or $Name -in @('.', '..') -or $Name -match '[\x00-\x1f\x7f:/\\<>"|?*]' -or $Name -match '[ .]$') { throw 'Unsafe named stream.' }
    }
    function getArchiveFileState([string]$Path) {
      $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
      if ($item.PSIsContainer -or ($item.Attributes -band ([IO.FileAttributes]::ReparsePoint -bor [IO.FileAttributes]::Offline -bor [IO.FileAttributes]::Encrypted -bor [IO.FileAttributes]::Device))) { throw 'Unsupported source file state.' }
      $streams = @(Get-Item -LiteralPath $Path -Stream '*' -Force -ErrorAction Stop)
      if ($streams.Count -lt 1 -or $streams.Count -gt 64) { throw 'Stream count limit or missing census.' }
      $names = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
      $total = 0L; $defaultCount = 0
      $rows = @(foreach ($stream in $streams) {
        $name = [string]$stream.Stream
        assertArchiveStreamName $name
        if (-not $names.Add($name) -or $null -eq $stream.Length -or $stream.Length -lt 0) { throw 'Invalid stream census.' }
        if ($name -ceq ':$DATA') { $defaultCount++ }
        $total += [long]$stream.Length
        if ($total -gt $byteLimit) { throw 'Uncompressed byte limit.' }
        [pscustomobject]@{ Name = $name; Bytes = [long]$stream.Length }
      })
      if ($defaultCount -ne 1 -or ($rows | Where-Object Name -CEQ ':$DATA').Bytes -ne $item.Length) { throw 'Default stream census mismatch.' }
      [pscustomobject]@{ Bytes = [long]$item.Length; Creation = $item.CreationTimeUtc.Ticks; Written = $item.LastWriteTimeUtc.Ticks
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

    function assertManifestFields([System.Text.Json.JsonElement]$Node, [string[]]$Fields) {
      if ($Node.ValueKind -ne [System.Text.Json.JsonValueKind]::Object) { throw 'Manifest object required.' }
      $names = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
      foreach ($property in $Node.EnumerateObject()) {
        if (-not $names.Add($property.Name) -or $property.Name -cnotin $Fields) { throw 'Unknown, duplicate or aliased manifest field.' }
      }
      if ($names.Count -ne $Fields.Count) { throw 'Missing manifest field.' }
    }
    function getManifestString([System.Text.Json.JsonElement]$Node) {
      if ($Node.ValueKind -ne [System.Text.Json.JsonValueKind]::String) { throw 'Manifest string required.' }
      $Node.GetString()
    }
  }
  process {
    $result = [pscustomobject]@{
      Status = 'Hold'; Errors = @(); ArchivePath = $null; ProofPath = $null
      FileArchiveVerified = $false; FileRestoreVerified = $false; ProofCreated = $false
      NamedStreamCount = 0; Approved = $false; ReadyForRemoval = $false; CustodyVerified = $false
      DirectoryStreamsVerified = $false; RootStreamsVerified = $false
      Limitations = @('One-file data/stream proof only; no ACL, identity or whole-tree custody.',
        'Non-atomic path checks; quiet producers required; partial proof retained on failure.')
    }
    $archiveStream = $null; $zip = $null; $document = $null
    try {
      if ($ExpectedArchiveSHA256 -cnotmatch '\A[0-9A-Fa-f]{64}\z') { throw 'Invalid expected archive hash.' }
      $root = getArchiveLocalPath $RootPath $false $true
      $archive = getArchiveLocalPath $ArchivePath $false $false
      $proof = getArchiveLocalPath $ProofRoot $true $true
      if ((testArchiveOverlap $root $archive) -or (testArchiveOverlap $root $proof) -or (testArchiveOverlap $archive $proof)) {
        throw 'Archive/proof overlaps source or each other.'
      }
      $archiveStream = [IO.File]::Open($archive, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
      if ($archiveStream.Length -gt $byteLimit) { throw 'Archive byte limit.' }
      if ((copyArchiveData $archiveStream $null).SHA256 -cne $ExpectedArchiveSHA256.ToUpperInvariant()) { throw 'Archive hash mismatch.' }
      $archiveStream.Position = 0
      $zip = [IO.Compression.ZipArchive]::new($archiveStream, [IO.Compression.ZipArchiveMode]::Read, $true)
      if ($zip.Entries.Count -lt 2 -or $zip.Entries.Count -gt 65) { throw 'Archive entry count limit.' }
      $entryNames = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
      foreach ($entry in $zip.Entries) {
        if (-not $entryNames.Add($entry.FullName) -or
          ($entry.FullName -cne 'manifest.json' -and $entry.FullName -cnotmatch '\Adata/[0-9]{4}\.bin\z')) { throw 'Unsafe, duplicate or unknown archive entry.' }
      }
      $manifestEntry = $zip.GetEntry('manifest.json')
      if ($null -eq $manifestEntry -or $manifestEntry.Length -gt 65536) { throw 'Missing or oversized manifest.' }
      $manifestBytes = [byte[]]::new([int]$manifestEntry.Length)
      $payloadInput = $manifestEntry.Open()
      try {
        $payloadInput.ReadExactly($manifestBytes, 0, $manifestBytes.Length)
        if ($payloadInput.ReadByte() -ne -1) { throw 'Manifest length drift.' }
      } finally { $payloadInput.Dispose() }
      $json = [Text.UTF8Encoding]::new($false, $true).GetString($manifestBytes)
      $document = [System.Text.Json.JsonDocument]::Parse($json)
      $manifest = $document.RootElement
      assertManifestFields $manifest @('Version', 'SourceRoot', 'RelativePath', 'Streams')
      if ($manifest.GetProperty('Version').GetRawText() -cne '1') { throw 'Unsupported archive version.' }
      $boundRoot = getManifestString ($manifest.GetProperty('SourceRoot'))
      if ($boundRoot -ine $root) { throw 'Pinned archive source boundary differs.' }
      $relative = getManifestString ($manifest.GetProperty('RelativePath'))
      assertArchiveRelative $relative
      $array = $manifest.GetProperty('Streams')
      if ($array.ValueKind -ne [System.Text.Json.JsonValueKind]::Array -or $array.GetArrayLength() -lt 1 -or $array.GetArrayLength() -gt 64) { throw 'Invalid stream descriptor array.' }
      $names = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
      $mappedEntries = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
      $descriptors = [Collections.Generic.List[object]]::new()
      $defaultCount = 0; $total = 0L
      foreach ($node in $array.EnumerateArray()) {
        assertManifestFields $node @('Name', 'Bytes', 'SHA256', 'Entry')
        $name = getManifestString ($node.GetProperty('Name'))
        $hash = getManifestString ($node.GetProperty('SHA256'))
        $entryName = getManifestString ($node.GetProperty('Entry'))
        assertArchiveStreamName $name
        $number = $node.GetProperty('Bytes'); $bytes = 0L
        if ($number.ValueKind -ne [System.Text.Json.JsonValueKind]::Number -or $number.GetRawText() -cnotmatch '\A(0|[1-9][0-9]*)\z' -or -not $number.TryGetInt64([ref]$bytes) -or $bytes -gt $byteLimit) { throw 'Invalid or oversized payload length.' }
        if (-not $names.Add($name) -or $hash -cnotmatch '\A[0-9A-F]{64}\z' -or
          $entryName -cnotmatch '\Adata/[0-9]{4}\.bin\z' -or -not $mappedEntries.Add($entryName)) { throw 'Invalid, duplicate or aliased stream descriptor.' }
        if ($name -ceq ':$DATA') { $defaultCount++ }
        $total += $bytes
        if ($total -gt $byteLimit) { throw 'Uncompressed byte limit.' }
        $entry = $zip.GetEntry($entryName)
        if ($null -eq $entry -or $entry.Length -ne $bytes) { throw 'Payload membership or declared length mismatch.' }
        $descriptors.Add([pscustomobject]@{ Name = $name; Bytes = $bytes; SHA256 = $hash; Entry = $entryName })
      }
      if ($defaultCount -ne 1 -or $zip.Entries.Count -ne $descriptors.Count + 1) { throw 'Default stream or exact archive membership mismatch.' }
      # Check every compressed payload before creating any proof output.
      foreach ($descriptor in $descriptors) {
        $payloadInput = $zip.GetEntry($descriptor.Entry).Open()
        try { $actual = copyArchiveData $payloadInput $null } finally { $payloadInput.Dispose() }
        if ($actual.Bytes -ne $descriptor.Bytes -or $actual.SHA256 -cne $descriptor.SHA256) { throw 'Archive stream digest mismatch.' }
      }
      $result.FileArchiveVerified = $true; $result.ArchivePath = $archive
      $result.NamedStreamCount = $descriptors.Count - 1
      if (-not $PSCmdlet.ShouldProcess($proof, 'Create independent one-file proof restore')) { $result.Status = 'Skipped'; return $result }
      # Recheck the new boundary immediately before creation. No overwrite/cleanup.
      $null = getArchiveLocalPath $proof $true $true
      $null = New-Item -ItemType Directory -Path $proof -ErrorAction Stop
      $result.ProofCreated = $true
      $target = Join-Path $proof $relative
      $null = New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force -ErrorAction Stop
      $null = getArchiveLocalPath $target $true $false
      # Default stream first; named streams are only present in ADS-positive manifests.
      foreach ($descriptor in @($descriptors | Sort-Object @{ Expression = { if ($_.Name -ceq ':$DATA') { 0 } else { 1 } } })) {
        $outputPath = if ($descriptor.Name -ceq ':$DATA') { $target } else { $target + ':' + $descriptor.Name }
        $payloadInput = $zip.GetEntry($descriptor.Entry).Open()
        $output = $null
        try {
          $output = [IO.File]::Open($outputPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
          $actual = copyArchiveData $payloadInput $output
          if ($actual.Bytes -ne $descriptor.Bytes -or $actual.SHA256 -cne $descriptor.SHA256) { throw 'Proof copy verification failed.' }
        } finally { if ($null -ne $output) { $output.Dispose() }; $payloadInput.Dispose() }
      }
      $state = getArchiveFileState $target
      if ($state.Streams.Count -ne $descriptors.Count) { throw 'Restored stream membership mismatch.' }
      foreach ($descriptor in $descriptors) {
        $row = @($state.Streams | Where-Object Name -CEQ $descriptor.Name)
        if ($row.Count -ne 1 -or $row[0].Bytes -ne $descriptor.Bytes) { throw 'Restored stream descriptor mismatch.' }
        $path = if ($descriptor.Name -ceq ':$DATA') { $target } else { $target + ':' + $descriptor.Name }
        $actual = getArchiveDigest $path
        if ($actual.Bytes -ne $descriptor.Bytes -or $actual.SHA256 -cne $descriptor.SHA256) { throw 'Restored stream digest mismatch.' }
      }
      $finalState = getArchiveFileState $target
      if (($state | ConvertTo-Json -Depth 5 -Compress) -cne ($finalState | ConvertTo-Json -Depth 5 -Compress)) { throw 'Restored metadata/stream-set drift.' }
      $result.ProofPath = $target; $result.FileRestoreVerified = $true; $result.Status = 'Verified'
    } catch {
      $result.Errors = @($_.Exception.Message)
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'File restore held; partial proof retained.'
    } finally {
      if ($null -ne $document) { $document.Dispose() }
      if ($null -ne $zip) { $zip.Dispose() }
      if ($null -ne $archiveStream) { $archiveStream.Dispose() }
    }
    $result
  }
  end { }
}
