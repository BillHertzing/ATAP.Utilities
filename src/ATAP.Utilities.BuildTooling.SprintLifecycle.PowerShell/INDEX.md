# SprintLifecycle module index

- `public/` contains the 38 exported SprintLifecycle commands.
- `private/` contains lifecycle-only helpers.
- `tests/Unit/` contains the migrated focused Pester coverage.
- `version.json` owns the child module's version.
- SprintEnd handoffs use bounded, process-lock-aware worktree teardown and retain a minimal retry handoff on incomplete removal.
- SprintEnd write targets are gated by `Test-SprintEndWriteTarget`; discovered defects route through `New-SprintEndDefectRoute` to a sprint worktree or a durable next-sprint input, never to a stable worktree (Task 14.10).
- SprintEnd approval prompts are resolved once by `Get-SprintEndApprovalPlan`; `Invoke-SprintEndRehearsal` rehearses the whole close non-destructively (Tasks 14.11, 14.12).
- Version 0.1.14 is the accepted two-host deploy state: fallback discovery is limited to the three approved ReadOnly service identities, authenticated service identities manage only their own profile, and operator-driven deployment is idempotent on UTAT01 and UTAT022.
