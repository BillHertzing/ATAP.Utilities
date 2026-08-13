function Get-SprintEndApprovalPlan {
  <#
  .SYNOPSIS
    Produces the deterministic SprintEnd approval plan: which close concerns
    require an operator prompt, why, and where each authority boundary sits.

  .DESCRIPTION
    Task 14.11. The Sprint 0013 close raised three approval messages the
    operator had, in substance, already answered. Each had a distinct cause, and
    each is corrected here by making the decision a function of the inputs
    rather than of who happened to evaluate $ConfirmPreference:

    1. PullRequestMerge -- Invoke-SprintEndGitHubClose declares ConfirmImpact
       High, and the orchestrator, the delegated PR specialist, and the
       interactive shell each evaluated that impact independently. One
       authorized merge therefore produced one prompt per evaluation layer. The
       correction is a single recorded authorization: the operator gate happens
       once, at the orchestrator, and -MergeAuthorizationConfirmed suppresses
       every downstream re-ask. Suppression never widens authority -- with no
       recorded authorization the plan still requires the prompt, and the
       concern is always reported at the 'Merge' boundary.

    2. DelegatedAgentAuthorization -- a delegated agent re-raised authorization
       it had already been handed, because the relay carried no provenance. A
       delegate cannot tell an inherited approval from an unauthorized request
       when nothing identifies the approver. The correction is that a delegate
       never prompts: it either relays a named authorization source or it fails
       closed, and the missing-provenance case is a failure rather than a
       silently re-asked question.

    3. NuGetLockFileRunner -- runner availability was presented as an optional
       "proceed anyway?" question, so the answer changed what the gate meant.
       The correction removes the prompt entirely and replaces it with a
       tri-state fact: NotApplicable when no selected worktree tracks a
       packages.lock.json, Enforced when lock files are tracked and the runner
       is available, and Blocked when lock files are tracked and it is not.
       Blocked is a hard failure, never an operator judgement call.

    The cmdlet is pure with respect to the outside world when
    -LockFileApplicable is supplied; otherwise it inspects the supplied
    worktrees read-only with Git to decide applicability. It never mutates, and
    it never prompts -- it only reports where prompts belong.

  .PARAMETER MergePullRequests
    The close intends to merge sprint pull requests.

  .PARAMETER MergeAuthorizationConfirmed
    The operator has already authorized the merge for this close. Suppresses
    downstream re-prompting only; it does not authorize a merge that was not
    requested.

  .PARAMETER DelegationMode
    'None' when the orchestrator performs GitHub operations itself; 'Delegated'
    when a PR/version-control agent performs them on its behalf.

  .PARAMETER DelegatedAuthorizationSource
    Provenance for the authorization relayed to the delegate, for example
    'Operator:2026-08-03T09:15:00-06:00'. Required when DelegationMode is
    'Delegated'.

  .PARAMETER WorktreePaths
    Sprint worktrees included in the close. Used to decide lock-file
    applicability when -LockFileApplicable is not supplied.

  .PARAMETER LockFileApplicable
    Explicit lock-file applicability, bypassing Git inspection.

  .PARAMETER LockFileRunnerAvailable
    Whether the lock-file guard command is available. Defaults to whether
    Assert-LockFilesClean resolves in this session.

  .PARAMETER ThrowOnFailure
    Throw a terminating error when the plan is not Ok.

  .OUTPUTS
    PSCustomObject with Ok, PromptCount, RequiredPrompts, Concerns, and
    Failures. Every concern carries Concern, Cause, Decision, PromptRequired,
    Boundary, and Detail.

  .EXAMPLE
    Get-SprintEndApprovalPlan -MergePullRequests -WorktreePaths $worktreePaths

  .EXAMPLE
    # After the operator confirms the dry run, the merge is authorized once.
    Get-SprintEndApprovalPlan -MergePullRequests -MergeAuthorizationConfirmed `
      -DelegationMode Delegated -DelegatedAuthorizationSource 'Operator:2026-08-03T09:15:00-06:00' `
      -LockFileApplicable:$false

  .NOTES
    AI assisted using ./.claude/rules/Powershell.md as guidelines.

  .LINK
    Invoke-SprintEndLifecycle
  #>
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter()]
    [switch]$MergePullRequests,

    [Parameter()]
    [switch]$MergeAuthorizationConfirmed,

    [Parameter()]
    [ValidateSet('None', 'Delegated')]
    [string]$DelegationMode = 'None',

    [Parameter()]
    [AllowEmptyString()]
    [string]$DelegatedAuthorizationSource,

    [Parameter()]
    [AllowEmptyCollection()]
    [string[]]$WorktreePaths = @(),

    [Parameter()]
    [bool]$LockFileApplicable,

    [Parameter()]
    [bool]$LockFileRunnerAvailable,

    [Parameter()]
    [switch]$ThrowOnFailure
  )

  begin {
    $fn = 'Get-SprintEndApprovalPlan'
    $mn = 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    if (-not (Get-Command -Name 'Get-SprintEndLockFileApplicability' -CommandType Function -ErrorAction SilentlyContinue)) {
      $applicabilityHelperPath = Join-Path $PSScriptRoot '..' 'private' 'Get-SprintEndLockFileApplicability.ps1'
      if (Test-Path -LiteralPath $applicabilityHelperPath -PathType Leaf) {
        . $applicabilityHelperPath
      }
    }

    $concerns = [System.Collections.Generic.List[object]]::new()
    $failures = [System.Collections.Generic.List[string]]::new()
  }

  process {
    # ------------------------------------------------------------------
    # Concern 1: pull-request merge authorization
    # ------------------------------------------------------------------
    $mergeCause = 'Invoke-SprintEndGitHubClose declares ConfirmImpact High, and the orchestrator, the delegated PR specialist, and the interactive shell each evaluated that impact independently, so one authorized merge produced one prompt per evaluation layer.'
    $mergeDecision = if (-not $MergePullRequests) {
      'NotRequested'
    } elseif ($MergeAuthorizationConfirmed) {
      'PreAuthorized'
    } else {
      'OperatorGate'
    }
    $mergePrompt = ($mergeDecision -eq 'OperatorGate')
    $mergeDetail = switch ($mergeDecision) {
      'NotRequested' { 'No merge was requested, so no merge authority is exercised and no prompt is raised.' }
      'PreAuthorized' { 'The operator authorized this merge once at the orchestrator. Downstream calls run with -Confirm:$false and must not re-ask; the merge boundary remains explicit in this plan.' }
      default { 'The merge is requested but not yet authorized. Exactly one operator prompt is raised, at the orchestrator, before any pull request is merged.' }
    }
    [void]$concerns.Add([PSCustomObject]@{
        Concern        = 'PullRequestMerge'
        Cause          = $mergeCause
        Decision       = $mergeDecision
        PromptRequired = $mergePrompt
        Boundary       = 'Merge'
        Deterministic  = $true
        Detail         = $mergeDetail
      })

    # ------------------------------------------------------------------
    # Concern 2: delegated-agent relayed authorization
    # ------------------------------------------------------------------
    $delegationCause = 'A delegated PR/version-control agent re-raised authorization it had already been handed, because the relay carried no provenance identifying the approver, so the delegate could not distinguish an inherited approval from an unauthorized request.'
    $hasSource = -not [string]::IsNullOrWhiteSpace($DelegatedAuthorizationSource)
    $delegationDecision = if ($DelegationMode -eq 'None') {
      'NotDelegated'
    } elseif ($hasSource) {
      'RelayedAuthorization'
    } else {
      'AuthorizationMissing'
    }
    $delegationDetail = switch ($delegationDecision) {
      'NotDelegated' { 'The orchestrator performs GitHub operations itself, so there is no relay and no second authorization surface.' }
      'RelayedAuthorization' { "The delegate carries named authorization provenance ('$DelegatedAuthorizationSource') and must not raise its own prompt. It exercises exactly the authority relayed to it and no more." }
      default { 'A delegate was selected without authorization provenance. The delegate must not invent a prompt to resolve this; the close fails closed until the orchestrator relays a named authorization source.' }
    }
    if ($delegationDecision -eq 'AuthorizationMissing') {
      [void]$failures.Add('DelegatedAuthorizationSourceMissing')
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $delegationDetail
    }
    [void]$concerns.Add([PSCustomObject]@{
        Concern        = 'DelegatedAgentAuthorization'
        Cause          = $delegationCause
        Decision       = $delegationDecision
        PromptRequired = $false
        Boundary       = 'Merge'
        Deterministic  = $true
        Detail         = $delegationDetail
      })

    # ------------------------------------------------------------------
    # Concern 3: optional NuGet lock-file runner availability
    # ------------------------------------------------------------------
    $lockCause = 'Lock-file runner availability was presented to the operator as an optional "proceed anyway?" question, so the operator answer changed what the guard meant instead of the repositories deciding whether the guard applies at all.'

    $runnerAvailable = if ($PSBoundParameters.ContainsKey('LockFileRunnerAvailable')) {
      $LockFileRunnerAvailable
    } else {
      [bool](Get-Command -Name 'Assert-LockFilesClean' -ErrorAction SilentlyContinue)
    }

    $applicabilityDetail = $null
    $applicable = if ($PSBoundParameters.ContainsKey('LockFileApplicable')) {
      $LockFileApplicable
    } else {
      $applicability = Get-SprintEndLockFileApplicability -WorktreePath $WorktreePaths
      $applicabilityDetail = "$($applicability.TrackedLockFileCount) tracked packages.lock.json file(s) across $(@($WorktreePaths).Count) worktree(s)."
      foreach ($applicabilityFailure in @($applicability.Failures)) {
        [void]$failures.Add($applicabilityFailure)
      }
      $applicability.Applicable
    }

    $lockDecision = if (-not $applicable) {
      'NotApplicable'
    } elseif ($runnerAvailable) {
      'Enforced'
    } else {
      'Blocked'
    }
    $lockDetail = switch ($lockDecision) {
      'NotApplicable' { 'No selected worktree tracks a packages.lock.json, so lock-file drift is impossible and runner availability is irrelevant. The guard is skipped as a fact, not as an operator decision.' }
      'Enforced' { 'Selected worktrees track lock files and the guard command is available, so the guard runs. No operator prompt is involved.' }
      default { 'Selected worktrees track lock files but the guard command is unavailable. This is a hard environment fault: repair the module install and re-run. It is never an operator "proceed anyway" decision.' }
    }
    if ($applicabilityDetail) {
      $lockDetail = "$lockDetail $applicabilityDetail"
    }
    if ($lockDecision -eq 'Blocked') {
      [void]$failures.Add('NuGetLockFileRunnerUnavailable')
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $lockDetail
    }
    [void]$concerns.Add([PSCustomObject]@{
        Concern        = 'NuGetLockFileRunner'
        Cause          = $lockCause
        Decision       = $lockDecision
        PromptRequired = $false
        Boundary       = 'ReadOnly'
        Deterministic  = $true
        Detail         = $lockDetail
      })
  }

  end {
    $requiredPrompts = @($concerns | Where-Object PromptRequired | Select-Object -ExpandProperty Concern)
    $result = [PSCustomObject]@{
      Ok              = ($failures.Count -eq 0)
      PromptCount     = $requiredPrompts.Count
      RequiredPrompts = $requiredPrompts
      Concerns        = $concerns.ToArray()
      Failures        = @($failures | Select-Object -Unique)
    }

    if (-not $result.Ok -and $ThrowOnFailure) {
      throw "SprintEnd approval plan failed: $($result.Failures -join ', ')."
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
    return $result
  }
}
