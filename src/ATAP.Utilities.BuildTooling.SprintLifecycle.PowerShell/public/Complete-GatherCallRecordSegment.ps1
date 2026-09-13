function Complete-GatherCallRecordSegment {
  <#
  .SYNOPSIS
    Validates and atomically seals one gather-call JSONL segment, or explicitly
    quarantines one invalid partial remnant.

  .DESCRIPTION
    Validates one UTF-8-without-BOM, newline-terminated JSONL file beneath the
    mutable CorpusGatherRecordsStagingPath and moves it without overwrite to
    CorpusGatherRecordsPath\sprint-<NNNN>. The source and destination must be on
    the same normalized volume. Invalid `_partial-*.tmp` remnants are untouched
    unless QuarantineInvalidRemnant is explicitly supplied; quarantine is an
    atomic move beneath the mutable staging root and never repairs or seals bytes.

    Omitted roots are resolved only through the exact Get-PVal setting keys.
    Explicitly bound null, blank, relative, or ambiguous values fail closed.

  .PARAMETER StagingFilePath
    Exactly one absolute source file beneath CorpusGatherRecordsStagingPath.

  .PARAMETER CorpusGatherRecordsStagingPath
    Explicit mutable staging root. When omitted, resolves only through the exact
    Get-PVal key CorpusGatherRecordsStagingPath.

  .PARAMETER CorpusGatherRecordsPath
    Explicit immutable corpus root. When omitted, resolves only through the exact
    Get-PVal key CorpusGatherRecordsPath.

  .PARAMETER SprintNumber
    Four-digit sprint number used in the exact destination partition name.

  .PARAMETER QuarantineInvalidRemnant
    Explicit intent to move one `_partial-*.tmp` remnant into the staging root's
    quarantine child. Without this switch such remnants are left untouched.

  .PARAMETER CaptureIdentity
    Capture account used to harden a valid segment before movement. When omitted,
    resolves only through the exact Get-PVal key CorpusCaptureIdentity.

  .PARAMETER ExpiryIdentity
    Distinct expiry account retaining deletion authority after sealing. When omitted,
    resolves only through the exact Get-PVal key CorpusExpiryIdentity.

  .PARAMETER ExpectedSha256
    Optional caller-pinned SHA-256 for the source bytes. When supplied it must be one
    64-hexadecimal-character string and must match both exclusive-open hash checks.

  .OUTPUTS
    PSCustomObject describing validation, movement, counts, hashes, destination,
    and any failure.

  .EXAMPLE
    Complete-GatherCallRecordSegment -StagingFilePath $segment `
      -CorpusGatherRecordsStagingPath $staging -CorpusGatherRecordsPath $corpus `
      -SprintNumber '0015'

  .EXAMPLE
    Complete-GatherCallRecordSegment -StagingFilePath $partial `
      -CorpusGatherRecordsStagingPath $staging -CorpusGatherRecordsPath $corpus `
      -SprintNumber '0015' -QuarantineInvalidRemnant -WhatIf

  .NOTES
    Task 15.191.c.sealing. This primitive does not discover abandoned remnants,
    decide age/size closure, change ACLs, index a database, mirror content, or
    enforce retention. Those concerns remain with later gated units.

  .LINK
    Corpus-AI-Conversation-Durability-Decision-Packet.md#153-sealing-and-acl-boundary
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true)]
    [AllowNull()]
    [AllowEmptyString()]
    [object]$StagingFilePath,

    [Parameter(Mandatory = $false)]
    [AllowNull()]
    [AllowEmptyString()]
    [object]$CorpusGatherRecordsStagingPath,

    [Parameter(Mandatory = $false)]
    [AllowNull()]
    [AllowEmptyString()]
    [object]$CorpusGatherRecordsPath,

    [Parameter(Mandatory = $true)]
    [AllowNull()]
    [AllowEmptyString()]
    [object]$SprintNumber,

    [Parameter(Mandatory = $false)]
    [switch]$QuarantineInvalidRemnant,

    [Parameter(Mandatory = $false)]
    [AllowNull()]
    [AllowEmptyString()]
    [object]$CaptureIdentity,

    [Parameter(Mandatory = $false)]
    [AllowNull()]
    [AllowEmptyString()]
    [object]$ExpiryIdentity,

    [Parameter(Mandatory = $false)]
    [AllowNull()]
    [AllowEmptyString()]
    [object]$ExpectedSha256
  )

  begin {
    $fn = 'Complete-GatherCallRecordSegment'
    $mn = 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
      -Message 'Beginning gather-call record segment completion.' -Tag 'GatherCallRecord'

    if (-not (Get-Command Set-CorpusFileSystemAcl -ErrorAction SilentlyContinue)) {
      . (Join-Path (Split-Path -Parent $PSScriptRoot) 'private\Set-CorpusFileSystemAcl.ps1')
    }

    $actionName = if ($QuarantineInvalidRemnant) { 'Quarantine' } else { 'Seal' }
    $result = [ordered]@{
      Ok = $false
      Action = $actionName
      Validation = [pscustomobject][ordered]@{
        Succeeded = $false
        SourcePath = $null
        StagingRoot = $null
        RecordVersion = $null
      }
      Movement = [pscustomobject][ordered]@{
        Planned = $false
        Performed = $false
        SameVolume = $null
        SourcePath = $null
        DestinationPath = $null
      }
      Counts = [pscustomobject][ordered]@{
        RecordCount = $null
        ByteCount = $null
      }
      Hashes = [pscustomobject][ordered]@{
        Algorithm = 'SHA-256'
        BeforeMove = $null
        AfterMove = $null
        Match = $null
      }
      Destination = [pscustomobject][ordered]@{
        CorpusRoot = $null
        Directory = $null
        Path = $null
      }
      Acl = [pscustomobject][ordered]@{
        Planned = $false
        Applied = $false
        Verified = $false
        BeforeOwner = $null
        BeforeSddl = $null
        AfterOwner = $null
        AfterSddl = $null
        RollbackAttempted = $false
        RollbackSucceeded = $false
        RollbackError = $null
      }
      Broker = [pscustomobject][ordered]@{
        Attempted = $false
        InstallerId = 'seal-gather-call-record-segment'
        RequestId = $null
        Status = $null
        Error = $null
        TranscriptPath = $null
      }
      Failure = $null
    }

    $setFailure = {
      param([string]$Code, [string]$Message)
      $result.Failure = [pscustomobject][ordered]@{ Code = $Code; Message = $Message }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error `
        -Message $Message -Tag 'GatherCallRecord'
    }

    $resolveSingleAbsoluteRoot = {
      param(
        [string]$ParameterName,
        [object]$ExplicitValue,
        [bool]$WasBound
      )

      $value = $ExplicitValue
      if (-not $WasBound) {
        if (-not (Get-Command -Name 'Get-PVal' -ErrorAction SilentlyContinue)) {
          throw "Get-PVal is unavailable, so $ParameterName cannot be resolved."
        }
        $value = Get-PVal -ParameterName $ParameterName `
          -originalPSBoundParameters @{} -dottedPath $ParameterName
      }

      $values = @($value)
      if ($values.Count -ne 1) {
        throw "$ParameterName must resolve to exactly one absolute path; received $($values.Count) values."
      }
      $text = if ($null -eq $values[0]) { $null } else { [string]$values[0] }
      if ([string]::IsNullOrWhiteSpace($text)) {
        throw "$ParameterName resolved to a blank value."
      }
      if (-not [System.IO.Path]::IsPathFullyQualified($text)) {
        throw "$ParameterName '$text' is relative; supply one absolute path."
      }
      [System.IO.Path]::GetFullPath($text).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar)
    }

    $hasReparsePoint = {
      param([System.IO.FileSystemInfo]$Item)
      ($Item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
    }

    $getSha256 = {
      param([System.IO.Stream]$Stream)
      $Stream.Position = 0
      $algorithm = [System.Security.Cryptography.SHA256]::Create()
      try {
        ([System.BitConverter]::ToString($algorithm.ComputeHash($Stream))).Replace('-', '').ToLowerInvariant()
      } finally {
        $algorithm.Dispose()
      }
    }

    $isNullableStringValid = {
      param([object]$Value)
      $null -eq $Value -or ($Value -is [string] -and -not [string]::IsNullOrWhiteSpace([string]$Value))
    }

    $resolveIdentity = {
      param([string]$ParameterName, [object]$ExplicitValue, [bool]$WasBound)
      $value = $ExplicitValue
      if (-not $WasBound) {
        if (-not (Get-Command -Name 'Get-PVal' -ErrorAction SilentlyContinue)) {
          throw "Get-PVal is unavailable, so $ParameterName cannot be resolved."
        }
        $value = Get-PVal -ParameterName $ParameterName `
          -originalPSBoundParameters @{} -dottedPath $ParameterName
      }
      $values = @($value)
      if ($values.Count -ne 1 -or $null -eq $values[0] -or
          [string]::IsNullOrWhiteSpace([string]$values[0])) {
        throw "$ParameterName must resolve to exactly one non-blank Windows account."
      }
      $values[0]
    }
  }

  process {
    try {
      $sourceValues = @($StagingFilePath)
      if ($sourceValues.Count -ne 1) {
        & $setFailure 'ambiguous-source' "StagingFilePath must contain exactly one value; received $($sourceValues.Count)."
        return [pscustomobject]$result
      }
      $sourceText = if ($null -eq $sourceValues[0]) { $null } else { [string]$sourceValues[0] }
      if ([string]::IsNullOrWhiteSpace($sourceText) -or
          -not [System.IO.Path]::IsPathFullyQualified($sourceText)) {
        & $setFailure 'invalid-source' 'StagingFilePath must be one non-blank absolute file path.'
        return [pscustomobject]$result
      }
      $sourcePath = [System.IO.Path]::GetFullPath($sourceText)
      $result.Validation.SourcePath = $sourcePath
      $result.Movement.SourcePath = $sourcePath

      try {
        $stagingRoot = & $resolveSingleAbsoluteRoot `
          'CorpusGatherRecordsStagingPath' $CorpusGatherRecordsStagingPath `
          $PSBoundParameters.ContainsKey('CorpusGatherRecordsStagingPath')
        $corpusRoot = & $resolveSingleAbsoluteRoot `
          'CorpusGatherRecordsPath' $CorpusGatherRecordsPath `
          $PSBoundParameters.ContainsKey('CorpusGatherRecordsPath')
      } catch {
        & $setFailure 'root-resolution-failed' $_.Exception.Message
        return [pscustomobject]$result
      }
      $result.Validation.StagingRoot = $stagingRoot
      $result.Destination.CorpusRoot = $corpusRoot

      $sprintValues = @($SprintNumber)
      $sprint = if ($sprintValues.Count -eq 1 -and $null -ne $sprintValues[0]) {
        [string]$sprintValues[0]
      } else { $null }
      if ($sprintValues.Count -ne 1 -or $sprint -notmatch '^\d{4}$') {
        & $setFailure 'invalid-sprint' 'SprintNumber must be exactly one four-digit value.'
        return [pscustomobject]$result
      }

      if (-not (Test-Path -LiteralPath $stagingRoot -PathType Container)) {
        & $setFailure 'staging-root-unavailable' "Staging root '$stagingRoot' does not exist as a directory."
        return [pscustomobject]$result
      }
      $stagingItem = Get-Item -LiteralPath $stagingRoot -Force -ErrorAction Stop
      if (& $hasReparsePoint $stagingItem) {
        & $setFailure 'reparse-point' "Staging root '$stagingRoot' is a reparse point."
        return [pscustomobject]$result
      }

      $relativeSource = [System.IO.Path]::GetRelativePath($stagingRoot, $sourcePath)
      if ([System.IO.Path]::IsPathFullyQualified($relativeSource) -or
          $relativeSource -eq '..' -or
          $relativeSource.StartsWith("..$([System.IO.Path]::DirectorySeparatorChar)", [System.StringComparison]::Ordinal) -or
          $relativeSource.StartsWith("..$([System.IO.Path]::AltDirectorySeparatorChar)", [System.StringComparison]::Ordinal)) {
        & $setFailure 'source-escape' "Source '$sourcePath' is not beneath staging root '$stagingRoot'."
        return [pscustomobject]$result
      }
      if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        & $setFailure 'source-unavailable' "Source '$sourcePath' does not exist as a file."
        return [pscustomobject]$result
      }
      $sourceItem = Get-Item -LiteralPath $sourcePath -Force -ErrorAction Stop
      if ($sourceItem.PSIsContainer) {
        & $setFailure 'source-is-directory' "Source '$sourcePath' is a directory."
        return [pscustomobject]$result
      }
      if (& $hasReparsePoint $sourceItem) {
        & $setFailure 'reparse-point' "Source '$sourcePath' is a reparse point."
        return [pscustomobject]$result
      }
      $ancestor = $sourceItem.Directory
      while ($null -ne $ancestor -and
             -not [string]::Equals($ancestor.FullName.TrimEnd('\', '/'), $stagingRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        if (& $hasReparsePoint $ancestor) {
          & $setFailure 'reparse-point' "Source ancestor '$($ancestor.FullName)' is a reparse point."
          return [pscustomobject]$result
        }
        $ancestor = $ancestor.Parent
      }

      $isPartialRemnant = $sourceItem.Name -match '^_partial-.+\.tmp$'
      if ($QuarantineInvalidRemnant) {
        if (-not $isPartialRemnant) {
          & $setFailure 'not-partial-remnant' 'Quarantine requires a file named `_partial-*.tmp` beneath staging.'
          return [pscustomobject]$result
        }
        $destinationDirectory = [System.IO.Path]::Combine($stagingRoot, 'quarantine')
      } else {
        if ($isPartialRemnant) {
          & $setFailure 'quarantine-intent-required' 'Invalid partial remnants are untouched unless QuarantineInvalidRemnant is explicit.'
          return [pscustomobject]$result
        }
        if (-not $sourceItem.Name.EndsWith('.jsonl', [System.StringComparison]::OrdinalIgnoreCase)) {
          & $setFailure 'invalid-source-name' 'A segment selected for sealing must have a .jsonl file name.'
          return [pscustomobject]$result
        }
        $destinationDirectory = [System.IO.Path]::Combine($corpusRoot, "sprint-$sprint")
      }
      $destinationPath = [System.IO.Path]::Combine($destinationDirectory, $sourceItem.Name)
      $result.Destination.Directory = $destinationDirectory
      $result.Destination.Path = $destinationPath
      $result.Movement.DestinationPath = $destinationPath

      $sourceVolume = [System.IO.Path]::GetPathRoot($sourcePath).TrimEnd('\', '/')
      $destinationVolume = [System.IO.Path]::GetPathRoot($destinationPath).TrimEnd('\', '/')
      $sameVolume = [string]::Equals($sourceVolume, $destinationVolume, [System.StringComparison]::OrdinalIgnoreCase)
      $result.Movement.SameVolume = $sameVolume
      if (-not $sameVolume) {
        & $setFailure 'cross-volume-refused' "Source volume '$sourceVolume' differs from destination volume '$destinationVolume'; copy fallback is prohibited."
        return [pscustomobject]$result
      }

      if (-not $QuarantineInvalidRemnant) {
        if (-not (Test-Path -LiteralPath $corpusRoot -PathType Container)) {
          & $setFailure 'corpus-root-unavailable' "Corpus root '$corpusRoot' does not exist as a directory."
          return [pscustomobject]$result
        }
        $corpusItem = Get-Item -LiteralPath $corpusRoot -Force -ErrorAction Stop
        if (& $hasReparsePoint $corpusItem) {
          & $setFailure 'reparse-point' "Corpus root '$corpusRoot' is a reparse point."
          return [pscustomobject]$result
        }
      }

      if (Test-Path -LiteralPath $destinationDirectory) {
        $destinationDirectoryItem = Get-Item -LiteralPath $destinationDirectory -Force -ErrorAction Stop
        if (-not $destinationDirectoryItem.PSIsContainer) {
          & $setFailure 'destination-directory-invalid' "Destination directory path '$destinationDirectory' is not a directory."
          return [pscustomobject]$result
        }
        if (& $hasReparsePoint $destinationDirectoryItem) {
          & $setFailure 'reparse-point' "Destination directory '$destinationDirectory' is a reparse point."
          return [pscustomobject]$result
        }
      }

      if (Test-Path -LiteralPath $destinationPath) {
        & $setFailure 'destination-exists' "Destination '$destinationPath' already exists; overwrite is prohibited."
        return [pscustomobject]$result
      }

      if ($QuarantineInvalidRemnant) {
        try {
          $probe = [System.IO.File]::Open($sourcePath, [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read, [System.IO.FileShare]::None)
          try { $result.Counts.ByteCount = $probe.Length } finally { $probe.Dispose() }
        } catch {
          & $setFailure 'exclusive-open-failed' "Source '$sourcePath' cannot be opened exclusively: $($_.Exception.Message)"
          return [pscustomobject]$result
        }
        $result.Validation.Succeeded = $true
      } else {
        try {
          $stream = [System.IO.File]::Open($sourcePath, [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read, [System.IO.FileShare]::None)
          try {
            $result.Counts.ByteCount = $stream.Length
            if ($stream.Length -eq 0) { throw 'The JSONL segment is empty.' }

            if ($stream.Length -ge 3) {
              $first = $stream.ReadByte()
              $second = $stream.ReadByte()
              $third = $stream.ReadByte()
              if ($first -eq 0xef -and $second -eq 0xbb -and $third -eq 0xbf) {
                throw 'The JSONL segment has a UTF-8 BOM.'
              }
            }
            $stream.Position = $stream.Length - 1
            if ($stream.ReadByte() -ne 0x0a) {
              throw 'The JSONL segment is missing its terminating newline.'
            }

            $result.Hashes.BeforeMove = & $getSha256 $stream
            if ($PSBoundParameters.ContainsKey('ExpectedSha256')) {
              $expectedValues = @($ExpectedSha256)
              if ($expectedValues.Count -ne 1 -or $expectedValues[0] -isnot [string] -or
                  [string]$expectedValues[0] -notmatch '^[0-9A-Fa-f]{64}$') {
                throw 'ExpectedSha256 must be exactly one 64-hexadecimal-character string.'
              }
              if (-not [string]::Equals([string]$expectedValues[0], $result.Hashes.BeforeMove,
                  [System.StringComparison]::OrdinalIgnoreCase)) {
                throw 'ExpectedSha256 does not match the exclusive-open source SHA-256.'
              }
            }
            $stream.Position = 0
            $strictUtf8 = [System.Text.UTF8Encoding]::new($false, $true)
            $reader = [System.IO.StreamReader]::new($stream, $strictUtf8, $false, 4096, $true)
            try {
              $recordCount = 0
              while (-not $reader.EndOfStream) {
                $line = $reader.ReadLine()
                if ([string]::IsNullOrWhiteSpace($line)) {
                  throw "JSONL line $($recordCount + 1) is blank."
                }
                try {
                  $document = [System.Text.Json.JsonDocument]::Parse($line)
                } catch {
                  throw "JSONL line $($recordCount + 1) is malformed JSON: $($_.Exception.Message)"
                }
                try {
                  $record = $document.RootElement
                  if ($record.ValueKind -ne [System.Text.Json.JsonValueKind]::Object) {
                    throw "JSONL line $($recordCount + 1) is not one JSON object."
                  }

                  $names = [System.Collections.Generic.List[string]]::new()
                  foreach ($jsonProperty in $record.EnumerateObject()) {
                    $names.Add($jsonProperty.Name)
                  }
                  $requiredIdentityFields = @(
                    'recordVersion', 'invocationId', 'requestResponsePairId', 'ordinal',
                    'ordinalScope', 'timestampUtc', 'agentName', 'agentModel', 'sessionId',
                    'taskId', 'worktreePath', 'repositoryName', 'conversationId',
                    'conversationTitle'
                  )
                  foreach ($field in $requiredIdentityFields) {
                    if ($names -notcontains $field) {
                      throw "JSONL line $($recordCount + 1) is missing required identity/time field '$field'."
                    }
                  }

                  $recordVersionElement = $record.GetProperty('recordVersion')
                  $recordVersion = if ($recordVersionElement.ValueKind -eq [System.Text.Json.JsonValueKind]::String) {
                    $recordVersionElement.GetString()
                  } else { $null }
                  if ($recordVersion -ne '1.0.0') {
                    throw "JSONL line $($recordCount + 1) has unsupported recordVersion '$recordVersion'."
                  }

                  $invocationElement = $record.GetProperty('invocationId')
                  $invocationId = if ($invocationElement.ValueKind -eq [System.Text.Json.JsonValueKind]::String) {
                    $invocationElement.GetString()
                  } else { $null }
                  if ($invocationId -notmatch '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$') {
                    throw "JSONL line $($recordCount + 1) has an invalid invocationId."
                  }

                  $ordinalElement = $record.GetProperty('ordinal')
                  $ordinal = [long]0
                  if ($ordinalElement.ValueKind -ne [System.Text.Json.JsonValueKind]::Number -or
                      -not $ordinalElement.TryGetInt64([ref]$ordinal)) {
                    throw "JSONL line $($recordCount + 1) has a non-integer ordinal."
                  }
                  $ordinalScopeElement = $record.GetProperty('ordinalScope')
                  $ordinalScope = if ($ordinalScopeElement.ValueKind -eq [System.Text.Json.JsonValueKind]::String) {
                    $ordinalScopeElement.GetString()
                  } else { $null }
                  if ($ordinal -lt 1 -or $ordinalScope -notin @('session', 'file')) {
                    throw "JSONL line $($recordCount + 1) has invalid ordinal identity."
                  }

                  $timestampElement = $record.GetProperty('timestampUtc')
                  $timestampUtc = if ($timestampElement.ValueKind -eq [System.Text.Json.JsonValueKind]::String) {
                    $timestampElement.GetString()
                  } else { $null }
                  if ($timestampUtc -notmatch '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$') {
                    throw "JSONL line $($recordCount + 1) has an invalid timestampUtc."
                  }
                  $parsedTimestamp = [datetime]::MinValue
                  if (-not [datetime]::TryParseExact($timestampUtc, 'yyyy-MM-ddTHH:mm:ss.fffZ',
                      [System.Globalization.CultureInfo]::InvariantCulture,
                      [System.Globalization.DateTimeStyles]::AssumeUniversal -bor
                        [System.Globalization.DateTimeStyles]::AdjustToUniversal,
                      [ref]$parsedTimestamp)) {
                    throw "JSONL line $($recordCount + 1) has an impossible timestampUtc."
                  }

                  $agentElement = $record.GetProperty('agentName')
                  $agentName = if ($agentElement.ValueKind -eq [System.Text.Json.JsonValueKind]::String) {
                    $agentElement.GetString()
                  } else { $null }
                  if ([string]::IsNullOrWhiteSpace($agentName)) {
                    throw "JSONL line $($recordCount + 1) has an invalid agentName."
                  }

                  foreach ($nullableField in @('requestResponsePairId', 'agentModel', 'sessionId', 'taskId',
                      'worktreePath', 'repositoryName', 'conversationId', 'conversationTitle')) {
                    $nullableElement = $record.GetProperty($nullableField)
                    $nullableValue = if ($nullableElement.ValueKind -eq [System.Text.Json.JsonValueKind]::Null) {
                      $null
                    } elseif ($nullableElement.ValueKind -eq [System.Text.Json.JsonValueKind]::String) {
                      $nullableElement.GetString()
                    } else {
                      [pscustomobject]@{ InvalidJsonType = $true }
                    }
                    if (-not (& $isNullableStringValid $nullableValue)) {
                      throw "JSONL line $($recordCount + 1) has an invalid $nullableField."
                    }
                  }
                } finally {
                  $document.Dispose()
                }
                $recordCount++
              }
              $result.Counts.RecordCount = $recordCount
              $result.Validation.RecordVersion = '1.0.0'
            } finally {
              $reader.Dispose()
            }
          } finally {
            $stream.Dispose()
          }
        } catch {
          & $setFailure 'validation-failed' $_.Exception.Message
          return [pscustomobject]$result
        }
        $result.Validation.Succeeded = $true

        try {
          $resolvedCaptureIdentity = & $resolveIdentity 'CorpusCaptureIdentity' $CaptureIdentity `
            $PSBoundParameters.ContainsKey('CaptureIdentity')
          $resolvedExpiryIdentity = & $resolveIdentity 'CorpusExpiryIdentity' $ExpiryIdentity `
            $PSBoundParameters.ContainsKey('ExpiryIdentity')
          $aclPlan = Set-CorpusFileSystemAcl -Path $sourcePath -BoundaryKind ImmutableArtifact `
            -CaptureIdentity $resolvedCaptureIdentity -ExpiryIdentity $resolvedExpiryIdentity `
            -PlanOnly -Confirm:$false
          $result.Acl.Planned = $true
          $result.Acl.BeforeOwner = $aclPlan.BeforeOwner
          $result.Acl.BeforeSddl = $aclPlan.BeforeSddl
        } catch {
          & $setFailure 'acl-validation-failed' $_.Exception.Message
          return [pscustomobject]$result
        }
      }

      $result.Movement.Planned = $true
      if (-not $PSCmdlet.ShouldProcess($sourcePath, "$actionName gather-call record segment to '$destinationPath'")) {
        $result.Ok = $true
        return [pscustomobject]$result
      }

      if (-not $QuarantineInvalidRemnant) {
        if (-not $IsWindows) {
          & $setFailure 'unsupported-platform' 'Corpus ACL sealing and its elevation broker require Windows.'
          return [pscustomobject]$result
        }
        try {
          $currentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
          $currentPrincipal = New-Object -TypeName System.Security.Principal.WindowsPrincipal `
            -ArgumentList @($currentIdentity)
          $isAdministrator = $currentPrincipal.IsInRole(
            [System.Security.Principal.WindowsBuiltInRole]::Administrator)
        } catch {
          & $setFailure 'administrator-check-failed' "Unable to determine the current Windows token elevation: $($_.Exception.Message)"
          return [pscustomobject]$result
        }

        if (-not $isAdministrator) {
          $result.Broker.Attempted = $true
          if (-not (Get-Command -Name 'Request-ElevatedInstall' -ErrorAction SilentlyContinue)) {
            $result.Broker.Status = 'unavailable'
            & $setFailure 'broker-unavailable' 'Request-ElevatedInstall is unavailable; corpus sealing cannot continue under a non-administrative token.'
            return [pscustomobject]$result
          }

          $brokerParameters = @{
            StagingFilePath = [string]$sourcePath
            CorpusGatherRecordsStagingPath = [string]$stagingRoot
            CorpusGatherRecordsPath = [string]$corpusRoot
            SprintNumber = [string]$sprint
            CaptureIdentity = [string]$resolvedCaptureIdentity
            ExpiryIdentity = [string]$resolvedExpiryIdentity
            ExpectedSha256 = [string]$result.Hashes.BeforeMove
          }
          try {
            $brokerResult = Request-ElevatedInstall `
              -InstallerId 'seal-gather-call-record-segment' `
              -Parameters $brokerParameters `
              -Confirm:$false
          } catch {
            $result.Broker.Status = 'request-failed'
            $result.Broker.Error = $_.Exception.Message
            & $setFailure 'broker-request-failed' "Corpus sealing broker request failed: $($_.Exception.Message)"
            return [pscustomobject]$result
          }

          foreach ($mapping in @(
              @{ Source = 'requestId'; Target = 'RequestId' },
              @{ Source = 'status'; Target = 'Status' },
              @{ Source = 'error'; Target = 'Error' },
              @{ Source = 'transcriptPath'; Target = 'TranscriptPath' }
            )) {
            if ($null -ne $brokerResult -and $brokerResult.PSObject.Properties[$mapping.Source]) {
              $result.Broker.($mapping.Target) = $brokerResult.($mapping.Source)
            }
          }
          if ($null -eq $brokerResult -or
              -not $brokerResult.PSObject.Properties['status'] -or
              [string]$brokerResult.status -ne 'succeeded') {
            $brokerStatus = if ([string]::IsNullOrWhiteSpace([string]$result.Broker.Status)) {
              'missing'
            } else { [string]$result.Broker.Status }
            & $setFailure 'broker-sealing-failed' "Corpus sealing broker returned status '$brokerStatus'."
            return [pscustomobject]$result
          }

          $result.Ok = $true
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
            -Message "Sealing completed through the elevation broker for '$destinationPath'." -Tag 'GatherCallRecord'
          return [pscustomobject]$result
        }
      }

      $aclApplied = $false
      try {
        if (-not (Test-Path -LiteralPath $destinationDirectory -PathType Container)) {
          [System.IO.Directory]::CreateDirectory($destinationDirectory) | Out-Null
        }
        $destinationDirectoryItem = Get-Item -LiteralPath $destinationDirectory -Force -ErrorAction Stop
        if (-not $destinationDirectoryItem.PSIsContainer) {
          throw "Destination directory path '$destinationDirectory' is not a directory."
        }
        if (& $hasReparsePoint $destinationDirectoryItem) {
          throw "Destination directory '$destinationDirectory' is a reparse point."
        }
        if (Test-Path -LiteralPath $destinationPath) {
          throw "Destination '$destinationPath' appeared before movement; overwrite is prohibited."
        }

        if (-not $QuarantineInvalidRemnant) {
          $preMoveStream = [System.IO.File]::Open($sourcePath, [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read, [System.IO.FileShare]::None)
          try {
            $preMoveByteCount = $preMoveStream.Length
            $preMoveHash = & $getSha256 $preMoveStream
          } finally {
            $preMoveStream.Dispose()
          }
          if ($preMoveByteCount -ne $result.Counts.ByteCount -or
              $preMoveHash -ne $result.Hashes.BeforeMove) {
            throw 'Source changed between validation and movement.'
          }
          if ($PSBoundParameters.ContainsKey('ExpectedSha256') -and
              -not [string]::Equals([string]$ExpectedSha256, $preMoveHash,
                [System.StringComparison]::OrdinalIgnoreCase)) {
            throw 'ExpectedSha256 no longer matches immediately before ACL application and movement.'
          }

          $aclResult = Set-CorpusFileSystemAcl -Path $sourcePath -BoundaryKind ImmutableArtifact `
            -CaptureIdentity $resolvedCaptureIdentity -ExpiryIdentity $resolvedExpiryIdentity `
            -Confirm:$false
          $aclApplied = $aclResult.Applied
          $result.Acl.Applied = $aclResult.Applied
          $result.Acl.Verified = $aclResult.Verified
          $result.Acl.BeforeOwner = $aclResult.BeforeOwner
          $result.Acl.BeforeSddl = $aclResult.BeforeSddl
          $result.Acl.AfterOwner = $aclResult.AfterOwner
          $result.Acl.AfterSddl = $aclResult.AfterSddl
        }

        [System.IO.File]::Move($sourcePath, $destinationPath)
        $result.Movement.Performed = $true

        if (-not $QuarantineInvalidRemnant) {
          $postMoveStream = [System.IO.File]::Open($destinationPath, [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
          try { $result.Hashes.AfterMove = & $getSha256 $postMoveStream } finally { $postMoveStream.Dispose() }
          $result.Hashes.Match = $result.Hashes.BeforeMove -eq $result.Hashes.AfterMove
          if (-not $result.Hashes.Match) {
            throw 'Post-move SHA-256 does not match the pre-move hash.'
          }
          $destinationAcl = Get-Acl -LiteralPath $destinationPath -ErrorAction Stop
          $destinationSddl = $destinationAcl.GetSecurityDescriptorSddlForm(
            [System.Security.AccessControl.AccessControlSections]::All)
          if ($destinationSddl -ne $result.Acl.AfterSddl -or
              $destinationAcl.Owner -ne $result.Acl.AfterOwner) {
            throw 'Destination ACL does not match the pre-move immutable descriptor.'
          }
        }
      } catch {
        if ($aclApplied -and -not $result.Movement.Performed -and
            (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
          $result.Acl.RollbackAttempted = $true
          try {
            Set-CorpusFileSystemAcl -Path $sourcePath -RestoreSddl $result.Acl.BeforeSddl `
              -Confirm:$false | Out-Null
            $result.Acl.RollbackSucceeded = $true
          } catch {
            $result.Acl.RollbackError = $_.Exception.Message
          }
        }
        & $setFailure 'movement-failed' $_.Exception.Message
        return [pscustomobject]$result
      }

      $result.Ok = $true
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
        -Message "$actionName completed at '$destinationPath'." -Tag 'GatherCallRecord'
      [pscustomobject]$result
    } catch {
      & $setFailure 'unexpected-failure' $_.Exception.Message
      [pscustomobject]$result
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
      -Message 'Finished gather-call record segment completion.' -Tag 'GatherCallRecord'
  }
}
