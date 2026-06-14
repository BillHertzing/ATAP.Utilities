# PowerShell-Module Pipeline — `-NoProfile` Settings Resolution Runbook

**Task:** V4-B02 (Sprint 0007) · **Status:** Policy of record · **Date:** 2026-06-04

## Purpose

BuildMaster runs the PowerShell-module 5-tier pipeline by invoking the runner with
`pwsh -NoProfile -File` (see the single `Exec` in
[`PowerShellModule-5Stage.otter`](../src/ATAP.Utilities.BuildTooling.BuildMaster/Plans/PowerShellModule-5Stage.otter)).
Under `-NoProfile`, the interactive user profile that populates `$global:settings` and
`$global:configRootKeys` **never loads**. Any settings lookup that assumes those globals
exist fails at deploy time with a confusing `$null`-index error deep inside a helper.

This runbook records the audit of **every settings lookup used by the plan and the
runner**, confirms each resolves under `-NoProfile`, and states the policy that future
edits must keep.

> **Audit conclusion:** the plan + runner are already `-NoProfile`-safe. Every settings
> lookup resolves through an explicit parameter, an environment variable, or a
> null-guarded read with a default. **No code change was required** — this task added the
> policy record and a regression test.

## Why this pipeline is safe (and the C# pipeline needed a bootstrap)

The decisive structural fact: the PowerShell-module runner **never calls
`Resolve-ProGetFeedFromSettings`** — the one helper that *throws* when `$global:Settings`
is null. It computes feed URIs directly from the `-ProGetUrl` parameter via
`Get-PowerShellGetFeedUri` and publishes with `Publish-PSResource`.

By contrast, the **C# package** runner's publish path
(`Publish-NuGetPackageToProGet → Resolve-ProGetFeedFromSettings`) *does* read those
globals, so it carries a deliberate bootstrap,
[`Set-NoProfileProGetFeedSettings`](../src/ATAP.Utilities.BuildTooling.BuildMaster/Plans/Invoke-CSharpPackageBuildMasterStage.ps1),
to seed the minimal feed settings under `-NoProfile`. The PowerShell-module runner needs
no equivalent. If a settings-driven feed *resolver* is ever introduced into this
pipeline, it MUST be paired with a `Set-NoProfileProGetFeedSettings`-style bootstrap.

## Audit table — settings lookups and their `-NoProfile` resolution

| Settings lookup | Where | Resolution under `-NoProfile` |
| --- | --- | --- |
| BuildMaster app vars: `$ApplicationName`, `$Branch`, `$SourcePath`, `$ModuleName`, `$PackageName`, `$ProGetUrl`, `$BuildMasterBuildId` | `.otter` plan | Passed as explicit `-Parameters` on the single `Exec`. **No `$global:settings` in OtterScript.** |
| ProGet API key | runner `BEGIN` | `$env:PROGET_BUILDMASTER_API_KEY` → `$env:PROGET_ADMIN_API_KEY` → explicit `throw "Unable to resolve ProGet API key…"`. Never a parameter (keeps secrets off the command line). |
| `$env:GIT_CONFIG_COUNT` | runner (`Add-GitSafeDirectoryForCurrentProcess`) | Defaults to `0` when unset. |
| `$env:ATAP_BUILDTOOLING_PESTER_OUTPUT_VERBOSITY` | runner (promotion/test) | Defaults to `'None'`; unknown values warned + ignored. |
| `Get-PVal` chain for `Name` / `Version` / `FromFeed` / `ToFeed` / `Reason` / `ProGetBaseUrl` / `ApiKey` | `Move-ProGetPackageInterTier`, `Invoke-PromotedModuleTests` | `Get-PVal` (`Get-ParameterValueFromNeoConfigurationRoot`) resolves **PSBoundParameters → env var → settings → DefaultValue**. The settings tier runs `-AllowMissing` inside a try/catch, so when the globals are absent it **degrades to `DefaultValue` without throwing** — **provided the runner declared the no-profile pipeline context** (see the host-context note below). The runner pre-sets `$global:ProGetBaseUrl = $ProGetUrl` and `$env:PROGET_BUILDMASTER_API_KEY`, and passes `-ProGetBaseUrl`/`-ApiKey` explicitly to `Invoke-PromotedModuleTests`. |

### Host-context exception for the `Get-PVal` loud-failure guard (Task 9.1)

Sprint 0008 Task 8.16 (SC-prop-0007-1) added a **loud-failure guard** to `Get-PVal`: if
resolution reaches the settings tier and **no** settings source exists at all (no
`-Settings`, no `$script:Settings`, no `$global:settings`), it throws instead of silently
returning the `DefaultValue`. The rationale is that an absent `$global:settings` in an
**interactive** ATAP session almost always means the profile failed to load, and silently
defaulting produced wrong BuildTooling behavior (Sprint-0007 V4-B01).

That guard directly contradicted this pipeline's documented contract, which **requires**
`Get-PVal` to degrade to the `DefaultValue` under `-NoProfile`. Both behaviors are correct
for their own context, so the guard is now **host-context aware**:

- The 5-tier runners (`Invoke-PowerShellModuleBuildMasterStage.ps1`,
  `Invoke-CSharpPackageBuildMasterStage.ps1`) **declare** the no-profile pipeline context
  by setting `$env:ATAP_NOPROFILE_PIPELINE = '1'` at the top of the script.
- In that declared context, the guard **yields** to an explicit `-DefaultValue` /
  `-AllowMissing` and the param → env → settings → DefaultValue chain degrades as
  documented.
- An interactive shell **never** sets the marker, so the loud-failure guard still fires —
  the SC-prop-0007-1 protection is fully intact for the case it was written for.

A bare `-NoProfile` on the command line is **not** the signal (Pester and other
non-interactive harnesses also launch `-NoProfile`); the explicit
`ATAP_NOPROFILE_PIPELINE` marker is what separates the pipeline from an interactive fault.
| `$global:settings[GeneratedRelativePath]` for transcript path | `Invoke-ModuleBuildWithRetry` | **Null-guarded** (`if ($null -ne $global:configRootKeys -and $null -ne $global:settings)`) with a fallback to `<moduleRoot>\_generated` (SC-0033). The runner also passes `-BuildLogPath` explicitly, so this branch never runs in the pipeline. |

## Policy for future changes

1. **Never assume `$global:settings` / `$global:configRootKeys` are populated** in this
   pipeline. The runner and everything it dot-sources run under `-NoProfile`.
2. **Every new settings lookup must resolve via an explicit parameter or environment
   variable.** Using the `Get-PVal` *parameter → env → settings → DefaultValue* chain is
   acceptable **because** it degrades to the `DefaultValue` when the globals are absent —
   so always supply a meaningful `-DefaultValue` (typically the bound parameter).
3. **Secrets stay off the command line.** Resolve API keys from `$env:PROGET_*` inside the
   runner; never add an `ApiKey`/`ProGetApiKey` parameter to the plan or runner.
4. **If you add a settings-driven resolver** (anything that reads `$global:Settings` and
   throws when absent, e.g. `Resolve-ProGetFeedFromSettings`), you MUST add a
   `Set-NoProfileProGetFeedSettings`-style bootstrap to the runner `BEGIN` block.
5. Any read of a profile global that survives MUST be **null-guarded with a default**, as
   `Invoke-ModuleBuildWithRetry` does for the generated path.

## Regression test

[`PowerShellModule-5Stage.Tests.ps1`](../src/ATAP.Utilities.BuildTooling.BuildMaster/Plans/tests/PowerShellModule-5Stage.Tests.ps1)
pins this contract (24 tests):

- Plan is a thin `-NoProfile -File` runner plan with no `$global:settings`, no inline
  `pwsh -Command`, no API key / `$env:PROGET_*` on the command line.
- Runner resolves the key from env (not a parameter), performs no unguarded
  `$global:settings` read, never references `Resolve-ProGetFeedFromSettings`, seeds
  `$global:ProGetBaseUrl` + the key env var before promotion, and passes
  `-ProGetBaseUrl`/`-ApiKey` explicitly to the promoted-module tests; the file parses
  clean.
- **Behavioral proof:** a clean `pwsh -NoProfile` child process that declares the
  pipeline context (`$env:ATAP_NOPROFILE_PIPELINE = '1'`) dot-sources `Get-PVal` and
  confirms it returns the `DefaultValue` (no throw) when no profile globals exist; a
  companion static check asserts the runner sets the `ATAP_NOPROFILE_PIPELINE` marker.

Run it (with the profile loaded — never run Pester with `-NoProfile`, per
[`PowerShell-Modules-Test-Process.md`](PowerShell-Modules-Test-Process.md)):

```powershell
pwsh -Command "Invoke-Pester -Path './src/ATAP.Utilities.BuildTooling.BuildMaster/Plans/tests/PowerShellModule-5Stage.Tests.ps1' -Output Detailed"
```

Last verified: **2026-06-13 — 24 passed, 0 failed** (Pester v5.7.1; Task 9.1 host-context
guard fix). The `Get-PVal` unit suite
([`Get-ParameterValueFromNeoConfigurationRoot.Tests.ps1`](../src/ATAP.Utilities.PowerShell/tests/Unit/Get-ParameterValueFromNeoConfigurationRoot.Tests.ps1))
also passes 34/0, covering both the interactive loud-failure case and the declared
pipeline-context degrade case.

## See also

- [`ConfigRootKeys-and-HostSettings.md`](ConfigRootKeys-and-HostSettings.md) §6.2 — the
  general defensive guard for no-profile / agent shells.
- [`PowerShell-Modules-Test-Process.md`](PowerShell-Modules-Test-Process.md) — why Pester
  itself must run **with** the profile.
- [`BuildMaster-Pipeline-Topology.md`](BuildMaster-Pipeline-Topology.md),
  [`Immutable-Build-Strategy.md`](Immutable-Build-Strategy.md) — pipeline shape and the
  build-once/promote-bytes model this runner implements.
