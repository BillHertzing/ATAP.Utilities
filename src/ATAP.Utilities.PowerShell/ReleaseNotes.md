# Release Notes for ATAP.Utilities.PowerShell

## [0.1.26] — 2026-07-31

### Fixed

- Fall back to the verified .NET Windows special-folder directory when both
  process aliases are absent and Machine-scope `%SystemRoot%` expansion cannot
  resolve `windir`.
- Preserve the bounded Process-alias, Machine-alias, then special-folder lookup
  order and restore the exact prior Process values after registration.

## [0.1.25] — 2026-07-31

### Fixed

- Temporarily normalize missing local-process `windir` and `SystemRoot` from
  Machine scope while `Register-PSSessionConfiguration` runs, then restore the
  exact prior process values in `finally`.
- Fail closed when neither scope provides the required Windows roots. Remote
  registration remains unchanged and the function never enables remoting.

## [0.1.24] — 2026-07-31

### Fixed

- Package the source-owned `Profiles/` directory with the module so an
  AllUsers installation contains `Profiles/WithProfiles.pssc` and
  `Register-ProfiledRemotingEndpoint` can resolve its default session
  configuration from the installed module.

## [0.1.18] — 2026-07-09

### Fixed

- **SC-0252 — `Get-HostSettings` never probed the current sprint's ATAP.IAC worktree.** The candidate
  chain hard-coded `ATAP.IAC-wt-9-Sprint-0007-work-items` as its only sprint-shaped path. That
  worktree was deleted at the end of Sprint 0007, so resolution silently fell through to the
  **stable** ATAP.IAC checkout, and any `HostSettings` edit made in a sprint worktree — which is
  where the repository's boundary rule says sprint work belongs — had **no runtime effect** for four
  sprints. Six BuildMaster module→application mappings added during Sprint 0012 were inert as a
  result; the effective map showed 5 entries where the reviewed fragment declared 10.

  The sprint worktree is now **discovered by pattern**, never named. Candidate ordering moved to a
  new private helper, `Get-IACHostSettingsCandidatePath`, so it can be tested without a real ATAP.IAC
  checkout:

  1. an explicit `-IACBasePath`;
  2. `$env:ATAP_IAC_BASE_PATH` (process, then user scope) — an operator naming a path outranks
     anything discovered, so this moved **ahead** of auto-discovery;
  3. the newest ATAP.IAC sprint worktree under each search root;
  4. the stable `ATAP.IAC` checkout under each search root;
  5. the `Resources` copy inside the installed module.

  Sprint worktrees rank by sprint number then worktree number, both compared as **integers**. A
  lexical sort puts `wt-9-Sprint-0007` above `wt-15-Sprint-0012`, which would have reproduced the
  original bug from the other direction. There is a test for exactly that.

### Added

- `private/Get-IACHostSettingsCandidatePath.ps1` (not exported).
- `tests/Unit/Get-IACHostSettingsCandidatePath.Tests.ps1` — 16 tests covering the **default**
  candidate chain. The old suite passed `-IACBasePath` explicitly in all four of its tests, so the
  only code path that runs in production was untested. That is why SC-0252 survived four sprints.
  Two of the new tests are source guards: `Get-HostSettings` must contain no hard-coded sprint
  worktree literal, and must delegate to the discovery helper.

### Notes

- `Update-BuildMasterApplicationMap`'s `$requiredMappings` list is retained as a **backstop** for a
  lagging HostSettings fragment, and is now documented as such. It is not the source of truth: a
  module missing from the effective map should be fixed in the ATAP.IAC fragment, not added here.
  Before this fix it was the *only* thing keeping core module routing alive.

## [0.1.2] — 2026-06-02

### Fixed

- **Manifest alias exports**: Corrected `AliasesToExport` in the module manifest to include only function-level aliases:
  - `Get-PVal` → alias for `Get-ParameterValueFromNeoConfigurationRoot`
  - `Resolve-PVal` → alias for `Resolve-ParameterValueToList`
  - Removed 9 stale parameter-level alias entries (`OutDir`, `ITypes`, `InObj`, etc.) that were incorrectly exported
  
- **BuildManifest task**: Updated `module.build.ps1` `BuildManifest` task to correctly identify function-level aliases using PowerShell AST:
  - Scans for `Set-Alias`/`New-Alias` CommandAst call-sites
  - Scans for `[Alias()]` attributes on function declarations (ParamBlockAst parent)
  - Excludes parameter-level `[Alias()]` attributes (ParameterAst parent) via structural filtering
  - Deduplicates and passes alias list to `Build-PSModuleManifest` for accurate population of `AliasesToExport`

- **PSScriptAnalyzer suppressions**: Added `[Diagnostics.CodeAnalysis.SuppressMessageAttribute]` for `PSAvoidUsingConvertToSecureStringWithPlainText` in:
  - `Invoke-ProvisionInedoServiceAccounts.ps1` — passwords read interactively from clipboard (ephemeral plaintext)
  - `Invoke-SetInedoServiceLogonAccounts.ps1` — passwords read interactively from clipboard (ephemeral plaintext)

### Known Issues

- **Pre-release warnings**: 41 pre-existing PSScriptAnalyzer warnings remain (ShouldProcess false positives in profiles, Invoke-Expression usage). These are deferred to a future cleanup task and do not block Production tier releases.

### Build / Distribution

- **Stable feed**: Published to `powershellget-stable` feed for general production use
- **Dependencies**: No new dependencies
- **Minimum PowerShell**: 5.1 (Desktop) and 7.x (Core)

---

## [0.1.1] — Earlier

Historical release — see git history for prior changes.
