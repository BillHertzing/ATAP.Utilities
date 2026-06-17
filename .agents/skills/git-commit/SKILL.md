---
name: git-commit
description: "Create intentional git commits using Conventional Commits. Use when the user asks to commit completed work or when a task explicitly requires committing."
---

# Git Commit Skill

Use this skill to create intentional Conventional Commits without mixing
unrelated work. Prefer `Invoke-GitCommit.ps1` from the most recent
`ATAP.Utilities` sprint worktree; use explicit path groups whenever a dirty tree
contains changes from more than one task or scope.

RTK guidance is archived and inactive until installation is verified. Use native
Git and PowerShell commands.

## Step 1 - Inspect Repository State

Run native Git and PowerShell commands from the repository being committed:

```powershell
git status --short
git diff --stat
git diff
git diff --staged
git log --oneline -5
git branch --show-current
```

Identify task-owned files and unrelated dirty files before staging anything.
Leave unrelated files unstaged.

## Step 2 - Locate `Invoke-GitCommit.ps1`

Prefer the copy in the most recent `ATAP.Utilities` sprint worktree so
sprint-local fixes take effect immediately; fall back to the main
`ATAP.Utilities` repo.

```powershell
$ghRoot  = 'C:\Dropbox\whertzing\GitHub'
$relPath = 'src\ATAP.Utilities.BuildTooling.PowerShell\public\Invoke-GitCommit.ps1'

$candidate = Get-ChildItem $ghRoot -Directory -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -match '^ATAP\.Utilities-wt-\d+-[Ss]print-\d{4}-' } |
  Sort-Object Name -Descending |
  Select-Object -First 1

$scriptPath = if ($candidate) { Join-Path $candidate.FullName $relPath } else { $null }
if (-not ($scriptPath -and (Test-Path $scriptPath))) {
  $scriptPath = Join-Path $ghRoot "ATAP.Utilities\$relPath"
}
```

## Step 3 - Choose Commit Shape

For a cohesive tree, use one message:

```powershell
Import-Module PSFramework -ErrorAction SilentlyContinue
. $scriptPath
Invoke-GitCommit -Message "feat(scope): add focused capability"
```

For a mixed tree, pass an explicit group plan. Each group stages only its matched
paths, runs the sensitive-file block and lock-file guard, appends the
`Co-Authored-By` footer, and creates its own commit. Dirty paths that are not in
any group are left unstaged.

```powershell
Import-Module PSFramework -ErrorAction SilentlyContinue
. $scriptPath
Invoke-GitCommit -Groups @(
  @{
    Paths = @(
      'src/ATAP.Utilities.BuildTooling.PowerShell/public/Invoke-GitCommit.ps1',
      'src/ATAP.Utilities.BuildTooling.PowerShell/tests/Unit/Invoke-GitCommit.Tests.ps1'
    )
    Message = 'feat(git): split commits by task scope'
  },
  @{
    Paths = @('SolutionDocumentation/**', 'README.md')
    Message = 'docs(git): document grouped commit workflow'
  }
)
```

If the function detects multiple path scopes and only one `-Message` was
supplied, it blocks by default. Use `-ForceSingleCommit` only after the mixed
scope has been reviewed and intentionally accepted.

## Manual Grouped Path

When the scripted path is unavailable or a human needs exact staging control,
manual grouping is first-class:

```powershell
git reset --mixed --quiet
git add -- <task-owned-path-1> <task-owned-path-2>
git diff --staged
git commit -m "<type>(<scope>): <summary>" -m "Co-Authored-By: AI Commit Agent <ai-commit-agent@users.noreply.github.com>"
```

Repeat for each task group. Do not use `git add -A` in a mixed tree.

## Step 4 - Checkpoint After a Successful Commit

> ⚠ **Run `/checkpoint` immediately after a successful commit.** A commit records
> code in git, but it does NOT update the sprint `_Planning` worktree. The
> conversation archive, memory snapshot, and session roster only advance when
> `/checkpoint` runs, so SprintEnd can verify checkpoint coverage by worktree
> name. Skipping it leaves the planning worktree out of sync with the committed
> work.

After the commit(s) report success:

1. Run `/checkpoint` (alias `/cp`) from the same repository root you just
   committed in. It archives the conversation, copies memory files, and appends a
   roster entry to the sprint `_Planning` worktree.
2. If you committed in more than one repository, run `/checkpoint` once per repo
   root (change directory between runs).
3. This satisfies the checkpoint-cadence rule (R-30): checkpoint at completed task
   boundaries, before risky context switches or broad refactors, and always before
   closing the session.

This step is a reminder, not a blocker: the commit is already durable. But do not
end a work session on a commit without a following `/checkpoint`.

## Conventional Commits Reference

```text
<type>(<scope>): <summary>

[optional body - wrap at 72 chars]

[optional footer - BREAKING CHANGE: ..., Closes #42]
```

Use `feat`, `fix`, `docs`, `refactor`, `chore`, `test`, `style`, `perf`, or
`ci`. Keep the subject line at or under 72 characters, use imperative mood, and
do not add a trailing period.

## Guardrails

- Never commit secrets, `.env` files, private keys, `node_modules/`, `bin/`, or
  `obj/` outputs.
- Never use `git reset --hard`, `git clean`, or checkout/restore to discard user
  work unless the user explicitly asks.
- Run the lock-file guard for every scripted commit unless the caller explicitly
  passes `-SkipLockFileGuard` and records why.
- Report the commit hash, commit message, staged file count, and files left
  unstaged.
- After a successful commit, run `/checkpoint` (alias `/cp`) so the sprint
  `_Planning` worktree (conversation archive, memory snapshot, session roster)
  stays synchronized with the committed work (see Step 4).
