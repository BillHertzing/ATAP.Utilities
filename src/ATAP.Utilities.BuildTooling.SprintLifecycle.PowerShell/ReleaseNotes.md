# Release notes

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
