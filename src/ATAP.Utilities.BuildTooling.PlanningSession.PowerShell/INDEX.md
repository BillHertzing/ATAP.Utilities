# PlanningSession child module index

- `public/` owns `Add-ScopeCreepIdea`, `Start-PlanningSession`, and
  `Complete-PlanningSession` in one reviewed move batch.
- `tests/Unit/` owns the scaffold/dependency and public-surface contracts plus
  four `Add-ScopeCreepIdea` functional contexts.
- The module depends on GitWorktree 0.1.3 or later for the public
  `Resolve-PlanningWorktreeRoot` contract.
- The compatibility parent re-exports only the three PlanningSession commands;
  it does not re-export the resolver.
