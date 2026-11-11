function Export-CoordState {
  <#
  .SYNOPSIS
    Exports a lossless state, custody and observed quartet snapshot under the producer lease.
  .DESCRIPTION
    Only the configured protected backup directory is writable. Export is not
    restore approval or admission of a replacement lineage; pending work is retained.
  #>
  [CmdletBinding(SupportsShouldProcess)]
  param([Parameter(Mandatory)][string]$HolderId, [Parameter(Mandatory)][string]$SessionId,
    [Parameter(Mandatory)][string]$DestinationPath, [switch]$NoCompression)
  process {
    if (-not $PSCmdlet.ShouldProcess($DestinationPath, 'Export coordination recovery snapshot')) { return }
    $context = $null
    try {
      $context = Read-CoordProducerContext -HolderId $HolderId -SessionId $SessionId -Role Export -AllowPending
      $root = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath((Get-CoordSetting 'OrchestrationProtectedBackupRootPath')))
      $path = [IO.Path]::GetFullPath($DestinationPath)
      if ([IO.Path]::GetDirectoryName($path) -ine $root) { throw 'BackupLocationConflict' }
      foreach ($protectedPath in @($context.StatePath, $context.RecordPath)) {
        $protectedDirectory = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($protectedPath)))
        if ($root -ieq $protectedDirectory -or (Test-CoordDescendant $root $protectedDirectory)) { throw 'BackupLocationConflict' }
      }
      Assert-CoordProtection $root $context.Record.custodianSid
      $null = Assert-CoordOrdinaryPath $path
      $outputs = [ordered]@{}
      foreach ($slot in @('markdown', 'boardHtml', 'proceduralDetailsHtml', 'accomplishedHtml')) {
        $file = $context.State.GetProperty('committedOutputManifest').GetProperty($slot).GetProperty('path').GetString()
        $null = Assert-CoordOrdinaryPath $file -MustExist
        $bytes = [IO.File]::ReadAllBytes($file)
        $outputs[$slot] = @{ path = $file; digest = Get-CoordHash $bytes; bytesBase64 = [Convert]::ToBase64String($bytes) }
      }
      $snapshot = ConvertTo-CoordElement @{
        schemaVersion = 'Coordination-export-v1'; resourceId = $context.Record.resourceId; lineageId = $context.Record.lineageId
        generation = $context.Record.generation; committedRevision = $context.State.GetProperty('committedRevision').GetString()
        stateBytesBase64 = [Convert]::ToBase64String($context.StateBytes); stateDigest = Get-CoordHash $context.StateBytes
        custodyBytesBase64 = [Convert]::ToBase64String($context.RecordBytes); custodyDigest = Get-CoordHash $context.RecordBytes
        observedOutputs = $outputs
      }
      $bytes = ConvertTo-CoordStateBytes $snapshot
      if ($bytes.Length -gt 67108864) { throw 'BundleByteLimitExceeded' }
      $bundleDigest = Get-CoordHash $bytes
      $work = $null
      if (-not $NoCompression) {
        $sevenZip = Get-CoordSevenZip
        $work = Join-Path $root ('.coord-export-' + [guid]::NewGuid().ToString('N'))
        $null = [IO.Directory]::CreateDirectory($work)
        [IO.File]::WriteAllBytes((Join-Path $work 'bundle.json'), $bytes)
        $archivePath = Join-Path $work 'snapshot.zip'
        $start = [Diagnostics.ProcessStartInfo]::new()
        $start.FileName = $sevenZip
        $start.WorkingDirectory = $work
        $start.UseShellExecute = $false
        $start.CreateNoWindow = $true
        $start.RedirectStandardOutput = $true
        $start.RedirectStandardError = $true
        foreach ($arg in @('a','-tzip','-mm=Deflate','-mx=5','-mmt=2','-bsp0','-bso0','-bse0','--',$archivePath,'bundle.json')) {
          $start.ArgumentList.Add($arg)
        }
        $process = [Diagnostics.Process]::Start($start)
        try {
          $stdout = $process.StandardOutput.ReadToEndAsync()
          $stderr = $process.StandardError.ReadToEndAsync()
          if (-not $process.WaitForExit(30000)) {
            $process.Kill($true)
            $process.WaitForExit()
            throw 'SevenZipDeadlineExpired'
          }
          $null = $stdout.GetAwaiter().GetResult()
          $null = $stderr.GetAwaiter().GetResult()
          if ($process.ExitCode -ne 0) { throw 'SevenZipCompressionFailed' }
        } finally { $process.Dispose() }
        if ([IO.FileInfo]::new($archivePath).Length -gt 67108864) { throw 'BundleByteLimitExceeded' }
        $archiveDigest = (Get-FileHash -LiteralPath $archivePath).Hash
        $verification = Read-CoordRecoveryBundle -Path $archivePath -ExpectedSha256 $archiveDigest
        if ($verification.Digest -cne $bundleDigest) { throw 'CompressedExportReadbackFailed' }
        $bytes = [IO.File]::ReadAllBytes($archivePath)
      }
      $stream = [IO.File]::Open($path, 'CreateNew', 'Write', 'None')
      try { $stream.Write($bytes, 0, $bytes.Length); $stream.Flush($true) } finally { $stream.Dispose() }
      if ((Get-CoordHash ([IO.File]::ReadAllBytes($path))) -cne (Get-CoordHash $bytes)) { throw 'ExportReadbackFailed' }
      Assert-CoordProtection $path $context.Record.custodianSid
      if ($work) {
        [IO.File]::Delete((Join-Path $work 'bundle.json'))
        [IO.File]::Delete((Join-Path $work 'snapshot.zip'))
        [IO.Directory]::Delete($work)
      }
      [pscustomobject]@{ Status = 'Exported'; Path = $path; Digest = Get-CoordHash $bytes
        BundleDigest = $bundleDigest; Format = $(if ($NoCompression) { 'JSON' } else { 'ZIP' })
        ResourceId = $context.Record.resourceId; LineageId = $context.Record.lineageId }
    } finally {
      if ($context) { $context.BoardLease.Dispose(); $context.Lease.Dispose() }
    }
  }
}
