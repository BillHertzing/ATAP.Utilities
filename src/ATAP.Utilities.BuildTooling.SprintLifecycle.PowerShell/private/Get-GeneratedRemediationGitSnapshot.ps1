function Get-GeneratedRemediationGitSnapshot {
  <#
  .SYNOPSIS
    Captures checked, read-only Git metadata for a later manifest acquisition layer.
  .DESCRIPTION
    Uses two observations, raw binary output and index hashes. This is not an
    atomic snapshot or a content/ADS inventory. No returned record is ready for
    manifest execution. Unborn, missing/split index, submodule and filter-configured
    repositories fail closed. Requires trusted local Git configuration and an
    agreed quiet window. Get-RepositoryRoot is a preliminary unmanaged resolver:
    its rev-parse call does not inherit the managed child's timeout/config flags.
    Configuration includes/core.worktree must not introduce external paths.
  .PARAMETER RootPath
    Expected exact worktree root; subdirectories and redirecting ancestors fail.
  .PARAMETER ExpectedCommonGitDir
    Caller-supplied expected common Git directory, checked against Git resolution.
  .PARAMETER TimeoutSeconds
    Upper bound for each managed Git child process.
  .OUTPUTS
    One object containing Success, Errors, Observations and explicit limitations.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$RootPath,
    [Parameter(Mandatory)][string]$ExpectedCommonGitDir,
    [ValidateRange(1, 120)][int]$TimeoutSeconds = 30
  )
  begin {
    $fn = 'Get-GeneratedRemediationGitSnapshot'
    $mn = 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell'
    $errors = [Collections.Generic.List[string]]::new()
    $observations = [Collections.Generic.List[object]]::new()
    $binding = $null
    $consistent = $false
    $timeoutMilliseconds = $TimeoutSeconds * 1000
    # Reject before loading or invoking the preliminary repository resolver.
    $ambientGitKeys = @([Environment]::GetEnvironmentVariables().Keys | Where-Object { $_ -like 'GIT_*' })
    if ($ambientGitKeys.Count) { $errors.Add('Ambient GIT_* environment is unsupported; no resolver or Git command was invoked.') }
    if (-not $errors.Count) {
      try {
        if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) { Import-Module PSFramework -ErrorAction Stop }
        $srcRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $resolver = Join-Path $srcRoot 'ATAP.Utilities.BuildTooling.Common.PowerShell/public/Get-RepositoryRoot.ps1'
        if (Test-Path -LiteralPath $resolver -PathType Leaf) { . $resolver }
        elseif (-not (Get-Command Get-RepositoryRoot -ErrorAction SilentlyContinue)) { throw 'Get-RepositoryRoot is unavailable.' }
      } catch { $errors.Add("Resolver loading failed: $($_.Exception.Message)") }
    }
  }
  process {
    function Get-SnapshotHash {
      param([byte[]]$Bytes)
      $sha = [Security.Cryptography.SHA256]::Create()
      try { [Convert]::ToHexString($sha.ComputeHash($Bytes)) } finally { $sha.Dispose() }
    }
    function Get-SnapshotLocalPath {
      param([string]$Path)
      # Lexical rejection precedes all target filesystem access, including UNC/device paths.
      if ($Path -notmatch '^[A-Za-z]:[\\/]' -or $Path -match '[\x00-\x1f]' -or $Path.Substring(2).Contains(':')) {
        throw 'Only fully qualified local drive paths are supported; UNC/device paths are refused.'
      }
      $drive = [IO.DriveInfo]::new($Path.Substring(0, 3))
      if ($drive.DriveType -ne [IO.DriveType]::Fixed) { throw 'Only fixed local drives are supported; network-mapped drives are refused.' }
      $full = [IO.Path]::GetFullPath($Path)
      if ($full.Length -gt 3) { $full = $full.TrimEnd([char[]]'\/') }
      return $full
    }
    function Get-SnapshotSafePath {
      param([string]$Path)
      $full = Get-SnapshotLocalPath $Path
      $cursor = [IO.Path]::GetPathRoot($full)
      $segments = @('') + @($full.Substring($cursor.Length) -split '[\\/]' | Where-Object { $_ })
      foreach ($segment in $segments) {
        if ($segment) { $cursor = Join-Path $cursor $segment }
        $item = Get-Item -LiteralPath $cursor -Force -ErrorAction Stop
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -and $null -ne $item.LinkTarget) {
          throw 'Redirecting path ancestor is unsupported.'
        }
      }
      return $full
    }
    function Get-SnapshotPointerTarget {
      param([string]$Text, [string]$ParentPath)
      $target = $Text.TrimEnd([char[]]"`r`n")
      if (-not $target -or $target -match '[\x00-\x1f]' -or $target -match '^[\\/]' -or $target -match '^[A-Za-z]:[^\\/]') {
        throw 'Unsupported remote/device/ambiguous Git control pointer.'
      }
      if ($target -match '^[A-Za-z]:[\\/]') { return Get-SnapshotSafePath $target }
      if ($target.Contains(':')) { throw 'Unsupported Git control pointer syntax.' }
      return Get-SnapshotSafePath ([IO.Path]::GetFullPath((Join-Path $ParentPath $target)))
    }
    function Get-SnapshotOptionalChild {
      param([string]$ParentPath, [string]$Name)
      $entry = @(Get-ChildItem -LiteralPath $ParentPath -Force -ErrorAction Stop | Where-Object Name -EQ $Name)
      if ($entry.Count -gt 1) { throw 'Ambiguous Git metadata entry.' }
      if ($entry.Count) { return Get-SnapshotSafePath $entry[0].FullName }
      return $null
    }
    function Invoke-SnapshotGit {
      param([string[]]$Arguments, [int[]]$AllowedExitCodes = @(0))
      $start = [Diagnostics.ProcessStartInfo]::new($gitExecutable)
      $start.WorkingDirectory = $canonicalRoot
      $start.UseShellExecute = $false
      $start.RedirectStandardOutput = $true
      $start.RedirectStandardError = $true
      $start.CreateNoWindow = $true
      foreach ($key in @($start.Environment.Keys | Where-Object { $_ -like 'GIT_*' })) { $null = $start.Environment.Remove($key) }
      $start.Environment['GIT_OPTIONAL_LOCKS'] = '0'
      $start.Environment['GIT_CONFIG_NOSYSTEM'] = '1'
      $start.Environment['GIT_CONFIG_GLOBAL'] = 'NUL'
      $start.Environment['GIT_CONFIG_SYSTEM'] = 'NUL'
      $start.Environment['GIT_NO_REPLACE_OBJECTS'] = '1'
      $start.Environment['GIT_TERMINAL_PROMPT'] = '0'
      $start.Environment['GIT_NO_LAZY_FETCH'] = '1'
      foreach ($arg in @('-c', 'core.fsmonitor=false', '-c', 'core.untrackedCache=false', '-c', 'gc.auto=0', '-c', 'maintenance.auto=false', '-c', 'core.hooksPath=', '--no-optional-locks', '--no-lazy-fetch') + $Arguments) {
        $start.ArgumentList.Add($arg)
      }
      $process = $null
      $buffer = [IO.MemoryStream]::new()
      try {
        $process = [Diagnostics.Process]::Start($start)
        $stdoutTask = $process.StandardOutput.BaseStream.CopyToAsync($buffer)
        $stderrTask = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($timeoutMilliseconds)) {
          $process.Kill($true)
          $process.WaitForExit()
          $null = $stdoutTask.GetAwaiter().GetResult()
          $null = $stderrTask.GetAwaiter().GetResult()
          throw 'Git metadata command timed out.'
        }
        $null = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        if ($process.ExitCode -notin $AllowedExitCodes) { throw "Git metadata command failed with exit $($process.ExitCode)." }
        [pscustomobject]@{ Bytes = $buffer.ToArray(); ExitCode = $process.ExitCode; StderrPresent = (-not [string]::IsNullOrEmpty($stderr)) }
      } finally {
        if ($null -ne $process) { $process.Dispose() }
        $buffer.Dispose()
      }
    }
    function Get-SnapshotScalar {
      param([string[]]$Arguments)
      $result = Invoke-SnapshotGit $Arguments
      $decoder = [Text.UTF8Encoding]::new($false, $true)
      $value = $decoder.GetString($result.Bytes).TrimEnd([char[]]"`r`n")
      if (-not $value -or $value -match '[\x00-\x1f]') { throw 'Malformed Git scalar metadata.' }
      return $value
    }
    function Get-SnapshotObservation {
      $head = Get-SnapshotScalar @('rev-parse', '--verify', 'HEAD')
      if ($head -cnotmatch '^([a-f0-9]{40}|[a-f0-9]{64})$') { throw 'Unsupported HEAD object identity.' }
      $branchResult = Invoke-SnapshotGit @('symbolic-ref', '--quiet', 'HEAD') @(0, 1)
      $branch = if ($branchResult.ExitCode -eq 0) { [Text.UTF8Encoding]::new($false, $true).GetString($branchResult.Bytes).TrimEnd([char[]]"`r`n") } else { $null }
      if ($branch -and ($branch -notmatch '^refs/heads/' -or $branch -match '[\x00-\x1f]')) { throw 'Malformed HEAD branch.' }
      $indexPath = Get-SnapshotSafePath (Get-SnapshotScalar @('rev-parse', '--path-format=absolute', '--git-path', 'index'))
      if ($indexPath -ine [IO.Path]::GetFullPath((Join-Path $gitDir 'index'))) { throw 'Index is outside the bound gitDir.' }
      if (-not (Test-Path -LiteralPath $indexPath -PathType Leaf)) { throw 'Missing index is unsupported.' }
      $indexBefore = Get-SnapshotHash ([IO.File]::ReadAllBytes($indexPath))
      $stages = Invoke-SnapshotGit @('ls-files', '--stage', '-z')
      # Detect only record prefixes; retain original bytes, never split path text.
      $stageText = [Text.UTF8Encoding]::new($false, $true).GetString($stages.Bytes)
      if ($stageText -match '(?:^|\x00)160000 ') { throw 'Submodule index entries are unsupported.' }
      $status = Invoke-SnapshotGit @('status', '--porcelain=v2', '-z', '--untracked-files=all', '--ignored=matching', '--ignore-submodules=all')
      $indexAfter = Get-SnapshotHash ([IO.File]::ReadAllBytes($indexPath))
      if ($indexBefore -ne $indexAfter) { throw 'Index changed during observation.' }
      [pscustomobject]@{
        Head = $head; Branch = $branch; Detached = ($branchResult.ExitCode -eq 1)
        IndexPath = $indexPath; IndexSHA256 = $indexAfter
        StageBytesBase64 = [Convert]::ToBase64String($stages.Bytes); StageBytesSHA256 = Get-SnapshotHash $stages.Bytes
        StatusBytesBase64 = [Convert]::ToBase64String($status.Bytes); StatusBytesSHA256 = Get-SnapshotHash $status.Bytes
      }
    }
    if (-not $errors.Count) {
      try {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Capturing read-only Git metadata; no content completeness asserted.'
        # Validate both lexical roots before either target is probed.
        $canonicalRoot = Get-SnapshotLocalPath $RootPath
        $expectedCommon = Get-SnapshotLocalPath $ExpectedCommonGitDir
        $canonicalRoot = Get-SnapshotSafePath $canonicalRoot
        $expectedCommon = Get-SnapshotSafePath $expectedCommon
        $controlPath = Get-SnapshotSafePath (Join-Path $canonicalRoot '.git')
        $control = Get-Item -LiteralPath $controlPath -Force -ErrorAction Stop
        $preGitDir = $controlPath
        if (-not $control.PSIsContainer) {
          $pointer = [IO.File]::ReadAllText($controlPath)
          if (-not $pointer.StartsWith('gitdir: ')) { throw 'Malformed .git control file.' }
          $preGitDir = Get-SnapshotPointerTarget $pointer.Substring(8) $canonicalRoot
        }
        $commonPointer = Get-SnapshotOptionalChild $preGitDir 'commondir'
        $preCommon = if ($commonPointer) { Get-SnapshotPointerTarget ([IO.File]::ReadAllText($commonPointer)) $preGitDir } else { $preGitDir }
        if ($preCommon -ine $expectedCommon) { throw 'Preliminary commonGitDir binding mismatch.' }
        # Object-store redirection is rejected before any Git command can consume it.
        $objectsPath = Get-SnapshotSafePath (Join-Path $preCommon 'objects')
        $infoPath = Get-SnapshotSafePath (Join-Path $objectsPath 'info')
        foreach ($name in @('alternates', 'http-alternates')) {
          if (Get-SnapshotOptionalChild $infoPath $name) { throw 'Alternate object stores are unsupported.' }
        }
        $packPath = Get-SnapshotSafePath (Join-Path $objectsPath 'pack')
        if (@(Get-ChildItem -LiteralPath $packPath -Force -ErrorAction Stop | Where-Object Name -Like '*.promisor').Count) { throw 'Promisor object stores are unsupported.' }
        $gitCommand = Get-Command git -ErrorAction Stop
        if ($gitCommand.CommandType -ne 'Application') { throw 'Git must resolve to an application, not a function or alias.' }
        $gitExecutable = $gitCommand.Source
        $unsupported = Invoke-SnapshotGit @('config', '--name-only', '--get-regexp', '^(filter\.|diff\.external$|core\.sparsecheckout$|core\.splitindex$|extensions\.partialclone$|remote\..*\.(promisor|partialclonefilter)$)') @(0, 1)
        if ($unsupported.ExitCode -eq 0) { throw 'Filter/external-diff/sparse/split-index/partial-clone/promisor configuration is unsupported.' }
        $preliminaryRoot = Get-RepositoryRoot -StartPath $canonicalRoot -Absolute -ErrorAction Stop
        if ([IO.Path]::GetFullPath($preliminaryRoot).TrimEnd([char[]]'\/') -ine $canonicalRoot) { throw 'Preliminary root does not match expected exact root.' }
        $actualRoot = Get-SnapshotSafePath (Get-SnapshotScalar @('rev-parse', '--show-toplevel'))
        $gitDir = Get-SnapshotSafePath (Get-SnapshotScalar @('rev-parse', '--absolute-git-dir'))
        $commonDir = Get-SnapshotSafePath (Get-SnapshotScalar @('rev-parse', '--path-format=absolute', '--git-common-dir'))
        if ($actualRoot -ine $canonicalRoot -or $commonDir -ine $expectedCommon -or $gitDir -ine $preGitDir) { throw 'Root/commonGitDir/gitDir binding mismatch.' }
        if ($gitDir -ine $commonDir -and -not $gitDir.StartsWith((Join-Path $commonDir 'worktrees') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
          throw 'gitDir is outside the expected common repository.'
        }
        if (Test-Path -LiteralPath (Join-Path $gitDir 'index.lock')) { throw 'Index lock present; snapshot refused.' }
        $splitIndex = Invoke-SnapshotGit @('rev-parse', '--shared-index-path')
        if ($splitIndex.Bytes.Length) { throw 'Split index is unsupported.' }
        $binding = [pscustomobject]@{ Root = $actualRoot; CommonGitDir = $commonDir; GitDir = $gitDir }
        $observations.Add((Get-SnapshotObservation))
        $observations.Add((Get-SnapshotObservation))
        $first = $observations[0]; $last = $observations[1]
        $consistent = $first.Head -ceq $last.Head -and $first.Branch -ceq $last.Branch -and $first.IndexPath -ceq $last.IndexPath -and
          $first.IndexSHA256 -ceq $last.IndexSHA256 -and $first.StageBytesSHA256 -ceq $last.StageBytesSHA256 -and $first.StatusBytesSHA256 -ceq $last.StatusBytesSHA256
        if (-not $consistent) { throw 'Git metadata changed between observations.' }
        if ((Get-SnapshotSafePath (Get-SnapshotScalar @('rev-parse', '--show-toplevel'))) -ine $canonicalRoot -or
          (Get-SnapshotSafePath (Get-SnapshotScalar @('rev-parse', '--path-format=absolute', '--git-common-dir'))) -ine $expectedCommon -or
          (Get-SnapshotSafePath (Get-SnapshotScalar @('rev-parse', '--absolute-git-dir'))) -ine $gitDir) { throw 'Repository identity changed during capture.' }
        if (Test-Path -LiteralPath (Join-Path $gitDir 'index.lock')) { throw 'Index lock appeared during capture.' }
      } catch { $errors.Add($_.Exception.Message); $consistent = $false }
    }
  }
  end {
    [pscustomobject]@{
      Success = ($errors.Count -eq 0); Errors = $errors.ToArray(); Binding = $binding
      Observations = $observations.ToArray(); Consistent = $consistent
      InventoryComplete = $false; ReadyForManifest = $false
      Limitations = 'Metadata only; two equal observations are not atomic. Status does not hash tracked, untracked or ignored contents/ADS; same-status content changes and ABA races can be missed. Trusted local configuration and quiet window required: preliminary Get-RepositoryRoot is unmanaged and has no child timeout/config isolation. No approval or custody verification.'
    }
  }
}
