# Release notes

## 0.1.2

- Made the public contract test honor `ATAP_PROMOTED_MODULE_MANIFEST` so tier
  gates test the supplied immutable package rather than the source copy.
- Proved child import preserves the compatibility parent's pre-existing load
  state instead of assuming a clean BuildMaster host.
- Replaces burned 0.1.1, whose Development promoted test exposed the
  host-contamination assumption.

## 0.1.1

- Declared an explicit empty `VariablesToExport` contract required by packaged
  manifest generation.
- Added regression coverage for all empty non-function export collections.
- Replaces burned 0.1.0, whose first Experimental build failed before package
  publication.

## 0.1.0

- Created the child scaffold and moved the three frozen PlanningSession commands.
- Declared GitWorktree 0.1.3 for Planning-root resolution and
  ATAP.Utilities.Powershell 0.1.23 for `Get-PVal`.
- Split resolver coverage to GitWorktree ownership while retaining the four
  `Add-ScopeCreepIdea` functional contexts in PlanningSession.
- Corrected the pre-existing nested wrapper around `Complete-PlanningSession`
  so its public parameter contract is active.
