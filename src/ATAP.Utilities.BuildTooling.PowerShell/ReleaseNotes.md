# Production Release Notes in Chronological order

# 0.1.53

- Re-exported the three PlanningSession commands through the compatibility
  parent while moving their implementations into the deployed child module.
- Raised the PlanningSession dependency floor to the independently validated
  Stable/AllUsers 0.1.2 release.
- Kept `Resolve-PlanningWorktreeRoot` child-only while preserving the exact
  legacy parent command surface.
- Accepted after all BuildMaster stages passed 593/0/4 of 597, an independent
  Stable matrix passed 597/0/4 of 601, and a fresh AllUsers process recovered
  all 200 legacy functions plus three child-only helpers.

# 0.1.52

- Made private GitWorktree dispatch shims explicitly restore the deployed child
  when an isolated test or consumer unloads it.
- Accepted after all BuildMaster stages, an independent Stable matrix of 610
  passed/0 failed/4 skipped, and an AllUsers fresh-process surface validation.

# 0.1.51

- Added private parent dispatch shims for GitWorktree helpers still consumed by
  remaining parent Sprint and scope-creep commands.
- Updated parent tests to load moved GitWorktree implementations from their
  canonical child source paths.
- Burned after independent Stable testing exposed three load-order failures.

# 0.1.50

- Re-exported the GitWorktree child through the parent compatibility surface.
- Raised the GitWorktree dependency floor to the deployed 0.1.2 release, whose
  Stable package preserves all fourteen child exports.
- Burned after the Development source gate reported 22 stale-path/private-helper
  failures.

# 0.1.49

- Preserved the legacy `Get-ServiceAccountBWSAccessToken` and
  `Initialize-ServiceAccountBWSAccessToken` aliases in flattened package output.
- Added a packaging-contract regression for both compatibility aliases.

# 0.1.48

- Made the BuildMaster readiness probe's secret-name default independent of global settings.
- Added absent and incomplete global-settings regressions for the readiness probe.

# 0.1.47

- Made explicit ProGet promotion inputs independent of profile-populated global settings.
- Added regressions for absent settings and settings maps without promotion keys.
- Raised the PesterScaffolding child dependency floor to the deployed 0.1.1 release.

## 0.2.0 - VersionJsonAsCeiling (Sprint 0007)

- Added `CurrentTier`, `CeilingTier`, and `IsAtCeiling` to `Get-BuildContext`.
- Kept `Get-BuildContext.Tier` as a deprecated alias for `CeilingTier`.
- Added `Get-TierOrder` and `Test-PromotionWithinCeiling`.
- Added optional `-CeilingTier` guard support to `Promote-ProGetPackage`.
- Updated `Get-TierFromNBGVLabel` compatibility behavior for feature-label ceilings and canonical `Production` tier naming.

## Template ToDo: Fix up release notes template

Template for release notes, edit before production release
%moduleName%
%moduleversion%
%releasedate%
%sha256%
%checksumURL%
%SWBOM%

## 🗪 Test Coverage & Results

- **Coverage:** $Coverage% of code paths covered
- **Tests run:** $Total total
  - ✅ Passed: $Passed
  - ❌ Failed: $Failed
  - ⚠️ Skipped: $Skipped

## Must have another level 2 chapter here

stuff
# 0.1.45

- Added checked-in `ModuleFamily.psd1` metadata and deterministic family build selection.
- Added the empty BuildTooling child-module scaffold and `New-BuildToolingChildModule`.
- Hardened parent exports to explicit functions, aliases, and empty cmdlet/variable arrays.
- Promoted the family-aware bootstrap through Production; installed deployment remains a separate gate.
- Prepared the parent compatibility dependency on the PesterScaffolding 0.1.0 pilot.
