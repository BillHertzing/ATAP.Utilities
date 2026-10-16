# SprintLifecycle module index

- `public/` contains the 40 exported SprintLifecycle commands.
- `private/` contains lifecycle-only helpers.
- `tests/Unit/` contains the migrated focused Pester coverage.
- `version.json` owns the child module's version.
- `ReleaseNotes.md` records the per-version change log; the newest entry is the authority for what a given installed version actually exports.
- SprintEnd handoffs use bounded, process-lock-aware worktree teardown. `Remove-SprintWorktreeSafely` records removal receipts, validates explicit legacy recovery, handles approved junctions and empty cloud-directory remnants nonrecursively, and reconciles selected nested registrations while preserving recovery refs. Incomplete removal retains a minimal retry handoff; see [operator controls](ReadMe.md#receipt-backed-worktree-cleanup).
- SprintEnd write targets are gated by `Test-SprintEndWriteTarget`; discovered defects route through `New-SprintEndDefectRoute` to a sprint worktree or a durable next-sprint input, never to a stable worktree (Task 14.10).
- SprintEnd approval prompts are resolved once by `Get-SprintEndApprovalPlan`; `Invoke-SprintEndRehearsal` rehearses the whole close non-destructively (Tasks 14.11, 14.12).
- `Write-GatherCallRecord` appends one immutable, structured gather-call record per invocation of the canonical `gather-content-summary` agent. By default (`-StoreTarget Durable`) it writes to the **durable** store under the `_Planning` sprint worktree, `InformationForTheFuture/Sprint<NNNN>/<Stream>/<TaskFolder>/gather-calls/`, which survives sprint end; `-StoreTarget Generated` writes the superseded `_generated/.../gather-calls/` layout under the calling worktree, which is deleted at sprint end. It is concurrency-safe without locking: each record is staged to a temp file and published with the two-argument `[System.IO.File]::Move` overload, whose refusal of an existing destination is itself the mutual exclusion, and `Flush($true)` before publish keeps a `*.jsonl` glob from observing a partial file. It generates its own invocation ID (callers cannot supply one), records the response digest and status only rather than the full ContentSummary response, redacts secrets in place without deleting surrounding text, and records unavailable metadata as absent rather than inferring it. `-WorktreeRoot` is required in effect — an omitted root is a terminating error, never a walk-up to the nearest `.git` ancestor. It implements `gather-call-record.contract.v1.md`. **No harvester exists**: the harvesting function (Task 15.183.c) and the SprintEnd integration (Task 15.183.d) were parked on 2026-08-26; see `handoff-correlation.deferred.v1.md`. **It is exported from version 0.1.34 onward**; 0.1.33 and every earlier release exported 39 commands and did not include it, so no installed module could write a record before 0.1.34. In an installed copy the command is not a `public/` file: the published package is a flattened single `.psm1`, and looking for `public\Write-GatherCallRecord.ps1` under an install tree finds nothing. Per-function `public/` files exist only in this source tree. See `ReadMe.md` for the full operator documentation.
- Version 0.1.14 is the accepted two-host deploy state: fallback discovery is limited to the three approved ReadOnly service identities, authenticated service identities manage only their own profile, and operator-driven deployment is idempotent on UTAT01 and UTAT022.
- Task 16.11 source: the settings helper provides transactional metadata and recovery with target/readability verdicts; SprintStart uses the actual SharedVSCode root, and SprintEnd selects stable settings and audits links independently before cleanup. Source validation: 236 passed, 0 failed; packaging and both-host acceptance remain in Task 16.12.

Task 16.12 release replacement 0.1.47 isolates the settings audit in unrelated
SprintEnd unit fixtures and retains the real fail-closed settings regressions.
UTAT022 installed acceptance is recorded in the Planning Task16.12 deployment
handoff; UTAT01 remains separately scoped under Task16.64.

Version 0.1.48 bounds retries of transient atomic receipt-replacement failures
without repeating worktree removal. Persistent denial preserves the prior receipt
and fails closed after six attempts; no permission or attribute changes are made.

Version 0.1.49 adds `private/Complete-SprintWorktreeNativeRemoval.ps1` for the
exact captured Git255 empty administrative-slot deletion failure. Recovery
retains the failed native result, validates identity before each nonrecursive
delete, and requires recorded completion on resume. Unknown failures remain blocked.
