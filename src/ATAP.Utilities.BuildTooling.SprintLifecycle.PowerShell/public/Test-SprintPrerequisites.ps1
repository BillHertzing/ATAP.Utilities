#Requires -Version 7.0

# Private helpers Test-SprintUrlReachable and Test-SprintModulePromotionDeploy
# now live in their own files under private/ (SC-0178: one eponymous Verb-Noun
# function per file). They autoload with the module alongside this function.

function Test-SprintPrerequisites {
  <#
.SYNOPSIS
    Verifies that SprintStartAgent or SprintEndAgent preconditions are satisfied.

.DESCRIPTION
    Runs a read-only preflight covering: pwsh engine version, gh CLI auth,
    Bitwarden Secrets Manager readiness (bws CLI on PATH plus an authenticated
    CommonCIForBitwardenReadOnly machine access token — BW_SESSION is personal-vault-only and is NOT
    required, per SC-0175), git working state of each required sprint worktree
    (no in-progress merge/rebase/cherry-pick/revert/bisect), BuildTooling module
    importability, self-bootstrap of the ATAP ConfigRootKeys/host-settings
    globals, existing per-developer SQL Server instances, HEAD
    reachability of the ProGet and BuildMaster base URLs, and — when the sprint
    declared newly built modules via -BuiltModule (Task 9.7) — that each built
    module's Production version is both in the *-stable ProGet feed AND installed
    on this workstation. Each discovered worktree is also checked with
    Assert-LockFilesClean unless -SkipLockFileGuard is supplied.

    Worktree git-state and lock-file checks run only when -RequiredRepoWorktrees
    is supplied. This keeps SprintStart Step 0 from failing on unrelated sibling
    worktrees while still supporting explicit multi-worktree gates.

    Every check runs to completion regardless of earlier failures so the
    structured result captures the full diagnostic picture. The cmdlet always
    returns a [PSCustomObject]; with -ThrowOnFailure, it additionally throws a
    terminating error (FullyQualifiedErrorId: SprintPrerequisitesFailedException)
    when AllOk is $false.

.PARAMETER RequiredRepoWorktrees
    Paths of git working trees to inspect. When omitted, the git-state and
    lock-file checks are recorded as skipped/Ok.

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

.PARAMETER DeveloperNames
    Developer names used to derive the expected SQL Server named instances:
    Dev<developer> and Exp<developer>. Defaults to $env:USERNAME.

.PARAMETER SqlServerInstanceNames
    Explicit SQL Server named-instance names to preflight. Overrides
    DeveloperNames-derived instance names.

.PARAMETER ReachabilityTimeoutSeconds
    HTTP timeout for the two reachability checks. Default 5.

.PARAMETER ThrowOnFailure
    If supplied, throw a terminating error when AllOk is $false.

.PARAMETER SkipLockFileGuard
    Explicitly bypasses Assert-LockFilesClean for sprint-start/sprint-end
    preflight. Use only when lock-file drift has been separately reviewed and
    the reason is recorded in sprint notes.

.PARAMETER SkipSqlServerInstanceCheck
    Explicitly bypasses the Dev<user>/Exp<user> SQL Server service preflight.
    Use only for tests or when SQL instance readiness has been separately
    verified and recorded.

.PARAMETER BuiltModule
    (Task 9.7) Zero or more modules the sprint built new versions of, each as a
    hashtable or PSCustomObject with Name and Version keys, e.g.
    @{ Name = 'ATAP.Utilities.Powershell'; Version = '0.1.4' }. For each entry
    the ModulePromotionDeploy check asserts the version is BOTH (a) in the
    *-stable ProGet feed AND (b) installed on this workstation, so the
    SprintEnd->SprintStart handoff resolves the latest Production module. When no
    BuiltModule is supplied the check is recorded as Skipped (Ok=$true).

.PARAMETER SkipModulePromotionDeployCheck
    Explicitly bypasses the Task 9.7 built-module promotion+deploy gate even when
    -BuiltModule entries are supplied. Use only for tests or when promotion and
    deployment have been separately verified and recorded.

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
    [string[]]$DeveloperNames,

    [Parameter()]
    [string[]]$SqlServerInstanceNames,

    [Parameter()]
    [ValidateRange(1, 60)]
    [int]$ReachabilityTimeoutSeconds = 5,

    [Parameter()]
    [switch]$ThrowOnFailure,

    [Parameter()]
    [switch]$SkipLockFileGuard,

    [Parameter()]
    [switch]$SkipSqlServerInstanceCheck,

    [Parameter()]
    [object[]]$BuiltModule,

    [Parameter()]
    [switch]$SkipModulePromotionDeployCheck
  )

  begin {
    $fn = 'Test-SprintPrerequisites'
    $mn = 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    # Autoload-or-throw contract (PlanFixSprintStart FSS-12). The BuildTooling
    # module is CI-built and installed, so every command this preflight relies on
    # must resolve by module autoload. A missing command is an environment fault
    # the user must repair — never a silent dot-source fallback from a worktree.
    foreach ($required in @(
        'Get-BWSAccessToken',
        'Assert-LockFilesClean',
        'Initialize-ATAPConfigurationGlobals',
        'Get-PVal',
        'Test-SprintUrlReachable',
        'Test-SprintModulePromotionDeploy')) {
      if (-not (Get-Command -Name $required -ErrorAction SilentlyContinue)) {
        throw "Required command '$required' is not available. The " +
        'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell module must be installed and ' +
        'autoloadable. Repair the module install before retrying sprint prerequisites.'
      }
    }
  }

  process {
    $checks = [ordered]@{}
    $failures = [System.Collections.Generic.List[string]]::new()

    # Task 10.5: repair agent shells that did not inherit the machine/user
    # profile globals before any settings-backed check runs.
    try {
      $configurationResult = Initialize-ATAPConfigurationGlobals -Confirm:$false
      $checks['ConfigurationGlobals'] = [PSCustomObject]@{
        Ok                  = $true
        Detail              = if ($configurationResult.Initialized) {
          'ATAP configuration globals were initialized for this process'
        } else {
          'ATAP configuration globals were already ready'
        }
        Initialized         = [bool]$configurationResult.Initialized
        ConfigRootKeysCount = $configurationResult.ConfigRootKeysCount
        SettingsCount       = $configurationResult.SettingsCount
      }
    } catch {
      $checks['ConfigurationGlobals'] = [PSCustomObject]@{
        Ok                  = $false
        Detail              = "ATAP configuration bootstrap failed: $($_.Exception.Message)"
        Initialized         = $false
        ConfigRootKeysCount = 0
        SettingsCount       = 0
      }
      [void]$failures.Add('ConfigurationGlobals')
    }

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

    # Bitwarden Secrets Manager readiness (SC-0175): sprint automation uses the
    # bws CLI with the CommonCIForBitwardenReadOnly machine access token; BW_SESSION is personal-vault-only
    # and is deliberately NOT required here.
    $bwOk = $false
    $bwsTokenPresent = $false
    $bwDetail = ''
    $bwsTokenWasSetHere = $false
    try {
      $null = Get-Command -Name bws -CommandType Application -ErrorAction Stop
      if (-not [string]::IsNullOrWhiteSpace($env:BWS_ACCESS_TOKEN)) {
        $bwsTokenPresent = $true
      } else {
        try {
          $cred = Get-BWSAccessToken -TokenPurpose ReadOnly -ErrorAction Stop
          $env:BWS_ACCESS_TOKEN = $cred.GetNetworkCredential().Password
          $bwsTokenWasSetHere = $true
          $bwsTokenPresent = -not [string]::IsNullOrWhiteSpace($env:BWS_ACCESS_TOKEN)
        } catch {
          $bwDetail = "BWS access token not resolvable (env or CommonCIForBitwardenReadOnly DPAPI file): $($_.Exception.Message)"
        }
      }
      if ($bwsTokenPresent) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Calling bws project list' -Tag 'BWSCall'
        $null = & bws project list --output json --color no 2>&1
        if ($LASTEXITCODE -eq 0) {
          $bwOk = $true
          $bwDetail = 'bws CLI present; CommonCIForBitwardenReadOnly machine access token authenticated (bws project list succeeded)'
        } else {
          $bwDetail = "bws project list returned exit code $LASTEXITCODE (token invalid, revoked, or network failure)"
        }
      }
    } catch {
      $bwDetail = "bws CLI not found or invocation failed: $($_.Exception.Message)"
    } finally {
      if ($bwsTokenWasSetHere) { Remove-Item Env:BWS_ACCESS_TOKEN -ErrorAction SilentlyContinue }
    }
    $checks['Bitwarden'] = [PSCustomObject]@{
      Ok           = $bwOk
      Detail       = $bwDetail
      TokenPresent = $bwsTokenPresent
    }
    if (-not $bwOk) { [void]$failures.Add('Bitwarden') }

    $worktreeChecksRequested = $PSBoundParameters.ContainsKey('RequiredRepoWorktrees')
    $resolvedRepos = if ($worktreeChecksRequested) { @($RequiredRepoWorktrees) } else { @() }

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
      Skipped = -not $worktreeChecksRequested
      Detail  = if (-not $worktreeChecksRequested) {
        'Git worktree state check skipped because -RequiredRepoWorktrees was not supplied'
      } elseif ($gitOk) {
        if ($repoCount -eq 0) { 'No requested worktrees to inspect' } else { "$repoCount worktree(s) clean of in-progress git operations" }
      } else { 'One or more worktrees have in-progress git operations' }
      PerRepo = $perRepo
    }
    if (-not $gitOk) { [void]$failures.Add('GitRepoState') }

    if (-not $worktreeChecksRequested) {
      $checks['LockFilesClean'] = [PSCustomObject]@{
        Ok      = $true
        Skipped = $true
        Detail  = 'Lock-file check skipped because -RequiredRepoWorktrees was not supplied'
        PerRepo = @()
      }
    } elseif ($SkipLockFileGuard) {
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

    if ($SkipSqlServerInstanceCheck) {
      $checks['SqlServerInstances'] = [PSCustomObject]@{
        Ok          = $true
        Skipped     = $true
        Detail      = 'SQL Server instance preflight skipped by explicit caller request'
        PerInstance = @()
      }
    } else {
      if (-not $PSBoundParameters.ContainsKey('SqlServerInstanceNames') -or
        $null -eq $SqlServerInstanceNames -or
        $SqlServerInstanceNames.Count -eq 0) {
        if (-not $PSBoundParameters.ContainsKey('DeveloperNames') -or
          $null -eq $DeveloperNames -or
          $DeveloperNames.Count -eq 0) {
          $DeveloperNames = @($env:USERNAME)
        }

        $resolvedSqlInstances = [System.Collections.Generic.List[string]]::new()
        foreach ($developer in ($DeveloperNames | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)) {
          [void]$resolvedSqlInstances.Add("Dev$developer")
          [void]$resolvedSqlInstances.Add("Exp$developer")
        }
        $SqlServerInstanceNames = $resolvedSqlInstances.ToArray()
      }

      $sqlInstanceResults = @()
      $sqlInstancesOk = $true
      foreach ($instanceName in ($SqlServerInstanceNames | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)) {
        $serviceName = "MSSQL`$$instanceName"
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        $instanceOk = $null -ne $service
        if (-not $instanceOk) { $sqlInstancesOk = $false }
        $sqlInstanceResults += [PSCustomObject]@{
          InstanceName = $instanceName
          ServiceName  = $serviceName
          Ok           = $instanceOk
          Detail       = if ($instanceOk) {
            "SQL Server instance service '$serviceName' exists"
          } else {
            "SQL Server instance service '$serviceName' not found; run developer onboarding SQL Server instance setup"
          }
        }
      }

      if ($sqlInstanceResults.Count -eq 0) {
        $sqlInstancesOk = $false
      }

      $checks['SqlServerInstances'] = [PSCustomObject]@{
        Ok          = $sqlInstancesOk
        Skipped     = $false
        Detail      = if ($sqlInstancesOk) {
          "$($sqlInstanceResults.Count) SQL Server instance service(s) found"
        } elseif ($sqlInstanceResults.Count -eq 0) {
          'No SQL Server instance names were supplied or derived'
        } else {
          'One or more required SQL Server instance services are missing'
        }
        PerInstance = $sqlInstanceResults
      }
      if (-not $sqlInstancesOk) { [void]$failures.Add('SqlServerInstances') }
    }

    $btOk = $false
    $btDetail = ''
    $btVersion = $null
    try {
      $existing = Get-Module -Name 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell' -ErrorAction SilentlyContinue
      if ($existing) {
        $btOk = $true
        $btVersion = $existing.Version.ToString()
        $btDetail = "Already imported (version $btVersion)"
      } else {
        $available = Get-Module -Name 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell' -ListAvailable -ErrorAction SilentlyContinue |
          Select-Object -First 1
        if ($available) {
          $btOk = $true
          $btVersion = $available.Version.ToString()
          $btDetail = "Module available for import (version $btVersion)"
        } else {
          $btDetail = 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell not found in PSModulePath'
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

    $integrityOk = $true
    $integrityDetail = ''
    $sourceVersion = $null
    $sourcePath = $null

    if (-not $btOk) {
      $integrityOk = $false
      $integrityDetail = 'BuildTooling module is not imported or available; cannot verify version integrity.'
    } else {
      # 1. Try to find the ATAP.Utilities repository root from $RequiredRepoWorktrees
      if ($RequiredRepoWorktrees) {
        foreach ($wt in $RequiredRepoWorktrees) {
          if ($wt) {
            $leaf = Split-Path -Path $wt -Leaf
            if ($leaf -eq 'ATAP.Utilities' -or $leaf -like 'ATAP.Utilities-wt-*') {
              $candidatePath = Join-Path $wt 'src\ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell\version.json'
              if (Test-Path -LiteralPath $candidatePath -PathType Leaf) {
                $sourcePath = $candidatePath
                break
              }
            }
          }
        }
      }

      # 2. Fallback to finding it relative to current repository root
      if (-not $sourcePath) {
        try {
          if (Get-Command -Name 'Get-RepositoryRoot' -CommandType Function -ErrorAction SilentlyContinue) {
            $localRoot = Get-RepositoryRoot -ErrorAction SilentlyContinue
            if ($localRoot) {
              $localRootFull = [IO.Path]::GetFullPath($localRoot)
              $candidatePath = Join-Path $localRootFull 'src\ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell\version.json'
              if (Test-Path -LiteralPath $candidatePath -PathType Leaf) {
                $sourcePath = $candidatePath
              }
            }
          }
        } catch { }
      }

      # 3. Fallback to parent directory discovery
      if (-not $sourcePath) {
        $parentDir = 'C:\Dropbox\whertzing\GitHub'
        if (Test-Path -LiteralPath $parentDir -PathType Container) {
          $siblingDirs = Get-ChildItem -LiteralPath $parentDir -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -eq 'ATAP.Utilities' -or $_.Name -like 'ATAP.Utilities-wt-*' }
          foreach ($sibling in $siblingDirs) {
            $candidatePath = Join-Path $sibling.FullName 'src\ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell\version.json'
            if (Test-Path -LiteralPath $candidatePath -PathType Leaf) {
              $sourcePath = $candidatePath
              break
            }
          }
        }
      }

      if ($sourcePath) {
        try {
          $json = Get-Content -Raw -LiteralPath $sourcePath -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
          if ($json.version) {
            $sourceVersion = $json.version
            if ($btVersion -eq $sourceVersion) {
              $integrityDetail = "Active module version ($btVersion) matches source version at ${sourcePath}"
            } else {
              $integrityOk = $false
              $integrityDetail = "Version mismatch: source version is $sourceVersion (at ${sourcePath}) but imported/available module version is $btVersion. Run a build/rebuild/promote/install session."
            }
          } else {
            $integrityDetail = "version.json at ${sourcePath} does not contain a 'version' key."
          }
        } catch {
          $integrityDetail = "Failed to parse version.json at ${sourcePath}: $($_.Exception.Message)"
        }
      } else {
        $integrityDetail = 'Could not locate ATAP.Utilities version.json; skipping source-vs-published integrity check.'
      }
    }

    $checks['BuildToolingVersionIntegrity'] = [PSCustomObject]@{
      Ok            = $integrityOk
      Detail        = $integrityDetail
      SourceVersion = $sourceVersion
      ActiveVersion = $btVersion
    }
    if (-not $integrityOk) { [void]$failures.Add('BuildToolingVersionIntegrity') }


    if (-not $PSBoundParameters.ContainsKey('ProGetBaseUrl')) {
      try {
        $proGetKey = if ($global:configRootKeys -and $global:configRootKeys['ProGetBaseUrlConfigRootKey']) {
          $global:configRootKeys['ProGetBaseUrlConfigRootKey']
        } else {
          'ProGetBaseUrl'
        }
        $ProGetBaseUrl = [string](Get-PVal -ParameterName 'ProGetBaseUrl' -originalPSBoundParameters $PSBoundParameters -dottedPath $proGetKey -DefaultValue $ProGetBaseUrl -AllowMissing)
      } catch { }
    }
    if (-not $PSBoundParameters.ContainsKey('BuildMasterBaseUrl')) {
      try {
        $buildMasterKey = if ($global:configRootKeys -and $global:configRootKeys['BuildMasterBaseUrlConfigRootKey']) {
          $global:configRootKeys['BuildMasterBaseUrlConfigRootKey']
        } else {
          'BuildMasterBaseUrl'
        }
        $BuildMasterBaseUrl = [string](Get-PVal -ParameterName 'BuildMasterBaseUrl' -originalPSBoundParameters $PSBoundParameters -dottedPath $buildMasterKey -DefaultValue $BuildMasterBaseUrl -AllowMissing)
      } catch { }
    }

    $checks['ProGetReachable'] = Test-SprintUrlReachable -Url $ProGetBaseUrl -TimeoutSeconds $ReachabilityTimeoutSeconds -Label 'ProGet'
    if (-not $checks['ProGetReachable'].Ok) { [void]$failures.Add('ProGetReachable') }

    $checks['BuildMasterReachable'] = Test-SprintUrlReachable -Url $BuildMasterBaseUrl -TimeoutSeconds $ReachabilityTimeoutSeconds -Label 'BuildMaster'
    if (-not $checks['BuildMasterReachable'].Ok) { [void]$failures.Add('BuildMasterReachable') }

    # Task 9.7: when the sprint built new module versions, confirm each one is
    # both in the *-stable ProGet feed AND installed on this workstation, so the
    # SprintEnd->SprintStart agents resolve the latest Production modules.
    $builtEntries = @($BuiltModule | Where-Object { $null -ne $_ })
    if ($SkipModulePromotionDeployCheck) {
      $checks['ModulePromotionDeploy'] = [PSCustomObject]@{
        Ok        = $true
        Skipped   = $true
        Detail    = 'Built-module promotion+deploy gate skipped by explicit caller request'
        PerModule = @()
      }
    } elseif ($builtEntries.Count -eq 0) {
      $checks['ModulePromotionDeploy'] = [PSCustomObject]@{
        Ok        = $true
        Skipped   = $true
        Detail    = 'No built modules declared (-BuiltModule); promotion+deploy gate not applicable'
        PerModule = @()
      }
    } else {
      $modPerModule = @()
      $modOk = $true
      foreach ($entry in $builtEntries) {
        $modName = $null
        $modVersion = $null
        if ($entry -is [System.Collections.IDictionary]) {
          $modName = [string]$entry['Name']
          $modVersion = [string]$entry['Version']
        } else {
          if ($entry.PSObject.Properties['Name']) { $modName = [string]$entry.Name }
          if ($entry.PSObject.Properties['Version']) { $modVersion = [string]$entry.Version }
        }

        if ([string]::IsNullOrWhiteSpace($modName) -or [string]::IsNullOrWhiteSpace($modVersion)) {
          $modOk = $false
          $modPerModule += [PSCustomObject]@{
            Name         = $modName
            Version      = $modVersion
            StableFeed   = $null
            Ok           = $false
            InStableFeed = $false
            Installed    = $false
            Detail       = 'BuiltModule entry is missing a Name and/or Version'
            Remediation  = 'Supply each -BuiltModule entry as @{ Name = <module>; Version = <version> }'
          }
          continue
        }

        $moduleResult = Test-SprintModulePromotionDeploy -Name $modName -Version $modVersion
        if (-not $moduleResult.Ok) { $modOk = $false }
        $modPerModule += $moduleResult
      }

      $checks['ModulePromotionDeploy'] = [PSCustomObject]@{
        Ok        = $modOk
        Skipped   = $false
        Detail    = if ($modOk) {
          "$($modPerModule.Count) built module(s) confirmed in *-stable feed and installed on the workstation"
        } else {
          'One or more built modules are missing from the *-stable feed or not installed on the workstation'
        }
        PerModule = $modPerModule
      }
      if (-not $modOk) { [void]$failures.Add('ModulePromotionDeploy') }
    }

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
