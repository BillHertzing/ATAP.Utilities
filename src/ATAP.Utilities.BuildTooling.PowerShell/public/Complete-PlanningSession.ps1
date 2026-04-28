function Complete-PlanningSession {
  <#
.SYNOPSIS
    Finalize a planning session: update status files, generate amendments, commit,
    push, open a PR, squash-merge, pull main, and remove the worktree.

.DESCRIPTION
    Reads a completed planning session notebook (Decision fields filled in),
    then automates the post-session artifact updates per Explainer 0000.

    The 6-phase planning process (Status Capture, AI Conversation Analysis,
    Scope Creep Review, Cross-Phase Reconciliation, Sprint Planning, and
    Conversation Bookmark) is performed by the facilitator. This cmdlet
    handles the mechanical file updates and Git operations afterward:

      1. Reads Session, BranchName, IssueNumber, WorktreePath from the notebook header
      2. Updates Status in ScopeCreep-Inbox.md for every decided idea
      3. Appends adopted ideas to ScopeCreep-Adopted.md (table row + full entry)
      4. Appends deferred ideas to ScopeCreep-Deferred.md (with TriggerCondition)
      5. Generates amendment blocks → ReplanningNotebooks\YYYY-MM-DD-Amendments.md
      6. Discovers all planning artifacts (Modernization Plan, TASKS.md,
         Sprint-Duration-Log.md, AI Conversation Analysis, Conversation Bookmark,
         README.md) and includes them in the commit
      7. Stages and commits ALL changes in the worktree
      8. Pushes the branch to origin
      9. Opens a PR (gh pr create) with "Closes #N" in the body
     10. Squash-merges the PR (gh pr merge --squash --delete-branch)
     11. Pulls main in the _Planning repo to get the merged changes
     12. Removes the worktree
     13. Prints next-step instructions

    All edits target the WORKTREE paths read from the session doc — the main
    repo working tree is not touched until the merge lands in step 11.

.PARAMETER SessionFile
    Filename (looked up in Sessions\) or full path to the completed session doc.

.PARAMETER PlanFile
    Modernization Plan path (AceCommander-Modernization-Plan.md). Used for display/instructions text only.

.PARAMETER SkipGitHub
    Skip gh pr create / merge. Use when gh CLI is unavailable.
    Changes are still committed and pushed; you merge the PR manually.

.PARAMETER SkipWorktreeRemove
    Leave the worktree in place after the PR merges (useful for post-session review).

.PARAMETER GhRepo
    GitHub repo owner/name. Auto-detected via gh repo view if omitted.

.OUTPUTS
    [void]

.EXAMPLE
    Complete-PlanningSession -SessionFile 2026-03-16-Session.md
    # Full run: commit → push → PR → merge → cleanup.

.EXAMPLE
    Complete-PlanningSession -SessionFile 2026-03-16-Session.md -SkipGitHub
    # Commit and push only; merge PR manually in GitHub.

.EXAMPLE
    Complete-PlanningSession -SessionFile 2026-03-16-Session.md -WhatIf
    # Dry run — shows what would change.

.NOTES
    AI assisted using Powershell.instructions.md as guidelines

.LINK
    https://github.com/whertzing/ATAP.Utilities
#>
  function Complete-PlanningSession {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    [OutputType([void])]
    param(
      [Parameter(Mandatory = $true, Position = 0)]
      [ValidateNotNullOrEmpty()]
      [string] $SessionFile,

      [Parameter(Mandatory = $false)]
      [string] $PlanFile,

      [Parameter(Mandatory = $false)]
      [switch] $SkipGitHub,

      [Parameter(Mandatory = $false)]
      [switch] $SkipWorktreeRemove,

      [Parameter(Mandatory = $false)]
      [string] $GhRepo = ''
    )

    begin {
      $fn = $MyInvocation.MyCommand.Name
      $mn = $MyInvocation.MyCommand.ModuleName

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Entering function'

      # Check and populate simple parameter (snippet: CheckAndPopulateSimpleParameter, param: SessionFile)
      $SessionFile = Get-PVal -ParameterName SessionFile -originalPSBoundParameters $PSBoundParameters -dottedPath SessionFile -DefaultValue $SessionFile

      # Check and populate simple parameter (snippet: CheckAndPopulateSimpleParameter, param: PlanFile)
      $PlanFile = Get-PVal -ParameterName PlanFile -originalPSBoundParameters $PSBoundParameters -dottedPath PlanFile -DefaultValue $PlanFile

      # Check and populate simple parameter (snippet: CheckAndPopulateSimpleParameter, param: GhRepo)
      $GhRepo = Get-PVal -ParameterName GhRepo -originalPSBoundParameters $PSBoundParameters -dottedPath GhRepo -DefaultValue $GhRepo

      # ── Private helpers ────────────────────────────────────────────────────────

      function invokeGit {
        param([string]$WorkDir, [string[]]$GitArgs)
        if ($WhatIfPreference) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "[WhatIf] git -C '$WorkDir' $($GitArgs -join ' ')"
          return
        }
        $result = & git -C $WorkDir @GitArgs 2>&1
        if ($LASTEXITCODE -ne 0) { throw "git $($GitArgs -join ' ') failed`n$result" }
        return $result
      }

      function updateStatusInFile {
        [CmdletBinding(SupportsShouldProcess)]
        param(
          [string] $FilePath,
          [string] $ScId,
          [string] $NewStatus,
          [string] $ExtraField = '',
          [string] $ExtraValue = ''
        )
        $content = Get-Content $FilePath -Raw
        $pattern = "(?ms)(## $([regex]::Escape($ScId))\r?\n(?:.*?\r?\n)*?)(- \*\*Status\*\*: \w+)"
        if ($content -match $pattern) {
          $newContent = $content -replace $pattern, "`$1- **Status**: $NewStatus"
          if ($ExtraField -and $ExtraValue) {
            $newContent = $newContent -replace "(- \*\*Status\*\*: $NewStatus)",
            "`$1`n- **$ExtraField**: $ExtraValue"
          }
          if ($PSCmdlet.ShouldProcess($FilePath, "Update $ScId Status → $NewStatus")) {
            Set-Content -Path $FilePath -Value $newContent -Encoding UTF8
          }
          return $true
        }
        return $false
      }
    }

    process {
      try {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'COMPLETE PLANNING SESSION'

        # ════════════════════════════════════════════════════════════════════════
        # 1.  Locate the _Planning repo and resolve the session file
        # ════════════════════════════════════════════════════════════════════════

        $planningRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        $sessionsDir = Join-Path $planningRoot 'ReplanningNotebooks'

        if (-not [System.IO.Path]::IsPathRooted($SessionFile)) {
          foreach ($candidate in @(
              (Join-Path $sessionsDir $SessionFile),
              (Join-Path $planningRoot $SessionFile),
              $SessionFile
            )) {
            if (Test-Path $candidate) { $SessionFile = $candidate; break }
          }
        }

        if (-not (Test-Path $SessionFile)) {
          throw "Session file not found: $SessionFile"
        }

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Session file: $SessionFile"
        $sessionContent = Get-Content $SessionFile -Raw

        # ── Extract Git metadata from session doc header ────────────────────────
        function getHeaderField([string]$Field) {
          if ($sessionContent -match "\|\s*\*\*$Field\*\*\s*\|\s*([^|`n]+)") {
            return $Matches[1].Trim()
          }
          return ''
        }

        $sessionId = getHeaderField 'Session'
        if (-not $sessionId) { $sessionId = getHeaderField 'SessionId' }
        $sessionDate = getHeaderField 'Date'
        if (-not $sessionDate) {
          $sessionDate = if ($SessionFile -match '(\d{4}-\d{2}-\d{2})') { $Matches[1] } else { Get-Date -Format 'yyyy-MM-dd' }
        }
        $branchName = getHeaderField 'BranchName'
        $issueNumber = [int](getHeaderField 'IssueNumber')
        $worktreePath = getHeaderField 'WorktreePath'
        $prevEnd = (getHeaderField 'PreviousProjectEnd') -replace '_.*_', '' | ForEach-Object { $_.Trim() }
        if (-not $prevEnd) { $prevEnd = 'Week 23' }

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "SessionId=$sessionId  Branch=$(if ($branchName) { $branchName } else { '(not set)' })  Issue=$(if ($issueNumber -gt 0) { "#$issueNumber" } else { 'none' })  Worktree=$(if ($worktreePath) { $worktreePath } else { '(not set)' })"

        # ── Resolve paths — prefer worktree when available ────────────────────────
        $workDir = if ($worktreePath -and (Test-Path $worktreePath)) { $worktreePath } else { $planningRoot }

        $inboxPath = Join-Path $workDir 'ScopeCreepManagement' 'ScopeCreep-Inbox.md'
        $adoptedPath = Join-Path $workDir 'ScopeCreepManagement' 'ScopeCreep-Adopted.md'
        $deferredPath = Join-Path $workDir 'ScopeCreepManagement' 'ScopeCreep-Deferred.md'
        $sessionsDirWt = Join-Path $workDir 'ReplanningNotebooks'
        if (-not (Test-Path $sessionsDirWt)) { New-Item -ItemType Directory -Path $sessionsDirWt | Out-Null }

        if (-not $PlanFile) {
          $found = Get-ChildItem $workDir -Filter 'AceCommander-Modernization-Plan.md' -ErrorAction SilentlyContinue |
            Select-Object -First 1
          $PlanFile = if ($found) { $found.FullName } else { Join-Path $workDir 'AceCommander-Modernization-Plan.md' }
        }

        # ════════════════════════════════════════════════════════════════════════
        # 2.  Parse decisions from the session doc
        # ════════════════════════════════════════════════════════════════════════

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Parsing decisions...'

        $blocks = [regex]::Split($sessionContent, '(?m)(?=^### SC-\d{4})')
        $itemBlocks = $blocks | Where-Object { $_ -match '(?m)^### SC-(\d{4})' }

        if (-not $itemBlocks) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Tag 'Warning' -Message 'No SC-NNNN blocks found. If this is a TASKS.md-only session, continue.'
        }

        $decisions = foreach ($block in @($itemBlocks)) {
          if ($block -notmatch '(?m)^### (SC-\d{4}) — (.+?)(?:\s*🔁.*)?$') { continue }
          $scId = $Matches[1]
          $title = $Matches[2].Trim()

          $F = { param([string]$P) if ($block -match $P) { $Matches[1].Trim() } else { '' } }

          $decision = ''
          if ($block -match '\[x\]\s*Adopt' -or $block -match '\[X\]\s*Adopt') { $decision = 'Adopt' }
          elseif ($block -match '\[x\]\s*Defer' -or $block -match '\[X\]\s*Defer') { $decision = 'Defer' }
          elseif ($block -match '\[x\]\s*Reject' -or $block -match '\[X\]\s*Reject') { $decision = 'Reject' }
          elseif ($block -match '\*\*Decision\*\*:\s*`?([A-Za-z]+)') { $decision = $Matches[1] }

          [PSCustomObject]@{
            ScId               = $scId
            Title              = $title
            Decision           = $decision
            Rationale          = & $F '\*\*Rationale\*\*:\s*(.+)'
            InsertAt           = & $F '- InsertAt:\s*(.+)'
            ImpactWeeks        = & $F '- ImpactWeeks:\s*(.+)'
            MilestonesAffected = & $F '- MilestonesAffected:\s*(.+)'
            NewProjectEnd      = & $F '- NewProjectEnd:\s*(.+)'
            TasksAdded         = & $F '- TasksAdded:\s*(.+)'
            Context            = & $F '- Context:\s*(.+)'
            DeferredReason     = & $F '- DeferredReason:\s*(.+)'
            DeferredUntil      = & $F '- DeferredUntil:\s*(.+)'
            TriggerCondition   = & $F '- TriggerCondition:\s*(.+)'
            SuggestedBy        = if ($block -match '\*\*SuggestedBy\*\*:\s*([^|]+)') { $Matches[1].Trim() } else { '' }
            SuggestedDate      = if ($block -match '\*\*Date\*\*:\s*([^|]+)') { $Matches[1].Trim() } else { '' }
            Repo               = if ($block -match '\*\*Repo\*\*:\s*([^|]+)') { $Matches[1].Trim() } else { '' }
            InitialSize        = if ($block -match '\*\*Size\*\*:\s*([^\|`n>]+)') { $Matches[1].Trim() } else { '' }
            AdoptedDate        = $sessionDate
            SessionId          = $sessionId
          }
        }

        $undecided = @($decisions | Where-Object { $_.Decision -notin @('Adopt', 'Defer', 'Reject') })
        $decided = @($decisions | Where-Object { $_.Decision -in @('Adopt', 'Defer', 'Reject') })
        $adopted = @($decided | Where-Object Decision -EQ 'Adopt')
        $deferred = @($decided | Where-Object Decision -EQ 'Defer')
        $rejected = @($decided | Where-Object Decision -EQ 'Reject')

        if ($undecided) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Tag 'Warning' -Message "Undecided (skipped): $(($undecided | ForEach-Object { $_.ScId }) -join ', ') — mark with [x] in the session doc and re-run if needed."
        }

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Adopted: $($adopted.Count)  Deferred: $($deferred.Count)  Rejected: $($rejected.Count)  Skipped: $($undecided.Count)"

        # ════════════════════════════════════════════════════════════════════════
        # 3.  Apply decisions to files in the worktree
        # ════════════════════════════════════════════════════════════════════════

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Updating status files...'

        $amendmentBlocks = [System.Text.StringBuilder]::new()
        $adoptedTableRows = [System.Text.StringBuilder]::new()
        $modifiedFiles = [System.Collections.Generic.List[string]]::new()

        foreach ($item in $adopted) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Tag 'Adopt' -Message "ADOPT  $($item.ScId) — $($item.Title)"

          if (updateStatusInFile -FilePath $inboxPath -ScId $item.ScId -NewStatus 'Adopted') {
            if ($inboxPath -notin $modifiedFiles) { $modifiedFiles.Add($inboxPath) }
          }

          $adoptedEntry = @"

### $($item.ScId) — $($item.Title)

- **SuggestedBy**: $($item.SuggestedBy)
- **Context**: $($item.Context)
- **Rationale for adoption**: $($item.Rationale)
- **InsertedAt**: $($item.InsertAt)
- **ImpactWeeks**: $($item.ImpactWeeks)
- **MilestonesAffected**: $($item.MilestonesAffected)

---
"@
          if ($PSCmdlet.ShouldProcess($adoptedPath, "Append $($item.ScId)")) {
            Add-Content -Path $adoptedPath -Value $adoptedEntry -Encoding UTF8
          }
          if ($adoptedPath -notin $modifiedFiles) { $modifiedFiles.Add($adoptedPath) }

          $projectEnd = if ($item.NewProjectEnd) { $item.NewProjectEnd } else { $prevEnd }
          $null = $adoptedTableRows.AppendLine(
            "| $($item.ScId) | $($item.Title) | $($item.SuggestedBy) | $($item.SuggestedDate) | " +
            "$($item.AdoptedDate) | $($item.SessionId) | $($item.InsertAt) | $($item.ImpactWeeks) | $projectEnd |")

          $milestoneLine = if ($item.MilestonesAffected -and $item.MilestonesAffected -notmatch '^\(') {
            "| MilestonesAffected | $($item.MilestonesAffected) |"
          } else { '' }
          $tasksAddedLine = if ($item.TasksAdded -and $item.TasksAdded -notmatch '^\(') {
            "| TasksAdded | $($item.TasksAdded) |"
          } else { '' }

          $null = $amendmentBlocks.AppendLine(@"

### ◈ $($item.ScId) — $($item.Title)

| Field | Value |
|-------|-------|
| SuggestedBy | $($item.SuggestedBy) |
| SuggestedDate | $($item.SuggestedDate) |
| AdoptedDate | $($item.AdoptedDate) |
| AdoptedIn | $($item.SessionId) ($sessionDate) |
| InsertedAt | $($item.InsertAt) |
| ImpactWeeks | $($item.ImpactWeeks) |
| PreviousProjectEnd | $prevEnd |
| NewProjectEnd | $($item.NewProjectEnd) |
$(if ($milestoneLine)  { $milestoneLine  + "`n" })$(if ($tasksAddedLine) { $tasksAddedLine + "`n" })
**Rationale:** $($item.Rationale)

**What Changed in the Plan:**

_(Fill in specific task additions and week shifts after editing the plan body)_

---
"@)
        }

        foreach ($item in $deferred) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Tag 'Defer' -Message "DEFER  $($item.ScId) — $($item.Title)"
          updateStatusInFile -FilePath $inboxPath -ScId $item.ScId -NewStatus 'Deferred' `
            -ExtraField 'DeferredReason' -ExtraValue $item.DeferredReason | Out-Null
          if ($inboxPath -notin $modifiedFiles) { $modifiedFiles.Add($inboxPath) }

          $deferredEntry = @"

### $($item.ScId) — $($item.Title)

- **SuggestedBy**: $($item.SuggestedBy)
- **SuggestedDate**: $($item.SuggestedDate)
- **DeferredDate**: $sessionDate
- **DeferredIn**: $($item.SessionId)
- **Repo**: $($item.Repo)
- **InitialSize**: $($item.InitialSize)
- **DeferredUntil**: $($item.DeferredUntil)
- **DeferredReason**: $($item.DeferredReason)
- **TriggerCondition**: $($item.TriggerCondition)

---
"@
          if ($PSCmdlet.ShouldProcess($deferredPath, "Append $($item.ScId)")) {
            Add-Content -Path $deferredPath -Value $deferredEntry -Encoding UTF8
          }
          if ($deferredPath -notin $modifiedFiles) { $modifiedFiles.Add($deferredPath) }
        }

        foreach ($item in $rejected) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Tag 'Reject' -Message "REJECT $($item.ScId) — $($item.Title)"
          updateStatusInFile -FilePath $inboxPath -ScId $item.ScId -NewStatus 'Rejected' | Out-Null
          if ($inboxPath -notin $modifiedFiles) { $modifiedFiles.Add($inboxPath) }
        }

        # ── Update adopted summary table ─────────────────────────────────────────
        if ($adopted.Count -gt 0 -and $adoptedTableRows.Length -gt 0 -and $PSCmdlet.ShouldProcess($adoptedPath, 'Update adopted summary table')) {
          $rows = $adoptedTableRows.ToString().TrimEnd()
          $current = Get-Content $adoptedPath -Raw
          $newContent = $current -replace '\|\s*_\(none yet\)_\s*\|[^\n]*\n', ''
          $newContent = $newContent -replace '(<!-- Full entries appended)', "$rows`n`$1"
          Set-Content -Path $adoptedPath -Value $newContent -Encoding UTF8
        }

        # ── Write amendments file ────────────────────────────────────────────────
        $amendmentsFile = Join-Path $sessionsDirWt "$sessionDate-Amendments.md"

        if ($adopted.Count -gt 0) {
          $planLeaf = if ($PlanFile) { Split-Path $PlanFile -Leaf } else { 'AceCommander-Modernization-Plan.md' }
          $amendHeader = @"
# Plan Amendments — $sessionDate ($sessionId)

Paste the blocks below into the ``## Scope-Creep Amendments`` section at the end of:
``$planLeaf``

After pasting, fill in **What Changed in the Plan** under each ◈ block with the
specific task additions and sprint-number shifts you made in the plan body.

---
"@
          $fullAmendments = $amendHeader + $amendmentBlocks.ToString()
          if ($PSCmdlet.ShouldProcess($amendmentsFile, 'Write amendments file')) {
            Set-Content -Path $amendmentsFile -Value $fullAmendments -Encoding UTF8
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Amendments file: $amendmentsFile"
          }
          $modifiedFiles.Add($amendmentsFile)
        }

        # ── Mark session Complete ────────────────────────────────────────────────
        $updatedSession = $sessionContent -replace '(\| \*\*Status\*\* \| )In-Progress', '${1}Complete'
        if ($PSCmdlet.ShouldProcess($SessionFile, 'Mark session Complete')) {
          Set-Content -Path $SessionFile -Value $updatedSession -Encoding UTF8
        }
        if ($SessionFile -notin $modifiedFiles) { $modifiedFiles.Add($SessionFile) }

        # ── Include all planning artifacts that may have been updated ────────────
        $planningArtifacts = @(
          (Join-Path $workDir 'TASKS.md'),
          (Join-Path $workDir 'README.md'),
          (Join-Path $workDir 'AceCommander-Modernization-Plan.md'),
          (Join-Path $workDir 'Sprint-Duration-Log.md')
        )

        $aiAnalysisDir = Join-Path $workDir 'AI-ConversationAnalysis'
        if (Test-Path $aiAnalysisDir) {
          Get-ChildItem $aiAnalysisDir -Filter 'SprintWorkSession-*AI Conversation Analysis.md' |
            ForEach-Object { $planningArtifacts += $_.FullName }
        }

        Get-ChildItem $workDir -Filter 'AceCommander_Project_State_Conversation_Bookmark_*.md' |
          ForEach-Object { $planningArtifacts += $_.FullName }

        foreach ($artifact in $planningArtifacts) {
          if ((Test-Path $artifact) -and $artifact -notin $modifiedFiles) {
            $modifiedFiles.Add($artifact)
          }
        }

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "File updates complete ($($modifiedFiles.Count) files)"

        # ════════════════════════════════════════════════════════════════════════
        # 4.  Commit everything in the worktree
        # ════════════════════════════════════════════════════════════════════════

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Committing in worktree ($workDir)..."

        $adoptedIds = ($adopted | ForEach-Object { $_.ScId }) -join ', '
        $commitTitle = "plan($sessionId): adopt $($adopted.Count), defer $($deferred.Count), reject $($rejected.Count)"
        $commitBody = if ($adoptedIds) { "Adopted: $adoptedIds" } else { 'No ideas adopted this session.' }
        if ($issueNumber -gt 0) { $commitBody += "`n`nCloses #$issueNumber" }

        try {
          invokeGit $workDir @('add', '-A')
          invokeGit $workDir @('commit', '-m', $commitTitle, '-m', $commitBody)
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Committed: $commitTitle"
        } catch {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Tag 'Warning' -Message "Commit failed (nothing to commit?): $_"
        }

        # ════════════════════════════════════════════════════════════════════════
        # 5.  Push the branch
        # ════════════════════════════════════════════════════════════════════════

        if ($branchName) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Pushing $branchName to origin..."
          try {
            invokeGit $workDir @('push', '-u', 'origin', $branchName)
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Pushed origin/$branchName"
          } catch {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Tag 'Warning' -Message "Push failed: $_ — push manually: git -C '$workDir' push -u origin $branchName"
          }
        }

        # ════════════════════════════════════════════════════════════════════════
        # 6.  Create and merge the PR
        # ════════════════════════════════════════════════════════════════════════

        if (-not $SkipGitHub -and $branchName) {
          if (-not $GhRepo) {
            $GhRepo = (& gh repo view --json nameWithOwner -q '.nameWithOwner' 2>$null)
          }

          $defaultBranch = (& git -C $planningRoot symbolic-ref refs/remotes/origin/HEAD 2>$null) `
            -replace 'refs/remotes/origin/', ''
          if (-not $defaultBranch) { $defaultBranch = 'main' }

          # ── Create PR ──────────────────────────────────────────────────────────
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Creating pull request...'

          $adoptedSummary = if ($adopted.Count -gt 0) {
            ($adopted | ForEach-Object { "- ◈ $($_.ScId): $($_.Title)" }) -join "`n"
          } else { '_(none)_' }

          $prBody = @"
## Planning Session $sessionId — $sessionDate

$(if ($issueNumber -gt 0) { "Closes #$issueNumber`n" })
### Decisions

| Result | Count | IDs |
|--------|-------|-----|
| Adopted | $($adopted.Count) | $(($adopted | ForEach-Object { $_.ScId }) -join ', ') |
| Deferred | $($deferred.Count) | $(($deferred | ForEach-Object { $_.ScId }) -join ', ') |
| Rejected | $($rejected.Count) | $(($rejected | ForEach-Object { $_.ScId }) -join ', ') |

### Adopted Ideas
$adoptedSummary

### Files Changed
$(($modifiedFiles | ForEach-Object { "- $(Split-Path $_ -Leaf)" }) -join "`n")

_Generated by Complete-PlanningSession_
"@

          try {
            if ($PSCmdlet.ShouldProcess("$GhRepo $branchName", 'Create pull request')) {
              $prUrl = & gh pr create `
                --title "Planning Session $sessionId ($sessionDate)" `
                --body $prBody `
                --base $defaultBranch `
                --head $branchName `
                --repo $GhRepo 2>&1

              if ($LASTEXITCODE -eq 0) {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "PR created: $prUrl"
              } else {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Tag 'Warning' -Message "gh pr create returned: $prUrl"
              }
            }
          } catch {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Tag 'Warning' -Message "PR creation failed: $_"
          }

          # ── Merge PR ────────────────────────────────────────────────────────────
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Squash-merging PR...'
          try {
            if ($PSCmdlet.ShouldProcess("$GhRepo $branchName", 'Squash-merge PR and delete branch')) {
              & gh pr merge $branchName `
                --squash `
                --delete-branch `
                --repo $GhRepo 2>&1 | Out-Null
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'PR squash-merged and branch deleted on origin'
            }
          } catch {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Tag 'Warning' -Message "PR merge failed: $_ — merge manually in GitHub."
          }

          # ── Pull main to get the squash commit ──────────────────────────────────
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Pulling main in _Planning repo...'
          try {
            invokeGit $planningRoot @('checkout', $defaultBranch)
            invokeGit $planningRoot @('pull', 'origin', $defaultBranch)
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'main is up to date'
          } catch {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Tag 'Warning' -Message "Could not pull main: $_"
          }
        }

        # ════════════════════════════════════════════════════════════════════════
        # 7.  Remove the worktree
        # ════════════════════════════════════════════════════════════════════════

        if ($worktreePath -and (Test-Path $worktreePath) -and -not $SkipWorktreeRemove) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Removing worktree...'
          try {
            if ($PSCmdlet.ShouldProcess($worktreePath, 'Remove worktree')) {
              & git -C $planningRoot worktree remove $worktreePath --force 2>&1 | Out-Null
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Worktree removed: $worktreePath"
            }
          } catch {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Tag 'Warning' -Message "Could not remove worktree: $_ — remove manually: git -C '$planningRoot' worktree remove '$worktreePath' --force"
          }
        }

        # ════════════════════════════════════════════════════════════════════════
        # 8.  Next-step instructions
        # ════════════════════════════════════════════════════════════════════════

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'NEXT STEPS'

        if ($adopted.Count -gt 0) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "1. Paste amendments into the plan document: $amendmentsFile — open the plan, go to '## Scope-Creep Amendments', paste each ◈ block and fill in 'What Changed in the Plan'."
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message '2. Review TASKS.md and confirm adopted tasks are present.'
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message '3. Verify Conversation Bookmark was generated: AceCommander_Project_State_Conversation_Bookmark_NNN.md'
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message '4. Commit all planning artifacts and create PR from the sprint branch.'
        } else {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'No ideas were adopted. Check TASKS.md for any manual edits. Commit all planning artifacts and create PR from the sprint branch.'
        }

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Planning session $sessionId complete."
      } catch {
        $errorMessage = "Complete-PlanningSession failed. Exception: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        throw
      }
    }

    end {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Leaving function'
    }
  }
}
