function New-CoordBoardChange {
  <#
  .SYNOPSIS
    Previews one existing task's Status-value annotation without preparing it.
  .DESCRIPTION
    Annotation-only first slice. AcceptChange.approvedChange must contain exactly
    annotation; every status/checkbox/completion operation is UnsupportedChange.
    Replaces exactly one active "  - Status: " value in the selected task, retaining
    its prefix, line ending and all outside text/bytes. Fenced/HTML task blocks,
    ambiguous/missing Status lines and unsupported annotation grammar are refused.
    The derived open/partial/closed category must remain unchanged. This pure
    policy mirror is bound to SprintLifecycle converter 0.1.60: x/X is closed,
    ~ is partial, otherwise Status containing partial|blocked|in-progress is
    partial (case-insensitive substring), else open. Inline text normalization
    follows that consumer; continued Status fields are UnsupportedChange because
    this preview edits one line only. Consumer policy changes require contract/test
    revalidation; this is not a shared runtime classifier.

    Snapshot is from Read-CoordBoard with pinned function-code identity D80978CB.
    snapshotParserSha256 remains the ACTUAL adjacent reader file's whole-file SHA,
    including its signature. This function re-reads that file, checks that binding,
    then parses without execution and requires only the exact pinned function.
    Standard Authenticode comments outside the function do not change code identity;
    different code or additional top-level script constructs are refused. Package
    signature/custody verification remains the trusted caller's responsibility.
    Request and
    AppliedReport are caller-validated accepted request/state-record JsonElements.
    Context is a PRIVATE trusted-caller binding, not a grant. Required keys:
    coordinatorId, resourceId, sprintId, generation, committedRevision, taskId,
    authorizationReference, holder, scope, claimId, reportRequestId, reportDigest,
    evidence, snapshotSha256, snapshotParserSha256. It binds current actual head,
    exact approved report/digests/evidence, holder/session, original ordered scope
    and this exact snapshot. The caller must separately prove current authority,
    custody/exclusion, resource/sprint registration, resolved containment, canonical
    identity/retry/causality and actual evidence before preparation. Context and
    Applied labels alone prove none of those facts.

    Report's historical expected revision is not silently rebased or required to
    equal the current head. Current Request/context revision must match. This slice
    supports the same ordered evidence inventory on approval/report/context only.
    It performs no role, deployment, receipt-authentication or full S3 admission.

    Annotation grammar is conservative single-line ASCII prose beginning with a
    letter/digit, using letters/digits/spaces and .,:;/()_=@+!?- only. Reserved
    task/status/control labels and whole-word completion assertions are refused.
    No Markdown/HTML, controls, Unicode line separators, fences or injected lines.
    This is a bounded preview grammar, not general Markdown editing or a full
    natural-language approval classifier. Caller remains responsible for meaning.

    Reservations is the complete caller-validated original inventory, including
    reservations absent from the board. It is cloned unchanged, never allocated,
    filtered, freed or inferred from visible tasks. Neither tasks nor state are
    mutated. Only the adjacent parser file is read; no renderer, revision or
    preparation receipt is produced.
  .PARAMETER Snapshot
    Original caller-bound Read-CoordBoard object with Text/RawBytes/Sha256/Tasks.
  .PARAMETER Request
    Validated AcceptChange request object, without envelope or transport.
  .PARAMETER AppliedReport
    Validated Applied stateRequestRecord for the exact ReportResult predecessor.
  .PARAMETER Context
    Trusted private bindings described above; never a self-authenticating grant.
  .PARAMETER Reservations
    Caller-validated JsonElement array; returned as an unchanged independent clone.
  .OUTPUTS
    PSCustomObject Stage=ProposedNotPrepared, RequestId, TaskId, base epoch/revision,
    BeforeSha256/AfterSha256, independent BeforeBytes/AfterBytes, AfterText and
    unchanged cloned Reservations. It is not publication or feature completion.
  .NOTES
    WhatIf/Confirm exist by convention; this pure preview has no durable mutation.
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)][ValidateNotNull()] [PSCustomObject]$Snapshot,
    [Parameter(Mandatory)] [System.Text.Json.JsonElement]$Request,
    [Parameter(Mandatory)] [System.Text.Json.JsonElement]$AppliedReport,
    [Parameter(Mandatory)] [System.Text.Json.JsonElement]$Context,
    [Parameter(Mandatory)] [System.Text.Json.JsonElement]$Reservations
  )

  begin {
    $fn = 'New-CoordBoardChange'
    $mn = 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell'
    $null = Get-Command -Name 'Write-PSFMessage' -ErrorAction Stop
    $utf8 = [System.Text.UTF8Encoding]::new($false, $true)

    function equalText {
      param([string]$Left, [string]$Right)
      [string]::Equals($Left, $Right, [System.StringComparison]::Ordinal)
    }
    function assertParserIdentity {
      param([string]$ActualFileSha256)
      try {
        $moduleRoot = if ((Split-Path $PSScriptRoot -Leaf) -ieq 'private') { Split-Path $PSScriptRoot -Parent } else { $PSScriptRoot }
        $parserPath = Join-Path $moduleRoot 'private/Read-CoordBoard.ps1'
        $parserBytes = [IO.File]::ReadAllBytes($parserPath)
        $fileSha256 = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($parserBytes)).ToLowerInvariant()
        if (-not (equalText $ActualFileSha256 $fileSha256)) { throw 'SnapshotMismatch' }
        $tokens = $null; $errors = $null
        $ast = [Management.Automation.Language.Parser]::ParseInput($utf8.GetString($parserBytes), $parserPath, [ref]$tokens, [ref]$errors)
        $statements = @($ast.EndBlock.Statements)
        if ($errors.Count -ne 0 -or $null -ne $ast.ParamBlock -or $null -ne $ast.BeginBlock -or
            $null -ne $ast.ProcessBlock -or $null -ne $ast.CleanBlock -or $null -ne $ast.DynamicParamBlock -or
            $null -ne $ast.ScriptRequirements -or $ast.Attributes.Count -ne 0 -or $ast.UsingStatements.Count -ne 0 -or
            $null -eq $ast.EndBlock -or -not $ast.EndBlock.Unnamed -or $ast.EndBlock.Traps.Count -ne 0 -or
            $statements.Count -ne 1 -or $statements[0] -isnot [Management.Automation.Language.FunctionDefinitionAst] -or
            $statements[0].Name -cne 'Read-CoordBoard' -or $statements[0].IsFilter -or $statements[0].IsWorkflow) {
          throw 'SnapshotMismatch'
        }
        $codeSha256 = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($utf8.GetBytes($statements[0].Extent.Text))).ToLowerInvariant()
        if (-not (equalText $codeSha256 'd80978cbdad2daed364ac171ddfafe5c4db27a5c7b9acf2407496e62e4f55898')) { throw 'SnapshotMismatch' }
      } catch { throw 'SnapshotMismatch' }
    }
    function derivedStatus {
      param([string]$Checkbox, [string]$StatusText)
      $StatusText = ($StatusText -replace '\s+', ' ').Trim()
      $StatusText = $StatusText -replace '\*\*(.+?)\*\*', '$1'
      $StatusText = $StatusText -replace '`(.+?)`', '$1'
      if ($Checkbox -eq 'x') { return 'closed' }
      if ($Checkbox -eq '~') { return 'partial' }
      if ($StatusText -match 'partial|blocked|in-progress') { return 'partial' }
      return 'open'
    }
    function textValue {
      param([System.Text.Json.JsonElement]$Object, [string]$Name)
      $value = $Object.GetProperty($Name)
      if ($value.ValueKind -ne [System.Text.Json.JsonValueKind]::String -or $value.GetString().Length -eq 0) { throw 'InvalidInput' }
      $value.GetString()
    }
    function closedMembers {
      param([System.Text.Json.JsonElement]$Object, [string[]]$Names)
      if ($Object.ValueKind -ne [System.Text.Json.JsonValueKind]::Object) { throw 'InvalidInput' }
      $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
      foreach ($property in $Object.EnumerateObject()) { if (-not $seen.Add($property.Name)) { throw 'InvalidInput' } }
      if ($seen.Count -ne $Names.Count) { throw 'InvalidInput' }
      foreach ($name in $Names) { if (-not $seen.Contains($name)) { throw 'InvalidInput' } }
    }
    function sameScope {
      param([System.Text.Json.JsonElement]$Left, [System.Text.Json.JsonElement]$Right)
      if ($Left.ValueKind -ne [System.Text.Json.JsonValueKind]::Array -or
          $Right.ValueKind -ne [System.Text.Json.JsonValueKind]::Array -or
          $Left.GetArrayLength() -eq 0 -or $Left.GetArrayLength() -ne $Right.GetArrayLength()) { return $false }
      for ($i = 0; $i -lt $Left.GetArrayLength(); $i++) {
        foreach ($name in @('registeredRootId', 'path')) {
          if (-not (equalText (textValue $Left[$i] $name) (textValue $Right[$i] $name))) { return $false }
        }
      }
      return $true
    }
    function sameEvidence {
      param([System.Text.Json.JsonElement]$Left, [System.Text.Json.JsonElement]$Right)
      if ($Left.ValueKind -ne [System.Text.Json.JsonValueKind]::Array -or
          $Right.ValueKind -ne [System.Text.Json.JsonValueKind]::Array -or
          $Left.GetArrayLength() -ne $Right.GetArrayLength()) { return $false }
      for ($i = 0; $i -lt $Left.GetArrayLength(); $i++) {
        if (-not (equalText (textValue $Left[$i] 'reference') (textValue $Right[$i] 'reference'))) { return $false }
        foreach ($name in @('algorithm', 'value')) {
          if (-not (equalText (textValue $Left[$i].GetProperty('digest') $name) (textValue $Right[$i].GetProperty('digest') $name))) { return $false }
        }
      }
      return $true
    }
  }

  process {
    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Previewing one existing-task annotation'
      closedMembers $Context @('coordinatorId', 'resourceId', 'sprintId', 'generation', 'committedRevision',
        'taskId', 'authorizationReference', 'holder', 'scope', 'claimId', 'reportRequestId', 'reportDigest',
        'evidence', 'snapshotSha256', 'snapshotParserSha256')
      $null = textValue $Context 'coordinatorId'
      assertParserIdentity (textValue $Context 'snapshotParserSha256')
      if (-not (equalText (textValue $Request 'protocolVersion') 'Coordination-v1') -or
          -not (equalText (textValue $Request 'category') 'AcceptChange')) { throw 'UnsupportedChange' }
      $payload = $Request.GetProperty('payload')
      $change = $payload.GetProperty('approvedChange')
      $changeNames = @($change.EnumerateObject() | ForEach-Object { $_.Name })
      if ($changeNames.Count -ne 1 -or -not (equalText $changeNames[0] 'annotation')) { throw 'UnsupportedChange' }
      $annotation = textValue $change 'annotation'
      if (-not [regex]::IsMatch($annotation, '\A[A-Za-z0-9][A-Za-z0-9 .,:;/()_=@+!?-]*\z') -or
          [regex]::IsMatch($annotation, '\A(?:Task|Status|Files|Risk|Dependency|Acceptance|Goal|Stream) *:',
            [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::CultureInvariant) -or
          [regex]::IsMatch($annotation, '\b(?:done|complete|completed|closed|finished|accomplished|deployed)\b',
            [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::CultureInvariant)) { throw 'UnsupportedAnnotation' }

      foreach ($name in @('resourceId', 'sprintId', 'generation', 'taskId', 'authorizationReference')) {
        if (-not (equalText (textValue $Request $name) (textValue $Context $name))) { throw 'BindingMismatch' }
      }
      if (-not (equalText (textValue $Request 'expectedRevision') (textValue $Context 'committedRevision'))) { throw 'BindingMismatch' }
      $report = $AppliedReport.GetProperty('request')
      $reportPayload = $report.GetProperty('payload')
      $terminal = $AppliedReport.GetProperty('terminalEvidence')
      $reportId = textValue $payload 'reportRequestId'
      if (-not (equalText (textValue $report 'protocolVersion') 'Coordination-v1') -or
          -not (equalText (textValue $AppliedReport 'status') 'Applied') -or
          -not (equalText (textValue $terminal 'status') 'Applied') -or
          -not (equalText (textValue $report 'category') 'ReportResult') -or
          -not (equalText $reportId (textValue $report 'requestId')) -or
          -not (equalText $reportId (textValue $Context 'reportRequestId')) -or
          -not (equalText $reportId (textValue $terminal 'requestId')) -or
          -not (equalText (textValue $AppliedReport 'digest') (textValue $Context 'reportDigest')) -or
          -not (equalText (textValue $AppliedReport 'digest') (textValue $terminal 'digest')) -or
          -not (equalText (textValue $reportPayload 'claimId') (textValue $Context 'claimId'))) { throw 'ReportMismatch' }
      foreach ($name in @('resourceId', 'sprintId', 'taskId')) {
        if (-not (equalText (textValue $report $name) (textValue $Context $name))) { throw 'ReportMismatch' }
      }
      if (-not (equalText (textValue $terminal 'resourceId') (textValue $Context 'resourceId'))) { throw 'ReportMismatch' }
      foreach ($name in @('holderId', 'sessionId')) {
        $expected = textValue $Context.GetProperty('holder') $name
        if (-not (equalText (textValue $Request.GetProperty('holder') $name) $expected) -or
            -not (equalText (textValue $report.GetProperty('holder') $name) $expected)) { throw 'BindingMismatch' }
      }
      if (-not (sameScope $Request.GetProperty('scope') $Context.GetProperty('scope')) -or
          -not (sameScope $report.GetProperty('scope') $Context.GetProperty('scope')) -or
          -not (sameEvidence $payload.GetProperty('evidence') $Context.GetProperty('evidence')) -or
          -not (sameEvidence $reportPayload.GetProperty('evidence') $Context.GetProperty('evidence'))) { throw 'ReportMismatch' }
      $foundPredecessor = $false
      foreach ($id in $Request.GetProperty('predecessors').EnumerateArray()) {
        if (equalText $id.GetString() $reportId) { $foundPredecessor = $true }
      }
      if (-not $foundPredecessor) { throw 'ReportMismatch' }
      if ($Reservations.ValueKind -ne [System.Text.Json.JsonValueKind]::Array) { throw 'InvalidInput' }

      if ($Snapshot.RawBytes -isnot [byte[]] -or $Snapshot.Text -isnot [string] -or $Snapshot.Tasks -isnot [array]) { throw 'SnapshotMismatch' }
      [byte[]]$beforeBytes = $Snapshot.RawBytes.Clone()
      $beforeText = $utf8.GetString($beforeBytes)
      $beforeSha = [System.Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($beforeBytes)).ToLowerInvariant()
      if (-not (equalText $beforeText $Snapshot.Text) -or -not (equalText $beforeSha $Snapshot.Sha256) -or
          -not (equalText $beforeSha (textValue $Context 'snapshotSha256'))) { throw 'SnapshotMismatch' }
      $taskId = textValue $Request 'taskId'
      $ids = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
      $target = $null
      $lastEnd = 0
      $taskPattern = '^[ \t]*-[ \t]+\[(?<checkbox>[ xX~])\][ \t]+\*\*Task[ \t]+(?<id>[0-9]+\.[0-9]+[A-Za-z]*(?:\.[A-Za-z0-9]+(?:-[A-Za-z0-9]+)*)*)\*\*(?:[ \t]+\*{0,2}\[[^\]\r\n]+\]\*{0,2})*[ \t]+[-–—][ \t]+\S.*$'
      foreach ($task in $Snapshot.Tasks) {
        if ($task.Id -isnot [string] -or -not $ids.Add($task.Id) -or
            $task.StartOffset -isnot [int] -or $task.EndOffset -isnot [int] -or
            $task.StartOffset -lt $lastEnd -or $task.EndOffset -lt $task.StartOffset -or
            $task.EndOffset -gt $beforeText.Length -or
            -not (equalText $task.Text $beforeText.Substring($task.StartOffset, $task.EndOffset - $task.StartOffset))) { throw 'SnapshotMismatch' }
        $firstLine = [regex]::Match($task.Text, '\A[^\r\n]*').Value
        if (-not (equalText $firstLine $task.Heading)) { throw 'SnapshotMismatch' }
        $parseHeading = $firstLine
        if ($task.StartOffset -eq 0 -and $parseHeading.StartsWith([string][char]0xFEFF, [System.StringComparison]::Ordinal)) { $parseHeading = $parseHeading.Substring(1) }
        $parsedHeading = [regex]::Match($parseHeading, $taskPattern)
        if (-not $parsedHeading.Success -or -not (equalText $task.Id $parsedHeading.Groups['id'].Value) -or
            -not (equalText $task.Checkbox $parsedHeading.Groups['checkbox'].Value)) { throw 'SnapshotMismatch' }
        $lastEnd = $task.EndOffset
        if (equalText $task.Id $taskId) { $target = $task }
      }
      if ($null -eq $target) { throw 'UnknownTask' }
      if ([regex]::IsMatch($target.Text, '(?m)^[ \t]*(?:\x60{3,}|~{3,}|<!--|</?[A-Za-z])')) { throw 'UnsupportedGrammar' }
      $lines = @([regex]::Matches($target.Text, '[^\r\n]*(?:\r\n|\r|\n|\z)') | Where-Object { $_.Length -gt 0 })
      if ($lines.Count -eq 0) { throw 'SnapshotMismatch' }
      $heading = [regex]::Replace($lines[0].Value, '(?:\r\n|\r|\n)$', '')
      if (-not (equalText $heading $target.Heading)) { throw 'SnapshotMismatch' }
      $matches = [System.Collections.Generic.List[object]]::new()
      foreach ($line in $lines) {
        $match = [regex]::Match($line.Value, '\A(?<prefix>  - Status: )(?<value>[^\r\n]*)(?:\r\n|\r|\n|\z)\z')
        if ($line.Index -gt 0 -and [regex]::IsMatch([regex]::Replace($line.Value, '(?:\r\n|\r|\n)$', ''), $taskPattern)) { throw 'SnapshotMismatch' }
        if ([regex]::IsMatch($line.Value, '\A[ \t]*-[ \t]+Status[ \t]*:',
            [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::CultureInvariant) -and
            -not $match.Success) { throw 'UnsupportedGrammar' }
        if ($match.Success) { $matches.Add([PSCustomObject]@{ Line = $line; Match = $match }) }
      }
      if ($matches.Count -ne 1) { throw 'UnsupportedGrammar' }
      $selected = $matches[0]
      $valueGroup = $selected.Match.Groups['value']
      # Bound the same field as the consumer. Do not compare only the first line
      # when a wrapped Status value would also contribute to derived status.
      foreach ($line in $lines) {
        if ($line.Index -le $selected.Line.Index) { continue }
        $following = [regex]::Replace($line.Value, '(?:\r\n|\r|\n)$', '')
        if ([regex]::IsMatch($following, '^\s{2,}-\s+(?:Files|Do|Acceptance|Status):', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase) -or
            [regex]::IsMatch($following, '^\s{2,}-\s+Evidence(?:\s+(?:\([^)]+\)|[^:]+))?:', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) { break }
        if (-not [regex]::IsMatch($following, '^\s*-\s') -and
            [regex]::IsMatch($following, '^\s{4,}\S')) { throw 'UnsupportedChange' }
      }
      $beforeStatus = derivedStatus $target.Checkbox $valueGroup.Value
      $afterStatus = derivedStatus $target.Checkbox $annotation
      if (-not (equalText $beforeStatus $afterStatus)) { throw 'UnsupportedChange' }
      $start = $target.StartOffset + $selected.Line.Index + $valueGroup.Index
      $end = $start + $valueGroup.Length
      $afterText = $beforeText.Substring(0, $start) + $annotation + $beforeText.Substring($end)
      [byte[]]$afterBytes = $utf8.GetBytes($afterText)
      [PSCustomObject]@{
        Stage = 'ProposedNotPrepared'
        RequestId = textValue $Request 'requestId'
        TaskId = $taskId
        Generation = textValue $Context 'generation'
        BaseRevision = textValue $Context 'committedRevision'
        BeforeSha256 = $beforeSha
        AfterSha256 = [System.Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($afterBytes)).ToLowerInvariant()
        BeforeBytes = $beforeBytes
        AfterBytes = $afterBytes
        AfterText = $afterText
        Reservations = $Reservations.Clone()
      }
    } catch {
      $code = $_.Exception.Message
      $allowed = @('InvalidInput', 'UnsupportedChange', 'UnsupportedAnnotation', 'BindingMismatch',
        'ReportMismatch', 'SnapshotMismatch', 'UnknownTask', 'UnsupportedGrammar')
      $known = $false
      foreach ($diagnostic in $allowed) { if (equalText $code $diagnostic) { $known = $true; break } }
      if (-not $known) { $code = 'InvalidInput' }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message 'Board preview refused without mutation'
      throw [System.InvalidOperationException]::new("New-CoordBoardChange: $code.")
    }
  }

  end {}
}

