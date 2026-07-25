# Production Release Notes in Chronological order

# 0.1.71

- Adds the extracted SprintLifecycle child to the canonical family dependency
  graph and raises the parent dependency floor to the repaired child 0.1.5.
- Preserves the parent compatibility command surface while consuming the
  separately released SprintLifecycle implementation.

# 0.1.66

- Supersedes 0.1.65, whose Development gate exposed two remaining child-owned
  test containers in the parent test tree.
- Moves the ceiling-label and feature-slug tests to the DotnetBuild child.

# 0.1.65

- Supersedes 0.1.64, which stopped after Experimental because the BuildMaster
  service account could not resolve the child's stale 0.1.0 source manifest.
- Aligns the DotnetBuild source manifest with accepted package version 0.1.1.

# 0.1.64

- Adds the DotnetBuild child to the canonical parent dependency graph.
- Requires accepted DotnetBuild 0.1.1 after the immutable 0.1.0 Development
  validation failure.
- Preserves the frozen legacy build command surface through compatibility
  proxies.
- Retains only `Invoke-DotnetDatabaseNuGetPush` as an intentional residual
  wrapper for the later DatabasePackaging extraction.

# 0.1.63

- Adds the Secrets and ProGet child modules to the canonical parent entry in
  `ModuleFamily.psd1`, ensuring the generated package manifest preserves the
  accepted ProGet dependency floor of 0.1.1.
- Supersedes parent 0.1.62, which promoted successfully but generated a package
  manifest without the extracted Secrets and ProGet dependencies.

# 0.1.62

- Raised the ProGet child dependency floor from burned 0.1.0 to the accepted
  Stable/AllUsers 0.1.1 release.
- Supersedes parent 0.1.61, whose promoted matrices passed but whose dependency
  range still admitted the rejected child version.

# 0.1.61

- Applied the promoted-host-safe `Get-SecretATAP` Pester mock to the duplicate
  Unit test container exercised by BuildMaster's Alpha filter.
- Supersedes burned parent packages 0.1.59 and 0.1.60.

# 0.1.60

- Replaced the infrastructure-health secret stub with a Pester mock so the
  promoted Secrets module cannot shadow it in BuildMaster hosts.
- Updated stale environment-variable assertions to the current
  `SecretEnvironmentVariables` prohibition contract.
- Supersedes burned parent package 0.1.59.

# 0.1.59

- Re-exported the ProGet child through the aggregate compatibility module after
  promoting and installing `ATAP.Utilities.BuildTooling.ProGet.PowerShell`
  0.1.1.
- Preserved every command in the frozen 200-function parent contract.
- Retained `Invoke-DotnetNuGetPush` and
  `Invoke-DotnetDatabaseNuGetPush` as explicit parent-residual wrappers pending
  their later DotnetBuild and DatabasePackaging extractions.
- Removed the migrated ProGet implementation and test files from the parent.

# 0.1.54

- Re-exported nine AiRendering commands through the compatibility parent while
  moving their implementations, tests, and failure-acknowledgement schema into
  the independently released AiRendering 0.1.0 child.
- Preserved the exact 200-function legacy parent manifest and exposed two
  additional child-only commands through direct child import.
- Rewired the source bootstrap gate to the AiRendering child so clean
  BuildMaster builds no longer depend on a removed parent source file.

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
