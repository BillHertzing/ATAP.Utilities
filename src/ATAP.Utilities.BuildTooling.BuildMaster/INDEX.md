# BuildMaster — File Index

The active plans under [`Plans/`](Plans/) use a SecretName-only ProGet contract;
see the [module ReadMe](ReadMe.md) for the authentication boundary.

This folder holds the OtterScript pipeline plans and the PowerShell entry-point
scripts that BuildMaster executes for the four ATAP.Utilities build pipelines:

- **CSharpPackage** — single NuGet meta-package, 5-tier promotion.
- **PowerShellModule** — single PowerShell module nupkg, 5-tier promotion.
- **DatabaseChangePackage** — single database change package nupkg, 5-tier
  promotion across `database-*` feeds.
- **ReleaseBundle** — product Universal Package, 6 stages including manifest
  generation and Chocolatey / WinGet publication.

All three pipelines follow the [Immutable Build Strategy](../../SolutionDocumentation/Immutable-Build-Strategy.md):
a single build happens in the Experimental stage; subsequent tiers promote the
same bytes through ProGet feeds and run promotion-side tests.

---

## OtterScript files

OtterScript plans are intentionally thin glue; non-trivial logic lives in the
`.ps1` workers in this folder so it can be unit-tested.

| File                                                                                                 | Kind     | What it does                                                                                                                                                                                                                                                       |
| ---------------------------------------------------------------------------------------------------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| [Plans/CSharpPackage-5Stage.otter](Plans/CSharpPackage-5Stage.otter)                                 | Plan     | 5-stage BuildMaster pipeline for the ATAP.Utilities C# meta-package: Experimental builds + publishes the .nupkg; Development → Integration → QA → Production stages promote that immutable nupkg through `nuget-experimental … nuget-stable` and run tier tests.  |
| [Plans/PowerShellModule-5Stage.otter](Plans/PowerShellModule-5Stage.otter)                           | Plan     | 5-stage BuildMaster pipeline for a single PowerShell module: Experimental builds + publishes the module nupkg to `powershellget-experimental`; later tiers call `Invoke-PowerShellModuleBuildMasterStage.ps1` to promote + test the same artifact up the feed chain. |
| [Plans/DatabaseChangePackage-5Stage.otter](Plans/DatabaseChangePackage-5Stage.otter)                 | Plan     | 5-stage BuildMaster pipeline for a database change package: Experimental builds the .nupkg via `New-DatabaseChangePackage` and pushes to `database-experimental`; Development → Integration → QA → Production promote the immutable nupkg through the canonical `database-*` feeds. `ExcludedMigrationFileNames` carries an optional semicolon-delimited, exact-name release boundary into the builder and run context. When a tier's `*DatabaseDBConnectionStringSecretName` Application Variable is set, the runner also enforces a Flyway rehearsal **before** each promotion and applies (migrate) the package to that tier's real database **after** it (Task 9.10). DBA2-T03 / V4-E08. |
| [Plans/ReleaseBundle-6Stage.otter](Plans/ReleaseBundle-6Stage.otter)                                 | Plan     | 6-stage BuildMaster pipeline for a product Release Bundle (Universal Package): Experimental builds the manifest + bundle, later stages promote across `releasebundle-*` feeds, Integration runs Flyway rehearsal, Production publishes to Chocolatey and WinGet.    |
| [Monitors/CSharpPackage-RepositoryMonitors.otter](Monitors/CSharpPackage-RepositoryMonitors.otter)   | Monitors | Declarative definition of the pilot BuildMaster Repository Monitors that fire `CSharpPackage-5Stage` for `ATAP.Utilities.StronglyTypedId` when sprint-branch or main pushes land under that package's `src/` folder, passing the C# package tuple to the shared application. |
| [Monitors/PowerShellModule-RepositoryMonitors.otter](Monitors/PowerShellModule-RepositoryMonitors.otter) | Monitors | Declarative definition of the pilot BuildMaster Repository Monitors that fire `PowerShellModule-5Stage` for `ATAP.Utilities.BuildTooling.PowerShell` when sprint-branch or main pushes land under that module's `src/` folder, passing `ModuleName`/`PackageName` to the shared PowerShell app. |

---

## PowerShell files

All `.ps1` files conform to [`.claude/Rules/Powershell.md`](../../../SharedVSCode/.claude/Rules/Powershell.md):
eponymous worker function, comment-based help with the `"AI assisted using
Powershell.instructions.md as guidelines"` validation string, `[CmdletBinding()]`
with `BEGIN`/`PROCESS`/`END` blocks, `$fn` and `$mn` populated at the top of
`BEGIN`, `Write-PSFMessage` logging, and `try`/`catch`/`finally` around risky
operations.

### Plans

| File                                                                                                                       | Eponymous Function                       | What it does                                                                                                                                                                                                                                                                                          |
| -------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [Plans/BuildMasterRunContext.Common.ps1](Plans/BuildMasterRunContext.Common.ps1)                                           | _(multi-function helper library)_        | Dot-sourced helper file. Defines the per-build run-context directory layout under `_generated/buildmaster/<BuildMasterBuildId>/`, the build-context.json shape, retention sweeping, allow-decision computation, and the `Write-BuildMasterRunStateFiles` helper used by every Initialize-* script.        |
| [Plans/Initialize-CSharpPackageBuildContext.ps1](Plans/Initialize-CSharpPackageBuildContext.ps1)                           | `Initialize-CSharpPackageBuildContext`   | Resolves `Get-BuildContext` for a C# package, validates the captured immutable `ResolvedVersion` across reruns, drops per-tier `.tmp` state markers OtterScript reads with `$FileContents()`, and persists `build-context.json`.                                                                       |
| [Plans/Initialize-PowerShellModuleBuildContext.ps1](Plans/Initialize-PowerShellModuleBuildContext.ps1)                     | `Initialize-PowerShellModuleBuildContext`| Same workflow as the C# variant but state-file names are prefixed with `$ModuleName` so two modules can share a single run-context directory. Drift between captured and current `ResolvedPackageVersion` is reported via `Write-PSFMessage -Level Important`, not thrown.                              |
| [Plans/Initialize-ReleaseBundleBuildContext.ps1](Plans/Initialize-ReleaseBundleBuildContext.ps1)                           | `Initialize-ReleaseBundleBuildContext`   | Resolves `Get-BuildContext` for a product (by `ReleaseTag` when present, otherwise by `Branch`), emits the `releasebundle_*.tmp` markers, serialises the build context to `releasebundle_context.json`, and persists `build-context.json`.                                                              |
| [Plans/Invoke-PowerShellModuleBuildMasterStage.ps1](Plans/Invoke-PowerShellModuleBuildMasterStage.ps1)                     | `Invoke-PowerShellModuleBuildMasterStage`| Drives one BuildMaster stage of the PowerShellModule pipeline. Experimental: invokes `Invoke-ModuleBuildWithRetry`, locates the produced nupkg, publishes to `powershellget-experimental`. Other tiers: `Promote-ProGetPackage` + `Invoke-PromotedModuleTests`, passing explicit ProGet URL/API key values because BuildMaster runs profileless. Stage completion markers make reruns idempotent. |
| [Plans/Invoke-DatabasePackageBuildMasterStage.ps1](Plans/Invoke-DatabasePackageBuildMasterStage.ps1)                       | `Invoke-DatabasePackageBuildMasterStage` | Drives one BuildMaster stage of the DatabaseChangePackage pipeline. Experimental: invokes `New-DatabaseChangePackage`, then `Publish-DatabaseChangePackageToProGet` against `database-experimental`. Other tiers: `Promote-DatabaseChangePackage` with feed-direction and ceiling enforcement. **Per-tier apply + rehearsal-before-promotion (Task 9.10):** when a tier's `*DatabaseDBConnectionStringSecretName` is supplied, runs `Invoke-DatabasePackageRehearsal` before each promotion (throws to block promotion on failure) and `Invoke-Flyway -FlywayCommand migrate` against the tier database afterward (Integration→QA→Production map to the `Testing`/`Production` Flyway environments and take a pre-migration snapshot); `-SkipRehearsal`/`-SkipApply` are audited bypasses. Stage completion + `.applied.tmp` markers make reruns idempotent. DBA2-T03 / V4-E08 / Task 9.10. |
| [Plans/New-ReleaseBundleBuildMasterPackage.ps1](Plans/New-ReleaseBundleBuildMasterPackage.ps1)                             | `New-ReleaseBundleBuildMasterPackage`    | Loads the release-bundle context JSON, calls `New-ReleaseManifest` and `New-ReleaseBundle`, publishes the Universal Package to the configured ProGet Experimental feed, drops per-bundle markers, and updates `build-context.json`.                                                                     |

### Scripts

| File                                                                                                       | Eponymous Function | What it does                                                                                                                                                                                                                                                  |
| ---------------------------------------------------------------------------------------------------------- | ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| [Scripts/Resolve-FeedName.ps1](Scripts/Resolve-FeedName.ps1)                                               | `Resolve-FeedName` | Resolves a ProGet feed name for a given 5-Tier tier and feed type from BuildTooling settings (bootstrapping `$global:Settings` from `HostSettings.PackageRepositoryFeeds.psd1` when needed) and writes it to `-OutputFile` for OtterScript to read back.       |

---

## Related Documentation

- [ReadMe.md](ReadMe.md) — High-level architecture and provisioning guide for this folder.
- `../../SolutionDocumentation/Immutable-Build-Strategy.md` — Foundational rule:
  build once in Experimental, promote bytes thereafter.
- `../../SolutionDocumentation/VersionJsonAsCeiling.md` — Why `version.json`
  pre-release labels behave as promotion ceilings rather than current stages.
- `../../SolutionDocumentation/BuildMaster-Pipeline-Topology.md` — How the three
  pipelines fit together at the BuildMaster application / pipeline level.
- `../../SolutionDocumentation/BuildMaster-ProGet-CSharp-Package-Pipeline.md` —
  Detailed walkthrough of the CSharp 5-stage flow.
- `../../SolutionDocumentation/Release-Bundle-Pipeline.md` — Detailed walkthrough
  of the Release-Bundle 6-stage flow.
