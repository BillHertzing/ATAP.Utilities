function Restore-CoordState {
  <#
  .SYNOPSIS
    Restores verified coordination images to their original, clean configured paths.
  .DESCRIPTION
    The bundle hash, identity, installed package and retained local history must
    match before any destination image is written. Original requests and journals
    are preserved byte for byte. A matching interrupted restore may resume.
    Restoring the entire history store requires separate custodian reconciliation.
    Destination parents and protected history must already be provisioned.
  #>
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
  param(
    [Parameter(Mandatory)][string]$BundlePath,
    [Parameter(Mandatory)][ValidatePattern('\A[0-9a-fA-F]{64}\z')][string]$ExpectedSha256,
    [Parameter(Mandatory)][string]$ExpectedResourceId,
    [Parameter(Mandatory)][string]$ExpectedLineageId,
    [Parameter(Mandatory)][string]$ExpectedGeneration,
    [Parameter(Mandatory)][string]$ExpectedCommittedRevision,
    [ValidateRange(1, 268435456)][int]$MaxBundleBytes = 67108864
  )
  $ErrorActionPreference = 'Stop'
  $moduleRoot = if ((Split-Path $PSScriptRoot -Leaf) -ieq 'public') { Split-Path $PSScriptRoot -Parent } else { $PSScriptRoot }
  $bundle = Read-CoordRecoveryBundle -Path $BundlePath -ExpectedSha256 $ExpectedSha256 -MaxBundleBytes $MaxBundleBytes
  $validation = @{
    BundleBytes = $bundle.Bytes; ExpectedSha256 = $bundle.Digest
    ExpectedResourceId = $ExpectedResourceId; ExpectedLineageId = $ExpectedLineageId
    ExpectedGeneration = $ExpectedGeneration; ExpectedCommittedRevision = $ExpectedCommittedRevision
    MaxBundleBytes = $MaxBundleBytes
    StateSchemaBytes = [IO.File]::ReadAllBytes((Join-Path $moduleRoot 'schemas/state-v1.schema.json'))
  }
  $verified = Test-CoordRestoreBundle @validation
  $witness = Read-CoordJsonBytes $verified.Custody.Bytes
  $record = ConvertFrom-CoordElement $witness
  $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
  if ($record.custodianSid -cne $sid) { throw 'RestoreCustodianMismatch' }
  $statePath = [IO.Path]::GetFullPath((Join-Path (Get-CoordSetting 'OrchestrationStateRootPath') 'state.json'))
  $custodyPath = [IO.Path]::GetFullPath((Get-CoordSetting 'OrchestrationCustodyRecordPath'))
  if ($record.statePath -cne $statePath) { throw 'RestoreOriginalPathRequired' }
  Assert-CoordPackageInventory $moduleRoot $record.package
  $historyRoot = Get-CoordRecoveryHistoryRoot
  if (-not $historyRoot) { throw 'RecoveryHistoryNotConfigured' }
  $files = @(
    [pscustomobject]@{ Path = $statePath; Bytes = $verified.State.Bytes; Digest = $verified.State.Sha256 },
    [pscustomobject]@{ Path = $custodyPath; Bytes = $verified.Custody.Bytes; Digest = $verified.Custody.Sha256 }
  )
  foreach ($slot in $verified.ObservedOutputs.Keys) {
    $image = $verified.ObservedOutputs[$slot]
    $files += [pscustomobject]@{ Path = $image.Path; Bytes = $image.Bytes; Digest = $image.Sha256 }
  }
  $unique = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  foreach ($file in $files) {
    if (-not [IO.Path]::IsPathFullyQualified($file.Path) -or
        -not $unique.Add([IO.Path]::GetFullPath($file.Path)) -or
        (Test-CoordDescendant $file.Path $historyRoot)) { throw 'RestoreDestinationConflict' }
    $null = Assert-CoordOrdinaryPath $file.Path
    $null = Assert-CoordOrdinaryPath ([IO.Path]::GetDirectoryName($file.Path)) -MustExist
  }
  foreach ($path in $statePath, $custodyPath) { Assert-CoordProtection ([IO.Path]::GetDirectoryName($path)) $sid }
  if (-not $PSCmdlet.ShouldProcess($statePath, 'Restore exact retained images to the original clean configured paths')) { return }
  $resourceLease = $null; $boardLease = $null; $historyLease = $null
  try {
    $resourceLease = Enter-CoordResourceLease ([IO.Path]::GetDirectoryName($custodyPath))
    $null = Assert-CoordOrdinaryPath $record.boardLockPath
    if ($unique.Contains([IO.Path]::GetFullPath($record.boardLockPath))) { throw 'RestoreDestinationConflict' }
    $boardLease = [IO.File]::Open($record.boardLockPath, 'OpenOrCreate', 'ReadWrite', 'None')
    $historyLease = [IO.File]::Open((Join-Path $historyRoot 'history.lock'), 'Open', 'ReadWrite', 'None')
    $history = Read-CoordRecoveryHistory $historyRoot
    if ($history.Pending -or $history.Binding.resourceId -cne $ExpectedResourceId -or
        $history.Binding.lineageId -cne $ExpectedLineageId -or
        $history.Pair.state -cne $verified.State.Sha256 -or
        $history.Pair.custody -cne $verified.Custody.Sha256) { throw 'RestoreDoesNotMatchRetainedHistory' }
    $restoreRoot = Join-Path $historyRoot 'Restores'
    $null = Assert-CoordOrdinaryPath $restoreRoot
    if (-not [IO.Directory]::Exists($restoreRoot)) {
      $null = [IO.Directory]::CreateDirectory($restoreRoot)
      $acl = Get-Acl -LiteralPath $restoreRoot
      $acl.SetAccessRuleProtection($true, $true)
      Set-Acl -LiteralPath $restoreRoot -AclObject $acl
    }
    Assert-CoordProtection $restoreRoot $sid
    $intentPath = Join-Path $restoreRoot ($ExpectedSha256.ToLowerInvariant() + '.intent.json')
    $receiptPath = Join-Path $restoreRoot ($ExpectedSha256.ToLowerInvariant() + '.receipt.json')
    $intent = ConvertTo-CoordStateBytes (ConvertTo-CoordElement ([ordered]@{
      archiveDigest = $ExpectedSha256.ToLowerInvariant(); bundleDigest = $bundle.Digest
      historyDigest = $history.Digest
      images = @($files | ForEach-Object { [ordered]@{ path = $_.Path; digest = $_.Digest } })
    }))
    $retry = [IO.File]::Exists($intentPath)
    $receipt = ConvertTo-CoordStateBytes (ConvertTo-CoordElement ([ordered]@{
      intentDigest = Get-CoordHash $intent; stateDigest = $verified.State.Sha256; custodyDigest = $verified.Custody.Sha256
    }))
    if ($retry -and (Get-CoordHash ([IO.File]::ReadAllBytes($intentPath))) -cne (Get-CoordHash $intent)) {
      throw 'RestoreAttemptIdentityConflict'
    }
    if ([IO.File]::Exists($receiptPath)) {
      Assert-CoordProtection $receiptPath $sid
      if (-not $retry -or (Get-CoordHash ([IO.File]::ReadAllBytes($receiptPath))) -cne (Get-CoordHash $receipt)) {
        throw 'RestoreReceiptMismatch'
      }
    }
    foreach ($file in $files) {
      if ([IO.File]::Exists($file.Path) -and (-not $retry -or
          (Get-CoordHash ([IO.File]::ReadAllBytes($file.Path))) -cne $file.Digest)) { throw 'RestoreDestinationNotClean' }
    }
    if (-not $retry) {
      $stream = [IO.File]::Open($intentPath, 'CreateNew', 'Write', 'None')
      try { $stream.Write($intent); $stream.Flush($true) } finally { $stream.Dispose() }
    }
    foreach ($file in $files) {
      if (-not [IO.File]::Exists($file.Path)) {
        Write-CoordRestoreImage -Path $file.Path -Bytes $file.Bytes -Digest $file.Digest
      }
      if ((Get-CoordHash ([IO.File]::ReadAllBytes($file.Path))) -cne $file.Digest) { throw 'RestoreImageReadbackFailed' }
    }
    foreach ($path in $statePath, $custodyPath) { Assert-CoordProtection $path $sid }
    if (-not [IO.File]::Exists($receiptPath)) {
      $stream = [IO.File]::Open($receiptPath, 'CreateNew', 'Write', 'None')
      try { $stream.Write($receipt); $stream.Flush($true) } finally { $stream.Dispose() }
    }
    if ((Get-CoordHash ([IO.File]::ReadAllBytes($receiptPath))) -cne (Get-CoordHash $receipt)) { throw 'RestoreReceiptMismatch' }
    Assert-CoordRecoveryPair (Read-CoordRecoveryHistory $historyRoot)
    [pscustomobject]@{ Status = 'RestoredHeld'; Format = $bundle.Format; StateDigest = $verified.State.Sha256
      CustodyDigest = $verified.Custody.Sha256; ReceiptPath = $receiptPath; Resumed = $retry
      ResourceId = $ExpectedResourceId; LineageId = $ExpectedLineageId; Generation = $ExpectedGeneration }
  } finally {
    if ($historyLease) { $historyLease.Dispose() }
    if ($boardLease) { $boardLease.Dispose() }
    if ($resourceLease) { $resourceLease.Dispose() }
  }
}

