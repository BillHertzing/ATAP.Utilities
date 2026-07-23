#Requires -Version 7.0
function Resolve-LocalPowerShellModulePollerRepoRoot {
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot
  )

  if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $repoRootOutput = & git rev-parse --show-toplevel 2>&1
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace([string]$repoRootOutput)) {
      $detail = ([string]($repoRootOutput | Out-String)).Trim()
      throw "Could not resolve the Git repository root from the current directory. $detail"
    }
    $RepoRoot = ([string]($repoRootOutput | Select-Object -First 1)).Trim()
  }

  return (Resolve-Path -LiteralPath $RepoRoot -ErrorAction Stop).ProviderPath
}

function ConvertTo-LocalPowerShellModulePollerPath {
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string]$Path
  )

  $normalized = ($Path -replace '\\', '/').Trim()
  while ($normalized.StartsWith('./')) {
    $normalized = $normalized.Substring(2)
  }
  return $normalized.Trim('/')
}

function Save-LocalPowerShellModulePollerState {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$StatePath,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Commit,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ModuleName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ModuleRelativePath,

    [Parameter(Mandatory = $false)]
    [string]$Branch
  )

  $stateDirectory = Split-Path -Parent $StatePath
  if (-not [string]::IsNullOrWhiteSpace($stateDirectory) -and -not (Test-Path -LiteralPath $stateDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $stateDirectory -Force | Out-Null
  }

  [PSCustomObject]@{
    LastSeenCommit     = $Commit
    Branch             = $Branch
    ModuleName         = $ModuleName
    ModuleRelativePath = $ModuleRelativePath
    UpdatedAtUtc       = (Get-Date).ToUniversalTime().ToString('o')
  } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $StatePath -Encoding utf8 -NoNewline
}

function Start-LocalPowerShellModuleBuildMasterPoller {
  <#
.SYNOPSIS
    Runs a local pilot Git poll for the BuildTooling PowerShell module.

.DESCRIPTION
    Compares the current local Git HEAD with a persisted last-seen commit. When
    committed changes under `src/ATAP.Utilities.BuildTooling.PowerShell/` are
    detected, it invokes Start-BuildMasterPackagePipeline with the same module
    and package identity used by the BuildMaster-native GitHub monitor.

    This pilot is intentionally local and state-file based so it can be invoked
    from Task Scheduler, a terminal loop, or manually while comparing behavior
    with BuildMaster's native GitHub repository monitor.

.PARAMETER RepoRoot
    Git repository root to poll. Defaults to `git rev-parse --show-toplevel`.

.PARAMETER ModuleName
    PowerShell module identity to pass to BuildMaster.

.PARAMETER PackageName
    Package identity to pass to BuildMaster. Defaults to `ModuleName`.

.PARAMETER ModuleRelativePath
    Repository-relative folder path to watch for committed changes.

.PARAMETER StatePath
    JSON file storing the last local commit this poller examined.

.PARAMETER UsePreviousCommitWhenStateMissing
    On first run, compare HEAD~1..HEAD instead of only initializing state.

.PARAMETER InitializeStateOnly
    Reset or create the state file at the current HEAD without queuing a build.

.OUTPUTS
    [PSCustomObject] summarizing commits, changed files, matched files, and the
    BuildMaster pipeline result when a matching commit was detected.
#>
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ModuleName = 'ATAP.Utilities.BuildTooling.PowerShell',

    [Parameter(Mandatory = $false)]
    [string]$PackageName,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ModuleRelativePath = 'src/ATAP.Utilities.BuildTooling.PowerShell',

    [Parameter(Mandatory = $false)]
    [string]$StatePath,

    [Parameter(Mandatory = $false)]
    [string]$Application = 'ATAP.Utilities-PowerShell',

    [Parameter(Mandatory = $false)]
    [Alias('Pipeline')]
    [string]$PipelineName = 'global::PowerShellModule-5Stage',

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Tier = 'Experimental',

    [Parameter(Mandatory = $false)]
    [string]$FeedName = 'powershellget-experimental',

    [Parameter(Mandatory = $false)]
    [string]$Branch,

    [Parameter(Mandatory = $false)]
    [switch]$SkipDeployment,

    [Parameter(Mandatory = $false)]
    [string]$BuildMasterBaseUrl,

    [Parameter(Mandatory = $false)]
    [string]$BuildMasterAdminApiKeySecretName,

    [Parameter(Mandatory = $false)]
    [switch]$UsePreviousCommitWhenStateMissing,

    [Parameter(Mandatory = $false)]
    [switch]$InitializeStateOnly
  )

  process {
    $resolvedRepoRoot = Resolve-LocalPowerShellModulePollerRepoRoot -RepoRoot $RepoRoot
    $normalizedModuleRelativePath = ConvertTo-LocalPowerShellModulePollerPath -Path $ModuleRelativePath
    if ([string]::IsNullOrWhiteSpace($normalizedModuleRelativePath)) {
      throw 'ModuleRelativePath cannot be empty after normalization.'
    }

    if ([string]::IsNullOrWhiteSpace($PackageName)) {
      $PackageName = $ModuleName
    }

    if ([string]::IsNullOrWhiteSpace($StatePath)) {
      $StatePath = Join-Path -Path $resolvedRepoRoot -ChildPath "_generated/buildmaster/local-poller/$ModuleName.json"
    }

    $currentCommit = Get-LocalPowerShellModulePollerGitScalar -RepoRoot $resolvedRepoRoot -Arguments @('rev-parse', 'HEAD')
    if ([string]::IsNullOrWhiteSpace($Branch)) {
      $Branch = Get-LocalPowerShellModulePollerGitScalar -RepoRoot $resolvedRepoRoot -Arguments @('branch', '--show-current')
    }

    $stateExists = Test-Path -LiteralPath $StatePath -PathType Leaf
    $stateWasMissing = -not $stateExists
    $previousCommit = $null
    if ($stateExists) {
      $state = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json -ErrorAction Stop
      $previousCommit = [string]$state.LastSeenCommit
    }

    if ([string]::IsNullOrWhiteSpace($previousCommit)) {
      if ($UsePreviousCommitWhenStateMissing.IsPresent -and -not $InitializeStateOnly.IsPresent) {
        try {
          $previousCommit = Get-LocalPowerShellModulePollerGitScalar -RepoRoot $resolvedRepoRoot -Arguments @('rev-parse', 'HEAD~1')
        } catch {
          $previousCommit = $currentCommit
        }
      } else {
        $previousCommit = $currentCommit
      }
    }

    $changedFiles = @()
    if (-not $InitializeStateOnly.IsPresent -and $previousCommit -ne $currentCommit) {
      $changedFiles = @(
        Invoke-LocalPowerShellModulePollerGit -RepoRoot $resolvedRepoRoot -Arguments @(
          'diff',
          '--name-only',
          '--diff-filter=ACMRT',
          $previousCommit,
          $currentCommit
        ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object {
          ConvertTo-LocalPowerShellModulePollerPath -Path $_
        }
      )
    }

    $matchedFiles = @(
      $changedFiles | Where-Object {
        $_ -eq $normalizedModuleRelativePath -or $_.StartsWith("$normalizedModuleRelativePath/")
      }
    )

    $buildResult = $null
    $triggered = $false
    $stateUpdated = $false
    $responseSummary = $null

    if ($InitializeStateOnly.IsPresent) {
      if ($PSCmdlet.ShouldProcess($StatePath, "Initialize local poller state at commit '$currentCommit'")) {
        Save-LocalPowerShellModulePollerState -StatePath $StatePath -Commit $currentCommit -ModuleName $ModuleName -ModuleRelativePath $normalizedModuleRelativePath -Branch $Branch
        $stateUpdated = $true
      }
      $responseSummary = "initialized local poller state for '$ModuleName' at $currentCommit"
    } elseif ($matchedFiles.Count -gt 0) {
      $projectPath = Join-Path -Path $resolvedRepoRoot -ChildPath $normalizedModuleRelativePath
      $target = "BuildMaster pipeline '$PipelineName' for '$ModuleName' at $currentCommit"
      if ($PSCmdlet.ShouldProcess($target, 'Start local-polled BuildMaster package pipeline')) {
        $pipelineParams = @{
          Application                     = $Application
          PipelineName                    = $PipelineName
          ModuleName                      = $ModuleName
          PackageName                     = $PackageName
          ProjectPath                     = $projectPath
          Tier                            = $Tier
          Reason                          = "Local Git poller detected committed changes under $normalizedModuleRelativePath at $currentCommit"
          SkipDeployment                  = $SkipDeployment.IsPresent
        }
        if (-not [string]::IsNullOrWhiteSpace($FeedName)) { $pipelineParams['FeedName'] = $FeedName }
        if (-not [string]::IsNullOrWhiteSpace($Branch)) { $pipelineParams['Branch'] = $Branch }
        if (-not [string]::IsNullOrWhiteSpace($BuildMasterBaseUrl)) { $pipelineParams['BuildMasterBaseUrl'] = $BuildMasterBaseUrl }
        if (-not [string]::IsNullOrWhiteSpace($BuildMasterAdminApiKeySecretName)) { $pipelineParams['BuildMasterAdminApiKeySecretName'] = $BuildMasterAdminApiKeySecretName }

        $buildResult = Start-BuildMasterPackagePipeline @pipelineParams
        $triggered = $true
        $pipelineSucceeded = $true
        if ($null -ne $buildResult -and $buildResult.PSObject.Properties.Name -contains 'Succeeded') {
          $pipelineSucceeded = [bool]$buildResult.Succeeded
        }

        if ($pipelineSucceeded) {
          Save-LocalPowerShellModulePollerState -StatePath $StatePath -Commit $currentCommit -ModuleName $ModuleName -ModuleRelativePath $normalizedModuleRelativePath -Branch $Branch
          $stateUpdated = $true
          $responseSummary = "matched $($matchedFiles.Count) committed file(s); queued BuildMaster pipeline and advanced state"
        } else {
          $responseSummary = "matched $($matchedFiles.Count) committed file(s); BuildMaster pipeline did not report success, so state was not advanced"
        }
      } else {
        $responseSummary = "WhatIf: matched $($matchedFiles.Count) committed file(s); BuildMaster pipeline was not queued"
      }
    } else {
      if ($PSCmdlet.ShouldProcess($StatePath, "Update local poller state to commit '$currentCommit'")) {
        Save-LocalPowerShellModulePollerState -StatePath $StatePath -Commit $currentCommit -ModuleName $ModuleName -ModuleRelativePath $normalizedModuleRelativePath -Branch $Branch
        $stateUpdated = $true
      }
      $responseSummary = "no committed changes matched '$normalizedModuleRelativePath'; state advanced to $currentCommit"
    }

    return [PSCustomObject]@{
      OperationName       = 'Start-LocalPowerShellModuleBuildMasterPoller'
      RepoRoot            = $resolvedRepoRoot
      ModuleName          = $ModuleName
      PackageName         = $PackageName
      ModuleRelativePath  = $normalizedModuleRelativePath
      StatePath           = $StatePath
      StateWasMissing     = $stateWasMissing
      PreviousCommit      = $previousCommit
      CurrentCommit       = $currentCommit
      Branch              = $Branch
      ChangedFiles        = $changedFiles
      MatchedFiles        = $matchedFiles
      Triggered           = $triggered
      StateUpdated        = $stateUpdated
      BuildResult         = $buildResult
      ResponseSummary     = $responseSummary
    }
  }
}
