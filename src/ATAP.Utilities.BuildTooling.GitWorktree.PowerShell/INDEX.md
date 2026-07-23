# GitWorktree child module index

- `public/` contains fourteen interim exported commands across fourteen source files. `Start-LocalPowerShellModuleBuildMasterPoller` remains here temporarily while the BuildMaster iteration is pending; its two Git helpers are packaged as separate GitWorktree commands.
- `private/` contains worktree pointer and workspace-owner helpers.
- `public/Resolve-PlanningWorktreeRoot.ps1` is a child-only dependency contract
  for PlanningSession and is not re-exported by the compatibility parent.
- `tests/Unit/` owns module/export/dependency contracts and moved functional tests.
- `Documentation/Task-13.72.1-Disposition.md` records batch ownership, consumer review, and SC-0248 results.
- Stable/AllUsers release: 0.1.2, fourteen exported commands; 0.1.0 and 0.1.1 are burned.
