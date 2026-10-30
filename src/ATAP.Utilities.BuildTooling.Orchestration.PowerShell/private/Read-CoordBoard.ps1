function Read-CoordBoard {
  <#
  .SYNOPSIS
    Reads a caller-selected planning directory into one unchanged board snapshot.
  .DESCRIPTION
    Reads only top-level markdown files. TASKS_V followed by a decimal Int64
    version (with any suffix before .md) takes precedence over Tasks.SprintNNNN.md.
    Equal highest versions, malformed version prefixes and missing inputs throw.
    Does not discover configuration, register state, render or write anything.

    Text is strict UTF-8 decoded verbatim, including U+FEFF when a BOM is present.
    RawBytes and Sha256 describe the same single read, not ongoing writer custody.
    Offsets are zero-based UTF-16 character indices into Text; EndOffset is exclusive.
    A task block ends at the next canonical task or column-zero level 1/2 ATX
    section heading outside a fence. Indented and level 3-6 detail headings remain.
    Child tasks have independent blocks; a parent block does not absorb its child.
    Blank lines before a boundary remain in the preceding block. Heading excludes
    its line terminator. Checkbox is space, x, X or ~; Checked is true only for x/X.
    IDs retain case and duplicate comparison is ordinal.

    This is a bounded board grammar, not a general Markdown interpreter. It accepts
    anchored dash-checkbox/bold Task ID/tag/title lines and backtick/tilde fences
    (including indented fences). It does not interpret HTML blocks or list nesting.
    No identity admission or revision/registration authority follows from this read.
  .PARAMETER PlanningRoot
    Explicit absolute existing filesystem directory. No ancestor search or recursion.
  .PARAMETER SprintNumber
    Explicit sprint number, formatted to four digits for the unversioned filename.
  .OUTPUTS
    PSCustomObject with Path, Version (null or Int64), SprintNumber, Sha256,
    RawBytes, Text, HasUtf8Bom, NewLineKinds, HasFinalNewLine and Tasks.
    Each task has Id, Checked, Checkbox, Heading, Text, StartOffset and EndOffset.
  .EXAMPLE
    Read-CoordBoard -PlanningRoot 'D:\ATAPArtifacts\DisposableBoard' -SprintNumber 17
  .NOTES
    Private source-stage API. Callers must separately validate registration/custody.
    WhatIf/Confirm are available by convention; the operation has no mutation.
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$PlanningRoot,

    [Parameter(Mandatory)]
    [ValidateRange(1, 9999)]
    [int]$SprintNumber
  )

  begin {
    $fn = 'Read-CoordBoard'
    $mn = 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell'
    $null = Get-Command -Name 'Write-PSFMessage' -ErrorAction Stop
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Reading explicit board snapshot'
    if (-not [System.IO.Path]::IsPathFullyQualified($PlanningRoot)) {
      throw 'PlanningRoot must be an absolute filesystem directory.'
    }
    $rootPath = [System.IO.Path]::GetFullPath($PlanningRoot)
    if (-not [System.IO.Directory]::Exists($rootPath)) {
      throw 'PlanningRoot must exist as a filesystem directory.'
    }
  }

  process {
    try {
      $files = @(Get-ChildItem -LiteralPath $rootPath -File -Force -ErrorAction Stop)
      $versioned = [System.Collections.Generic.List[object]]::new()
      foreach ($file in $files) {
        if (-not $file.Extension.Equals('.md', [System.StringComparison]::OrdinalIgnoreCase) -or
            -not $file.Name.StartsWith('TASKS_V', [System.StringComparison]::OrdinalIgnoreCase)) {
          continue
        }
        $versionMatch = [regex]::Match($file.Name, '^TASKS_V(?<version>[0-9]+).*\.md$', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        [long]$number = 0
        if (-not $versionMatch.Success -or
            -not [long]::TryParse($versionMatch.Groups['version'].Value, [System.Globalization.NumberStyles]::None,
              [System.Globalization.CultureInfo]::InvariantCulture, [ref]$number)) {
          throw "Invalid TASKS_V numeric version: $($file.Name)"
        }
        $versioned.Add([PSCustomObject]@{ File = $file; Version = $number })
      }

      $version = $null
      if ($versioned.Count -gt 0) {
        $highest = ($versioned | Sort-Object Version -Descending | Select-Object -First 1).Version
        $winners = @($versioned | Where-Object { $_.Version -eq $highest })
        if ($winners.Count -ne 1) {
          throw "Ambiguous highest TASKS_V version: $highest"
        }
        $selected = $winners[0].File
        $version = $highest
      } else {
        $name = 'Tasks.Sprint{0:D4}.md' -f $SprintNumber
        $matchesByName = @($files | Where-Object { $_.Name.Equals($name, [System.StringComparison]::OrdinalIgnoreCase) })
        if ($matchesByName.Count -ne 1) {
          throw "Expected exactly one top-level board: $name"
        }
        $selected = $matchesByName[0]
      }
      if (($selected.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        $queryOutput = $null
        try {
          # A null LinkTarget alone is not evidence that a reparse point is safe.
          $targetProperty = $selected.PSObject.Properties['LinkTarget']
          if (-not $IsWindows -or $null -eq $targetProperty -or $null -ne $targetProperty.Value) {
            throw 'Unverified reparse-point metadata.'
          }
          $fsutilPath = Join-Path ([System.Environment]::SystemDirectory) 'fsutil.exe'
          $metadataCommand = Get-Command -Name $fsutilPath -CommandType Application -ErrorAction Stop
          # Fixed read-only verbs and a separate path argument; never emit the payload.
          $queryOutput = @(& $metadataCommand reparsepoint query $selected.FullName 2>$null)
          if ($LASTEXITCODE -ne 0) { throw 'Reparse metadata query failed.' }
          $tagMatches = @(
            foreach ($queryLine in $queryOutput) {
              $tagMatch = [regex]::Match([string]$queryLine, '^\s*Reparse Tag Value\s*:\s*0x(?<tag>[0-9a-fA-F]{8})\s*$')
              if ($tagMatch.Success) { $tagMatch.Groups['tag'].Value }
            }
          )
          if ($tagMatches.Count -ne 1) { throw 'Reparse metadata tag is missing or ambiguous.' }
          $tag = [System.Convert]::ToUInt32($tagMatches[0], 16)
          $cloudMask = [System.Convert]::ToUInt32('FFFF0FFF', 16)
          $cloudBase = [System.Convert]::ToUInt32('9000001A', 16)
          $nameSurrogateBit = [System.Convert]::ToUInt32('20000000', 16)
          if (($tag -band $nameSurrogateBit) -ne 0 -or ($tag -band $cloudMask) -ne $cloudBase) {
            throw 'Unsupported reparse tag.'
          }
        } catch {
          # Opaque native output and native error details never cross this boundary.
          throw 'Selected board reparse metadata is not a verified Windows cloud placeholder.'
        } finally {
          $queryOutput = $null
        }
      }

      [byte[]]$rawBytes = [System.IO.File]::ReadAllBytes($selected.FullName)
      $text = [System.Text.UTF8Encoding]::new($false, $true).GetString($rawBytes)
      $sha256 = [System.Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($rawBytes)).ToLowerInvariant()
      $hasUtf8Bom = $rawBytes.Length -ge 3 -and $rawBytes[0] -eq 0xEF -and $rawBytes[1] -eq 0xBB -and $rawBytes[2] -eq 0xBF
      $tasks = [System.Collections.Generic.List[object]]::new()
      $ids = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
      $newLineKinds = [System.Collections.Generic.List[string]]::new()
      $current = $null
      $fenceCharacter = [char]0
      $fenceLength = 0
      $taskPattern = '^[ \t]*-[ \t]+\[(?<checkbox>[ xX~])\][ \t]+\*\*Task[ \t]+(?<id>[0-9]+\.[0-9]+[A-Za-z]*(?:\.[A-Za-z0-9]+(?:-[A-Za-z0-9]+)*)*)\*\*(?:[ \t]+\*{0,2}\[[^\]\r\n]+\]\*{0,2})*[ \t]+[-–—][ \t]+\S.*$'

      foreach ($lineMatch in [regex]::Matches($text, '[^\r\n]*(?:\r\n|\r|\n|\z)')) {
        if ($lineMatch.Length -eq 0) { continue }
        $line = [regex]::Replace($lineMatch.Value, '(?:\r\n|\r|\n)$', '')
        $terminator = $lineMatch.Value.Substring($line.Length)
        $kind = switch ($terminator) {
          ([string][char]13 + [char]10) { 'CRLF' }
          ([string][char]10) { 'LF' }
          ([string][char]13) { 'CR' }
        }
        if ($kind -and -not $newLineKinds.Contains($kind)) { $newLineKinds.Add($kind) }
        $parseLine = $line
        if ($lineMatch.Index -eq 0 -and $hasUtf8Bom) { $parseLine = $line.Substring(1) }

        if ($fenceLength -gt 0) {
          $closingPattern = '^[ \t]*' + [regex]::Escape([string]$fenceCharacter) + '{' + $fenceLength + ',}[ \t]*$'
          if ([regex]::IsMatch($parseLine, $closingPattern)) { $fenceLength = 0 }
          continue
        }
        $fence = [regex]::Match($parseLine, '^[ \t]*(?<marker>~{3,}|\x60{3,})(?<info>.*)$')
        if ($fence.Success) {
          $marker = $fence.Groups['marker'].Value
          if ($marker[0] -ne [char]0x60 -or -not $fence.Groups['info'].Value.Contains([char]0x60)) {
            $fenceCharacter = $marker[0]
            $fenceLength = $marker.Length
            continue
          }
        }

        $taskMatch = [regex]::Match($parseLine, $taskPattern)
        $sectionBoundary = [regex]::IsMatch($parseLine, '^#{1,2}(?:[ \t]+|$)')
        if ($taskMatch.Success -or $sectionBoundary) {
          if ($null -ne $current) {
            $current.EndOffset = $lineMatch.Index
            $current.Text = $text.Substring($current.StartOffset, $current.EndOffset - $current.StartOffset)
            $tasks.Add($current)
            $current = $null
          }
        }
        if ($taskMatch.Success) {
          $id = $taskMatch.Groups['id'].Value
          if (-not $ids.Add($id)) { throw "Duplicate task ID: $id" }
          $checkbox = $taskMatch.Groups['checkbox'].Value
          $current = [PSCustomObject]@{
            Id = $id
            Checked = $checkbox -ceq 'x' -or $checkbox -ceq 'X'
            Checkbox = $checkbox
            Heading = $line
            Text = $null
            StartOffset = $lineMatch.Index
            EndOffset = $null
          }
        }
      }
      if ($null -ne $current) {
        $current.EndOffset = $text.Length
        $current.Text = $text.Substring($current.StartOffset)
        $tasks.Add($current)
      }

      [PSCustomObject]@{
        Path = $selected.FullName
        Version = $version
        SprintNumber = $SprintNumber
        Sha256 = $sha256
        RawBytes = $rawBytes
        Text = $text
        HasUtf8Bom = $hasUtf8Bom
        NewLineKinds = $newLineKinds.ToArray()
        HasFinalNewLine = $text.EndsWith([string][char]10) -or $text.EndsWith([string][char]13)
        Tasks = $tasks.ToArray()
      }
    } catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message 'Board snapshot read failed'
      throw
    }
  }

  end {}
}
