# SprintLifecycle module index

- `public/` contains the 34 exported SprintLifecycle commands.
- `private/` contains lifecycle-only helpers.
- `tests/Unit/` contains the migrated focused Pester coverage.
- `version.json` owns the child module's version.
- SprintEnd handoffs use bounded, process-lock-aware worktree teardown and retain a minimal retry handoff on incomplete removal.
