# Release notes

## 0.1.31

- Task 14.13: `Save-SprintWorkSession` no longer resolves the Claude Code memory
  directory as a child of whichever project key the transcript search settled on.
  The store is now located independently — the sprint-worktree key is probed
  first, then the stable-repo key — so a checkpoint whose transcript lives at the
  sprint key and whose memory lives only at the stable key captures memory
  instead of silently reporting success with zero files. The sprint key always
  wins when both exist, so a live sprint store is never shadowed by a staler
  stable one, and the key that supplied the memory is recorded in the roster as
  `MemorySourceKey`.
- Task 14.13: memory skips are now discriminated. `MemorySkipKind` is one of
  `None` (the agent has no on-disk memory store — Codex, correct behavior),
  `NotFound` (a store was expected at a known key and was not there — the defect
  above), or `Empty` (the store existed but held nothing). Previously the only
  machine-readable signal was a boolean, so a failed capture and a correct skip
  produced structurally identical roster rows.
- Task 14.13: **behavior change** — `Save-SprintWorkSession` now returns the
  roster entry as a `PSCustomObject` (`OutputType` changed from `[void]`), so a
  caller sees an unexpected `NotFound` without reading PSFramework output.
  Callers that invoke it as a statement now emit that object to the pipeline;
  suppress with `| Out-Null` where the output is unwanted.
- Task 14.14: `Convert-TasksMdToSprintBoard` derives its default `-OutputPath`
  from the input file name instead of a fixed `TASKS.html`. Regenerating a dotted
  sprint board without an explicit output path now updates
  `Tasks.SprintNNNN.html` rather than writing a stray `TASKS.html` and leaving
  the real board stale while reporting success. Backward compatible: a legacy
  `TASKS.md` still derives `TASKS.html`. `-OutputPath` now accepts an empty
  string (validator relaxed from `ValidateNotNullOrEmpty` to `AllowEmptyString`)
  and treats it, like a whitespace-only value, as "not supplied".

## 0.1.29

- Task 14.10: add Test-SprintEndWriteTarget and New-SprintEndDefectRoute,
  and gate the SprintEnd close plan so a stable worktree substituted into
  WorktreePaths is rejected before any phase runs. Defects discovered during
  a close route to the active sprint worktree or to a durable next-sprint input
  under the _Planning sprint worktree, never to a stable checkout.
- Task 14.11: add Get-SprintEndApprovalPlan. Pull-request merge
  authorization is recorded once through -MergeAuthorizationConfirmed
  instead of re-evaluated by each layer that can prompt; a delegated agent
  relays named authorization provenance or fails closed; and NuGet lock-file
  runner availability becomes a deterministic NotApplicable/Enforced/Blocked
  fact rather than an operator proceed anyway question.
- Task 14.12: add Invoke-SprintEndRehearsal covering the dry-run,
  stable-boundary, crash/resume, and full-close scenarios, with before/after
  stable-worktree snapshots proving the rehearsal changed no stable repository.

## 0.1.27

- Classify committed `SolutionDocumentation/*-Task-N.before.summary.json` and
  `*.after.summary.json` files as historical SprintEnd evidence rather than
  live configuration drift.

## 0.1.26

- Forward the verified checkpoint and user-global write gates from the typed
  SprintEnd lifecycle into the live and `WhatIf` boundary reset.
- Fail closed before boundary mutation when checkpoint coverage was not
  requested or did not pass.

## 0.1.25

- Replace the remoting-health test fixture's `%windir%`-relative plug-in path
  with an explicitly verified missing path beneath Pester `TestDrive`, removing
  the last service-account host-filesystem dependency from the promoted gate.
- Preserve the 0.1.24 injectable probe seam and the production default provider
  unchanged.

## 0.1.24

- Make the profiled-remoting boundary probe's session-configuration source
  injectable for deterministic tests while preserving
  `Get-PSSessionConfiguration -ErrorAction Stop` as the production default.
- Remove the remoting-health unit fixture's dependency on Pester mocking a core
  remoting cmdlet under the BuildMaster service-account promoted-module host.
- Add adversarial coverage proving the production default remains real and an
  injected provider failure is reported as an unsuccessful probe.

## 0.1.23

- Package the private `Set-UserSettingsSymlink` bridge with SprintLifecycle so
  an exact child-module import can perform the machine settings boundary without
  relying on the umbrella module's private session state.
- Detect enabled PowerShell 7 session configurations whose registered plug-in
  file is missing, resolve the canonical binary from the unversioned
  `$PSHOME\pwrshplugin.dll`, and return bounded repair guidance for the existing
  WSMan entries without enabling remoting or creating another endpoint.

## 0.1.22

- Add `Disabled`, `Auto`, and `Required` profiled-remoting policies to sprint
  boundary orchestration. `Auto` is the safe default and treats hosts without a
  remoting surface or managed endpoint state as not applicable without enabling
  remoting; existing or required endpoint state remains a strict failure gate.
- Propagate the policy through SprintEnd lifecycle, cleanup, handoff generation,
  and structured boundary evidence.

## 0.1.21

- Preserve the compatible installed `Set-UserScopeProfile` command during
  boundary profile deployment; load the stable-source fallback only when the
  command is absent, and fail explicitly when the required parameter contract
  is unavailable.

## 0.1.20

- Keep stable repository worktrees read-only before SprintEnd PR merge by
  materializing stable-only adapter projections into the outgoing sprint
  branches for review and commit.
- Replace the fixed two-render assumption with a bounded five-pass convergence
  gate that records every pass and still fails closed when no clean pass is
  reached.
- Resolve an empty automatic current-user profile path through the Windows
  Documents known folder, with a bounded USERPROFILE fallback.

## 0.1.19

- Project the End-boundary preview's planned process-scoped BWS token removal
  into the cleanup health check, then restore the exact prior process value.
  This prevents a false secret-drift failure while preserving the dry run's
  zero-net-mutation contract.

## 0.1.18

- Keep the SprintEnd cleanup health check read-only and deterministic under a
  lifecycle `-WhatIf`: transient Bitwarden Secrets Manager environment setup
  is cleaned up instead of being mistaken for persistent secret drift, and the
  cleanup result is reported as planned rather than applied. Live cleanup
  health and mutation gates remain strict.

## 0.1.17

- Treat a successful GitHub close preview as planned lifecycle work even when
  the current-state result is not yet `Ok` because its pull request would be
  created by the live run. Live closes continue to fail on any non-OK GitHub
  close result.

## 0.1.16

- Keep the complete SprintEnd lifecycle dry run non-mutating by invoking the
  post-boundary template-reference assertion with `-WhatIf`. Current sprint
  references are reported as a planned-after-boundary preview instead of a
  false dry-run failure; live closes retain the strict merge-gate assertion.

## 0.1.14

- Isolate the SprintEnd resumability unit test from live service-account profile management under the BuildMaster service identity.

## 0.1.13

- Resolve service-account ownership from the authenticated Windows identity token rather than the inheritable USERNAME environment variable.
- Add an explicit current-identity test seam for deterministic least-privilege coverage.

## 0.1.12

- Limit fallback service-account discovery to the three approved ReadOnly identities.
- Prevent an approved service identity from managing peer service-account profiles; operator shells retain the three-account deployment path.

## 0.1.11

- `Set-SprintBoundaryUserProfiles` now loads `Set-UserScopeProfile` from the caller-selected
  ATAP.Utilities worktree, preventing an installed parent module from silently supplying a
  stale implementation during sprint-boundary deployment.
- When ConfigRootKeys do not describe established service identities, discovery merges only
  approved local accounts that actually exist. The fixed policy remains bounded to
  `SvcBuildMaster`, `SvcProGet`, `SvcSQLServer`, `SvcSeq`, and `SvcParityAudit`; absent
  accounts are ignored and no broad local-account enumeration is introduced.
- Added regression coverage proving `SvcBuildMaster`, `SvcProGet`, and `SvcSQLServer` are
  discovered with the required secret policy when configuration discovery omits them.
## 0.1.10

- `Set-SprintBoundaryContext -Boundary Start` now provisions the durable AI agent memory
  junction for every sprint worktree it creates (Task 13.88), via the new private helper
  `Set-AIAgentMemoryJunction`. Because both `New-SprintStage1` and `New-SprintStage2`
  delegate per-worktree provisioning to this function, `_Planning` and every downstream
  repo are covered by the one hook.
- **Why this exists.** Claude Code and the checkpoint tooling resolve DIFFERENT project
  slugs under `~\.claude\projects\`. Claude Code derives its slug from
  `git rev-parse --git-common-dir`, so from a worktree it resolves to the MAIN repository;
  `Save-SprintWorkSession` derives its path from the transcript slug, which IS the sprint
  worktree. Left alone the two never meet, and the failure is **silent** —
  `Save-SprintWorkSession` reports `MemorySnapshotCreated = $false` with reason
  "Memory directory not found" and still exits successfully, so checkpoints look healthy
  while archiving zero memory files. Sprint 0013 lost three consecutive checkpoints to it.
  The helper junctions BOTH slugs' `memory` directories at one canonical store.
- The store lives under Dropbox, outside every git repository, so memory survives sprint
  end, reaches every host via Dropbox sync, stays clear of the stable-worktree boundary
  rule, and is never committed to git. Its root is derived from
  `DropboxBasePathConfigRootKey` as `<DropboxBase>\<user>\ATAP\AIAgentMemory`, or supplied
  explicitly with the new `-AIAgentMemoryRoot` parameter.
- **Fails safe in three directions.** When `DropboxBasePathConfigRootKey` is unavailable
  (an agent shell with no PowerShell profile, where `$global:settings` is empty) it SKIPS
  with a recorded reason instead of guessing a path. A pre-existing REAL memory directory
  is migrated into the store rather than clobbered, and a non-empty one that cannot be
  fully migrated aborts instead of destroying files. And a memory-junction failure is
  non-fatal: it is recorded in the per-worktree result as `MemoryJunctionError` and never
  aborts sprint provisioning.
- `Set-SprintBoundaryContext`'s per-worktree result gains `MemoryJunctionCreated`,
  `MemoryStorePath`, and `MemoryJunctionError`.
- New suite `tests/Unit/Set-AIAgentMemoryJunction.Tests.ps1` passes 8/8 against real git
  repos, real worktrees, and real NTFS junctions, covering both-slug creation, shared
  target with a write/read round trip through opposite junctions, main-repo resolution via
  the git common dir for a repo name containing `.` and `_`, idempotent re-runs that
  preserve stored memory, migration of a pre-existing real directory, the config-missing
  skip, a nonexistent worktree, and `-WhatIf`.

## 0.1.6

- `Save-SprintWorkSession` now asserts the conversation archive's **contents** before
  reporting `ConversationArchiveCreated = $true` (Task 13.76.d). Previously the presence
  of the `.7z` file alone was treated as success, so a `7z a` that produced a zero-entry
  archive was recorded as a saved conversation. The archive must now list at least one
  entry and must contain the rollout JSONL by name; either failure is terminating.
- Note for anyone porting the patch published in
  `_Planning/InformationForTheFuture/CodexMisstepFixes/SaveSprintWorkSession-EmptyArchive-Defect.md`:
  that version's entry-count regex (`^\s*\d+\s+\S+`) never matches real `7z l -ba`
  output, whose lines begin with an ISO date, and would therefore have thrown on every
  checkpoint. The shipped implementation counts non-empty listing lines instead.

## 0.1.5

- Add an explicit Stage 2 profile-retarget bypass for isolated validation.
- Require every mutating Stage 2 test to use that bypass, preventing tests from changing machine-wide PowerShell profile links.

## 0.1.4

- Load the complete SprintLifecycle public command surface in SprintEnd tests so clean promoted-module runs can mock every owned command.
- Stub machine-wide PowerShell profile deployment in all mutating Stage 2 tests and enforce that isolation with a static contract test.

## 0.1.0

- Initial empty scaffold.
