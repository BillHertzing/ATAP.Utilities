function Get-SprintGeneratedArtifactState {
  <#
  .SYNOPSIS
  Reports tracked and cited `_generated/` content in sprint worktrees (SC-0470).

  .DESCRIPTION
  Read-only R-38 gate for SprintEnd. `_generated/` is ephemeral sprint output, so
  nothing under it may reach a stable branch, and nothing a planning artifact still
  cites may be cleared before it is relocated to InformationForTheFuture.

  Two findings fail the gate:

  - TrackedPaths: every path returned by `git ls-files -- _generated` in a selected
    worktree. Tracked `_generated/` files merge into the stable branch.
  - CitedPaths: every `_generated/...` path cited by a sprint board file
    (`Tasks.Sprint*` / `TASKS*` at the Planning root) or by a Markdown, HTML or
    JSON file under `InformationForTheFuture/`, when the cited path currently
    exists under a selected worktree's `_generated/`. Clearing would delete it.

  A citation whose text names a selected worktree folder is resolved only against
  that worktree; otherwise it is resolved against every selected worktree.
  Citations containing wildcards are not resolved. A worktree that git cannot
  list fails closed.

  .PARAMETER WorktreePaths
  Sprint worktrees to inspect.

  .PARAMETER PlanningRoot
  Active _Planning sprint worktree that holds the boards and InformationForTheFuture.

  .OUTPUTS
  PSCustomObject with Ok, TrackedPaths, CitedPaths and Failures.

  .NOTES
  AI assisted using Powershell.instructions.md as guidelines.
  #>
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string[]]$WorktreePaths,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$PlanningRoot,

    [string]$GeneratedArtifactDisposition
  )

  begin {
    $fn = 'Get-SprintGeneratedArtifactState'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
    if (-not (Get-Command -Name 'Invoke-SprintEndNativeCommand' -ErrorAction SilentlyContinue)) {
      . (Join-Path $PSScriptRoot 'Invoke-SprintEndNativeCommand.ps1')
    }
  }

  process {
    $failures = [System.Collections.Generic.List[string]]::new()
    $trackedPaths = [System.Collections.Generic.List[object]]::new()
    $citedPaths = [System.Collections.Generic.List[object]]::new()
    $worktrees = @($WorktreePaths | ForEach-Object { [IO.Path]::GetFullPath($_) } | Select-Object -Unique)
    $planningRootFull = [IO.Path]::GetFullPath($PlanningRoot)

    foreach ($worktree in $worktrees) {
      try {
        $listResult = Invoke-SprintEndNativeCommand -FilePath 'git' `
          -ArgumentList @('-C', $worktree, 'ls-files', '--', '_generated') -AllowNonZeroExitCode
        if (-not $listResult.Succeeded) { throw ($listResult.Output -join ' ') }
        foreach ($line in @($listResult.Output | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
          [void]$trackedPaths.Add([PSCustomObject]@{ Worktree = $worktree; Path = $line.Trim() })
        }
      } catch {
        [void]$failures.Add("GitListFailed:$worktree")
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error `
          -Message "Could not list tracked _generated files in '$worktree': $($_.Exception.Message)"
      }
    }
    if ($trackedPaths.Count -gt 0) { [void]$failures.Add('TrackedGeneratedArtifacts') }

    $sourceFiles = [System.Collections.Generic.List[string]]::new()
    if (Test-Path -LiteralPath $planningRootFull -PathType Container) {
      foreach ($board in @(Get-ChildItem -LiteralPath $planningRootFull -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '(?i)^(?:Tasks\.Sprint|TASKS)' -and $_.Extension -match '(?i)^\.(?:md|html)$' })) {
        [void]$sourceFiles.Add($board.FullName)
      }
      $futureRoot = Join-Path $planningRootFull 'InformationForTheFuture'
      if (Test-Path -LiteralPath $futureRoot -PathType Container) {
        foreach ($doc in @(Get-ChildItem -LiteralPath $futureRoot -File -Recurse -ErrorAction SilentlyContinue |
              Where-Object { $_.Extension -match '(?i)^\.(?:md|html|json)$' })) {
          [void]$sourceFiles.Add($doc.FullName)
        }
      }
    } else {
      [void]$failures.Add('PlanningRootMissing')
    }

    # Index each worktree's _generated tree once (relative file and directory
    # paths, '/'-separated); resolving thousands of citations with Test-Path on a
    # synced volume is too slow for a SprintEnd gate.
    $generatedIndex = @{}
    foreach ($worktree in $worktrees) {
      $set = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
      $generatedRoot = Join-Path $worktree '_generated'
      if (Test-Path -LiteralPath $generatedRoot -PathType Container) {
        foreach ($entry in [IO.Directory]::EnumerateFileSystemEntries($generatedRoot, '*', [IO.SearchOption]::AllDirectories)) {
          [void]$set.Add(([IO.Path]::GetRelativePath($generatedRoot, $entry) -replace '\\', '/'))
        }
      }
      $generatedIndex[$worktree] = $set
    }

    $tokenCharacters = '[^\s"''<>|()\[\]`*,;]'
    $citationRegex = [regex]::new("(?<prefix>$tokenCharacters*)_generated[\\/](?<tail>$tokenCharacters+)",
      [Text.RegularExpressions.RegexOptions]'IgnoreCase, Compiled')
    $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($sourceFile in $sourceFiles) {
      $lineNumber = 0
      foreach ($line in [IO.File]::ReadLines($sourceFile)) {
        $lineNumber++
        if ($line.IndexOf('_generated', [StringComparison]::OrdinalIgnoreCase) -lt 0) { continue }
        foreach ($match in $citationRegex.Matches($line)) {
          # Collapse separator runs so JSON-escaped citations (`_generated\\a\\b`
          # in the HTML board) resolve like their Markdown twins.
          $tail = ($match.Groups['tail'].Value -replace '[\\/]+', '/').TrimEnd('.', ':', '/').TrimStart('/')
          if ([string]::IsNullOrWhiteSpace($tail) -or $tail -match '[?]') { continue }
          $prefix = $match.Groups['prefix'].Value
          $candidates = @($worktrees | Where-Object {
              $prefix.IndexOf((Split-Path -Path $_ -Leaf), [StringComparison]::OrdinalIgnoreCase) -ge 0
            })
          if ($candidates.Count -eq 0) { $candidates = $worktrees }
          foreach ($worktree in $candidates) {
            if (-not $generatedIndex[$worktree].Contains($tail)) { continue }
            $resolved = [IO.Path]::GetFullPath((Join-Path (Join-Path $worktree '_generated') $tail))
            if (-not $seen.Add("$sourceFile|$lineNumber|$resolved")) { continue }
            [void]$citedPaths.Add([PSCustomObject]@{
                SourcePath   = $sourceFile
                LineNumber   = $lineNumber
                Citation     = $match.Value
                ResolvedPath = $resolved
              })
          }
        }
      }
    }
    $dispositionedPaths = [System.Collections.Generic.List[object]]::new()
    $dispositionError = $null
    if ($citedPaths.Count -gt 0) { [void]$failures.Add('CitedGeneratedArtifacts') }
    $originalFailures = $failures.ToArray()
    if ($PSBoundParameters.ContainsKey('GeneratedArtifactDisposition')) {
      try {
        # Resolve each untrusted component under its declared base, rejecting redirects.
        $checkAncestors = {
          param([string]$Path)
          $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
          while ($null -ne $item) {
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'ReparsePoint' }
            $item = $item.Parent
          }
        }
        $safePath = {
          param([string]$Base, [string]$Relative)
          if ([string]::IsNullOrWhiteSpace($Relative) -or $Relative -notmatch '^(?!/)(?!.*(?:^|/)\.{1,2}(?:/|$))(?!.*//)[^\\:\x00-\x1F]+(?<!/)$') { throw 'InvalidRelativePath' }
          $current = [IO.Path]::GetFullPath($Base)
          & $checkAncestors $current
          foreach ($part in $Relative.Split('/')) {
            $current = Join-Path $current $part
            $item = Get-Item -LiteralPath $current -Force -ErrorAction Stop
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'ReparsePoint' }
          }
          return [IO.Path]::GetFullPath($current)
        }
        $keysAre = { param($Object, [string[]]$Keys) return ($Object -is [System.Collections.IDictionary] -and @($Object.Keys).Count -eq $Keys.Count -and @($Keys | Where-Object { -not $Object.Contains($_) }).Count -eq 0) }
        $assertDurable = {
          param([string]$Path)
          $full = [IO.Path]::GetFullPath($Path)
          foreach ($worktree in $worktrees) {
            $root = [IO.Path]::GetFullPath((Join-Path $worktree '_generated')).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
            if ($full.Equals($root, [StringComparison]::OrdinalIgnoreCase) -or $full.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'NonDurableProofPath' }
          }
        }
        $recordPath = [IO.Path]::GetFullPath($GeneratedArtifactDisposition)
        & $assertDurable $recordPath
        $recordItem = Get-Item -LiteralPath $recordPath -Force -ErrorAction Stop
        if ($recordItem.PSIsContainer -or ($recordItem.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'InvalidDispositionPath' }
        & $checkAncestors $recordPath
        $record = Get-Content -LiteralPath $recordPath -Raw -ErrorAction Stop | ConvertFrom-Json -AsHashtable -ErrorAction Stop
        if (-not (& $keysAre $record @('schemaVersion','SprintNumber','GateName','RawFailure','ExternalManifest','AuthorityReference','ExpiresAfterSprint')) -or
            $record.schemaVersion -cne '1.0.0' -or $record.GateName -cne 'CitedGeneratedArtifacts' -or
            $record.SprintNumber -isnot [string] -or $record.SprintNumber -cnotmatch '\A[0-9]{4}\z' -or
            $record.ExpiresAfterSprint -isnot [string] -or $record.ExpiresAfterSprint -cnotmatch '\A[0-9]{4}\z' -or
            $record.ExpiresAfterSprint -cne $record.SprintNumber -or
            $record.AuthorityReference -isnot [string] -or $record.AuthorityReference.Length -eq 0) { throw 'InvalidDisposition' }
        foreach ($worktree in $worktrees) {
          if ((Split-Path $worktree -Leaf) -notmatch "(?i)Sprint-?$($record.SprintNumber)(?:-|$)") { throw 'SprintMismatch' }
        }
        $base = Split-Path $recordPath -Parent
        $references = @{}
        foreach ($name in @('RawFailure','ExternalManifest')) {
          $ref = $record[$name]
          if (-not (& $keysAre $ref @('path','sha256')) -or $ref.path -isnot [string] -or $ref.sha256 -isnot [string] -or $ref.sha256 -notmatch '^[a-fA-F0-9]{64}$') { throw 'InvalidReference' }
          $path = & $safePath $base $ref.path
          & $assertDurable $path
          if ([string]::Equals($path, $recordPath, [StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ine $ref.sha256) { throw 'ReferenceMismatch' }
          $references[$name] = $path
        }
        if ($references.RawFailure -ieq $references.ExternalManifest) { throw 'SelfReference' }
        $raw = Get-Content -LiteralPath $references.RawFailure -Raw | ConvertFrom-Json -AsHashtable -ErrorAction Stop
        if ($raw.Ok -isnot [bool] -or $raw.Ok -ne $false -or @($raw.Failures) -notcontains 'CitedGeneratedArtifacts' -or $null -eq $raw.CitedPaths) { throw 'InvalidRawFailure' }
        $manifest = Get-Content -LiteralPath $references.ExternalManifest -Raw | ConvertFrom-Json -AsHashtable -ErrorAction Stop
        if (-not (& $keysAre $manifest @('schemaVersion','files')) -or $manifest.schemaVersion -cne '1.0.0' -or $manifest.files -isnot [array] -or $manifest.files.Count -eq 0) { throw 'InvalidManifest' }
        $manifestBase = Split-Path $references.ExternalManifest -Parent
        $entries = @{}
        foreach ($entry in $manifest.files) {
          if (-not (& $keysAre $entry @('worktree','relativePath','preservedPath','sha256','bytes')) -or $entry.worktree -isnot [string] -or $entry.worktree -notmatch '^[^/\\:]+$' -or $entry.relativePath -isnot [string] -or $entry.preservedPath -isnot [string] -or $entry.sha256 -isnot [string] -or $entry.sha256 -notmatch '^[a-fA-F0-9]{64}$' -or $entry.bytes -isnot [long] -or $entry.bytes -lt 0) { throw 'InvalidManifestEntry' }
          $selected = @($worktrees | Where-Object { (Split-Path $_ -Leaf) -ieq $entry.worktree })
          if ($selected.Count -ne 1) { throw 'InvalidWorktree' }
          $key = "$($entry.worktree)|$($entry.relativePath)"
          if ($entries.ContainsKey($key)) { throw 'DuplicateManifestEntry' }
          $original = & $safePath (Join-Path $selected[0] '_generated') $entry.relativePath
          $preserved = & $safePath $manifestBase $entry.preservedPath
          & $assertDurable $preserved
          if ($preserved -ieq $original -or $preserved -ieq $recordPath -or $preserved -ieq $references.ExternalManifest -or $preserved -ieq $references.RawFailure -or -not (Test-Path -LiteralPath $original -PathType Leaf) -or -not (Test-Path -LiteralPath $preserved -PathType Leaf)) { throw 'InvalidPreservedFile' }
          foreach ($file in @($original, $preserved)) {
            if ((Get-Item -LiteralPath $file).Length -ne $entry.bytes -or (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -ine $entry.sha256) { throw 'PreservedFileMismatch' }
          }
          $entries[$key] = $original
        }
        foreach ($citation in $citedPaths) {
          $rawMatch = @($raw.CitedPaths | Where-Object { $_.ResolvedPath -ieq $citation.ResolvedPath -and $_.SourcePath -ieq $citation.SourcePath -and $_.LineNumber -eq $citation.LineNumber -and $_.Citation -ceq $citation.Citation })
          if ($rawMatch.Count -ne 1) { continue }
          foreach ($original in $entries.Values) {
            if ($original -ieq $citation.ResolvedPath) { [void]$dispositionedPaths.Add($citation); break }
          }
        }
        if ($citedPaths.Count -gt 0 -and $dispositionedPaths.Count -eq $citedPaths.Count) { [void]$failures.Remove('CitedGeneratedArtifacts') }
      } catch {
        $dispositionedPaths.Clear()
        $dispositionError = $_.Exception.Message
        [void]$failures.Add('InvalidGeneratedArtifactDisposition')
      }
    }

    [PSCustomObject]@{
      Ok           = ($failures.Count -eq 0)
      WorktreePaths = $worktrees
      PlanningRoot = $planningRootFull
      TrackedPaths = $trackedPaths.ToArray()
      CitedPaths   = $citedPaths.ToArray()
      DispositionedPaths = $dispositionedPaths.ToArray()
      DispositionError = $dispositionError
      OriginalFailures = $originalFailures
      Failures     = $failures.ToArray()
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
