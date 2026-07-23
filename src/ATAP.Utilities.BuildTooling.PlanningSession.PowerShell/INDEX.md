# PlanningSession child module index

- `public/` will own `Add-ScopeCreepIdea`, `Start-PlanningSession`, and
  `Complete-PlanningSession` in one reviewed move batch.
- `tests/Unit/` owns the scaffold/dependency contract and moved functional tests.
- The module depends on GitWorktree 0.1.3 or later for the public
  `Resolve-PlanningWorktreeRoot` contract.
