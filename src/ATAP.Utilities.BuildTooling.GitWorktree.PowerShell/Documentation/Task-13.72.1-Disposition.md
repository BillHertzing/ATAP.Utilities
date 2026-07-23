# Task 13.72.1 GitWorktree disposition

The frozen scope began as the 15 files and 16 functions listed in the Planning Phase 4 group-order record. The compatibility gate exposed a cross-group function/file overlap in `Start-LocalPowerShellModuleBuildMasterPoller.ps1`: its two Git helpers were assigned to GitWorktree while the `Start-LocalPowerShellModuleBuildMasterPoller` entry was assigned to BuildMaster. Because the implementation file moved as one reviewed unit, the GitWorktree child temporarily exports fourteen public commands; BuildMaster must split and assume the `Start-*` command in its later iteration. The three private helpers remain internal.

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

## Batch 3 evidence

Batch 3 moved the pre-commit hook, issue/worktree commands, junction command, and the local BuildMaster poller file. The junction suite moved with its owner. The child-owned Batch 3 contract verifies all six exported commands supplied by these five implementation files, exercises both Git poller helpers against a temporary local repository, previews issue creation without calling `gh`, and repeats the function-only AST assertion.

The dependency adversarial pass identified two late-bound runtime contracts not represented by the child manifest: `New-GitHubIssue` resolves `Get-PVal` from the configured host, and `Start-LocalPowerShellModuleBuildMasterPoller` invokes `Start-BuildMasterPackagePipeline` only when a qualifying change is detected. These remain aggregate/toolchain contracts for this iteration and must be revisited when ParentResidual and BuildMaster ownership are finalized; they are not silently declared as Common dependencies. The parent compatibility test proved why the interim `Start-*` export is necessary: omitting it reduced the frozen 200-function surface to 199.

- PowerShell parser: 0 errors across the complete child module.
- Manifest validation: passed for source version 0.1.0.
- Complete child Pester gate after Batch 3: 39 passed, 0 failed across ten test files.

## Parent rewire evidence

The parent psm1 now creates contract-preserving proxies for an ordered list of child modules instead of hard-coding the PesterScaffolding child. The parent manifest and family metadata declare GitWorktree 0.1.0 alongside PesterScaffolding 0.1.1.

- Focused compatibility Pester gate: 3 passed, 0 failed.
- Fresh source import: exactly 200 parent functions and five source-manifest aliases.
- `Invoke-GitCommit` retains its named `RepoPath` parameter through the proxy.
- `Start-LocalPowerShellModuleBuildMasterPoller` remains present in the frozen parent surface.
- The two new child-only poller helpers remain intentionally excluded from the parent manifest.
- Combined child, compatibility, and family-metadata Pester gate: 46 passed, 0 failed across twelve test files.

## Consumer evidence

Eight SharedVSCode canonical `.ai` files referenced GitWorktree commands. Seven are command-name-only consumers and require no edit because the parent compatibility surface remains stable. The canonical `git-commit` skill contained two explicit parent source paths; both now point to the GitWorktree child. The governed render updated all four agent adapters, a second render changed zero files, and instruction drift reports zero drift and zero missing targets.
