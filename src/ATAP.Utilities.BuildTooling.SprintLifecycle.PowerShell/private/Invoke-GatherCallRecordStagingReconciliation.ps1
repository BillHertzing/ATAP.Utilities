function Invoke-GatherCallRecordStagingReconciliation {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  [OutputType([PSCustomObject])]
  param(
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
    [AllowNull()]
    [AllowEmptyString()]
    [string[]]$ClosedSessionId = @(),

    [Parameter(Mandatory = $true)]
    [timespan]$MaximumSegmentAge,

    [Parameter(Mandatory = $true)]
    [long]$MaximumSegmentBytes,

    [Parameter(Mandatory = $true)]
    [timespan]$AbandonedRemnantAge,

    [Parameter(Mandatory = $true)]
    [datetime]$NowUtc
  )

  begin {
    $fn = 'Invoke-GatherCallRecordStagingReconciliation'
    $mn = 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
      -Message 'Beginning gather-call staging reconciliation.' -Tag 'GatherCallRecord'

    $newSummary = {
      [pscustomobject][ordered]@{
        Ok = $false
        Counts = [pscustomobject][ordered]@{
          Discovered = 0
          Eligible = 0
          Invoked = 0
          Sealed = 0
          Quarantined = 0
          Skipped = 0
          Failed = 0
        }
        Files = @()
        Failure = $null
      }
    }

    $resolveSingleAbsoluteRoot = {
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

    $isReparsePoint = {
      param([System.IO.FileSystemInfo]$Item)
      ($Item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
    }

    $newFileResult = {
      param([System.IO.FileInfo]$Item, [string]$Kind)
      [ordered]@{
        Path = $Item.FullName
        Name = $Item.Name
        Kind = $Kind
        SessionId = $null
        Eligible = $false
        Boundary = @()
        Action = 'None'
        Reason = $null
        Status = 'Discovered'
        Result = $null
      }
    }
  }

  process {
    $summary = & $newSummary
    try {
      try {
        $stagingRoot = & $resolveSingleAbsoluteRoot `
          'CorpusGatherRecordsStagingPath' $CorpusGatherRecordsStagingPath `
          $PSBoundParameters.ContainsKey('CorpusGatherRecordsStagingPath')
        $corpusRoot = & $resolveSingleAbsoluteRoot `
          'CorpusGatherRecordsPath' $CorpusGatherRecordsPath `
          $PSBoundParameters.ContainsKey('CorpusGatherRecordsPath')
      } catch {
        throw "Root resolution failed: $($_.Exception.Message)"
      }

      $sprintValues = @($SprintNumber)
      $sprint = if ($sprintValues.Count -eq 1 -and $null -ne $sprintValues[0]) {
        [string]$sprintValues[0]
      } else { $null }
      if ($sprintValues.Count -ne 1 -or $sprint -notmatch '^\d{4}$') {
        throw 'SprintNumber must be exactly one four-digit value.'
      }
      if ($MaximumSegmentAge -lt [timespan]::Zero -or
          $AbandonedRemnantAge -lt [timespan]::Zero -or
          $MaximumSegmentBytes -lt 1) {
        throw 'Age boundaries must be non-negative and MaximumSegmentBytes must be positive.'
      }
      if ($NowUtc.Kind -ne [System.DateTimeKind]::Utc) {
        throw 'NowUtc must have DateTimeKind Utc.'
      }

      foreach ($rootSpec in @(
          [pscustomobject]@{ Name = 'staging'; Path = $stagingRoot },
          [pscustomobject]@{ Name = 'corpus'; Path = $corpusRoot })) {
        if (-not (Test-Path -LiteralPath $rootSpec.Path -PathType Container)) {
          throw "$($rootSpec.Name) root '$($rootSpec.Path)' is unavailable."
        }
        $rootItem = Get-Item -LiteralPath $rootSpec.Path -Force -ErrorAction Stop
        if (& $isReparsePoint $rootItem) {
          throw "$($rootSpec.Name) root '$($rootSpec.Path)' is a reparse point."
        }
      }

      $closedSessions = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::Ordinal)
      foreach ($closedId in @($ClosedSessionId)) {
        if ([string]::IsNullOrWhiteSpace($closedId)) {
          throw 'ClosedSessionId cannot contain null or blank values.'
        }
        [void]$closedSessions.Add($closedId)
      }

      $snapshot = @(Get-ChildItem -LiteralPath $stagingRoot -File -Force -ErrorAction Stop |
          Where-Object {
            $_.Name.EndsWith('.jsonl', [System.StringComparison]::OrdinalIgnoreCase) -or
            $_.Name -match '^_partial-.+\.tmp$'
          })
      $paths = [System.Collections.Generic.List[string]]::new()
      foreach ($item in $snapshot) { $paths.Add($item.FullName) }
      $paths.Sort([System.StringComparer]::Ordinal)

      $snapshotByPath = @{}
      foreach ($item in $snapshot) { $snapshotByPath[$item.FullName] = $item }
      $fileResults = [System.Collections.Generic.List[object]]::new()

      foreach ($path in $paths) {
        $item = $snapshotByPath[$path]
        $isPartial = $item.Name -match '^_partial-.+\.tmp$'
        $file = & $newFileResult $item $(if ($isPartial) { 'PartialRemnant' } else { 'JsonlSegment' })
        $summary.Counts.Discovered++

        if (& $isReparsePoint $item) {
          $file.Status = 'Failed'
          $file.Reason = 'reparse-point'
          $summary.Counts.Failed++
          $fileResults.Add([pscustomobject]$file)
          continue
        }

        if ($isPartial) {
          $age = $NowUtc - $item.LastWriteTimeUtc
          if ($age -lt $AbandonedRemnantAge) {
            $file.Status = 'Skipped'
            $file.Reason = 'recent-partial-remnant'
            $summary.Counts.Skipped++
            $fileResults.Add([pscustomobject]$file)
            continue
          }
          $file.Eligible = $true
          $file.Boundary = @('abandoned-remnant-age')
          $file.Action = 'Quarantine'
        } else {
          if ($item.Name -notmatch '^\d{8}T\d{9}Z-[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}\.jsonl$') {
            $file.Status = 'Skipped'
            $file.Reason = 'unsupported-filename'
            $summary.Counts.Skipped++
            $fileResults.Add([pscustomobject]$file)
            continue
          }

          try {
            $sessionSet = [System.Collections.Generic.HashSet[string]]::new(
              [System.StringComparer]::Ordinal)
            $hasNullSession = $false
            foreach ($line in @(Get-Content -LiteralPath $item.FullName -ErrorAction Stop)) {
              if ([string]::IsNullOrWhiteSpace($line)) { throw 'The segment contains a blank line.' }
              $record = $line | ConvertFrom-Json -ErrorAction Stop
              if (-not $record.PSObject.Properties['sessionId'] -or
                  $null -eq $record.sessionId -or
                  [string]::IsNullOrWhiteSpace([string]$record.sessionId)) {
                $hasNullSession = $true
              } else {
                [void]$sessionSet.Add([string]$record.sessionId)
              }
            }
            if ($hasNullSession -or $sessionSet.Count -ne 1) {
              $file.Status = 'Skipped'
              $file.Reason = if ($hasNullSession) { 'null-session-identity' } else { 'mixed-session-identity' }
              $summary.Counts.Skipped++
              $fileResults.Add([pscustomobject]$file)
              continue
            }
            $file.SessionId = @($sessionSet)[0]
          } catch {
            $file.Status = 'Failed'
            $file.Reason = 'session-inspection-failed'
            $file.Result = [pscustomobject]@{ Failure = $_.Exception.Message }
            $summary.Counts.Failed++
            $fileResults.Add([pscustomobject]$file)
            continue
          }

          $boundaries = [System.Collections.Generic.List[string]]::new()
          if ($closedSessions.Contains($file.SessionId)) { $boundaries.Add('closed-session') }
          if ($item.Length -ge $MaximumSegmentBytes) { $boundaries.Add('maximum-bytes') }
          if (($NowUtc - $item.LastWriteTimeUtc) -ge $MaximumSegmentAge) {
            $boundaries.Add('maximum-age')
          }
          if ($boundaries.Count -eq 0) {
            $file.Status = 'Skipped'
            $file.Reason = 'no-boundary-met'
            $summary.Counts.Skipped++
            $fileResults.Add([pscustomobject]$file)
            continue
          }
          $file.Eligible = $true
          $file.Boundary = @($boundaries)
          $file.Action = 'Seal'
        }

        $summary.Counts.Eligible++
        if (-not (Test-Path -LiteralPath $item.FullName -PathType Leaf)) {
          $file.Status = 'Skipped'
          $file.Reason = 'source-disappeared'
          $summary.Counts.Skipped++
          $fileResults.Add([pscustomobject]$file)
          continue
        }
        try {
          $current = Get-Item -LiteralPath $item.FullName -Force -ErrorAction Stop
        } catch {
          $file.Status = 'Skipped'
          $file.Reason = 'source-disappeared'
          $summary.Counts.Skipped++
          $fileResults.Add([pscustomobject]$file)
          continue
        }
        if (& $isReparsePoint $current) {
          $file.Status = 'Failed'
          $file.Reason = 'reparse-point'
          $summary.Counts.Failed++
          $fileResults.Add([pscustomobject]$file)
          continue
        }
        if ($current.Length -ne $item.Length -or
            $current.LastWriteTimeUtc -ne $item.LastWriteTimeUtc) {
          $file.Status = 'Skipped'
          $file.Reason = 'source-changed'
          $summary.Counts.Skipped++
          $fileResults.Add([pscustomobject]$file)
          continue
        }

        $arguments = @{
          StagingFilePath = $item.FullName
          CorpusGatherRecordsStagingPath = $stagingRoot
          CorpusGatherRecordsPath = $corpusRoot
          SprintNumber = $sprint
          WhatIf = [bool]$WhatIfPreference
        }
        if ($file.Action -eq 'Quarantine') { $arguments.QuarantineInvalidRemnant = $true }
        if ($PSBoundParameters.ContainsKey('Confirm')) { $arguments.Confirm = $false }

        try {
          $summary.Counts.Invoked++
          $primitiveResult = Complete-GatherCallRecordSegment @arguments
          $file.Result = $primitiveResult
          if ($null -eq $primitiveResult -or -not $primitiveResult.Ok) {
            $file.Status = 'Failed'
            $file.Reason = 'primitive-refused'
            $summary.Counts.Failed++
          } else {
            $file.Status = if ($WhatIfPreference) { 'Planned' } else { 'Completed' }
            $file.Reason = if ($WhatIfPreference) { 'whatif' } else { 'primitive-succeeded' }
            $brokerSealingConfirmed = $file.Action -eq 'Seal' -and
              $null -ne $primitiveResult.PSObject.Properties['Broker'] -and
              $primitiveResult.Broker.Attempted -and
              [string]$primitiveResult.Broker.Status -eq 'succeeded'
            if ($primitiveResult.Movement.Performed -or $brokerSealingConfirmed) {
              if ($file.Action -eq 'Quarantine') { $summary.Counts.Quarantined++ }
              else { $summary.Counts.Sealed++ }
            }
          }
        } catch {
          $file.Status = 'Failed'
          $file.Reason = 'primitive-threw'
          $file.Result = [pscustomobject]@{ Failure = $_.Exception.Message }
          $summary.Counts.Failed++
        }
        $fileResults.Add([pscustomobject]$file)
      }

      $summary.Files = @($fileResults)
      $summary.Ok = $summary.Counts.Failed -eq 0
    } catch {
      $summary.Failure = [pscustomobject][ordered]@{
        Code = 'reconciliation-failed'
        Message = $_.Exception.Message
      }
      $summary.Counts.Failed++
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error `
        -Message $_.Exception.Message -Tag 'GatherCallRecord'
    }
    $summary
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
      -Message 'Finished gather-call staging reconciliation.' -Tag 'GatherCallRecord'
  }
}
