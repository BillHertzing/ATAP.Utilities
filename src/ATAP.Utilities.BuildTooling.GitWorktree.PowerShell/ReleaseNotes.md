# Release notes

## 0.1.0

- Created the GitWorktree child scaffold and moved all frozen implementation batches.
- Preserved the parent `Start-LocalPowerShellModuleBuildMasterPoller` contract with one interim export pending the BuildMaster file split, for fourteen explicit child exports total.
- Corrected 0.1.1 packaging so both public poller Git helpers are emitted as distinct command files; 0.1.0 is burned after its Development artifact exposed only twelve commands.
- Corrected the promoted-test import contract in 0.1.2 so the harness tests its supplied package manifest without loading a duplicate module; 0.1.1 is burned after its Development test gate reported six duplicate-module failures.
- Declared Common 0.1.5 as the minimum child dependency.
- Added stable-release NBGV metadata and the Task 13.72.1 scaffold contract.

## 0.1.0

- Initial empty scaffold.
