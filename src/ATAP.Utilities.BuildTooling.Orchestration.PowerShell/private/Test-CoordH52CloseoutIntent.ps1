function Test-CoordH52CloseoutIntent {
  <#
  .SYNOPSIS
    Validates the exact reviewed Sprint 0017 H52 closeout material in memory.
  .DESCRIPTION
    The receipt pin is fixed to the reviewed C2065 candidate. The caller must
    supply the committed manifest from its independently admitted head and
    immutable quartet images in the existing state-v1 representation. This
    function neither resolves physical paths nor proves custody or authority.
  #>
  [CmdletBinding()]
  [OutputType([bool])]
  param(
    [Parameter(Mandatory)][System.Text.Json.JsonElement]$Intent,
    [Parameter(Mandatory)][byte[]]$ReceiptBytes,
    [Parameter(Mandatory)][System.Text.Json.JsonElement]$CommittedOutputManifest,
    [Parameter(Mandatory)][System.Text.Json.JsonElement]$BeforeOutputs,
    [Parameter(Mandatory)][System.Text.Json.JsonElement]$AfterOutputs
  )

  Test-CoordH52CloseoutIntentAgainstReceipt @PSBoundParameters -ReviewedReceiptSha256 'bc100d3f0f06cb21bc91c4da82745285b13e33d992b6146098886a6d3d17ddba'
}

function Test-CoordH52CloseoutIntentAgainstReceipt {
  # Pure implementation shared with synthetic tests. The live caller must use
  # Test-CoordH52CloseoutIntent and must never derive a trust pin from the input.
  [CmdletBinding()]
  [OutputType([bool])]
  param(
    [Parameter(Mandatory)][System.Text.Json.JsonElement]$Intent,
    [Parameter(Mandatory)][byte[]]$ReceiptBytes,
    [Parameter(Mandatory)][System.Text.Json.JsonElement]$CommittedOutputManifest,
    [Parameter(Mandatory)][System.Text.Json.JsonElement]$BeforeOutputs,
    [Parameter(Mandatory)][System.Text.Json.JsonElement]$AfterOutputs,
    [Parameter(Mandatory)][ValidatePattern('\A[0-9a-f]{64}\z', Options = 'None')][string]$ReviewedReceiptSha256
  )

  $ordinal = [StringComparer]::Ordinal
  $expectedIds = @('17.52.a', '17.52.b')
  $fileNames = [ordered]@{
    markdown = 'Tasks.Sprint0017.md'
    boardHtml = 'Tasks.Sprint0017.html'
    proceduralDetailsHtml = 'Tasks.Sprint0017.ProceduralDetails.html'
    accomplishedHtml = 'Tasks.Sprint0017.Accomplished.html'
  }

  function Assert-ClosedObject([System.Text.Json.JsonElement]$Element, [string[]]$Names) {
    if ($Element.ValueKind -ne [System.Text.Json.JsonValueKind]::Object -or
        @($Element.EnumerateObject()).Count -ne $Names.Count) { throw 'H52InvalidShape' }
    foreach ($name in $Names) {
      $property = [System.Text.Json.JsonElement]::new()
      if (-not $Element.TryGetProperty($name, [ref]$property)) { throw 'H52InvalidShape' }
    }
  }

  function Assert-TaskSet([string[]]$TaskIds) {
    $ids = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($id in $TaskIds) { $null = $ids.Add($id) }
    if ($TaskIds.Count -ne 2 -or -not $ids.SetEquals([string[]]$expectedIds)) { throw 'H52UnexpectedTaskSet' }
  }

  function Assert-FileImage([System.Text.Json.JsonElement]$Image, [string]$Path, [string]$ExpectedDigest) {
    Assert-ClosedObject $Image @('path', 'bytesBase64', 'digest')
    if (-not $ordinal.Equals($Image.GetProperty('path').GetString(), $Path)) { throw 'H52PathMismatch' }

    $encoded = $Image.GetProperty('bytesBase64').GetString()
    if ($null -eq $encoded) { throw 'H52InvalidImage' }
    try { $bytes = [Convert]::FromBase64String($encoded) } catch [FormatException] { throw 'H52InvalidImage' }
    if (-not $ordinal.Equals([Convert]::ToBase64String($bytes), $encoded)) { throw 'H52InvalidImage' }
    if (-not $ordinal.Equals($Image.GetProperty('digest').GetString(), $ExpectedDigest) -or
        -not $ordinal.Equals((Get-CoordHash $bytes), $ExpectedDigest)) { throw 'H52DigestMismatch' }
  }

  Assert-ClosedObject $Intent @('kind', 'taskIds', 'receiptSha256', 'outputs')
  if (-not $ordinal.Equals($Intent.GetProperty('kind').GetString(), 'Coordination-h52-closeout-intent-v1')) {
    throw 'H52InvalidIntentKind'
  }
  $taskIds = @($Intent.GetProperty('taskIds').EnumerateArray() | ForEach-Object { $_.GetString() })
  Assert-TaskSet $taskIds

  # Verify and parse the same immutable snapshot of the caller's byte array.
  $receiptSnapshot = [byte[]]$ReceiptBytes.Clone()
  if (-not $ordinal.Equals($Intent.GetProperty('receiptSha256').GetString(), $ReviewedReceiptSha256) -or
      -not $ordinal.Equals((Get-CoordHash $receiptSnapshot), $ReviewedReceiptSha256)) { throw 'H52ReceiptPinMismatch' }
  $receipt = Read-CoordJsonBytes $receiptSnapshot
  if (-not $ordinal.Equals($receipt.GetProperty('Outcome').GetString(), 'CandidateVerified') -or
      -not $ordinal.Equals($receipt.GetProperty('BoardHold').GetString(), 'ALL_TASKS') -or
      $receipt.GetProperty('MarkdownTaskCount').GetInt32() -ne 188 -or
      $receipt.GetProperty('HtmlTaskCount').GetInt32() -ne 188 -or
      -not $receipt.GetProperty('OtherHtmlStreamAndTaskFieldsEqual').GetBoolean()) { throw 'H52InvalidReceipt' }

  $markdownIds = @($receipt.GetProperty('MarkdownDelta').EnumerateArray() | ForEach-Object { $_.GetProperty('TaskId').GetString() })
  Assert-TaskSet $markdownIds
  $htmlIds = @(foreach ($row in $receipt.GetProperty('HtmlDelta').EnumerateArray()) {
    if (-not $ordinal.Equals($row.GetProperty('Before').GetString(), 'open') -or
        -not $ordinal.Equals($row.GetProperty('After').GetString(), 'closed')) { throw 'H52InvalidReceipt' }
    $row.GetProperty('TaskId').GetString()
  })
  Assert-TaskSet $htmlIds

  $files = $receipt.GetProperty('Files')
  if ($files.GetArrayLength() -ne 4) { throw 'H52InvalidReceipt' }
  $intentOutputs = $Intent.GetProperty('outputs')
  foreach ($quartet in @($CommittedOutputManifest, $intentOutputs, $BeforeOutputs, $AfterOutputs)) {
    Assert-ClosedObject $quartet @($fileNames.Keys)
  }

  $boardRoot = $null
  foreach ($slot in $fileNames.Keys) {
    $name = $fileNames[$slot]
    $file = @($files.EnumerateArray() | Where-Object { $ordinal.Equals($_.GetProperty('Name').GetString(), $name) })
    if ($file.Count -ne 1) { throw 'H52InvalidReceipt' }
    $beforePin = $file[0].GetProperty('RetainedCommittedManifestSha256').GetString().ToLowerInvariant()
    $afterPin = $file[0].GetProperty('CandidateSha256').GetString().ToLowerInvariant()
    if (-not $ordinal.Equals($file[0].GetProperty('ActiveBeforeSha256').GetString().ToLowerInvariant(), $beforePin) -or
        -not $ordinal.Equals($file[0].GetProperty('ActiveAfterSha256').GetString().ToLowerInvariant(), $beforePin)) {
      throw 'H52InvalidReceipt'
    }

    $manifestEntry = $CommittedOutputManifest.GetProperty($slot)
    $intentEntry = $intentOutputs.GetProperty($slot)
    Assert-ClosedObject $manifestEntry @('path', 'digest')
    Assert-ClosedObject $intentEntry @('path', 'beforeSha256', 'afterSha256')
    $path = $manifestEntry.GetProperty('path').GetString()
    if ([string]::IsNullOrEmpty($path) -or $path -cnotmatch '\A[A-Za-z]:[\\/]' -or
        -not $ordinal.Equals($path, $intentEntry.GetProperty('path').GetString()) -or
        -not $ordinal.Equals([IO.Path]::GetFileName($path), $name) -or
        -not $ordinal.Equals([IO.Path]::GetFullPath($path), $path.Replace('/', '\'))) { throw 'H52PathMismatch' }
    $parent = [IO.Path]::GetDirectoryName($path)
    if ($null -eq $boardRoot) { $boardRoot = $parent }
    if (-not $ordinal.Equals($boardRoot, $parent)) { throw 'H52PathMismatch' }

    if (-not $ordinal.Equals($manifestEntry.GetProperty('digest').GetString(), $beforePin) -or
        -not $ordinal.Equals($intentEntry.GetProperty('beforeSha256').GetString(), $beforePin) -or
        -not $ordinal.Equals($intentEntry.GetProperty('afterSha256').GetString(), $afterPin)) { throw 'H52DigestMismatch' }

    $beforeImage = $BeforeOutputs.GetProperty($slot)
    $afterImage = $AfterOutputs.GetProperty($slot)
    Assert-FileImage $beforeImage $path $beforePin
    Assert-FileImage $afterImage $path $afterPin
    $unchanged = $ordinal.Equals($beforeImage.GetProperty('bytesBase64').GetString(), $afterImage.GetProperty('bytesBase64').GetString())
    if ($unchanged -ne $ordinal.Equals($slot, 'proceduralDetailsHtml')) { throw 'H52UnexpectedQuartetDelta' }
  }

  return $true
}
