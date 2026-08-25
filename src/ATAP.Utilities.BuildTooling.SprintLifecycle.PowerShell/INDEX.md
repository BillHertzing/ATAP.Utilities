# SprintLifecycle module index

- `public/` contains the 40 exported SprintLifecycle commands.
- `private/` contains lifecycle-only helpers.
- `tests/Unit/` contains the migrated focused Pester coverage.
- `version.json` owns the child module's version.
- SprintEnd handoffs use bounded, process-lock-aware worktree teardown and retain a minimal retry handoff on incomplete removal.
- SprintEnd write targets are gated by `Test-SprintEndWriteTarget`; discovered defects route through `New-SprintEndDefectRoute` to a sprint worktree or a durable next-sprint input, never to a stable worktree (Task 14.10).
- SprintEnd approval prompts are resolved once by `Get-SprintEndApprovalPlan`; `Invoke-SprintEndRehearsal` rehearses the whole close non-destructively (Tasks 14.11, 14.12).
- `Write-GatherCallRecord` appends one immutable, structured gather-call record per invocation of the canonical `gather-content-summary` agent, under the calling sprint worktree's `_generated/.../gather-calls/` store. It is concurrency-safe without locking: each record is staged to a temp file and published with the two-argument `[System.IO.File]::Move` overload, whose refusal of an existing destination is itself the mutual exclusion, and `Flush($true)` before publish keeps a `*.jsonl` glob from observing a partial file. It generates its own invocation ID (callers cannot supply one), records the response digest and status only rather than the full ContentSummary response, redacts secrets in place without deleting surrounding text, and records unavailable metadata as absent rather than inferring it. It implements `gather-call-record.contract.v1.md` and is consumed by the harvester (Task 15.183).
- Version 0.1.14 is the accepted two-host deploy state: fallback discovery is limited to the three approved ReadOnly service identities, authenticated service identities manage only their own profile, and operator-driven deployment is idempotent on UTAT01 and UTAT022.
