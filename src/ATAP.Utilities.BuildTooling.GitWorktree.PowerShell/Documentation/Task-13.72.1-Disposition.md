# Task 13.72.1 GitWorktree disposition

The frozen scope is the 15 files and 16 functions listed in the Planning Phase 4 group-order record. The child exports thirteen public commands; the three private helpers remain internal.

The refreshed AST inventory reports no top-level executable code and no `Write-Host` use for this group. No SC-0248 source correction is approved beyond path/import changes required by the move. Six matching functional test files move with their owning batches; missing public smoke contracts are added in the child.

All four sprint worktrees are present. Eight SharedVSCode `.ai` canonical files reference GitWorktree command names. Each is reviewed before editing: command-name-only references retain compatibility through the parent and need no module-path change; any source-path or explicit import must move to the child and be rendered. Generated adapters are never hand-edited.

Only Task 13.72.1 owns the parent manifest/psm1 rewire. Parent implementation copies are removed only as each reviewed batch lands; the compatibility surface remains complete through child proxies.

## Batch 1 evidence

Batch 1 moved the three private ownership/workspace helpers and the two public validation commands into the child. The three existing functional test files moved with their owners, and `Confirm-GitFSCK.Tests.ps1` now covers its frozen parameters and empty-repository behavior.

The migration's adversarial pass found and corrected a pre-existing `Confirm-GitFSCK` writability-probe defect: the output directory and `test.txt` were concatenated without a separator. The probe now uses `Join-Path`.

- PowerShell parser: 0 errors across the child module.
- Manifest validation: passed for version 0.1.1.
- Focused Pester gate: 23 passed, 0 failed across the scaffold contract and four Batch 1 test files.

## Batch 2 evidence

Batch 2 moved the adapter conversion command, repository integrity scanner, grouped commit command, and the post-checkout/post-commit hook commands. The conversion and commit suites moved with their owners. A child-owned Batch 2 contract adds safe behavior coverage for an empty repository collection, export coverage for both hooks, and AST proof that all five files remain function-only.

The dependency adversarial pass confirmed that `Invoke-GitCommit` calls `Assert-LockFilesClean`, which remains assigned to ParentResidual. Aggregate-parent execution continues to supply that command. The child test injects the contract into child module scope so the per-group guard call is verifiable without importing the parent. The ParentResidual review must decide whether the guard becomes a Common primitive or remains an explicitly documented aggregate-only runtime contract before claiming fully standalone child behavior.

- PowerShell parser: 0 errors across the child module.
- Complete child Pester gate after Batch 2: 34 passed, 0 failed across eight test files.
