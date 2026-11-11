function Get-CoordSevenZip {
  $path = Assert-CoordOrdinaryPath (Get-CoordSetting 'OrchestrationSevenZipPath') -MustExist
  $expected = Get-CoordSetting 'OrchestrationSevenZipSha256'
  if ($expected -cnotmatch '\A[0-9A-Fa-f]{64}\z' -or
      (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ine $expected) { throw 'SevenZipPinMismatch' }
  $path
}

function Write-CoordRestoreImage {
  param([string]$Path, [byte[]]$Bytes, [string]$Digest)
  $stage = $Path + '.restore-' + [guid]::NewGuid().ToString('N')
  $stream = [IO.File]::Open($stage, 'CreateNew', 'Write', 'None')
  try { $stream.Write($Bytes); $stream.Flush($true) } finally { $stream.Dispose() }
  if ((Get-CoordHash ([IO.File]::ReadAllBytes($stage))) -cne $Digest) { throw 'RestoreImageReadbackFailed' }
  # A crash leaves an unattached stage. The retained restore intent permits only
  # exact image publication at an absent final path on the next attempt.
  [IO.File]::Move($stage, $Path)
}

function Read-CoordRecoveryBundle {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][ValidatePattern('\A[0-9a-fA-F]{64}\z')][string]$ExpectedSha256,
    [ValidateRange(1, 268435456)][int]$MaxBundleBytes = 67108864
  )
  $path = Assert-CoordOrdinaryPath $Path -MustExist
  $inputStream = [IO.File]::Open($path, 'Open', 'Read', 'Read')
  try {
    if ($inputStream.Length -lt 1 -or $inputStream.Length -gt $MaxBundleBytes) { throw 'BundleByteLimitExceeded' }
    $bytes = [byte[]]::new([int]$inputStream.Length)
    $inputStream.ReadExactly($bytes)
  } finally { $inputStream.Dispose() }
  if ((Get-CoordHash $bytes) -cne $ExpectedSha256.ToLowerInvariant()) { throw 'BundleDigestMismatch' }
  if ($bytes.Length -ge 4 -and $bytes[0] -eq 0x50 -and $bytes[1] -eq 0x4b) {
    $memory = [IO.MemoryStream]::new($bytes, $false)
    $archive = $null
    try {
      $archive = [IO.Compression.ZipArchive]::new($memory, [IO.Compression.ZipArchiveMode]::Read, $true)
      if ($archive.Entries.Count -ne 1) { throw 'UnexpectedArchiveEntry' }
      $entry = $archive.Entries[0]
      if ($entry.FullName -cne 'bundle.json' -or $entry.Length -lt 1 -or $entry.Length -gt $MaxBundleBytes -or
          (($entry.ExternalAttributes -shr 16) -band 0xf000) -eq 0xa000) { throw 'UnexpectedArchiveEntry' }
      $stream = $entry.Open()
      try {
        $bundle = [byte[]]::new([int]$entry.Length)
        $stream.ReadExactly($bundle)
        if ($stream.ReadByte() -ne -1) { throw 'BundleByteLimitExceeded' }
      } finally { $stream.Dispose() }
      [pscustomobject]@{ Format = 'ZIP'; Bytes = $bundle; Digest = Get-CoordHash $bundle }
    } finally {
      if ($archive) { $archive.Dispose() }
      $memory.Dispose()
    }
  } else {
    # Strict JSON validation happens in the pure G1 validator.
    [pscustomobject]@{ Format = 'JSON'; Bytes = $bytes; Digest = Get-CoordHash $bytes }
  }
}

