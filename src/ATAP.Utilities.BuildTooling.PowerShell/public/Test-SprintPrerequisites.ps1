#Requires -Version 7.0

function Test-SprintUrlReachable {
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter()]
    [AllowEmptyString()]
    [AllowNull()]
    [string]$Url,

    [Parameter()]
    [int]$TimeoutSeconds = 5,

    [Parameter(Mandatory = $true)]
    [string]$Label
  )

  if ([string]::IsNullOrWhiteSpace($Url)) {
    return [PSCustomObject]@{
      Ok      = $true
      Detail  = "$Label base URL not supplied; reachability check skipped"
      Url     = $null
      Skipped = $true
    }
  }

  try {
    $response = Invoke-WebRequest -Uri $Url -Method Head -TimeoutSec $TimeoutSeconds -UseBasicParsing -ErrorAction Stop
    $code = [int]$response.StatusCode
    return [PSCustomObject]@{
      Ok      = ($code -lt 500)
      Detail  = "$Label HEAD $Url returned HTTP $code"
      Url     = $Url
      Skipped = $false
    }
  } catch {
    $code = $null
    if ($_.Exception.PSObject.Properties['Response'] -and $_.Exception.Response -and $_.Exception.Response.StatusCode) {
      $code = [int]$_.Exception.Response.StatusCode
    }
    if ($code -and $code -lt 500) {
      return [PSCustomObject]@{
        Ok      = $true
        Detail  = "$Label HEAD $Url returned HTTP $code (reachable; auth not asserted)"
        Url     = $Url
        Skipped = $false
      }
    }
    return [PSCustomObject]@{
      Ok      = $false
      Detail  = "$Label HEAD $Url failed: $($_.Exception.Message)"
      Url     = $Url
      Skipped = $false
    }
  }
}

function Test-SprintPrerequisites {
  <#
.SYNOPSIS
    Verifies that SprintStartAgent or SprintEndAgent preconditions are satisfied.

.DESCRIPTION
    Runs a read-only preflight covering: pwsh engine version, gh CLI auth,
    Bitwarden CLI session, git working state of each required sprint worktree
    (no in-progress merge/rebase/cherry-pick/revert/bisect), BuildTooling module
    importability, and HEAD reachability of the ProGet and BuildMaster base URLs.
    Each discovered worktree is also checked with Assert-LockFilesClean unless
    -SkipLockFileGuard is supplied.

    Every check runs to completion regardless of earlier failures so the
    structured result captures the full diagnostic picture. The cmdlet always
    returns a [PSCustomObject]; with -ThrowOnFailure, it additionally throws a
    terminating error (FullyQualifiedErrorId: SprintPrerequisitesFailedException)
    when AllOk is $false.

.PARAMETER RequiredRepoWorktrees
    Paths of git working trees to inspect. Defaults to all
    *-wt-*-Sprint-*-work-items directories in the parent of the current worktree.

.PARAMETER MinimumPwshVersion
    Required PowerShell engine version. Default '7.0'.

.PARAMETER ProGetBaseUrl
    Base URL for ProGet. Defaults to
    $global:settings[$global:configRootKeys['ProGetBaseUrlConfigRootKey']]
    when available. Empty/null marks the check as Skipped (Ok=$true).

.PARAMETER BuildMasterBaseUrl
    Base URL for BuildMaster. Defaults to
    $global:settings[$global:configRootKeys['BuildMasterBaseUrlConfigRootKey']]
    when available. Empty/null marks the check as Skipped (Ok=$true).

.PARAMETER ReachabilityTimeoutSeconds
    HTTP timeout for the two reachability checks. Default 5.

.PARAMETER ThrowOnFailure
    If supplied, throw a terminating error when AllOk is $false.

.PARAMETER SkipLockFileGuard
    Explicitly bypasses Assert-LockFilesClean for sprint-start/sprint-end
    preflight. Use only when lock-file drift has been separately reviewed and
    the reason is recorded in sprint notes.

.OUTPUTS
    [PSCustomObject] with AllOk [bool], Checks [PSCustomObject], Failures [string[]],
    Timestamp [DateTime].

.EXAMPLE
    Test-SprintPrerequisites | ConvertTo-Json -Depth 4

.EXAMPLE
    Test-SprintPrerequisites -ThrowOnFailure

.NOTES
    AI assisted using Powershell.instructions.md as guidelines
#>
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter()]
    [string[]]$RequiredRepoWorktrees,

    [Parameter()]
    [ValidatePattern('^\d+\.\d+$')]
    [string]$MinimumPwshVersion = '7.0',

    [Parameter()]
    [string]$ProGetBaseUrl,

    [Parameter()]
    [string]$BuildMasterBaseUrl,

    [Parameter()]
    [ValidateRange(1, 60)]
    [int]$ReachabilityTimeoutSeconds = 5,

    [Parameter()]
    [switch]$ThrowOnFailure,

    [Parameter()]
    [switch]$SkipLockFileGuard
  )

  begin {
    $fn = 'Test-SprintPrerequisites'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    # Load helper functions. Fallback for running this file from source without
    # importing the module; a normal Import-Module already dot-sources the private
    # helper. Kept inside BEGIN so loading/dot-sourcing this file only DEFINES the
    # function and never executes anything at load time.
    if (-not (Get-Command -Name 'Invoke-BitwardenCliWithCleanTlsEnvironment' -ErrorAction SilentlyContinue)) {
      $bitwardenTlsHelperPath = Join-Path -Path $PSScriptRoot -ChildPath '..\private\Invoke-BitwardenCliWithCleanTlsEnvironment.ps1'
      if (Test-Path -LiteralPath $bitwardenTlsHelperPath -PathType Leaf) {
        . $bitwardenTlsHelperPath
      }
    }
  }

  process {
    $checks = [ordered]@{}
    $failures = [System.Collections.Generic.List[string]]::new()

    $required = [Version]$MinimumPwshVersion
    $actual = $PSVersionTable.PSVersion
    $ok = ($actual -ge $required)
    $checks['PwshVersion'] = [PSCustomObject]@{
      Ok       = $ok
      Detail   = if ($ok) { "pwsh $actual satisfies required >= $required" } else { "pwsh $actual is below required $required" }
      Required = $required.ToString()
      Actual   = $actual.ToString()
    }
    if (-not $ok) { [void]$failures.Add('PwshVersion') }

    $ghOk = $false
    $ghDetail = ''
    try {
      $ghCmd = Get-Command -Name gh -CommandType Application -ErrorAction Stop
      $null = & $ghCmd auth status 2>&1
      if ($LASTEXITCODE -eq 0) {
        $ghOk = $true
        $ghDetail = 'gh auth status: authenticated'
      } else {
        $ghDetail = "gh auth status returned exit code $LASTEXITCODE"
      }
    } catch {
      $ghDetail = "gh CLI not found or invocation failed: $($_.Exception.Message)"
    }
    $checks['GhAuth'] = [PSCustomObject]@{ Ok = $ghOk; Detail = $ghDetail }
    if (-not $ghOk) { [void]$failures.Add('GhAuth') }

    $bwOk = $false
    $bwSessionPresent = -not [string]::IsNullOrWhiteSpace($env:BW_SESSION)
    $bwDetail = ''
    try {
      $bwCmd = Get-Command -Name bw -CommandType Application -ErrorAction Stop
      $statusJson = Invoke-BitwardenCliWithCleanTlsEnvironment -FunctionName 'Test-SprintPrerequisites' {
        & $bwCmd status 2>$null
      }
      if ($LASTEXITCODE -eq 0 -and $statusJson) {
        try {
          $status = ($statusJson | ConvertFrom-Json).status
          if ($status -eq 'unlocked') {
            $bwOk = $true
            $bwDetail = 'bw status: unlocked'
          } else {
            $bwDetail = "bw status: '$status' (need 'unlocked')"
          }
        } catch {
          $bwDetail = "Failed to parse bw status JSON: $($_.Exception.Message)"
        }
      } else {
        $bwDetail = "bw status returned exit code $LASTEXITCODE"
      }
    } catch {
      $bwDetail = "bw CLI not found or invocation failed: $($_.Exception.Message)"
    }
    $checks['Bitwarden'] = [PSCustomObject]@{
      Ok             = $bwOk
      Detail         = $bwDetail
      SessionPresent = $bwSessionPresent
    }
    if (-not $bwOk) { [void]$failures.Add('Bitwarden') }

    $resolvedRepos = @()
    if ($PSBoundParameters.ContainsKey('RequiredRepoWorktrees')) {
      $resolvedRepos = @($RequiredRepoWorktrees)
    } else {
      try {
        $here = (Get-Location).Path
        $parent = Split-Path $here -Parent
        $resolvedRepos = @(Get-ChildItem -Path $parent -Directory -Filter '*-wt-*-Sprint-*-work-items' -ErrorAction SilentlyContinue |
          Select-Object -ExpandProperty FullName)
      } catch {
        $resolvedRepos = @()
      }
    }

    $perRepo = @()
    $gitOk = $true
    foreach ($repoPath in $resolvedRepos) {
      $r = [PSCustomObject]@{
        Path       = $repoPath
        Ok         = $false
        Detail     = ''
        InProgress = $null
      }
      try {
        if (-not (Test-Path $repoPath -PathType Container)) {
          $r.Detail = 'Path does not exist'
        } else {
          $gitDir = Join-Path $repoPath '.git'
          $realGitDir = $null
          if (Test-Path $gitDir -PathType Container) {
            $realGitDir = $gitDir
          } elseif (Test-Path $gitDir -PathType Leaf) {
            $line = (Get-Content -LiteralPath $gitDir -ErrorAction Stop | Select-Object -First 1).Trim()
            if ($line -match '^gitdir:\s*(.+)$') {
              $candidate = $Matches[1].Trim()
              if (-not [System.IO.Path]::IsPathRooted($candidate)) {
                $candidate = Join-Path $repoPath $candidate
              }
              $resolved = Resolve-Path -LiteralPath $candidate -ErrorAction SilentlyContinue
              if ($resolved) { $realGitDir = $resolved.Path }
            }
          }
          if (-not $realGitDir) {
            $r.Detail = "Could not locate .git directory for $repoPath"
          } else {
            $markers = @(
              'MERGE_HEAD'
              'REBASE_HEAD'
              'CHERRY_PICK_HEAD'
              'REVERT_HEAD'
              'BISECT_LOG'
              'rebase-apply'
              'rebase-merge'
            )
            $present = foreach ($m in $markers) {
              if (Test-Path (Join-Path $realGitDir $m)) { $m }
            }
            if ($present) {
              $r.InProgress = @($present)
              $r.Detail = "In-progress git operation(s): $($present -join ', ')"
            } else {
              $r.Ok = $true
              $r.Detail = 'No in-progress merge/rebase/cherry-pick'
            }
          }
        }
      } catch {
        $r.Detail = "Inspection failed: $($_.Exception.Message)"
      }
      if (-not $r.Ok) { $gitOk = $false }
      $perRepo += $r
    }
    $repoCount = $resolvedRepos.Count
    $checks['GitRepoState'] = [PSCustomObject]@{
      Ok      = $gitOk
      Detail  = if ($gitOk) {
        if ($repoCount -eq 0) { 'No sprint worktrees found to inspect' } else { "$repoCount worktree(s) clean of in-progress git operations" }
      } else { 'One or more worktrees have in-progress git operations' }
      PerRepo = $perRepo
    }
    if (-not $gitOk) { [void]$failures.Add('GitRepoState') }

    if ($SkipLockFileGuard) {
      $checks['LockFilesClean'] = [PSCustomObject]@{
        Ok      = $true
        Skipped = $true
        Detail  = 'Assert-LockFilesClean skipped by explicit caller request'
        PerRepo = @()
      }
    } else {
      $lockPerRepo = @()
      $lockOk = $true
      foreach ($repoPath in $resolvedRepos) {
        $entry = [PSCustomObject]@{
          Path                    = $repoPath
          Ok                      = $false
          Detail                  = ''
          DirtyLockFiles          = @()
          MissingTrackedLockFiles = @()
          Failures                = @()
        }
        try {
          if (-not (Test-Path $repoPath -PathType Container)) {
            $entry.Detail = 'Path does not exist'
          } else {
            $lockResult = Assert-LockFilesClean -RepoPath $repoPath
            $entry.Ok = [bool]$lockResult.AllOk
            $entry.Detail = if ($entry.Ok) { 'Lock files clean' } else { "Lock-file guard failed: $($lockResult.Failures -join ', ')" }
            $entry.DirtyLockFiles = @($lockResult.Checks.GitStatus.DirtyLockFiles)
            $entry.MissingTrackedLockFiles = @($lockResult.Checks.GitStatus.MissingTrackedLockFiles)
            $entry.Failures = @($lockResult.Failures)
          }
        } catch {
          $entry.Detail = "Lock-file inspection failed: $($_.Exception.Message)"
        }
        if (-not $entry.Ok) { $lockOk = $false }
        $lockPerRepo += $entry
      }

      $checks['LockFilesClean'] = [PSCustomObject]@{
        Ok      = $lockOk
        Skipped = $false
        Detail  = if ($lockOk) {
          if ($resolvedRepos.Count -eq 0) { 'No sprint worktrees found to inspect' } else { "$($resolvedRepos.Count) worktree(s) have clean lock files" }
        } else { 'One or more worktrees have dirty or missing packages.lock.json files' }
        PerRepo = $lockPerRepo
      }
      if (-not $lockOk) { [void]$failures.Add('LockFilesClean') }
    }

    $btOk = $false
    $btDetail = ''
    $btVersion = $null
    try {
      $existing = Get-Module -Name 'ATAP.Utilities.BuildTooling.PowerShell' -ErrorAction SilentlyContinue
      if ($existing) {
        $btOk = $true
        $btVersion = $existing.Version.ToString()
        $btDetail = "Already imported (version $btVersion)"
      } else {
        $available = Get-Module -Name 'ATAP.Utilities.BuildTooling.PowerShell' -ListAvailable -ErrorAction SilentlyContinue |
          Select-Object -First 1
        if ($available) {
          $btOk = $true
          $btVersion = $available.Version.ToString()
          $btDetail = "Module available for import (version $btVersion)"
        } else {
          $btDetail = 'ATAP.Utilities.BuildTooling.PowerShell not found in PSModulePath'
        }
      }
    } catch {
      $btDetail = "Module discovery failed: $($_.Exception.Message)"
    }
    $checks['BuildToolingImport'] = [PSCustomObject]@{
      Ok      = $btOk
      Detail  = $btDetail
      Version = $btVersion
    }
    if (-not $btOk) { [void]$failures.Add('BuildToolingImport') }

    if (-not $PSBoundParameters.ContainsKey('ProGetBaseUrl')) {
      try {
        if ($global:configRootKeys -and $global:settings) {
          $k = $global:configRootKeys['ProGetBaseUrlConfigRootKey']
          if ($k -and $global:settings.ContainsKey($k)) {
            $ProGetBaseUrl = [string]$global:settings[$k]
          }
        }
      } catch { }
    }
    if (-not $PSBoundParameters.ContainsKey('BuildMasterBaseUrl')) {
      try {
        if ($global:configRootKeys -and $global:settings) {
          $k = $global:configRootKeys['BuildMasterBaseUrlConfigRootKey']
          if ($k -and $global:settings.ContainsKey($k)) {
            $BuildMasterBaseUrl = [string]$global:settings[$k]
          }
        }
      } catch { }
    }

    $checks['ProGetReachable'] = Test-SprintUrlReachable -Url $ProGetBaseUrl -TimeoutSeconds $ReachabilityTimeoutSeconds -Label 'ProGet'
    if (-not $checks['ProGetReachable'].Ok) { [void]$failures.Add('ProGetReachable') }

    $checks['BuildMasterReachable'] = Test-SprintUrlReachable -Url $BuildMasterBaseUrl -TimeoutSeconds $ReachabilityTimeoutSeconds -Label 'BuildMaster'
    if (-not $checks['BuildMasterReachable'].Ok) { [void]$failures.Add('BuildMasterReachable') }

    $result = [PSCustomObject]@{
      AllOk     = ($failures.Count -eq 0)
      Checks    = [PSCustomObject]$checks
      Failures  = $failures.ToArray()
      Timestamp = (Get-Date)
    }

    if ($ThrowOnFailure -and -not $result.AllOk) {
      $msg = "Sprint prerequisites not satisfied. Failing checks: $($result.Failures -join ', ')"
      $exception = [System.InvalidOperationException]::new($msg)
      $errorRecord = [System.Management.Automation.ErrorRecord]::new(
        $exception,
        'SprintPrerequisitesFailedException',
        [System.Management.Automation.ErrorCategory]::PermissionDenied,
        $result
      )
      $PSCmdlet.ThrowTerminatingError($errorRecord)
    }

    return $result
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
