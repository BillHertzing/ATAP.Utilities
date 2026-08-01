function Invoke-SprintEndGitHubClose {
  <#
  .SYNOPSIS
  Ensures a sprint PR closes its originating GitHub issue and optionally merges it.

  .DESCRIPTION
  Resolves the current branch and repository, derives the sprint issue from the
  numeric branch prefix when not supplied, ensures the PR body contains
  "Closes #N", and optionally performs a non-interactive squash merge. All
  native calls return compact structured results.

  .PARAMETER RepoPath
  Local sprint worktree path.

  .PARAMETER Repository
  GitHub repository in owner/name form. When omitted, derived from origin.

  .PARAMETER IssueNumber
  Originating sprint issue number. When omitted, derived from the branch prefix.

  .PARAMETER CreateIfMissing
  Creates a draft PR when no PR exists for the current branch.

  .PARAMETER Merge
  Validates mergeability and checks, then squash-merges and deletes the branch.

  .OUTPUTS
  PSCustomObject describing repository, issue, PR, and merge state.

  .EXAMPLE
  Invoke-SprintEndGitHubClose -RepoPath C:\Repos\App-wt-42-Sprint-0010-work-items -WhatIf

  .NOTES
  AI assisted using Powershell.instructions.md as guidelines.
  #>
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$RepoPath,

    [Parameter()]
    [string]$Repository,

    [Parameter()]
    [ValidateRange(1, [int]::MaxValue)]
    [int]$IssueNumber,

    [Parameter()]
    [switch]$CreateIfMissing,

    [Parameter()]
    [switch]$Merge
  )

  begin {
    $fn = 'Invoke-SprintEndGitHubClose'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
  }

  process {
    function Test-SprintEndGitHubTokenScopePreflight {
      [CmdletBinding()]
      [OutputType([PSCustomObject])]
      param()

      $scopeProbe = Invoke-SprintEndNativeCommand -FilePath 'gh' `
        -ArgumentList @('api', '-i', 'rate_limit') `
        -AllowNonZeroExitCode
      if (-not $scopeProbe.Succeeded) {
        return [PSCustomObject]@{
          Checked = $false
          Ok      = $true
          Scopes  = @()
          Message = 'GitHub token-scope preflight could not determine the active scopes; continuing with the close flow.'
        }
      }

      $scopeHeader = @(
        $scopeProbe.Output |
          Where-Object { $_ -match '^(?i)x-oauth-scopes:' }
      ) | Select-Object -First 1
      if ([string]::IsNullOrWhiteSpace($scopeHeader)) {
        return [PSCustomObject]@{
          Checked = $false
          Ok      = $true
          Scopes  = @()
          Message = 'GitHub token-scope preflight did not find an X-OAuth-Scopes header; continuing with the close flow.'
        }
      }

      $scopes = @(
        (($scopeHeader -replace '^(?i)x-oauth-scopes:\s*', '') -split ',') |
          ForEach-Object { $_.Trim() } |
          Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
      )
      $hasRequiredScope = ($scopes -contains 'read:org') -or ($scopes -contains 'read:discussion')
      $message = if ($hasRequiredScope) {
        "GitHub token-scope preflight passed with one of the required supplemental scopes: $($scopes -join ', ')."
      } else {
        "GitHub token-scope preflight detected scopes '$($scopes -join ', ')'. The current SprintEnd GitHub close flow needs a token that includes either 'read:org' or 'read:discussion' before any PR GraphQL calls are attempted."
      }

      return [PSCustomObject]@{
        Checked = $true
        Ok      = $hasRequiredScope
        Scopes  = $scopes
        Message = $message
      }
    }

    $resolvedRepoPath = [IO.Path]::GetFullPath($RepoPath)
    $branchResult = Invoke-SprintEndNativeCommand -FilePath 'git' `
      -ArgumentList @('-C', $resolvedRepoPath, 'branch', '--show-current')
    $branch = ($branchResult.Output -join '').Trim()
    if ([string]::IsNullOrWhiteSpace($branch)) {
      throw "Could not resolve the current branch for '$resolvedRepoPath'."
    }

    if ([string]::IsNullOrWhiteSpace($Repository)) {
      $remoteResult = Invoke-SprintEndNativeCommand -FilePath 'git' `
        -ArgumentList @('-C', $resolvedRepoPath, 'remote', 'get-url', 'origin')
      $remote = ($remoteResult.Output -join '').Trim()
      if ($remote -match '(?i)(?:github\.com[:/])(?<repo>[^/]+/.+?)(?:\.git)?/?$') {
        $Repository = $Matches.repo
      } else {
        throw "Could not derive GitHub repository from origin '$remote'."
      }
    }

    if (-not $PSBoundParameters.ContainsKey('IssueNumber')) {
      if ($branch -match '^(?<issue>\d+)-') {
        $IssueNumber = [int]$Matches.issue
      } else {
        throw "IssueNumber was not supplied and branch '$branch' has no numeric issue prefix."
      }
    }

    $scopePreflight = Test-SprintEndGitHubTokenScopePreflight
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message $scopePreflight.Message
    if (-not $scopePreflight.Ok) {
      throw "GitHub token-scope preflight failed for '$Repository'. Add either 'read:org' or 'read:discussion' to the SprintEnd token used by gh before retrying."
    }

    $issueResult = Invoke-SprintEndNativeCommand -FilePath 'gh' `
      -ArgumentList @('issue', 'view', "$IssueNumber", '--repo', $Repository, '--json', 'number,state,title,url') `
      -AllowNonZeroExitCode
    if (-not $issueResult.Succeeded) {
      throw "Sprint issue #$IssueNumber was not found in '$Repository'."
    }
    $issue = ($issueResult.Output -join [Environment]::NewLine) | ConvertFrom-Json

    $prListResult = Invoke-SprintEndNativeCommand -FilePath 'gh' `
      -ArgumentList @('pr', 'list', '--repo', $Repository, '--head', $branch, '--state', 'all', `
        '--json', 'number,state,title,body,url,mergeable,mergedAt') `
      -AllowNonZeroExitCode
    $pullRequests = if ($prListResult.Succeeded -and $prListResult.Output.Count -gt 0) {
      @(($prListResult.Output -join [Environment]::NewLine) | ConvertFrom-Json)
    } else {
      @()
    }
    if ($pullRequests.Count -gt 1) {
      throw "More than one PR exists for '$Repository' branch '$branch'."
    }
    $pr = $pullRequests | Select-Object -First 1
    $actions = [System.Collections.Generic.List[string]]::new()

    if (-not $pr -and $CreateIfMissing) {
      if ($PSCmdlet.ShouldProcess("$Repository/$branch", 'Push branch and create draft pull request')) {
        [void](Invoke-SprintEndNativeCommand -FilePath 'git' `
            -ArgumentList @('-C', $resolvedRepoPath, 'push', '--set-upstream', 'origin', $branch))
        $titleResult = Invoke-SprintEndNativeCommand -FilePath 'git' `
          -ArgumentList @('-C', $resolvedRepoPath, 'log', '-1', '--pretty=%s')
        $title = ($titleResult.Output -join '').Trim()
        $body = "## Sprint close`n`nCloses #$IssueNumber"
        [void](Invoke-SprintEndNativeCommand -FilePath 'gh' `
            -ArgumentList @('pr', 'create', '--repo', $Repository, '--head', $branch, '--base', 'main', `
              '--draft', '--title', $title, '--body', $body))
        [void]$actions.Add('Created draft PR.')
        $prListResult = Invoke-SprintEndNativeCommand -FilePath 'gh' `
          -ArgumentList @('pr', 'list', '--repo', $Repository, '--head', $branch, '--state', 'all', `
            '--json', 'number,state,title,body,url,mergeable,mergedAt')
        $pr = @(($prListResult.Output -join [Environment]::NewLine) | ConvertFrom-Json) |
          Select-Object -First 1
      } else {
        [void]$actions.Add('Would create draft PR.')
      }
    }

    $view = $null
    $checks = @()
    $requiredChecks = @()
    $codeSeeChecks = @()
    $planningPayload = $null
    if ($pr) {
      $closingPattern = "(?im)\b(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?)\s+#$IssueNumber\b"
      if ([string]$pr.body -notmatch $closingPattern) {
        $newBody = (([string]$pr.body).TrimEnd() + "`n`nCloses #$IssueNumber").Trim()
        if ($PSCmdlet.ShouldProcess("$Repository PR #$($pr.number)", "Add Closes #$IssueNumber")) {
          [void](Invoke-SprintEndNativeCommand -FilePath 'gh' `
              -ArgumentList @('pr', 'edit', "$($pr.number)", '--repo', $Repository, '--body', $newBody))
          $pr.body = $newBody
          [void]$actions.Add("Added Closes #$IssueNumber.")
        } else {
          [void]$actions.Add("Would add Closes #$IssueNumber.")
        }
      }

      $viewJsonFields = 'number,state,mergeable,reviewDecision,isDraft,statusCheckRollup,url,headRefOid'
      $viewResult = Invoke-SprintEndNativeCommand -FilePath 'gh' `
        -ArgumentList @('pr', 'view', "$($pr.number)", '--repo', $Repository, '--json', $viewJsonFields)
      $view = ($viewResult.Output -join [Environment]::NewLine) | ConvertFrom-Json
      if ($Merge -and [bool]$view.isDraft -and [string]$pr.state -ne 'MERGED') {
        if ($PSCmdlet.ShouldProcess("$Repository PR #$($pr.number)", 'Mark pull request ready for review before merge')) {
          [void](Invoke-SprintEndNativeCommand -FilePath 'gh' `
              -ArgumentList @('pr', 'ready', "$($pr.number)", '--repo', $Repository))
          [void]$actions.Add('Marked PR ready for review.')
          $viewResult = Invoke-SprintEndNativeCommand -FilePath 'gh' `
            -ArgumentList @('pr', 'view', "$($pr.number)", '--repo', $Repository, '--json', $viewJsonFields)
          $view = ($viewResult.Output -join [Environment]::NewLine) | ConvertFrom-Json
        } else {
          [void]$actions.Add('Would mark PR ready for review.')
        }
      }
      $requiredResult = Invoke-SprintEndNativeCommand -FilePath 'gh' `
        -ArgumentList @('pr', 'checks', "$($pr.number)", '--repo', $Repository, '--required', `
          '--json', 'bucket,name,state,link,workflow') -AllowNonZeroExitCode
      if ($requiredResult.Output.Count -gt 0) {
        try {
          $requiredChecks = @(($requiredResult.Output -join [Environment]::NewLine) | ConvertFrom-Json)
        } catch {
          $requiredChecks = @()
        }
      }
      $requiredNames = @($requiredChecks | ForEach-Object { [string]$_.name } | Where-Object { $_ } | Select-Object -Unique)
      $checks = @($view.statusCheckRollup | ForEach-Object {
          $name = if ($_.name) { [string]$_.name } elseif ($_.context) { [string]$_.context } else { 'unnamed-check' }
          $state = if ($_.conclusion) {
            [string]$_.conclusion
          } elseif ($_.state) {
            [string]$_.state
          } elseif ($_.status) {
            [string]$_.status
          } else {
            'UNKNOWN'
          }
          [PSCustomObject]@{
            Name           = $name
            State          = $state.ToUpperInvariant()
            Required       = ($requiredNames -contains $name)
            Classification = if ($name -match '(?i)codesee') { 'PlanningSignal' } elseif ($requiredNames -contains $name) { 'Required' } else { 'Informational' }
            Url            = if ($_.detailsUrl) { [string]$_.detailsUrl } elseif ($_.link) { [string]$_.link } else { $null }
          }
        })
      $codeSeeChecks = @($checks | Where-Object { $_.Name -match '(?i)codesee' })
      $failedRequiredChecks = @($checks | Where-Object {
          $_.Required -and $_.State -notin @('SUCCESS', 'SKIPPED', 'NEUTRAL', 'PASS')
        })

      if ($Merge -and $pr.state -ne 'MERGED') {
        if ($view.mergeable -ne 'MERGEABLE' -or $failedRequiredChecks.Count -gt 0) {
          throw "PR #$($pr.number) is not ready to merge. mergeable=$($view.mergeable); failedRequiredChecks=$($failedRequiredChecks.Count)."
        }
        if ($PSCmdlet.ShouldProcess("$Repository PR #$($pr.number)", 'Squash merge and delete branch')) {
          [void](Invoke-SprintEndNativeCommand -FilePath 'gh' `
              -ArgumentList @('pr', 'merge', "$($pr.number)", '--repo', $Repository, '--squash', '--delete-branch'))
          [void]$actions.Add('Merged PR.')
          $pr.state = 'MERGED'
        } else {
          [void]$actions.Add('Would merge PR.')
        }
      }

      $planningPayload = [PSCustomObject]@{
        Repository          = $Repository
        SprintIssue         = $IssueNumber
        PullRequest         = [int]$pr.number
        FinalCommit         = [string]$view.headRefOid
        RequiredCheckCount  = @($checks | Where-Object Required).Count
        InformationalCount  = @($checks | Where-Object { -not $_.Required }).Count
        CodeSeeClassification = if ($codeSeeChecks.Count -gt 0) { 'PlanningSignal' } else { 'NotReported' }
        CodeSee             = $codeSeeChecks
        FailedRequiredChecks = $failedRequiredChecks
      }
    }

    $issueClosed = ([string]$issue.state -eq 'CLOSED')
    if ($pr -and [string]$pr.state -eq 'MERGED') {
      $issueRefresh = Invoke-SprintEndNativeCommand -FilePath 'gh' `
        -ArgumentList @('issue', 'view', "$IssueNumber", '--repo', $Repository, '--json', 'number,state,title,url')
      $issue = ($issueRefresh.Output -join [Environment]::NewLine) | ConvertFrom-Json
      $issueClosed = ([string]$issue.state -eq 'CLOSED')
      if (-not $issueClosed) {
        throw "PR merged but sprint issue #$IssueNumber remains open in '$Repository'."
      }
    }

    return [PSCustomObject]@{
      Repository   = $Repository
      RepoPath     = $resolvedRepoPath
      Branch       = $branch
      IssueNumber  = $IssueNumber
      IssueState   = [string]$issue.state
      IssueClosed  = $issueClosed
      PullRequest  = $pr
      FinalCommit  = if ($view) { [string]$view.headRefOid } else { $null }
      Checks       = $checks
      RequiredChecks = $requiredChecks
      CodeSee      = $codeSeeChecks
      PlanningPayload = $planningPayload
      Actions      = $actions.ToArray()
      Ok           = ($null -ne $pr -and (-not $Merge -or $issueClosed))
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
