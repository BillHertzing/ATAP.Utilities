#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.2.0' }

BeforeAll {
  . (Join-Path $PSScriptRoot '../../private/CoordProducerJson.ps1')
  . (Join-Path $PSScriptRoot '../../private/Test-CoordH52CloseoutIntent.ps1')

  function New-H52IntentFixture {
    $utf8 = [Text.UTF8Encoding]::new($false, $true)
    $names = [ordered]@{
      markdown = 'Tasks.Sprint0017.md'
      boardHtml = 'Tasks.Sprint0017.html'
      proceduralDetailsHtml = 'Tasks.Sprint0017.ProceduralDetails.html'
      accomplishedHtml = 'Tasks.Sprint0017.Accomplished.html'
    }
    $beforeOutputs = [ordered]@{}
    $afterOutputs = [ordered]@{}
    $manifest = [ordered]@{}
    $intentOutputs = [ordered]@{}
    $files = @(foreach ($slot in $names.Keys) {
      $path = 'C:\H52-Synthetic\' + $names[$slot]
      $before = $utf8.GetBytes("synthetic $slot before")
      $after = if ($slot -eq 'proceduralDetailsHtml') { $before } else { $utf8.GetBytes("synthetic $slot after") }
      $beforePin = Get-CoordHash $before
      $afterPin = Get-CoordHash $after
      $beforeOutputs[$slot] = [ordered]@{ path = $path; digest = $beforePin; bytesBase64 = [Convert]::ToBase64String($before) }
      $afterOutputs[$slot] = [ordered]@{ path = $path; digest = $afterPin; bytesBase64 = [Convert]::ToBase64String($after) }
      $manifest[$slot] = [ordered]@{ path = $path; digest = $beforePin }
      $intentOutputs[$slot] = [ordered]@{ path = $path; beforeSha256 = $beforePin; afterSha256 = $afterPin }
      [ordered]@{
        Name = $names[$slot]; RetainedCommittedManifestSha256 = $beforePin.ToUpperInvariant()
        ActiveBeforeSha256 = $beforePin.ToUpperInvariant(); ActiveAfterSha256 = $beforePin.ToUpperInvariant()
        CandidateSha256 = $afterPin.ToUpperInvariant()
      }
    })

    $receipt = [ordered]@{
      Outcome = 'CandidateVerified'; BoardHold = 'ALL_TASKS'; MarkdownTaskCount = 188; HtmlTaskCount = 188
      OtherHtmlStreamAndTaskFieldsEqual = $true
      MarkdownDelta = @(@{ TaskId = '17.52.a' }, @{ TaskId = '17.52.b' })
      HtmlDelta = @(
        @{ TaskId = '17.52.a'; Before = 'open'; After = 'closed' }
        @{ TaskId = '17.52.b'; Before = 'open'; After = 'closed' }
      )
      Files = $files
    }
    $receiptBytes = $utf8.GetBytes((ConvertTo-Json -InputObject $receipt -Depth 12 -Compress))
    $receiptPin = Get-CoordHash $receiptBytes
    [pscustomobject]@{
      Receipt = $receipt; ReceiptBytes = $receiptBytes; ReceiptPin = $receiptPin
      Intent = [ordered]@{
        kind = 'Coordination-h52-closeout-intent-v1'
        taskIds = @('17.52.a', '17.52.b')
        receiptSha256 = $receiptPin
        outputs = $intentOutputs
      }
      Manifest = $manifest; Before = $beforeOutputs; After = $afterOutputs
    }
  }

  function Set-H52SyntheticReceiptPin($Fixture) {
    # Re-pin only a synthetic fixture to reach the structural checks after the receipt digest check.
    $Fixture.ReceiptBytes = [Text.Encoding]::UTF8.GetBytes((ConvertTo-Json -InputObject $Fixture.Receipt -Depth 12 -Compress))
    $Fixture.ReceiptPin = Get-CoordHash $Fixture.ReceiptBytes
    $Fixture.Intent.receiptSha256 = $Fixture.ReceiptPin
  }

  function Invoke-H52IntentFixture($Fixture, [switch]$UseReviewedPin) {
    $arguments = @{
      Intent = ConvertTo-CoordElement $Fixture.Intent
      ReceiptBytes = $Fixture.ReceiptBytes
      CommittedOutputManifest = ConvertTo-CoordElement $Fixture.Manifest
      BeforeOutputs = ConvertTo-CoordElement $Fixture.Before
      AfterOutputs = ConvertTo-CoordElement $Fixture.After
    }
    if ($UseReviewedPin) { return (Test-CoordH52CloseoutIntent @arguments) }
    Test-CoordH52CloseoutIntentAgainstReceipt @arguments -ReviewedReceiptSha256 $Fixture.ReceiptPin
  }
}

Describe 'Exact H52 closeout intent validation in memory' -Tag 'Unit', 'C2065H52ExactCloseoutIntent' {
  BeforeEach {
    $fixture = New-H52IntentFixture
  }

  It 'accepts the exact pair and quartet without modifying the supplied inputs' {
    $fixture.Intent.taskIds = @('17.52.b', '17.52.a')
    $receiptBefore = [Convert]::ToBase64String($fixture.ReceiptBytes)
    $intentBefore = (ConvertTo-CoordElement $fixture.Intent).GetRawText()
    $imagesBefore = (ConvertTo-CoordElement $fixture.After).GetRawText()

    Invoke-H52IntentFixture $fixture | Should -BeTrue

    [Convert]::ToBase64String($fixture.ReceiptBytes) | Should -BeExactly $receiptBefore
    (ConvertTo-CoordElement $fixture.Intent).GetRawText() | Should -BeExactly $intentBefore
    (ConvertTo-CoordElement $fixture.After).GetRawText() | Should -BeExactly $imagesBefore
  }

  It 'refuses a self-pinned synthetic receipt at the fixed-pin entry point' {
    { Invoke-H52IntentFixture $fixture -UseReviewedPin } | Should -Throw 'H52ReceiptPinMismatch'
  }

  It 'refuses <Fault> in the receipt pin chain' -ForEach @(
    @{ Fault = 'changed receipt bytes' }
    @{ Fault = 'changed intent receipt digest' }
  ) {
    if ($Fault -eq 'changed receipt bytes') { $fixture.ReceiptBytes += [byte]32 }
    else { $fixture.Intent.receiptSha256 = 'a' * 64 }
    { Invoke-H52IntentFixture $fixture } | Should -Throw 'H52ReceiptPinMismatch'
  }

  It 'refuses task substitution <Fault>' -ForEach @(
    @{ Fault = 'missing leaf'; Tasks = @('17.52.a') }
    @{ Fault = 'extra leaf'; Tasks = @('17.52.a', '17.52.b', '17.52.d') }
    @{ Fault = 'duplicate leaf'; Tasks = @('17.52.a', '17.52.a') }
    @{ Fault = 'case variant'; Tasks = @('17.52.a', '17.52.B') }
    @{ Fault = 'ignorable suffix'; Tasks = @('17.52.a', ('17.52.b' + [char]0x00AD)) }
  ) {
    $fixture.Intent.taskIds = $Tasks
    { Invoke-H52IntentFixture $fixture } | Should -Throw 'H52UnexpectedTaskSet'
  }

  It 'refuses additional intent, output slot or image fields (<Fault>)' -ForEach @(
    @{ Fault = 'top-level flag' }
    @{ Fault = 'extra slot' }
    @{ Fault = 'extra image field' }
    @{ Fault = 'missing slot' }
  ) {
    switch ($Fault) {
      'top-level flag' { $fixture.Intent.approved = $true }
      'extra slot' { $fixture.Intent.outputs.additionalHtml = $fixture.Intent.outputs.boardHtml }
      'extra image field' { $fixture.After.markdown.reparse = $true }
      'missing slot' { $fixture.Before.Remove('boardHtml') }
    }
    { Invoke-H52IntentFixture $fixture } | Should -Throw 'H52InvalidShape'
  }

  It 'refuses duplicate JSON slot members even when both values are identical' {
    $intent = (ConvertTo-CoordElement $fixture.Intent).GetRawText()
    $entry = (ConvertTo-CoordElement $fixture.Intent.outputs.markdown).GetRawText()
    $duplicate = $intent.Replace('"markdown":', ('"markdown":' + $entry + ',"markdown":'))
    $document = [System.Text.Json.JsonDocument]::Parse($duplicate)
    try {
      {
        Test-CoordH52CloseoutIntentAgainstReceipt -Intent $document.RootElement -ReceiptBytes $fixture.ReceiptBytes -ReviewedReceiptSha256 $fixture.ReceiptPin -CommittedOutputManifest (ConvertTo-CoordElement $fixture.Manifest) -BeforeOutputs (ConvertTo-CoordElement $fixture.Before) -AfterOutputs (ConvertTo-CoordElement $fixture.After)
      } | Should -Throw 'H52InvalidShape'
    } finally {
      $document.Dispose()
    }
  }

  It 'refuses <Fault> in the reviewed quartet binding' -ForEach @(
    @{ Fault = 'before manifest digest'; Error = 'H52DigestMismatch' }
    @{ Fault = 'after intent digest'; Error = 'H52DigestMismatch' }
    @{ Fault = 'candidate byte change'; Error = 'H52DigestMismatch' }
    @{ Fault = 'before byte change'; Error = 'H52DigestMismatch' }
    @{ Fault = 'noncanonical base64'; Error = 'H52InvalidImage' }
    @{ Fault = 'redirected path'; Error = 'H52PathMismatch' }
    @{ Fault = 'swapped slot'; Error = 'H52PathMismatch' }
    @{ Fault = 'noncanonical path'; Error = 'H52PathMismatch' }
  ) {
    switch ($Fault) {
      'before manifest digest' { $fixture.Manifest.markdown.digest = 'a' * 64 }
      'after intent digest' { $fixture.Intent.outputs.boardHtml.afterSha256 = 'a' * 64 }
      'candidate byte change' { $fixture.After.accomplishedHtml.bytesBase64 = 'YQ==' }
      'before byte change' { $fixture.Before.boardHtml.bytesBase64 = 'YQ==' }
      'noncanonical base64' { $fixture.After.boardHtml.bytesBase64 += ' ' }
      'redirected path' { $fixture.After.markdown.path = 'C:\Other\Tasks.Sprint0017.md' }
      'swapped slot' { $fixture.After.markdown = $fixture.After.boardHtml }
      'noncanonical path' {
        $path = 'C:\H52-Synthetic\sub\..\Tasks.Sprint0017.md'
        $fixture.Manifest.markdown.path = $path
        $fixture.Intent.outputs.markdown.path = $path
        $fixture.Before.markdown.path = $path
        $fixture.After.markdown.path = $path
      }
    }
    { Invoke-H52IntentFixture $fixture } | Should -Throw $Error
  }

  It 'refuses a changed ProceduralDetails even when a synthetic receipt pins the changed bytes' {
    $bytes = [Text.Encoding]::UTF8.GetBytes('changed synthetic procedural details')
    $digest = Get-CoordHash $bytes
    $fixture.After.proceduralDetailsHtml.bytesBase64 = [Convert]::ToBase64String($bytes)
    $fixture.After.proceduralDetailsHtml.digest = $digest
    $fixture.Intent.outputs.proceduralDetailsHtml.afterSha256 = $digest
    ($fixture.Receipt.Files | Where-Object Name -EQ 'Tasks.Sprint0017.ProceduralDetails.html').CandidateSha256 = $digest
    Set-H52SyntheticReceiptPin $fixture

    { Invoke-H52IntentFixture $fixture } | Should -Throw 'H52UnexpectedQuartetDelta'
  }

  It 'refuses <Fault> even in a separately pinned synthetic receipt' -ForEach @(
    @{ Fault = 'different HTML leaf'; Error = 'H52UnexpectedTaskSet' }
    @{ Fault = 'different Markdown leaf'; Error = 'H52UnexpectedTaskSet' }
    @{ Fault = 'unexpected HTML status'; Error = 'H52InvalidReceipt' }
    @{ Fault = 'duplicate file pin'; Error = 'H52InvalidReceipt' }
    @{ Fault = 'baseline drift'; Error = 'H52InvalidReceipt' }
  ) {
    switch ($Fault) {
      'different HTML leaf' { $fixture.Receipt.HtmlDelta[0].TaskId = '17.52.d' }
      'different Markdown leaf' { $fixture.Receipt.MarkdownDelta[0].TaskId = '17.52.d' }
      'unexpected HTML status' { $fixture.Receipt.HtmlDelta[0].After = 'partial' }
      'duplicate file pin' { $fixture.Receipt.Files[0].Name = $fixture.Receipt.Files[1].Name }
      'baseline drift' { $fixture.Receipt.Files[0].ActiveAfterSha256 = 'a' * 64 }
    }
    Set-H52SyntheticReceiptPin $fixture

    { Invoke-H52IntentFixture $fixture } | Should -Throw $Error
  }
}
