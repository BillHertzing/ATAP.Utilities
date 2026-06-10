# Release Notes for ATAP.Utilities.PowerShell

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