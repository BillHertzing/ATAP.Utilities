function Restore-SprintHistoryArtifacts {
  <#
  .SYNOPSIS
  Reconstructs selected sprint-planning artifacts from an immutable Git commit.

  .DESCRIPTION
  Restores explicitly named repository paths from SourceRef into
  SprintHistory/SprintNNNN beneath PlanningRoot. Git blob bytes are written
  without text conversion, source-relative paths are preserved, and an
  immutable Reconstruction.json provenance record is maintained.

  Identical reruns are idempotent. Existing files with different content and
  existing manifests with different provenance are preserved and reported.
  The command never searches arbitrary Git history.

  .PARAMETER PlanningRoot
  Root of the planning Git repository.

  .PARAMETER SprintNumber
  Sprint number used to create SprintHistory/SprintNNNN.

  .PARAMETER SourceRef
  Commit-ish containing the historical artifacts. The ref is resolved to a
  full commit hash before restoration.

  .PARAMETER SourcePath
  One or more repository-relative paths to restore from SourceRef.

  .PARAMETER NotebookPath
  Optional notebook path recorded in Reconstruction.json.

  .EXAMPLE
  Restore-SprintHistoryArtifacts `
    -PlanningRoot 'C:\Dropbox\whertzing\GitHub\_Planning' `
    -SprintNumber 9 `
    -SourceRef 'e7831e2' `
    -SourcePath 'TASKS.md', 'Tasks.Accomplished.html'
  #>
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
  [OutputType([pscustomobject])]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $PlanningRoot,

    [Parameter(Mandatory)]
    [ValidateRange(1, 9999)]
    [int] $SprintNumber,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $SourceRef,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string[]] $SourcePath,

    [Parameter()]
    [string] $NotebookPath
  )

  begin {
    $functionName = $MyInvocation.MyCommand.Name
    $moduleName = 'ATAP.Utilities.BuildTooling.PowerShell'
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)

    $invokeGitForBytes = {
      param(
        [Parameter(Mandatory)]
        [string[]] $Arguments
      )

      $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
      $startInfo.FileName = 'git'
      $startInfo.UseShellExecute = $false
      $startInfo.CreateNoWindow = $true
      $startInfo.RedirectStandardOutput = $true
      $startInfo.RedirectStandardError = $true

      foreach ($argument in $Arguments) {
        $null = $startInfo.ArgumentList.Add($argument)
      }

      $process = [System.Diagnostics.Process]::new()
      $process.StartInfo = $startInfo
      $standardOutput = [System.IO.MemoryStream]::new()

      try {
        if (-not $process.Start()) {
          throw 'Unable to start git.'
        }

        # Drain stderr concurrently before waiting so redirected buffers cannot
        # deadlock while stdout is copied byte-for-byte.
        $standardErrorTask = $process.StandardError.ReadToEndAsync()
        $process.StandardOutput.BaseStream.CopyTo($standardOutput)
        $process.WaitForExit()
        $standardError = $standardErrorTask.GetAwaiter().GetResult()

        [pscustomobject]@{
          ExitCode = $process.ExitCode
          Bytes    = $standardOutput.ToArray()
          Error    = $standardError.Trim()
        }
      }
      finally {
        $standardOutput.Dispose()
        $process.Dispose()
      }
    }

    $normalizeRepositoryPath = {
      param(
        [Parameter(Mandatory)]
        [string] $Path
      )

      if ([string]::IsNullOrWhiteSpace($Path)) {
        throw 'SourcePath cannot be empty.'
      }

      $normalizedPath = $Path.Trim().Replace('\', '/').TrimStart('/')
      if (
        [System.IO.Path]::IsPathRooted($Path) -or
        $normalizedPath.Contains(':') -or
        $normalizedPath.IndexOf([char]0) -ge 0
      ) {
        throw "SourcePath '$Path' must be repository-relative."
      }

      $segments = @($normalizedPath.Split('/', [System.StringSplitOptions]::None))
      if (
        $segments.Count -eq 0 -or
        $segments.Where({ [string]::IsNullOrWhiteSpace($_) -or $_ -eq '.' -or $_ -eq '..' }).Count -gt 0
      ) {
        throw "SourcePath '$Path' contains an invalid path segment."
      }

      if ($normalizedPath.Equals('Reconstruction.json', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "SourcePath '$Path' conflicts with the reconstruction manifest."
      }

      return $normalizedPath
    }
  }

  process {
    $resolvedPlanningRoot = (Resolve-Path -LiteralPath $PlanningRoot -ErrorAction Stop).Path
    $sprintLabel = 'Sprint{0:D4}' -f $SprintNumber
    $historyRoot = Join-Path $resolvedPlanningRoot "SprintHistory\$sprintLabel"
    $manifestPath = Join-Path $historyRoot 'Reconstruction.json'
    $failures = [System.Collections.Generic.List[object]]::new()
    $fileResults = [System.Collections.Generic.List[object]]::new()

    Write-PSFMessage -FunctionName $functionName -ModuleName $moduleName -Level Debug `
      -Message "Resolving sprint-history source ref '$SourceRef' beneath '$resolvedPlanningRoot'." `
      -Tag 'SprintHistory'

    $resolveRefResult = & $invokeGitForBytes -Arguments @(
      '-C',
      $resolvedPlanningRoot,
      'rev-parse',
      '--verify',
      "$SourceRef^{commit}"
    )

    if ($resolveRefResult.ExitCode -ne 0) {
      throw "SourceRef '$SourceRef' is not a valid commit in '$resolvedPlanningRoot'. $($resolveRefResult.Error)"
    }

    $resolvedSourceRef = $utf8NoBom.GetString($resolveRefResult.Bytes).Trim()
    if ($resolvedSourceRef -notmatch '^[0-9a-fA-F]{40,64}$') {
      throw "Git returned an unexpected commit identifier for SourceRef '$SourceRef'."
    }

    $normalizedNotebookPath = if ([string]::IsNullOrWhiteSpace($NotebookPath)) {
      $null
    }
    else {
      $NotebookPath.Trim().Replace('\', '/')
    }

    $normalizedSourcePaths = [System.Collections.Generic.List[string]]::new()
    $seenSourcePaths = [System.Collections.Generic.HashSet[string]]::new(
      [System.StringComparer]::OrdinalIgnoreCase
    )

    foreach ($requestedPath in $SourcePath) {
      $normalizedPath = & $normalizeRepositoryPath -Path $requestedPath
      if ($seenSourcePaths.Add($normalizedPath)) {
        $normalizedSourcePaths.Add($normalizedPath)
      }
    }

    $existingManifest = $null
    if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
      try {
        $existingManifest = Get-Content -LiteralPath $manifestPath -Raw -ErrorAction Stop |
          ConvertFrom-Json -ErrorAction Stop
      }
      catch {
        $failures.Add([pscustomobject]@{
            Kind    = 'InvalidManifest'
            Path    = $manifestPath
            Message = "Existing reconstruction manifest could not be read: $($_.Exception.Message)"
          })
      }

      if ($null -ne $existingManifest) {
        $existingManifestRef = [string] $existingManifest.SourceRef
        $existingResolvedRef = $null

        if (-not [string]::IsNullOrWhiteSpace($existingManifestRef)) {
          $existingRefResult = & $invokeGitForBytes -Arguments @(
            '-C',
            $resolvedPlanningRoot,
            'rev-parse',
            '--verify',
            "$existingManifestRef^{commit}"
          )

          if ($existingRefResult.ExitCode -eq 0) {
            $existingResolvedRef = $utf8NoBom.GetString($existingRefResult.Bytes).Trim()
          }
        }

        $sameProvenance = (
          [int] $existingManifest.SprintNumber -eq $SprintNumber -and
          $existingResolvedRef -eq $resolvedSourceRef -and
          [string] $existingManifest.NotebookPath -eq [string] $normalizedNotebookPath
        )

        if (-not $sameProvenance) {
          $failures.Add([pscustomobject]@{
              Kind    = 'ProvenanceConflict'
              Path    = $manifestPath
              Message = 'Existing reconstruction manifest has different provenance and was preserved.'
            })
        }
      }
    }

    if ($failures.Count -eq 0) {
      $historyRootFullPath = [System.IO.Path]::GetFullPath($historyRoot)
      $historyRootPrefix = $historyRootFullPath.TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
      ) + [System.IO.Path]::DirectorySeparatorChar

      foreach ($normalizedSourcePath in $normalizedSourcePaths) {
        $blobResult = & $invokeGitForBytes -Arguments @(
          '-C',
          $resolvedPlanningRoot,
          'cat-file',
          'blob',
          "${resolvedSourceRef}:$normalizedSourcePath"
        )

        $relativeDestinationPath = $normalizedSourcePath.Replace(
          '/',
          [System.IO.Path]::DirectorySeparatorChar
        )
        $destinationPath = [System.IO.Path]::GetFullPath(
          (Join-Path $historyRootFullPath $relativeDestinationPath)
        )

        if (-not $destinationPath.StartsWith(
            $historyRootPrefix,
            [System.StringComparison]::OrdinalIgnoreCase
          )) {
          throw "SourcePath '$normalizedSourcePath' resolves outside '$historyRootFullPath'."
        }

        if ($blobResult.ExitCode -ne 0) {
          $failure = [pscustomobject]@{
            Kind    = 'MissingSource'
            Path    = $normalizedSourcePath
            Message = "Path '$normalizedSourcePath' does not exist at commit '$resolvedSourceRef'."
          }
          $failures.Add($failure)
          $fileResults.Add([pscustomobject]@{
              SourcePath      = $normalizedSourcePath
              DestinationPath = $destinationPath
              Status          = 'MissingSource'
              Sha256          = $null
            })
          continue
        }

        $sourceHashAlgorithm = [System.Security.Cryptography.SHA256]::Create()
        try {
          $sourceHash = [System.Convert]::ToHexString(
            $sourceHashAlgorithm.ComputeHash($blobResult.Bytes)
          )
        }
        finally {
          $sourceHashAlgorithm.Dispose()
        }

        if (Test-Path -LiteralPath $destinationPath) {
          if (-not (Test-Path -LiteralPath $destinationPath -PathType Leaf)) {
            $failures.Add([pscustomobject]@{
                Kind    = 'ContentConflict'
                Path    = $destinationPath
                Message = 'Destination exists but is not a file and was preserved.'
              })
            $fileResults.Add([pscustomobject]@{
                SourcePath      = $normalizedSourcePath
                DestinationPath = $destinationPath
                Status          = 'PreservedConflict'
                Sha256          = $sourceHash
              })
            continue
          }

          $destinationHash = (Get-FileHash -LiteralPath $destinationPath -Algorithm SHA256).Hash
          if ($destinationHash -eq $sourceHash) {
            $fileResults.Add([pscustomobject]@{
                SourcePath      = $normalizedSourcePath
                DestinationPath = $destinationPath
                Status          = 'Identical'
                Sha256          = $sourceHash
              })
            continue
          }

          $failures.Add([pscustomobject]@{
              Kind    = 'ContentConflict'
              Path    = $destinationPath
              Message = 'Destination content differs from the selected Git blob and was preserved.'
            })
          $fileResults.Add([pscustomobject]@{
              SourcePath      = $normalizedSourcePath
              DestinationPath = $destinationPath
              Status          = 'PreservedConflict'
              Sha256          = $sourceHash
            })
          continue
        }

        if ($PSCmdlet.ShouldProcess($destinationPath, "Restore from $resolvedSourceRef")) {
          $destinationDirectory = Split-Path -Parent $destinationPath
          if (-not (Test-Path -LiteralPath $destinationDirectory -PathType Container)) {
            $null = New-Item -ItemType Directory -Path $destinationDirectory -Force
          }

          [System.IO.File]::WriteAllBytes($destinationPath, $blobResult.Bytes)
          $status = 'Restored'
        }
        else {
          $status = 'Planned'
        }

        $fileResults.Add([pscustomobject]@{
            SourcePath      = $normalizedSourcePath
            DestinationPath = $destinationPath
            Status          = $status
            Sha256          = $sourceHash
          })
      }
    }

    if ($failures.Count -eq 0) {
      $manifestSourcePaths = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
      )

      if ($null -ne $existingManifest) {
        foreach ($existingPath in @($existingManifest.SourcePaths)) {
          if (-not [string]::IsNullOrWhiteSpace([string] $existingPath)) {
            $null = $manifestSourcePaths.Add(([string] $existingPath).Replace('\', '/'))
          }
        }
      }

      foreach ($normalizedSourcePath in $normalizedSourcePaths) {
        $null = $manifestSourcePaths.Add($normalizedSourcePath)
      }

      $manifest = [ordered]@{
        SprintNumber  = '{0:D4}' -f $SprintNumber
        SourceRef     = $resolvedSourceRef
        SourcePaths   = @($manifestSourcePaths | Sort-Object)
        NotebookPath  = $normalizedNotebookPath
      }

      if ($PSCmdlet.ShouldProcess($manifestPath, 'Write reconstruction provenance')) {
        if (-not (Test-Path -LiteralPath $historyRoot -PathType Container)) {
          $null = New-Item -ItemType Directory -Path $historyRoot -Force
        }

        $manifestJson = $manifest | ConvertTo-Json -Depth 5
        [System.IO.File]::WriteAllText($manifestPath, "$manifestJson`r`n", $utf8NoBom)
      }
    }

    $ok = $failures.Count -eq 0
    Write-PSFMessage -FunctionName $functionName -ModuleName $moduleName -Level Important `
      -Message "Sprint-history reconstruction completed for $sprintLabel with $($fileResults.Count) file result(s) and $($failures.Count) failure(s)." `
      -Tag 'SprintHistory'

    [pscustomobject]@{
      Ok                 = $ok
      SprintNumber       = $SprintNumber
      RequestedSourceRef = $SourceRef
      SourceRef          = $resolvedSourceRef
      HistoryRoot        = $historyRoot
      ManifestPath       = $manifestPath
      Files              = @($fileResults)
      Failures           = @($failures)
    }
  }
}
