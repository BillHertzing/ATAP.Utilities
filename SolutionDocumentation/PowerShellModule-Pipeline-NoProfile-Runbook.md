# PowerShell-Module Pipeline — `-NoProfile` Settings Resolution Runbook

> **Task 13.62 security cutover:** The pipeline now passes `ProGet.BuildMaster.API.Key` as `-ProGetApiKeySecretName`; authenticated leaves resolve it with `Get-SecretATAP`. Retired environment-variable and raw-value guidance has been removed.

**Task:** V4-B02 (Sprint 0007) · **Update:** Task 9.38 (Sprint 0009) · **Status:** Policy of record · **Date:** 2026-06-16

## Purpose

BuildMaster runs the PowerShell-module 5-tier pipeline by invoking the runner with
`pwsh -NoProfile -File` (see the single `Exec` in
[`PowerShellModule-5Stage.otter`](../src/ATAP.Utilities.BuildTooling.BuildMaster/Plans/PowerShellModule-5Stage.otter)).
Under `-NoProfile`, the interactive user profile that populates `$global:settings` and
`$global:configRootKeys` **never loads**.

To ensure variables and configuration resolve identically between a developer's interactive workstation and the unattended BuildMaster pipeline, the pipeline runners explicitly bootstrap `$global:settings` in memory. This is achieved via a standalone settings loader helper (`Initialize-LocalHostSettings` in `BuildMasterRunContext.Common.ps1`).

This design allows the runners to execute within a fast, hermetic `-NoProfile` shell while maintaining full access to the host settings profile configuration, completely eliminating the need for silent fallback degradation or bypass markers inside `Get-PVal`.

## The Standalone Settings Loader (`Initialize-LocalHostSettings`)

Rather than relying on the PowerShell SCM or service profile configuration (which is complex to set up securely for service accounts like `SvcBuildMaster`), the stage runners explicitly load host settings in memory:

1. Dot-source [`BuildMasterRunContext.Common.ps1`](../src/ATAP.Utilities.BuildTooling.BuildMaster/Plans/BuildMasterRunContext.Common.ps1).
2. Call `Initialize-LocalHostSettings -SourcePath $SourcePath`.

This helper resolves the local hostname, sets up `$global:PSDefaultParameterValues` settings references, locates the host configuration settings using the active sprint/stable worktree path, and populates `$global:settings` and `$global:configRootKeys` in memory.

Since `$global:settings` is now guaranteed to be populated, the `Get-PVal` loud-failure guard does not need any context bypass logic. The old `$env:ATAP_NOPROFILE_PIPELINE = '1'` context marker and `Test-NoProfilePipelineContext` check have been deprecated and removed.

## Audit table — settings lookups and their `-NoProfile` resolution

| Settings lookup | Where | Resolution under `-NoProfile` |
| --- | --- | --- |
| BuildMaster app vars: `$ApplicationName`, `$Branch`, `$SourcePath`, `$ModuleName`, `$PackageName`, `$ProGetUrl`, `$BuildMasterBuildId` | `.otter` plan | Passed as explicit `-Parameters` on the single `Exec`. **No `$global:settings` in OtterScript.** |
| ProGet authentication | runner parameter / authenticated leaf | Runner receives `ProGet.BuildMaster.API.Key` as `-ProGetApiKeySecretName`; the leaf resolves with `Get-SecretATAP` and fails closed. |
| `$env:GIT_CONFIG_COUNT` | runner (`Add-GitSafeDirectoryForCurrentProcess`) | Defaults to `0` when unset. |
| `$env:ATAP_BUILDTOOLING_PESTER_OUTPUT_VERBOSITY` | runner (promotion/test) | Defaults to `'None'`; unknown values warned + ignored. |
| `Get-PVal` chain for `Name` / `Version` / `FromFeed` / `ToFeed` | `Move-ProGetPackageInterTier`, `Invoke-PromotedModuleTests` | Resolves **PSBoundParameters → env var → settings**. Because `$global:settings` is explicitly loaded in memory by `Initialize-LocalHostSettings`, `Get-PVal` has full access to host settings just like an interactive session, and resolves settings values cleanly without throwing or degrading. |
| `$global:settings[GeneratedRelativePath]` for transcript path | `Invoke-ModuleBuildWithRetry` | Handled via the populated `$global:settings` in memory, falling back to `<moduleRoot>\_generated` (SC-0033) if needed. |

## Policy for future changes

1. **Never assume user/machine profiles are loaded automatically** in this pipeline. The runner and everything it dot-sources run under `-NoProfile`.
2. **Always call `Initialize-LocalHostSettings`** at the entry point of any new stage runner script before calling other build tooling functions that depend on `Get-PVal` or settings globals.
3. **Secrets stay off the command line.** Pass only
   `-ProGetApiKeySecretName ProGet.BuildMaster.API.Key`; never accept a raw
   `ApiKey` parameter or read a ProGet API-key environment variable.
4. **No context bypass markers.** Do not re-introduce `$env:ATAP_NOPROFILE_PIPELINE` or similar context degradation flags. All runners should bootstrap settings explicitly.

## Regression test

[`PowerShellModule-5Stage.Tests.ps1`](../src/ATAP.Utilities.BuildTooling.BuildMaster/Plans/tests/PowerShellModule-5Stage.Tests.ps1) pins this contract:

- Plan is a thin `-NoProfile -File` runner plan with no `$global:settings` in
  OtterScript, no inline `pwsh -Command`, and only a SecretName in arguments.
- Runner carries the canonical SecretName, performs no unguarded
  `$global:settings` read, and calls `Initialize-LocalHostSettings`; the
  authenticated leaf performs resolution.
- **Behavioral proof:** Under a bare `-NoProfile` session with no initialized settings, `Get-PVal` fails loud (throws) as expected. The runner itself calls `Initialize-LocalHostSettings` to bootstrap settings.

Run it (with the profile loaded — never run Pester with `-NoProfile`, per [`PowerShell-Modules-Test-Process.md`](PowerShell-Modules-Test-Process.md)):

```powershell
pwsh -Command "Invoke-Pester -Path './src/ATAP.Utilities.BuildTooling.BuildMaster/Plans/tests/PowerShellModule-5Stage.Tests.ps1' -Output Detailed"
```

The `Get-PVal` unit suite ([`Get-ParameterValueFromNeoConfigurationRoot.Tests.ps1`](../src/ATAP.Utilities.PowerShell/tests/Unit/Get-ParameterValueFromNeoConfigurationRoot.Tests.ps1)) also passes, verifying the loud-failure guard behavior when settings are absent.

## See also

- [`ConfigRootKeys-and-HostSettings.md`](ConfigRootKeys-and-HostSettings.md) §6.2 — the general defensive guard for no-profile / agent shells.
- [`PowerShell-Modules-Test-Process.md`](PowerShell-Modules-Test-Process.md) — why Pester itself must run **with** the profile.
- [`BuildMaster-Pipeline-Topology.md`](BuildMaster-Pipeline-Topology.md), [`Immutable-Build-Strategy.md`](Immutable-Build-Strategy.md) — pipeline shape and the build-once/promote-bytes model this runner implements.
