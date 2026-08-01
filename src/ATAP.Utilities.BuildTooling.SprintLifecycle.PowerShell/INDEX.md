# SprintLifecycle module index

- `public/` contains the 34 exported SprintLifecycle commands.
- `private/` contains lifecycle-only helpers.
- `tests/Unit/` contains the migrated focused Pester coverage.
- `version.json` owns the child module's version.
- SprintEnd handoffs use bounded, process-lock-aware worktree teardown and retain a minimal retry handoff on incomplete removal.
- Version 0.1.14 is the accepted two-host deploy state: fallback discovery is limited to the three approved ReadOnly service identities, authenticated service identities manage only their own profile, and operator-driven deployment is idempotent on UTAT01 and UTAT022.
