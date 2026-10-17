function Get-GeneratedRemediationManifestSelection {
  <#
  .SYNOPSIS
    Validates a raw JSON snapshot and selects generated-file duplicate candidates.
  .DESCRIPTION
    Pure, file-only SprintDuplicateSelection v1 contract. No live state or archive
    assurance is established. Every result is unapproved. Any invalid record
    invalidates the entire envelope. Internal helpers have no external effects.
  .PARAMETER ManifestJson
    Raw JSON, required so duplicate property names can be rejected before conversion.
  .PARAMETER CurrentSprintNumber
    Explicit protection boundary; never inferred from the environment or clock.
  .OUTPUTS
    One PSCustomObject with Valid, Errors, Rows, Approved and Verification fields.
  #>
  [CmdletBinding()]
  param(
    [AllowNull()][AllowEmptyString()][string]$ManifestJson,
    [int]$CurrentSprintNumber
  )

  begin {
    # Deliberately no logging/autoload: this selector must remain side-effect free.
    $errors = [Collections.Generic.List[string]]::new()
    $rows = [Collections.Generic.List[object]]::new()
  }
  process {
    function Test-ManifestNode {
      param([System.Text.Json.JsonElement]$Node, $Spec, [string]$Location)
      $kind = $Node.ValueKind.ToString()
      switch ($Spec.Type) {
        'object' {
          if ($kind -ne 'Object') { $errors.Add("$Location must be an object"); return }
          $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
          foreach ($property in $Node.EnumerateObject()) {
            if (-not $seen.Add($property.Name)) { $errors.Add("$Location has duplicate/alias property '$($property.Name)'") }
            if (-not $Spec.Fields.Contains($property.Name) -or $property.Name -cnotin @($Spec.Fields.Keys)) {
              $errors.Add("$Location has unknown property '$($property.Name)'")
            } else { Test-ManifestNode $property.Value $Spec.Fields[$property.Name] "$Location.$($property.Name)" }
          }
          foreach ($key in $Spec.Fields.Keys) {
            if (-not $seen.Contains($key)) { $errors.Add("$Location lacks '$key'") }
          }
        }
        'array' {
          if ($kind -ne 'Array') { $errors.Add("$Location must be an array"); return }
          $i = 0
          foreach ($element in $Node.EnumerateArray()) { Test-ManifestNode $element $Spec.Item "$Location[$i]"; $i++ }
        }
        'string' {
          if ($kind -ne 'String') { $errors.Add("$Location must be a string"); return }
          $value = $Node.GetString()
          if ([string]::IsNullOrWhiteSpace($value)) { $errors.Add("$Location cannot be blank") }
          if ($Spec.Pattern -and $value -cnotmatch $Spec.Pattern) { $errors.Add("$Location has invalid format") }
          if ($Spec.ContainsKey('Values') -and $value -cnotin $Spec['Values']) { $errors.Add("$Location has unsupported value") }
        }
        'integer' {
          if ($kind -ne 'Number' -or $Node.GetRawText() -cnotmatch '^(0|[1-9][0-9]*)$') {
            $errors.Add("$Location must be a nonnegative integer without coercion"); return
          }
          $number = 0L
          if (-not $Node.TryGetInt64([ref]$number)) { $errors.Add("$Location exceeds Int64") }
          if ($Spec.ContainsKey('Value') -and $number -ne $Spec.Value) { $errors.Add("$Location has unsupported value") }
        }
        'boolean' {
          if ($kind -notin @('True', 'False')) { $errors.Add("$Location must be boolean"); return }
          if ($Spec.ContainsKey('Value') -and $Node.GetBoolean() -ne $Spec.Value) { $errors.Add("$Location has forbidden value") }
        }
      }
    }

    function Test-ManifestPath {
      param([string]$Value, [bool]$Absolute)
      # Canonical lexical Windows paths only. No filesystem resolution occurs.
      if ($Absolute) {
        if ($Value -cnotmatch '^[A-Za-z]:[\\/]') { return $false }
        $tail = $Value.Substring(3)
      } else {
        if ($Value.Contains('\')) { return $false }
        $tail = $Value
      }
      if ($tail -match '[:<>"|?*]' -or $tail -match '[\x00-\x1f]') { return $false }
      foreach ($segment in ($tail -split '[\\/]')) {
        if (-not $segment -or $segment -in @('.', '..') -or $segment -match '[ .]$' -or
          $segment -match '^(?i:CON|PRN|AUX|NUL|COM[1-9\u00b9\u00b2\u00b3]|LPT[1-9\u00b9\u00b2\u00b3])(?:\.|$)') { return $false }
      }
      return $true
    }

    function ConvertTo-ManifestPathKey {
      param([string]$Value)
      return $Value.Replace('\', '/').ToUpperInvariant()
    }

    $text = @{ Type = 'string' }
    $hash = @{ Type = 'string'; Pattern = '^[a-fA-F0-9]{64}$' }
    $boolean = @{ Type = 'boolean' }
    $unapproved = @{ Type = 'boolean'; Value = $false }
    $stream = @{ Type = 'object'; Fields = [ordered]@{
        name = $text; bytes = @{ Type = 'integer' }; sha256 = $hash
        archiveMember = $text; restoreVerified = $boolean
      } }
    $file = @{ Type = 'object'; Fields = [ordered]@{
        repositoryIdentity = $text; root = $text; relativePath = $text
        bytes = @{ Type = 'integer' }; sha256 = $hash; tracked = $boolean
        streams = @{ Type = 'array'; Item = $stream }; streamInventoryComplete = $boolean
      } }
    $worktree = @{ Type = 'object'; Fields = [ordered]@{
        role = @{ Type = 'string'; Values = @('Stable', 'Sprint') }; root = $text
        head = @{ Type = 'string'; Pattern = '^([a-f0-9]{40}|[a-f0-9]{64})$' }
        indexSHA256 = $hash; stagedSHA256 = $hash; unstagedSHA256 = $hash; untrackedSHA256 = $hash
        inventoryComplete = @{ Type = 'boolean'; Value = $true }
      } }
    $rowSpec = @{ Type = 'object'; Fields = [ordered]@{
        id = $text; kind = @{ Type = 'string'; Values = @('File') }; baselineRowSHA256 = $hash
        source = $file; candidate = $file
        pathClassification = @{ Type = 'string'; Values = @('Regular', 'ReadableCloudPlaceholder', 'RedirectingLink', 'NestedRepository', 'Unknown') }
        protectionReasons = @{ Type = 'array'; Item = $text }
        proposedAction = @{ Type = 'string'; Values = @('EligibleCandidate', 'Hold', 'Preserve', 'Error') }
        approved = $unapproved
      } }
    $schema = @{ Type = 'object'; Fields = [ordered]@{
        schemaVersion = @{ Type = 'integer'; Value = 1 }; runId = $text; capturedUtc = $text; host = $text
        operation = @{ Type = 'string'; Values = @('SprintDuplicateSelection') }; approved = $unapproved
        repository = @{ Type = 'object'; Fields = [ordered]@{ identity = $text; commonGitDir = $text; stableRoot = $text; sprintRoot = $text } }
        worktrees = @{ Type = 'array'; Item = $worktree }
        baseline = @{ Type = 'object'; Fields = [ordered]@{
            origin = @{ Type = 'string'; Values = @('LiveStable', 'VerifiedArchive') }; manifestSHA256 = $hash; custodyReceiptSHA256 = $hash
          } }
        rows = @{ Type = 'array'; Item = $rowSpec }
      } }

    $document = $null
    try {
      if ($CurrentSprintNumber -lt 1 -or $CurrentSprintNumber -gt 9999) { $errors.Add('CurrentSprintNumber must be explicit and between 1 and 9999') }
      if ([string]::IsNullOrWhiteSpace($ManifestJson)) { $errors.Add('ManifestJson is empty') }
      else {
        $document = [System.Text.Json.JsonDocument]::Parse($ManifestJson)
        Test-ManifestNode $document.RootElement $schema '$'
      }
      if ($errors.Count -eq 0) {
        $manifest = ConvertFrom-Json -InputObject $ManifestJson -AsHashtable -Depth 64 -ErrorAction Stop
        $manifest.capturedUtc = $document.RootElement.GetProperty('capturedUtc').GetString()
        $timestamp = [DateTimeOffset]::MinValue
        if ($manifest.capturedUtc -cnotmatch '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,7})?Z$' -or
          -not [DateTimeOffset]::TryParse($manifest.capturedUtc, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$timestamp)) {
          $errors.Add('capturedUtc must be a valid UTC timestamp ending in Z')
        }
        $repository = $manifest.repository
        foreach ($field in @('commonGitDir', 'stableRoot', 'sprintRoot')) {
          if (-not (Test-ManifestPath $repository[$field] $true)) { $errors.Add("repository.$field is unsafe or noncanonical") }
        }
        $stableKey = ConvertTo-ManifestPathKey $repository.stableRoot
        $sprintKey = ConvertTo-ManifestPathKey $repository.sprintRoot
        if ($stableKey -eq $sprintKey -or $stableKey.StartsWith($sprintKey + '/') -or $sprintKey.StartsWith($stableKey + '/')) {
          $errors.Add('Stable and sprint roots must be distinct and non-nested')
        }
        if ($manifest.worktrees.Count -ne 2 -or @($manifest.worktrees | Where-Object role -CEQ 'Stable').Count -ne 1 -or
          @($manifest.worktrees | Where-Object role -CEQ 'Sprint').Count -ne 1) { $errors.Add('Exactly one Stable and one Sprint worktree are required') }
        foreach ($worktreeRecord in $manifest.worktrees) {
          $expectedRoot = if ($worktreeRecord.role -ceq 'Stable') { $repository.stableRoot } else { $repository.sprintRoot }
          if ($worktreeRecord.root -cne $expectedRoot) { $errors.Add('Worktree root binding mismatch') }
        }
        $ids = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $sourcePaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $candidatePaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach ($record in $manifest.rows) {
          if (-not $ids.Add($record.id)) { $errors.Add('Duplicate/alias row id') }
          $reasons = [Collections.Generic.List[string]]::new()
          foreach ($side in @('source', 'candidate')) {
            $fileRecord = $record[$side]
            $expectedRoot = if ($side -eq 'source') { $repository.stableRoot } else { $repository.sprintRoot }
            if ($fileRecord.root -cne $expectedRoot) { $errors.Add("$($record.id): $side root binding mismatch") }
            if (-not (Test-ManifestPath $fileRecord.relativePath $false) -or $fileRecord.relativePath -cnotmatch '^_generated/') {
              $errors.Add("$($record.id): unsafe/noncanonical relative path")
            }
            $paths = if ($side -eq 'source') { ,$sourcePaths } else { ,$candidatePaths }
            if (-not $paths.Add((ConvertTo-ManifestPathKey $fileRecord.relativePath))) { $errors.Add('Duplicate/alias file path') }
            if (-not $fileRecord.streamInventoryComplete) { $reasons.Add("$side ADS inventory incomplete") }
            $streamNames = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
            $members = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
            foreach ($streamRecord in $fileRecord.streams) {
              if ($streamRecord.name -match '[:/\\\x00-\x1f]' -or -not $streamNames.Add($streamRecord.name)) { $errors.Add('Unsafe/alias ADS name') }
              if (-not (Test-ManifestPath $streamRecord.archiveMember $false) -or -not $members.Add($streamRecord.archiveMember)) { $errors.Add('Unsafe/duplicate archive stream member') }
              if (-not $streamRecord.restoreVerified) { $reasons.Add("$side ADS restore not verified in supplied record") }
            }
            foreach ($segment in ($fileRecord.relativePath -split '[\\/]')) {
              if ($segment -ieq '.git') { $reasons.Add('Git metadata path') }
              foreach ($match in [regex]::Matches($segment, '(?i)sprint[-_]?(?:end[-_]?)?(\d+)')) {
                $sprintNumber = 0L
                $numericToken = $match.Groups[1].Value.TrimStart('0')
                if (-not $numericToken) { $numericToken = '0' }
                $suffix = $segment.Substring($match.Index + $match.Length)
                if (-not [long]::TryParse($numericToken, [ref]$sprintNumber) -or
                  $suffix -match '^(?:[.,]\d|[eE][+-]?\d)') {
                  $reasons.Add('Ambiguous/overflow sprint number')
                } elseif ($sprintNumber -ge $CurrentSprintNumber) { $reasons.Add('Current/future sprint path') }
              }
            }
          }
          foreach ($reason in $record.protectionReasons) { $reasons.Add("Explicit protection: $reason") }
          if ($record.pathClassification -notin @('Regular', 'ReadableCloudPlaceholder')) { $reasons.Add("Path classification: $($record.pathClassification)") }
          $sourceRecord = $record.source
          $candidateRecord = $record.candidate
          $sameRepository = $sourceRecord.repositoryIdentity -ceq $repository.identity -and $candidateRecord.repositoryIdentity -ceq $repository.identity
          $samePath = $sourceRecord.relativePath -ceq $candidateRecord.relativePath
          if (-not $samePath -and (ConvertTo-ManifestPathKey $sourceRecord.relativePath) -eq (ConvertTo-ManifestPathKey $candidateRecord.relativePath)) { $errors.Add('Source/candidate path alias mismatch') }
          $sameBytes = $sourceRecord.bytes -eq $candidateRecord.bytes -and $sourceRecord.sha256 -ieq $candidateRecord.sha256
          $action = if ($reasons.Count) { 'Hold' } elseif (-not $sameRepository -or -not $samePath -or -not $sameBytes) { 'Preserve' } else { 'EligibleCandidate' }
          if ($action -eq 'Preserve') { $reasons.Add('Repository, relative path or default bytes differ') }
          $rows.Add([pscustomobject]@{
              Id = $record.id; RelativePath = $candidateRecord.relativePath
              Action = $action; Reasons = $reasons.ToArray(); Approved = $false
              BaselineRowSHA256 = $record.baselineRowSHA256
            })
        }
      }
    } catch { $errors.Add("Invalid manifest: $($_.Exception.Message)") }
    finally { if ($null -ne $document) { $document.Dispose() } }
  }
  end {
    [pscustomobject]@{
      Valid = ($errors.Count -eq 0)
      Errors = $errors.ToArray()
      Rows = @(if (-not $errors.Count) { $rows.ToArray() })
      Approved = $false
      Verification = 'Snapshot-only; supplied custody/provenance assertions are not verified against live files, Git or archives.'
    }
  }
}
