#Requires -Version 7.0

function Assert-LockFilesClean {
  <#
.SYNOPSIS
    Verifies that NuGet lock files are not dirty or missing.

.DESCRIPTION
    Checks a git worktree for `packages.lock.json` drift before commit, PR,
    sprint-start, or sprint-end automation proceeds. The default check inspects
    git status and fails when a lock file is modified, staged, untracked,
    renamed, or deleted.

    When -CheckSolutionFilter is supplied, the cmdlet also reads a .slnf file
    and verifies that every included project has a sibling `packages.lock.json`,
    except for paths listed in -AllowedMissingLockFileProjectPaths.

    The cmdlet returns a structured result by default. Use -ThrowOnFailure for
    fail-fast automation.

.PARAMETER RepoPath
    Path to the git working tree. Defaults to the current directory.

.PARAMETER SolutionFilterPath
    Optional solution filter path used with -CheckSolutionFilter. Relative paths
    are resolved from RepoPath.

.PARAMETER CheckSolutionFilter
    Enables project-to-lock-file validation using SolutionFilterPath.

.PARAMETER ExcludedPathPatterns
    Relative path wildcard patterns to ignore. Defaults to `samples/**`.

.PARAMETER AllowedMissingLockFileProjectPaths
    Project paths allowed to omit `packages.lock.json`, such as documented
    facade/aggregator projects that do not produce a lock file after restore.

.PARAMETER ThrowOnFailure
    Throw a terminating error when lock files are dirty or missing.

.OUTPUTS
    PSCustomObject with AllOk [bool], Checks [PSCustomObject], Failures
    [string[]], and Timestamp [DateTime].

.EXAMPLE
    Assert-LockFilesClean -ThrowOnFailure

.EXAMPLE
    Assert-LockFilesClean -CheckSolutionFilter `
      -SolutionFilterPath .\ATAP.Utilities.Production.slnf `
      -AllowedMissingLockFileProjectPaths @(
        'src/ATAP.Utilities.ComputerInventory/ATAP.Utilities.ComputerInventory.csproj'
      )

.NOTES
    AI assisted using Powershell.instructions.md as guidelines.
  #>
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$RepoPath = (Get-Location).Path,

    [Parameter()]
    [AllowEmptyString()]
    [string]$SolutionFilterPath = '',

    [Parameter()]
    [switch]$CheckSolutionFilter,

    [Parameter()]
    [string[]]$ExcludedPathPatterns = @('samples/**'),

    [Parameter()]
    [string[]]$AllowedMissingLockFileProjectPaths = @(),

    [Parameter()]
    [switch]$ThrowOnFailure
  )

  begin {
    $fn = 'Assert-LockFilesClean'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    function ConvertTo-LockGuardRelativePath {
      param(
        [Parameter(Mandatory)]
        [string]$Path
      )

      return ($Path -replace '\\', '/').TrimStart('./')
    }

    function Test-LockGuardPathExcluded {
      param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter()]
        [string[]]$Patterns = @()
      )

      $relative = ConvertTo-LockGuardRelativePath -Path $Path
      foreach ($pattern in $Patterns) {
        $normalizedPattern = ConvertTo-LockGuardRelativePath -Path $pattern
        if ($relative -like $normalizedPattern) {
          return $true
        }
      }
      return $false
    }

    function ConvertFrom-GitPorcelainLockStatus {
      param(
        [Parameter(Mandatory)]
        [string[]]$StatusLines
      )

      foreach ($line in $StatusLines) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line.Length -lt 4) {
          continue
        }

        $code = $line.Substring(0, 2)
        $pathPart = $line.Substring(3).Trim()
        if ($pathPart -match ' -> ') {
          $pathPart = ($pathPart -split ' -> ')[-1]
        }
        $pathPart = $pathPart.Trim('"')
        $relative = ConvertTo-LockGuardRelativePath -Path $pathPart

        if ($relative -ne 'packages.lock.json' -and -not $relative.EndsWith('/packages.lock.json', [System.StringComparison]::OrdinalIgnoreCase)) {
          continue
        }

        [PSCustomObject]@{
          Status = $code
          Path   = $relative
          Missing = $code.Contains('D')
        }
      }
    }
  }

  process {
    $checks = [ordered]@{}
    $failures = [System.Collections.Generic.List[string]]::new()

    try {
      Assert-GitAvailable

      $resolvedRepo = (Resolve-Path -LiteralPath $RepoPath -ErrorAction Stop).Path
      $repoRoot = (& git -C $resolvedRepo rev-parse --show-toplevel 2>&1)
      if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($repoRoot)) {
        throw "RepoPath '$RepoPath' is not inside a git worktree. $repoRoot"
      }
      $repoRoot = [string]$repoRoot.Trim()

      $statusLines = @(& git -C $repoRoot status --porcelain=v1 --untracked-files=all 2>&1)
      if ($LASTEXITCODE -ne 0) {
        throw "git status failed for '$repoRoot'. $($statusLines -join [Environment]::NewLine)"
      }

      $lockStatuses = @()
      if ($statusLines.Count -gt 0) {
        $lockStatuses = @(ConvertFrom-GitPorcelainLockStatus -StatusLines $statusLines |
          Where-Object { -not (Test-LockGuardPathExcluded -Path $_.Path -Patterns $ExcludedPathPatterns) })
      }

      $dirtyLockFiles = @($lockStatuses | Where-Object { -not $_.Missing } | Select-Object -ExpandProperty Path)
      $missingTrackedLockFiles = @($lockStatuses | Where-Object { $_.Missing } | Select-Object -ExpandProperty Path)

      $gitStatusOk = ($dirtyLockFiles.Count -eq 0 -and $missingTrackedLockFiles.Count -eq 0)
      $checks['GitStatus'] = [PSCustomObject]@{
        Ok                    = $gitStatusOk
        Detail                = if ($gitStatusOk) { 'No dirty or deleted packages.lock.json files in git status' } else { 'Dirty or deleted packages.lock.json files detected in git status' }
        DirtyLockFiles        = $dirtyLockFiles
        MissingTrackedLockFiles = $missingTrackedLockFiles
      }
      if (-not $gitStatusOk) { [void]$failures.Add('GitStatus') }

      if ($CheckSolutionFilter) {
        $solutionPathToUse = $SolutionFilterPath
        if ([string]::IsNullOrWhiteSpace($solutionPathToUse)) {
          $candidate = Join-Path -Path $repoRoot -ChildPath 'ATAP.Utilities.Production.slnf'
          if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            $solutionPathToUse = $candidate
          }
        }

        if ([string]::IsNullOrWhiteSpace($solutionPathToUse)) {
          $checks['SolutionFilter'] = [PSCustomObject]@{
            Ok       = $false
            Skipped  = $false
            Detail   = 'CheckSolutionFilter was supplied but no SolutionFilterPath was provided or auto-detected'
            MissingLockFiles = @()
          }
          [void]$failures.Add('SolutionFilter')
        } else {
          if (-not [System.IO.Path]::IsPathRooted($solutionPathToUse)) {
            $solutionPathToUse = Join-Path -Path $repoRoot -ChildPath $solutionPathToUse
          }
          $resolvedSolutionFilter = (Resolve-Path -LiteralPath $solutionPathToUse -ErrorAction Stop).Path
          $solutionJson = Get-Content -LiteralPath $resolvedSolutionFilter -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
          $projectPaths = @($solutionJson.solution.projects)
          $allowed = @($AllowedMissingLockFileProjectPaths | ForEach-Object { ConvertTo-LockGuardRelativePath -Path $_ })

          $missingProjectLocks = foreach ($projectPath in $projectPaths) {
            $relativeProjectPath = ConvertTo-LockGuardRelativePath -Path ([string]$projectPath)
            if (Test-LockGuardPathExcluded -Path $relativeProjectPath -Patterns $ExcludedPathPatterns) {
              continue
            }
            if ($relativeProjectPath -in $allowed) {
              continue
            }

            $absoluteProjectPath = Join-Path -Path $repoRoot -ChildPath $relativeProjectPath
            $lockPath = Join-Path -Path (Split-Path -Path $absoluteProjectPath -Parent) -ChildPath 'packages.lock.json'
            if (-not (Test-Path -LiteralPath $lockPath -PathType Leaf)) {
              [PSCustomObject]@{
                ProjectPath = $relativeProjectPath
                LockFilePath = ConvertTo-LockGuardRelativePath -Path ((Join-Path -Path (Split-Path -Path $relativeProjectPath -Parent) -ChildPath 'packages.lock.json'))
              }
            }
          }

          $missingProjectLocks = @($missingProjectLocks)
          $solutionOk = ($missingProjectLocks.Count -eq 0)
          $checks['SolutionFilter'] = [PSCustomObject]@{
            Ok                 = $solutionOk
            Skipped            = $false
            Detail             = if ($solutionOk) { "Every non-excluded project in '$resolvedSolutionFilter' has a packages.lock.json or an explicit exception" } else { "One or more projects in '$resolvedSolutionFilter' are missing packages.lock.json" }
            SolutionFilterPath = $resolvedSolutionFilter
            MissingLockFiles   = $missingProjectLocks
            AllowedMissingLockFileProjectPaths = $allowed
          }
          if (-not $solutionOk) { [void]$failures.Add('SolutionFilter') }
        }
      } else {
        $checks['SolutionFilter'] = [PSCustomObject]@{
          Ok       = $true
          Skipped  = $true
          Detail   = 'Solution filter lock-file existence check skipped; pass -CheckSolutionFilter to enable it'
          MissingLockFiles = @()
        }
      }

      $result = [PSCustomObject]@{
        AllOk     = ($failures.Count -eq 0)
        RepoPath   = $repoRoot
        Checks    = [PSCustomObject]$checks
        Failures  = $failures.ToArray()
        Timestamp = (Get-Date)
      }

      if ($ThrowOnFailure -and -not $result.AllOk) {
        $msg = "Lock files are not clean. Failing checks: $($result.Failures -join ', ')"
        $exception = [System.InvalidOperationException]::new($msg)
        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
          $exception,
          'LockFilesNotCleanException',
          [System.Management.Automation.ErrorCategory]::InvalidData,
          $result
        )
        $PSCmdlet.ThrowTerminatingError($errorRecord)
      }

      return $result
    } catch {
      if ($_.FullyQualifiedErrorId -eq 'LockFilesNotCleanException') {
        throw
      }

      $msg = "Assert-LockFilesClean failed: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
