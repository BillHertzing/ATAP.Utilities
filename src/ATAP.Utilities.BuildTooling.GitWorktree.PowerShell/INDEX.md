# GitWorktree child module index

- `public/` contains fourteen interim exported commands across twelve source files. `Start-LocalPowerShellModuleBuildMasterPoller` remains here temporarily because its source file also owns two Git helpers; the BuildMaster iteration must split and assume it.
- `private/` contains worktree pointer, workspace-owner, and Planning-root helpers.
- `tests/Unit/` owns module/export/dependency contracts and moved functional tests.
- `Documentation/Task-13.72.1-Disposition.md` records batch ownership, consumer review, and SC-0248 results.
