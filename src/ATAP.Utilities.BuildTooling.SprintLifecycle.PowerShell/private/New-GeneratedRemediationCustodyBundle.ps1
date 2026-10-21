function New-GeneratedRemediationCustodyBundle {
  <#
  .SYNOPSIS
    Composes bounded archives into one verified recovery tree.
  .DESCRIPTION
    Reuses default-mode TreeCensus and accepted archive/restore engines. Metadata
    and stream lengths bound the entire worklist before any bundle write. Each
    entry has its own archive and is restored into one new recovery boundary.
    Actual recovery and final source stream hashes are checked against manifests.
    These non-atomic checks establish no ACL, identity, durability or approval.
    Quiet producers required: late content-only changes, aliases and ABA can
    evade observations. Partial outputs retained; no cleanup or retry.
    No index is persisted: the returned receipt map is the only bundle index.
  .PARAMETER RootPath
    Explicit fixed-local NTFS source boundary containing _generated.
  .PARAMETER BundleRoot
    NEW external directory, with an existing ordinary parent.
  .PARAMETER MaxEntries
    Finite structural rows including the root, at most 10000.
  .PARAMETER MaxDepth
    Finite census depth, at most 128.
  .PARAMETER MaxBundlePayloadBytes
    Aggregate uncompressed default/file ADS and directory named data, up to 1 GiB.
    Each accepted entry helper additionally enforces its own 64 MiB limit.
  .PARAMETER AllowVerifiedCloudDirectoryMetadata
    Explicitly forwards the existing reviewed cloud-directory census option.
    Default false; the TreeCensus helper owns the unchanged metadata policy.
  .OUTPUTS
    CoherentTreeRestoreVerified and AggregateSourceBytesRechecked describe the
    observed checks only. Global custody and readiness remain false.
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [Parameter(Mandatory)][string]$RootPath,
    [Parameter(Mandatory)][string]$BundleRoot,
    [ValidateRange(1, 10000)][int]$MaxEntries = 256,
    [ValidateRange(1, 128)][int]$MaxDepth = 32,
    [ValidateRange(0, 1073741824)][long]$MaxBundlePayloadBytes = 268435456,
    [switch]$AllowVerifiedCloudDirectoryMetadata
  )
  begin {
    $fn = 'New-GeneratedRemediationCustodyBundle'
    $mn = 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell'
    if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) { Import-Module PSFramework -ErrorAction Stop }
    foreach ($dependency in @('Get-GeneratedRemediationTreeCensus',
      'New-GeneratedRemediationFileArchive', 'Restore-GeneratedRemediationFileArchive',
      'New-GeneratedRemediationDirectoryArchive', 'Restore-GeneratedRemediationDirectoryArchive')) {
      if (-not (Get-Command $dependency -ErrorAction SilentlyContinue)) {
        . (Join-Path $PSScriptRoot ($dependency + '.ps1'))
        if (-not (Get-Command $dependency -ErrorAction SilentlyContinue)) { throw "Missing required helper: $dependency" }
      }
    }
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

    function getBundleRows($Envelope, [string]$ExpectedRoot = $root) {
      if ($null -eq $Envelope -or $Envelope.Success -isnot [bool] -or -not $Envelope.Success -or
        $Envelope.Consistent -isnot [bool] -or -not $Envelope.Consistent -or
        $Envelope.StructuralInventoryComplete -isnot [bool] -or -not $Envelope.StructuralInventoryComplete -or
        $Envelope.RootState -cne 'Present' -or $null -eq $Envelope.FailedWalks -or @($Envelope.FailedWalks).Count -ne 0 -or
        $null -eq $Envelope.Errors -or @($Envelope.Errors).Count -ne 0 -or
        $Envelope.Binding.Root -isnot [string] -or $Envelope.Binding.RelativePath -isnot [string] -or
        $Envelope.Binding.MaxEntries -isnot [int] -or $Envelope.Binding.MaxDepth -isnot [int] -or
        $Envelope.Binding.Root -cne $ExpectedRoot -or $Envelope.Binding.RelativePath -cne '_generated' -or
        $Envelope.Binding.MaxEntries -ne $MaxEntries -or $Envelope.Binding.MaxDepth -ne $MaxDepth -or
        @($Envelope.Observations).Count -ne 2) { throw 'Incomplete or wrongly bound structural census.' }
      $canonical = $null
      foreach ($observation in $Envelope.Observations) {
        if ($observation.Holds -isnot [int] -or $observation.Holds -ne 0 -or
          $null -eq $observation.Rows -or @($observation.Rows).Count -lt 1 -or @($observation.Rows).Count -gt $MaxEntries) { throw 'Invalid census rows or holds.' }
        $byPath = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
        $aliases = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach ($row in $observation.Rows) {
          if ($row.RelativePath -isnot [string] -or $row.Kind -cnotin @('File', 'Directory') -or
            $row.Hold -isnot [bool] -or $row.Hold -or $row.Depth -isnot [int] -or $row.Depth -lt 0 -or $row.Depth -gt $MaxDepth -or
            $row.Attributes -isnot [long] -or $row.CreationTicks -isnot [long] -or $row.LastWriteTicks -isnot [long] -or
            ($row.Kind -ceq 'File' -and ($row.Length -isnot [long] -or $row.Length -lt 0)) -or
            ($row.Kind -ceq 'Directory' -and $null -ne $row.Length)) { throw 'Malformed structural row.' }
          assertArchiveRelative $row.RelativePath
          if ($row.Depth -ne ($row.RelativePath.Split('/').Count - 1) -or -not $aliases.Add($row.RelativePath)) { throw 'Duplicate, aliased or wrongly deep census row.' }
          $byPath.Add($row.RelativePath, $row)
        }
        if (-not $byPath.ContainsKey('_generated') -or $byPath['_generated'].Kind -cne 'Directory') { throw 'Missing directory root row.' }
        foreach ($row in $byPath.Values) {
          if ($row.RelativePath -ceq '_generated') { continue }
          $parent = $row.RelativePath.Substring(0, $row.RelativePath.LastIndexOf('/'))
          if (-not $byPath.ContainsKey($parent) -or $byPath[$parent].Kind -cne 'Directory') { throw 'Missing, aliased or non-directory parent row.' }
        }
        $keys = [string[]]@($byPath.Keys); [Array]::Sort($keys, [StringComparer]::Ordinal)
        $rows = @(foreach ($key in $keys) { $byPath[$key] })
        $serialized = ConvertTo-Json -InputObject $rows -Depth 8 -Compress
        if ($null -ne $canonical -and $canonical -cne $serialized) { throw 'Census observations differ.' }
        $canonical = $serialized
      }
      # Return one object so a one-entry worklist cannot unroll into a scalar.
      [pscustomobject]@{ Rows = $rows; Serialized = $canonical }
    }
    function getBundleEntryState($Row, [string]$Boundary = $root) {
      $directory = $Row.Kind -ceq 'Directory'
      $path = getArchiveLocalPath (Join-Path $Boundary $Row.RelativePath) $false $directory
      $item = Get-Item -LiteralPath $path -Force -ErrorAction Stop
      if ([long]$item.Attributes -ne $Row.Attributes -or $item.CreationTimeUtc.Ticks -ne $Row.CreationTicks -or
        $item.LastWriteTimeUtc.Ticks -ne $Row.LastWriteTicks -or (-not $directory -and $item.Length -ne $Row.Length)) { throw 'Entry metadata differs from census.' }
      $streams = @(Get-Item -LiteralPath $path -Stream '*' -Force -ErrorAction Stop)
      if ($streams.Count -gt 65) { throw 'Entry stream count limit.' }
      $names = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
      $defaultCount = 0; $total = 0L
      $descriptors = @(foreach ($stream in $streams) {
        $name = [string]$stream.Stream
        if ($name -ceq ':$DATA') {
          $defaultCount++
          if ($defaultCount -gt 1 -or $stream.Length -isnot [long] -or
            ($directory -and $stream.Length -ne 0) -or (-not $directory -and $stream.Length -ne $item.Length)) { throw 'Invalid default census marker.' }
          if ($directory) { continue }
        } else { assertArchiveStreamName $name }
        if (-not $names.Add($name) -or $stream.Length -isnot [long] -or $stream.Length -lt 0 -or $names.Count -gt 64) { throw 'Invalid stream census.' }
        $total += $stream.Length
        if ($total -gt $byteLimit) { throw 'Per-entry byte limit.' }
        [pscustomobject]@{ Name = $name; Bytes = $stream.Length }
      })
      if (-not $directory -and $defaultCount -ne 1) { throw 'Missing file default stream.' }
      [pscustomobject]@{ Path = $path; Bytes = $total; Streams = @($descriptors | Sort-Object Name -CaseSensitive)
        Attributes = [long]$item.Attributes; Creation = $item.CreationTimeUtc.Ticks; Written = $item.LastWriteTimeUtc.Ticks }
    }
    function assertBundleFlags($Receipt) {
      foreach ($flag in @('Approved','ReadyForRemoval','CustodyVerified','DirectoryStreamsVerified','RootStreamsVerified')) {
        if ($Receipt.$flag -isnot [bool] -or $Receipt.$flag) { throw 'Malformed or unsafe helper flags.' }
      }
      if ($Receipt.Status -cne 'Verified' -or $null -eq $Receipt.Errors -or @($Receipt.Errors).Count) { throw 'Entry helper did not verify.' }
    }
    function getBundleWriterBytes($Receipt, $Row, $State, [string]$Archive) {
      assertBundleFlags $Receipt
      $flag = if ($Row.Kind -ceq 'File') { 'FileArchiveVerified' } else { 'DirectoryArchiveVerified' }
      $namedCount = $State.Streams.Count - [int]($Row.Kind -ceq 'File')
      if ($Receipt.ArchiveCreated -isnot [bool] -or -not $Receipt.ArchiveCreated -or
        $Receipt.$flag -isnot [bool] -or -not $Receipt.$flag -or $Receipt.ArchivePath -cne $Archive -or
        $Receipt.NamedStreamCount -isnot [int] -or $Receipt.NamedStreamCount -ne $namedCount -or
        $Receipt.ArchiveSHA256 -isnot [string] -or $Receipt.ArchiveSHA256 -cnotmatch '\A[0-9A-F]{64}\z') { throw 'Malformed or substituted archive receipt.' }
      $manifest = $Receipt.Manifest
      if ($null -eq $manifest -or $manifest.Version -isnot [int] -or $manifest.Version -ne 1 -or
        $manifest.SourceRoot -cne $root -or $manifest.RelativePath -cne $Row.RelativePath -or
        ($Row.Kind -ceq 'Directory' -and $manifest.SourceKind -cne 'DirectoryNamedStreams') -or
        ($Row.Kind -ceq 'File' -and $null -ne $manifest.PSObject.Properties['SourceKind']) -or
        $null -eq $manifest.Streams -or @($manifest.Streams).Count -ne $State.Streams.Count) { throw 'Archive manifest row binding mismatch.' }
      $names = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
      $entries = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
      $total = 0L
      foreach ($descriptor in $manifest.Streams) {
        $streamRows = @($State.Streams | Where-Object Name -CEQ $descriptor.Name)
        if ($descriptor.Name -isnot [string] -or -not $names.Add($descriptor.Name) -or $streamRows.Count -ne 1 -or
          $descriptor.Bytes -isnot [long] -or $descriptor.Bytes -ne $streamRows[0].Bytes -or
          $descriptor.SHA256 -isnot [string] -or $descriptor.SHA256 -cnotmatch '\A[0-9A-F]{64}\z' -or
          $descriptor.Entry -isnot [string] -or $descriptor.Entry -cnotmatch '\Adata/[0-9]{4}\.bin\z' -or
          -not $entries.Add($descriptor.Entry)) { throw 'Malformed or changed archive stream descriptors.' }
        $total += $descriptor.Bytes
      }
      $null = getArchiveLocalPath $Archive $false $false
      if ($total -ne $State.Bytes -or $total -gt $byteLimit -or
        (Get-FileHash -LiteralPath $Archive -Algorithm SHA256 -ErrorAction Stop).Hash -cne $Receipt.ArchiveSHA256) { throw 'Actual archive hash/receipt bytes mismatch.' }
      $total
    }
    function getBundleDigest([string]$Path) {
      $inputStream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
      $hash = [Security.Cryptography.IncrementalHash]::CreateHash([Security.Cryptography.HashAlgorithmName]::SHA256)
      $bytes = 0L; $buffer = [byte[]]::new(65536)
      try {
        if ($inputStream.Length -gt $byteLimit) { throw 'Actual verification payload exceeds entry limit.' }
        while (($count = $inputStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
          $bytes += $count
          if ($bytes -gt $byteLimit) { throw 'Actual verification payload exceeds entry limit.' }
          $hash.AppendData($buffer, 0, $count)
        }
        [pscustomobject]@{ Bytes = $bytes; SHA256 = [Convert]::ToHexString($hash.GetHashAndReset()) }
      } finally { $inputStream.Dispose(); $hash.Dispose() }
    }
    function getBundlePayloadVerification($Rows, [string]$Boundary) {
      $total = 0L
      $observed = @(foreach ($entry in $receipts) {
        $row = @($Rows | Where-Object RelativePath -CEQ $entry.RelativePath)
        if ($row.Count -ne 1 -or $row[0].Kind -cne $entry.Kind) { throw 'Verification inventory differs from receipt map.' }
        $beforeState = getBundleEntryState $row[0] $Boundary
        $descriptors = @($entry.Writer.Manifest.Streams)
        if ($beforeState.Streams.Count -ne $descriptors.Count) { throw 'Verification stream membership differs.' }
        $streams = @(foreach ($descriptor in $descriptors) {
          $streamRow = @($beforeState.Streams | Where-Object Name -CEQ $descriptor.Name)
          if ($streamRow.Count -ne 1 -or $streamRow[0].Bytes -ne $descriptor.Bytes) { throw 'Verification stream descriptor differs.' }
          $path = if ($descriptor.Name -ceq ':$DATA') { $beforeState.Path } else { $beforeState.Path + ':' + $descriptor.Name }
          $digest = getBundleDigest $path
          if ($digest.Bytes -ne $descriptor.Bytes -or $digest.SHA256 -cne $descriptor.SHA256) { throw 'Verification stream content drift.' }
          $total += $digest.Bytes
          if ($total -gt $MaxBundlePayloadBytes) { throw 'Aggregate verification byte limit.' }
          [pscustomobject]@{ Name = $descriptor.Name; Bytes = $digest.Bytes; SHA256 = $digest.SHA256 }
        })
        $afterState = getBundleEntryState $row[0] $Boundary
        if ((ConvertTo-Json $beforeState -Depth 6 -Compress) -cne (ConvertTo-Json $afterState -Depth 6 -Compress)) { throw 'Verification stream-set/metadata drift.' }
        [pscustomobject]@{ RelativePath = $entry.RelativePath; Kind = $entry.Kind; Streams = $streams }
      })
      if ($total -ne $result.PreflightPayloadBytes) { throw 'Aggregate verified payload total differs.' }
      [pscustomobject]@{ Bytes = $total; Entries = $observed }
    }
  }
  process {
    $result = [pscustomobject]@{
      Status = 'Hold'; Errors = @(); BundlePath = $null; BundleCreated = $false
      ExpectedEntries = 0; VerifiedEntries = 0; PreflightPayloadBytes = 0L; VerifiedPayloadBytes = 0L
      Entries = @(); InitialCensus = $null; FinalCensus = $null; EntryProofCoverageComplete = $false
      ProofRoot = $null; ProofCensus = $null; SourceStreamVerification = $null; ProofStreamVerification = $null
      Approved = $false; ReadyForRemoval = $false; CustodyVerified = $false
      RootStreamsVerified = $false; DirectoryStreamsVerified = $false
      CoherentTreeRestoreVerified = $false; AggregateSourceBytesRechecked = $false
      Limitations = @('One composed recovery tree and final source stream checks against captured manifests.',
        'Checks are non-atomic; quiet producers required. Changes after a stream check, ABA and aliases can be missed.',
        'No ACL, identity, durable custody or removal approval.',
        'Partial output retained; no automatic cleanup, retry or removal approval.')
    }
    $receipts = [Collections.Generic.List[object]]::new()
    try {
      $root = getArchiveLocalPath $RootPath $false $true
      $bundle = getArchiveLocalPath $BundleRoot $true $true
      if (testArchiveOverlap $root $bundle) { throw 'Bundle overlaps source boundary.' }
      $initial = @(Get-GeneratedRemediationTreeCensus -RootPath $root -MaxEntries $MaxEntries -MaxDepth $MaxDepth -AllowVerifiedCloudDirectoryMetadata:$AllowVerifiedCloudDirectoryMetadata)
      if ($initial.Count -ne 1) { throw 'Expected one census envelope.' }
      $work = getBundleRows $initial[0]
      $result.InitialCensus = $initial[0]; $result.ExpectedEntries = $work.Rows.Count
      $states = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
      foreach ($row in $work.Rows) {
        $state = getBundleEntryState $row
        $states.Add($row.RelativePath, $state)
        $result.PreflightPayloadBytes += $state.Bytes
        if ($result.PreflightPayloadBytes -gt $MaxBundlePayloadBytes) { throw 'Aggregate preflight payload budget exceeded.' }
      }
      if (-not $PSCmdlet.ShouldProcess($bundle, 'Create verified recovery-tree bundle')) { $result.Status = 'Skipped'; return $result }
      $null = getArchiveLocalPath $bundle $true $true
      $null = New-Item -ItemType Directory -Path $bundle -ErrorAction Stop
      $result.BundleCreated = $true; $result.BundlePath = $bundle
      $archives = Join-Path $bundle 'archives'; $proof = Join-Path $bundle 'recovery'
      $null = New-Item -ItemType Directory -Path $archives, $proof -ErrorAction Stop
      $result.ProofRoot = $proof
      $index = 0
      $orderedRows = @($work.Rows | Sort-Object @{ Expression = { if ($_.Kind -ceq 'Directory') { 0 } else { 1 } } }, Depth, RelativePath -CaseSensitive)
      foreach ($row in $orderedRows) {
        $state = getBundleEntryState $row
        if ((ConvertTo-Json $state -Depth 6 -Compress) -cne (ConvertTo-Json $states[$row.RelativePath] -Depth 6 -Compress)) { throw 'Pre-entry stream-set/metadata drift.' }
        $archive = Join-Path $archives ('{0:D4}.zip' -f $index)
        $entry = [pscustomobject]@{ Index = $index; RelativePath = $row.RelativePath; Kind = $row.Kind
          ArchivePath = $archive; ProofRoot = $proof; RestoreMode = 'Composition'; ArchiveSHA256 = $null; Writer = $null; Restore = $null; Verified = $false }
        $receipts.Add($entry)
        $writerName = if ($row.Kind -ceq 'File') { 'New-GeneratedRemediationFileArchive' } else { 'New-GeneratedRemediationDirectoryArchive' }
        $created = @(& $writerName -RootPath $root -RelativePath $row.RelativePath -ArchivePath $archive -Confirm:$false -WhatIf:$false)
        if ($created.Count -ne 1) { throw 'Expected one writer receipt.' }
        $entry.Writer = $created[0]
        $actualBytes = getBundleWriterBytes $created[0] $row $state $archive
        if ($result.VerifiedPayloadBytes + $actualBytes -gt $MaxBundlePayloadBytes) { throw 'Actual receipt budget exceeded; no further writes.' }
        $entry.ArchiveSHA256 = $created[0].ArchiveSHA256
        $restoreName = if ($row.Kind -ceq 'File') { 'Restore-GeneratedRemediationFileArchive' } else { 'Restore-GeneratedRemediationDirectoryArchive' }
        $restored = @(& $restoreName -RootPath $root -ArchivePath $archive -ExpectedArchiveSHA256 $entry.ArchiveSHA256 -ProofRoot $proof -ComposeIntoProofRoot -ExpectedRelativePath $row.RelativePath -Confirm:$false -WhatIf:$false)
        if ($restored.Count -ne 1) { throw 'Expected one restore receipt.' }
        $entry.Restore = $restored[0]
        assertBundleFlags $restored[0]
        $archiveFlag = if ($row.Kind -ceq 'File') { 'FileArchiveVerified' } else { 'DirectoryArchiveVerified' }
        $restoreFlag = if ($row.Kind -ceq 'File') { 'FileRestoreVerified' } else { 'DirectoryRestoreVerified' }
        $namedCount = $state.Streams.Count - [int]($row.Kind -ceq 'File')
        if ($restored[0].$archiveFlag -isnot [bool] -or -not $restored[0].$archiveFlag -or
          $restored[0].$restoreFlag -isnot [bool] -or -not $restored[0].$restoreFlag -or
          $restored[0].NamedStreamCount -isnot [int] -or $restored[0].NamedStreamCount -ne $namedCount -or
          $restored[0].ProofCreated -isnot [bool] -or -not $restored[0].ProofCreated -or
          $restored[0].RestoreMode -cne 'Composition' -or $restored[0].ArchivePath -cne $archive -or $restored[0].ProofPath -cne (Join-Path $proof $row.RelativePath)) { throw 'Malformed or substituted actual restore receipt.' }
        $null = getArchiveLocalPath $restored[0].ProofPath $false ($row.Kind -ceq 'Directory')
        $proofItem = Get-Item -LiteralPath $restored[0].ProofPath -Force -ErrorAction Stop
        if ([bool]$proofItem.PSIsContainer -ne ($row.Kind -ceq 'Directory')) { throw 'Actual proof shape mismatch.' }
        $entry.Verified = $true; $result.VerifiedEntries++; $result.VerifiedPayloadBytes += $actualBytes
        $index++
      }
      $final = @(Get-GeneratedRemediationTreeCensus -RootPath $root -MaxEntries $MaxEntries -MaxDepth $MaxDepth -AllowVerifiedCloudDirectoryMetadata:$AllowVerifiedCloudDirectoryMetadata)
      if ($final.Count -ne 1) { throw 'Expected one final census envelope.' }
      $result.FinalCensus = $final[0]
      $last = getBundleRows $final[0]
      if ($last.Serialized -cne $work.Serialized) { throw 'Post-batch structural drift.' }
      if ($result.VerifiedEntries -ne $result.ExpectedEntries -or $result.VerifiedPayloadBytes -ne $result.PreflightPayloadBytes) { throw 'Incomplete per-entry coverage.' }
      $proofObservation = @(Get-GeneratedRemediationTreeCensus -RootPath $proof -MaxEntries $MaxEntries -MaxDepth $MaxDepth -AllowVerifiedCloudDirectoryMetadata:$AllowVerifiedCloudDirectoryMetadata)
      if ($proofObservation.Count -ne 1) { throw 'Expected one proof census envelope.' }
      $proofRows = getBundleRows $proofObservation[0] $proof
      $shape = ConvertTo-Json -InputObject @($work.Rows | Select-Object RelativePath, Kind) -Compress
      $proofShape = ConvertTo-Json -InputObject @($proofRows.Rows | Select-Object RelativePath, Kind) -Compress
      if ($shape -cne $proofShape) { throw 'Coherent recovery tree inventory mismatch.' }
      $result.ProofCensus = $proofObservation[0]
      $result.ProofStreamVerification = getBundlePayloadVerification $proofRows.Rows $proof
      $result.SourceStreamVerification = getBundlePayloadVerification $last.Rows $root
      foreach ($entry in $receipts) {
        if ((getBundleDigest $entry.ArchivePath).SHA256 -cne $entry.ArchiveSHA256) { throw 'Archive drift after restore.' }
      }
      $sourceAgain = @(Get-GeneratedRemediationTreeCensus -RootPath $root -MaxEntries $MaxEntries -MaxDepth $MaxDepth -AllowVerifiedCloudDirectoryMetadata:$AllowVerifiedCloudDirectoryMetadata)
      $proofAgain = @(Get-GeneratedRemediationTreeCensus -RootPath $proof -MaxEntries $MaxEntries -MaxDepth $MaxDepth -AllowVerifiedCloudDirectoryMetadata:$AllowVerifiedCloudDirectoryMetadata)
      if ($sourceAgain.Count -ne 1 -or $proofAgain.Count -ne 1 -or
        (getBundleRows $sourceAgain[0]).Serialized -cne $work.Serialized -or
        (getBundleRows $proofAgain[0] $proof).Serialized -cne $proofRows.Serialized) { throw 'Final source/proof structural drift.' }
      $result.FinalCensus = $sourceAgain[0]; $result.ProofCensus = $proofAgain[0]
      $result.CoherentTreeRestoreVerified = $true; $result.AggregateSourceBytesRechecked = $true
      $result.EntryProofCoverageComplete = $true; $result.Status = 'Verified'
    } catch {
      $result.Errors = @($_.Exception.Message)
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Recovery bundle held; partial outputs retained.'
    } finally { $result.Entries = @($receipts.ToArray()) }
    $result
  }
  end { }
}
