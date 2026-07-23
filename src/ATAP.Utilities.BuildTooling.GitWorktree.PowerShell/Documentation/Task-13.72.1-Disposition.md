# Task 13.72.1 GitWorktree disposition

The frozen scope is the 15 files and 16 functions listed in the Planning Phase 4 group-order record. The child exports thirteen public commands; the three private helpers remain internal.

The refreshed AST inventory reports no top-level executable code and no `Write-Host` use for this group. No SC-0248 source correction is approved beyond path/import changes required by the move. Six matching functional test files move with their owning batches; missing public smoke contracts are added in the child.

All four sprint worktrees are present. Eight SharedVSCode `.ai` canonical files reference GitWorktree command names. Each is reviewed before editing: command-name-only references retain compatibility through the parent and need no module-path change; any source-path or explicit import must move to the child and be rendered. Generated adapters are never hand-edited.

Only Task 13.72.1 owns the parent manifest/psm1 rewire. Parent implementation copies are removed only as each reviewed batch lands; the compatibility surface remains complete through child proxies.
