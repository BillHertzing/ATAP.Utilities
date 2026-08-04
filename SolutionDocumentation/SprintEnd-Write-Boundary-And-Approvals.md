# SprintEnd write boundary, approval determinism, and close rehearsal

Sprint 0014, Stream B (Tasks 14.10, 14.11, 14.12).

This document is the authority for three related SprintEnd behaviors: where a
close is allowed to write, which close concerns may ask the operator anything,
and how a close is rehearsed before it runs for real.

---

## 1. The stable-worktree write boundary (Task 14.10)

### 1.1 What happened

During the Sprint 0013 close, remediation changes reached stable worktrees.
Stable worktrees are supposed to receive sprint content exactly one way -- by
merging the sprint branch -- so a close that edits them produces content that
exists in stable but in no sprint branch, and is therefore invisible to review
and lost or duplicated at the next merge.

### 1.2 Root cause

There was no single place that asked "is this write target a sprint worktree?"
before a mutation ran. Instead:

- **Each cmdlet derived its own stable/sprint paths.** `Set-SprintBoundaryContext`
  strips the `-wt-<n>-Sprint-<nnnn>-work-items` suffix to find the stable repo;
  other cmdlets re-derived the same relationship independently. There was no
  shared rule, so there was no shared enforcement.

- **A stable path substituted into a worktree list was only caught
  incidentally.** The Sprint 0012 close incident (CP06-D02) added a guard, but
  it lived inside one cmdlet's per-worktree loop and only fired for the specific
  case where the derived stable path equalled the supplied worktree path. A
  stable path reaching any other phase was not checked at all.

- **A discovered defect had no legal destination.** When a close found a real
  bug in a file, the shortest path to "fix it" was to edit the stable checkout,
  because after merge that is where the file lives. Nothing offered a better
  option, and "don't do that" was a rule in prose rather than a behavior in
  code.

The three causes compound: no shared rule, no single gate, and no legal
alternative.

### 1.3 The correction

**One rule.** `Get-SprintWorktreeClassification` (private) is the only place
that decides what a path is. A repository folder directly beneath the Git root
whose leaf matches `<repo>-wt-<issue>-Sprint-<nnnn>-work-items` is a sprint
worktree. Any other repository folder beneath the Git root is a stable worktree.
Anything else is `OutsideGitRoot`. It is a pure path function, so a planned or
deleted path classifies identically to a live one.

**One gate.** `Test-SprintEndWriteTarget` classifies every intended write target
and blocks anything that is not a sprint worktree. `Invoke-SprintEndLifecycle`
calls it on the whole close plan before any phase runs, so a stable path fails
the close immediately rather than surfacing from inside whichever helper touches
it first. Paths outside the Git root are blocked unless the caller names them in
`-AllowedOutsideGitRootPath`; that allowance exists for genuinely machine-global
state (user profiles, machine settings), and it cannot reach a stable worktree
because a stable worktree is inside the Git root by construction.

**One legal destination.** `New-SprintEndDefectRoute` routes a discovered defect
deterministically:

| Affected paths | Route | Effect |
| --- | --- | --- |
| All inside sprint worktrees | `SprintWorktree` | Fix on the sprint branch before its PR merges. No file written. |
| Any stable, outside the Git root, or none supplied | `NextSprintInput` | A durable Markdown record under the _Planning **sprint** worktree at `InformationForTheFuture\Sprint<NNNN>\SprintEnd-Defects\<DefectId>.md`. |

The record goes in the _Planning sprint worktree, not `_generated`, because it
is an input to future work rather than evidence of past work (repository rule
R-38): it survives worktree teardown by merging with `_Planning`. `PlanningRoot`
is itself gated -- writing a next-sprint input into the stable `_Planning`
checkout would reintroduce exactly the defect this cmdlet prevents. Re-running
with identical content is a no-op; re-running with different content preserves
the existing human-reviewed record and reports a conflict unless `-Force` is
given.

### 1.4 Regression coverage

`tests/Unit/SprintEndStableWorktreeBoundary.Tests.ps1` (21 tests). The
load-bearing cases:

- A stable repository substituted into the close plan fails the lifecycle and
  **no** mutation phase runs -- boundary reset, GitHub close, infrastructure
  cleanup, and handoff are all mocked to throw and all are asserted uninvoked.
- A file deep inside a stable worktree classifies by its repository folder, not
  by its leaf, so `.../ATAP.Utilities/src/.../Some-Function.ps1` is blocked.
- A path that has never existed on disk is gated exactly like a real one, so a
  *planned* stable write is refused before it becomes an actual one.
- A sibling directory whose name merely starts with the Git root string
  (`...\GitHubBackup\...`) is not treated as a child of it.
- An allowance entry naming a stable worktree does not unblock it.
- A defect against stable content produces a next-sprint record and writes
  nothing whatsoever into any stable worktree.

### 1.5 Known limitations

Stated plainly so the next agent does not assume more coverage than exists:

- **Symbolic links and NTFS junctions are not followed.** The classifier is a
  pure path function, so a link inside a sprint worktree whose target is a
  stable worktree classifies by its literal path and is allowed. Resolving links
  would require filesystem access and would forfeit the ability to gate *planned*
  paths, which is the more valuable property — a planned stable write is refused
  before it becomes an actual one. Sprint worktree junctions are provisioned by
  `Set-SprintBoundaryContext` and cover `.vscode` only.
- **8.3 short names are not expanded.** A path written as `C:\Repos\ATAP~1`
  classifies by that literal name.
- **Sprint number is not checked.** A leftover worktree from an earlier sprint
  classifies as a sprint worktree. Closing the correct sprint is
  `Get-SprintEndContext`'s job, not this gate's.

What *is* covered, and regression-tested: relative traversal that escapes a
sprint worktree into a stable one, case differences, forward versus backslash
separators, trailing separators, a sibling directory whose name merely starts
with the Git root string, and near-miss worktree names that omit the four-digit
sprint token.

---

## 2. Approval determinism (Task 14.11)

Three approval messages in the Sprint 0013 close asked the operator something
they had, in substance, already answered. Each has a distinct cause and a
distinct correction. `Get-SprintEndApprovalPlan` reports all three as data:
`Concern`, `Cause`, `Decision`, `PromptRequired`, `Boundary`, `Detail`.

### 2.1 PR-specialist merge approval

**Cause.** `Invoke-SprintEndGitHubClose` declares `ConfirmImpact = 'High'`, and
the orchestrator, the delegated PR specialist, and the interactive shell each
evaluate that impact against their own `$ConfirmPreference`. One authorized
merge therefore produced one prompt per evaluation layer. Nothing was wrong with
any single prompt; the defect is that authorization was re-derived instead of
recorded.

**Correction.** Authorization is recorded once. `-MergeAuthorizationConfirmed`
on `Invoke-SprintEndLifecycle` states that the operator approved this close's
merge at the dry-run gate; downstream calls then run `-Confirm:$false` and must
not re-ask.

**Authority is not widened.** `-MergeAuthorizationConfirmed` without
`-MergePullRequests` still decides `NotRequested` -- it cannot authorize a merge
nobody asked for. A **live** merge without recorded authorization now fails with
`MergeAuthorizationRequired` rather than falling back to a prompt: the close
refuses instead of quietly re-asking. A dry run plans the merge without the
authorization, because `-WhatIf` mutates nothing. The concern is reported at the
`Merge` boundary in every state, including the suppressed one.

### 2.2 Delegated-agent relayed authorization

**Cause.** A delegated PR/version-control agent re-raised authorization it had
already been handed, because the relay carried no provenance identifying the
approver. A delegate that cannot tell an inherited approval from an
unauthorized request has only one safe move: ask again.

**Correction.** A delegate never prompts. It either relays a named
authorization source (`-DelegatedAuthorizationSource`, for example
`Operator:2026-08-03T09:15:00-06:00`) or the plan fails closed with
`DelegatedAuthorizationSourceMissing`. Missing provenance is a hard stop, not a
re-asked question -- the fix is for the orchestrator to relay the authorization,
not for the delegate to manufacture a new approval surface.

### 2.3 Optional NuGet lock-file runner availability

**Cause.** Runner availability was surfaced as an optional "proceed anyway?"
question. That made the operator's answer change what the guard meant, when
whether the guard is meaningful is a property of the repositories being closed.

**Correction.** No prompt, in any state. A deterministic tri-state:

| Decision | Condition | Effect |
| --- | --- | --- |
| `NotApplicable` | No selected worktree tracks a `packages.lock.json` | Guard skipped as a fact. The lifecycle passes `-SkipLockFileGuard` to `Test-SprintPrerequisites`. |
| `Enforced` | Lock files tracked, guard command available | Guard runs. |
| `Blocked` | Lock files tracked, guard command unavailable | Hard failure `NuGetLockFileRunnerUnavailable`. Repair the module install; never an operator judgement call. |

Applicability is probed read-only with `git ls-files -- *packages.lock.json`.
When a worktree cannot be inspected -- not a Git repository, git unavailable,
transient failure -- applicability is **indeterminate and treated as
applicable**. Failing safe rather than closed: a probe that is only an
optimization must never be why a needed guard is skipped, and must never be why
a close is blocked.

### 2.4 Boundaries that stay explicit

Suppressing a duplicate prompt is not the same as removing a boundary. Every
concern still reports its `Boundary`, and the irreversible, merge, secret, and
external-state boundaries are unchanged:

- A live merge still requires recorded operator authorization.
- Secret operations are untouched by this work; SprintEnd still never deletes
  Bitwarden secrets.
- Infrastructure cleanup still removes sprint databases only and retains the
  permanent SQL Server instances.
- No synthetic "sprint complete" task is ever marked.

### 2.5 Coverage

`tests/Unit/SprintEndApprovalPlan.Tests.ps1` (24 tests), including: identical
inputs produce an identical plan; a recorded authorization cannot widen
authority to an unrequested merge; a whitespace-only authorization source counts
as missing; the lock-file concern raises no prompt in any of its three states;
and the lifecycle refuses a live unauthorized merge without invoking the GitHub
close at all.

---

## 3. Close rehearsal (Task 14.12)

A dry run proves one pass is non-mutating. It does not prove that an interrupted
close can be resumed, that stable worktrees were untouched while it ran, or that
the invariants the close claims actually held.

`Invoke-SprintEndRehearsal` rehearses all four:

| Scenario | What it proves |
| --- | --- |
| `DryRun` | The full-switch pass reports `DryRun` and defers final boundary verification until after live mutations. |
| `StableBoundary` | The close plan contains no stable worktree, through the same gate the live close uses. |
| `CrashResume` | A second identical pass produces the same close plan and the same verdict, so re-entry depends on inputs rather than on how far the first pass got. |
| `FullClose` | Database-only cleanup, retained SQL instances, no Bitwarden secret removal, no synthetic task completion, no planned stable write. |

Every lifecycle pass runs with `-WhatIf`, so the rehearsal is structurally
incapable of merging a PR, deleting a branch, dropping a database, or mutating
external state. On top of that structural guarantee there is a **positive
check**: the stable repositories implied by the close plan are snapshotted
(`HEAD` plus `git status --porcelain`) before and after the rehearsal, and any
difference is reported as `StableWorktreeMutated`. Structure says it cannot
happen; the snapshot proves it did not.

Evidence is written to `<PlanningRoot>\_generated\SprintEnd-Rehearsal\<timestamp>\SprintEnd-Rehearsal.json`
(SC-0033). Point-in-time verification evidence belongs in `_generated`; only
inputs to future work move to `InformationForTheFuture` (R-38).

`tests/Unit/SprintEndRehearsal.Tests.ps1` (13 tests) covers the clean rehearsal
and drives each invariant to failure individually -- a stable worktree in the
plan, a stable worktree mutated mid-rehearsal, a diverging re-entry plan, a
synthetic task completion, a Bitwarden secret removal, and a widened database
cleanup.

---

## 4. Deploy state

The behavior described here is implemented and unit-verified in the Sprint 0014
`ATAP.Utilities` worktree at module version `0.1.29`. It is **not** yet promoted
through the tier ladder or installed AllUsers, so a live SprintEnd run using the
installed Production module does not have it yet. Promotion and installation are
a separate, explicitly authorized step.
